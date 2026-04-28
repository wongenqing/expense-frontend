package com.example.expensetracker_app

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {

    private val CHANNEL = "widget_channel"
    private var methodChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        methodChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        )

        methodChannel?.setMethodCallHandler { call, result ->
            if (call.method == "getLaunchAction") {
                val openVoice = intent?.getBooleanExtra("openVoice", false) ?: false
                result.success(openVoice)
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)

        val openVoice = intent.getBooleanExtra("openVoice", false)

        if (openVoice) {
            methodChannel?.invokeMethod("onWidgetClicked", true)
        }
    }
}