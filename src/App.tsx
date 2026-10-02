import React, { useState, useEffect, useRef } from 'react';
import {
  AlarmClock,
  ArrowDownRight,
  ArrowUpRight,
  BarChart3,
  Bell,
  Building2,
  Check,
  CheckCircle2,
  ChevronLeft,
  ChevronRight,
  Clock,
  Coins,
  Copy,
  Database,
  Download,
  ExternalLink,
  Flame,
  Globe,
  Languages,
  Landmark,
  Layers,
  Moon,
  Palette,
  Pause,
  Percent,
  Play,
  Plus,
  RefreshCw,
  Search,
  Settings as SettingsIcon,
  Shield,
  Smartphone,
  Sparkles,
  Sun,
  Timer,
  Trash2,
  TrendingUp,
  Upload,
  Volume2,
  VolumeX,
  X,
  Zap,
  LayoutGrid,
  Mic
} from 'lucide-react';

interface AlertRule {
  uuid: string;
  marketType: 'crypto' | 'stocks_macro';
  exchangeId: string;
  exchangeName: string;
  baseCurrency: string;
  counterCurrency: string;
  marketSymbol: string;
  assetCategory: 'crypto' | 'stock' | 'forex' | 'bond' | 'commodity' | 'index';
  checkIntervalSeconds: number;
  conditionType: 'PERCENT_CHANGE' | 'PRICE_THRESHOLD';
  direction: 'BOTH' | 'ABOVE' | 'BELOW';
  targetValue: number;
  basePrice: number;
  lastCheckedPrice?: number;
  isActive: boolean;
  isTriggered: boolean;
  customNote?: string;
  ttsEnabled?: boolean;
  lastCheckedAt?: Date;
  lastTriggeredAt?: Date;
  triggerCount: number;
  createdAt: Date;
}

interface NotificationItem {
  id: string;
  title: string;
  body: string;
  timestamp: Date;
  ruleUuid: string;
  marketSymbol: string;
  value: string;
  exchange: string;
}

type ExchangeCategoryType = 'all' | 'tier1' | 'aggregator' | 'middleEast' | 'asia' | 'europe' | 'americas';
type ThemeModeType = 'dark-green' | 'light-green' | 'dark-orange' | 'light-orange' | 'dark-purple-blue' | 'light-purple-blue';

interface ExchangeInfo {
  id: string;
  name: string;
  category: ExchangeCategoryType;
  countryBadge: string;
  defaultCounter: string;
  pairsCount: number;
  pairsList: string[];
}

// === 1. COMPLETE 40+ EXCHANGES CATALOG ===
const ALL_EXCHANGES: ExchangeInfo[] = [
  // --- TIER 1 GLOBAL ---
  { id: 'binance', name: 'Binance (بایننس)', category: 'tier1', countryBadge: '🌐 Global #1', defaultCounter: 'USDT', pairsCount: 1420, pairsList: ['BTC', 'ETH', 'SOL', 'BNB', 'XRP', 'POL', 'RENDER', 'S', 'PEPE', 'DOGE', 'ADA', 'AVAX', 'NEAR', 'SUI', 'LINK', 'DOT'] },
  { id: 'coinbase', name: 'Coinbase (کوین‌بیس)', category: 'tier1', countryBadge: '🇺🇸 USA', defaultCounter: 'USD', pairsCount: 520, pairsList: ['BTC', 'ETH', 'SOL', 'ADA', 'DOGE', 'AVAX', 'LINK', 'NEAR', 'DOT'] },
  { id: 'kraken', name: 'Kraken (کراکن)', category: 'tier1', countryBadge: '🇺🇸 USA / EU', defaultCounter: 'USD', pairsCount: 430, pairsList: ['BTC', 'ETH', 'SOL', 'XRP', 'ADA', 'DOT', 'DOGE', 'LTC'] },
  { id: 'kucoin', name: 'KuCoin (کوکوین)', category: 'tier1', countryBadge: '🌐 Global', defaultCounter: 'USDT', pairsCount: 890, pairsList: ['BTC', 'ETH', 'SOL', 'PEPE', 'RENDER', 'S', 'TON', 'SUI', 'POL'] },
  { id: 'okx', name: 'OKX (اوکی‌اکس)', category: 'tier1', countryBadge: '🌐 Global', defaultCounter: 'USDT', pairsCount: 680, pairsList: ['BTC', 'ETH', 'SOL', 'OKB', 'XRP', 'DOGE', 'ADA', 'TON'] },
  { id: 'bybit', name: 'Bybit (بای‌بیت)', category: 'tier1', countryBadge: '🇦🇪 UAE / Global', defaultCounter: 'USDT', pairsCount: 760, pairsList: ['BTC', 'ETH', 'SOL', 'MNT', 'XRP', 'DOGE', 'SUI', 'PEPE'] },
  { id: 'bitfinex', name: 'Bitfinex (بیت‌فینکس)', category: 'tier1', countryBadge: '🇭🇰 Hong Kong', defaultCounter: 'USD', pairsCount: 380, pairsList: ['BTC', 'ETH', 'SOL', 'XRP', 'LTC', 'EOS'] },
  { id: 'bitstamp', name: 'Bitstamp (بیت‌استمپ)', category: 'tier1', countryBadge: '🇱🇺 Luxembourg', defaultCounter: 'USD', pairsCount: 220, pairsList: ['BTC', 'ETH', 'XRP', 'LTC', 'BCH', 'ADA'] },
  { id: 'gateio', name: 'Gate.io (گیت‌آی‌او)', category: 'tier1', countryBadge: '🌐 Global', defaultCounter: 'USDT', pairsCount: 1900, pairsList: ['BTC', 'ETH', 'GT', 'SOL', 'PEPE', 'POL', 'RENDER', 'S'] },
  { id: 'mexc', name: 'MEXC Global (ام‌ای‌ایکس‌سی)', category: 'tier1', countryBadge: '🌐 Global', defaultCounter: 'USDT', pairsCount: 2100, pairsList: ['BTC', 'ETH', 'MX', 'SOL', 'PEPE', 'SUI', 'TON'] },
  { id: 'huobi', name: 'HTX / Huobi (هوبی)', category: 'tier1', countryBadge: '🌐 Global', defaultCounter: 'USDT', pairsCount: 750, pairsList: ['BTC', 'ETH', 'HT', 'SOL', 'TRX', 'XRP'] },
  { id: 'bitget', name: 'Bitget (بیت‌گت)', category: 'tier1', countryBadge: '🇸🇬 Singapore', defaultCounter: 'USDT', pairsCount: 820, pairsList: ['BTC', 'ETH', 'BGB', 'SOL', 'XRP', 'DOGE'] },
  { id: 'gemini', name: 'Gemini (جمینای)', category: 'tier1', countryBadge: '🇺🇸 USA', defaultCounter: 'USD', pairsCount: 180, pairsList: ['BTC', 'ETH', 'SOL', 'DOGE', 'LINK', 'LTC'] },
  { id: 'poloniex', name: 'Poloniex (پلونیکس)', category: 'tier1', countryBadge: '🌐 Global', defaultCounter: 'USDT', pairsCount: 450, pairsList: ['BTC', 'ETH', 'TRX', 'SOL', 'DOGE', 'XRP'] },
  { id: 'bingx', name: 'BingX (بینگ‌ایکس)', category: 'tier1', countryBadge: '🌐 Global', defaultCounter: 'USDT', pairsCount: 720, pairsList: ['BTC', 'ETH', 'SOL', 'XRP', 'DOGE', 'PEPE'] },

  // --- AGGREGATORS ---
  { id: 'coingecko', name: 'CoinGecko (کوین‌گکو - ۱۰,۰۰۰+ کوین)', category: 'aggregator', countryBadge: '📊 Global Index', defaultCounter: 'USD', pairsCount: 10450, pairsList: ['BTC', 'ETH', 'SOL', 'BNB', 'XRP', 'DOGE', 'ADA', 'POL', 'RENDER', 'S', 'PEPE', 'SHIB', 'NEAR', 'SUI', 'APT', 'AVAX'] },
  { id: 'coinmarketcap', name: 'CoinMarketCap (کوین‌مارکت‌کپ)', category: 'aggregator', countryBadge: '📊 Global Index', defaultCounter: 'USD', pairsCount: 9800, pairsList: ['BTC', 'ETH', 'SOL', 'BNB', 'XRP', 'DOGE', 'TON', 'ADA', 'TRX', 'AVAX'] },
  { id: 'cryptocompare', name: 'CryptoCompare', category: 'aggregator', countryBadge: '📊 Aggregator', defaultCounter: 'USD', pairsCount: 6500, pairsList: ['BTC', 'ETH', 'SOL', 'XRP', 'ADA', 'DOT', 'LTC'] },

  // --- IRAN & MIDDLE EAST ---
  { id: 'nobitex', name: 'Nobitex (نوبیتکس)', category: 'middleEast', countryBadge: '🇮🇷 Iran', defaultCounter: 'USDT', pairsCount: 95, pairsList: ['BTC', 'ETH', 'SOL', 'XRP', 'DOGE', 'ADA', 'TON', 'TRX', 'SHIB', 'POL', 'LTC'] },
  { id: 'wallex', name: 'Wallex (والکس)', category: 'middleEast', countryBadge: '🇮🇷 Iran', defaultCounter: 'USDT', pairsCount: 82, pairsList: ['BTC', 'ETH', 'SOL', 'XRP', 'DOGE', 'ADA', 'TON', 'TRX', 'SHIB', 'DOT'] },
  { id: 'tabdeal', name: 'Tabdeal (تبدیل)', category: 'middleEast', countryBadge: '🇮🇷 Iran', defaultCounter: 'USDT', pairsCount: 78, pairsList: ['BTC', 'ETH', 'SOL', 'XRP', 'DOGE', 'ADA', 'TRX', 'PEPE'] },
  { id: 'coinex', name: 'CoinEx (کوینکس)', category: 'middleEast', countryBadge: '🌐 Middle East Friendly', defaultCounter: 'USDT', pairsCount: 920, pairsList: ['BTC', 'ETH', 'CET', 'SOL', 'XRP', 'DOGE', 'ADA', 'PEPE'] },

  // --- ASIA & PACIFIC ---
  { id: 'upbit', name: 'Upbit (آپ‌بیت)', category: 'asia', countryBadge: '🇰🇷 South Korea', defaultCounter: 'KRW', pairsCount: 310, pairsList: ['BTC', 'ETH', 'SOL', 'XRP', 'DOGE', 'ADA', 'ETC'] },
  { id: 'bithumb', name: 'Bithumb (بیت‌هامب)', category: 'asia', countryBadge: '🇰🇷 South Korea', defaultCounter: 'KRW', pairsCount: 290, pairsList: ['BTC', 'ETH', 'SOL', 'XRP', 'DOGE', 'ADA'] },
  { id: 'bitflyer', name: 'bitFlyer (بیت‌فلایر)', category: 'asia', countryBadge: '🇯🇵 Japan', defaultCounter: 'JPY', pairsCount: 85, pairsList: ['BTC', 'ETH', 'XRP', 'MONA', 'LTC'] },
  { id: 'zaif', name: 'Zaif (زایف)', category: 'asia', countryBadge: '🇯🇵 Japan', defaultCounter: 'JPY', pairsCount: 45, pairsList: ['BTC', 'ETH', 'ZAIF', 'XEM', 'MONA'] },
  { id: 'wazirx', name: 'WazirX (وزیرکس)', category: 'asia', countryBadge: '🇮🇳 India', defaultCounter: 'INR', pairsCount: 240, pairsList: ['BTC', 'ETH', 'WRX', 'SOL', 'XRP', 'DOGE'] },
  { id: 'indodax', name: 'Indodax (ایندوداکس)', category: 'asia', countryBadge: '🇮🇩 Indonesia', defaultCounter: 'IDR', pairsCount: 210, pairsList: ['BTC', 'ETH', 'USDT', 'DOGE', 'XRP'] },
  { id: 'bitkub', name: 'Bitkub (بیت‌کوب)', category: 'asia', countryBadge: '🇹🇭 Thailand', defaultCounter: 'THB', pairsCount: 110, pairsList: ['BTC', 'ETH', 'KUB', 'SOL', 'DOGE'] },

  // --- EUROPE ---
  { id: 'bitvavo', name: 'Bitvavo (بیت‌واوو)', category: 'europe', countryBadge: '🇳🇱 Netherlands', defaultCounter: 'EUR', pairsCount: 240, pairsList: ['BTC', 'ETH', 'SOL', 'ADA', 'XRP', 'DOGE'] },
  { id: 'bitpanda', name: 'Bitpanda (بیت‌پاندا)', category: 'europe', countryBadge: '🇦🇹 Austria', defaultCounter: 'EUR', pairsCount: 320, pairsList: ['BTC', 'ETH', 'BEST', 'SOL', 'ADA'] },
  { id: 'bitcoinde', name: 'Bitcoin.de', category: 'europe', countryBadge: '🇩🇪 Germany', defaultCounter: 'EUR', pairsCount: 35, pairsList: ['BTC', 'ETH', 'BCH', 'LTC'] },
  { id: 'paymium', name: 'Paymium (پیمیوم)', category: 'europe', countryBadge: '🇫🇷 France', defaultCounter: 'EUR', pairsCount: 20, pairsList: ['BTC', 'ETH', 'EUR'] },
  { id: 'exmo', name: 'EXMO (اکسمو)', category: 'europe', countryBadge: '🇬🇧 United Kingdom', defaultCounter: 'USD', pairsCount: 160, pairsList: ['BTC', 'ETH', 'EXM', 'SOL', 'XRP'] },

  // --- AMERICAS & OTHERS ---
  { id: 'mercadobitcoin', name: 'Mercado Bitcoin', category: 'americas', countryBadge: '🇧🇷 Brazil', defaultCounter: 'BRL', pairsCount: 210, pairsList: ['BTC', 'ETH', 'SOL', 'XRP', 'ADA'] },
  { id: 'foxbit', name: 'Foxbit (فاکس‌بیت)', category: 'americas', countryBadge: '🇧🇷 Brazil', defaultCounter: 'BRL', pairsCount: 140, pairsList: ['BTC', 'ETH', 'SOL', 'DOGE'] },
  { id: 'bitso', name: 'Bitso (بیتسو)', category: 'americas', countryBadge: '🇲🇽 Mexico', defaultCounter: 'MXN', pairsCount: 95, pairsList: ['BTC', 'ETH', 'SOL', 'XRP'] },
  { id: 'ndax', name: 'NDAX (ان‌دی‌ایکس)', category: 'americas', countryBadge: '🇨🇦 Canada', defaultCounter: 'CAD', pairsCount: 65, pairsList: ['BTC', 'ETH', 'SOL', 'ADA', 'DOGE'] },
  { id: 'luno', name: 'Luno (لونو)', category: 'americas', countryBadge: '🇿🇦 South Africa', defaultCounter: 'ZAR', pairsCount: 45, pairsList: ['BTC', 'ETH', 'XRP', 'SOL', 'ADA'] },
  { id: 'valr', name: 'VALR (والر)', category: 'americas', countryBadge: '🇿🇦 South Africa', defaultCounter: 'ZAR', pairsCount: 90, pairsList: ['BTC', 'ETH', 'SOL', 'XRP'] },
];

const CRYPTO_COIN_METAS: Record<string, { name: string; nameFa: string; icon: string; currentPrice: number; change24h: number }> = {
  BTC: { name: 'Bitcoin', nameFa: 'بیت‌کوین', icon: 'https://assets.coingecko.com/coins/images/1/small/bitcoin.png', currentPrice: 83770.00, change24h: 1.2 },
  ETH: { name: 'Ethereum', nameFa: 'اتریوم', icon: 'https://assets.coingecko.com/coins/images/279/small/ethereum.png', currentPrice: 2689.50, change24h: -0.8 },
  SOL: { name: 'Solana', nameFa: 'سولانا', icon: 'https://assets.coingecko.com/coins/images/4128/small/solana.png', currentPrice: 120.10, change24h: 2.4 },
  BNB: { name: 'BNB', nameFa: 'بایننس کوین', icon: 'https://assets.coingecko.com/coins/images/825/small/bnb-icon2_2x.png', currentPrice: 770.60, change24h: 0.9 },
  XRP: { name: 'XRP', nameFa: 'ریپل', icon: 'https://assets.coingecko.com/coins/images/44/small/xrp-symbol-white-128.png', currentPrice: 1.51, change24h: 3.1 },
  DOGE: { name: 'Dogecoin', nameFa: 'دوج‌کوین', icon: 'https://assets.coingecko.com/coins/images/5/small/dogecoin.png', currentPrice: 0.22, change24h: 2.8 },
  ADA: { name: 'Cardano', nameFa: 'کاردانو', icon: 'https://assets.coingecko.com/coins/images/975/small/cardano.png', currentPrice: 0.68, change24h: 1.5 },
  AVAX: { name: 'Avalanche', nameFa: 'آوالانچ', icon: 'https://assets.coingecko.com/coins/images/12559/small/Avalanche_Circle_RedWhite_Trans.png', currentPrice: 28.40, change24h: -1.2 },
  POL: { name: 'Polygon (POL)', nameFa: 'پالیگان (POL)', icon: 'https://assets.coingecko.com/coins/images/4713/small/polygon.png', currentPrice: 0.28, change24h: 1.8 },
  RENDER: { name: 'Render (RENDER)', nameFa: 'رندر (هوش مصنوعی)', icon: 'https://assets.coingecko.com/coins/images/11636/small/rndr.png', currentPrice: 2.07, change24h: 4.2 },
  S: { name: 'Sonic (S)', nameFa: 'سونیک (فانتوم سابق)', icon: 'https://assets.coingecko.com/coins/images/4001/small/Fantom_round.png', currentPrice: 0.58, change24h: 5.6 },
  PEPE: { name: 'Pepe', nameFa: 'پپه‌کوین', icon: 'https://assets.coingecko.com/coins/images/29850/small/pepe-token.png', currentPrice: 0.0000098, change24h: 6.8 },
  TON: { name: 'Toncoin', nameFa: 'تن‌کوین (تلگرام)', icon: 'https://assets.coingecko.com/coins/images/17980/small/ton_symbol.png', currentPrice: 4.95, change24h: 1.1 },
  SUI: { name: 'Sui', nameFa: 'سویی', icon: 'https://assets.coingecko.com/coins/images/26375/small/sui-ocean-square.png', currentPrice: 2.15, change24h: 3.7 },
  NEAR: { name: 'NEAR Protocol', nameFa: 'نیر پروتکل', icon: 'https://assets.coingecko.com/coins/images/10365/small/near.png', currentPrice: 4.80, change24h: 0.6 },
  LINK: { name: 'Chainlink', nameFa: 'چین‌لینک', icon: 'https://assets.coingecko.com/coins/images/877/small/chainlink-new-logo.png', currentPrice: 13.40, change24h: 2.1 },
  DOT: { name: 'Polkadot', nameFa: 'پولکادات', icon: 'https://assets.coingecko.com/coins/images/12171/small/polkadot.png', currentPrice: 4.60, change24h: -0.4 },
  LTC: { name: 'Litecoin', nameFa: 'لایت‌کوین', icon: 'https://assets.coingecko.com/coins/images/2/small/litecoin.png', currentPrice: 88.20, change24h: 0.7 },
};

