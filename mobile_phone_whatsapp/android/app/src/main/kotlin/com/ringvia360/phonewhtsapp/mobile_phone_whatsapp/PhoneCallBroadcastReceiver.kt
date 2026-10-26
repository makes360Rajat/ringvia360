package com.ringvia360.phonewhtsapp.mobile_phone_whatsapp

import android.Manifest
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Environment
import android.provider.CallLog
import android.provider.Settings
import android.telephony.TelephonyManager
import androidx.core.content.ContextCompat
import org.json.JSONObject
import java.io.BufferedReader
import java.io.File
import java.io.FileInputStream
import java.io.InputStreamReader
import java.io.OutputStream
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL
import java.security.MessageDigest
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.UUID

class PhoneCallBroadcastReceiver : BroadcastReceiver() {

    companion object {
        const val PREFS_NAME = "phone_telemetry_prefs"
        const val BASE_URL = "https://ringvia360.com/api/phone_whatsapp.php"
        private var lastState: String? = null
        private var callStartTime: Long = 0L
        private var ringingNumber: String = ""
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != TelephonyManager.ACTION_PHONE_STATE_CHANGED) return

        val state = intent.getStringExtra(TelephonyManager.EXTRA_STATE) ?: return
        val incomingNumber = intent.getStringExtra(TelephonyManager.EXTRA_INCOMING_NUMBER) ?: ""
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val now = System.currentTimeMillis()
        val isoFormat = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", Locale.US)
        val timestamp = isoFormat.format(Date(now))

        if (incomingNumber.isNotEmpty()) {
            ringingNumber = incomingNumber
            prefs.edit().putString("last_number", incomingNumber).apply()
        } else {
            ringingNumber = prefs.getString("last_number", "") ?: ""
        }

