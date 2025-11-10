package com.example.network_predicter

import android.app.*
import android.content.Intent
import android.content.pm.PackageManager
import android.net.TrafficStats
import android.os.Build
import android.os.IBinder
import android.telephony.*
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import com.google.android.gms.location.*
import kotlinx.coroutines.*
import java.util.concurrent.atomic.AtomicBoolean

class NetworkLoggerService : Service() {

    data class NetworkLog(
        val downloadKb: Double,
        val uploadKb: Double,
        val signalStrength: Int?,
        val latitude: Double?,
        val longitude: Double?,
        val timestamp: Long,
        val weather: String,
        val temperature: Double,
        val region: String
    )

    fun interface NetworkLogListener { fun onLog(log: NetworkLog) }
    companion object {
        private val listeners = mutableListOf<NetworkLogListener>()
        fun subscribe(listener: NetworkLogListener) = synchronized(listeners) { listeners.add(listener) }
        fun unsubscribe(listener: NetworkLogListener) = synchronized(listeners) { listeners.remove(listener) }
        private fun notifyLog(log: NetworkLog) {
            synchronized(listeners) { listeners.toList().forEach { it.onLog(log) } }
            Log.d("NetworkLoggerService", "Log notified: $log")
        }
    }

    private val intervalMs: Long = 1000L
    private val running = AtomicBoolean(false)
    private lateinit var fusedLocationClient: FusedLocationProviderClient
    private val coroutineScope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private var lastSignalStrength: Int? = null
    private var lastLatitude: Double? = null
    private var lastLongitude: Double? = null

    override fun onCreate() {
        super.onCreate()
        Log.d("NetworkLoggerService", "Service created")
        fusedLocationClient = LocationServices.getFusedLocationProviderClient(this)
        startForegroundNotification()
        registerSignalStrengthListener()
        startLogging()
    }

    private fun startForegroundNotification() {
        val channelId = "network_logger_channel"
        val channelName = "Network Logger"
        val manager = getSystemService(NotificationManager::class.java)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(channelId, channelName, NotificationManager.IMPORTANCE_LOW)
            manager.createNotificationChannel(channel)
        }

        val notification = NotificationCompat.Builder(this, channelId)
            .setContentTitle("Network Logger Running")
            .setContentText("Collecting network usage and signal data")
            .setSmallIcon(android.R.drawable.stat_sys_download)
            .setOngoing(true)
            .build()

