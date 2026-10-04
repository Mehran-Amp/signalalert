#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
SignalAlert Instant Push Notification Terminal CLI Tester
Usage:
    python test_push.py
    python test_push.py "App is connected to server 🚀"
    python test_push.py "My Title" "My Body Message"
"""

import sys
import os
import json
import time
from datetime import datetime

print("\n" + "="*60)
print("🚀 SignalAlert Terminal Push Notification Tester")
print("="*60 + "\n")

# 1. Check serviceAccountKey.json
if not os.path.exists("serviceAccountKey.json"):
    print("❌ ERROR: 'serviceAccountKey.json' not found in current directory!")
    print("👉 Please place your Firebase serviceAccountKey.json in this folder.")
    sys.exit(1)

# 2. Initialize Firebase Admin SDK
try:
    import firebase_admin
    from firebase_admin import credentials, messaging

    if not firebase_admin._apps:
        cred = credentials.Certificate("serviceAccountKey.json")
        firebase_admin.initialize_app(cred)
    print("✅ Firebase Admin SDK Initialized Successfully.")
except Exception as e:
    print(f"❌ Failed to initialize Firebase Admin: {e}")
    sys.exit(1)

# 3. Find Device FCM Token
target_token = None
alerts_file = "alerts_data.json"

if os.path.exists(alerts_file):
    try:
        with open(alerts_file, "r", encoding="utf-8") as f:
            alerts = json.load(f)
            for a in alerts:
                tok = a.get("fcm_token", "")
                if tok and not any(k in tok.lower() for k in ["sample", "pending", "device_token_"]):
                    target_token = tok
                    print(f"📱 Found Real Device FCM Token from Alert DB: {tok[:14]}...{tok[-6:]}")
                    break
    except Exception as e:
        print(f"⚠️ Error reading alerts_data.json: {e}")

if not target_token and len(sys.argv) > 3:
    target_token = sys.argv[3]

if not target_token:
    print("⚠️ No real device FCM token found in alerts_data.json.")
    print("👉 Pass your token as an argument or open the SignalAlert app on your phone so it registers its FCM token with the server.")
    print("\nSyntax: python test_push.py \"Title\" \"Body\" \"FCM_TOKEN\"\n")
    sys.exit(1)

# 4. Determine Title & Body
title = "🔔 [SignalAlert Live Connection]"
body = "✅ App is connected to server! Live Push Channel Active."

if len(sys.argv) == 2:
    body = sys.argv[1]
elif len(sys.argv) >= 3:
    title = sys.argv[1]
    body = sys.argv[2]

print(f"\n📤 Sending Test Notification:")
print(f"   • Title: {title}")
print(f"   • Body:  {body}")
print(f"   • Time:  {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")

# 5. Dispatch High-Priority Push via FCM
try:
    message = messaging.Message(
        notification=messaging.Notification(
            title=title,
            body=body
        ),
        data={
            "type": "test_ping",
            "timestamp": str(time.time()),
            "source": "terminal_cli_test"
        },
        token=target_token,
        android=messaging.AndroidConfig(
            priority="high",
            ttl=0,
            notification=messaging.AndroidNotification(
                sound="default",
                channel_id="alarmer_critical_price_alerts",
                priority="max",
                visibility="public",
                default_sound=True,
                default_vibrate_timings=True,
                default_light_settings=True
            )
        ),
        apns=messaging.APNSConfig(
            payload=messaging.APNSPayload(
                aps=messaging.Aps(
                    sound="default",
                    badge=1,
                    interruption_level="time-sensitive"
                )
            )
        )
    )

    response = messaging.send(message)
    print("\n" + "="*60)
    print(f"🎉 SUCCESS! Push notification sent successfully.")
    print(f"📨 FCM Message ID: {response}")
    print("📲 Check your phone's lock screen right now!")
    print("="*60 + "\n")

except Exception as e:
    print("\n" + "="*60)
    print(f"❌ FCM Push Delivery Failed: {e}")
    print("="*60 + "\n")
    sys.exit(1)
