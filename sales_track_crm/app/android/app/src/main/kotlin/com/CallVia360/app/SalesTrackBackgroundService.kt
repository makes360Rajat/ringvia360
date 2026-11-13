package com.CallVia360.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.database.ContentObserver
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.provider.CallLog
import android.provider.Telephony
import android.util.Log
import androidx.core.app.NotificationCompat

class SalesTrackBackgroundService : Service() {

    companion object {
        private const val TAG = "SalesTrackBgService"
        private const val NOTIFICATION_ID = 36002
        private const val CHANNEL_ID = "callvia360_background_sync"

        fun start(context: Context) {
            try {
                val intent = Intent(context, SalesTrackBackgroundService::class.java)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(intent)
                } else {
                    context.startService(intent)
                }
            } catch (e: Exception) {
                Log.e(TAG, "Failed to start background service: ${e.message}")
            }
        }
    }

    private var callLogObserver: ContentObserver? = null
    private var smsObserver: ContentObserver? = null
    private val handler = Handler(Looper.getMainLooper())

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        startInForeground()
        registerObservers()
        NativeSyncManager.scheduleJob(this)
        NativeSyncManager.triggerSync(this)
        Log.i(TAG, "SalesTrackBackgroundService running in foreground")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        startInForeground()
        NativeSyncManager.triggerSync(this)
        return START_STICKY
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager ?: return
            val channel = NotificationChannel(
                CHANNEL_ID,
                "CallVia360 Telemetry Service",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Monitors calls, SMS and synchronizes telemetry with CRM server"
                setShowBadge(false)
            }
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun startInForeground() {
        try {
            val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
            val pendingIntent = PendingIntent.getActivity(
                this,
                0,
                launchIntent,
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
            )

            val notification: Notification = NotificationCompat.Builder(this, CHANNEL_ID)
                .setSmallIcon(android.R.drawable.stat_notify_sync)
                .setContentTitle("CallVia360 CRM Active")
                .setContentText("Telemetry & call sync monitoring active")
                .setPriority(NotificationCompat.PRIORITY_LOW)
                .setOngoing(true)
                .setContentIntent(pendingIntent)
                .build()

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
        } catch (e: Exception) {
            Log.e(TAG, "startForeground error: ${e.message}")
        }
    }

    private fun registerObservers() {
        try {
            if (callLogObserver == null) {
                callLogObserver = object : ContentObserver(handler) {
                    override fun onChange(selfChange: Boolean) {
                        super.onChange(selfChange)
                        Log.d(TAG, "CallLog content changed; checking for newly completed calls...")
                        NativeSyncManager.checkAndSyncLatestCallLog(applicationContext)
                    }
                }
                contentResolver.registerContentObserver(
                    CallLog.Calls.CONTENT_URI,
                    true,
                    callLogObserver!!
                )
            }

            if (smsObserver == null) {
                smsObserver = object : ContentObserver(handler) {
                    override fun onChange(selfChange: Boolean) {
                        super.onChange(selfChange)
                        Log.d(TAG, "SMS content changed; checking for newly sent/received messages...")
                        NativeSyncManager.checkAndSyncLatestSms(applicationContext)
                    }
                }
                contentResolver.registerContentObserver(
                    Telephony.Sms.CONTENT_URI,
                    true,
                    smsObserver!!
                )
                try {
                    contentResolver.registerContentObserver(
                        android.net.Uri.parse("content://mms"),
                        true,
                        smsObserver!!
                    )
                    contentResolver.registerContentObserver(
                        android.net.Uri.parse("content://mms-sms/"),
                        true,
                        smsObserver!!
                    )
                } catch (_: Exception) {}
            }
        } catch (e: Exception) {
            Log.e(TAG, "registerObservers error: ${e.message}")
        }
    }

    override fun onDestroy() {
        try {
            callLogObserver?.let { contentResolver.unregisterContentObserver(it) }
            smsObserver?.let { contentResolver.unregisterContentObserver(it) }
        } catch (_: Exception) {}

        // Revive service if terminated
        start(applicationContext)
        super.onDestroy()
    }
}

