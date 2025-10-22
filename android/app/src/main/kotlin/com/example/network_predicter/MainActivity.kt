package com.example.network_predicter


import android.content.Intent
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel


class MainActivity : FlutterActivity() {


    private val trafficChannel = "netspeed_channel"
    private var subscription: NetworkLoggerService.NetworkLogListener? = null


    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)


// Start the foreground logging service
        val serviceIntent = Intent(this, NetworkLoggerService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(serviceIntent)
        } else {
            startService(serviceIntent)
        }


// Set up EventChannel to receive traffic data from the service
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, trafficChannel)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
// create a listener (SAM) and subscribe to service
                    subscription = NetworkLoggerService.NetworkLogListener { log ->
                        val payload = mapOf(
                            "download_kb_s" to log.downloadKb,
                            "upload_kb_s" to log.uploadKb,
                            "signal_dbm" to log.signalStrength,
                            "latitude" to log.latitude,
                            "longitude" to log.longitude,
                            "timestamp_ms" to log.timestamp
                        )
                        events?.success(payload)
                    }


                    subscription?.let { NetworkLoggerService.subscribe(it) }
                }


                override fun onCancel(arguments: Any?) {
                    subscription?.let { NetworkLoggerService.unsubscribe(it) }
                    subscription = null
                }
            })
    }
}