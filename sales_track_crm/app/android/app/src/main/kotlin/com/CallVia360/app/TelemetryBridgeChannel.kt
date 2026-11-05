package com.CallVia360.app

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel
import java.util.concurrent.ConcurrentLinkedQueue

object TelemetryBridgeChannel {
    const val CHANNEL_NAME = "com.CallVia360.app/telemetry_stream"
    private var eventSink: EventChannel.EventSink? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private val pendingEvents = ConcurrentLinkedQueue<Map<String, Any?>>()

    fun setEventSink(sink: EventChannel.EventSink?) {
        this.eventSink = sink
        if (sink != null) {
            mainHandler.post {
                while (!pendingEvents.isEmpty()) {
                    val ev = pendingEvents.poll() ?: break
                    try {
                        sink.success(ev)
                    } catch (_: Exception) {}
                }
            }
        }
    }

    fun sendTelemetryEvent(event: Map<String, Any?>) {
        mainHandler.post {
            try {
                if (eventSink != null) {
                    eventSink?.success(event)
                } else {
                    pendingEvents.offer(event)
                }
            } catch (_: Exception) {
                pendingEvents.offer(event)
            }
        }
    }
}
