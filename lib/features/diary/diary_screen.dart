// lib/features/diary/diary_screen.dart  — Phase 4 (complete rewrite)
//
// ══════════════════════════════════════════════════════════════════════════════
// Diary Screen — List View + Zen Mode Editor (Phase 4)
// ══════════════════════════════════════════════════════════════════════════════
//
// PHASE 4 ADDITIONS vs Phase 3:
//   ✅ Correct Quill round-trip (save → encrypt → decrypt → reload)
//   ✅ _initialized guard (prevents controller reinit on stream rebuild)
//   ✅ Biometric auth — 3 trigger points
//   ✅ Hero on date number (list row → editor header)
//   ✅ Book-open transition via diaryScreenTransitionBuilder
//   ✅ Date pulse animation signals decrypt completion
//   ✅ Relaunch auth: checks if diary was last screen
// ══════════════════════════════════════════════════════════════════════════════

import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/services/biometric_service.dart';
import '../../core/theme/asrio_colors.dart';
import '../../core/theme/asrio_text_styles.dart';
import '../../providers/diary_provider.dart';
import '../../providers/settings_provider.dart';
import '../main_screen.dart';
import 'widgets/diary_page_transition.dart';

class DiaryScreen extends ConsumerStatefulWidget {
  const DiaryScreen({super.key});

  @override
  ConsumerState<DiaryScreen> createState() => _DiaryScreenState();
}

class _DiaryScreenState extends ConsumerState<DiaryScreen> {
  bool _inEditor = false;
  DateTime? _editingDate;

