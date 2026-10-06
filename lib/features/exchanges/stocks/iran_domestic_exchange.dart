import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../base/currency_pair.dart';
import '../base/exchange.dart';
import '../base/exchange_category.dart';
import '../base/models/market_ticker.dart';
import '../base/models/price_snapshot.dart';

/// Comprehensive Iran Domestic Market Adapter:
/// Gold & Coins, Free Market Cash Currencies, SANA/NIMA Rates, and Tehran Stock Exchange (TEDPIX).
/// Quote currency is strictly Toman (TMN).
class IranDomesticExchange implements Exchange {
  final http.Client _client;

  IranDomesticExchange({http.Client? client})
      : _client = client ?? http.Client();

  @override
  String get id => 'iran_market';

  @override
  String get name => 'بازار ایران (طلا، سکه، ارز آزاد و بورس)';

  @override
  ExchangeCategory get category => ExchangeCategory.iran;

  @override
  String get countryBadge => '🇮🇷 بازار تهران و تومان';

  @override
  String get defaultCounterCurrency => 'TMN';

  static const List<Map<String, dynamic>> predefinedAssets = [
    // --- ۱. طلا و مسکوکات (Gold & Coins) ---
    {
      'symbol': 'GERAM18',
      'name': 'Gold 18K (1 Gram)',
      'nameFa': 'طلای ۱۸ عیار (هر گرم)',
      'cat': 'Gold',
      'icon': '🥇',
      'price': 26738000.0,
      'unit': 'تومان',
    },
    {
      'symbol': 'GERAM24',
      'name': 'Gold 24K (1 Gram)',
      'nameFa': 'طلای ۲۴ عیار (هر گرم)',
      'cat': 'Gold',
      'icon': '✨',
      'price': 35650000.0,
      'unit': 'تومان',
    },
    {
      'symbol': 'MESGHAL',
      'name': 'Mithqal Gold (Tehran Benchmark)',
      'nameFa': 'مثقال طلا (مظنه بازار تهران)',
      'cat': 'Gold',
      'icon': '⚖️',
      'price': 115830000.0,
      'unit': 'تومان',
    },
    {
      'symbol': 'GOLD_USED',
      'name': 'Second-hand Gold',
      'nameFa': 'طلای دست دوم (بدون اجرت)',
      'cat': 'Gold',
      'icon': '💍',
      'price': 26350000.0,
      'unit': 'تومان',
    },
    {
      'symbol': 'GOLD_MELTED',
      'name': 'Melted Gold Cash',
      'nameFa': 'آبشده نقدی بنکداری',
      'cat': 'Gold',
      'icon': '🔥',
      'price': 115900000.0,
      'unit': 'تومان',
    },
    {
      'symbol': 'COIN_EMAMI',
      'name': 'Emami Gold Coin (New Design)',
      'nameFa': 'سکه امامی (طرح جدید)',
      'cat': 'Coins',
      'icon': '🪙',
      'price': 271910000.0,
      'unit': 'تومان',
    },
    {
      'symbol': 'COIN_BAHAR',
      'name': 'Bahar Azadi Coin (Old Design)',
      'nameFa': 'سکه تمام بهار آزادی (طرح قدیم)',
      'cat': 'Coins',
      'icon': '🏵️',
      'price': 264220000.0,
      'unit': 'تومان',
    },
    {
      'symbol': 'COIN_HALF',
      'name': 'Half Bahar Azadi Coin',
      'nameFa': 'نیم سکه بهار آزادی',
      'cat': 'Coins',
      'icon': '🌗',
      'price': 143460000.0,
      'unit': 'تومان',
    },
    {
      'symbol': 'COIN_QUARTER',
      'name': 'Quarter Bahar Azadi Coin',
      'nameFa': 'ربع سکه بهار آزادی',
      'cat': 'Coins',
      'icon': '🌘',
      'price': 77230000.0,
      'unit': 'تومان',
    },
    {
      'symbol': 'COIN_GRAM',
      'name': 'Gram Bahar Azadi Coin',
      'nameFa': 'سکه گرمی بانک مرکزی',
      'cat': 'Coins',
      'icon': '🔹',
      'price': 38150000.0,
      'unit': 'تومان',
    },

    // --- ۲. ارزهای بازار آزاد (Free Market Currencies) ---
    {
      'symbol': 'USD_TMN',
      'name': 'US Dollar Cash (Free Market)',
      'nameFa': 'دلار آمریکا (اسکناس بازار آزاد)',
      'cat': 'Currencies',
      'icon': '💵',
      'price': 268820.0,
      'unit': 'تومان',
    },
    {
      'symbol': 'EUR_TMN',
      'name': 'Euro Cash (Free Market)',
      'nameFa': 'یورو اروپا (بازار آزاد)',
      'cat': 'Currencies',
      'icon': '💶',
      'price': 303210.0,
      'unit': 'تومان',
    },
    {
      'symbol': 'GBP_TMN',
      'name': 'British Pound (Free Market)',
      'nameFa': 'پوند انگلیس (بازار آزاد)',
      'cat': 'Currencies',
      'icon': '💷',
      'price': 356400.0,
      'unit': 'تومان',
    },
    {
      'symbol': 'AED_TMN',
      'name': 'UAE Dirham (Free Market)',
      'nameFa': 'درهم امارات (اسکناس و حواله)',
      'cat': 'Currencies',
      'icon': '🇦🇪',
      'price': 73420.0,
      'unit': 'تومان',
    },
    {
      'symbol': 'TRY_TMN',
      'name': 'Turkish Lira (Free Market)',
      'nameFa': 'لیر ترکیه (بازار آزاد)',
      'cat': 'Currencies',
      'icon': '🇹🇷',
      'price': 5470.0,
      'unit': 'تومان',
    },
    {
      'symbol': 'CAD_TMN',
      'name': 'Canadian Dollar (Free Market)',
      'nameFa': 'دلار کانادا (بازار آزاد)',
      'cat': 'Currencies',
      'icon': '🇨🇦',
      'price': 189510.0,
      'unit': 'تومان',
    },
    {
      'symbol': 'AUD_TMN',
      'name': 'Australian Dollar (Free Market)',
      'nameFa': 'دلار استرالیا (بازار آزاد)',
      'cat': 'Currencies',
      'icon': '🇦🇺',
      'price': 172400.0,
      'unit': 'تومان',
    },
    {
      'symbol': 'CNY_TMN',
      'name': 'Chinese Yuan (Free Market)',
      'nameFa': 'یوان چین (بازار آزاد)',
      'cat': 'Currencies',
      'icon': '🇨🇳',
      'price': 37100.0,
      'unit': 'تومان',
    },
    {
      'symbol': 'CHF_TMN',
      'name': 'Swiss Franc (Free Market)',
      'nameFa': 'فرانک سوئیس (بازار آزاد)',
      'cat': 'Currencies',
      'icon': '🇨🇭',
      'price': 301500.0,
      'unit': 'تومان',
    },
    {
      'symbol': 'SAR_TMN',
      'name': 'Saudi Riyal (Free Market)',
      'nameFa': 'ریال عربستان سعودی',
      'cat': 'Currencies',
      'icon': '🇸🇦',
      'price': 71600.0,
      'unit': 'تومان',
    },
    {
      'symbol': 'KWD_TMN',
      'name': 'Kuwaiti Dinar (Free Market)',
      'nameFa': 'دینار کویت (بازار آزاد)',
      'cat': 'Currencies',
      'icon': '🇰🇼',
      'price': 876000.0,
      'unit': 'تومان',
    },
    {
      'symbol': 'BHD_TMN',
      'name': 'Bahraini Dinar (Free Market)',
      'nameFa': 'دینار بحرین',
      'cat': 'Currencies',
      'icon': '🇧🇭',
      'price': 713000.0,
      'unit': 'تومان',
    },
    {
      'symbol': 'OMR_TMN',
      'name': 'Omani Rial (Free Market)',
      'nameFa': 'ریال عمان',
      'cat': 'Currencies',
      'icon': '🇴🇲',
      'price': 698000.0,
      'unit': 'تومان',
    },
    {
      'symbol': 'QAR_TMN',
      'name': 'Qatari Riyal (Free Market)',
      'nameFa': 'ریال قطر',
      'cat': 'Currencies',
      'icon': '🇶🇦',
      'price': 73800.0,
      'unit': 'تومان',
    },
    {
      'symbol': 'IQD_TMN',
      'name': 'Iraqi Dinar (100 Dinars)',
      'nameFa': '۱۰۰ دینار عراق',
      'cat': 'Currencies',
      'icon': '🇮🇶',
      'price': 20500.0,
      'unit': 'تومان',
    },
    {
      'symbol': 'AFN_TMN',
      'name': 'Afghan Afghani (Free Market)',
      'nameFa': 'افغانی افغانستان',
      'cat': 'Currencies',
      'icon': '🇦🇫',
      'price': 3950.0,
      'unit': 'تومان',
    },
    {
      'symbol': 'RUB_TMN',
      'name': 'Russian Ruble (Free Market)',
      'nameFa': 'روبل روسیه',
      'cat': 'Currencies',
      'icon': '🇷🇺',
      'price': 2850.0,
      'unit': 'تومان',
    },
    {
      'symbol': 'INR_TMN',
      'name': 'Indian Rupee (Free Market)',
      'nameFa': 'روپیه هند',
      'cat': 'Currencies',
      'icon': '🇮🇳',
      'price': 3120.0,
      'unit': 'تومان',
    },
    {
      'symbol': 'JPY_TMN',
      'name': 'Japanese Yen (100 Yen)',
      'nameFa': '۱۰۰ ین ژاپن',
      'cat': 'Currencies',
      'icon': '🇯🇵',
      'price': 174000.0,
      'unit': 'تومان',
    },
    {
      'symbol': 'SEK_TMN',
      'name': 'Swedish Krona (Free Market)',
      'nameFa': 'کرون سوئد',
      'cat': 'Currencies',
      'icon': '🇸🇪',
      'price': 27500.0,
      'unit': 'تومان',
    },
    {
      'symbol': 'NOK_TMN',
      'name': 'Norwegian Krone (Free Market)',
      'nameFa': 'کرون نروژ',
      'cat': 'Currencies',
      'icon': '🇳🇴',
      'price': 25800.0,
      'unit': 'تومان',
    },
    {
      'symbol': 'AZN_TMN',
      'name': 'Azerbaijani Manat',
      'nameFa': 'منات آذربایجان',
      'cat': 'Currencies',
      'icon': '🇦🇿',
      'price': 158000.0,
      'unit': 'تومان',
    },
    {
      'symbol': 'GEL_TMN',
      'name': 'Georgian Lari',
      'nameFa': 'لاری گرجستان',
      'cat': 'Currencies',
      'icon': '🇬🇪',
      'price': 98500.0,
      'unit': 'تومان',
    },
    {
      'symbol': 'AMD_TMN',
      'name': 'Armenian Dram (1000 Dram)',
      'nameFa': '۱۰۰۰ درام ارمنستان',
      'cat': 'Currencies',
      'icon': '🇦🇲',
      'price': 69000.0,
      'unit': 'تومان',
    },

    // --- ۳. ارزهای رسمی و صرافی ملی (Official SANA & NIMA) ---
    {
      'symbol': 'SANA_USD',
      'name': 'SANA US Dollar (National Exchange)',
      'nameFa': 'دلار سامانه سنا (صرافی ملی)',
      'cat': 'Official',
      'icon': '🏛️',
      'price': 130650.0,
      'unit': 'تومان',
    },
    {
      'symbol': 'SANA_EUR',
      'name': 'SANA Euro (National Exchange)',
      'nameFa': 'یورو سامانه سنا (صرافی ملی)',
      'cat': 'Official',
      'icon': '🏛️',
      'price': 147500.0,
      'unit': 'تومان',
    },
    {
      'symbol': 'SANA_AED',
      'name': 'SANA UAE Dirham',
      'nameFa': 'درهم امارات سامانه سنا',
      'cat': 'Official',
      'icon': '🏛️',
      'price': 35570.0,
      'unit': 'تومان',
    },
    {
      'symbol': 'NIMA_USD',
      'name': 'NIMA US Dollar Remittance',
      'nameFa': 'دلار حواله سامانه نیما',
      'cat': 'Official',
      'icon': '🏢',
      'price': 176810.0,
      'unit': 'تومان',
    },
    {
      'symbol': 'NIMA_EUR',
      'name': 'NIMA Euro Remittance',
      'nameFa': 'یورو حواله سامانه نیما',
      'cat': 'Official',
      'icon': '🏢',
      'price': 199500.0,
      'unit': 'تومان',
    },
    {
      'symbol': 'NIMA_AED',
      'name': 'NIMA UAE Dirham Remittance',
      'nameFa': 'درهم امارات حواله نیما',
      'cat': 'Official',
      'icon': '🏢',
      'price': 48140.0,
      'unit': 'تومان',
    },

    // --- ۴. شاخص‌های بورس تهران (Bourse) ---
    {
      'symbol': 'TEDPIX',
      'name': 'Tehran Stock Exchange Index (TEDPIX)',
      'nameFa': 'شاخص کل بورس اوراق بهادار تهران',
      'cat': 'Bourse',
      'icon': '📊',
      'price': 2150000.0,
      'unit': 'واحد',
    },
    {
      'symbol': 'TEDPIX_EQUAL',
      'name': 'Tehran Equal-Weighted Index',
      'nameFa': 'شاخص کل هم‌وزن بورس تهران',
      'cat': 'Bourse',
      'icon': '📈',
      'price': 695000.0,
      'unit': 'واحد',
    },
  ];

