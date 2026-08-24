package com.focusecho.ai

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.app.usage.UsageStatsManager
import android.app.usage.UsageEvents
import android.content.Context
import android.content.Intent
import android.content.BroadcastReceiver
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import androidx.core.app.NotificationCompat
import org.json.JSONObject
import java.time.Instant

class FocusDetectionService : Service() {
    private val handler = Handler(Looper.getMainLooper())
    private lateinit var runnable: Runnable
    private var lastForegroundPackage: String? = null
    private var lastSwitchTimeMs: Long = 0
    private var lastDistractionNotifMs: Long = 0
    private var screenReceiver: BroadcastReceiver? = null

    // Cached values — refreshed every CACHE_TTL_MS to avoid disk reads every tick
    private var cachedSessionActive = false
    private var lastCacheRefresh = 0L

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        registerScreenReceiver()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == STOP_ACTION) {
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
            return START_NOT_STICKY
        }

        refreshCache(force = true)
        startForeground(1001, buildNotification())
        runnable = Runnable {
            refreshCache()
            detectForegroundApp()
            drainAccessibilityQueue()
            handler.postDelayed(runnable, POLL_INTERVAL_MS)
        }
        handler.post(runnable)
        return START_STICKY
    }

    /**
     * Re-read SharedPreferences at most once per [CACHE_TTL_MS] to avoid
     * disk + JSON parse overhead on every poll tick.
     */
    private fun refreshCache(force: Boolean = false) {
        val now = System.currentTimeMillis()
        if (!force && now - lastCacheRefresh < CACHE_TTL_MS) return
        lastCacheRefresh = now

        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        cachedSessionActive = prefs.getBoolean("flutter.session_active", false)
    }

    private fun detectForegroundApp() {
        if (!cachedSessionActive) return

        val packageName = getForegroundPackageName() ?: return
        if (packageName == lastForegroundPackage) return

        val now = System.currentTimeMillis()
        if (now - lastSwitchTimeMs < 500) return
        lastSwitchTimeMs = now
        lastForegroundPackage = packageName

        val label = getAppLabel(packageName)

        // Check if this is a known distracting app and fire a heads-up notification
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val distractingRaw = prefs.getString("flutter.distracting_apps", "[]") ?: "[]"
        val isDistraction = distractingRaw.contains(packageName) ||
            ALWAYS_DISTRACTION_PACKAGES.contains(packageName)
        if (isDistraction) {
            sendDistractionNotification(label, packageName)
        }

        val payload = JSONObject()
            .put("eventType", "app_switch")
            .put("packageName", packageName)
            .put("appLabel", label)
            .put("timestamp", Instant.now().toString())
            .put("source", "usage_stats")
            .toString()
        sendOrBuffer(payload)
    }

    /**
     * Fires a high-priority heads-up notification when a distracting app
     * is detected. Visible even when FocusEcho is fully backgrounded.
     */
    private fun sendDistractionNotification(appLabel: String, packageName: String) {
        // Throttle: at most one distraction notification per 30 seconds
        val now = System.currentTimeMillis()
        if (now - lastDistractionNotifMs < DISTRACTION_NOTIF_THROTTLE_MS) return
        lastDistractionNotifMs = now

        val openAppIntent = packageManager.getLaunchIntentForPackage(this.packageName)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, openAppIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(this, DISTRACTION_CHANNEL_ID)
            .setContentTitle("⚠️ Focus check — $appLabel detected")
            .setContentText("You opened $appLabel during your focus session. Tap to return.")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .build()

        val manager = getSystemService(NotificationManager::class.java)
        manager.notify(DISTRACTION_NOTIF_ID, notification)
    }

    /**
     * Drain events posted by [FocusAccessibilityService] via the shared
     * [DistractionEventQueue].
     */
    private fun drainAccessibilityQueue() {
        if (!cachedSessionActive) return
        val events = DistractionEventQueue.drainAll()
        for (event in events) {
            sendOrBuffer(event)
        }
    }

    /**
     * Deliver payload to Flutter via EventChannel sink, or buffer if the
     * sink is null (Flutter UI not active).  Buffered events are flushed
     * when the sink reconnects (see [MainActivity]).
     */
    private fun sendOrBuffer(payload: String) {
        val sink = MainActivity.distractionEventSink
        if (sink != null) {
            // Flush any buffered events first
            flushPendingEvents()
            sink.success(payload)
        } else {
            synchronized(pendingEvents) {
                pendingEvents.add(payload)
                if (pendingEvents.size > MAX_BUFFER_SIZE) pendingEvents.removeAt(0)
            }
        }
    }

    private fun flushPendingEvents() {
        val sink = MainActivity.distractionEventSink ?: return
        synchronized(pendingEvents) {
            for (p in pendingEvents) {
                sink.success(p)
            }
            pendingEvents.clear()
        }
    }

    private fun getForegroundPackageName(): String? {
        val usageManager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val now = System.currentTimeMillis()
        val events = usageManager.queryEvents(now - 10_000, now)
        val event = UsageEvents.Event()
        var latestPackage: String? = null

        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            if (
                event.eventType == UsageEvents.Event.MOVE_TO_FOREGROUND ||
                event.eventType == UsageEvents.Event.ACTIVITY_RESUMED
            ) {
                latestPackage = event.packageName
            }
        }

        return latestPackage
    }

    private fun getAppLabel(packageName: String): String {
        return try {
            val info = packageManager.getApplicationInfo(packageName, 0)
            packageManager.getApplicationLabel(info).toString()
        } catch (_: PackageManager.NameNotFoundException) {
            packageName
        }
    }

    private fun buildNotification(): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Focus Echo is active")
            .setContentText("Monitoring your focus session...")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .build()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(NotificationManager::class.java)

            // Persistent foreground service notification (low importance — silent)
            val serviceChannel = NotificationChannel(
                CHANNEL_ID,
                "Focus Detection",
                NotificationManager.IMPORTANCE_LOW
            )
            manager.createNotificationChannel(serviceChannel)

            // Distraction alert notifications (high importance — heads-up banner)
            val alertChannel = NotificationChannel(
                DISTRACTION_CHANNEL_ID,
                "Distraction Alerts",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Notifies you when a distracting app is opened during a focus session"
                enableVibration(true)
            }
            manager.createNotificationChannel(alertChannel)
        }
    }

    override fun onDestroy() {
        handler.removeCallbacksAndMessages(null)
        unregisterScreenReceiver()
        stopForeground(STOP_FOREGROUND_REMOVE)
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    companion object {
        const val START_ACTION = "com.focusecho.ai.START_FOCUS_DETECTION"
        const val STOP_ACTION = "com.focusecho.ai.STOP_FOCUS_DETECTION"
        private const val CHANNEL_ID = "focus_detection_channel"
        private const val DISTRACTION_CHANNEL_ID = "distraction_alert_channel"
        private const val DISTRACTION_NOTIF_ID = 2001

        /** Poll every 3 seconds instead of 1 to reduce battery drain. */
        private const val POLL_INTERVAL_MS = 3_000L

        /** Refresh cached SharedPreferences values every 5 seconds. */
        private const val CACHE_TTL_MS = 5_000L

        /** Max buffered events when Flutter UI is not active. */
        private const val MAX_BUFFER_SIZE = 100

        /** Throttle distraction notifications to one per 30 seconds. */
        private const val DISTRACTION_NOTIF_THROTTLE_MS = 30_000L

        /** Well-known always-distracting packages (fallback if prefs unavailable). */
        private val ALWAYS_DISTRACTION_PACKAGES = setOf(
            "com.instagram.android",
            "com.facebook.katana",
            "com.twitter.android",
            "com.zhiliaoapp.musically",
            "com.snapchat.android",
            "com.reddit.frontpage",
        )

        /** Events buffered when EventChannel sink is null. */
        val pendingEvents = mutableListOf<String>()
    }

    private fun registerScreenReceiver() {
        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_SCREEN_OFF)
            addAction(Intent.ACTION_SCREEN_ON)
        }
        screenReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                val action = intent?.action ?: return
                val eventType = when (action) {
                    Intent.ACTION_SCREEN_OFF -> "screen_off"
                    Intent.ACTION_SCREEN_ON -> "screen_on"
                    else -> return
                }
                val payload = JSONObject()
                    .put("eventType", eventType)
                    .put("timestamp", Instant.now().toString())
                    .toString()
                sendOrBuffer(payload)
            }
        }
        registerReceiver(screenReceiver, filter)
    }

    private fun unregisterScreenReceiver() {
        screenReceiver?.let {
            unregisterReceiver(it)
        }
        screenReceiver = null
    }
}
