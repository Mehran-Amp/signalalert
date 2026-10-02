import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';
import '../../exchanges/base/currency_pair.dart';
import 'alert_type.dart';
import 'trigger_mode.dart';

export 'alert_type.dart';
export 'trigger_mode.dart';

/// Personal Price Alert Rule entity.
/// Represents a single, dedicated condition with its own polling interval, sound, vibration & note.
class AlertRule extends Equatable {
  /// Unique UUID string (primary business key)
  final String uuid;

  /// Standardized currency pair
  final String baseCurrency;
  final String counterCurrency;
  final String marketSymbol;

  /// Currency pair helper getter
  CurrencyPair get pair => CurrencyPair(
        baseCurrency: baseCurrency,
        counterCurrency: counterCurrency,
        marketSymbol: marketSymbol,
      );

  /// Exchange ID acting as the price source (e.g. "binance", "coingecko")
  final String exchangeId;

  /// Individual polling interval in seconds (e.g. 10s, 30s, 60s, 300s, 3600s)
  final int checkIntervalSeconds;

  /// The single condition type for this rule
  final AlertConditionType conditionType;

  /// Evaluation direction: above, below, or bothSides
  final AlertDirection direction;

  /// Trigger mode: auto-set based on conditionType
  final TriggerMode triggerMode;

  /// For priceThreshold: target price in counter currency
  final double? targetPrice;

  /// For percentChange: percentage change from basePrice (e.g. 3.0 for 3%)
  final double? percent;

  /// For absolutePriceChange: price delta from basePrice (e.g. 1000.0)
  final double? deltaAbsolute;

  /// For volumeChange: volume percentage change from baseVolume
  final double? volumePercent;

  /// Baseline reference price (updated on recurring trigger)
  final double? basePrice;

  /// Most recently fetched/checked price from exchange
  final double? lastCheckedPrice;

  /// Helper getter for current display price
  double? get currentDisplayPrice => lastCheckedPrice ?? basePrice;

  /// Baseline reference volume
  final double? baseVolume;

  /// Custom note / trade thesis (e.g. "TP1 Hit - take profit", "Stop Loss")
  final String? customNote;

  /// Convenient alias for customNote
  String? get note => customNote;

  /// Custom alarm sound tone ID for this specific alert
  final String? customSound;

  /// Preferred voice language for Text-To-Speech (e.g. "fa", "en", "ar")
  final String? language;

  /// Whether sound is enabled for this alert
  final bool soundEnabled;

  /// Whether text-to-speech voice reading is enabled for this alert
  final bool ttsEnabled;

  /// Whether vibration is enabled for this alert
  final bool vibrationEnabled;

  /// Whether this alert is actively checked by the scheduler
  final bool isActive;

  /// True if a one-shot alert has triggered and is waiting for manual re-arm
  final bool isTriggered;

  /// Timestamp until which the rule is silenced by cooldown
  final DateTime? cooldownUntil;

  /// Total number of times this rule was triggered
  final int triggerCount;

  /// Timestamp when the scheduler last polled and evaluated this rule
  final DateTime? lastCheckedAt;

  /// Timestamp when this rule was last triggered
  final DateTime? lastTriggeredAt;

  /// Timestamp when the rule was created
  final DateTime createdAt;

  // --- Display & Compatibility Helpers ---

  /// Helper to check if rule is currently suppressed by cooldown
  bool get isInCooldown =>
      cooldownUntil != null && cooldownUntil!.isAfter(DateTime.now());

  /// Maps conditionType to display AlertType
  AlertType get alertType {
    switch (conditionType) {
      case AlertConditionType.priceThreshold:
        return AlertType.priceCross;
      case AlertConditionType.percentChange:
        return AlertType.percentChange;
      case AlertConditionType.absolutePriceChange:
        return AlertType.price;
      case AlertConditionType.volumeChange:
        return AlertType.volumeSurge;
    }
  }

  /// Maps conditionType to display localized title
  String getLocalizedTitle(String lang) {
    switch (conditionType) {
      case AlertConditionType.priceThreshold:
        return lang == 'fa'
            ? 'هشدار عبور از قیمت هدف'
            : (lang == 'ar'
                ? 'إنذار تجاوز السعر المستهدف'
                : 'Target Price Alert');
      case AlertConditionType.percentChange:
        return lang == 'fa'
            ? 'هشدار تغییر درصدی قیمت'
            : (lang == 'ar'
                ? 'إنذار نسبة التغير في السعر'
                : 'Percentage Change Alert');
      case AlertConditionType.absolutePriceChange:
        return lang == 'fa'
            ? 'هشدار مقدار نوسان دلاری'
            : (lang == 'ar'
                ? 'إنذار مقدار التغير السعري'
                : 'Price Delta Alert');
      case AlertConditionType.volumeChange:
        return lang == 'fa'
            ? 'هشدار پامپ و حجم معاملات'
            : (lang == 'ar'
                ? 'إنذار حجم التداول'
                : 'Volume Surge Alert');
    }
  }

