package com.makes360.salestrack.sales_track_crm

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Environment
import android.provider.CallLog
import android.provider.MediaStore
import android.telephony.TelephonyManager
import java.io.File
import java.io.FileInputStream
import java.security.MessageDigest
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.UUID

class PhoneCallBroadcastReceiver : BroadcastReceiver() {

    companion object {
        const val PREFS_NAME = "sales_track_prefs"
        private var lastState: String? = null
        private var callStartTime: Long = 0L
        private var ringingNumber: String = ""
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_NEW_OUTGOING_CALL) {
            val outNum = intent.getStringExtra(Intent.EXTRA_PHONE_NUMBER) ?: ""
            if (outNum.isNotEmpty()) {
                val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                prefs.edit().putString("outgoing_number", outNum).apply()
            }
            return
        }

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

                val savedName = ContactLookupHelper.resolveContactName(context, ringingNumber)
                val contactDisplayName = if (!savedName.isNullOrEmpty()) savedName else if (ringingNumber.isNotEmpty()) ringingNumber else "Incoming Caller"
                val event = mapOf(
                    "type" to "incoming_call_ringing",
                    "state" to "RINGING",
                    "phoneNumber" to (if (ringingNumber.isNotEmpty()) ringingNumber else "Incoming Caller"),
                    "contactName" to contactDisplayName,
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

                val activeNum = if (isIncoming) ringingNumber else (prefs.getString("outgoing_number", "") ?: "")
                val event = mapOf(
                    "type" to "call_answered",
                    "direction" to (if (isIncoming) "incoming" else "outgoing"),
                    "phoneNumber" to activeNum,
                    "timestamp" to timestamp
                )
                TelemetryBridgeChannel.sendTelemetryEvent(event)
            }

