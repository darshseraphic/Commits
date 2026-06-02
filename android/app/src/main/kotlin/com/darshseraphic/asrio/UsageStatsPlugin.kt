// android/app/src/main/kotlin/com/darshvici/asrio/UsageStatsPlugin.kt
// Phase 5 — Full implementation

package com.darshvici.asrio

import android.app.AppOpsManager
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.os.Process
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

object UsageStatsPlugin {

    private const val CHANNEL_ID = "com.darshvici.asrio/usage_stats"

    fun register(messenger: BinaryMessenger, context: Context) {
        val channel = MethodChannel(messenger, CHANNEL_ID)

        channel.setMethodCallHandler { call, result ->
            when (call.method) {

                // ── Permission check ──────────────────────────────────────────
                "hasUsagePermission" -> {
                    result.success(hasUsagePermission(context))
                }

                // ── Open usage access settings ────────────────────────────────
                "openUsageAccessSettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
                        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        context.startActivity(intent)
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("SETTINGS_UNAVAILABLE", e.message, null)
                    }
                }

                // ── Get usage stats ───────────────────────────────────────────
                "getUsageStats" -> {
                    if (!hasUsagePermission(context)) {
                        result.success(emptyList<Map<String, Any>>())
                        return@setMethodCallHandler
                    }

                    try {
                        val startTime = call.argument<Long>("startTime") ?: 0L
                        val endTime   = call.argument<Long>("endTime")
                            ?: System.currentTimeMillis()

                        val usm = context.getSystemService(
                            Context.USAGE_STATS_SERVICE
                        ) as UsageStatsManager

                        val stats = usm.queryUsageStats(
                            UsageStatsManager.INTERVAL_DAILY,
                            startTime,
                            endTime
                        )

                        // Resolve app name via PackageManager
                        val pm = context.packageManager

                        val resultList = stats
                            .filter { it.totalTimeInForeground > 0 }
                            .map { stat ->
                                val appName = try {
                                    val info = pm.getApplicationInfo(
                                        stat.packageName, 0
                                    )
                                    pm.getApplicationLabel(info).toString()
                                } catch (e: Exception) {
                                    // App uninstalled — derive readable name
                                    stat.packageName
                                        .split(".")
                                        .last()
                                        .replaceFirstChar { it.uppercase() }
                                }

                                mapOf(
                                    "packageName" to stat.packageName,
                                    "appName"     to appName,
                                    "usageMs"     to stat.totalTimeInForeground
                                )
                            }

                        result.success(resultList)
                    } catch (e: Exception) {
                        result.error(
                            "USAGE_STATS_ERROR",
                            e.message,
                            null
                        )
                    }
                }

                else -> result.notImplemented()
            }
        }
    }

    private fun hasUsagePermission(context: Context): Boolean {
        val appOps = context.getSystemService(
            Context.APP_OPS_SERVICE
        ) as AppOpsManager

        val mode = appOps.checkOpNoThrow(
            AppOpsManager.OPSTR_GET_USAGE_STATS,
            Process.myUid(),
            context.packageName
        )
        return mode == AppOpsManager.MODE_ALLOWED
    }
}
