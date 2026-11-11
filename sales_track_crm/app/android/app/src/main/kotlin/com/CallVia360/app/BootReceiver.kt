package com.CallVia360.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class BootReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "BootReceiver"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return
        Log.i(TAG, "Device booted / package updated ($action); starting CallVia360 background engine")
        SalesTrackBackgroundService.start(context)
        NativeSyncManager.scheduleJob(context)
        NativeSyncManager.triggerSync(context)
    }
}

