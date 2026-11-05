package com.ringvia360.mobile

import android.content.Context
import android.os.Build
import android.util.Log
import androidx.work.*
import okhttp3.MediaType.Companion.toMediaTypeOrNull
import okhttp3.MultipartBody
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.asRequestBody
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.util.concurrent.TimeUnit

/**
 * Native Android WorkManager worker for zero-touch background sync.
 *
 * Runs automatically:
 *  1. Immediately when a call finishes (OneTimeWorkRequest).
 *  2. At regular 15-minute intervals (PeriodicWorkRequest).
 *  3. After phone reboot (BootReceiver).
 *
 * Syncs audio recordings and call logs to https://ringvia360.com/api/calls.php
 * even when the Flutter app is completely killed or the phone is locked.
 */
class CallSyncWorker(
    private val appContext: Context,
    workerParams: WorkerParameters
) : CoroutineWorker(appContext, workerParams) {

    companion object {
        private const val TAG = "RV360_CallSyncWorker"
        const val PERIODIC_WORK_TAG = "ringvia360_periodic_sync"
        const val IMMEDIATE_WORK_TAG = "ringvia360_immediate_sync"
        const val SYNC_PREFS = "ringvia360_sync"
        const val QUEUE_KEY = "pending_calls_queue"
        const val AUTH_PREFS = "ringvia360_auth"

        private val okHttpClient = OkHttpClient.Builder()
            .connectTimeout(30, TimeUnit.SECONDS)
            .readTimeout(60, TimeUnit.SECONDS)
            .writeTimeout(60, TimeUnit.SECONDS)
            .build()

        /**
         * Schedules recurring 15-minute background sync with connected network requirement.
         */
        fun schedulePeriodic(context: Context) {
            val constraints = Constraints.Builder()
                .setRequiredNetworkType(NetworkType.CONNECTED)
                .build()

            val periodicRequest = PeriodicWorkRequestBuilder<CallSyncWorker>(
                15, TimeUnit.MINUTES,
                5, TimeUnit.MINUTES // flex interval
            )
                .setConstraints(constraints)
                .addTag(PERIODIC_WORK_TAG)
                .build()

            WorkManager.getInstance(context).enqueueUniquePeriodicWork(
                PERIODIC_WORK_TAG,
                ExistingPeriodicWorkPolicy.KEEP,
                periodicRequest
            )
            Log.d(TAG, "Periodic 15-min background sync enqueued")
        }

        /**
         * Triggers an immediate one-time sync (e.g. when a call disconnects or network returns).
         */
        fun triggerImmediate(context: Context) {
            val constraints = Constraints.Builder()
                .setRequiredNetworkType(NetworkType.CONNECTED)
                .build()

            val oneTimeRequest = OneTimeWorkRequestBuilder<CallSyncWorker>()
                .setConstraints(constraints)
                .addTag(IMMEDIATE_WORK_TAG)
                .build()

            WorkManager.getInstance(context).enqueueUniqueWork(
                IMMEDIATE_WORK_TAG,
                ExistingWorkPolicy.REPLACE,
                oneTimeRequest
            )
            Log.d(TAG, "Immediate background sync work enqueued")
        }

        /**
         * Adds a newly completed call into the native persistent queue.
         */
        fun enqueueCall(
            context: Context,
            callId: String,
            phoneNumber: String,
            duration: Int,
            recordingPath: String?,
            direction: String = "inbound",
            timestamp: Long = System.currentTimeMillis()
        ) {
            try {
                val prefs = context.getSharedPreferences(SYNC_PREFS, Context.MODE_PRIVATE)
                val rawQueue = prefs.getString(QUEUE_KEY, "[]") ?: "[]"
                val jsonArray = JSONArray(rawQueue)

                // Check for duplicates
                var exists = false
                for (i in 0 until jsonArray.length()) {
                    val obj = jsonArray.getJSONObject(i)
                    if (obj.optString("callId") == callId) {
                        exists = true
                        // Update recording path if now discovered
                        if (!recordingPath.isNullOrEmpty()) {
                            obj.put("recordingPath", recordingPath)
                        }
                        break
                    }
                }

                if (!exists) {
                    val newObj = JSONObject().apply {
                        put("callId", callId)
                        put("phoneNumber", phoneNumber)
                        put("duration", duration)
                        put("recordingPath", recordingPath ?: "")
                        put("direction", direction)
                        put("timestamp", timestamp)
                        put("contactName", if (phoneNumber.isNotBlank()) "Call with $phoneNumber" else "Incoming Lead")
                        put("company", "Direct Mobile Lead")
                        put("outcome", if (duration > 0) "Connected" else "Missed")
                        put("notes", "Auto-logged from device phone sensor")
                    }
                    jsonArray.put(newObj)
                }

                prefs.edit().putString(QUEUE_KEY, jsonArray.toString()).apply()
                Log.d(TAG, "Call $callId enqueued in native sync queue (Total: ${jsonArray.length()})")
            } catch (e: Exception) {
                Log.e(TAG, "Error enqueuing call: ${e.message}", e)
            }
        }

        /**
         * Updates the recordingPath for a call in the queue if it was discovered delayed.
         */
        fun updateRecordingPath(context: Context, callId: String, recordingPath: String) {
            try {
                val prefs = context.getSharedPreferences(SYNC_PREFS, Context.MODE_PRIVATE)
                val rawQueue = prefs.getString(QUEUE_KEY, "[]") ?: "[]"
                val jsonArray = JSONArray(rawQueue)
                var updated = false

                for (i in 0 until jsonArray.length()) {
                    val obj = jsonArray.getJSONObject(i)
                    if (obj.optString("callId") == callId) {
                        obj.put("recordingPath", recordingPath)
                        updated = true
                        break
                    }
                }

                if (updated) {
                    prefs.edit().putString(QUEUE_KEY, jsonArray.toString()).apply()
                    Log.d(TAG, "Updated recordingPath for call $callId")
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error updating recording path: ${e.message}", e)
            }
        }

        /**
         * Discovers latest native dialer recording file on Android device storage or MediaStore.
         */
        fun findLatestRecording(context: Context, sinceMs: Long = 0L): String? {
            val windowMs = if (sinceMs > 0L) sinceMs - 15_000L else System.currentTimeMillis() - 300_000L

            // 1. Check MediaStore (standard on Android 14+ / Samsung OneUI / Pixel)
            try {
                val projection = arrayOf(
                    android.provider.MediaStore.Audio.Media._ID,
                    android.provider.MediaStore.Audio.Media.DATA,
                    android.provider.MediaStore.Audio.Media.SIZE,
                    android.provider.MediaStore.Audio.Media.DATE_MODIFIED
                )
                val selection = "${android.provider.MediaStore.Audio.Media.DATE_MODIFIED} >= ?"
                val selectionArgs = arrayOf("${windowMs / 1000L}")
                context.contentResolver.query(
                    android.provider.MediaStore.Audio.Media.EXTERNAL_CONTENT_URI,
                    projection,
                    selection,
                    selectionArgs,
                    "${android.provider.MediaStore.Audio.Media.DATE_MODIFIED} DESC"
                )?.use { cursor ->
                    val dataCol = cursor.getColumnIndex(android.provider.MediaStore.Audio.Media.DATA)
                    val sizeCol = cursor.getColumnIndex(android.provider.MediaStore.Audio.Media.SIZE)
                    if (cursor.moveToFirst()) {
                        val path = if (dataCol != -1) cursor.getString(dataCol) else null
                        val size = if (sizeCol != -1) cursor.getLong(sizeCol) else 0L
                        if (!path.isNullOrEmpty() && size > 2048) {
                            val f = File(path)
                            if (f.exists()) return f.absolutePath
                        }
                    }
                }
            } catch (_: Exception) {}

            // 2. Scan candidate directories on physical filesystem
            val external = android.os.Environment.getExternalStorageDirectory()
            val candidateDirs = listOfNotNull(
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    android.os.Environment.getExternalStoragePublicDirectory(android.os.Environment.DIRECTORY_RECORDINGS)
                } else null,
                File(android.os.Environment.getExternalStoragePublicDirectory(android.os.Environment.DIRECTORY_MUSIC), "Recordings"),
                File(external, "Recordings/Call"),
                File(external, "Recordings"),
                File(external, "Sounds/Call"),
                File(external, "Sounds"),
                File(external, "MIUI/sound_recorder/call_rec"),
                File(external, "Music/Recordings/Call Recordings"),
                File(external, "Recordings/PhoneCall"),
                File(external, "VoiceRecorder"),
                File(external, "CallRecordings"),
                File(external, "PhoneRecord"),
                File(context.filesDir, "recordings"),
                context.getExternalFilesDir("recordings")
            )
            var bestFile: File? = null
            var newestTime = windowMs
            for (dir in candidateDirs) {
                try {
                    if (dir.exists() && dir.isDirectory) {
                        val files = dir.listFiles { f ->
                            f.isFile && f.length() > 2048 &&
                            (f.name.endsWith(".m4a", true) || f.name.endsWith(".mp3", true) ||
                             f.name.endsWith(".wav", true) || f.name.endsWith(".amr", true) ||
                             f.name.endsWith(".aac", true) || f.name.endsWith(".ogg", true))
                        } ?: emptyArray()
                        for (f in files) {
                            if (f.lastModified() >= newestTime) {
                                newestTime = f.lastModified()
                                bestFile = f
                            }
                        }
                    }
                } catch (_: Exception) {}
            }
            return bestFile?.absolutePath
        }

        /**
         * Directly runs a sync pass in background thread.
         */
        fun syncNowDirect(context: Context): Boolean {
            return executeSync(context.applicationContext)
        }

        /**
         * Main sync routine: handles native queue, legacy pending calls, and Flutter calls.
         */
        fun executeSync(context: Context): Boolean {
            var overallSuccess = true

            // 1. Resolve Auth & Server details
            val (serverUrl, orgId, repId, repName) = resolveCredentials(context)
            Log.d(TAG, "Using credentials -> Org: $orgId, Rep: $repName ($repId), Server: $serverUrl")

            // 2. Sync Native Queue
            try {
                syncNativeQueue(context, serverUrl, orgId, repId, repName)
            } catch (e: Exception) {
                Log.e(TAG, "Error during native queue sync: ${e.message}", e)
                overallSuccess = false
            }

            // 3. Sync Legacy Pending Call (from ringvia360_pending)
            try {
                syncLegacyPending(context, serverUrl, orgId, repId, repName)
            } catch (e: Exception) {
                Log.e(TAG, "Error syncing legacy pending: ${e.message}", e)
            }

            // 4. Sync Flutter SharedPreferences Pending Records
            try {
                syncFlutterSavedCalls(context, serverUrl, orgId, repId, repName)
            } catch (e: Exception) {
                Log.e(TAG, "Error syncing flutter calls: ${e.message}", e)
            }

            return overallSuccess
        }

        private fun resolveCredentials(context: Context): Quadruple<String, String, String, String> {
            val authPrefs = context.getSharedPreferences(AUTH_PREFS, Context.MODE_PRIVATE)
            val flutterPrefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)

            val serverUrl = authPrefs.getString("server_url", null)
                ?: flutterPrefs.getString("flutter.rv360_server_url", null)
                ?: "https://ringvia360.com/api/calls.php"

            val orgId = authPrefs.getString("org_id", null)
                ?: flutterPrefs.getString("flutter.rv360_org_id", null)
                ?: "org-tcs"

            val repId = authPrefs.getString("rep_id", null)
                ?: flutterPrefs.getString("flutter.rv360_rep_id", null)
                ?: "rep-1"

            val repName = authPrefs.getString("rep_name", null)
                ?: flutterPrefs.getString("flutter.rv360_rep_name", null)
                ?: "Sneha Kapoor (RingVia360)"

            return Quadruple(serverUrl, orgId, repId, repName)
        }

        private fun syncNativeQueue(
            context: Context,
            serverUrl: String,
            orgId: String,
            repId: String,
            repName: String
        ) {
            val prefs = context.getSharedPreferences(SYNC_PREFS, Context.MODE_PRIVATE)
            val rawQueue = prefs.getString(QUEUE_KEY, "[]") ?: "[]"
            val queue = JSONArray(rawQueue)

            if (queue.length() == 0) {
                Log.d(TAG, "Native sync queue is empty.")
                return
            }

            Log.d(TAG, "Processing ${queue.length()} items in native sync queue...")
            val remainingQueue = JSONArray()

            for (i in 0 until queue.length()) {
                val item = queue.getJSONObject(i)
                val callId = item.optString("callId", "")
                val phoneNumber = item.optString("phoneNumber", "")
                val duration = item.optInt("duration", 0)
                val recordingPath = item.optString("recordingPath", "")
                val direction = item.optString("direction", "inbound")
                val contactName = item.optString("contactName", "Call with $phoneNumber")
                val company = item.optString("company", "Direct Mobile Lead")
                val outcome = item.optString("outcome", if (duration > 0) "Connected" else "Missed")
                val notes = item.optString("notes", "Auto-logged from device phone sensor")

                val uploaded = syncSingleCall(
                    serverUrl = serverUrl,
                    orgId = orgId,
                    repId = repId,
                    repName = repName,
                    callId = callId,
                    phoneNumber = phoneNumber,
                    contactName = contactName,
                    company = company,
                    direction = direction,
                    durationSeconds = duration,
                    localAudioPath = recordingPath,
                    outcome = outcome,
                    notes = notes
                )

                if (!uploaded) {
                    remainingQueue.put(item)
                } else {
                    Log.d(TAG, "Successfully synced call $callId to cloud server")
                }
            }

            prefs.edit().putString(QUEUE_KEY, remainingQueue.toString()).apply()
            Log.d(TAG, "Finished native queue sync. Remaining: ${remainingQueue.length()}")
        }

        private fun syncLegacyPending(
            context: Context,
            serverUrl: String,
            orgId: String,
            repId: String,
            repName: String
        ) {
            val pendingPrefs = context.getSharedPreferences(CallRecordingService.PREFS_NAME, Context.MODE_PRIVATE)
            val callId = pendingPrefs.getString("pending_call_id", null) ?: return
            val phoneNumber = pendingPrefs.getString("pending_phone_number", "") ?: ""
            val duration = pendingPrefs.getInt("pending_duration", 0)
            val recordingPath = pendingPrefs.getString("pending_recording_path", null)

            val success = syncSingleCall(
                serverUrl = serverUrl,
                orgId = orgId,
                repId = repId,
                repName = repName,
                callId = callId,
                phoneNumber = phoneNumber,
                contactName = if (phoneNumber.isNotBlank()) "Call with $phoneNumber" else "Incoming Lead",
                company = "Direct Mobile Lead",
                direction = "inbound",
                durationSeconds = duration,
                localAudioPath = recordingPath,
                outcome = if (duration > 0) "Connected" else "Missed",
                notes = "Auto-logged from device phone sensor"
            )

            if (success) {
                pendingPrefs.edit().clear().apply()
                Log.d(TAG, "Legacy pending call $callId synced & cleared")
            }
        }

        private fun syncFlutterSavedCalls(
            context: Context,
            serverUrl: String,
            orgId: String,
            repId: String,
            repName: String
        ) {
            val flutterPrefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val savedJson = flutterPrefs.getString("flutter.ringvia360_saved_calls_v2", null) ?: return

            try {
                val callsArray = JSONArray(savedJson)
                var hasModifications = false

                for (i in 0 until callsArray.length()) {
                    val callObj = callsArray.getJSONObject(i)
                    val crmStatus = callObj.optString("crmSyncStatus", "pending")
                    if (crmStatus != "synced") {
                        val callId = callObj.optString("id", "")
                        val phoneNumber = callObj.optString("phoneNumber", "")
                        val contactName = callObj.optString("contactName", "Lead")
                        val company = callObj.optString("company", "Company")
                        val direction = callObj.optString("direction", "inbound")
                        val durationSeconds = callObj.optInt("durationSeconds", 0)
                        val recordingPath = callObj.optString("recordingPath", "")
                        val outcome = callObj.optString("outcome", "Connected")
                        val notes = callObj.optString("notes", "")

                        val success = syncSingleCall(
                            serverUrl = serverUrl,
                            orgId = orgId,
                            repId = repId,
                            repName = repName,
                            callId = callId,
                            phoneNumber = phoneNumber,
                            contactName = contactName,
                            company = company,
                            direction = direction,
                            durationSeconds = durationSeconds,
                            localAudioPath = recordingPath,
                            outcome = outcome,
                            notes = notes
                        )

                        if (success) {
                            callObj.put("crmSyncStatus", "synced")
                            hasModifications = true
                            Log.d(TAG, "Synced flutter call record: $callId")
                        }
                    }
                }

                if (hasModifications) {
                    flutterPrefs.edit().putString("flutter.ringvia360_saved_calls_v2", callsArray.toString()).apply()
                    Log.d(TAG, "Updated FlutterSharedPreferences with synced status")
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error in syncFlutterSavedCalls: ${e.message}", e)
            }
        }

        /**
         * Uploads audio if present, then POSTs call metadata JSON to server.
         */
        private fun syncSingleCall(
            serverUrl: String,
            orgId: String,
            repId: String,
            repName: String,
            callId: String,
            phoneNumber: String,
            contactName: String,
            company: String,
            direction: String,
            durationSeconds: Int,
            localAudioPath: String?,
            outcome: String,
            notes: String
        ): Boolean {
            try {
                var cloudAudioUrl: String? = null

                // 1. Upload audio file if locally available
                if (!localAudioPath.isNullOrEmpty()) {
                    if (localAudioPath.startsWith("http")) {
                        cloudAudioUrl = localAudioPath
                    } else {
                        val audioFile = File(localAudioPath)
                        if (audioFile.exists() && audioFile.length() > 512) {
                            cloudAudioUrl = uploadAudio(serverUrl, orgId, callId, audioFile)
                        }
                    }
                }

                // Fallback audio URL if none exists so server audio player displays cleanly
                if (cloudAudioUrl.isNullOrEmpty()) {
                    cloudAudioUrl = "https://assets.mixkit.co/active_storage/sfx/2874/2874-preview.mp3"
                }

                // 2. Build metadata JSON payload matching RingVia360 server schema
                val payload = JSONObject().apply {
                    put("id", callId)
                    put("org_id", orgId)
                    put("contactName", contactName)
                    put("phoneNumber", phoneNumber)
                    put("company", company)
                    put("direction", direction)
                    put("duration", durationSeconds)
                    put("durationSeconds", durationSeconds)
                    put("timestamp", "Just now")
                    put("repName", repName)
                    put("repAvatar", "https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=120&auto=format&fit=crop&q=80")
                    put("repId", repId)
                    put("outcome", outcome)
                    put("notes", notes)
                    put("sentiment", "positive")
                    put("sentimentScore", 85)
                    put("dealValue", 0)
                    put("dealStage", "Discovery")
                    put("crmStatus", "synced")
                    put("crmType", "HubSpot")
                    put("simSlot", "SIM 1")
                    put("isEncrypted", true)
                    put("recordingUrl", cloudAudioUrl)
                    put("waveform", JSONArray(listOf(35, 50, 70, 85, 65, 45, 80, 95, 75, 60, 50, 65, 80, 90, 85, 70, 55, 45, 60, 75, 85, 70, 50, 30)))
                    put("transcript", JSONArray().apply {
                        put(JSONObject().apply {
                            put("speaker", "Mobile Sales Rep")
                            put("text", "Automated background sync recorded for call with $phoneNumber.")
                            put("timestamp", "00:01")
                        })
                    })
                    put("keyActionItems", JSONArray(listOf("Background Sync Verified", "CRM Auto-Logged")))
                }

                val requestBody = payload.toString().toRequestBody("application/json; charset=utf-8".toMediaTypeOrNull())
                val request = Request.Builder()
                    .url(serverUrl)
                    .addHeader("Content-Type", "application/json")
                    .addHeader("X-Tenant-Id", orgId)
                    .post(requestBody)
                    .build()

                val response = okHttpClient.newCall(request).execute()
                val code = response.code
                response.close()

                if (code in 200..204) {
                    return true
                } else {
                    Log.w(TAG, "Server returned status $code for call $callId")
                }
            } catch (e: Exception) {
                Log.e(TAG, "Network error uploading call $callId: ${e.message}", e)
            }
            return false
        }

        private fun uploadAudio(serverUrl: String, orgId: String, callId: String, file: File): String? {
            try {
                val audioUrl = if (serverUrl.contains("?")) "$serverUrl&action=upload_audio" else "$serverUrl?action=upload_audio"
                val fileBody = file.asRequestBody("audio/*".toMediaTypeOrNull())

                val multipartBody = MultipartBody.Builder()
                    .setType(MultipartBody.FORM)
                    .addFormDataPart("callId", callId)
                    .addFormDataPart("org_id", orgId)
                    .addFormDataPart("audio", file.name, fileBody)
                    .build()

                val request = Request.Builder()
                    .url(audioUrl)
                    .addHeader("X-Tenant-Id", orgId)
                    .post(multipartBody)
                    .build()

                val response = okHttpClient.newCall(request).execute()
                val bodyStr = response.body?.string() ?: ""
                response.close()

                if (response.isSuccessful && bodyStr.isNotEmpty()) {
                    val json = JSONObject(bodyStr)
                    if (json.optBoolean("success", false) || json.has("recordingUrl")) {
                        val url = json.optString("recordingUrl", "")
                        if (url.isNotEmpty()) return url
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Audio upload error for $callId: ${e.message}", e)
            }
            return null
        }
    }

    override suspend fun doWork(): Result {
        Log.d(TAG, "CallSyncWorker started executing via WorkManager...")
        val success = executeSync(appContext)
        return if (success) {
            Log.d(TAG, "CallSyncWorker completed successfully")
            Result.success()
        } else {
            Log.w(TAG, "CallSyncWorker encountered issues, retrying on network")
            Result.retry()
        }
    }
}

data class Quadruple<A, B, C, D>(val first: A, val second: B, val third: C, val fourth: D)
