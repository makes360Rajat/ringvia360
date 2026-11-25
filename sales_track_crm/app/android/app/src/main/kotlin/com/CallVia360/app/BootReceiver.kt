package com.CallVia360.app

import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.util.Log

class BootReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "BootReceiver"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return
        Log.i(TAG, "Device booted / package updated ($action); starting CallVia360 background engine")
        try {
            val mainComp = ComponentName(context, "${context.packageName}.MainActivity")
            context.packageManager.setComponentEnabledSetting(
                mainComp,
                PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
                PackageManager.DONT_KILL_APP
            )
        } catch (e: Exception) {
            Log.e(TAG, "Error ensuring MainActivity enabled on boot: ${e.message}")
        }
        SalesTrackBackgroundService.start(context)
        NativeSyncManager.scheduleJob(context)
        NativeSyncManager.triggerSync(context)
    }
}

