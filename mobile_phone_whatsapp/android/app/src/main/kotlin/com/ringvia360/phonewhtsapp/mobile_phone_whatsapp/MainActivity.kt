package com.ringvia360.phonewhtsapp.mobile_phone_whatsapp

import android.Manifest
import android.content.ComponentName
import android.content.ContentUris
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.media.AudioAttributes
import android.media.MediaMetadataRetriever
import android.media.MediaPlayer
import android.media.MediaScannerConnection
import android.media.PlaybackParams
import android.net.Uri
import android.os.BatteryManager
import android.os.Build
import android.os.Environment
import android.os.PowerManager
import android.provider.CallLog
import android.provider.MediaStore
import android.provider.Settings
import android.provider.Telephony
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import android.database.ContentObserver
import android.os.Handler
import android.os.Looper
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
import java.util.TimeZone
import java.util.UUID
import org.json.JSONObject

class MainActivity : FlutterActivity() {

    companion object {
        const val METHOD_CHANNEL = "com.ringvia360.phonewhtsapp/platform"
        const val BASE_URL = "https://ringvia360.com/api/phone_whatsapp.php"
        private var mediaPlayer: MediaPlayer? = null
        private var activeFis: FileInputStream? = null
        private var activeAudioPath: String? = null
        private var isPlayerPrepared: Boolean = false
        private val playerLock = Any()

        fun stopNativeAudio() {
            synchronized(playerLock) {
                activeAudioPath = null
                isPlayerPrepared = false
                mediaPlayer?.let { player ->
                    try {
                        player.setOnPreparedListener(null)
                        player.setOnErrorListener(null)
                        player.setOnCompletionListener(null)
                        if (player.isPlaying) {
                            player.stop()
                        }
                    } catch (_: Exception) {}
                    try {
                        player.reset()
                    } catch (_: Exception) {}
                    try {
                        player.release()
                    } catch (_: Exception) {}
                }
                mediaPlayer = null
                try {
                    activeFis?.close()
                } catch (_: Exception) {}
                activeFis = null
            }
        }
    }

    private var callLogObserver: ContentObserver? = null
    private var lastObservedCallId: String = ""
    private var lastObservedCallDate: Long = 0L
    private val observerHandler = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Automatically activate real-time system CallLog ContentObserver
        registerCallLogObserver()

