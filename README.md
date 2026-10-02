# BitcoinChecker

A production-grade, local-first real-time financial market alert app in Flutter.

## Architecture Highlights
- **State Management**: BLoC pattern (`flutter_bloc`) with strict event-driven state transitions.
- **Data Ingestion**: Modular Multi-Exchange Adapter pattern inspired by `aneonex/BitcoinChecker` (Binance, Coinbase, Kraken, OKX, CoinGecko).
- **Rule Evaluator**: Dedicated Dart background isolate using a fixed-size `CircularTickBuffer` (RingBuffer) for sub-35MB RAM footprint across variable time windows.
- **Persistence**: Local-first `Isar` NoSQL database; opened independently per isolate.
- **Alert Cooldown**: Strict 3-minute suppression window preventing notification storms.
- **Background & Notifications**:
  - Android 14+: `flutter_background_service` declared as `FOREGROUND_SERVICE_DATA_SYNC` with `dataSync` foreground service type and Doze mode exemption.
  - iOS: Time-Sensitive notifications (`interruptionLevel: timeSensitive`) bypassing Focus modes without special entitlements.
- **Store Target**: Fully compliant for release on Google Play and Apple App Store.
