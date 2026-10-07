<?php
/**
 * SignalAlert - Iran High-Speed Market Data Bridge & Proxy
 * Host this file on your Iranian server (e.g. https://aegkala.com/market-bridge.php)
 *
 * It securely fetches TSETMC Bourse Indices, Gold ETFs, Free FX & Official Rates from inside Iran,
 * caches them locally for 60 seconds, and serves them rapidly to your German Alert Server.
 */

// 1. Security Secret Token (Must match the token configured in your server.py)
define('SECRET_TOKEN', 'sig_bridge_98f4a2e1d7c6b5a0e3f892147acb');
define('CACHE_TTL', 60); // 60 seconds cache
define('CACHE_FILE', sys_get_temp_dir() . '/signalalert_market_cache.json');

// 2. Set JSON Response Headers & CORS
header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Headers: Authorization, Content-Type');
header('X-Bridge-Version: 1.0.0');

// 3. Authenticate Request
$authHeader = isset($_SERVER['HTTP_AUTHORIZATION']) ? $_SERVER['HTTP_AUTHORIZATION'] : '';
$queryToken = isset($_GET['token']) ? $_GET['token'] : '';

$providedToken = '';
if (preg_match('/Bearer\s+(.*)$/i', $authHeader, $matches)) {
    $providedToken = trim($matches[1]);
} elseif (!empty($queryToken)) {
    $providedToken = trim($queryToken);
}

if ($providedToken !== SECRET_TOKEN) {
    http_response_code(401);
    echo json_encode([
        'success' => false,
        'message' => 'Unauthorized: Invalid or missing secret token.',
    ], JSON_UNESCAPED_UNICODE);
    exit;
}

// 4. Check Local Cache (Sub-millisecond response)
$now = time();
$forceRefresh = isset($_GET['refresh']) && $_GET['refresh'] === '1';

if (!$forceRefresh && file_exists(CACHE_FILE)) {
    $cacheContent = @file_get_contents(CACHE_FILE);
    if ($cacheContent) {
        $cachedData = json_decode($cacheContent, true);
        if (is_array($cachedData) && isset($cachedData['timestamp']) && ($now - $cachedData['timestamp']) < CACHE_TTL) {
            $cachedData['cached'] = true;
            $cachedData['age_seconds'] = $now - $cachedData['timestamp'];
            echo json_encode($cachedData, JSON_UNESCAPED_UNICODE);
            exit;
        }
    }
}

// 5. Helper Function for HTTP Requests with Timeout
function fetchUrl($url, $headers = [], $postData = null) {
    $ch = curl_init();
    curl_setopt($ch, CURLOPT_URL, $url);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_TIMEOUT, 4);
    curl_setopt($ch, CURLOPT_CONNECTTIMEOUT, 3);
    curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
    curl_setopt($ch, CURLOPT_SSL_VERIFYHOST, false);
    curl_setopt($ch, CURLOPT_USERAGENT, 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36');
    
    if (!empty($headers)) {
        curl_setopt($ch, CURLOPT_HTTPHEADER, $headers);
    }
    if ($postData !== null) {
        curl_setopt($ch, CURLOPT_POST, true);
        curl_setopt($ch, CURLOPT_POSTFIELDS, $postData);
    }
    
    $response = curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);
    
    if ($httpCode === 200 && $response) {
        return $response;
    }
    return null;
}

$rates = [];

// 6. Fetch TSETMC Bourse Indices (TEDPIX, TEDPIX_EQUAL, IFX)
$indices = [
    'TEDPIX' => '32097828799138116',
    'TEDPIX_EQUAL' => '67130298613737946',
    'IFX' => '43685683301327984',
];

foreach ($indices as $sym => $inscode) {
    $raw = fetchUrl("https://cdn.tsetmc.com/api/Index/GetIndexB2/{$inscode}", ['Accept: application/json']);
    if ($raw) {
        $json = json_decode($raw, true);
        $val = isset($json['indexB2']['xNivInIdxPb']) ? $json['indexB2']['xNivInIdxPb'] : (isset($json['indexB2']['xNivInIdx']) ? $json['indexB2']['xNivInIdx'] : null);
        if ($val && floatval($val) > 0) {
            $rates[$sym] = [
                'price' => floatval($val),
                'unit' => 'واحد',
                'source' => 'TSETMC Bourse',
            ];
        }
    }
}

