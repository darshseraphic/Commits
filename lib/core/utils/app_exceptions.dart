// lib/core/utils/app_exceptions.dart
//
// Typed exception hierarchy for ASRIO.
//
// WHY typed exceptions?
// 'catch (e)' where e is dynamic forces every catch site to inspect the
// runtime type to decide how to handle it. Typed exceptions let the provider
// layer catch DatabaseException specifically (showing a DB error message)
// while letting EncryptionException propagate differently (showing a key error).
//
// RULE: Repositories throw these. Providers catch them. Widgets never catch.

/// Base class for all ASRIO application exceptions.
abstract class AsrioException implements Exception {
  const AsrioException(this.message, {this.cause});

  final String message;

  /// The underlying exception that caused this, if any.
  final Object? cause;

  @override
  String toString() => '${runtimeType}: $message'
      '${cause != null ? '\nCaused by: $cause' : ''}';
}

/// Thrown when a Drift database operation fails unexpectedly.
class DatabaseException extends AsrioException {
  const DatabaseException(super.message, {super.cause});
}

/// Thrown when encryption or decryption fails.
/// If this surfaces in the UI, the user's key may be corrupted.
class EncryptionException extends AsrioException {
  const EncryptionException(super.message, {super.cause});
}

/// Thrown when a notification operation fails.
/// Non-fatal — tasks still exist without their reminder.
class NotificationException extends AsrioException {
  const NotificationException(super.message, {super.cause});
}

/// Thrown when a required entity is not found in the database.
class NotFoundException extends AsrioException {
  const NotFoundException(super.message, {super.cause});
}

/// Thrown when input validation fails before a database write.
class ValidationException extends AsrioException {
  const ValidationException(super.message, {super.cause});
}