  static final Map<String, String> _tgjuSlugMap = {
    'USD_TMN': 'price_dollar_rl',
    'EUR_TMN': 'price_eur',
    'GBP_TMN': 'price_gbp',
    'AED_TMN': 'price_aed',
    'TRY_TMN': 'price_try',
    'CAD_TMN': 'price_cad',
    'AUD_TMN': 'price_aud',
    'CNY_TMN': 'price_cny',
    'CHF_TMN': 'price_chf',
    'SAR_TMN': 'price_sar',
    'KWD_TMN': 'price_kwd',
    'BHD_TMN': 'price_bhd',
    'OMR_TMN': 'price_omr',
    'QAR_TMN': 'price_qar',
    'IQD_TMN': 'price_iqd',
    'AFN_TMN': 'price_afn',
    'RUB_TMN': 'price_rub',
    'INR_TMN': 'price_inr',
    'JPY_TMN': 'price_jpy',
    'SEK_TMN': 'price_sek',
    'NOK_TMN': 'price_nok',
    'AZN_TMN': 'price_azn',
    'GEL_TMN': 'price_gel',
    'AMD_TMN': 'price_amd',
    'GERAM18': 'geram18',
    'GERAM24': 'geram24',
    'MESGHAL': 'mesghal',
    'GOLD_USED': 'gold_mini_size',
    'GOLD_MELTED': 'gold_futures',
    'COIN_EMAMI': 'sekee',
    'COIN_BAHAR': 'sekeb',
    'COIN_HALF': 'nim',
    'COIN_QUARTER': 'rob',
    'COIN_GRAM': 'gerami',
    'SANA_USD': 'sana_sell_usd',
    'SANA_EUR': 'sana_sell_eur',
    'SANA_AED': 'sana_sell_aed',
    'NIMA_USD': 'nima_sell_usd',
    'NIMA_EUR': 'nima_sell_eur',
    'NIMA_AED': 'nima_sell_aed',
    'TEDPIX': 'bourse',
    'TEDPIX_EQUAL': 'bourse_equal',
  };