            TelephonyManager.EXTRA_STATE_IDLE -> {
                val prevState = prefs.getString("call_state", "")
                val answerTime = prefs.getLong("answer_time", 0L)
                val ringingTime = prefs.getLong("ringing_time", 0L)
                val outgoingNum = prefs.getString("outgoing_number", "") ?: ""
                val activeNum = if (ringingNumber.isNotEmpty()) ringingNumber else outgoingNum

                var duration = 0
                val direction: String

                if (prevState == "OFFHOOK" && answerTime > 0L) {
                    duration = ((now - answerTime) / 1000).toInt()
                    direction = if (ringingTime > 0L) "incoming" else "outgoing"
                } else if (prevState == "RINGING") {
                    duration = 0
                    direction = "missed"
                } else {
                    duration = 0
                    direction = if (outgoingNum.isNotEmpty()) "outgoing" else "incoming"
                }

                // Reset state in prefs
                prefs.edit()
                    .putString("call_state", "IDLE")
                    .putLong("answer_time", 0L)
                    .putLong("ringing_time", 0L)
                    .putString("outgoing_number", "")
                    .apply()

                val pendingResult = goAsync()
                Thread {
                    try {
                        // Wait 2 seconds for CallLog and recording files to be written to disk
                        Thread.sleep(2000)

                        val latestCallInfo = fetchLatestCallLogRecord(context, activeNum)
                        val finalPhone = latestCallInfo?.get("phoneNumber") as? String ?: (if (activeNum.isNotEmpty()) activeNum else "Unknown Caller")
                        val savedContactName = ContactLookupHelper.resolveContactName(context, finalPhone)
                        val finalName = if (!savedContactName.isNullOrEmpty()) {
                            savedContactName
                        } else {
                            val logName = latestCallInfo?.get("contactName") as? String
                            if (!logName.isNullOrEmpty() && logName != finalPhone && !logName.equals("unknown", ignoreCase = true) && !logName.equals("unknown caller", ignoreCase = true)) logName else ""
                        }
                        val finalDuration = (latestCallInfo?.get("duration") as? Int) ?: duration
                        val finalDirection = (latestCallInfo?.get("direction") as? String) ?: direction
                        val callLogId = latestCallInfo?.get("callLogId")?.toString() ?: ""
                        val simSlot = (latestCallInfo?.get("simSlot") as? Int) ?: 1

                        val callDateMs = (latestCallInfo?.get("callDateMs") as? Long) ?: now
                        val uid = if (callLogId.isNotEmpty()) "call-${callLogId}-$callDateMs" else "call-$callDateMs"

                        // Scan for newly recorded audio file
                        val recordingPath = findNewestRecordingFile(context, finalPhone, finalName) ?: ""
                        val hasRecording = recordingPath.isNotEmpty()

                        val event = mapOf(
                            "type" to "call_completed",
                            "uid" to uid,
                            "kind" to "call",
                            "phoneNumber" to finalPhone,
                            "number" to finalPhone,
                            "contactName" to finalName,
                            "name" to finalName,
                            "direction" to finalDirection,
                            "duration" to finalDuration,
                            "sim" to simSlot,
                            "recording" to hasRecording,
                            "recordingPath" to recordingPath,
                            "time" to callDateMs,
                            "timestamp" to timestamp,
                            "source" to "auto"
                        )

                        TelemetryBridgeChannel.sendTelemetryEvent(event)
                    } catch (_: Exception) {
                    } finally {
                        pendingResult.finish()
                    }
                }.start()
            }
        }
    }

    private fun fetchLatestCallLogRecord(context: Context, targetPhone: String): Map<String, Any>? {
        return try {
            val projection = arrayOf(
                CallLog.Calls._ID,
                CallLog.Calls.NUMBER,
                CallLog.Calls.CACHED_NAME,
                CallLog.Calls.DURATION,
                CallLog.Calls.TYPE,
                CallLog.Calls.DATE
            )
            val sortOrder = "${CallLog.Calls.DATE} DESC"
            context.contentResolver.query(
                CallLog.Calls.CONTENT_URI,
                projection,
                null,
                null,
                sortOrder
            )?.use { cursor ->
                if (cursor.moveToFirst()) {
                    val id = cursor.getString(cursor.getColumnIndexOrThrow(CallLog.Calls._ID))
                    val number = cursor.getString(cursor.getColumnIndexOrThrow(CallLog.Calls.NUMBER)) ?: targetPhone
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
                        CallLog.Calls.VOICEMAIL_TYPE -> "voicemail"
                        else -> "incoming"
                    }

                    mapOf(
                        "callLogId" to id,
                        "phoneNumber" to number,
                        "contactName" to name,
                        "duration" to duration,
                        "direction" to direction,
                        "callDateMs" to callDateMs,
                        "simSlot" to 1
                    )
                } else null
            }
        } catch (_: Exception) {
            null
        }
    }

    private fun findNewestRecordingFile(context: Context, phone: String, name: String): String? {
        val minTimeSec = (System.currentTimeMillis() - 120000) / 1000L
        try {
            val projection = arrayOf(
                MediaStore.Audio.Media.DATA,
                MediaStore.Audio.Media.DATE_MODIFIED
            )
            val selection = "${MediaStore.Audio.Media.DATE_MODIFIED} > ? AND (${MediaStore.Audio.Media.DATA} LIKE '%Record%' OR ${MediaStore.Audio.Media.DISPLAY_NAME} LIKE '%Call%')"
            context.contentResolver.query(
                MediaStore.Audio.Media.EXTERNAL_CONTENT_URI,
                projection,
                selection,
                arrayOf(minTimeSec.toString()),
                "${MediaStore.Audio.Media.DATE_MODIFIED} DESC"
            )?.use { cursor ->
                if (cursor.moveToFirst()) {
                    val path = cursor.getString(0) ?: ""
                    if (path.isNotEmpty()) return path
                }
            }
        } catch (_: Exception) {}

        val candidateDirs = listOf(
            File(Environment.getExternalStorageDirectory(), "Recordings/Call"),
            File(Environment.getExternalStorageDirectory(), "Sounds/Call"),
            File(Environment.getExternalStorageDirectory(), "CallRecordings"),
            File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_MUSIC), "Recordings/Call")
        )
        var newestPath: String? = null
        var newestTime: Long = System.currentTimeMillis() - 120000L
        for (dir in candidateDirs) {
            try {
                if (dir.exists() && dir.isDirectory) {
                    dir.listFiles()?.forEach { file ->
                        if (file.isFile && file.lastModified() > newestTime) {
                            val ext = file.extension.lowercase()
                            if (ext in listOf("m4a", "mp3", "aac", "wav", "amr", "awb", "3gp", "opus", "ogg")) {
                                newestTime = file.lastModified()
                                newestPath = file.absolutePath
                            }
                        }
                    }
                }
            } catch (_: Exception) {}
        }
        return newestPath
    }
}
