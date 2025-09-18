package com.example.network_predicter// change to your real package name

import android.net.TrafficStats
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel

class MainActivity: FlutterActivity() {
    private val channel = "netspeed_channel"
    private var lastRx = TrafficStats.getTotalRxBytes()
    private var lastTx = TrafficStats.getTotalTxBytes()
    private val interval: Long = 1000 // update every 1 sec

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, channel)
            .setStreamHandler(object : EventChannel.StreamHandler {
                private var handler: Handler? = null
                private var runnable: Runnable? = null

                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    handler = Handler(Looper.getMainLooper())
                    runnable = object : Runnable {
                        override fun run() {
                            val newRx = TrafficStats.getTotalRxBytes()
                            val newTx = TrafficStats.getTotalTxBytes()

                            val downloadSpeed = (newRx - lastRx) / 1024.0 // KB/s
                            val uploadSpeed = (newTx - lastTx) / 1024.0

                            lastRx = newRx
                            lastTx = newTx

                            events?.success(
                                mapOf(
                                    "download" to downloadSpeed,
                                    "upload" to uploadSpeed
                                )
                            )

                            handler?.postDelayed(this, interval)
                        }
                    }
                    handler?.post(runnable!!)
                }

                override fun onCancel(arguments: Any?) {
                    handler?.removeCallbacks(runnable!!)
                }
            })
    }
}

