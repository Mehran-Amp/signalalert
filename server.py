import os
import time
import uuid
import json
import asyncio
from datetime import datetime, timedelta
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
firebase_initialized = False

if os.path.exists(SERVICE_ACCOUNT_FILE):
    try:
        cred = credentials.Certificate(SERVICE_ACCOUNT_FILE)
        firebase_admin.initialize_app(cred)
        firebase_initialized = True
        print("✅ فایربیس با موفقیت از فایل کلید محلی متصل شد.")
    except Exception as e:
        print(f"⚠️ خطای اتصال فایربیس: {e}")
elif os.getenv("FIREBASE_SERVICE_ACCOUNT"):
    try:
        cred_dict = json.loads(os.getenv("FIREBASE_SERVICE_ACCOUNT"))
        cred = credentials.Certificate(cred_dict)
        firebase_admin.initialize_app(cred)
        firebase_initialized = True
        print("✅ فایربیس با موفقیت از متغیر محیطی متصل شد.")
    except Exception as e:
        print(f"⚠️ خطای اتصال فایربیس از متغیر محیطی: {e}")
else:
    print(f"ℹ️ فایل '{SERVICE_ACCOUNT_FILE}' در ریپازیتوری وجود ندارد (جهت امنیت در .gitignore قرار دارد). برای فعال‌سازی پوش‌نوتیفیکیشن، فایل کلید را در سیستم محلی خود قرار دهید.")

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
    trigger_mode: Optional[str] = "oneShot" # 'oneShot' | 'recurring'
    sound_enabled: bool = True
    vibration_enabled: bool = True
    tts_enabled: bool = True
    sound: Optional[str] = "alarm_siren"

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
        # 1. IRANIAN EXCHANGES (Tabdeal, Nobitex, Wallex, Bitpin, Tetherland, Ramzinex, AbanTether, etc.)
        if ex in ['tabdeal', 'nobitex', 'wallex', 'bitpin', 'tetherland', 'abantether', 'ramzinex', 'bitbarg', 'sarmayex', 'exir'] or sym.endswith('TMN') or sym.endswith('IRT') or sym.endswith('RLS'):
            # Normalize symbol for Iranian APIs (e.g. USDTTMN -> USDTIRT / USDT_IRT / USDT_TMN)
            nobitex_sym = sym
            if sym in ['USDTTMN', 'USDTIRT', 'USDT', 'USDT-TMN', 'USDT-IRT']:
                nobitex_sym = 'USDTIRT'
            elif sym.endswith('TMN'):
                nobitex_sym = sym[:-3] + 'IRT'
            elif sym.endswith('IRT'):
                nobitex_sym = sym

            # 1a. Tabdeal API (Primary for Tabdeal exchange or USDT/TMN)
            try:
                url_tabdeal = "https://api.tabdeal.org/r/plots/market/information"
                res = await client.get(url_tabdeal, timeout=4.0, headers={'User-Agent': 'Mozilla/5.0'})
                if res.status_code == 200:
                    data = res.json()
                    # Tabdeal format: {"USDT_IRT": {"price": "...", ...}}
                    for t_key, t_val in data.items():
                        clean_t = t_key.upper().replace('_', '').replace('-', '')
                        if clean_t in [sym, nobitex_sym, 'USDTTMN', 'USDTIRT']:
                            if isinstance(t_val, dict) and 'price' in t_val:
                                return float(t_val['price'])
                            elif isinstance(t_val, dict) and 'last_price' in t_val:
                                return float(t_val['last_price'])
            except Exception:
                pass

            # 1b. Nobitex Orderbook (Try .net first for international DNS, then .ir)
            for domain in ['api.nobitex.net', 'api.nobitex.ir']:
                try:
                    url = f"https://{domain}/v2/orderbook/{nobitex_sym}"
                    res = await client.get(url, timeout=4.0, headers={'User-Agent': 'Mozilla/5.0'})
                    if res.status_code == 200:
                        data = res.json()
                        if 'bids' in data and len(data['bids']) > 0:
                            return float(data['bids'][0][0])
                except Exception:
                    continue

            # 1c. Nobitex Market Stats (.net then .ir)
            for domain in ['api.nobitex.net', 'api.nobitex.ir']:
                try:
                    url = f"https://{domain}/market/stats"
                    res = await client.get(url, timeout=4.0, headers={'User-Agent': 'Mozilla/5.0'})
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
                    continue

            # 1d. Bitpin API (High availability across global networks)
            try:
                for b_domain in ['api.bitpin.org', 'api.bitpin.ir']:
                    try:
                        url_bitpin = f"https://{b_domain}/v1/mkt/markets/"
                        res = await client.get(url_bitpin, timeout=4.0, headers={'User-Agent': 'Mozilla/5.0'})
                        if res.status_code == 200:
                            b_data = res.json()
                            results = b_data.get('results', [])
                            for m in results:
                                code = m.get('code', '').upper().replace('_', '').replace('-', '')
                                if code in [sym, nobitex_sym, 'USDTIRT', 'USDTTMN']:
                                    p = m.get('price')
                                    if p:
                                        return float(p)
                            break
                    except Exception:
                        continue
            except Exception:
                pass

            # 1e. Wallex API
            try:
                url = "https://api.wallex.ir/v1/markets"
                res = await client.get(url, timeout=4.0, headers={'User-Agent': 'Mozilla/5.0'})
                if res.status_code == 200:
                    data = res.json()
                    if 'result' in data and 'symbols' in data['result']:
                        symbols = data['result']['symbols']
                        for s_key, s_data in symbols.items():
                            if s_key.upper().replace('-', '') == sym or s_key.upper() == sym:
                                return float(s_data['stats']['lastPrice'])
            except Exception:
                pass

            # 1f. Tetherland API (Direct Tether / Toman rate)
            if sym in ['USDTTMN', 'USDTIRT', 'USDT']:
                try:
                    url_tetherland = "https://api.tetherland.com/currencies"
                    res = await client.get(url_tetherland, timeout=4.0, headers={'User-Agent': 'Mozilla/5.0'})
                    if res.status_code == 200:
                        t_data = res.json()
                        if 'data' in t_data and 'currencies' in t_data['data'] and 'USDT' in t_data['data']['currencies']:
                            usdt_info = t_data['data']['currencies']['USDT']
                            price = usdt_info.get('price') or usdt_info.get('last_price')
                            if price:
                                return float(price)
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

        # 3. GLOBAL CRYPTO (Binance, MEXC, KuCoin, Gate.io, OKX, CoinEx, etc.)
        crypto_sym = sym
        if not crypto_sym.endswith('USDT') and not crypto_sym.endswith('BUSD') and not crypto_sym.endswith('BTC') and not crypto_sym.endswith('USDC'):
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

        # Try KuCoin
        try:
            url = f"https://api.kucoin.com/api/v1/market/orderbook/level1?symbol={crypto_sym[:-4]}-USDT"
            res = await client.get(url, timeout=4.0)
            if res.status_code == 200:
                data = res.json()
                if 'data' in data and 'price' in data['data']:
                    return float(data['data']['price'])
        except Exception:
            pass

        # Try Gate.io
        try:
            url = f"https://api.gateio.ws/api/v4/spot/tickers?currency_pair={crypto_sym[:-4]}_USDT"
            res = await client.get(url, timeout=4.0)
            if res.status_code == 200:
                data = res.json()
                if data and len(data) > 0 and 'last' in data[0]:
                    return float(data[0]['last'])
        except Exception:
            pass

        # Try CoinEx
        try:
            url = f"https://api.coinex.com/v1/market/ticker?market={crypto_sym}"
            res = await client.get(url, timeout=4.0)
            if res.status_code == 200:
                data = res.json()
                if 'data' in data and 'ticker' in data['data'] and 'last' in data['data']['ticker']:
                    return float(data['data']['ticker']['last'])
        except Exception:
            pass

    except Exception as e:
        print(f"⚠️ [Worker] Unable to resolve price for {symbol} on {exchange} ({e})")

    return None

