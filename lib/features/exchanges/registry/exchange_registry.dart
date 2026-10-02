import '../base/currency_pair.dart';
import '../base/currency_pairs_helper.dart';
import '../base/exchange.dart';
import '../base/models/price_snapshot.dart';
import '../../../core/utils/symbol_filter_helper.dart';

/// Central Exchange Registry (inspired by aneonex/BitcoinChecker).
/// Manages all registered exchanges, handles dynamic pair discovery,
/// and provides manual refresh capabilities.
class ExchangeRegistry {
  final Map<String, Exchange> _exchanges = {};
  final Map<String, List<CurrencyPair>> _cachedPairsByExchange = {};
  final Map<String, CurrencyPairsHelper> _cachedHelpersByExchange = {};

  ExchangeRegistry();

  /// Registers an exchange adapter instance
  void register(Exchange exchange) {
    _exchanges[exchange.id] = exchange;
  }

  /// Retrieves an exchange adapter by its unique ID
  Exchange? get(String exchangeId) => _exchanges[exchangeId];

  /// Returns all currently registered exchanges
  List<Exchange> getAll() => _exchanges.values.toList();

  /// Map of all exchanges
  Map<String, Exchange> get asMap => Map.unmodifiable(_exchanges);

  /// Fetches a lightweight price & volume snapshot directly from the specified exchange
  Future<PriceSnapshot?> fetchSnapshotFrom(String exchangeId, CurrencyPair pair) async {
    final exchange = _exchanges[exchangeId];
    if (exchange == null) return null;
    return await exchange.fetchSnapshot(pair);
  }

  /// Preloads or gets cached currency pairs for a specific exchange
  Future<List<CurrencyPair>> getCurrencyPairs(String exchangeId) async {
    final cached = _cachedPairsByExchange[exchangeId];
    if (cached != null && cached.isNotEmpty) {
      return cached;
    }

    return await refreshCurrencyPairs(exchangeId);
  }

  /// Returns a CurrencyPairsHelper instance for smart filtering
  Future<CurrencyPairsHelper> getPairsHelper(String exchangeId) async {
    final cachedHelper = _cachedHelpersByExchange[exchangeId];
    if (cachedHelper != null && !cachedHelper.isEmpty) {
      return cachedHelper;
    }

    final pairs = await getCurrencyPairs(exchangeId);
    final helper = CurrencyPairsHelper(pairs: pairs);
    _cachedHelpersByExchange[exchangeId] = helper;
    return helper;
  }

  /// Force refresh currency pairs from the specified exchange
  Future<List<CurrencyPair>> refreshCurrencyPairs(String exchangeId) async {
    final exchange = _exchanges[exchangeId];
    if (exchange == null) {
      throw Exception('Exchange $exchangeId not found in registry');
    }

    _cachedPairsByExchange.remove(exchangeId);
    _cachedHelpersByExchange.remove(exchangeId);
    final pairs = await exchange.fetchCurrencyPairs();
    _cachedPairsByExchange[exchangeId] = pairs;
    _cachedHelpersByExchange[exchangeId] = CurrencyPairsHelper(pairs: pairs);
    return pairs;
  }

  /// Cross-exchange search: Finds matching currency pairs across all registered exchanges with startsWith prioritization
  Future<Map<String, List<CurrencyPair>>> searchPairsAcrossExchanges(String query) async {
    final cleanQuery = query.trim();
    final results = <String, List<CurrencyPair>>{};

    for (final exchange in _exchanges.values) {
      if (exchange.id == 'global_stocks') continue;
      try {
        final pairs = await getCurrencyPairs(exchange.id);
        final matched = SymbolFilterHelper.filterAndSort(pairs, cleanQuery).take(50).toList();

        if (matched.isNotEmpty) {
          results[exchange.id] = matched;
        }
      } catch (_) {}
    }

    return results;
  }

  /// Finds which registered exchanges offer a specific pair (e.g. BTC / USDT)
  Future<List<Exchange>> findExchangesForPair({
    required String baseCurrency,
    required String counterCurrency,
  }) async {
    final b = baseCurrency.toUpperCase();
    final c = counterCurrency.toUpperCase();
    final available = <Exchange>[];

    for (final exchange in _exchanges.values) {
      if (exchange.id == 'global_stocks') continue;
      try {
        final pairs = await getCurrencyPairs(exchange.id);
        final exists = pairs.any(
          (p) => p.baseCurrency.toUpperCase() == b && p.counterCurrency.toUpperCase() == c,
        );
        if (exists) {
          available.add(exchange);
        }
      } catch (_) {}
    }

    return available;
  }

  /// Clears all registered exchanges and cached pairs
  void disposeAll() {
    _exchanges.clear();
    _cachedPairsByExchange.clear();
  }
}
