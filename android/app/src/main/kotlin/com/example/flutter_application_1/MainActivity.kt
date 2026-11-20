package com.example.flutter_application_1

import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.view.KeyEvent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel

/**
 * Wanur Glove: logger event keypad.
 *
 * Keypad glove terhubung sebagai keyboard Bluetooth (HID), jadi tekanannya langsung
 * masuk ke WebView game. Activity.dispatchKeyEvent adalah titik masuk pertama semua
 * key event ke window, jadi di sini event disalin ke Flutter lewat EventChannel
 * "wanur/key_events", lalu SELALU diteruskan ke super.dispatchKeyEvent supaya game
 * menerima event tanpa perubahan.
 */
class MainActivity : FlutterActivity() {
    private var keyEventSink: EventChannel.EventSink? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, KEY_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    keyEventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    keyEventSink = null
                }
            })
    }

    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        try {
            forwardToFlutter(event)
        } catch (_: Throwable) {
            // Logging tidak boleh mengganggu alur event ke game.
        }
        return super.dispatchKeyEvent(event)
    }

    private fun forwardToFlutter(event: KeyEvent) {
        val sink = keyEventSink ?: return
        val action = when (event.action) {
            KeyEvent.ACTION_DOWN -> "down"
            KeyEvent.ACTION_UP -> "up"
            else -> return
        }
        // Abaikan auto-repeat (tombol ditahan) untuk key-down.
        if (event.action == KeyEvent.ACTION_DOWN && event.repeatCount > 0) return

        val code = event.unicodeChar
        val char = if (code != 0) String(Character.toChars(code)).lowercase() else ""

        // event.eventTime memakai jam uptimeMillis (sejak boot). Untuk penyimpanan
        // dibutuhkan waktu dinding (epoch ms), jadi dikonversi di sini.
        val wallTimeMs = System.currentTimeMillis() - (SystemClock.uptimeMillis() - event.eventTime)

        val payload = hashMapOf<String, Any>(
            "char" to char,
            "keyCode" to event.keyCode,
            "action" to action,
            "eventTime" to event.eventTime,
            "wallTimeMs" to wallTimeMs,
            "deviceId" to event.deviceId,
        )
        mainHandler.post { keyEventSink?.success(payload) }
    }

    companion object {
        private const val KEY_CHANNEL = "wanur/key_events"
    }
}
