import os
import time
import uuid
import json
import asyncio
from datetime import datetime
from typing import List, Optional, Dict
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from apscheduler.schedulers.asyncio import AsyncIOScheduler
import httpx
import firebase_admin
from firebase_admin import credentials, messaging

# -------------------------------------------------------------------
# 1. Firebase Initialization
# -------------------------------------------------------------------
SERVICE_ACCOUNT_FILE = "serviceAccountKey.json"

if os.path.exists(SERVICE_ACCOUNT_FILE):
    try:
        cred = credentials.Certificate(SERVICE_ACCOUNT_FILE)
        firebase_admin.initialize_app(cred)
        print("✅ فایربیس با موفقیت متصل شد.")
    except Exception as e:
        print(f"⚠️ خطای اتصال فایربیس: {e}")
else:
    print(f"⚠️ هشدار: فایل {SERVICE_ACCOUNT_FILE} یافت نشد! نوتیفیکیشن غیرفعال است.")

# -------------------------------------------------------------------
# 2. Data Models & Persistent Storage
# -------------------------------------------------------------------
class AlertCreate(BaseModel):
    user_id: str
    exchange: str            # e.g. 'nobitex', 'wallex', 'binance', 'iran_market'
    symbol: str              # e.g. 'BTCUSDT', 'USDTIRT', 'GOLD18'
    target_price: float      # Target price threshold
    condition: str           # 'ABOVE' or 'BELOW'
    fcm_token: str           # Target device FCM token
    check_interval_seconds: int = 10  # Flexible interval (seconds, converted from min/hours in app)
    note: Optional[str] = None

class Alert(AlertCreate):
    id: str
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

def save_alerts_to_disk(alerts: List[Alert]):
    try:
        with open(DB_FILE, "w", encoding="utf-8") as f:
            json.dump([a.dict() for a in alerts], f, ensure_ascii=False, indent=2)
    except Exception as e:
        print(f"⚠️ Error saving alerts disk DB: {e}")

ALERTS_DB: List[Alert] = load_alerts_from_disk()