        // 1. Live Telemetry Event Channel
        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            TelemetryBridgeChannel.CHANNEL_NAME
        ).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                TelemetryBridgeChannel.setEventSink(events)
            }

            override fun onCancel(arguments: Any?) {
                TelemetryBridgeChannel.setEventSink(null)
            }
        })

        // 2. Platform Controls Channel
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            METHOD_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                // Device Hardware Information
                "getDeviceInfo" -> {
                    try {
                        val bm = getSystemService(Context.BATTERY_SERVICE) as? BatteryManager
                        val battery = bm?.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY) ?: 85
                        val prefs = getSharedPreferences("ringvia_prefs", Context.MODE_PRIVATE)
                        var did = prefs.getString("device_unique_id", null)
                        if (did == null) {
                            val androidId = Settings.Secure.getString(contentResolver, Settings.Secure.ANDROID_ID)
                            did = if (!androidId.isNullOrEmpty()) "dev_$androidId" else "dev_" + UUID.randomUUID().toString().substring(0, 8)
                            prefs.edit().putString("device_unique_id", did).apply()
                        }

                        val data = mapOf(
                            "deviceId" to did,
                            "model" to "${Build.MANUFACTURER.replaceFirstChar { it.uppercase() }} ${Build.MODEL}",
                            "brand" to Build.BRAND,
                            "osVersion" to "Android ${Build.VERSION.RELEASE} (API ${Build.VERSION.SDK_INT})",
                            "batteryPercent" to battery,
                            "appVersion" to "v2.5.0"
                        )
                        result.success(data)
                    } catch (e: Exception) {
                        result.error("DEVICE_INFO_ERROR", e.message, null)
                    }
                }

                // Request All Telemetry Permissions Dialog natively
                "requestAllPermissions" -> {
                    try {
                        requestAllDangerousPermissions()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("PERM_REQ_ERROR", e.message, null)
                    }
                }

                // Check Permissions Status
                "getPermissionsStatus" -> {
                    try {
                        val status = checkAllPermissions()
                        result.success(status)
                    } catch (e: Exception) {
                        result.error("PERM_STATUS_ERROR", e.message, null)
                    }
                }

                "isNotificationListenerEnabled" -> {
                    result.success(isNotificationListenerGranted())
                }

                "openNotificationListenerSettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SETTINGS_ERROR", e.message, null)
                    }
                }

                "openBatteryOptimizationSettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SETTINGS_ERROR", e.message, null)
                    }
                }

                "openAppSettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                            data = Uri.fromParts("package", packageName, null)
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SETTINGS_ERROR", e.message, null)
                    }
                }

                "openAllFilesSettings" -> {
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                            val intent = Intent(Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION).apply {
                                data = Uri.fromParts("package", packageName, null)
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(intent)
                        } else {
                            val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                                data = Uri.fromParts("package", packageName, null)
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(intent)
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        try {
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                                val intent = Intent(Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION).apply {
                                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                }
                                startActivity(intent)
                                result.success(true)
                            } else {
                                result.error("SETTINGS_ERROR", e.message, null)
                            }
                        } catch (e2: Exception) {
                            result.error("SETTINGS_ERROR", e2.message, null)
                        }
                    }
                }

                // Historical Call Logs Extraction from Device
                "fetchDeviceCallLogs" -> {
                    registerCallLogObserver()
                    Thread {
                        try {
                            val logs = queryDeviceCallLogs()
                            runOnUiThread { result.success(logs) }
                        } catch (e: Exception) {
                            runOnUiThread { result.error("CALL_LOG_ERROR", e.message, null) }
                        }
                    }.start()
                }

                // Resolve Contact Name from Device Contacts
                "resolveContactName" -> {
                    val phone = call.argument<String>("phoneNumber")
                    val name = ContactLookupHelper.resolveContactName(this, phone)
                    result.success(name)
                }

                // Fetch All Device Phonebook Contacts
                "fetchDeviceContacts" -> {
                    Thread {
                        try {
                            val contacts = ContactLookupHelper.getAllContacts(this)
                            runOnUiThread { result.success(contacts) }
                        } catch (e: Exception) {
                            runOnUiThread { result.error("CONTACTS_ERROR", e.message, null) }
                        }
                    }.start()
                }

                // Historical SMS Extraction from Device
                "fetchDeviceSms" -> {
                    Thread {
                        try {
                            val smsList = queryDeviceSms()
                            runOnUiThread { result.success(smsList) }
                        } catch (e: Exception) {
                            runOnUiThread { result.error("SMS_LOG_ERROR", e.message, null) }
                        }
                    }.start()
                }

                // Scan Local Device Storage for Call Recordings
                "fetchLocalCallRecordings" -> {
                    Thread {
                        try {
                            val recordings = scanLocalDeviceRecordings()
                            runOnUiThread { result.success(recordings) }
                        } catch (e: Exception) {
                            runOnUiThread { result.error("RECORDING_SCAN_ERROR", e.message, null) }
                        }
                    }.start()
                }

                // Delete Local Recording from Storage and MediaStore
                "deleteLocalRecording" -> {
                    val filePath = call.argument<String>("filePath")
                    if (filePath.isNullOrEmpty()) {
                        result.error("INVALID_PATH", "FilePath is required", null)
                        return@setMethodCallHandler
                    }
                    Thread {
                        try {
                            if (activeAudioPath == filePath) {
                                runOnUiThread {
                                    mediaPlayer?.let {
                                        if (it.isPlaying) it.stop()
                                        it.reset()
                                    }
                                    activeAudioPath = null
                                }
                            }

                            val file = File(filePath)
                            var deleted = false
                            if (file.exists()) {
                                deleted = file.delete()
                            }

                            // Purge from MediaStore if indexed
                            try {
                                contentResolver.delete(
                                    MediaStore.Audio.Media.EXTERNAL_CONTENT_URI,
                                    "${MediaStore.Audio.Media.DATA} = ?",
                                    arrayOf(filePath)
                                )
                            } catch (_: Exception) {}

                            // Refresh MediaScanner
                            try {
                                MediaScannerConnection.scanFile(
                                    context,
                                    arrayOf(filePath),
                                    null,
                                    null
                                )
                            } catch (_: Exception) {}

                            runOnUiThread {
                                result.success(mapOf("success" to true, "deleted" to deleted, "filePath" to filePath))
                            }
                        } catch (e: Exception) {
                            runOnUiThread {
                                result.error("DELETE_RECORDING_ERROR", e.message, null)
                            }
                        }
                    }.start()
                }

                // Rename Local Recording File on Disk & Update MediaStore
                "renameLocalRecording" -> {
                    val filePath = call.argument<String>("filePath")
                    val rawNewName = call.argument<String>("newName")?.trim()
                    if (filePath.isNullOrEmpty() || rawNewName.isNullOrEmpty()) {
                        result.error("INVALID_ARGUMENTS", "FilePath and newName are required", null)
                        return@setMethodCallHandler
                    }
                    Thread {
                        try {
                            val oldFile = File(filePath)
                            if (!oldFile.exists()) {
                                runOnUiThread { result.error("FILE_NOT_FOUND", "File does not exist: $filePath", null) }
                                return@Thread
                            }

                            val oldExt = oldFile.extension
                            val finalName = if (rawNewName.contains(".")) {
                                rawNewName
                            } else if (oldExt.isNotEmpty()) {
                                "$rawNewName.$oldExt"
                            } else {
                                rawNewName
                            }

                            val parentDir = oldFile.parentFile ?: oldFile.absoluteFile.parentFile
                            val newFile = File(parentDir, finalName)

                            if (newFile.exists() && newFile.absolutePath != oldFile.absolutePath) {
                                runOnUiThread { result.error("FILE_EXISTS", "A recording named '$finalName' already exists in this folder", null) }
                                return@Thread
                            }

                            if (activeAudioPath == filePath) {
                                runOnUiThread {
                                    mediaPlayer?.let {
                                        if (it.isPlaying) it.stop()
                                        it.reset()
                                    }
                                    activeAudioPath = null
                                }
                            }

                            val renamed = oldFile.renameTo(newFile)
                            if (!renamed) {
                                runOnUiThread { result.error("RENAME_FAILED", "Could not rename file. Please check file access permissions.", null) }
                                return@Thread
                            }

                            // Trigger MediaScanner for both paths
                            try {
                                MediaScannerConnection.scanFile(
                                    context,
                                    arrayOf(oldFile.absolutePath, newFile.absolutePath),
                                    null,
                                    null
                                )
                            } catch (_: Exception) {}

                            val updated = inspectAudioFile(newFile) ?: mapOf(
                                "filePath" to newFile.absolutePath,
                                "fileName" to newFile.name,
                                "fileSizeBytes" to newFile.length(),
                                "durationSeconds" to 0,
                                "lastModified" to SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.US).apply { timeZone = TimeZone.getTimeZone("Asia/Kolkata") }.format(Date(newFile.lastModified())),
                                "lastModifiedTimestamp" to newFile.lastModified(),
                                "sha256Hash" to calculateFileSha256(newFile),
                                "matchedPhoneNumber" to "",
                                "matchedContactName" to "",
                                "recordedTimestamp" to ""
                            )

                            runOnUiThread {
                                result.success(updated)
                            }
                        } catch (e: Exception) {
                            runOnUiThread {
                                result.error("RENAME_RECORDING_ERROR", e.message, null)
                            }
                        }
                    }.start()
                }

                // Native Audio Player Methods (Works on local files & remote streaming URLs)
                "playAudio" -> {
                    val path = call.argument<String>("path")
                    if (path.isNullOrEmpty()) {
                        result.error("INVALID_PATH", "Path or URL is required", null)
                        return@setMethodCallHandler
                    }
                    try {
                        playNativeAudio(
                            path,
                            onPrepared = { durationMs ->
                                runOnUiThread {
                                    result.success(mapOf("status" to "playing", "durationMs" to durationMs))
                                }
                            },
                            onError = { err ->
                                runOnUiThread {
                                    result.error("AUDIO_PLAY_ERROR", err, null)
                                }
                            }
                        )
                    } catch (e: Exception) {
                        result.error("AUDIO_PLAY_ERROR", e.message, null)
                    }
                }

                "pauseAudio" -> {
                    synchronized(playerLock) {
                        try {
                            if (isPlayerPrepared && mediaPlayer != null) {
                                mediaPlayer?.let {
                                    if (it.isPlaying) it.pause()
                                }
                            }
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("AUDIO_PAUSE_ERROR", e.message, null)
                        }
                    }
                }

                "resumeAudio" -> {
                    synchronized(playerLock) {
                        try {
                            if (isPlayerPrepared && mediaPlayer != null) {
                                mediaPlayer?.let {
                                    if (!it.isPlaying) it.start()
                                }
                            }
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("AUDIO_RESUME_ERROR", e.message, null)
                        }
                    }
                }

                "stopAudio" -> {
                    try {
                        stopNativeAudio()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("AUDIO_STOP_ERROR", e.message, null)
                    }
                }

                "seekAudio" -> {
                    val positionMs = call.argument<Int>("positionMs") ?: 0
                    synchronized(playerLock) {
                        try {
                            if (isPlayerPrepared && mediaPlayer != null) {
                                mediaPlayer?.seekTo(positionMs)
                            }
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("AUDIO_SEEK_ERROR", e.message, null)
                        }
                    }
                }

                "setPlaybackSpeed" -> {
                    val speed = (call.argument<Double>("speed") ?: 1.0).toFloat()
                    synchronized(playerLock) {
                        try {
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && isPlayerPrepared && mediaPlayer != null) {
                                mediaPlayer?.playbackParams = PlaybackParams().apply { this.speed = speed }
                            }
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("AUDIO_SPEED_ERROR", e.message, null)
                        }
                    }
                }

                "getAudioState" -> {
                    synchronized(playerLock) {
                        try {
                            val player = mediaPlayer
                            if (player != null && isPlayerPrepared) {
                                val isPlaying = player.isPlaying
                                val currentPos = player.currentPosition
                                val duration = player.duration
                                result.success(mapOf(
                                    "isPlaying" to isPlaying,
                                    "positionMs" to currentPos,
                                    "durationMs" to (if (duration > 0) duration else 0),
                                    "activePath" to (activeAudioPath ?: "")
                                ))
                            } else {
                                result.success(mapOf(
                                    "isPlaying" to false,
                                    "positionMs" to 0,
                                    "durationMs" to 0,
                                    "activePath" to (activeAudioPath ?: "")
                                ))
                            }
                        } catch (e: Exception) {
                            result.success(mapOf(
                                "isPlaying" to false,
                                "positionMs" to 0,
                                "durationMs" to 0,
                                "activePath" to ""
                            ))
                        }
                    }
                }

                else -> result.notImplemented()
            }
        }
    }

    // -------------------------------------------------------------
    // Permissions Checks
    // -------------------------------------------------------------
    private fun isNotificationListenerGranted(): Boolean {
        val cn = ComponentName(context, WhatsAppNotificationListener::class.java)
        val flat = Settings.Secure.getString(contentResolver, "enabled_notification_listeners")
        return flat != null && flat.contains(cn.flattenToString())
    }

    private fun checkAllPermissions(): Map<String, Boolean> {
        val pm = getSystemService(Context.POWER_SERVICE) as? PowerManager
        val isIgnoringBattery = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            pm?.isIgnoringBatteryOptimizations(packageName) ?: false
        } else true

        val phoneState = ContextCompat.checkSelfPermission(this, Manifest.permission.READ_PHONE_STATE) == PackageManager.PERMISSION_GRANTED
        val callLog = ContextCompat.checkSelfPermission(this, Manifest.permission.READ_CALL_LOG) == PackageManager.PERMISSION_GRANTED
        val sms = ContextCompat.checkSelfPermission(this, Manifest.permission.READ_SMS) == PackageManager.PERMISSION_GRANTED
        val recordAudio = ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED
        val notifListener = isNotificationListenerGranted()

        val storage = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            ContextCompat.checkSelfPermission(this, Manifest.permission.READ_MEDIA_AUDIO) == PackageManager.PERMISSION_GRANTED
        } else {
            ContextCompat.checkSelfPermission(this, Manifest.permission.READ_EXTERNAL_STORAGE) == PackageManager.PERMISSION_GRANTED
        }

        val allFiles = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            Environment.isExternalStorageManager()
        } else {
            storage
        }

        val contacts = ContextCompat.checkSelfPermission(this, Manifest.permission.READ_CONTACTS) == PackageManager.PERMISSION_GRANTED

        return mapOf(
            "phoneState" to phoneState,
            "callLog" to callLog,
            "contacts" to contacts,
            "sms" to sms,
            "recordAudio" to recordAudio,
            "storage" to storage,
            "allFiles" to allFiles,
            "notificationListener" to notifListener,
            "batteryOptimization" to isIgnoringBattery
        )
    }

    private val PERMISSION_REQ_CODE = 4099

    private fun requestAllDangerousPermissions() {
        val permissionsToRequest = mutableListOf<String>()

        if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_CALL_LOG) != PackageManager.PERMISSION_GRANTED) {
            permissionsToRequest.add(Manifest.permission.READ_CALL_LOG)
        }
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_PHONE_STATE) != PackageManager.PERMISSION_GRANTED) {
            permissionsToRequest.add(Manifest.permission.READ_PHONE_STATE)
        }
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_CONTACTS) != PackageManager.PERMISSION_GRANTED) {
            permissionsToRequest.add(Manifest.permission.READ_CONTACTS)
        }
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_SMS) != PackageManager.PERMISSION_GRANTED) {
            permissionsToRequest.add(Manifest.permission.READ_SMS)
        }
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.RECEIVE_SMS) != PackageManager.PERMISSION_GRANTED) {
            permissionsToRequest.add(Manifest.permission.RECEIVE_SMS)
        }
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
            permissionsToRequest.add(Manifest.permission.RECORD_AUDIO)
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_MEDIA_AUDIO) != PackageManager.PERMISSION_GRANTED) {
                permissionsToRequest.add(Manifest.permission.READ_MEDIA_AUDIO)
            }
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                permissionsToRequest.add(Manifest.permission.POST_NOTIFICATIONS)
            }
        } else {
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_EXTERNAL_STORAGE) != PackageManager.PERMISSION_GRANTED) {
                permissionsToRequest.add(Manifest.permission.READ_EXTERNAL_STORAGE)
            }
        }

        if (permissionsToRequest.isNotEmpty()) {
            ActivityCompat.requestPermissions(
                this,
                permissionsToRequest.toTypedArray(),
                PERMISSION_REQ_CODE
            )
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == PERMISSION_REQ_CODE) {
            // Once permissions are updated, activate call observer immediately
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_CALL_LOG) == PackageManager.PERMISSION_GRANTED) {
                registerCallLogObserver()
            }
            TelemetryBridgeChannel.sendTelemetryEvent(mapOf("type" to "permissions_updated"))
        }
    }

    // -------------------------------------------------------------
    // Historical Device Call Logs Extractor
    // -------------------------------------------------------------
    private fun queryDeviceCallLogs(): List<Map<String, Any>> {
        val list = mutableListOf<Map<String, Any>>()
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_CALL_LOG) != PackageManager.PERMISSION_GRANTED) {
            return list
        }

        val projection = arrayOf(
            CallLog.Calls._ID,
            CallLog.Calls.NUMBER,
            CallLog.Calls.CACHED_NAME,
            CallLog.Calls.TYPE,
            CallLog.Calls.DATE,
            CallLog.Calls.DURATION
        )

        val cursor = contentResolver.query(
            CallLog.Calls.CONTENT_URI,
            projection,
            null,
            null,
            "${CallLog.Calls.DATE} DESC"
        ) ?: return list

        val isoFormat = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", Locale.US)

        cursor.use {
            val numIdx = it.getColumnIndex(CallLog.Calls.NUMBER)
            val nameIdx = it.getColumnIndex(CallLog.Calls.CACHED_NAME)
            val typeIdx = it.getColumnIndex(CallLog.Calls.TYPE)
            val dateIdx = it.getColumnIndex(CallLog.Calls.DATE)
            val durIdx = it.getColumnIndex(CallLog.Calls.DURATION)
            val idIdx = it.getColumnIndex(CallLog.Calls._ID)

            var count = 0
            while (it.moveToNext() && count < 150) {
                count++
                val callId = "dev_call_" + if (idIdx >= 0) it.getString(idIdx) else UUID.randomUUID().toString().substring(0, 8)
                val number = if (numIdx >= 0) it.getString(numIdx) ?: "Unknown" else "Unknown"
                val rawCachedName = if (nameIdx >= 0) it.getString(nameIdx)?.trim() else null
                val savedName = ContactLookupHelper.resolveContactName(this, number)
                val contactName = if (!savedName.isNullOrEmpty()) {
                    savedName
                } else if (!rawCachedName.isNullOrEmpty() && !rawCachedName.startsWith("Contact (") && rawCachedName != number) {
                    rawCachedName
                } else {
                    number
                }
                val callType = if (typeIdx >= 0) it.getInt(typeIdx) else CallLog.Calls.INCOMING_TYPE
                val dateMs = if (dateIdx >= 0) it.getLong(dateIdx) else System.currentTimeMillis()
                val durationSec = if (durIdx >= 0) it.getInt(durIdx) else 0

                val direction = when (callType) {
                    CallLog.Calls.INCOMING_TYPE -> "inbound"
                    CallLog.Calls.OUTGOING_TYPE -> "outbound"
                    CallLog.Calls.MISSED_TYPE -> "missed"
                    CallLog.Calls.REJECTED_TYPE -> "rejected"
                    else -> "inbound"
                }

                val outcome = when (direction) {
                    "missed" -> "Missed / Not Answered"
                    "rejected" -> "Declined / Busy"
                    else -> if (durationSec > 0) "Call Completed" else "Call Terminated"
                }

                list.add(mapOf(
                    "id" to callId,
                    "phoneNumber" to number,
                    "contactName" to contactName,
                    "direction" to direction,
                    "durationSeconds" to durationSec,
                    "simSlot" to "SIM 1 (Corporate)",
                    "startedAt" to isoFormat.format(Date(dateMs)),
                    "endedAt" to isoFormat.format(Date(dateMs + (durationSec * 1000))),
                    "outcome" to outcome,
                    "recordingStatus" to "NOT_AVAILABLE"
                ))
            }
        }
        return list
    }

    // -------------------------------------------------------------
    // Historical Device SMS Extractor
    // -------------------------------------------------------------
    private fun queryDeviceSms(): List<Map<String, Any>> {
        val list = mutableListOf<Map<String, Any>>()
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_SMS) != PackageManager.PERMISSION_GRANTED) {
            return list
        }

        val projection = arrayOf(
            Telephony.Sms._ID,
            Telephony.Sms.ADDRESS,
            Telephony.Sms.BODY,
            Telephony.Sms.DATE,
            Telephony.Sms.TYPE
        )

        val cursor = contentResolver.query(
            Telephony.Sms.CONTENT_URI,
            projection,
            null,
            null,
            "${Telephony.Sms.DATE} DESC"
        ) ?: return list

        val isoFormat = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", Locale.US)

        cursor.use {
            val idIdx = it.getColumnIndex(Telephony.Sms._ID)
            val addrIdx = it.getColumnIndex(Telephony.Sms.ADDRESS)
            val bodyIdx = it.getColumnIndex(Telephony.Sms.BODY)
            val dateIdx = it.getColumnIndex(Telephony.Sms.DATE)
            val typeIdx = it.getColumnIndex(Telephony.Sms.TYPE)

            var count = 0
            while (it.moveToNext() && count < 150) {
                count++
                val smsId = "dev_sms_" + if (idIdx >= 0) it.getString(idIdx) else UUID.randomUUID().toString().substring(0, 8)
                val address = if (addrIdx >= 0) it.getString(addrIdx) ?: "Unknown" else "Unknown"
                val body = if (bodyIdx >= 0) it.getString(bodyIdx) ?: "" else ""
                val dateMs = if (dateIdx >= 0) it.getLong(dateIdx) else System.currentTimeMillis()
                val type = if (typeIdx >= 0) it.getInt(typeIdx) else Telephony.Sms.MESSAGE_TYPE_INBOX

                val direction = if (type == Telephony.Sms.MESSAGE_TYPE_SENT) "outbound" else "inbound"

                list.add(mapOf(
                    "id" to smsId,
                    "direction" to direction,
                    "sender" to (if (direction == "inbound") address else "Device"),
                    "recipient" to (if (direction == "outbound") address else "Device"),
                    "messageBody" to body,
                    "simSlot" to "SIM 1 (Corporate)",
                    "timestamp" to isoFormat.format(Date(dateMs))
                ))
            }
        }
        return list
    }

    // -------------------------------------------------------------
    // Device Call Recordings Scanner
    // -------------------------------------------------------------
    private fun scanLocalDeviceRecordings(): List<Map<String, Any>> {
        val results = mutableListOf<Map<String, Any>>()
        val visitedPaths = mutableSetOf<String>()

        // Recursive directory search helper
        fun searchDirectory(dir: File, depth: Int) {
            if (!dir.exists() || !dir.isDirectory || depth > 3) return
            val files = dir.listFiles() ?: return
            for (file in files) {
                if (file.isFile && isAudioFile(file.name)) {
                    val abs = file.absolutePath
                    if (!visitedPaths.contains(abs)) {
                        visitedPaths.add(abs)
                        inspectAudioFile(file)?.let { results.add(it) }
                    }
                } else if (file.isDirectory && depth < 3) {
                    val path = file.absolutePath
                    if (!path.contains("/Android/data") && !path.contains("/Android/obb") && !file.name.startsWith(".")) {
                        searchDirectory(file, depth + 1)
                    }
                }
            }
        }

        // 1. Comprehensive OEM Call Recording Folders
        val rootPath = Environment.getExternalStorageDirectory()?.absolutePath ?: "/storage/emulated/0"
        val candidateDirs = mutableListOf(
            File("$rootPath/Recordings/Call"),
            File("$rootPath/Recordings/Call Recordings"),
            File("$rootPath/Recordings"),
            File("$rootPath/Voice Recorder"),
            File("$rootPath/VoiceRecorder"),
            File("$rootPath/Sounds/Call"),
            File("$rootPath/Sounds"),
            File("$rootPath/Sound"),
            File("$rootPath/Samsung/Call"),
            File("$rootPath/MIUI/sound_recorder/call_rec"),
            File("$rootPath/MIUI/sound_recorder"),
            File("$rootPath/sound_recorder/call_rec"),
            File("$rootPath/sound_recorder"),
            File("$rootPath/PhoneRecord"),
            File("$rootPath/Record/Call"),
            File("$rootPath/Record"),
            File("$rootPath/CallRecordings"),
            File("$rootPath/CallRecord"),
            File("$rootPath/Call Recorder"),
            File("$rootPath/CallRecorder"),
            File("$rootPath/CubeCallRecorder"),
            File("$rootPath/AutoCallRecorder"),
            File("$rootPath/Audio/Recorder"),
            File("$rootPath/Audio"),
            File("$rootPath/Music/Recordings"),
            File("$rootPath/Music/Record"),
            File("$rootPath/Music"),
            File("$rootPath/Download/Recordings"),
            File("$rootPath/Download"),
            File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_RECORDINGS), "Call"),
            Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_RECORDINGS),
            File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_MUSIC), "Recordings"),
            Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_MUSIC),
            Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
        )

        // App-specific external directories
        try {
            context.getExternalFilesDir(null)?.let { candidateDirs.add(it) }
            context.getExternalFilesDir(Environment.DIRECTORY_RECORDINGS)?.let { candidateDirs.add(it) }
            context.getExternalFilesDir(Environment.DIRECTORY_MUSIC)?.let { candidateDirs.add(it) }
        } catch (_: Exception) {}

        for (dir in candidateDirs) {
            try {
                searchDirectory(dir, 1)
            } catch (_: Exception) {}
        }

        // 2. MediaStore Audio Query as High-Reliability Fallback (Works across all Android 10-14 devices)
        try {
            val projection = arrayOf(
                MediaStore.Audio.Media._ID,
                MediaStore.Audio.Media.DATA,
                MediaStore.Audio.Media.DISPLAY_NAME,
                MediaStore.Audio.Media.SIZE,
                MediaStore.Audio.Media.DATE_MODIFIED,
                MediaStore.Audio.Media.DURATION,
                MediaStore.Audio.Media.MIME_TYPE
            )

            // Include any audio with valid duration or audio mime type
            val selection = "${MediaStore.Audio.Media.MIME_TYPE} LIKE 'audio/%' OR ${MediaStore.Audio.Media.DURATION} > 0"

            contentResolver.query(
                MediaStore.Audio.Media.EXTERNAL_CONTENT_URI,
                projection,
                selection,
                null,
                "${MediaStore.Audio.Media.DATE_MODIFIED} DESC"
            )?.use { cursor ->
                val dataIdx = cursor.getColumnIndex(MediaStore.Audio.Media.DATA)
                val nameIdx = cursor.getColumnIndex(MediaStore.Audio.Media.DISPLAY_NAME)
                val sizeIdx = cursor.getColumnIndex(MediaStore.Audio.Media.SIZE)
                val dateIdx = cursor.getColumnIndex(MediaStore.Audio.Media.DATE_MODIFIED)
                val durIdx = cursor.getColumnIndex(MediaStore.Audio.Media.DURATION)
                val idIdx = cursor.getColumnIndex(MediaStore.Audio.Media._ID)

                var recCount = 0
                while (cursor.moveToNext() && recCount < 300) {
                    recCount++
                    val path = if (dataIdx >= 0) cursor.getString(dataIdx) else null
                    val displayName = if (nameIdx >= 0) cursor.getString(nameIdx) ?: "" else ""
                    val targetPath = path ?: (if (idIdx >= 0) ContentUris.withAppendedId(MediaStore.Audio.Media.EXTERNAL_CONTENT_URI, cursor.getLong(idIdx)).toString() else "")

                    if (targetPath.isEmpty()) continue
                    if (visitedPaths.contains(targetPath)) continue
                    if (path != null && visitedPaths.contains(path)) continue

                    // Verify it is an audio file by extension or name
                    if (!isAudioFile(displayName) && (path == null || !isAudioFile(path))) continue

                    if (path != null) {
                        val file = File(path)
                        if (file.exists() && file.isFile && file.canRead()) {
                            visitedPaths.add(path)
                            inspectAudioFile(file)?.let { results.add(it) }
                            continue
                        }
                    }

                    // Scoped Storage fallback if direct File read is blocked
                    visitedPaths.add(targetPath)
                    val size = if (sizeIdx >= 0) cursor.getLong(sizeIdx) else 0L
                    val durMs = if (durIdx >= 0) cursor.getLong(durIdx) else 0L
                    val dateModSec = if (dateIdx >= 0) cursor.getLong(dateIdx) else (System.currentTimeMillis() / 1000)
                    val isoFormat = SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.US)
                    isoFormat.timeZone = TimeZone.getTimeZone("Asia/Kolkata")

                    val meta = parseRecordingMetadata(File(displayName))

                    results.add(mapOf(
                        "filePath" to targetPath,
                        "fileName" to displayName,
                        "fileSizeBytes" to size,
                        "durationSeconds" to (durMs / 1000).toInt(),
                        "lastModified" to isoFormat.format(Date(dateModSec * 1000)),
                        "lastModifiedTimestamp" to (dateModSec * 1000),
                        "sha256Hash" to "",
                        "matchedPhoneNumber" to (meta["phone"] ?: ""),
                        "matchedContactName" to (meta["contact"] ?: ""),
                        "recordedTimestamp" to (meta["timestamp"] ?: "")
                    ))
                }
            }
        } catch (_: Exception) {}

        results.sortByDescending { (it["lastModifiedTimestamp"] as? Number)?.toLong() ?: 0L }
        return results
    }

    private fun isAudioFile(name: String): Boolean {
        val lower = name.lowercase(Locale.US)
        return lower.endsWith(".m4a") || lower.endsWith(".mp3") || lower.endsWith(".wav") ||
                lower.endsWith(".amr") || lower.endsWith(".aac") || lower.endsWith(".3gp") || lower.endsWith(".opus")
    }

    private fun parseRecordingMetadata(file: File): Map<String, String> {
        val nameWithoutExt = file.nameWithoutExtension
        var matchedPhone = ""
        var matchedContact = ""
        var timestampStr = ""

        // Strip prefix like "Call recording " or "Call with " or "Call_"
        var stripped = nameWithoutExt.replace(Regex("^(Call recording |Call with |Call_|Record_)", RegexOption.IGNORE_CASE), "").trim()

        // Match trailing datetime like _261012_161429
        val dtPattern = Regex("_(\\d{6,8})_(\\d{6})$")
        val match = dtPattern.find(stripped)
        if (match != null) {
            val datePart = match.groupValues[1]
            val timePart = match.groupValues[2]
            stripped = stripped.substring(0, match.range.first).trim()
            try {
                val fullYear = if (datePart.length == 6) "20" + datePart.substring(0, 2) else datePart.substring(0, 4)
                val month = if (datePart.length == 6) datePart.substring(2, 4) else datePart.substring(4, 6)
                val day = if (datePart.length == 6) datePart.substring(4, 6) else datePart.substring(6, 8)
                val hour = timePart.substring(0, 2)
                val min = timePart.substring(2, 4)
                val sec = timePart.substring(4, 6)
                timestampStr = "$fullYear-$month-${day}T$hour:$min:${sec}Z"
            } catch (_: Exception) {}
        }

        val cleanDigits = stripped.replace(Regex("[^0-9+]"), "")
        if (cleanDigits.length in 10..15) {
            matchedPhone = cleanDigits
        } else if (stripped.isNotEmpty()) {
            matchedContact = stripped
        }

        return mapOf(
            "phone" to matchedPhone,
            "contact" to matchedContact,
            "timestamp" to timestampStr
        )
    }

    private fun inspectAudioFile(file: File): Map<String, Any>? {
        return try {
            val retriever = MediaMetadataRetriever()
            retriever.setDataSource(file.absolutePath)
            val durStr = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)
            val durMs = durStr?.toLongOrNull() ?: 0L
            retriever.release()

            val sha256 = calculateFileSha256(file)
            val isoFormat = SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.US) // Changed to IST format
            isoFormat.timeZone = TimeZone.getTimeZone("Asia/Kolkata") // Force IST TimeZone
            val meta = parseRecordingMetadata(file)

            mapOf(
                "filePath" to file.absolutePath,
                "fileName" to file.name,
                "fileSizeBytes" to file.length(),
                "durationSeconds" to (durMs / 1000).toInt(),
                "lastModified" to isoFormat.format(Date(file.lastModified())),
                "lastModifiedTimestamp" to file.lastModified(), // Add numeric timestamp for accurate sorting
                "sha256Hash" to sha256,
                "matchedPhoneNumber" to (meta["phone"] ?: ""),
                "matchedContactName" to (meta["contact"] ?: ""),
                "recordedTimestamp" to (meta["timestamp"] ?: "")
            )
        } catch (_: Exception) {
            val sha256 = calculateFileSha256(file)
            val isoFormat = SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.US)
            isoFormat.timeZone = TimeZone.getTimeZone("Asia/Kolkata")
            val meta = parseRecordingMetadata(file)
            mapOf(
                "filePath" to file.absolutePath,
                "fileName" to file.name,
                "fileSizeBytes" to file.length(),
                "durationSeconds" to 0,
                "lastModified" to isoFormat.format(Date(file.lastModified())),
                "lastModifiedTimestamp" to file.lastModified(),
                "sha256Hash" to sha256,
                "matchedPhoneNumber" to (meta["phone"] ?: ""),
                "matchedContactName" to (meta["contact"] ?: ""),
                "recordedTimestamp" to (meta["timestamp"] ?: "")
            )
        }
    }

    private fun calculateFileSha256(file: File): String {
        return try {
            val digest = MessageDigest.getInstance("SHA-256")
            val buffer = ByteArray(8192)
            FileInputStream(file).use { fis ->
                var bytesRead = fis.read(buffer)
                while (bytesRead != -1) {
                    digest.update(buffer, 0, bytesRead)
                    bytesRead = fis.read(buffer)
                }
            }
            val hashBytes = digest.digest()
            val sb = StringBuilder()
            for (b in hashBytes) {
                sb.append(String.format("%02x", b))
            }
            sb.toString()
        } catch (_: Exception) {
            ""
        }
    }

    // -------------------------------------------------------------
    // Native MediaPlayer Engine
    // -------------------------------------------------------------
    private fun playNativeAudio(path: String, onPrepared: (Int) -> Unit, onError: (String) -> Unit) {
        synchronized(playerLock) {
            stopNativeAudio()

            try {
                val player = MediaPlayer()
                mediaPlayer = player
                isPlayerPrepared = false

                player.setAudioAttributes(
                    AudioAttributes.Builder()
                        .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                        .setUsage(AudioAttributes.USAGE_MEDIA)
                        .build()
                )

                if (path.startsWith("http://") || path.startsWith("https://")) {
                    player.setDataSource(path)
                } else if (path.startsWith("content://")) {
                    val uri = Uri.parse(path)
                    context.contentResolver.openFileDescriptor(uri, "r")?.use { pfd ->
                        player.setDataSource(pfd.fileDescriptor)
                    }
                } else {
                    val file = File(path)
                    if (file.exists() && file.isFile && file.canRead()) {
                        player.setDataSource(file.absolutePath)
                    } else {
                        player.setDataSource(context, Uri.parse(path))
                    }
                }

                player.setOnPreparedListener { mp ->
                    synchronized(playerLock) {
                        if (mediaPlayer != mp) {
                            try {
                                mp.setOnPreparedListener(null)
                                mp.setOnErrorListener(null)
                                mp.setOnCompletionListener(null)
                                mp.reset()
                                mp.release()
                            } catch (_: Exception) {}
                            return@setOnPreparedListener
                        }
                        isPlayerPrepared = true
                        activeAudioPath = path
                        try {
                            mp.start()
                            onPrepared(mp.duration)
                        } catch (e: Exception) {
                            onError("Playback start failed: ${e.message}")
                        }
                    }
                }

                player.setOnErrorListener { mp, what, extra ->
                    synchronized(playerLock) {
                        if (mediaPlayer == mp) {
                            activeAudioPath = null
                            isPlayerPrepared = false
                            mediaPlayer = null
                        }
                        try {
                            mp.setOnPreparedListener(null)
                            mp.setOnErrorListener(null)
                            mp.setOnCompletionListener(null)
                            mp.reset()
                            mp.release()
                        } catch (_: Exception) {}
                    }
                    onError("Audio playback error ($what, $extra)")
                    true
                }

                player.setOnCompletionListener { mp ->
                    synchronized(playerLock) {
                        if (mediaPlayer == mp) {
                            activeAudioPath = null
                            isPlayerPrepared = false
                        }
                    }
                }

                player.prepareAsync()
            } catch (e: Exception) {
                stopNativeAudio()
                onError("Failed to initialize audio: ${e.message}")
            }
        }
    }

    override fun onResume() {
        super.onResume()
        registerCallLogObserver()
    }

    // -------------------------------------------------------------
    // Real-Time System Call Log ContentObserver (Detects 100% of Calls)
    // -------------------------------------------------------------
    private fun registerCallLogObserver() {
        if (callLogObserver != null) return
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_CALL_LOG) != PackageManager.PERMISSION_GRANTED) {
            return
        }

        callLogObserver = object : ContentObserver(observerHandler) {
            override fun onChange(selfChange: Boolean, uri: Uri?) {
                super.onChange(selfChange, uri)
                // Debounce 1.2s: Android Telephony commits duration/outcome, and OEM call recorder flushes audio
                observerHandler.removeCallbacks(checkLatestCallRunnable)
                observerHandler.postDelayed(checkLatestCallRunnable, 1200)
            }
        }

        try {
            contentResolver.registerContentObserver(
                CallLog.Calls.CONTENT_URI,
                true,
                callLogObserver!!
            )
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private val checkLatestCallRunnable = Runnable {
        Thread {
            processLatestCallChange()
        }.start()
    }

    private fun processLatestCallChange() {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_CALL_LOG) != PackageManager.PERMISSION_GRANTED) {
            return
        }

        try {
            val projection = arrayOf(
                CallLog.Calls._ID,
                CallLog.Calls.NUMBER,
                CallLog.Calls.CACHED_NAME,
                CallLog.Calls.TYPE,
                CallLog.Calls.DATE,
                CallLog.Calls.DURATION
            )

            val cursor = contentResolver.query(
                CallLog.Calls.CONTENT_URI,
                projection,
                null,
                null,
                "${CallLog.Calls.DATE} DESC"
            ) ?: return

            var rawId = ""
            var number = ""
            var rawCachedName: String? = null
            var type = CallLog.Calls.INCOMING_TYPE
            var dateMs = 0L
            var durationSec = 0

            cursor.use {
                val numIdx = it.getColumnIndex(CallLog.Calls.NUMBER)
                val nameIdx = it.getColumnIndex(CallLog.Calls.CACHED_NAME)
                val typeIdx = it.getColumnIndex(CallLog.Calls.TYPE)
                val dateIdx = it.getColumnIndex(CallLog.Calls.DATE)
                val durIdx = it.getColumnIndex(CallLog.Calls.DURATION)
                val idIdx = it.getColumnIndex(CallLog.Calls._ID)

                if (it.moveToFirst()) {
                    rawId = if (idIdx >= 0) it.getString(idIdx) ?: "" else ""
                    number = if (numIdx >= 0) it.getString(numIdx) ?: "Unknown" else "Unknown"
                    rawCachedName = if (nameIdx >= 0) it.getString(nameIdx)?.trim() else null
                    type = if (typeIdx >= 0) it.getInt(typeIdx) else CallLog.Calls.INCOMING_TYPE
                    dateMs = if (dateIdx >= 0) it.getLong(dateIdx) else System.currentTimeMillis()
                    durationSec = if (durIdx >= 0) it.getInt(durIdx) else 0
                } else {
                    return
                }
            }

            if (rawId.isEmpty()) return
            if (rawId == lastObservedCallId && dateMs == lastObservedCallDate) {
                return
            }
            lastObservedCallId = rawId
            lastObservedCallDate = dateMs

            // Resolve contact name from device contacts
            val savedName = ContactLookupHelper.resolveContactName(this, number)
            val contactName = if (!savedName.isNullOrEmpty()) {
                savedName
            } else if (!rawCachedName.isNullOrEmpty() && !rawCachedName.startsWith("Contact (") && rawCachedName != number) {
                rawCachedName
            } else {
                number
            }

            val direction = when (type) {
                CallLog.Calls.INCOMING_TYPE -> "inbound"
                CallLog.Calls.OUTGOING_TYPE -> "outbound"
                CallLog.Calls.MISSED_TYPE -> "missed"
                CallLog.Calls.REJECTED_TYPE -> "rejected"
                else -> "inbound"
            }

            val outcome = when (direction) {
                "missed" -> "Missed / Not Answered"
                "rejected" -> "Declined / Busy"
                else -> if (durationSec > 0) "Call Completed" else "Call Terminated"
            }

            val isoFormat = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", Locale.US)
            val startedAt = isoFormat.format(Date(dateMs))
            val endedAt = isoFormat.format(Date(dateMs + (durationSec * 1000)))

            val prefs = getSharedPreferences("ringvia_prefs", Context.MODE_PRIVATE)
            var did = prefs.getString("device_unique_id", null)
            if (did == null) {
                val androidId = Settings.Secure.getString(contentResolver, Settings.Secure.ANDROID_ID)
                did = if (!androidId.isNullOrEmpty()) "dev_$androidId" else "dev_" + UUID.randomUUID().toString().substring(0, 8)
                prefs.edit().putString("device_unique_id", did).apply()
            }

            val callId = "dev_call_$rawId"

            // Look for newly recorded audio file
            val latestRecFile = findNewestRecordingFile(number, contactName)
            var serverUrl = ""
            var serverSha256 = ""

            if (latestRecFile != null && latestRecFile.exists() && latestRecFile.length() > 0) {
                val sha256 = calculateFileSha256(latestRecFile)
                serverSha256 = sha256
                val uploadRes = uploadAudioMultipart(did, number, callId, sha256, latestRecFile)
                if (uploadRes != null) {
                    serverUrl = uploadRes.optString("recordingUrl", "")
                    if (serverSha256.isEmpty()) {
                        serverSha256 = uploadRes.optString("recordingSha256", sha256)
                    }
                }
            }

            // Sync call record to cloud server in background
            syncCallRecordToServer(
                deviceId = did,
                callId = callId,
                phone = number,
                name = contactName,
                direction = direction,
                duration = durationSec,
                outcome = outcome,
                recordingUrl = serverUrl,
                recordingSha256 = serverSha256,
                timestamp = startedAt
            )

            // Emit instant Telemetry event to Flutter UI
            val event = mapOf(
                "type" to "call_completed",
                "id" to callId,
                "phoneNumber" to number,
                "contactName" to contactName,
                "direction" to direction,
                "duration" to durationSec,
                "durationSeconds" to durationSec,
                "outcome" to outcome,
                "recordingStatus" to (if (serverUrl.isNotEmpty() || (latestRecFile != null && latestRecFile.exists())) "AVAILABLE" else "NOT_AVAILABLE"),
                "recordingUrl" to (if (serverUrl.isNotEmpty()) serverUrl else (latestRecFile?.absolutePath ?: "")),
                "recordingSha256" to serverSha256,
                "simSlot" to "SIM 1 (Corporate)",
                "timestamp" to startedAt,
                "startedAt" to startedAt,
                "endedAt" to endedAt
            )
            runOnUiThread {
                TelemetryBridgeChannel.sendTelemetryEvent(event)
            }
        } catch (e: Exception) {
            e.printStackTrace()
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
                    if (file.isFile && isAudioFile(file.name)) {
                        val mod = file.lastModified()
                        val diff = now - mod

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

    override fun onDestroy() {
        callLogObserver?.let {
            try {
                contentResolver.unregisterContentObserver(it)
            } catch (_: Exception) {}
            callLogObserver = null
        }
        observerHandler.removeCallbacks(checkLatestCallRunnable)
        stopNativeAudio()
        super.onDestroy()
    }
}
