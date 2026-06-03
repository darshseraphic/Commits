// lib/core/encryption/encryption_service.dart
//
// ══════════════════════════════════════════════════════════════════════════════
// EncryptionService — AES-256-CBC Diary Encryption
// ══════════════════════════════════════════════════════════════════════════════
//
// DESIGN:
//   Key:       256-bit (32 bytes), generated once on first launch.
//   Algorithm: AES-256-CBC (Cipher Block Chaining).
//   IV:        16 bytes, cryptographically random, unique per encryption call.
//   Storage:   Key stored in flutter_secure_storage → Android Keystore.
//              IV stored alongside ciphertext in the DiaryPages table.
//
// WHY CBC over GCM?
//   AES-GCM is generally preferred for new systems (it provides authentication).
//   However, the 'encrypt' package's GCM support on Android has had stability
//   issues across Flutter versions. CBC with a random IV per entry is secure
//   for this use case (diary content, not network communication) and is
//   universally supported. We can migrate to GCM in a future schema version.
//
// WHY a random IV per entry?
//   Without a unique IV, two pages with identical content would produce
//   identical ciphertext. An attacker with DB access could deduce which diary
//   pages have the same content. A unique IV breaks this pattern entirely.
//
// SINGLETON:
//   EncryptionService is a singleton because key loading is async and
//   expensive (Keystore access). We load the key once and cache it in RAM.
//   The key is never written to any log, print statement, or error message.
// ══════════════════════════════════════════════════════════════════════════════

import 'dart:math';
import 'dart:typed_data';

import 'package:encrypt/encrypt.dart';
import 'package:flutter/foundation.dart' hide Key;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The result of a single encryption operation.
/// Both [ciphertext] and [iv] must be stored together.
/// [iv] is required for decryption and is NOT secret — it can be stored in plain.
@immutable
class EncryptedPayload {
  const EncryptedPayload({required this.ciphertext, required this.iv});

  /// AES-256-CBC ciphertext bytes.
  final Uint8List ciphertext;

  /// 16-byte Initialization Vector. Store alongside ciphertext in the DB.
  final Uint8List iv;
}

class EncryptionService {
  // ── Singleton ─────────────────────────────────────────────────────────────
  EncryptionService._internal();
  static final EncryptionService _instance = EncryptionService._internal();
  factory EncryptionService() => _instance;

  // ── Internal State ────────────────────────────────────────────────────────
  static const _keyStorageKey = 'asrio_aes_key_v1';
  static const _keyLengthBytes = 32; // 256 bits.

  // Cached in RAM after first load. Never written to logs.
  Key? _cachedKey;
  bool _initialized = false;

  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      // Ties the key to the device. Uninstalling the app destroys the key,
      // making the stored diary ciphertext permanently unreadable.
      // This is a feature, not a bug — it prevents forensic recovery.
    ),
  );

  // ── Initialization ────────────────────────────────────────────────────────

  /// Loads (or generates) the AES key from the Android Keystore.
  ///
  /// Must be called before [encrypt] or [decrypt].
  /// Safe to call multiple times — subsequent calls are no-ops.
  Future<void> initialize() async {
    if (_initialized) return;
    _cachedKey = await _loadOrGenerateKey();
    _initialized = true;
    debugPrint('[EncryptionService] ✓ AES-256 key loaded from Keystore.');
  }

  Future<Key> _loadOrGenerateKey() async {
    final stored = await _storage.read(key: _keyStorageKey);

    if (stored != null) {
      // Key already exists — decode from Base64.
      return Key.fromBase64(stored);
    }

    // First launch: generate a new 256-bit key.
    final keyBytes = _secureRandom(_keyLengthBytes);
    final key = Key(keyBytes);

    // Persist to Keystore. This is the only write to secure storage.
    await _storage.write(
      key: _keyStorageKey,
      value: key.base64,
    );

    debugPrint('[EncryptionService] Generated new AES-256 key on first launch.');
    return key;
  }

  // ── Core Operations ───────────────────────────────────────────────────────

  /// Encrypts [plaintext] and returns an [EncryptedPayload].
  ///
  /// A new random 16-byte IV is generated for every call.
  /// The IV must be stored alongside the ciphertext for later decryption.
  ///
  /// Throws [EncryptionException] if the service is not initialized.
  EncryptedPayload encrypt(String plaintext) {
    _assertInitialized();

    // Generate a fresh 16-byte IV for this specific entry.
    final ivBytes = _secureRandom(16);
    final iv = IV(ivBytes);

    final encrypter = Encrypter(AES(_cachedKey!, mode: AESMode.cbc));
    final encrypted = encrypter.encrypt(plaintext, iv: iv);

    return EncryptedPayload(
      ciphertext: encrypted.bytes,
      iv: ivBytes,
    );
  }

  /// Decrypts [ciphertext] using [iv] and returns the original plaintext.
  ///
  /// [iv] must be the exact same bytes that were returned when [ciphertext]
  /// was produced. Using the wrong IV produces garbage output, not an error.
  ///
  /// Throws [EncryptionException] if the service is not initialized.
  /// Throws [EncryptionException] if decryption fails (corrupted data).
  String decrypt(Uint8List ciphertext, Uint8List iv) {
    _assertInitialized();

    try {
      final encrypter = Encrypter(AES(_cachedKey!, mode: AESMode.cbc));
      return encrypter.decrypt(Encrypted(ciphertext), iv: IV(iv));
    } catch (e) {
      throw EncryptionException(
        'Decryption failed. The data may be corrupted or the key has changed.\n'
        'Original error: $e',
      );
    }
  }

  // ── Key Management ────────────────────────────────────────────────────────

  /// Returns true if a key is already stored in the Keystore.
  /// Used during onboarding to detect a returning user.
  Future<bool> hasKey() async {
    final stored = await _storage.read(key: _keyStorageKey);
    return stored != null;
  }

  /// DANGER: Permanently deletes the AES key from the Keystore.
  ///
  /// After this call, ALL encrypted diary content is permanently unreadable.
  /// This should only be called when the user explicitly chooses to
  /// "Erase all data" in Settings. It cannot be undone.
  ///
  /// The caller must also delete all DiaryPages rows from the database
  /// before calling this, to avoid leaving orphaned ciphertext.
  Future<void> destroyKey() async {
    await _storage.delete(key: _keyStorageKey);
    _cachedKey = null;
    _initialized = false;
    debugPrint('[EncryptionService] ⚠ AES key destroyed. Diary data is now unreadable.');
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _assertInitialized() {
    if (!_initialized || _cachedKey == null) {
      throw EncryptionException(
        'EncryptionService.initialize() must be called before encrypt/decrypt.\n'
        'Did you forget to await it in main.dart?',
      );
    }
  }

  /// Generates [length] cryptographically secure random bytes.
  ///
  /// Uses Dart's [Random.secure()] which reads from /dev/urandom on Android.
  /// This is suitable for IV and key generation.
  static Uint8List _secureRandom(int length) {
    final rng = Random.secure();
    return Uint8List.fromList(
      List.generate(length, (_) => rng.nextInt(256)),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Exception Types
// ══════════════════════════════════════════════════════════════════════════════

/// Thrown by [EncryptionService] when encryption or decryption fails.
class EncryptionException implements Exception {
  const EncryptionException(this.message);
  final String message;

  @override
  String toString() => 'EncryptionException: $message';
}
