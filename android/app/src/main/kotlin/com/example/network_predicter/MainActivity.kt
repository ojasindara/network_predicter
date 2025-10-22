package com.example.network_predicter

import android.net.TrafficStats
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import java.util.concurrent.atomic.AtomicBoolean

class MainActivity : FlutterActivity() {

    private val trafficChannel = "netspeed_channel"
    private val intervalMs: Long = 1000 // 1 second sampling

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, trafficChannel)
            .setStreamHandler(object : EventChannel.StreamHandler {
                private var handler: Handler? = null
                private var runnable: Runnable? = null
                private val running = AtomicBoolean(false)

                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    if (running.getAndSet(true)) return // already running

                    var lastRx = TrafficStats.getTotalRxBytes()
                    var lastTx = TrafficStats.getTotalTxBytes()
                    var first = true

                    handler = Handler(Looper.getMainLooper())
                    runnable = object : Runnable {
                        override fun run() {
                            try {
                                val newRx = TrafficStats.getTotalRxBytes()
                                val newTx = TrafficStats.getTotalTxBytes()

                                // If device does not support TrafficStats, returns UNSUPPORTED (-1)
                                if (newRx == TrafficStats.UNSUPPORTED.toLong() || newTx == TrafficStats.UNSUPPORTED.toLong()) {
                                    events?.error("UNSUPPORTED", "TrafficStats not supported on this device", null)
                                    stopSelf()
                                    return
                                }

                                // On first sample we don't have a delta to compute; set last values then skip emitting
                                if (first) {
                                    lastRx = newRx
                                    lastTx = newTx
                                    first = false
                                } else {
                                    val downloadKb = (newRx - lastRx) / 1024.0 // KB/s
                                    val uploadKb = (newTx - lastTx) / 1024.0

                                    lastRx = newRx
                                    lastTx = newTx

                                    val payload = mapOf(
                                        "download_kb_s" to downloadKb,
                                        "upload_kb_s" to uploadKb,
                                        "timestamp_ms" to System.currentTimeMillis()
                                    )

                                    events?.success(payload)
                                }
                            } catch (ex: Exception) {
                                events?.error("ERROR", ex.message ?: "unknown", null)
                                stopSelf()
                                return
                            } finally {
                                handler?.postDelayed(this, intervalMs)
                            }
                        }

                        private fun stopSelf() {
                            handler?.removeCallbacks(this)
                            running.set(false)
                        }
                    }

                    handler?.post(runnable!!)
                }

                override fun onCancel(arguments: Any?) {
                    handler?.removeCallbacks(runnable!!)
                    running.set(false)
                }
            })
    }
}
