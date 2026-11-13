package com.CallVia360.app

import android.app.job.JobInfo
import android.app.job.JobScheduler
import android.content.ComponentName
import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.CallLog
import android.provider.Telephony
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject
import java.io.BufferedReader
import java.io.File
import java.io.InputStreamReader
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.UUID
import java.util.concurrent.Executors

/**
 * NativeSyncManager: 100% autonomous native Android synchronization engine.
 * Ensures all calls (cellular & WhatsApp) and SMS messages are synced to the CRM server
 * even when the Flutter app is completely closed, killed from Recents, or the phone was restarted.
 */
object NativeSyncManager {
    private const val TAG = "NativeSyncManager"
    private const val QUEUE_FILE = "sales_track_native_queue.json"
    private const val JOB_ID = 36001
    private val executor = Executors.newSingleThreadExecutor()
    private val queueLock = Any()
    private val debounceLock = Any()
    private val mainHandler = Handler(Looper.getMainLooper())
    private var pendingCallLogRunnable: Runnable? = null
    private var pendingSmsRunnable: Runnable? = null
    private val processedUids = LinkedHashSet<String>()
    private val processedSmsFingerprints = LinkedHashSet<String>()

    fun markSmsProcessed(address: String, body: String, timeMs: Long, uid: String) {
        synchronized(processedUids) {
            if (uid.isNotEmpty()) {
                processedUids.add(uid)
                if (processedUids.size > 500) {
                    val it = processedUids.iterator()
                    if (it.hasNext()) { it.next(); it.remove() }
                }
            }
            val digits = address.replace(Regex("[^0-9]"), "")
            val key = if (digits.length >= 5) digits.takeLast(10) else address.trim().lowercase()
            val cleanBody = body.trim().replace(Regex("\\s+"), " ")
            val bodyHash = (cleanBody.hashCode().toLong() and 0xFFFFFFFFL).toString(16)
            val bucket = timeMs / 60000 // 1-minute bucket
            processedSmsFingerprints.add("${key}_${bodyHash}_$bucket")
            processedSmsFingerprints.add("${key}_${bodyHash}_${bucket - 1}")
            processedSmsFingerprints.add("${key}_${bodyHash}_${bucket + 1}")
            processedSmsFingerprints.add("${key}_${bodyHash}_${bucket - 2}")
            processedSmsFingerprints.add("${key}_${bodyHash}_${bucket + 2}")
            if (processedSmsFingerprints.size > 800) {
                val it = processedSmsFingerprints.iterator()
                if (it.hasNext()) { it.next(); it.remove() }
            }
        }
    }

    fun isSmsAlreadyProcessed(address: String, body: String, timeMs: Long, uid: String): Boolean {
        synchronized(processedUids) {
            if (uid.isNotEmpty() && processedUids.contains(uid)) return true
            val digits = address.replace(Regex("[^0-9]"), "")
            val key = if (digits.length >= 5) digits.takeLast(10) else address.trim().lowercase()
            val cleanBody = body.trim().replace(Regex("\\s+"), " ")
            val bodyHash = (cleanBody.hashCode().toLong() and 0xFFFFFFFFL).toString(16)
            val bucket = timeMs / 60000
            if (processedSmsFingerprints.contains("${key}_${bodyHash}_$bucket")) return true
        }
        return false
    }

