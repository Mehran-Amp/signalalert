<?php
/**
 * SignalAlert - Iran High-Speed Market Data Bridge & Proxy (v2.2.3)
 * Secure, token-isolated, and production hardened.
 * Host: https://aegkala.com/market-bridge.php
 */

@ini_set('display_errors', '0');
@error_reporting(0);
@set_time_limit(15);

// 1. Load Secret Token from Environment or Config File
$token = getenv('SIGNALALERT_BRIDGE_TOKEN');

if (empty($token)) {
    $configPaths = [
        dirname(__DIR__) . '/market-bridge.config.php', // Parent directory (above public_html)
        __DIR__ . '/market-bridge.config.php',          // Same directory
    ];
    foreach ($configPaths as $path) {
        if (file_exists($path)) {
            $conf = @include $path;
            if (is_array($conf) && !empty($conf['token'])) {
                $token = trim($conf['token']);
                break;
            }
        }
    }
}

// Token must be at least 16 characters for security
if (empty($token) || strlen($token) < 16) {
    http_response_code(500);
    header('Content-Type: application/json; charset=utf-8');
    echo json_encode([
        'success' => false,
        'message' => 'Server configuration error: Bridge token not set or invalid.'
    ], JSON_UNESCAPED_UNICODE);
    exit;
}

define('SECRET_TOKEN', $token);
define('CACHE_TTL', 60); // 60 seconds RAM/Disk cache
define('CACHE_FILE', sys_get_temp_dir() . '/sig_market_bridge_cache_v22.json');

// 2. Set JSON Response Headers & Security
header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Headers: Authorization, Content-Type');
header('X-Bridge-Version: 2.2.3');

// Enforce GET Method Only
if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    http_response_code(405);
    echo json_encode([
        'success' => false,
        'message' => 'Method Not Allowed. Only GET requests are accepted.'
    ], JSON_UNESCAPED_UNICODE);
    exit;
}

// 3. Strict Header-Only Authentication (Bearer Token)
$authHeader = isset($_SERVER['HTTP_AUTHORIZATION']) ? $_SERVER['HTTP_AUTHORIZATION'] : (isset($_SERVER['REDIRECT_HTTP_AUTHORIZATION']) ? $_SERVER['REDIRECT_HTTP_AUTHORIZATION'] : '');

$providedToken = '';
if (preg_match('/Bearer\s+(.*)$/i', $authHeader, $matches)) {
    $providedToken = trim($matches[1]);
}

if (empty($providedToken) || !hash_equals(SECRET_TOKEN, $providedToken)) {
    http_response_code(401);
    echo json_encode([
        'success' => false,
        'message' => 'Unauthorized'
    ], JSON_UNESCAPED_UNICODE);
    exit;
}

// 4. Check Local Cache (Sub-millisecond response)
$now = time();
$forceRefresh = isset($_GET['refresh']) && $_GET['refresh'] === '1';

if (!$forceRefresh && file_exists(CACHE_FILE)) {
    $cacheContent = @file_get_contents(CACHE_FILE);
    if ($cacheContent) {
        $cachedData = @json_decode($cacheContent, true);
        if (is_array($cachedData) && isset($cachedData['timestamp']) && ($now - $cachedData['timestamp']) < CACHE_TTL) {
            $cachedData['cached'] = true;
            $cachedData['age_seconds'] = $now - $cachedData['timestamp'];
            echo json_encode($cachedData, JSON_UNESCAPED_UNICODE);
            exit;
        }
    }
}

// 5. Safe cURL Helper with strict timeout
function fetchApi($url, $headers = [], $timeout = 3) {
    if (!function_exists('curl_init')) return null;
    $ch = @curl_init();
    if (!$ch) return null;
    
    @curl_setopt($ch, CURLOPT_URL, $url);
    @curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    @curl_setopt($ch, CURLOPT_TIMEOUT, $timeout);
    @curl_setopt($ch, CURLOPT_CONNECTTIMEOUT, 2);
    @curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, true);
    @curl_setopt($ch, CURLOPT_SSL_VERIFYHOST, 2);
    @curl_setopt($ch, CURLOPT_USERAGENT, 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36');
    
    $reqHeaders = [
        'Accept: application/json, text/plain, */*',
        'Accept-Language: fa,en-US;q=0.9',
    ];
    if (!empty($headers)) {
        $reqHeaders = array_merge($reqHeaders, $headers);
    }
    @curl_setopt($ch, CURLOPT_HTTPHEADER, $reqHeaders);

    $response = @curl_exec($ch);
    $httpCode = @curl_getinfo($ch, CURLINFO_HTTP_CODE);
    @curl_close($ch);
    
    if ($httpCode === 200 && $response) {
        return $response;
    }
    return null;
}

