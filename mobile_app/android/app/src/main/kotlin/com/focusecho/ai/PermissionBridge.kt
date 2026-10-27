package com.focusecho.ai

import android.app.Activity
import android.app.AppOpsManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import android.content.pm.PackageManager
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationManagerCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Flutter ↔ native bridge for permission checks and settings deep-links.
 *
 * Permissions checked:
 *   - Usage Access (PACKAGE_USAGE_STATS) — required for detection.
 *   - Battery optimisation exemption    — required for background reliability.
 *
 * Accessibility service has been removed (decision 2026-10-03 — single
 * detection path via UsageStats).  The [checkAccessibility] method has been
 * deleted; the wizard view-model always reports true for that flag.
 */
class PermissionBridge(private val activity: Activity) {
    private val context: Context get() = activity

    fun register(engine: FlutterEngine) {
        MethodChannel(engine.dartExecutor.binaryMessenger, "focus_echo/permissions")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "checkUsageAccess" -> result.success(checkUsageAccess())
                    "openUsageSettings" -> {
                        context.startActivity(
                            Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
                                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        )
                        result.success(true)
                    }
                    "isIgnoringBatteryOptimizations" -> result.success(isIgnoringBatteryOptimizations())
                    "checkNotificationPermission" -> result.success(checkNotificationPermission())
                    "openNotificationSettings" -> {
                        openNotificationSettings()
                        result.success(true)
                    }
                    "requestNotificationPermission" -> {
                        requestNotificationPermission()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun checkUsageAccess(): Boolean {
        val appOps = context.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = appOps.checkOpNoThrow(
            AppOpsManager.OPSTR_GET_USAGE_STATS,
            android.os.Process.myUid(),
            context.packageName
        )
        return mode == AppOpsManager.MODE_ALLOWED
    }

    private fun isIgnoringBatteryOptimizations(): Boolean {
        val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            pm.isIgnoringBatteryOptimizations(context.packageName)
        } else true
    }

    private fun checkNotificationPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context.checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) ==
                PackageManager.PERMISSION_GRANTED
        } else {
            NotificationManagerCompat.from(context).areNotificationsEnabled()
        }
    }

    private fun requestNotificationPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (!checkNotificationPermission()) {
                ActivityCompat.requestPermissions(
                    activity,
                    arrayOf(android.Manifest.permission.POST_NOTIFICATIONS),
                    NOTIFICATION_PERMISSION_REQUEST_CODE,
                )
            }
        } else if (!checkNotificationPermission()) {
            openNotificationSettings()
        }
    }

    private fun openNotificationSettings() {
        activity.startActivity(
            Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                .putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName),
        )
    }

    private companion object {
        const val NOTIFICATION_PERMISSION_REQUEST_CODE = 101
    }
}