# -------------------------------------------------------------------
# 5. Direct FCM High-Priority Notification Engine
# -------------------------------------------------------------------
def get_exchange_display_name(exchange_id: str) -> str:
    ex = (exchange_id or '').lower()
    mapping = {
        'nobitex': 'Nobitex',
        'wallex': 'Wallex',
        'binance': 'Binance',
        'tabdeal': 'Tabdeal',
        'ramzinex': 'Ramzinex',
        'kucoin': 'KuCoin',
        'mexc': 'MEXC',
        'gateio': 'Gate.io',
        'gate': 'Gate.io',
        'coinex': 'CoinEx',
        'okx': 'OKX',
        'bybit': 'Bybit',
        'bitbarg': 'BitBarg',
        'tetherland': 'Tetherland',
        'abantether': 'AbanTether',
        'global_stocks': 'Global Stocks',
        'stocks': 'Stocks',
        'forex': 'Forex',
        'macro': 'Macro',
        'bonds': 'Bonds',
        'wallstreet': 'Wall Street',
        'iran_market': 'Iran Market'
    }
    return mapping.get(ex, exchange_id.capitalize() if exchange_id else 'Unknown')

def send_fcm_notification(fcm_token: str, title: str, body: str, data_payload: dict = None) -> tuple[bool, str]:
    if not firebase_admin._apps:
        return False, "Firebase Admin SDK is not initialized."
    if not fcm_token:
        return False, "FCM token is empty."
    if fcm_token.startswith('dev_') or fcm_token.startswith('device_token_') or len(fcm_token) < 40:
        return False, f"Token '{fcm_token}' is a local device ID, not a Google FCM registration token."
    try:
        full_data = {
            "title": str(title),
            "body": str(body),
            **(data_payload or {})
        }
        # Ensure all data values are string format for FCM protocol
        full_data_str = {k: str(v) if v is not None else "" for k, v in full_data.items()}

        message = messaging.Message(
            data=full_data_str,
            token=fcm_token,
            android=messaging.AndroidConfig(
                priority='high',
                ttl=timedelta(days=1),
                direct_boot_ok=True
            ),
            apns=messaging.APNSConfig(
                payload=messaging.APNSPayload(
                    aps=messaging.Aps(
                        content_available=True,
                        badge=1
                    )
                )
            )
        )
        response = messaging.send(message)
        print(f"🚀 FCM High-Priority Data Push Sent: {response}")
        return True, f"FCM Message ID: {response}"
    except Exception as e:
        print(f"❌ FCM Push Error: {e}")
        return False, str(e)

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
            # Check cooldown and one-shot vs recurring trigger behavior
            last_trig = getattr(alert, 'last_triggered_at', 0.0)
            is_one_shot = getattr(alert, 'trigger_mode', 'oneShot') == 'oneShot'

            # For oneShot, only fire once and deactivate so it never spams continuously
            # For recurring, enforce at least 60s cooldown (or alert's interval if longer)
            min_cooldown = max(60.0, float(alert.check_interval_seconds))
            if is_one_shot or (current_time - last_trig) >= min_cooldown:
                print(f"🔔 [ALERT TRIGGERED & FCM PUSH SENT] {alert.symbol} @ {current_price} (Target: {alert.target_price})")

                # Format standardized uniform Title & Body matching applet design
                is_above = alert.condition.upper() == 'ABOVE'
                emoji = '🟢' if is_above else '🔴'
                arrow = '▲' if is_above else '▼'
                sign = '+' if is_above else '-'

                if alert.target_price > 0:
                    pct_diff = abs(((current_price - alert.target_price) / alert.target_price) * 100.0)
                    pct_str = f"{sign}{pct_diff:.2f}%"
                else:
                    pct_str = ""

                price_formatted = f"${current_price:,.4f}".rstrip('0').rstrip('.') if current_price < 1 else f"${current_price:,.2f}"
                if alert.symbol.endswith('TMN') or alert.symbol.endswith('IRT'):
                    price_formatted = f"{int(current_price):,} TMN"

                display_symbol = alert.symbol
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

                send_fcm_notification(
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
                alert.last_triggered_at = current_time
                if is_one_shot:
                    alert.is_active = False # Deactivate one-shot alert after trigger so it doesn't repeat!
                updated = True

    if updated:
        save_alerts_to_disk(ALERTS_DB)

# -------------------------------------------------------------------
# 7. Endpoints
# -------------------------------------------------------------------
@app.on_event("startup")
async def startup_event():
    scheduler.add_job(
        check_alerts_job,
        'interval',
        seconds=2,
        max_instances=5,
        coalesce=True,
        misfire_grace_time=15
    )
    scheduler.start()
    print("🚀 SignalAlert Enterprise Engine Online (2s High-Performance Precision Scheduler).")

@app.api_route("/", methods=["GET", "HEAD"])
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
@app.post("/alerts", response_model=Alert)
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
        trigger_mode=alert_in.trigger_mode or "oneShot",
        sound_enabled=alert_in.sound_enabled,
        vibration_enabled=alert_in.vibration_enabled,
        tts_enabled=alert_in.tts_enabled,
        sound=alert_in.sound or "alarm_siren",
        is_active=True,
        created_at=datetime.utcnow().isoformat(),
        last_checked_at=0.0,
        last_triggered_at=0.0
    )
    ALERTS_DB.append(new_alert)
    save_alerts_to_disk(ALERTS_DB)
    print(f"📩 [API] New Alert Created: {new_alert.symbol} ({new_alert.exchange}) | Target: {new_alert.target_price} | Interval: {new_alert.check_interval_seconds}s")
    return new_alert

