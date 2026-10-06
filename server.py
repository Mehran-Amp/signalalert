#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
SignalAlert Enterprise Engine v2.6.0
High-Performance, Multi-Source Async Real-Time Alert Engine for Crypto, Forex, Macro & Iran Markets.
Features:
 - Async Non-Blocking Architecture with Persistent HTTP Connection Pooling
 - In-Memory Intelligent Price Cache (2s TTL) for 80%+ Reduction in External API Load
 - Thread/Task-Safe Alert DB with Asynchronous Lock & Atomic Disk Flush
 - Unified Multi-Exchange Price Resolver (Nobitex, Tabdeal, Wallex, Bitpin, Binance, MEXC, Yahoo Finance, etc.)
 - Multi-Channel Notification Dispatcher (FCM High-Priority Data Push, Telegram Bot, Webhooks)
 - Modern FastAPI Lifespan Context Manager & Real-Time /status Dashboard
"""

import os
import time
import uuid
import json
import asyncio
import ipaddress
import html
import hmac
import math
import re
import socket
from urllib.parse import urlparse
from datetime import datetime, timedelta, timezone
from typing import List, Optional, Dict, Any, Tuple
from contextlib import asynccontextmanager

from fastapi import FastAPI, HTTPException, Depends, Header
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import HTMLResponse
from pydantic import BaseModel
from apscheduler.schedulers.asyncio import AsyncIOScheduler
import httpx
import firebase_admin
from firebase_admin import credentials, messaging
from firebase_admin import exceptions as fb_exceptions

APP_VERSION = "2.6.0"

# -------------------------------------------------------------------
# 0. Security Configuration, Auth Dependencies & Validation Helpers
# -------------------------------------------------------------------
API_KEY = os.getenv("API_KEY", "").strip()          # shared key the mobile app sends as X-API-Key
ADMIN_KEY = os.getenv("ADMIN_KEY", "").strip()      # operator key: /status, /debug/*, /test/push
CORS_ORIGINS = [o.strip() for o in os.getenv("CORS_ORIGINS", "").split(",") if o.strip()]

SYMBOL_RE = re.compile(r'^[A-Za-z0-9^.=_/\-]{1,32}$')
EXCHANGE_RE = re.compile(r'^[a-z0-9_.\-]{1,32}$')
CHAT_ID_RE = re.compile(r'^(-?\d{1,20}|@[A-Za-z0-9_]{3,64})$')
MAX_ALERTS_PER_USER = 200
MAX_NOTE_LEN = 500
MAX_WEBHOOK_LEN = 500

def _key_matches(provided: Optional[str], expected: str) -> bool:
    return bool(provided) and bool(expected) and hmac.compare_digest(provided.encode("utf-8"), expected.encode("utf-8"))

async def require_api_key(x_api_key: Optional[str] = Header(None)):
    if not API_KEY:
        raise HTTPException(status_code=503, detail="API key is not configured on the server.")
    if not (_key_matches(x_api_key, API_KEY) or _key_matches(x_api_key, ADMIN_KEY)):
        raise HTTPException(status_code=401, detail="Invalid or missing API key.")

async def require_admin(x_admin_key: Optional[str] = Header(None), admin_key: Optional[str] = None):
    if not ADMIN_KEY:
        raise HTTPException(status_code=503, detail="Admin key is not configured on the server.")
    if not (_key_matches(x_admin_key, ADMIN_KEY) or _key_matches(admin_key, ADMIN_KEY)):
        raise HTTPException(status_code=401, detail="Invalid or missing admin key.")

API_DEP = [Depends(require_api_key)]
ADMIN_DEP = [Depends(require_admin)]

def _scrub(value: Any) -> str:
    text = str(value)
    return text.replace(TELEGRAM_BOT_TOKEN, "***") if TELEGRAM_BOT_TOKEN else text

def _clamp_interval(value: Any) -> int:
    try:
        v = int(value)
    except (TypeError, ValueError):
        v = 180
    return max(180, min(86400, v))

def _validate_market_args(exchange: str, symbol: str) -> None:
    if not EXCHANGE_RE.match((exchange or '').lower()) or not SYMBOL_RE.match(symbol or ''):
        raise HTTPException(status_code=400, detail="Invalid exchange or symbol.")

def _normalize_sync_item(item: Any) -> Dict[str, Any]:
    if not isinstance(item, dict):
        raise ValueError("alert item must be an object")
    out = dict(item)
    out['exchange'] = str(item.get('exchange') or 'nobitex').strip().lower()
    out['symbol'] = str(item.get('symbol') or 'USDTIRT').strip().upper()
    if not EXCHANGE_RE.match(out['exchange']) or not SYMBOL_RE.match(out['symbol']):
        raise ValueError("invalid exchange or symbol")
    tp = float(item.get('target_price', 0.0))
    if not math.isfinite(tp):
        raise ValueError("invalid target_price")
    out['target_price'] = tp
    out['condition'] = str(item.get('condition') or 'ABOVE').strip().upper()
    out['check_interval_seconds'] = _clamp_interval(item.get('check_interval_seconds', 180))
    note = item.get('note')
    out['note'] = str(note)[:MAX_NOTE_LEN] if note is not None else None
    for k in ('id', 'created_at', 'sound', 'trigger_mode', 'alert_nature'):
        if item.get(k) is not None:
            out[k] = str(item[k])[:128]
    chat = item.get('telegram_chat_id')
    if chat is not None and str(chat).strip():
        chat = str(chat).strip()
        if not CHAT_ID_RE.match(chat):
            raise ValueError("invalid telegram_chat_id")
        out['telegram_chat_id'] = chat
    else:
        out['telegram_chat_id'] = None
    return out

# -------------------------------------------------------------------
# 1. Firebase Initialization (Robust Multi-Source Key Loader)
# -------------------------------------------------------------------
SERVICE_ACCOUNT_FILE = "serviceAccountKey.json"
firebase_initialized = False

TELEGRAM_BOT_TOKEN = os.getenv("TELEGRAM_BOT_TOKEN", "").strip()
TELEGRAM_BOT_METADATA: Dict[str, Any] = {
    "username": "aisocialfeedbot",
    "first_name": "AiSFeed",
    "id": 8597547058,
    "is_connected": False
}

if os.path.exists(SERVICE_ACCOUNT_FILE):
    try:
        cred = credentials.Certificate(SERVICE_ACCOUNT_FILE)
        firebase_admin.initialize_app(cred)
        firebase_initialized = True
        print("✅ [Firebase] Connected successfully from local serviceAccountKey.json.")
    except Exception as e:
        print(f"⚠️ [Firebase] Local key init note: {e}")
elif os.getenv("FIREBASE_SERVICE_ACCOUNT"):
    try:
        cred_dict = json.loads(os.getenv("FIREBASE_SERVICE_ACCOUNT"))
        cred = credentials.Certificate(cred_dict)
        firebase_admin.initialize_app(cred)
        firebase_initialized = True
        print("✅ [Firebase] Connected successfully from environment variable.")
    except Exception as e:
        print(f"⚠️ [Firebase] Env key init note: {e}")
else:
    print(f"ℹ️ [Firebase] '{SERVICE_ACCOUNT_FILE}' not found (git-ignored). Place key file for mobile push.")

# -------------------------------------------------------------------
# 2. Global Persistent HTTP Client & Connection Pooling
# -------------------------------------------------------------------
http_client: Optional[httpx.AsyncClient] = None
scheduler = AsyncIOScheduler()
_db_lock = asyncio.Lock()

# Price In-Memory Cache: key -> (price, timestamp)
PRICE_CACHE: Dict[str, Tuple[float, float]] = {}
CACHE_TTL_SECONDS = 2.0

# Diagnostic Log Ring Buffer (Max 100 entries)
RECENT_DIAGNOSTICS: List[Dict[str, Any]] = []

# Global Engine Metrics
METRICS = {
    "start_time": time.time(),
    "total_checks": 0,
    "cache_hits": 0,
    "cache_misses": 0,
    "total_triggers": 0,
    "fcm_success": 0,
    "fcm_failed": 0,
    "telegram_sent": 0,
    "webhook_sent": 0
}

# -------------------------------------------------------------------
# 3. Data Models (Pydantic V2/V1 Backward Compatible)
# -------------------------------------------------------------------
class AlertCreate(BaseModel):
    id: Optional[str] = None
    user_id: str
    exchange: str            # e.g. 'nobitex', 'wallex', 'tabdeal', 'binance', 'stocks'
    symbol: str              # e.g. 'BTCUSDT', 'USDTIRT', 'GOLD', 'DX-Y.NYB'
    target_price: float
    condition: str           # 'ABOVE' or 'BELOW'
    fcm_token: str
    check_interval_seconds: int = 180
    note: Optional[str] = None
    trigger_mode: Optional[str] = "oneShot" # 'oneShot' | 'recurring'
    alert_nature: Optional[str] = "price"    # 'price' | 'timer'
    sound_enabled: bool = True
    vibration_enabled: bool = True
    tts_enabled: bool = True
    sound: Optional[str] = "alarm_siren"
    telegram_chat_id: Optional[str] = None
    webhook_url: Optional[str] = None

class Alert(AlertCreate):
    id: str
    is_active: bool = True
    created_at: str
    last_checked_at: float = 0.0
    last_triggered_at: float = 0.0

class AlertPublic(BaseModel):
    # Same as Alert but WITHOUT fcm_token (never returned to API clients)
    id: str
    user_id: str
    exchange: str
    symbol: str
    target_price: float
    condition: str
    check_interval_seconds: int = 180
    note: Optional[str] = None
    trigger_mode: Optional[str] = "oneShot"
    alert_nature: Optional[str] = "price"
    sound_enabled: bool = True
    vibration_enabled: bool = True
    tts_enabled: bool = True
    sound: Optional[str] = "alarm_siren"
    telegram_chat_id: Optional[str] = None
    webhook_url: Optional[str] = None
    is_active: bool = True
    created_at: str
    last_checked_at: float = 0.0
    last_triggered_at: float = 0.0

DB_FILE = "alerts_data.json"

def load_alerts_from_disk() -> List[Alert]:
    if os.path.exists(DB_FILE):
        try:
            with open(DB_FILE, "r", encoding="utf-8") as f:
                data = json.load(f)
                return [Alert(**item) for item in data]
        except Exception as e:
            print(f"⚠️ Error loading alerts disk DB: {e}")
    return []

async def save_alerts_to_disk_async(alerts: List[Alert]):
    """Atomic asynchronous disk writer to prevent file corruption during power/server events"""
    async with _db_lock:
        try:
            loop = asyncio.get_running_loop()
            data = [a.model_dump() if hasattr(a, 'model_dump') else a.dict() for a in alerts]
            json_str = json.dumps(data, ensure_ascii=False, indent=2)

            def _write():
                tmp_file = f"{DB_FILE}.tmp"
                with open(tmp_file, "w", encoding="utf-8") as f:
                    f.write(json_str)
                    f.flush()
                    os.fsync(f.fileno())
                os.replace(tmp_file, DB_FILE)

            await loop.run_in_executor(None, _write)
        except Exception as e:
            print(f"⚠️ Error saving alerts disk DB: {e}")

ALERTS_DB: List[Alert] = load_alerts_from_disk()

# -------------------------------------------------------------------
# 4. FastAPI Lifespan Context Manager (Modern Startup & Shutdown)
# -------------------------------------------------------------------
@asynccontextmanager
async def lifespan(app: FastAPI):
    global http_client
    # Startup: Initialize persistent HTTP connection pool
    limits = httpx.Limits(max_keepalive_connections=50, max_connections=100)
    timeout = httpx.Timeout(5.0, connect=3.0)
    http_client = httpx.AsyncClient(limits=limits, timeout=timeout)
    if not API_KEY:
        print("🚨 [Security] API_KEY is not set: all /api endpoints will answer 503 until it is configured.")
    if not ADMIN_KEY:
        print("🚨 [Security] ADMIN_KEY is not set: /status, /debug/* and /test/push are disabled.")

    # Initialize Telegram Bot & launch polling worker
    await init_telegram_bot(http_client)
    tg_task = asyncio.create_task(telegram_bot_polling_loop())

    scheduler.add_job(
        check_alerts_job,
        'interval',
        seconds=2,
        max_instances=1,
        coalesce=True,
        misfire_grace_time=15
    )
    scheduler.start()
    print("🚀 [SignalAlert Engine] Online (2s High-Performance Async Scheduler, Telegram Bot & Connection Pool Ready).")

    yield

    # Shutdown: Cleanly close pool and scheduler
    tg_task.cancel()
    scheduler.shutdown(wait=False)
    if http_client:
        await http_client.aclose()
    print("🛑 [SignalAlert Engine] Gracefully stopped.")

app = FastAPI(
    title="SignalAlert Production Engine",
    version=APP_VERSION,
    lifespan=lifespan
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=CORS_ORIGINS,
    allow_credentials=False,
    allow_methods=["GET", "POST", "DELETE"],
    allow_headers=["X-API-Key", "X-Admin-Key", "Content-Type"],
)

BULK_MARKET_RESPONSE_CACHE: Dict[str, Tuple[Any, float]] = {}

# -------------------------------------------------------------------
# 5. Unified High-Performance Multi-Exchange Price Resolver
# -------------------------------------------------------------------
def normalize_symbol(symbol: str) -> str:
    return (symbol or '').upper().replace('/', '').replace(' ', '').replace('-', '').replace('_', '')

async def fetch_price_with_trace(
    client: httpx.AsyncClient,
    exchange: str,
    symbol: str,
    collect_all_traces: bool = False
) -> Tuple[Optional[float], List[Dict[str, Any]]]:
    """
    Unified multi-source price engine with Bulk Ticker Cache & Fast Parallel Fallback.
    - Fast Mode (collect_all_traces=False): Returns on first valid price immediately.
    - Diagnostic Mode (collect_all_traces=True): Tests all sources, collecting latency & trace stats.
    """
    ex = (exchange or '').lower()
    sym_clean = normalize_symbol(symbol)
    traces: List[Dict[str, Any]] = []
    final_price: Optional[float] = None

    # Helper function for tracing with Bulk Response Caching
    async def _try_fetch(source_name: str, url: str, extractor_func, headers=None) -> Optional[float]:
        nonlocal final_price
        t0 = time.time()
        now = time.time()

        # Check Bulk Response Cache (3 second TTL for full-market endpoints)
        cached_bulk = BULK_MARKET_RESPONSE_CACHE.get(url)
        if cached_bulk and (now - cached_bulk[1]) < 3.0:
            try:
                price = extractor_func(cached_bulk[0])
                if price and float(price) > 0:
                    val = float(price)
                    traces.append({'source': source_name, 'url': url, 'status_code': 200, 'latency_ms': 0.1, 'parsed_price': val, 'success': True, 'cached_bulk': True})
                    if final_price is None:
                        final_price = val
                    return val
            except Exception:
                pass

        req_headers = {'User-Agent': f'Mozilla/5.0 (Windows NT 10.0; Win64; x64) SignalAlert/{APP_VERSION}'}
        if headers:
            req_headers.update(headers)
        try:
            res = await client.get(url, headers=req_headers, timeout=3.5)
            latency = round((time.time() - t0) * 1000, 2)
            if res.status_code == 200:
                data = res.json()
                BULK_MARKET_RESPONSE_CACHE[url] = (data, now)
                price = extractor_func(data)
                if price and float(price) > 0:
                    val = float(price)
                    traces.append({'source': source_name, 'url': url, 'status_code': 200, 'latency_ms': latency, 'parsed_price': val, 'success': True})
                    if final_price is None:
                        final_price = val
                    return val
                else:
                    traces.append({'source': source_name, 'url': url, 'status_code': 200, 'latency_ms': latency, 'error': 'Symbol not found or 0 price', 'success': False})
            else:
                traces.append({'source': source_name, 'url': url, 'status_code': res.status_code, 'latency_ms': latency, 'error': f'HTTP {res.status_code}', 'success': False})
        except Exception as e:
            traces.append({'source': source_name, 'url': url, 'status_code': 0, 'latency_ms': round((time.time() - t0) * 1000, 2), 'error': str(e), 'success': False})
        return None

    # -------------------------------------------------------------
    # 1. IRANIAN EXCHANGES & TOMAN MARKETS
    # -------------------------------------------------------------
    is_iranian = ex in ['tabdeal', 'nobitex', 'wallex', 'bitpin', 'tetherland', 'abantether', 'ramzinex', 'bitbarg', 'sarmayex', 'exir', 'iran_market'] or \
                 sym_clean.endswith('TMN') or sym_clean.endswith('IRT') or sym_clean.endswith('RLS')

    if is_iranian:
        nobitex_sym = 'USDTIRT' if sym_clean in ['USDTTMN', 'USDTIRT', 'USDT'] else (sym_clean[:-3] + 'IRT' if sym_clean.endswith('TMN') else sym_clean)
        matching_keys = [sym_clean, nobitex_sym]
        if sym_clean in ['USDT', 'USDTTMN', 'USDTIRT']:
            matching_keys.extend(['USDTTMN', 'USDTIRT', 'USDT_IRT', 'USDT_TMN'])

        # 1a. Tabdeal
        def _extract_tabdeal(data):
            if isinstance(data, dict):
                for k, v in data.items():
                    if normalize_symbol(k) in matching_keys:
                        if isinstance(v, dict):
                            p = v.get('price') or v.get('last_price')
                            if p and float(p) > 0:
                                val = float(p)
                                return val / 10.0 if (val > 500000 and 'USDT' in sym_clean) else val
            return None

        p = await _try_fetch('Tabdeal Spot API', 'https://api.tabdeal.org/r/plots/market/information', _extract_tabdeal)
        if p and not collect_all_traces: return p, traces

        # 1b. Nobitex Orderbook (.net then .ir)
        for domain, label in [('api.nobitex.net', 'Nobitex Global Net'), ('api.nobitex.ir', 'Nobitex Local IR')]:
            def _extract_nobitex_ob(data):
                if isinstance(data, dict) and 'bids' in data and len(data['bids']) > 0:
                    val = float(data['bids'][0][0])
                    return val / 10.0 if (val > 500000 and 'USDT' in sym_clean) else val
                return None
            p = await _try_fetch(f'{label} Orderbook', f'https://{domain}/v2/orderbook/{nobitex_sym}', _extract_nobitex_ob)
            if p and not collect_all_traces: return p, traces

        # 1c. Bitpin
        def _extract_bitpin(data):
            if isinstance(data, dict):
                for m in data.get('results', []):
                    if normalize_symbol(m.get('code', '')) in matching_keys:
                        val = float(m.get('price', 0))
                        return val / 10.0 if (val > 500000 and 'USDT' in sym_clean) else val
            return None

        p = await _try_fetch('Bitpin Markets API', 'https://api.bitpin.org/v1/mkt/markets/', _extract_bitpin)
        if p and not collect_all_traces: return p, traces

        # 1d. Wallex
        def _extract_wallex(data):
            if isinstance(data, dict):
                symbols = data.get('result', {}).get('symbols', {})
                for k, v in symbols.items():
                    if normalize_symbol(k) == sym_clean:
                        return v.get('stats', {}).get('lastPrice')
            return None

        p = await _try_fetch('Wallex Markets API', 'https://api.wallex.ir/v1/markets', _extract_wallex)
        if p and not collect_all_traces: return p, traces

        # 1e. Tetherland (For USDT/TMN direct)
        if sym_clean in ['USDTTMN', 'USDTIRT', 'USDT']:
            def _extract_tetherland(data):
                if isinstance(data, dict):
                    usdt_info = data.get('data', {}).get('currencies', {}).get('USDT', {})
                    return usdt_info.get('price') or usdt_info.get('last_price')
                return None

            p = await _try_fetch('Tetherland API', 'https://api.tetherland.com/currencies', _extract_tetherland)
            if p and not collect_all_traces: return p, traces

    # -------------------------------------------------------------
    # 2. GLOBAL MACRO / FOREX / US BONDS / STOCKS (Yahoo Finance)
    # -------------------------------------------------------------
    elif ex in ['global_stocks', 'stocks', 'macro', 'forex', 'bonds', 'wallstreet'] or any(k in sym_clean for k in ['DXY', 'US10Y', 'TNX', 'EURUSD', 'GBPUSD', 'USDJPY', 'GOLD', 'XAU', 'NYB']):
        yf_symbol = symbol.upper().replace(' ', '')
        if 'DX-Y' in yf_symbol or 'DXY' in yf_symbol: yf_symbol = 'DX-Y.NYB'
        elif 'US10Y' in yf_symbol or '10Y' in yf_symbol or 'TNX' in yf_symbol: yf_symbol = '^TNX'
        elif 'EURUSD' in sym_clean: yf_symbol = 'EURUSD=X'
        elif 'GBPUSD' in sym_clean: yf_symbol = 'GBPUSD=X'
        elif 'USDJPY' in sym_clean: yf_symbol = 'USDJPY=X'
        elif 'GOLD' in sym_clean or 'XAU' in sym_clean: yf_symbol = 'GC=F'

        def _extract_yf(data):
            if isinstance(data, dict):
                chart = data.get('chart', {}).get('result', [])
                if chart and isinstance(chart, list) and len(chart) > 0:
                    return chart[0].get('meta', {}).get('regularMarketPrice')
            return None

        p = await _try_fetch('Yahoo Finance API', f'https://query1.finance.yahoo.com/v8/finance/chart/{yf_symbol}?interval=1m&range=1d', _extract_yf)
        if p and not collect_all_traces: return p, traces

    # -------------------------------------------------------------
    # 3. GLOBAL CRYPTO (Binance, MEXC, KuCoin, Gate.io, CoinEx)
    # -------------------------------------------------------------
    else:
        crypto_sym = sym_clean
        if not any(crypto_sym.endswith(q) for q in ['USDT', 'BUSD', 'USDC', 'BTC', 'ETH', 'EUR', 'USD']):
            crypto_sym = crypto_sym + 'USDT'

        # 3a. Binance
        p = await _try_fetch('Binance Spot API', f'https://api.binance.com/api/v3/ticker/price?symbol={crypto_sym}', lambda d: d.get('price') if isinstance(d, dict) else None)
        if p and not collect_all_traces: return p, traces

        # 3b. MEXC
        p = await _try_fetch('MEXC Spot API', f'https://api.mexc.com/api/v3/ticker/price?symbol={crypto_sym}', lambda d: d.get('price') if isinstance(d, dict) else None)
        if p and not collect_all_traces: return p, traces

        # 3c. KuCoin
        kucoin_sym = f"{crypto_sym[:-4]}-USDT" if crypto_sym.endswith('USDT') else crypto_sym
        p = await _try_fetch('KuCoin Spot API', f'https://api.kucoin.com/api/v1/market/orderbook/level1?symbol={kucoin_sym}', lambda d: d.get('data', {}).get('price') if isinstance(d, dict) else None)
        if p and not collect_all_traces: return p, traces

        # 3d. Gate.io
        gate_sym = f"{crypto_sym[:-4]}_USDT" if crypto_sym.endswith('USDT') else crypto_sym
        p = await _try_fetch('Gate.io Spot API', f'https://api.gateio.ws/api/v4/spot/tickers?currency_pair={gate_sym}', lambda d: d[0].get('last') if isinstance(d, list) and len(d) > 0 else None)
        if p and not collect_all_traces: return p, traces

        # 3e. CoinEx
        p = await _try_fetch('CoinEx Spot API', f'https://api.coinex.com/v1/market/ticker?market={crypto_sym}', lambda d: d.get('data', {}).get('ticker', {}).get('last') if isinstance(d, dict) else None)
        if p and not collect_all_traces: return p, traces

    return final_price, traces

OUTLIER_STREAK: Dict[str, int] = {}

async def get_cached_price(client: httpx.AsyncClient, exchange: str, symbol: str) -> Optional[float]:
    """Fetches price with in-memory TTL caching and Outlier Protection filter"""
    now = time.time()
    cache_key = f"{exchange.lower()}:{normalize_symbol(symbol)}"

    cached = PRICE_CACHE.get(cache_key)
    if cached and (now - cached[1]) < CACHE_TTL_SECONDS:
        METRICS["cache_hits"] += 1
        return cached[0]

    METRICS["cache_misses"] += 1
    price, _ = await fetch_price_with_trace(client, exchange, symbol, collect_all_traces=False)
    if price is not None and price > 0:
        # Outlier Protection: suspicious 50%+ jumps must be confirmed 3 times in a row before acceptance
        if cached and cached[0] > 0 and (now - cached[1]) < 300:
            last_p = cached[0]
            dev = abs(price - last_p) / last_p
            if dev > 0.50 and last_p > 1.0:
                streak = OUTLIER_STREAK.get(cache_key, 0) + 1
                if streak < 3:
                    OUTLIER_STREAK[cache_key] = streak
                    print(f"⚠️ [Outlier Filter] {cache_key}: {last_p} -> {price} ({dev*100:.1f}%), confirm {streak}/3")
                    return cached[0]

        OUTLIER_STREAK.pop(cache_key, None)
        PRICE_CACHE[cache_key] = (price, now)
        return price
    return None

# -------------------------------------------------------------------
# 6. Multi-Channel Notification Dispatcher
# -------------------------------------------------------------------
def get_exchange_display_name(exchange_id: str) -> str:
    mapping = {
        'nobitex': 'Nobitex', 'wallex': 'Wallex', 'binance': 'Binance',
        'tabdeal': 'Tabdeal', 'ramzinex': 'Ramzinex', 'kucoin': 'KuCoin',
        'mexc': 'MEXC', 'gateio': 'Gate.io', 'gate': 'Gate.io',
        'coinex': 'CoinEx', 'okx': 'OKX', 'bybit': 'Bybit',
        'bitbarg': 'BitBarg', 'tetherland': 'Tetherland', 'abantether': 'AbanTether',
        'global_stocks': 'Global Stocks', 'stocks': 'Stocks', 'forex': 'Forex',
        'macro': 'Macro', 'bonds': 'Bonds', 'wallstreet': 'Wall Street', 'iran_market': 'Iran Market'
    }
    return mapping.get((exchange_id or '').lower(), (exchange_id or 'Market').capitalize())

def is_safe_webhook_url(url_str: str) -> bool:
    if not url_str or not url_str.startswith('https://'):
        return False
    try:
        parsed = urlparse(url_str)
        hostname = (parsed.hostname or '').lower().strip()
        if not hostname or hostname in ['localhost', '0.0.0.0']:
            return False

        # Parse directly if IP address
        try:
            ip = ipaddress.ip_address(hostname)
            if not _ip_is_public(ip):
                return False
        except ValueError:
            if hostname.endswith('.local') or hostname.endswith('.internal'):
                return False

        return True
    except Exception:
        return False

def _ip_is_public(ip) -> bool:
    if ip.version == 6 and ip.ipv4_mapped:
        ip = ip.ipv4_mapped
    return ip.is_global and not ip.is_multicast

async def is_safe_webhook_url_async(url_str: str) -> bool:
    """Static checks + DNS resolution: every resolved address must be public (blocks internal-host SSRF)."""
    if not url_str or len(url_str) > MAX_WEBHOOK_LEN or not is_safe_webhook_url(url_str):
        return False
    host = (urlparse(url_str).hostname or '').strip()
    try:
        ipaddress.ip_address(host)
        return True  # literal IP already vetted by is_safe_webhook_url
    except ValueError:
        pass
    try:
        loop = asyncio.get_running_loop()
        infos = await asyncio.wait_for(loop.getaddrinfo(host, 443, type=socket.SOCK_STREAM), timeout=3.0)
    except Exception:
        return False
    if not infos:
        return False
    for info in infos:
        try:
            if not _ip_is_public(ipaddress.ip_address(info[4][0].split('%')[0])):
                return False
        except ValueError:
            return False
    return True

# Strong references so fire-and-forget tasks cannot be garbage-collected mid-flight
# (asyncio keeps only weak refs; a collected task = a silently lost notification).
_BG_TASKS: set = set()

def _spawn(coro):
    task = asyncio.create_task(coro)
    _BG_TASKS.add(task)
    task.add_done_callback(_BG_TASKS.discard)
    return task

def _send_fcm_sync(fcm_token: str, title: str, body: str, data_payload: dict = None, ttl_seconds: int = 300) -> Tuple[bool, str]:
    if not firebase_admin._apps:
        return False, "Firebase Admin SDK not initialized."
    if not fcm_token or fcm_token.startswith('dev_') or fcm_token.startswith('device_token_') or len(fcm_token) < 40:
        return False, "Not a valid Google FCM registration token."

    try:
        full_data = {"title": str(title), "body": str(body), **(data_payload or {})}
        full_data_str = {k: str(v) if v is not None else "" for k, v in full_data.items()}

        effective_ttl = timedelta(seconds=max(60, min(3600, ttl_seconds)))

        message = messaging.Message(
            data=full_data_str,
            token=fcm_token,
            android=messaging.AndroidConfig(priority='high', ttl=effective_ttl, direct_boot_ok=True),
            apns=messaging.APNSConfig(payload=messaging.APNSPayload(aps=messaging.Aps(content_available=True, badge=1)))
        )
        # Retry transient failures (FCM 5xx / quota) so a blip never drops an alert.
        last_err = None
        for attempt, delay in enumerate((0, 0.5, 1.5), start=1):
            if delay:
                time.sleep(delay)
            try:
                response = messaging.send(message)
                METRICS["fcm_success"] += 1
                print(f"🚀 [FCM Push] Sent (TTL: {effective_ttl}, attempt {attempt}): {response}")
                return True, f"FCM Message ID: {response}"
            except (fb_exceptions.UnavailableError, fb_exceptions.InternalError, messaging.QuotaExceededError) as e:
                last_err = e
                print(f"⚠️ [FCM Push] transient error (attempt {attempt}): {e}")
        raise last_err
    except messaging.UnregisteredError:
        METRICS["fcm_failed"] += 1
        print(f"❌ [FCM Push] token no longer registered: ...{fcm_token[-6:]}")
        return False, "UNREGISTERED"
    except Exception as e:
        METRICS["fcm_failed"] += 1
        print(f"❌ [FCM Push Error] {e}")
        return False, str(e)

async def send_fcm_notification_async(fcm_token: str, title: str, body: str, data_payload: dict = None, ttl_seconds: int = 300) -> Tuple[bool, str]:
    return await asyncio.to_thread(_send_fcm_sync, fcm_token, title, body, data_payload, ttl_seconds)

async def send_telegram_alert(client: httpx.AsyncClient, chat_id: str, message: str, bot_token: Optional[str] = None):
    token = bot_token or TELEGRAM_BOT_TOKEN
    if not token or not chat_id:
        return
    try:
        url = f"https://api.telegram.org/bot{token}/sendMessage"
        await client.post(url, json={"chat_id": chat_id, "text": message, "parse_mode": "HTML", "disable_web_page_preview": True}, timeout=6.0)
        METRICS["telegram_sent"] += 1
    except Exception as e:
        print(f"⚠️ [Telegram Dispatch Error] {_scrub(e)}")

async def init_telegram_bot(client: httpx.AsyncClient):
    global TELEGRAM_BOT_METADATA
    if not TELEGRAM_BOT_TOKEN:
        return
    try:
        res = await client.get(f"https://api.telegram.org/bot{TELEGRAM_BOT_TOKEN}/getMe", timeout=6.0)
        if res.status_code == 200:
            data = res.json().get("result", {})
            TELEGRAM_BOT_METADATA["username"] = data.get("username", "aisocialfeedbot")
            TELEGRAM_BOT_METADATA["first_name"] = data.get("first_name", "AiSFeed")
            TELEGRAM_BOT_METADATA["id"] = data.get("id", 8597547058)
            TELEGRAM_BOT_METADATA["is_connected"] = True
            print(f"🤖 [Telegram Bot] Connected to @{TELEGRAM_BOT_METADATA['username']} ({TELEGRAM_BOT_METADATA['first_name']})")
    except Exception as e:
        print(f"⚠️ [Telegram Bot Init Note] {_scrub(e)}")

async def telegram_bot_polling_loop():
    """Background listener for user interactions: /start, /myalerts, /clear, /stop, /help"""
    global ALERTS_DB
    if not TELEGRAM_BOT_TOKEN:
        return
    offset = 0
    print("📡 [Telegram Bot] Polling listener active for instant Chat ID onboarding & alert management.")
    while True:
        try:
            if http_client is None:
                await asyncio.sleep(2)
                continue

            url = f"https://api.telegram.org/bot{TELEGRAM_BOT_TOKEN}/getUpdates"
            params = {"offset": offset, "timeout": 20, "allowed_updates": ["message"]}
            res = await http_client.get(url, params=params, timeout=25.0)
            if res.status_code == 200:
                data = res.json()
                for update in data.get("result", []):
                    offset = update.get("update_id", offset) + 1
                    msg = update.get("message") or {}
                    chat = msg.get("chat") or {}
                    chat_id = chat.get("id")
                    text = (msg.get("text") or "").strip()
                    user_name = html.escape(str(chat.get("first_name") or chat.get("username") or "کاربر گرامی"))

                    if not chat_id:
                        continue

                    reply_url = f"https://api.telegram.org/bot{TELEGRAM_BOT_TOKEN}/sendMessage"
                    chat_id_str = str(chat_id)
                    text_lower = text.lower()

                    # 1. /clear or /stop - Stop all alerts for this chat_id
                    if text_lower.startswith("/clear") or text_lower.startswith("/stop"):
                        async with _db_lock:
                            initial_len = len(ALERTS_DB)
                            ALERTS_DB = [a for a in ALERTS_DB if (a.telegram_chat_id or "").strip() != chat_id_str]
                            removed_count = initial_len - len(ALERTS_DB)

                        if removed_count > 0:
                            await save_alerts_to_disk_async(ALERTS_DB)
                            resp_text = (
                                f"🧹 <b>تمام هشدارهای متصل به این چت تلگرام ({removed_count} هشدار) با موفقیت متوقف و پاکسازی شدند.</b>\n\n"
                                "⚡ دیگر هیچ پیامی از سرور برای این چت ارسال نخواهد شد مگر اینکه در اپلیکیشن مجدداً هشدار ثبت کنید."
                            )
                        else:
                            resp_text = "ℹ️ هیچ هشدار فعالی روی سرور به این Chat ID متصل نیست."

                        await http_client.post(reply_url, json={
                            "chat_id": chat_id,
                            "text": resp_text,
                            "parse_mode": "HTML",
                            "disable_web_page_preview": True
                        }, timeout=5.0)

                    # 2. /myalerts or /list - List all active alerts for this user
                    elif text_lower.startswith("/myalerts") or text_lower.startswith("/list"):
                        user_alerts = [a for a in ALERTS_DB if (a.telegram_chat_id or "").strip() == chat_id_str]
                        if not user_alerts:
                            resp_text = (
                                "📭 <b>هیچ هشداری به این حساب تلگرام متصل نیست.</b>\n\n"
                                f"🆔 Chat ID شما: <code>{chat_id}</code>\n"
                                "برای ثبت هشدار وارد اپلیکیشن SignalAlert شده و این شناسه را در تنظیمات ثبت فرمایید."
                            )
                        else:
                            lines = [f"📋 <b>لیست هشدارهای متصل به تلگرام شما ({len(user_alerts)} مورد):</b>\n"]
                            for i, a in enumerate(user_alerts, 1):
                                st = "🟢 فعال" if a.is_active else "⚪ تکمیل شده"
                                lines.append(f"{i}. <b>{html.escape(a.symbol)}</b> ({get_exchange_display_name(a.exchange)}) - تارگت: <code>{a.target_price:,.2f}</code> | {st}")
                            lines.append("\n💡 <i>برای لغو تمامی هشدارها دستور /clear را بفرستید.</i>")
                            resp_text = "\n".join(lines)

                        await http_client.post(reply_url, json={
                            "chat_id": chat_id,
                            "text": resp_text,
                            "parse_mode": "HTML",
                            "disable_web_page_preview": True
                        }, timeout=5.0)

                    # 3. /help - Help guide
                    elif text_lower.startswith("/help"):
                        help_text = (
                            "🤖 <b>راهنمای دستورات ربات هوشمند SignalAlert:</b>\n\n"
                            "🔹 <code>/start</code> - دریافت شناسه اختصاصی (Chat ID) و راهنمای اتصال\n"
                            "🔹 <code>/myalerts</code> - مشاهده لیست هشدارهای فعال متصل به تلگرام شما\n"
                            "🔹 <code>/clear</code> - توقف و پاکسازی فوری تمام هشدارهای متصل به این چت\n\n"
                            f"🆔 <b>Chat ID شما:</b> <code>{chat_id}</code>"
                        )
                        await http_client.post(reply_url, json={
                            "chat_id": chat_id,
                            "text": help_text,
                            "parse_mode": "HTML",
                            "disable_web_page_preview": True
                        }, timeout=5.0)

                    # 4. /start or any greeting
                    else:
                        welcome_msg = (
                            f"👋 <b>سلام {user_name} عزیز! به ربات رسمی SignalAlert خوش آمدید.</b>\n\n"
                            f"🆔 <b>شناسه چت (Chat ID) شما:</b>\n"
                            f"<code>{chat_id}</code>\n"
                            f"<i>(روی عدد بالا لمس کنید تا کپی شود)</i>\n\n"
                            f"📱 <b>نحوه اتصال به اپلیکیشن:</b>\n"
                            f"۱. وارد تب <b>تنظیمات ⚙️</b> در اپلیکیشن SignalAlert شوید.\n"
                            f"۲. گزینه <b>«اتصال به تلگرام 📱»</b> را انتخاب کنید.\n"
                            f"۳. شناسه <code>{chat_id}</code> را وارد و دکمه ذخیره را بزنید.\n\n"
                            f"⚡ پس از اتصال، تمامی آلارم‌های قیمت و تغییرات تارگت شما به صورت ۲۴/۷ و فوری به این چت ارسال خواهند شد.\n\n"
                            "🔹 <i>دستورات موجود:</i> <code>/myalerts</code> (مشاهده هشدارها) | <code>/clear</code> (توقف هشدارها)"
                        )
                        await http_client.post(reply_url, json={
                            "chat_id": chat_id,
                            "text": welcome_msg,
                            "parse_mode": "HTML",
                            "disable_web_page_preview": True
                        }, timeout=5.0)
            else:
                print(f"⚠️ [Telegram Polling] HTTP {res.status_code}: {res.text[:120]}")
                await asyncio.sleep(15 if res.status_code in (401, 409, 429) else 5)
        except asyncio.CancelledError:
            break
        except Exception as e:
            print(f"⚠️ [Telegram Polling Error] {_scrub(e)}")
            await asyncio.sleep(4)

async def send_webhook_alert(client: httpx.AsyncClient, webhook_url: str, payload: dict):
    if not webhook_url:
        return
    if not await is_safe_webhook_url_async(webhook_url):
        print("⚠️ [Webhook Blocked] Unsafe or unresolvable webhook URL.")
        return
    try:
        await client.post(webhook_url, json=payload, timeout=4.0, follow_redirects=False)
        METRICS["webhook_sent"] += 1
    except Exception as e:
        print(f"⚠️ [Webhook Dispatch Error] {e}")

# -------------------------------------------------------------------
# 7. High-Precision Concurrent Worker
# -------------------------------------------------------------------
async def check_alerts_job():
    global http_client
    if http_client is None:
        return

    current_time = time.time()
    METRICS["total_checks"] += 1

    active_alerts = [
        a for a in ALERTS_DB
        if a.is_active and getattr(a, 'alert_nature', 'price') == 'price' and a.target_price > 0 and a.exchange.lower() not in ['timer', 'local', 'clock', 'none']
    ]
    ready_alerts = [
        a for a in active_alerts
        if (current_time - a.last_checked_at) >= a.check_interval_seconds
    ]

    if not ready_alerts:
        return

    # Update last_checked_at pre-fetch to prevent any concurrent overlap
    for a in ready_alerts:
        a.last_checked_at = current_time

    # Group unique pairs to batch fetch concurrently
    unique_pairs = list({(a.exchange, a.symbol) for a in ready_alerts})
    tasks = [get_cached_price(http_client, ex, sym) for ex, sym in unique_pairs]
    results = await asyncio.gather(*tasks, return_exceptions=True)

    prices: Dict[str, float] = {}
    for (ex, sym), price in zip(unique_pairs, results):
        if isinstance(price, (int, float)) and price > 0:
            prices[f"{ex.lower()}:{normalize_symbol(sym)}"] = float(price)

    updated = False

    async def _process(alert):
        nonlocal updated
        key = f"{alert.exchange.lower()}:{normalize_symbol(alert.symbol)}"
        current_price = prices.get(key)

        if current_price is None:
            # retry ~5s later instead of waiting a full interval
            alert.last_checked_at = current_time - max(0, alert.check_interval_seconds - 5)
            return

        triggered = False
        if alert.condition == 'ABOVE' and current_price >= alert.target_price:
            triggered = True
        elif alert.condition == 'BELOW' and current_price <= alert.target_price:
            triggered = True

        if triggered:
            async with _db_lock:
                last_trig = getattr(alert, 'last_triggered_at', 0.0)
                is_one_shot = getattr(alert, 'trigger_mode', 'oneShot') == 'oneShot'
                min_cooldown = max(30.0, float(alert.check_interval_seconds))

                if is_one_shot:
                    if not alert.is_active or last_trig > 0:
                        return
                else:
                    if (current_time - last_trig) < min_cooldown:
                        return

                # Atomic pre-dispatch update before any IO or network calls
                alert.last_triggered_at = current_time
                if is_one_shot:
                    alert.is_active = False
                updated = True

            METRICS["total_triggers"] += 1
            print(f"🔔 [TRIGGER] {alert.symbol} @ {current_price} (Target: {alert.target_price})")

            is_above = alert.condition.upper() == 'ABOVE'
            emoji = '🟢' if is_above else '🔴'
            arrow = '▲' if is_above else '▼'
            sign = '+' if is_above else '-'

            display_symbol = alert.symbol
            pct_str = f"{sign}{abs(((current_price - alert.target_price) / alert.target_price) * 100.0):.2f}%" if alert.target_price > 0 else ""
            price_formatted = f"${current_price:,.4f}".rstrip('0').rstrip('.') if current_price < 1 else f"${current_price:,.2f}"
            if alert.symbol.endswith('TMN') or alert.symbol.endswith('IRT'):
                price_formatted = f"{int(current_price):,} TMN"
            if '/' not in display_symbol:
                for quote in ['USDT', 'USDC', 'BUSD', 'FDUSD', 'EUR', 'USD', 'TMN', 'IRT', 'BTC', 'ETH']:
                    if display_symbol.endswith(quote):
                        base = display_symbol[:-len(quote)]
                        display_symbol = f"{base}/{quote}"
                        break

            title = f"{emoji} {display_symbol} {pct_str} {price_formatted} {arrow}".replace('  ', ' ')
            exchange_name = get_exchange_display_name(alert.exchange)
            body_lines = [f"🏛️ {exchange_name}"]
            if alert.note and alert.note.strip():
                clean_note = alert.note.strip()
                if not clean_note.startswith('📝'):
                    clean_note = f"📝 {clean_note}"
                body_lines.append(clean_note)
            body = "\n".join(body_lines)

            # 1. Dispatch High-Priority FCM Push for Cloud Backup (Non-blocking Thread Execution)
            _spawn(
                send_fcm_notification_async(
                    fcm_token=alert.fcm_token,
                    title=title,
                    body=body,
                    data_payload={
                        "alert_id": alert.id,
                        "symbol": display_symbol,
                        "price": str(current_price),
                        "note": alert.note or "",
                        "sound_enabled": "true" if alert.sound_enabled else "false",
                        "vibration_enabled": "true" if alert.vibration_enabled else "false",
                        "tts_enabled": "true" if alert.tts_enabled else "false",
                        "sound": alert.sound or "alarm_siren"
                    }
                )
            )

            # 2. Dispatch Optional Telegram Message with HTML Escaping
            if alert.telegram_chat_id:
                is_tmn = alert.symbol.endswith('TMN') or alert.symbol.endswith('IRT')
                target_formatted = f"{int(alert.target_price):,} TMN" if is_tmn else (f"${alert.target_price:,.4f}".rstrip('0').rstrip('.') if alert.target_price < 1 else f"${alert.target_price:,.2f}")

                # Check if condition is percentage or standard price threshold
                cond_upper = (alert.condition or '').upper()
                if 'PERCENT' in cond_upper or '%' in cond_upper or cond_upper == 'BOTHSIDES':
                    if 'ABOVE' in cond_upper or 'UP' in cond_upper:
                        target_display = f"{abs(alert.target_price):g}% عبور به بالا"
                    elif 'BELOW' in cond_upper or 'DOWN' in cond_upper:
                        target_display = f"{abs(alert.target_price):g}% عبور به پایین"
                    else:
                        target_display = f"{abs(alert.target_price):g}% عبور از هر دو طرف"
                else:
                    target_display = target_formatted

                pct_val = abs(((current_price - alert.target_price) / max(1e-8, alert.target_price)) * 100.0) if alert.target_price > 0 else 0.0
                pct_display = f"{arrow}{pct_val:.2f}%" if pct_val > 0.001 else f"{arrow}"

                safe_symbol = html.escape(display_symbol)
                safe_exchange = html.escape(exchange_name)

                tg_lines = [
                    "🚨 <b>هشدار فعال شد:</b>",
                    f"📊{emoji} <b>{safe_symbol} {price_formatted} {pct_display}</b>",
                    f"🎯 <b>قیمت تارگت:</b> {target_display}",
                ]
                if alert.note and alert.note.strip():
                    clean_note = alert.note.strip()
                    if clean_note.startswith('📝'):
                        clean_note = clean_note[1:].strip()
                    safe_note = html.escape(clean_note)
                    tg_lines.append(f"📝 <b>یادداشت:</b> <i>{safe_note}</i>")

                tg_lines.append(f"🏛️ {safe_exchange}")
                now_utc = datetime.now(timezone.utc).strftime('%Y-%m-%d %H:%M:%S UTC')
                tg_lines.append(f"🕒 <b>زمان:</b> <code>{now_utc}</code>")
                tg_lines.append("⚡ <i>ارسال شده توسط ربات هوشمند SignalAlert Enterprise</i>")

                tg_msg = "\n".join(tg_lines)
                _spawn(send_telegram_alert(http_client, alert.telegram_chat_id, tg_msg))

            # 3. Dispatch Optional Webhook with SSRF Protection
            if alert.webhook_url:
                hook_data = {
                    "event": "price_alert_triggered",
                    "alert_id": alert.id,
                    "symbol": display_symbol,
                    "price": current_price,
                    "target_price": alert.target_price,
                    "condition": alert.condition,
                    "timestamp": datetime.now(timezone.utc).isoformat()
                }
                _spawn(send_webhook_alert(http_client, alert.webhook_url, hook_data))

    for alert in ready_alerts:
        try:
            await _process(alert)
        except Exception as e:
            print(f"❌ [Alert Job] {alert.id} {alert.symbol}: {e}")

    if updated:
        await save_alerts_to_disk_async(ALERTS_DB)

# -------------------------------------------------------------------
# 8. API Endpoints
# -------------------------------------------------------------------
@app.api_route("/", methods=["GET", "HEAD"])
def read_root():
    uptime = int(time.time() - METRICS["start_time"])
    return {
        "status": "online",
        "engine": f"SignalAlert Enterprise Engine v{APP_VERSION}",
        "uptime_seconds": uptime,
    }

@app.get("/status", response_class=HTMLResponse, dependencies=ADMIN_DEP)
def get_status_dashboard():
    """Live Dark-Themed Web Monitoring Dashboard"""
    uptime_min = int((time.time() - METRICS["start_time"]) / 60)
    active_count = len([a for a in ALERTS_DB if a.is_active])
    total_count = len(ALERTS_DB)
    cache_total = METRICS["cache_hits"] + METRICS["cache_misses"]
    cache_ratio = round((METRICS["cache_hits"] / max(1, cache_total)) * 100, 1)

    page = f"""
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>SignalAlert Engine Monitor</title>
        <style>
            body {{ font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: #0b0f19; color: #e2e8f0; margin: 0; padding: 24px; }}
            .container {{ max-width: 900px; margin: 0 auto; }}
            .header {{ display: flex; align-items: center; justify-content: space-between; border-bottom: 1px solid #1e293b; padding-bottom: 16px; margin-bottom: 24px; }}
            .status-badge {{ background: #10b98120; color: #10b981; border: 1px solid #10b98140; padding: 6px 12px; border-radius: 9999px; font-weight: bold; font-size: 13px; }}
            .grid {{ display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 16px; margin-bottom: 24px; }}
            .card {{ background: #131b2e; border: 1px solid #1e293b; border-radius: 12px; padding: 16px; }}
            .card-title {{ font-size: 12px; color: #94a3b8; text-transform: uppercase; font-weight: bold; margin-bottom: 8px; }}
            .card-value {{ font-size: 24px; font-weight: 900; color: #f8fafc; font-family: monospace; }}
            .table-wrap {{ background: #131b2e; border: 1px solid #1e293b; border-radius: 12px; padding: 16px; overflow-x: auto; }}
            table {{ width: 100%; border-collapse: collapse; text-align: left; font-size: 13px; }}
            th, td {{ padding: 10px 12px; border-bottom: 1px solid #1e293b; }}
            th {{ color: #94a3b8; font-weight: 600; }}
            .badge-active {{ color: #10b981; font-weight: bold; }}
            .badge-done {{ color: #f59e0b; font-weight: bold; }}
        </style>
    </head>
    <body>
        <div class="container">
            <div class="header">
                <div>
                    <h2 style="margin:0; color:#38bdf8;">⚡ SignalAlert Enterprise Monitor</h2>
                    <p style="margin:4px 0 0; color:#64748b; font-size:13px;">High-Precision 24/7 Background Alert Processor</p>
                </div>
                <div class="status-badge">● ONLINE ({uptime_min}m uptime)</div>
            </div>

            <div class="grid">
                <div class="card">
                    <div class="card-title">Active Alerts</div>
                    <div class="card-value">{active_count} <span style="font-size:14px;color:#64748b;">/ {total_count}</span></div>
                </div>
                <div class="card">
                    <div class="card-title">Total Evaluated</div>
                    <div class="card-value">{METRICS["total_checks"]:,}</div>
                </div>
                <div class="card">
                    <div class="card-title">Cache Hit Ratio</div>
                    <div class="card-value">{cache_ratio}%</div>
                </div>
                <div class="card">
                    <div class="card-title">FCM Push Sent</div>
                    <div class="card-value" style="color:#10b981;">{METRICS["fcm_success"]}</div>
                </div>
            </div>

            <h3 style="margin: 0 0 12px; color: #f8fafc;">Live Registered Alert Rules ({len(ALERTS_DB)})</h3>
            <div class="table-wrap">
                <table>
                    <thead>
                        <tr>
                            <th>Symbol</th>
                            <th>Exchange</th>
                            <th>Target</th>
                            <th>Condition</th>
                            <th>Interval</th>
                            <th>Status</th>
                        </tr>
                    </thead>
                    <tbody>
                        {"".join(f'''
                        <tr>
                            <td style="font-weight:bold; font-family:monospace;">{html.escape(a.symbol)}</td>
                            <td>{html.escape(get_exchange_display_name(a.exchange))}</td>
                            <td style="font-family:monospace; color:#38bdf8;">{a.target_price:,.2f}</td>
                            <td>{"🟢 Above" if a.condition.upper() == "ABOVE" else "🔴 Below"}</td>
                            <td>{a.check_interval_seconds}s</td>
                            <td class="{'badge-active' if a.is_active else 'badge-done'}">{'Active' if a.is_active else 'Triggered (Done)'}</td>
                        </tr>
                        ''' for a in ALERTS_DB[:25]) if ALERTS_DB else '<tr><td colspan="6" style="text-align:center;color:#64748b;padding:24px;">No alerts registered on server yet.</td></tr>'}
                    </tbody>
                </table>
            </div>
        </div>
    </body>
    </html>
    """
    return HTMLResponse(content=page)

@app.post("/api/alerts", response_model=AlertPublic, dependencies=API_DEP)
@app.post("/alerts", response_model=AlertPublic, dependencies=API_DEP)
async def create_alert(alert_in: AlertCreate):
    alert_in.condition = (alert_in.condition or 'ABOVE').strip().upper()
    alert_in.exchange = (alert_in.exchange or '').strip().lower()
    alert_in.symbol = (alert_in.symbol or '').strip().upper()
    if not EXCHANGE_RE.match(alert_in.exchange) or not SYMBOL_RE.match(alert_in.symbol):
        raise HTTPException(status_code=400, detail="Invalid exchange or symbol.")
    if not math.isfinite(alert_in.target_price):
        raise HTTPException(status_code=400, detail="Invalid target_price.")
    if not alert_in.user_id.strip() or len(alert_in.user_id) > 128 or len(alert_in.fcm_token) > 512:
        raise HTTPException(status_code=400, detail="Invalid user_id or fcm_token.")
    if alert_in.telegram_chat_id:
        alert_in.telegram_chat_id = alert_in.telegram_chat_id.strip()
        if not CHAT_ID_RE.match(alert_in.telegram_chat_id):
            raise HTTPException(status_code=400, detail="Invalid telegram_chat_id.")
    if alert_in.webhook_url and not await is_safe_webhook_url_async(alert_in.webhook_url):
        raise HTTPException(status_code=400, detail="Unsafe or unresolvable webhook_url (https + public host required).")
    alert_in.check_interval_seconds = _clamp_interval(alert_in.check_interval_seconds)
    if alert_in.note:
        alert_in.note = alert_in.note[:MAX_NOTE_LEN]
    rule_id = (alert_in.id or str(uuid.uuid4()))[:128]
    async with _db_lock:
        existing = next((a for a in ALERTS_DB if a.id == rule_id), None)
        if existing:
            existing.user_id = alert_in.user_id
            existing.exchange = alert_in.exchange
            existing.symbol = alert_in.symbol
            existing.target_price = alert_in.target_price
            existing.condition = alert_in.condition
            existing.fcm_token = alert_in.fcm_token
            existing.check_interval_seconds = alert_in.check_interval_seconds
            existing.note = alert_in.note
            existing.trigger_mode = alert_in.trigger_mode or "oneShot"
            existing.alert_nature = alert_in.alert_nature or "price"
            existing.sound_enabled = alert_in.sound_enabled
            existing.vibration_enabled = alert_in.vibration_enabled
            existing.tts_enabled = alert_in.tts_enabled
            existing.sound = alert_in.sound or "alarm_siren"
            existing.telegram_chat_id = alert_in.telegram_chat_id
            existing.webhook_url = alert_in.webhook_url
            existing.is_active = True
            existing.last_triggered_at = 0.0
            existing.last_checked_at = 0.0
            new_alert = existing
        else:
            if sum(1 for a in ALERTS_DB if a.user_id == alert_in.user_id) >= MAX_ALERTS_PER_USER:
                raise HTTPException(status_code=400, detail="Alert limit reached for this user.")
            new_alert = Alert(
                id=rule_id,
                user_id=alert_in.user_id,
                exchange=alert_in.exchange,
                symbol=alert_in.symbol,
                target_price=alert_in.target_price,
                condition=alert_in.condition,
                fcm_token=alert_in.fcm_token,
                check_interval_seconds=alert_in.check_interval_seconds,
                note=alert_in.note,
                trigger_mode=alert_in.trigger_mode or "oneShot",
                alert_nature=alert_in.alert_nature or "price",
                sound_enabled=alert_in.sound_enabled,
                vibration_enabled=alert_in.vibration_enabled,
                tts_enabled=alert_in.tts_enabled,
                sound=alert_in.sound or "alarm_siren",
                telegram_chat_id=alert_in.telegram_chat_id,
                webhook_url=alert_in.webhook_url,
                is_active=True,
                created_at=datetime.now(timezone.utc).isoformat(),
                last_checked_at=0.0,
                last_triggered_at=0.0
            )
            ALERTS_DB.append(new_alert)
    await save_alerts_to_disk_async(ALERTS_DB)
    print(f"📩 [API] New Alert Created/Updated: {new_alert.symbol} ({new_alert.exchange}) | ID: {new_alert.id} | Target: {new_alert.target_price} | Interval: {new_alert.check_interval_seconds}s")
    return new_alert

@app.post("/api/alerts/sync", dependencies=API_DEP)
@app.post("/alerts/sync", dependencies=API_DEP)
async def sync_user_alerts(payload: dict):
    global ALERTS_DB
    user_id = str(payload.get('user_id') or 'user_default').strip()
    fcm_token = str(payload.get('fcm_token') or '').strip()
    alerts_data = payload.get('alerts', [])
    if user_id == 'user_default' and len(fcm_token) <= 10:
        raise HTTPException(status_code=400, detail="user_id or a valid fcm_token is required.")
    if len(user_id) > 128 or len(fcm_token) > 512:
        raise HTTPException(status_code=400, detail="user_id or fcm_token too long.")
    if not isinstance(alerts_data, list) or len(alerts_data) > MAX_ALERTS_PER_USER:
        raise HTTPException(status_code=400, detail=f"'alerts' must be a list of at most {MAX_ALERTS_PER_USER} items.")
    try:
        alerts_data = [_normalize_sync_item(i) for i in alerts_data]
    except (ValueError, TypeError) as e:
        raise HTTPException(status_code=400, detail=f"Invalid alert payload: {e}")
    for item in alerts_data:
        hook = item.get('webhook_url')
        if hook:
            if await is_safe_webhook_url_async(str(hook)):
                item['webhook_url'] = str(hook)
            else:
                print(f"⚠️ [API] Dropped unsafe webhook_url from synced alert {item.get('id')}")
                item['webhook_url'] = None

    async with _db_lock:
        existing_map = {a.id: a for a in ALERTS_DB if (a.user_id == user_id or a.fcm_token == fcm_token)}
        new_alerts = []
        added_count = 0
        for item in alerts_data:
            rule_id = item.get('id') or str(uuid.uuid4())
            existing = existing_map.get(rule_id)

            last_trig = existing.last_triggered_at if existing else 0.0
            last_chk = existing.last_checked_at if existing else 0.0
            is_act = bool(item.get('is_active', True))
            if existing and not existing.is_active and getattr(existing, 'trigger_mode', 'oneShot') == 'oneShot':
                is_act = False

            alert_obj = Alert(
                id=rule_id,
                user_id=user_id,
                exchange=item.get('exchange', 'nobitex').lower(),
                symbol=item.get('symbol', 'USDTIRT').upper(),
                target_price=float(item.get('target_price', 0.0)),
                condition=item.get('condition', 'ABOVE').upper(),
                fcm_token=item.get('fcm_token') or fcm_token,
                check_interval_seconds=_clamp_interval(item.get('check_interval_seconds', 180)),
                note=item.get('note'),
                trigger_mode=item.get('trigger_mode', 'oneShot'),
                alert_nature=item.get('alert_nature') or 'price',
                sound_enabled=bool(item.get('sound_enabled', True)),
                vibration_enabled=bool(item.get('vibration_enabled', True)),
                tts_enabled=bool(item.get('tts_enabled', True)),
                sound=item.get('sound', 'alarm_siren'),
                telegram_chat_id=item.get('telegram_chat_id'),
                webhook_url=item.get('webhook_url'),
                is_active=is_act,
                created_at=item.get('created_at') or datetime.now(timezone.utc).isoformat(),
                last_checked_at=last_chk,
                last_triggered_at=last_trig
            )
            new_alerts.append(alert_obj)
            added_count += 1

        if user_id == 'user_default':
            ALERTS_DB = [a for a in ALERTS_DB if a.fcm_token != fcm_token]
        elif len(fcm_token) > 10:
            ALERTS_DB = [a for a in ALERTS_DB if (a.user_id != user_id and a.fcm_token != fcm_token)]
        else:
            ALERTS_DB = [a for a in ALERTS_DB if a.user_id != user_id]
        ALERTS_DB.extend(new_alerts)

    await save_alerts_to_disk_async(ALERTS_DB)
    active_remaining = len([a for a in ALERTS_DB if a.is_active])
    print(f"🔄 [API] Bulk Synced {added_count} alert(s) for user {user_id} (Active remaining: {active_remaining})")
    return {"status": "synced", "count": added_count, "total_active": active_remaining}

@app.delete("/api/alerts", dependencies=API_DEP)
@app.delete("/alerts", dependencies=API_DEP)
async def clear_all_alerts(user_id: Optional[str] = None, fcm_token: Optional[str] = None):
    global ALERTS_DB
    async with _db_lock:
        if fcm_token:
            ALERTS_DB = [a for a in ALERTS_DB if a.fcm_token != fcm_token]
        elif user_id:
            ALERTS_DB = [a for a in ALERTS_DB if a.user_id != user_id]
        else:
            raise HTTPException(status_code=400, detail="user_id or fcm_token is required.")
    await save_alerts_to_disk_async(ALERTS_DB)
    print("🧹 [API] Alerts purged from server.")
    return {"status": "cleared", "total_alerts": len(ALERTS_DB)}

@app.get("/api/alerts/{user_id}", response_model=List[AlertPublic], dependencies=API_DEP)
@app.get("/alerts/{user_id}", response_model=List[AlertPublic], dependencies=API_DEP)
async def get_user_alerts(user_id: str, fcm_token: Optional[str] = None):
    clean_uid = (user_id or "").strip().lower()
    clean_fcm = (fcm_token or "").strip()

    async with _db_lock:
        results = []
        for a in ALERTS_DB:
            a_uid = (a.user_id or "").strip().lower()
            a_fcm = (a.fcm_token or "").strip()

            # Match if user_id matches, or if FCM token matches (same device)
            if (clean_uid and a_uid == clean_uid) or (clean_fcm and a_fcm and a_fcm == clean_fcm):
                # If alert was created under 'user_default', migrate it to logged-in user_id
                if clean_uid and clean_uid != 'user_default' and a_uid == 'user_default':
                    a.user_id = clean_uid
                results.append(a)

    return results

@app.delete("/api/alerts/{alert_id}", dependencies=API_DEP)
@app.delete("/alerts/{alert_id}", dependencies=API_DEP)
async def delete_alert(alert_id: str):
    global ALERTS_DB
    clean_id = (alert_id or "").strip()
    async with _db_lock:
        ALERTS_DB = [a for a in ALERTS_DB if a.id != clean_id]
    await save_alerts_to_disk_async(ALERTS_DB)
    return {"status": "deleted", "id": clean_id}

@app.get("/api/price/{exchange}/{symbol}", dependencies=API_DEP)
@app.get("/price/{exchange}/{symbol}", dependencies=API_DEP)
async def get_live_price(exchange: str, symbol: str):
    global http_client
    if http_client is None:
        raise HTTPException(status_code=503, detail="Server client initializing...")
    _validate_market_args(exchange, symbol)
    price = await get_cached_price(http_client, exchange, symbol)
    if price is not None and price > 0:
        return {
            "status": "ok",
            "exchange": exchange,
            "symbol": symbol,
            "price": price,
            "timestamp": time.time()
        }
    raise HTTPException(status_code=502, detail="Unable to fetch live price from market sources.")

@app.get("/api/debug/inspect/{exchange}/{symbol}", dependencies=ADMIN_DEP)
@app.get("/debug/inspect/{exchange}/{symbol}", dependencies=ADMIN_DEP)
async def inspect_market_source(exchange: str, symbol: str):
    """Deeply tests and traces every API endpoint without code duplication"""
    global http_client
    if http_client is None:
        raise HTTPException(status_code=503, detail="Server initializing...")

    _validate_market_args(exchange, symbol)
    start_time = time.time()
    final_price, traces = await fetch_price_with_trace(http_client, exchange, symbol, collect_all_traces=True)
    elapsed_total = round((time.time() - start_time) * 1000, 2)

    report = {
        'status': 'OK' if final_price is not None else 'FAILED',
        'exchange': exchange,
        'symbol': symbol,
        'resolved_price': final_price,
        'total_duration_ms': elapsed_total,
        'timestamp': datetime.utcnow().isoformat(),
        'traces': traces,
        'recommendation': 'Price resolved successfully.' if final_price else f'Unable to fetch {symbol} on {exchange}. Verify symbol code.'
    }

    RECENT_DIAGNOSTICS.insert(0, report)
    if len(RECENT_DIAGNOSTICS) > 50:
        RECENT_DIAGNOSTICS.pop()

    return report

@app.get("/api/debug/logs", dependencies=ADMIN_DEP)
@app.get("/debug/logs", dependencies=ADMIN_DEP)
def get_debug_logs():
    return {"count": len(RECENT_DIAGNOSTICS), "logs": RECENT_DIAGNOSTICS}

@app.get("/api/test/push", dependencies=ADMIN_DEP)
@app.post("/api/test/push", dependencies=ADMIN_DEP)
async def test_push_notification(fcm_token: Optional[str] = None, title: Optional[str] = None, body: Optional[str] = None):
    token_to_use = fcm_token
    if not token_to_use:
        for a in ALERTS_DB:
            if a.fcm_token and not any(k in a.fcm_token.lower() for k in ['sample', 'pending', 'device_token_']):
                token_to_use = a.fcm_token
                break

    test_title = title or "🔔 [SignalAlert Live Connection]"
    test_body = body or "✅ App is successfully connected to the server! Live push notification channel is online."

    if not token_to_use:
        return {
            "success": False,
            "error": "No real FCM device token found. Please open mobile app or pass ?fcm_token=YOUR_TOKEN",
            "firebase_initialized": bool(firebase_admin._apps),
            "service_account_key_found": os.path.exists("serviceAccountKey.json"),
            "active_alerts_count": len(ALERTS_DB),
            "timestamp": datetime.utcnow().isoformat()
        }

    sent_ok, sent_msg = await send_fcm_notification_async(
        fcm_token=token_to_use,
        title=test_title,
        body=test_body,
        data_payload={"type": "test_ping", "timestamp": str(time.time()), "source": "api_test_endpoint"}
    )

    return {
        "success": sent_ok,
        "details": sent_msg,
        "fcm_token_used": "..." + token_to_use[-6:],
        "firebase_initialized": bool(firebase_admin._apps),
        "service_account_key_found": os.path.exists("serviceAccountKey.json"),
        "title_sent": test_title,
        "body_sent": test_body,
        "timestamp": datetime.utcnow().isoformat()
    }

class TelegramTestRequest(BaseModel):
    chat_id: str

@app.get("/api/telegram/bot-info", dependencies=API_DEP)
@app.get("/telegram/bot-info", dependencies=API_DEP)
def get_telegram_bot_info():
    uname = TELEGRAM_BOT_METADATA.get("username", "aisocialfeedbot")
    return {
        "bot_token_configured": bool(TELEGRAM_BOT_TOKEN),
        "username": uname,
        "first_name": TELEGRAM_BOT_METADATA.get("first_name", "AiSFeed"),
        "is_connected": TELEGRAM_BOT_METADATA.get("is_connected", False),
        "bot_url": f"https://t.me/{uname}",
        "bot_handle": f"@{uname}"
    }

@app.post("/api/telegram/test-message", dependencies=API_DEP)
@app.post("/telegram/test-message", dependencies=API_DEP)
async def send_telegram_test_message(req: TelegramTestRequest):
    global http_client
    if not http_client:
        raise HTTPException(status_code=503, detail="Server client not initialized.")
    if not TELEGRAM_BOT_TOKEN:
        raise HTTPException(status_code=400, detail="Telegram Bot Token is not configured.")

    chat_id = (req.chat_id or "").strip()
    if not chat_id or not CHAT_ID_RE.match(chat_id):
        raise HTTPException(status_code=400, detail="Valid chat_id is required.")

    test_msg = (
        "🚨 <b>هشدار فعال شد:</b>\n"
        "📊🟢 <b>^TNX/USD $5.31 ▲3.12%</b>\n"
        "🎯 <b>قیمت تارگت:</b> $5.90\n"
        "🏛️ Global Stocks\n"
        f"🕒 <b>زمان:</b> <code>{datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S UTC')}</code>\n"
        "⚡ <i>ارسال شده توسط ربات هوشمند SignalAlert Enterprise</i>"
    )

    try:
        url = f"https://api.telegram.org/bot{TELEGRAM_BOT_TOKEN}/sendMessage"
        res = await http_client.post(url, json={
            "chat_id": chat_id,
            "text": test_msg,
            "parse_mode": "HTML",
            "disable_web_page_preview": True
        }, timeout=8.0)
        if res.status_code == 200:
            METRICS["telegram_sent"] += 1
            return {"status": "ok", "message": "پیام تست با موفقیت به تلگرام شما ارسال شد!", "chat_id": chat_id}
        else:
            return {"status": "error", "detail": res.text[:200], "status_code": res.status_code}
    except Exception as e:
        print(f"⚠️ [Telegram Test Error] {_scrub(e)}")
        raise HTTPException(status_code=502, detail="Telegram request failed.")