  @override
  Future<List<CurrencyPair>> fetchCurrencyPairs() async {
    return predefinedAssets.map((asset) {
      final sym = asset['symbol'] as String;
      final unit = asset['unit'] as String? ?? 'TMN';
      return CurrencyPair(
        baseCurrency: sym,
        counterCurrency: unit,
        marketSymbol: sym,
      );
    }).toList();
  }

  @override
  Future<PriceSnapshot> fetchSnapshot(CurrencyPair pair) async {
    final ticker = await fetchTicker(pair);
    return PriceSnapshot(
      price: ticker.lastPrice,
      volume: ticker.volume24h,
      fetchedAt: ticker.timestamp,
      asOf: ticker.asOf,
      state: ticker.state,
      quoteUnit: ticker.quoteUnit,
      source: ticker.source,
    );
  }

  @override
  Future<MarketTicker> fetchTicker(CurrencyPair pair) async {
    final sym = pair.baseCurrency.toUpperCase();
    final slug = _tgjuSlugMap[sym] ?? _tgjuSlugMap['${sym}_TMN'];

    // 1. Direct TGJU Profile query
    if (slug != null) {
      try {
        final url = Uri.parse('https://www.tgju.org/profile/$slug');
        final response = await _client.get(url, headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          'Accept': 'text/html',
        }).timeout(const Duration(seconds: 4));

        if (response.statusCode == 200) {
          final html = response.body;
          final regex = RegExp(r'>([0-9]{1,3}(?:,[0-9]{3})+)<');
          final matches = regex.allMatches(html);
          for (final m in matches) {
            final rawStr = m.group(1)?.replaceAll(',', '');
            if (rawStr != null) {
              final val = double.tryParse(rawStr);
              if (val != null && val > 100) {
                // If bourse index, value is index points
                final isBourse = sym.startsWith('TEDPIX');
                final finalPrice = isBourse ? val : (val / 10.0); // Convert RLS to TMN
                return MarketTicker(
                  exchangeId: id,
                  pair: pair,
                  lastPrice: finalPrice,
                  volume24h: 0.0,
                  timestamp: DateTime.now(),
                  asOf: DateTime.now(),
                  state: 'live',
                  quoteUnit: isBourse ? 'واحد' : 'تومان',
                  source: 'TGJU / بازار تهران',
                );
              }
            }
          }
        }
      } catch (e) {
        debugPrint('⚠️ [IranDomesticExchange] Direct fetch error for $sym: $e');
      }
    }

    // 2. Predefined fallback baseline
    final matched = predefinedAssets.firstWhere(
      (a) => a['symbol'] == sym,
      orElse: () => {'price': 0.0, 'unit': 'تومان'},
    );

    final baselinePrice = (matched['price'] as num?)?.toDouble() ?? 0.0;
    if (baselinePrice > 0) {
      return MarketTicker(
        exchangeId: id,
        pair: pair,
        lastPrice: baselinePrice,
        volume24h: 0.0,
        timestamp: DateTime.now(),
        asOf: DateTime.now(),
        state: 'delayed',
        quoteUnit: matched['unit'] as String? ?? 'تومان',
        source: 'بازار تهران (مظنه پایه)',
      );
    }

    throw Exception('خطا در دریافت قیمت لحظه‌ای $sym از بازار تهران');
  }

  void dispose() {
    _client.close();
  }
}