# -------------------------------------------------------------------
# 3. FastAPI App & CORS Setup
# -------------------------------------------------------------------
app = FastAPI(title="SignalAlert Production Engine", version="2.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

scheduler = AsyncIOScheduler()

# -------------------------------------------------------------------
# 4. Asynchronous High-Performance Price Engine (httpx Async)
# -------------------------------------------------------------------
async def fetch_price_async(client: httpx.AsyncClient, exchange: str, symbol: str) -> Optional[float]:
    """Non-blocking async HTTP fetcher with connection pooling and multi-source fallbacks"""
    ex = exchange.lower()
    sym = symbol.upper().replace('/', '').replace(' ', '')

    try:
        # 1. IRANIAN EXCHANGES (Nobitex, Wallex, Tabdeal, Ramzinex, Tetherland, etc.)
        if ex in ['nobitex', 'wallex', 'tabdeal', 'ramzinex', 'tetherland', 'abantether', 'bitbarg', 'sarmayex', 'exir']:
            # Normalize symbol for Iranian APIs (e.g. USDTTMN -> USDTIRT or usdt-rls)
            nobitex_sym = sym
            if sym in ['USDTTMN', 'USDTIRT', 'USDT']:
                nobitex_sym = 'USDTIRT'
            elif sym.endswith('TMN'):
                nobitex_sym = sym[:-3] + 'IRT'
            elif sym.endswith('IRT'):
                nobitex_sym = sym

            # Try Nobitex Orderbook
            try:
                url = f"https://api.nobitex.ir/v2/orderbook/{nobitex_sym}"
                res = await client.get(url, timeout=5.0, headers={'User-Agent': 'Mozilla/5.0'})
                if res.status_code == 200:
                    data = res.json()
                    if 'bids' in data and len(data['bids']) > 0:
                        return float(data['bids'][0][0])
            except Exception:
                pass

            # Try Nobitex Market Stats
            try:
                url = "https://api.nobitex.ir/market/stats"
                res = await client.get(url, timeout=5.0, headers={'User-Agent': 'Mozilla/5.0'})
                if res.status_code == 200:
                    data = res.json()
                    if 'stats' in data:
                        stats = data['stats']
                        for k, v in stats.items():
                            clean_k = k.upper().replace('-', '').replace('RLS', 'TMN').replace('IRT', 'TMN')
                            if clean_k == sym or k.upper().replace('-', '') == nobitex_sym:
                                if 'latestPrice' in v:
                                    val = float(v['latestPrice'])
                                    return val / 10.0 if k.endswith('-rls') else val
            except Exception:
                pass

            # Try Wallex API fallback
            try:
                url = "https://api.wallex.ir/v1/markets"
                res = await client.get(url, timeout=5.0, headers={'User-Agent': 'Mozilla/5.0'})
                if res.status_code == 200:
                    data = res.json()
                    if 'result' in data and 'symbols' in data['result']:
                        symbols = data['result']['symbols']
                        for s_key, s_data in symbols.items():
                            if s_key.upper().replace('-', '') == sym or s_key.upper() == sym:
                                return float(s_data['stats']['lastPrice'])
            except Exception:
                pass

        # 2. GLOBAL MACRO / FOREX / US BONDS / STOCKS (e.g. DX-Y.NYB, US10Y, EUR/USD, NVDA, GOLD)
        elif ex in ['global_stocks', 'stocks', 'macro', 'forex', 'bonds', 'wallstreet'] or '-' in sym or 'NYB' in sym or '10Y' in sym:
            yf_symbol = sym
            if 'DX-Y' in sym or 'DXY' in sym:
                yf_symbol = 'DX-Y.NYB'
            elif 'US10Y' in sym or '10Y' in sym or 'TNX' in sym:
                yf_symbol = '^TNX'
            elif 'EURUSD' in sym or 'EUR/USD' in sym:
                yf_symbol = 'EURUSD=X'
            elif 'GBPUSD' in sym:
                yf_symbol = 'GBPUSD=X'
            elif 'USDJPY' in sym:
                yf_symbol = 'USDJPY=X'
            elif 'GOLD' in sym or 'XAU' in sym:
                yf_symbol = 'GC=F'

            try:
                url = f"https://query1.finance.yahoo.com/v8/finance/chart/{yf_symbol}?interval=1m&range=1d"
                res = await client.get(url, timeout=5.0, headers={'User-Agent': 'Mozilla/5.0'})
                if res.status_code == 200:
                    data = res.json()
                    if 'chart' in data and 'result' in data['chart'] and data['chart']['result']:
                        meta = data['chart']['result'][0]['meta']
                        price = meta.get('regularMarketPrice')
                        if price and float(price) > 0:
                            return float(price)
            except Exception:
                pass

        # 3. GLOBAL CRYPTO (Binance, MEXC, KuCoin, Gate.io, OKX, Bybit)
        crypto_sym = sym
        if not crypto_sym.endswith('USDT') and not crypto_sym.endswith('BUSD') and not crypto_sym.endswith('BTC'):
            crypto_sym = crypto_sym + 'USDT'

        # Try Binance
        try:
            url = f"https://api.binance.com/api/v3/ticker/price?symbol={crypto_sym}"
            res = await client.get(url, timeout=4.0)
            if res.status_code == 200:
                return float(res.json()['price'])
        except Exception:
            pass

        # Try MEXC
        try:
            url = f"https://api.mexc.com/api/v3/ticker/price?symbol={crypto_sym}"
            res = await client.get(url, timeout=4.0)
            if res.status_code == 200:
                return float(res.json()['price'])
        except Exception:
            pass

    except Exception as e:
        print(f"⚠️ [Worker] Unable to resolve price for {symbol} on {exchange} ({e})")

    return None

# -------------------------------------------------------------------
# 5. Direct FCM High-Priority Notification Engine
# -------------------------------------------------------------------
def send_fcm_notification(fcm_token: str, title: str, body: str, data_payload: dict = None):
    if not firebase_admin._apps:
        return False
    try:
        message = messaging.Message(
            notification=messaging.Notification(title=title, body=body),
            data=data_payload or {},
            token=fcm_token,
            android=messaging.AndroidConfig(
                priority='high',
                ttl=0, # Immediate delivery
                notification=messaging.AndroidNotification(
                    sound='default',
                    channel_id='price_alerts_channel',
                    priority='max'
                )
            )
        )
        response = messaging.send(message)
        print(f"🚀 FCM High-Priority Push Sent: {response}")
        return True
    except Exception as e:
        print(f"❌ FCM Push Error: {e}")
        return False

# -------------------------------------------------------------------
# 6. High-Precision Concurrent Worker
# -------------------------------------------------------------------
async def check_alerts_job():
    current_time = time.time()
    active_alerts = [a for a in ALERTS_DB if a.is_active]

    # Filter alerts whose custom interval (seconds, minutes, or hours) has elapsed
    ready_alerts = [
        a for a in active_alerts 
        if (current_time - a.last_checked_at) >= a.check_interval_seconds
    ]

    if not ready_alerts:
        return

    print(f"⏰ [Worker] Checking prices for {len(ready_alerts)} active alert(s)...")

    # Group unique (exchange, symbol) pairs to minimize HTTP requests
    unique_pairs = list({(a.exchange, a.symbol) for a in ready_alerts})

    prices: Dict[str, float] = {}
    async with httpx.AsyncClient() as client:
        # Fetch all unique prices concurrently (Non-blocking Parallel IO)
        tasks = [fetch_price_async(client, ex, sym) for ex, sym in unique_pairs]
        results = await asyncio.gather(*tasks)

        for (ex, sym), price in zip(unique_pairs, results):
            if price is not None:
                prices[f"{ex}:{sym}"] = price

    # Evaluate conditions for each ready alert
    updated = False
    for alert in ready_alerts:
        alert.last_checked_at = current_time
        key = f"{alert.exchange}:{alert.symbol}"
        current_price = prices.get(key)

        if current_price is None:
            continue

        triggered = False
        if alert.condition == 'ABOVE' and current_price >= alert.target_price:
            triggered = True
        elif alert.condition == 'BELOW' and current_price <= alert.target_price:
            triggered = True

        if triggered:
            # Check cooldown so we don't spam FCM push faster than alert's check_interval_seconds
            last_trig = getattr(alert, 'last_triggered_at', 0.0)
            if (current_time - last_trig) >= alert.check_interval_seconds:
                print(f"🔔 [ALERT TRIGGERED & FCM PUSH SENT] {alert.symbol} @ {current_price} (Target: {alert.target_price})")
                send_fcm_notification(
                    fcm_token=alert.fcm_token,
                    title=f"🚨 هشدار قیمت {alert.symbol}",
                    body=f"قیمت {alert.symbol} در صرافی {alert.exchange.capitalize()} به {current_price:,.2f} رسید!",
                    data_payload={"alert_id": alert.id, "symbol": alert.symbol, "price": str(current_price)}
                )
                alert.last_triggered_at = current_time
                alert.is_active = True # Keep active for 24/7 background monitoring
                updated = True

    if updated:
        save_alerts_to_disk(ALERTS_DB)

# -------------------------------------------------------------------
# 7. Endpoints
# -------------------------------------------------------------------
@app.on_event("startup")
async def startup_event():
    scheduler.add_job(check_alerts_job, 'interval', seconds=1)
    scheduler.start()
    print("🚀 SignalAlert Enterprise Engine Online (1s Precision Scheduler).")

@app.get("/")
def read_root():
    print("🌐 [API] Health check requested.")
    return {
        "status": "online",
        "engine": "SignalAlert Enterprise Engine v2.0",
        "total_alerts": len(ALERTS_DB),
        "active_alerts": len([a for a in ALERTS_DB if a.is_active])
    }

@app.post("/api/alerts", response_model=Alert)
def create_alert(alert_in: AlertCreate):
    new_alert = Alert(
        id=str(uuid.uuid4()),
        user_id=alert_in.user_id,
        exchange=alert_in.exchange,
        symbol=alert_in.symbol,
        target_price=alert_in.target_price,
        condition=alert_in.condition,
        fcm_token=alert_in.fcm_token,
        check_interval_seconds=alert_in.check_interval_seconds,
        note=alert_in.note,
        is_active=True,
        created_at=datetime.utcnow().isoformat(),
        last_checked_at=0.0,
        last_triggered_at=0.0
    )
    ALERTS_DB.append(new_alert)
    save_alerts_to_disk(ALERTS_DB)
    print(f"📩 [API] New Alert Created: {new_alert.symbol} ({new_alert.exchange}) | Target: {new_alert.target_price} | Interval: {new_alert.check_interval_seconds}s")
    return new_alert

@app.get("/api/alerts/{user_id}", response_model=List[Alert])
def get_user_alerts(user_id: str):
    user_alerts = [a for a in ALERTS_DB if a.user_id == user_id]
    print(f"📖 [API] Fetching alerts for user {user_id}: {len(user_alerts)} alert(s) found.")
    return user_alerts

@app.delete("/api/alerts/{alert_id}")
def delete_alert(alert_id: str):
    global ALERTS_DB
    ALERTS_DB = [a for a in ALERTS_DB if a.id != alert_id]
    save_alerts_to_disk(ALERTS_DB)
    print(f"🗑️ [API] Deleted Alert {alert_id}")
    return {"status": "deleted", "id": alert_id}

@app.get("/api/price/{exchange}/{symbol}")
async def get_live_price(exchange: str, symbol: str):
    async with httpx.AsyncClient() as client:
        price = await fetch_price_async(client, exchange, symbol)
        if price is not None and price > 0:
            return {
                "status": "ok",
                "exchange": exchange,
                "symbol": symbol,
                "price": price,
                "timestamp": time.time()
            }
        else:
            raise HTTPException(status_code=502, detail="Unable to fetch price from market source")
