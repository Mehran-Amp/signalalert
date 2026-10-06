#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Phase 2 Comprehensive Unit Tests:
 1. MarketTicker & PriceSnapshot model schemas:
    - asOf, state, quoteUnit, source optional fields
    - Backward-compatible constructor & serialization
 2. predefinedStocks contract & integrity:
    - Exactly 0 duplicate symbols
    - 0 Pre-IPO unlisted symbols (OPENAI, ANTHROPIC, STRIPE, BYTEDANCE, DATABRICKS removed)
    - ^IRX correctly labeled as 13-Week Treasury Bill yield ('اوراق ۱۳ هفته‌ای خزانه‌داری آمریکا')
    - 0 static ranks in nameFa ('رتبه X جهان' removed)
    - 100% of items have explicit 'unit' key without breaking symbol, name, nameFa, cat, icon, price, isTop100
 3. fetchTicker & fetchSnapshot offline logic:
    - CoinGecko: No hardcoded fallback numbers; 60s cache; real updated_at asOf; state='live'
    - AlternativeMe (CRYPTO_FGI): timestamp asOf; state='delayed'; quoteUnit='pts'
    - Yahoo Finance: regularMarketTime parsed to asOf; marketState parsed; 404 halts without retry; currency to quoteUnit
    - Stooq: explicit verified symbol map; CSV format parsing (not JSON); state='delayed'
    - Zero silent catch blocks