        when (state) {
            TelephonyManager.EXTRA_STATE_RINGING -> {
                callStartTime = now
                prefs.edit()
                    .putString("call_state", "RINGING")
                    .putLong("ringing_time", now)
                    .putString("active_number", ringingNumber)
                    .apply()

                // Silent telemetry registration (with resolved contact name)
                val savedName = ContactLookupHelper.resolveContactName(context, ringingNumber)
                val contactDisplayName = if (!savedName.isNullOrEmpty()) savedName else if (ringingNumber.isNotEmpty()) ringingNumber else "Incoming Caller"
                val event = mapOf(
                    "type" to "incoming_call_silent",
                    "state" to "RINGING",
                    "phoneNumber" to (if (ringingNumber.isNotEmpty()) ringingNumber else "Incoming Caller"),
                    "contactName" to contactDisplayName,
                    "simSlot" to "SIM 1 (Corporate)",
                    "timestamp" to timestamp
                )
                TelemetryBridgeChannel.sendTelemetryEvent(event)
            }

            TelephonyManager.EXTRA_STATE_OFFHOOK -> {
                val isIncoming = prefs.getString("call_state", "") == "RINGING"
                val answerTime = now
                prefs.edit()
                    .putString("call_state", "OFFHOOK")
                    .putLong("answer_time", answerTime)
                    .apply()

                val event = mapOf(
                    "type" to "call_answered",
                    "direction" to (if (isIncoming) "inbound" else "outbound"),
                    "phoneNumber" to ringingNumber,
                    "timestamp" to timestamp
                )
                TelemetryBridgeChannel.sendTelemetryEvent(event)
            }

            TelephonyManager.EXTRA_STATE_IDLE -> {
                // Call ended or missed! Perform automatic background server synchronization
                val prevState = prefs.getString("call_state", "")
                val answerTime = prefs.getLong("answer_time", 0L)
                val ringingTime = prefs.getLong("ringing_time", 0L)
                val activeNum = prefs.getString("active_number", ringingNumber) ?: ringingNumber

                var duration = 0
                val outcome: String
                val direction: String

                if (prevState == "OFFHOOK" && answerTime > 0L) {
                    duration = ((now - answerTime) / 1000).toInt()
                    outcome = "Call Completed"
                    direction = if (ringingTime > 0L) "inbound" else "outbound"
                } else if (prevState == "RINGING") {
                    duration = 0
                    outcome = "Missed / Rejected"
                    direction = "missed"
                } else {
                    duration = 0
                    outcome = "Call Terminated"
                    direction = "inbound"
                }

                // Reset state in prefs
                prefs.edit()
                    .putString("call_state", "IDLE")
                    .putLong("answer_time", 0L)
                    .putLong("ringing_time", 0L)
                    .apply()

                // Keep receiver process active in background via goAsync()
                val pendingResult = goAsync()

                Thread {
                    try {
                        // 1. Wait 2.5 seconds for OEM recorder (Samsung/Xiaomi/Pixel) to flush file to disk & CallLog to write
                        Thread.sleep(2500)

                        val devicePrefs = context.getSharedPreferences("ringvia_prefs", Context.MODE_PRIVATE)
                        var deviceId = devicePrefs.getString("device_unique_id", null)
                        if (deviceId == null) {
                            val androidId = Settings.Secure.getString(context.contentResolver, Settings.Secure.ANDROID_ID)
                            deviceId = if (!androidId.isNullOrEmpty()) "dev_$androidId" else "dev_" + UUID.randomUUID().toString().substring(0, 8)
                            devicePrefs.edit().putString("device_unique_id", deviceId).apply()
                        }

                        // 2. Query latest call from Android CallLog
                        val latestCallInfo = fetchLatestCallLogRecord(context, activeNum)
                        val callId = "call_" + System.currentTimeMillis() + "_" + UUID.randomUUID().toString().substring(0, 4)
                        val finalPhone = latestCallInfo?.get("phoneNumber") as? String ?: (if (activeNum.isNotEmpty()) activeNum else "Unknown Caller")
                        val savedContactName = ContactLookupHelper.resolveContactName(context, finalPhone)
                        val finalName = if (!savedContactName.isNullOrEmpty()) {
                            savedContactName
                        } else {
                            val logName = latestCallInfo?.get("contactName") as? String
                            if (!logName.isNullOrEmpty() && !logName.startsWith("Contact (") && logName != finalPhone) logName else finalPhone
                        }
                        val finalDuration = (latestCallInfo?.get("duration") as? Int) ?: duration
                        val finalDirection = (latestCallInfo?.get("direction") as? String) ?: direction
                        val finalOutcome = (latestCallInfo?.get("outcome") as? String) ?: outcome

                        // 3. Scan for newly created audio recording on device storage
                        val latestRecFile = findNewestRecordingFile(finalPhone, finalName)
                        var serverUrl = ""
                        var serverSha256 = ""

                        if (latestRecFile != null && latestRecFile.exists() && latestRecFile.length() > 0) {
                            val sha256 = calculateSha256(latestRecFile)
                            serverSha256 = sha256

                            // 4. Upload recording audio directly to server in background
                            val uploadRes = uploadAudioMultipart(deviceId, finalPhone, callId, sha256, latestRecFile)
                            if (uploadRes != null) {
                                serverUrl = uploadRes.optString("recordingUrl", "")
                                if (serverSha256.isEmpty()) {
                                    serverSha256 = uploadRes.optString("recordingSha256", sha256)
                                }
                            }
                        }

                        // 5. Sync call record to cloud server with audio URL & SHA-256
                        syncCallRecordToServer(
                            deviceId = deviceId,
                            callId = callId,
                            phone = finalPhone,
                            name = finalName,
                            direction = finalDirection,
                            duration = finalDuration,
                            outcome = finalOutcome,
                            recordingUrl = serverUrl,
                            recordingSha256 = serverSha256,
                            timestamp = timestamp
                        )

                        // 6. Notify Flutter UI if listening
                        val event = mapOf(
                            "type" to "call_completed",
                            "id" to callId,
                            "phoneNumber" to finalPhone,
                            "contactName" to finalName,
                            "direction" to finalDirection,
                            "duration" to finalDuration,
                            "outcome" to finalOutcome,
                            "recordingStatus" to (if (serverUrl.isNotEmpty()) "AVAILABLE" else "NOT_AVAILABLE"),
                            "recordingUrl" to serverUrl,
                            "recordingSha256" to serverSha256,
                            "simSlot" to "SIM 1 (Corporate)",
                            "timestamp" to timestamp
                        )
                        TelemetryBridgeChannel.sendTelemetryEvent(event)
                    } catch (e: Exception) {
                        e.printStackTrace()
                    } finally {
                        pendingResult.finish()
                    }
                }.start()
            }
        }

