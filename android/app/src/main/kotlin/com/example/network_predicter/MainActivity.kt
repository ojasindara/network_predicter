package com.example.network_predicter

import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.Manifest
import androidx.core.content.ContextCompat
import android.content.pm.PackageManager
import androidx.core.app.ActivityCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import android.util.Log

class MainActivity : FlutterActivity() {

    private val trafficChannel = "netspeed_channel"
    private var subscription: NetworkLoggerService.NetworkLogListener? = null
    private val LOCATION_PERMISSION_REQUEST_CODE = 1001

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Check permissions for Android 13+ (especially location + notification for foreground service)
        if (ActivityCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION)
            != PackageManager.PERMISSION_GRANTED ||
            (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
                    ActivityCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS)
                    != PackageManager.PERMISSION_GRANTED)
        ) {
            val permissions = mutableListOf(Manifest.permission.ACCESS_FINE_LOCATION)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                permissions.add(Manifest.permission.POST_NOTIFICATIONS)
            }
            ActivityCompat.requestPermissions(
                this,
                permissions.toTypedArray(),
                LOCATION_PERMISSION_REQUEST_CODE
            )
        } else {
            startLoggerService()
        }
    }

    private fun startLoggerService() {
        try {
            // Check location permission
            val fineLocation = android.Manifest.permission.ACCESS_FINE_LOCATION
            val coarseLocation = android.Manifest.permission.ACCESS_COARSE_LOCATION
            if (ContextCompat.checkSelfPermission(this, fineLocation) != PackageManager.PERMISSION_GRANTED &&
                ContextCompat.checkSelfPermission(this, coarseLocation) != PackageManager.PERMISSION_GRANTED) {

                ActivityCompat.requestPermissions(
                    this,
                    arrayOf(android.Manifest.permission.ACCESS_FINE_LOCATION, android.Manifest.permission.ACCESS_COARSE_LOCATION),
                    101
                )
                return
            }


            val serviceIntent = Intent(this, NetworkLoggerService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(serviceIntent)
            } else {
                startService(serviceIntent)
            }
            Log.d("MainActivity", "NetworkLoggerService started successfully.")
        } catch (e: Exception) {
            Log.e("MainActivity", "Failed to start service: ${e.message}")
        }
    }


    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, trafficChannel)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    subscription = NetworkLoggerService.NetworkLogListener { log ->
                        val payload = mapOf(
                            "downloadKb" to log.downloadKb,
                            "uploadKb" to log.uploadKb,
                            "signalStrength" to log.signalStrength,
                            "latitude" to log.latitude,
                            "longitude" to log.longitude,
                            "weather" to log.weather,
                            "temperature" to log.temperature,
                            "timestamp" to log.timestamp,
                            "region" to log.region
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

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == LOCATION_PERMISSION_REQUEST_CODE) {
            val granted = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
            if (granted) {
                startLoggerService()
            } else {
                Log.w("MainActivity", "Location permission not granted. Service not started.")
            }
        }
    }
}
