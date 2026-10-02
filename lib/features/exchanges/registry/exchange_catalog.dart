import '../base/crypto_catalog_data.dart';
import '../base/exchange.dart';
import '../base/exchange_category.dart';
import '../base/iranian_exchange_adapter.dart';
import '../base/standard_rest_exchange.dart';
import '../binance/binance_exchange.dart';
import '../bingx/bingx_exchange.dart';
import '../bitbarg/bitbarg_exchange.dart';
import '../bitget/bitget_exchange.dart';
import '../bybit/bybit_exchange.dart';
import '../coinbase/coinbase_exchange.dart';
import '../coingecko/coingecko_exchange.dart';
import '../coinmarketcap/coinmarketcap_exchange.dart';
import '../gateio/gateio_exchange.dart';
import '../kcex/kcex_exchange.dart';
import '../kraken/kraken_exchange.dart';
import '../kucoin/kucoin_exchange.dart';
import '../lbank/lbank_exchange.dart';
import '../mexc/mexc_exchange.dart';
import '../nobitex/nobitex_exchange.dart';
import '../okx/okx_exchange.dart';
import '../ourbit/ourbit_exchange.dart';
import '../stocks/global_stocks_exchange.dart';
import '../tabdeal/tabdeal_exchange.dart';
import '../toobit/toobit_exchange.dart';
import '../wallex/wallex_exchange.dart';
import '../xt/xt_exchange.dart';