@app.post("/api/alerts/sync")
@app.post("/alerts/sync")
def sync_user_alerts(payload: dict):
    global ALERTS_DB
    user_id = payload.get('user_id', 'user_default')
    fcm_token = payload.get('fcm_token', '')
    alerts_data = payload.get('alerts', [])
    
    # Map existing alerts to preserve trigger timestamps & state
    existing_map = {a.id: a for a in ALERTS_DB if (a.user_id == user_id or a.fcm_token == fcm_token)}

    # Remove old alerts for this user or matching this device FCM token
    if fcm_token and len(fcm_token) > 10:
        ALERTS_DB = [a for a in ALERTS_DB if (a.user_id != user_id and a.fcm_token != fcm_token)]
    else:
        ALERTS_DB = [a for a in ALERTS_DB if a.user_id != user_id]
    
    added_count = 0
    for item in alerts_data:
        rule_id = item.get('id') or str(uuid.uuid4())
        existing = existing_map.get(rule_id)

        # Preserve last_triggered_at if existing, so sync doesn't reset cooldowns or trigger loops
        last_trig = existing.last_triggered_at if existing else 0.0
        last_chk = existing.last_checked_at if existing else 0.0
        
        # If the alert was deactivated on server (e.g. triggered oneShot), respect server deactivation!
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
            check_interval_seconds=int(item.get('check_interval_seconds', 10)),
            note=item.get('note'),
            trigger_mode=item.get('trigger_mode', 'oneShot'),
            sound_enabled=bool(item.get('sound_enabled', True)),
            vibration_enabled=bool(item.get('vibration_enabled', True)),
            tts_enabled=bool(item.get('tts_enabled', True)),
            sound=item.get('sound', 'alarm_siren'),
            is_active=is_act,
            created_at=item.get('created_at') or datetime.utcnow().isoformat(),
            last_checked_at=last_chk,
            last_triggered_at=last_trig
        )
        ALERTS_DB.append(alert_obj)
        added_count += 1
        
    save_alerts_to_disk(ALERTS_DB)
    print(f"🔄 [API] Bulk Synced {added_count} alert(s) for user {user_id} with FCM token: {fcm_token[:20] if fcm_token else 'none'}... (Total active remaining: {len([a for a in ALERTS_DB if a.is_active])})")
    return {"status": "synced", "count": added_count, "total_active": len([a for a in ALERTS_DB if a.is_active])}