$rates = [];
$failedSources = [];

// =========================================================================
// 1. Nobitex Exchange (USDT, Gold 18k, BTC, ETH)
// =========================================================================
$nobitexRaw = fetchApi("https://apiv2.nobitex.ir/market/stats", ['Referer: https://nobitex.ir/']);
if ($nobitexRaw) {
    $nobiJson = @json_decode($nobitexRaw, true);
    if (isset($nobiJson['stats'])) {
        $stats = $nobiJson['stats'];
        // USDT
        $usdt = isset($stats['usdt-irt']['latest']) ? $stats['usdt-irt']['latest'] : (isset($stats['usdt-rls']['latest']) ? floatval($stats['usdt-rls']['latest'])/10.0 : null);
        if ($usdt && floatval($usdt) > 0) {
            $rates['USDT_NOBITEX'] = ['price' => floatval($usdt), 'unit' => 'تومان', 'source' => 'Nobitex'];
            $rates['USD_TMN'] = ['price' => floatval($usdt), 'unit' => 'تومان', 'source' => 'Nobitex Tether'];
        }
        // Gold 18k
        $pm = isset($stats['pm-irt']['latest']) ? $stats['pm-irt']['latest'] : (isset($stats['pm-rls']['latest']) ? floatval($stats['pm-rls']['latest'])/10.0 : null);
        if ($pm && floatval($pm) > 0) {
            $rates['GOLD_NOBITEX'] = ['price' => floatval($pm), 'unit' => 'تومان', 'source' => 'Nobitex Gold'];
        }
        // BTC & ETH
        if (isset($stats['btc-irt']['latest']) && floatval($stats['btc-irt']['latest']) > 0) {
            $rates['BTC_NOBITEX'] = ['price' => floatval($stats['btc-irt']['latest']), 'unit' => 'تومان', 'source' => 'Nobitex'];
        }
        if (isset($stats['eth-irt']['latest']) && floatval($stats['eth-irt']['latest']) > 0) {
            $rates['ETH_NOBITEX'] = ['price' => floatval($stats['eth-irt']['latest']), 'unit' => 'تومان', 'source' => 'Nobitex'];
        }
    } else {
        $failedSources[] = 'Nobitex (Invalid structure)';
    }
} else {
    $failedSources[] = 'Nobitex';
}

// =========================================================================
// 2. Wallex Exchange (USDT, PAXG Gold, BTC, ETH)
// =========================================================================
$wallexRaw = fetchApi("https://api.wallex.ir/v1/markets");
if ($wallexRaw) {
    $wallexJson = @json_decode($wallexRaw, true);
    $symbols = isset($wallexJson['result']['symbols']) ? $wallexJson['result']['symbols'] : [];
    if (isset($symbols['USDTTMN']['stats']['lastPrice'])) {
        $rates['USDT_WALLEX'] = ['price' => floatval($symbols['USDTTMN']['stats']['lastPrice']), 'unit' => 'تومان', 'source' => 'Wallex'];
    }
    if (isset($symbols['PAXGTMN']['stats']['lastPrice'])) {
        $rates['GOLD_WALLEX'] = ['price' => floatval($symbols['PAXGTMN']['stats']['lastPrice']), 'unit' => 'تومان', 'source' => 'Wallex'];
    }
    if (isset($symbols['BTCTMN']['stats']['lastPrice'])) {
        $rates['BTC_WALLEX'] = ['price' => floatval($symbols['BTCTMN']['stats']['lastPrice']), 'unit' => 'تومان', 'source' => 'Wallex'];
    }
    if (isset($symbols['ETHTMN']['stats']['lastPrice'])) {
        $rates['ETH_WALLEX'] = ['price' => floatval($symbols['ETHTMN']['stats']['lastPrice']), 'unit' => 'تومان', 'source' => 'Wallex'];
    }
} else {
    $failedSources[] = 'Wallex';
}

