package com.mywallet.my_wallet

import android.app.Notification
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import java.util.concurrent.CopyOnWriteArrayList

class BankNotificationListenerService : NotificationListenerService() {

    companion object {
        val listeners = CopyOnWriteArrayList<(Map<String, Any?>) -> Unit>()

        private val ALLOWED_PACKAGES = setOf(
            "com.google.android.apps.nbu.paisa.user", // Google Pay
            "com.phonepe.app",                       // PhonePe
            "net.one97.paytm",                       // Paytm
            "com.dreamplug.androidapp",               // CRED
            "com.snapwork.hdfc",                      // HDFC MobileBanking
            "com.hdfcbank.payzapp",                   // HDFC PayZapp
            "com.csam.icici.bank.imobile",            // ICICI iMobile
            "com.sbi.lotusintouch",                   // SBI Yono
            "com.sbi.SBIFreedomPlus",                 // SBI Yono Lite
            "com.axis.mobile",                        // Axis Mobile
            "com.msf.kbank.mobile",                   // Kotak Mobile Banking
            "com.jupiter.money",                      // Jupiter Money
            "club.onecard",                           // OneCard
            "in.niyo.bharat",                         // Niyo
            "com.slicepay",                           // Slice
            "com.mobikwik_new"                        // MobiKwik
        )
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        super.onNotificationPosted(sbn)
        if (sbn == null) return

        val packageName = sbn.packageName ?: return
        if (packageName !in ALLOWED_PACKAGES) return

        val extras = sbn.notification?.extras ?: return
        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString() ?: ""
        val text = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString()
            ?: extras.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString()
            ?: ""

        if (text.isBlank()) return

        val payload = mapOf(
            "packageName" to packageName,
            "title" to title,
            "body" to text,
            "timestamp" to sbn.postTime
        )

        for (listener in listeners) {
            try {
                listener(payload)
            } catch (_: Exception) {}
        }
    }
}
