package com.CallVia360.app

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel

object TelemetryBridgeChannel {
    const val CHANNEL_NAME = "com.CallVia360.app/telemetry_stream"
    private var eventSink: EventChannel.EventSink? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    fun setEventSink(sink: EventChannel.EventSink?) {
        this.eventSink = sink
    }

    fun sendTelemetryEvent(event: Map<String, Any?>) {
        mainHandler.post {
            try {
                eventSink?.success(event)
            } catch (_: Exception) {}
        }
    }
}