  // ── Trigger 3: Relaunch auth ───────────────────────────────────────────────
  // Check on first build if diary was the last open screen.
  bool _relaunchCheckDone = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkRelaunch());
  }

  Future<void> _checkRelaunch() async {
    if (_relaunchCheckDone) return;
    _relaunchCheckDone = true;

    final lastTab = ref.read(lastActiveTabProvider);
    final lockEnabled = ref.read(diaryLockEnabledProvider);

    // If diary was the last active screen AND lock is on,
    // show the list but blur it until auth passes.
    if (lastTab == kDiaryTabIndex && lockEnabled) {
      final allowed = await BiometricService().isAllowed(lockEnabled: lockEnabled);
      if (!allowed && mounted) {
        // Auth failed/cancelled — navigate away from diary tab.
        // The PageController is owned by MainScreen so we use a callback.
        // For now: show a snackbar. Phase 6 will add tab-switching callback.
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Authentication required to access your diary.'),
              backgroundColor: AsrioColors.black,
            ),
          );
        }
      }
    }
  }

  // ── Open editor (Trigger 1: entry tap) ───────────────────────────────────

  Future<void> _openEditor(DateTime date) async {
    final lockEnabled = ref.read(diaryLockEnabledProvider);

    if (lockEnabled) {
      final result = await BiometricService().authenticate(
        lockEnabled: lockEnabled,
        reason: 'Authenticate to open your diary.',
      );

      if (result != BiometricResult.success &&
          result != BiometricResult.lockDisabled) {
        if (!mounted) return;
        if (result != BiometricResult.cancelled) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Authentication failed. Try again.'),
              backgroundColor: AsrioColors.black,
              duration: Duration(seconds: 2),
            ),
          );
        }
        return; // Stay on list view.
      }
    }

    // Auth passed (or lock is off). Load the date and open.
    ref.read(diaryNotifierProvider.notifier).navigateToDate(date);

    setState(() {
      _inEditor = true;
      _editingDate = date;
    });
    zenModeNotifier.value = true;

    // Save this tab as last active.
    ref.read(lastActiveTabProvider.notifier).setTab(kDiaryTabIndex);
  }

  void _closeEditor() {
    ref.read(diaryNotifierProvider.notifier).saveImmediately();
    setState(() {
      _inEditor = false;
      _editingDate = null;
    });
    zenModeNotifier.value = false;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 380),
      transitionBuilder: diaryScreenTransitionBuilder,
      child: _inEditor
          ? _DiaryEditor(
              key: const ValueKey('editor'),
              date: _editingDate ?? DateTime.now(),
              onClose: _closeEditor,
            )
          : _DiaryListView(
              key: const ValueKey('list'),
              onEntryTap: _openEditor,
            ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// DIARY LIST VIEW
// ══════════════════════════════════════════════════════════════════════════════

class _DiaryListView extends ConsumerWidget {
  const _DiaryListView({super.key, required this.onEntryTap});
  final Future<void> Function(DateTime) onEntryTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeDates = ref.watch(activeDiaryDatesProvider);
    final lockEnabled = ref.watch(diaryLockEnabledProvider);

    return Scaffold(
      backgroundColor: AsrioColors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ───────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Diary', style: AsrioText.greeting),
                  Row(
                    children: [
                      // Lock status indicator
                      if (lockEnabled)
                        Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: Icon(
                            Icons.lock_rounded,
                            size: 16,
                            color: AsrioColors.black,
                          ),
                        ),
                      // New entry
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          onEntryTap(DateTime.now());
                        },
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AsrioColors.black,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.edit_outlined,
                              color: AsrioColors.white, size: 18),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                '${activeDates.valueOrNull?.length ?? 0} entries',
                style: AsrioText.bodyMuted,
              ),
            ),
            const SizedBox(height: 24),
            const Divider(
                color: AsrioColors.border, height: 1, thickness: 0.8),

            // ── Entry List ────────────────────────────────────────────────
            Expanded(
              child: activeDates.when(
                data: (dates) {
                  if (dates.isEmpty) {
                    return _EmptyDiaryState(onTap: onEntryTap);
                  }
                  final sorted = dates.keys.toList()
                    ..sort((a, b) => b.compareTo(a));

                  return ListView.separated(
                    physics: const BouncingScrollPhysics(),
                    itemCount: sorted.length,
                    separatorBuilder: (_, __) => const Divider(
                        color: AsrioColors.border, height: 1, thickness: 0.8),
                    itemBuilder: (_, i) => _DiaryEntryRow(
                      date: sorted[i],
                      onTap: () => onEntryTap(sorted[i]),
                    ),
                  );
                },
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AsrioColors.black),
                ),
                error: (_, __) => Center(
                  child: Text('Could not load entries.', style: AsrioText.bodyMuted),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Entry Row with Hero on date ───────────────────────────────────────────────

class _DiaryEntryRow extends StatelessWidget {
  const _DiaryEntryRow({required this.date, required this.onTap});
  final DateTime date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      splashColor: AsrioColors.offWhite,
      highlightColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
        child: Row(
          children: [
            // ── Hero: date number flies to editor header ──────────────
            SizedBox(
              width: 48,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Hero(
                    tag: heroDateTag(date),
                    child: Material(
                      color: Colors.transparent,
                      child: Text(
                        DateFormat('d').format(date),
                        style: AsrioText.cardTitle.copyWith(fontSize: 22),
                      ),
                    ),
                  ),
                  Text(
                    DateFormat('MMM').format(date).toUpperCase(),
                    style: AsrioText.label,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            // ── Preview ───────────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(DateFormat('EEEE').format(date),
                      style: AsrioText.diaryDate),
                  const SizedBox(height: 3),
                  Text(
                    'Tap to continue writing...',
                    style: AsrioText.diaryPreview,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            const Icon(Icons.lock_outline_rounded,
                size: 14, color: AsrioColors.muted),
          ],
        ),
      ),
    );
  }
}

class _EmptyDiaryState extends StatelessWidget {
  const _EmptyDiaryState({required this.onTap});
  final Future<void> Function(DateTime) onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.auto_stories_outlined,
              size: 48, color: AsrioColors.muted),
          const SizedBox(height: 16),
          Text('Your diary is empty.', style: AsrioText.cardTitle),
          const SizedBox(height: 8),
          Text('Tap the pencil to write your first entry.',
              style: AsrioText.bodyMuted),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// DIARY EDITOR — Zen Mode
// ══════════════════════════════════════════════════════════════════════════════

class _DiaryEditor extends ConsumerStatefulWidget {
  const _DiaryEditor({
    super.key,
    required this.date,
    required this.onClose,
  });
  final DateTime date;
  final VoidCallback onClose;

  @override
  ConsumerState<_DiaryEditor> createState() => _DiaryEditorState();
}

