package com.ringvia360.mobile

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.telephony.TelephonyManager
import android.util.Log

/**
 * Manifest-registered BroadcastReceiver — fires even when the app is completely killed.
 *
 * State machine:
 *  RINGING   -> caches incoming number, notifies Flutter HUD if app is running
 *  OFFHOOK   -> starts timer, attempts CallRecordingService
 *  IDLE      -> discovers audio recording, enqueues call into CallSyncWorker, and triggers WorkManager
 */
class PhoneStateReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "RV360_PhoneReceiver"
        private const val PREFS_CALL_STATE = "ringvia360_call_state"
        private const val KEY_CALL_START_MS = "call_start_ms"
        private const val KEY_ACTIVE_NUMBER = "active_number"
        private const val KEY_LAST_RINGING = "last_ringing"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return
        if (action != TelephonyManager.ACTION_PHONE_STATE_CHANGED && action != "com.ringvia360.TEST_PHONE_STATE") return

        val state = intent.getStringExtra(TelephonyManager.EXTRA_STATE) ?: return
        val rawNumber = intent.getStringExtra(TelephonyManager.EXTRA_INCOMING_NUMBER) ?: ""
        val prefs = context.getSharedPreferences(PREFS_CALL_STATE, Context.MODE_PRIVATE)

        Log.d(TAG, "PhoneState received: $state, number: $rawNumber")

        when (state) {
            TelephonyManager.EXTRA_STATE_RINGING -> {
                if (rawNumber.isNotBlank()) {
                    prefs.edit().putString(KEY_LAST_RINGING, rawNumber).apply()
                }
                try {
                    CallSensorChannel.notifyCallStateChanged("ringing", rawNumber)
                } catch (_: Exception) {}
            }

            TelephonyManager.EXTRA_STATE_OFFHOOK -> {
                val num = if (rawNumber.isNotBlank()) rawNumber else prefs.getString(KEY_LAST_RINGING, "") ?: ""
                val now = System.currentTimeMillis()
                prefs.edit()
                    .putLong(KEY_CALL_START_MS, now)
                    .putString(KEY_ACTIVE_NUMBER, num)
                    .apply()

                // Try starting foreground service (succeeds if app is foreground)
                try {
                    CallRecordingService.startRecording(context, num)
                } catch (_: Exception) {}

                try {
                    CallSensorChannel.notifyCallStateChanged("connected", num, "native-call-$now", 0, null)
                } catch (_: Exception) {}
            }

            TelephonyManager.EXTRA_STATE_IDLE -> {
                val callStartMs = prefs.getLong(KEY_CALL_START_MS, 0L)
                val storedNum = prefs.getString(KEY_ACTIVE_NUMBER, "") ?: ""
                val num = if (rawNumber.isNotBlank()) {
                    rawNumber
                } else if (storedNum.isNotBlank()) {
                    storedNum
                } else {
                    prefs.getString(KEY_LAST_RINGING, "") ?: ""
                }

                val now = System.currentTimeMillis()
                val duration = if (callStartMs > 0L) ((now - callStartMs) / 1000).toInt() else 0
                val callId = "native-call-${if (callStartMs > 0L) callStartMs else now}"

                // 1. Look for recording on storage / MediaStore
                val recordingPath = CallSyncWorker.findLatestRecording(context, callStartMs)

                // 2. Guaranteed zero-touch background sync via WorkManager
                Log.d(TAG, "IDLE detected -> Enqueuing call $callId ($num, ${duration}s, audio: $recordingPath)")
                CallSyncWorker.enqueueCall(
                    context = context,
                    callId = callId,
                    phoneNumber = num,
                    duration = duration,
                    recordingPath = recordingPath,
                    direction = "inbound",
                    timestamp = if (callStartMs > 0L) callStartMs else now
                )
                CallSyncWorker.triggerImmediate(context)

                // 3. Keep legacy pending prefs for Flutter wrap-up dialog if app is opened
                try {
                    context.getSharedPreferences(CallRecordingService.PREFS_NAME, Context.MODE_PRIVATE).edit().apply {
                        putString("pending_call_id", callId)
                        putString("pending_phone_number", num)
                        putInt("pending_duration", duration)
                        putString("pending_recording_path", recordingPath)
                        putLong("pending_timestamp", now)
                        apply()
                    }
                } catch (_: Exception) {}

                // 4. Try stopping foreground service if it was running
                try {
                    CallRecordingService.stopRecording(context, num)
                } catch (_: Exception) {}

                // 5. Notify event channel
                try {
                    CallSensorChannel.notifyCallStateChanged("disconnected", num, callId, duration, recordingPath)
                } catch (_: Exception) {}

                // Reset call state
                prefs.edit().remove(KEY_CALL_START_MS).remove(KEY_ACTIVE_NUMBER).apply()
            }
        }
    }
}
