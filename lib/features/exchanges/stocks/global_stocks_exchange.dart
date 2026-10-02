import 'dart:convert';
import 'package:http/http.dart' as http;
import '../base/currency_pair.dart';
import '../base/exchange.dart';
import '../base/exchange_category.dart';
import '../base/models/market_ticker.dart';
import '../base/models/price_snapshot.dart';

/// Comprehensive Global Stock Markets, Commodities, Forex, Crypto Macro & Top 100 Companies Adapter
class GlobalStocksExchange implements Exchange {
  final http.Client _client;

  GlobalStocksExchange({http.Client? client})
      : _client = client ?? http.Client();

  @override
  String get id => 'global_stocks';

  @override
  String get name => 'بازارهای جهانی، بورس و شاخص‌های کلان (Macro / Top 100 / Forex / Commodities)';

  @override
  ExchangeCategory get category => ExchangeCategory.all;

  @override
  String get countryBadge => '🏛️ Global Equities & Commodities';

  @override
  String get defaultCounterCurrency => 'USD';

  static const List<Map<String, dynamic>> predefinedStocks = [
    // =========================================================================
    // 1. CRYPTO MACRO & DOMINANCE INDICES (شاخص‌های کلان کریپتو و دامیننس)
    // =========================================================================
    {
      'symbol': 'TOTAL',
      'name': 'Crypto Total Market Cap (TOTAL)',
      'nameFa': 'شاخص کل ارزش بازار کریپتو (TOTAL)',
      'cat': 'CryptoMacro',
      'icon': '🌐',
      'price': 2450.0, // Billion USD
    },
    {
      'symbol': 'TOTAL2',
      'name': 'Crypto Market Cap Excl. BTC (TOTAL2)',
      'nameFa': 'شاخص بازار کریپتو منهای بیت‌کوین (TOTAL2)',
      'cat': 'CryptoMacro',
      'icon': '🔷',
      'price': 1080.0, // Billion USD
    },
    {
      'symbol': 'TOTAL3',
      'name': 'Altcoin Market Cap Excl. BTC & ETH (TOTAL3)',
      'nameFa': 'شاخص آلت‌کوین‌ها منهای بیت‌کوین و اتریوم (TOTAL3)',
      'cat': 'CryptoMacro',
      'icon': '🚀',
      'price': 685.0, // Billion USD
    },
    {
      'symbol': 'BTC.D',
      'name': 'Bitcoin Dominance Index (BTC.D)',
      'nameFa': 'شاخص دامیننس و سهم بازار بیت‌کوین (BTC.D %)',
      'cat': 'CryptoMacro',
      'icon': '₿',
      'price': 58.60, // %
    },
    {
      'symbol': 'USDT.D',
      'name': 'Tether Dominance Index (USDT.D)',
      'nameFa': 'شاخص دامیننس تتر و نقدینگی دلاری (USDT.D %)',
      'cat': 'CryptoMacro',
      'icon': '💵',
      'price': 5.15, // %
    },
    {
      'symbol': 'ETH.D',
      'name': 'Ethereum Dominance Index (ETH.D)',
      'nameFa': 'شاخص دامیننس و سهم بازار اتریوم (ETH.D %)',
      'cat': 'CryptoMacro',
      'icon': '⟠',
      'price': 14.30, // %
    },
    {
      'symbol': 'CRYPTO_FGI',
      'name': 'Crypto Fear & Greed Index',
      'nameFa': 'شاخص احساسات، ترس و طمع کریپتو (0-100)',
      'cat': 'CryptoMacro',
      'icon': '🧭',
      'price': 68.0,
    },

    // =========================================================================
    // 2. MACRO BENCHMARKS, YIELDS & DXY (اوراق قرضه، شاخص دلار و نوسان)
    // =========================================================================
    {
      'symbol': 'DX-Y.NYB',
      'name': 'US Dollar Index (DXY)',
      'nameFa': 'شاخص قدرت جهانی دلار آمریکا (DXY)',
      'cat': 'Macro',
      'icon': '💵',
      'price': 104.25,
    },
    {
      'symbol': '^TNX',
      'name': 'US 10-Year Treasury Yield',
      'nameFa': 'نرخ بازدهی اوراق ۱۰ ساله آمریکا (US10Y)',
      'cat': 'Macro',
      'icon': '📈',
      'price': 4.28,
    },
    {
      'symbol': '^IRX',
      'name': 'US 2-Year Treasury Yield',
      'nameFa': 'نرخ بازدهی اوراق ۲ ساله آمریکا (US02Y)',
      'cat': 'Macro',
      'icon': '📊',
      'price': 4.15,
    },
    {
      'symbol': '^TYX',
      'name': 'US 30-Year Treasury Bond',
      'nameFa': 'اوراق قرضه ۳۰ ساله بلندمدت آمریکا (US30Y)',
      'cat': 'Macro',
      'icon': '🏛️',
      'price': 4.52,
    },
    {
      'symbol': '^FVX',
      'name': 'US 5-Year Treasury Yield',
      'nameFa': 'نرخ بازدهی اوراق ۵ ساله آمریکا (US05Y)',
      'cat': 'Macro',
      'icon': '📉',
      'price': 4.18,
    },
    {
      'symbol': '^VIX',
      'name': 'CBOE Volatility Index (VIX)',
      'nameFa': 'شاخص نوسان و ترس وال‌استریت (VIX)',
      'cat': 'Macro',
      'icon': '⚡',
      'price': 18.50,
    },

    // =========================================================================
    // 3. GLOBAL STOCK INDICES (شاخص‌های برتر بورس‌های جهان)
    // =========================================================================
    {
      'symbol': '^GSPC',
      'name': 'S&P 500 Index',
      'nameFa': 'شاخص ۵۰۰ شرکت برتر آمریکا (S&P 500)',
      'cat': 'Indices',
      'icon': '🇺🇸',
      'price': 5864.67,
    },
    {
      'symbol': '^NDX',
      'name': 'NASDAQ 100 Index',
      'nameFa': 'شاخص ۱۰۰ شرکت برتر فناوری (NASDAQ 100)',
      'cat': 'Indices',
      'icon': '💻',
      'price': 20380.50,
    },
    {
      'symbol': '^DJI',
      'name': 'Dow Jones Industrial Average',
      'nameFa': 'شاخص صنعتی داوجونز (Dow Jones 30)',
      'cat': 'Indices',
      'icon': '🏭',
      'price': 42931.60,
    },
    {
      'symbol': '^RUT',
      'name': 'Russell 2000 Index',
      'nameFa': 'شاخص ۲۰۰۰ شرکت کوچک و چابک آمریکا (Russell 2000)',
      'cat': 'Indices',
      'icon': '🏢',
      'price': 2250.40,
    },
    {
      'symbol': '^GDAXI',
      'name': 'DAX 40 Germany',
      'nameFa': 'شاخص بورس آلمان (DAX 40)',
      'cat': 'Indices',
      'icon': '🇩🇪',
      'price': 19450.20,
    },
    {
      'symbol': '^FTSE',
      'name': 'FTSE 100 UK',
      'nameFa': 'شاخص بورس لندن (FTSE 100)',
      'cat': 'Indices',
      'icon': '🇬🇧',
      'price': 8250.80,
    },
    {
      'symbol': '^FCHI',
      'name': 'CAC 40 France',
      'nameFa': 'شاخص بورس پاریس (CAC 40)',
      'cat': 'Indices',
      'icon': '🇫🇷',
      'price': 7510.30,
    },

    // =========================================================================
    // 4. CHINA & ASIAN BENCHMARKS & GIANTS (بازارها، شاخص‌ها و غول‌های چین و آسیا)
    // =========================================================================
    {
      'symbol': '000001.SS',
      'name': 'Shanghai Composite Index',
      'nameFa': 'شاخص کل بورس شانگهای چین (SSE)',
      'cat': 'China',
      'icon': '🇨🇳',
      'price': 3290.15,
    },
    {
      'symbol': '399001.SZ',
      'name': 'Shenzhen Component Index',
      'nameFa': 'شاخص بورس شنژن چین (SZSE)',
      'cat': 'China',
      'icon': '🇨🇳',
      'price': 10580.40,
    },
    {
      'symbol': '^HSI',
      'name': 'Hang Seng Index Hong Kong',
      'nameFa': 'شاخص بورس هنگ‌کنگ (Hang Seng)',
      'cat': 'China',
      'icon': '🇭🇰',
      'price': 20680.40,
    },
    {
      'symbol': 'FXI',
      'name': 'iShares China Large-Cap ETF',
      'nameFa': 'صندوق ۵۰ شرکت غول‌پیکر چین (FXI ETF)',
      'cat': 'China',
      'icon': '🇨🇳',
      'price': 31.85,
    },
    {
      'symbol': 'KWEB',
      'name': 'KraneShares CSI China Internet ETF',
      'nameFa': 'صندوق شرکت‌های اینترنتی و کلاد چین (KWEB)',
      'cat': 'China',
      'icon': '🌐',
      'price': 32.40,
    },
    {
      'symbol': 'BYDDY',
      'name': 'BYD Company ADR',
      'nameFa': 'بی‌وای‌دی (بزرگ‌ترین خودروساز برقی جهان)',
      'cat': 'China',
      'icon': '🔋',
      'price': 72.80,
    },
    {
      'symbol': 'LI',
      'name': 'Li Auto Inc.',
      'nameFa': 'لی اتو (شاسی‌بلندهای هوشمند هیبریدی چین)',
      'cat': 'China',
      'icon': '🚗',
      'price': 29.40,
    },
    {
      'symbol': 'XPEV',
      'name': 'XPeng Inc.',
      'nameFa': 'ایکس‌پنگ (خودروهای تمام‌برقی و هوش مصنوعی پروازی)',
      'cat': 'China',
      'icon': '🚘',
      'price': 11.60,
    },
    {
      'symbol': 'XIACY',
      'name': 'Xiaomi Corporation ADR',
      'nameFa': 'شیائومی (گوشی‌های هوشمند و خودرو برقی SU7)',
      'cat': 'China',
      'icon': '📱',
      'price': 16.80,
    },
    {
      'symbol': 'NTES',
      'name': 'NetEase Inc.',
      'nameFa': 'نت‌ایز (غول سرگرمی دیجیتال و هوش مصنوعی چین)',
      'cat': 'China',
      'icon': '🎲',
      'price': 84.50,
    },
    {
      'symbol': 'SMICY',
      'name': 'SMIC Semiconductor ADR',
      'nameFa': 'اس‌ام‌آی‌سی (بزرگ‌ترین کارخانه تراشه‌سازی چین)',
      'cat': 'China',
      'icon': '🔬',
      'price': 18.20,
    },
    {
      'symbol': 'BILI',
      'name': 'Bilibili Inc.',
      'nameFa': 'بیلی‌بیلی (یوتیوب چین و استریم ویدیو)',
      'cat': 'China',
      'icon': '📺',
      'price': 19.80,
    },
    {
      'symbol': '^N225',
      'name': 'Nikkei 225 Japan',
      'nameFa': 'شاخص بورس توکیو ژاپن (Nikkei 225)',
      'cat': 'China',
      'icon': '🇯🇵',
      'price': 38980.00,
    },
    {
      'symbol': '^KS11',
      'name': 'KOSPI South Korea',
      'nameFa': 'شاخص بورس کره جنوبی (KOSPI)',
      'cat': 'China',
      'icon': '🇰🇷',
      'price': 2610.50,
    },
    {
      'symbol': '^TWII',
      'name': 'Taiwan Weighted Index',
      'nameFa': 'شاخص کل بورس تایوان (TWSE)',
      'cat': 'China',
      'icon': '🇹🇼',
      'price': 23200.00,
    },

    // =========================================================================
    // 5. PRECIOUS METALS & COMMODITIES (طلا، نقره، نفت و فلزات صنعتی)
    // =========================================================================
    {
      'symbol': 'GC=F',
      'name': 'Gold Spot (XAU/USD)',
      'nameFa': 'انس طلای جهانی (Gold XAU/USD)',
      'cat': 'Commodities',
      'icon': '🥇',
      'price': 2735.40,
    },
    {
      'symbol': 'SI=F',
      'name': 'Silver Spot (XAG/USD)',
      'nameFa': 'انس نقره جهانی (Silver XAG/USD)',
      'cat': 'Commodities',
      'icon': '🥈',
      'price': 33.85,
    },
    {
      'symbol': 'PL=F',
      'name': 'Platinum Futures',
      'nameFa': 'انس پلاتین جهانی (Platinum)',
      'cat': 'Commodities',
      'icon': '⚪',
      'price': 1025.50,
    },
    {
      'symbol': 'PA=F',
      'name': 'Palladium Futures',
      'nameFa': 'انس پالادیوم جهانی (Palladium)',
      'cat': 'Commodities',
      'icon': '✨',
      'price': 1140.00,
    },
    {
      'symbol': 'BZ=F',
      'name': 'Brent Crude Oil',
      'nameFa': 'نفت خام برنت دریای شمال (Brent)',
      'cat': 'Commodities',
      'icon': '🛢️',
      'price': 75.40,
    },
    {
      'symbol': 'CL=F',
      'name': 'Crude Oil WTI',
      'nameFa': 'نفت خام سبک تگزاس (WTI Oil)',
      'cat': 'Commodities',
      'icon': '⛽',
      'price': 71.20,
    },
    {
      'symbol': 'NG=F',
      'name': 'Natural Gas Futures',
      'nameFa': 'گاز طبیعی جهانی (Natural Gas)',
      'cat': 'Commodities',
      'icon': '🔥',
      'price': 2.85,
    },
    {
      'symbol': 'HG=F',
      'name': 'Copper Futures (Dr. Copper)',
      'nameFa': 'مس صنعتی جهانی (دماسنج اقتصاد)',
      'cat': 'Commodities',
      'icon': '🥉',
      'price': 4.42,
    },

    // =========================================================================
    // 6. FOREX MAJORS & CROSSES (فارکس و برابری ارزهای بین‌المللی)
    // =========================================================================
    {
      'symbol': 'EURUSD=X',
      'name': 'EUR/USD',
      'nameFa': 'یورو به دلار آمریکا (EUR/USD)',
      'cat': 'Forex',
      'icon': '🇪🇺',
      'price': 1.0825,
    },
    {
      'symbol': 'GBPUSD=X',
      'name': 'GBP/USD (Cable)',
      'nameFa': 'پوند انگلیس به دلار آمریکا (GBP/USD)',
      'cat': 'Forex',
      'icon': '🇬🇧',
      'price': 1.2980,
    },
    {
      'symbol': 'USDJPY=X',
      'name': 'USD/JPY',
      'nameFa': 'دلار آمریکا به ین ژاپن (USD/JPY)',
      'cat': 'Forex',
      'icon': '🇯🇵',
      'price': 153.40,
    },
    {
      'symbol': 'USDCHF=X',
      'name': 'USD/CHF (Swissie)',
      'nameFa': 'دلار آمریکا به فرانک سوئیس (USD/CHF)',
      'cat': 'Forex',
      'icon': '🇨🇭',
      'price': 0.8670,
    },
    {
      'symbol': 'AUDUSD=X',
      'name': 'AUD/USD (Aussie)',
      'nameFa': 'دلار استرالیا به دلار آمریکا (AUD/USD)',
      'cat': 'Forex',
      'icon': '🇦🇺',
      'price': 0.6620,
    },
    {
      'symbol': 'USDCAD=X',
      'name': 'USD/CAD (Loonie)',
      'nameFa': 'دلار آمریکا به دلار کانادا (USD/CAD)',
      'cat': 'Forex',
      'icon': '🇨🇦',
      'price': 1.3850,
    },
    {
      'symbol': 'NZDUSD=X',
      'name': 'NZD/USD (Kiwi)',
      'nameFa': 'دلار نیوزیلند به دلار آمریکا (NZD/USD)',
      'cat': 'Forex',
      'icon': '🇳🇿',
      'price': 0.6010,
    },
    {
      'symbol': 'EURJPY=X',
      'name': 'EUR/JPY',
      'nameFa': 'یورو به ین ژاپن (EUR/JPY)',
      'cat': 'Forex',
      'icon': '💱',
      'price': 166.10,
    },
    {
      'symbol': 'GBPJPY=X',
      'name': 'GBP/JPY (Guppy)',
      'nameFa': 'پوند انگلیس به ین ژاپن (GBP/JPY)',
      'cat': 'Forex',
      'icon': '💱',
      'price': 199.20,
    },
    {
      'symbol': 'EURGBP=X',
      'name': 'EUR/GBP',
      'nameFa': 'یورو به پوند انگلیس (EUR/GBP)',
      'cat': 'Forex',
      'icon': '💱',
      'price': 0.8340,
    },
    {
      'symbol': 'USDCNH=X',
      'name': 'USD/CNH',
      'nameFa': 'دلار آمریکا به یوان چین فراساحلی (USD/CNH)',
      'cat': 'Forex',
      'icon': '🇨🇳',
      'price': 7.1420,
    },
    {
      'symbol': 'USDTRY=X',
      'name': 'USD/TRY',
      'nameFa': 'دلار آمریکا به لیر ترکیه (USD/TRY)',
      'cat': 'Forex',
      'icon': '🇹🇷',
      'price': 34.28,
    },

    // =========================================================================
    // 7. AEROSPACE, DEFENSE & COMMERCIAL SPACE (فضا، استارلینک، ماهواره و هوافضا)
    // =========================================================================
    {
      'symbol': 'SPACEX',
      'name': 'SpaceX (Space Exploration Technologies & Starlink)',
      'nameFa': 'اسپیس‌ایکس (فناوری‌های فضایی، موشک استارشیپ و اینترنت ماهواره‌ای استارلینک)',
      'cat': 'Aerospace',
      'icon': '🚀',
      'price': 112.0,
      'isTop100': true,
    },
    {
      'symbol': 'DXYZ',
      'name': 'Destiny Tech100 Inc. (SpaceX & OpenAI Portfolio ETF)',
      'nameFa': 'صندوق سرنوشت ۱۰۰ (سبد سهام عمومی اسپیس‌ایکس و اوپن‌ای‌آی در بورس نیویورک)',
      'cat': 'Aerospace',
      'icon': '🌌',
      'price': 18.50,
    },
    {
      'symbol': 'RKLB',
      'name': 'Rocket Lab USA Inc.',
      'nameFa': 'راکت لب (پرتاب‌های فضایی مداری تجاری و ماهواره‌های ناسا)',
      'cat': 'Aerospace',
      'icon': '🛰️',
      'price': 10.45,
    },
    {
      'symbol': 'ASTS',
      'name': 'AST SpaceMobile Inc.',
      'nameFa': 'ای‌اس‌تی اسپیس‌موبایل (شبکه پهن‌باند ماهواره‌ای مستقیم به گوشی‌های هوشمند)',
      'cat': 'Aerospace',
      'icon': '📡',
      'price': 26.80,
    },
    {
      'symbol': 'LUNR',
      'name': 'Intuitive Machines Inc.',
      'nameFa': 'اینتیوتیو ماشینز (فرودگرهای رباتیک ماه و ماموریت‌های آرتمیس ناسا)',
      'cat': 'Aerospace',
      'icon': '🌕',
      'price': 8.35,
    },
    {
      'symbol': 'BA',
      'name': 'The Boeing Company',
      'nameFa': 'بوئینگ (غول هواپیماسازی، فضاپیما و کپسول فضایی استارلاینر)',
      'cat': 'Aerospace',
      'icon': '✈️',
      'price': 155.20,
      'isTop100': true,
    },
    {
      'symbol': 'NOC',
      'name': 'Northrop Grumman Corporation',
      'nameFa': 'نورثروپ گرومن (تلسکوپ فضایی جیمز وب، بمب‌افکن B-21 و سامانه‌های فضایی)',
      'cat': 'Aerospace',
      'icon': '🛡️',
      'price': 512.40,
    },
    {
      'symbol': 'SPCE',
      'name': 'Virgin Galactic Holdings Inc.',
      'nameFa': 'ویرجین گلکتیک (گردشگری فضایی تجاری زیرمداری)',
      'cat': 'Aerospace',
      'icon': '👨‍🚀',
      'price': 7.15,
    },

    // =========================================================================
    // 8. PRE-IPO UNICORNS & FRONTIER AI GIANTS (غول‌های فناوری خصوصی و پیش‌عرضه اولیه)
    // =========================================================================
    {
      'symbol': 'OPENAI',
      'name': 'OpenAI (ChatGPT & Frontier AI Labs Benchmark)',
      'nameFa': 'اوپن‌ای‌آی (خالق چت‌جی‌پی‌تی و پیشتاز جهانی هوش مصنوعی عمومی AGI)',
      'cat': 'PreIPO',
      'icon': '🧠',
      'price': 150.0,
      'isTop100': true,
    },
    {
      'symbol': 'ANTHROPIC',
      'name': 'Anthropic (Claude AI Research & Safety)',
      'nameFa': 'انتروپیک (خالق هوش مصنوعی کلود Claude و مدل‌های پیشرفته ایمن زبانی)',
      'cat': 'PreIPO',
      'icon': '🤖',
      'price': 85.0,
    },
    {
      'symbol': 'STRIPE',
      'name': 'Stripe Inc. (Global Payments & Crypto Rails)',
      'nameFa': 'استریپ (بزرگ‌ترین زیرساخت پرداخت اینترنتی و تسویه مالی جهان)',
      'cat': 'PreIPO',
      'icon': '💳',
      'price': 32.50,
    },
    {
      'symbol': 'BYTEDANCE',
      'name': 'ByteDance Ltd. (TikTok & Douyin Global)',
      'nameFa': 'بایت‌دنس (مالک تیک‌تاک و غول الگوریتم‌های هوش مصنوعی و ویدیو)',
      'cat': 'PreIPO',
      'icon': '🎵',
      'price': 175.0,
    },
    {
      'symbol': 'DATABRICKS',
      'name': 'Databricks Inc. (Data Intelligence & Apache Spark)',
      'nameFa': 'دیتابریکس (پلتفرم یکپارچه داده، دریاچه داده و هوش مصنوعی شرکتی)',
      'cat': 'PreIPO',
      'icon': '🧱',
      'price': 78.0,
    },

    // =========================================================================
    // 9. CRYPTO MINING, BLOCKCHAIN TREASURY & FINTECH (استخراج بیت‌کوین و فین‌تک)
    // =========================================================================
    {
      'symbol': 'MARA',
      'name': 'MARA Holdings Inc. (Marathon Digital)',
      'nameFa': 'ماراتون دیجیتال / MARA (بزرگ‌ترین شرکت عمومی استخراج و خزانه‌داری بیت‌کوین)',
      'cat': 'FintechMining',
      'icon': '⛏️',
      'price': 18.90,
    },
    {
      'symbol': 'RIOT',
      'name': 'Riot Platforms Inc.',
      'nameFa': 'رایوت پلتفرمز (زیرساخت دیتاسنتر و مزارع استخراج بیت‌کوین)',
      'cat': 'FintechMining',
      'icon': '⚡',
      'price': 9.85,
    },
    {
      'symbol': 'CLSK',
      'name': 'CleanSpark Inc.',
      'nameFa': 'کلین‌اسپارک (استخراج سبز و پربازده بیت‌کوین با انرژی پاک)',
      'cat': 'FintechMining',
      'icon': '🔋',
      'price': 12.40,
    },
    {
      'symbol': 'HOOD',
      'name': 'Robinhood Markets Inc.',
      'nameFa': 'رابین‌هود (کارگزاری پیشرو معامله سهام، آپشن و کریپتو)',
      'cat': 'FintechMining',
      'icon': '🏹',
      'price': 27.30,
    },
    {
      'symbol': 'RDDT',
      'name': 'Reddit Inc.',
      'nameFa': 'ردیت (انجمن بزرگ گفتگوی وب و مرجع داده‌های آموزش هوش مصنوعی)',
      'cat': 'FintechMining',
      'icon': '🤖',
      'price': 82.60,
    },
    {
      'symbol': 'SHOP',
      'name': 'Shopify Inc.',
      'nameFa': 'شاپیفای (غول تجارت الکترونیک و فروشگاه‌ساز آنلاین جهانی)',
      'cat': 'Top100',
      'icon': '🛍️',
      'price': 81.40,
      'isTop100': true,
    },
    {
      'symbol': 'SNOW',
      'name': 'Snowflake Inc.',
      'nameFa': 'اسنوفلیک (انبار داده‌های کلاد ابری و تحلیل داده‌های هوش مصنوعی)',
      'cat': 'Top100',
      'icon': '❄️',
      'price': 118.50,
      'isTop100': true,
    },
    {
      'symbol': 'RACE',
      'name': 'Ferrari N.V.',
      'nameFa': 'فراری (نماد سوپراسپرت‌های لوکس ایتالیا و فرمول یک)',
      'cat': 'Top100',
      'icon': '🏎️',
      'price': 462.80,
      'isTop100': true,
    },

    // =========================================================================
    // 10. THE 100 LARGEST COMPANIES BY MARKET CAP (CompaniesMarketCap.com 1-100)
    // =========================================================================
    {
      'symbol': 'NVDA',
      'name': 'NVIDIA Corporation',
      'nameFa': 'انویدیا (رتبه ۱ جهان - رهبر هوش مصنوعی)',
      'cat': 'Top100',
      'icon': '🟢',
      'price': 138.25,
      'isTop100': true,
    },
    {
      'symbol': 'AAPL',
      'name': 'Apple Inc.',
      'nameFa': 'اپل (رتبه ۲ جهان - غول سخت‌افزار و اکوسیستم)',
      'cat': 'Top100',
      'icon': '🍎',
      'price': 228.50,
      'isTop100': true,
    },
    {
      'symbol': 'MSFT',
      'name': 'Microsoft Corporation',
      'nameFa': 'مایکروسافت (رتبه ۳ جهان - ویندوز، کلاد و OpenAI)',
      'cat': 'Top100',
      'icon': '🪟',
      'price': 428.10,
      'isTop100': true,
    },
    {
      'symbol': 'GOOGL',
      'name': 'Alphabet Inc. (Google)',
      'nameFa': 'گوگل / آلفابت (رتبه ۴ جهان - موتور جستجو و Gemini AI)',
      'cat': 'Top100',
      'icon': '🔍',
      'price': 165.30,
      'isTop100': true,
    },
    {
      'symbol': 'AMZN',
      'name': 'Amazon.com Inc.',
      'nameFa': 'آمازون (رتبه ۵ جهان - تجارت الکترونیک و AWS)',
      'cat': 'Top100',
      'icon': '📦',
      'price': 186.70,
      'isTop100': true,
    },
    {
      'symbol': 'META',
      'name': 'Meta Platforms Inc.',
      'nameFa': 'متا (رتبه ۶ جهان - اینستاگرام، واتساپ و Llama AI)',
      'cat': 'Top100',
      'icon': '🌐',
      'price': 585.20,
      'isTop100': true,
    },
    {
      'symbol': 'TSM',
      'name': 'Taiwan Semiconductor (TSMC)',
      'nameFa': 'تی‌اس‌ام‌سی (رتبه ۷ جهان - بزرگ‌ترین تولیدکننده تراشه)',
      'cat': 'Top100',
      'icon': '🇹🇼',
      'price': 192.40,
      'isTop100': true,
    },
    {
      'symbol': 'BRK-B',
      'name': 'Berkshire Hathaway',
      'nameFa': 'برکشایر هاتاوی (رتبه ۸ جهان - هلدینگ وارن بافت)',
      'cat': 'Top100',
      'icon': '🎩',
      'price': 462.10,
      'isTop100': true,
    },
    {
      'symbol': 'TSLA',
      'name': 'Tesla Inc.',
      'nameFa': 'تسلا (رتبه ۹ جهان - خودروهای خودران، انرژی و رباتیک)',
      'cat': 'Top100',
      'icon': '⚡',
      'price': 255.40,
      'isTop100': true,
    },
    {
      'symbol': 'LLY',
      'name': 'Eli Lilly and Company',
      'nameFa': 'الی لیلی (رتبه ۱۰ جهان - ارزشمندترین شرکت داروسازی)',
      'cat': 'Top100',
      'icon': '💊',
      'price': 910.30,
      'isTop100': true,
    },
    {
      'symbol': 'AVGO',
      'name': 'Broadcom Inc.',
      'nameFa': 'برودکام (رتبه ۱۱ جهان - تراشه‌های شبکه هوش مصنوعی)',
      'cat': 'Top100',
      'icon': '📡',
      'price': 176.80,
      'isTop100': true,
    },
    {
      'symbol': 'JPM',
      'name': 'JPMorgan Chase & Co.',
      'nameFa': 'جی‌پی مورگان (رتبه ۱۲ جهان - بزرگ‌ترین بانک وال‌استریت)',
      'cat': 'Top100',
      'icon': '🏦',
      'price': 222.60,
      'isTop100': true,
    },
    {
      'symbol': 'WMT',
      'name': 'Walmart Inc.',
      'nameFa': 'والمارت (رتبه ۱۳ جهان - بزرگ‌ترین زنجیره خرده‌فروشی)',
      'cat': 'Top100',
      'icon': '🏬',
      'price': 80.50,
      'isTop100': true,
    },
    {
      'symbol': 'V',
      'name': 'Visa Inc.',
      'nameFa': 'ویزا کارت (رتبه ۱۴ جهان - غول پرداخت و تراکنش جهانی)',
      'cat': 'Top100',
      'icon': '💳',
      'price': 288.90,
      'isTop100': true,
    },
    {
      'symbol': 'NVO',
      'name': 'Novo Nordisk A/S',
      'nameFa': 'نوو نوردیسک (رتبه ۱۵ جهان - داروسازی اوزمپیک و دیابت)',
      'cat': 'Top100',
      'icon': '🇩🇰',
      'price': 116.80,
      'isTop100': true,
    },
    {
      'symbol': 'TCEHY',
      'name': 'Tencent Holdings',
      'nameFa': 'تنسنت (رتبه ۱۶ جهان - غول اینترنت و گیمینگ چین)',
      'cat': 'Top100',
      'icon': '🎮',
      'price': 54.80,
      'isTop100': true,
    },
    {
      'symbol': 'XOM',
      'name': 'Exxon Mobil Corp.',
      'nameFa': 'اکسون موبیل (رتبه ۱۷ جهان - غول نفت و گاز)',
      'cat': 'Top100',
      'icon': '🛢️',
      'price': 120.40,
      'isTop100': true,
    },
    {
      'symbol': 'UNH',
      'name': 'UnitedHealth Group',
      'nameFa': 'یونایتدهلث (رتبه ۱۸ جهان - بیمه و خدمات سلامت)',
      'cat': 'Top100',
      'icon': '🏥',
      'price': 572.80,
      'isTop100': true,
    },
    {
      'symbol': 'ORCL',
      'name': 'Oracle Corporation',
      'nameFa': 'اوراکل (رتبه ۱۹ جهان - دیتابیس و کلاد سازمانی)',
      'cat': 'Top100',
      'icon': '💾',
      'price': 175.60,
      'isTop100': true,
    },
    {
      'symbol': 'MA',
      'name': 'Mastercard Inc.',
      'nameFa': 'مسترکارت (رتبه ۲۰ جهان - شبکه پرداخت بین‌المللی)',
      'cat': 'Top100',
      'icon': '💳',
      'price': 505.40,
      'isTop100': true,
    },
    {
      'symbol': 'COST',
      'name': 'Costco Wholesale',
      'nameFa': 'کاستکو (رتبه ۲۱ جهان - فروشگاه‌های زنجیره‌ای)',
      'cat': 'Top100',
      'icon': '🛒',
      'price': 905.80,
      'isTop100': true,
    },
    {
      'symbol': 'HD',
      'name': 'The Home Depot',
      'nameFa': 'هوم دیپو (رتبه ۲۲ جهان - لوازم ساختمانی و منزل)',
      'cat': 'Top100',
      'icon': '🔨',
      'price': 398.50,
      'isTop100': true,
    },
    {
      'symbol': 'PG',
      'name': 'Procter & Gamble',
      'nameFa': 'پروکتر اند گمبل (رتبه ۲۳ جهان - کالاهای مصرفی)',
      'cat': 'Top100',
      'icon': '🧼',
      'price': 168.20,
      'isTop100': true,
    },
    {
      'symbol': 'JNJ',
      'name': 'Johnson & Johnson',
      'nameFa': 'جانسون اند جانسون (رتبه ۲۴ جهان - تجهیزات پزشکی و دارو)',
      'cat': 'Top100',
      'icon': '🩹',
      'price': 161.40,
      'isTop100': true,
    },
    {
      'symbol': 'ASML',
      'name': 'ASML Holding N.V.',
      'nameFa': 'ای‌اس‌ام‌ال (رتبه ۲۵ جهان - لیتوگرافی تراشه هلند)',
      'cat': 'Top100',
      'icon': '🇳🇱',
      'price': 710.20,
      'isTop100': true,
    },
    {
      'symbol': 'ABBV',
      'name': 'AbbVie Inc.',
      'nameFa': 'اب‌وی (رتبه ۲۶ جهان - بیوداروسازی)',
      'cat': 'Top100',
      'icon': '🧬',
      'price': 188.50,
      'isTop100': true,
    },
    {
      'symbol': 'BAC',
      'name': 'Bank of America',
      'nameFa': 'بنک آو آمریکا (رتبه ۲۷ جهان - بانکداری کلان)',
      'cat': 'Top100',
      'icon': '🏦',
      'price': 42.30,
      'isTop100': true,
    },
    {
      'symbol': 'BABA',
      'name': 'Alibaba Group Holding',
      'nameFa': 'علی‌بابا (رتبه ۲۸ جهان - غول تجارت الکترونیک چین)',
      'cat': 'Top100',
      'icon': '🛍️',
      'price': 98.40,
      'isTop100': true,
    },
    {
      'symbol': 'NFLX',
      'name': 'Netflix Inc.',
      'nameFa': 'نتفلیکس (رتبه ۲۹ جهان - سرویس پخش آنلاین سرگرمی)',
      'cat': 'Top100',
      'icon': '🎬',
      'price': 720.60,
      'isTop100': true,
    },
    {
      'symbol': 'SAP',
      'name': 'SAP SE',
      'nameFa': 'اس‌ای‌پی (رتبه ۳۰ جهان - نرم‌افزارهای سازمانی آلمان)',
      'cat': 'Top100',
      'icon': '🇩🇪',
      'price': 234.10,
      'isTop100': true,
    },
    {
      'symbol': 'KO',
      'name': 'The Coca-Cola Company',
      'nameFa': 'کوکاکولا (رتبه ۳۱ جهان - نوشیدنی‌های بین‌المللی)',
      'cat': 'Top100',
      'icon': '🥤',
      'price': 68.40,
      'isTop100': true,
    },
    {
      'symbol': 'CVX',
      'name': 'Chevron Corporation',
      'nameFa': 'شورون (رتبه ۳۲ جهان - نفت، گاز و پتروشیمی)',
      'cat': 'Top100',
      'icon': '⛽',
      'price': 152.60,
      'isTop100': true,
    },
    {
      'symbol': 'CRM',
      'name': 'Salesforce Inc.',
      'nameFa': 'سیلزفورس (رتبه ۳۳ جهان - مدیریت ارتباط با مشتری CRM)',
      'cat': 'Top100',
      'icon': '☁️',
      'price': 294.50,
      'isTop100': true,
    },
    {
      'symbol': 'AMD',
      'name': 'Advanced Micro Devices',
      'nameFa': 'ای‌ام‌دی (رتبه ۳۴ جهان - پردازنده‌های Instinct AI و سرور)',
      'cat': 'Top100',
      'icon': '🔴',
      'price': 156.90,
      'isTop100': true,
    },
    {
      'symbol': 'LVMUY',
      'name': 'LVMH Moet Hennessy',
      'nameFa': 'ال‌وی‌ام‌اچ (رتبه ۳۵ جهان - برندهای لوکس فرانسه)',
      'cat': 'Top100',
      'icon': '👜',
      'price': 132.80,
      'isTop100': true,
    },
    {
      'symbol': 'TM',
      'name': 'Toyota Motor Corp.',
      'nameFa': 'تویوتا موتور (رتبه ۳۶ جهان - غول خودروسازی ژاپن)',
      'cat': 'Top100',
      'icon': '🚗',
      'price': 176.40,
      'isTop100': true,
    },
    {
      'symbol': 'HESAY',
      'name': 'Hermes International',
      'nameFa': 'هرمس اینترنشنال (رتبه ۳۷ جهان - مد لوکس فرانسه)',
      'cat': 'Top100',
      'icon': '🧣',
      'price': 225.60,
      'isTop100': true,
    },
    {
      'symbol': 'AZN',
      'name': 'AstraZeneca PLC',
      'nameFa': 'آسترازنکا (رتبه ۳۸ جهان - داروسازی بریتانیا)',
      'cat': 'Top100',
      'icon': '💉',
      'price': 81.20,
      'isTop100': true,
    },
    {
      'symbol': 'NVS',
      'name': 'Novartis AG',
      'nameFa': 'نووارتیس (رتبه ۳۹ جهان - بهداشت و داروی سوئیس)',
      'cat': 'Top100',
      'icon': '🇨🇭',
      'price': 112.50,
      'isTop100': true,
    },
    {
      'symbol': 'ADBE',
      'name': 'Adobe Inc.',
      'nameFa': 'ادوبی (رتبه ۴۰ جهان - فتوشاپ، پریمیر و هوش مصنوعی Firefly)',
      'cat': 'Top100',
      'icon': '🎨',
      'price': 508.40,
      'isTop100': true,
    },
    {
      'symbol': 'CSCO',
      'name': 'Cisco Systems',
      'nameFa': 'سیسکو سیستمز (رتبه ۴۱ جهان - زیرساخت شبکه و امنیت)',
      'cat': 'Top100',
      'icon': '🌐',
      'price': 55.80,
      'isTop100': true,
    },
    {
      'symbol': 'QCOM',
      'name': 'Qualcomm Inc.',
      'nameFa': 'کوالکام (رتبه ۴۲ جهان - مودم‌های 5G و اسنپ‌دراگون)',
      'cat': 'Top100',
      'icon': '📱',
      'price': 168.50,
      'isTop100': true,
    },
    {
      'symbol': 'LIN',
      'name': 'Linde plc',
      'nameFa': 'لیندا (رتبه ۴۳ جهان - گازهای صنعتی و پزشکی)',
      'cat': 'Top100',
      'icon': '🧪',
      'price': 458.20,
      'isTop100': true,
    },
    {
      'symbol': 'WFC',
      'name': 'Wells Fargo & Co.',
      'nameFa': 'ولز فارگو (رتبه ۴۴ جهان - خدمات مالی و وام مسکن)',
      'cat': 'Top100',
      'icon': '🏦',
      'price': 64.20,
      'isTop100': true,
    },
    {
      'symbol': 'MCD',
      'name': 'McDonald\'s Corp.',
      'nameFa': 'مک‌دونالد (رتبه ۴۵ جهان - بزرگ‌ترین فست‌فود دنیا)',
      'cat': 'Top100',
      'icon': '🍔',
      'price': 296.80,
      'isTop100': true,
    },
    {
      'symbol': 'PEP',
      'name': 'PepsiCo Inc.',
      'nameFa': 'پپسی‌کو (رتبه ۴۶ جهان - نوشیدنی و اسنک چیپس)',
      'cat': 'Top100',
      'icon': '🥤',
      'price': 171.20,
      'isTop100': true,
    },
    {
      'symbol': 'ACN',
      'name': 'Accenture plc',
      'nameFa': 'اکسنچر (رتبه ۴۷ جهان - مشاوره مدیریت و فناوری اطلاعات)',
      'cat': 'Top100',
      'icon': '💼',
      'price': 358.40,
      'isTop100': true,
    },
    {
      'symbol': 'PLTR',
      'name': 'Palantir Technologies',
      'nameFa': 'پالانتیر (رتبه ۴۸ جهان - تحلیل کلان‌داده و هوش دفاعی AIP)',
      'cat': 'Top100',
      'icon': '🔮',
      'price': 44.10,
      'isTop100': true,
    },
    {
      'symbol': 'IBM',
      'name': 'International Business Machines',
      'nameFa': 'آی‌بی‌ام (رتبه ۴۹ جهان - سرورهای کوانتومی و هوش مصنوعی)',
      'cat': 'Top100',
      'icon': '💻',
      'price': 214.80,
      'isTop100': true,
    },
    {
      'symbol': 'NOW',
      'name': 'ServiceNow Inc.',
      'nameFa': 'سرویس‌ناو (رتبه ۵۰ جهان - اتوماسیون فرایندهای سازمانی)',
      'cat': 'Top100',
      'icon': '⚙️',
      'price': 918.40,
      'isTop100': true,
    },
    {
      'symbol': 'GE',
      'name': 'GE Aerospace',
      'nameFa': 'جنرال الکتریک (رتبه ۵۱ جهان - موتورهای توربینی هواپیما)',
      'cat': 'Top100',
      'icon': '✈️',
      'price': 188.60,
      'isTop100': true,
    },
    {
      'symbol': 'TMUS',
      'name': 'T-Mobile US Inc.',
      'nameFa': 'تی‌موبایل (رتبه ۵۲ جهان - اپراتور ارتباطی 5G آمریکا)',
      'cat': 'Top100',
      'icon': '📶',
      'price': 218.40,
      'isTop100': true,
    },
    {
      'symbol': 'INTU',
      'name': 'Intuit Inc.',
      'nameFa': 'اینتویت (رتبه ۵۳ جهان - نرم‌افزارهای حسابداری مالیاتی)',
      'cat': 'Top100',
      'icon': '📊',
      'price': 635.80,
      'isTop100': true,
    },
    {
      'symbol': 'TXN',
      'name': 'Texas Instruments',
      'nameFa': 'تگزاس اینسترومنتس (رتبه ۵۴ جهان - تراشه‌های آنالوگ و صنعتی)',
      'cat': 'Top100',
      'icon': '📟',
      'price': 202.40,
      'isTop100': true,
    },
    {
      'symbol': 'MS',
      'name': 'Morgan Stanley',
      'nameFa': 'مورگان استنلی (رتبه ۵۵ جهان - مدیریت دارایی و سرمایه‌گذاری)',
      'cat': 'Top100',
      'icon': '📈',
      'price': 118.50,
      'isTop100': true,
    },
    {
      'symbol': 'GS',
      'name': 'The Goldman Sachs Group',
      'nameFa': 'گلدمن ساکس (رتبه ۵۶ جهان - بانکداری سرمایه‌گذاری)',
      'cat': 'Top100',
      'icon': '🏛️',
      'price': 518.20,
      'isTop100': true,
    },
    {
      'symbol': 'CAT',
      'name': 'Caterpillar Inc.',
      'nameFa': 'کاترپیلار (رتبه ۵۷ جهان - ماشین‌آلات سنگین معدنی)',
      'cat': 'Top100',
      'icon': '🚜',
      'price': 388.40,
      'isTop100': true,
    },
    {
      'symbol': 'AMGN',
      'name': 'Amgen Inc.',
      'nameFa': 'امژن (رتبه ۵۸ جهان - پیشگام بیوتکنولوژی و دارو)',
      'cat': 'Top100',
      'icon': '🔬',
      'price': 315.60,
      'isTop100': true,
    },
    {
      'symbol': 'UBER',
      'name': 'Uber Technologies',
      'nameFa': 'اوبر (رتبه ۵۹ جهان - تاکسی اینترنتی و تحویل کالا)',
      'cat': 'Top100',
      'icon': '🚗',
      'price': 78.40,
      'isTop100': true,
    },
    {
      'symbol': 'DIS',
      'name': 'The Walt Disney Company',
      'nameFa': 'والت دیزنی (رتبه ۶۰ جهان - سرگرمی، پارک‌ها و دیزنی‌پلاس)',
      'cat': 'Top100',
      'icon': '🏰',
      'price': 96.40,
      'isTop100': true,
    },
    {
      'symbol': 'PM',
      'name': 'Philip Morris International',
      'nameFa': 'فیلیپ موریس (رتبه ۶۱ جهان - دخانیات و محصولات جدید)',
      'cat': 'Top100',
      'icon': '🚬',
      'price': 131.20,
      'isTop100': true,
    },
    {
      'symbol': 'AXP',
      'name': 'American Express',
      'nameFa': 'امریکن اکسپرس (رتبه ۶۲ جهان - کارت‌های اعتباری ممتاز)',
      'cat': 'Top100',
      'icon': '💳',
      'price': 274.60,
      'isTop100': true,
    },
    {
      'symbol': 'ISRG',
      'name': 'Intuitive Surgical',
      'nameFa': 'اینتویتیو سرجیکال (رتبه ۶۳ جهان - ربات‌های جراح داوینچی)',
      'cat': 'Top100',
      'icon': '🤖',
      'price': 512.40,
      'isTop100': true,
    },
    {
      'symbol': 'VZ',
      'name': 'Verizon Communications',
      'nameFa': 'ورایزون (رتبه ۶۴ جهان - بزرگ‌ترین مخابرات آمریکا)',
      'cat': 'Top100',
      'icon': '📞',
      'price': 42.80,
      'isTop100': true,
    },
    {
      'symbol': 'BKNG',
      'name': 'Booking Holdings',
      'nameFa': 'بوکینگ (رتبه ۶۵ جهان - رزرواسیون هتل و گردشگری آنلاین)',
      'cat': 'Top100',
      'icon': '🏨',
      'price': 4480.00,
      'isTop100': true,
    },
    {
      'symbol': 'BLK',
      'name': 'BlackRock Inc.',
      'nameFa': 'بلک‌راک (رتبه ۶۶ جهان - بزرگ‌ترین مدیر دارایی دنیا و IBIT)',
      'cat': 'Top100',
      'icon': '🏛️',
      'price': 985.40,
      'isTop100': true,
    },
    {
      'symbol': 'PFE',
      'name': 'Pfizer Inc.',
      'nameFa': 'فایزر (رتبه ۶۷ جهان - واکسن‌ها و ایمنی‌شناسی)',
      'cat': 'Top100',
      'icon': '💉',
      'price': 28.50,
      'isTop100': true,
    },
    {
      'symbol': 'SNY',
      'name': 'Sanofi SA',
      'nameFa': 'سانوفی (رتبه ۶۸ جهان - داروسازی چندملیتی فرانسه)',
      'cat': 'Top100',
      'icon': '🇫🇷',
      'price': 54.20,
      'isTop100': true,
    },
    {
      'symbol': 'SONY',
      'name': 'Sony Group Corp.',
      'nameFa': 'سونی (رتبه ۶۹ جهان - پلی‌استیشن و سنسورهای تصویر)',
      'cat': 'Top100',
      'icon': '🎮',
      'price': 94.80,
      'isTop100': true,
    },
    {
      'symbol': 'SIEGY',
      'name': 'Siemens AG',
      'nameFa': 'زیمنس (رتبه ۷۰ جهان - اتوماسیون صنعتی آلمان)',
      'cat': 'Top100',
      'icon': '🇩🇪',
      'price': 98.40,
      'isTop100': true,
    },
    {
      'symbol': 'DHR',
      'name': 'Danaher Corporation',
      'nameFa': 'داناخر (رتبه ۷۱ جهان - تجهیزات آزمایشگاهی و ژنتیک)',
      'cat': 'Top100',
      'icon': '🧬',
      'price': 264.20,
      'isTop100': true,
    },
    {
      'symbol': 'RTX',
      'name': 'RTX Corporation (Raytheon)',
      'nameFa': 'آر‌تی‌ایکس / ریتون (رتبه ۷۲ جهان - سامانه‌های موشکی پاتریوت)',
      'cat': 'Top100',
      'icon': '🚀',
      'price': 124.60,
      'isTop100': true,
    },
    {
      'symbol': 'HON',
      'name': 'Honeywell International',
      'nameFa': 'هانی‌ول (رتبه ۷۳ جهان - تجهیزات هوافضا و سنسورها)',
      'cat': 'Top100',
      'icon': '✈️',
      'price': 212.80,
      'isTop100': true,
    },
    {
      'symbol': 'UNP',
      'name': 'Union Pacific Corp.',
      'nameFa': 'یونیون پاسیفیک (رتبه ۷۴ جهان - بزرگ‌ترین راه‌آهن آمریکا)',
      'cat': 'Top100',
      'icon': '🚂',
      'price': 238.40,
      'isTop100': true,
    },
    {
      'symbol': 'AMAT',
      'name': 'Applied Materials',
      'nameFa': 'اپلاید متریالز (رتبه ۷۵ جهان - تجهیزات ساخت ویفر تراشه)',
      'cat': 'Top100',
      'icon': '🔬',
      'price': 192.50,
      'isTop100': true,
    },
    {
      'symbol': 'TTE',
      'name': 'TotalEnergies SE',
      'nameFa': 'توتال‌انرژیز (رتبه ۷۶ جهان - غول انرژی فرانسه)',
      'cat': 'Top100',
      'icon': '🇫🇷',
      'price': 63.80,
      'isTop100': true,
    },
    {
      'symbol': 'MU',
      'name': 'Micron Technology',
      'nameFa': 'میکرون (رتبه ۷۷ جهان - حافظه‌های HBM3e هوش مصنوعی)',
      'cat': 'Top100',
      'icon': '💾',
      'price': 110.50,
      'isTop100': true,
    },
    {
      'symbol': 'COP',
      'name': 'ConocoPhillips',
      'nameFa': 'کونوکو فیلیپس (رتبه ۷۸ جهان - اکتشاف و استخراج نفت)',
      'cat': 'Top100',
      'icon': '🛢️',
      'price': 108.40,
      'isTop100': true,
    },
    {
      'symbol': 'ETN',
      'name': 'Eaton Corporation plc',
      'nameFa': 'ایتون (رتبه ۷۹ جهان - مدیریت هوشمند برق و دیتاسنتر)',
      'cat': 'Top100',
      'icon': '⚡',
      'price': 342.80,
      'isTop100': true,
    },
    {
      'symbol': 'PANW',
      'name': 'Palo Alto Networks',
      'nameFa': 'پالو آلتو نتورکس (رتبه ۸۰ جهان - امنیت سایبری و فایروال)',
      'cat': 'Top100',
      'icon': '🛡️',
      'price': 365.40,
      'isTop100': true,
    },
    {
      'symbol': 'NKE',
      'name': 'NIKE Inc.',
      'nameFa': 'نایکی (رتبه ۸۱ جهان - کفش و پوشاک ورزشی بین‌المللی)',
      'cat': 'Top100',
      'icon': '👟',
      'price': 82.60,
      'isTop100': true,
    },
    {
      'symbol': 'BMY',
      'name': 'Bristol Myers Squibb',
      'nameFa': 'بریستول مایرز (رتبه ۸۲ جهان - داروسازی سرطان و قلب)',
      'cat': 'Top100',
      'icon': '💊',
      'price': 52.40,
      'isTop100': true,
    },
    {
      'symbol': 'LMT',
      'name': 'Lockheed Martin Corp.',
      'nameFa': 'لاکهید مارتین (رتبه ۸۳ جهان - سازنده جنگنده‌های F-35)',
      'cat': 'Top100',
      'icon': '🛩️',
      'price': 570.40,
      'isTop100': true,
    },
    {
      'symbol': 'SBUX',
      'name': 'Starbucks Corporation',
      'nameFa': 'استارباکس (رتبه ۸۴ جهان - قهوه‌خانه‌های زنجیره‌ای)',
      'cat': 'Top100',
      'icon': '☕',
      'price': 97.50,
      'isTop100': true,
    },
    {
      'symbol': 'PDD',
      'name': 'PDD Holdings Inc. (Temu)',
      'nameFa': 'پین‌دودو / تیمو (رتبه ۸۵ جهان - فروشگاه جهانی Temu)',
      'cat': 'Top100',
      'icon': '🏷️',
      'price': 122.80,
      'isTop100': true,
    },
    {
      'symbol': 'MSTR',
      'name': 'MicroStrategy Inc.',
      'nameFa': 'مایکرواستراتژی (رتبه ۸۶ جهان - بزرگ‌ترین خزانه‌داری بیت‌کوین)',
      'cat': 'Top100',
      'icon': '🪙',
      'price': 235.50,
      'isTop100': true,
    },
    {
      'symbol': 'COIN',
      'name': 'Coinbase Global Inc.',
      'nameFa': 'کوین‌بیس (رتبه ۸۷ جهان - صرافی رسمی بورس نزدک)',
      'cat': 'Top100',
      'icon': '🔵',
      'price': 214.30,
      'isTop100': true,
    },
    {
      'symbol': 'LRCX',
      'name': 'Lam Research Corp.',
      'nameFa': 'لم ریسرچ (رتبه ۸۸ جهان - فرایندهای اچینگ تراشه)',
      'cat': 'Top100',
      'icon': '🔬',
      'price': 76.40,
      'isTop100': true,
    },
    {
      'symbol': 'BSX',
      'name': 'Boston Scientific Corp.',
      'nameFa': 'بوستون ساینتیفیک (رتبه ۸۹ جهان - ایمپلنت‌های پزشکی)',
      'cat': 'Top100',
      'icon': '🫀',
      'price': 86.20,
      'isTop100': true,
    },
    {
      'symbol': 'KLAC',
      'name': 'KLA Corporation',
      'nameFa': 'کی‌ال‌ای (رتبه ۹۰ جهان - بازرسی کیفیت نانو تراشه)',
      'cat': 'Top100',
      'icon': '🔍',
      'price': 698.50,
      'isTop100': true,
    },
    {
      'symbol': 'SBGSY',
      'name': 'Schneider Electric SE',
      'nameFa': 'اشنایدر الکتریک (رتبه ۹۱ جهان - زیرساخت توزیع برق فرانسه)',
      'cat': 'Top100',
      'icon': '⚡',
      'price': 52.80,
      'isTop100': true,
    },
    {
      'symbol': 'SYK',
      'name': 'Stryker Corporation',
      'nameFa': 'استرایکر (رتبه ۹۲ جهان - تجهیزات ارتوپدی و جراحی)',
      'cat': 'Top100',
      'icon': '🦾',
      'price': 365.20,
      'isTop100': true,
    },
    {
      'symbol': 'ADI',
      'name': 'Analog Devices Inc.',
      'nameFa': 'آنالوگ دیوایسز (رتبه ۹۳ جهان - پردازش سیگنال و سنسور)',
      'cat': 'Top100',
      'icon': '📡',
      'price': 216.40,
      'isTop100': true,
    },
    {
      'symbol': 'VRTX',
      'name': 'Vertex Pharmaceuticals',
      'nameFa': 'ورتکس (رتبه ۹۴ جهان - ژن‌درمانی بیماری‌های خاص)',
      'cat': 'Top100',
      'icon': '🧬',
      'price': 478.60,
      'isTop100': true,
    },
    {
      'symbol': 'ARM',
      'name': 'Arm Holdings plc',
      'nameFa': 'آرم هولدینگز (رتبه ۹۵ جهان - معماری پردازنده‌های موبایل و سرور)',
      'cat': 'Top100',
      'icon': '📐',
      'price': 142.30,
      'isTop100': true,
    },
    {
      'symbol': 'CRWD',
      'name': 'CrowdStrike Holdings',
      'nameFa': 'کراوداسترایک (رتبه ۹۶ جهان - امنیت شبکه فالکون AI)',
      'cat': 'Top100',
      'icon': '🦅',
      'price': 312.40,
      'isTop100': true,
    },
    {
      'symbol': 'SMCI',
      'name': 'Super Micro Computer',
      'nameFa': 'سوپرمیکرو (رتبه ۹۷ جهان - سرورهای دیتاسنتر مایع‌خنک AI)',
      'cat': 'Top100',
      'icon': '🖥️',
      'price': 46.80,
      'isTop100': true,
    },
    {
      'symbol': 'INTC',
      'name': 'Intel Corporation',
      'nameFa': 'اینتل (رتبه ۹۸ جهان - پردازنده‌های کامپیوتر و کارخانجات فاندری)',
      'cat': 'Top100',
      'icon': '🔷',
      'price': 22.80,
      'isTop100': true,
    },
    {
      'symbol': 'BIDU',
      'name': 'Baidu Inc.',
      'nameFa': 'بایدو (رتبه ۹۹ جهان - غول هوش مصنوعی و خودرو خودران چین)',
      'cat': 'Top100',
      'icon': '🇨🇳',
      'price': 89.20,
      'isTop100': true,
    },
    {
      'symbol': 'NIO',
      'name': 'NIO Inc.',
      'nameFa': 'نیو (رتبه ۱۰۰ جهان - خودروهای برقی هوشمند با تعویض باتری)',
      'cat': 'Top100',
      'icon': '🚙',
      'price': 5.25,
      'isTop100': true,
    },
  ];

