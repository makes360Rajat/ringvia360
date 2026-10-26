package com.ringvia360.mobile

import android.app.*
import android.content.Context
import android.content.Intent
import android.media.MediaRecorder
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import java.io.File

/**
 * Robust Foreground Service that keeps call recording alive even when the app is backgrounded.
 *
 * Lifecycle:
 *  1. PhoneStateReceiver detects OFFHOOK (call answered) -> starts this service -> starts recording
 *  2. PhoneStateReceiver detects IDLE (call ended)       -> stops recording, saves metadata,
 *                                                          launches wrap-up popup & heads-up banner
 *  3. Passes exact callId, duration, and recordingPath to Flutter layer & SharedPreferences
 */
class CallRecordingService : Service() {

    companion object {
        const val CHANNEL_RECORDING = "ringvia360_recording"
        const val CHANNEL_WRAPUP    = "ringvia360_wrapup"

        const val NOTIF_ONGOING = 1001
        const val NOTIF_ENDED   = 1002
        const val PREFS_NAME    = "ringvia360_pending"

        const val ACTION_START = "com.ringvia360.ACTION_CALL_STARTED"
        const val ACTION_STOP  = "com.ringvia360.ACTION_CALL_ENDED"
        const val EXTRA_NUMBER = "phone_number"

        fun startRecording(context: Context, phoneNumber: String) {
            val intent = Intent(context, CallRecordingService::class.java).apply {
                action = ACTION_START
                putExtra(EXTRA_NUMBER, phoneNumber)
            }
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(intent)
                } else {
                    context.startService(intent)
                }
            } catch (_: Exception) {}
        }

        fun stopRecording(context: Context, phoneNumber: String) {
            val intent = Intent(context, CallRecordingService::class.java).apply {
                action = ACTION_STOP
                putExtra(EXTRA_NUMBER, phoneNumber)
            }
            try {
                context.startService(intent)
            } catch (_: Exception) {}
        }
    }

    private var mediaRecorder: MediaRecorder? = null
    private var currentCallId: String?  = null
    private var recordingPath: String?  = null
    private var callStartMs:  Long      = 0L

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannels()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> handleCallStarted(intent.getStringExtra(EXTRA_NUMBER) ?: "")
            ACTION_STOP  -> handleCallEnded(intent.getStringExtra(EXTRA_NUMBER) ?: "")
        }
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        releaseRecorder()
        super.onDestroy()
    }

    // ── Call Lifecycle Handlers ──────────────────────────────────────────────

    private fun handleCallStarted(phoneNumber: String) {
        callStartMs   = System.currentTimeMillis()
        currentCallId = "native-call-$callStartMs"

        // Resilient startForeground for Android 14+ / 16 (prevents SecurityException crash)
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val serviceType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE or android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC
                } else {
                    android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE
                }
                startForeground(NOTIF_ONGOING, buildOngoingNotification(phoneNumber), serviceType)
            } else {
                startForeground(NOTIF_ONGOING, buildOngoingNotification(phoneNumber))
            }
        } catch (e: SecurityException) {
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    startForeground(
                        NOTIF_ONGOING,
                        buildOngoingNotification(phoneNumber),
                        android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC
                    )
                } else {
                    startForeground(NOTIF_ONGOING, buildOngoingNotification(phoneNumber))
                }
            } catch (_: Exception) {}
        } catch (_: Exception) {}

        startAudioRecording(currentCallId!!)

        // Notify Flutter layer that call is active (shows In-Call HUD without starting a second recorder)
        CallSensorChannel.notifyCallStateChanged("connected", phoneNumber, currentCallId, 0, recordingPath)
    }

    private fun handleCallEnded(phoneNumber: String) {
        val callId   = currentCallId ?: "native-call-${System.currentTimeMillis()}"
        val duration = if (callStartMs > 0L) {
            ((System.currentTimeMillis() - callStartMs) / 1000).toInt()
        } else {
            0
        }

        releaseRecorder()

        // 1. Check if phone's native dialer (Samsung/Xiaomi/OnePlus/Oppo/Truecaller) captured the call
        val nativeMatch = findLatestNativeCallRecording(callStartMs)
        val validFile = recordingPath?.let { File(it) }

        val finalFile = if (nativeMatch != null && nativeMatch.exists() && nativeMatch.length() > 2048) {
            nativeMatch
        } else if (validFile != null && validFile.exists() && validFile.length() > 0) {
            validFile
        } else {
            null
        }
        val finalPath = finalFile?.absolutePath

        // 1. Persist call summary in SharedPreferences so Flutter can pick it up on resume/cold-start
        try {
            getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE).edit().apply {
                putString("pending_call_id",        callId)
                putString("pending_phone_number",   phoneNumber)
                putInt   ("pending_duration",       duration)
                putString("pending_recording_path", finalPath)
                putLong  ("pending_timestamp",      System.currentTimeMillis())
                apply()
            }
        } catch (_: Exception) {}

        // 2. Immediately notify Flutter event channel with initial metadata
        CallSensorChannel.notifyCallStateChanged(
            "disconnected",
            phoneNumber,
            callId,
            duration,
            finalPath
        )

        // 2b. If no native file found at the exact second of disconnect,
        // retry in background at +800ms, +1800ms, +3200ms, +5000ms as dialers finish saving.
        if (finalPath == null) {
            Thread {
                val retryDelays = listOf(800L, 1800L, 3200L, 5000L)
                for (delayMs in retryDelays) {
                    try {
                        Thread.sleep(delayMs)
                        val delayedMatch = findLatestNativeCallRecording(callStartMs)
                        if (delayedMatch != null && delayedMatch.exists() && delayedMatch.length() > 2048) {
                            val readyPath = delayedMatch.absolutePath
                            // Update SharedPreferences with the newly saved recording path
                            try {
                                getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE).edit().apply {
                                    putString("pending_recording_path", readyPath)
                                    apply()
                                }
                            } catch (_: Exception) {}

                            // Notify Flutter layer that the call recording is ready and linked
                            android.os.Handler(android.os.Looper.getMainLooper()).post {
                                CallSensorChannel.notifyCallStateChanged(
                                    "recording_ready",
                                    phoneNumber,
                                    callId,
                                    duration,
                                    readyPath
                                )
                            }
                            break
                        }
                    } catch (_: Exception) {}
                }
            }.start()
        }

        // 3. Immediately launch MainActivity so wrap-up pop-up appears over dialer
        try {
            val launchIntent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
                addFlags(
                    Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP
                )
                putExtra("show_wrap_up", true)
                putExtra("call_id", callId)
                putExtra("phone_number", phoneNumber)
                putExtra("duration", duration)
                putExtra("recording_path", finalPath)
            }
            if (launchIntent != null) {
                startActivity(launchIntent)
            }
        } catch (_: Exception) {}

        // 4. Show HIGH-PRIORITY heads-up banner notification with fullScreenIntent
        showCallEndedNotification(phoneNumber, duration, callId, finalPath)

        currentCallId = null
        try {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } catch (_: Exception) {}
        stopSelf()
    }

    // ── Audio Recording ──────────────────────────────────────────────────────

    private fun startAudioRecording(callId: String) {
        try {
            val dir = getExternalFilesDir("recordings")
                ?: File(filesDir, "recordings").also { it.mkdirs() }
            if (!dir.exists()) dir.mkdirs()
            val file = File(dir, "$callId.m4a")
            recordingPath = file.absolutePath

            mediaRecorder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                MediaRecorder(this)
            } else {
                @Suppress("DEPRECATION")
                MediaRecorder()
            }

            mediaRecorder?.apply {
                try {
                    // Try VOICE_COMMUNICATION first
                    setAudioSource(MediaRecorder.AudioSource.VOICE_COMMUNICATION)
                } catch (_: Exception) {
                    setAudioSource(MediaRecorder.AudioSource.MIC)
                }
                setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
                setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
                setAudioEncodingBitRate(128_000)
                setAudioSamplingRate(44_100)
                setOutputFile(recordingPath)
                prepare()
                start()
            }
        } catch (e: Exception) {
            // Clean fallback to standard MIC
            try {
                mediaRecorder?.reset()
                mediaRecorder?.release()
                mediaRecorder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    MediaRecorder(this)
                } else {
                    @Suppress("DEPRECATION")
                    MediaRecorder()
                }
                mediaRecorder?.apply {
                    setAudioSource(MediaRecorder.AudioSource.MIC)
                    setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
                    setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
                    setOutputFile(recordingPath)
                    prepare()
                    start()
                }
            } catch (_: Exception) {
                mediaRecorder = null
            }
        }
    }

    private fun releaseRecorder() {
        try {
            mediaRecorder?.stop()
        } catch (_: Exception) {
            // Stop might fail if call was < 1 second; file may still exist
        }
        try {
            mediaRecorder?.reset()
            mediaRecorder?.release()
        } catch (_: Exception) {}
        mediaRecorder = null
    }

    private fun findLatestNativeCallRecording(sinceMs: Long): File? {
        val windowMs = if (sinceMs > 0L) sinceMs - 15_000L else System.currentTimeMillis() - 180_000L
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
            File(external, "Record/Call"),
            File(filesDir, "recordings")
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
                         f.name.endsWith(".aac", true) || f.name.endsWith(".ogg", true) ||
                         f.name.endsWith(".3gp", true) || f.name.endsWith(".mp4", true))
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

        return bestFile
    }

    // ── Notifications ────────────────────────────────────────────────────────

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm = getSystemService(NotificationManager::class.java)

            // Ongoing recording (Low importance, silent)
            val recChannel = NotificationChannel(
                CHANNEL_RECORDING,
                "Call Recording Active",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "RingVia360 active call audio capture"
                setSound(null, null)
                enableVibration(false)
            }
            nm.createNotificationChannel(recChannel)

            // Call Ended Wrap-Up (High importance, pops up on screen)
            val wrapupChannel = NotificationChannel(
                CHANNEL_WRAPUP,
                "Call Wrap-Up Alerts",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Presents post-call wrap-up prompt after call finishes"
                enableVibration(true)
                setShowBadge(true)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            }
            nm.createNotificationChannel(wrapupChannel)
        }
    }

    private fun buildOngoingNotification(phoneNumber: String): Notification {
        val open = packageManager.getLaunchIntentForPackage(packageName)
        val pi = PendingIntent.getActivity(
            this, 0, open, PendingIntent.FLAG_IMMUTABLE
        )
        return NotificationCompat.Builder(this, CHANNEL_RECORDING)
            .setContentTitle("🔴 RingVia360 — Recording Call")
            .setContentText(
                if (phoneNumber.isNotBlank()) "Recording line: $phoneNumber"
                else "Active call audio capture in progress…"
            )
            .setSmallIcon(android.R.drawable.presence_audio_online)
            .setOngoing(true)
            .setSilent(true)
            .setContentIntent(pi)
            .build()
    }

    private fun showCallEndedNotification(
        phoneNumber: String,
        durationSecs: Int,
        callId: String,
        recordingPath: String?
    ) {
        val m = durationSecs / 60
        val s = durationSecs % 60

        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra("show_wrap_up", true)
            putExtra("call_id", callId)
            putExtra("phone_number", phoneNumber)
            putExtra("duration", durationSecs)
            putExtra("recording_path", recordingPath)
        }
        val pi = PendingIntent.getActivity(
            this, NOTIF_ENDED, launchIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        val notification = NotificationCompat.Builder(this, CHANNEL_WRAPUP)
            .setContentTitle("📋 Call Ended — Submit Wrap-Up & Feed")
            .setContentText(
                buildString {
                    if (phoneNumber.isNotBlank()) append("$phoneNumber • ")
                    append("${m}m ${s}s • Tap to send notes & podcast to live feed")
                }
            )
            .setSmallIcon(android.R.drawable.ic_menu_call)
            .setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setFullScreenIntent(pi, true)
            .setContentIntent(pi)
            .build()

        getSystemService(NotificationManager::class.java)
            .notify(NOTIF_ENDED, notification)
    }
}
