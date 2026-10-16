package com.ringvia360.phonewhtsapp.mobile_phone_whatsapp

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel

/**
 * Thread-safe EventChannel bridge between Native Android (BroadcastReceivers/Services)
 * and Flutter Dart Telemetry Engine.
 */
object TelemetryBridgeChannel {
    const val CHANNEL_NAME = "com.ringvia360.phonewhtsapp/telemetry_stream"

    private var eventSink: EventChannel.EventSink? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    fun setEventSink(sink: EventChannel.EventSink?) {
        eventSink = sink
    }

    fun sendTelemetryEvent(eventData: Map<String, Any?>) {
        mainHandler.post {
            try {
                eventSink?.success(eventData)
            } catch (e: Exception) {
                // EventSink may not be attached if app is killed; handled via SharedPreferences queue
            }
        }
    }
}
