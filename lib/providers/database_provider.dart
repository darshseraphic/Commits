// lib/providers/database_provider.dart
//
// The single source of truth for the AppDatabase singleton in the Riverpod graph.
//
// DESIGN DECISION — Why throw instead of creating the DB here?
//
// We deliberately throw in the fallback because AppDatabase must be created
// in main.dart where we can also call logAppOpen() and manage its lifecycle
// cleanly. If we created it inside the provider, we'd have no way to call
// cleanup code when the process exits, and we'd risk creating two DB connections
// on a hot restart during development.
//
// The ProviderScope.override in main.dart replaces this throw with the real
// instance before any widget renders. If you ever see this error at runtime,
// it means the override was forgotten in a test or a new entry point.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database/app_database.dart';

/// Provides the [AppDatabase] singleton to the entire Riverpod tree.
///
/// Never construct [AppDatabase] directly inside a widget or provider —
/// always consume it through this provider to guarantee a single connection.
final databaseProvider = Provider<AppDatabase>(
  (ref) => throw UnimplementedError(
    'databaseProvider has no value.\n'
    'Did you forget the ProviderScope.overrides in main.dart?\n'
    'Expected: databaseProvider.overrideWithValue(AppDatabase())',
  ),
  // Name shows in Riverpod DevTools for easier debugging.
  name: 'databaseProvider',
);
