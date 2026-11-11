package com.ringvia360.mobile

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * Ensures zero-touch background sync survives phone reboots and app updates.
 */
class BootReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "RV360_BootReceiver"
    }

    override fun onReceive(context: Context, intent: Intent?) {
        val action = intent?.action ?: return
        Log.d(TAG, "Received broadcast action: $action")

        if (action == Intent.ACTION_BOOT_COMPLETED ||
            action == "android.intent.action.QUICKBOOT_POWERON" ||
            action == Intent.ACTION_MY_PACKAGE_REPLACED
        ) {
            // 1. Reschedule 15-minute background sync worker
            CallSyncWorker.schedulePeriodic(context)

            // 2. If there are pending un-synced calls from before reboot, trigger immediate sync
            CallSyncWorker.triggerImmediate(context)
            Log.d(TAG, "Zero-touch background sync scheduled after boot/update")
        }
    }
}