  @override
  Future<List<CurrencyPair>> fetchCurrencyPairs() async {
    return predefinedStocks.map<CurrencyPair>((s) {
      final sym = s['symbol'] as String;
      return CurrencyPair(
        baseCurrency: sym,
        counterCurrency: 'USD',
        marketSymbol: '$sym/USD',
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
    );
  }

  @override
  Future<MarketTicker> fetchTicker(CurrencyPair pair) async {
    final cleanSymbol = pair.baseCurrency;

    // 1. Specialized Handler for Crypto Macro & Dominance Indices
    if (cleanSymbol == 'TOTAL' ||
        cleanSymbol == 'TOTAL2' ||
        cleanSymbol == 'TOTAL3' ||
        cleanSymbol == 'BTC.D' ||
        cleanSymbol == 'USDT.D' ||
        cleanSymbol == 'ETH.D') {
      try {
        final res = await _client.get(Uri.parse('https://api.coingecko.com/api/v3/global')).timeout(const Duration(seconds: 5));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body)['data'];
          if (data != null) {
            final totalUsd = (data['total_market_cap']?['usd'] as num?)?.toDouble() ?? 2450000000000.0;
            final marketCapPct = data['market_cap_percentage'] as Map<String, dynamic>? ?? {};
            final btcPct = (marketCapPct['btc'] as num?)?.toDouble() ?? 58.6;
            final ethPct = (marketCapPct['eth'] as num?)?.toDouble() ?? 14.3;
            final usdtPct = (marketCapPct['usdt'] as num?)?.toDouble() ?? 5.15;

            double targetValue = 0.0;
            if (cleanSymbol == 'TOTAL') {
              targetValue = totalUsd / 1e9; // in Billions USD
            } else if (cleanSymbol == 'TOTAL2') {
              targetValue = (totalUsd * (100 - btcPct) / 100) / 1e9;
            } else if (cleanSymbol == 'TOTAL3') {
              targetValue = (totalUsd * (100 - btcPct - ethPct) / 100) / 1e9;
            } else if (cleanSymbol == 'BTC.D') {
              targetValue = btcPct;
            } else if (cleanSymbol == 'USDT.D') {
              targetValue = usdtPct;
            } else if (cleanSymbol == 'ETH.D') {
              targetValue = ethPct;
            }

            if (targetValue > 0) {
              return MarketTicker(
                exchangeId: id,
                pair: pair,
                lastPrice: targetValue,
                volume24h: 0.0,
                timestamp: DateTime.now(),
              );
            }
          }
        }
      } catch (_) {}
    }

    if (cleanSymbol == 'CRYPTO_FGI') {
      try {
        final res = await _client.get(Uri.parse('https://api.alternative.me/fng/')).timeout(const Duration(seconds: 4));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          final valStr = data['data']?[0]?['value'];
          final val = double.tryParse(valStr?.toString() ?? '');
          if (val != null && val > 0) {
            return MarketTicker(
              exchangeId: id,
              pair: pair,
              lastPrice: val,
              volume24h: 0.0,
              timestamp: DateTime.now(),
            );
          }
        }
      } catch (_) {}
    }

