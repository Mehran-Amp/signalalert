import 'dart:convert';
import 'package:flutter/foundation.dart';
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
  String get name => 'Global Markets (Stocks / Macro / Forex / Commodities)';

  @override
  ExchangeCategory get category => ExchangeCategory.all;

  @override
  String get countryBadge => '🏛️ Global Equities & Commodities';

  @override
  String get defaultCounterCurrency => 'USD';

  static const List<Map<String, dynamic>> predefinedStocks = [
{
      'symbol': 'TOTAL',
      'name': 'Crypto Total Market Cap (TOTAL)',
      'nameFa': 'شاخص کل ارزش بازار کریپتو (TOTAL)',
      'cat': 'CryptoMacro',
      'icon': '🌐',
      'price': 2450.0, // Billion USD
      'unit': 'Billion USD',
    },
{
      'symbol': 'TOTAL2',
      'name': 'Crypto Market Cap Excl. BTC (TOTAL2)',
      'nameFa': 'شاخص بازار کریپتو منهای بیت‌کوین (TOTAL2)',
      'cat': 'CryptoMacro',
      'icon': '🔷',
      'price': 1080.0, // Billion USD
      'unit': 'Billion USD',
    },
{
      'symbol': 'TOTAL3',
      'name': 'Altcoin Market Cap Excl. BTC & ETH (TOTAL3)',
      'nameFa': 'شاخص آلت‌کوین‌ها منهای بیت‌کوین و اتریوم (TOTAL3)',
      'cat': 'CryptoMacro',
      'icon': '🚀',
      'price': 685.0, // Billion USD
      'unit': 'Billion USD',
    },
{
      'symbol': 'BTC.D',
      'name': 'Bitcoin Dominance Index (BTC.D)',
      'nameFa': 'شاخص دامیننس و سهم بازار بیت‌کوین (BTC.D %)',
      'cat': 'CryptoMacro',
      'icon': '₿',
      'price': 58.60, // %
      'unit': '%',
    },
{
      'symbol': 'USDT.D',
      'name': 'Tether Dominance Index (USDT.D)',
      'nameFa': 'شاخص دامیننس تتر و نقدینگی دلاری (USDT.D %)',
      'cat': 'CryptoMacro',
      'icon': '💵',
      'price': 5.15, // %
      'unit': '%',
    },
{
      'symbol': 'ETH.D',
      'name': 'Ethereum Dominance Index (ETH.D)',
      'nameFa': 'شاخص دامیننس و سهم بازار اتریوم (ETH.D %)',
      'cat': 'CryptoMacro',
      'icon': '⟠',
      'price': 14.30, // %
      'unit': '%',
    },
{
      'symbol': 'CRYPTO_FGI',
      'name': 'Crypto Fear & Greed Index',
      'nameFa': 'شاخص احساسات، ترس و طمع کریپتو (0-100)',
      'cat': 'CryptoMacro',
      'icon': '🧭',
      'price': 68.0,
      'unit': 'pts',
    },
{
      'symbol': 'DX-Y.NYB',
      'name': 'US Dollar Index (DXY)',
      'nameFa': 'شاخص قدرت جهانی دلار آمریکا (DXY)',
      'cat': 'Macro',
      'icon': '💵',
      'price': 104.25,
      'unit': 'pts',
    },
{
      'symbol': '^TNX',
      'name': 'US 10-Year Treasury Yield',
      'nameFa': 'نرخ بازدهی اوراق ۱۰ ساله آمریکا (US10Y)',
      'cat': 'Macro',
      'icon': '📈',
      'price': 4.28,
      'unit': '%',
    },
{
      'symbol': '^IRX',
      'name': 'US 13-Week Treasury Bill Yield (^IRX)',
      'nameFa': 'نرخ بازدهی اوراق ۱۳ هفته‌ای خزانه‌داری آمریکا (^IRX)',
      'cat': 'Macro',
      'icon': '📊',
      'price': 4.15,
      'unit': '%',
    },
{
      'symbol': '^TYX',
      'name': 'US 30-Year Treasury Bond',
      'nameFa': 'اوراق قرضه ۳۰ ساله بلندمدت آمریکا (US30Y)',
      'cat': 'Macro',
      'icon': '🏛️',
      'price': 4.52,
      'unit': '%',
    },
{
      'symbol': '^FVX',
      'name': 'US 5-Year Treasury Yield',
      'nameFa': 'نرخ بازدهی اوراق ۵ ساله آمریکا (US05Y)',
      'cat': 'Macro',
      'icon': '📉',
      'price': 4.18,
      'unit': 'USD',
    },
{
      'symbol': '^VIX',
      'name': 'CBOE Volatility Index (VIX)',
      'nameFa': 'شاخص نوسان و ترس وال‌استریت (VIX)',
      'cat': 'Macro',
      'icon': '⚡',
      'price': 18.50,
      'unit': 'pts',
    },
{
      'symbol': '^GSPC',
      'name': 'S&P 500 Index',
      'nameFa': 'شاخص ۵۰۰ شرکت برتر آمریکا (S&P 500)',
      'cat': 'Indices',
      'icon': '🇺🇸',
      'price': 5864.67,
      'unit': 'pts',
    },
{
      'symbol': '^NDX',
      'name': 'NASDAQ 100 Index',
      'nameFa': 'شاخص ۱۰۰ شرکت برتر فناوری (NASDAQ 100)',
      'cat': 'Indices',
      'icon': '💻',
      'price': 20380.50,
      'unit': 'USD',
    },
{
      'symbol': '^DJI',
      'name': 'Dow Jones Industrial Average',
      'nameFa': 'شاخص صنعتی داوجونز (Dow Jones 30)',
      'cat': 'Indices',
      'icon': '🏭',
      'price': 42931.60,
      'unit': 'pts',
    },
{
      'symbol': '^RUT',
      'name': 'Russell 2000 Index',
      'nameFa': 'شاخص ۲۰۰۰ شرکت کوچک و چابک آمریکا (Russell 2000)',
      'cat': 'Indices',
      'icon': '🏢',
      'price': 2250.40,
      'unit': 'pts',
    },
{
      'symbol': '^GDAXI',
      'name': 'DAX 40 Germany',
      'nameFa': 'شاخص بورس آلمان (DAX 40)',
      'cat': 'Indices',
      'icon': '🇩🇪',
      'price': 19450.20,
      'unit': 'pts',
    },
{
      'symbol': '^FTSE',
      'name': 'FTSE 100 UK',
      'nameFa': 'شاخص بورس لندن (FTSE 100)',
      'cat': 'Indices',
      'icon': '🇬🇧',
      'price': 8250.80,
      'unit': 'pts',
    },
{
      'symbol': '^FCHI',
      'name': 'CAC 40 France',
      'nameFa': 'شاخص بورس پاریس (CAC 40)',
      'cat': 'Indices',
      'icon': '🇫🇷',
      'price': 7510.30,
      'unit': 'USD',
    },
{
      'symbol': '000001.SS',
      'name': 'Shanghai Composite Index',
      'nameFa': 'شاخص کل بورس شانگهای چین (SSE)',
      'cat': 'China',
      'icon': '🇨🇳',
      'price': 3290.15,
      'unit': 'pts',
    },
{
      'symbol': '399001.SZ',
      'name': 'Shenzhen Component Index',
      'nameFa': 'شاخص بورس شنژن چین (SZSE)',
      'cat': 'China',
      'icon': '🇨🇳',
      'price': 10580.40,
      'unit': 'pts',
    },
{
      'symbol': '^HSI',
      'name': 'Hang Seng Index Hong Kong',
      'nameFa': 'شاخص بورس هنگ‌کنگ (Hang Seng)',
      'cat': 'China',
      'icon': '🇭🇰',
      'price': 20680.40,
      'unit': 'pts',
    },
{
      'symbol': 'FXI',
      'name': 'iShares China Large-Cap ETF',
      'nameFa': 'صندوق ۵۰ شرکت غول‌پیکر چین (FXI ETF)',
      'cat': 'China',
      'icon': '🇨🇳',
      'price': 31.85,
      'unit': 'USD',
    },
{
      'symbol': 'KWEB',
      'name': 'KraneShares CSI China Internet ETF',
      'nameFa': 'صندوق شرکت‌های اینترنتی و کلاد چین (KWEB)',
      'cat': 'China',
      'icon': '🌐',
      'price': 32.40,
      'unit': 'USD',
    },
{
      'symbol': 'BYDDY',
      'name': 'BYD Company ADR',
      'nameFa': 'بی‌وای‌دی (بزرگ‌ترین خودروساز برقی جهان)',
      'cat': 'China',
      'icon': '🔋',
      'price': 72.80,
      'unit': 'USD',
    },
{
      'symbol': 'LI',
      'name': 'Li Auto Inc.',
      'nameFa': 'لی اتو (شاسی‌بلندهای هوشمند هیبریدی چین)',
      'cat': 'China',
      'icon': '🚗',
      'price': 29.40,
      'unit': 'USD',
    },
{
      'symbol': 'XPEV',
      'name': 'XPeng Inc.',
      'nameFa': 'ایکس‌پنگ (خودروهای تمام‌برقی و هوش مصنوعی پروازی)',
      'cat': 'China',
      'icon': '🚘',
      'price': 11.60,
      'unit': 'USD',
    },
{
      'symbol': 'XIACY',
      'name': 'Xiaomi Corporation ADR',
      'nameFa': 'شیائومی (گوشی‌های هوشمند و خودرو برقی SU7)',
      'cat': 'China',
      'icon': '📱',
      'price': 16.80,
      'unit': 'USD',
    },
{
      'symbol': 'NTES',
      'name': 'NetEase Inc.',
      'nameFa': 'نت‌ایز (غول سرگرمی دیجیتال و هوش مصنوعی چین)',
      'cat': 'China',
      'icon': '🎲',
      'price': 84.50,
      'unit': 'USD',
    },
{
      'symbol': 'SMICY',
      'name': 'SMIC Semiconductor ADR',
      'nameFa': 'اس‌ام‌آی‌سی (بزرگ‌ترین کارخانه تراشه‌سازی چین)',
      'cat': 'China',
      'icon': '🔬',
      'price': 18.20,
      'unit': 'USD',
    },
{
      'symbol': 'BILI',
      'name': 'Bilibili Inc.',
      'nameFa': 'بیلی‌بیلی (یوتیوب چین و استریم ویدیو)',
      'cat': 'China',
      'icon': '📺',
      'price': 19.80,
      'unit': 'USD',
    },
{
      'symbol': '^N225',
      'name': 'Nikkei 225 Japan',
      'nameFa': 'شاخص بورس توکیو ژاپن (Nikkei 225)',
      'cat': 'China',
      'icon': '🇯🇵',
      'price': 38980.00,
      'unit': 'pts',
    },
{
      'symbol': '^KS11',
      'name': 'KOSPI South Korea',
      'nameFa': 'شاخص بورس کره جنوبی (KOSPI)',
      'cat': 'China',
      'icon': '🇰🇷',
      'price': 2610.50,
      'unit': 'pts',
    },
    {
      'symbol': '^NSEI',
      'name': 'NIFTY 50 India',
      'nameFa': 'شاخص بورس ملی هند (NIFTY 50)',
      'cat': 'China',
      'icon': '🇮🇳',
      'price': 25000.00,
      'unit': 'pts',
    },
{
      'symbol': '^TWII',
      'name': 'Taiwan Weighted Index',
      'nameFa': 'شاخص کل بورس تایوان (TWSE)',
      'cat': 'China',
      'icon': '🇹🇼',
      'price': 23200.00,
      'unit': 'pts',
    },
{
      'symbol': 'GC=F',
      'name': 'Gold Spot (XAU/USD)',
      'nameFa': 'انس طلای جهانی (Gold XAU/USD)',
      'cat': 'Commodities',
      'icon': '🥇',
      'price': 2735.40,
      'unit': 'USD',
    },
{
      'symbol': 'SI=F',
      'name': 'Silver Spot (XAG/USD)',
      'nameFa': 'انس نقره جهانی (Silver XAG/USD)',
      'cat': 'Commodities',
      'icon': '🥈',
      'price': 33.85,
      'unit': 'USD',
    },
{
      'symbol': 'PL=F',
      'name': 'Platinum Futures',
      'nameFa': 'انس پلاتین جهانی (Platinum)',
      'cat': 'Commodities',
      'icon': '⚪',
      'price': 1025.50,
      'unit': 'USD',
    },
{
      'symbol': 'PA=F',
      'name': 'Palladium Futures',
      'nameFa': 'انس پالادیوم جهانی (Palladium)',
      'cat': 'Commodities',
      'icon': '✨',
      'price': 1140.00,
      'unit': 'USD',
    },
{
      'symbol': 'BZ=F',
      'name': 'Brent Crude Oil',
      'nameFa': 'نفت خام برنت دریای شمال (Brent)',
      'cat': 'Commodities',
      'icon': '🛢️',
      'price': 75.40,
      'unit': 'USD',
    },
{
      'symbol': 'CL=F',
      'name': 'Crude Oil WTI',
      'nameFa': 'نفت خام سبک تگزاس (WTI Oil)',
      'cat': 'Commodities',
      'icon': '⛽',
      'price': 71.20,
      'unit': 'USD',
    },
{
      'symbol': 'NG=F',
      'name': 'Natural Gas Futures',
      'nameFa': 'گاز طبیعی جهانی (Natural Gas)',
      'cat': 'Commodities',
      'icon': '🔥',
      'price': 2.85,
      'unit': 'USD',
    },
{
      'symbol': 'HG=F',
      'name': 'Copper Futures (Dr. Copper)',
      'nameFa': 'مس صنعتی جهانی (دماسنج اقتصاد)',
      'cat': 'Commodities',
      'icon': '🥉',
      'price': 4.42,
      'unit': 'USD',
    },
{
      'symbol': 'EURUSD=X',
      'name': 'EUR/USD',
      'nameFa': 'یورو به دلار آمریکا (EUR/USD)',
      'cat': 'Forex',
      'icon': '🇪🇺',
      'price': 1.0825,
      'unit': 'USD',
    },
{
      'symbol': 'GBPUSD=X',
      'name': 'GBP/USD (Cable)',
      'nameFa': 'پوند انگلیس به دلار آمریکا (GBP/USD)',
      'cat': 'Forex',
      'icon': '🇬🇧',
      'price': 1.2980,
      'unit': 'USD',
    },
{
      'symbol': 'USDJPY=X',
      'name': 'USD/JPY',
      'nameFa': 'دلار آمریکا به ین ژاپن (USD/JPY)',
      'cat': 'Forex',
      'icon': '🇯🇵',
      'price': 153.40,
      'unit': 'JPY',
    },
{
      'symbol': 'USDCHF=X',
      'name': 'USD/CHF (Swissie)',
      'nameFa': 'دلار آمریکا به فرانک سوئیس (USD/CHF)',
      'cat': 'Forex',
      'icon': '🇨🇭',
      'price': 0.8670,
      'unit': 'CHF',
    },
{
      'symbol': 'AUDUSD=X',
      'name': 'AUD/USD (Aussie)',
      'nameFa': 'دلار استرالیا به دلار آمریکا (AUD/USD)',
      'cat': 'Forex',
      'icon': '🇦🇺',
      'price': 0.6620,
      'unit': 'USD',
    },
{
      'symbol': 'USDCAD=X',
      'name': 'USD/CAD (Loonie)',
      'nameFa': 'دلار آمریکا به دلار کانادا (USD/CAD)',
      'cat': 'Forex',
      'icon': '🇨🇦',
      'price': 1.3850,
      'unit': 'CAD',
    },
{
      'symbol': 'NZDUSD=X',
      'name': 'NZD/USD (Kiwi)',
      'nameFa': 'دلار نیوزیلند به دلار آمریکا (NZD/USD)',
      'cat': 'Forex',
      'icon': '🇳🇿',
      'price': 0.6010,
      'unit': 'USD',
    },
{
      'symbol': 'EURJPY=X',
      'name': 'EUR/JPY',
      'nameFa': 'یورو به ین ژاپن (EUR/JPY)',
      'cat': 'Forex',
      'icon': '💱',
      'price': 166.10,
      'unit': 'USD',
    },
{
      'symbol': 'GBPJPY=X',
      'name': 'GBP/JPY (Guppy)',
      'nameFa': 'پوند انگلیس به ین ژاپن (GBP/JPY)',
      'cat': 'Forex',
      'icon': '💱',
      'price': 199.20,
      'unit': 'USD',
    },
{
      'symbol': 'EURGBP=X',
      'name': 'EUR/GBP',
      'nameFa': 'یورو به پوند انگلیس (EUR/GBP)',
      'cat': 'Forex',
      'icon': '💱',
      'price': 0.8340,
      'unit': 'USD',
    },
{
      'symbol': 'USDCNH=X',
      'name': 'USD/CNH',
      'nameFa': 'دلار آمریکا به یوان چین فراساحلی (USD/CNH)',
      'cat': 'Forex',
      'icon': '🇨🇳',
      'price': 7.1420,
      'unit': 'USD',
    },
{
      'symbol': 'USDTRY=X',
      'name': 'USD/TRY',
      'nameFa': 'دلار آمریکا به لیر ترکیه (USD/TRY)',
      'cat': 'Forex',
      'icon': '🇹🇷',
      'price': 34.28,
      'unit': 'TRY',
    },
{
      'symbol': 'TSLA',
      'name': 'Tesla Inc. (EV, AI, Optimus & Energy)',
      'nameFa': 'تسلا (خودروهای برقی، هوش مصنوعی، ربات انسان‌نمای اپتیموس و انرژی ایلان ماسک)',
      'cat': 'ElonMusk',
      'icon': '⚡',
      'price': 255.40,
      'isTop100': true,
      'unit': 'USD',
    },
{
      'symbol': 'SPACEX',
      'name': 'SpaceX (Starship, Falcon & Mars Missions)',
      'nameFa': 'اسپیس‌ایکس (فناوری‌های فضایی، استارشیپ و ماموریت‌های مریخ ایلان ماسک)',
      'cat': 'ElonMusk',
      'icon': '🚀',
      'price': 112.0,
      'isTop100': true,
      'unit': 'USD',
    },
{
      'symbol': 'STARLINK',
      'name': 'Starlink (SpaceX Satellite Constellation)',
      'nameFa': 'استارلینک (شبکه اینترنت ماهواره‌ای جهانی ایلان ماسک)',
      'cat': 'ElonMusk',
      'icon': '🛰️',
      'price': 85.0,
      'isTop100': true,
      'unit': 'USD',
    },
{
      'symbol': 'XAI',
      'name': 'xAI (Grok AI & Colossus Supercomputer)',
      'nameFa': 'شرکت هوش مصنوعی xAI (خالق Grok و سوپرکامپیوتر کلوسوس ایلان ماسک)',
      'cat': 'ElonMusk',
      'icon': '🧠',
      'price': 45.0,
      'isTop100': true,
      'unit': 'USD',
    },
{
      'symbol': 'X_CORP',
      'name': 'X Corp (Formerly Twitter - Everything App)',
      'nameFa': 'ایکس / توییتر سابق (شبکه اجتماعی جهانی و اپلیکیشن همه‌کاره ایلان ماسک)',
      'cat': 'ElonMusk',
      'icon': '𝕏',
      'price': 38.50,
      'isTop100': true,
      'unit': 'USD',
    },
{
      'symbol': 'NEURALINK',
      'name': 'Neuralink (Brain-Computer Interface & Telepathy)',
      'nameFa': 'نورالینک (تراشه رابط مغز و رایانه و تله‌پاتی ایلان ماسک)',
      'cat': 'ElonMusk',
      'icon': '🧬',
      'price': 55.0,
      'isTop100': true,
      'unit': 'USD',
    },
{
      'symbol': 'BORING',
      'name': 'The Boring Company (Hyperloop & Tunneling)',
      'nameFa': 'بورینگ کمپانی (تونل‌های زیرزمینی حمل‌ونقل سریع هایپرلوپ ایلان ماسک)',
      'cat': 'ElonMusk',
      'icon': '🚇',
      'price': 22.0,
      'isTop100': true,
      'unit': 'USD',
    },
{
      'symbol': 'DOGE',
      'name': 'Dogecoin (Elon Musk Ecosystem Crypto)',
      'nameFa': 'دوج‌کوین (رمزارز محبوب و رسمی اکوسیستم تسلا و پلتفرم ایکس)',
      'cat': 'ElonMusk',
      'icon': '🐕',
      'price': 0.165,
      'isTop100': true,
      'unit': 'USD',
    },
{
      'symbol': 'MC.PA',
      'name': 'LVMH Moët Hennessy Louis Vuitton',
      'nameFa': 'ال‌وی‌ام‌اچ فرانسه (لویی ویتون، دیور، تیفانی، بولگاری - پادشاه برندهای لوکس جهان)',
      'cat': 'Luxury',
      'icon': '👑',
      'price': 635.80,
      'isTop100': true,
      'unit': 'EUR',
    },
{
      'symbol': 'RMS.PA',
      'name': 'Hermès International',
      'nameFa': 'هرمس اینترنشنال (گران‌قیمت‌ترین خانه مد، کیف برکین و چرم دست‌ساز جهان)',
      'cat': 'Luxury',
      'icon': '👜',
      'price': 2085.0,
      'isTop100': true,
      'unit': 'EUR',
    },
{
      'symbol': 'P911.DE',
      'name': 'Porsche AG',
      'nameFa': 'پورشه آلمان (سوپراسپرت‌های لوکس و مهندسی اشتوتگارت)',
      'cat': 'Luxury',
      'icon': '🏎️',
      'price': 68.40,
      'isTop100': true,
      'unit': 'EUR',
    },
{
      'symbol': 'RACE',
      'name': 'Ferrari N.V.',
      'nameFa': 'فراری ایتالیا (سوپراسپرت‌های اشرافی و اسب سرکش مارانلو)',
      'cat': 'Luxury',
      'icon': '🐎',
      'price': 462.80,
      'isTop100': true,
      'unit': 'USD',
    },
{
      'symbol': 'URNM',
      'name': 'Sprott Uranium Miners ETF',
      'nameFa': 'صندوق معادن اورانیوم (سوخت انرژی هسته‌ای دیتاسنترهای AI)',
      'cat': 'Commodities',
      'icon': '☢️',
      'price': 52.80,
      'unit': 'USD',
    },
{
      'symbol': 'TSM',
      'name': 'Taiwan Semiconductor Manufacturing (TSMC)',
      'nameFa': 'تی‌اس‌ام‌سی (سازنده انحصاری تراشه‌های انویدیا، اپل و نبض جهان)',
      'cat': 'Tech',
      'icon': '🇹🇼',
      'price': 195.40,
      'isTop100': true,
      'unit': 'USD',
    },
{
      'symbol': 'ASML',
      'name': 'ASML Holding N.V.',
      'nameFa': 'ای‌اس‌ام‌ال هلند (انحصار ۱۰۰٪ ماشین‌آلات لیتوگرافی فرابنفش چاپ تراشه)',
      'cat': 'Tech',
      'icon': '🔬',
      'price': 712.50,
      'isTop100': true,
      'unit': 'USD',
    },
{
      'symbol': 'AVGO',
      'name': 'Broadcom Inc.',
      'nameFa': 'برودکام (غول تراشه‌های اختصاصی شبکه و هوش مصنوعی)',
      'cat': 'Tech',
      'icon': '📡',
      'price': 178.60,
      'isTop100': true,
      'unit': 'USD',
    },
{
      'symbol': 'USDT/TMN',
      'name': 'Tether to Iranian Toman (USDT/TMN)',
      'nameFa': 'تتر به تومان ایران (نرخ لحظه‌ای بازار آزاد تهران)',
      'cat': 'Forex',
      'icon': '🇮🇷',
      'price': 69400.0,
      'unit': 'USD',
    },
{
      'symbol': 'USDAED=X',
      'name': 'USD/AED (UAE Dirham)',
      'nameFa': 'دلار آمریکا به درهم امارات (USD/AED)',
      'cat': 'Forex',
      'icon': '🇦🇪',
      'price': 3.6725,
      'unit': 'AED',
    },
{
      'symbol': 'DXYZ',
      'name': 'Destiny Tech100 Inc. (SpaceX & OpenAI Portfolio ETF)',
      'nameFa': 'صندوق سرنوشت ۱۰۰ (سبد سهام عمومی اسپیس‌ایکس و اوپن‌ای‌آی در بورس نیویورک)',
      'cat': 'Aerospace',
      'icon': '🌌',
      'price': 18.50,
      'unit': 'USD',
    },
{
      'symbol': 'RKLB',
      'name': 'Rocket Lab USA Inc.',
      'nameFa': 'راکت لب (پرتاب‌های فضایی مداری تجاری و ماهواره‌های ناسا)',
      'cat': 'Aerospace',
      'icon': '🛰️',
      'price': 10.45,
      'unit': 'USD',
    },
{
      'symbol': 'ASTS',
      'name': 'AST SpaceMobile Inc.',
      'nameFa': 'ای‌اس‌تی اسپیس‌موبایل (شبکه پهن‌باند ماهواره‌ای مستقیم به گوشی‌های هوشمند)',
      'cat': 'Aerospace',
      'icon': '📡',
      'price': 26.80,
      'unit': 'USD',
    },
{
      'symbol': 'LUNR',
      'name': 'Intuitive Machines Inc.',
      'nameFa': 'اینتیوتیو ماشینز (فرودگرهای رباتیک ماه و ماموریت‌های آرتمیس ناسا)',
      'cat': 'Aerospace',
      'icon': '🌕',
      'price': 8.35,
      'unit': 'USD',
    },
{
      'symbol': 'BA',
      'name': 'The Boeing Company',
      'nameFa': 'بوئینگ (غول هواپیماسازی، فضاپیما و کپسول فضایی استارلاینر)',
      'cat': 'Aerospace',
      'icon': '✈️',
      'price': 155.20,
      'isTop100': true,
      'unit': 'USD',
    },
{
      'symbol': 'NOC',
      'name': 'Northrop Grumman Corporation',
      'nameFa': 'نورثروپ گرومن (تلسکوپ فضایی جیمز وب، بمب‌افکن B-21 و سامانه‌های فضایی)',
      'cat': 'Aerospace',
      'icon': '🛡️',
      'price': 512.40,
      'unit': 'USD',
    },
{
      'symbol': 'SPCE',
      'name': 'Virgin Galactic Holdings Inc.',
      'nameFa': 'ویرجین گلکتیک (گردشگری فضایی تجاری زیرمداری)',
      'cat': 'Aerospace',
      'icon': '👨‍🚀',
      'price': 7.15,
      'unit': 'USD',
    },
{
      'symbol': 'MARA',
      'name': 'MARA Holdings Inc. (Marathon Digital)',
      'nameFa': 'ماراتون دیجیتال / MARA (بزرگ‌ترین شرکت عمومی استخراج و خزانه‌داری بیت‌کوین)',
      'cat': 'FintechMining',
      'icon': '⛏️',
      'price': 18.90,
      'unit': 'USD',
    },
{
      'symbol': 'RIOT',
      'name': 'Riot Platforms Inc.',
      'nameFa': 'رایوت پلتفرمز (زیرساخت دیتاسنتر و مزارع استخراج بیت‌کوین)',
      'cat': 'FintechMining',
      'icon': '⚡',
      'price': 9.85,
      'unit': 'USD',
    },
{
      'symbol': 'CLSK',
      'name': 'CleanSpark Inc.',
      'nameFa': 'کلین‌اسپارک (استخراج سبز و پربازده بیت‌کوین با انرژی پاک)',
      'cat': 'FintechMining',
      'icon': '🔋',
      'price': 12.40,
      'unit': 'USD',
    },
{
      'symbol': 'HOOD',
      'name': 'Robinhood Markets Inc.',
      'nameFa': 'رابین‌هود (کارگزاری پیشرو معامله سهام، آپشن و کریپتو)',
      'cat': 'FintechMining',
      'icon': '🏹',
      'price': 27.30,
      'unit': 'USD',
    },
{
      'symbol': 'RDDT',
      'name': 'Reddit Inc.',
      'nameFa': 'ردیت (انجمن بزرگ گفتگوی وب و مرجع داده‌های آموزش هوش مصنوعی)',
      'cat': 'FintechMining',
      'icon': '🤖',
      'price': 82.60,
      'unit': 'USD',
    },
{
      'symbol': 'SHOP',
      'name': 'Shopify Inc.',
      'nameFa': 'شاپیفای (غول تجارت الکترونیک و فروشگاه‌ساز آنلاین جهانی)',
      'cat': 'Top100',
      'icon': '🛍️',
      'price': 81.40,
      'isTop100': true,
      'unit': 'USD',
    },
{
      'symbol': 'SNOW',
      'name': 'Snowflake Inc.',
      'nameFa': 'اسنوفلیک (انبار داده‌های کلاد ابری و تحلیل داده‌های هوش مصنوعی)',
      'cat': 'Top100',
      'icon': '❄️',
      'price': 118.50,
      'isTop100': true,
      'unit': 'USD',
    },
{
      'symbol': 'NVDA',
      'name': 'NVIDIA Corporation',
      'nameFa': 'انویدیا (رهبر هوش مصنوعی)',
      'cat': 'Top100',
      'icon': '🟢',
      'price': 138.25,
      'isTop100': true,
      'unit': 'USD',
    },
{
      'symbol': 'AAPL',
      'name': 'Apple Inc.',
      'nameFa': 'اپل (غول سخت‌افزار و اکوسیستم)',
      'cat': 'Top100',
      'icon': '🍎',
      'price': 228.50,
      'isTop100': true,
      'unit': 'USD',
    },
{
      'symbol': 'MSFT',
      'name': 'Microsoft Corporation',
      'nameFa': 'مایکروسافت (ویندوز، کلاد و OpenAI)',
      'cat': 'Top100',
      'icon': '🪟',
      'price': 428.10,
      'isTop100': true,
      'unit': 'USD',
    },
{
      'symbol': 'GOOGL',
      'name': 'Alphabet Inc. (Google)',
      'nameFa': 'گوگل / آلفابت (موتور جستجو و Gemini AI)',
      'cat': 'Top100',
      'icon': '🔍',
      'price': 165.30,
      'isTop100': true,
      'unit': 'USD',
    },
{
      'symbol': 'AMZN',
      'name': 'Amazon.com Inc.',
      'nameFa': 'آمازون (تجارت الکترونیک و AWS)',
      'cat': 'Top100',
      'icon': '📦',
      'price': 186.70,
      'isTop100': true,
      'unit': 'USD',
    },
{
      'symbol': 'META',
      'name': 'Meta Platforms Inc.',
      'nameFa': 'متا (اینستاگرام، واتساپ و Llama AI)',
      'cat': 'Top100',
      'icon': '🌐',
      'price': 585.20,
      'isTop100': true,
      'unit': 'USD',
    },
{
      'symbol': 'BRK-B',
      'name': 'Berkshire Hathaway',
      'nameFa': 'برکشایر هاتاوی (هلدینگ وارن بافت)',
      'cat': 'Top100',
      'icon': '🎩',
      'price': 462.10,
      'isTop100': true,
      'unit': 'USD',
    },
{
      'symbol': 'LLY',
      'name': 'Eli Lilly and Company',
      'nameFa': 'الی لیلی (ارزشمندترین شرکت داروسازی)',
      'cat': 'Top100',
      'icon': '💊',
      'price': 910.30,
      'isTop100': true,
      'unit': 'USD',
    },
{
      'symbol': 'JPM',
      'name': 'JPMorgan Chase & Co.',
      'nameFa': 'جی‌پی مورگان (بزرگ‌ترین بانک وال‌استریت)',
      'cat': 'Top100',
      'icon': '🏦',
      'price': 222.60,
      'isTop100': true,
      'unit': 'USD',
    },
{
      'symbol': 'WMT',
      'name': 'Walmart Inc.',
      'nameFa': 'والمارت (بزرگ‌ترین زنجیره خرده‌فروشی)',
      'cat': 'Top100',
      'icon': '🏬',
      'price': 80.50,
      'isTop100': true,
      'unit': 'USD',
    },
{
      'symbol': 'V',
      'name': 'Visa Inc.',
      'nameFa': 'ویزا کارت (غول پرداخت و تراکنش جهانی)',
      'cat': 'Top100',
      'icon': '💳',
      'price': 288.90,
      'isTop100': true,
      'unit': 'USD',
    },
{
      'symbol': 'NVO',
      'name': 'Novo Nordisk A/S',
      'nameFa': 'نوو نوردیسک (داروسازی اوزمپیک و دیابت)',
      'cat': 'Top100',
      'icon': '🇩🇰',
      'price': 116.80,
      'isTop100': true,
      'unit': 'USD',
    },
{
      'symbol': 'TCEHY',
      'name': 'Tencent Holdings',
      'nameFa': 'تنسنت (غول اینترنت و گیمینگ چین)',
      'cat': 'Top100',
      'icon': '🎮',
      'price': 54.80,
      'isTop100': true,
      'unit': 'USD',
    },
{
      'symbol': 'XOM',
      'name': 'Exxon Mobil Corp.',
      'nameFa': 'اکسون موبیل (غول نفت و گاز)',
      'cat': 'Top100',
      'icon': '🛢️',
      'price': 120.40,
      'isTop100': true,
      'unit': 'USD',
    },
{
      'symbol': 'UNH',
      'name': 'UnitedHealth Group',
      'nameFa': 'یونایتدهلث (بیمه و خدمات سلامت)',
      'cat': 'Top100',
      'icon': '🏥',
      'price': 572.80,
      'isTop100': true,
      'unit': 'USD',
    },
{
      'symbol': 'ORCL',
      'name': 'Oracle Corporation',
      'nameFa': 'اوراکل (دیتابیس و کلاد سازمانی)',
      'cat': 'Top100',
      'icon': '💾',
      'price': 175.60,
      'isTop100': true,
      'unit': 'USD',
    },
{
      'symbol': 'MA',
      'name': 'Mastercard Inc.',
      'nameFa': 'مسترکارت (شبکه پرداخت بین‌المللی)',
      'cat': 'Top100',
      'icon': '💳',
      'price': 505.40,
      'isTop100': true,
      'unit': 'USD',
    },
{
      'symbol': 'COST',
      'name': 'Costco Wholesale',
      'nameFa': 'کاستکو (فروشگاه‌های زنجیره‌ای)',
      'cat': 'Top100',
      'icon': '🛒',
      'price': 905.80,
      'isTop100': true,
      'unit': 'USD',
    },
{
      'symbol': 'HD',
      'name': 'The Home Depot',
      'nameFa': 'هوم دیپو (لوازم ساختمانی و منزل)',
      'cat': 'Top100',
      'icon': '🔨',
      'price': 398.50,
      'isTop100': true,
      'unit': 'USD',
    },
{
      'symbol': 'PG',
      'name': 'Procter & Gamble',
      'nameFa': 'پروکتر اند گمبل (کالاهای مصرفی)',
      'cat': 'Top100',
      'icon': '🧼',
      'price': 168.20,
      'isTop100': true,
      'unit': 'USD',
    },
{
      'symbol': 'JNJ',
      'name': 'Johnson & Johnson',
      'nameFa': 'جانسون اند جانسون (تجهیزات پزشکی و دارو)',
      'cat': 'Top100',
      'icon': '🩹',
      'price': 161.40,
      'isTop100': true,
      'unit': 'USD',
    },
{
      'symbol': 'ABBV',
      'name': 'AbbVie Inc.',
      'nameFa': 'اب‌وی (بیوداروسازی)',
      'cat': 'Top100',
      'icon': '🧬',
      'price': 188.50,
      'isTop100': true,
      'unit': 'USD',
    },
{
      'symbol': 'BAC',
      'name': 'Bank of America',
      'nameFa': 'بنک آو آمریکا (بانکداری کلان)',
      'cat': 'Top100',
      'icon': '🏦',
      'price': 42.30,
      'isTop100': true,
      'unit': 'USD',
    },
{
      'symbol': 'BABA',
      'name': 'Alibaba Group Holding',
      'nameFa': 'علی‌بابا (غول تجارت الکترونیک چین)',
      'cat': 'Top100',
      'icon': '🛍️',
      'price': 98.40,
      'isTop100': true,
      'unit': 'USD',
    },
{
      'symbol': 'NFLX',
      'name': 'Netflix Inc.',
      'nameFa': 'نتفلیکس (سرویس پخش آنلاین سرگرمی)',
      'cat': 'Top100',
      'icon': '🎬',
      'price': 720.60,
      'isTop100': true,
      'unit': 'USD',
    },
{
      'symbol': 'SAP',
      'name': 'SAP SE',
      'nameFa': 'اس‌ای‌پی (نرم‌افزارهای سازمانی آلمان)',
      'cat': 'Top100',
      'icon': '🇩🇪',
      'price': 234.10,
      'isTop100': true,
      'unit': 'USD',
    },
{
      'symbol': 'KO',
      'name': 'The Coca-Cola Company',
      'nameFa': 'کوکاکولا (نوشیدنی‌های بین‌المللی)',
      'cat': 'Top100',
      'icon': '🥤',
      'price': 68.40,
      'isTop100': true,
      'unit': 'USD',
    },
{
      'symbol': 'CVX',
      'name': 'Chevron Corporation',
      'nameFa': 'شورون (نفت، گاز و پتروشیمی)',
      'cat': 'Top100',
      'icon': '⛽',
      'price': 152.60,
      'isTop100': true,
      'unit': 'USD',
    },
{
      'symbol': 'CRM',
      'name': 'Salesforce Inc.',
      'nameFa': 'سیلزفورس (مدیریت ارتباط با مشتری CRM)',
      'cat': 'Top100',
      'icon': '☁️',
      'price': 294.50,
      'isTop100': true,
      'unit': 'USD',
    },
{
      'symbol': 'AMD',
      'name': 'Advanced Micro Devices',
      'nameFa': 'ای‌ام‌دی (پردازنده‌های Instinct AI و سرور)',
      'cat': 'Top100',
      'icon': '🔴',
      'price': 156.90,
      'isTop100': true,
      'unit': 'USD',
    },
{
      'symbol': 'LVMUY',
      'name': 'LVMH Moet Hennessy',
      'nameFa': 'ال‌وی‌ام‌اچ (برندهای لوکس فرانسه)',
      'cat': 'Top100',
      'icon': '👜',
      'price': 132.80,
      'isTop100': true,
      'unit': 'USD',
    },
{
      'symbol': 'TM',
      'name': 'Toyota Motor Corp.',
      'nameFa': 'تویوتا موتور (غول خودروسازی ژاپن)',
      'cat': 'Top100',
      'icon': '🚗',
      'price': 176.40,
      'isTop100': true,
      'unit': 'USD',
    },
{
      'symbol': 'HESAY',
      'name': 'Hermes International',
      'nameFa': 'هرمس اینترنشنال (مد لوکس فرانسه)',
      'cat': 'Top100',
      'icon': '🧣',
      'price': 225.60,
      'isTop100': true,
      'unit': 'USD',
    },
{
      'symbol': 'AZN',
      'name': 'AstraZeneca PLC',
      'nameFa': 'آسترازنکا (داروسازی بریتانیا)',
      'cat': 'Top100',
      'icon': '💉',
      'price': 81.20,
      'isTop100': true,
      'unit': 'USD',
    },
{
      'symbol': 'NVS',
      'name': 'Novartis AG',
      'nameFa': 'نووارتیس (بهداشت و داروی سوئیس)',
      'cat': 'Top100',
      'icon': '🇨🇭',
      'price': 112.50,
      'isTop100': true,
      'unit': 'USD',
    },
{
      'symbol': 'ADBE',
      'name': 'Adobe Inc.',
      'nameFa': 'ادوبی (فتوشاپ، پریمیر و هوش مصنوعی Firefly)',
      'cat': 'Top100',
      'icon': '🎨',
      'price': 508.40,
      'isTop100': true,
      'unit': 'USD',
    },
{
      'symbol': 'CSCO',
      'name': 'Cisco Systems',
      'nameFa': 'سیسکو سیستمز (زیرساخت شبکه و امنیت)',
      'cat': 'Top100',
      'icon': '🌐',
      'price': 55.80,
      'isTop100': true,
      'unit': 'USD',
    },
{
      'symbol': 'QCOM',
      'name': 'Qualcomm Inc.',
      'nameFa': 'کوالکام (مودم‌های 5G و اسنپ‌دراگون)',
      'cat': 'Top100',
      'icon': '📱',
      'price': 168.50,
      'isTop100': true,
      'unit': 'USD',
    },
{
      'symbol': 'LIN',
      'name': 'Linde plc',
      'nameFa': 'لیندا (گازهای صنعتی و پزشکی)',
      'cat': 'Top100',
      'icon': '🧪',
      'price': 458.20,
      'isTop100': true,
      'unit': 'USD',
    },
{
      'symbol': 'WFC',
      'name': 'Wells Fargo & Co.',
      'nameFa': 'ولز فارگو (خدمات مالی و وام مسکن)',
      'cat': 'Top100',
      'icon': '🏦',
      'price': 64.20,
      'isTop100': true,
      'unit': 'USD',
    },
{
      'symbol': 'MCD',
      'name': 'McDonald\'s Corp.',
      'nameFa': 'مک‌دونالد (بزرگ‌ترین فست‌فود دنیا)',
      'cat': 'Top100',
      'icon': '🍔',
      'price': 296.80,
      'isTop100': true,
      'unit': 'USD',
    },
{
      'symbol': 'PEP',
      'name': 'PepsiCo Inc.',
      'nameFa': 'پپسی‌کو (نوشیدنی و اسنک چیپس)',
      'cat': 'Top100',
      'icon': '🥤',
      'price': 171.20,
      'isTop100': true,
      'unit': 'USD',
    },
{
      'symbol': 'ACN',
      'name': 'Accenture plc',
      'nameFa': 'اکسنچر (مشاوره مدیریت و فناوری اطلاعات)',
      'cat': 'Top100',
      'icon': '💼',
      'price': 358.40,
      'isTop100': true,
      'unit': 'USD',
    },
{
      'symbol': 'PLTR',
      'name': 'Palantir Technologies',
      'nameFa': 'پالانتیر (تحلیل کلان‌داده و هوش دفاعی AIP)',
      'cat': 'Top100',
      'icon': '🔮',
      'price': 44.10,
      'isTop100': true,
      'unit': 'USD',
    },
{
      'symbol': 'IBM',
      'name': 'International Business Machines',
      'nameFa': 'آی‌بی‌ام (سرورهای کوانتومی و هوش مصنوعی)',
      'cat': 'Top100',
      'icon': '💻',
      'price': 214.80,
      'isTop100': true,
      'unit': 'USD',
    },
{
      'symbol': 'NOW',
      'name': 'ServiceNow Inc.',
      'nameFa': 'سرویس‌ناو (اتوماسیون فرایندهای سازمانی)',
      'cat': 'Top100',
      'icon': '⚙️',
      'price': 918.40,
      'isTop100': true,
      'unit': 'USD',
    },
{
      'symbol': 'GE',
      'name': 'GE Aerospace',
      'nameFa': 'جنرال الکتریک (موتورهای توربینی هواپیما)',
      'cat': 'Top100',
      'icon': '✈️',
      'price': 188.60,
      'isTop100': true,
      'unit': 'USD',
    },
{
      'symbol': 'TMUS',
      'name': 'T-Mobile US Inc.',
      'nameFa': 'تی‌موبایل (اپراتور ارتباطی 5G آمریکا)',
      'cat': 'Top100',
      'icon': '📶',
      'price': 218.40,
      'isTop100': true,
      'unit': 'USD',
    },
{
      'symbol': 'INTU',
      'name': 'Intuit Inc.',
      'nameFa': 'اینتویت (نرم‌افزارهای حسابداری مالیاتی)',
      'cat': 'Top100',
      'icon': '📊',
      'price': 635.80,
      'isTop100': true,
      'unit': 'USD',
    },
{
      'symbol': 'TXN',
      'name': 'Texas Instruments',
      'nameFa': 'تگزاس اینسترومنتس (تراشه‌های آنالوگ و صنعتی)',
      'cat': 'Top100',
      'icon': '📟',
      'price': 202.40,
      'isTop100': true,
      'unit': 'USD',
    },
{
      'symbol': 'MS',
      'name': 'Morgan Stanley',
      'nameFa': 'مورگان استنلی (مدیریت دارایی و سرمایه‌گذاری)',
      'cat': 'Top100',
      'icon': '📈',
      'price': 118.50,
      'isTop100': true,
      'unit': 'USD',
    },
{
      'symbol': 'GS',
      'name': 'The Goldman Sachs Group',
      'nameFa': 'گلدمن ساکس (بانکداری سرمایه‌گذاری)',
      'cat': 'Top100',
      'icon': '🏛️',
      'price': 518.20,
      'isTop100': true,
      'unit': 'USD',
    },
{
      'symbol': 'CAT',
      'name': 'Caterpillar Inc.',
      'nameFa': 'کاترپیلار (ماشین‌آلات سنگین معدنی)',
      'cat': 'Top100',
      'icon': '🚜',
      'price': 388.40,
      'isTop100': true,
      'unit': 'USD',
    },
{
      'symbol': 'AMGN',
      'name': 'Amgen Inc.',
      'nameFa': 'امژن (پیشگام بیوتکنولوژی و دارو)',
      'cat': 'Top100',
      'icon': '🔬',
      'price': 315.60,
      'isTop100': true,
      'unit': 'USD',
    },
{
      'symbol': 'UBER',
      'name': 'Uber Technologies',
      'nameFa': 'اوبر (تاکسی اینترنتی و تحویل کالا)',
      'cat': 'Top100',
      'icon': '🚗',
      'price': 78.40,
      'isTop100': true,
      'unit': 'USD',
    },
{
      'symbol': 'DIS',
      'name': 'The Walt Disney Company',
      'nameFa': 'والت دیزنی (سرگرمی، پارک‌ها و دیزنی‌پلاس)',
      'cat': 'Top100',
      'icon': '🏰',
      'price': 96.40,
      'isTop100': true,
      'unit': 'USD',
    },
{
      'symbol': 'PM',
      'name': 'Philip Morris International',
      'nameFa': 'فیلیپ موریس (دخانیات و محصولات جدید)',
      'cat': 'Top100',
      'icon': '🚬',
      'price': 131.20,
      'isTop100': true,
      'unit': 'USD',
    },
{
      'symbol': 'AXP',
      'name': 'American Express',
      'nameFa': 'امریکن اکسپرس (کارت‌های اعتباری ممتاز)',
      'cat': 'Top100',
      'icon': '💳',
      'price': 274.60,
      'isTop100': true,
      'unit': 'USD',
    },
{
      'symbol': 'ISRG',
      'name': 'Intuitive Surgical',
      'nameFa': 'اینتویتیو سرجیکال (ربات‌های جراح داوینچی)',
      'cat': 'Top100',
      'icon': '🤖',
      'price': 512.40,
      'isTop100': true,
      'unit': 'USD',
    },
{
      'symbol': 'VZ',
      'name': 'Verizon Communications',
      'nameFa': 'ورایزون (بزرگ‌ترین مخابرات آمریکا)',
      'cat': 'Top100',
      'icon': '📞',
      'price': 42.80,
      'isTop100': true,
      'unit': 'USD',
    },
{
      'symbol': 'BKNG',
      'name': 'Booking Holdings',
      'nameFa': 'بوکینگ (رزرواسیون هتل و گردشگری آنلاین)',
      'cat': 'Top100',
      'icon': '🏨',
      'price': 4480.00,
      'isTop100': true,
      'unit': 'USD',
    },
{
      'symbol': 'BLK',
      'name': 'BlackRock Inc.',
      'nameFa': 'بلک‌راک (بزرگ‌ترین مدیر دارایی دنیا و IBIT)',
      'cat': 'Top100',
      'icon': '🏛️',
      'price': 985.40,
      'isTop100': true,
      'unit': 'USD',
    },
{
      'symbol': 'PFE',
      'name': 'Pfizer Inc.',
      'nameFa': 'فایزر (واکسن‌ها و ایمنی‌شناسی)',
      'cat': 'Top100',
      'icon': '💉',
      'price': 28.50,
      'isTop100': true,
      'unit': 'USD',
    },
{
      'symbol': 'SNY',
      'name': 'Sanofi SA',
      'nameFa': 'سانوفی (داروسازی چندملیتی فرانسه)',
      'cat': 'Top100',
      'icon': '🇫🇷',
      'price': 54.20,
      'isTop100': true,
      'unit': 'USD',
    },
{
      'symbol': 'SONY',
      'name': 'Sony Group Corp.',
      'nameFa': 'سونی (پلی‌استیشن و سنسورهای تصویر)',
      'cat': 'Top100',
      'icon': '🎮',
      'price': 94.80,
      'isTop100': true,
      'unit': 'USD',
    },
{
      'symbol': 'SIEGY',
      'name': 'Siemens AG',
      'nameFa': 'زیمنس (اتوماسیون صنعتی آلمان)',
      'cat': 'Top100',
      'icon': '🇩🇪',
      'price': 98.40,
      'isTop100': true,
      'unit': 'USD',
    },
{
      'symbol': 'DHR',
      'name': 'Danaher Corporation',
      'nameFa': 'داناخر (تجهیزات آزمایشگاهی و ژنتیک)',
      'cat': 'Top100',
      'icon': '🧬',
      'price': 264.20,
      'isTop100': true,
      'unit': 'USD',
    },
{
      'symbol': 'RTX',
      'name': 'RTX Corporation (Raytheon)',
      'nameFa': 'آر‌تی‌ایکس / ریتون (سامانه‌های موشکی پاتریوت)',
      'cat': 'Top100',
      'icon': '🚀',
      'price': 124.60,
      'isTop100': true,
      'unit': 'USD',
    },
{
      'symbol': 'HON',
      'name': 'Honeywell International',
      'nameFa': 'هانی‌ول (تجهیزات هوافضا و سنسورها)',
      'cat': 'Top100',
      'icon': '✈️',
      'price': 212.80,
      'isTop100': true,
      'unit': 'USD',
    },
{
      'symbol': 'UNP',
      'name': 'Union Pacific Corp.',
      'nameFa': 'یونیون پاسیفیک (بزرگ‌ترین راه‌آهن آمریکا)',
      'cat': 'Top100',
      'icon': '🚂',
      'price': 238.40,
      'isTop100': true,
      'unit': 'USD',
    },
{
      'symbol': 'AMAT',
      'name': 'Applied Materials',
      'nameFa': 'اپلاید متریالز (تجهیزات ساخت ویفر تراشه)',
      'cat': 'Top100',
      'icon': '🔬',
      'price': 192.50,
      'isTop100': true,
      'unit': 'USD',
    },
{
      'symbol': 'TTE',
      'name': 'TotalEnergies SE',
      'nameFa': 'توتال‌انرژیز (غول انرژی فرانسه)',
      'cat': 'Top100',
      'icon': '🇫🇷',
      'price': 63.80,
      'isTop100': true,
      'unit': 'USD',
    },
{
      'symbol': 'MU',
      'name': 'Micron Technology',
      'nameFa': 'میکرون (حافظه‌های HBM3e هوش مصنوعی)',
      'cat': 'Top100',
      'icon': '💾',
      'price': 110.50,
      'isTop100': true,
      'unit': 'USD',
    },
{
      'symbol': 'COP',
      'name': 'ConocoPhillips',
      'nameFa': 'کونوکو فیلیپس (اکتشاف و استخراج نفت)',
      'cat': 'Top100',
      'icon': '🛢️',
      'price': 108.40,
      'isTop100': true,
      'unit': 'USD',
    },
{
      'symbol': 'ETN',
      'name': 'Eaton Corporation plc',
      'nameFa': 'ایتون (مدیریت هوشمند برق و دیتاسنتر)',
      'cat': 'Top100',
      'icon': '⚡',
      'price': 342.80,
      'isTop100': true,
      'unit': 'USD',
    },
{
      'symbol': 'PANW',
      'name': 'Palo Alto Networks',
      'nameFa': 'پالو آلتو نتورکس (امنیت سایبری و فایروال)',
      'cat': 'Top100',
      'icon': '🛡️',
      'price': 365.40,
      'isTop100': true,
      'unit': 'USD',
    },
{
      'symbol': 'NKE',
      'name': 'NIKE Inc.',
      'nameFa': 'نایکی (کفش و پوشاک ورزشی بین‌المللی)',
      'cat': 'Top100',
      'icon': '👟',
      'price': 82.60,
      'isTop100': true,
      'unit': 'USD',
    },
{
      'symbol': 'BMY',
      'name': 'Bristol Myers Squibb',
      'nameFa': 'بریستول مایرز (داروسازی سرطان و قلب)',
      'cat': 'Top100',
      'icon': '💊',
      'price': 52.40,
      'isTop100': true,
      'unit': 'USD',
    },
{
      'symbol': 'LMT',
      'name': 'Lockheed Martin Corp.',
      'nameFa': 'لاکهید مارتین (سازنده جنگنده‌های F-35)',
      'cat': 'Top100',
      'icon': '🛩️',
      'price': 570.40,
      'isTop100': true,
      'unit': 'USD',
    },
{
      'symbol': 'SBUX',
      'name': 'Starbucks Corporation',
      'nameFa': 'استارباکس (قهوه‌خانه‌های زنجیره‌ای)',
      'cat': 'Top100',
      'icon': '☕',
      'price': 97.50,
      'isTop100': true,
      'unit': 'USD',
    },
{
      'symbol': 'PDD',
      'name': 'PDD Holdings Inc. (Temu)',
      'nameFa': 'پین‌دودو / تیمو (فروشگاه جهانی Temu)',
      'cat': 'Top100',
      'icon': '🏷️',
      'price': 122.80,
      'isTop100': true,
      'unit': 'USD',
    },
{
      'symbol': 'MSTR',
      'name': 'MicroStrategy Inc.',
      'nameFa': 'مایکرواستراتژی (بزرگ‌ترین خزانه‌داری بیت‌کوین)',
      'cat': 'Top100',
      'icon': '🪙',
      'price': 235.50,
      'isTop100': true,
      'unit': 'USD',
    },
{
      'symbol': 'COIN',
      'name': 'Coinbase Global Inc.',
      'nameFa': 'کوین‌بیس (صرافی رسمی بورس نزدک)',
      'cat': 'Top100',
      'icon': '🔵',
      'price': 214.30,
      'isTop100': true,
      'unit': 'USD',
    },
{
      'symbol': 'LRCX',
      'name': 'Lam Research Corp.',
      'nameFa': 'لم ریسرچ (فرایندهای اچینگ تراشه)',
      'cat': 'Top100',
      'icon': '🔬',
      'price': 76.40,
      'isTop100': true,
      'unit': 'USD',
    },
{
      'symbol': 'BSX',
      'name': 'Boston Scientific Corp.',
      'nameFa': 'بوستون ساینتیفیک (ایمپلنت‌های پزشکی)',
      'cat': 'Top100',
      'icon': '🫀',
      'price': 86.20,
      'isTop100': true,
      'unit': 'USD',
    },
{
      'symbol': 'KLAC',
      'name': 'KLA Corporation',
      'nameFa': 'کی‌ال‌ای (بازرسی کیفیت نانو تراشه)',
      'cat': 'Top100',
      'icon': '🔍',
      'price': 698.50,
      'isTop100': true,
      'unit': 'USD',
    },
{
      'symbol': 'SBGSY',
      'name': 'Schneider Electric SE',
      'nameFa': 'اشنایدر الکتریک (زیرساخت توزیع برق فرانسه)',
      'cat': 'Top100',
      'icon': '⚡',
      'price': 52.80,
      'isTop100': true,
      'unit': 'USD',
    },
{
      'symbol': 'SYK',
      'name': 'Stryker Corporation',
      'nameFa': 'استرایکر (تجهیزات ارتوپدی و جراحی)',
      'cat': 'Top100',
      'icon': '🦾',
      'price': 365.20,
      'isTop100': true,
      'unit': 'USD',
    },
{
      'symbol': 'ADI',
      'name': 'Analog Devices Inc.',
      'nameFa': 'آنالوگ دیوایسز (پردازش سیگنال و سنسور)',
      'cat': 'Top100',
      'icon': '📡',
      'price': 216.40,
      'isTop100': true,
      'unit': 'USD',
    },
{
      'symbol': 'VRTX',
      'name': 'Vertex Pharmaceuticals',
      'nameFa': 'ورتکس (ژن‌درمانی بیماری‌های خاص)',
      'cat': 'Top100',
      'icon': '🧬',
      'price': 478.60,
      'isTop100': true,
      'unit': 'USD',
    },
{
      'symbol': 'ARM',
      'name': 'Arm Holdings plc',
      'nameFa': 'آرم هولدینگز (معماری پردازنده‌های موبایل و سرور)',
      'cat': 'Top100',
      'icon': '📐',
      'price': 142.30,
      'isTop100': true,
      'unit': 'USD',
    },
{
      'symbol': 'CRWD',
      'name': 'CrowdStrike Holdings',
      'nameFa': 'کراوداسترایک (امنیت شبکه فالکون AI)',
      'cat': 'Top100',
      'icon': '🦅',
      'price': 312.40,
      'isTop100': true,
      'unit': 'USD',
    },
{
      'symbol': 'SMCI',
      'name': 'Super Micro Computer',
      'nameFa': 'سوپرمیکرو (سرورهای دیتاسنتر مایع‌خنک AI)',
      'cat': 'Top100',
      'icon': '🖥️',
      'price': 46.80,
      'isTop100': true,
      'unit': 'USD',
    },
{
      'symbol': 'INTC',
      'name': 'Intel Corporation',
      'nameFa': 'اینتل (پردازنده‌های کامپیوتر و کارخانجات فاندری)',
      'cat': 'Top100',
      'icon': '🔷',
      'price': 22.80,
      'isTop100': true,
      'unit': 'USD',
    },
{
      'symbol': 'BIDU',
      'name': 'Baidu Inc.',
      'nameFa': 'بایدو (غول هوش مصنوعی و خودرو خودران چین)',
      'cat': 'Top100',
      'icon': '🇨🇳',
      'price': 89.20,
      'isTop100': true,
      'unit': 'USD',
    },
{
      'symbol': 'NIO',
      'name': 'NIO Inc.',
      'nameFa': 'نیو (خودروهای برقی هوشمند با تعویض باتری)',
      'cat': 'Top100',
      'icon': '🚙',
      'price': 5.25,
      'isTop100': true,
      'unit': 'USD',
    },
  ];

  @override
  Future<List<CurrencyPair>> fetchCurrencyPairs() async {
    return predefinedStocks.map<CurrencyPair>((s) {
      final sym = s['symbol'] as String;
      final unit = (s['unit'] as String?) ?? 'USD';
      return CurrencyPair(
        baseCurrency: sym,
        counterCurrency: unit,
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
      asOf: ticker.asOf,
      state: ticker.state,
      quoteUnit: ticker.quoteUnit,
      source: ticker.source,
    );
  }

  static final Map<String, MarketTicker> _lastKnownLiveTickers = {};
  static Map<String, dynamic>? _cachedCoinGeckoGlobalData;
  static DateTime? _cachedCoinGeckoTime;

  static const Map<String, String> stooqSymbolMap = {
    '^GSPC': '^spx',
    '^DJI': '^dji',
    '^IXIC': '^ndq',
    '^RUT': '^rut',
    'AAPL': 'aapl.us',
    'MSFT': 'msft.us',
    'GOOGL': 'googl.us',
    'AMZN': 'amzn.us',
    'NVDA': 'nvda.us',
    'TSLA': 'tsla.us',
    'EURUSD=X': 'eurusd',
    'GBPUSD=X': 'gbpusd',
    'USDJPY=X': 'usdjpy',
    'GC=F': 'xauusd',
    'CL=F': 'cl.f',
  };

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
        Map<String, dynamic>? data;
        final now = DateTime.now();
        if (_cachedCoinGeckoGlobalData != null &&
            _cachedCoinGeckoTime != null &&
            now.difference(_cachedCoinGeckoTime!) < const Duration(seconds: 60)) {
          data = _cachedCoinGeckoGlobalData;
        } else {
          final res = await _client
              .get(Uri.parse('https://api.coingecko.com/api/v3/global'))
              .timeout(const Duration(seconds: 5));
          if (res.statusCode == 200) {
            final body = jsonDecode(res.body);
            if (body is Map && body['data'] is Map<String, dynamic>) {
              data = body['data'] as Map<String, dynamic>;
              _cachedCoinGeckoGlobalData = data;
              _cachedCoinGeckoTime = now;
            }
          } else {
            debugPrint('CoinGecko /global error: HTTP ${res.statusCode}');
          }
        }

        if (data != null) {
          final totalUsdNum = data['total_market_cap']?['usd'] as num?;
          final marketCapPct = data['market_cap_percentage'] as Map<String, dynamic>?;

          if (totalUsdNum != null && marketCapPct != null) {
            final double totalUsd = totalUsdNum.toDouble();
            final btcPct = (marketCapPct['btc'] as num?)?.toDouble();
            final ethPct = (marketCapPct['eth'] as num?)?.toDouble();
            final usdtPct = (marketCapPct['usdt'] as num?)?.toDouble();

            double targetValue = 0.0;
            String quoteUnit = 'Billion USD';

            if (cleanSymbol == 'TOTAL') {
              targetValue = totalUsd / 1e9; // in Billions USD
              quoteUnit = 'Billion USD';
            } else if (cleanSymbol == 'TOTAL2' && btcPct != null) {
              targetValue = (totalUsd * (100 - btcPct) / 100) / 1e9;
              quoteUnit = 'Billion USD';
            } else if (cleanSymbol == 'TOTAL3' && btcPct != null && ethPct != null) {
              targetValue = (totalUsd * (100 - btcPct - ethPct) / 100) / 1e9;
              quoteUnit = 'Billion USD';
            } else if (cleanSymbol == 'BTC.D' && btcPct != null) {
              targetValue = btcPct;
              quoteUnit = '%';
            } else if (cleanSymbol == 'USDT.D' && usdtPct != null) {
              targetValue = usdtPct;
              quoteUnit = '%';
            } else if (cleanSymbol == 'ETH.D' && ethPct != null) {
              targetValue = ethPct;
              quoteUnit = '%';
            }

            final updatedAt = data['updated_at'] as int?;
            final asOf = updatedAt != null
                ? DateTime.fromMillisecondsSinceEpoch(updatedAt * 1000, isUtc: true)
                : now;

            if (targetValue > 0) {
              final ticker = MarketTicker(
                exchangeId: id,
                pair: pair,
                lastPrice: targetValue,
                volume24h: 0.0,
                timestamp: asOf,
                asOf: asOf,
                state: 'live',
                quoteUnit: quoteUnit,
                source: 'CoinGecko',
              );
              _lastKnownLiveTickers[cleanSymbol] = ticker;
              return ticker;
            }
          }
        }
      } catch (e) {
        debugPrint('GlobalStocksExchange CoinGecko fetch error ($cleanSymbol): $e');
      }
    }

    if (cleanSymbol == 'CRYPTO_FGI') {
      try {
        final res = await _client
            .get(Uri.parse('https://api.alternative.me/fng/'))
            .timeout(const Duration(seconds: 4));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          final first = data['data']?[0];
          final valStr = first?['value'];
          final val = double.tryParse(valStr?.toString() ?? '');
          final tsStr = first?['timestamp']?.toString();
          final tsSec = tsStr != null ? int.tryParse(tsStr) : null;
          final asOf = tsSec != null
              ? DateTime.fromMillisecondsSinceEpoch(tsSec * 1000, isUtc: true)
              : null;

          if (val != null && val > 0) {
            final ticker = MarketTicker(
              exchangeId: id,
              pair: pair,
              lastPrice: val,
              volume24h: 0.0,
              timestamp: asOf ?? DateTime.now(),
              asOf: asOf,
              state: 'delayed',
              quoteUnit: 'pts',
              source: 'AlternativeMe',
            );
            _lastKnownLiveTickers[cleanSymbol] = ticker;
            return ticker;
          }
        }
      } catch (e) {
        debugPrint('GlobalStocksExchange CRYPTO_FGI fetch error: $e');
      }
    }

    // 2. Try Yahoo Finance primary & secondary endpoints for Stocks, Commodities & Forex
    final hosts = ['query1.finance.yahoo.com', 'query2.finance.yahoo.com'];

    for (final host in hosts) {
      try {
        final url = Uri.parse(
            'https://$host/v8/finance/chart/$cleanSymbol?interval=1m&range=1d');
        final response = await _client.get(url, headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Accept': 'application/json',
        }).timeout(const Duration(seconds: 6));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final result = data['chart']?['result']?[0];
          if (result != null) {
            final meta = result['meta'] as Map<String, dynamic>? ?? {};
            final regularPrice = (meta['regularMarketPrice'] as num?)?.toDouble() ?? 0.0;
            final double high = (meta['regularMarketDayHigh'] as num?)?.toDouble() ?? regularPrice;
            final double low = (meta['regularMarketDayLow'] as num?)?.toDouble() ?? regularPrice;
            final double volume = (meta['regularMarketVolume'] as num?)?.toDouble() ?? 0.0;

            final int? regularMarketTime = (meta['regularMarketTime'] as num?)?.toInt();
            final DateTime? asOf = regularMarketTime != null
                ? DateTime.fromMillisecondsSinceEpoch(regularMarketTime * 1000, isUtc: true)
                : null;

            final rawMarketState = (meta['marketState'] as String?)?.toUpperCase();
            String state = 'live';
            if (rawMarketState == 'CLOSED' ||
                rawMarketState == 'POSTPOST' ||
                rawMarketState == 'PREPRE') {
              state = 'closed';
            } else if (asOf != null &&
                DateTime.now().toUtc().difference(asOf).inMinutes > 15) {
              state = 'delayed';
            } else if (rawMarketState != null && rawMarketState != 'REGULAR') {
              state = 'delayed';
            }

            final String quoteUnit = (meta['currency'] as String?)?.toUpperCase() ?? 'USD';

            if (regularPrice > 0) {
              final ticker = MarketTicker(
                exchangeId: id,
                pair: pair,
                lastPrice: regularPrice,
                volume24h: volume,
                high24h: high,
                low24h: low,
                timestamp: asOf ?? DateTime.now(),
                asOf: asOf,
                state: state,
                quoteUnit: quoteUnit,
                source: 'YahooFinance',
              );
              _lastKnownLiveTickers[cleanSymbol] = ticker;
              return ticker;
            }
          }
        } else if (response.statusCode == 404) {
          // If 404, symbol is not found on Yahoo; do not retry query2
          break;
        }
      } catch (e) {
        debugPrint('GlobalStocksExchange Yahoo Finance fetch error ($host, $cleanSymbol): $e');
      }
    }

    // 3. Stooq Financial Mirror (for verified symbols only with explicit mapping & CSV)
    final stooqCode = stooqSymbolMap[cleanSymbol];
    if (stooqCode != null) {
      try {
        final stooqUrl = Uri.parse(
            'https://stooq.com/q/l/?s=$stooqCode&f=sd2t2ohlcv&h&e=csv');
        final res = await _client.get(stooqUrl, headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        }).timeout(const Duration(seconds: 5));

        if (res.statusCode == 200) {
          final lines = res.body.trim().split(RegExp(r'\r?\n'));
          if (lines.length >= 2) {
            final cols = lines[1].split(',');
            if (cols.length >= 7) {
              final closeStr = cols[6].trim();
              final p = double.tryParse(closeStr);
              if (p != null && p > 0) {
                DateTime? asOf;
                if (cols.length >= 3) {
                  final dateStr = cols[1].trim();
                  final timeStr = cols[2].trim();
                  asOf = DateTime.tryParse('${dateStr}T$timeStr');
                }
                final ticker = MarketTicker(
                  exchangeId: id,
                  pair: pair,
                  lastPrice: p,
                  volume24h: cols.length >= 8 ? (double.tryParse(cols[7].trim()) ?? 0.0) : 0.0,
                  high24h: cols.length >= 5 ? (double.tryParse(cols[4].trim()) ?? p) : p,
                  low24h: cols.length >= 6 ? (double.tryParse(cols[5].trim()) ?? p) : p,
                  timestamp: asOf ?? DateTime.now(),
                  asOf: asOf,
                  state: 'delayed',
                  quoteUnit: 'USD',
                  source: 'Stooq',
                );
                _lastKnownLiveTickers[cleanSymbol] = ticker;
                return ticker;
              }
            }
          }
        }
      } catch (e) {
        debugPrint('GlobalStocksExchange Stooq fetch error ($stooqCode): $e');
      }
    }

    // 4. Return cached live ticker if available from previous successful network fetch
    if (_lastKnownLiveTickers.containsKey(cleanSymbol)) {
      return _lastKnownLiveTickers[cleanSymbol]!;
    }

    // If completely offline and never fetched before, do NOT return static catalog price which would corrupt rule state!
    throw Exception('Connection error: Live price unavailable for $cleanSymbol');
  }
}