    fun isMessageCountSummary(str: String?): Boolean {
        if (str == null) return false
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

    /**
     * Dispatch event: forwards to Flutter EventSink if app is running,
     * and guarantees direct persistent upload to CRM server even if app is killed.
     */
    fun sendOrQueueEvent(context: Context, event: Map<String, Any?>) {
        val kind = event["kind"]?.toString() ?: ""
        val text = event["text"]?.toString() ?: ""
        val name = event["name"]?.toString() ?: ""
        val uid = event["uid"]?.toString() ?: ""
        val number = event["number"]?.toString() ?: ""
        val timeMs = (event["time"] as? Number)?.toLong() ?: System.currentTimeMillis()

        if (isMessageCountSummary(text) || isMessageCountSummary(name)) {
            Log.d(TAG, "Dropped message count summary: $text")
            return
        }

        if (kind == "sms") {
            markSmsProcessed(number, text, timeMs, uid)
        }

        // 1. Forward to Flutter UI if app is open
        try {
            TelemetryBridgeChannel.sendTelemetryEvent(event)
        } catch (_: Exception) {}

        // 2. Persist in native queue and SQLite
        val jsonEvent = JSONObject()
        for ((k, v) in event) {
            if (v != null) {
                jsonEvent.put(k, v)
            }
        }

        enqueueEvent(context, jsonEvent)
        markOrInsertEventInLocalDb(context, event, "pending")

        // 3. Immediately fire direct HTTP upload in background
        triggerSync(context.applicationContext)
    }

    /**
     * Executes immediate background HTTP sync with the CRM server.
     */
    fun triggerSync(context: Context) {
        executor.execute {
            try {
                val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                val token = prefs.getString("flutter.mks_device_token", null)
                val serverUrl = prefs.getString("flutter.mks_server_url", null) ?: "https://crm.make360.in"
                val deviceUid = prefs.getString("flutter.mks_device_uid", null)

                if (token.isNullOrEmpty()) {
                    Log.d(TAG, "Device not paired yet; events safely preserved in native queue")
                    return@execute
                }

                val pending = getPendingEvents(context)
                if (pending.length() == 0) {
                    Log.d(TAG, "No pending native events to upload")
                    return@execute
                }

                // Batch up to 50 events per request
                val batch = JSONArray()
                val batchUids = mutableListOf<String>()
                for (i in 0 until Math.min(50, pending.length())) {
                    val ev = pending.getJSONObject(i)
                    val uid = ev.optString("uid", "")
                    if (uid.isNotEmpty()) {
                        val apiEvent = JSONObject().apply {
                            put("uid", uid)
                            put("kind", ev.optString("kind", "call"))
                            put("time", ev.optLong("time", System.currentTimeMillis()))
                            put("direction", ev.optString("direction", "incoming"))
                            put("number", ev.optString("number", ""))
                            put("name", ev.optString("name", ""))
                            put("sim", ev.optInt("sim", 1))
                            put("duration", ev.optInt("duration", 0))
                            put("recording", ev.optBoolean("recording", false))
                            if (ev.has("media")) put("media", ev.optString("media", "voice"))
                            if (ev.has("app")) put("app", ev.optString("app", ""))
                            if (ev.has("text")) put("text", ev.optString("text", ""))
                            put("source", "auto")
                        }
                        batch.put(apiEvent)
                        batchUids.add(uid)
                    }
                }

                if (batch.length() == 0) return@execute

                Log.d(TAG, "Direct native sync: uploading ${batch.length()} events to $serverUrl")

                val payload = JSONObject().apply {
                    put("events", batch)
                    put("token", token)
                    if (!deviceUid.isNullOrEmpty()) {
                        put("device_uid", deviceUid)
                    }
                }

                var normalizedUrl = serverUrl.trim()
                if (normalizedUrl.endsWith("/")) {
                    normalizedUrl = normalizedUrl.substring(0, normalizedUrl.length - 1)
                }
                val syncUrl = if (normalizedUrl.endsWith("/api/v1")) "$normalizedUrl/sync" else "$normalizedUrl/mks_sales_track/api/v1/sync"

                val url = URL(syncUrl)
                val conn = (url.openConnection() as HttpURLConnection).apply {
                    requestMethod = "POST"
                    connectTimeout = 15000
                    readTimeout = 20000
                    doOutput = true
                    doInput = true
                    setRequestProperty("Content-Type", "application/json; charset=UTF-8")
                    setRequestProperty("Accept", "application/json")
                    setRequestProperty("X-Sales-Track-Token", token)
                    setRequestProperty("Authorization", "Bearer $token")
                }

                OutputStreamWriter(conn.outputStream, "UTF-8").use { writer ->
                    writer.write(payload.toString())
                    writer.flush()
                }

                val responseCode = conn.responseCode
                Log.d(TAG, "Sync HTTP Response: $responseCode")

                if (responseCode in 200..299) {
                    val responseStr = BufferedReader(InputStreamReader(conn.inputStream, "UTF-8")).use { it.readText() }
                    val respJson = JSONObject(responseStr)
                    val isSuccess = respJson.optBoolean("success", false)

                    if (isSuccess) {
                        val dataObj = respJson.optJSONObject("data")
                        val stored = dataObj?.optJSONArray("stored") ?: JSONArray()
                        val duplicate = dataObj?.optJSONArray("duplicate") ?: JSONArray()
                        val finishedUids = mutableSetOf<String>()

                        for (i in 0 until stored.length()) finishedUids.add(stored.getString(i))
                        for (i in 0 until duplicate.length()) finishedUids.add(duplicate.getString(i))
                        finishedUids.addAll(batchUids)

                        // 1. Remove from native queue
                        removeCompletedUids(context, finishedUids.toList())

                        // 2. Mark as synced in local SQLite database
                        markEventsSyncedInLocalDb(context, finishedUids.toList())

                        Log.d(TAG, "Successfully synced ${finishedUids.size} events from native background!")

                        // 3. Continue with remaining pending events if any
                        val remaining = getPendingEvents(context)
                        if (remaining.length() > 0) {
                            triggerSync(context)
                        }
                    }
                } else if (responseCode == 401) {
                    Log.w(TAG, "Sync server returned 401 Unauthorized; token may need refreshing. Pausing retries.")
                } else {
                    Log.w(TAG, "Sync server returned non-200 status: $responseCode")
                    scheduleJob(context)
                }
            } catch (e: Exception) {
                Log.e(TAG, "Direct sync network error: ${e.message}")
                scheduleJob(context)
            }
        }
    }

    /**
     * Watchdog: inspects CallLog for any recent calls (within last 15 mins) that may not be synced.
     * Debounced by 1200ms to eliminate redundant triggers when system states or observers change rapidly.
     */
    fun checkAndSyncLatestCallLog(context: Context) {
        synchronized(debounceLock) {
            pendingCallLogRunnable?.let { mainHandler.removeCallbacks(it) }
            pendingCallLogRunnable = Runnable {
                executor.execute {
                    performCheckAndSyncLatestCallLog(context.applicationContext)
                }
            }
            mainHandler.postDelayed(pendingCallLogRunnable!!, 1200L)
        }
    }

    private fun performCheckAndSyncLatestCallLog(context: Context) {
        try {
            val projection = arrayOf(
                CallLog.Calls._ID,
                CallLog.Calls.NUMBER,
                CallLog.Calls.CACHED_NAME,
                CallLog.Calls.DURATION,
                CallLog.Calls.TYPE,
                CallLog.Calls.DATE
            )
                val cutoff = System.currentTimeMillis() - (15 * 60 * 1000)
                val selection = "${CallLog.Calls.DATE} >= ?"
                val selectionArgs = arrayOf(cutoff.toString())
                val sortOrder = "${CallLog.Calls.DATE} DESC LIMIT 10"

                context.contentResolver.query(
                    CallLog.Calls.CONTENT_URI,
                    projection,
                    selection,
                    selectionArgs,
                    sortOrder
                )?.use { cursor ->
                    while (cursor.moveToNext()) {
                        val id = cursor.getString(cursor.getColumnIndexOrThrow(CallLog.Calls._ID))
                        val number = cursor.getString(cursor.getColumnIndexOrThrow(CallLog.Calls.NUMBER)) ?: ""
                        val name = cursor.getString(cursor.getColumnIndexOrThrow(CallLog.Calls.CACHED_NAME)) ?: ""
                        val duration = cursor.getInt(cursor.getColumnIndexOrThrow(CallLog.Calls.DURATION))
                        val type = cursor.getInt(cursor.getColumnIndexOrThrow(CallLog.Calls.TYPE))
                        val callDateMs = cursor.getLong(cursor.getColumnIndexOrThrow(CallLog.Calls.DATE))

                        val direction = when (type) {
                            CallLog.Calls.INCOMING_TYPE -> "incoming"
                            CallLog.Calls.OUTGOING_TYPE -> "outgoing"
                            CallLog.Calls.MISSED_TYPE -> "missed"
                            CallLog.Calls.REJECTED_TYPE -> "rejected"
                            CallLog.Calls.BLOCKED_TYPE -> "blocked"
                            else -> "incoming"
                        }

                        val uid = "call-${id}-$callDateMs"
                        if (processedUids.contains(uid)) continue

                        val resolvedName = ContactLookupHelper.resolveContactName(context, number) ?: name
                        val isoFormat = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", Locale.US)
                        val timestamp = isoFormat.format(Date(callDateMs))

                        val event = mapOf(
                            "type" to "call_completed",
                            "uid" to uid,
                            "kind" to "call",
                            "phoneNumber" to number,
                            "number" to number,
                            "contactName" to resolvedName,
                            "name" to resolvedName,
                            "direction" to direction,
                            "duration" to duration,
                            "sim" to 1,
                            "recording" to false,
                            "recordingPath" to "",
                            "time" to callDateMs,
                            "timestamp" to timestamp,
                            "source" to "auto"
                        )

                        processedUids.add(uid)
                        if (processedUids.size > 200) {
                            val it = processedUids.iterator()
                            if (it.hasNext()) { it.next(); it.remove() }
                        }

                        sendOrQueueEvent(context, event)
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "checkAndSyncLatestCallLog error: ${e.message}")
            }
        }

    /**
     * Watchdog: inspects SMS for any recent messages (within last 15 mins) that may not be synced.
     * Debounced by 1200ms to consolidate ContentObserver and Google Messages notification bursts.
     */
    fun checkAndSyncLatestSms(context: Context) {
        synchronized(debounceLock) {
            pendingSmsRunnable?.let { mainHandler.removeCallbacks(it) }
            pendingSmsRunnable = Runnable {
                executor.execute {
                    performCheckAndSyncLatestSms(context.applicationContext)
                }
            }
            mainHandler.postDelayed(pendingSmsRunnable!!, 1200L)
        }
    }

    private fun performCheckAndSyncLatestSms(context: Context) {
        try {
            val projection = arrayOf(
                Telephony.Sms._ID,
                Telephony.Sms.ADDRESS,
                Telephony.Sms.BODY,
                Telephony.Sms.DATE,
                Telephony.Sms.TYPE
            )
                val cutoff = System.currentTimeMillis() - (15 * 60 * 1000)
                val selection = "${Telephony.Sms.DATE} >= ?"
                val selectionArgs = arrayOf(cutoff.toString())
                val sortOrder = "${Telephony.Sms.DATE} DESC LIMIT 10"

                context.contentResolver.query(
                    Telephony.Sms.CONTENT_URI,
                    projection,
                    selection,
                    selectionArgs,
                    sortOrder
                )?.use { cursor ->
                    while (cursor.moveToNext()) {
                        val id = cursor.getString(cursor.getColumnIndexOrThrow(Telephony.Sms._ID))
                        val address = cursor.getString(cursor.getColumnIndexOrThrow(Telephony.Sms.ADDRESS)) ?: ""
                        val body = cursor.getString(cursor.getColumnIndexOrThrow(Telephony.Sms.BODY)) ?: ""
                        val dateMs = cursor.getLong(cursor.getColumnIndexOrThrow(Telephony.Sms.DATE))
                        val type = cursor.getInt(cursor.getColumnIndexOrThrow(Telephony.Sms.TYPE))

                        val direction = if (type == Telephony.Sms.MESSAGE_TYPE_SENT) "outgoing" else "incoming"
                        val uid = "sms-${id}-$dateMs"

                        if (isSmsAlreadyProcessed(address, body, dateMs, uid)) continue
                        if (isMessageCountSummary(body)) continue

                        markSmsProcessed(address, body, dateMs, uid)

                        val resolvedName = ContactLookupHelper.resolveContactName(context, address) ?: address
                        val isoFormat = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", Locale.US)
                        val timestamp = isoFormat.format(Date(dateMs))

                        val event = mapOf(
                            "type" to "sms",
                            "uid" to uid,
                            "kind" to "sms",
                            "direction" to direction,
                            "number" to address,
                            "name" to resolvedName,
                            "sim" to 1,
                            "text" to body,
                            "time" to dateMs,
                            "timestamp" to timestamp,
                            "source" to "auto"
                        )

                        processedUids.add(uid)
                        if (processedUids.size > 200) {
                            val it = processedUids.iterator()
                            if (it.hasNext()) { it.next(); it.remove() }
                        }

                        sendOrQueueEvent(context, event)
                    }
                }

                // Check recent MMS and RCS messages
                val mmsList = MmsLookupHelper.queryMmsMessages(context, limit = 20, sinceMs = cutoff)
                for (event in mmsList) {
                    val uid = event["uid"]?.toString() ?: ""
                    val number = event["number"]?.toString() ?: ""
                    val text = event["text"]?.toString() ?: ""
                    val timeMs = (event["time"] as? Number)?.toLong() ?: 0L

                    if (isSmsAlreadyProcessed(number, text, timeMs, uid)) continue
                    if (isMessageCountSummary(text)) continue

                    markSmsProcessed(number, text, timeMs, uid)
                    processedUids.add(uid)
                    if (processedUids.size > 200) {
                        val it = processedUids.iterator()
                        if (it.hasNext()) { it.next(); it.remove() }
                    }

                    sendOrQueueEvent(context, event)
                }
            } catch (e: Exception) {
                Log.e(TAG, "checkAndSyncLatestSms error: ${e.message}")
            }
        }

    /**
     * Schedules native JobScheduler watchdog periodic job.
     */
    fun scheduleJob(context: Context) {
        try {
            val js = context.getSystemService(Context.JOB_SCHEDULER_SERVICE) as? JobScheduler ?: return
            val component = ComponentName(context, SalesTrackJobService::class.java)
            val builder = JobInfo.Builder(JOB_ID, component)
                .setRequiredNetworkType(JobInfo.NETWORK_TYPE_ANY)
                .setPersisted(true)
                .setBackoffCriteria(30000, JobInfo.BACKOFF_POLICY_EXPONENTIAL)

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                builder.setPeriodic(15 * 60 * 1000, 5 * 60 * 1000)
            } else {
                builder.setPeriodic(15 * 60 * 1000)
            }
            js.schedule(builder.build())
            Log.d(TAG, "JobScheduler watchdog registered (Job ID: $JOB_ID)")
        } catch (e: Exception) {
            Log.e(TAG, "JobScheduler schedule error: ${e.message}")
        }
    }

    private fun getPendingEvents(context: Context): JSONArray {
        synchronized(queueLock) {
            val file = File(context.filesDir, QUEUE_FILE)
            if (!file.exists()) return JSONArray()
            return try {
                val text = file.readText(Charsets.UTF_8)
                if (text.isBlank()) JSONArray() else JSONArray(text)
            } catch (_: Exception) {
                JSONArray()
            }
        }
    }

    private fun enqueueEvent(context: Context, event: JSONObject) {
        synchronized(queueLock) {
            try {
                val current = getPendingEvents(context)
                val uid = event.optString("uid", "")
                var exists = false
                for (i in 0 until current.length()) {
                    if (current.getJSONObject(i).optString("uid", "") == uid) {
                        exists = true
                        break
                    }
                }
                if (!exists) {
                    current.put(event)
                    val file = File(context.filesDir, QUEUE_FILE)
                    file.writeText(current.toString(), Charsets.UTF_8)
                }
            } catch (e: Exception) {
                Log.e(TAG, "Enqueue error: ${e.message}")
            }
        }
    }

    private fun removeCompletedUids(context: Context, uids: List<String>) {
        if (uids.isEmpty()) return
        synchronized(queueLock) {
            try {
                val current = getPendingEvents(context)
                val newArray = JSONArray()
                val uidSet = uids.toSet()
                for (i in 0 until current.length()) {
                    val ev = current.getJSONObject(i)
                    if (!uidSet.contains(ev.optString("uid", ""))) {
                        newArray.put(ev)
                    }
                }
                val file = File(context.filesDir, QUEUE_FILE)
                file.writeText(newArray.toString(), Charsets.UTF_8)
            } catch (e: Exception) {
                Log.e(TAG, "Remove completed error: ${e.message}")
            }
        }
    }

    private fun markOrInsertEventInLocalDb(context: Context, event: Map<String, Any?>, syncStatus: String) {
        try {
            val dbFile = context.getDatabasePath("sales_track_local.db")
            if (!dbFile.exists()) return
            val db = SQLiteDatabase.openDatabase(dbFile.absolutePath, null, SQLiteDatabase.OPEN_READWRITE)
            db.use { database ->
                val uid = event["uid"]?.toString() ?: return
                val values = ContentValues().apply {
                    put("uid", uid)
                    put("kind", event["kind"]?.toString() ?: "call")
                    put("time", (event["time"] as? Number)?.toLong() ?: System.currentTimeMillis())
                    put("direction", event["direction"]?.toString() ?: "incoming")
                    put("number", event["number"]?.toString() ?: "")
                    put("name", event["name"]?.toString() ?: "")
                    put("sim", (event["sim"] as? Number)?.toInt() ?: 1)
                    put("duration", (event["duration"] as? Number)?.toInt() ?: 0)
                    put("recording", if (event["recording"] == true) 1 else 0)
                    put("media", event["media"]?.toString())
                    put("app", event["app"]?.toString())
                    put("text", event["text"]?.toString())
                    put("source", event["source"]?.toString() ?: "auto")
                    put("recording_path", event["recordingPath"]?.toString())
                    put("sync_status", syncStatus)
                    put("recording_sync_status", "none")
                    val now = System.currentTimeMillis()
                    put("created_at", now)
                    put("updated_at", now)
                }
                database.insertWithOnConflict("events", null, values, SQLiteDatabase.CONFLICT_REPLACE)
            }
        } catch (e: Exception) {
            Log.e(TAG, "SQLite upsert error: ${e.message}")
        }
    }

    private fun markEventsSyncedInLocalDb(context: Context, uids: List<String>) {
        try {
            val dbFile = context.getDatabasePath("sales_track_local.db")
            if (!dbFile.exists() || uids.isEmpty()) return
            val db = SQLiteDatabase.openDatabase(dbFile.absolutePath, null, SQLiteDatabase.OPEN_READWRITE)
            db.use { database ->
                val now = System.currentTimeMillis()
                val values = ContentValues().apply {
                    put("sync_status", "synced")
                    put("updated_at", now)
                }
                for (uid in uids) {
                    database.update("events", values, "uid = ?", arrayOf(uid))
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "SQLite mark synced error: ${e.message}")
        }
    }
}

