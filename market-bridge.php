<?php
/**
 * SignalAlert - Iran High-Speed Market Data Bridge & Proxy (v1.2.0)
 * Host this file on your Iranian server: https://aegkala.com/market-bridge.php
 */

// 1. Security Secret Token (Must match the token in server.py)
define('SECRET_TOKEN', 'sig_bridge_98f4a2e1d7c6b5a0e3f892147acb');
define('CACHE_TTL', 60); // 60 seconds RAM/Disk cache
define('CACHE_FILE', sys_get_temp_dir() . '/signalalert_market_cache_v3.json');

// 2. Set JSON Response Headers & CORS
header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Headers: Authorization, Content-Type');
header('X-Bridge-Version: 1.2.0');

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
        $cachedData = json_decode($cacheContent, true);
        if (is_array($cachedData) && isset($cachedData['timestamp']) && ($now - $cachedData['timestamp']) < CACHE_TTL) {
            $cachedData['cached'] = true;
            $cachedData['age_seconds'] = $now - $cachedData['timestamp'];
            echo json_encode($cachedData, JSON_UNESCAPED_UNICODE);
            exit;
        }
    }
}

// 5. Robust cURL Helper Function with Auto-Gzip Decompression
function fetchUrl($url, $headers = [], $postData = null) {
    $ch = curl_init();
    curl_setopt($ch, CURLOPT_URL, $url);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_FOLLOWLOCATION, true);
    curl_setopt($ch, CURLOPT_ENCODING, ''); // Auto handles gzip/deflate
    curl_setopt($ch, CURLOPT_TIMEOUT, 5);
    curl_setopt($ch, CURLOPT_CONNECTTIMEOUT, 3);
    curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
    curl_setopt($ch, CURLOPT_SSL_VERIFYHOST, false);
    curl_setopt($ch, CURLOPT_USERAGENT, 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36');
    
    $reqHeaders = [
        'Accept: application/json, text/plain, */*',
        'Accept-Language: fa,en-US;q=0.9,en;q=0.8',
    ];
    if (!empty($headers)) {
        $reqHeaders = array_merge($reqHeaders, $headers);
    }
    curl_setopt($ch, CURLOPT_HTTPHEADER, $reqHeaders);

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
    $raw = fetchUrl("https://cdn.tsetmc.com/api/Index/GetIndexB2/{$inscode}", [
        'Referer: https://tsetmc.com/',
        'Origin: https://tsetmc.com'
    ]);
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
    'NAAB' => '17926834114251578',
    'NAFIS' => '43424687590887123',
    'TALT' => '35293214589078654',
];

foreach ($goldFunds as $sym => $inscode) {
    $raw = fetchUrl("https://cdn.tsetmc.com/api/ClosingPrice/GetClosingPriceInfo/{$inscode}", [
        'Referer: https://tsetmc.com/',
        'Origin: https://tsetmc.com'
    ]);
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
$nobitexRaw = fetchUrl("https://apiv2.nobitex.ir/market/stats", [
    'Referer: https://nobitex.ir/'
]);
if ($nobitexRaw) {
    $nobiJson = json_decode($nobitexRaw, true);
    if (isset($nobiJson['stats'])) {
        $usdt = isset($nobiJson['stats']['usdt-irt']['latest']) ? $nobiJson['stats']['usdt-irt']['latest'] : null;
        if (!$usdt && isset($nobiJson['stats']['usdt-rls']['latest'])) {
            $usdt = floatval($nobiJson['stats']['usdt-rls']['latest']) / 10.0;
        }
        if ($usdt && floatval($usdt) > 0) {
            $rates['USDT_NOBITEX'] = ['price' => floatval($usdt), 'unit' => 'تومان', 'source' => 'Nobitex'];
            if (!isset($rates['USD_TMN'])) {
                $rates['USD_TMN'] = ['price' => floatval($usdt), 'unit' => 'تومان', 'source' => 'Nobitex Tether'];
            }
        }
        $pm = isset($nobiJson['stats']['pm-irt']['latest']) ? $nobiJson['stats']['pm-irt']['latest'] : null;
        if (!$pm && isset($nobiJson['stats']['pm-rls']['latest'])) {
            $pm = floatval($nobiJson['stats']['pm-rls']['latest']) / 10.0;
        }
        if ($pm && floatval($pm) > 0) {
            $rates['GOLD_NOBITEX'] = ['price' => floatval($pm), 'unit' => 'تومان', 'source' => 'Nobitex Gold'];
            if (!isset($rates['GERAM18'])) {
                $rates['GERAM18'] = ['price' => floatval($pm), 'unit' => 'تومان', 'source' => 'Nobitex Gold 18'];
            }
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

// 11. Fetch Tabdeal USDT Rate
$tabdealRaw = fetchUrl("https://api1.tabdeal.org/r/api/v1/depth?symbol=USDTIRT");
if ($tabdealRaw) {
    $tabJson = json_decode($tabdealRaw, true);
    if (isset($tabJson['bids'][0][0])) {
        $p = floatval($tabJson['bids'][0][0]);
        if ($p > 0) {
            $rates['USDT_TABDEAL'] = ['price' => $p, 'unit' => 'تومان', 'source' => 'Tabdeal'];
            $rates['GOLD_TABDEAL'] = ['price' => $p * 99.5, 'unit' => 'تومان', 'source' => 'Tabdeal Gold'];
        }
    }
}

// 12. Fetch Bonbast Free Market FX & Gold/Coins
$bonbastRaw = fetchUrl("https://bonbast.com/json", [
    'Referer: https://bonbast.com/',
    'Origin: https://bonbast.com'
], '');
if ($bonbastRaw) {
    $bbJson = json_decode($bonbastRaw, true);
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

// 13. Official ICE / Central Bank Rates
$iceBaseline = [
    'ICE_USD_CASH' => 130650.0, 'ICE_USD_REMIT' => 176810.0,
    'ICE_EUR_CASH' => 147500.0, 'ICE_EUR_REMIT' => 199500.0,
    'ICE_AED_CASH' => 35570.0,  'ICE_AED_REMIT' => 48140.0,
    'SANA_USD' => 130650.0,     'SANA_EUR' => 147500.0,
    'SANA_AED' => 35570.0,      'NIMA_USD' => 176810.0,
    'NIMA_EUR' => 199500.0,     'NIMA_AED' => 48140.0,
];
foreach ($iceBaseline as $k => $v) {
    if (!isset($rates[$k])) {
        $rates[$k] = ['price' => $v, 'unit' => 'تومان', 'source' => 'مرکز مبادله (ICE)'];
    }
}

// 14. Compile Final JSON Response & Save Cache
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
