package com.example.network_predicter

import android.app.*
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.TrafficStats
import android.os.*
import androidx.core.app.NotificationCompat
import com.google.android.gms.tasks.CancellationTokenSource
import androidx.core.content.ContextCompat
import android.telephony.*
import com.google.android.gms.location.*
import java.util.concurrent.atomic.AtomicBoolean

class NetworkLoggerService : Service() {

    fun interface NetworkLogListener { fun onLog(log: NetworkLog) }

    data class NetworkLog(
        val downloadKb: Double,
        val uploadKb: Double,
        val signalStrength: Int? = null,
        val latitude: Double? = null,
        val longitude: Double? = null,
        val timestamp: Long
    )

    companion object {
        const val CHANNEL_ID = "network_logger_channel"
        private val listeners = mutableListOf<NetworkLogListener>()
        fun subscribe(listener: NetworkLogListener) = synchronized(listeners) { listeners.add(listener) }
        fun unsubscribe(listener: NetworkLogListener) = synchronized(listeners) { listeners.remove(listener) }
        private fun notifyLog(log: NetworkLog) = synchronized(listeners) { listeners.toList().forEach { it.onLog(log) } }
    }

    private val intervalMs: Long = 1000
    private var handler: Handler? = null
    private var runnable: Runnable? = null
    private val running = AtomicBoolean(false)
    private lateinit var fusedLocationClient: FusedLocationProviderClient

    override fun onCreate() {
        super.onCreate()
        fusedLocationClient = LocationServices.getFusedLocationProviderClient(this)
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        startForeground(
            1,
            NotificationCompat.Builder(this, CHANNEL_ID)
                .setContentTitle("Network Logger")
                .setContentText("Logging network speed, signal, location")
                .setSmallIcon(R.mipmap.ic_launcher)
                .setPriority(NotificationCompat.PRIORITY_LOW)
                .build()
        )
        startLogging()
        return START_STICKY
    }

    override fun onBind(intent: Intent): IBinder? = null

    private fun hasPermission(permission: String) =
        ContextCompat.checkSelfPermission(this, permission) == PackageManager.PERMISSION_GRANTED

    private fun getSignalStrength(): Int? {
        return try {
            if (!hasPermission(android.Manifest.permission.READ_PHONE_STATE)) return null
            val tm = getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager
            val cells = tm.allCellInfo ?: return null
            for (c in cells) when (c) {
                is CellInfoGsm -> return c.cellSignalStrength.dbm
                is CellInfoLte -> return c.cellSignalStrength.dbm
                is CellInfoWcdma -> return c.cellSignalStrength.dbm
            }
            null
        } catch (se: SecurityException) {
            null
        }
    }


    private fun getLocation(onResult: (Double?, Double?) -> Unit) {
        try {
            if (!hasPermission(android.Manifest.permission.ACCESS_FINE_LOCATION)) {
                onResult(null, null)
                return
            }
            fusedLocationClient.getCurrentLocation(
                Priority.PRIORITY_HIGH_ACCURACY,
                CancellationTokenSource().token
            ).addOnSuccessListener { loc -> onResult(loc?.latitude, loc?.longitude) }
                .addOnFailureListener { onResult(null, null) }
        } catch (se: SecurityException) {
            onResult(null, null)
        }
    }


    private fun startLogging() {
        if (running.getAndSet(true)) return
        var lastRx = TrafficStats.getTotalRxBytes()
        var lastTx = TrafficStats.getTotalTxBytes()
        var first = true

        handler = Handler(Looper.getMainLooper())
        runnable = object : Runnable {
            override fun run() {
                try {
                    val newRx = TrafficStats.getTotalRxBytes()
                    val newTx = TrafficStats.getTotalTxBytes()
                    if (!first) {
                        val downloadKb = (newRx - lastRx) / 1024.0
                        val uploadKb = (newTx - lastTx) / 1024.0
                        lastRx = newRx
                        lastTx = newTx
                        val signal = getSignalStrength()
                        getLocation { lat, lon ->
                            notifyLog(NetworkLog(downloadKb, uploadKb, signal, lat, lon, System.currentTimeMillis()))
                        }
                    } else { first = false; lastRx = newRx; lastTx = newTx }
                } finally { handler?.postDelayed(this, intervalMs) }
            }
        }
        handler?.post(runnable!!)
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(CHANNEL_ID, "Network Logger", NotificationManager.IMPORTANCE_LOW)
            (getSystemService(NotificationManager::class.java))?.createNotificationChannel(channel)
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        handler?.removeCallbacks(runnable!!)
        running.set(false)
    }
}
