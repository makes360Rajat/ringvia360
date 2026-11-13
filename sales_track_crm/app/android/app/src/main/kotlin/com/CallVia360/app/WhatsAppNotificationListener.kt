package com.CallVia360.app

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

        // Track active WhatsApp call sessions: callerKey -> (uid, startTime, direction)
        private val ongoingCallUids = mutableMapOf<String, String>()
        private val ongoingCallStartTimes = mutableMapOf<String, Long>()
        private val ongoingCallDirections = mutableMapOf<String, String>()

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
        SalesTrackBackgroundService.start(this)
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
        val type = event["type"]?.toString() ?: ""
        if (type == "whatsapp_message" || type == "whatsapp_call_completed" || (type == "whatsapp_call" && event["direction"] == "missed")) {
            NativeSyncManager.sendOrQueueEvent(this, event)
        }
    }

    private fun isMessageCountSummary(str: String): Boolean {
        val trimmed = str.trim()
        if (trimmed.isEmpty()) return false
        val lower = trimmed.lowercase()

        // e.g. "5 new messages", "1 new message", "24 messages", "3 unread messages", "(5 messages)"
        if (lower.matches(Regex("""^\(?\d+\s+(new\s+|unread\s+)?messages?[\s\.\,\!\?]*\)?$"""))) return true

        // e.g. "2 messages from 2 chats", "28 messages from 6 chats", "5 new messages from 3 chats"
        if (lower.matches(Regex("""^\d+\s+(new\s+|unread\s+)?messages?\s+from\s+.*$"""))) return true

        // e.g. "5 new messages" appearing as a standalone phrase
        if (lower.contains("new message") && lower.matches(Regex(""".*\b\d+\s+new\s+messages?\b.*""")) && lower.length < 35) return true

        // e.g. "messages from X chats"
        if (lower.contains("messages from") && lower.contains("chat")) return true

        // e.g. "Checking for new messages", "Looking for new messages"
        if (lower.contains("checking for new messages") || lower.contains("looking for new messages")) return true

        // WhatsApp Web companion notifications
        if (lower.contains("whatsapp web is currently active") || lower.contains("whatsapp web")) return true

        // Strings ending in "(X messages)"
        if (lower.matches(Regex(""".*\(\d+\s+messages?\)$"""))) return true

        return false
    }

    private fun parseWhatsAppNotification(sbn: StatusBarNotification): Map<String, Any>? {
        val packageName = sbn.packageName ?: return null
        if (packageName == "com.google.android.apps.messaging") {
            NativeSyncManager.checkAndSyncLatestSms(this)
            return null
        }
        if (packageName != "com.whatsapp" && packageName != "com.whatsapp.w4b") return null

        val notification = sbn.notification ?: return null
        val extras = notification.extras ?: return null

        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString()?.trim() ?: ""
        val text = (extras.getCharSequence(Notification.EXTRA_TEXT)?.toString()
            ?: extras.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString() ?: "").trim()
        val subText = extras.getCharSequence(Notification.EXTRA_SUB_TEXT)?.toString()?.trim() ?: ""
        val summaryText = extras.getCharSequence(Notification.EXTRA_SUMMARY_TEXT)?.toString()?.trim() ?: ""
        val category = notification.category ?: ""
        val channelId = notification.channelId ?: ""

        if (title.isEmpty() && text.isEmpty()) return null

        // Skip message count summary text (e.g. "5 new messages", "3 messages from 2 chats")
        if (isMessageCountSummary(text) || isMessageCountSummary(title) || isMessageCountSummary(subText) || isMessageCountSummary(summaryText)) {
            return null
        }

        // Skip internal/backup/companion notifications
        if (title.contains("backup", ignoreCase = true) ||
            text.contains("Checking for new messages", ignoreCase = true) ||
            text.contains("Looking for new messages", ignoreCase = true) ||
            title.contains("WhatsApp Web", ignoreCase = true) ||
            text.contains("WhatsApp Web", ignoreCase = true)
        ) {
            return null
        }

        // 1. Detect if notification is any kind of Call (VoIP incoming, outgoing, ongoing, missed)
        var hasCallAction = false
        var isCallActionEnd = false
        notification.actions?.forEach { action ->
            val at = action.title?.toString()?.lowercase() ?: ""
            if (at.contains("decline") || at.contains("answer") || at.contains("accept") || at.contains("call back") || at.contains("call again")) {
                hasCallAction = true
            } else if (at.contains("end") || at.contains("hang up") || at.contains("mute")) {
                hasCallAction = true
                isCallActionEnd = true
            }
        }

        val hasMessagingStyle = extras.containsKey("android.messagingUser") ||
                extras.containsKey("android.messages")

        val isCallCategory = (category == Notification.CATEGORY_CALL) ||
                (category == Notification.CATEGORY_MISSED_CALL) ||
                (category == "call") ||
                (category == "missed_call")

        val isCallChannel = channelId.contains("voip", ignoreCase = true) ||
                channelId.contains("call", ignoreCase = true)

        val isCallText = text.equals("Incoming voice call", ignoreCase = true) ||
                text.equals("Incoming video call", ignoreCase = true) ||
                text.equals("Ongoing call", ignoreCase = true) ||
                text.equals("Ringing...", ignoreCase = true) ||
                text.equals("Ringing…", ignoreCase = true) ||
                text.startsWith("Ongoing voice call", ignoreCase = true) ||
                text.startsWith("Ongoing video call", ignoreCase = true) ||
                text.matches(Regex("""^(Incoming|Ongoing|Missed)\s+(voice|video\s+)?call.*""", RegexOption.IGNORE_CASE)) ||
                subText.matches(Regex("""^(Incoming|Ongoing|Missed)\s+(voice|video\s+)?call.*""", RegexOption.IGNORE_CASE))

        val isCall = !hasMessagingStyle && (isCallCategory || isCallChannel || hasCallAction || isCallText)

        val isWhatsAppBusiness = packageName == "com.whatsapp.w4b"
        val isWebCompanion = false
        val now = System.currentTimeMillis()
        val isoFormat = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", Locale.US)
        val timestamp = isoFormat.format(Date(now))
        val contentHash = Math.abs((title + text).hashCode())

        if (isCall) {
            val isMissed = (category == Notification.CATEGORY_MISSED_CALL) ||
                    (category == "missed_call") ||
                    text.contains("missed", ignoreCase = true) ||
                    title.contains("missed", ignoreCase = true)
            val isOutgoing = text.contains("calling", ignoreCase = true) || text.contains("outgoing", ignoreCase = true)
            val isOngoing = isCallActionEnd ||
                    text.contains("ongoing", ignoreCase = true) ||
                    text.contains("tap to return to call", ignoreCase = true) ||
                    text.matches(Regex("""^\d{1,2}:\d{2}(:\d{2})?$"""))

            val isVideo = text.contains("video", ignoreCase = true) || title.contains("video", ignoreCase = true)

            var callNumber = if (title.matches(Regex("^[+0-9\\s\\-()]{7,}$"))) {
                title
            } else {
                ContactLookupHelper.resolvePhoneNumberByName(this, title) ?: ""
            }

            if (callNumber.isEmpty()) {
                val people = extras.getStringArray(Notification.EXTRA_PEOPLE)
                if (people != null) {
                    for (person in people) {
                        if (person.startsWith("tel:")) {
                            callNumber = person.removePrefix("tel:")
                            break
                        }
                    }
                }
            }

            if (callNumber.isEmpty()) {
                callNumber = title
            }

            // Strictly normalize phone number: keep leading '+' if present, strip all spaces and punctuation
            val rawTrimmed = callNumber.trim()
            val hasPlus = rawTrimmed.startsWith("+")
            val digitsOnly = rawTrimmed.replace(Regex("[^0-9]"), "")
            val normalizedNumber = if (digitsOnly.isNotEmpty()) {
                if (hasPlus) "+$digitsOnly" else digitsOnly
            } else {
                rawTrimmed
            }
            callNumber = normalizedNumber

            val normalizedCaller = if (digitsOnly.length >= 7) digitsOnly.takeLast(10) else callNumber.trim().lowercase()
            val callerKey = "$packageName:$normalizedCaller"
            val callerHash = Math.abs(callerKey.hashCode())

            val isEnded = text.contains("call ended", ignoreCase = true) ||
                    text.contains("ended", ignoreCase = true) ||
                    subText.contains("call ended", ignoreCase = true)

            // Resolve or preserve the call direction & stable UID
            val direction: String
            val callUid: String
            val callTime: Long

            if (isMissed) {
                direction = "missed"
                // If there was an active incoming/ringing session, reuse its exact UID and start time!
                callTime = ongoingCallStartTimes.remove(callerKey) ?: sbn.postTime
                callUid = ongoingCallUids.remove(callerKey) ?: "wacall_${callTime}_$callerHash"
                ongoingCallDirections.remove(callerKey)
            } else if (isEnded && (ongoingCallUids.containsKey(callerKey) || ongoingCallUids.keys.any { it.startsWith("$packageName:") })) {
                val matchedKey = if (ongoingCallUids.containsKey(callerKey)) callerKey else ongoingCallUids.keys.first { it.startsWith("$packageName:") }
                callUid = ongoingCallUids.remove(matchedKey) ?: "wacall_${sbn.postTime}_$callerHash"
                callTime = ongoingCallStartTimes.remove(matchedKey) ?: sbn.postTime
                direction = ongoingCallDirections.remove(matchedKey) ?: (if (isOutgoing) "outgoing" else "incoming")
                val durationSec = Math.max(1, ((now - callTime) / 1000).toInt())
                return mapOf(
                    "type" to "whatsapp_call_completed",
                    "uid" to callUid,
                    "kind" to "whatsapp_call",
                    "packageName" to packageName,
                    "isBusiness" to isWhatsAppBusiness,
                    "accountType" to (if (isWhatsAppBusiness) "WhatsApp Business" else "WhatsApp"),
                    "name" to (if (title.isNotEmpty()) title else "WhatsApp Contact"),
                    "number" to callNumber,
                    "direction" to direction,
                    "media" to (if (isVideo) "video" else "voice"),
                    "duration" to durationSec,
                    "time" to callTime,
                    "timestamp" to timestamp,
                    "source" to "auto"
                )
            } else if (ongoingCallUids.containsKey(callerKey)) {
                // Call is ALREADY ACTIVE - Reuse the exact same UID, start time, and original direction!
                callUid = ongoingCallUids[callerKey]!!
                callTime = ongoingCallStartTimes[callerKey] ?: sbn.postTime
                direction = ongoingCallDirections[callerKey] ?: (if (isOutgoing) "outgoing" else "incoming")
            } else {
                // Call is STARTING
                direction = if (isOutgoing) "outgoing" else "incoming"
                callTime = sbn.postTime
                callUid = "wacall_${callTime}_$callerHash"
                ongoingCallUids[callerKey] = callUid
                ongoingCallStartTimes[callerKey] = callTime
                ongoingCallDirections[callerKey] = direction
            }

            val durationSeconds = if (isOngoing && ongoingCallStartTimes.containsKey(callerKey)) {
                val start = ongoingCallStartTimes[callerKey] ?: now
                Math.max(0, ((now - start) / 1000).toInt())
            } else 0

            return mapOf(
                "type" to "whatsapp_call",
                "uid" to callUid,
                "kind" to "whatsapp_call",
                "packageName" to packageName,
                "isBusiness" to isWhatsAppBusiness,
                "isWeb" to isWebCompanion,
                "accountType" to (if (isWhatsAppBusiness) "WhatsApp Business" else "WhatsApp"),
                "name" to (if (title.isNotEmpty()) title else "WhatsApp Contact"),
                "number" to callNumber,
                "direction" to direction,
                "media" to (if (isVideo) "video" else "voice"),
                "duration" to durationSeconds,
                "time" to callTime,
                "timestamp" to timestamp,
                "source" to "auto"
            )
        } else {
            // It is a chat message:
            // 1. Skip Android group summary notifications (e.g. the summary notification that groups individual messages)
            if ((notification.flags and Notification.FLAG_GROUP_SUMMARY) != 0) {
                return null
            }

            // 2. Skip message count summary text (e.g. "5 new messages", "3 messages from 2 chats")
            if (isMessageCountSummary(text) || isMessageCountSummary(title) || isMessageCountSummary(subText) || isMessageCountSummary(summaryText)) {
                return null
            }

            // WhatsApp Chat / SMS Message
            val groupName = extras.getCharSequence(Notification.EXTRA_CONVERSATION_TITLE)?.toString()
            var msgNumber = if (title.matches(Regex("^[+0-9\\s\\-()]{7,}$"))) {
                title
            } else {
                ContactLookupHelper.resolvePhoneNumberByName(this, title) ?: ""
            }

            val msgRawTrimmed = msgNumber.trim()
            val msgHasPlus = msgRawTrimmed.startsWith("+")
            val msgDigitsOnly = msgRawTrimmed.replace(Regex("[^0-9]"), "")
            if (msgDigitsOnly.isNotEmpty()) {
                msgNumber = if (msgHasPlus) "+$msgDigitsOnly" else msgDigitsOnly
            }

            return mapOf(
                "type" to "whatsapp_message",
                "uid" to "wamsg_${sbn.postTime}_$contentHash",
                "kind" to "whatsapp_message",
                "packageName" to packageName,
                "isBusiness" to isWhatsAppBusiness,
                "isWeb" to isWebCompanion,
                "accountType" to (if (isWhatsAppBusiness) "WhatsApp Business" else "WhatsApp"),
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
        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString()?.trim() ?: ""
        var callNumber = if (title.matches(Regex("^[+0-9\\s\\-()]{7,}$"))) {
            title
        } else {
            ContactLookupHelper.resolvePhoneNumberByName(this, title) ?: ""
        }
        if (callNumber.isEmpty()) {
            callNumber = title
        }
        val rawTrimmed = callNumber.trim()
        val hasPlus = rawTrimmed.startsWith("+")
        val digitsOnly = rawTrimmed.replace(Regex("[^0-9]"), "")
        if (digitsOnly.isNotEmpty()) {
            callNumber = if (hasPlus) "+$digitsOnly" else digitsOnly
        }
        val normalizedCaller = if (digitsOnly.length >= 7) digitsOnly.takeLast(10) else callNumber.trim().lowercase()
        val callerKey = "$packageName:$normalizedCaller"

        // Find matching active session by callerKey or single active session
        val matchedKey = if (ongoingCallUids.containsKey(callerKey)) {
            callerKey
        } else if (ongoingCallUids.size == 1 && ongoingCallUids.keys.first().startsWith("$packageName:")) {
            ongoingCallUids.keys.first()
        } else {
            null
        }

        // If an ongoing call notification was removed, calculate total duration and emit completed event
        if (matchedKey != null) {
            val callUid = ongoingCallUids.remove(matchedKey) ?: "wacall_done_${sbn.postTime}_${Math.abs(callerKey.hashCode())}"
            val startTime = ongoingCallStartTimes.remove(matchedKey) ?: System.currentTimeMillis()
            val direction = ongoingCallDirections.remove(matchedKey) ?: "incoming"
            val durationSec = Math.max(0, ((System.currentTimeMillis() - startTime) / 1000).toInt())

            val now = System.currentTimeMillis()
            val isoFormat = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", Locale.US)
            val timestamp = isoFormat.format(Date(now))
            val isWhatsAppBusiness = packageName == "com.whatsapp.w4b"

            val event = mapOf(
                "type" to "whatsapp_call_completed",
                "uid" to callUid, // USE THE SAME STABLE UID TO PREVENT DUPLICATES!
                "kind" to "whatsapp_call",
                "packageName" to packageName,
                "isBusiness" to isWhatsAppBusiness,
                "accountType" to (if (isWhatsAppBusiness) "WhatsApp Business" else "WhatsApp"),
                "name" to (if (title.isNotEmpty()) title else "WhatsApp Contact"),
                "number" to callNumber,
                "direction" to direction,
                "media" to "voice",
                "duration" to durationSec,
                "time" to startTime,
                "timestamp" to timestamp,
                "source" to "auto"
            )

            cacheEvent(event)
            TelemetryBridgeChannel.sendTelemetryEvent(event)
            NativeSyncManager.sendOrQueueEvent(this, event)
        }
    }
}
