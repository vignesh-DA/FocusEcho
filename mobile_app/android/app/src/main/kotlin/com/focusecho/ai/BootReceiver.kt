package com.focusecho.ai

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action != Intent.ACTION_BOOT_COMPLETED) return
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val isActive = prefs.getBoolean("flutter.session_active", false)
        if (isActive) {
            val serviceIntent = Intent(context, FocusDetectionService::class.java).apply {
                action = FocusDetectionService.START_ACTION
            }
            context.startForegroundService(serviceIntent)
        }
        val count = prefs.getInt("flutter.boot_restart_count", 0) + 1
        prefs.edit().putInt("flutter.boot_restart_count", count).apply()
    }
}