@app.delete("/api/alerts")
@app.delete("/alerts")
def clear_all_alerts(user_id: Optional[str] = None, fcm_token: Optional[str] = None):
    global ALERTS_DB
    if fcm_token:
        ALERTS_DB = [a for a in ALERTS_DB if a.fcm_token != fcm_token]
    elif user_id:
        ALERTS_DB = [a for a in ALERTS_DB if a.user_id != user_id]
    else:
        ALERTS_DB = []
    save_alerts_to_disk(ALERTS_DB)
    print("🧹 [API] All alerts successfully purged from server.")
    return {"status": "cleared", "total_alerts": len(ALERTS_DB)}

@app.get("/api/alerts/{user_id}", response_model=List[Alert])
@app.get("/alerts/{user_id}", response_model=List[Alert])
def get_user_alerts(user_id: str):
    user_alerts = [a for a in ALERTS_DB if a.user_id == user_id]
    print(f"📖 [API] Fetching alerts for user {user_id}: {len(user_alerts)} alert(s) found.")
    return user_alerts

@app.delete("/api/alerts/{alert_id}")
@app.delete("/alerts/{alert_id}")
def delete_alert(alert_id: str):
    global ALERTS_DB
    ALERTS_DB = [a for a in ALERTS_DB if a.id != alert_id]
    save_alerts_to_disk(ALERTS_DB)
    print(f"🗑️ [API] Deleted Alert {alert_id}")
    return {"status": "deleted", "id": alert_id}

