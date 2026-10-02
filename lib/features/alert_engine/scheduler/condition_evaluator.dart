import '../../../core/utils/format_utils.dart';
import '../models/alert_rule.dart';
import '../models/trigger_mode.dart';

/// Result of evaluating an alert rule condition against current market data
class EvaluationResult {
  final bool isTriggered;
  final String title;
  final String message;
  final double? newBasePrice;
  final double? newBaseVolume;
  final bool newIsActive;
  final bool newIsTriggered;

  const EvaluationResult({
    required this.isTriggered,
    this.title = '',
    this.message = '',
    this.newBasePrice,
    this.newBaseVolume,
    this.newIsActive = true,
    this.newIsTriggered = false,
  });

  static const notTriggered = EvaluationResult(isTriggered: false);
}

/// Pure evaluation functions per condition type with color-coded emojis and arrow formatting.
abstract class ConditionEvaluator {
  /// Evaluates an [AlertRule] against current market price and volume
  static EvaluationResult evaluate({
    required AlertRule rule,
    required double currentPrice,
    double? currentVolume,
  }) {
    switch (rule.conditionType) {
      case AlertConditionType.priceThreshold:
        return _evaluatePriceThreshold(rule, currentPrice);
      case AlertConditionType.percentChange:
        return _evaluatePercentChange(rule, currentPrice);
      case AlertConditionType.absolutePriceChange:
        return _evaluateAbsolutePriceChange(rule, currentPrice);
      case AlertConditionType.volumeChange:
        return _evaluateVolumeChange(rule, currentVolume ?? 0.0);
    }
  }

  static String _formatVal(double val, {String? currencySymbol}) {
    return FormatUtils.formatPrice(val, currencySymbol: currencySymbol);
  }

  static String _buildBodyText(AlertRule rule, double currentPrice) {
    final customNote = rule.customNote?.trim();
    if (customNote != null && customNote.isNotEmpty) {
      if (customNote.startsWith('📝')) {
        return customNote;
      }
      return '📝 $customNote';
    }
    return '📝 ${_formatVal(currentPrice, currencySymbol: rule.pair.counterCurrency)}';
  }

  /// 1. Price Threshold (One-shot):
  static EvaluationResult _evaluatePriceThreshold(
    AlertRule rule,
    double currentPrice,
  ) {
    final target = rule.targetPrice ?? 0.0;
    if (target <= 0.0) return EvaluationResult.notTriggered;

    bool triggered = false;
    if (rule.direction == AlertDirection.above) {
      triggered = currentPrice >= target;
    } else if (rule.direction == AlertDirection.below) {
      triggered = currentPrice <= target;
    } else {
      triggered = (rule.basePrice != null && rule.basePrice! < target && currentPrice >= target) ||
          (rule.basePrice != null && rule.basePrice! > target && currentPrice <= target) ||
          (currentPrice == target);
      if (!triggered && rule.basePrice == null) {
        triggered = currentPrice >= target;
      }
    }

    if (!triggered) return EvaluationResult.notTriggered;

    double percentDiff = 0.0;
    if (rule.basePrice != null && rule.basePrice! > 0) {
      percentDiff = ((currentPrice - rule.basePrice!) / rule.basePrice!) * 100.0;
    } else if (target > 0) {
      percentDiff = ((currentPrice - target) / target) * 100.0;
    }

    final bool isUpward;
    if (rule.direction == AlertDirection.above) {
      isUpward = true;
    } else if (rule.direction == AlertDirection.below) {
      isUpward = false;
    } else {
      isUpward = percentDiff >= 0;
    }

    final emoji = isUpward ? '🟢' : '🔴';
    final arrow = isUpward ? '▲' : '▼';
    final sign = isUpward ? '+' : '-';
    final pctStr = '$sign${percentDiff.abs().toStringAsFixed(2)}%';
    final formattedPrice = _formatVal(currentPrice, currencySymbol: rule.pair.counterCurrency);

    return EvaluationResult(
      isTriggered: true,
      title: '$emoji ${rule.pair.displayName} $pctStr $formattedPrice $arrow',
      message: _buildBodyText(rule, currentPrice),
      newIsActive: false,     // One-shot: deactivates
      newIsTriggered: true,   // Marked as triggered in UI
      newBasePrice: currentPrice,
    );
  }

