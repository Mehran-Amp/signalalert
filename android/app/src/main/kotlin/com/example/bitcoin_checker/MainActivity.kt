package com.example.bitcoin_checker

import android.content.Context
import android.os.Bundle
import android.speech.tts.TextToSpeech
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

/**
 * Main Activity for Alarmer.
 * Handles App Lifecycle, Background Minification, Widget State, and Native Text-To-Speech (TTS).
 */
class MainActivity : FlutterActivity(), TextToSpeech.OnInitListener {
    private val CHANNEL = "com.example.bitcoin_checker/app_lifecycle"
    private var tts: TextToSpeech? = null
    private var isTtsReady = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        try {
            tts = TextToSpeech(applicationContext, this)
        } catch (_: Exception) {}
    }

    override fun onInit(status: Int) {
        if (status == TextToSpeech.SUCCESS) {
            isTtsReady = true
            tts?.language = Locale.US
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "speak" -> {
                    val text = call.argument<String>("text") ?: ""
                    val langCode = call.argument<String>("lang") ?: "en"
                    val rate = call.argument<Double>("rate") ?: 1.0
                    val pitch = call.argument<Double>("pitch") ?: 1.0

                    if (tts == null) {
                        try {
                            tts = TextToSpeech(applicationContext) { initStatus ->
                                if (initStatus == TextToSpeech.SUCCESS) {
                                    isTtsReady = true
                                    performSpeak(text, langCode, rate.toFloat(), pitch.toFloat())
                                }
                            }
                        } catch (_: Exception) {}
                    } else {
                        performSpeak(text, langCode, rate.toFloat(), pitch.toFloat())
                    }
                    result.success(true)
                }
                "stopSpeak" -> {
                    try {
                        tts?.stop()
                    } catch (_: Exception) {}
                    result.success(true)
                }
                "sendToBackground" -> {
                    val moved = moveTaskToBack(true)
                    result.success(moved)
                }
                "updateWidgetList" -> {
                    val json = call.argument<String>("json") ?: ""
                    val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                    prefs.edit()
                        .putString("flutter.widget_alerts_json", json)
                        .apply()

                    AlarmerAppWidgetProvider.updateAllWidgets(this)
                    result.success(true)
                }
                "updateWidget" -> {
                    val symbol = call.argument<String>("symbol") ?: "BTC/USDT"
                    val price = call.argument<String>("price") ?: "$87,420.00"
                    val change = call.argument<String>("change") ?: "+3.52% ▲"
                    val exchange = call.argument<String>("exchange") ?: "Binance • Live"
                    val status = call.argument<String>("status") ?: "⚡ Active Alerts Monitored"

                    val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                    prefs.edit()
                        .putString("flutter.widget_symbol", symbol)
                        .putString("flutter.widget_price", price)
                        .putString("flutter.widget_change", change)
                        .putString("flutter.widget_exchange", exchange)
                        .putString("flutter.widget_status", status)
                        .apply()

                    AlarmerAppWidgetProvider.updateAllWidgets(this)
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun performSpeak(text: String, langCode: String, rate: Float, pitch: Float) {
        if (text.isEmpty()) return
        try {
            val locale = when (langCode.lowercase()) {
                "fa" -> Locale("fa", "IR")
                "ar" -> Locale("ar", "SA")
                "de" -> Locale.GERMAN
                "fr" -> Locale.FRENCH
                "es" -> Locale("es", "ES")
                "tr" -> Locale("tr", "TR")
                "zh" -> Locale.CHINESE
                "ru" -> Locale("ru", "RU")
                "ckb" -> Locale("ar", "IQ")
                else -> Locale.US
            }

            tts?.setSpeechRate(rate)
            tts?.setPitch(pitch)

            val langResult = tts?.setLanguage(locale)
            if (langResult == TextToSpeech.LANG_MISSING_DATA || langResult == TextToSpeech.LANG_NOT_SUPPORTED) {
                // Fallback to English if device does not have target locale pack installed
                tts?.setLanguage(Locale.US)
            }

            tts?.speak(text, TextToSpeech.QUEUE_FLUSH, null, "AlarmerSpeech_${System.currentTimeMillis()}")
        } catch (_: Exception) {}
    }

    override fun onDestroy() {
        try {
            tts?.stop()
            tts?.shutdown()
        } catch (_: Exception) {}
        super.onDestroy()
    }

    override fun onBackPressed() {
        moveTaskToBack(true)
    }
}
