package com.CallVia360.app

import android.Manifest
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.database.ContentObserver
import android.media.MediaPlayer
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.Uri
import android.os.BatteryManager
import android.os.Build
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.provider.CallLog
import android.provider.Settings
import android.provider.Telephony
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import android.content.ContentUris
import android.provider.MediaStore
import android.util.Log
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.UUID

data class LocalRecordingItem(
    val path: String,
    val name: String,
    val size: Long,
    val lastModified: Long,
    val durationMs: Int
)

class MainActivity : FlutterActivity() {

    companion object {
        const val METHOD_CHANNEL = "com.CallVia360.app/platform"
        private const val PERMISSIONS_REQUEST_CODE = 1001

        private var mediaPlayer: MediaPlayer? = null
        private var activeAudioPath: String? = null
        private var isPlayerPrepared: Boolean = false
        private val playerLock = Any()

        fun stopNativeAudio() {
            synchronized(playerLock) {
                activeAudioPath = null
                isPlayerPrepared = false
                mediaPlayer?.let { player ->
                    try {
                        if (player.isPlaying) player.stop()
                    } catch (_: Exception) {}
                    try {
                        player.reset()
                        player.release()
                    } catch (_: Exception) {}
                }
                mediaPlayer = null
            }
        }
    }

    // CallLog Observer for 100% reliable real-time call sensing across Android & Samsung OneUI
    private var callLogObserver: ContentObserver? = null
    private val observerHandler = Handler(Looper.getMainLooper())
    private var lastObservedCallId: String = ""
    private var lastObservedCallDate: Long = 0L

    private val checkLatestCallRunnable = Runnable {
        Thread {
            processLatestCallChange()
        }.start()
    }

    // SMS Observer for real-time sensing of outgoing AND incoming SMS messages
    private var smsObserver: ContentObserver? = null
    private var lastObservedSmsId: String = ""
    private var lastObservedSmsDate: Long = 0L

    private val checkLatestSmsRunnable = Runnable {
        Thread {
            processLatestSmsChange()
        }.start()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Telemetry Stream EventChannel
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

        // Platform Methods Channel
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            METHOD_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getDeviceInfo" -> {
                    try {
                        val prefs = getSharedPreferences("sales_track_prefs", Context.MODE_PRIVATE)
                        var deviceUid = prefs.getString("device_uid", null)
                        if (deviceUid == null) {
                            deviceUid = UUID.randomUUID().toString()
                            prefs.edit().putString("device_uid", deviceUid).apply()
                        }

                        val bm = getSystemService(Context.BATTERY_SERVICE) as? BatteryManager
                        val batteryLevel = bm?.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY) ?: 80

                        val pm = getSystemService(Context.POWER_SERVICE) as? PowerManager
                        val isBatteryUnrestricted = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            pm?.isIgnoringBatteryOptimizations(packageName) ?: false
                        } else true

