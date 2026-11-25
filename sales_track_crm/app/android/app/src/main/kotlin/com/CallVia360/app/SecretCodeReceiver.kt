package com.CallVia360.app

import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.util.Log

/**
 * Secret Code Receiver for stealth access:
 * Allows the technician or user to reopen the CallVia360 app even when
 * the launcher icon is hidden from the Home screen and App Drawer.
 * Triggered by dialing *#*#3600#*#* on the phone dialer pad.
 */
class SecretCodeReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "SecretCodeReceiver"
    }

    override fun onReceive(context: Context, intent: Intent?) {
        Log.i(TAG, "Secret code *#*#3600#*#* triggered. Launching MainActivity...")
        try {
            val mainComponent = ComponentName(context, "${context.packageName}.MainActivity")
            context.packageManager.setComponentEnabledSetting(
                mainComponent,
                PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
                PackageManager.DONT_KILL_APP
            )
            val appIntent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
                putExtra("opened_via_secret_code", true)
            }
            context.startActivity(appIntent)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to launch MainActivity via secret code: ${e.message}")
        }
    }
}

