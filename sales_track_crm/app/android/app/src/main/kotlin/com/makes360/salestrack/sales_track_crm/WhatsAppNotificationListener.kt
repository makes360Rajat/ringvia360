package com.makes360.salestrack.sales_track_crm

import android.app.Notification
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import java.text.SimpleDateFormat
import java.util.Collections
import java.util.Date
import java.util.Locale

class WhatsAppNotificationListener : NotificationListenerService() {

    companion object {
        var instance: WhatsAppNotificationListener? = null
            private set

        // Track ongoing WhatsApp call start times to calculate talk duration
        private val ongoingCallStartTimes = mutableMapOf<String, Long>()

        // Cache recently sensed events so Flutter can fetch them if stream wasn't ready
        private val recentEvents = Collections.synchronizedList(mutableListOf<Map<String, Any>>())

        fun getRecentEvents(): List<Map<String, Any>> {
            synchronized(recentEvents) {
                return recentEvents.toList()
            }
        }

        private fun cacheEvent(event: Map<String, Any>) {
            synchronized(recentEvents) {
                val uid = event["uid"] as? String ?: ""
                recentEvents.removeAll { (it["uid"] as? String) == uid }
                if (recentEvents.size > 200) {
                    recentEvents.removeAt(0)
                }
                recentEvents.add(event)
            }
        }
    }

    override fun onListenerConnected() {
        super.onListenerConnected()
        instance = this
        try {
            val active = activeNotifications ?: return
            for (sbn in active) {
                onNotificationPosted(sbn)
            }
        } catch (_: Exception) {}
    }

    override fun onListenerDisconnected() {
        super.onListenerDisconnected()
        if (instance == this) {
            instance = null
        }
    }

    fun pollActiveNotifications(): List<Map<String, Any>> {
        val result = mutableListOf<Map<String, Any>>()
        try {
            val active = activeNotifications ?: return emptyList()
            for (sbn in active) {
                val ev = parseWhatsAppNotification(sbn)
                if (ev != null) {
                    result.add(ev)
                }
            }
        } catch (_: Exception) {}
        return result
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        if (sbn == null) return
        val event = parseWhatsAppNotification(sbn) ?: return
        cacheEvent(event)
        TelemetryBridgeChannel.sendTelemetryEvent(event)
    }

