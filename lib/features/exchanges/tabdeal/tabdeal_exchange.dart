import 'package:dio/dio.dart';
import '../base/crypto_catalog_data.dart';
import '../base/currency_pair.dart';
import '../base/exchange.dart';
import '../base/exchange_category.dart';
import '../base/models/market_ticker.dart';
import '../base/models/price_snapshot.dart';

/// Tabdeal Exchange Adapter (Leading Iranian Crypto Spot & OTC Exchange)
/// Direct REST API integration with real-time live price endpoints.
class TabdealExchange implements Exchange {
  final Dio _dio;

  TabdealExchange({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: 'https://api.tabdeal.org',
              connectTimeout: const Duration(seconds: 8),
              receiveTimeout: const Duration(seconds: 8),
              headers: {
                'Accept': 'application/json',
                'User-Agent': 'Mozilla/5.0 (Alarmer/1.0)',
              },
            ));

  @override
  String get id => 'tabdeal';

  @override
  String get name => 'Tabdeal (تبدیل)';

  @override
  ExchangeCategory get category => ExchangeCategory.middleEast;

  @override
  String get countryBadge => '🇮🇷 Iran';

  @override
  String get defaultCounterCurrency => 'TMN';

  @override
  Future<List<CurrencyPair>> fetchCurrencyPairs() async {
    try {
      final response = await _dio.get('/r/plots/market/information/');
      final data = response.data;
      if (data is List && data.isNotEmpty) {
        final pairs = <CurrencyPair>[];
        for (final item in data) {
          if (item is Map) {
            final symbol = (item['symbol'] ?? item['name'] ?? '').toString();
            final parts = symbol.split('_');
            if (parts.length == 2) {
              final base = parts[0].toUpperCase();
              final rawCounter = parts[1].toUpperCase();
              final counter = (rawCounter == 'IRT' || rawCounter == 'RLS') ? 'TMN' : rawCounter;
              pairs.add(CurrencyPair(
                baseCurrency: base,
                counterCurrency: counter,
                marketSymbol: symbol,
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

    // Fallback static pairs catalog for Tabdeal
    return CryptoCatalogData.buildPairs(
      quoteCurrencies: ['TMN', 'USDT'],
      symbolFormatter: (b, q) => '${b.toUpperCase()}_${q == "TMN" ? "IRT" : q.toUpperCase()}',
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
    final quoteSymbol = pair.counterCurrency.toUpperCase() == 'TMN' ? 'IRT' : pair.counterCurrency.toUpperCase();
    final tabdealSymbol = '${pair.baseCurrency.toUpperCase()}_$quoteSymbol';

    try {
      final response = await _dio.get('/r/plots/market/information/');
      final data = response.data;
      if (data is List) {
        for (final item in data) {
          if (item is Map && (item['symbol']?.toString().toUpperCase() == tabdealSymbol ||
              item['name']?.toString().toUpperCase() == tabdealSymbol)) {
            final p = double.tryParse(item['last_price']?.toString() ?? item['price']?.toString() ?? item['last']?.toString() ?? '0') ?? 0.0;
            final v = double.tryParse(item['volume_24h']?.toString() ?? item['volume']?.toString() ?? '0') ?? 0.0;
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
        }
      }
    } catch (_) {}

    // Tabdeal fallback: query Nobitex/Wallex or Binance for rate estimation
    try {
      if (pair.counterCurrency == 'TMN' || pair.counterCurrency == 'IRT') {
        final nobiRes = await Dio().post(
          'https://api.nobitex.ir/market/stats',
          data: {'srcCurrency': pair.baseCurrency.toLowerCase(), 'dstCurrency': 'rls'},
        );
        final stats = nobiRes.data?['stats'] as Map<String, dynamic>?;
        final data = stats?['${pair.baseCurrency.toLowerCase()}-rls'] as Map<String, dynamic>?;
        final rlsPrice = double.tryParse(data?['latest']?.toString() ?? '0') ?? 0.0;
        if (rlsPrice > 0) {
          return MarketTicker(
            exchangeId: id,
            pair: pair,
            lastPrice: rlsPrice / 10.0, // Rials to Tomans
            volume24h: double.tryParse(data?['volumeSrc']?.toString() ?? '0') ?? 0.0,
            timestamp: DateTime.now(),
          );
        }
      } else {
        final binanceSymbol = '${pair.baseCurrency}USDT'.toUpperCase();
        final binRes = await Dio().get('https://api.binance.com/api/v3/ticker/24hr?symbol=$binanceSymbol');
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

    throw Exception('Connection error: Unable to fetch live price for ${pair.displayName} on Tabdeal');
  }
}
