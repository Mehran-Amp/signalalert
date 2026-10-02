import 'package:equatable/equatable.dart';

/// Lightweight price and volume snapshot for rule evaluation without full ticker metadata.
class PriceSnapshot extends Equatable {
  final double price;
  final double? volume;
  final DateTime fetchedAt;

  const PriceSnapshot({
    required this.price,
    this.volume,
    required this.fetchedAt,
  });

  @override
  List<Object?> get props => [price, volume, fetchedAt];

  @override
  String toString() => 'PriceSnapshot(price: $price, volume: $volume, fetchedAt: $fetchedAt)';
}
