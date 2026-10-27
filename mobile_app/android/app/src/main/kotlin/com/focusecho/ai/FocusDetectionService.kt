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
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import androidx.core.app.NotificationCompat
import org.json.JSONObject
import java.time.Instant

class FocusDetectionService : Service() {
    private val handler = Handler(Looper.getMainLooper())
    private lateinit var runnable: Runnable
    private var lastForegroundPackage: String? = null
    private var lastSwitchTimeMs: Long = 0
    private var continuousDistractionStartMs: Long = 0L
    private var lastNudgeSentMs: Long = 0L
    private var currentDistractionLevel: Int = 1
    private var screenReceiver: BroadcastReceiver? = null
    private var simulationReceiver: BroadcastReceiver? = null
    private var wakeLock: PowerManager.WakeLock? = null

    // Cached values — refreshed every CACHE_TTL_MS to avoid disk reads every tick
    private var cachedSessionActive = false
    private var lastCacheRefresh = 0L

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        registerScreenReceiver()
        registerSimulationReceiver()
        wakeLock = (getSystemService(Context.POWER_SERVICE) as PowerManager)
            .newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "FocusEcho:DistractionAlertLock")
            .apply { setReferenceCounted(false) }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == STOP_ACTION) {
            clearDistractionNotifications()
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
            return START_NOT_STICKY
        }
        if (intent?.action == TAKE_BREAK_ACTION) {
            sendOrBuffer(
                JSONObject()
                    .put("eventType", "intervention_action")
                    .put("level", intent.getIntExtra("level", 1))
                    .put("action", "take_break")
                    .put("timestamp", Instant.now().toString())
                    .toString()
            )
            getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                .edit().putBoolean("flutter.session_active", false).apply()
            clearDistractionNotifications()
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
            return START_NOT_STICKY
        }

        // Feature 2 — a fresh session resets the relapse ladder.
        DistractionEventQueue.resetSession()
        lastForegroundPackage = null
        lastSwitchTimeMs = 0L
        continuousDistractionStartMs = 0L
        lastNudgeSentMs = 0L
        currentDistractionLevel = 1
        refreshCache(force = true)
        startForeground(1001, buildNotification())
        runnable = Runnable {
            refreshCache()
            detectForegroundApp()
            flushPendingEvents()
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
        val now = System.currentTimeMillis()
        val label = getAppLabel(packageName)

        // Check if this is a known distracting app and escalate accordingly
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val distractingRaw = prefs.getString("flutter.distracting_apps", "[]") ?: "[]"
        val isDistraction = distractingRaw.contains(packageName) ||
            ALWAYS_DISTRACTION_PACKAGES.contains(packageName)

        if (packageName == lastForegroundPackage) {
            if (isDistraction) {
                if (continuousDistractionStartMs == 0L) continuousDistractionStartMs = now
                val elapsed = now - continuousDistractionStartMs
                if (now - lastNudgeSentMs >= NUDGE_REPEAT_INTERVAL_MS) {
                    sendDistractionNotification(
                        label,
                        currentDistractionLevel,
                        relapse = 1,
                        isRepeat = true,
                        elapsedMs = elapsed,
                    )
                    lastNudgeSentMs = now
                }
            } else {
                continuousDistractionStartMs = 0L
                lastNudgeSentMs = 0L
                currentDistractionLevel = 1
                clearDistractionNotifications()
            }
            return
        }

        if (now - lastSwitchTimeMs < 500) return
        lastSwitchTimeMs = now
        lastForegroundPackage = packageName

        if (isDistraction) {
            continuousDistractionStartMs = now
            lastNudgeSentMs = now
            handleDistractionDetected(packageName, label, source = "usage_stats")
            return
        }

        continuousDistractionStartMs = 0L
        lastNudgeSentMs = 0L
        currentDistractionLevel = 1
        clearDistractionNotifications()

        val payload = JSONObject()
            .put("eventType", "app_switch")
            .put("packageName", packageName)
            .put("appLabel", label)
            .put("timestamp", Instant.now().toString())
            .put("source", "usage_stats")
            .toString()
        sendOrBuffer(payload)
    }

    /** Feature 2 — relapse count to escalation level (1/2/3). */
    private fun escalationLevelFor(relapse: Int): Int {
        return when {
            relapse <= 1 -> 1
            relapse <= 3 -> 2
            else -> 3
        }
    }

    /**
     * Feature 2 — single escalation entry point shared by real foreground-app
     * polling (source="usage_stats") and the debug ADB broadcast fixture
     * (source="adb_fixture"). Registers the per-session relapse, drives the
     * notification ladder (all levels post a heads-up notification; level 3
     * also requests a full-screen intent), and forwards the event to Flutter with its
     * escalation level so the SQLite row records it.
     */
    private fun handleDistractionDetected(packageName: String, label: String, source: String) {
        val relapse = DistractionEventQueue.registerRelapse()
        val level = escalationLevelFor(relapse)
        currentDistractionLevel = level
        sendDistractionNotification(label, level, relapse)
        val payload = JSONObject()
            .put("eventType", "app_switch")
            .put("packageName", packageName)
            .put("appLabel", label)
            .put("timestamp", Instant.now().toString())
            .put("source", source)
            .put("escalation_level", level)
            .toString()
        sendOrBuffer(payload)
    }

    /**
     * Fires a high-priority heads-up notification when a distracting app
     * is detected. Visible even when FocusEcho is fully backgrounded.
     */
    private fun sendDistractionNotification(
        appLabel: String,
        level: Int,
        relapse: Int,
        isRepeat: Boolean = false,
        elapsedMs: Long = 0L,
    ) {
        acquireDistractionWakeLock()

        val fullScreenIntent = PendingIntent.getActivity(
            this,
            3000 + relapse,
            Intent(this, InterventionActivity::class.java).apply {
                putExtra(InterventionActivity.EXTRA_LEVEL, level)
                putExtra(InterventionActivity.EXTRA_COUNT, relapse)
                putExtra(InterventionActivity.EXTRA_APP_LABEL, appLabel)
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val takeBreakIntent = PendingIntent.getService(
            this,
            4000 + relapse,
            Intent(this, FocusDetectionService::class.java).apply {
                action = TAKE_BREAK_ACTION
                putExtra(InterventionActivity.EXTRA_LEVEL, level)
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val returnIntent = PendingIntent.getActivity(
            this,
            5000 + relapse,
            packageManager.getLaunchIntentForPackage(this.packageName),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val elapsedNudges = (elapsedMs / NUDGE_REPEAT_INTERVAL_MS).coerceAtLeast(1L)
        val title = if (isRepeat) {
            "⚠️ Still on $appLabel? (${elapsedNudges}m drift)"
        } else {
            "⚠️ Focus check — $appLabel detected (L$level)"
        }
        val content = if (isRepeat) {
            "Your session is active. Tap to reclaim your focus."
        } else {
            "You opened $appLabel during your focus session. Choose an action."
        }
        val notification = NotificationCompat.Builder(this, DISTRACTION_CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(content)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            // Re-alert when updating the same notification ID on each 30 s tick.
            .setOnlyAlertOnce(false)
            .setVibrate(VIBRATION_PATTERN)
            .setAutoCancel(true)
            .setContentIntent(returnIntent)
            .addAction(NotificationCompat.Action.Builder(R.mipmap.ic_launcher, "🎯 Return to Focus", returnIntent).build())
            .addAction(NotificationCompat.Action.Builder(R.mipmap.ic_launcher, "☕ Take a Break", takeBreakIntent).build())
            .setFullScreenIntent(if (level >= 3) fullScreenIntent else null, level >= 3)
            .build()

        // Level 2 is notification-only on modern Android. Record the shown
        // intervention even when the app cannot launch an Activity from the
        // background; Level 3 records its lifecycle from InterventionActivity.
        if (level == 2) {
            sendOrBuffer(
                JSONObject()
                    .put("eventType", "intervention_shown")
                    .put("level", level)
                    .put("timestamp", Instant.now().toString())
                    .toString()
            )
        }

        val manager = getSystemService(NotificationManager::class.java)
        manager.notify(ACTIVE_DISTRACTION_NOTIF_ID, notification)
    }

    private fun clearDistractionNotifications() {
        val manager = getSystemService(NotificationManager::class.java)
        manager.cancel(ACTIVE_DISTRACTION_NOTIF_ID)
        // Remove alerts posted by older app versions.
        manager.cancel(LEGACY_REPEAT_NUDGE_NOTIF_ID)
        releaseDistractionWakeLock()
    }

    private fun acquireDistractionWakeLock() {
        val lock = wakeLock ?: return
        if (lock.isHeld) lock.release()
        lock.acquire(WAKE_LOCK_TIMEOUT_MS)
    }

    private fun releaseDistractionWakeLock() {
        wakeLock?.takeIf { it.isHeld }?.release()
    }

    /** Persist before attempting delivery; Flutter deletes the row after SQLite ack. */
    private fun sendOrBuffer(payload: String) {
        OfflineEventStore(this).use { store -> store.stage(payload) }
        flushPendingEvents()
    }

    private fun flushPendingEvents() {
        flushBufferedEvents(this)
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

            // Existing installs may retain frozen channel settings. A versioned
            // channel gives the new alert configuration a clean OS-owned record.
            manager.deleteNotificationChannel(LEGACY_DISTRACTION_CHANNEL_ID)
            manager.cancel(ACTIVE_DISTRACTION_NOTIF_ID)
            manager.cancel(LEGACY_REPEAT_NUDGE_NOTIF_ID)

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
                setVibrationPattern(VIBRATION_PATTERN)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            }
            manager.createNotificationChannel(alertChannel)
        }
    }

    override fun onDestroy() {
        handler.removeCallbacksAndMessages(null)
        clearDistractionNotifications()
        wakeLock = null
        unregisterScreenReceiver()
        unregisterSimulationReceiver()
        stopForeground(STOP_FOREGROUND_REMOVE)
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    companion object {
        const val START_ACTION = "com.focusecho.ai.START_FOCUS_DETECTION"
        const val STOP_ACTION = "com.focusecho.ai.STOP_FOCUS_DETECTION"
        const val TAKE_BREAK_ACTION = "com.focusecho.ai.TAKE_BREAK"
        /** ADB test fixture — simulation broadcast actions (debug builds only). */
        const val SIMULATE_DISTRACTION_ACTION = "com.focusecho.ai.SIMULATE_DISTRACTION"
        const val SIMULATE_DISTRACTION_DEBUG_ACTION = "com.focusecho.debug.SIMULATE_DISTRACTION"
        private const val CHANNEL_ID = "focus_detection_channel"

        private const val DISTRACTION_CHANNEL_ID = "distraction_alert_channel_v2"
        private const val LEGACY_DISTRACTION_CHANNEL_ID = "distraction_alert_channel"
        private const val ACTIVE_DISTRACTION_NOTIF_ID = 2001
        private const val LEGACY_REPEAT_NUDGE_NOTIF_ID = 2002
        private val VIBRATION_PATTERN = longArrayOf(0L, 350L, 200L, 350L)
        private const val WAKE_LOCK_TIMEOUT_MS = 10 * 60 * 1000L

        /** Poll every 3 seconds instead of 1 to reduce battery drain. */
        private const val POLL_INTERVAL_MS = 3_000L

        /** Refresh cached SharedPreferences values every 5 seconds. */
        private const val CACHE_TTL_MS = 5_000L

        private const val NUDGE_REPEAT_INTERVAL_MS = 30_000L

        /** Well-known always-distracting packages (fallback if prefs unavailable). */
        private val ALWAYS_DISTRACTION_PACKAGES = setOf(
            "com.instagram.android",
            "com.facebook.katana",
            "com.twitter.android",
            "com.zhiliaoapp.musically",
            "com.snapchat.android",
            "com.reddit.frontpage",
        )

        /** Redeliver unacknowledged SQLite-staged records after transient delivery failures. */
        private const val DELIVERY_RETRY_INTERVAL_MS = 10_000L
        private val deliveryAttempts = mutableMapOf<String, Long>()

        fun stageEvent(context: Context, payload: String) {
            OfflineEventStore(context).use { it.stage(payload) }
            flushBufferedEvents(context)
        }

        fun flushBufferedEvents(context: Context) {
            val sink = MainActivity.distractionEventSink ?: return
            OfflineEventStore(context).use { store ->
                val now = System.currentTimeMillis()
                for ((deliveryId, payload) in store.pending()) {
                    val shouldSend = synchronized(deliveryAttempts) {
                        val previous = deliveryAttempts[deliveryId]
                        if (previous != null && now - previous < DELIVERY_RETRY_INTERVAL_MS) false
                        else {
                            deliveryAttempts[deliveryId] = now
                            true
                        }
                    }
                    if (shouldSend) {
                        try {
                            sink.success(payload)
                        } catch (_: Exception) {
                            synchronized(deliveryAttempts) { deliveryAttempts.remove(deliveryId) }
                        }
                    }
                }
            }
        }

        fun acknowledgeBufferedEvent(context: Context, deliveryId: String): Boolean {
            synchronized(deliveryAttempts) { deliveryAttempts.remove(deliveryId) }
            return OfflineEventStore(context).use { it.acknowledge(deliveryId) }
        }
    }

    private fun registerSimulationReceiver() {
        // Debug-builds only — the simulation entry point must never ship in a
        // release APK (it is an exported receiver accepting synthetic events).
        if (applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE == 0) return
        // Hybrid alias: both the established action and the plan's
        // com.focusecho.debug.* namespace resolve to the same receiver.
        val filter = IntentFilter().apply {
            addAction(SIMULATE_DISTRACTION_ACTION)
            addAction(SIMULATE_DISTRACTION_DEBUG_ACTION)
        }
        simulationReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                val packageName = intent?.getStringExtra("package_name")
                    ?: intent?.getStringExtra("packageName")
                    ?: "com.instagram.android"
                val label = intent?.getStringExtra("app_label")
                    ?: intent?.getStringExtra("appLabel")
                    ?: getAppLabel(packageName)

                // Feed into the SAME function real UsageStatsManager polling
                // calls — relapse counter, escalation ladder, notification /
                // full-screen intervention, and EventChannel payload are all
                // exercised for real (no bypass of the production path).
                handleDistractionDetected(packageName, label, source = "adb_fixture")
            }
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(simulationReceiver, filter, Context.RECEIVER_EXPORTED)
        } else {
            registerReceiver(simulationReceiver, filter)
        }
    }

    private fun unregisterSimulationReceiver() {
        simulationReceiver?.let {
            unregisterReceiver(it)
        }
        simulationReceiver = null
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