        startForeground(1, notification)
    }

    private fun registerSignalStrengthListener() {
        val tm = getSystemService(TELEPHONY_SERVICE) as TelephonyManager
        val mainExecutor = ContextCompat.getMainExecutor(this)

        if (ContextCompat.checkSelfPermission(
                this,
                android.Manifest.permission.READ_PHONE_STATE
            ) != PackageManager.PERMISSION_GRANTED
        ) {
            Log.d("NetworkLoggerService", "READ_PHONE_STATE permission not granted")
            return
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S_V2) { // API 31+
            tm.registerTelephonyCallback(
                mainExecutor,
                object : TelephonyCallback(), TelephonyCallback.SignalStrengthsListener {
                    override fun onSignalStrengthsChanged(signalStrength: SignalStrength) {
                        // No super call here!
                        lastSignalStrength = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                            val gsmStrength = signalStrength.cellSignalStrengths
                                .filterIsInstance<CellSignalStrengthGsm>()
                                .firstOrNull()
                            val lteStrength = signalStrength.cellSignalStrengths
                                .filterIsInstance<CellSignalStrengthLte>()
                                .firstOrNull()
                            val wcdmaStrength = signalStrength.cellSignalStrengths
                                .filterIsInstance<CellSignalStrengthWcdma>()
                                .firstOrNull()

                            gsmStrength?.dbm ?: lteStrength?.dbm ?: wcdmaStrength?.dbm
                        } else {
                            @Suppress("DEPRECATION")
                            signalStrength.gsmSignalStrength.takeIf { it != Int.MAX_VALUE }
                                ?.let { -113 + 2 * it }
                        }

                        Log.d(
                            "NetworkLoggerService",
                            "Signal strength updated: $lastSignalStrength"
                        )
                    }
                }
            )
        } else {
            tm.listen(object : PhoneStateListener() {
                override fun onSignalStrengthsChanged(signalStrength: SignalStrength) {
                    super.onSignalStrengthsChanged(signalStrength) // Here it's fine
                    @Suppress("DEPRECATION")
                    lastSignalStrength =
                        signalStrength.gsmSignalStrength.takeIf { it != Int.MAX_VALUE }
                            ?.let { -113 + 2 * it }
                    Log.d("NetworkLoggerService", "Signal strength updated: $lastSignalStrength")
                }
            }, PhoneStateListener.LISTEN_SIGNAL_STRENGTHS)
        }
    }

    private fun startLogging() {
        if (running.getAndSet(true)) return

        coroutineScope.launch {
            var lastRx = TrafficStats.getTotalRxBytes().takeIf { it != TrafficStats.UNSUPPORTED.toLong() } ?: 0L
            var lastTx = TrafficStats.getTotalTxBytes().takeIf { it != TrafficStats.UNSUPPORTED.toLong() } ?: 0L

            while (running.get()) {
                try {
                    val newRx = TrafficStats.getTotalRxBytes().takeIf { it != TrafficStats.UNSUPPORTED.toLong() } ?: lastRx
                    val newTx = TrafficStats.getTotalTxBytes().takeIf { it != TrafficStats.UNSUPPORTED.toLong() } ?: lastTx

                    val downloadKb = (newRx - lastRx) / 1024.0
                    val uploadKb = (newTx - lastTx) / 1024.0
                    val region = "room"

                    lastRx = newRx
                    lastTx = newTx

                    val lat = lastLatitude
                    val lon = lastLongitude

                    if (lat != null && lon != null) {
                        val log = NetworkLog(
                            downloadKb = downloadKb,
                            uploadKb = uploadKb,
                            signalStrength = lastSignalStrength,
                            latitude = lat,
                            longitude = lon,
                            timestamp = System.currentTimeMillis(),
                            weather = "Sunny",
                            temperature = 30.0,
                            region
                        )
                        withContext(Dispatchers.Main) { notifyLog(log) }
                    } else {
                        Log.d("NetworkLoggerService", "Skipping log: location unavailable")
                        updateLocation()
                    }

                } catch (e: Exception) {
                    Log.e("NetworkLoggerService", "Error logging network data: $e")
                }
                delay(intervalMs)
            }
        }
    }

    private fun updateLocation() {
        if (ContextCompat.checkSelfPermission(this, android.Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED &&
            ContextCompat.checkSelfPermission(this, android.Manifest.permission.ACCESS_COARSE_LOCATION) != PackageManager.PERMISSION_GRANTED
        ) {
            Log.d("NetworkLoggerService", "Location permission not granted")
            return
        }

        val token = com.google.android.gms.tasks.CancellationTokenSource()
        fusedLocationClient.getCurrentLocation(Priority.PRIORITY_HIGH_ACCURACY, token.token)
            .addOnSuccessListener { location ->
                if (location != null && location.latitude != 0.0 && location.longitude != 0.0) {
                    lastLatitude = location.latitude
                    lastLongitude = location.longitude
                    Log.d("NetworkLoggerService", "Location updated: lat=${location.latitude}, lon=${location.longitude}")
                }
            }.addOnFailureListener { e ->
                Log.d("NetworkLoggerService", "Failed to get location: $e")
            }
    }

    override fun onBind(intent: Intent): IBinder? = null

    override fun onDestroy() {
        super.onDestroy()
        running.set(false)
        coroutineScope.cancel()
        Log.d("NetworkLoggerService", "Service destroyed")
    }
}
