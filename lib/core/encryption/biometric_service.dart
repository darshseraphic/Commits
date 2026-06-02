// lib/core/services/biometric_service.dart
//
// ══════════════════════════════════════════════════════════════════════════════
// BiometricService — Diary Lock via local_auth
// ══════════════════════════════════════════════════════════════════════════════
//
// DESIGN CONTRACT:
//   - This service NEVER crashes the app. All failure modes return false.
//   - It checks the diaryLockEnabled flag before touching local_auth.
//     If the toggle is off, authenticate() returns true immediately.
//   - If the device has no enrolled biometrics, canUseBiometrics() returns
//     false and the settings toggle will refuse to be turned on.
//
// THREE TRIGGER POINTS (all route through authenticate()):
//   1. User taps a diary entry (if lock is ON)
//   2. App returns from background while diary editor was open
//   3. App relaunches and diary was the last screen
//
// SINGLETON: same pattern as EncryptionService and NotificationService.
// ══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth/error_codes.dart' as auth_error;

/// Result of a biometric authentication attempt.
enum BiometricResult {
  /// Authentication succeeded — allow access.
  success,

  /// User cancelled the prompt — do NOT allow access, do NOT show error.
  cancelled,

  /// Authentication failed (wrong fingerprint, etc.) — show retry prompt.
  failed,

  /// Biometrics are not available or not enrolled on this device.
  unavailable,

  /// Diary lock is disabled in settings — access is freely allowed.
  lockDisabled,
}

class BiometricService {
  // ── Singleton ─────────────────────────────────────────────────────────────
  BiometricService._internal();
  static final BiometricService _instance = BiometricService._internal();
  factory BiometricService() => _instance;

  final LocalAuthentication _auth = LocalAuthentication();

  // ── Capability Check ──────────────────────────────────────────────────────

  /// Returns true if this device can perform biometric authentication.
  ///
  /// Checks both hardware support AND whether biometrics are enrolled.
  /// Called by the Settings toggle before allowing it to be turned on.
  /// If this returns false, show the user a clear explanation and revert the toggle.
  Future<bool> canUseBiometrics() async {
    try {
      final isAvailable = await _auth.canCheckBiometrics;
      final isDeviceSupported = await _auth.isDeviceSupported();

      if (!isAvailable || !isDeviceSupported) return false;

      // Check if any biometrics are actually enrolled.
      final enrolled = await _auth.getAvailableBiometrics();
      return enrolled.isNotEmpty;
    } catch (e) {
      debugPrint('[BiometricService] canUseBiometrics check failed: $e');
      return false;
    }
  }

  /// Returns a human-readable description of the available biometric type.
  /// Used in the Settings tile subtitle (e.g., "Fingerprint", "Face ID").
  Future<String> getBiometricTypeLabel() async {
    try {
      final types = await _auth.getAvailableBiometrics();
      if (types.contains(BiometricType.face)) return 'Face ID';
      if (types.contains(BiometricType.fingerprint)) return 'Fingerprint';
      if (types.contains(BiometricType.iris)) return 'Iris';
      return 'Biometric';
    } catch (_) {
      return 'Biometric';
    }
  }

  // ── Authentication ────────────────────────────────────────────────────────

  /// Attempts biometric authentication and returns a [BiometricResult].
  ///
  /// [lockEnabled] — pass the current value of diaryLockEnabledProvider.
  ///                 If false, returns [BiometricResult.lockDisabled] immediately.
  ///
  /// [reason] — shown inside the system biometric dialog.
  Future<BiometricResult> authenticate({
    required bool lockEnabled,
    String reason = 'Authenticate to access your diary.',
  }) async {
    // Fast path: lock is off, no auth needed.
    if (!lockEnabled) return BiometricResult.lockDisabled;

    try {
      final authenticated = await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          // biometricOnly: false allows PIN/pattern fallback if
          // biometric fails or the user chooses it.
          biometricOnly: false,
          stickyAuth: true, // Keeps the dialog alive if app loses focus briefly.
          sensitiveTransaction: true, // Signals to the OS this is high-security.
        ),
      );

      return authenticated ? BiometricResult.success : BiometricResult.failed;
    } on PlatformException catch (e) {
      debugPrint('[BiometricService] PlatformException: ${e.code} — ${e.message}');

      return switch (e.code) {
        auth_error.notAvailable    => BiometricResult.unavailable,
        auth_error.notEnrolled     => BiometricResult.unavailable,
        auth_error.lockedOut       => BiometricResult.failed,
        auth_error.permanentlyLockedOut => BiometricResult.unavailable,
        auth_error.passcodeNotSet  => BiometricResult.unavailable,
        _ => BiometricResult.cancelled,
      };
    } catch (e) {
      debugPrint('[BiometricService] Unexpected error: $e');
      return BiometricResult.failed;
    }
  }

  // ── Convenience ───────────────────────────────────────────────────────────

  /// Returns true only on [BiometricResult.success] or [BiometricResult.lockDisabled].
  /// Use this as a simple gate: `if (await biometricService.isAllowed(...)) { ... }`
  Future<bool> isAllowed({required bool lockEnabled}) async {
    final result = await authenticate(lockEnabled: lockEnabled);
    return result == BiometricResult.success ||
        result == BiometricResult.lockDisabled;
  }
}