// 7. Fetch TSETMC Gold ETFs (صندوق‌های طلا بورس تهران)
$goldFunds = [
    'AYAR' => '60114064560731671',
    'TALA' => '48624647890698372',
    'ZAR' => '16477146522530182',
    'KAHROBA' => '53070494481084285',
    'GOHAR' => '50428574164177263',
];

foreach ($goldFunds as $sym => $inscode) {
    $raw = fetchUrl("https://cdn.tsetmc.com/api/ClosingPrice/GetClosingPriceInfo/{$inscode}", ['Accept: application/json']);
    if ($raw) {
        $json = json_decode($raw, true);
        $closing = isset($json['closingPriceInfo']['pClosing']) ? $json['closingPriceInfo']['pClosing'] : (isset($json['closingPriceInfo']['pDrCotVal']) ? $json['closingPriceInfo']['pDrCotVal'] : null);
        if ($closing && floatval($closing) > 0) {
            $rates[$sym] = [
                'price' => floatval($closing) / 10.0, // Convert Rial to Toman
                'unit' => 'تومان',
                'source' => 'TSETMC Gold ETF',
            ];
        }
    }
}

// 8. Fetch Nobitex USDT & Gold Rates
$nobitexRaw = fetchUrl("https://apiv2.nobitex.ir/market/stats");
if ($nobitexRaw) {
    $nobiJson = json_decode($nobitexRaw, true);
    if (isset($nobiJson['stats'])) {
        $usdt = isset($nobiJson['stats']['usdt-irt']['latest']) ? $nobiJson['stats']['usdt-irt']['latest'] : null;
        if ($usdt && floatval($usdt) > 0) {
            $rates['USDT_NOBITEX'] = ['price' => floatval($usdt), 'unit' => 'تومان', 'source' => 'Nobitex'];
            $rates['USD_TMN'] = ['price' => floatval($usdt), 'unit' => 'تومان', 'source' => 'Nobitex Tether'];
        }
        $pm = isset($nobiJson['stats']['pm-irt']['latest']) ? $nobiJson['stats']['pm-irt']['latest'] : null;
        if ($pm && floatval($pm) > 0) {
            $rates['GOLD_NOBITEX'] = ['price' => floatval($pm), 'unit' => 'تومان', 'source' => 'Nobitex Gold'];
            $rates['GERAM18'] = ['price' => floatval($pm), 'unit' => 'تومان', 'source' => 'Nobitex Gold 18'];
        }
    }
}

// 9. Fetch Wallex USDT & PAXG Rates
$wallexRaw = fetchUrl("https://api.wallex.ir/v1/markets");
if ($wallexRaw) {
    $wallexJson = json_decode($wallexRaw, true);
    $symbols = isset($wallexJson['result']['symbols']) ? $wallexJson['result']['symbols'] : [];
    if (isset($symbols['USDTTMN']['stats']['lastPrice'])) {
        $rates['USDT_WALLEX'] = ['price' => floatval($symbols['USDTTMN']['stats']['lastPrice']), 'unit' => 'تومان', 'source' => 'Wallex'];
    }
    if (isset($symbols['PAXGTMN']['stats']['lastPrice'])) {
        $rates['GOLD_WALLEX'] = ['price' => floatval($symbols['PAXGTMN']['stats']['lastPrice']), 'unit' => 'تومان', 'source' => 'Wallex'];
    }
}

// 10. Fetch Tetherland Direct USDT Rate
$tetherlandRaw = fetchUrl("https://api.tetherland.com/currencies");
if ($tetherlandRaw) {
    $tlandJson = json_decode($tetherlandRaw, true);
    $tlandPrice = isset($tlandJson['data']['currencies']['USDT']['price']) ? $tlandJson['data']['currencies']['USDT']['price'] : null;
    if ($tlandPrice && floatval($tlandPrice) > 0) {
        $rates['USDT_TETHERLAND'] = ['price' => floatval($tlandPrice), 'unit' => 'تومان', 'source' => 'Tetherland'];
    }
}

// 11. Compile Final JSON Response & Save Cache
$responsePayload = [
    'success' => true,
    'timestamp' => $now,
    'datetime' => date('Y-m-d H:i:s'),
    'cached' => false,
    'source' => 'aegkala_iran_bridge',
    'symbols_count' => count($rates),
    'data' => $rates,
];

@file_put_contents(CACHE_FILE, json_encode($responsePayload, JSON_UNESCAPED_UNICODE));

echo json_encode($responsePayload, JSON_UNESCAPED_UNICODE);
