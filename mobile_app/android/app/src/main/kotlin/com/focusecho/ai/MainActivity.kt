package com.focusecho.ai

import android.content.Context
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        PermissionBridge(this).register(flutterEngine)
        BatteryBridge(this).register(flutterEngine)

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "focus_echo/distraction_stream")
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    distractionEventSink = events
                    // Flush any events buffered while the Flutter UI was away
                    if (events != null) {
                        synchronized(FocusDetectionService.pendingEvents) {
                            for (payload in FocusDetectionService.pendingEvents) {
                                events.success(payload)
                            }
                            FocusDetectionService.pendingEvents.clear()
                        }
                    }
                }

                override fun onCancel(arguments: Any?) {
                    distractionEventSink = null
                }
            })

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "focus_echo/session")
            .setMethodCallHandler { call, result ->
                val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                when (call.method) {
                    "startSession" -> {
                        val intent = Intent(this, FocusDetectionService::class.java).apply {
                            action = FocusDetectionService.START_ACTION
                        }
                        startForegroundService(intent)
                        prefs.edit().putBoolean("flutter.session_active", true).apply()
                        result.success(true)
                    }
                    "stopSession" -> {
                        val intent = Intent(this, FocusDetectionService::class.java).apply {
                            action = FocusDetectionService.STOP_ACTION
                        }
                        stopService(intent)
                        prefs.edit().putBoolean("flutter.session_active", false).apply()
                        result.success(true)
                    }
                    "getSessionStatus" -> result.success(prefs.getBoolean("flutter.session_active", false))
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "focus_echo/firebase_config")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isFirebaseConfigured" -> result.success(isFirebaseConfigured())
                    else -> result.notImplemented()
                }
            }
    }

    private fun isFirebaseConfigured(): Boolean {
        val googleAppIdRes = resources.getIdentifier("google_app_id", "string", packageName)
        val senderIdRes = resources.getIdentifier("gcm_defaultSenderId", "string", packageName)
        val projectIdRes = resources.getIdentifier("project_id", "string", packageName)

        if (googleAppIdRes == 0 || senderIdRes == 0 || projectIdRes == 0) {
            return false
        }

        val googleAppId = getString(googleAppIdRes)
        val senderId = getString(senderIdRes)
        val projectId = getString(projectIdRes)

        return googleAppId.isNotBlank() && senderId.isNotBlank() && projectId.isNotBlank()
    }

    companion object {
        @JvmStatic
        var distractionEventSink: EventChannel.EventSink? = null
    }
}
