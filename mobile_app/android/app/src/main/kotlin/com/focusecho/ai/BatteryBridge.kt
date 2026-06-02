package com.focusecho.ai

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class BatteryBridge(private val context: Context) {
    fun register(engine: FlutterEngine) {
        MethodChannel(engine.dartExecutor.binaryMessenger, "focus_echo/battery")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "requestIgnoreOptimization" -> {
                        result.success(requestIgnoreOptimization())
                    }
                    "isIgnoringBatteryOptimizations" -> {
                        val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
                        val allowed = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            pm.isIgnoringBatteryOptimizations(context.packageName)
                        } else true
                        result.success(allowed)
                    }
                    "getDeviceManufacturer" -> result.success(Build.MANUFACTURER.lowercase())
                    "openManufacturerBatterySettings" -> {
                        result.success(openManufacturerSettings(Build.MANUFACTURER.lowercase()))
                    }
                    "runBatteryOptimizationFlow" -> {
                        result.success(runBatteryOptimizationFlow())
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun requestIgnoreOptimization(): Boolean {
        val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
            data = Uri.parse("package:${context.packageName}")
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        if (!canResolve(intent)) return false
        context.startActivity(intent)
        return true
    }

    private fun runBatteryOptimizationFlow(): Map<String, Any> {
        val manufacturer = Build.MANUFACTURER.lowercase()
        val openedRequest = requestIgnoreOptimization()
        val openedManufacturer = if (!openedRequest) openManufacturerSettings(manufacturer) else false
        val openedFallback = if (!openedRequest && !openedManufacturer) openBatterySaverSettings() else false
        return mapOf(
            "manufacturer" to manufacturer,
            "openedRequest" to openedRequest,
            "openedManufacturer" to openedManufacturer,
            "openedFallback" to openedFallback
        )
    }

    private fun openManufacturerSettings(manufacturer: String): Boolean {
        val intent = when (manufacturer) {
            "xiaomi" -> Intent().setComponent(
                ComponentName("com.miui.powerkeeper", "com.miui.powerkeeper.ui.HiddenAppsConfigActivity")
            )
            "samsung" -> Intent().setComponent(
                ComponentName("com.samsung.android.lool", "com.samsung.android.sm.ui.battery.BatteryActivity")
            )
            "oneplus" -> Intent().setComponent(
                ComponentName("com.oneplus.opti", "com.oneplus.opti.activities.OptimizeActivity")
            )
            else -> Intent(Settings.ACTION_BATTERY_SAVER_SETTINGS)
        }.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)

        if (!canResolve(intent)) {
            return false
        }
        context.startActivity(intent)
        return true
    }

    private fun openBatterySaverSettings(): Boolean {
        val intent = Intent(Settings.ACTION_BATTERY_SAVER_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        if (!canResolve(intent)) {
            return false
        }
        context.startActivity(intent)
        return true
    }

    private fun canResolve(intent: Intent): Boolean {
        return intent.resolveActivity(context.packageManager) != null ||
            context.packageManager.queryIntentActivities(intent, PackageManager.MATCH_DEFAULT_ONLY).isNotEmpty()
    }
}
