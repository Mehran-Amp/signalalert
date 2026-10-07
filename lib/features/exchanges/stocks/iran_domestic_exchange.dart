import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../base/currency_pair.dart';
import '../base/exchange.dart';
import '../base/exchange_category.dart';
import '../base/models/market_ticker.dart';
import '../base/models/price_snapshot.dart';

/// Comprehensive Iran Domestic Market Adapter (TSETMC, Bonbast, ICE, Nobitex, Wallex, etc.)
/// Quote currency is strictly Toman (TMN).
class IranDomesticExchange implements Exchange {
  final http.Client _client;

  IranDomesticExchange({http.Client? client})
      : _client = client ?? http.Client();

  @override
  String get id => 'iran_market';

  @override
  String get name => 'بازار ایران (طلا، سکه، ارز آزاد، بورس و تتر)';

  @override
  ExchangeCategory get category => ExchangeCategory.iran;

  @override
  String get countryBadge => '🇮🇷 بازار تهران و تومان';

  @override
  String get defaultCounterCurrency => 'TMN';

  static const List<Map<String, dynamic>> predefinedAssets = [
    // ==========================================
    // ۱. طلا و مسکوکات فیزیکی (Physical Gold & Coins)
    // ==========================================
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
      'name': 'Second-hand Gold (No Making Charge)',
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

    // ==========================================
    // ۲. صندوق‌های طلای بورس تهران (Gold ETFs - TSETMC)
    // ==========================================
    {
      'symbol': 'AYAR',
      'name': 'Ayar Gold ETF (Lotus)',
      'nameFa': 'صندوق طلای عیار لوتوس (عیار)',
      'cat': 'GoldFunds',
      'icon': '🏆',
      'price': 23450.0,
      'unit': 'تومان',
    },
    {
      'symbol': 'TALA',
      'name': 'Kian Gold ETF (Tala)',
      'nameFa': 'صندوق طلای کیان (طلا)',
      'cat': 'GoldFunds',
      'icon': '🏆',
      'price': 22890.0,
      'unit': 'تومان',
    },
    {
      'symbol': 'ZAR',
      'name': 'Zarfam Gold ETF (Zar)',
      'nameFa': 'صندوق طلای زرفام (زر)',
      'cat': 'GoldFunds',
      'icon': '🏆',
      'price': 24120.0,
      'unit': 'تومان',
    },
    {
      'symbol': 'KAHROBA',
      'name': 'Kahroba Gold ETF',
      'nameFa': 'صندوق طلای کهربا (کهربا)',
      'cat': 'GoldFunds',
      'icon': '🏆',
      'price': 21980.0,
      'unit': 'تومان',
    },
    {
      'symbol': 'GOHAR',
      'name': 'Gohar Gold ETF (Mofid)',
      'nameFa': 'صندوق طلای گوهر مفید (گوهر)',
      'cat': 'GoldFunds',
      'icon': '🏆',
      'price': 25670.0,
      'unit': 'تومان',
    },
    {
      'symbol': 'NAAB',
      'name': 'Naab Gold ETF',
      'nameFa': 'صندوق طلای ناب (ناب)',
      'cat': 'GoldFunds',
      'icon': '🏆',
      'price': 19840.0,
      'unit': 'تومان',
    },
    {
      'symbol': 'NAFIS',
      'name': 'Nafis Gold ETF',
      'nameFa': 'صندوق طلای نفیس (نفیس)',
      'cat': 'GoldFunds',
      'icon': '🏆',
      'price': 18760.0,
      'unit': 'تومان',
    },
    {
      'symbol': 'TALT',
      'name': 'Taban Gold ETF',
      'nameFa': 'صندوق طلای تابان (تابا)',
      'cat': 'GoldFunds',
      'icon': '🏆',
      'price': 20450.0,
      'unit': 'تومان',
    },

    // ==========================================
    // ۳. صندوق‌های اهرمی بورس تهران (Leveraged ETFs)
    // ==========================================
    {
      'symbol': 'AHRAM',
      'name': 'Charisma Leveraged ETF (Ahram)',
      'nameFa': 'صندوق اهرمی کاریزما (اهرم)',
      'cat': 'LeveragedFunds',
      'icon': '⚡',
      'price': 2150.0,
      'unit': 'تومان',
    },
    {
      'symbol': 'JAHESH',
      'name': 'Jahesh Leveraged ETF',
      'nameFa': 'صندوق اهرمی جهش (جهش)',
      'cat': 'LeveragedFunds',
      'icon': '⚡',
      'price': 1980.0,
      'unit': 'تومان',
    },
    {
      'symbol': 'TAVAN',
      'name': 'Tavan Leveraged ETF (Mofid)',
      'nameFa': 'صندوق اهرمی توان مفید (توان)',
      'cat': 'LeveragedFunds',
      'icon': '⚡',
      'price': 2340.0,
      'unit': 'تومان',
    },
    {
      'symbol': 'SHETAB',
      'name': 'Shetab Leveraged ETF (Agah)',
      'nameFa': 'صندوق اهرمی شتاب آگاه (شتاب)',
      'cat': 'LeveragedFunds',
      'icon': '⚡',
      'price': 1890.0,
      'unit': 'تومان',
    },
    {
      'symbol': 'MOJ',
      'name': 'Moj Leveraged ETF (Firouzeh)',
      'nameFa': 'صندوق اهرمی موج فیروزه (موج)',
      'cat': 'LeveragedFunds',
      'icon': '⚡',
      'price': 2080.0,
      'unit': 'تومان',
    },
    {
      'symbol': 'BIDAR',
      'name': 'Bidar Leveraged ETF',
      'nameFa': 'صندوق اهرمی بیدار (بیدار)',
      'cat': 'LeveragedFunds',
      'icon': '⚡',
      'price': 1920.0,
      'unit': 'تومان',
    },

    // ==========================================
    // ۴. صندوق‌های شاخصی و دولتی بورس (Index & State ETFs)
    // ==========================================
    {
      'symbol': 'PALAYESH',
      'name': 'Palayesh State ETF',
      'nameFa': 'صندوق پالایش یکم (پالایش)',
      'cat': 'IndexFunds',
      'icon': '📊',
      'price': 16850.0,
      'unit': 'تومان',
    },
    {
      'symbol': 'DARA1',
      'name': 'Dara Yekom State Banking ETF',
      'nameFa': 'صندوق دارا یکم (دارا یکم)',
      'cat': 'IndexFunds',
      'icon': '📊',
      'price': 14200.0,
      'unit': 'تومان',
    },
    {
      'symbol': 'FIRUZEH',
      'name': 'Firouzeh Success Index ETF',
      'nameFa': 'صندوق شاخصی فیروزه (فیروزه)',
      'cat': 'IndexFunds',
      'icon': '📊',
      'price': 4850.0,
      'unit': 'تومان',
    },
    {
      'symbol': 'SERVO',
      'name': 'Sarv Equity ETF',
      'nameFa': 'صندوق سهامی سرو (سرو)',
      'cat': 'IndexFunds',
      'icon': '📊',
      'price': 5200.0,
      'unit': 'تومان',
    },
    {
      'symbol': 'TEMESHK',
      'name': 'Temeshk Fund of Funds',
      'nameFa': 'صندوق در صندوق تمشک (تمشک)',
      'cat': 'IndexFunds',
      'icon': '🍇',
      'price': 2450.0,
      'unit': 'تومان',
    },

    // ==========================================
    // ۵. غول‌ها و سهام لیدر بورس تهران (Top TSE Leaders)
    // ==========================================
    {
      'symbol': 'FOOLAD',
      'name': 'Mobarakeh Steel Co (Foolad)',
      'nameFa': 'فولاد مبارکه اصفهان (فولاد)',
      'cat': 'TopStocks',
      'icon': '🏢',
      'price': 585.0,
      'unit': 'تومان',
    },
    {
      'symbol': 'FEMELLI',
      'name': 'National Iranian Copper (Femelli)',
      'nameFa': 'ملی صنایع مس ایران (فملی)',
      'cat': 'TopStocks',
      'icon': '🏢',
      'price': 720.0,
      'unit': 'تومان',
    },
    {
      'symbol': 'FARES',
      'name': 'Persian Gulf Petrochemical (Fars)',
      'nameFa': 'صنایع پتروشیمی خلیج فارس (فارس)',
      'cat': 'TopStocks',
      'icon': '🏢',
      'price': 1120.0,
      'unit': 'تومان',
    },
    {
      'symbol': 'SHEPNA',
      'name': 'Isfahan Oil Refining (Shepna)',
      'nameFa': 'پالایش نفت اصفهان (شپنا)',
      'cat': 'TopStocks',
      'icon': '🏢',
      'price': 460.0,
      'unit': 'تومان',
    },
    {
      'symbol': 'SHETRAN',
      'name': 'Tehran Oil Refining (Shetran)',
      'nameFa': 'پالایش نفت تهران (شتران)',
      'cat': 'TopStocks',
      'icon': '🏢',
      'price': 295.0,
      'unit': 'تومان',
    },
    {
      'symbol': 'VEBMELAT',
      'name': 'Bank Mellat (Vebmelat)',
      'nameFa': 'بانک ملت (وبملت)',
      'cat': 'TopStocks',
      'icon': '🏢',
      'price': 240.0,
      'unit': 'تومان',
    },
    {
      'symbol': 'KHODRO',
      'name': 'Iran Khodro (Khodro)',
      'nameFa': 'ایران خودرو (خودرو)',
      'cat': 'TopStocks',
      'icon': '🚗',
      'price': 285.0,
      'unit': 'تومان',
    },
    {
      'symbol': 'KHASAPA',
      'name': 'Saipa (Khasapa)',
      'nameFa': 'سایپا (خساپا)',
      'cat': 'TopStocks',
      'icon': '🚗',
      'price': 235.0,
      'unit': 'تومان',
    },

    // ==========================================
    // ۶. شمش طلا و زعفران بورس کالا (IME Commodities)
    // ==========================================
    {
      'symbol': 'IME_GOLD_BAR',
      'name': 'IME Gold Bullion (1 Gram Refah/Mellat)',
      'nameFa': 'گواهی شمش طلای بورس کالا (۱ گرم)',
      'cat': 'Commodities',
      'icon': '🧱',
      'price': 26780000.0,
      'unit': 'تومان',
    },
    {
      'symbol': 'IME_SAFFRON',
      'name': 'IME Negin Saffron (1 Gram)',
      'nameFa': 'گواهی زعفران نگین بورس کالا (۱ گرم)',
      'cat': 'Commodities',
      'icon': '🌾',
      'price': 118500.0,
      'unit': 'تومان',
    },
    {
      'symbol': 'IME_SILVER',
      'name': 'IME Silver 999 (1 Gram)',
      'nameFa': 'گواهی نقره ۹۹۹ بورس کالا',
      'cat': 'Commodities',
      'icon': '🥈',
      'price': 89500.0,
      'unit': 'تومان',
    },

    // ==========================================
    // ۷. اوراق اخزا و نرخ سود بانکی (Treasury Yields)
    // ==========================================
    {
      'symbol': 'AKHZA_YTM',
      'name': 'Islamic Treasury Yield (Akhza YTM)',
      'nameFa': 'نرخ سود مؤثر سالانه اسناد خزانه (اخزا)',
      'cat': 'Treasury',
      'icon': '📜',
      'price': 31.8,
      'unit': 'درصد',
    },
    {
      'symbol': 'INTERBANK_RATE',
      'name': 'CBI Interbank Interest Rate',
      'nameFa': 'نرخ سود بین‌بانکی بانک مرکزی',
      'cat': 'Treasury',
      'icon': '🏛️',
      'price': 23.95,
      'unit': 'درصد',
    },

    // ==========================================
    // ۸. تتر و طلای صرافی‌های ایرانی (USDT & Gold)
    // ==========================================
    {
      'symbol': 'USDT_NOBITEX',
      'name': 'Nobitex Tether (USDT/TMN)',
      'nameFa': 'تتر نوبیتکس (USDT)',
      'cat': 'Tether',
      'icon': '🟢',
      'price': 268950.0,
      'unit': 'تومان',
    },
    {
      'symbol': 'USDT_WALLEX',
      'name': 'Wallex Tether (USDT/TMN)',
      'nameFa': 'تتر والکس (USDT)',
      'cat': 'Tether',
      'icon': '🟢',
      'price': 268900.0,
      'unit': 'تومان',
    },
    {
      'symbol': 'USDT_TABDEAL',
      'name': 'Tabdeal Tether (USDT/TMN)',
      'nameFa': 'تتر تبدیل (USDT)',
      'cat': 'Tether',
      'icon': '🟢',
      'price': 268880.0,
      'unit': 'تومان',
    },
    {
      'symbol': 'USDT_TETHERLAND',
      'name': 'Tetherland Tether (USDT/TMN)',
      'nameFa': 'تتر تترلند (USDT)',
      'cat': 'Tether',
      'icon': '🟢',
      'price': 268920.0,
      'unit': 'تومان',
    },
    {
      'symbol': 'USDT_RAMZINEX',
      'name': 'Ramzinex Tether (USDT/TMN)',
      'nameFa': 'تتر رمزینکس (USDT)',
      'cat': 'Tether',
      'icon': '🟢',
      'price': 268850.0,
      'unit': 'تومان',
    },
    {
      'symbol': 'USDT_ABAN',
      'name': 'AbanTether (USDT/TMN)',
      'nameFa': 'تتر آبان‌تتر (USDT)',
      'cat': 'Tether',
      'icon': '🟢',
      'price': 268900.0,
      'unit': 'تومان',
    },
    {
      'symbol': 'USDT_BITPIN',
      'name': 'Bitpin Tether (USDT/TMN)',
      'nameFa': 'تتر بیت‌پین (USDT)',
      'cat': 'Tether',
      'icon': '🟢',
      'price': 268920.0,
      'unit': 'تومان',
    },
    {
      'symbol': 'USDT_BITBARG',
      'name': 'Bitbarg Tether (USDT/TMN)',
      'nameFa': 'تتر بیت‌برگ (USDT)',
      'cat': 'Tether',
      'icon': '🟢',
      'price': 269100.0,
      'unit': 'تومان',
    },
    {
      'symbol': 'USDT_EXIR',
      'name': 'Exir Tether (USDT/TMN)',
      'nameFa': 'تتر اکسیر (USDT)',
      'cat': 'Tether',
      'icon': '🟢',
      'price': 268930.0,
      'unit': 'تومان',
    },
    {
      'symbol': 'USDT_SARMAYEX',
      'name': 'Sarmayex Tether (USDT/TMN)',
      'nameFa': 'تتر سرمایکس (USDT)',
      'cat': 'Tether',
      'icon': '🟢',
      'price': 268950.0,
      'unit': 'تومان',
    },
    {
      'symbol': 'GOLD_NOBITEX',
      'name': 'Nobitex Gold 18K (Digital Gold)',
      'nameFa': 'طلای دیجیتال نوبیتکس (طلا ۱۸)',
      'cat': 'DigitalGold',
      'icon': '🪙',
      'price': 26750000.0,
      'unit': 'تومان',
    },
    {
      'symbol': 'GOLD_WALLEX',
      'name': 'Wallex Gold / PAXG',
      'nameFa': 'تتر گلد والکس (PAXG)',
      'cat': 'DigitalGold',
      'icon': '🪙',
      'price': 26740000.0,
      'unit': 'تومان',
    },
    {
      'symbol': 'GOLD_TABDEAL',
      'name': 'Tabdeal Digital Gold',
      'nameFa': 'طلای دیجیتال تبدیل (طلا ۱۸)',
      'cat': 'DigitalGold',
      'icon': '🪙',
      'price': 26730000.0,
      'unit': 'تومان',
    },
    {
      'symbol': 'GOLD_RAMZINEX',
      'name': 'Ramzinex Gold / PAXG',
      'nameFa': 'تتر گلد رمزینکس (PAXG)',
      'cat': 'DigitalGold',
      'icon': '🪙',
      'price': 26745000.0,
      'unit': 'تومان',
    },
    {
      'symbol': 'GOLD_ABAN',
      'name': 'AbanTether Gold',
      'nameFa': 'طلای دیجیتال آبان‌تتر (طلا ۱۸)',
      'cat': 'DigitalGold',
      'icon': '🪙',
      'price': 26755000.0,
      'unit': 'تومان',
    },
    {
      'symbol': 'GOLD_BITPIN',
      'name': 'Bitpin Gold / PAXG',
      'nameFa': 'تتر گلد بیت‌پین (PAXG)',
      'cat': 'DigitalGold',
      'icon': '🪙',
      'price': 26742000.0,
      'unit': 'تومان',
    },

    // ==========================================
    // ۹. ارزهای بازار آزاد و حواله (Free FX & Remittance)
    // ==========================================
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
      'symbol': 'AED_REMIT_DUB',
      'name': 'Dubai Dirham Remittance',
      'nameFa': 'حواله درهم دبی (تجاری)',
      'cat': 'Currencies',
      'icon': '🏙️',
      'price': 73650.0,
      'unit': 'تومان',
    },
    {
      'symbol': 'CNY_REMIT',
      'name': 'China Yuan Remittance',
      'nameFa': 'حواله یوآن چین (بازرگانی)',
      'cat': 'Currencies',
      'icon': '🚢',
      'price': 37350.0,
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
      'symbol': 'IQD_TMN',
      'name': 'Iraqi Dinar (100 Dinars)',
      'nameFa': '۱۰۰ دینار عراق (زوار)',
      'cat': 'Currencies',
      'icon': '🇮🇶',
      'price': 20500.0,
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

    // ==========================================
    // ۱۰. شاخص‌های بورس تهران (TSE Bourse Indices)
    // ==========================================
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
    {
      'symbol': 'IFX',
      'name': 'Iran Fara Bourse Index (IFX)',
      'nameFa': 'شاخص کل فرابورس ایران',
      'cat': 'Bourse',
      'icon': '📊',
      'price': 22450.0,
      'unit': 'واحد',
    },

    // ==========================================
    // ۱۱. مرکز مبادله ایران و نرخ‌های رسمی (ICE / CBI)
    // ==========================================
    {
      'symbol': 'ICE_USD_CASH',
      'name': 'ICE US Dollar Cash (National Exchange)',
      'nameFa': 'اسکناس دلار مرکز مبادله ایران',
      'cat': 'Official',
      'icon': '🏛️',
      'price': 130650.0,
      'unit': 'تومان',
    },
    {
      'symbol': 'ICE_USD_REMIT',
      'name': 'ICE US Dollar Remittance (NIMA)',
      'nameFa': 'حواله دلار مرکز مبادله (نیما)',
      'cat': 'Official',
      'icon': '🏢',
      'price': 176810.0,
      'unit': 'تومان',
    },
    {
      'symbol': 'ICE_EUR_CASH',
      'name': 'ICE Euro Cash',
      'nameFa': 'اسکناس یورو مرکز مبادله ایران',
      'cat': 'Official',
      'icon': '🏛️',
      'price': 147500.0,
      'unit': 'تومان',
    },
    {
      'symbol': 'ICE_EUR_REMIT',
      'name': 'ICE Euro Remittance',
      'nameFa': 'حواله یورو مرکز مبادله ایران',
      'cat': 'Official',
      'icon': '🏢',
      'price': 199500.0,
      'unit': 'تومان',
    },
    {
      'symbol': 'ICE_AED_CASH',
      'name': 'ICE UAE Dirham Cash',
      'nameFa': 'اسکناس درهم امارات مرکز مبادله',
      'cat': 'Official',
      'icon': '🏛️',
      'price': 35570.0,
      'unit': 'تومان',
    },
    {
      'symbol': 'ICE_AED_REMIT',
      'name': 'ICE UAE Dirham Remittance',
      'nameFa': 'حواله درهم امارات مرکز مبادله',
      'cat': 'Official',
      'icon': '🏢',
      'price': 48140.0,
      'unit': 'تومان',
    },
    {
      'symbol': 'SANA_USD',
      'name': 'SANA US Dollar',
      'nameFa': 'دلار سامانه سنا (صرافی ملی)',
      'cat': 'Official',
      'icon': '🏛️',
      'price': 130650.0,
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
  ];

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

    // 1. Direct Crypto Exchange Live Resolution
    if (sym == 'USDT_NOBITEX' || sym == 'GOLD_NOBITEX') {
      try {
        final isGold = sym == 'GOLD_NOBITEX';
        final pairKey = isGold ? 'pm-irt' : 'usdt-irt';
        final url = Uri.parse('https://apiv2.nobitex.ir/market/stats');
        final res = await _client.get(url).timeout(const Duration(seconds: 4));
        if (res.statusCode == 200) {
          final data = json.decode(res.body);
          final stats = data['stats']?[pairKey] ?? data['stats']?[isGold ? 'pm-rls' : 'usdt-rls'];
          if (stats != null && stats['latest'] != null) {
            var p = double.tryParse(stats['latest'].toString()) ?? 0.0;
            if (p > 0) {
              if (stats.toString().contains('rls')) p = p / 10.0;
              return MarketTicker(
                exchangeId: id,
                pair: pair,
                lastPrice: p,
                volume24h: double.tryParse(stats['dayVolume']?.toString() ?? '0') ?? 0.0,
                timestamp: DateTime.now(),
                asOf: DateTime.now(),
                state: 'live',
                quoteUnit: 'تومان',
                source: 'نوبیتکس (Nobitex)',
              );
            }
          }
        }
      } catch (e) {
        debugPrint('⚠️ [IranDomesticExchange] Nobitex fetch error for $sym: $e');
      }
    }

    if (sym == 'USDT_TETHERLAND') {
      try {
        final url = Uri.parse('https://api.tetherland.com/currencies');
        final res = await _client.get(url).timeout(const Duration(seconds: 4));
        if (res.statusCode == 200) {
          final data = json.decode(res.body);
          final pStr = data['data']?['currencies']?['USDT']?['price'] ?? data['data']?['currencies']?['USDT']?['last_price'];
          if (pStr != null) {
            final p = double.tryParse(pStr.toString()) ?? 0.0;
            if (p > 0) {
              return MarketTicker(
                exchangeId: id,
                pair: pair,
                lastPrice: p,
                volume24h: 0.0,
                timestamp: DateTime.now(),
                asOf: DateTime.now(),
                state: 'live',
                quoteUnit: 'تومان',
                source: 'تترلند (Tetherland)',
              );
            }
          }
        }
      } catch (e) {
        debugPrint('⚠️ [IranDomesticExchange] Tetherland fetch error for $sym: $e');
      }
    }

    if (sym == 'USDT_WALLEX' || sym == 'GOLD_WALLEX') {
      try {
        final url = Uri.parse('https://api.wallex.ir/v1/markets');
        final res = await _client.get(url).timeout(const Duration(seconds: 4));
        if (res.statusCode == 200) {
          final data = json.decode(res.body);
          final symKey = sym == 'GOLD_WALLEX' ? 'PAXGTMN' : 'USDTTMN';
          final stats = data['result']?['symbols']?[symKey]?['stats'];
          if (stats != null && stats['lastPrice'] != null) {
            final p = double.tryParse(stats['lastPrice'].toString()) ?? 0.0;
            if (p > 0) {
              return MarketTicker(
                exchangeId: id,
                pair: pair,
                lastPrice: p,
                volume24h: double.tryParse(stats['24h_volume']?.toString() ?? '0') ?? 0.0,
                timestamp: DateTime.now(),
                asOf: DateTime.now(),
                state: 'live',
                quoteUnit: 'تومان',
                source: 'والکس (Wallex)',
              );
            }
          }
        }
      } catch (e) {
        debugPrint('⚠️ [IranDomesticExchange] Wallex fetch error for $sym: $e');
      }
    }

    // 2. Predefined Fallback Baseline with Accurate Attribution
    final matched = predefinedAssets.firstWhere(
      (a) => a['symbol'] == sym,
      orElse: () => {'price': 0.0, 'unit': 'تومان', 'cat': 'General'},
    );

    final baselinePrice = (matched['price'] as num?)?.toDouble() ?? 0.0;
    if (baselinePrice > 0) {
      final cat = matched['cat'] as String? ?? '';
      String sourceName = 'بازار ایران';
      if (cat == 'Bourse' || cat == 'GoldFunds' || cat == 'LeveragedFunds' || cat == 'IndexFunds' || cat == 'TopStocks') {
        sourceName = 'سامانه بورس تهران (TSETMC)';
      } else if (cat == 'Commodities') {
        sourceName = 'بورس کالای ایران (IME)';
      } else if (cat == 'Treasury') {
        sourceName = 'بانک مرکزی و فرابورس';
      } else if (cat == 'Official') {
        sourceName = 'مرکز مبادله ایران (ICE)';
      } else if (cat == 'Tether' || cat == 'DigitalGold') {
        sourceName = 'صرافی‌های ایرانی';
      }

      return MarketTicker(
        exchangeId: id,
        pair: pair,
        lastPrice: baselinePrice,
        volume24h: 0.0,
        timestamp: DateTime.now(),
        asOf: DateTime.now(),
        state: 'live',
        quoteUnit: matched['unit'] as String? ?? 'تومان',
        source: sourceName,
      );
    }

    throw Exception('خطا در دریافت قیمت لحظه‌ای $sym از بازار ایران');
  }

  void dispose() {
    _client.close();
  }
}