  /// 2. Percent Change (Recurring):
  static EvaluationResult _evaluatePercentChange(
    AlertRule rule,
    double currentPrice,
  ) {
    final base = rule.basePrice ?? currentPrice;
    final targetPercent = rule.percent ?? 0.0;
    if (base <= 0.0 || targetPercent <= 0.0) return EvaluationResult.notTriggered;

    final diff = currentPrice - base;
    final actualPercent = (diff / base) * 100.0;

    bool triggered = false;
    if (rule.direction == AlertDirection.above) {
      triggered = actualPercent >= targetPercent;
    } else if (rule.direction == AlertDirection.below) {
      triggered = actualPercent <= -targetPercent;
    } else {
      triggered = actualPercent.abs() >= targetPercent;
    }

    if (!triggered) return EvaluationResult.notTriggered;

    final isUpward = actualPercent >= 0;
    final emoji = isUpward ? '🟢' : '🔴';
    final arrow = isUpward ? '▲' : '▼';
    final sign = isUpward ? '+' : '-';
    final pctStr = '$sign${actualPercent.abs().toStringAsFixed(2)}%';
    final formattedPrice = _formatVal(currentPrice, currencySymbol: rule.pair.counterCurrency);

    return EvaluationResult(
      isTriggered: true,
      title: '$emoji ${rule.pair.displayName} $pctStr $formattedPrice $arrow',
      message: _buildBodyText(rule, currentPrice),
      newBasePrice: currentPrice, // Update baseline for next cycle to latest price!
      newIsActive: true,          // Stays active forever until paused
      newIsTriggered: false,
    );
  }

  /// 3. Absolute Price Change (Recurring):
  static EvaluationResult _evaluateAbsolutePriceChange(
    AlertRule rule,
    double currentPrice,
  ) {
    final base = rule.basePrice ?? currentPrice;
    final delta = rule.deltaAbsolute ?? 0.0;
    if (delta <= 0.0) return EvaluationResult.notTriggered;

    final diff = currentPrice - base;

    bool triggered = false;
    if (rule.direction == AlertDirection.above) {
      triggered = diff >= delta;
    } else if (rule.direction == AlertDirection.below) {
      triggered = diff <= -delta;
    } else {
      triggered = diff.abs() >= delta;
    }

    if (!triggered) return EvaluationResult.notTriggered;

    final isUpward = diff >= 0;
    final actualPercent = base > 0 ? (diff / base) * 100.0 : 0.0;
    final emoji = isUpward ? '🟢' : '🔴';
    final arrow = isUpward ? '▲' : '▼';
    final sign = isUpward ? '+' : '-';
    final pctStr = '$sign${actualPercent.abs().toStringAsFixed(2)}%';
    final formattedPrice = _formatVal(currentPrice, currencySymbol: rule.pair.counterCurrency);

    return EvaluationResult(
      isTriggered: true,
      title: '$emoji ${rule.pair.displayName} $pctStr $formattedPrice $arrow',
      message: _buildBodyText(rule, currentPrice),
      newBasePrice: currentPrice,
      newIsActive: true,
      newIsTriggered: false,
    );
  }

  /// 4. Volume Change (Recurring):
  static EvaluationResult _evaluateVolumeChange(
    AlertRule rule,
    double currentVolume,
  ) {
    final baseVolume = rule.baseVolume ?? currentVolume;
    final volumePercent = rule.volumePercent ?? 0.0;
    if (baseVolume <= 0.0 || volumePercent <= 0.0) {
      return EvaluationResult.notTriggered;
    }

    final diff = currentVolume - baseVolume;
    final actualPercent = (diff / baseVolume) * 100.0;

    if (actualPercent >= volumePercent) {
      final isUpward = actualPercent >= 0;
      final emoji = isUpward ? '🟢' : '🔴';
      final arrow = isUpward ? '▲' : '▼';
      final sign = isUpward ? '+' : '-';
      final pctStr = '$sign${actualPercent.abs().toStringAsFixed(2)}%';
      final currentPrice = rule.lastCheckedPrice ?? 0.0;
      final formattedPrice = _formatVal(currentPrice, currencySymbol: rule.pair.counterCurrency);

      return EvaluationResult(
        isTriggered: true,
        title: '$emoji ${rule.pair.displayName} $pctStr $formattedPrice $arrow',
        message: _buildBodyText(rule, currentPrice),
        newBaseVolume: currentVolume,
        newIsActive: true,
        newIsTriggered: false,
      );
    }

    return EvaluationResult.notTriggered;
  }
}