                        val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager
                        val networkType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            val activeNet = cm?.activeNetwork
                            val caps = cm?.getNetworkCapabilities(activeNet)
                            when {
                                caps == null -> "none"
                                caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) -> "wifi"
                                caps.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) -> "mobile"
                                else -> "wifi"
                            }
                        } else {
                            @Suppress("DEPRECATION")
                            val info = cm?.activeNetworkInfo
                            @Suppress("DEPRECATION")
                            when {
                                info == null || !info.isConnected -> "none"
                                info.type == ConnectivityManager.TYPE_WIFI -> "wifi"
                                info.type == ConnectivityManager.TYPE_MOBILE -> "mobile"
                                else -> "wifi"
                            }
                        }

                        val bFilter = IntentFilter(Intent.ACTION_BATTERY_CHANGED)
                        val bIntent = registerReceiver(null, bFilter)
                        val bStatus = bIntent?.getIntExtra(BatteryManager.EXTRA_STATUS, -1) ?: -1
                        val isCharging = bStatus == BatteryManager.BATTERY_STATUS_CHARGING || bStatus == BatteryManager.BATTERY_STATUS_FULL

                        val info = mapOf(
                            "uid" to deviceUid,
                            "platform" to "android",
                            "manufacturer" to Build.MANUFACTURER,
                            "model" to Build.MODEL,
                            "os_version" to Build.VERSION.RELEASE,
                            "app_version" to "1.9.2",
                            "batteryPercent" to batteryLevel,
                            "charging" to isCharging,
                            "network" to networkType,
                            "batteryUnrestricted" to isBatteryUnrestricted,
                            "sims" to listOf(
                                mapOf("slot" to 1, "label" to "Primary SIM"),
                                mapOf("slot" to 2, "label" to "Secondary SIM")
                            )
                        )
                        result.success(info)
                    } catch (e: Exception) {
                        result.error("DEVICE_INFO_ERROR", e.message, null)
                    }
                }

                "getPermissionsStatus" -> {
                    val status = checkAllPermissions()
                    result.success(status)
                }

                "requestAllPermissions" -> {
                    requestRequiredPermissions()
                    result.success(true)
                }

                "requestPermission" -> {
                    val perm = call.argument<String>("permission") ?: ""
                    requestSpecificPermission(perm)
                    result.success(true)
                }

                "isNotificationListenerEnabled" -> {
                    result.success(isNotificationListenerGranted())
                }

                "openNotificationListenerSettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS).apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SETTINGS_ERROR", e.message, null)
                    }
                }

                "openBatteryOptimizationSettings", "requestBatteryOptimization" -> {
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                                data = Uri.parse("package:$packageName")
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(intent)
                        } else {
                            val intent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS).apply {
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(intent)
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        try {
                            val intent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS).apply {
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (e2: Exception) {
                            result.error("SETTINGS_ERROR", e2.message, null)
                        }
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

                "fetchDeviceCallLogs" -> {
                    Thread {
                        try {
                            val logs = queryHistoricalCallLogs()
                            runOnUiThread { result.success(logs) }
                        } catch (e: Exception) {
                            runOnUiThread { result.error("CALL_LOG_ERROR", e.message, null) }
                        }
                    }.start()
                }

                "fetchDeviceSms" -> {
                    Thread {
                        try {
                            val smsList = queryHistoricalSms()
                            runOnUiThread { result.success(smsList) }
                        } catch (e: Exception) {
                            runOnUiThread { result.error("SMS_LOG_ERROR", e.message, null) }
                        }
                    }.start()
                }

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

                "fetchLocalCallRecordings" -> {
                    Thread {
                        try {
                            val recordings = scanLocalRecordings()
                            runOnUiThread { result.success(recordings) }
                        } catch (e: Exception) {
                            runOnUiThread { result.error("RECORDING_ERROR", e.message, null) }
                        }
                    }.start()
                }

                "fetchActiveWhatsAppNotifications" -> {
                    Thread {
                        try {
                            val active = WhatsAppNotificationListener.instance?.pollActiveNotifications() ?: emptyList()
                            val recent = WhatsAppNotificationListener.getRecentEvents()
                            val combined = (active + recent).distinctBy { it["uid"] }
                            runOnUiThread { result.success(combined) }
                        } catch (e: Exception) {
                            runOnUiThread { result.success(emptyList<Map<String, Any>>()) }
                        }
                    }.start()
                }

                // Native Audio Player
                "playAudio" -> {
                    val path = call.argument<String>("path") ?: ""
                    if (path.isEmpty()) {
                        result.error("INVALID_PATH", "Path is required", null)
                        return@setMethodCallHandler
                    }
                    playAudioFile(path, { durationMs ->
                        result.success(mapOf("status" to "playing", "durationMs" to durationMs))
                    }, { err ->
                        result.error("AUDIO_ERROR", err, null)
                    })
                }

                "pauseAudio" -> {
                    synchronized(playerLock) {
                        mediaPlayer?.let { if (it.isPlaying) it.pause() }
                    }
                    result.success(true)
                }

                "resumeAudio" -> {
                    synchronized(playerLock) {
                        mediaPlayer?.let { if (!it.isPlaying) it.start() }
                    }
                    result.success(true)
                }

                "stopAudio" -> {
                    stopNativeAudio()
                    result.success(true)
                }

                "seekAudio" -> {
                    val positionMs = call.argument<Int>("positionMs") ?: 0
                    synchronized(playerLock) {
                        mediaPlayer?.seekTo(positionMs)
                    }
                    result.success(true)
                }

                "getAudioState" -> {
                    synchronized(playerLock) {
                        val player = mediaPlayer
                        if (player != null && isPlayerPrepared) {
                            result.success(mapOf(
                                "isPlaying" to player.isPlaying,
                                "positionMs" to player.currentPosition,
                                "durationMs" to player.duration,
                                "activePath" to (activeAudioPath ?: "")
                            ))
                        } else {
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

        // Initialize CallLogObserver and SmsObserver immediately
        registerCallLogObserver()
        registerSmsObserver()
    }

    override fun onResume() {
        super.onResume()
        registerCallLogObserver()
        registerSmsObserver()
        val status = checkAllPermissions()
        TelemetryBridgeChannel.sendTelemetryEvent(mapOf(
            "type" to "permissions_updated",
            "permissions" to status
        ))
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == PERMISSIONS_REQUEST_CODE) {
            registerCallLogObserver()
            registerSmsObserver()
            val status = checkAllPermissions()
            TelemetryBridgeChannel.sendTelemetryEvent(mapOf(
                "type" to "permissions_updated",
                "permissions" to status
            ))
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        callLogObserver?.let {
            try {
                contentResolver.unregisterContentObserver(it)
            } catch (_: Exception) {}
            callLogObserver = null
        }
        smsObserver?.let {
            try {
                contentResolver.unregisterContentObserver(it)
            } catch (_: Exception) {}
            smsObserver = null
        }
        stopNativeAudio()
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

    // -------------------------------------------------------------
    // Real-Time System SMS ContentObserver (Detects 100% Incoming & Outgoing SMS)
    // -------------------------------------------------------------
    private fun registerSmsObserver() {
        if (smsObserver != null) return
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_SMS) != PackageManager.PERMISSION_GRANTED) {
            return
        }

        smsObserver = object : ContentObserver(observerHandler) {
            override fun onChange(selfChange: Boolean, uri: Uri?) {
                super.onChange(selfChange, uri)
                // Debounce 1.0s to allow SMS provider to fully write the message body and status
                observerHandler.removeCallbacks(checkLatestSmsRunnable)
                observerHandler.postDelayed(checkLatestSmsRunnable, 1000)
            }
        }

        try {
            contentResolver.registerContentObserver(
                Telephony.Sms.CONTENT_URI,
                true,
                smsObserver!!
            )
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun processLatestSmsChange() {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_SMS) != PackageManager.PERMISSION_GRANTED) {
            return
        }

        try {
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
            ) ?: return

            var rawId = ""
            var address = ""
            var body = ""
            var dateMs = 0L
            var type = Telephony.Sms.MESSAGE_TYPE_INBOX

            cursor.use {
                val idIdx = it.getColumnIndex(Telephony.Sms._ID)
                val addrIdx = it.getColumnIndex(Telephony.Sms.ADDRESS)
                val bodyIdx = it.getColumnIndex(Telephony.Sms.BODY)
                val dateIdx = it.getColumnIndex(Telephony.Sms.DATE)
                val typeIdx = it.getColumnIndex(Telephony.Sms.TYPE)

                if (it.moveToFirst()) {
                    rawId = if (idIdx >= 0) it.getString(idIdx) ?: "" else ""
                    address = if (addrIdx >= 0) it.getString(addrIdx) ?: "" else ""
                    body = if (bodyIdx >= 0) it.getString(bodyIdx) ?: "" else ""
                    dateMs = if (dateIdx >= 0) it.getLong(dateIdx) else System.currentTimeMillis()
                    type = if (typeIdx >= 0) it.getInt(typeIdx) else Telephony.Sms.MESSAGE_TYPE_INBOX
                } else {
                    return
                }
            }

            if (rawId.isEmpty()) return
            if (rawId == lastObservedSmsId && dateMs == lastObservedSmsDate) {
                return
            }
            lastObservedSmsId = rawId
            lastObservedSmsDate = dateMs

            val resolvedName = ContactLookupHelper.resolveContactName(this, address)
            val direction = if (type == Telephony.Sms.MESSAGE_TYPE_INBOX) "incoming" else "outgoing"

            val isoFormat = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", Locale.US)
            val timestamp = isoFormat.format(Date(dateMs))

            val event = mapOf(
                "type" to "sms",
                "uid" to "sms-$rawId-$dateMs",
                "kind" to "sms",
                "direction" to direction,
                "number" to address,
                "name" to (resolvedName ?: address),
                "sim" to 1,
                "text" to body,
                "time" to dateMs,
                "timestamp" to timestamp,
                "source" to "auto"
            )

            TelemetryBridgeChannel.sendTelemetryEvent(event)
        } catch (e: Exception) {
            e.printStackTrace()
        }
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
                val idIdx = it.getColumnIndex(CallLog.Calls._ID)
                val numIdx = it.getColumnIndex(CallLog.Calls.NUMBER)
                val nameIdx = it.getColumnIndex(CallLog.Calls.CACHED_NAME)
                val typeIdx = it.getColumnIndex(CallLog.Calls.TYPE)
                val dateIdx = it.getColumnIndex(CallLog.Calls.DATE)
                val durIdx = it.getColumnIndex(CallLog.Calls.DURATION)

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
                CallLog.Calls.INCOMING_TYPE -> "incoming"
                CallLog.Calls.OUTGOING_TYPE -> "outgoing"
                CallLog.Calls.MISSED_TYPE -> "missed"
                CallLog.Calls.REJECTED_TYPE -> "rejected"
                CallLog.Calls.BLOCKED_TYPE -> "blocked"
                CallLog.Calls.VOICEMAIL_TYPE -> "voicemail"
                else -> "incoming"
            }

            val isoFormat = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", Locale.US)
            val dateIso = isoFormat.format(Date(dateMs))

            val recFile = findNewestRecordingFile(number, contactName)
            val hasRecording = recFile != null && recFile.exists() && recFile.length() > 0

            val event = mapOf(
                "type" to "call_completed",
                "uid" to "call-$rawId-$dateMs",
                "kind" to "call",
                "number" to number,
                "phoneNumber" to number,
                "name" to contactName,
                "contactName" to contactName,
                "direction" to direction,
                "duration" to durationSec,
                "sim" to 1,
                "recording" to hasRecording,
                "recordingPath" to (if (hasRecording) recFile!!.absolutePath else ""),
                "time" to dateMs,
                "timestamp" to dateIso,
                "source" to "auto"
            )

            runOnUiThread {
                TelemetryBridgeChannel.sendTelemetryEvent(event)
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun isNotificationListenerGranted(): Boolean {
        return try {
            val packages = NotificationManagerCompat.getEnabledListenerPackages(this)
            if (packages.contains(packageName)) {
                return true
            }
            val flat = Settings.Secure.getString(contentResolver, "enabled_notification_listeners")
            flat != null && flat.contains(packageName)
        } catch (_: Exception) {
            val flat = Settings.Secure.getString(contentResolver, "enabled_notification_listeners")
            flat != null && flat.contains(packageName)
        }
    }

    private fun checkAllPermissions(): Map<String, Boolean> {
        val pm = getSystemService(Context.POWER_SERVICE) as? PowerManager
        val isIgnoringBattery = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            pm?.isIgnoringBatteryOptimizations(packageName) ?: false
        } else true

        val phoneState = ContextCompat.checkSelfPermission(this, Manifest.permission.READ_PHONE_STATE) == PackageManager.PERMISSION_GRANTED
        val callLog = ContextCompat.checkSelfPermission(this, Manifest.permission.READ_CALL_LOG) == PackageManager.PERMISSION_GRANTED
        val sms = ContextCompat.checkSelfPermission(this, Manifest.permission.READ_SMS) == PackageManager.PERMISSION_GRANTED
        val contacts = ContextCompat.checkSelfPermission(this, Manifest.permission.READ_CONTACTS) == PackageManager.PERMISSION_GRANTED
        val notifications = isNotificationListenerGranted()
        val recordAudio = ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED

        val mediaAudio = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            ContextCompat.checkSelfPermission(this, Manifest.permission.READ_MEDIA_AUDIO) == PackageManager.PERMISSION_GRANTED
        } else {
            ContextCompat.checkSelfPermission(this, Manifest.permission.READ_EXTERNAL_STORAGE) == PackageManager.PERMISSION_GRANTED
        }

        return mapOf(
            "call_log" to callLog,
            "phone_state" to phoneState,
            "contacts" to contacts,
            "sms" to sms,
            "whatsapp_access" to notifications,
            "notifications" to notifications,
            "recordings_folder" to mediaAudio,
            "manage_storage" to mediaAudio,
            "storage" to mediaAudio,
            "recordings" to (mediaAudio || recordAudio),
            "battery_unrestricted" to isIgnoringBattery
        )
    }

    private fun requestSpecificPermission(group: String) {
        val perms = when (group) {
            "call_log" -> arrayOf(Manifest.permission.READ_CALL_LOG)
            "phone_state" -> arrayOf(Manifest.permission.READ_PHONE_STATE)
            "contacts" -> arrayOf(Manifest.permission.READ_CONTACTS)
            "sms" -> arrayOf(Manifest.permission.READ_SMS, Manifest.permission.RECEIVE_SMS)
            "audio", "storage", "recordings" -> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    arrayOf(Manifest.permission.READ_MEDIA_AUDIO, Manifest.permission.RECORD_AUDIO)
                } else {
                    arrayOf(Manifest.permission.READ_EXTERNAL_STORAGE, Manifest.permission.RECORD_AUDIO)
                }
            }
            else -> null
        }

        if (perms != null) {
            val ungranted = perms.filter { ContextCompat.checkSelfPermission(this, it) != PackageManager.PERMISSION_GRANTED }
            if (ungranted.isEmpty()) {
                val status = checkAllPermissions()
                TelemetryBridgeChannel.sendTelemetryEvent(mapOf(
                    "type" to "permissions_updated",
                    "permissions" to status
                ))
                return
            }

            val permanentlyDenied = ungranted.any { perm ->
                !ActivityCompat.shouldShowRequestPermissionRationale(this, perm) &&
                getSharedPreferences("app_perms", Context.MODE_PRIVATE).getBoolean("req_$perm", false)
            }

            val editor = getSharedPreferences("app_perms", Context.MODE_PRIVATE).edit()
            ungranted.forEach { editor.putBoolean("req_$it", true) }
            editor.apply()

            if (permanentlyDenied) {
                try {
                    val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                        data = Uri.fromParts("package", packageName, null)
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    startActivity(intent)
                } catch (_: Exception) {
                    ActivityCompat.requestPermissions(this, ungranted.toTypedArray(), PERMISSIONS_REQUEST_CODE)
                }
            } else {
                ActivityCompat.requestPermissions(this, ungranted.toTypedArray(), PERMISSIONS_REQUEST_CODE)
            }
        } else {
            requestRequiredPermissions()
        }
    }

    private fun requestRequiredPermissions() {
        val permissions = mutableListOf<String>()

        if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_PHONE_STATE) != PackageManager.PERMISSION_GRANTED) {
            permissions.add(Manifest.permission.READ_PHONE_STATE)
        }
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_CALL_LOG) != PackageManager.PERMISSION_GRANTED) {
            permissions.add(Manifest.permission.READ_CALL_LOG)
        }
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_CONTACTS) != PackageManager.PERMISSION_GRANTED) {
            permissions.add(Manifest.permission.READ_CONTACTS)
        }
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_SMS) != PackageManager.PERMISSION_GRANTED) {
            permissions.add(Manifest.permission.READ_SMS)
        }
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.RECEIVE_SMS) != PackageManager.PERMISSION_GRANTED) {
            permissions.add(Manifest.permission.RECEIVE_SMS)
        }
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
            permissions.add(Manifest.permission.RECORD_AUDIO)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                permissions.add(Manifest.permission.POST_NOTIFICATIONS)
            }
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_MEDIA_AUDIO) != PackageManager.PERMISSION_GRANTED) {
                permissions.add(Manifest.permission.READ_MEDIA_AUDIO)
            }
        } else {
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_EXTERNAL_STORAGE) != PackageManager.PERMISSION_GRANTED) {
                permissions.add(Manifest.permission.READ_EXTERNAL_STORAGE)
            }
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.WRITE_EXTERNAL_STORAGE) != PackageManager.PERMISSION_GRANTED) {
                permissions.add(Manifest.permission.WRITE_EXTERNAL_STORAGE)
            }
        }

        if (permissions.isNotEmpty()) {
            ActivityCompat.requestPermissions(this, permissions.toTypedArray(), PERMISSIONS_REQUEST_CODE)
        } else {
            val status = checkAllPermissions()
            TelemetryBridgeChannel.sendTelemetryEvent(mapOf(
                "type" to "permissions_updated",
                "permissions" to status
            ))
        }
    }

    private fun getFastCallRecordingFiles(): List<LocalRecordingItem> {
        val all = mutableListOf<LocalRecordingItem>()
        val seenPaths = HashSet<String>()

        // 1. Query MediaStore Audio (Standard Android 10/11/12/13/14/15 access)
        try {
            val projection = arrayOf(
                MediaStore.Audio.Media._ID,
                MediaStore.Audio.Media.DATA,
                MediaStore.Audio.Media.DISPLAY_NAME,
                MediaStore.Audio.Media.SIZE,
                MediaStore.Audio.Media.DATE_MODIFIED,
                MediaStore.Audio.Media.DURATION
            )
            val selection = "${MediaStore.Audio.Media.DATA} LIKE '%Record%' OR ${MediaStore.Audio.Media.DISPLAY_NAME} LIKE '%Call%' OR ${MediaStore.Audio.Media.DATA} LIKE '%Voice%'"
            contentResolver.query(
                MediaStore.Audio.Media.EXTERNAL_CONTENT_URI,
                projection,
                selection,
                null,
                "${MediaStore.Audio.Media.DATE_MODIFIED} DESC"
            )?.use { cursor ->
                val dataIdx = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.DATA)
                val nameIdx = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.DISPLAY_NAME)
                val sizeIdx = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.SIZE)
                val dateIdx = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.DATE_MODIFIED)
                val durIdx = cursor.getColumnIndex(MediaStore.Audio.Media.DURATION)

                while (cursor.moveToNext()) {
                    val path = cursor.getString(dataIdx) ?: ""
                    val name = cursor.getString(nameIdx) ?: File(path).name
                    val size = cursor.getLong(sizeIdx)
                    val dateModifiedSec = cursor.getLong(dateIdx)
                    val durationMs = if (durIdx >= 0) cursor.getInt(durIdx) else 0

                    if (path.isNotEmpty() && size > 0 && !seenPaths.contains(path)) {
                        seenPaths.add(path)
                        all.add(LocalRecordingItem(
                            path = path,
                            name = name,
                            size = size,
                            lastModified = dateModifiedSec * 1000L,
                            durationMs = durationMs
                        ))
                    }
                }
            }
        } catch (e: Exception) {
            Log.e("MksSalesTrack", "Error querying MediaStore recordings: ${e.message}")
        }

        // 2. Direct directory scan fallback
        val candidateDirs = listOf(
            File(Environment.getExternalStorageDirectory(), "Recordings/Call"),
            File(Environment.getExternalStorageDirectory(), "Sounds/Call"),
            File(Environment.getExternalStorageDirectory(), "CallRecordings"),
            File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_MUSIC), "Recordings/Call")
        )
        for (dir in candidateDirs) {
            try {
                if (dir.exists() && dir.isDirectory) {
                    dir.listFiles()?.forEach { file ->
                        if (file.isFile && file.length() > 0 && !seenPaths.contains(file.absolutePath)) {
                            seenPaths.add(file.absolutePath)
                            all.add(LocalRecordingItem(
                                path = file.absolutePath,
                                name = file.name,
                                size = file.length(),
                                lastModified = file.lastModified(),
                                durationMs = 0
                            ))
                        }
                    }
                }
            } catch (_: Exception) {}
        }
        return all
    }

    private fun queryHistoricalCallLogs(limit: Int = 3000): List<Map<String, Any>> {
        val list = mutableListOf<Map<String, Any>>()
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_CALL_LOG) != PackageManager.PERMISSION_GRANTED) {
            return list
        }
        try {
            val contactsMap = ContactLookupHelper.getQuickLookupMap(this)
            val recordingsList = getFastCallRecordingFiles()

            val projection = arrayOf(
                CallLog.Calls._ID,
                CallLog.Calls.NUMBER,
                CallLog.Calls.CACHED_NAME,
                CallLog.Calls.DURATION,
                CallLog.Calls.TYPE,
                CallLog.Calls.DATE,
                CallLog.Calls.PHONE_ACCOUNT_COMPONENT_NAME
            )
            val sortOrder = "${CallLog.Calls.DATE} DESC"
            contentResolver.query(CallLog.Calls.CONTENT_URI, projection, null, null, sortOrder)?.use { cursor ->
                val idIdx = cursor.getColumnIndexOrThrow(CallLog.Calls._ID)
                val numIdx = cursor.getColumnIndexOrThrow(CallLog.Calls.NUMBER)
                val nameIdx = cursor.getColumnIndexOrThrow(CallLog.Calls.CACHED_NAME)
                val durIdx = cursor.getColumnIndexOrThrow(CallLog.Calls.DURATION)
                val typeIdx = cursor.getColumnIndexOrThrow(CallLog.Calls.TYPE)
                val dateIdx = cursor.getColumnIndexOrThrow(CallLog.Calls.DATE)
                val compIdx = try { cursor.getColumnIndex(CallLog.Calls.PHONE_ACCOUNT_COMPONENT_NAME) } catch (_: Exception) { -1 }

                var count = 0
                val isoFormat = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", Locale.US)
                val claimedRecordingPaths = HashSet<String>()

                while (cursor.moveToNext() && count < limit) {
                    val id = cursor.getString(idIdx)
                    val number = cursor.getString(numIdx) ?: ""
                    val cachedName = cursor.getString(nameIdx) ?: ""
                    val duration = cursor.getInt(durIdx)
                    val type = cursor.getInt(typeIdx)
                    val dateMs = cursor.getLong(dateIdx)
                    val componentName = if (compIdx >= 0) cursor.getString(compIdx) ?: "" else ""

                    val isWhatsApp = componentName.contains("com.whatsapp", ignoreCase = true)
                    val isWhatsAppBusiness = componentName.contains("com.whatsapp.w4b", ignoreCase = true)

                    val direction = when (type) {
                        CallLog.Calls.INCOMING_TYPE -> "incoming"
                        CallLog.Calls.OUTGOING_TYPE -> "outgoing"
                        CallLog.Calls.MISSED_TYPE -> "missed"
                        CallLog.Calls.REJECTED_TYPE -> "rejected"
                        CallLog.Calls.BLOCKED_TYPE -> "blocked"
                        CallLog.Calls.VOICEMAIL_TYPE -> "voicemail"
                        else -> "incoming"
                    }

                    // Fast O(1) in-memory contact resolution
                    val digits = number.replace(Regex("[^0-9]"), "")
                    val key = if (digits.length >= 10) digits.takeLast(10) else number
                    val resolvedName = contactsMap[key] ?: contactsMap[number]
                        ?: if (cachedName.isNotEmpty() && cachedName != number && !cachedName.equals("unknown", ignoreCase = true) && !cachedName.equals("unknown caller", ignoreCase = true)) cachedName
                        else ""

                    val dateIso = isoFormat.format(Date(dateMs))

                    // Intelligent recording match using contact name / number key & timestamp (strictly 1-to-1)
                    val recItem = recordingsList.filter { !claimedRecordingPaths.contains(it.path) }.minByOrNull { rec ->
                        val nameLower = resolvedName.trim().lowercase()
                        val recNameLower = rec.name.lowercase()

                        val nameMatches = (nameLower.length >= 2 && nameLower != number && recNameLower.contains(nameLower)) ||
                                          (key.length >= 7 && recNameLower.contains(key))

                        val callEndMs = dateMs + (duration * 1000L)
                        val diffStart = Math.abs(rec.lastModified - dateMs)
                        val diffEnd = Math.abs(rec.lastModified - callEndMs)
                        val minDiff = Math.min(diffStart, diffEnd)

                        if (nameMatches && minDiff < 90000) {
                            minDiff
                        } else if (!nameMatches && minDiff < 25000) {
                            minDiff
                        } else {
                            Long.MAX_VALUE
                        }
                    }?.takeIf { rec ->
                        val nameLower = resolvedName.trim().lowercase()
                        val recNameLower = rec.name.lowercase()
                        val nameMatches = (nameLower.length >= 2 && nameLower != number && recNameLower.contains(nameLower)) ||
                                          (key.length >= 7 && recNameLower.contains(key))
                        val callEndMs = dateMs + (duration * 1000L)
                        val diffStart = Math.abs(rec.lastModified - dateMs)
                        val diffEnd = Math.abs(rec.lastModified - callEndMs)
                        val minDiff = Math.min(diffStart, diffEnd)
                        (nameMatches && minDiff < 90000) || (!nameMatches && minDiff < 25000)
                    }

                    if (recItem != null) {
                        claimedRecordingPaths.add(recItem.path)
                    }

                    val hasRecording = recItem != null
                    val effectiveDuration = if (duration == 0 && recItem != null && recItem.durationMs > 0) {
                        recItem.durationMs / 1000
                    } else {
                        duration
                    }

                    if (isWhatsApp) {
                        list.add(mapOf(
                            "uid" to "wacall-$id-$dateMs",
                            "kind" to "whatsapp_call",
                            "app" to (if (isWhatsAppBusiness) "com.whatsapp.w4b" else "com.whatsapp"),
                            "direction" to direction,
                            "number" to number,
                            "phoneNumber" to number,
                            "name" to resolvedName,
                            "contactName" to resolvedName,
                            "time" to dateMs,
                            "timestamp" to dateIso,
                            "duration" to effectiveDuration,
                            "media" to "voice",
                            "source" to "auto"
                        ))
                    } else {
                        list.add(mapOf(
                            "uid" to "call-$id-$dateMs",
                            "kind" to "call",
                            "direction" to direction,
                            "number" to number,
                            "phoneNumber" to number,
                            "name" to resolvedName,
                            "contactName" to resolvedName,
                            "sim" to 1,
                            "time" to dateMs,
                            "timestamp" to dateIso,
                            "duration" to effectiveDuration,
                            "recording" to hasRecording,
                            "recordingPath" to (if (hasRecording) recItem!!.path else ""),
                            "source" to "auto"
                        ))
                    }
                    count++
                }
            }
        } catch (_: Exception) {}
        return list
    }

    private fun queryHistoricalSms(limit: Int = 3000): List<Map<String, Any>> {
        val list = mutableListOf<Map<String, Any>>()
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_SMS) != PackageManager.PERMISSION_GRANTED) {
            return list
        }
        try {
            val contactsMap = ContactLookupHelper.getQuickLookupMap(this)
            val projection = arrayOf(
                Telephony.Sms._ID,
                Telephony.Sms.ADDRESS,
                Telephony.Sms.BODY,
                Telephony.Sms.DATE,
                Telephony.Sms.TYPE
            )
            val sortOrder = "${Telephony.Sms.DATE} DESC"
            contentResolver.query(Telephony.Sms.CONTENT_URI, projection, null, null, sortOrder)?.use { cursor ->
                val idIdx = cursor.getColumnIndexOrThrow(Telephony.Sms._ID)
                val addrIdx = cursor.getColumnIndexOrThrow(Telephony.Sms.ADDRESS)
                val bodyIdx = cursor.getColumnIndexOrThrow(Telephony.Sms.BODY)
                val dateIdx = cursor.getColumnIndexOrThrow(Telephony.Sms.DATE)
                val typeIdx = cursor.getColumnIndexOrThrow(Telephony.Sms.TYPE)

                var count = 0
                val isoFormat = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", Locale.US)

                while (cursor.moveToNext() && count < limit) {
                    val id = cursor.getString(idIdx)
                    val address = cursor.getString(addrIdx) ?: ""
                    val body = cursor.getString(bodyIdx) ?: ""
                    val dateMs = cursor.getLong(dateIdx)
                    val type = cursor.getInt(typeIdx)

                    val direction = if (type == Telephony.Sms.MESSAGE_TYPE_INBOX) "incoming" else "outgoing"

                    val digits = address.replace(Regex("[^0-9]"), "")
                    val key = if (digits.length >= 10) digits.takeLast(10) else address
                    val resolvedName = contactsMap[key] ?: contactsMap[address] ?: address

                    val dateIso = isoFormat.format(Date(dateMs))

                    list.add(mapOf(
                        "uid" to "sms-$id-$dateMs",
                        "kind" to "sms",
                        "direction" to direction,
                        "number" to address,
                        "name" to resolvedName,
                        "sim" to 1,
                        "text" to body,
                        "time" to dateMs,
                        "timestamp" to dateIso,
                        "source" to "auto"
                    ))
                    count++
                }
            }
        } catch (_: Exception) {}
        return list
    }

    private fun findNewestRecordingFile(phone: String, name: String): File? {
        val candidateDirs = mutableListOf(
            File(Environment.getExternalStorageDirectory(), "Recordings/Call"),
            File(Environment.getExternalStorageDirectory(), "Sounds/Call"),
            File(Environment.getExternalStorageDirectory(), "CallRecordings"),
            File(Environment.getExternalStorageDirectory(), "MIUI/sound_recorder/call_rec"),
            File(Environment.getExternalStorageDirectory(), "PhoneRecord"),
            File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_MUSIC), "Recordings/Call")
        )
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            candidateDirs.add(File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_RECORDINGS), "Call"))
            candidateDirs.add(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_RECORDINGS))
        }

        var newestFile: File? = null
        var newestTime: Long = System.currentTimeMillis() - 120000 // Last 2 minutes

        for (dir in candidateDirs) {
            if (dir.exists() && dir.isDirectory) {
                dir.listFiles()?.forEach { file ->
                    if (file.isFile && file.lastModified() > newestTime) {
                        val ext = file.extension.lowercase()
                        if (ext in listOf("m4a", "mp3", "aac", "wav", "amr", "awb", "3gp", "opus", "ogg")) {
                            newestTime = file.lastModified()
                            newestFile = file
                        }
                    }
                }
            }
        }
        return newestFile
    }

    private fun scanLocalRecordings(): List<Map<String, Any>> {
        val recordings = getFastCallRecordingFiles()
        return recordings.map { rec ->
            mapOf(
                "fileName" to rec.name,
                "filePath" to rec.path,
                "fileSizeBytes" to rec.size,
                "lastModified" to rec.lastModified,
                "durationMs" to rec.durationMs,
                "extension" to File(rec.path).extension.lowercase()
            )
        }
    }

    private fun playAudioFile(path: String, onPrepared: (Int) -> Unit, onError: (String) -> Unit) {
        synchronized(playerLock) {
            stopNativeAudio()
            try {
                mediaPlayer = MediaPlayer().apply {
                    var isSourceSet = false
                    try {
                        setDataSource(path)
                        isSourceSet = true
                    } catch (e: Exception) {
                        try {
                            val uri = MediaStore.Audio.Media.EXTERNAL_CONTENT_URI
                            val sel = "${MediaStore.Audio.Media.DATA} = ?"
                            contentResolver.query(uri, arrayOf(MediaStore.Audio.Media._ID), sel, arrayOf(path), null)?.use { cursor ->
                                if (cursor.moveToFirst()) {
                                    val id = cursor.getLong(0)
                                    val contentUri = ContentUris.withAppendedId(MediaStore.Audio.Media.EXTERNAL_CONTENT_URI, id)
                                    contentResolver.openFileDescriptor(contentUri, "r")?.use { pfd ->
                                        setDataSource(pfd.fileDescriptor)
                                        isSourceSet = true
                                    }
                                }
                            }
                        } catch (_: Exception) {}
                    }
                    if (!isSourceSet) {
                        onError("Cannot access audio source: $path")
                        return@synchronized
                    }
                    setOnPreparedListener { player ->
                        isPlayerPrepared = true
                        activeAudioPath = path
                        player.start()
                        onPrepared(player.duration)
                    }
                    setOnErrorListener { _, what, extra ->
                        isPlayerPrepared = false
                        onError("MediaPlayer error: what=$what, extra=$extra")
                        true
                    }
                    setOnCompletionListener {
                        stopNativeAudio()
                    }
                    prepareAsync()
                }
            } catch (e: Exception) {
                onError("Failed to initialize MediaPlayer: ${e.message}")
            }
        }
    }
}
