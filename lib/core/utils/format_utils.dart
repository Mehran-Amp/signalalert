import 'package:intl/intl.dart';

/// Universal Price and Decimal Formatter (inspired by BitcoinChecker FormatUtilsBase)
/// Supports dynamic significant digits, sub-cent cryptos (Shiba, Pepe, etc.),
/// and international fiat/crypto currency symbols and subunits.
class FormatUtils {
  static final NumberFormat _noDecimal = NumberFormat('#,###', 'en_US');
  static final NumberFormat _twoDecimal = NumberFormat('#,###.00', 'en_US');

  /// Formats any double price with intelligent precision based on its scale:
  /// - Large assets (BTC, Gold, Indices >= $1,000): 2 decimals with thousand separators ($94,520.50)
  /// - Standard assets ($1 to $1,000): 2 decimals ($18.45)
  /// - Penny assets ($0.01 to $1): 4 decimals ($0.0452)
  /// - Micro assets ($0.0001 to $0.01): 6 decimals ($0.004210)
  /// - Nano assets (< $0.0001, e.g. PEPE, SHIB): up to 8 decimals ($0.00000845)
  static String formatPrice(double price, {String? currencySymbol, bool showSymbol = true}) {
    if (price.isNaN || price.isInfinite) return '0.00';

    String formattedNumber;
    final absPrice = price.abs();

    if (absPrice >= 1000) {
      formattedNumber = _twoDecimal.format(price);
    } else if (absPrice >= 1) {
      formattedNumber = price.toStringAsFixed(2);
    } else if (absPrice >= 0.01) {
      formattedNumber = price.toStringAsFixed(4);
    } else if (absPrice >= 0.0001) {
      formattedNumber = price.toStringAsFixed(6);
    } else if (absPrice >= 0.00000001) {
      // Strip trailing zeros for micro assets
      formattedNumber = price.toStringAsFixed(8).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
    } else if (absPrice == 0) {
      formattedNumber = '0.00';
    } else {
      formattedNumber = price.toStringAsFixed(8);
    }

    if (!showSymbol || currencySymbol == null || currencySymbol.isEmpty) {
      return formattedNumber;
    }

    // Handle Persian / RTL counter currencies
    final isToman = currencySymbol.toUpperCase() == 'TMN' || currencySymbol == 'تومان';
    final isRial = currencySymbol.toUpperCase() == 'IRR' || currencySymbol == 'ریال' || currencySymbol.toUpperCase() == 'RLS';

    if (isToman) {
      final tmnNumber = absPrice >= 1 ? _noDecimal.format(price) : formattedNumber;
      return '$tmnNumber تومان';
    }
    if (isRial) {
      final rialNumber = absPrice >= 1 ? _noDecimal.format(price) : formattedNumber;
      return '$rialNumber ریال';
    }

    // Universal symbols
    switch (currencySymbol.toUpperCase()) {
      case 'USD':
      case 'USDT':
      case 'USDC':
        return '\$$formattedNumber';
      case 'EUR':
        return '€$formattedNumber';
      case 'GBP':
        return '£$formattedNumber';
      case 'JPY':
      case 'CNY':
        return '¥$formattedNumber';
      case 'BTC':
        return '₿$formattedNumber';
      case 'SAT':
      case 'SATOSHI':
        return '${_noDecimal.format(price)} sats';
      default:
        return '$formattedNumber $currencySymbol';
    }
  }

  /// Converts a price into a specific Subunit (e.g. BTC to Satoshi, Tomans to Rials)
  static double convertToSubunit(double basePrice, String baseCurrency, String targetSubunit) {
    if (baseCurrency.toUpperCase() == 'BTC' && (targetSubunit.toUpperCase() == 'SAT' || targetSubunit.toUpperCase() == 'SATOSHI')) {
      return basePrice * 100000000.0;
    }
    if (baseCurrency.toUpperCase() == 'BTC' && targetSubunit.toUpperCase() == 'MBTC') {
      return basePrice * 1000.0;
    }
    if (targetSubunit.toUpperCase() == 'RLS' && baseCurrency.toUpperCase() == 'TMN') {
      return basePrice * 10.0;
    }
    return basePrice;
  }

  /// Converts any English digits in a string or number to Persian digits (۰-۹)
  static String toPersianDigits(dynamic input) {
    if (input == null) return '';
    final str = input.toString();
    const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const persian = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
    var result = str;
    for (int i = 0; i < english.length; i++) {
      result = result.replaceAll(english[i], persian[i]);
    }
    return result;
  }

  /// Converts Persian (۰-۹) or Arabic (٠-٩) digits to standard ASCII digits (0-9)
  static String normalizePersianDigits(String input) {
    if (input.isEmpty) return '';
    const persian = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
    const arabic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    var result = input;
    for (int i = 0; i < 10; i++) {
      result = result.replaceAll(persian[i], english[i]).replaceAll(arabic[i], english[i]);
    }
    return result;
  }

  /// Formats prices specifically for the Iran Market UI (100% Persian digits with 'ت' or 'تومان')
  static String formatIranPrice(double price, {String unit = 'ت'}) {
    if (price.isNaN || price.isInfinite) return '۰ $unit';
    final absPrice = price.abs();
    String formattedEn;
    if (absPrice >= 1000) {
      formattedEn = _noDecimal.format(price);
    } else if (absPrice >= 1) {
      formattedEn = price.toStringAsFixed(2);
    } else {
      formattedEn = price.toStringAsFixed(4);
    }
    final faNum = toPersianDigits(formattedEn);
    return '$faNum $unit';
  }

  /// Formats prices for Alert List / Card rows in English digits with 'T' (e.g. 268,500 T)
  static String formatAlertCardPrice(double price, String quoteCurrency) {
    final isToman = quoteCurrency.toUpperCase() == 'TMN' ||
        quoteCurrency.toUpperCase() == 'IRT' ||
        quoteCurrency == 'تومان' ||
        quoteCurrency.toUpperCase() == 'IRR' ||
        quoteCurrency.toUpperCase() == 'RLS' ||
        quoteCurrency == 'ریال';
    if (isToman) {
      final numStr = price >= 1000
          ? _noDecimal.format(price)
          : (price == price.roundToDouble() ? price.toInt().toString() : price.toStringAsFixed(2));
      return '$numStr T';
    }
    return formatPrice(price, currencySymbol: quoteCurrency);
  }

  /// Formats volume with compact SI units (K, M, B)
  static String formatVolume(double volume) {
    if (volume >= 1000000000) {
      return '${(volume / 1000000000).toStringAsFixed(2)}B';
    } else if (volume >= 1000000) {
      return '${(volume / 1000000).toStringAsFixed(2)}M';
    } else if (volume >= 1000) {
      return '${(volume / 1000).toStringAsFixed(1)}K';
    } else {
      return volume.toStringAsFixed(0);
    }
  }
}
