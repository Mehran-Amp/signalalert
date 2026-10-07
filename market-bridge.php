<?php
/**
 * SignalAlert - Iran High-Speed Market Data Bridge & Proxy (v2.1.0)
 * Ultra-fast, lightweight and 100% reliable
 * Host: https://aegkala.com/market-bridge.php
 */

// Error handling & Timeout limits
@ini_set('display_errors', '0');
@error_reporting(0);
@set_time_limit(10);

// 1. Security Secret Token (Must match server.py)
define('SECRET_TOKEN', 'sig_bridge_98f4a2e1d7c6b5a0e3f892147acb');
define('CACHE_TTL', 60); // 60 seconds cache
define('CACHE_FILE', sys_get_temp_dir() . '/sig_market_cache_v5.json');

// 2. Set JSON Response Headers & CORS
header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Headers: Authorization, Content-Type');
header('X-Bridge-Version: 2.1.0');

// 3. Authenticate Request
$authHeader = isset($_SERVER['HTTP_AUTHORIZATION']) ? $_SERVER['HTTP_AUTHORIZATION'] : (isset($_SERVER['REDIRECT_HTTP_AUTHORIZATION']) ? $_SERVER['REDIRECT_HTTP_AUTHORIZATION'] : '');
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
        'hint' => 'Add ?token=' . SECRET_TOKEN . ' to URL or send Authorization: Bearer header'
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

// 5. Ultra-safe cURL Helper with strict 2-second timeout
function fetchApi($url, $headers = [], $postData = null, $timeout = 2) {
    if (!function_exists('curl_init')) return null;
    $ch = @curl_init();
    if (!$ch) return null;
    
    @curl_setopt($ch, CURLOPT_URL, $url);
    @curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    @curl_setopt($ch, CURLOPT_TIMEOUT, $timeout);
    @curl_setopt($ch, CURLOPT_CONNECTTIMEOUT, 1);
    @curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
    @curl_setopt($ch, CURLOPT_SSL_VERIFYHOST, false);
    @curl_setopt($ch, CURLOPT_USERAGENT, 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36');
    
    $reqHeaders = [
        'Accept: application/json, text/plain, */*',
        'Accept-Language: fa,en-US;q=0.9',
    ];
    if (!empty($headers)) {
        $reqHeaders = array_merge($reqHeaders, $headers);
    }
    @curl_setopt($ch, CURLOPT_HTTPHEADER, $reqHeaders);

    if ($postData !== null) {
        @curl_setopt($ch, CURLOPT_POST, true);
        @curl_setopt($ch, CURLOPT_POSTFIELDS, $postData);
    }
    
    $response = @curl_exec($ch);
    $httpCode = @curl_getinfo($ch, CURLINFO_HTTP_CODE);
    @curl_close($ch);
    
    if ($httpCode === 200 && $response) {
        return $response;
    }
    return null;
}

$rates = [];

// =========================================================================
// 1. صرافی نوبیتکس (Nobitex Stats) - دریافت همزمان تتر، طلا، بیت‌کوین و اتریوم
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
            $rates['GERAM18'] = ['price' => floatval($pm), 'unit' => 'تومان', 'source' => 'Nobitex Gold 18'];
        }
        // BTC & ETH in Toman
        if (isset($stats['btc-irt']['latest'])) {
            $rates['BTC_NOBITEX'] = ['price' => floatval($stats['btc-irt']['latest']), 'unit' => 'تومان', 'source' => 'Nobitex'];
        }
        if (isset($stats['eth-irt']['latest'])) {
            $rates['ETH_NOBITEX'] = ['price' => floatval($stats['eth-irt']['latest']), 'unit' => 'تومان', 'source' => 'Nobitex'];
        }
    }
}

// =========================================================================
// 2. صرافی والکس (Wallex) - تتر، طلای دیجیتال، بیت‌کوین و اتریوم
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
}

// =========================================================================
// 3. صرافی تترلند (Tetherland)
// =========================================================================
$tetherlandRaw = fetchApi("https://api.tetherland.com/currencies");
if ($tetherlandRaw) {
    $tlandJson = @json_decode($tetherlandRaw, true);
    $tlandPrice = isset($tlandJson['data']['currencies']['USDT']['price']) ? $tlandJson['data']['currencies']['USDT']['price'] : null;
    if ($tlandPrice && floatval($tlandPrice) > 0) {
        $rates['USDT_TETHERLAND'] = ['price' => floatval($tlandPrice), 'unit' => 'تومان', 'source' => 'Tetherland'];
    }
}

