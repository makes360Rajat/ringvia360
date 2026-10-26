package com.ringvia360.mobile

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel

/**
 * Singleton channel that holds a reference to the Flutter EventChannel sink.
 * Thread-safe posting to the main Looper so events never crash on background threads.
 */
object CallSensorChannel {

    const val CHANNEL_NAME = "com.ringvia360/call_sensor"

    private var eventSink: EventChannel.EventSink? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    fun setEventSink(sink: EventChannel.EventSink?) {
        eventSink = sink
    }

    /**
     * Sends a call state change event to Flutter.
     * @param state one of "ringing", "connected", "disconnected"
     * @param phoneNumber the caller's number
     * @param callId unique call identifier
     * @param duration call duration in seconds
     * @param recordingPath local file path to audio recording
     */
    fun notifyCallStateChanged(
        state: String,
        phoneNumber: String,
        callId: String? = null,
        duration: Int = 0,
        recordingPath: String? = null
    ) {
        mainHandler.post {
            try {
                eventSink?.success(
                    mapOf(
                        "state" to state,
                        "phoneNumber" to (phoneNumber ?: ""),
                        "callId" to (callId ?: ""),
                        "duration" to duration,
                        "recordingPath" to (recordingPath ?: "")
                    )
                )
            } catch (_: Exception) {}
        }
    }
}
