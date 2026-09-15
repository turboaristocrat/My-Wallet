package com.mywallet.my_wallet

import android.content.Intent
import android.provider.Settings
import androidx.core.app.NotificationManagerCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val METHOD_CHANNEL = "com.mywallet.my_wallet/notifications"
    private val EVENT_CHANNEL = "com.mywallet.my_wallet/notification_events"

    private var eventSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // MethodChannel for permission check and settings intent
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isNotificationListenerEnabled" -> {
                    val enabled = NotificationManagerCompat.getEnabledListenerPackages(this).contains(packageName)
                    result.success(enabled)
                }
                "openNotificationListenerSettings" -> {
                    val intent = Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
                    startActivity(intent)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        // EventChannel for streaming notifications to Flutter
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                private val listener: (Map<String, Any?>) -> Unit = { payload ->
                    runOnUiThread {
                        eventSink?.success(payload)
                    }
                }

                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                    BankNotificationListenerService.listeners.add(listener)
                }

                override fun onCancel(arguments: Any?) {
                    BankNotificationListenerService.listeners.remove(listener)
                    eventSink = null
                }
            }
        )
    }
}
