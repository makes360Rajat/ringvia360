package com.ringvia360.mobile

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {

    companion object {
        const val PENDING_CALL_CHANNEL = "com.ringvia360/pending_call"
        const val REQ_PICK_AUDIO = 8821
    }

    private var pendingPickResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ── 1. EventChannel: live call state -> Flutter stream ──────────────────
        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CallSensorChannel.CHANNEL_NAME
        ).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                CallSensorChannel.setEventSink(events)
            }
            override fun onCancel(arguments: Any?) {
                CallSensorChannel.setEventSink(null)
            }
        })

        // ── 2. MethodChannel: Flutter reads pending wrap-up & local recordings ───
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            PENDING_CALL_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getPendingCall" -> {
                    val prefs = getSharedPreferences(
                        CallRecordingService.PREFS_NAME, Context.MODE_PRIVATE
                    )
                    val callId = prefs.getString("pending_call_id", null)
                    if (callId != null) {
                        result.success(
                            mapOf(
                                "callId"        to callId,
                                "phoneNumber"   to (prefs.getString("pending_phone_number", "") ?: ""),
                                "duration"      to prefs.getInt("pending_duration", 0),
                                "recordingPath" to prefs.getString("pending_recording_path", null),
                                "timestamp"     to prefs.getLong("pending_timestamp", 0L),
                            )
                        )
                        // Consume it — avoid double wrap-up
                        prefs.edit().clear().apply()
                    } else {
                        result.success(null)
                    }
                }

                "getLocalRecordings" -> {
                    try {
                        val recordingsList = mutableListOf<Map<String, Any>>()
                        val external = android.os.Environment.getExternalStorageDirectory()
                        val directories = listOfNotNull(
                            getExternalFilesDir("recordings"),
                            File(filesDir, "recordings"),
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
                            File(external, "CallRecordings")
                        )

                        val seenPaths = mutableSetOf<String>()
                        for (dir in directories) {
                            if (dir.exists() && dir.isDirectory) {
                                val files = dir.listFiles { f ->
                                    f.isFile && f.length() > 512 &&
                                    (f.name.endsWith(".m4a", true) || f.name.endsWith(".mp3", true) ||
                                     f.name.endsWith(".wav", true) || f.name.endsWith(".aac", true) ||
                                     f.name.endsWith(".amr", true) || f.name.endsWith(".ogg", true))
                                } ?: emptyArray()

                                for (file in files) {
                                    if (!seenPaths.contains(file.absolutePath)) {
                                        seenPaths.add(file.absolutePath)
                                        recordingsList.add(
                                            mapOf(
                                                "fileName"     to file.name,
                                                "filePath"     to file.absolutePath,
                                                "sizeBytes"    to file.length(),
                                                "lastModified" to file.lastModified()
                                            )
                                        )
                                    }
                                }
                            }
                        }

                        // Also query MediaStore.Audio.Media for recordings
                        try {
                            val projection = arrayOf(
                                android.provider.MediaStore.Audio.Media._ID,
                                android.provider.MediaStore.Audio.Media.DISPLAY_NAME,
                                android.provider.MediaStore.Audio.Media.DATA,
                                android.provider.MediaStore.Audio.Media.SIZE,
                                android.provider.MediaStore.Audio.Media.DATE_MODIFIED
                            )
                            contentResolver.query(
                                android.provider.MediaStore.Audio.Media.EXTERNAL_CONTENT_URI,
                                projection,
                                null,
                                null,
                                "${android.provider.MediaStore.Audio.Media.DATE_MODIFIED} DESC"
                            )?.use { cursor ->
                                val dataCol = cursor.getColumnIndex(android.provider.MediaStore.Audio.Media.DATA)
                                val nameCol = cursor.getColumnIndex(android.provider.MediaStore.Audio.Media.DISPLAY_NAME)
                                val sizeCol = cursor.getColumnIndex(android.provider.MediaStore.Audio.Media.SIZE)
                                val dateCol = cursor.getColumnIndex(android.provider.MediaStore.Audio.Media.DATE_MODIFIED)

                                var count = 0
                                while (cursor.moveToNext() && count < 60) {
                                    val path = if (dataCol != -1) cursor.getString(dataCol) else null
                                    if (!path.isNullOrBlank() && !seenPaths.contains(path)) {
                                        val f = File(path)
                                        if (f.exists() && f.length() > 512) {
                                            seenPaths.add(path)
                                            val name = if (nameCol != -1) cursor.getString(nameCol) else f.name
                                            val size = if (sizeCol != -1) cursor.getLong(sizeCol) else f.length()
                                            val date = if (dateCol != -1) cursor.getLong(dateCol) * 1000L else f.lastModified()
                                            recordingsList.add(
                                                mapOf(
                                                    "fileName"     to (name ?: f.name),
                                                    "filePath"     to path,
                                                    "sizeBytes"    to size,
                                                    "lastModified" to date
                                                )
                                            )
                                            count++
                                        }
                                    }
                                }
                            }
                        } catch (_: Exception) {}

                        // Sort newest first
                        recordingsList.sortByDescending { it["lastModified"] as? Long ?: 0L }
                        result.success(recordingsList)
                    } catch (e: Exception) {
                        result.error("SCAN_ERROR", e.message, null)
                    }
                }

                "pickAudioFile" -> {
                    pendingPickResult = result
                    try {
                        val intent = Intent(Intent.ACTION_GET_CONTENT).apply {
                            type = "audio/*"
                            addCategory(Intent.CATEGORY_OPENABLE)
                        }
                        startActivityForResult(Intent.createChooser(intent, "Select Call Recording"), REQ_PICK_AUDIO)
                    } catch (e: Exception) {
                        pendingPickResult = null
                        result.error("PICK_ERROR", e.message, null)
                    }
                }

                "hasOverlayPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        result.success(Settings.canDrawOverlays(this))
                    } else {
                        result.success(true)
                    }
                }

                "requestOverlayPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        try {
                            val intent = Intent(
                                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                                Uri.parse("package:$packageName")
                            )
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("PERMISSION_ERROR", e.message, null)
                        }
                    } else {
                        result.success(true)
                    }
                }

                else -> result.notImplemented()
            }
        }

        // Handle cold-start from wrap-up intent
        checkWrapUpIntent(intent)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQ_PICK_AUDIO) {
            val res = pendingPickResult
            pendingPickResult = null
            if (resultCode == RESULT_OK && data?.data != null) {
                try {
                    val uri = data.data!!
                    var fileName = "recording_${System.currentTimeMillis()}.m4a"
                    contentResolver.query(uri, null, null, null, null)?.use { cursor ->
                        val nameIndex = cursor.getColumnIndex(android.provider.OpenableColumns.DISPLAY_NAME)
                        if (nameIndex != -1 && cursor.moveToFirst()) {
                            fileName = cursor.getString(nameIndex) ?: fileName
                        }
                    }

                    val destDir = File(filesDir, "recordings").also { it.mkdirs() }
                    val destFile = File(destDir, fileName)
                    contentResolver.openInputStream(uri)?.use { input ->
                        destFile.outputStream().use { output ->
                            input.copyTo(output)
                        }
                    }

                    res?.success(
                        mapOf(
                            "fileName" to destFile.name,
                            "filePath" to destFile.absolutePath,
                            "sizeBytes" to destFile.length(),
                            "lastModified" to destFile.lastModified()
                        )
                    )
                } catch (e: Exception) {
                    res?.error("COPY_ERROR", e.message, null)
                }
            } else {
                res?.success(null)
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        checkWrapUpIntent(intent)
    }

    private fun checkWrapUpIntent(intent: Intent?) {
        if (intent != null && intent.getBooleanExtra("show_wrap_up", false)) {
            val callId = intent.getStringExtra("call_id") ?: ""
            val phone = intent.getStringExtra("phone_number") ?: ""
            val duration = intent.getIntExtra("duration", 0)
            val recordingPath = intent.getStringExtra("recording_path")
            intent.removeExtra("show_wrap_up")
            CallSensorChannel.notifyCallStateChanged(
                "disconnected",
                phone,
                callId,
                duration,
                recordingPath
            )
        }
    }
}