// =========================================================================
// 3. Tetherland Exchange (USDT)
// =========================================================================
$tetherlandRaw = fetchApi("https://api.tetherland.com/currencies");
if ($tetherlandRaw) {
    $tlandJson = @json_decode($tetherlandRaw, true);
    $tlandPrice = isset($tlandJson['data']['currencies']['USDT']['price']) ? $tlandJson['data']['currencies']['USDT']['price'] : null;
    if ($tlandPrice && floatval($tlandPrice) > 0) {
        $rates['USDT_TETHERLAND'] = ['price' => floatval($tlandPrice), 'unit' => 'تومان', 'source' => 'Tetherland'];
    }
} else {
    $failedSources[] = 'Tetherland';
}

// =========================================================================
// 4. Tabdeal Exchange (USDT)
// =========================================================================
$tabdealRaw = fetchApi("https://api1.tabdeal.org/r/api/v1/depth?symbol=USDTIRT");
if ($tabdealRaw) {
    $tabJson = @json_decode($tabdealRaw, true);
    if (isset($tabJson['bids'][0][0])) {
        $p = floatval($tabJson['bids'][0][0]);
        if ($p > 0) {
            $rates['USDT_TABDEAL'] = ['price' => $p, 'unit' => 'تومان', 'source' => 'Tabdeal'];
        }
    }
} else {
    $failedSources[] = 'Tabdeal';
}

// =========================================================================
// 5. TSETMC Verified Gold Funds (AYAR, TALA, ZAR, KAHROBA, GOHAR)
// =========================================================================
$verifiedGoldFunds = [
    'AYAR' => ['inscode' => '34144395039913458', 'name' => 'صندوق طلای عیار'],
    'TALA' => ['inscode' => '46700660505281786', 'name' => 'صندوق طلای کیان'],
    'ZAR' => ['inscode' => '33254899395816171', 'name' => 'صندوق طلای زرفام'],
    'KAHROBA' => ['inscode' => '25559236668122210', 'name' => 'صندوق طلای کهربا'],
    'GOHAR' => ['inscode' => '12390706505809150', 'name' => 'صندوق طلای گوهر'],
];

foreach ($verifiedGoldFunds as $sym => $info) {
    $raw = fetchApi("https://cdn.tsetmc.com/api/ClosingPrice/GetClosingPriceInfo/{$info['inscode']}", [
        'Referer: https://tsetmc.com/',
        'Origin: https://tsetmc.com'
    ], 2);
    if ($raw) {
        $j = @json_decode($raw, true);
        $closing = isset($j['closingPriceInfo']['pClosing']) ? $j['closingPriceInfo']['pClosing'] : (isset($j['closingPriceInfo']['pDrCotVal']) ? $j['closingPriceInfo']['pDrCotVal'] : null);
        if ($closing && floatval($closing) > 0) {
            $rates[$sym] = [
                'price' => floatval($closing) / 10.0, // Rial to Toman
                'unit' => 'تومان',
                'source' => $info['name'] . ' (TSETMC)'
            ];
        }
    }
}

// =========================================================================
// 6. Response Compilation & Cache Management
// =========================================================================
if (!empty($rates)) {
    $responsePayload = [
        'success' => true,
        'timestamp' => $now,
        'datetime' => date('Y-m-d H:i:s'),
        'cached' => false,
        'stale' => false,
        'failed_sources' => $failedSources,
        'source' => 'aegkala_iran_bridge',
        'symbols_count' => count($rates),
        'data' => $rates,
    ];

    @file_put_contents(CACHE_FILE, json_encode($responsePayload, JSON_UNESCAPED_UNICODE));
    echo json_encode($responsePayload, JSON_UNESCAPED_UNICODE);
    exit;
}

// Fallback to Stale Cache if all upstreams failed
if (file_exists(CACHE_FILE)) {
    $staleContent = @file_get_contents(CACHE_FILE);
    if ($staleContent) {
        $staleData = @json_decode($staleContent, true);
        if (is_array($staleData)) {
            $staleData['cached'] = true;
            $staleData['stale'] = true;
            $staleData['age_seconds'] = $now - (isset($staleData['timestamp']) ? $staleData['timestamp'] : $now);
            $staleData['failed_sources'] = $failedSources;
            echo json_encode($staleData, JSON_UNESCAPED_UNICODE);
            exit;
        }
    }
}

// 503 If completely down and no cache exists
http_response_code(503);
echo json_encode([
    'success' => false,
    'message' => 'All upstream market sources are currently unavailable.',
    'failed_sources' => $failedSources
], JSON_UNESCAPED_UNICODE);
