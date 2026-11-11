package com.CallVia360.app

import android.app.job.JobParameters
import android.app.job.JobService
import android.util.Log

class SalesTrackJobService : JobService() {
    companion object {
        private const val TAG = "SalesTrackJobService"
    }

    override fun onStartJob(params: JobParameters?): Boolean {
        Log.d(TAG, "JobService woke up: running watchdog sync")
        SalesTrackBackgroundService.start(applicationContext)
        NativeSyncManager.triggerSync(applicationContext)
        jobFinished(params, false)
        return false
    }

    override fun onStopJob(params: JobParameters?): Boolean {
        return true
    }
}

