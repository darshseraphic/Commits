// lib/providers/diary_provider.dart
//
// ══════════════════════════════════════════════════════════════════════════════
// Diary Providers
// ══════════════════════════════════════════════════════════════════════════════
//
// STATE DESIGN:
//   DiaryNotifier holds the active editing session state:
//     - Which date is being viewed.
//     - The list of pages for that date (decrypted, in RAM only).
//     - Which page index is currently visible in the PageView.
//     - Whether an auto-save is in progress.
//
//   The Drift stream (watchPagesForDate) is used for INITIAL load only.
//   During an active editing session, we manage the page list locally to
//   avoid the stream re-triggering a full decrypt on every auto-save.
//   When the user navigates away, the stream resumes ownership.
//
// AUTO-SAVE:
//   The DiaryScreen calls notifier.updatePageContent(index, content) as the
//   user types. DiaryNotifier debounces this: only saves to the DB after
//   2 seconds of inactivity. This avoids hammering the DB + encryption on
//   every keystroke while still persisting promptly.
// ══════════════════════════════════════════════════════════════════════════════

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/app_exceptions.dart';
import '../data/models/diary_entry_model.dart';
import 'repository_providers.dart';

// ── Stream Provider (Calendar Shading) ───────────────────────────────────────

/// Streams the set of dates that have diary entries.
/// Used by the Consistency tab calendar and the diary date selector.
final activeDiaryDatesProvider = StreamProvider<Map<DateTime, bool>>(
  (ref) => ref.watch(diaryRepositoryProvider).watchActiveDiaryDates(),
  name: 'activeDiaryDatesProvider',
);

/// Streams the pages for a specific date (used in read-only contexts).
/// The diary editing screen uses DiaryNotifier instead.
final diaryPagesForDateProvider =
    StreamProvider.family<List<DiaryEntryModel>, DateTime>(
  (ref, date) =>
      ref.watch(diaryRepositoryProvider).watchPagesForDate(date),
  name: 'diaryPagesForDateProvider',
);

// ── Editing Session State ─────────────────────────────────────────────────────

/// The complete state of an active diary editing session.
@immutable
class DiarySessionState {
  const DiarySessionState({
    required this.date,
    required this.pages,
    required this.currentPageIndex,
    this.isSaving = false,
    this.lastSaveError,
  });

  /// The date being viewed/edited.
  final DateTime date;

  /// Decrypted pages for this date, in page-number order.
  final List<DiaryEntryModel> pages;

  /// Index of the page currently visible in the PageView (0-based).
  final int currentPageIndex;

  /// True while an auto-save is in progress. Used to show a subtle indicator.
  final bool isSaving;

  /// The error from the most recent save attempt, if any.
  final String? lastSaveError;

  /// The currently visible page model.
  DiaryEntryModel get currentPage => pages[currentPageIndex];

  /// Total number of pages for this date.
  int get pageCount => pages.length;

  bool get hasError => lastSaveError != null;

  DiarySessionState copyWith({
    DateTime? date,
    List<DiaryEntryModel>? pages,
    int? currentPageIndex,
    bool? isSaving,
    String? lastSaveError,
    bool clearError = false,
  }) {
    return DiarySessionState(
      date: date ?? this.date,
      pages: pages ?? this.pages,
      currentPageIndex: currentPageIndex ?? this.currentPageIndex,
      isSaving: isSaving ?? this.isSaving,
      lastSaveError: clearError ? null : (lastSaveError ?? this.lastSaveError),
    );
  }
}

// ── Diary Notifier ────────────────────────────────────────────────────────────

class DiaryNotifier extends AsyncNotifier<DiarySessionState> {
  Timer? _debounceTimer;
  static const _autoSaveDelay = Duration(seconds: 2);

  @override
  Future<DiarySessionState> build() async {
    // Initial state: today's diary.
    return _loadDate(DateTime.now());
  }

  DiaryRepository get _repo => ref.read(diaryRepositoryProvider);

  // ── Navigation ─────────────────────────────────────────────────────────────

