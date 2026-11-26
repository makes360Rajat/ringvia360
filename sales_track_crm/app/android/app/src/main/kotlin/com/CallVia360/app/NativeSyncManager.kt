package com.CallVia360.app

import android.app.job.JobInfo
import android.app.job.JobScheduler
import android.content.ComponentName
import android.content.ContentValues
import android.content.Context
import android.content.pm.PackageManager
import android.database.sqlite.SQLiteDatabase
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.CallLog
import android.provider.MediaStore
import android.provider.Telephony
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject
import java.io.BufferedReader
import java.io.File
import java.io.FileInputStream
import java.io.InputStreamReader
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.UUID
import java.util.concurrent.Executors
import android.os.Environment

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
            val bucket = timeMs / 15000 // 15-second window for same-instant duplicate suppression
            processedSmsFingerprints.add("${key}_${bodyHash}_$bucket")
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
            val bucket = timeMs / 15000
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
                    Log.d(TAG, "No pending native events to upload; checking pending recordings")
                    uploadPendingRecordings(context)
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

                        val configVersion = respJson.optString("config_version", "")
                        if (configVersion.isNotEmpty()) {
                            fetchSettingsAndApply(context, configVersion)
                        }

                        // 3. Continue with remaining pending events if any
                        val remaining = getPendingEvents(context)
                        if (remaining.length() > 0) {
                            triggerSync(context)
                        } else {
                            // 4. Trigger autonomous native background upload of recordings
                            uploadPendingRecordings(context)
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
                val sortOrder = "${CallLog.Calls.DATE} DESC"

                context.contentResolver.query(
                    CallLog.Calls.CONTENT_URI,
                    projection,
                    selection,
                    selectionArgs,
                    sortOrder
                )?.use { cursor ->
                    var count = 0
                    while (cursor.moveToNext() && count < 10) {
                        count++
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

                        val recPath = findRecordingForCall(context, number, resolvedName, callDateMs) ?: ""
                        val hasRec = recPath.isNotEmpty()

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
                            "recording" to hasRec,
                            "recordingPath" to recPath,
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
                val sortOrder = "${Telephony.Sms.DATE} DESC"

                context.contentResolver.query(
                    Telephony.Sms.CONTENT_URI,
                    projection,
                    selection,
                    selectionArgs,
                    sortOrder
                )?.use { cursor ->
                    var count = 0
                    while (cursor.moveToNext() && count < 10) {
                        count++
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

                    Log.d("RCS_SYNC", "📱 [RCS MMS WATCHDOG] Sensed new MMS/RCS message: num=$number, text=\"$text\"")
                    println("📱 [RCS MMS WATCHDOG] Sensed new MMS/RCS message: num=$number, text=\"$text\"")

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
            val db = SQLiteDatabase.openDatabase(dbFile.absolutePath, null, SQLiteDatabase.OPEN_READWRITE or SQLiteDatabase.ENABLE_WRITE_AHEAD_LOGGING)
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
                    var existingSync: String? = null
                    var existingRecSync: String? = null
                    var existingPath: String? = null
                    try {
                        database.rawQuery("SELECT sync_status, recording_sync_status, recording_path FROM events WHERE uid = ?", arrayOf(uid)).use { cur ->
                            if (cur.moveToNext()) {
                                existingSync = cur.getString(0)
                                existingRecSync = cur.getString(1)
                                existingPath = cur.getString(2)
                            }
                        }
                    } catch (_: Exception) {}

                    val recPath = event["recordingPath"]?.toString() ?: existingPath
                    val hasRec = !recPath.isNullOrEmpty()
                    put("recording_path", recPath)
                    put("recording", if (hasRec || event["recording"] == true) 1 else 0)
                    put("sync_status", if (existingSync == "synced") "synced" else syncStatus)
                    put("recording_sync_status", when {
                        existingRecSync == "synced" -> "synced"
                        existingRecSync == "failed_permanent" -> "failed_permanent"
                        hasRec -> "pending"
                        else -> "none"
                    })
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
            val db = SQLiteDatabase.openDatabase(dbFile.absolutePath, null, SQLiteDatabase.OPEN_READWRITE or SQLiteDatabase.ENABLE_WRITE_AHEAD_LOGGING)
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

    /**
     * Autonomous background audio recording upload:
     * Scans local SQLite DB for any calls with audio recordings that need upload
     * and streams them directly to the CRM server in the background without needing Flutter.
     */
    fun uploadPendingRecordings(context: Context) {
        executor.execute {
            try {
                if (getPendingEvents(context).length() > 0) {
                    Log.d(TAG, "Pending native call events exist; triggering sync first before uploading recordings")
                    triggerSync(context)
                }

                val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                val token = prefs.getString("flutter.mks_device_token", null)
                val serverUrl = prefs.getString("flutter.mks_server_url", null) ?: "https://crm.make360.in"
                if (token.isNullOrEmpty()) return@execute

                val dbFile = context.getDatabasePath("sales_track_local.db")
                if (!dbFile.exists()) return@execute
                val db = SQLiteDatabase.openDatabase(dbFile.absolutePath, null, SQLiteDatabase.OPEN_READWRITE or SQLiteDatabase.ENABLE_WRITE_AHEAD_LOGGING)
                val pendingList = mutableListOf<Triple<String, String, Long>>()
                db.use { database ->
                    // Auto-heal: for calls with missing recording_path, search storage for newly saved files
                    try {
                        val findQuery = "SELECT uid, number, name, time FROM events WHERE kind = 'call' AND (recording_path IS NULL OR recording_path = '') AND (recording_sync_status IS NULL OR recording_sync_status != 'synced') ORDER BY time DESC LIMIT 15"
                        database.rawQuery(findQuery, null).use { cursor ->
                            while (cursor.moveToNext()) {
                                val uid = cursor.getString(0) ?: ""
                                val num = cursor.getString(1) ?: ""
                                val name = cursor.getString(2) ?: ""
                                val time = cursor.getLong(3)
                                val found = findRecordingForCall(context, num, name, time)
                                if (!found.isNullOrEmpty()) {
                                    val cv = ContentValues().apply {
                                        put("recording_path", found)
                                        put("recording", 1)
                                        put("recording_sync_status", "pending")
                                        put("updated_at", System.currentTimeMillis())
                                    }
                                    database.update("events", cv, "uid = ?", arrayOf(uid))
                                }
                            }
                        }
                    } catch (e: Exception) {
                        Log.e(TAG, "Error resolving missing recording paths: ${e.message}")
                    }

                    // Query pending recordings that need upload (only for calls already synced to CRM)
                    val query = "SELECT uid, recording_path, time FROM events WHERE kind = 'call' AND sync_status = 'synced' AND recording_path IS NOT NULL AND recording_path != '' AND (recording_sync_status IS NULL OR recording_sync_status IN ('pending', 'none', 'failed')) AND recording_sync_status != 'failed_permanent' ORDER BY time DESC LIMIT 10"
                    database.rawQuery(query, null).use { cursor ->
                        while (cursor.moveToNext()) {
                            val uid = cursor.getString(0) ?: ""
                            val path = cursor.getString(1) ?: ""
                            val time = cursor.getLong(2)
                            if (uid.isNotEmpty() && path.isNotEmpty()) {
                                pendingList.add(Triple(uid, path, time))
                            }
                        }
                    }
                }

                if (pendingList.isEmpty()) {
                    return@execute
                }

                var normalizedUrl = serverUrl.trim()
                if (normalizedUrl.endsWith("/")) {
                    normalizedUrl = normalizedUrl.substring(0, normalizedUrl.length - 1)
                }
                val uploadUrl = if (normalizedUrl.endsWith("/api/v1")) "$normalizedUrl/recording" else "$normalizedUrl/mks_sales_track/api/v1/recording"

                for ((uid, path, _) in pendingList) {
                    val file = File(path)
                    if (!file.exists()) {
                        markRecordingStatus(context, uid, "none")
                        continue
                    }
                    if (file.length() > 25 * 1024 * 1024L) {
                        Log.w(TAG, "Recording file ${file.name} too large (${file.length()} bytes), skipping")
                        markRecordingStatus(context, uid, "failed_permanent")
                        continue
                    }

                    Log.i(TAG, "Native background uploading recording: uid=$uid, file=${file.name} (${file.length()} bytes)")
                    val success = uploadSingleRecording(uploadUrl, token, uid, file)
                    if (success) {
                        Log.i(TAG, "Native recording upload SUCCESS for uid=$uid")
                        markRecordingStatus(context, uid, "synced")
                    } else {
                        Log.w(TAG, "Native recording upload FAILED for uid=$uid")
                        markRecordingStatus(context, uid, "failed")
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error in uploadPendingRecordings: ${e.message}")
            }
        }
    }

    private fun uploadSingleRecording(uploadUrl: String, token: String, uid: String, file: File): Boolean {
        var conn: HttpURLConnection? = null
        try {
            val boundary = "Boundary-" + UUID.randomUUID().toString()
            val lineFeed = "\r\n"
            val url = URL(uploadUrl)
            conn = (url.openConnection() as HttpURLConnection).apply {
                requestMethod = "POST"
                connectTimeout = 30000
                readTimeout = 60000
                doOutput = true
                doInput = true
                useCaches = false
                setRequestProperty("User-Agent", "CallVia360-Android/2.6.0")
                setRequestProperty("Content-Type", "multipart/form-data; boundary=$boundary")
                setRequestProperty("X-Sales-Track-Token", token)
                setRequestProperty("Authorization", "Bearer $token")
            }

            conn.outputStream.use { output ->
                // Field: uid
                val uidPart = "--$boundary$lineFeed" +
                        "Content-Disposition: form-data; name=\"uid\"$lineFeed$lineFeed" +
                        "$uid$lineFeed"
                output.write(uidPart.toByteArray(Charsets.UTF_8))

                // Field: token
                val tokenPart = "--$boundary$lineFeed" +
                        "Content-Disposition: form-data; name=\"token\"$lineFeed$lineFeed" +
                        "$token$lineFeed"
                output.write(tokenPart.toByteArray(Charsets.UTF_8))

                // File Part (Sanitized safe filename to prevent WAF / ModSecurity 403 blocks)
                val safeName = file.name.replace(Regex("[^a-zA-Z0-9._-]"), "_")
                val fileHeader = "--$boundary$lineFeed" +
                        "Content-Disposition: form-data; name=\"file\"; filename=\"$safeName\"$lineFeed" +
                        "Content-Type: audio/mp4$lineFeed$lineFeed"
                output.write(fileHeader.toByteArray(Charsets.UTF_8))

                FileInputStream(file).use { input ->
                    val buffer = ByteArray(8192)
                    var bytesRead: Int
                    while (input.read(buffer).also { bytesRead = it } != -1) {
                        output.write(buffer, 0, bytesRead)
                    }
                    output.flush()
                }

                output.write(lineFeed.toByteArray(Charsets.UTF_8))
                val endBoundary = "--$boundary--$lineFeed"
                output.write(endBoundary.toByteArray(Charsets.UTF_8))
                output.flush()
            }

            val responseCode = conn.responseCode
            Log.d(TAG, "Recording upload response code: $responseCode for uid=$uid")
            if (responseCode in 200..299) {
                val responseStr = BufferedReader(InputStreamReader(conn.inputStream, Charsets.UTF_8)).use { it.readText() }
                val respJson = JSONObject(responseStr)
                return respJson.optBoolean("success", false) ||
                       respJson.optBoolean("already", false) ||
                       respJson.optString("recording") == "stored" ||
                       respJson.optString("recording") == "already_stored"
            } else {
                val errStr = BufferedReader(InputStreamReader(conn.errorStream ?: conn.inputStream, Charsets.UTF_8)).use { it.readText() }
                Log.w(TAG, "Recording upload error ($responseCode): $errStr")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Recording upload exception: ${e.message}")
        } finally {
            conn?.disconnect()
        }
        return false
    }

    private fun markRecordingStatus(context: Context, uid: String, status: String) {
        try {
            val dbFile = context.getDatabasePath("sales_track_local.db")
            if (!dbFile.exists()) return
            val db = SQLiteDatabase.openDatabase(dbFile.absolutePath, null, SQLiteDatabase.OPEN_READWRITE or SQLiteDatabase.ENABLE_WRITE_AHEAD_LOGGING)
            db.use { database ->
                val values = ContentValues().apply {
                    put("recording_sync_status", status)
                    put("updated_at", System.currentTimeMillis())
                }
                database.update("events", values, "uid = ?", arrayOf(uid))
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to update recording status for $uid: ${e.message}")
        }
    }

    fun findRecordingForCall(context: Context?, phone: String, name: String, callTimeMs: Long): String? {
        val cleanPhone = phone.replace(Regex("[^0-9]"), "").takeLast(10)
        val minTimeMs = callTimeMs - 180000L
        val maxTimeMs = callTimeMs + 180000L

        // 1. Query Android MediaStore (Primary for OnePlus, Samsung, Xiaomi, Oppo, Vivo)
        if (context != null) {
            try {
                val projection = arrayOf<String>(
                    MediaStore.Audio.Media.DATA,
                    MediaStore.Audio.Media.DISPLAY_NAME,
                    MediaStore.Audio.Media.DATE_MODIFIED
                )
                val minTimeSec = minTimeMs / 1000L
                val maxTimeSec = (maxTimeMs + 60000L) / 1000L
                val selection = "(${MediaStore.Audio.Media.DATE_MODIFIED} BETWEEN ? AND ?) AND (${MediaStore.Audio.Media.DATA} LIKE '%Record%' OR ${MediaStore.Audio.Media.DISPLAY_NAME} LIKE '%Call%' OR ${MediaStore.Audio.Media.DATA} LIKE '%Call%')"
                context.contentResolver.query(
                    MediaStore.Audio.Media.EXTERNAL_CONTENT_URI,
                    projection,
                    selection,
                    arrayOf(minTimeSec.toString(), maxTimeSec.toString()),
                    "${MediaStore.Audio.Media.DATE_MODIFIED} DESC"
                )?.use { cursor ->
                    var bestMediaStorePath: String? = null
                    var bestDiff = Long.MAX_VALUE
                    val dataIdx = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.DATA)
                    val nameIdx = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.DISPLAY_NAME)
                    val dateIdx = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.DATE_MODIFIED)

                    while (cursor.moveToNext()) {
                        val path = cursor.getString(dataIdx) ?: ""
                        val fName = cursor.getString(nameIdx) ?: File(path).name
                        val modMs = cursor.getLong(dateIdx) * 1000L
                        val diff = Math.abs(modMs - callTimeMs)

                        val matchNum = cleanPhone.isNotEmpty() && fName.replace(Regex("[^0-9]"), "").contains(cleanPhone)
                        val matchName = name.isNotEmpty() && fName.contains(name, ignoreCase = true)

                        if ((matchNum || matchName) && diff < 180000L) {
                            if (diff < bestDiff) {
                                bestDiff = diff
                                bestMediaStorePath = path
                            }
                        } else if (diff < 30000L && bestMediaStorePath == null) {
                            bestMediaStorePath = path
                            bestDiff = diff
                        }
                    }
                    if (!bestMediaStorePath.isNullOrEmpty() && File(bestMediaStorePath).exists()) {
                        return bestMediaStorePath
                    }
                }
            } catch (e: Exception) {
                Log.w(TAG, "Error querying MediaStore in NativeSyncManager: ${e.message}")
            }
        }

        // 2. Direct directory scan fallback
        val candidateDirs = mutableListOf(
            File(Environment.getExternalStorageDirectory(), "Recordings/Call"),
            File(Environment.getExternalStorageDirectory(), "Sounds/Call"),
            File(Environment.getExternalStorageDirectory(), "CallRecordings"),
            File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_MUSIC), "Recordings/Call")
        )
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            candidateDirs.add(File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_RECORDINGS), "Call"))
            candidateDirs.add(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_RECORDINGS))
        }

        var bestFile: File? = null
        var bestDiff = Long.MAX_VALUE

        for (dir in candidateDirs) {
            try {
                if (dir.exists() && dir.isDirectory) {
                    dir.listFiles()?.forEach { file ->
                        if (file.isFile && (file.extension.equals("m4a", true) || file.extension.equals("mp3", true) || file.extension.equals("wav", true) || file.extension.equals("amr", true) || file.extension.equals("aac", true) || file.extension.equals("3gp", true) || file.extension.equals("opus", true))) {
                            val fName = file.name
                            val matchNumber = cleanPhone.isNotEmpty() && fName.replace(Regex("[^0-9]"), "").contains(cleanPhone)
                            val matchName = name.isNotEmpty() && fName.contains(name, ignoreCase = true)
                            val lastMod = file.lastModified()
                            val diff = Math.abs(lastMod - callTimeMs)

                            if ((matchNumber || matchName) && diff < 180000L) { // within 3 minutes of call
                                if (diff < bestDiff) {
                                    bestDiff = diff
                                    bestFile = file
                                }
                            } else if (diff < 30000L && bestFile == null) {
                                bestFile = file
                                bestDiff = diff
                            }
                        }
                    }
                }
            } catch (_: Exception) {}
        }
        return bestFile?.absolutePath
    }

    /**
     * Autonomous background settings sync: fetches effective CRM control flags from /settings,
     * checks version hash, and applies them to native SharedPreferences and component states
     * (silent mode, launcher icon hiding, open on call, alerts, dialogs).
     */
    fun fetchSettingsAndApply(context: Context, forceOrExpectedVersion: String? = null) {
        executor.execute {
            try {
                val flutterPrefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                val token = flutterPrefs.getString("flutter.mks_device_token", null)
                val serverUrl = flutterPrefs.getString("flutter.mks_server_url", null) ?: "https://crm.make360.in"
                if (token.isNullOrEmpty()) return@execute

                val nativePrefs = context.getSharedPreferences("sales_track_prefs", Context.MODE_PRIVATE)
                val storedVersion = nativePrefs.getString("mks_crm_settings_version", "") ?: ""

                if (!forceOrExpectedVersion.isNullOrEmpty() && forceOrExpectedVersion == storedVersion) {
                    return@execute
                }

                var normalizedUrl = serverUrl.trim()
                if (normalizedUrl.endsWith("/")) {
                    normalizedUrl = normalizedUrl.substring(0, normalizedUrl.length - 1)
                }
                val settingsUrl = if (normalizedUrl.endsWith("/api/v1")) "$normalizedUrl/settings" else "$normalizedUrl/mks_sales_track/api/v1/settings"

                val url = URL(settingsUrl)
                val conn = (url.openConnection() as HttpURLConnection).apply {
                    requestMethod = "GET"
                    connectTimeout = 15000
                    readTimeout = 15000
                    setRequestProperty("Accept", "application/json")
                    setRequestProperty("User-Agent", "CallVia360-Android/2.6.0")
                    setRequestProperty("X-Sales-Track-Token", token)
                    setRequestProperty("Authorization", "Bearer $token")
                }

                val responseCode = conn.responseCode
                if (responseCode in 200..299) {
                    val responseStr = BufferedReader(InputStreamReader(conn.inputStream, "UTF-8")).use { it.readText() }
                    val respJson = JSONObject(responseStr)
                    if (respJson.optBoolean("success", false)) {
                        val settings = respJson.optJSONObject("settings")
                        if (settings != null) {
                            val newVersion = settings.optString("version", "")
                            if (newVersion.isNotEmpty() && newVersion == storedVersion && forceOrExpectedVersion == null) {
                                return@execute
                            }

                            val silentMode = settings.optBoolean("silent_mode", false)
                            val appIconHidden = settings.optBoolean("app_icon_hidden", false)
                            val openOnCall = settings.optBoolean("open_on_call", false)
                            val showAlerts = settings.optBoolean("show_alerts", true)
                            val showDialogs = settings.optBoolean("show_dialogs", true)
                            val leadEdit = settings.optBoolean("lead_edit", true)
                            val paused = settings.optBoolean("paused", false)

                            val currentIconHidden = nativePrefs.getBoolean("app_icon_hidden", false)
                            if (currentIconHidden != appIconHidden) {
                                try {
                                    // Ensure MainActivity itself is enabled
                                    val mainComp = ComponentName(context, "${context.packageName}.MainActivity")
                                    context.packageManager.setComponentEnabledSetting(
                                        mainComp,
                                        PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
                                        PackageManager.DONT_KILL_APP
                                    )

                                    // Toggle only LauncherAlias to hide/show launcher icon
                                    val alias = ComponentName(context, "${context.packageName}.LauncherAlias")
                                    val state = if (appIconHidden) PackageManager.COMPONENT_ENABLED_STATE_DISABLED else PackageManager.COMPONENT_ENABLED_STATE_ENABLED
                                    context.packageManager.setComponentEnabledSetting(alias, state, PackageManager.DONT_KILL_APP)
                                    Log.i(TAG, "Native applied launcher icon visibility: hidden=$appIconHidden")
                                } catch (e: Exception) {
                                    Log.e(TAG, "Failed to update icon visibility: ${e.message}")
                                }
                            }

                            nativePrefs.edit()
                                .putString("mks_crm_settings_version", newVersion)
                                .putBoolean("silent_mode", silentMode)
                                .putBoolean("app_icon_hidden", appIconHidden)
                                .putBoolean("open_on_call", openOnCall)
                                .putBoolean("show_alerts", showAlerts)
                                .putBoolean("show_dialogs", showDialogs)
                                .putBoolean("lead_edit", leadEdit)
                                .putBoolean("paused", paused)
                                .apply()

                            Log.i(TAG, "Native CRM settings applied: version=$newVersion, silent=$silentMode, hide_icon=$appIconHidden, open_on_call=$openOnCall, alerts=$showAlerts, dialogs=$showDialogs")
                        }
                    }
                }
                conn.disconnect()
            } catch (e: Exception) {
                Log.w(TAG, "Failed to fetch settings natively: ${e.message}")
            }
        }
    }
}

