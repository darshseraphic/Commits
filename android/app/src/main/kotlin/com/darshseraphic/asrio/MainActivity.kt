// android/app/src/main/kotlin/com/darshvici/asrio/MainActivity.kt
//
// ══════════════════════════════════════════════════════════════════════════════
// ASRIO — Android Entry Point
// ══════════════════════════════════════════════════════════════════════════════
//
// ARCHITECTURE RULE: MainActivity is a thin bootstrap layer.
// It registers platform channels but delegates ALL logic to Plugin classes.
//
// What belongs here:  configureFlutterEngine(), channel registration.
// What does NOT belong: any UsageStats logic, any permission dialogs,
//                        any business logic.
//
// Phase 5 will add UsageStatsPlugin registration here.
// ══════════════════════════════════════════════════════════════════════════════

package com.darshvici.asrio

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ── Platform Channel Registration ──────────────────────────────────
        //
        // Register the UsageStats platform channel.
        // The Dart side (AppUsageService) sends a MethodCall to this channel ID.
        // UsageStatsPlugin.kt handles the call and returns the usage map.
        //
        // Phase 5: Uncomment when UsageStatsPlugin.kt is implemented.
        //
        // UsageStatsPlugin.register(
        //     flutterEngine.dartExecutor.binaryMessenger,
        //     this
        // )
        //
        // ── Future Channels ────────────────────────────────────────────────
        // Add additional platform channels here as new native features are added.
        // Keep each plugin in its own .kt file — do not inline logic here.
    }
}
