package com.example.network_predicter // keep your package name

import android.net.TrafficStats
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.BufferedInputStream
import java.io.DataOutputStream
import java.net.HttpURLConnection
import java.net.URL
import kotlin.concurrent.thread
import kotlin.math.roundToInt

class MainActivity : FlutterActivity() {

    // EventChannel for real-time network stats
    private val trafficChannel = "netspeed_channel"
    private var lastRx = TrafficStats.getTotalRxBytes()
    private var lastTx = TrafficStats.getTotalTxBytes()
    private val interval: Long = 1000 // update every 1 sec

    // MethodChannel for speed tests
    private val speedTestChannel = "com.networkpredictor/speedtest"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ---------------- EventChannel for real-time traffic stats ----------------
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, trafficChannel)
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

        // ---------------- MethodChannel for download & upload tests ----------------
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, speedTestChannel)
            .setMethodCallHandler { call, _ ->
                when (call.method) {
                    "startDownloadTest" -> {
                        val url = call.argument<String>("url") ?: return@setMethodCallHandler
                        startDownloadTest(url)
                    }
                    "startUploadTest" -> {
                        val url = call.argument<String>("url") ?: return@setMethodCallHandler
                        val fileSize = call.argument<Int>("fileSize") ?: 5 * 1024 * 1024
                        startUploadTest(url, fileSize)
                    }
                    else -> {}
                }
            }
    }

    // ---------------- Download Test ----------------
    private fun startDownloadTest(url: String) {
        thread {
            try {
                val connection = URL(url).openConnection() as HttpURLConnection
                connection.connectTimeout = 15000
                connection.readTimeout = 15000

                val input = BufferedInputStream(connection.inputStream)
                val buffer = ByteArray(1024)
                var bytesRead: Int
                var totalBytes = 0L
                val startTime = System.currentTimeMillis()

                while (input.read(buffer).also { bytesRead = it } != -1) {
                    totalBytes += bytesRead
                }

                val elapsedSeconds = (System.currentTimeMillis() - startTime) / 1000.0
                val mbps = if (elapsedSeconds > 0) (totalBytes * 8 / 1e6) / elapsedSeconds else 0.0

                MethodChannel(flutterEngine!!.dartExecutor.binaryMessenger, speedTestChannel)
                    .invokeMethod("onSpeedTestComplete", mbps.roundToInt())
            } catch (e: Exception) {
                MethodChannel(flutterEngine!!.dartExecutor.binaryMessenger, speedTestChannel)
                    .invokeMethod("onSpeedTestError", e.message ?: "Download failed")
            }
        }
    }

    // ---------------- Upload Test ----------------
    private fun startUploadTest(url: String, fileSize: Int) {
        thread {
            try {
                val connection = URL(url).openConnection() as HttpURLConnection
                connection.doOutput = true
                connection.requestMethod = "POST"
                connection.connectTimeout = 15000
                connection.readTimeout = 15000

                val data = ByteArray(fileSize) { (0..255).random().toByte() }

                val startTime = System.currentTimeMillis()
                DataOutputStream(connection.outputStream).use { it.write(data) }
                connection.responseCode // trigger upload

                val elapsedSeconds = (System.currentTimeMillis() - startTime) / 1000.0
                val mbps = if (elapsedSeconds > 0) (data.size * 8 / 1e6) / elapsedSeconds else 0.0

                MethodChannel(flutterEngine!!.dartExecutor.binaryMessenger, speedTestChannel)

                    .invokeMethod("onSpeedTestComplete", mbps.roundToInt())
            } catch (e: Exception) {
                MethodChannel(flutterEngine!!.dartExecutor.binaryMessenger, speedTestChannel)

                    .invokeMethod("onSpeedTestError", e.message ?: "Upload failed")
            }
        }
    }
}