    // 2. Try Yahoo Finance primary & secondary endpoints for Stocks, Commodities & Forex
    final hosts = ['query1.finance.yahoo.com', 'query2.finance.yahoo.com'];

    for (final host in hosts) {
      try {
        final url = Uri.parse('https://$host/v8/finance/chart/$cleanSymbol?interval=1m&range=1d');
        final response = await _client.get(url, headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Accept': 'application/json',
        }).timeout(const Duration(seconds: 6));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final result = data['chart']?['result']?[0];
          if (result != null) {
            final meta = result['meta'];
            final double regularPrice = (meta['regularMarketPrice'] as num).toDouble();
            final double high = (meta['regularMarketDayHigh'] as num?)?.toDouble() ?? regularPrice;
            final double low = (meta['regularMarketDayLow'] as num?)?.toDouble() ?? regularPrice;
            final double volume = (meta['regularMarketVolume'] as num?)?.toDouble() ?? 0.0;

            if (regularPrice > 0) {
              return MarketTicker(
                exchangeId: id,
                pair: pair,
                lastPrice: regularPrice,
                volume24h: volume,
                high24h: high,
                low24h: low,
                timestamp: DateTime.now(),
              );
            }
          }
        }
      } catch (_) {}
    }

    // 3. High-speed Stooq Financial Mirror (for Indices, Forex & Stocks)
    try {
      final stooqSym = cleanSymbol.replaceAll('^', '').replaceAll('=X', '').toLowerCase();
      final stooqUrl = Uri.parse('https://stooq.com/q/l/?s=$stooqSym.us&f=sd2t2ohlcv&h&e=json');
      final res = await _client.get(stooqUrl).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is Map && data['symbols'] is List && (data['symbols'] as List).isNotEmpty) {
          final item = data['symbols'][0];
          final p = double.tryParse(item['close']?.toString() ?? '0') ?? 0.0;
          if (p > 0) {
            return MarketTicker(
              exchangeId: id,
              pair: pair,
              lastPrice: p,
              volume24h: 0.0,
              timestamp: DateTime.now(),
            );
          }
        }
      }
    } catch (_) {}

    // 4. Fallback to predefined baseline price if network is temporarily slow
    final match = predefinedStocks.firstWhere(
      (s) => (s['symbol'] as String).toUpperCase() == cleanSymbol.toUpperCase(),
      orElse: () => {},
    );
    if (match.isNotEmpty && match['price'] != null) {
      return MarketTicker(
        exchangeId: id,
        pair: pair,
        lastPrice: (match['price'] as num).toDouble(),
        volume24h: 0.0,
        timestamp: DateTime.now(),
      );
    }

    throw Exception('Connection error: Live price unavailable for $cleanSymbol');
  }
}
