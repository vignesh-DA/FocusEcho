package com.focusecho.ai

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.content.Context
import android.view.accessibility.AccessibilityEvent
import org.json.JSONObject
import java.time.Instant

/**
 * Detects foreground app switches via Accessibility events and posts
 * distraction payloads to [DistractionEventQueue].
 *
 * Previous implementation used MethodChannel which was null when the Flutter
 * UI was destroyed (app killed / backgrounded), silently dropping all events.
 * The shared queue approach works regardless of Flutter lifecycle state.
 */
class FocusAccessibilityService : AccessibilityService() {

    private var lastSwitchTimeMs = 0L



    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return
        if (
            event.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED &&
            event.eventType != AccessibilityEvent.TYPE_NOTIFICATION_STATE_CHANGED
        ) return

        if (event.eventType == AccessibilityEvent.TYPE_NOTIFICATION_STATE_CHANGED) {
            val packageName = event.packageName?.toString() ?: return
            val payload = JSONObject()
                .put("eventType", "notification")
                .put("packageName", packageName)
                .put("timestamp", Instant.now().toString())
                .toString()
            DistractionEventQueue.add(payload)
            return
        }

        val now = System.currentTimeMillis()
        if (now - lastSwitchTimeMs < 500) return
        lastSwitchTimeMs = now

        val packageName = event.packageName?.toString() ?: return

        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)

        // Only process during active sessions
        val sessionActive = prefs.getBoolean("flutter.session_active", false)
        if (!sessionActive) return

        val label = getAppLabel(packageName)
        val payload = JSONObject()
            .put("eventType", "app_switch")
            .put("packageName", packageName)
            .put("appLabel", label)
            .put("timestamp", Instant.now().toString())
            .put("source", "accessibility")
            .toString()
        DistractionEventQueue.add(payload)
    }

    private fun getAppLabel(packageName: String): String {
        return try {
            val info = packageManager.getApplicationInfo(packageName, 0)
            packageManager.getApplicationLabel(info).toString()
        } catch (_: Exception) {
            packageName
        }
    }

    override fun onServiceConnected() {
        val info = AccessibilityServiceInfo().apply {
            eventTypes =
                AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED or
                AccessibilityEvent.TYPE_NOTIFICATION_STATE_CHANGED
            feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
            notificationTimeout = 100
        }
        serviceInfo = info
    }

    override fun onInterrupt() = Unit
}
