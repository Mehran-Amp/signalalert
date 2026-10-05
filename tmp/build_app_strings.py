# -*- coding: utf-8 -*-
import json, re

# Complete 10-language dictionary builder for AppStrings
dart_content = '''/// Comprehensive Multilingual dictionary supporting 10 languages with exact RTL/LTR support.
class AppStrings {
  static bool isRtl(String lang) {
    return lang == 'fa' || lang == 'ar' || lang == 'ckb';
  }

  static String getArrow(String lang) {
    return isRtl(lang) ? '←' : '→';
  }

  static final Map<String, Map<String, String>> _translations = {
'''

# Let's define translation dictionaries for all 10 languages
# Languages: fa, en, ckb, ar, de, fr, es, tr, zh, ko

# We will populate all keys for every language accurately and fluently.