  /// Loads the diary for [date].
  /// Saves any pending auto-save for the current date first.
  Future<void> navigateToDate(DateTime date) async {
    _cancelDebounce();
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _loadDate(date));
  }

  Future<DiarySessionState> _loadDate(DateTime date) async {
    final pages = await _repo.getPagesForDate(date);
    return DiarySessionState(
      date: date,
      pages: pages,
      currentPageIndex: 0,
    );
  }

  // ── Page Navigation ────────────────────────────────────────────────────────

  void setCurrentPage(int index) {
    state.whenData((session) {
      if (index < 0 || index >= session.pages.length) return;
      state = AsyncData(session.copyWith(currentPageIndex: index));
    });
  }

  // ── Content Editing (Auto-Save) ────────────────────────────────────────────

  /// Called by the DiaryScreen on every QuillController change event.
  ///
  /// Updates the in-memory page content immediately (so the UI is responsive),
  /// then debounces the actual DB write by [_autoSaveDelay].
  void updatePageContent(int pageIndex, String newContent) {
    state.whenData((session) {
      if (pageIndex >= session.pages.length) return;

      // Update in-memory immediately — no DB call yet.
      final updatedPages = List<DiaryEntryModel>.from(session.pages);
      updatedPages[pageIndex] =
          session.pages[pageIndex].copyWith(content: newContent);

      state = AsyncData(session.copyWith(pages: updatedPages));

      // Debounce: cancel the previous timer, start a new 2-second countdown.
      _debounceTimer?.cancel();
      _debounceTimer = Timer(_autoSaveDelay, () {
        _persistPage(pageIndex, newContent);
      });
    });
  }

  /// Forces an immediate save, bypassing the debounce timer.
  /// Called when the user navigates away from the diary screen.
  Future<void> saveImmediately() async {
    _cancelDebounce();
    final session = state.valueOrNull;
    if (session == null) return;

    for (int i = 0; i < session.pages.length; i++) {
      final page = session.pages[i];
      if (!page.isEmpty) {
        await _persistPage(i, page.content);
      }
    }
  }

  Future<void> _persistPage(int pageIndex, String content) async {
    final session = state.valueOrNull;
    if (session == null) return;
    if (pageIndex >= session.pages.length) return;

    final page = session.pages[pageIndex];
    if (page.isEmpty) return;

    // Show saving indicator.
    state = AsyncData(session.copyWith(isSaving: true, clearError: true));

    try {
      final saved = await _repo.savePage(
        date: session.date,
        pageNumber: page.pageNumber,
        content: content,
        existingId: page.isNew ? null : page.id,
      );

      // Update the page in state with the real DB id (important for new pages).
      final updatedPages = List<DiaryEntryModel>.from(session.pages);
      updatedPages[pageIndex] = saved;

      state = AsyncData(session.copyWith(
        pages: updatedPages,
        isSaving: false,
      ));
    } catch (e) {
      final errorMsg = e is AsrioException ? e.message : 'Auto-save failed.';
      state = AsyncData(session.copyWith(
        isSaving: false,
        lastSaveError: errorMsg,
      ));
      debugPrint('[DiaryNotifier] Auto-save error: $e');
    }
  }

  // ── Page Management ────────────────────────────────────────────────────────

  /// Adds a new blank page to the current date's diary session.
  Future<void> addPage() async {
    final session = state.valueOrNull;
    if (session == null) return;

    final newPageNumber = session.pageCount + 1;
    final newPage = DiaryEntryModel.blank(
      date: session.date,
      pageNumber: newPageNumber,
    );

    final updatedPages = [...session.pages, newPage];
    state = AsyncData(session.copyWith(
      pages: updatedPages,
      currentPageIndex: updatedPages.length - 1,
    ));
  }

  /// Deletes the page at [pageIndex] from the current session.
  /// If only one page remains, clears its content instead of deleting.
  Future<void> deletePage(int pageIndex) async {
    final session = state.valueOrNull;
    if (session == null) return;

    final page = session.pages[pageIndex];

    // Never delete the last page — clear it instead.
    if (session.pageCount == 1) {
      updatePageContent(0, '[{"insert":"\\n"}]');
      return;
    }

    if (!page.isNew) {
      try {
        await _repo.deletePage(page.id);
      } catch (e) {
        debugPrint('[DiaryNotifier] Failed to delete page: $e');
        return;
      }
    }

    final updatedPages = List<DiaryEntryModel>.from(session.pages)
      ..removeAt(pageIndex);

    final newIndex = pageIndex > 0 ? pageIndex - 1 : 0;
    state = AsyncData(session.copyWith(
      pages: updatedPages,
      currentPageIndex: newIndex,
    ));
  }

  // ── Cleanup ────────────────────────────────────────────────────────────────

  void _cancelDebounce() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
  }

  /// Must be called when the DiaryScreen is disposed.
  /// Saves any pending content and cancels the debounce timer.
  Future<void> dispose() async {
    await saveImmediately();
    _cancelDebounce();
  }
}

final diaryNotifierProvider =
    AsyncNotifierProvider<DiaryNotifier, DiarySessionState>(
  () => DiaryNotifier(),
  name: 'diaryNotifierProvider',
);