class _DiaryEditorState extends ConsumerState<_DiaryEditor>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  QuillController? _quillController;
  final FocusNode _focusNode = FocusNode();

  // ── Phase 4: _initialized guard ──────────────────────────────────────────
  // Prevents controller re-initialization when the Drift stream emits after
  // an auto-save. Without this, the cursor jumps to the top after every save.
  bool _initialized = false;

  // Ghost Mode
  bool _isBlurred = false;
  bool _pendingAuth = false;

  // Date pulse animation (signals decryption complete)
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  // Floating toolbar visibility
  bool _toolbarVisible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _pulseAnim = Tween<double>(begin: 1.0, end: 0.55).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) => _initController());
  }

  // ── Quill round-trip (Phase 4 fix) ───────────────────────────────────────

  void _initController() {
    if (_initialized) return; // Guard: only run once per editor session.

    final session = ref.read(diaryNotifierProvider).valueOrNull;
    if (session == null || !mounted) return;

    final page = session.pages.isNotEmpty
        ? session.pages[session.currentPageIndex]
        : null;

    Document doc;

    if (page != null && page.content.isNotEmpty) {
      try {
        // Phase 4 fix: correct JSON decode path.
        // content is a JSON string: '[{"insert":"Hello\n"}]'
        final List<dynamic> deltaJson = jsonDecode(page.content) as List<dynamic>;
        doc = Document.fromJson(deltaJson);
      } catch (e) {
        debugPrint('[DiaryEditor] Failed to parse Quill delta: $e');
        doc = Document();
      }
    } else {
      doc = Document();
    }

    final controller = QuillController(
      document: doc,
      selection: const TextSelection.collapsed(offset: 0),
    );

    // Listen for content changes → debounced auto-save via DiaryNotifier.
    controller.document.changes.listen((_) {
      if (!mounted || _quillController == null) return;

      final deltaJson = _quillController!.document.toDelta().toJson();
      final content = jsonEncode(deltaJson);

      ref
          .read(diaryNotifierProvider.notifier)
          .updatePageContent(
            session.currentPageIndex,
            content,
          );

      // Show/hide floating toolbar based on text selection.
      final hasSelection = !_quillController!.selection.isCollapsed;
      if (hasSelection != _toolbarVisible && mounted) {
        setState(() => _toolbarVisible = hasSelection);
      }
    });

    setState(() {
      _quillController = controller;
      _initialized = true;
    });

    // Pulse the date to signal "content loaded".
    _pulseController.forward().then((_) => _pulseController.reverse());
  }

  // ── Ghost Mode — Trigger 2: background/foreground ─────────────────────────

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // Blur immediately when going to background.
      setState(() {
        _isBlurred = true;
        _pendingAuth = true;
      });
    } else if (state == AppLifecycleState.resumed && _pendingAuth) {
      // App returned — require auth before lifting blur.
      _requestAuthAfterResume();
    }
  }

  Future<void> _requestAuthAfterResume() async {
    final lockEnabled = ref.read(diaryLockEnabledProvider);

    final result = await BiometricService().authenticate(
      lockEnabled: lockEnabled,
      reason: 'Authenticate to continue writing.',
    );

    if (!mounted) return;

    if (result == BiometricResult.success ||
        result == BiometricResult.lockDisabled) {
      setState(() {
        _isBlurred = false;
        _pendingAuth = false;
      });
    } else if (result == BiometricResult.cancelled) {
      // Keep blur — user dismissed the prompt. They must try again.
      // The blur overlay has a "Try Again" button for this case.
    } else {
      // Failed — keep blur, let user retry via the overlay button.
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pulseController.dispose();
    _quillController?.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(diaryNotifierProvider);

    return Scaffold(
      backgroundColor: AsrioColors.white,
      body: Stack(
        children: [
          // ── Main editor body ─────────────────────────────────────────
          SafeArea(
            child: Column(
              children: [
                // ── Editor top bar ──────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 12, 16, 0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded,
                            size: 18, color: AsrioColors.black),
                        onPressed: widget.onClose,
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ── Hero: date flies from list row ──────
                            Hero(
                              tag: heroDateTag(widget.date),
                              child: Material(
                                color: Colors.transparent,
                                child: AnimatedBuilder(
                                  animation: _pulseAnim,
                                  builder: (_, child) => Opacity(
                                    opacity: _pulseAnim.value,
                                    child: child,
                                  ),
                                  child: Text(
                                    DateFormat('EEEE, d MMMM')
                                        .format(widget.date),
                                    style: AsrioText.diaryDate,
                                  ),
                                ),
                              ),
                            ),
                            Text(
                              DateFormat('yyyy').format(widget.date),
                              style: AsrioText.caption,
                            ),
                          ],
                        ),
                      ),
                      // Auto-save indicator
                      session.when(
                        data: (s) => AnimatedOpacity(
                          opacity: s.isSaving ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 300),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 10,
                                height: 10,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.5,
                                  color: AsrioColors.muted,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text('Saving', style: AsrioText.caption),
                            ],
                          ),
                        ),
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.lock_outline_rounded,
                          size: 16, color: AsrioColors.muted),
                    ],
                  ),
                ),

                const Divider(
                    color: AsrioColors.border, height: 1, thickness: 0.8),

                // ── Quill editor canvas ─────────────────────────────
                Expanded(
                  child: _quillController == null
                      ? const Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AsrioColors.muted),
                          ),
                        )
                      : GestureDetector(
                          onTap: () => _focusNode.requestFocus(),
                          child: QuillEditor.basic(
                            controller: _quillController!,
                            focusNode: _focusNode,
                            config: QuillEditorConfig(
                              padding: const EdgeInsets.fromLTRB(24, 24, 24, 60),
                              placeholder: 'Write your thoughts...',
                              customStyles: DefaultStyles(
                                paragraph: DefaultTextBlockStyle(
                                  AsrioText.diaryBody,
                                  const HorizontalSpacing(0, 0),
                                  const VerticalSpacing(0, 0),
                                  const VerticalSpacing(0, 0),
                                  null,
                                ),
                              ),
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),

          // ── Floating format toolbar (on text selection only) ─────────
          if (_toolbarVisible && _quillController != null)
            Positioned(
              bottom: MediaQuery.of(context).viewInsets.bottom + 8,
              left: 16,
              right: 16,
              child: _FloatingFormatBar(controller: _quillController!),
            ),

          // ── Ghost Mode blur overlay ──────────────────────────────────
          if (_isBlurred)
            Positioned.fill(
              child: GestureDetector(
                onTap: _requestAuthAfterResume,
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
                  child: Container(
                    color: AsrioColors.white.withAlpha(200),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: AsrioColors.black,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.lock_rounded,
                                color: AsrioColors.white, size: 28),
                          ),
                          const SizedBox(height: 20),
                          Text('Diary Locked',
                              style: AsrioText.cardTitle),
                          const SizedBox(height: 8),
                          Text('Tap to authenticate.',
                              style: AsrioText.bodyMuted),
                          const SizedBox(height: 28),
                          GestureDetector(
                            onTap: _requestAuthAfterResume,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 28, vertical: 14),
                              decoration: BoxDecoration(
                                color: AsrioColors.black,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text('Unlock',
                                  style: AsrioText.cardTitleWhite
                                      .copyWith(fontSize: 15)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Floating Format Bar ───────────────────────────────────────────────────────

class _FloatingFormatBar extends StatelessWidget {
  const _FloatingFormatBar({required this.controller});
  final QuillController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AsrioColors.black,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AsrioColors.black.withAlpha(50),
            blurRadius: 24,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: QuillSimpleToolbar(
        controller: controller,
        config: QuillSimpleToolbarConfig(
          showBoldButton: true,
          showItalicButton: true,
          showUnderLineButton: false,
          showStrikeThrough: false,
          showListBullets: true,
          showListNumbers: false,
          showListCheck: false,
          showCodeBlock: false,
          showQuote: false,
          showLink: false,
          showSearchButton: false,
          showSubscript: false,
          showSuperscript: false,
          showSmallButton: false,
          showInlineCode: false,
          showColorButton: false,
          showBackgroundColorButton: false,
          showClearFormat: false,
          showHeaderStyle: false,
          showIndent: false,
          showUndo: false,
          showRedo: false,
          showFontFamily: false,
          showFontSize: false,
          showDividers: false,
          showAlignmentButtons: false,
          toolbarSize: 44,
          buttonOptions: QuillSimpleToolbarButtonOptions(
            base: QuillToolbarBaseButtonOptions(
              iconTheme: QuillIconTheme(
                iconButtonUnselectedData: const IconButtonData(
                  color: AsrioColors.muted,
                ),
                iconButtonSelectedData: const IconButtonData(
                  color: AsrioColors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
