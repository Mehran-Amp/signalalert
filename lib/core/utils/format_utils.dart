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
