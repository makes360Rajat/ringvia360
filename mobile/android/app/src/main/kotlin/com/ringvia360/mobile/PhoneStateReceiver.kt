package com.ringvia360.mobile

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.telephony.TelephonyManager

/**
 * Manifest-registered BroadcastReceiver — fires even when the app is killed.
 *
 * State machine:
 *  RINGING   -> notify Flutter HUD (inbound call incoming)
 *  OFFHOOK   -> start CallRecordingForegroundService (recording begins)
 *  IDLE      -> stop CallRecordingForegroundService (recording stops, wrap-up triggered)
 */
class PhoneStateReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != TelephonyManager.ACTION_PHONE_STATE_CHANGED && intent.action != "com.ringvia360.TEST_PHONE_STATE") return

        val state  = intent.getStringExtra(TelephonyManager.EXTRA_STATE) ?: return
        val number = intent.getStringExtra(TelephonyManager.EXTRA_INCOMING_NUMBER) ?: ""

        when (state) {
            TelephonyManager.EXTRA_STATE_RINGING -> {
                try {
                    CallSensorChannel.notifyCallStateChanged("ringing", number)
                } catch (_: Exception) {}
            }

            TelephonyManager.EXTRA_STATE_OFFHOOK -> {
                try {
                    CallRecordingService.startRecording(context, number)
                } catch (_: Exception) {}
            }

            TelephonyManager.EXTRA_STATE_IDLE -> {
                try {
                    CallRecordingService.stopRecording(context, number)
                } catch (_: Exception) {}
            }
        }
    }
}
