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
    """Non-blocking async HTTP fetcher with connection pooling"""
    ex = exchange.lower()
    sym = symbol.upper()
    try:
        if ex == 'nobitex':
            url = f"https://api.nobitex.ir/v2/orderbook/{sym}"
            res = await client.get(url, timeout=4.0)
            if res.status_code == 200:
                data = res.json()
                if 'bids' in data and len(data['bids']) > 0:
                    return float(data['bids'][0][0])

        elif ex in ['wallex', 'tabdeal', 'ramzinex', 'tetherland']:
            # Fallback or direct endpoints
            url = f"https://api.nobitex.ir/v2/orderbook/{sym}"
            res = await client.get(url, timeout=4.0)
            if res.status_code == 200:
                data = res.json()
                if 'bids' in data and len(data['bids']) > 0:
                    return float(data['bids'][0][0])

        else:
            # Binance & Global Crypto
            url = f"https://api.binance.com/api/v3/ticker/price?symbol={sym}"
            res = await client.get(url, timeout=4.0)
            if res.status_code == 200:
                return float(res.json()['price'])

    except Exception as e:
        print(f"❌ Error fetching {sym} from {exchange}: {e}")
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
            print(f"🔔 [ALERT TRIGGERED] {alert.symbol} @ {current_price} (Target: {alert.target_price})")
            send_fcm_notification(
                fcm_token=alert.fcm_token,
                title=f"🚨 هشدار قیمت {alert.symbol}",
                body=f"قیمت {alert.symbol} در صرافی {alert.exchange.capitalize()} به {current_price:,.2f} رسید!",
                data_payload={"alert_id": alert.id, "symbol": alert.symbol, "price": str(current_price)}
            )
            alert.is_active = False
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
        last_checked_at=0.0
    )
    ALERTS_DB.append(new_alert)
    save_alerts_to_disk(ALERTS_DB)
    print(f"➕ Alert Created: {new_alert.symbol} ({new_alert.check_interval_seconds}s interval)")
    return new_alert

@app.get("/api/alerts/{user_id}", response_model=List[Alert])
def get_user_alerts(user_id: str):
    return [a for a in ALERTS_DB if a.user_id == user_id]

@app.delete("/api/alerts/{alert_id}")
def delete_alert(alert_id: str):
    global ALERTS_DB
    ALERTS_DB = [a for a in ALERTS_DB if a.id != alert_id]
    save_alerts_to_disk(ALERTS_DB)
    return {"status": "deleted", "id": alert_id}
