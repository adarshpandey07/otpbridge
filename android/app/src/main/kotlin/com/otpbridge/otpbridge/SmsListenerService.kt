package com.otpbridge.otpbridge

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.provider.Telephony
import io.flutter.plugin.common.EventChannel

/**
 * Foreground service that keeps OTPBridge listening for incoming SMS.
 *
 * Responsibilities:
 *  - shows the mandatory ongoing notification (its own low-importance channel),
 *  - dynamically registers/unregisters an [SmsReceiver],
 *  - owns the static EventChannel sink that streams messages to Flutter.
 *
 * The receiver is also declared in the manifest; [dispatch] de-duplicates so a
 * message delivered to both registrations reaches Dart exactly once.
 */
class SmsListenerService : Service() {

    private var receiver: SmsReceiver? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val notification = buildNotification()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }

        if (receiver == null) {
            val filter = IntentFilter(Telephony.Sms.Intents.SMS_RECEIVED_ACTION).apply {
                priority = RECEIVER_PRIORITY
            }
            receiver = SmsReceiver().also {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    // SMS_RECEIVED is a protected system broadcast, but Android 14+
                    // still requires an explicit export flag for dynamic receivers.
                    registerReceiver(it, filter, Context.RECEIVER_EXPORTED)
                } else {
                    registerReceiver(it, filter)
                }
            }
        }
        isRunning = true
        return START_STICKY
    }

    override fun onDestroy() {
        receiver?.let {
            try {
                unregisterReceiver(it)
            } catch (e: IllegalArgumentException) {
                // Already unregistered — nothing to do.
            }
        }
        receiver = null
        isRunning = false
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java) ?: return
        val channel = NotificationChannel(
            CHANNEL_ID,
            "SMS listening",
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "Shown while OTPBridge watches incoming SMS for OTPs"
            setShowBadge(false)
        }
        manager.createNotificationChannel(channel)
    }

    private fun buildNotification(): Notification {
        val contentIntent = packageManager.getLaunchIntentForPackage(packageName)?.let {
            PendingIntent.getActivity(
                this,
                0,
                it,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
        return builder
            .setContentTitle("OTPBridge is listening")
            .setContentText("Watching incoming SMS for OTPs to forward")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .apply { contentIntent?.let { setContentIntent(it) } }
            .build()
    }

    companion object {
        private const val CHANNEL_ID = "otpbridge_listener"
        private const val NOTIFICATION_ID = 4242
        private const val RECEIVER_PRIORITY = 999
        private const val DEDUPE_WINDOW_MS = 3_000L

        @Volatile
        var isRunning: Boolean = false
            private set

        @Volatile
        private var eventSink: EventChannel.EventSink? = null

        private var lastFingerprint: String? = null
        private var lastDispatchAt: Long = 0L

        /** Called by MainActivity's EventChannel StreamHandler. */
        fun setEventSink(sink: EventChannel.EventSink?) {
            eventSink = sink
        }

        fun start(context: Context) {
            val intent = Intent(context, SmsListenerService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, SmsListenerService::class.java))
            isRunning = false
        }

        /**
         * Forwards one parsed SMS to the Flutter EventChannel sink. The receiver
         * can be registered twice (manifest + dynamic), so identical payloads
         * inside a short window are dropped.
         */
        fun dispatch(sender: String, body: String, timestamp: Long, simSlot: Int) {
            val fingerprint = "$sender|$body|$timestamp"
            val now = System.currentTimeMillis()
            synchronized(this) {
                if (fingerprint == lastFingerprint && now - lastDispatchAt < DEDUPE_WINDOW_MS) {
                    return
                }
                lastFingerprint = fingerprint
                lastDispatchAt = now
            }
            // BroadcastReceiver.onReceive runs on the main thread, which is the
            // thread EventSink requires.
            eventSink?.success(
                mapOf(
                    "sender" to sender,
                    "body" to body,
                    "timestamp" to timestamp,
                    "simSlot" to simSlot,
                ),
            )
        }
    }
}