@app.get("/api/price/{exchange}/{symbol}")
@app.get("/price/{exchange}/{symbol}")
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

# -------------------------------------------------------------------
# 8. Powerful Deep Diagnostics & Debug Center API
# -------------------------------------------------------------------
RECENT_DIAGNOSTICS: List[Dict] = []

@app.get("/api/debug/inspect/{exchange}/{symbol}")
@app.get("/debug/inspect/{exchange}/{symbol}")
async def inspect_market_source(exchange: str, symbol: str):
    """Deeply tests and traces every single API endpoint for a specific symbol & exchange."""
    start_time = time.time()
    ex = exchange.lower()
    sym = symbol.upper().replace('/', '').replace(' ', '')
    crypto_sym = sym
    if not crypto_sym.endswith('USDT') and not crypto_sym.endswith('BUSD') and not crypto_sym.endswith('BTC') and not crypto_sym.endswith('USDC'):
        crypto_sym = crypto_sym + 'USDT'
    traces = []
    final_price = None

    async with httpx.AsyncClient() as client:
        # Test 1: Iranian Exchanges (Tabdeal, Nobitex, Bitpin, Wallex)
        if ex in ['tabdeal', 'nobitex', 'wallex', 'bitpin', 'tetherland', 'abantether', 'ramzinex', 'bitbarg', 'sarmayex', 'exir'] or sym.endswith('TMN') or sym.endswith('IRT') or sym.endswith('RLS'):
            nobitex_sym = sym
            if sym in ['USDTTMN', 'USDTIRT', 'USDT', 'USDT-TMN', 'USDT-IRT']:
                nobitex_sym = 'USDTIRT'
            elif sym.endswith('TMN'):
                nobitex_sym = sym[:-3] + 'IRT'
            elif sym.endswith('IRT'):
                nobitex_sym = sym

            # Trace 1a: Tabdeal API
            url_tabdeal = "https://api.tabdeal.org/r/plots/market/information"
            t0 = time.time()
            try:
                res = await client.get(url_tabdeal, timeout=4.0, headers={'User-Agent': 'Mozilla/5.0'})
                latency = round((time.time() - t0) * 1000, 2)
                if res.status_code == 200:
                    data = res.json()
                    p_tabdeal = None
                    for t_key, t_val in data.items():
                        clean_t = t_key.upper().replace('_', '').replace('-', '')
                        if clean_t in [sym, nobitex_sym, 'USDTTMN', 'USDTIRT']:
                            if isinstance(t_val, dict) and 'price' in t_val:
                                p_tabdeal = float(t_val['price'])
                            elif isinstance(t_val, dict) and 'last_price' in t_val:
                                p_tabdeal = float(t_val['last_price'])
                            if p_tabdeal: break
                    if p_tabdeal:
                        traces.append({'source': 'Tabdeal Spot API', 'url': url_tabdeal, 'status_code': 200, 'latency_ms': latency, 'parsed_price': p_tabdeal, 'success': True})
                        if not final_price: final_price = p_tabdeal
                    else:
                        traces.append({'source': 'Tabdeal Spot API', 'url': url_tabdeal, 'status_code': 200, 'latency_ms': latency, 'error': f'Symbol {sym} not found in Tabdeal', 'success': False})
                else:
                    traces.append({'source': 'Tabdeal Spot API', 'url': url_tabdeal, 'status_code': res.status_code, 'latency_ms': latency, 'error': f'HTTP {res.status_code}', 'success': False})
            except Exception as e:
                traces.append({'source': 'Tabdeal Spot API', 'url': url_tabdeal, 'status_code': 0, 'latency_ms': round((time.time() - t0) * 1000, 2), 'error': str(e), 'success': False})

            # Trace 1b: Nobitex Orderbook (Try .net and .ir)
            for domain, label in [('api.nobitex.net', 'Nobitex Global Net'), ('api.nobitex.ir', 'Nobitex Local IR')]:
                url = f"https://{domain}/v2/orderbook/{nobitex_sym}"
                t0 = time.time()
                try:
                    res = await client.get(url, timeout=4.0, headers={'User-Agent': 'Mozilla/5.0'})
                    latency = round((time.time() - t0) * 1000, 2)
                    if res.status_code == 200:
                        data = res.json()
                        if 'bids' in data and len(data['bids']) > 0:
                            p = float(data['bids'][0][0])
                            traces.append({'source': f'{label} Orderbook', 'url': url, 'status_code': 200, 'latency_ms': latency, 'parsed_price': p, 'success': True})
                            if not final_price: final_price = p
                        else:
                            traces.append({'source': f'{label} Orderbook', 'url': url, 'status_code': 200, 'latency_ms': latency, 'error': 'No bids array in JSON', 'success': False})
                    else:
                        traces.append({'source': f'{label} Orderbook', 'url': url, 'status_code': res.status_code, 'latency_ms': latency, 'error': f'HTTP {res.status_code}', 'success': False})
                except Exception as e:
                    traces.append({'source': f'{label} Orderbook', 'url': url, 'status_code': 0, 'latency_ms': round((time.time() - t0) * 1000, 2), 'error': str(e), 'success': False})

            # Test 1b: Nobitex Market Stats
            # Trace 1c: Bitpin API
            url_bitpin = "https://api.bitpin.org/v1/mkt/markets/"
            t0 = time.time()
            try:
                res = await client.get(url_bitpin, timeout=4.0, headers={'User-Agent': 'Mozilla/5.0'})
                latency = round((time.time() - t0) * 1000, 2)
                if res.status_code == 200:
                    b_data = res.json()
                    p_bitpin = None
                    for m in b_data.get('results', []):
                        code = m.get('code', '').upper().replace('_', '').replace('-', '')
                        if code in [sym, nobitex_sym, 'USDTIRT', 'USDTTMN']:
                            if m.get('price'):
                                p_bitpin = float(m['price'])
                                break
                    if p_bitpin:
                        traces.append({'source': 'Bitpin Markets API', 'url': url_bitpin, 'status_code': 200, 'latency_ms': latency, 'parsed_price': p_bitpin, 'success': True})
                        if not final_price: final_price = p_bitpin
                    else:
                        traces.append({'source': 'Bitpin Markets API', 'url': url_bitpin, 'status_code': 200, 'latency_ms': latency, 'error': f'{sym} not found in Bitpin', 'success': False})
                else:
                    traces.append({'source': 'Bitpin Markets API', 'url': url_bitpin, 'status_code': res.status_code, 'latency_ms': latency, 'error': f'HTTP {res.status_code}', 'success': False})
            except Exception as e:
                traces.append({'source': 'Bitpin Markets API', 'url': url_bitpin, 'status_code': 0, 'latency_ms': round((time.time() - t0) * 1000, 2), 'error': str(e), 'success': False})

            # Test 1c: Wallex API
            url_wallex = "https://api.wallex.ir/v1/markets"
            t0 = time.time()
            try:
                res = await client.get(url_wallex, timeout=5.0, headers={'User-Agent': 'Mozilla/5.0'})
                latency = round((time.time() - t0) * 1000, 2)
                if res.status_code == 200:
                    data = res.json()
                    if 'result' in data and 'symbols' in data['result']:
                        found = False
                        for s_key, s_data in data['result']['symbols'].items():
                            if s_key.upper().replace('-', '') == sym or s_key.upper() == sym:
                                p = float(s_data['stats']['lastPrice'])
                                traces.append({'source': 'Wallex Markets', 'url': url_wallex, 'status_code': 200, 'latency_ms': latency, 'parsed_price': p, 'success': True})
                                if not final_price: final_price = p
                                found = True
                                break
                        if not found:
                            traces.append({'source': 'Wallex Markets', 'url': url_wallex, 'status_code': 200, 'latency_ms': latency, 'error': f'Symbol {sym} not found in Wallex symbols', 'success': False})
            except Exception as e:
                traces.append({'source': 'Wallex Markets', 'url': url_wallex, 'status_code': 0, 'latency_ms': round((time.time() - t0) * 1000, 2), 'error': str(e), 'success': False})

        # Test 2: Yahoo Finance (Stocks, Macro, Forex, Commodities)
        elif ex in ['global_stocks', 'stocks', 'macro', 'forex', 'bonds', 'wallstreet'] or '-' in sym or 'NYB' in sym or '10Y' in sym:
            yf_symbol = sym
            if 'DX-Y' in sym or 'DXY' in sym: yf_symbol = 'DX-Y.NYB'
            elif 'US10Y' in sym or '10Y' in sym or 'TNX' in sym: yf_symbol = '^TNX'
            elif 'EURUSD' in sym or 'EUR/USD' in sym: yf_symbol = 'EURUSD=X'
            elif 'GOLD' in sym or 'XAU' in sym: yf_symbol = 'GC=F'

            url = f"https://query1.finance.yahoo.com/v8/finance/chart/{yf_symbol}?interval=1m&range=1d"
            t0 = time.time()
            try:
                res = await client.get(url, timeout=5.0, headers={'User-Agent': 'Mozilla/5.0'})
                latency = round((time.time() - t0) * 1000, 2)
                if res.status_code == 200:
                    data = res.json()
                    if 'chart' in data and 'result' in data['chart'] and data['chart']['result']:
                        meta = data['chart']['result'][0]['meta']
                        price = meta.get('regularMarketPrice')
                        if price and float(price) > 0:
                            traces.append({'source': 'Yahoo Finance', 'url': url, 'status_code': 200, 'latency_ms': latency, 'parsed_price': float(price), 'success': True})
                            final_price = float(price)
                        else:
                            traces.append({'source': 'Yahoo Finance', 'url': url, 'status_code': 200, 'latency_ms': latency, 'error': 'Missing regularMarketPrice field', 'success': False})
                else:
                    traces.append({'source': 'Yahoo Finance', 'url': url, 'status_code': res.status_code, 'latency_ms': latency, 'error': f'HTTP {res.status_code}', 'success': False})
            except Exception as e:
                traces.append({'source': 'Yahoo Finance', 'url': url, 'status_code': 0, 'latency_ms': round((time.time() - t0) * 1000, 2), 'error': str(e), 'success': False})

        # Test 3: Crypto Gateways (Binance, MEXC, KuCoin, Gate.io, CoinEx)
        else:
            crypto_sym = sym
            if not crypto_sym.endswith('USDT') and not crypto_sym.endswith('BUSD') and not crypto_sym.endswith('BTC') and not crypto_sym.endswith('USDC'):
                crypto_sym = crypto_sym + 'USDT'

            # Binance Test
            url_bin = f"https://api.binance.com/api/v3/ticker/price?symbol={crypto_sym}"
            t0 = time.time()
            try:
                res = await client.get(url_bin, timeout=4.0)
                latency = round((time.time() - t0) * 1000, 2)
                if res.status_code == 200:
                    p = float(res.json()['price'])
                    traces.append({'source': 'Binance Spot', 'url': url_bin, 'status_code': 200, 'latency_ms': latency, 'parsed_price': p, 'success': True})
                    if not final_price: final_price = p
                else:
                    traces.append({'source': 'Binance Spot', 'url': url_bin, 'status_code': res.status_code, 'latency_ms': latency, 'error': f'HTTP {res.status_code}', 'success': False})
            except Exception as e:
                traces.append({'source': 'Binance Spot', 'url': url_bin, 'status_code': 0, 'latency_ms': round((time.time() - t0) * 1000, 2), 'error': str(e), 'success': False})

            # MEXC Test
            url_mexc = f"https://api.mexc.com/api/v3/ticker/price?symbol={crypto_sym}"
            t0 = time.time()
            try:
                res = await client.get(url_mexc, timeout=4.0)
                latency = round((time.time() - t0) * 1000, 2)
                if res.status_code == 200:
                    p = float(res.json()['price'])
                    traces.append({'source': 'MEXC Spot', 'url': url_mexc, 'status_code': 200, 'latency_ms': latency, 'parsed_price': p, 'success': True})
                    if not final_price: final_price = p
                else:
                    traces.append({'source': 'MEXC Spot', 'url': url_mexc, 'status_code': res.status_code, 'latency_ms': latency, 'error': f'HTTP {res.status_code}', 'success': False})
            except Exception as e:
                traces.append({'source': 'MEXC Spot', 'url': url_mexc, 'status_code': 0, 'latency_ms': round((time.time() - t0) * 1000, 2), 'error': str(e), 'success': False})

    elapsed_total = round((time.time() - start_time) * 1000, 2)

    report = {
        'status': 'OK' if final_price is not None else 'FAILED',
        'exchange': exchange,
        'symbol': symbol,
        'normalized_symbol': sym,
        'resolved_price': final_price,
        'total_duration_ms': elapsed_total,
        'timestamp': datetime.utcnow().isoformat(),
        'traces': traces,
        'recommendation': 'Price resolved successfully' if final_price else f'Unable to fetch {symbol} on {exchange}. Verify symbol format or check if market source is active.'
    }

    # Record in memory diagnostics
    RECENT_DIAGNOSTICS.insert(0, report)
    if len(RECENT_DIAGNOSTICS) > 50:
        RECENT_DIAGNOSTICS.pop()

    return report

