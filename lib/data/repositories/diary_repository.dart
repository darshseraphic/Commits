// lib/data/repositories/diary_repository.dart
//
// ══════════════════════════════════════════════════════════════════════════════
// DiaryRepository — Encrypt/Decrypt Coordinator
// ══════════════════════════════════════════════════════════════════════════════
//
// SECURITY INVARIANT enforced by this class:
//   - Plaintext ENTERS this class from the provider layer (on save).
//   - Plaintext EXITS this class to the provider layer (on read).
//   - Ciphertext only ever exists between this class and the DAO.
//   - The DAO never sees plaintext. The provider never sees ciphertext.
//
// AUTO-SAVE DESIGN:
//   The DiaryScreen auto-saves every N seconds using a debounce timer.
//   This repository's savePage() uses an upsert (insert-or-update), so
//   calling it repeatedly with the same (date, pageNumber) is safe — it
//   updates the existing row rather than creating duplicates.
// ══════════════════════════════════════════════════════════════════════════════


import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import '../../core/encryption/encryption_service.dart';
// Use EncryptionService's own exception.
import '../../core/utils/app_exceptions.dart' as ex;
import '../database/app_database.dart';
import '../database/daos/diary_dao.dart';
import '../models/diary_entry_model.dart';

class DiaryRepository {
  const DiaryRepository({
    required DiaryDao diaryDao,
    required EncryptionService encryptionService,
  })  : _dao = diaryDao,
        _encryption = encryptionService;

  final DiaryDao _dao;
  final EncryptionService _encryption;

  // ── Streams ───────────────────────────────────────────────────────────────

  /// Streams all decrypted pages for [date], ordered by page number.
  ///
  /// Decryption runs on every stream emission. If the Encryption key has
  /// changed (impossible under normal operation but theoretically possible
  /// after a key rotation), this stream will emit an error.
  ///
  /// The provider layer uses AsyncValue to surface decryption errors to the UI.
  Stream<List<DiaryEntryModel>> watchPagesForDate(DateTime date) {
    return _dao.watchPagesForDate(date).map((encryptedPages) {
      return encryptedPages.map(_decryptPage).toList();
    });
  }

  /// Streams a map of {dateOnly → hasEntry} for calendar shading.
  /// No decryption needed — we only need to know IF a page exists, not its content.
  Stream<Map<DateTime, bool>> watchActiveDiaryDates({int days = 365}) =>
      _dao.watchActiveDiaryDates(days: days);

  // ── One-shot Reads ────────────────────────────────────────────────────────

  /// Returns all decrypted pages for [date].
  ///
  /// If the date has no pages, returns a list with one blank page.
  /// This ensures the diary screen always has at least one page to show.
  Future<List<DiaryEntryModel>> getPagesForDate(DateTime date) async {
    try {
      final encryptedPages = await _dao.getPagesForDate(date);

      if (encryptedPages.isEmpty) {
        return [DiaryEntryModel.blank(date: date, pageNumber: 1)];
      }

      return encryptedPages.map(_decryptPage).toList();
    } on ex.EncryptionException {
      rethrow;
    } catch (e) {
      throw ex.DatabaseException(
        'Failed to load diary pages for ${date.toIso8601String()}.',
        cause: e,
      );
    }
  }

  // ── Writes ────────────────────────────────────────────────────════════════

  /// Encrypts [content] and saves (or updates) a diary page.
  ///
  /// This is an UPSERT: if a page for (date, pageNumber) already exists,
  /// it is updated. This makes auto-save safe to call repeatedly.
  ///
  /// Returns the saved [DiaryEntryModel] with its assigned database ID.
  Future<DiaryEntryModel> savePage({
    required DateTime date,
    required int pageNumber,
    required String content,
    int? existingId,
  }) async {
    if (content.isEmpty) {
      throw const ex.ValidationException(
          'Cannot save an empty diary page.');
    }

    // ── Encrypt ─────────────────────────────────────────────────────────────
    final EncryptedPayload payload;
    try {
      payload = _encryption.encrypt(content);
    } catch (e) {
      throw ex.EncryptionException(
          'Failed to encrypt diary content.', cause: e);
    }

    // ── Upsert ──────────────────────────────────────────────────────────────
    final int savedId;
    try {
      savedId = await _dao.upsertPage(
        DiaryPagesCompanion.insert(
          encryptedContent: payload.ciphertext,
          iv: payload.iv,
          pageNumber: pageNumber,
          entryDate: DateTime(date.year, date.month, date.day),
          updatedAt: Value(DateTime.now()),
        ),
      );
    } catch (e) {
      throw ex.DatabaseException('Failed to save diary page.', cause: e);
    }

    return DiaryEntryModel(
      id: savedId,
      entryDate: date,
      pageNumber: pageNumber,
      content: content, // Return the plaintext — the UI already has it.
      updatedAt: DateTime.now(),
    );
  }

  // ── Deletes ───────────────────────────────────────────────────────────────

  /// Deletes a single diary page.
  Future<void> deletePage(int pageId) async {
    try {
      await _dao.deletePage(pageId);
    } catch (e) {
      throw ex.DatabaseException(
          'Failed to delete diary page $pageId.', cause: e);
    }
  }

  /// Deletes ALL pages for a date (the user removes an entire diary entry).
  Future<void> deleteEntryForDate(DateTime date) async {
    try {
      await _dao.deleteAllPagesForDate(date);
    } catch (e) {
      throw ex.DatabaseException(
          'Failed to delete diary entry for $date.', cause: e);
    }
  }

  // ── Active Date Query ─────────────────────────────────────────────────────

  Future<List<DateTime>> getActiveDiaryDates() => _dao.getActiveDiaryDates();

  // ── Private: Decrypt a single Drift row → DiaryEntryModel ─────────────────

  DiaryEntryModel _decryptPage(DiaryPage row) {
    try {
      final plaintext = _encryption.decrypt(
        Uint8List.fromList(row.encryptedContent),
        Uint8List.fromList(row.iv),
      );
      return DiaryEntryModel(
        id: row.id,
        entryDate: row.entryDate,
        pageNumber: row.pageNumber,
        content: plaintext,
        updatedAt: row.updatedAt,
      );
    } catch (e) {
      debugPrint('[DiaryRepository] ⚠ Decryption failed for page ${row.id}: $e');
      // Return a model that signals decryption failure. The UI shows an error
      // state rather than crashing the entire diary screen.
      return DiaryEntryModel(
        id: row.id,
        entryDate: row.entryDate,
        pageNumber: row.pageNumber,
        content: '[{"insert":"⚠ Could not decrypt this page.\\n"}]',
        updatedAt: row.updatedAt,
      );
    }
  }
}