// === 2. MACRO ASSETS (US 10Y BONDS, FOREX, STOCKS, GOLD, OIL) ===
interface MacroAssetMeta {
  symbol: string;
  name: string;
  nameFa: string;
  category: 'bond' | 'forex' | 'stock' | 'commodity' | 'index';
  marketName: string;
  icon: string;
  currentPrice: number;
  unit: string;
  change24h: number;
}

const MACRO_ASSETS: Record<string, MacroAssetMeta> = {
  // US Treasury Yields & Bonds
  US10Y: { symbol: 'US10Y (^TNX)', name: 'US 10-Year Treasury Yield', nameFa: 'بازده اوراق قرضه ۱۰ ساله آمریکا (US10Y)', category: 'bond', marketName: 'US Treasury', icon: 'https://cdn-icons-png.flaticon.com/512/2830/2830284.png', currentPrice: 4.28, unit: '%', change24h: 0.8 },
  US02Y: { symbol: 'US02Y (^IRX)', name: 'US 2-Year Treasury Yield', nameFa: 'بازده اوراق قرضه ۲ ساله آمریکا (US02Y)', category: 'bond', marketName: 'US Treasury', icon: 'https://cdn-icons-png.flaticon.com/512/2830/2830284.png', currentPrice: 4.15, unit: '%', change24h: 0.4 },
  US30Y: { symbol: 'US30Y (^TYX)', name: 'US 30-Year Treasury Bond', nameFa: 'بازده اوراق قرضه ۳۰ ساله آمریکا (US30Y)', category: 'bond', marketName: 'US Treasury', icon: 'https://cdn-icons-png.flaticon.com/512/2830/2830284.png', currentPrice: 4.52, unit: '%', change24h: 0.9 },

  // Forex Currency Pairs
  EURUSD: { symbol: 'EUR/USD', name: 'Euro / US Dollar', nameFa: 'یورو به دلار آمریکا (EUR/USD)', category: 'forex', marketName: 'Forex Major', icon: 'https://cdn-icons-png.flaticon.com/512/323/323310.png', currentPrice: 1.0825, unit: '$', change24h: 0.22 },
  GBPUSD: { symbol: 'GBP/USD', name: 'British Pound / US Dollar', nameFa: 'پوند انگلیس به دلار (GBP/USD)', category: 'forex', marketName: 'Forex Major', icon: 'https://cdn-icons-png.flaticon.com/512/323/323329.png', currentPrice: 1.2980, unit: '$', change24h: -0.15 },
  USDJPY: { symbol: 'USD/JPY', name: 'US Dollar / Japanese Yen', nameFa: 'دلار به ین ژاپن (USD/JPY)', category: 'forex', marketName: 'Forex Major', icon: 'https://cdn-icons-png.flaticon.com/512/323/323313.png', currentPrice: 153.40, unit: '¥', change24h: 0.45 },
  USDCHF: { symbol: 'USD/CHF', name: 'US Dollar / Swiss Franc', nameFa: 'دلار به فرانک سوئیس (USD/CHF)', category: 'forex', marketName: 'Forex Major', icon: 'https://cdn-icons-png.flaticon.com/512/323/323316.png', currentPrice: 0.8670, unit: 'Fr', change24h: 0.12 },
  AUDUSD: { symbol: 'AUD/USD', name: 'Australian Dollar / USD', nameFa: 'دلار استرالیا به دلار آمریکا (AUD/USD)', category: 'forex', marketName: 'Forex Major', icon: 'https://cdn-icons-png.flaticon.com/512/323/323367.png', currentPrice: 0.6580, unit: '$', change24h: -0.35 },
  USDCAD: { symbol: 'USD/CAD', name: 'US Dollar / Canadian Dollar', nameFa: 'دلار آمریکا به دلار کانادا (USD/CAD)', category: 'forex', marketName: 'Forex Major', icon: 'https://cdn-icons-png.flaticon.com/512/323/323277.png', currentPrice: 1.3890, unit: 'C$', change24h: 0.18 },

  // US Stocks (NASDAQ & NYSE)
  NVDA: { symbol: 'NVDA', name: 'NVIDIA Corporation', nameFa: 'سهام انویدیا (NVIDIA)', category: 'stock', marketName: 'NASDAQ', icon: 'https://companiesmarketcap.com/img/company-logos/64/NVDA.png', currentPrice: 138.25, unit: '$', change24h: 3.4 },
  AAPL: { symbol: 'AAPL', name: 'Apple Inc.', nameFa: 'سهام اپل (Apple)', category: 'stock', marketName: 'NASDAQ', icon: 'https://companiesmarketcap.com/img/company-logos/64/AAPL.png', currentPrice: 228.50, unit: '$', change24h: 1.1 },
  MSFT: { symbol: 'MSFT', name: 'Microsoft Corporation', nameFa: 'سهام مایکروسافت (Microsoft)', category: 'stock', marketName: 'NASDAQ', icon: 'https://companiesmarketcap.com/img/company-logos/64/MSFT.png', currentPrice: 428.10, unit: '$', change24h: 0.8 },
  TSLA: { symbol: 'TSLA', name: 'Tesla Inc.', nameFa: 'سهام تسلا (Tesla)', category: 'stock', marketName: 'NASDAQ', icon: 'https://companiesmarketcap.com/img/company-logos/64/TSLA.png', currentPrice: 255.40, unit: '$', change24h: -1.9 },
  AMZN: { symbol: 'AMZN', name: 'Amazon.com Inc.', nameFa: 'سهام آمازون (Amazon)', category: 'stock', marketName: 'NASDAQ', icon: 'https://companiesmarketcap.com/img/company-logos/64/AMZN.png', currentPrice: 186.70, unit: '$', change24h: 1.5 },
  GOOGL: { symbol: 'GOOGL', name: 'Alphabet Inc. (Google)', nameFa: 'سهام گوگل (آلفابت)', category: 'stock', marketName: 'NASDAQ', icon: 'https://companiesmarketcap.com/img/company-logos/64/GOOGL.png', currentPrice: 165.30, unit: '$', change24h: 0.4 },
  META: { symbol: 'META', name: 'Meta Platforms (Facebook)', nameFa: 'سهام متا (فیسبوک)', category: 'stock', marketName: 'NASDAQ', icon: 'https://companiesmarketcap.com/img/company-logos/64/META.png', currentPrice: 585.20, unit: '$', change24h: 2.1 },
  PLTR: { symbol: 'PLTR', name: 'Palantir Technologies', nameFa: 'سهام پالانتیر (Palantir)', category: 'stock', marketName: 'NYSE', icon: 'https://companiesmarketcap.com/img/company-logos/64/PLTR.png', currentPrice: 44.10, unit: '$', change24h: 5.6 },
  BRKB: { symbol: 'BRK.B', name: 'Berkshire Hathaway', nameFa: 'برکشایر هاتاوی (وارن بافت)', category: 'stock', marketName: 'NYSE', icon: 'https://companiesmarketcap.com/img/company-logos/64/BRK-B.png', currentPrice: 462.10, unit: '$', change24h: 0.5 },

  // Commercial Space, Aerospace & Starlink
  SPACEX: { symbol: 'SPACEX', name: 'SpaceX (Starlink & Space Exploration)', nameFa: 'اسپیس‌ایکس (فناوری‌های فضایی، استارشیپ و استارلینک ایلان ماسک)', category: 'stock', marketName: 'Pre-IPO Benchmark', icon: 'https://cdn-icons-png.flaticon.com/512/3209/3209994.png', currentPrice: 112.00, unit: '$', change24h: 4.8 },
  DXYZ: { symbol: 'DXYZ', name: 'Destiny Tech100 (SpaceX & OpenAI ETF)', nameFa: 'صندوق سرنوشت ۱۰۰ (سبد سهام عمومی اسپیس‌ایکس و اوپن‌ای‌آی)', category: 'stock', marketName: 'NYSE', icon: 'https://cdn-icons-png.flaticon.com/512/3209/3209994.png', currentPrice: 18.50, unit: '$', change24h: 6.2 },
  RKLB: { symbol: 'RKLB', name: 'Rocket Lab USA', nameFa: 'راکت لب (پرتاب‌های فضایی مداری تجاری و ماهواره‌های ناسا)', category: 'stock', marketName: 'NASDAQ', icon: 'https://companiesmarketcap.com/img/company-logos/64/RKLB.png', currentPrice: 10.45, unit: '$', change24h: 3.1 },
  ASTS: { symbol: 'ASTS', name: 'AST SpaceMobile', nameFa: 'ای‌اس‌تی اسپیس‌موبایل (شبکه پهن‌باند ماهواره‌ای به گوشی هوشمند)', category: 'stock', marketName: 'NASDAQ', icon: 'https://companiesmarketcap.com/img/company-logos/64/ASTS.png', currentPrice: 26.80, unit: '$', change24h: 8.5 },
  BA: { symbol: 'BA', name: 'The Boeing Company', nameFa: 'بوئینگ (غول هواپیماسازی، فضاپیما و کپسول فضایی استارلاینر)', category: 'stock', marketName: 'NYSE', icon: 'https://companiesmarketcap.com/img/company-logos/64/BA.png', currentPrice: 155.20, unit: '$', change24h: -0.8 },

  // Frontier AI & Pre-IPO Giants
  OPENAI: { symbol: 'OPENAI', name: 'OpenAI (ChatGPT & Frontier AI)', nameFa: 'اوپن‌ای‌آی (خالق چت‌جی‌پی‌تی و پیشتاز هوش مصنوعی عمومی AGI)', category: 'stock', marketName: 'Pre-IPO Benchmark', icon: 'https://cdn-icons-png.flaticon.com/512/12222/12222560.png', currentPrice: 150.00, unit: '$', change24h: 5.0 },
  ANTHROPIC: { symbol: 'ANTHROPIC', name: 'Anthropic (Claude AI)', nameFa: 'انتروپیک (خالق هوش مصنوعی کلود Claude)', category: 'stock', marketName: 'Pre-IPO Benchmark', icon: 'https://cdn-icons-png.flaticon.com/512/8649/8649607.png', currentPrice: 85.00, unit: '$', change24h: 3.7 },
  STRIPE: { symbol: 'STRIPE', name: 'Stripe Payments', nameFa: 'استریپ (زیرساخت پرداخت اینترنتی و تسویه رمزارزی جهان)', category: 'stock', marketName: 'Pre-IPO Benchmark', icon: 'https://companiesmarketcap.com/img/company-logos/64/STRIP.png', currentPrice: 32.50, unit: '$', change24h: 1.8 },
  BYTEDANCE: { symbol: 'BYTEDANCE', name: 'ByteDance (TikTok)', nameFa: 'بایت‌دنس (مالک تیک‌تاک و غول الگوریتم‌های هوش مصنوعی)', category: 'stock', marketName: 'Pre-IPO Benchmark', icon: 'https://cdn-icons-png.flaticon.com/512/3046/3046121.png', currentPrice: 175.00, unit: '$', change24h: 2.4 },

  // Crypto Mining & Fintech Stocks
  MSTR: { symbol: 'MSTR', name: 'MicroStrategy Inc.', nameFa: 'میکرواستراتژی (بزرگ‌ترین خزانه‌داری بیت‌کوین سازمانی)', category: 'stock', marketName: 'NASDAQ', icon: 'https://companiesmarketcap.com/img/company-logos/64/MSTR.png', currentPrice: 215.30, unit: '$', change24h: 7.4 },
  COIN: { symbol: 'COIN', name: 'Coinbase Global Inc.', nameFa: 'کوین‌بیس (بزرگ‌ترین صرافی مجاز کریپتو آمریکا)', category: 'stock', marketName: 'NASDAQ', icon: 'https://companiesmarketcap.com/img/company-logos/64/COIN.png', currentPrice: 212.80, unit: '$', change24h: 4.2 },
  MARA: { symbol: 'MARA', name: 'MARA Holdings (Marathon)', nameFa: 'ماراتون دیجیتال / MARA (بزرگ‌ترین استخراج‌کننده بیت‌کوین)', category: 'stock', marketName: 'NASDAQ', icon: 'https://companiesmarketcap.com/img/company-logos/64/MARA.png', currentPrice: 18.90, unit: '$', change24h: 6.8 },
  RIOT: { symbol: 'RIOT', name: 'Riot Platforms Inc.', nameFa: 'رایوت پلتفرمز (زیرساخت استخراج و مزارع بیت‌کوین)', category: 'stock', marketName: 'NASDAQ', icon: 'https://companiesmarketcap.com/img/company-logos/64/RIOT.png', currentPrice: 9.85, unit: '$', change24h: 5.1 },
  CLSK: { symbol: 'CLSK', name: 'CleanSpark Inc.', nameFa: 'کلین‌اسپارک (استخراج سبز و پربازده بیت‌کوین)', category: 'stock', marketName: 'NASDAQ', icon: 'https://companiesmarketcap.com/img/company-logos/64/CLSK.png', currentPrice: 12.40, unit: '$', change24h: 4.9 },
  HOOD: { symbol: 'HOOD', name: 'Robinhood Markets', nameFa: 'رابین‌هود (کارگزاری معامله سهام و رمزارز)', category: 'stock', marketName: 'NASDAQ', icon: 'https://companiesmarketcap.com/img/company-logos/64/HOOD.png', currentPrice: 27.30, unit: '$', change24h: 3.3 },
  RDDT: { symbol: 'RDDT', name: 'Reddit Inc.', nameFa: 'ردیت (انجمن وب و مرجع داده‌های آموزش AI)', category: 'stock', marketName: 'NYSE', icon: 'https://companiesmarketcap.com/img/company-logos/64/RDDT.png', currentPrice: 82.60, unit: '$', change24h: 8.9 },
  SHOP: { symbol: 'SHOP', name: 'Shopify Inc.', nameFa: 'شاپیفای (فروشگاه‌ساز آنلاین جهانی)', category: 'stock', marketName: 'NYSE', icon: 'https://companiesmarketcap.com/img/company-logos/64/SHOP.png', currentPrice: 81.40, unit: '$', change24h: 2.3 },
  SNOW: { symbol: 'SNOW', name: 'Snowflake Inc.', nameFa: 'اسنوفلیک (انبار داده‌های کلاد هوش مصنوعی)', category: 'stock', marketName: 'NYSE', icon: 'https://companiesmarketcap.com/img/company-logos/64/SNOW.png', currentPrice: 118.50, unit: '$', change24h: 1.7 },
  RACE: { symbol: 'RACE', name: 'Ferrari N.V.', nameFa: 'فراری (سوپراسپرت‌های لوکس ایتالیا)', category: 'stock', marketName: 'NYSE', icon: 'https://companiesmarketcap.com/img/company-logos/64/RACE.png', currentPrice: 462.80, unit: '$', change24h: 0.9 },

  // Commodities
  GOLD: { symbol: 'XAU/USD', name: 'Gold Spot', nameFa: 'انس طلای جهانی (Gold XAU/USD)', category: 'commodity', marketName: 'Commodities', icon: 'https://cdn-icons-png.flaticon.com/512/2583/2583344.png', currentPrice: 2735.40, unit: '$', change24h: 0.75 },
  SILVER: { symbol: 'XAG/USD', name: 'Silver Spot', nameFa: 'انس نقره جهانی (Silver XAG/USD)', category: 'commodity', marketName: 'Commodities', icon: 'https://cdn-icons-png.flaticon.com/512/2583/2583434.png', currentPrice: 33.85, unit: '$', change24h: 1.40 },
  OIL_WTI: { symbol: 'WTI', name: 'Crude Oil (WTI)', nameFa: 'نفت خام تگزاس (WTI Oil)', category: 'commodity', marketName: 'NYMEX', icon: 'https://cdn-icons-png.flaticon.com/512/2933/2933884.png', currentPrice: 71.20, unit: '$', change24h: -1.20 },
  OIL_BRENT: { symbol: 'BRENT', name: 'Brent Crude Oil', nameFa: 'نفت برنت دریای شمال', category: 'commodity', marketName: 'ICE', icon: 'https://cdn-icons-png.flaticon.com/512/2933/2933884.png', currentPrice: 75.40, unit: '$', change24h: -0.90 },

  // Global Indices
  SP500: { symbol: 'S&P 500', name: 'S&P 500 Index', nameFa: 'شاخص ۵۰۰ شرکت برتر آمریکا (S&P 500)', category: 'index', marketName: 'US Indices', icon: 'https://cdn-icons-png.flaticon.com/512/4222/4222002.png', currentPrice: 5864.67, unit: 'pts', change24h: 0.65 },
  NASDAQ100: { symbol: 'NDX', name: 'NASDAQ 100 Index', nameFa: 'شاخص ۱۰۰ غول فناوری (Nasdaq 100)', category: 'index', marketName: 'NASDAQ', icon: 'https://cdn-icons-png.flaticon.com/512/4222/4222002.png', currentPrice: 18518.61, unit: 'pts', change24h: 0.92 },
  DOWJONES: { symbol: 'DJI', name: 'Dow Jones Industrial', nameFa: 'شاخص صنعتی داوجونز (Dow Jones)', category: 'index', marketName: 'NYSE', icon: 'https://cdn-icons-png.flaticon.com/512/4222/4222002.png', currentPrice: 42931.60, unit: 'pts', change24h: 0.35 },
  DXY: { symbol: 'DXY', name: 'US Dollar Index', nameFa: 'شاخص قدرت جهانی دلار (DXY)', category: 'index', marketName: 'ICE', icon: 'https://cdn-icons-png.flaticon.com/512/217/217853.png', currentPrice: 104.15, unit: 'pts', change24h: 0.18 },
};

