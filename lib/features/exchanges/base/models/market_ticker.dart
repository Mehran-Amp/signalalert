import 'package:equatable/equatable.dart';
import '../currency_pair.dart';

/// Standardized financial market tick payload emitted across all exchanges.
class MarketTicker extends Equatable {
  final String? exchangeId;
  final CurrencyPair? pair;

  /// Latest traded price
  final double lastPrice;

  /// Total trading volume in counter currency over the last 24 hours
  final double volume24h;

  /// Highest traded price in the last 24 hours
  final double high24h;

  /// Lowest traded price in the last 24 hours
  final double low24h;

  /// Best current buy order price (bid)
  final double? bid;

  /// Best current sell order price (ask)
  final double? ask;

  /// Timestamp when the tick was emitted
  final DateTime timestamp;

  const MarketTicker({
    this.exchangeId,
    this.pair,
    required this.lastPrice,
    required this.volume24h,
    double? high24h,
    double? low24h,
    this.bid,
    this.ask,
    required this.timestamp,
  })  : high24h = high24h ?? lastPrice,
        low24h = low24h ?? lastPrice;

  @override
  List<Object?> get props => [
    exchangeId,
    pair,
    lastPrice,
    volume24h,
    high24h,
    low24h,
    bid,
    ask,
    timestamp,
  ];

  Map<String, dynamic> toJson() => {
    if (exchangeId != null) 'exchangeId': exchangeId,
    'lastPrice': lastPrice,
    'volume24h': volume24h,
    'high24h': high24h,
    'low24h': low24h,
    'bid': bid,
    'ask': ask,
    'timestamp': timestamp.toIso8601String(),
  };

  factory MarketTicker.fromJson(Map<String, dynamic> json) => MarketTicker(
    exchangeId: json['exchangeId'] as String?,
    lastPrice: (json['lastPrice'] as num).toDouble(),
    volume24h: (json['volume24h'] as num).toDouble(),
    high24h: (json['high24h'] as num?)?.toDouble() ?? (json['lastPrice'] as num).toDouble(),
    low24h: (json['low24h'] as num?)?.toDouble() ?? (json['lastPrice'] as num).toDouble(),
    bid: (json['bid'] as num?)?.toDouble(),
    ask: (json['ask'] as num?)?.toDouble(),
    timestamp: DateTime.parse(json['timestamp'] as String),
  );
}