        lastState = state
    }

    private fun fetchLatestCallLogRecord(context: Context, expectedNumber: String): Map<String, Any>? {
        if (ContextCompat.checkSelfPermission(context, Manifest.permission.READ_CALL_LOG) != PackageManager.PERMISSION_GRANTED) {
            return null
        }
        return try {
            val projection = arrayOf(
                CallLog.Calls.NUMBER,
                CallLog.Calls.CACHED_NAME,
                CallLog.Calls.TYPE,
                CallLog.Calls.DURATION,
                CallLog.Calls.DATE
            )
            val cursor = context.contentResolver.query(
                CallLog.Calls.CONTENT_URI,
                projection,
                null,
                null,
                "${CallLog.Calls.DATE} DESC"
            ) ?: return null

            cursor.use {
                val numIdx = it.getColumnIndex(CallLog.Calls.NUMBER)
                val nameIdx = it.getColumnIndex(CallLog.Calls.CACHED_NAME)
                val typeIdx = it.getColumnIndex(CallLog.Calls.TYPE)
                val durIdx = it.getColumnIndex(CallLog.Calls.DURATION)

                var searchCount = 0
                while (it.moveToNext() && searchCount < 5) {
                    searchCount++
                    val num = if (numIdx >= 0) it.getString(numIdx) ?: "" else ""
                    val name = if (nameIdx >= 0) it.getString(nameIdx) ?: "" else ""
                    val type = if (typeIdx >= 0) it.getInt(typeIdx) else CallLog.Calls.INCOMING_TYPE
                    val dur = if (durIdx >= 0) it.getInt(durIdx) else 0

                    val dir = when (type) {
                        CallLog.Calls.INCOMING_TYPE -> "inbound"
                        CallLog.Calls.OUTGOING_TYPE -> "outbound"
                        CallLog.Calls.MISSED_TYPE -> "missed"
                        CallLog.Calls.REJECTED_TYPE -> "rejected"
                        else -> "inbound"
                    }
                    val outc = when (dir) {
                        "missed" -> "Missed / Not Answered"
                        "rejected" -> "Declined / Busy"
                        else -> if (dur > 0) "Call Completed" else "Call Terminated"
                    }

                    val savedName = ContactLookupHelper.resolveContactName(context, num)
                    val resolvedName = if (!savedName.isNullOrEmpty()) {
                        savedName
                    } else if (name.isNotEmpty() && !name.startsWith("Contact (") && name != num) {
                        name
                    } else {
                        if (num.isNotEmpty()) num else expectedNumber
                    }

                    return mapOf(
                        "phoneNumber" to (if (num.isNotEmpty()) num else expectedNumber),
                        "contactName" to resolvedName,
                        "direction" to dir,
                        "duration" to dur,
                        "outcome" to outc
                    )
                }
            }
            null
        } catch (_: Exception) {
            null
        }
    }

    private fun findNewestRecordingFile(phoneNumber: String, contactName: String): File? {
        val rootPath = Environment.getExternalStorageDirectory()?.absolutePath ?: "/storage/emulated/0"
        val candidateDirs = mutableListOf(
            File("$rootPath/Recordings/Call"),
            File("$rootPath/Recordings"),
            File("$rootPath/Voice Recorder"),
            File("$rootPath/Sounds/Call"),
            File("$rootPath/Sounds"),
            File("$rootPath/Samsung/Call"),
            File("$rootPath/MIUI/sound_recorder/call_rec"),
            File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_RECORDINGS), "Call"),
            Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_RECORDINGS)
        )

        val cleanPhone = phoneNumber.replace(Regex("[^0-9]"), "")
        val lowerContact = contactName.lowercase(Locale.US)
        val now = System.currentTimeMillis()
        var bestMatch: File? = null
        var newestModified = 0L

        for (dir in candidateDirs) {
            if (dir.exists() && dir.isDirectory) {
                dir.listFiles()?.forEach { file ->
                    if (file.isFile && isAudio(file.name)) {
                        val mod = file.lastModified()
                        val diff = now - mod

                        // Check name matches phone or contact
                        val fileNameLower = file.name.lowercase(Locale.US)
                        val nameMatches = (cleanPhone.length >= 8 && fileNameLower.contains(cleanPhone.takeLast(8))) ||
                                (lowerContact.length > 2 && fileNameLower.contains(lowerContact))

                        if (nameMatches) {
                            if (mod > newestModified) {
                                newestModified = mod
                                bestMatch = file
                            }
                        } else if (diff in 0..180000) { // Created within last 3 minutes
                            if (mod > newestModified) {
                                newestModified = mod
                                bestMatch = file
                            }
                        }
                    }
                }
            }
        }
        return bestMatch
    }

    private fun isAudio(name: String): Boolean {
        val l = name.lowercase(Locale.US)
        return l.endsWith(".m4a") || l.endsWith(".mp3") || l.endsWith(".wav") || l.endsWith(".amr") || l.endsWith(".aac") || l.endsWith(".3gp")
    }

    private fun calculateSha256(file: File): String {
        return try {
            val digest = MessageDigest.getInstance("SHA-256")
            val buffer = ByteArray(8192)
            FileInputStream(file).use { fis ->
                var read = fis.read(buffer)
                while (read != -1) {
                    digest.update(buffer, 0, read)
                    read = fis.read(buffer)
                }
            }
            val bytes = digest.digest()
            val sb = StringBuilder()
            for (b in bytes) {
                sb.append(String.format("%02x", b))
            }
            sb.toString()
        } catch (_: Exception) {
            ""
        }
    }

    private fun uploadAudioMultipart(deviceId: String, phoneNumber: String, callId: String, sha256: String, file: File): JSONObject? {
        val boundary = "==RingVia360Boundary==" + System.currentTimeMillis()
        val lineEnd = "\r\n"
        val twoHyphens = "--"

        return try {
            val url = URL("$BASE_URL?action=upload_recording")
            val conn = url.openConnection() as HttpURLConnection
            conn.requestMethod = "POST"
            conn.doOutput = true
            conn.doInput = true
            conn.useCaches = false
            conn.connectTimeout = 30000
            conn.readTimeout = 45000
            conn.setRequestProperty("Connection", "Keep-Alive")
            conn.setRequestProperty("Content-Type", "multipart/form-data; boundary=$boundary")

            val outputStream: OutputStream = conn.outputStream

            fun writeField(name: String, value: String) {
                outputStream.write("$twoHyphens$boundary$lineEnd".toByteArray())
                outputStream.write("Content-Disposition: form-data; name=\"$name\"$lineEnd$lineEnd".toByteArray())
                outputStream.write("$value$lineEnd".toByteArray())
            }

            writeField("deviceId", deviceId)
            writeField("phoneNumber", phoneNumber)
            writeField("callId", callId)
            writeField("sha256", sha256)

            // Audio File Part
            outputStream.write("$twoHyphens$boundary$lineEnd".toByteArray())
            outputStream.write("Content-Disposition: form-data; name=\"audio\"; filename=\"${file.name}\"$lineEnd".toByteArray())
            outputStream.write("Content-Type: audio/mp4$lineEnd$lineEnd".toByteArray())

            val buffer = ByteArray(8192)
            FileInputStream(file).use { fis ->
                var bytesRead = fis.read(buffer)
                while (bytesRead != -1) {
                    outputStream.write(buffer, 0, bytesRead)
                    bytesRead = fis.read(buffer)
                }
            }
            outputStream.write(lineEnd.toByteArray())
            outputStream.write("$twoHyphens$boundary$twoHyphens$lineEnd".toByteArray())
            outputStream.flush()
            outputStream.close()

            if (conn.responseCode == 200) {
                val reader = BufferedReader(InputStreamReader(conn.inputStream))
                val resp = reader.readText()
                reader.close()
                JSONObject(resp)
            } else {
                null
            }
        } catch (_: Exception) {
            null
        }
    }

    private fun syncCallRecordToServer(
        deviceId: String,
        callId: String,
        phone: String,
        name: String,
        direction: String,
        duration: Int,
        outcome: String,
        recordingUrl: String,
        recordingSha256: String,
        timestamp: String
    ) {
        try {
            val url = URL("$BASE_URL?action=call")
            val conn = url.openConnection() as HttpURLConnection
            conn.requestMethod = "POST"
            conn.doOutput = true
            conn.setRequestProperty("Content-Type", "application/json; charset=UTF-8")
            conn.connectTimeout = 15000
            conn.readTimeout = 15000

            val json = JSONObject().apply {
                put("id", callId)
                put("deviceId", deviceId)
                put("phoneNumber", phone)
                put("contactName", name)
                put("direction", direction)
                put("durationSeconds", duration)
                put("duration", duration)
                put("outcome", outcome)
                put("simSlot", "SIM 1 (Corporate)")
                put("startedAt", timestamp)
                put("endedAt", timestamp)
                put("recordingStatus", if (recordingUrl.isNotEmpty()) "AVAILABLE" else "NOT_AVAILABLE")
                if (recordingUrl.isNotEmpty()) {
                    put("recordingUrl", recordingUrl)
                    put("recordingSha256", recordingSha256)
                }
            }

            OutputStreamWriter(conn.outputStream).use {
                it.write(json.toString())
                it.flush()
            }
            conn.responseCode
        } catch (_: Exception) {}
    }
}