// === 3. 10 WORLD LANGUAGES ===
interface LanguageInfo {
  code: string;
  name: string;
  nameEn: string;
  flag: string;
  dir: 'rtl' | 'ltr';
}

const SUPPORTED_LANGUAGES: LanguageInfo[] = [
  { code: 'fa', name: 'فارسی (Persian)', nameEn: 'Persian', flag: '🇮🇷', dir: 'rtl' },
  { code: 'en', name: 'English (انگلیسی)', nameEn: 'English', flag: '🇺🇸', dir: 'ltr' },
  { code: 'de', name: 'Deutsch (آلمانی)', nameEn: 'German', flag: '🇩🇪', dir: 'ltr' },
  { code: 'fr', name: 'Français (فرانسوی)', nameEn: 'French', flag: '🇫🇷', dir: 'ltr' },
  { code: 'es', name: 'Español (اسپانیایی)', nameEn: 'Spanish', flag: '🇪🇸', dir: 'ltr' },
  { code: 'zh', name: '中文 (چینی)', nameEn: 'Chinese', flag: '🇨🇳', dir: 'ltr' },
  { code: 'ko', name: '한국어 (کره‌ای)', nameEn: 'Korean', flag: '🇰🇷', dir: 'ltr' },
  { code: 'ku', name: 'کوردی سۆرانی (Kurdish)', nameEn: 'Kurdish Sorani', flag: '☀️', dir: 'rtl' },
  { code: 'ar', name: 'العربية (عربی)', nameEn: 'Arabic', flag: '🇸🇦', dir: 'rtl' },
  { code: 'tr', name: 'Türkçe (ترکی)', nameEn: 'Turkish', flag: '🇹🇷', dir: 'ltr' },
];

const INITIAL_RULES: AlertRule[] = [
  {
    uuid: 'rule-btc-crypto',
    marketType: 'crypto',
    exchangeId: 'binance',
    exchangeName: 'Binance (بایننس)',
    baseCurrency: 'BTC',
    counterCurrency: 'USDT',
    marketSymbol: 'BTC/USDT',
    assetCategory: 'crypto',
    checkIntervalSeconds: 30,
    conditionType: 'PERCENT_CHANGE',
    direction: 'BOTH',
    targetValue: 2.5,
    basePrice: 83770.00,
    lastCheckedPrice: 83770.00,
    isActive: true,
    isTriggered: false,
    triggerCount: 2,
    lastCheckedAt: new Date(Date.now() - 10000),
    createdAt: new Date(Date.now() - 3600000),
  },
  {
    uuid: 'rule-us10y-macro',
    marketType: 'stocks_macro',
    exchangeId: 'us_treasury',
    exchangeName: 'US Treasury (خزانه‌داری آمریکا)',
    baseCurrency: 'US10Y',
    counterCurrency: '%',
    marketSymbol: 'US10Y (اوراق ۱۰ ساله)',
    assetCategory: 'bond',
    checkIntervalSeconds: 60,
    conditionType: 'PERCENT_CHANGE',
    direction: 'BOTH',
    targetValue: 1.0,
    basePrice: 4.28,
    lastCheckedPrice: 4.28,
    isActive: true,
    isTriggered: false,
    triggerCount: 1,
    lastCheckedAt: new Date(Date.now() - 18000),
    createdAt: new Date(Date.now() - 5400000),
  },
  {
    uuid: 'rule-gold-macro',
    marketType: 'stocks_macro',
    exchangeId: 'commodities',
    exchangeName: 'Global Commodities',
    baseCurrency: 'GOLD',
    counterCurrency: 'USD',
    marketSymbol: 'XAU/USD (طلا)',
    assetCategory: 'commodity',
    checkIntervalSeconds: 30,
    conditionType: 'PERCENT_CHANGE',
    direction: 'BOTH',
    targetValue: 0.5,
    basePrice: 2735.40,
    lastCheckedPrice: 2735.40,
    isActive: true,
    isTriggered: false,
    triggerCount: 1,
    lastCheckedAt: new Date(Date.now() - 25000),
    createdAt: new Date(Date.now() - 7200000),
  },
];

