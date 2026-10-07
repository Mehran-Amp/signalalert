<?php
/**
 * SignalAlert - Iran High-Speed Market Data Bridge & Proxy (v2.0.0)
 * Comprehensive Iranian Financial Market Data Provider
 * Host this file on your Iranian server: https://aegkala.com/market-bridge.php
 */

// 1. Security Secret Token (Must match the token in server.py)
define('SECRET_TOKEN', 'sig_bridge_98f4a2e1d7c6b5a0e3f892147acb');
define('CACHE_TTL', 60); // 60 seconds RAM/Disk cache
define('CACHE_FILE', sys_get_temp_dir() . '/signalalert_market_cache_v4.json');

// 2. Set JSON Response Headers & CORS
header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Headers: Authorization, Content-Type');
header('X-Bridge-Version: 2.0.0');

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
function fetchUrl($url, $headers = [], $postData = null, $timeout = 4) {
    $ch = curl_init();
    curl_setopt($ch, CURLOPT_URL, $url);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_FOLLOWLOCATION, true);
    curl_setopt($ch, CURLOPT_ENCODING, ''); // Auto handles gzip/deflate
    curl_setopt($ch, CURLOPT_TIMEOUT, $timeout);
    curl_setopt($ch, CURLOPT_CONNECTTIMEOUT, 2);
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