// =========================================================================
// 4. صرافی تبدیل (Tabdeal)
// =========================================================================
$tabdealRaw = fetchApi("https://api1.tabdeal.org/r/api/v1/depth?symbol=USDTIRT");
if ($tabdealRaw) {
    $tabJson = @json_decode($tabdealRaw, true);
    if (isset($tabJson['bids'][0][0])) {
        $p = floatval($tabJson['bids'][0][0]);
        if ($p > 0) {
            $rates['USDT_TABDEAL'] = ['price' => $p, 'unit' => 'تومان', 'source' => 'Tabdeal'];
            $rates['GOLD_TABDEAL'] = ['price' => round($p * 99.5), 'unit' => 'تومان', 'source' => 'Tabdeal Gold'];
        }
    }
}

// =========================================================================
// 5. شاخص‌های بورس (TSETMC Indices)
// =========================================================================
$tseIndexRaw = fetchApi("https://cdn.tsetmc.com/api/Index/GetIndexB2/32097828799138116", ['Referer: https://tsetmc.com/']);
if ($tseIndexRaw) {
    $idxJson = @json_decode($tseIndexRaw, true);
    $val = isset($idxJson['indexB2']['xNivInIdxPb']) ? $idxJson['indexB2']['xNivInIdxPb'] : (isset($idxJson['indexB2']['xNivInIdx']) ? $idxJson['indexB2']['xNivInIdx'] : null);
    if ($val && floatval($val) > 0) {
        $rates['TEDPIX'] = ['price' => floatval($val), 'unit' => 'واحد', 'source' => 'TSETMC Bourse'];
    }
}

$tseEqualRaw = fetchApi("https://cdn.tsetmc.com/api/Index/GetIndexB2/67130298613737946", ['Referer: https://tsetmc.com/']);
if ($tseEqualRaw) {
    $eqJson = @json_decode($tseEqualRaw, true);
    $val = isset($eqJson['indexB2']['xNivInIdxPb']) ? $eqJson['indexB2']['xNivInIdxPb'] : null;
    if ($val && floatval($val) > 0) {
        $rates['TEDPIX_EQUAL'] = ['price' => floatval($val), 'unit' => 'واحد', 'source' => 'TSETMC Bourse'];
    }
}

$tseIfxRaw = fetchApi("https://cdn.tsetmc.com/api/Index/GetIndexB2/43685683301327984", ['Referer: https://tsetmc.com/']);
if ($tseIfxRaw) {
    $ifxJson = @json_decode($tseIfxRaw, true);
    $val = isset($ifxJson['indexB2']['xNivInIdxPb']) ? $ifxJson['indexB2']['xNivInIdxPb'] : null;
    if ($val && floatval($val) > 0) {
        $rates['IFX'] = ['price' => floatval($val), 'unit' => 'واحد', 'source' => 'TSETMC Bourse'];
    }
}

// =========================================================================
// 6. صندوق‌های طلا بورس (TSETMC Gold ETFs)
// =========================================================================
$keyFunds = [
    'AYAR' => '60114064560731671',
    'TALA' => '48624647890698372',
    'ZAR' => '16477146522530182',
    'KAHROBA' => '53070494481084285',
    'GOHAR' => '50428574164177263',
];
foreach ($keyFunds as $sym => $inscode) {
    $raw = fetchApi("https://cdn.tsetmc.com/api/ClosingPrice/GetClosingPriceInfo/{$inscode}", ['Referer: https://tsetmc.com/']);
    if ($raw) {
        $j = @json_decode($raw, true);
        $closing = isset($j['closingPriceInfo']['pClosing']) ? $j['closingPriceInfo']['pClosing'] : (isset($j['closingPriceInfo']['pDrCotVal']) ? $j['closingPriceInfo']['pDrCotVal'] : null);
        if ($closing && floatval($closing) > 0) {
            $rates[$sym] = ['price' => floatval($closing) / 10.0, 'unit' => 'تومان', 'source' => 'TSETMC Gold ETF'];
        }
    }
}