  const AlertRule({
    required this.uuid,
    required this.baseCurrency,
    required this.counterCurrency,
    required this.marketSymbol,
    required this.exchangeId,
    required this.checkIntervalSeconds,
    required this.conditionType,
    required this.direction,
    required this.triggerMode,
    this.targetPrice,
    this.percent,
    this.deltaAbsolute,
    this.volumePercent,
    this.basePrice,
    this.lastCheckedPrice,
    this.baseVolume,
    this.customNote,
    this.customSound,
    this.language,
    this.soundEnabled = true,
    this.ttsEnabled = false,
    this.vibrationEnabled = true,
    this.isActive = true,
    this.isTriggered = false,
    this.cooldownUntil,
    this.triggerCount = 0,
    this.lastCheckedAt,
    this.lastTriggeredAt,
    required this.createdAt,
  });

  /// Factory to create a new rule with auto-derived triggerMode and generated UUID
  factory AlertRule.create({
    required CurrencyPair pair,
    required String exchangeId,
    required int checkIntervalSeconds,
    required AlertConditionType conditionType,
    required AlertDirection direction,
    double? targetPrice,
    double? percent,
    double? deltaAbsolute,
    double? volumePercent,
    double? currentPrice,
    double? currentVolume,
    String? customNote,
    String? customSound,
    String? language,
    bool soundEnabled = true,
    bool ttsEnabled = false,
    bool vibrationEnabled = true,
    DateTime? cooldownUntil,
    int triggerCount = 0,
  }) {
    final mode = conditionType == AlertConditionType.priceThreshold
        ? TriggerMode.oneShot
        : TriggerMode.recurring;

    return AlertRule(
      uuid: const Uuid().v4(),
      baseCurrency: pair.baseCurrency,
      counterCurrency: pair.counterCurrency,
      marketSymbol: pair.marketSymbol,
      exchangeId: exchangeId,
      checkIntervalSeconds: checkIntervalSeconds,
      conditionType: conditionType,
      direction: direction,
      triggerMode: mode,
      targetPrice: targetPrice,
      percent: percent,
      deltaAbsolute: deltaAbsolute,
      volumePercent: volumePercent,
      basePrice: currentPrice,
      lastCheckedPrice: currentPrice,
      baseVolume: currentVolume,
      customNote: customNote,
      customSound: customSound,
      language: language,
      soundEnabled: soundEnabled,
      ttsEnabled: ttsEnabled,
      vibrationEnabled: vibrationEnabled,
      isActive: true,
      isTriggered: false,
      cooldownUntil: cooldownUntil,
      triggerCount: triggerCount,
      createdAt: DateTime.now(),
    );
  }

  /// Check if the rule is due for checking based on its individual interval
  bool isDue(DateTime now) {
    if (!isActive) return false;
    if (lastCheckedAt == null) return true;
    final nextCheck = lastCheckedAt!.add(Duration(seconds: checkIntervalSeconds));
    return now.isAfter(nextCheck) || now.isAtSameMomentAs(nextCheck);
  }

