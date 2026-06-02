// android/app/src/main/kotlin/com/darshvici/asrio/UsageStatsPlugin.kt
//
// ══════════════════════════════════════════════════════════════════════════════
// ASRIO — Usage Stats Platform Channel (Phase 1 Stub)
// ══════════════════════════════════════════════════════════════════════════════
//
// CURRENT STATUS: Stub. Registration is commented out in MainActivity.
// This file exists now so the channel contract (method names, return types)
// is documented and agreed upon before Phase 5 implementation begins.
//
// FULL IMPLEMENTATION: Phase 5 (Consistency Tab).
//
// ── What this plugin does ──────────────────────────────────────────────────
//
// UsageStatsManager is a private Android API — Flutter has no plugin for it.
// We write a thin Kotlin plugin that responds to MethodChannel calls from Dart.
//
// Dart side (AppUsageService) calls: channel.invokeMethod('getUsageStats', args)
// Kotlin side (this class) queries UsageStatsManager and returns a Map.
//
// ── Why NOT a community plugin? ───────────────────────────────────────────
//
// The few pub.dev packages for usage stats are unmaintained and use deprecated
// UsageStats APIs. Writing our own thin plugin gives us:
//   - Control over exactly which data is returned.
//   - No transitive native dependencies.
//   - Faster build times.
//
// ── Return format (agreed contract for Phase 5) ──────────────────────────
//
//   Method: 'getUsageStats'
//   Args:   { 'startTime': long (epoch ms), 'endTime': long (epoch ms) }
//   Returns: Map<String, Long>  { packageName: totalForegroundTimeMs }
//
//   On permission denied: returns empty map {} (never throws).
//   On Android < 5.0:     returns empty map {} (API not available).
// ══════════════════════════════════════════════════════════════════════════════

package com.darshvici.asrio

import android.content.Context
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

object UsageStatsPlugin {

    /** The channel ID must exactly match AppUsageService._channelName in Dart. */
    private const val CHANNEL_ID = "com.darshvici.asrio/usage_stats"

    /**
     * Registers this plugin on the given [messenger].
     * Called from MainActivity.configureFlutterEngine().
     *
     * Phase 5: Uncomment the handler body below.
     */
    fun register(messenger: BinaryMessenger, context: Context) {
        val channel = MethodChannel(messenger, CHANNEL_ID)

        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "getUsageStats" -> {
                    // Phase 5 implementation:
                    //
                    // val startTime = call.argument<Long>("startTime") ?: 0L
                    // val endTime   = call.argument<Long>("endTime")   ?: System.currentTimeMillis()
                    //
                    // if (!hasUsagePermission(context)) {
                    //     result.success(emptyMap<String, Long>())
                    //     return@setMethodCallHandler
                    // }
                    //
                    // val usm = context.getSystemService(Context.USAGE_STATS_SERVICE)
                    //         as UsageStatsManager
                    //
                    // val stats = usm.queryUsageStats(
                    //     UsageStatsManager.INTERVAL_DAILY, startTime, endTime
                    // )
                    //
                    // val result_map = stats
                    //     .filter { it.totalTimeInForeground > 0 }
                    //     .associate { it.packageName to it.totalTimeInForeground }
                    //
                    // result.success(result_map)

                    // Phase 1: Return empty map until Phase 5.
                    result.success(emptyMap<String, Long>())
                }

                "hasUsagePermission" -> {
                    // Phase 5: Check AppOpsManager.MODE_ALLOWED for USAGE_STATS.
                    // Phase 1: Return false so the UI shows the permission prompt.
                    result.success(false)
                }

                else -> result.notImplemented()
            }
        }
    }

    // Phase 5: Uncomment this helper.
    //
    // private fun hasUsagePermission(context: Context): Boolean {
    //     val appOps = context.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
    //     val mode = appOps.checkOpNoThrow(
    //         AppOpsManager.OPSTR_GET_USAGE_STATS,
    //         android.os.Process.myUid(),
    //         context.packageName
    //     )
    //     return mode == AppOpsManager.MODE_ALLOWED
    // }
}