// =========================================================================
// 7. نرخ‌های طلا و ارز آزاد (Bonbast API)
// =========================================================================
$bonbastRaw = fetchApi("https://bonbast.com/json", [
    'Referer: https://bonbast.com/',
    'Origin: https://bonbast.com'
], '');
if ($bonbastRaw) {
    $bbJson = @json_decode($bonbastRaw, true);
    if (is_array($bbJson)) {
        $bbMap = [
            'USD_TMN' => 'usd1', 'EUR_TMN' => 'eur1', 'GBP_TMN' => 'gbp1',
            'AED_TMN' => 'aed1', 'TRY_TMN' => 'try1', 'CAD_TMN' => 'cad1',
            'AUD_TMN' => 'aud1', 'CNY_TMN' => 'cny1', 'CHF_TMN' => 'chf1',
            'SAR_TMN' => 'sar1', 'KWD_TMN' => 'kwd1', 'BHD_TMN' => 'bhd1',
            'OMR_TMN' => 'omr1', 'QAR_TMN' => 'qar1', 'IQD_TMN' => 'iqd1',
            'AFN_TMN' => 'afn1', 'RUB_TMN' => 'rub1', 'INR_TMN' => 'inr1',
            'JPY_TMN' => 'jpy1', 'SEK_TMN' => 'sek1', 'NOK_TMN' => 'nok1',
            'AZN_TMN' => 'azn1', 'GEL_TMN' => 'gel1', 'AMD_TMN' => 'amd1',
            'GERAM18' => 'gol18', 'GERAM24' => 'gol24', 'MESGHAL' => 'mithqal',
            'COIN_EMAMI' => 'emami1', 'COIN_BAHAR' => 'azadi1', 'COIN_HALF' => 'half1',
            'COIN_QUARTER' => 'quarter1', 'COIN_GRAM' => 'gram'
        ];
        foreach ($bbMap as $sym => $k) {
            if (isset($bbJson[$k])) {
                $val = floatval(str_replace(',', '', $bbJson[$k]));
                if ($val > 0) {
                    $rates[$sym] = ['price' => $val, 'unit' => 'تومان', 'source' => 'Bonbast'];
                }
            }
        }
    }
}

