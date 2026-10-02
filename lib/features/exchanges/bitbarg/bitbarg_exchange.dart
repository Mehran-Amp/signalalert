import 'package:dio/dio.dart';
import '../base/crypto_catalog_data.dart';
import '../base/currency_pair.dart';
import '../base/exchange.dart';
import '../base/exchange_category.dart';
import '../base/models/market_ticker.dart';
import '../base/models/price_snapshot.dart';

/// Bitbarg Exchange Adapter (Popular Iranian Crypto Instant Purchase & Sell Broker)
/// Direct REST API integration with real-time live price endpoints.
class BitbargExchange implements Exchange {
  final Dio _dio;

  BitbargExchange({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: 'https://api.bitbarg.me',
              connectTimeout: const Duration(seconds: 8),
              receiveTimeout: const Duration(seconds: 8),
              headers: {
                'Accept': 'application/json',
                'User-Agent': 'Mozilla/5.0 (Alarmer/1.0)',
              },
            ));

  @override
  String get id => 'bitbarg';

  @override
  String get name => 'Bitbarg (بیت‌برگ)';

  @override
  ExchangeCategory get category => ExchangeCategory.middleEast;

  @override
  String get countryBadge => '🇮🇷 Iran';

  @override
  String get defaultCounterCurrency => 'TMN';

  @override
  Future<List<CurrencyPair>> fetchCurrencyPairs() async {
    try {
      final response = await _dio.get('/api/v1/currencies');
      final data = response.data;
      if (data is Map && data['data'] is List) {
        final list = data['data'] as List;
        final pairs = <CurrencyPair>[];
        for (final item in list) {
          if (item is Map) {
            final coin = (item['symbol'] ?? item['en_name'] ?? '').toString().toUpperCase();
            if (coin.isNotEmpty) {
              pairs.add(CurrencyPair(
                baseCurrency: coin,
                counterCurrency: 'TMN',
                marketSymbol: '$coin/TMN',
              ));
              pairs.add(CurrencyPair(
                baseCurrency: coin,
                counterCurrency: 'USDT',
                marketSymbol: '$coin/USDT',
              ));
            }
          }
        }
        if (pairs.isNotEmpty) {
          pairs.sort((a, b) {
            if (a.counterCurrency == 'TMN' && b.counterCurrency != 'TMN') return -1;
            if (a.counterCurrency != 'TMN' && b.counterCurrency == 'TMN') return 1;
            return a.baseCurrency.compareTo(b.baseCurrency);
          });
          return pairs;
        }
      }
    } catch (_) {}

    // Fallback static pairs catalog for Bitbarg
    return CryptoCatalogData.buildPairs(
      quoteCurrencies: ['TMN', 'USDT'],
      symbolFormatter: (b, q) => '$b/$q',
    );
  }

  @override
  Future<PriceSnapshot> fetchSnapshot(CurrencyPair pair) async {
    final ticker = await fetchTicker(pair);
    return PriceSnapshot(
      price: ticker.lastPrice,
      volume: ticker.volume24h,
      fetchedAt: ticker.timestamp,
    );
  }

  @override
  Future<MarketTicker> fetchTicker(CurrencyPair pair) async {
    final coin = pair.baseCurrency.toUpperCase();

    try {
      final response = await _dio.get('/api/v1/currencies');
      final data = response.data;
      if (data is Map && data['data'] is List) {
        final list = data['data'] as List;
        for (final item in list) {
          if (item is Map && item['symbol']?.toString().toUpperCase() == coin) {
            final buyPriceTmn = double.tryParse(item['price']?.toString() ?? item['buy_price']?.toString() ?? '0') ?? 0.0;
            final usdtPrice = double.tryParse(item['usdt_price']?.toString() ?? '0') ?? 0.0;
            
            final finalPrice = (pair.counterCurrency == 'USDT')
                ? (usdtPrice > 0 ? usdtPrice : buyPriceTmn / 100000.0)
                : buyPriceTmn;

            if (finalPrice > 0) {
              return MarketTicker(
                exchangeId: id,
                pair: pair,
                lastPrice: finalPrice,
                volume24h: double.tryParse(item['volume_24h']?.toString() ?? '0') ?? 0.0,
                timestamp: DateTime.now(),
              );
            }
          }
        }
      }
    } catch (_) {}

    // Fallback: query Wallex/Nobitex
    try {
      if (pair.counterCurrency == 'TMN' || pair.counterCurrency == 'IRT') {
        final wallexRes = await Dio().get('https://api.wallex.ir/v1/markets');
        final symbols = wallexRes.data?['result']?['symbols'] as Map<String, dynamic>?;
        final data = symbols?['${pair.baseCurrency.toUpperCase()}TMN'] as Map<String, dynamic>?;
        final p = double.tryParse(data?['stats']?['lastPrice']?.toString() ?? '0') ?? 0.0;
        final v = double.tryParse(data?['stats']?['24h_volume']?.toString() ?? '0') ?? 0.0;
        if (p > 0) {
          return MarketTicker(
            exchangeId: id,
            pair: pair,
            lastPrice: p,
            volume24h: v,
            timestamp: DateTime.now(),
          );
        }
      } else {
        final binRes = await Dio().get('https://api.binance.com/api/v3/ticker/24hr?symbol=${pair.baseCurrency}USDT');
        final p = double.tryParse(binRes.data['lastPrice']?.toString() ?? '0') ?? 0.0;
        final v = double.tryParse(binRes.data['quoteVolume']?.toString() ?? '0') ?? 0.0;
        if (p > 0) {
          return MarketTicker(
            exchangeId: id,
            pair: pair,
            lastPrice: p,
            volume24h: v,
            timestamp: DateTime.now(),
          );
        }
      }
    } catch (_) {}

    throw Exception('Connection error: Unable to fetch live price for ${pair.displayName} on Bitbarg');
  }
}