    private fun parseWhatsAppNotification(sbn: StatusBarNotification): Map<String, Any>? {
        val packageName = sbn.packageName ?: return null
        if (packageName != "com.whatsapp" && packageName != "com.whatsapp.w4b") return null

        val notification = sbn.notification ?: return null
        val extras = notification.extras ?: return null

        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString() ?: ""
        val text = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString()
            ?: extras.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString() ?: ""

        if (title.isEmpty() && text.isEmpty()) return null

        // Skip internal/backup notifications
        if (title.contains("backup", ignoreCase = true) ||
            text.contains("Checking for new messages", ignoreCase = true)
        ) {
            return null
        }

        val isWhatsAppBusiness = packageName == "com.whatsapp.w4b"
        val isWebCompanion = title.contains("WhatsApp Web", ignoreCase = true) || text.contains("WhatsApp Web", ignoreCase = true)
        val now = System.currentTimeMillis()
        val isoFormat = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", Locale.US)
        val timestamp = isoFormat.format(Date(now))

        // Deterministic hash component for strict deduplication
        val contentHash = Math.abs((title + text).hashCode())

        // Detect Call Notifications
        val isCall = (notification.category == Notification.CATEGORY_CALL) ||
                text.contains("call", ignoreCase = true) ||
                text.contains("calling", ignoreCase = true) ||
                title.contains("voice call", ignoreCase = true) ||
                title.contains("video call", ignoreCase = true)

        if (isCall) {
            val isMissed = text.contains("missed", ignoreCase = true) || title.contains("missed", ignoreCase = true)
            val isOutgoing = text.contains("calling", ignoreCase = true) || text.contains("outgoing", ignoreCase = true)
            val isOngoing = text.contains("ongoing", ignoreCase = true) || text.contains("tap to return to call", ignoreCase = true)

            val direction = when {
                isMissed -> "missed"
                isOutgoing -> "outgoing"
                isOngoing -> "incoming" // Ongoing connected
                else -> "incoming"
            }

            val isVideo = text.contains("video", ignoreCase = true) || title.contains("video", ignoreCase = true)
            val callerKey = "$packageName:$title"

            if (isOngoing && !ongoingCallStartTimes.containsKey(callerKey)) {
                ongoingCallStartTimes[callerKey] = now
            }

            val durationSeconds = if (isOngoing) {
                val start = ongoingCallStartTimes[callerKey] ?: now
                ((now - start) / 1000).toInt()
            } else 0

            val callNumber = if (title.matches(Regex("^[+0-9\\s\\-()]{7,}$"))) {
                title
            } else {
                ContactLookupHelper.resolvePhoneNumberByName(this, title) ?: ""
            }

            return mapOf(
                "type" to "whatsapp_call",
                "uid" to "wacall_${sbn.postTime}_$contentHash",
                "kind" to "whatsapp_call",
                "packageName" to packageName,
                "isBusiness" to isWhatsAppBusiness,
                "isWeb" to isWebCompanion,
                "accountType" to (if (isWhatsAppBusiness) "WhatsApp Business" else (if (isWebCompanion) "WhatsApp Web" else "WhatsApp")),
                "name" to (if (title.isNotEmpty()) title else "WhatsApp Contact"),
                "number" to callNumber,
                "direction" to direction,
                "media" to (if (isVideo) "video" else "voice"),
                "duration" to durationSeconds,
                "time" to sbn.postTime,
                "timestamp" to timestamp,
                "source" to "auto"
            )
        } else {
            // WhatsApp Chat / SMS Message
            val groupName = extras.getCharSequence(Notification.EXTRA_CONVERSATION_TITLE)?.toString()
            val msgNumber = if (title.matches(Regex("^[+0-9\\s\\-()]{7,}$"))) {
                title
            } else {
                ContactLookupHelper.resolvePhoneNumberByName(this, title) ?: ""
            }
            return mapOf(
                "type" to "whatsapp_message",
                "uid" to "wamsg_${sbn.postTime}_$contentHash",
                "kind" to "whatsapp_message",
                "packageName" to packageName,
                "isBusiness" to isWhatsAppBusiness,
                "isWeb" to isWebCompanion,
                "accountType" to (if (isWhatsAppBusiness) "WhatsApp Business" else (if (isWebCompanion) "WhatsApp Web" else "WhatsApp")),
                "sender" to (if (title.isNotEmpty()) title else "WhatsApp Contact"),
                "name" to title,
                "number" to msgNumber,
                "groupName" to (groupName ?: ""),
                "text" to text,
                "direction" to "incoming",
                "time" to sbn.postTime,
                "timestamp" to timestamp,
                "source" to "auto"
            )
        }
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification?) {
        if (sbn == null) return
        val packageName = sbn.packageName ?: return
        if (packageName != "com.whatsapp" && packageName != "com.whatsapp.w4b") return

        val notification = sbn.notification ?: return
        val extras = notification.extras ?: return
        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString() ?: ""
        val callerKey = "$packageName:$title"

        // If an ongoing call notification was removed, calculate total duration and emit completed event
        if (ongoingCallStartTimes.containsKey(callerKey)) {
            val startTime = ongoingCallStartTimes.remove(callerKey) ?: System.currentTimeMillis()
            val durationSec = ((System.currentTimeMillis() - startTime) / 1000).toInt()

            val now = System.currentTimeMillis()
            val isoFormat = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", Locale.US)
            val timestamp = isoFormat.format(Date(now))
            val isWhatsAppBusiness = packageName == "com.whatsapp.w4b"
            val callerHash = Math.abs(callerKey.hashCode())

            val callNumber = if (title.matches(Regex("^[+0-9\\s\\-()]{7,}$"))) {
                title
            } else {
                ContactLookupHelper.resolvePhoneNumberByName(this, title) ?: ""
            }

            val event = mapOf(
                "type" to "whatsapp_call_completed",
                "uid" to "wacall_done_${startTime}_$callerHash",
                "kind" to "whatsapp_call",
                "packageName" to packageName,
                "isBusiness" to isWhatsAppBusiness,
                "accountType" to (if (isWhatsAppBusiness) "WhatsApp Business" else "WhatsApp"),
                "name" to (if (title.isNotEmpty()) title else "WhatsApp Contact"),
                "number" to callNumber,
                "direction" to "incoming",
                "media" to "voice",
                "duration" to durationSec,
                "time" to startTime,
                "timestamp" to timestamp,
                "source" to "auto"
            )

            cacheEvent(event)
            TelemetryBridgeChannel.sendTelemetryEvent(event)
        }
    }
}
