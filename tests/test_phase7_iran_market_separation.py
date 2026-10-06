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
        self.assertIn('_buildIranCryptoPairPicker', content)
        self.assertIn('_onIranDomesticAssetChosen', content)
        self.assertIn('_onIranExchangeChosen', content)

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

        # Key symbols check
        symbols = ['GERAM18', 'GERAM24', 'MESGHAL', 'COIN_EMAMI', 'COIN_BAHAR', 'USD_TMN', 'EUR_TMN', 'AED_TMN', 'SANA_USD', 'TEDPIX']
        for sym in symbols:
            self.assertIn(f"'{sym}'", content, f"Symbol {sym} must be present in IranDomesticExchange")

    def test_server_iran_cache_ttl_60s(self):
        with open('server.py', 'r') as f:
            content = f.read()

        # Check 60-second strict cache
        self.assertIn('CACHE_TTL_IRAN = 60.0', content)
        self.assertIn('TGJU_MAP', content)
        self.assertIn('price_dollar_rl', content)
        self.assertIn('geram18', content)
        self.assertIn('sekee', content)

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

if __name__ == '__main__':
    unittest.main()
