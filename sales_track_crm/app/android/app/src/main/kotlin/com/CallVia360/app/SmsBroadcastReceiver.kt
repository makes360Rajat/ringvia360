package com.CallVia360.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.UUID

class SmsBroadcastReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) return

        val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent)
        if (messages.isNullOrEmpty()) return

        val fullBody = StringBuilder()
        var sender = ""
        var timestampMs = System.currentTimeMillis()

        for (sms in messages) {
            if (sender.isEmpty()) {
                sender = sms.displayOriginatingAddress ?: sms.originatingAddress ?: ""
                timestampMs = sms.timestampMillis
            }
            fullBody.append(sms.displayMessageBody ?: sms.messageBody ?: "")
        }

        val resolvedName = ContactLookupHelper.resolveContactName(context, sender)
        val isoFormat = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", Locale.US)
        val timestamp = isoFormat.format(Date(timestampMs))
        val uid = "sms_${timestampMs}_${UUID.randomUUID().toString().substring(0, 6)}"

        val event = mapOf(
            "type" to "sms",
            "uid" to uid,
            "kind" to "sms",
            "direction" to "incoming",
            "number" to (if (sender.isNotEmpty()) sender else "Unknown Sender"),
            "name" to (resolvedName ?: sender),
            "sim" to 1,
            "text" to fullBody.toString(),
            "time" to timestampMs,
            "timestamp" to timestamp,
            "source" to "auto"
        )

        TelemetryBridgeChannel.sendTelemetryEvent(event)
    }
}
