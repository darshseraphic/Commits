// lib/providers/repository_providers.dart
//
// ══════════════════════════════════════════════════════════════════════════════
// Repository Providers — single source of truth for all service/repo DI
// ══════════════════════════════════════════════════════════════════════════════

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/encryption/encryption_service.dart';
import '../data/repositories/consistency_repository.dart';
import '../data/repositories/diary_repository.dart';
import '../data/repositories/habit_repository.dart';
import '../data/repositories/mood_repository.dart';
import '../data/repositories/task_repository.dart';
import '../data/services/app_usage_service.dart';
import '../data/services/notification_service.dart';
import 'database_provider.dart';

// ── Service Providers ─────────────────────────────────────────────────────────

final encryptionServiceProvider = Provider<EncryptionService>(
  (ref) => EncryptionService(),
  name: 'encryptionServiceProvider',
);

final notificationServiceProvider = Provider<NotificationService>(
  (ref) => NotificationService(),
  name: 'notificationServiceProvider',
);

final appUsageServiceProvider = Provider<AppUsageService>(
  (ref) => AppUsageService(),
  name: 'appUsageServiceProvider',
);

// ── Repository Providers ──────────────────────────────────────────────────────

final taskRepositoryProvider = Provider<TaskRepository>(
  (ref) => TaskRepository(
    tasksDao: ref.watch(databaseProvider).tasksDao,
    notificationService: ref.watch(notificationServiceProvider),
  ),
  name: 'taskRepositoryProvider',
);

final diaryRepositoryProvider = Provider<DiaryRepository>(
  (ref) => DiaryRepository(
    diaryDao: ref.watch(databaseProvider).diaryDao,
    encryptionService: ref.watch(encryptionServiceProvider),
  ),
  name: 'diaryRepositoryProvider',
);

final habitRepositoryProvider = Provider<HabitRepository>(
  (ref) => HabitRepository(
    habitsDao: ref.watch(databaseProvider).habitsDao,
  ),
  name: 'habitRepositoryProvider',
);

final moodRepositoryProvider = Provider<MoodRepository>(
  (ref) => MoodRepository(
    moodDao: ref.watch(databaseProvider).moodDao,
  ),
  name: 'moodRepositoryProvider',
);

final consistencyRepositoryProvider = Provider<ConsistencyRepository>(
  (ref) {
    final db = ref.watch(databaseProvider);
    return ConsistencyRepository(
      tasksDao:    db.tasksDao,
      diaryDao:    db.diaryDao,
      activityDao: db.activityDao,
    );
  },
  name: 'consistencyRepositoryProvider',
);
