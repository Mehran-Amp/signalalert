import unittest
import json
import os
import re

class TestIranMarketSeparation(unittest.TestCase):
    def test_iran_market_in_create_alert_flow(self):
        with open('lib/features/watchlist/pages/create_alert_flow.dart', 'r') as f:
            content = f.read()

        # Check MarketFlowType includes iran
        self.assertIn('MarketFlowType.iran', content)
        self.assertIn('_buildIranMarketPicker', content)
        self.assertIn('_onIranDomesticAssetChosen', content)

    def test_international_crypto_excludes_iranian_exchanges(self):
        with open('lib/features/watchlist/pages/create_alert_flow.dart', 'r') as f:
            content = f.read()

        # Check international crypto picker filters out Iranian exchanges
        self.assertIn('iranExchangeIds', content)
        self.assertIn('nobitex', content)
        self.assertIn('wallex', content)

    def test_iran_domestic_exchange_symbols(self):
        with open('lib/features/exchanges/stocks/iran_domestic_exchange.dart', 'r') as f:
            content = f.read()

        # Key symbols check including Bonbast (Gold & FX), TSETMC (Indices & Gold Funds), ICE, Tether & Digital Gold
        symbols = [
            'GERAM18', 'GERAM24', 'MESGHAL', 'COIN_EMAMI', 'COIN_BAHAR',
            'USD_TMN', 'EUR_TMN', 'AED_TMN', 'SANA_USD', 'TEDPIX',
            'AYAR', 'TALA', 'ZAR', 'KAHROBA', 'GOHAR',
            'ICE_USD_CASH', 'ICE_USD_REMIT',
            'USDT_NOBITEX', 'USDT_WALLEX', 'USDT_TABDEAL', 'USDT_TETHERLAND',
            'GOLD_NOBITEX', 'GOLD_WALLEX', 'GOLD_TABDEAL'
        ]
        for sym in symbols:
            self.assertIn(f"'{sym}'", content, f"Symbol {sym} must be present in IranDomesticExchange")

    def test_server_iran_sources_and_cache_ttl_60s(self):
        with open('server.py', 'r') as f:
            content = f.read()

        # Check 60-second strict cache and new legal source maps
        self.assertIn('CACHE_TTL_IRAN = 60.0', content)
        self.assertIn('BONBAST_MAP', content)
        self.assertIn('TSETMC_INDEX_MAP', content)
        self.assertIn('TSETMC_GOLD_FUNDS_MAP', content)
        self.assertIn('ICE_MAP', content)
        self.assertIn('bonbast.com', content)
        self.assertIn('cdn.tsetmc.com', content)

        # Assure TGJU is completely removed
        self.assertNotIn('TGJU_MAP', content)
        self.assertNotIn('tgju.org', content)

    def test_app_strings_translations(self):
        with open('lib/core/localization/app_strings.dart', 'r') as f:
            content = f.read()

        # Check Persian keys
        self.assertIn('iran_market_title', content)
        self.assertIn('iran_subtab_domestic', content)
        self.assertIn('iran_subtab_crypto', content)
        self.assertIn('iran_cat_gold', content)
        self.assertIn('iran_cat_coins', content)
        self.assertIn('iran_cat_currencies', content)
        self.assertIn('iran_cat_gold_funds', content)

    def test_persian_rtl_and_format_utils(self):
        with open('lib/features/watchlist/pages/create_alert_flow.dart', 'r') as f:
            content = f.read()

        # Check strict RTL directionality for Iran Market
        self.assertIn('TextDirection.rtl', content)
        self.assertIn('FormatUtils.formatIranPrice', content)
        self.assertIn('FormatUtils.normalizePersianDigits', content)

        with open('lib/core/utils/format_utils.dart', 'r') as f:
            fmt_content = f.read()

        self.assertIn('toPersianDigits', fmt_content)
        self.assertIn('normalizePersianDigits', fmt_content)
        self.assertIn('formatIranPrice', fmt_content)
        self.assertIn('formatAlertCardPrice', fmt_content)

if __name__ == '__main__':
    unittest.main()
