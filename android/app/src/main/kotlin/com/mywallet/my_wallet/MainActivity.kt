package com.mywallet.my_wallet

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.provider.Settings
import android.provider.Telephony
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val METHOD_CHANNEL = "com.mywallet.my_wallet/notifications"
    private val EVENT_CHANNEL = "com.mywallet.my_wallet/notification_events"
    private val SMS_CHANNEL = "com.mywallet.my_wallet/sms"

    private var eventSink: EventChannel.EventSink? = null
    private var pendingSmsResult: MethodChannel.Result? = null
    private val SMS_PERMISSION_CODE = 1001

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // MethodChannel for notification listener
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

        // MethodChannel for SMS Inbox querying
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SMS_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "checkSmsPermission" -> {
                    val hasPerm = ContextCompat.checkSelfPermission(
                        this,
                        Manifest.permission.READ_SMS
                    ) == PackageManager.PERMISSION_GRANTED
                    result.success(hasPerm)
                }
                "requestSmsPermission" -> {
                    if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_SMS) == PackageManager.PERMISSION_GRANTED) {
                        result.success(true)
                    } else {
                        pendingSmsResult = result
                        ActivityCompat.requestPermissions(
                            this,
                            arrayOf(Manifest.permission.READ_SMS),
                            SMS_PERMISSION_CODE
                        )
                    }
                }
                "readSmsInbox" -> {
                    val limit = call.argument<Int>("limit") ?: 500
                    val sinceMillis = call.argument<Number>("sinceMillis")?.toLong() ?: 0L
                    try {
                        val messages = readSmsMessages(limit, sinceMillis)
                        result.success(messages)
                    } catch (e: Exception) {
                        result.error("SMS_READ_ERROR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == SMS_PERMISSION_CODE) {
            val granted = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
            pendingSmsResult?.success(granted)
            pendingSmsResult = null
        }
    }

    private fun readSmsMessages(limit: Int, sinceMillis: Long = 0L): List<Map<String, Any>> {
        val list = mutableListOf<Map<String, Any>>()
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_SMS) != PackageManager.PERMISSION_GRANTED) {
            return list
        }

        val projection = arrayOf(
            Telephony.Sms.ADDRESS,
            Telephony.Sms.BODY,
            Telephony.Sms.DATE
        )

        val selection = if (sinceMillis > 0L) "${Telephony.Sms.DATE} >= ?" else null
        val selectionArgs = if (sinceMillis > 0L) arrayOf(sinceMillis.toString()) else null

        val cursor = contentResolver.query(
            Telephony.Sms.Inbox.CONTENT_URI,
            projection,
            selection,
            selectionArgs,
            "${Telephony.Sms.DATE} DESC LIMIT $limit"
        )

        cursor?.use {
            val addressIdx = it.getColumnIndex(Telephony.Sms.ADDRESS)
            val bodyIdx = it.getColumnIndex(Telephony.Sms.BODY)
            val dateIdx = it.getColumnIndex(Telephony.Sms.DATE)

            while (it.moveToNext()) {
                val address = if (addressIdx != -1) it.getString(addressIdx) ?: "" else ""
                val body = if (bodyIdx != -1) it.getString(bodyIdx) ?: "" else ""
                val date = if (dateIdx != -1) it.getLong(dateIdx) else System.currentTimeMillis()

                list.add(
                    mapOf(
                        "address" to address,
                        "body" to body,
                        "date" to date
                    )
                )
            }
        }

        return list
    }
}