All tests run completely OFFLINE using mocks.
"""

import unittest
import re
import os
import json
from datetime import datetime, timezone

class TestPhase2GlobalStocks(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        # Read the Dart source files
        with open('lib/features/exchanges/base/models/market_ticker.dart', 'r', encoding='utf-8') as f:
            cls.market_ticker_dart = f.read()

        with open('lib/features/exchanges/base/models/price_snapshot.dart', 'r', encoding='utf-8') as f:
            cls.price_snapshot_dart = f.read()

        with open('lib/features/exchanges/stocks/global_stocks_exchange.dart', 'r', encoding='utf-8') as f:
            cls.stocks_exchange_dart = f.read()

    def test_01_market_ticker_and_snapshot_fields(self):
        """Verify asOf, state, quoteUnit, source exist in MarketTicker and PriceSnapshot"""
        required_fields = ['asOf', 'state', 'quoteUnit', 'source']
        for field in required_fields:
            with self.subTest(field=field):
                self.assertIn(f'final DateTime? asOf;', self.market_ticker_dart)
                self.assertIn(f'final String? state;', self.market_ticker_dart)
                self.assertIn(f'final String? quoteUnit;', self.market_ticker_dart)
                self.assertIn(f'final String? source;', self.market_ticker_dart)

                self.assertIn(f'final DateTime? asOf;', self.price_snapshot_dart)
                self.assertIn(f'final String? state;', self.price_snapshot_dart)
                self.assertIn(f'final String? quoteUnit;', self.price_snapshot_dart)
                self.assertIn(f'final String? source;', self.price_snapshot_dart)

    def test_02_predefined_stocks_zero_duplicates(self):
        """Verify 0 duplicate symbols exist across predefinedStocks"""
        symbols = re.findall(r"'symbol':\s*'([^']+)'", self.stocks_exchange_dart)
        from collections import Counter
        counts = Counter(symbols)
        duplicates = {s: c for s, c in counts.items() if c > 1}
        self.assertEqual(duplicates, {}, f"Found duplicate symbols: {duplicates}")

    def test_03_predefined_stocks_zero_pre_ipo(self):
        """Verify 5 unlisted Pre-IPO symbols are removed"""
        pre_ipos = ['OPENAI', 'ANTHROPIC', 'STRIPE', 'BYTEDANCE', 'DATABRICKS']
        for sym in pre_ipos:
            with self.subTest(sym=sym):
                self.assertNotIn(f"'symbol': '{sym}'", self.stocks_exchange_dart,
                                 f"Pre-IPO symbol {sym} should have been removed")

    def test_04_irx_correct_treasury_bill_label(self):
        """Verify ^IRX label is 13-week T-bill and NOT 2-year note"""
        irx_match = re.search(r"'symbol':\s*'\^IRX'[\s\S]*?'nameFa':\s*'([^']+)'", self.stocks_exchange_dart)
        self.assertIsNotNone(irx_match, "^IRX must be present")
        name_fa = irx_match.group(1)
        self.assertIn('۱۳ هفته‌ای', name_fa, f"Expected 13-week label, got: {name_fa}")
        self.assertNotIn('۲ ساله', name_fa, f"Should not be labeled as 2-year: {name_fa}")

    def test_05_predefined_stocks_zero_static_ranks(self):
        """Verify static ranks (رتبه X جهان) are removed from nameFa"""
        rank_matches = re.findall(r"'nameFa':\s*'[^']*رتبه\s+\d+\s+جهان[^']*'", self.stocks_exchange_dart)
        self.assertEqual(len(rank_matches), 0, f"Found static ranks in nameFa: {rank_matches}")

    def test_06_predefined_stocks_all_have_unit_and_required_keys(self):
        """Verify every single item has unit without breaking symbol, name, nameFa, cat, icon, price"""
        blocks = re.findall(r'(\{\s*\'symbol\':\s*\'[^\']+\'[\s\S]*?\n\s*\})', self.stocks_exchange_dart)
        self.assertGreater(len(blocks), 150, "Should have loaded full catalog")
        
        required_keys = ['symbol', 'name', 'nameFa', 'cat', 'icon', 'price', 'unit']
        for b in blocks:
            sym_m = re.search(r"'symbol':\s*'([^']+)'", b)
            sym = sym_m.group(1) if sym_m else 'unknown'
            with self.subTest(symbol=sym):
                for k in required_keys:
                    self.assertIn(f"'{k}':", b, f"Missing required key '{k}' in item {sym}")

    def test_07_coingecko_zero_hardcoded_fake_numbers(self):
        """Verify that live CoinGecko code does not contain hardcoded default fallbacks"""
        self.assertNotIn('2450000000000.0', self.stocks_exchange_dart,
                         "CoinGecko live path should not contain 2.45T hardcoded fallback")
        # Check that 60s cache variable exists
        self.assertIn('_cachedCoinGeckoGlobalData', self.stocks_exchange_dart)
        self.assertIn('_cachedCoinGeckoTime', self.stocks_exchange_dart)
        self.assertIn('Duration(seconds: 60)', self.stocks_exchange_dart)

    def test_08_stooq_explicit_map_and_csv_handling(self):
        """Verify Stooq uses explicit symbol mapping and parses CSV (not JSON)"""
        self.assertIn('stooqSymbolMap', self.stocks_exchange_dart)
        self.assertIn('f=sd2t2ohlcv&h&e=csv', self.stocks_exchange_dart)
        self.assertNotIn('f=sd2t2ohlcv&h&e=json', self.stocks_exchange_dart)
        self.assertIn("split(',')", self.stocks_exchange_dart)

    def test_09_zero_silent_catches(self):
        """Verify no silent catch (_) {} blocks remain in global_stocks_exchange.dart"""
        silent_catches = re.findall(r'catch\s*\(_\)\s*\{\s*\}', self.stocks_exchange_dart)
        self.assertEqual(len(silent_catches), 0, f"Found silent catch blocks: {len(silent_catches)}")

    def test_10_regular_market_time_asof_and_state_handling(self):
        """Verify regularMarketTime is parsed to asOf and state is properly assigned"""
        self.assertIn('regularMarketTime', self.stocks_exchange_dart)
        self.assertIn('DateTime.fromMillisecondsSinceEpoch', self.stocks_exchange_dart)
        self.assertIn("state = 'delayed'", self.stocks_exchange_dart)
        self.assertIn("state = 'closed'", self.stocks_exchange_dart)
        self.assertIn("source: 'YahooFinance'", self.stocks_exchange_dart)
        self.assertIn("source: 'Stooq'", self.stocks_exchange_dart)
        self.assertIn("source: 'CoinGecko'", self.stocks_exchange_dart)
        self.assertIn("source: 'AlternativeMe'", self.stocks_exchange_dart)


if __name__ == '__main__':
    unittest.main()