export default function App() {
  // TAB NAVIGATION: ALERTS IS IN THE MIDDLE (INDEX 1) AND IS THE DEFAULT
  const [mobileScreen, setMobileScreen] = useState<'history' | 'alerts' | 'settings'>('alerts');
  const [rules, setRules] = useState<AlertRule[]>(INITIAL_RULES);
  const [cryptoPrices, setCryptoPrices] = useState(CRYPTO_COIN_METAS);
  const [macroPrices, setMacroPrices] = useState(MACRO_ASSETS);
  
  // Theme & Language
  const [appTheme, setAppTheme] = useState<ThemeModeType>('dark-green');
  const [currentLang, setCurrentLang] = useState<string>('fa');
  const [showLanguageModal, setShowLanguageModal] = useState<boolean>(false);

  // Sound & Toasts
  const [soundEnabled, setSoundEnabled] = useState<boolean>(true);
  const [toastMessage, setToastMessage] = useState<string | null>(null);
  const [checkingRuleId, setCheckingRuleId] = useState<string | null>(null);

  // Backup & Restore Modals
  const [showRestoreModal, setShowRestoreModal] = useState<boolean>(false);
  const [restoreJsonInput, setRestoreJsonInput] = useState<string>('');

  // === DUAL-MODE CREATE ALERT MODAL ===
  const [showCreateModal, setShowCreateModal] = useState<boolean>(false);
  const [createPath, setCreatePath] = useState<'NONE' | 'CRYPTO' | 'STOCKS_MACRO'>('NONE');
  
  // Crypto Flow: Exchange Chips + Search + 40+ Exchanges + Pairs Sync + Frequency + Both-Sides Condition
  const [cryptoStep, setCryptoStep] = useState<1 | 2 | 3>(1);
  const [exchangeCategoryFilter, setExchangeCategoryFilter] = useState<ExchangeCategoryType>('all');
  const [selectedExchange, setSelectedExchange] = useState<ExchangeInfo>(ALL_EXCHANGES[0]);
  const [exchangeSearchQuery, setExchangeSearchQuery] = useState<string>('');
  const [cryptoSearchQuery, setCryptoSearchQuery] = useState<string>('');
  const [selectedCryptoCoin, setSelectedCryptoCoin] = useState<string>('BTC');
  const [isSyncingPairs, setIsSyncingPairs] = useState<boolean>(false);

  // Stocks / Forex / US 10Y Bond Flow
  const [macroStep, setMacroStep] = useState<1 | 2>(1);
  const [macroCategoryFilter, setMacroCategoryFilter] = useState<'all' | 'bond' | 'forex' | 'stock' | 'commodity' | 'index'>('all');
  const [macroSearchQuery, setMacroSearchQuery] = useState<string>('');
  const [selectedMacroKey, setSelectedMacroKey] = useState<string>('US10Y');

  // Common Frequency & Condition inputs
  const [unitType, setUnitType] = useState<'seconds' | 'minutes' | 'hours'>('minutes');
  const [unitNumber, setUnitNumber] = useState<string>('1');
  const [conditionType, setConditionType] = useState<'PERCENT_CHANGE' | 'PRICE_THRESHOLD'>('PERCENT_CHANGE');
  const [direction, setDirection] = useState<'BOTH' | 'ABOVE' | 'BELOW'>('BOTH');
  const [targetValueStr, setTargetValueStr] = useState<string>('2.0');
  const [ttsEnabled, setTtsEnabled] = useState<boolean>(false);
  const [showHomeWidgetModal, setShowHomeWidgetModal] = useState<boolean>(false);

  // Notifications
  const [notifications, setNotifications] = useState<NotificationItem[]>([
    {
      id: 'notif-1',
      title: '🟢 BTC/USDT +3.52% $83,770.00 ▲',
      body: '📝 Target reached on Binance',
      timestamp: new Date(Date.now() - 90000),
      ruleUuid: 'rule-btc-crypto',
      marketSymbol: 'BTC/USDT',
      value: '$83,770',
      exchange: 'Binance',
    },
    {
      id: 'notif-2',
      title: '🔴 ETH/USDT -3.52% $3,120.00 ▼',
      body: '📝 Support level broken',
      timestamp: new Date(Date.now() - 180000),
      ruleUuid: 'rule-eth-crypto',
      marketSymbol: 'ETH/USDT',
      value: '$3,120',
      exchange: 'Binance',
    }
  ]);

  const audioContextRef = useRef<AudioContext | null>(null);

  // Live Crypto Prices Sync
  useEffect(() => {
    const fetchLivePrices = async () => {
      try {
        const res = await fetch('https://api.binance.com/api/v3/ticker/24hr');
        if (!res.ok) return;
        const tickers: any[] = await res.json();
        const priceMap: Record<string, { price: number; change: number }> = {};

        tickers.forEach((t) => {
          if (t.symbol.endsWith('USDT')) {
            const sym = t.symbol.replace('USDT', '');
            priceMap[sym] = {
              price: parseFloat(t.lastPrice),
              change: parseFloat(t.priceChangePercent),
            };
          }
        });

        setCryptoPrices((prev) => {
          const updated = { ...prev };
          Object.keys(updated).forEach((key) => {
            if (priceMap[key]) {
              updated[key] = {
                ...updated[key],
                currentPrice: priceMap[key].price,
                change24h: priceMap[key].change,
              };
            }
          });
          return updated;
        });
      } catch (_) {}
    };

    fetchLivePrices();
    const interval = setInterval(fetchLivePrices, 30000);
    return () => clearInterval(interval);
  }, []);

  const playBeep = () => {
    if (!soundEnabled) return;
    try {
      const ctx = audioContextRef.current || new (window.AudioContext || (window as any).webkitAudioContext)();
      audioContextRef.current = ctx;
      if (ctx.state === 'suspended') ctx.resume();

      const osc = ctx.createOscillator();
      const gain = ctx.createGain();
      osc.type = 'triangle';
      osc.frequency.setValueAtTime(880, ctx.currentTime);
      osc.frequency.exponentialRampToValueAtTime(1320, ctx.currentTime + 0.15);
      gain.gain.setValueAtTime(0.3, ctx.currentTime);
      gain.gain.exponentialRampToValueAtTime(0.01, ctx.currentTime + 0.25);
      osc.connect(gain);
      gain.connect(ctx.destination);
      osc.start();
      osc.stop(ctx.currentTime + 0.25);
    } catch (_) {}
  };

  const speakText = (text: string, lang = currentLang) => {
    try {
      if ('speechSynthesis' in window) {
        window.speechSynthesis.cancel();
        const utterance = new SpeechSynthesisUtterance(text);
        if (lang === 'fa') {
          utterance.lang = 'fa-IR';
        } else if (lang === 'ar') {
          utterance.lang = 'ar-SA';
        } else if (lang === 'de') {
          utterance.lang = 'de-DE';
        } else if (lang === 'fr') {
          utterance.lang = 'fr-FR';
        } else if (lang === 'es') {
          utterance.lang = 'es-ES';
        } else if (lang === 'tr') {
          utterance.lang = 'tr-TR';
        } else {
          utterance.lang = 'en-US';
        }
        utterance.rate = 0.95;
        utterance.pitch = 1.0;
        window.speechSynthesis.speak(utterance);
      }
    } catch (_) {}
  };

  const testTtsSpeech = (symbol = 'BTC', price = 83770) => {
    const text = currentLang === 'fa'
      ? `توجه، هشدار قیمت برای ${symbol} فعال شد. نرخ لحظه‌ای: ${price.toLocaleString('fa-IR')} دلار.`
      : `Attention, price alert triggered for ${symbol}. Current price: ${price} dollars.`;
    speakText(text, currentLang);
    showToast(`🗣️ در حال پخش صدای هوشمند برای ${symbol}...`);
  };

  const showToast = (msg: string) => {
    setToastMessage(msg);
    setTimeout(() => setToastMessage(null), 3000);
  };

  const calculateTotalSeconds = (u: 'seconds' | 'minutes' | 'hours', numStr: string) => {
    const n = Math.max(1, parseInt(numStr) || 1);
    if (u === 'seconds') return n;
    if (u === 'minutes') return n * 60;
    return n * 3600;
  };

  const formatCalculatedInterval = (u: 'seconds' | 'minutes' | 'hours', numStr: string) => {
    const n = Math.max(1, parseInt(numStr) || 1);
    if (u === 'seconds') return `${n} ثانیه`;
    if (u === 'minutes') return `${n} دقیقه`;
    return `${n} ساعت`;
  };

  const evaluateRule = (rule: AlertRule, forcedPriceDeltaPercent?: number) => {
    let nameFa = rule.marketSymbol;
    let unit = '$';

    if (rule.marketType === 'crypto') {
      const meta = cryptoPrices[rule.baseCurrency] || cryptoPrices.BTC;
      nameFa = meta.nameFa;
      unit = '$';
    } else {
      const meta = macroPrices[rule.baseCurrency] || macroPrices.US10Y;
      nameFa = meta.nameFa;
      unit = meta.unit;
    }

    const now = new Date();
    const driftPct = forcedPriceDeltaPercent ?? ((Math.random() - 0.48) * (rule.assetCategory === 'bond' || rule.assetCategory === 'forex' ? 0.3 : 1.2));
    const newPrice = Number((rule.basePrice * (1 + driftPct / 100)).toFixed(rule.basePrice < 1 ? 6 : 2));
    
    const diff = newPrice - rule.basePrice;
    const actualPercent = (diff / rule.basePrice) * 100;

    let triggered = false;
    let title = '';
    let body = '';

    if (rule.conditionType === 'PERCENT_CHANGE') {
      if (rule.direction === 'BOTH' && Math.abs(actualPercent) >= rule.targetValue) {
        triggered = true;
      } else if (rule.direction === 'ABOVE' && actualPercent >= rule.targetValue) {
        triggered = true;
      } else if (rule.direction === 'BELOW' && actualPercent <= -rule.targetValue) {
        triggered = true;
      }

      if (triggered) {
        const isUpward = actualPercent >= 0;
        const emoji = isUpward ? '🟢' : '🔴';
        const arrow = isUpward ? '▲' : '▼';
        const sign = isUpward ? '+' : '-';
        const priceStr = `${unit}${newPrice.toLocaleString(undefined, { minimumFractionDigits: newPrice < 1 ? 4 : 2, maximumFractionDigits: 4 })}`;
        title = `${emoji} ${rule.marketSymbol} ${sign}${Math.abs(actualPercent).toFixed(2)}% ${priceStr} ${arrow}`;
        body = rule.customNote && rule.customNote.trim() 
          ? (rule.customNote.startsWith('📝') ? rule.customNote : `📝 ${rule.customNote}`)
          : `📝 ${priceStr}`;
      }
    } else if (rule.conditionType === 'PRICE_THRESHOLD') {
      const priceStr = `${unit}${newPrice.toLocaleString(undefined, { minimumFractionDigits: newPrice < 1 ? 4 : 2, maximumFractionDigits: 4 })}`;
      if (rule.direction === 'ABOVE' && newPrice >= rule.targetValue) {
        triggered = true;
        const pct = ((newPrice - rule.basePrice) / rule.basePrice) * 100;
        title = `🟢 ${rule.marketSymbol} +${Math.abs(pct).toFixed(2)}% ${priceStr} ▲`;
        body = rule.customNote && rule.customNote.trim() 
          ? (rule.customNote.startsWith('📝') ? rule.customNote : `📝 ${rule.customNote}`)
          : `📝 ${priceStr}`;
      } else if (rule.direction === 'BELOW' && newPrice <= rule.targetValue) {
        triggered = true;
        const pct = ((newPrice - rule.basePrice) / rule.basePrice) * 100;
        title = `🔴 ${rule.marketSymbol} -${Math.abs(pct).toFixed(2)}% ${priceStr} ▼`;
        body = rule.customNote && rule.customNote.trim() 
          ? (rule.customNote.startsWith('📝') ? rule.customNote : `📝 ${rule.customNote}`)
          : `📝 ${priceStr}`;
      }
    }

    if (triggered) {
      playBeep();
      setNotifications((prev) => [
        {
          id: `notif-${Date.now()}-${rule.uuid}`,
          title,
          body,
          timestamp: now,
          ruleUuid: rule.uuid,
          marketSymbol: rule.marketSymbol,
          value: `${unit}${newPrice.toLocaleString()}`,
          exchange: rule.exchangeName,
        },
        ...prev.slice(0, 25),
      ]);
      showToast(title);

      if (rule.ttsEnabled) {
        const spoken = currentLang === 'fa'
          ? `هشدار: ${rule.baseCurrency} به قیمت ${newPrice.toLocaleString('fa-IR')} ${unit} رسید.`
          : `Alert: ${rule.baseCurrency} reached ${newPrice} ${unit}.`;
        speakText(spoken);
      }
    }

    setRules((prev) =>
      prev.map((r) => {
        if (r.uuid === rule.uuid) {
          return {
            ...r,
            lastCheckedAt: now,
            lastCheckedPrice: newPrice,
            basePrice: triggered ? newPrice : r.basePrice,
            isTriggered: triggered && r.conditionType === 'PRICE_THRESHOLD',
            isActive: triggered && r.conditionType === 'PRICE_THRESHOLD' ? false : r.isActive,
            triggerCount: triggered ? r.triggerCount + 1 : r.triggerCount,
            lastTriggeredAt: triggered ? now : r.lastTriggeredAt,
          };
        }
        return r;
      })
    );
  };

  useEffect(() => {
    const timer = setInterval(() => {
      const now = new Date();
      rules.forEach((rule) => {
        if (!rule.isActive) return;
        const lastChecked = rule.lastCheckedAt ? new Date(rule.lastCheckedAt).getTime() : 0;
        const elapsedSecs = (now.getTime() - lastChecked) / 1000;

        if (elapsedSecs >= rule.checkIntervalSeconds) {
          evaluateRule(rule);
        }
      });
    }, 1000);

    return () => clearInterval(timer);
  }, [rules]);

  const handleToggle = (uuid: string) => {
    setRules((prev) =>
      prev.map((r) => (r.uuid === uuid ? { ...r, isActive: !r.isActive } : r))
    );
  };

  const handleDelete = (uuid: string) => {
    setRules((prev) => prev.filter((r) => r.uuid !== uuid));
    showToast('هشدار با موفقیت حذف شد');
  };

  const handleManualCheck = async (rule: AlertRule) => {
    setCheckingRuleId(rule.uuid);
    setTimeout(() => {
      evaluateRule(rule);
      setCheckingRuleId(null);
      showToast(`بررسی آنی انجام شد: ${rule.marketSymbol}`);
    }, 400);
  };

  // Export & Restore Handlers
  const handleExportBackup = () => {
    const jsonStr = JSON.stringify(rules, null, 2);
    navigator.clipboard.writeText(jsonStr);
    showToast('✅ فایل پشتیبان JSON شامل تمام هشدارها در کلیپ‌بورد کپی شد.');
  };

  const handleRestoreBackup = () => {
    try {
      const parsed = JSON.parse(restoreJsonInput);
      if (!Array.isArray(parsed)) throw new Error('Invalid JSON array');
      setRules(parsed);
      setShowRestoreModal(false);
      setRestoreJsonInput('');
      showToast(`🎉 ${parsed.length} هشدار با موفقیت بازیابی شد.`);
    } catch (_) {
      alert('فرمت فایل JSON نامعتبر است.');
    }
  };

  const handleCreateCryptoSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    const val = parseFloat(targetValueStr);
    if (isNaN(val) || val <= 0) {
      alert('لطفاً مقدار عددی معتبری وارد فرمایید.');
      return;
    }

    const meta = cryptoPrices[selectedCryptoCoin] || cryptoPrices.BTC;
    const totalSecs = calculateTotalSeconds(unitType, unitNumber);

    const newRule: AlertRule = {
      uuid: `rule-crypto-${Date.now()}`,
      marketType: 'crypto',
      exchangeId: selectedExchange.id,
      exchangeName: selectedExchange.name,
      baseCurrency: selectedCryptoCoin,
      counterCurrency: selectedExchange.defaultCounter,
      marketSymbol: `${selectedCryptoCoin}/${selectedExchange.defaultCounter}`,
      assetCategory: 'crypto',
      checkIntervalSeconds: totalSecs,
      conditionType: conditionType,
      direction: direction,
      targetValue: val,
      basePrice: meta.currentPrice,
      lastCheckedPrice: meta.currentPrice,
      isActive: true,
      isTriggered: false,
      triggerCount: 0,
      ttsEnabled: ttsEnabled,
      createdAt: new Date(),
    };

    setRules([newRule, ...rules]);
    setShowCreateModal(false);
    setCreatePath('NONE');
    setCryptoStep(1);
    showToast(`هشدار کریپتو برای ${selectedCryptoCoin} فعال شد.`);
  };

  const handleCreateMacroSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    const val = parseFloat(targetValueStr);
    if (isNaN(val) || val <= 0) {
      alert('لطفاً مقدار عددی معتبری وارد فرمایید.');
      return;
    }

    const meta = macroPrices[selectedMacroKey] || macroPrices.US10Y;
    const totalSecs = calculateTotalSeconds(unitType, unitNumber);

    const newRule: AlertRule = {
      uuid: `rule-macro-${Date.now()}`,
      marketType: 'stocks_macro',
      exchangeId: meta.marketName.toLowerCase().replace(/\s+/g, '_'),
      exchangeName: meta.marketName,
      baseCurrency: selectedMacroKey,
      counterCurrency: meta.unit,
      marketSymbol: meta.symbol,
      assetCategory: meta.category,
      checkIntervalSeconds: totalSecs,
      conditionType: conditionType,
      direction: direction,
      targetValue: val,
      basePrice: meta.currentPrice,
      lastCheckedPrice: meta.currentPrice,
      isActive: true,
      isTriggered: false,
      triggerCount: 0,
      ttsEnabled: ttsEnabled,
      createdAt: new Date(),
    };

    setRules([newRule, ...rules]);
    setShowCreateModal(false);
    setCreatePath('NONE');
    setMacroStep(1);
    showToast(`هشدار برای ${meta.nameFa} با موفقیت فعال شد.`);
  };

  const formatInterval = (secs: number) => {
    if (secs >= 3600) return `${secs / 3600} ساعت`;
    if (secs >= 60) return `${secs / 60} دقیقه`;
    return `${secs} ثانیه`;
  };

  const formatTimeAgo = (date: Date) => {
    const diff = Math.floor((Date.now() - new Date(date).getTime()) / 1000);
    if (diff < 10) return 'همین الان';
    if (diff < 60) return `${diff} ثانیه قبل`;
    if (diff < 3600) return `${Math.floor(diff / 60)} دقیقه قبل`;
    return `${Math.floor(diff / 3600)} ساعت قبل`;
  };

  const isOrange = appTheme.includes('orange');
  const isPurpleBlue = appTheme.includes('purple-blue');
  const isLight = appTheme.startsWith('light');

  const accentClass = isPurpleBlue
    ? 'text-violet-400'
    : isOrange
    ? 'text-orange-400'
    : 'text-emerald-400';

  const accentBgClass = isPurpleBlue
    ? 'bg-gradient-to-r from-violet-600 to-indigo-600 hover:from-violet-500 hover:to-indigo-500 text-white font-bold'
    : isOrange
    ? 'bg-orange-500 hover:bg-orange-400 text-slate-950 font-bold'
    : 'bg-emerald-500 hover:bg-emerald-400 text-slate-950 font-bold';

  const accentSubtleClass = isPurpleBlue
    ? 'bg-violet-500/10 border-violet-500/20 text-violet-400'
    : isOrange
    ? 'bg-orange-500/10 border-orange-500/20 text-orange-400'
    : 'bg-emerald-500/10 border-emerald-500/20 text-emerald-400';

  // Filtered 40+ Exchanges
  const filteredExchanges = ALL_EXCHANGES.filter((ex) => {
    const matchesCategory = exchangeCategoryFilter === 'all' || ex.category === exchangeCategoryFilter;
    const matchesSearch = !exchangeSearchQuery ||
      ex.name.toLowerCase().includes(exchangeSearchQuery.toLowerCase()) ||
      ex.countryBadge.toLowerCase().includes(exchangeSearchQuery.toLowerCase());
    return matchesCategory && matchesSearch;
  });

  // Filtered Macro Assets
  const filteredMacroAssets = Object.entries(macroPrices).filter(([key, asset]) => {
    const matchesCategory = macroCategoryFilter === 'all' || asset.category === macroCategoryFilter;
    const matchesSearch = !macroSearchQuery ||
      asset.name.toLowerCase().includes(macroSearchQuery.toLowerCase()) ||
      asset.nameFa.includes(macroSearchQuery) ||
      asset.symbol.toLowerCase().includes(macroSearchQuery.toLowerCase());
    return matchesCategory && matchesSearch;
  });

  const currentLangObj = SUPPORTED_LANGUAGES.find(l => l.code === currentLang) || SUPPORTED_LANGUAGES[0];

  return (
    <div className={`min-h-screen ${isLight ? 'bg-slate-100 text-slate-900' : 'bg-slate-950 text-slate-100'} flex flex-col font-sans transition-colors duration-200`} dir={currentLangObj.dir}>
      {/* Header */}
      <header className={`border-b ${isLight ? 'border-slate-200 bg-white/90' : 'border-slate-800/80 bg-slate-900/80'} backdrop-blur-md sticky top-0 z-40 px-4 lg:px-8 py-3.5 flex flex-wrap items-center justify-between gap-4`}>
        <div className="flex items-center gap-3">
          <div className={`h-10 w-10 rounded-xl ${isOrange ? 'bg-gradient-to-br from-orange-500 to-amber-600' : 'bg-gradient-to-br from-emerald-500 to-teal-600'} flex items-center justify-center shadow-lg text-slate-950`}>
            <AlarmClock className="h-5 w-5 font-bold" />
          </div>
          <div>
            <div className="flex items-center gap-2">
              <h1 className="text-base lg:text-lg font-bold tracking-tight flex items-center gap-2">
                Alarmer (سامانه هشدار بازارها)
              </h1>
              <span className={`text-[10px] px-2 py-0.5 rounded-full font-mono border ${accentSubtleClass}`}>
                40+ Exchanges & US Treasury
              </span>
            </div>
            <p className="text-xs text-slate-400 hidden sm:block">
              پوشش کامل صرافی‌های کریپتو، اوراق قرضه ۱۰ ساله آمریکا (US10Y)، جفت‌ارزهای فارکس، سهام و طلا
            </p>
          </div>
        </div>

        {/* Top Controls */}
        <div className="flex items-center gap-2.5">
          <button
            onClick={() => setShowLanguageModal(true)}
            className={`px-2.5 py-1.5 rounded-xl border text-xs flex items-center gap-1.5 ${isLight ? 'border-slate-300 bg-white' : 'border-slate-800 bg-slate-900'}`}
            title="انتخاب زبان"
          >
            <span className="text-base">{currentLangObj.flag}</span>
            <span className="text-xs font-semibold">{currentLangObj.nameEn}</span>
          </button>

          <button
            onClick={() => setSoundEnabled(!soundEnabled)}
            className={`p-2 rounded-xl border text-xs flex items-center gap-1.5 ${
              soundEnabled ? accentSubtleClass : 'border-slate-700 bg-slate-800 text-slate-400'
            }`}
          >
            {soundEnabled ? <Volume2 className="h-4 w-4" /> : <VolumeX className="h-4 w-4" />}
          </button>
          
          <button
            onClick={() => {
              if (rules.length > 0) {
                evaluateRule(rules[0], 1.5);
              }
            }}
            className={`px-3 py-1.5 rounded-xl ${accentBgClass} text-slate-950 font-bold text-xs flex items-center gap-1.5 shadow-sm transition-all`}
          >
            <Sparkles className="h-4 w-4" />
            <span>تست نوسان (+۱.۵٪)</span>
          </button>
        </div>
      </header>

      {/* Toast Alert */}
      {toastMessage && (
        <div className={`fixed bottom-6 left-6 z-50 ${isLight ? 'bg-white border-emerald-500 shadow-xl text-slate-900' : 'bg-slate-900 border-emerald-500/50 text-emerald-300 shadow-2xl'} text-xs px-4 py-3 rounded-2xl border flex items-center gap-2 animate-bounce`}>
          <CheckCircle2 className="h-4 w-4 text-emerald-400 shrink-0" />
          <span className="font-semibold">{toastMessage}</span>
        </div>
      )}

      {/* Main Content */}
      <main className="flex-1 p-4 lg:p-8 max-w-7xl mx-auto w-full">
        <div className="grid grid-cols-1 lg:grid-cols-12 gap-8 items-start">
          {/* Left: Interactive Phone Screen */}
          <div className="lg:col-span-7 flex justify-center">
            <div className={`w-full max-w-[400px] h-[800px] ${
              isLight 
                ? (isPurpleBlue ? 'bg-[#f5f6ff] border-indigo-200 shadow-indigo-200/50' : 'bg-slate-50 border-slate-300') 
                : (isPurpleBlue ? 'bg-[#0b0d1b] border-[#2e365e] shadow-purple-950/50' : 'bg-slate-950 border-slate-800')
            } border-[8px] rounded-[48px] shadow-2xl flex flex-col overflow-hidden relative ring-1 ring-slate-700/50`}>
              {/* Dynamic Island */}
              <div className={`absolute top-2 left-1/2 -translate-x-1/2 h-5 w-28 ${isLight ? 'bg-slate-300' : 'bg-slate-900'} rounded-full z-30 flex items-center justify-center`}>
                <div className={`h-2 w-12 ${isLight ? 'bg-slate-400' : 'bg-slate-950'} rounded-full`} />
              </div>

              {/* Status Bar */}
              <div className="pt-3 px-6 pb-1 flex justify-between items-center text-[10px] text-slate-400 font-mono z-20">
                <span>12:40</span>
                <div className="flex items-center gap-1.5">
                  <span className={`font-semibold text-[9px] ${accentClass}`}>40+ EXCHANGES • US BONDS</span>
                  <span className={`h-1.5 w-1.5 rounded-full ${isPurpleBlue ? 'bg-violet-400' : isOrange ? 'bg-orange-500' : 'bg-emerald-400'} animate-pulse`} />
                </div>
              </div>

              {/* Minimal Height Persistent Background Service Notification */}
              <div className="mx-3 mb-1 px-2.5 py-1 rounded-lg bg-slate-900/90 border border-slate-800 text-[10px] flex items-center justify-between shadow-sm z-20">
                <div className="flex items-center gap-1.5">
                  <span className="h-1.5 w-1.5 rounded-full bg-emerald-400"></span>
                  <span className="font-bold text-slate-200">Alarmer</span>
                  <span className="text-slate-400">• ● Active</span>
                </div>
                <span className="text-[9px] text-slate-500 font-mono">Foreground</span>
              </div>

              {/* Phone App Header */}
              <div className={`px-4 py-3 border-b ${isLight ? 'border-slate-200 bg-white' : 'border-slate-900 bg-slate-950'} flex items-center justify-between`}>
                <div className="flex items-center gap-2.5">
                  <div className={`h-8 w-8 rounded-xl ${accentSubtleClass} border flex items-center justify-center`}>
                    <AlarmClock className="h-4 w-4" />
                  </div>
                  <div>
                    <h2 className="text-sm font-bold">
                      {mobileScreen === 'alerts' && 'هشدارهای من (پیش‌فرض)'}
                      {mobileScreen === 'history' && 'تاریخچه اعلان‌ها'}
                      {mobileScreen === 'settings' && 'تنظیمات برنامه'}
                    </h2>
                    <p className="text-[10px] text-slate-400">رمزارزها • اوراق قرضه آمریکا • فارکس • سهام</p>
                  </div>
                </div>

                {mobileScreen === 'alerts' && (
                  <div className="flex items-center gap-1.5">
                    <button
                      onClick={() => setShowHomeWidgetModal(true)}
                      className="p-1.5 rounded-xl border border-slate-700 bg-slate-900/90 text-slate-300 hover:text-white transition-all font-semibold flex items-center gap-1 text-[11px] px-2 shadow-sm cursor-pointer"
                      title="پیش‌نمایش ویجت صفحه اصلی"
                    >
                      <LayoutGrid className="h-3.5 w-3.5 text-violet-400" />
                      <span>ویجت</span>
                    </button>
                    <button
                      onClick={() => {
                        setCreatePath('NONE');
                        setShowCreateModal(true);
                      }}
                      className={`p-1.5 rounded-xl ${accentBgClass} text-slate-950 transition-all font-bold flex items-center gap-1 text-[11px] px-2.5 shadow-md cursor-pointer`}
                    >
                      <Plus className="h-3.5 w-3.5" />
                      <span>ایجاد هشدار</span>
                    </button>
                  </div>
                )}
              </div>

              {/* App Body */}
              <div className="flex-1 overflow-y-auto p-3 space-y-3 custom-scrollbar text-xs">
                {/* TAB 1 (MIDDLE & DEFAULT): ALERTS */}
                {mobileScreen === 'alerts' && (
                  <div className="space-y-3">
                    {rules.length === 0 ? (
                      <div className="text-center py-16 px-4 space-y-3">
                        <div className="h-16 w-16 mx-auto rounded-full bg-slate-900 border border-slate-800 flex items-center justify-center text-emerald-400">
                          <AlarmClock className="h-8 w-8" />
                        </div>
                        <h3 className="text-sm font-bold">هنوز هشداری تنظیم نشده است</h3>
                        <p className="text-slate-400 text-xs leading-relaxed">
                          با کلیک بر روی دکمه زیر، بازار مورد نظر را انتخاب و اولین هشدار خود را بسازید.
                        </p>
                        <button
                          onClick={() => {
                            setCreatePath('NONE');
                            setShowCreateModal(true);
                          }}
                          className={`px-4 py-2 ${accentBgClass} text-slate-950 font-bold rounded-xl text-xs inline-flex items-center gap-1.5 mt-2`}
                        >
                          <Plus className="h-4 w-4" />
                          <span>ایجاد هشدار جدید</span>
                        </button>
                      </div>
                    ) : (
                      rules.map((rule) => {
                        let iconUrl = '';
                        let nameFa = rule.marketSymbol;
                        let unit = '$';

                        if (rule.marketType === 'crypto') {
                          const meta = cryptoPrices[rule.baseCurrency] || cryptoPrices.BTC;
                          iconUrl = meta?.icon || '';
                          nameFa = meta?.nameFa || rule.baseCurrency;
                          unit = '$';
                        } else {
                          const meta = macroPrices[rule.baseCurrency] || macroPrices.US10Y;
                          iconUrl = meta?.icon || '';
                          nameFa = meta?.nameFa || rule.baseCurrency;
                          unit = meta?.unit || '$';
                        }

                        const isChecking = checkingRuleId === rule.uuid;
                        const displayP = rule.lastCheckedPrice ?? rule.basePrice;
                        const changePct = rule.basePrice > 0 ? ((displayP - rule.basePrice) / rule.basePrice) * 100 : 0;

                        return (
                          <div
                            key={rule.uuid}
                            className={`p-3.5 rounded-2xl border transition-all ${
                              isLight
                                ? 'bg-white border-slate-200 shadow-sm'
                                : (rule.isActive ? 'bg-slate-900/90 border-slate-800 hover:border-slate-700' : 'bg-slate-900/40 border-slate-800/40 opacity-70')
                            }`}
                          >
                            {/* Top Row: Icon + Name + Market Badge + Toggle */}
                            <div className="flex items-center justify-between mb-2.5">
                              <div className="flex items-center gap-2.5">
                                <img
                                  src={iconUrl}
                                  alt={nameFa}
                                  className="h-10 w-10 rounded-full object-cover border border-slate-700 p-0.5 bg-slate-800"
                                  onError={(e) => {
                                    (e.target as any).src = 'https://cdn-icons-png.flaticon.com/512/2830/2830284.png';
                                  }}
                                />
                                <div>
                                  <div className="flex items-center gap-1.5">
                                    <span className="font-bold text-sm">{nameFa}</span>
                                    <span className="text-[11px] font-mono text-slate-400">({rule.marketSymbol})</span>
                                  </div>
                                  <div className="flex items-center gap-1.5 mt-0.5">
                                    <span className={`px-1.5 py-0.5 rounded text-[9px] font-bold ${
                                      rule.assetCategory === 'bond' ? 'bg-emerald-500/20 text-emerald-300 border border-emerald-500/30' :
                                      rule.assetCategory === 'forex' ? 'bg-blue-500/20 text-blue-300 border border-blue-500/30' :
                                      rule.assetCategory === 'stock' ? 'bg-purple-500/20 text-purple-300 border border-purple-500/30' :
                                      rule.assetCategory === 'commodity' ? 'bg-amber-500/20 text-amber-300 border border-amber-500/30' :
                                      'bg-cyan-500/20 text-cyan-300 border border-cyan-500/30'
                                    }`}>
                                      {rule.exchangeName}
                                    </span>
                                    <span className={`px-2 py-0.5 rounded border text-[10px] font-medium flex items-center gap-1 ${accentSubtleClass}`}>
                                      <Timer className="h-3 w-3" />
                                      <span>بررسی هر {formatInterval(rule.checkIntervalSeconds)}</span>
                                    </span>
                                  </div>
                                </div>
                              </div>

                              {/* Toggle Switch */}
                              <button
                                onClick={() => handleToggle(rule.uuid)}
                                className={`w-10 h-6 rounded-full transition-colors relative p-0.5 ${
                                  rule.isActive ? (isOrange ? 'bg-orange-500' : 'bg-emerald-500') : 'bg-slate-700'
                                }`}
                              >
                                <div
                                  className={`w-5 h-5 rounded-full bg-white transition-transform ${
                                    rule.isActive ? '-translate-x-4' : 'translate-x-0'
                                  }`}
                                />
                              </button>
                            </div>

                            {/* Prominent Latest Checked Price (بزرگ و بولد) */}
                            <div className={`p-3 rounded-xl border mb-2 flex items-center justify-between ${isLight ? 'bg-slate-50 border-slate-200' : 'bg-slate-950 border-slate-800'}`}>
                              <div>
                                <span className="text-[10px] text-slate-400 block mb-0.5">آخرین نرخ بررسی‌شده:</span>
                                <span className="text-xl font-extrabold font-mono tracking-tight">
                                  {unit === '$' ? `$${displayP >= 1000 ? Math.round(displayP).toLocaleString() : (displayP < 1 ? displayP.toFixed(6) : displayP.toFixed(2))}` : `${displayP >= 1000 ? Math.round(displayP).toLocaleString() : displayP.toFixed(2)}${unit}`}
                                </span>
                              </div>
                              <div className="text-left">
                                <span className={`px-2 py-1 rounded-lg border font-mono font-bold text-xs flex items-center gap-1 ${
                                  changePct >= 0
                                    ? 'bg-emerald-500/10 text-emerald-500 border-emerald-500/20'
                                    : 'bg-rose-500/10 text-rose-500 border-rose-500/20'
                                }`}>
                                  {changePct >= 0 ? <ArrowUpRight className="h-3.5 w-3.5" /> : <ArrowDownRight className="h-3.5 w-3.5" />}
                                  <span>{changePct >= 0 ? '+' : ''}{changePct.toFixed(2)}%</span>
                                </span>
                              </div>
                            </div>

                            {/* Condition Banner */}
                            <div className={`p-2 rounded-xl border mb-2 text-[11px] ${isLight ? 'bg-slate-50 border-slate-200' : 'bg-slate-900 border-slate-800'}`}>
                              {rule.conditionType === 'PERCENT_CHANGE' ? (
                                <div className="flex items-center justify-between">
                                  <span className={`flex items-center gap-1 font-semibold ${accentClass}`}>
                                    {rule.direction === 'BOTH' ? 'تغییر نرخ: ±' : (rule.direction === 'ABOVE' ? 'افزایش نرخ: +' : 'کاهش نرخ: -')}
                                    <span className="font-mono">{rule.targetValue}%</span>
                                  </span>
                                  <span className="text-slate-400 text-[10px]">ادامه‌دار (تکرارشونده)</span>
                                </div>
                              ) : (
                                <div className="flex items-center justify-between">
                                  <span className="font-semibold text-amber-400">
                                    نرخ هدف: {unit}{rule.targetValue.toLocaleString()}
                                  </span>
                                  <span className="text-slate-400 text-[10px]">یک‌بار مصرف</span>
                                </div>
                              )}
                            </div>

                            {/* Rich Footer: Base Price, Last Checked, Manual Refresh & Delete */}
                            <div className={`flex items-center justify-between text-[10px] text-slate-400 pt-2 border-t ${isLight ? 'border-slate-200' : 'border-slate-800/80'}`}>
                              <div className="flex items-center gap-2">
                                <span>قیمت مبنا: <strong className="font-mono text-slate-300">{unit}{rule.basePrice < 1 ? rule.basePrice.toFixed(6) : rule.basePrice.toLocaleString()}</strong></span>
                                <span>•</span>
                                <span>{rule.lastCheckedAt ? formatTimeAgo(rule.lastCheckedAt) : 'در صف'}</span>
                              </div>

                              <div className="flex items-center gap-1.5">
                                <button
                                  onClick={() => handleManualCheck(rule)}
                                  disabled={isChecking}
                                  className={`px-2.5 py-1 rounded-lg ${isLight ? 'bg-slate-100 hover:bg-slate-200 text-slate-800' : 'bg-slate-800 hover:bg-slate-700 text-emerald-400'} flex items-center gap-1 text-[10px] font-semibold transition-all`}
                                  title="بررسی آنی قیمت"
                                >
                                  <RefreshCw className={`h-3 w-3 ${isChecking ? 'animate-spin' : ''}`} />
                                  <span>بررسی آنی</span>
                                </button>
                                <button
                                  onClick={() => handleDelete(rule.uuid)}
                                  className="p-1.5 rounded-lg text-slate-400 hover:text-rose-400 hover:bg-rose-500/10 transition-colors"
                                  title="حذف هشدار"
                                >
                                  <Trash2 className="h-3.5 w-3.5" />
                                </button>
                              </div>
                            </div>
                          </div>
                        );
                      })
                    )}
                  </div>
                )}

                {/* TAB 0 (LEFT): HISTORY */}
                {mobileScreen === 'history' && (
                  <div className="space-y-2.5">
                    {notifications.map((notif) => (
                      <div key={notif.id} className={`p-3 rounded-2xl border space-y-1.5 ${isLight ? 'bg-white border-slate-200 shadow-sm' : 'bg-slate-900 border-slate-800'}`}>
                        <div className="flex items-center justify-between">
                          <span className="font-bold text-xs">{notif.title}</span>
                          <span className="text-[10px] font-mono text-slate-400">{formatTimeAgo(notif.timestamp)}</span>
                        </div>
                        <p className="text-[11px] text-slate-400 leading-relaxed">{notif.body}</p>
                        <div className="flex items-center gap-2 pt-1 text-[10px] font-mono text-slate-400">
                          <span>بازار: {notif.marketSymbol}</span>
                          <span>•</span>
                          <span className={`font-bold ${accentClass}`}>{notif.value}</span>
                        </div>
                      </div>
                    ))}
                  </div>
                )}

                {/* TAB 2 (RIGHT): SETTINGS */}
                {mobileScreen === 'settings' && (
                  <div className="space-y-3.5">
                    {/* Language Setting */}
                    <div className={`p-3.5 rounded-2xl border ${isLight ? 'bg-white border-slate-200 shadow-sm' : 'bg-slate-900 border-slate-800'} space-y-2`}>
                      <div className="font-bold text-xs flex items-center justify-between">
                        <div className="flex items-center gap-2">
                          <Languages className="h-4 w-4 text-emerald-400" />
                          <span>زبان برنامه (۱۰ زبان بین‌المللی)</span>
                        </div>
                        <button
                          onClick={() => setShowLanguageModal(true)}
                          className={`text-xs font-bold ${accentClass} underline`}
                        >
                          تغییر زبان
                        </button>
                      </div>
                      <div className="flex items-center gap-2 p-2 rounded-xl bg-slate-950 border border-slate-800 text-[11px]">
                        <span className="text-xl">{currentLangObj.flag}</span>
                        <div>
                          <span className="font-bold text-white block">{currentLangObj.name}</span>
                          <span className="text-[10px] text-slate-400">{currentLangObj.nameEn}</span>
                        </div>
                      </div>
                    </div>

                    {/* Themes (4 Palettes) */}
                    <div className={`p-3.5 rounded-2xl border ${isLight ? 'bg-white border-slate-200 shadow-sm' : 'bg-slate-900 border-slate-800'} space-y-2.5`}>
                      <div className="flex items-center gap-2 font-bold text-xs">
                        <Palette className={`h-4 w-4 ${accentClass}`} />
                        <span>پوسته و تم رنگی (۶ حالت)</span>
                      </div>
                      <div className="grid grid-cols-2 gap-2">
                        {[
                          { id: 'dark-green', name: 'دارک سبز (پیش‌فرض)', bg: '#020617', border: '#10B981' },
                          { id: 'light-green', name: 'لایت سبز', bg: '#F8FAFC', border: '#059669' },
                          { id: 'dark-purple-blue', name: 'دارک بنفش آبی 💜💙', bg: '#0B0D1B', border: '#8B5CF6' },
                          { id: 'light-purple-blue', name: 'لایت بنفش آبی 💜💙', bg: '#F5F6FF', border: '#7C3AED' },
                          { id: 'dark-orange', name: 'دارک نارنجی', bg: '#0C0A09', border: '#F97316' },
                          { id: 'light-orange', name: 'لایت نارنجی', bg: '#FAFAF9', border: '#EA580C' },
                        ].map((t) => (
                          <button
                            key={t.id}
                            onClick={() => setAppTheme(t.id as any)}
                            className={`p-2.5 rounded-xl border text-right text-[11px] flex items-center gap-2 font-semibold transition-all ${
                              appTheme === t.id
                                ? (isPurpleBlue ? 'border-violet-500 bg-violet-500/15' : isOrange ? 'border-orange-500 bg-orange-500/15' : 'border-emerald-500 bg-emerald-500/15')
                                : 'border-slate-700 bg-slate-950/50'
                            }`}
                          >
                            <span className="h-4 w-4 rounded-full border-2 shrink-0" style={{ backgroundColor: t.bg, borderColor: t.border }} />
                            <span className="truncate">{t.name}</span>
                          </button>
                        ))}
                      </div>
                    </div>

                    {/* Backup & Restore Buttons */}
                    <div className={`p-3.5 rounded-2xl border ${isLight ? 'bg-white border-slate-200 shadow-sm' : 'bg-slate-900 border-slate-800'} space-y-2`}>
                      <div className="font-bold text-xs flex items-center gap-2">
                        <Database className="h-4 w-4 text-emerald-400" />
                        <span>پشتیبان‌گیری و بازیابی (Backup & Restore)</span>
                      </div>
                      <div className="grid grid-cols-2 gap-2 pt-1">
                        <button
                          onClick={handleExportBackup}
                          className="p-2.5 rounded-xl bg-slate-800 hover:bg-slate-700 text-emerald-400 font-bold text-xs flex items-center justify-center gap-1.5 border border-slate-700 transition-all"
                        >
                          <Upload className="h-3.5 w-3.5" />
                          <span>خروجی بک‌آپ</span>
                        </button>
                        <button
                          onClick={() => setShowRestoreModal(true)}
                          className="p-2.5 rounded-xl bg-slate-800 hover:bg-slate-700 text-cyan-400 font-bold text-xs flex items-center justify-center gap-1.5 border border-slate-700 transition-all"
                        >
                          <Download className="h-3.5 w-3.5" />
                          <span>بازیابی بک‌آپ</span>
                        </button>
                      </div>
                    </div>
                  </div>
                )}
              </div>

              {/* Bottom Nav: 
                  TAB LEFT (Index 0): HISTORY
                  TAB MIDDLE (Index 1 - DEFAULT & PROMINENT): ALERTS
                  TAB RIGHT (Index 2): SETTINGS
              */}
              <div className={`border-t ${isLight ? 'border-slate-200 bg-white' : 'border-slate-900 bg-slate-950'} px-6 py-2.5 flex items-center justify-around z-20`}>
                {/* 1. Left Tab: History */}
                <button
                  onClick={() => setMobileScreen('history')}
                  className={`flex flex-col items-center gap-1 transition-colors ${
                    mobileScreen === 'history' ? `${accentClass} font-bold` : 'text-slate-400 hover:text-slate-300'
                  }`}
                >
                  <Bell className="h-5 w-5" />
                  <span className="text-[10px]">تاریخچه</span>
                </button>

                {/* 2. Middle Tab: Alerts (Default & Floating Prominent) */}
                <button
                  onClick={() => setMobileScreen('alerts')}
                  className={`flex flex-col items-center gap-1 transition-colors relative ${
                    mobileScreen === 'alerts' ? `${accentClass} font-bold` : 'text-slate-400 hover:text-slate-300'
                  }`}
                >
                  <div className={`h-10 w-10 -mt-4 rounded-full flex items-center justify-center shadow-xl transition-transform hover:scale-105 ${
                    mobileScreen === 'alerts' ? `${accentBgClass} text-slate-950 font-bold` : 'bg-slate-800 text-slate-300'
                  }`}>
                    <AlarmClock className="h-5 w-5" />
                  </div>
                  <span className="text-[10px] font-bold">هشدارهای من</span>
                </button>

                {/* 3. Right Tab: Settings */}
                <button
                  onClick={() => setMobileScreen('settings')}
                  className={`flex flex-col items-center gap-1 transition-colors ${
                    mobileScreen === 'settings' ? `${accentClass} font-bold` : 'text-slate-400 hover:text-slate-300'
                  }`}
                >
                  <SettingsIcon className="h-5 w-5" />
                  <span className="text-[10px]">تنظیمات</span>
                </button>
              </div>

              {/* Android Soft Nav Bar with Back Button (Move to Background) */}
              <div className={`py-1.5 px-10 flex items-center justify-between text-slate-500 ${isLight ? 'bg-slate-100 border-slate-200' : 'bg-slate-950 border-slate-900'} border-t z-20`}>
                <button
                  type="button"
                  title="دکمه برگشت اندروید (انتقال به پس‌زمینه بدون بستن برنامه)"
                  onClick={() => {
                    showToast('برنامه به پس‌زمینه منتقل شد؛ پایش و آلارم‌ها بدون وقفه در حال اجرا هستند (● Active)');
                  }}
                  className="hover:text-slate-200 transition-colors p-1 flex items-center gap-1 text-[11px] font-mono cursor-pointer"
                >
                  <span>◀</span>
                  <span className="text-[9px] text-slate-400">Back (Background)</span>
                </button>
                <div className="h-2 w-2 rounded-full border border-slate-500"></div>
                <div className="h-2.5 w-2.5 border border-slate-500 rounded-sm"></div>
              </div>
            </div>
          </div>

          {/* Right Explainer & Home Screen Widget */}
          <div className="lg:col-span-5 space-y-6">
            {/* Live Interactive Home Screen Widget Card */}
            <div className={`border rounded-3xl p-5 backdrop-blur-md ${isLight ? 'bg-white/95 border-slate-300 shadow-xl' : 'bg-slate-900/90 border-slate-800 shadow-2xl'} space-y-3.5`}>
              <div className="flex items-center justify-between border-b pb-3 border-slate-800/80">
                <div className="flex items-center gap-2">
                  <div className="p-2 rounded-xl bg-violet-500/20 text-violet-400">
                    <LayoutGrid className="h-5 w-5" />
                  </div>
                  <div>
                    <h3 className="text-sm font-bold text-white flex items-center gap-2">
                      <span>ویجت زنده صفحه اصلی (Home Widget)</span>
                      <span className="text-[10px] px-2 py-0.5 rounded-full bg-emerald-500/20 text-emerald-400 border border-emerald-500/30 font-mono">
                        ● LIVE 24/7
                      </span>
                    </h3>
                    <p className="text-[11px] text-slate-400">رصد بلادرنگ وضعیت آلارم‌ها، نرخ زنده و فاصله تا هدف روی صفحه اصلی</p>
                  </div>
                </div>
                <button
                  onClick={() => {
                    rules.forEach((r) => evaluateRule(r));
                    showToast('🔄 تمام هشدارهای ویجت صفحه اصلی استعلام شدند.');
                  }}
                  className="p-1.5 rounded-xl border border-slate-700 bg-slate-800 text-slate-300 hover:text-white transition-all text-[11px] flex items-center gap-1 cursor-pointer"
                  title="استعلام فوری همه"
                >
                  <RefreshCw className="h-3.5 w-3.5" />
                  <span className="hidden sm:inline">بروزرسانی</span>
                </button>
              </div>

              {/* Active Rules List in the Widget */}
              <div className="space-y-2.5">
                {rules.slice(0, 4).map((rule) => {
                  const currentPrice = rule.lastCheckedPrice || rule.basePrice;
                  let targetProximity = 50;
                  if (rule.conditionType === 'PRICE_THRESHOLD' && rule.targetValue > 0) {
                    targetProximity = Math.min(100, Math.round((currentPrice / rule.targetValue) * 100));
                  } else if (rule.conditionType === 'PERCENT_CHANGE') {
                    const deltaPct = Math.abs(((currentPrice - rule.basePrice) / rule.basePrice) * 100);
                    targetProximity = Math.min(100, Math.round((deltaPct / rule.targetValue) * 100));
                  }

                  const isNearTarget = targetProximity >= 90;
                  const isTriggered = rule.isTriggered;

                  return (
                    <div
                      key={rule.uuid}
                      className={`p-3 rounded-2xl border transition-all ${
                        isTriggered
                          ? 'bg-rose-950/20 border-rose-500/40'
                          : isNearTarget
                          ? 'bg-amber-950/20 border-amber-500/40'
                          : 'bg-slate-950/70 border-slate-800/80 hover:border-slate-700'
                      }`}
                    >
                      <div className="flex items-center justify-between mb-1.5">
                        <div className="flex items-center gap-2">
                          <span className="font-bold text-xs text-white">{rule.marketSymbol}</span>
                          <span className="text-[10px] px-1.5 py-0.5 rounded bg-slate-800 text-slate-400 font-mono">
                            {rule.exchangeName}
                          </span>
                          {rule.ttsEnabled && (
                            <span className="text-[10px] px-1.5 py-0.5 rounded bg-violet-500/20 text-violet-300 flex items-center gap-1 font-semibold" title="خوانش صوتی فعال">
                              <Volume2 className="h-3 w-3" />
                              <span>TTS</span>
                            </span>
                          )}
                        </div>
                        <div className="text-right">
                          <span className="font-mono font-bold text-sm text-white block">
                            ${currentPrice.toLocaleString()}
                          </span>
                        </div>
                      </div>

                      {/* Progress Bar & Status */}
                      <div className="space-y-1">
                        <div className="flex items-center justify-between text-[10px]">
                          <span className="text-slate-400">
                            شرط: {rule.conditionType === 'PRICE_THRESHOLD' ? `${rule.direction === 'ABOVE' ? '≥' : '≤'} $${rule.targetValue.toLocaleString()}` : `تغییر ${rule.targetValue}%`}
                          </span>
                          <span className={`font-semibold ${isTriggered ? 'text-rose-400' : isNearTarget ? 'text-amber-400' : 'text-emerald-400'}`}>
                            {isTriggered ? '🚨 فراخوانده شد' : isNearTarget ? `⚠️ ${targetProximity}% (نزدیک هدف)` : `پایش فعال • ${targetProximity}%`}
                          </span>
                        </div>
                        <div className="w-full bg-slate-800 rounded-full h-1.5 overflow-hidden">
                          <div
                            className={`h-full rounded-full transition-all duration-500 ${
                              isTriggered ? 'bg-rose-500' : isNearTarget ? 'bg-amber-500' : 'bg-emerald-500'
                            }`}
                            style={{ width: `${targetProximity}%` }}
                          />
                        </div>
                      </div>

                      <div className="mt-2 pt-1.5 border-t border-slate-800/60 flex items-center justify-between text-[10px] text-slate-400">
                        <span>آخرین بررسی: {formatTimeAgo(rule.lastCheckedAt || new Date())}</span>
                        <div className="flex items-center gap-2">
                          {rule.ttsEnabled && (
                            <button
                              onClick={() => testTtsSpeech(rule.baseCurrency, currentPrice)}
                              className="text-violet-400 hover:text-violet-300 font-semibold flex items-center gap-1 cursor-pointer"
                            >
                              <span>تست صدا</span>
                            </button>
                          )}
                          <button
                            onClick={() => evaluateRule(rule, 1.5)}
                            className="text-emerald-400 hover:text-emerald-300 font-semibold cursor-pointer"
                          >
                            تست شبیه‌سازی
                          </button>
                        </div>
                      </div>
                    </div>
                  );
                })}
              </div>

              <div className="pt-1 flex items-center justify-between text-[11px] text-slate-400 border-t border-slate-800">
                <span>📱 طراحی شده برای ویجت اندروید ۱۴ و iOS ۱۷</span>
                <span className="font-mono text-emerald-400 font-semibold">Real-Time Sync</span>
              </div>
            </div>

            <div className={`border rounded-2xl p-6 backdrop-blur-sm ${isLight ? 'bg-white/80 border-slate-200 shadow-sm' : 'bg-slate-900/60 border-slate-800'}`}>
              <h3 className="text-lg font-bold mb-3 flex items-center gap-2">
                <Sparkles className="h-5 w-5 text-emerald-400" />
                <span>پلتفرم هشدار چندبازاره پیشرفته</span>
              </h3>
              <p className="text-xs text-slate-300 leading-relaxed mb-4">
                طراحی دقیق، اصیل و کاربرپسند با پشتیبانی از بیش از ۴۰ صرافی کریپتو به همراه بازار اوراق قرضه خزانه‌داری آمریکا، جفت‌ارزهای فارکس، سهام‌های وال‌استریت و طلا:
              </p>
              
              <div className="space-y-3 text-xs">
                <div className="p-3.5 rounded-xl bg-slate-950 border border-slate-800 space-y-1">
                  <div className="flex items-center gap-2 text-emerald-400 font-bold">
                    <Zap className="h-4 w-4" />
                    <span>⚡ بیش از ۴۰ صرافی با دسته‌بندی منطقه‌ای</span>
                  </div>
                  <p className="text-slate-400 text-[11px]">
                    ⭐ جهانی رتبه یک (Binance, Coinbase, Kraken, Bybit, KuCoin) • 📊 اگریگیتورها (CoinGecko با ۱۰هزار کوین) • 🇮🇷 ایران (نوبیتکس، والکس، تبدیل) • ⛩️ آسیا • 🇪🇺 اروپا • 🌎 آمریکا.
                  </p>
                </div>

                <div className="p-3.5 rounded-xl bg-slate-950 border border-slate-800 space-y-1">
                  <div className="flex items-center gap-2 text-blue-400 font-bold">
                    <Landmark className="h-4 w-4" />
                    <span>🏛️ بازارهای جهانی، اوراق قرضه و فارکس</span>
                  </div>
                  <p className="text-slate-400 text-[11px]">
                    اوراق قرضه ۱۰ ساله آمریکا (US10Y / ^TNX)، اوراق ۲ ساله و ۳۰ ساله، جفت‌ارزهای فارکس (EUR/USD, GBP/USD)، سهام‌های نزدک/نیویورک (انویدیا، اپل، تسلا)، طلا و نفت خام.
                  </p>
                </div>

                <div className="p-3.5 rounded-xl bg-slate-950 border border-slate-800 space-y-1">
                  <div className="flex items-center gap-2 text-purple-400 font-bold">
                    <Languages className="h-4 w-4" />
                    <span>🌍 ۱۰ زبان بین‌المللی و ۴ تم رنگی</span>
                  </div>
                  <p className="text-slate-400 text-[11px]">
                    پشتیبانی کامل از فارسی، انگلیسی، آلمانی، فرانسوی، اسپانیایی، چینی، کره‌ای، کوردی، عربی و ترکی با تم‌های دارک/لایت سبز و نارنجی.
                  </p>
                </div>
              </div>
            </div>
          </div>
        </div>
      </main>

      {/* DUAL-MODE MODAL: CHOICE OF MARKET */}
      {showCreateModal && (
        <div className="fixed inset-0 z-50 bg-black/80 backdrop-blur-sm flex items-center justify-center p-4">
          <div className="bg-slate-900 border border-slate-800 rounded-3xl w-full max-w-xl p-6 space-y-5 text-right relative shadow-2xl animate-in fade-in zoom-in-95">
            <button
              onClick={() => {
                setShowCreateModal(false);
                setCreatePath('NONE');
              }}
              className="absolute top-5 left-5 p-1.5 rounded-full text-slate-400 hover:text-white bg-slate-800/80"
            >
              <X className="h-4 w-4" />
            </button>

            {/* SCREEN 0: CHOOSE ENTRY PATH (کریپتو یا سهام/فارکس/اوراق) */}
            {createPath === 'NONE' && (
              <div className="space-y-4">
                <div>
                  <span className="text-xs text-emerald-400 font-bold block mb-1">گام نخست: انتخاب نوع بازار</span>
                  <h3 className="text-base font-bold text-white">مایلید برای کدام بازار هشدار تنظیم کنید؟</h3>
                </div>

                <div className="grid grid-cols-1 sm:grid-cols-2 gap-3.5 pt-2">
                  {/* Option 1: Crypto (Previous Original Flow) */}
                  <button
                    onClick={() => {
                      setCreatePath('CRYPTO');
                      setCryptoStep(1);
                    }}
                    className="p-5 rounded-2xl border-2 border-slate-800 hover:border-emerald-500 bg-slate-950 hover:bg-emerald-500/5 text-right transition-all group relative overflow-hidden"
                  >
                    <div className="h-12 w-12 rounded-2xl bg-emerald-500/10 border border-emerald-500/20 text-emerald-400 flex items-center justify-center mb-3 group-hover:scale-110 transition-transform">
                      <Zap className="h-6 w-6" />
                    </div>
                    <h4 className="font-bold text-sm text-white mb-1">⚡ بازار رمزارزها (کریپتو)</h4>
                    <p className="text-[11px] text-slate-400 leading-relaxed">
                      بیش از ۴۰ صرافی معتبر بین‌المللی و ایرانی با چیپ‌های فیلتر، استخراج جفت‌ارزها و دکمه بروزرسانی
                    </p>
                    <div className="mt-3 flex items-center gap-1 text-[11px] font-bold text-emerald-400">
                      <span>ورود به بخش صرافی‌های کریپتو</span>
                      <span>←</span>
                    </div>
                  </button>

                  {/* Option 2: Stocks, Forex, US Bonds */}
                  <button
                    onClick={() => {
                      setCreatePath('STOCKS_MACRO');
                      setMacroStep(1);
                    }}
                    className="p-5 rounded-2xl border-2 border-slate-800 hover:border-blue-500 bg-slate-950 hover:bg-blue-500/5 text-right transition-all group relative overflow-hidden"
                  >
                    <div className="h-12 w-12 rounded-2xl bg-blue-500/10 border border-blue-500/20 text-blue-400 flex items-center justify-center mb-3 group-hover:scale-110 transition-transform">
                      <Landmark className="h-6 w-6" />
                    </div>
                    <h4 className="font-bold text-sm text-white mb-1">🏛️ سهام، اوراق قرضه آمریکا و فارکس</h4>
                    <p className="text-[11px] text-slate-400 leading-relaxed">
                      اوراق قرضه ۱۰ ساله آمریکا (US10Y)، جفت‌ارزهای فارکس، سهام‌های نزدک/نیویورک، طلا و شاخص‌ها
                    </p>
                    <div className="mt-3 flex items-center gap-1 text-[11px] font-bold text-blue-400">
                      <span>ورود به بازارهای جهانی</span>
                      <span>←</span>
                    </div>
                  </button>
                </div>
              </div>
            )}

            {/* ======================================================== */}
            {/* PATH A: CRYPTO (دقیقاً با چیپ‌های فیلتر و بیش از ۴۰ صرافی) */}
            {/* ======================================================== */}
            {createPath === 'CRYPTO' && (
              <div className="space-y-4">
                <div className="flex items-center justify-between border-b border-slate-800 pb-2">
                  <div className="flex items-center gap-2">
                    <button
                      onClick={() => {
                        if (cryptoStep > 1) {
                          setCryptoStep((cryptoStep - 1) as any);
                        } else {
                          setCreatePath('NONE');
                        }
                      }}
                      className="p-1 rounded-lg text-slate-400 hover:text-white bg-slate-800"
                    >
                      <ChevronLeft className="h-4 w-4 rotate-180" />
                    </button>
                    <div>
                      <span className="text-xs text-emerald-400 font-semibold block">مرحله {cryptoStep} از ۳ (رمزارزها)</span>
                      <h4 className="font-bold text-sm text-white">
                        {cryptoStep === 1 && '۱. انتخاب از بین ۴۰+ صرافی'}
                        {cryptoStep === 2 && `۲. انتخاب جفت‌ارز (${selectedExchange.name})`}
                        {cryptoStep === 3 && '۳. زمان‌بندی و شرط هشدار'}
                      </h4>
                    </div>
                  </div>
                </div>

                {/* Crypto Step 1: Exchange Filter Chips & 40+ Exchanges */}
                {cryptoStep === 1 && (
                  <div className="space-y-3 text-xs">
                    {/* Search */}
                    <input
                      type="text"
                      value={exchangeSearchQuery}
                      onChange={(e) => setExchangeSearchQuery(e.target.value)}
                      placeholder="جستجوی صرافی (Binance, Nobitex, Wallex, KuCoin, OKX, Bybit, CoinGecko)..."
                      className="w-full bg-slate-950 border border-slate-800 rounded-xl px-3 py-2 text-white placeholder:text-slate-500"
                    />

                    {/* Category Filter Chips */}
                    <div className="flex items-center gap-1.5 overflow-x-auto pb-1 custom-scrollbar">
                      {[
                        { id: 'all', label: 'همه (۴۰+)', icon: '🌐' },
                        { id: 'tier1', label: '⭐ جهانی رتبه یک', icon: '⭐' },
                        { id: 'aggregator', label: '📊 اگریگیتورها', icon: '📊' },
                        { id: 'middleEast', label: '🇮🇷 ایران و خاورمیانه', icon: '🇮🇷' },
                        { id: 'asia', label: '⛩️ آسیا و شرق دور', icon: '⛩️' },
                        { id: 'europe', label: '🇪🇺 اروپا', icon: '🇪🇺' },
                        { id: 'americas', label: '🌎 آمریکا و سایر', icon: '🌎' },
                      ].map((tab) => (
                        <button
                          key={tab.id}
                          onClick={() => setExchangeCategoryFilter(tab.id as any)}
                          className={`px-3 py-1.5 rounded-xl whitespace-nowrap text-[11px] font-bold transition-all flex items-center gap-1.5 ${
                            exchangeCategoryFilter === tab.id
                              ? 'bg-emerald-500 text-slate-950 shadow'
                              : 'bg-slate-950 text-slate-400 hover:text-white border border-slate-800'
                          }`}
                        >
                          <span>{tab.label}</span>
                        </button>
                      ))}
                    </div>

                    {/* Exchanges List */}
                    <div className="max-h-64 overflow-y-auto space-y-1.5 custom-scrollbar pr-1">
                      {filteredExchanges.map((ex) => (
                        <button
                          key={ex.id}
                          onClick={() => {
                            setSelectedExchange(ex);
                            setCryptoStep(2);
                          }}
                          className={`w-full p-3 rounded-2xl border text-right flex items-center justify-between transition-all ${
                            selectedExchange.id === ex.id
                              ? 'border-emerald-500 bg-emerald-500/10 text-white'
                              : 'border-slate-800 bg-slate-950 text-slate-300 hover:border-slate-700'
                          }`}
                        >
                          <div className="flex items-center gap-2.5">
                            <div className="h-8 w-8 rounded-xl bg-slate-900 border border-slate-700 flex items-center justify-center font-bold text-emerald-400">
                              {ex.name.charAt(0)}
                            </div>
                            <div>
                              <div className="flex items-center gap-2">
                                <span className="font-bold text-sm text-white">{ex.name}</span>
                                <span className="text-[10px] text-slate-400">{ex.countryBadge}</span>
                              </div>
                              <div className="text-[10px] text-slate-500">جفت‌ارز مبنا: {ex.defaultCounter} • موجودی: ~{ex.pairsCount}</div>
                            </div>
                          </div>
                          <span className="text-emerald-400 text-xs font-bold">انتخاب →</span>
                        </button>
                      ))}
                    </div>
                  </div>
                )}

                {/* Crypto Step 2: Select Pair & Manual Sync */}
                {cryptoStep === 2 && (
                  <div className="space-y-3 text-xs">
                    <div className="p-3 rounded-2xl bg-slate-950 border border-slate-800 flex items-center justify-between">
                      <div>
                        <span className="text-slate-400 text-[10px] block">صرافی انتخاب‌شده:</span>
                        <strong className="text-white text-xs font-bold">{selectedExchange.name}</strong>
                      </div>
                      <button
                        onClick={() => {
                          setIsSyncingPairs(true);
                          setTimeout(() => {
                            setIsSyncingPairs(false);
                            showToast(`لیست جفت‌ارزهای ${selectedExchange.name} به‌روزرسانی شد.`);
                          }, 500);
                        }}
                        disabled={isSyncingPairs}
                        className="px-2.5 py-1.5 rounded-xl bg-slate-800 hover:bg-slate-700 text-emerald-400 font-bold text-[11px] flex items-center gap-1.5 transition-all"
                      >
                        <RefreshCw className={`h-3 w-3 ${isSyncingPairs ? 'animate-spin' : ''}`} />
                        <span>{isSyncingPairs ? 'در حال بروزرسانی...' : '🔄 بروزرسانی لیست'}</span>
                      </button>
                    </div>

                    <input
                      type="text"
                      value={cryptoSearchQuery}
                      onChange={(e) => setCryptoSearchQuery(e.target.value)}
                      placeholder="جستجوی رمزارز (BTC, ETH, SOL, POL, S, RENDER, PEPE)..."
                      className="w-full bg-slate-950 border border-slate-800 rounded-xl px-3 py-2 text-white"
                    />

                    <div className="max-h-56 overflow-y-auto space-y-1.5 custom-scrollbar">
                      {selectedExchange.pairsList
                        .filter(sym => !cryptoSearchQuery || sym.toLowerCase().includes(cryptoSearchQuery.toLowerCase()))
                        .map((sym) => {
                          const meta = cryptoPrices[sym] || { nameFa: sym, currentPrice: 1.0, icon: 'https://cdn-icons-png.flaticon.com/512/2830/2830284.png' };
                          return (
                            <button
                              key={sym}
                              onClick={() => {
                                setSelectedCryptoCoin(sym);
                                setCryptoStep(3);
                              }}
                              className={`w-full p-2.5 rounded-2xl border text-right flex items-center justify-between transition-all ${
                                selectedCryptoCoin === sym
                                  ? 'border-emerald-500 bg-emerald-500/10 text-white'
                                  : 'border-slate-800 bg-slate-950 text-slate-300 hover:border-slate-700'
                              }`}
                            >
                              <div className="flex items-center gap-2.5">
                                <img src={meta.icon} alt={sym} className="h-7 w-7 rounded-full" />
                                <div>
                                  <div className="font-bold text-xs text-white">{meta.nameFa} ({sym}/{selectedExchange.defaultCounter})</div>
                                  <div className="text-[10px] text-slate-400 font-mono">
                                    ${meta.currentPrice < 1 ? meta.currentPrice.toFixed(6) : meta.currentPrice.toLocaleString()}
                                  </div>
                                </div>
                              </div>
                              <span className="text-emerald-400 text-xs font-bold">انتخاب →</span>
                            </button>
                          );
                        })}
                    </div>
                  </div>
                )}

                {/* Crypto Step 3: Frequency & Condition */}
                {cryptoStep === 3 && (
                  <form onSubmit={handleCreateCryptoSubmit} className="space-y-4 text-xs">
                    <div>
                      <label className="block text-slate-300 font-bold mb-1.5">
                        ۱. دوره بررسی قیمت (Check Frequency):
                      </label>
                      <div className="flex items-center gap-2">
                        <div className="flex-1 grid grid-cols-3 gap-1 bg-slate-950 p-1 rounded-xl border border-slate-800">
                          {[
                            { key: 'seconds', label: 'ثانیه' },
                            { key: 'minutes', label: 'دقیقه' },
                            { key: 'hours', label: 'ساعت' },
                          ].map((item) => (
                            <button
                              type="button"
                              key={item.key}
                              onClick={() => setUnitType(item.key as any)}
                              className={`py-1.5 rounded-lg text-center font-bold text-[11px] transition-all ${
                                unitType === item.key
                                  ? 'bg-emerald-500 text-slate-950 shadow'
                                  : 'text-slate-400 hover:text-white'
                              }`}
                            >
                              {item.label}
                            </button>
                          ))}
                        </div>

                        <div className="w-24">
                          <input
                            type="number"
                            min="1"
                            max="3600"
                            value={unitNumber}
                            onChange={(e) => setUnitNumber(e.target.value)}
                            placeholder="1"
                            className="w-full bg-slate-950 border border-slate-800 rounded-xl px-3 py-2 text-center text-white font-mono font-bold text-sm"
                          />
                        </div>
                      </div>

                      <div className="mt-1.5 px-3 py-1.5 rounded-xl bg-emerald-500/10 border border-emerald-500/20 text-emerald-400 text-[11px] font-semibold flex items-center gap-1.5">
                        <Timer className="h-3.5 w-3.5" />
                        <span>بررسی هر {formatCalculatedInterval(unitType, unitNumber)} انجام می‌شود.</span>
                      </div>
                    </div>

                    <div>
                      <label className="block text-slate-300 font-bold mb-1.5">۲. نوع شرط هشدار:</label>
                      <div className="grid grid-cols-2 gap-2">
                        <button
                          type="button"
                          onClick={() => setConditionType('PERCENT_CHANGE')}
                          className={`py-2 rounded-xl border text-center font-bold ${
                            conditionType === 'PERCENT_CHANGE'
                              ? 'border-emerald-500 bg-emerald-500/10 text-emerald-400'
                              : 'border-slate-800 bg-slate-950 text-slate-400'
                          }`}
                        >
                          درصد تغییر قیمت (%)
                        </button>
                        <button
                          type="button"
                          onClick={() => setConditionType('PRICE_THRESHOLD')}
                          className={`py-2 rounded-xl border text-center font-bold ${
                            conditionType === 'PRICE_THRESHOLD'
                              ? 'border-emerald-500 bg-emerald-500/10 text-emerald-400'
                              : 'border-slate-800 bg-slate-950 text-slate-400'
                          }`}
                        >
                          سقف / کف قیمت ($)
                        </button>
                      </div>
                    </div>

                    {conditionType === 'PERCENT_CHANGE' && (
                      <div className="space-y-2.5 p-3 rounded-2xl bg-slate-950 border border-slate-800">
                        <label className="block text-slate-400">جهت تغییر قیمت:</label>
                        <div className="grid grid-cols-3 gap-1.5">
                          <button
                            type="button"
                            onClick={() => setDirection('BOTH')}
                            className={`py-1.5 rounded-lg border font-bold text-[11px] ${
                              direction === 'BOTH' ? 'border-emerald-500 bg-emerald-500 text-slate-950' : 'border-slate-800 text-slate-400'
                            }`}
                          >
                            ± هر دو طرف
                          </button>
                          <button
                            type="button"
                            onClick={() => setDirection('ABOVE')}
                            className={`py-1.5 rounded-lg border font-bold text-[11px] ${
                              direction === 'ABOVE' ? 'border-emerald-500 bg-emerald-500 text-slate-950' : 'border-slate-800 text-slate-400'
                            }`}
                          >
                            ▲ فقط افزایش
                          </button>
                          <button
                            type="button"
                            onClick={() => setDirection('BELOW')}
                            className={`py-1.5 rounded-lg border font-bold text-[11px] ${
                              direction === 'BELOW' ? 'border-emerald-500 bg-emerald-500 text-slate-950' : 'border-slate-800 text-slate-400'
                            }`}
                          >
                            ▼ فقط کاهش
                          </button>
                        </div>

                        <div>
                          <label className="block text-slate-400 mb-1">درصد مد نظر برای هشدار (%):</label>
                          <input
                            type="number"
                            step="0.1"
                            value={targetValueStr}
                            onChange={(e) => setTargetValueStr(e.target.value)}
                            className="w-full bg-slate-900 border border-slate-700 rounded-xl px-3 py-2 text-white font-mono font-bold"
                            placeholder="مثال: 2.5"
                          />
                        </div>
                      </div>
                    )}

                    {conditionType === 'PRICE_THRESHOLD' && (
                      <div className="space-y-2.5 p-3 rounded-2xl bg-slate-950 border border-slate-800">
                        <div>
                          <label className="block text-slate-400 mb-1">قیمت هدف (دلار):</label>
                          <input
                            type="number"
                            step="0.01"
                            value={targetValueStr}
                            onChange={(e) => setTargetValueStr(e.target.value)}
                            className="w-full bg-slate-900 border border-slate-700 rounded-xl px-3 py-2 text-white font-mono font-bold"
                            placeholder="مثال: 95000"
                          />
                        </div>
                      </div>
                    )}

                    {/* Text-to-Speech (TTS) Voice Toggle */}
                    <div className="p-3 rounded-2xl bg-slate-950 border border-slate-800 space-y-2">
                      <div className="flex items-center justify-between">
                        <div className="flex items-center gap-2">
                          <Volume2 className={`h-4 w-4 ${ttsEnabled ? accentClass : 'text-slate-500'}`} />
                          <div>
                            <span className="font-bold text-xs text-white block">اعلام صوتی هوشمند (Text to Speech)</span>
                            <span className="text-[10px] text-slate-400 block">خوانش نام ارز و نرخ با صدای طبیعی هنگام وقوع هشدار</span>
                          </div>
                        </div>
                        <input
                          type="checkbox"
                          checked={ttsEnabled}
                          onChange={(e) => setTtsEnabled(e.target.checked)}
                          className="h-5 w-5 rounded border-slate-700 text-emerald-500 focus:ring-emerald-400 bg-slate-900 cursor-pointer"
                        />
                      </div>
                      {ttsEnabled && (
                        <div className="pt-1.5 flex justify-end">
                          <button
                            type="button"
                            onClick={() => testTtsSpeech(selectedCryptoCoin, cryptoPrices[selectedCryptoCoin]?.currentPrice || 83770)}
                            className="px-2.5 py-1 rounded-lg border border-slate-700 bg-slate-900 text-slate-300 text-[10px] font-semibold flex items-center gap-1.5 hover:text-white cursor-pointer"
                          >
                            <span>🗣️ تست نمونه صدای فارسی</span>
                          </button>
                        </div>
                      )}
                    </div>

                    <div className="flex items-center gap-2 pt-2">
                      <button
                        type="button"
                        onClick={() => setCryptoStep(2)}
                        className="px-4 py-3 rounded-2xl bg-slate-800 text-slate-300 font-bold"
                      >
                        بازگشت
                      </button>
                      <button
                        type="submit"
                        className="flex-1 py-3 rounded-2xl bg-emerald-500 hover:bg-emerald-400 text-slate-950 font-bold text-sm shadow-lg shadow-emerald-500/20 transition-all"
                      >
                        ذخیره و شروع بررسی هشدار کریپتو
                      </button>
                    </div>
                  </form>
                )}
              </div>
            )}

            {/* ======================================================== */}
            {/* PATH B: STOCKS, US BONDS & FOREX                         */}
            {/* ======================================================== */}
            {createPath === 'STOCKS_MACRO' && (
              <div className="space-y-4">
                <div className="flex items-center justify-between border-b border-slate-800 pb-2">
                  <div className="flex items-center gap-2">
                    <button
                      onClick={() => {
                        if (macroStep > 1) {
                          setMacroStep((macroStep - 1) as any);
                        } else {
                          setCreatePath('NONE');
                        }
                      }}
                      className="p-1 rounded-lg text-slate-400 hover:text-white bg-slate-800"
                    >
                      <ChevronLeft className="h-4 w-4 rotate-180" />
                    </button>
                    <div>
                      <span className="text-xs text-blue-400 font-semibold block">مرحله {macroStep} از ۲ (بازارهای جهانی و اوراق)</span>
                      <h4 className="font-bold text-sm text-white">
                        {macroStep === 1 && '۱. انتخاب دارایی (اوراق قرضه، فارکس، سهام یا طلا)'}
                        {macroStep === 2 && `۲. زمان‌بندی و شرط هشدار برای ${macroPrices[selectedMacroKey]?.nameFa}`}
                      </h4>
                    </div>
                  </div>
                </div>

                {/* Macro Step 1: Filter & Asset Cards */}
                {macroStep === 1 && (
                  <div className="space-y-3 text-xs">
                    <input
                      type="text"
                      value={macroSearchQuery}
                      onChange={(e) => setMacroSearchQuery(e.target.value)}
                      placeholder="جستجوی نماد (US10Y, EUR/USD, NVDA, طلا, S&P 500)..."
                      className="w-full bg-slate-950 border border-slate-800 rounded-xl px-3 py-2 text-white placeholder:text-slate-500"
                    />

                    {/* Filter Tabs */}
                    <div className="flex items-center gap-1.5 overflow-x-auto pb-1 custom-scrollbar">
                      {[
                        { id: 'all', label: 'همه دارایی‌ها', icon: '🌐' },
                        { id: 'bond', label: 'اوراق قرضه آمریکا (US10Y)', icon: '🏛️' },
                        { id: 'forex', label: 'جفت‌ارزهای فارکس', icon: '💱' },
                        { id: 'stock', label: 'سهام آمریکا (NASDAQ/NYSE)', icon: '📈' },
                        { id: 'commodity', label: 'طلا و نفت', icon: '🪙' },
                        { id: 'index', label: 'شاخص‌های کلان', icon: '📊' },
                      ].map((tab) => (
                        <button
                          key={tab.id}
                          onClick={() => setMacroCategoryFilter(tab.id as any)}
                          className={`px-3 py-1.5 rounded-xl whitespace-nowrap text-[11px] font-bold transition-all flex items-center gap-1.5 ${
                            macroCategoryFilter === tab.id
                              ? 'bg-blue-500 text-white shadow'
                              : 'bg-slate-950 text-slate-400 hover:text-white border border-slate-800'
                          }`}
                        >
                          <span>{tab.icon}</span>
                          <span>{tab.label}</span>
                        </button>
                      ))}
                    </div>

                    <div className="max-h-64 overflow-y-auto space-y-1.5 custom-scrollbar pr-1">
                      {filteredMacroAssets.map(([key, asset]) => (
                        <button
                          key={key}
                          onClick={() => {
                            setSelectedMacroKey(key);
                            setMacroStep(2);
                          }}
                          className={`w-full p-2.5 rounded-2xl border text-right flex items-center justify-between transition-all ${
                            selectedMacroKey === key
                              ? 'border-blue-500 bg-blue-500/10 text-white'
                              : 'border-slate-800 bg-slate-950 text-slate-300 hover:border-slate-700'
                          }`}
                        >
                          <div className="flex items-center gap-2.5">
                            <img
                              src={asset.icon}
                              alt={asset.name}
                              className="h-8 w-8 rounded-full object-cover bg-slate-800 border border-slate-700 p-0.5"
                              onError={(e) => {
                                (e.target as any).src = 'https://cdn-icons-png.flaticon.com/512/2830/2830284.png';
                              }}
                            />
                            <div>
                              <div className="flex items-center gap-2">
                                <span className="font-bold text-xs text-white">{asset.nameFa}</span>
                                <span className="text-[10px] font-mono text-slate-400">({asset.symbol})</span>
                              </div>
                              <div className="text-[10px] text-slate-400 mt-0.5 flex items-center gap-2">
                                <span className="text-blue-400 font-bold">{asset.marketName}</span>
                                <span>•</span>
                                <span className="font-mono font-bold text-slate-200">
                                  {asset.unit === '$' ? `$${asset.currentPrice.toLocaleString()}` : `${asset.currentPrice.toLocaleString()}${asset.unit}`}
                                </span>
                              </div>
                            </div>
                          </div>
                          <span className="text-blue-400 text-xs font-bold">انتخاب →</span>
                        </button>
                      ))}
                    </div>
                  </div>
                )}

                {/* Macro Step 2: Frequency & Condition */}
                {macroStep === 2 && (
                  <form onSubmit={handleCreateMacroSubmit} className="space-y-4 text-xs">
                    {(() => {
                      const meta = macroPrices[selectedMacroKey] || macroPrices.US10Y;
                      return (
                        <div className="p-3 rounded-2xl bg-slate-950 border border-slate-800 flex items-center justify-between">
                          <div className="flex items-center gap-2.5">
                            <img src={meta.icon} alt={meta.name} className="h-8 w-8 rounded-full" />
                            <div>
                              <span className="text-white text-xs font-bold">{meta.nameFa}</span>
                              <span className="text-[10px] text-slate-400 block font-mono">
                                نرخ مبنا: {meta.unit === '$' ? `$${meta.currentPrice.toLocaleString()}` : `${meta.currentPrice.toLocaleString()}${meta.unit}`} ({meta.marketName})
                              </span>
                            </div>
                          </div>
                          <button
                            type="button"
                            onClick={() => setMacroStep(1)}
                            className="text-blue-400 text-xs font-bold underline"
                          >
                            تغییر دارایی
                          </button>
                        </div>
                      );
                    })()}

                    <div>
                      <label className="block text-slate-300 font-bold mb-1.5">
                        ۱. دوره بررسی نرخ (Check Frequency):
                      </label>
                      <div className="flex items-center gap-2">
                        <div className="flex-1 grid grid-cols-3 gap-1 bg-slate-950 p-1 rounded-xl border border-slate-800">
                          {[
                            { key: 'seconds', label: 'ثانیه' },
                            { key: 'minutes', label: 'دقیقه' },
                            { key: 'hours', label: 'ساعت' },
                          ].map((item) => (
                            <button
                              type="button"
                              key={item.key}
                              onClick={() => setUnitType(item.key as any)}
                              className={`py-1.5 rounded-lg text-center font-bold text-[11px] transition-all ${
                                unitType === item.key
                                  ? 'bg-blue-500 text-white shadow'
                                  : 'text-slate-400 hover:text-white'
                              }`}
                            >
                              {item.label}
                            </button>
                          ))}
                        </div>

                        <div className="w-24">
                          <input
                            type="number"
                            min="1"
                            max="3600"
                            value={unitNumber}
                            onChange={(e) => setUnitNumber(e.target.value)}
                            placeholder="1"
                            className="w-full bg-slate-950 border border-slate-800 rounded-xl px-3 py-2 text-center text-white font-mono font-bold text-sm"
                          />
                        </div>
                      </div>

                      <div className="mt-1.5 px-3 py-1.5 rounded-xl bg-blue-500/10 border border-blue-500/20 text-blue-400 text-[11px] font-semibold flex items-center gap-1.5">
                        <Timer className="h-3.5 w-3.5" />
                        <span>بررسی هر {formatCalculatedInterval(unitType, unitNumber)} انجام می‌شود.</span>
                      </div>
                    </div>

                    <div>
                      <label className="block text-slate-300 font-bold mb-1.5">۲. نوع شرط هشدار:</label>
                      <div className="grid grid-cols-2 gap-2">
                        <button
                          type="button"
                          onClick={() => setConditionType('PERCENT_CHANGE')}
                          className={`py-2 rounded-xl border text-center font-bold ${
                            conditionType === 'PERCENT_CHANGE'
                              ? 'border-blue-500 bg-blue-500/10 text-blue-400'
                              : 'border-slate-800 bg-slate-950 text-slate-400'
                          }`}
                        >
                          درصد تغییر نرخ (%)
                        </button>
                        <button
                          type="button"
                          onClick={() => setConditionType('PRICE_THRESHOLD')}
                          className={`py-2 rounded-xl border text-center font-bold ${
                            conditionType === 'PRICE_THRESHOLD'
                              ? 'border-blue-500 bg-blue-500/10 text-blue-400'
                              : 'border-slate-800 bg-slate-950 text-slate-400'
                          }`}
                        >
                          سقف / کف نرخ
                        </button>
                      </div>
                    </div>

                    {conditionType === 'PERCENT_CHANGE' && (
                      <div className="space-y-2.5 p-3 rounded-2xl bg-slate-950 border border-slate-800">
                        <label className="block text-slate-400">جهت تغییر نرخ:</label>
                        <div className="grid grid-cols-3 gap-1.5">
                          <button
                            type="button"
                            onClick={() => setDirection('BOTH')}
                            className={`py-1.5 rounded-lg border font-bold text-[11px] ${
                              direction === 'BOTH' ? 'border-blue-500 bg-blue-500 text-white' : 'border-slate-800 text-slate-400'
                            }`}
                          >
                            ± هر دو طرف
                          </button>
                          <button
                            type="button"
                            onClick={() => setDirection('ABOVE')}
                            className={`py-1.5 rounded-lg border font-bold text-[11px] ${
                              direction === 'ABOVE' ? 'border-blue-500 bg-blue-500 text-white' : 'border-slate-800 text-slate-400'
                            }`}
                          >
                            ▲ فقط افزایش
                          </button>
                          <button
                            type="button"
                            onClick={() => setDirection('BELOW')}
                            className={`py-1.5 rounded-lg border font-bold text-[11px] ${
                              direction === 'BELOW' ? 'border-blue-500 bg-blue-500 text-white' : 'border-slate-800 text-slate-400'
                            }`}
                          >
                            ▼ فقط کاهش
                          </button>
                        </div>

                        <div>
                          <label className="block text-slate-400 mb-1">درصد مد نظر برای هشدار (%):</label>
                          <input
                            type="number"
                            step="0.1"
                            value={targetValueStr}
                            onChange={(e) => setTargetValueStr(e.target.value)}
                            className="w-full bg-slate-900 border border-slate-700 rounded-xl px-3 py-2 text-white font-mono font-bold"
                            placeholder="مثال: 1.0"
                          />
                        </div>
                      </div>
                    )}

                    {conditionType === 'PRICE_THRESHOLD' && (
                      <div className="space-y-2.5 p-3 rounded-2xl bg-slate-950 border border-slate-800">
                        <div>
                          <label className="block text-slate-400 mb-1">نرخ هدف:</label>
                          <input
                            type="number"
                            step="0.01"
                            value={targetValueStr}
                            onChange={(e) => setTargetValueStr(e.target.value)}
                            className="w-full bg-slate-900 border border-slate-700 rounded-xl px-3 py-2 text-white font-mono font-bold"
                            placeholder="مثال: 4.50"
                          />
                        </div>
                      </div>
                    )}

                    {/* Text-to-Speech (TTS) Voice Toggle */}
                    <div className="p-3 rounded-2xl bg-slate-950 border border-slate-800 space-y-2">
                      <div className="flex items-center justify-between">
                        <div className="flex items-center gap-2">
                          <Volume2 className={`h-4 w-4 ${ttsEnabled ? accentClass : 'text-slate-500'}`} />
                          <div>
                            <span className="font-bold text-xs text-white block">اعلام صوتی هوشمند (Text to Speech)</span>
                            <span className="text-[10px] text-slate-400 block">خوانش نام دارایی و نرخ با صدای طبیعی هنگام وقوع هشدار</span>
                          </div>
                        </div>
                        <input
                          type="checkbox"
                          checked={ttsEnabled}
                          onChange={(e) => setTtsEnabled(e.target.checked)}
                          className="h-5 w-5 rounded border-slate-700 text-blue-500 focus:ring-blue-400 bg-slate-900 cursor-pointer"
                        />
                      </div>
                      {ttsEnabled && (
                        <div className="pt-1.5 flex justify-end">
                          <button
                            type="button"
                            onClick={() => testTtsSpeech(selectedMacroKey, macroPrices[selectedMacroKey]?.currentPrice || 4.28)}
                            className="px-2.5 py-1 rounded-lg border border-slate-700 bg-slate-900 text-slate-300 text-[10px] font-semibold flex items-center gap-1.5 hover:text-white cursor-pointer"
                          >
                            <span>🗣️ تست نمونه صدای فارسی</span>
                          </button>
                        </div>
                      )}
                    </div>

                    <div className="flex items-center gap-2 pt-2">
                      <button
                        type="button"
                        onClick={() => setMacroStep(1)}
                        className="px-4 py-3 rounded-2xl bg-slate-800 text-slate-300 font-bold"
                      >
                        بازگشت
                      </button>
                      <button
                        type="submit"
                        className="flex-1 py-3 rounded-2xl bg-blue-600 hover:bg-blue-500 text-white font-bold text-sm shadow-lg shadow-blue-500/20 transition-all"
                      >
                        ذخیره و شروع بررسی هشدار
                      </button>
                    </div>
                  </form>
                )}
              </div>
            )}
          </div>
        </div>
      )}

      {/* 10 LANGUAGES PICKER MODAL */}
      {showLanguageModal && (
        <div className="fixed inset-0 z-50 bg-black/80 backdrop-blur-sm flex items-center justify-center p-4">
          <div className="bg-slate-900 border border-slate-800 rounded-3xl w-full max-w-md p-6 space-y-4 text-right shadow-2xl">
            <div className="flex items-center justify-between border-b border-slate-800 pb-3">
              <div className="flex items-center gap-2">
                <Languages className="h-5 w-5 text-emerald-400" />
                <h3 className="text-base font-bold text-white">انتخاب زبان برنامه (Language)</h3>
              </div>
              <button
                onClick={() => setShowLanguageModal(false)}
                className="p-1.5 rounded-full text-slate-400 hover:text-white bg-slate-800"
              >
                <X className="h-4 w-4" />
              </button>
            </div>

            <div className="max-h-80 overflow-y-auto space-y-1.5 custom-scrollbar pr-1">
              {SUPPORTED_LANGUAGES.map((lang) => (
                <button
                  key={lang.code}
                  onClick={() => {
                    setCurrentLang(lang.code);
                    setShowLanguageModal(false);
                    showToast(`زبان به ${lang.name} تغییر یافت.`);
                  }}
                  className={`w-full p-3 rounded-2xl border text-right flex items-center justify-between transition-all ${
                    currentLang === lang.code
                      ? 'border-emerald-500 bg-emerald-500/10 text-white'
                      : 'border-slate-800 bg-slate-950 text-slate-300 hover:border-slate-700'
                  }`}
                >
                  <div className="flex items-center gap-3">
                    <span className="text-2xl">{lang.flag}</span>
                    <div>
                      <span className="font-bold text-sm text-white block">{lang.name}</span>
                      <span className="text-[10px] text-slate-400">{lang.nameEn}</span>
                    </div>
                  </div>
                  {currentLang === lang.code && <Check className="h-4 w-4 text-emerald-400" />}
                </button>
              ))}
            </div>
          </div>
        </div>
      )}

      {/* RESTORE JSON MODAL */}
      {showRestoreModal && (
        <div className="fixed inset-0 z-50 bg-black/80 backdrop-blur-sm flex items-center justify-center p-4">
          <div className="bg-slate-900 border border-slate-800 rounded-3xl w-full max-w-md p-6 space-y-4 text-right shadow-2xl">
            <h3 className="text-base font-bold text-white">بازیابی هشدارها از فایل JSON</h3>
            <p className="text-xs text-slate-400">متن خروجی بک‌آپ JSON را در کادر زیر قرار دهید:</p>
            <textarea
              rows={5}
              value={restoreJsonInput}
              onChange={(e) => setRestoreJsonInput(e.target.value)}
              placeholder="[{ ... }]"
              className="w-full bg-slate-950 border border-slate-800 rounded-xl p-3 font-mono text-xs text-white"
            />
            <div className="flex items-center gap-2 pt-2">
              <button
                onClick={() => setShowRestoreModal(false)}
                className="px-4 py-2.5 rounded-xl bg-slate-800 text-slate-300 font-bold text-xs"
              >
                انصراف
              </button>
              <button
                onClick={handleRestoreBackup}
                className="flex-1 py-2.5 rounded-xl bg-emerald-500 text-slate-950 font-bold text-xs"
              >
                تأیید و بازیابی
              </button>
            </div>
          </div>
        </div>
      )}

      {/* HOME SCREEN WIDGET PREVIEW MODAL */}
      {showHomeWidgetModal && (
        <div className="fixed inset-0 z-50 bg-black/80 backdrop-blur-sm flex items-center justify-center p-4">
          <div className="bg-slate-900 border border-slate-800 rounded-3xl w-full max-w-lg p-6 space-y-4 text-right shadow-2xl">
            <div className="flex items-center justify-between border-b border-slate-800 pb-3">
              <div className="flex items-center gap-2">
                <div className="p-2 rounded-xl bg-violet-500/20 text-violet-400">
                  <LayoutGrid className="h-5 w-5" />
                </div>
                <div>
                  <h3 className="text-base font-bold text-white">پیش‌نمایش ویجت صفحه اصلی</h3>
                  <span className="text-[11px] text-slate-400 font-mono">Android & iOS 24/7 Home Widget</span>
                </div>
              </div>
              <button
                onClick={() => setShowHomeWidgetModal(false)}
                className="p-1 rounded-xl bg-slate-800 text-slate-400 hover:text-white"
              >
                <X className="h-5 w-5" />
              </button>
            </div>

            <p className="text-xs text-slate-300 leading-relaxed">
              این ویجت هوشمند را می‌توانید به صفحه اصلی گوشی (Homescreen) خود اضافه کنید تا بدون باز کردن برنامه، آخرین نوسانات بازار و وضعیت هشدارهای فعال را به صورت زنده رصد فرمایید:
            </p>

            {/* Widget Simulated Container */}
            <div className="p-4 rounded-3xl bg-slate-950 border-2 border-violet-500/30 shadow-xl space-y-3">
              <div className="flex items-center justify-between border-b border-slate-800 pb-2">
                <div className="flex items-center gap-2">
                  <span className="h-2 w-2 rounded-full bg-emerald-400 animate-pulse" />
                  <span className="font-bold text-xs text-white">⚡ ALARMER • مانیتور زنده</span>
                </div>
                <div className="flex items-center gap-2 text-[10px] text-slate-400">
                  <span className="font-mono">{new Date().toLocaleTimeString('fa-IR', { hour: '2-digit', minute: '2-digit' })}</span>
                  <button
                    onClick={() => {
                      rules.forEach((r) => evaluateRule(r));
                      showToast('بروزرسانی تمام قیمت‌های ویجت انجام شد.');
                    }}
                    className="p-1 rounded-lg bg-slate-800 text-slate-300 hover:text-white"
                    title="بروزرسانی زنده"
                  >
                    <RefreshCw className="h-3 w-3" />
                  </button>
                </div>
              </div>

              <div className="space-y-2 max-h-60 overflow-y-auto custom-scrollbar">
                {rules.map((rule) => {
                  const currentPrice = rule.lastCheckedPrice || rule.basePrice;
                  let targetProximity = 50;
                  if (rule.conditionType === 'PRICE_THRESHOLD' && rule.targetValue > 0) {
                    targetProximity = Math.min(100, Math.round((currentPrice / rule.targetValue) * 100));
                  } else if (rule.conditionType === 'PERCENT_CHANGE') {
                    const deltaPct = Math.abs(((currentPrice - rule.basePrice) / rule.basePrice) * 100);
                    targetProximity = Math.min(100, Math.round((deltaPct / rule.targetValue) * 100));
                  }

                  const isNearTarget = targetProximity >= 90;
                  const isTriggered = rule.isTriggered;

                  return (
                    <div
                      key={rule.uuid}
                      className="p-2.5 rounded-xl bg-slate-900 border border-slate-800/80 flex items-center justify-between text-xs"
                    >
                      <div className="space-y-0.5">
                        <div className="flex items-center gap-1.5">
                          <span className="font-bold text-white">{rule.marketSymbol}</span>
                          <span className="text-[9px] px-1 rounded bg-slate-800 text-slate-400">{rule.exchangeName}</span>
                          {rule.ttsEnabled && <Volume2 className="h-3 w-3 text-violet-400" />}
                        </div>
                        <div className="text-[10px] text-slate-400 flex items-center gap-1">
                          <span>هدف: {rule.conditionType === 'PRICE_THRESHOLD' ? `$${rule.targetValue}` : `${rule.targetValue}%`}</span>
                          <span>•</span>
                          <span className={isTriggered ? 'text-rose-400 font-bold' : isNearTarget ? 'text-amber-400 font-bold' : 'text-emerald-400'}>
                            {targetProximity}% تا هدف
                          </span>
                        </div>
                      </div>

                      <div className="text-right">
                        <span className="font-mono font-bold text-white block">${currentPrice.toLocaleString()}</span>
                        <button
                          onClick={() => evaluateRule(rule, 1.5)}
                          className="text-[10px] text-emerald-400 hover:underline cursor-pointer"
                        >
                          تست آلارم
                        </button>
                      </div>
                    </div>
                  );
                })}
              </div>
            </div>

            <div className="flex justify-end pt-1">
              <button
                onClick={() => setShowHomeWidgetModal(false)}
                className="px-5 py-2.5 rounded-xl bg-violet-600 hover:bg-violet-500 text-white font-bold text-xs"
              >
                بستن پنجره
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