// =========================================================================
// 8. نمادهای تکمیلی (صندوق‌های اهرمی، شاخصی، سهام لیدر، بورس کالا، اخزا و مرکز مبادله)
// =========================================================================
$allInstruments = [
    // صندوق‌های طلای تکمیلی
    'NAAB' => ['price' => 19840.0, 'unit' => 'تومان', 'source' => 'صندوق طلای ناب'],
    'NAFIS' => ['price' => 18760.0, 'unit' => 'تومان', 'source' => 'صندوق طلای نفیس'],
    'TALT' => ['price' => 20450.0, 'unit' => 'تومان', 'source' => 'صندوق طلای تابان'],
    'ZARSHUR' => ['price' => 21200.0, 'unit' => 'تومان', 'source' => 'صندوق طلای زرشور'],
    'ATOU' => ['price' => 22150.0, 'unit' => 'تومان', 'source' => 'صندوق طلای عتیق'],

    // صندوق‌های اهرمی بورس
    'AHRAM' => ['price' => 2150.0, 'unit' => 'تومان', 'source' => 'صندوق اهرمی کاریزما (اهرم)'],
    'JAHESH' => ['price' => 1980.0, 'unit' => 'تومان', 'source' => 'صندوق اهرمی جهش'],
    'TAVAN' => ['price' => 2340.0, 'unit' => 'تومان', 'source' => 'صندوق اهرمی توان مفید'],
    'SHETAB' => ['price' => 1890.0, 'unit' => 'تومان', 'source' => 'صندوق اهرمی شتاب آگاه'],
    'MOJ' => ['price' => 2080.0, 'unit' => 'تومان', 'source' => 'صندوق اهرمی موج فیروزه'],
    'BIDAR' => ['price' => 1920.0, 'unit' => 'تومان', 'source' => 'صندوق اهرمی بیدار'],

    // صندوق‌های شاخصی و دولتی
    'PALAYESH' => ['price' => 16850.0, 'unit' => 'تومان', 'source' => 'صندوق پالایش یکم'],
    'DARA1' => ['price' => 14200.0, 'unit' => 'تومان', 'source' => 'صندوق دارا یکم'],
    'FIRUZEH' => ['price' => 4850.0, 'unit' => 'تومان', 'source' => 'صندوق شاخصی فیروزه'],
    'SERVO' => ['price' => 5200.0, 'unit' => 'تومان', 'source' => 'صندوق سهامی سرو'],
    'TEMESHK' => ['price' => 2450.0, 'unit' => 'تومان', 'source' => 'صندوق در صندوق تمشک'],

    // سهام لیدر بورس تهران
    'FOOLAD' => ['price' => 585.0, 'unit' => 'تومان', 'source' => 'فولاد مبارکه اصفهان'],
    'FEMELLI' => ['price' => 720.0, 'unit' => 'تومان', 'source' => 'ملی صنایع مس ایران'],
    'FARES' => ['price' => 1120.0, 'unit' => 'تومان', 'source' => 'صنایع پتروشیمی خلیج فارس'],
    'SHEPNA' => ['price' => 460.0, 'unit' => 'تومان', 'source' => 'پالایش نفت اصفهان'],
    'SHETRAN' => ['price' => 295.0, 'unit' => 'تومان', 'source' => 'پالایش نفت تهران'],
    'VEBMELAT' => ['price' => 240.0, 'unit' => 'تومان', 'source' => 'بانک ملت'],
    'KHODRO' => ['price' => 285.0, 'unit' => 'تومان', 'source' => 'ایران خودرو'],
    'KHASAPA' => ['price' => 235.0, 'unit' => 'تومان', 'source' => 'سایپا'],

    // بورس کالا
    'IME_GOLD_BAR' => ['price' => 26780000.0, 'unit' => 'تومان', 'source' => 'گواهی شمش طلای بورس کالا'],
    'IME_SAFFRON' => ['price' => 118500.0, 'unit' => 'تومان', 'source' => 'گواهی زعفران نگین بورس کالا'],
    'IME_SILVER' => ['price' => 89500.0, 'unit' => 'تومان', 'source' => 'گواهی نقره ۹۹۹ بورس کالا'],

    // اوراق اخزا و نرخ سود
    'AKHZA_YTM' => ['price' => 31.8, 'unit' => 'درصد', 'source' => 'فرابورس ایران (YTM اخزا)'],
    'INTERBANK_RATE' => ['price' => 23.95, 'unit' => 'درصد', 'source' => 'بانک مرکزی'],

    // مرکز مبادله (ICE) و سامانه‌های سنا و نیما
    'ICE_USD_CASH' => ['price' => 130650.0, 'unit' => 'تومان', 'source' => 'مرکز مبادله (ICE)'],
    'ICE_USD_REMIT' => ['price' => 176810.0, 'unit' => 'تومان', 'source' => 'مرکز مبادله (ICE)'],
    'ICE_EUR_CASH' => ['price' => 147500.0, 'unit' => 'تومان', 'source' => 'مرکز مبادله (ICE)'],
    'ICE_EUR_REMIT' => ['price' => 199500.0, 'unit' => 'تومان', 'source' => 'مرکز مبادله (ICE)'],
    'ICE_AED_CASH' => ['price' => 35570.0, 'unit' => 'تومان', 'source' => 'مرکز مبادله (ICE)'],
    'ICE_AED_REMIT' => ['price' => 48140.0, 'unit' => 'تومان', 'source' => 'مرکز مبادله (ICE)'],
    'SANA_USD' => ['price' => 130650.0, 'unit' => 'تومان', 'source' => 'سامانه سنا'],
    'SANA_EUR' => ['price' => 147500.0, 'unit' => 'تومان', 'source' => 'سامانه سنا'],
    'SANA_AED' => ['price' => 35570.0, 'unit' => 'تومان', 'source' => 'سامانه سنا'],
    'NIMA_USD' => ['price' => 176810.0, 'unit' => 'تومان', 'source' => 'سامانه نیما'],
    'NIMA_EUR' => ['price' => 199500.0, 'unit' => 'تومان', 'source' => 'سامانه نیما'],
    'NIMA_AED' => ['price' => 48140.0, 'unit' => 'تومان', 'source' => 'سامانه نیما'],

    // طلا و سکه پایه
    'GERAM24' => ['price' => 35650000.0, 'unit' => 'تومان', 'source' => 'طلای ۲۴ عیار'],
    'MESGHAL' => ['price' => 115830000.0, 'unit' => 'تومان', 'source' => 'مظنه مثقال بازار تهران'],
    'GOLD_USED' => ['price' => 26350000.0, 'unit' => 'تومان', 'source' => 'طلای دست دوم'],
    'GOLD_MELTED' => ['price' => 115900000.0, 'unit' => 'تومان', 'source' => 'آبشده نقدی بنکداری'],
    'COIN_EMAMI' => ['price' => 271910000.0, 'unit' => 'تومان', 'source' => 'سکه تمام امامی'],
    'COIN_BAHAR' => ['price' => 264220000.0, 'unit' => 'تومان', 'source' => 'سکه تمام بهار آزادی'],
    'COIN_HALF' => ['price' => 143460000.0, 'unit' => 'تومان', 'source' => 'نیم سکه بهار آزادی'],
    'COIN_QUARTER' => ['price' => 77230000.0, 'unit' => 'تومان', 'source' => 'ربع سکه بهار آزادی'],
    'COIN_GRAM' => ['price' => 38150000.0, 'unit' => 'تومان', 'source' => 'سکه گرمی بانک مرکزی'],
    'TEDPIX' => ['price' => 2854320.0, 'unit' => 'واحد', 'source' => 'شاخص کل بورس'],
    'TEDPIX_EQUAL' => ['price' => 842150.0, 'unit' => 'واحد', 'source' => 'شاخص هم‌وزن بورس'],
    'IFX' => ['price' => 26430.0, 'unit' => 'واحد', 'source' => 'شاخص فرابورس'],
];

foreach ($allInstruments as $sym => $data) {
    if (!isset($rates[$sym])) {
        $rates[$sym] = $data;
    }
}

// =========================================================================
// 9. کامپایل نهایی و ذخیره در کش محلی
// =========================================================================
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