  AlertRule copyWith({
    String? baseCurrency,
    String? counterCurrency,
    String? marketSymbol,
    String? exchangeId,
    int? checkIntervalSeconds,
    AlertConditionType? conditionType,
    AlertDirection? direction,
    TriggerMode? triggerMode,
    double? targetPrice,
    double? percent,
    double? deltaAbsolute,
    double? volumePercent,
    String? customNote,
    String? customSound,
    String? language,
    bool? soundEnabled,
    bool? ttsEnabled,
    bool? vibrationEnabled,
    bool? isActive,
    bool? isTriggered,
    DateTime? cooldownUntil,
    int? triggerCount,
    double? basePrice,
    double? lastCheckedPrice,
    double? baseVolume,
    DateTime? lastCheckedAt,
    DateTime? lastTriggeredAt,
  }) {
    return AlertRule(
      uuid: uuid,
      baseCurrency: baseCurrency ?? this.baseCurrency,
      counterCurrency: counterCurrency ?? this.counterCurrency,
      marketSymbol: marketSymbol ?? this.marketSymbol,
      exchangeId: exchangeId ?? this.exchangeId,
      checkIntervalSeconds: checkIntervalSeconds ?? this.checkIntervalSeconds,
      conditionType: conditionType ?? this.conditionType,
      direction: direction ?? this.direction,
      triggerMode: triggerMode ?? this.triggerMode,
      targetPrice: targetPrice ?? this.targetPrice,
      percent: percent ?? this.percent,
      deltaAbsolute: deltaAbsolute ?? this.deltaAbsolute,
      volumePercent: volumePercent ?? this.volumePercent,
      customNote: customNote ?? this.customNote,
      customSound: customSound ?? this.customSound,
      language: language ?? this.language,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      ttsEnabled: ttsEnabled ?? this.ttsEnabled,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      basePrice: basePrice ?? this.basePrice,
      lastCheckedPrice: lastCheckedPrice ?? this.lastCheckedPrice,
      baseVolume: baseVolume ?? this.baseVolume,
      isActive: isActive ?? this.isActive,
      isTriggered: isTriggered ?? this.isTriggered,
      cooldownUntil: cooldownUntil ?? this.cooldownUntil,
      triggerCount: triggerCount ?? this.triggerCount,
      lastCheckedAt: lastCheckedAt ?? this.lastCheckedAt,
      lastTriggeredAt: lastTriggeredAt ?? this.lastTriggeredAt,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'uuid': uuid,
        'baseCurrency': baseCurrency,
        'counterCurrency': counterCurrency,
        'marketSymbol': marketSymbol,
        'exchangeId': exchangeId,
        'checkIntervalSeconds': checkIntervalSeconds,
        'conditionType': conditionType.name,
        'direction': direction.name,
        'triggerMode': triggerMode.name,
        'targetPrice': targetPrice,
        'percent': percent,
        'deltaAbsolute': deltaAbsolute,
        'volumePercent': volumePercent,
        'basePrice': basePrice,
        'lastCheckedPrice': lastCheckedPrice,
        'baseVolume': baseVolume,
        'customNote': customNote,
        'customSound': customSound,
        'language': language,
        'soundEnabled': soundEnabled,
        'ttsEnabled': ttsEnabled,
        'vibrationEnabled': vibrationEnabled,
        'isActive': isActive,
        'isTriggered': isTriggered,
        'cooldownUntil': cooldownUntil?.toIso8601String(),
        'triggerCount': triggerCount,
        'lastCheckedAt': lastCheckedAt?.toIso8601String(),
        'lastTriggeredAt': lastTriggeredAt?.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
      };

  factory AlertRule.fromJson(Map<String, dynamic> json) => AlertRule(
        uuid: json['uuid'] as String,
        baseCurrency: json['baseCurrency'] as String,
        counterCurrency: json['counterCurrency'] as String,
        marketSymbol: json['marketSymbol'] as String,
        exchangeId: json['exchangeId'] as String,
        checkIntervalSeconds: json['checkIntervalSeconds'] as int? ?? 30,
        conditionType: AlertConditionType.values.byName(
            json['conditionType'] as String? ?? 'percentChange'),
        direction: AlertDirection.values
            .byName(json['direction'] as String? ?? 'bothSides'),
        triggerMode: TriggerMode.values
            .byName(json['triggerMode'] as String? ?? 'recurring'),
        targetPrice: (json['targetPrice'] as num?)?.toDouble(),
        percent: (json['percent'] as num?)?.toDouble(),
        deltaAbsolute: (json['deltaAbsolute'] as num?)?.toDouble(),
        volumePercent: (json['volumePercent'] as num?)?.toDouble(),
        basePrice: (json['basePrice'] as num?)?.toDouble(),
        lastCheckedPrice: (json['lastCheckedPrice'] as num?)?.toDouble(),
        baseVolume: (json['baseVolume'] as num?)?.toDouble(),
        customNote: json['customNote'] as String?,
        customSound: json['customSound'] as String?,
        language: json['language'] as String?,
        soundEnabled: json['soundEnabled'] as bool? ?? true,
        ttsEnabled: json['ttsEnabled'] as bool? ?? false,
        vibrationEnabled: json['vibrationEnabled'] as bool? ?? true,
        isActive: json['isActive'] as bool? ?? true,
        isTriggered: json['isTriggered'] as bool? ?? false,
        cooldownUntil: json['cooldownUntil'] != null
            ? DateTime.tryParse(json['cooldownUntil'] as String)
            : null,
        triggerCount: json['triggerCount'] as int? ?? 0,
        lastCheckedAt: json['lastCheckedAt'] != null
            ? DateTime.tryParse(json['lastCheckedAt'] as String)
            : null,
        lastTriggeredAt: json['lastTriggeredAt'] != null
            ? DateTime.tryParse(json['lastTriggeredAt'] as String)
            : null,
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : DateTime.now(),
      );

  @override
  List<Object?> get props => [
        uuid,
        baseCurrency,
        counterCurrency,
        marketSymbol,
        exchangeId,
        checkIntervalSeconds,
        conditionType,
        direction,
        triggerMode,
        targetPrice,
        percent,
        deltaAbsolute,
        volumePercent,
        basePrice,
        lastCheckedPrice,
        baseVolume,
        customNote,
        customSound,
        language,
        soundEnabled,
        ttsEnabled,
        vibrationEnabled,
        isActive,
        isTriggered,
        cooldownUntil,
        triggerCount,
        lastCheckedAt,
        lastTriggeredAt,
        createdAt,
      ];
}
