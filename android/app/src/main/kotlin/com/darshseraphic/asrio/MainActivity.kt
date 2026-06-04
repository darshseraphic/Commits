package com.darshvici.asrio

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugins.GeneratedPluginRegistrant

class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        // Automatically registers standard Flutter community plugins safely using v2 Embedding (Drift, Secure Storage, etc.)
        GeneratedPluginRegistrant.registerWith(flutterEngine)

        // Custom cross-platform bridge registration for tracking hardware application runtime milestones
        UsageStatsPlugin.register(
            flutterEngine.dartExecutor.binaryMessenger,
            this
        )
    }
}