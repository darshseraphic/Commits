// lib/main.dart — Phase 6 (timezone init added)


import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/encryption/encryption_service.dart';
import 'data/services/notification_scheduler.dart';
import 'data/database/app_database.dart';
import 'data/services/notification_service.dart';
import 'providers/database_provider.dart';

Future<void> main() async {
  // ── Step 1: Bind Flutter engine ──────────────────────────────────────────
  WidgetsFlutterBinding.ensureInitialized();

  // ── Step 2: Error handlers ───────────────────────────────────────────────
  _setupErrorHandlers();

  // ── Step 3: Initialize timezone database ─────────────────────────────────
  // Required for flutter_local_notifications zonedSchedule().
  // In-memory operation (~5ms). Must run before NotificationScheduler.
  NotificationScheduler().initializeTimezones();

  // ── Step 4: Initialize Drift database ────────────────────────────────────
  final appDatabase = AppDatabase();
  unawaited(appDatabase.logAppOpen());

  // ── Step 5: Initialize AES-256 encryption key ────────────────────────────
  final encryptionService = EncryptionService();
  await encryptionService.initialize();

  // ── Step 6: Initialize notification channels ─────────────────────────────
  final notificationService = NotificationService();
  await notificationService.initialize();

  // ── Step 7: Run app ───────────────────────────────────────────────────────
  runApp(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(appDatabase),
      ],
      child: const AsrioApp(),
    ),
  );
}

void _setupErrorHandlers() {
  FlutterError.onError = (FlutterErrorDetails details) {
    if (kDebugMode) {
      FlutterError.dumpErrorToConsole(details);
      return;
    }
    debugPrint('[ASRIO] Widget error: ${details.exceptionAsString()}\n${details.stack}');
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    debugPrint('[ASRIO] Async error: $error');
    return true;
  };
}

void unawaited(Future<void> future) {}