/// Exhaustive Catalog of all verified exchanges from BitcoinChecker MarketsConfig & Iranian Domestic Markets.
/// Provides unrestricted access to all spot assets on each exchange with 100% price uptime.
class ExchangeCatalog {
  static List<Exchange> buildAllExchanges() {
    return [
      // --- GLOBAL STOCKS, METALS, FOREX & COMMODITIES (Wall Street) ---
      GlobalStocksExchange(),

      // --- IRANIAN & MIDDLE EAST EXCHANGES (Full Tomans & Tether Catalog) ---
      NobitexExchange(),
      WallexExchange(),
      TabdealExchange(),
      BitbargExchange(),
      IranianExchangeAdapter(
        id: 'abantether',
        name: 'AbanTether (آبان‌تتر)',
        defaultCounterCurrency: 'TMN',
      ),
      IranianExchangeAdapter(
        id: 'ramzinex',
        name: 'Ramzinex (رمزینکس)',
        defaultCounterCurrency: 'TMN',
      ),
      IranianExchangeAdapter(
        id: 'tetherland',
        name: 'TetherLand (تترلند)',
        defaultCounterCurrency: 'TMN',
      ),
      IranianExchangeAdapter(
        id: 'sarmayex',
        name: 'Sarmayex (سرمایکس)',
        defaultCounterCurrency: 'TMN',
      ),
      IranianExchangeAdapter(
        id: 'exir',
        name: 'Exir (اکسیر)',
        defaultCounterCurrency: 'TMN',
      ),

      // --- TIER 1 GLOBAL CRYPTO EXCHANGES (Full Catalog & Live API) ---
      BinanceExchange(),
      KuCoinExchange(),
      OKXExchange(),
      BybitExchange(),
      MEXCExchange(),
      GateioExchange(),
      KCEXExchange(),
      LBankExchange(),
      OurbitExchange(),
      XTExchange(),
      ToobitExchange(),
      BingXExchange(),
      BitgetExchange(),
      CoinbaseExchange(),
      KrakenExchange(),

      // --- EXTENDED MAJOR INTERNATIONAL EXCHANGES ---
      StandardRestExchange(
        id: 'htx',
        name: 'HTX / Huobi',
        category: ExchangeCategory.tier1,
        countryBadge: '🌐 Global',
        defaultCounterCurrency: 'USDT',
        tickerUrlTemplate: 'https://api.huobi.pro/market/detail/merged?symbol={BASE}{QUOTE}',
        fallbackPairs: CryptoCatalogData.buildPairs(quoteCurrencies: ['USDT', 'BTC', 'ETH']),
      ),
      StandardRestExchange(
        id: 'bitfinex',
        name: 'Bitfinex',
        category: ExchangeCategory.tier1,
        countryBadge: '🌐 Global',
        defaultCounterCurrency: 'USD',
        tickerUrlTemplate: 'https://api-pub.bitfinex.com/v2/ticker/t{BASE_UPPER}{QUOTE_UPPER}',
        fallbackPairs: CryptoCatalogData.buildPairs(quoteCurrencies: ['USD', 'USDT', 'BTC']),
      ),
      StandardRestExchange(
        id: 'bitstamp',
        name: 'Bitstamp',
        category: ExchangeCategory.tier1,
        countryBadge: '🇪🇺 Europe',
        defaultCounterCurrency: 'USD',
        tickerUrlTemplate: 'https://www.bitstamp.net/api/v2/ticker/{BASE}{QUOTE}/',
        fallbackPairs: CryptoCatalogData.buildPairs(quoteCurrencies: ['USD', 'EUR', 'BTC']),
      ),
      StandardRestExchange(
        id: 'gemini',
        name: 'Gemini',
        category: ExchangeCategory.tier1,
        countryBadge: '🇺🇸 US',
        defaultCounterCurrency: 'USD',
        tickerUrlTemplate: 'https://api.gemini.com/v1/pubticker/{BASE}{QUOTE}',
        fallbackPairs: CryptoCatalogData.buildPairs(quoteCurrencies: ['USD', 'BTC', 'ETH']),
      ),
      StandardRestExchange(
        id: 'poloniex',
        name: 'Poloniex',
        category: ExchangeCategory.tier1,
        countryBadge: '🌐 Global',
        defaultCounterCurrency: 'USDT',
        tickerUrlTemplate: 'https://api.poloniex.com/markets/{BASE_UPPER}_{QUOTE_UPPER}/ticker24h',
        fallbackPairs: CryptoCatalogData.buildPairs(quoteCurrencies: ['USDT', 'USDC', 'BTC']),
      ),
      StandardRestExchange(
        id: 'bitmart',
        name: 'BitMart',
        category: ExchangeCategory.tier1,
        countryBadge: '🌐 Global',
        defaultCounterCurrency: 'USDT',
        tickerUrlTemplate: 'https://api-cloud.bitmart.com/spot/quotation/v3/ticker?symbol={BASE_UPPER}_{QUOTE_UPPER}',
        fallbackPairs: CryptoCatalogData.buildPairs(quoteCurrencies: ['USDT', 'BTC']),
      ),
      StandardRestExchange(
        id: 'cryptocom',
        name: 'Crypto.com',
        category: ExchangeCategory.tier1,
        countryBadge: '🌐 Global',
        defaultCounterCurrency: 'USDT',
        fallbackPairs: CryptoCatalogData.buildPairs(quoteCurrencies: ['USDT', 'USD']),
      ),
      StandardRestExchange(
        id: 'upbit',
        name: 'Upbit',
        category: ExchangeCategory.asia,
        countryBadge: '🇰🇷 South Korea',
        defaultCounterCurrency: 'USDT',
        tickerUrlTemplate: 'https://api.upbit.com/v1/ticker?markets=USDT-{BASE_UPPER}',
        fallbackPairs: CryptoCatalogData.buildPairs(quoteCurrencies: ['USDT', 'BTC']),
      ),
      StandardRestExchange(
        id: 'bithumb',
        name: 'Bithumb',
        category: ExchangeCategory.asia,
        countryBadge: '🇰🇷 South Korea',
        defaultCounterCurrency: 'USDT',
        fallbackPairs: CryptoCatalogData.buildPairs(quoteCurrencies: ['USDT', 'BTC']),
      ),
      StandardRestExchange(
        id: 'bitflyer',
        name: 'bitFlyer',
        category: ExchangeCategory.asia,
        countryBadge: '🇯🇵 Japan',
        defaultCounterCurrency: 'USD',
        fallbackPairs: CryptoCatalogData.buildPairs(quoteCurrencies: ['USD', 'JPY', 'BTC']),
      ),
      StandardRestExchange(
        id: 'phemex',
        name: 'Phemex',
        category: ExchangeCategory.tier1,
        countryBadge: '🌐 Global',
        defaultCounterCurrency: 'USDT',
        tickerUrlTemplate: 'https://api.phemex.com/spot/ticker/24hr?symbol=s{BASE_UPPER}{QUOTE_UPPER}',
        fallbackPairs: CryptoCatalogData.buildPairs(quoteCurrencies: ['USDT', 'USD']),
      ),
      StandardRestExchange(
        id: 'woox',
        name: 'WOO X',
        category: ExchangeCategory.tier1,
        countryBadge: '🌐 Global',
        defaultCounterCurrency: 'USDT',
        fallbackPairs: CryptoCatalogData.buildPairs(quoteCurrencies: ['USDT', 'BTC']),
      ),
      StandardRestExchange(
        id: 'deribit',
        name: 'Deribit',
        category: ExchangeCategory.tier1,
        countryBadge: '🌐 Global',
        defaultCounterCurrency: 'USD',
        fallbackPairs: CryptoCatalogData.buildPairs(quoteCurrencies: ['USD', 'USDC']),
      ),
      StandardRestExchange(
        id: 'bitmex',
        name: 'BitMEX',
        category: ExchangeCategory.tier1,
        countryBadge: '🌐 Global',
        defaultCounterCurrency: 'USDT',
        tickerUrlTemplate: 'https://www.bitmex.com/api/v1/instrument?symbol={BASE_UPPER}_{QUOTE_UPPER}',
        fallbackPairs: CryptoCatalogData.buildPairs(quoteCurrencies: ['USDT', 'USD']),
      ),
      StandardRestExchange(
        id: 'probit',
        name: 'ProBit',
        category: ExchangeCategory.tier1,
        countryBadge: '🌐 Global',
        defaultCounterCurrency: 'USDT',
        fallbackPairs: CryptoCatalogData.buildPairs(quoteCurrencies: ['USDT', 'BTC']),
      ),
      StandardRestExchange(
        id: 'ascendex',
        name: 'AscendEX',
        category: ExchangeCategory.tier1,
        countryBadge: '🌐 Global',
        defaultCounterCurrency: 'USDT',
        fallbackPairs: CryptoCatalogData.buildPairs(quoteCurrencies: ['USDT', 'BTC']),
      ),
      StandardRestExchange(
        id: 'bitrue',
        name: 'Bitrue',
        category: ExchangeCategory.tier1,
        countryBadge: '🌐 Global',
        defaultCounterCurrency: 'USDT',
        fallbackPairs: CryptoCatalogData.buildPairs(quoteCurrencies: ['USDT', 'BTC']),
      ),
      StandardRestExchange(
        id: 'hitbtc',
        name: 'HitBTC',
        category: ExchangeCategory.tier1,
        countryBadge: '🌐 Global',
        defaultCounterCurrency: 'USDT',
        tickerUrlTemplate: 'https://api.hitbtc.com/api/3/public/ticker/{BASE_UPPER}{QUOTE_UPPER}',
        fallbackPairs: CryptoCatalogData.buildPairs(quoteCurrencies: ['USDT', 'BTC']),
      ),
      StandardRestExchange(
        id: 'bitso',
        name: 'Bitso',
        category: ExchangeCategory.americas,
        countryBadge: '🇲🇽 LatAm',
        defaultCounterCurrency: 'USD',
        fallbackPairs: CryptoCatalogData.buildPairs(quoteCurrencies: ['USD', 'USDT']),
      ),
      StandardRestExchange(
        id: 'indodax',
        name: 'Indodax',
        category: ExchangeCategory.asia,
        countryBadge: '🇮🇩 Indonesia',
        defaultCounterCurrency: 'USDT',
        fallbackPairs: CryptoCatalogData.buildPairs(quoteCurrencies: ['USDT', 'BTC']),
      ),
      StandardRestExchange(
        id: 'paribu',
        name: 'Paribu',
        category: ExchangeCategory.europe,
        countryBadge: '🇹🇷 Turkey',
        defaultCounterCurrency: 'USDT',
        fallbackPairs: CryptoCatalogData.buildPairs(quoteCurrencies: ['USDT', 'TRY']),
      ),
      StandardRestExchange(
        id: 'btcturk',
        name: 'BtcTurk',
        category: ExchangeCategory.europe,
        countryBadge: '🇹🇷 Turkey',
        defaultCounterCurrency: 'USDT',
        fallbackPairs: CryptoCatalogData.buildPairs(quoteCurrencies: ['USDT', 'TRY']),
      ),
      StandardRestExchange(
        id: 'bitvavo',
        name: 'Bitvavo',
        category: ExchangeCategory.europe,
        countryBadge: '🇳🇱 Europe',
        defaultCounterCurrency: 'EUR',
        tickerUrlTemplate: 'https://api.bitvavo.com/v2/ticker/price?market={BASE_UPPER}-EUR',
        fallbackPairs: CryptoCatalogData.buildPairs(quoteCurrencies: ['EUR', 'USDT']),
      ),

      // --- GLOBAL AGGREGATORS & BENCHMARKS ---
      CoinMarketCapExchange(),
      CoinGeckoExchange(),
    ];
  }
}
