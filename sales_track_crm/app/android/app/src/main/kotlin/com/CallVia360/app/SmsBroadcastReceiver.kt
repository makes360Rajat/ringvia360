package com.CallVia360.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class SmsBroadcastReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        SalesTrackBackgroundService.start(context)
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

        val bodyText = fullBody.toString()

        // 1. Try to match Android Telephony provider ID if already committed
        var resolvedUid: String? = null
        try {
            val projection = arrayOf(Telephony.Sms._ID, Telephony.Sms.DATE)
            val selection = "${Telephony.Sms.DATE} >= ? AND ${Telephony.Sms.DATE} <= ?"
            val selectionArgs = arrayOf((timestampMs - 3000).toString(), (timestampMs + 3000).toString())
            context.contentResolver.query(
                Telephony.Sms.CONTENT_URI,
                projection,
                selection,
                selectionArgs,
                "${Telephony.Sms.DATE} DESC LIMIT 1"
            )?.use { cursor ->
                if (cursor.moveToFirst()) {
                    val id = cursor.getString(cursor.getColumnIndexOrThrow(Telephony.Sms._ID))
                    val dateMs = cursor.getLong(cursor.getColumnIndexOrThrow(Telephony.Sms.DATE))
                    resolvedUid = "sms-$id-$dateMs"
                }
            }
        } catch (_: Exception) {}

        // 2. Deterministic fallback UID if not yet in database
        val cleanSender = sender.replace(Regex("[^0-9a-zA-Z]"), "")
        val bodyHash = (bodyText.trim().hashCode().toLong() and 0xFFFFFFFFL).toString(16)
        val uid = resolvedUid ?: "sms_${timestampMs / 1000}_${cleanSender}_$bodyHash"

        // Prevent duplicate processing
        if (NativeSyncManager.isSmsAlreadyProcessed(sender, bodyText, timestampMs, uid)) {
            return
        }
        NativeSyncManager.markSmsProcessed(sender, bodyText, timestampMs, uid)

        val resolvedName = ContactLookupHelper.resolveContactName(context, sender)
        val isoFormat = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", Locale.US)
        val timestamp = isoFormat.format(Date(timestampMs))

        val event = mapOf(
            "type" to "sms",
            "uid" to uid,
            "kind" to "sms",
            "direction" to "incoming",
            "number" to (if (sender.isNotEmpty()) sender else "Unknown Sender"),
            "name" to (resolvedName ?: sender),
            "sim" to 1,
            "text" to bodyText,
            "time" to timestampMs,
            "timestamp" to timestamp,
            "source" to "auto"
        )

        TelemetryBridgeChannel.sendTelemetryEvent(event)
        NativeSyncManager.sendOrQueueEvent(context, event)
    }
}