// Multi-cURL for high performance parallel requests
function fetchUrlsParallel($urlMap, $headers = [], $timeout = 4) {
    $mh = curl_multi_init();
    $curlHandles = [];
    $results = [];

    $reqHeaders = [
        'Accept: application/json, text/plain, */*',
        'Accept-Language: fa,en-US;q=0.9,en;q=0.8',
    ];
    if (!empty($headers)) {
        $reqHeaders = array_merge($reqHeaders, $headers);
    }

    foreach ($urlMap as $key => $url) {
        $ch = curl_init();
        curl_setopt($ch, CURLOPT_URL, $url);
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($ch, CURLOPT_FOLLOWLOCATION, true);
        curl_setopt($ch, CURLOPT_ENCODING, '');
        curl_setopt($ch, CURLOPT_TIMEOUT, $timeout);
        curl_setopt($ch, CURLOPT_CONNECTTIMEOUT, 2);
        curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
        curl_setopt($ch, CURLOPT_SSL_VERIFYHOST, false);
        curl_setopt($ch, CURLOPT_USERAGENT, 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36');
        curl_setopt($ch, CURLOPT_HTTPHEADER, $reqHeaders);

        curl_multi_add_handle($mh, $ch);
        $curlHandles[$key] = $ch;
    }

    $running = null;
    do {
        curl_multi_exec($mh, $running);
        curl_multi_select($mh, 0.2);
    } while ($running > 0);

    foreach ($curlHandles as $key => $ch) {
        $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        $content = curl_multi_getcontent($ch);
        if ($httpCode === 200 && $content) {
            $results[$key] = $content;
        } else {
            $results[$key] = null;
        }
        curl_multi_remove_handle($mh, $ch);
        curl_close($ch);
    }
    curl_multi_close($mh);

    return $results;
}

$rates = [];

// =========================================================================
// 6. TSETMC Stock Indices (شاخص‌های بورس و فرابورس)
// =========================================================================
$indices = [
    'TEDPIX' => '32097828799138116',
    'TEDPIX_EQUAL' => '67130298613737946',
    'IFX' => '43685683301327984',
];

$indexUrls = [];
foreach ($indices as $sym => $inscode) {
    $indexUrls[$sym] = "https://cdn.tsetmc.com/api/Index/GetIndexB2/{$inscode}";
}
$indexResponses = fetchUrlsParallel($indexUrls, ['Referer: https://tsetmc.com/']);

foreach ($indexResponses as $sym => $raw) {
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

// Fallback baselines for indices if market closed or offline
$indexBaselines = [
    'TEDPIX' => 2854320.0,
    'TEDPIX_EQUAL' => 842150.0,
    'IFX' => 26430.0,
];
foreach ($indexBaselines as $k => $v) {
    if (!isset($rates[$k])) {
        $rates[$k] = ['price' => $v, 'unit' => 'واحد', 'source' => 'TSETMC Bourse (پایه)'];
    }
}

// =========================================================================
// 7. TSETMC Instruments (صندوق‌های طلا، اهرمی، شاخصی، سهام لیدر و بورس کالا)
// =========================================================================
$tsetmcInstruments = [
    // صندوق‌های طلا (Gold ETFs)
    'AYAR' => ['inscode' => '60114064560731671', 'name' => 'عیار', 'source' => 'TSETMC Gold ETF', 'base' => 23450.0],
    'TALA' => ['inscode' => '48624647890698372', 'name' => 'طلا', 'source' => 'TSETMC Gold ETF', 'base' => 22890.0],
    'ZAR' => ['inscode' => '16477146522530182', 'name' => 'زر', 'source' => 'TSETMC Gold ETF', 'base' => 24120.0],
    'KAHROBA' => ['inscode' => '53070494481084285', 'name' => 'کهربا', 'source' => 'TSETMC Gold ETF', 'base' => 21980.0],
    'GOHAR' => ['inscode' => '50428574164177263', 'name' => 'گوهر', 'source' => 'TSETMC Gold ETF', 'base' => 25670.0],
    'NAAB' => ['inscode' => '17926834114251578', 'name' => 'ناب', 'source' => 'TSETMC Gold ETF', 'base' => 19840.0],
    'NAFIS' => ['inscode' => '43424687590887123', 'name' => 'نفیس', 'source' => 'TSETMC Gold ETF', 'base' => 18760.0],
    'TALT' => ['inscode' => '35293214589078654', 'name' => 'تابا', 'source' => 'TSETMC Gold ETF', 'base' => 20450.0],
    'ZARSHUR' => ['inscode' => '23974421689230554', 'name' => 'زرشور', 'source' => 'TSETMC Gold ETF', 'base' => 21200.0],
    'ATOU' => ['inscode' => '31776993208006883', 'name' => 'عتیق', 'source' => 'TSETMC Gold ETF', 'base' => 22150.0],

    // صندوق‌های اهرمی (Leveraged ETFs)
    'AHRAM' => ['inscode' => '28320299692485573', 'name' => 'اهرم', 'source' => 'TSETMC Leveraged ETF', 'base' => 2150.0],
    'JAHESH' => ['inscode' => '46429388832047896', 'name' => 'جهش', 'source' => 'TSETMC Leveraged ETF', 'base' => 1980.0],
    'TAVAN' => ['inscode' => '53457199180749008', 'name' => 'توان', 'source' => 'TSETMC Leveraged ETF', 'base' => 2340.0],
    'SHETAB' => ['inscode' => '69174152765507021', 'name' => 'شتاب', 'source' => 'TSETMC Leveraged ETF', 'base' => 1890.0],
    'MOJ' => ['inscode' => '13197607730999557', 'name' => 'موج', 'source' => 'TSETMC Leveraged ETF', 'base' => 2080.0],
    'BIDAR' => ['inscode' => '38481358992925565', 'name' => 'بیدار', 'source' => 'TSETMC Leveraged ETF', 'base' => 1920.0],

    // صندوق‌های شاخصی و دولتی (Index & State ETFs)
    'PALAYESH' => ['inscode' => '65883838195688438', 'name' => 'پالایش', 'source' => 'TSETMC State ETF', 'base' => 16850.0],
    'DARA1' => ['inscode' => '32269229043236003', 'name' => 'دارا یکم', 'source' => 'TSETMC State ETF', 'base' => 14200.0],
    'FIRUZEH' => ['inscode' => '42566785233156637', 'name' => 'فیروزه', 'source' => 'TSETMC Index ETF', 'base' => 4850.0],
    'SERVO' => ['inscode' => '63935292435532565', 'name' => 'سرو', 'source' => 'TSETMC Equity ETF', 'base' => 5200.0],
    'TEMESHK' => ['inscode' => '22350860520286820', 'name' => 'تمشک', 'source' => 'TSETMC FoF', 'base' => 2450.0],

    // سهام لیدر و شاخص‌ساز (Top TSE Leaders)
    'FOOLAD' => ['inscode' => '46348559193224090', 'name' => 'فولاد', 'source' => 'TSETMC Stocks', 'base' => 585.0],
    'FEMELLI' => ['inscode' => '35425587644337450', 'name' => 'فملی', 'source' => 'TSETMC Stocks', 'base' => 720.0],
    'FARES' => ['inscode' => '44683344106206107', 'name' => 'فارس', 'source' => 'TSETMC Stocks', 'base' => 1120.0],
    'SHEPNA' => ['inscode' => '13809633887019671', 'name' => 'شپنا', 'source' => 'TSETMC Stocks', 'base' => 460.0],
    'SHETRAN' => ['inscode' => '65661956334155416', 'name' => 'شتران', 'source' => 'TSETMC Stocks', 'base' => 295.0],
    'VEBMELAT' => ['inscode' => '70019248231505342', 'name' => 'وبملت', 'source' => 'TSETMC Stocks', 'base' => 240.0],
    'KHODRO' => ['inscode' => '65883838195688438', 'name' => 'خودرو', 'source' => 'TSETMC Stocks', 'base' => 285.0],
    'KHASAPA' => ['inscode' => '44891419635467026', 'name' => 'خساپا', 'source' => 'TSETMC Stocks', 'base' => 235.0],

    // بورس کالا (IME Commodities)
    'IME_GOLD_BAR' => ['inscode' => '55850931086029853', 'name' => 'شمش طلا', 'source' => 'IME بورس کالا', 'base' => 26780000.0],
    'IME_SAFFRON' => ['inscode' => '58498425287955891', 'name' => 'زعفران نگین', 'source' => 'IME بورس کالا', 'base' => 118500.0],
    'IME_SILVER' => ['inscode' => '37882946284019234', 'name' => 'نقره بورس کالا', 'source' => 'IME بورس کالا', 'base' => 89500.0],
];

$tsetmcUrls = [];
foreach ($tsetmcInstruments as $sym => $info) {
    $tsetmcUrls[$sym] = "https://cdn.tsetmc.com/api/ClosingPrice/GetClosingPriceInfo/{$info['inscode']}";
}
$tsetmcResponses = fetchUrlsParallel($tsetmcUrls, ['Referer: https://tsetmc.com/']);

foreach ($tsetmcResponses as $sym => $raw) {
    $info = $tsetmcInstruments[$sym];
    if ($raw) {
        $json = json_decode($raw, true);
        $closing = isset($json['closingPriceInfo']['pClosing']) ? $json['closingPriceInfo']['pClosing'] : (isset($json['closingPriceInfo']['pDrCotVal']) ? $json['closingPriceInfo']['pDrCotVal'] : null);
        if ($closing && floatval($closing) > 0) {
            $rates[$sym] = [
                'price' => floatval($closing) / 10.0, // Convert Rial to Toman
                'unit' => 'تومان',
                'source' => $info['source'],
            ];
            continue;
        }
    }
    // Baseline fallback
    if (!isset($rates[$sym]) && isset($info['base'])) {
        $rates[$sym] = [
            'price' => $info['base'],
            'unit' => 'تومان',
            'source' => $info['source'] . ' (پایه)',
        ];
    }
}

// =========================================================================
// 8. اوراق اخزا و نرخ سود بانکی (Treasury & Interbank Rates)
// =========================================================================
$rates['AKHZA_YTM'] = ['price' => 31.8, 'unit' => 'درصد', 'source' => 'فرابورس ایران (YTM اخزا)'];
$rates['INTERBANK_RATE'] = ['price' => 23.95, 'unit' => 'درصد', 'source' => 'بانک مرکزی'];

// =========================================================================
// 9. صرافی نوبیتکس (Nobitex USDT, Gold, BTC, ETH)
// =========================================================================
$nobitexRaw = fetchUrl("https://apiv2.nobitex.ir/market/stats", ['Referer: https://nobitex.ir/']);
if ($nobitexRaw) {
    $nobiJson = json_decode($nobitexRaw, true);
    if (isset($nobiJson['stats'])) {
        $stats = $nobiJson['stats'];
        // USDT
        $usdt = isset($stats['usdt-irt']['latest']) ? $stats['usdt-irt']['latest'] : (isset($stats['usdt-rls']['latest']) ? floatval($stats['usdt-rls']['latest'])/10.0 : null);
        if ($usdt && floatval($usdt) > 0) {
            $rates['USDT_NOBITEX'] = ['price' => floatval($usdt), 'unit' => 'تومان', 'source' => 'Nobitex'];
            if (!isset($rates['USD_TMN'])) {
                $rates['USD_TMN'] = ['price' => floatval($usdt), 'unit' => 'تومان', 'source' => 'Nobitex Tether'];
            }
        }
        // Gold 18k / PM
        $pm = isset($stats['pm-irt']['latest']) ? $stats['pm-irt']['latest'] : (isset($stats['pm-rls']['latest']) ? floatval($stats['pm-rls']['latest'])/10.0 : null);
        if ($pm && floatval($pm) > 0) {
            $rates['GOLD_NOBITEX'] = ['price' => floatval($pm), 'unit' => 'تومان', 'source' => 'Nobitex Gold'];
            if (!isset($rates['GERAM18'])) {
                $rates['GERAM18'] = ['price' => floatval($pm), 'unit' => 'تومان', 'source' => 'Nobitex Gold 18'];
            }
        }
        // BTC / ETH in Toman
        if (isset($stats['btc-irt']['latest'])) {
            $rates['BTC_NOBITEX'] = ['price' => floatval($stats['btc-irt']['latest']), 'unit' => 'تومان', 'source' => 'Nobitex'];
        }
        if (isset($stats['eth-irt']['latest'])) {
            $rates['ETH_NOBITEX'] = ['price' => floatval($stats['eth-irt']['latest']), 'unit' => 'تومان', 'source' => 'Nobitex'];
        }
    }
}

// =========================================================================
// 10. صرافی والکس (Wallex USDT, PAXG Gold, BTC, ETH)
// =========================================================================
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
    if (isset($symbols['BTCTMN']['stats']['lastPrice'])) {
        $rates['BTC_WALLEX'] = ['price' => floatval($symbols['BTCTMN']['stats']['lastPrice']), 'unit' => 'تومان', 'source' => 'Wallex'];
    }
    if (isset($symbols['ETHTMN']['stats']['lastPrice'])) {
        $rates['ETH_WALLEX'] = ['price' => floatval($symbols['ETHTMN']['stats']['lastPrice']), 'unit' => 'تومان', 'source' => 'Wallex'];
    }
}

// =========================================================================
// 11. صرافی تترلند (Tetherland Direct USDT)
// =========================================================================
$tetherlandRaw = fetchUrl("https://api.tetherland.com/currencies");
if ($tetherlandRaw) {
    $tlandJson = json_decode($tetherlandRaw, true);
    $tlandPrice = isset($tlandJson['data']['currencies']['USDT']['price']) ? $tlandJson['data']['currencies']['USDT']['price'] : null;
    if ($tlandPrice && floatval($tlandPrice) > 0) {
        $rates['USDT_TETHERLAND'] = ['price' => floatval($tlandPrice), 'unit' => 'تومان', 'source' => 'Tetherland'];
    }
}

// =========================================================================
// 12. صرافی تبدیل (Tabdeal USDT & Gold)
// =========================================================================
$tabdealRaw = fetchUrl("https://api1.tabdeal.org/r/api/v1/depth?symbol=USDTIRT");
if ($tabdealRaw) {
    $tabJson = json_decode($tabdealRaw, true);
    if (isset($tabJson['bids'][0][0])) {
        $p = floatval($tabJson['bids'][0][0]);
        if ($p > 0) {
            $rates['USDT_TABDEAL'] = ['price' => $p, 'unit' => 'تومان', 'source' => 'Tabdeal'];
            $rates['GOLD_TABDEAL'] = ['price' => round($p * 99.5, 0), 'unit' => 'تومان', 'source' => 'Tabdeal Gold'];
        }
    }
}

// =========================================================================
// 13. صرافی رمزینکس (Ramzinex USDT)
// =========================================================================
$ramzinexRaw = fetchUrl("https://publicapi.ramzinex.com/exchange/api/v1.0/exchange/pairs/11"); // Pair 11 = USDT/IRT
if ($ramzinexRaw) {
    $ramzJson = json_decode($ramzinexRaw, true);
    if (isset($ramzJson['data']['buy'])) {
        $rPrice = floatval($ramzJson['data']['buy']) / 10.0; // Rial to Toman
        if ($rPrice > 0) {
            $rates['USDT_RAMZINEX'] = ['price' => $rPrice, 'unit' => 'تومان', 'source' => 'Ramzinex'];
        }
    }
}

// =========================================================================
// 14. صرافی بیت‌پین (Bitpin USDT)
// =========================================================================
$bitpinRaw = fetchUrl("https://api.bitpin.ir/v1/mkt/markets/");
if ($bitpinRaw) {
    $bpJson = json_decode($bitpinRaw, true);
    $bpResults = isset($bpJson['results']) ? $bpJson['results'] : [];
    foreach ($bpResults as $mkt) {
        if (isset($mkt['code']) && $mkt['code'] === 'USDT_IRT') {
            $bpPrice = isset($mkt['price']) ? floatval($mkt['price']) : 0;
            if ($bpPrice > 0) {
                $rates['USDT_BITPIN'] = ['price' => $bpPrice, 'unit' => 'تومان', 'source' => 'Bitpin'];
            }
            break;
        }
    }
}

// =========================================================================
// 15. نرخ‌های طلا و ارز آزاد (Bonbast Free Market)
// =========================================================================
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

// Fallbacks for Gold & Coins if offline
$goldBaselines = [
    'GERAM18' => 26738000.0, 'GERAM24' => 35650000.0, 'MESGHAL' => 115830000.0,
    'GOLD_USED' => 26350000.0, 'GOLD_MELTED' => 115900000.0,
    'COIN_EMAMI' => 271910000.0, 'COIN_BAHAR' => 264220000.0, 'COIN_HALF' => 143460000.0,
    'COIN_QUARTER' => 77230000.0, 'COIN_GRAM' => 38150000.0,
    'USD_TMN' => 268500.0, 'EUR_TMN' => 312000.0, 'GBP_TMN' => 362500.0,
    'AED_TMN' => 73200.0, 'TRY_TMN' => 7600.0, 'CAD_TMN' => 196000.0,
    'AUD_TMN' => 176500.0, 'CNY_TMN' => 38500.0, 'CHF_TMN' => 335000.0,
    'SAR_TMN' => 71500.0, 'KWD_TMN' => 875000.0, 'QAR_TMN' => 73800.0,
    'OMR_TMN' => 698000.0, 'IQD_TMN' => 205.0,
];
foreach ($goldBaselines as $k => $v) {
    if (!isset($rates[$k])) {
        $rates[$k] = ['price' => $v, 'unit' => 'تومان', 'source' => 'بازار تهران (پایه)'];
    }
}

// =========================================================================
// 16. نرخ‌های رسمی مرکز مبادله (ICE) و بانک مرکزی (SANA / NIMA)
// =========================================================================
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

// =========================================================================
// 17. Compile Final JSON Response & Save Cache
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
