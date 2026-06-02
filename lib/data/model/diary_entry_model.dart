// lib/data/models/diary_entry_model.dart
//
// ══════════════════════════════════════════════════════════════════════════════
// DiaryEntryModel — Domain Model
// ══════════════════════════════════════════════════════════════════════════════
//
// SECURITY CONTRACT:
//   This model holds ONLY plaintext content. It is created by DiaryRepository
//   AFTER decryption. Ciphertext never appears in this class.
//
//   The lifecycle is:
//     DB (ciphertext) → DiaryRepository.decrypt() → DiaryEntryModel (plaintext)
//     DiaryEntryModel (plaintext) → DiaryRepository.encrypt() → DB (ciphertext)
//
//   If you find yourself storing a Uint8List (encrypted bytes) in this class,
//   the architecture has been violated.
//
// PAGE MODEL:
//   A single diary entry date can have multiple pages (pageNumber 1, 2, 3...).
//   DiaryEntryModel represents ONE page. DiaryRepository returns a
//   List<DiaryEntryModel> for a given date (one per page).
// ══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/foundation.dart';

/// A single decrypted diary page, safe to pass to the widget layer.
///
/// [content] is a QuillDelta JSON string — the rich text format used by
/// flutter_quill. It is decoded by QuillController in the DiaryScreen widget.
@immutable
class DiaryEntryModel {
  const DiaryEntryModel({
    required this.id,
    required this.entryDate,
    required this.pageNumber,
    required this.content,
    required this.updatedAt,
  });

  /// Database primary key. Used to update the correct row on save.
  final int id;

  /// The calendar date this page belongs to (time component is ignored).
  final DateTime entryDate;

  /// Which page within this date's diary session. First page = 1.
  final int pageNumber;

  /// Decrypted QuillDelta JSON string.
  /// Example: '[{"insert":"Hello world\\n"}]'
  ///
  /// INVARIANT: This field is ALWAYS plaintext. It is decrypted before
  /// this model is constructed and encrypted before it is persisted.
  final String content;

  final DateTime updatedAt;

  // ── Derived Properties ────────────────────────────────────────────────────

  /// True if this page has never been saved (id == -1 is the sentinel for new).
  bool get isNew => id == -1;

  /// True if the content is the empty QuillDelta (a single newline insert).
  /// Used to avoid saving empty pages.
  bool get isEmpty => content == '[{"insert":"\\n"}]' || content.isEmpty;

  /// A date-only DateTime for use as a Map key in the consistency calendar.
  /// Strips the time component to allow reliable equality comparison.
  DateTime get dateOnly => DateTime(entryDate.year, entryDate.month, entryDate.day);

  // ── Factory Constructors ──────────────────────────────────────────────────

  /// Creates a blank new page for [date] with [pageNumber].
  /// Uses id = -1 as the sentinel for "not yet persisted".
  factory DiaryEntryModel.blank({
    required DateTime date,
    required int pageNumber,
  }) {
    return DiaryEntryModel(
      id: -1,
      entryDate: date,
      pageNumber: pageNumber,
      content: '[{"insert":"\\n"}]', // QuillDelta empty document.
      updatedAt: DateTime.now(),
    );
  }

  // ── Mutation ──────────────────────────────────────────────────────────────

  DiaryEntryModel copyWith({
    int? id,
    DateTime? entryDate,
    int? pageNumber,
    String? content,
    DateTime? updatedAt,
  }) {
    return DiaryEntryModel(
      id: id ?? this.id,
      entryDate: entryDate ?? this.entryDate,
      pageNumber: pageNumber ?? this.pageNumber,
      content: content ?? this.content,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // ── Equality ──────────────────────────────────────────────────────────────

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiaryEntryModel &&
          id == other.id &&
          pageNumber == other.pageNumber &&
          content == other.content;

  @override
  int get hashCode => Object.hash(id, pageNumber, content);

  @override
  String toString() =>
      'DiaryEntryModel(id: $id, date: ${entryDate.toIso8601String().split("T")[0]}, '
      'page: $pageNumber, isEmpty: $isEmpty)';
}
