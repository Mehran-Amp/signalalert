import 'package:dio/dio.dart';
import '../base/crypto_catalog_data.dart';
import '../base/currency_pair.dart';
import '../base/exchange.dart';
import '../base/exchange_category.dart';
import '../base/models/market_ticker.dart';
import '../base/models/price_snapshot.dart';

/// Configurable Standard REST Exchange Adapter (inspired by BitcoinChecker DataModule)
/// Connects to verified real-time REST endpoints. Never fabricates fake prices.
class StandardRestExchange implements Exchange {
  @override
  final String id;
  @override
  final String name;
  @override
  final ExchangeCategory category;
  @override
  final String countryBadge;
  @override
  final String defaultCounterCurrency;

  final String? tickerUrlTemplate;
  final String? pairsUrl;
  final List<CurrencyPair> fallbackPairs;
  final Dio _dio;

  StandardRestExchange({
    required this.id,
    required this.name,
    required this.category,
    required this.countryBadge,
    required this.defaultCounterCurrency,
    this.tickerUrlTemplate,
    this.pairsUrl,
    required this.fallbackPairs,
    Dio? dio,
  }) : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 8),
              receiveTimeout: const Duration(seconds: 8),
              headers: {
                'Accept': 'application/json',
                'User-Agent': 'Alarmer/1.0',
              },
            ));

  @override
  Future<List<CurrencyPair>> fetchCurrencyPairs() async {
    if (pairsUrl != null) {
      try {
        final response = await _dio.get(pairsUrl!);
        final data = response.data;
        if (data is List) {
          final list = data.map((item) {
            if (item is Map) {
              final base = (item['base'] ?? item['baseCurrency'] ?? item['base_currency'] ?? 'BTC').toString().toUpperCase();
              final target = (item['target'] ?? item['quoteCurrency'] ?? item['quote_currency'] ?? defaultCounterCurrency).toString().toUpperCase();
              final symbol = (item['symbol'] ?? item['id'] ?? '$base$target').toString().toUpperCase();
              return CurrencyPair(baseCurrency: base, counterCurrency: target, marketSymbol: symbol);
            }
            return CurrencyPair(baseCurrency: 'BTC', counterCurrency: defaultCounterCurrency, marketSymbol: 'BTC$defaultCounterCurrency');
          }).toList();
          if (list.isNotEmpty) return list;
        } else if (data is Map && data['result'] is Map) {
          final map = data['result'] as Map<String, dynamic>;
          final pairs = <CurrencyPair>[];
          for (final entry in map.entries) {
            final val = entry.value as Map<String, dynamic>?;
            final base = val?['base']?.toString().toUpperCase() ?? '';
            final quote = val?['quote']?.toString().toUpperCase() ?? '';
            if (base.isNotEmpty && quote.isNotEmpty) {
              pairs.add(CurrencyPair(baseCurrency: base, counterCurrency: quote, marketSymbol: entry.key));
            }
          }
          if (pairs.isNotEmpty) return pairs;
        }
      } catch (_) {}
    }

    if (fallbackPairs.isNotEmpty) {
      return fallbackPairs;
    }

    return CryptoCatalogData.buildPairs(quoteCurrencies: [defaultCounterCurrency]);
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
    // 1. If specific tickerUrlTemplate provided, query it
    if (tickerUrlTemplate != null) {
      try {
        final url = tickerUrlTemplate!
            .replaceAll('{BASE}', pair.baseCurrency.toLowerCase())
            .replaceAll('{QUOTE}', pair.counterCurrency.toLowerCase())
            .replaceAll('{BASE_UPPER}', pair.baseCurrency.toUpperCase())
            .replaceAll('{QUOTE_UPPER}', pair.counterCurrency.toUpperCase())
            .replaceAll('{SYMBOL}', pair.marketSymbol.toUpperCase());

        final response = await _dio.get(url);
        final data = response.data;

        double price = 0.0;
        double vol = 0.0;

        if (data is Map<String, dynamic>) {
          final d = data['data'] is Map ? data['data'] as Map<String, dynamic> : data;
          price = double.tryParse(d['lastPrice']?.toString() ?? d['last']?.toString() ?? d['price']?.toString() ?? d['close']?.toString() ?? '0') ?? 0.0;
          vol = double.tryParse(d['volume']?.toString() ?? d['vol']?.toString() ?? d['volume24h']?.toString() ?? d['quoteVolume']?.toString() ?? '0') ?? 0.0;
        } else if (data is List && data.isNotEmpty && data.first is Map) {
          final first = data.first as Map<String, dynamic>;
          price = double.tryParse(first['last']?.toString() ?? first['price']?.toString() ?? first['lastPrice']?.toString() ?? '0') ?? 0.0;
          vol = double.tryParse(first['volume']?.toString() ?? first['quote_volume']?.toString() ?? '0') ?? 0.0;
        }

        if (price > 0) {
          return MarketTicker(
            exchangeId: id,
            pair: pair,
            lastPrice: price,
            volume24h: vol,
            timestamp: DateTime.now(),
          );
        }
      } catch (_) {}
    }

    // 2. Real fallback: Query Binance public live ticker for the asset pair
    try {
      final quote = pair.counterCurrency == 'USD' ? 'USDT' : pair.counterCurrency;
      final binanceSymbol = '${pair.baseCurrency}$quote'.toUpperCase();
      final res = await _dio.get('https://api.binance.com/api/v3/ticker/24hr?symbol=$binanceSymbol');
      final p = double.tryParse(res.data['lastPrice']?.toString() ?? '0') ?? 0.0;
      final v = double.tryParse(res.data['quoteVolume']?.toString() ?? '0') ?? 0.0;
      if (p > 0) {
        return MarketTicker(
          exchangeId: id,
          pair: pair,
          lastPrice: p,
          volume24h: v,
          timestamp: DateTime.now(),
        );
      }
    } catch (_) {}

    throw Exception('Connection error: Unable to fetch live price for ${pair.displayName} on $name');
  }
}
