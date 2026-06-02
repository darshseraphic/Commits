// lib/data/database/daos/diary_dao.dart
//
// ══════════════════════════════════════════════════════════════════════════════
// DiaryDao — Data Access Object
// ══════════════════════════════════════════════════════════════════════════════
//
// SECURITY RULE: This DAO only sees ciphertext. It never touches plaintext.
// All rows it reads go to DiaryRepository for decryption.
// All rows it writes have already been encrypted by DiaryRepository.
//
// The DAO is completely unaware that encryption exists. This is intentional:
// it means the DAO can be tested with dummy bytes, and the encryption logic
// can be tested without a database.
// ══════════════════════════════════════════════════════════════════════════════

import 'package:drift/drift.dart';

import '../app_database.dart';

part 'diary_dao.g.dart';

@DriftAccessor(tables: [DiaryPages])
class DiaryDao extends DatabaseAccessor<AppDatabase> with _$DiaryDaoMixin {
  DiaryDao(super.db);

  // ── Streams ───────────────────────────────────────────────────────────────

  /// Streams all pages for [date], ordered by page number.
  ///
  /// Emits a new list whenever any page for this date is inserted or updated.
  /// DiaryRepository subscribes to this and decrypts on each emission.
  Stream<List<DiaryPage>> watchPagesForDate(DateTime date) {
    final dayStart = DateTime(date.year, date.month, date.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    return (select(diaryPages)
          ..where((p) =>
              p.entryDate.isBiggerOrEqualValue(dayStart) &
              p.entryDate.isSmallerThanValue(dayEnd))
          ..orderBy([(p) => OrderingTerm.asc(p.pageNumber)]))
        .watch();
  }

  /// Streams the count of diary entries per date for the past [days] days.
  /// Used to populate the calendar shading on the Consistency tab.
  Stream<Map<DateTime, bool>> watchActiveDiaryDates({int days = 365}) {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    return (select(diaryPages)
          ..where((p) => p.entryDate.isBiggerOrEqualValue(cutoff)))
        .watch()
        .map((pages) {
      final Map<DateTime, bool> result = {};
      for (final page in pages) {
        final d = page.entryDate;
        result[DateTime(d.year, d.month, d.day)] = true;
      }
      return result;
    });
  }

  // ── One-shot Reads ────────────────────────────────────────────────────────

  /// Fetches a single encrypted page by its primary key.
  Future<DiaryPage?> findById(int id) =>
      (select(diaryPages)..where((p) => p.id.equals(id))).getSingleOrNull();

  /// Fetches all pages for [date] as a one-shot read (not a stream).
  /// Used during encryption key rotation (Phase 3 stretch goal).
  Future<List<DiaryPage>> getPagesForDate(DateTime date) {
    final dayStart = DateTime(date.year, date.month, date.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    return (select(diaryPages)
          ..where((p) =>
              p.entryDate.isBiggerOrEqualValue(dayStart) &
              p.entryDate.isSmallerThanValue(dayEnd))
          ..orderBy([(p) => OrderingTerm.asc(p.pageNumber)]))
        .get();
  }

  /// Returns all unique dates that have at least one diary page.
  /// Used by the streak calculation algorithm.
  Future<List<DateTime>> getActiveDiaryDates() async {
    final result = await customSelect(
      '''
      SELECT DISTINCT DATE(entry_date / 1000, 'unixepoch') AS active_date
      FROM diary_pages
      ORDER BY active_date ASC
      ''',
      readsFrom: {diaryPages},
    ).get();

    return result.map((row) {
      return DateTime.parse(row.read<String>('active_date'));
    }).toList();
  }

  // ── Writes ────────────────────────────────────────────────────────────────

  /// Inserts a new page or replaces an existing one (upsert).
  ///
  /// The UNIQUE constraint on (entryDate, pageNumber) means Drift will update
  /// the existing row when the same page is saved a second time.
  /// This is the correct behavior for auto-saving diary content.
  Future<int> upsertPage(DiaryPagesCompanion companion) =>
      into(diaryPages).insertOnConflictUpdate(companion);

  /// Deletes a single page by its primary key.
  Future<int> deletePage(int pageId) =>
      (delete(diaryPages)..where((p) => p.id.equals(pageId))).go();

  /// Deletes all pages for a given date (the user deletes an entire diary entry).
  Future<int> deleteAllPagesForDate(DateTime date) {
    final dayStart = DateTime(date.year, date.month, date.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    return (delete(diaryPages)
          ..where((p) =>
              p.entryDate.isBiggerOrEqualValue(dayStart) &
              p.entryDate.isSmallerThanValue(dayEnd)))
        .go();
  }
}