@app.get("/api/debug/logs")
@app.get("/debug/logs")
def get_debug_logs():
    return {
        "count": len(RECENT_DIAGNOSTICS),
        "logs": RECENT_DIAGNOSTICS
    }

@app.get("/api/test/push")
@app.post("/api/test/push")
async def test_push_notification(fcm_token: Optional[str] = None, title: Optional[str] = None, body: Optional[str] = None):
    """
    Sends an instant verification test push notification to verify mobile app connectivity.
    Can be triggered via GET/POST /api/test/push or terminal CLI (test_push.py).
    """
    token_to_use = fcm_token
    if not token_to_use:
        # Check active alerts for recent real token
        for a in ALERTS_DB:
            if a.fcm_token and not any(k in a.fcm_token.lower() for k in ['sample', 'pending', 'device_token_']):
                token_to_use = a.fcm_token
                break

    test_title = title or "🔔 [SignalAlert Live Connection]"
    test_body = body or "✅ App is successfully connected to the server! Live push notification channel is online."

    if not token_to_use:
        return {
            "success": False,
            "error": "No real FCM device token found. Please open the mobile app or pass ?fcm_token=YOUR_TOKEN",
            "firebase_initialized": bool(firebase_admin._apps),
            "service_account_key_found": os.path.exists("serviceAccountKey.json"),
            "active_alerts_count": len(ALERTS_DB),
            "timestamp": datetime.utcnow().isoformat()
        }

    sent_ok, sent_msg = send_fcm_notification(
        fcm_token=token_to_use,
        title=test_title,
        body=test_body,
        data_payload={"type": "test_ping", "timestamp": str(time.time()), "source": "api_test_endpoint"}
    )

    return {
        "success": sent_ok,
        "details": sent_msg,
        "fcm_token_used": token_to_use,
        "firebase_initialized": bool(firebase_admin._apps),
        "service_account_key_found": os.path.exists("serviceAccountKey.json"),
        "title_sent": test_title,
        "body_sent": test_body,
        "timestamp": datetime.utcnow().isoformat()
    }

