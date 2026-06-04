// lib/features/diary/diary_screen.dart — Phase 7 fix
// Pencil fixed, clean empty state, no marketing copy

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
  bool _relaunchCheckDone = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkRelaunch());
  }

  Future<void> _checkRelaunch() async {
    if (_relaunchCheckDone) return;
    _relaunchCheckDone = true;
    final lastTab    = ref.read(lastActiveTabProvider);
    final lockEnabled = ref.read(diaryLockEnabledProvider);
    if (lastTab == kDiaryTabIndex && lockEnabled) {
      final allowed = await BiometricService()
          .isAllowed(lockEnabled: lockEnabled);
      if (!allowed && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Authentication required.'),
            backgroundColor: AsrioColors.black,
          ),
        );
      }
    }
  }

  Future<void> _openEditor(DateTime date) async {
    final lockEnabled = ref.read(diaryLockEnabledProvider);
    if (lockEnabled) {
      final result = await BiometricService()
          .authenticate(lockEnabled: lockEnabled,
              reason: 'Authenticate to open your diary.');
      if (result != BiometricResult.success &&
          result != BiometricResult.lockDisabled) {
        if (!mounted) return;
        if (result != BiometricResult.cancelled) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Authentication failed.'),
              backgroundColor: AsrioColors.black,
            ),
          );
        }
        return;
      }
    }

    if (!mounted) return;

    // Navigate diary notifier to the selected date BEFORE switching view
    await ref.read(diaryNotifierProvider.notifier).navigateToDate(date);

    if (!mounted) return;
    setState(() {
      _inEditor    = true;
      _editingDate = date;
    });
    zenModeNotifier.value = true;
    ref.read(lastActiveTabProvider.notifier).setTab(kDiaryTabIndex);
  }

  void _closeEditor() {
    ref.read(diaryNotifierProvider.notifier).saveImmediately();
    setState(() {
      _inEditor    = false;
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
              key:     const ValueKey('editor'),
              date:    _editingDate ?? DateTime.now(),
              onClose: _closeEditor,
            )
          : _DiaryList(
              key:         const ValueKey('list'),
              onEntryTap:  _openEditor,
            ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// LIST VIEW
// ══════════════════════════════════════════════════════════════════════════════

class _DiaryList extends ConsumerWidget {
  const _DiaryList({super.key, required this.onEntryTap});
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
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Diary', style: AsrioText.greeting),
                  Row(children: [
                    if (lockEnabled)
                      const Padding(
                        padding: EdgeInsets.only(right: 12),
                        child: Icon(Icons.lock_rounded,
                            size: 16, color: AsrioColors.black),
                      ),
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        onEntryTap(DateTime.now());
                      },
                      child: Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: AsrioColors.black,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.edit_outlined,
                            color: AsrioColors.white, size: 18),
                      ),
                    ),
                  ]),
                ],
              ),
            ),

            const SizedBox(height: 24),
            const Divider(color: AsrioColors.border, height: 1, thickness: 0.8),

            Expanded(
              child: activeDates.when(
                loading: () => const Center(
                    child: CircularProgressIndicator(color: AsrioColors.black)),
                error: (_, __) => Center(
                    child: Text('Could not load.', style: AsrioText.bodyMuted)),
                data: (dates) {
                  // Empty state — minimal, no marketing copy
                  if (dates.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.chrome_reader_mode_outlined,
                              size: 40, color: AsrioColors.muted),
                          const SizedBox(height: 12),
                          Text('No entries yet.',
                              style: AsrioText.bodyMuted),
                        ],
                      ),
                    );
                  }

                  final sorted = dates.keys.toList()
                    ..sort((a, b) => b.compareTo(a));

                  return ListView.separated(
                    physics: const BouncingScrollPhysics(),
                    itemCount: sorted.length,
                    separatorBuilder: (_, __) => const Divider(
                        color: AsrioColors.border,
                        height: 1,
                        thickness: 0.8),
                    itemBuilder: (_, i) => _EntryRow(
                      date:  sorted[i],
                      onTap: () => onEntryTap(sorted[i]),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.date, required this.onTap});
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
                        style:
                            AsrioText.cardTitle.copyWith(fontSize: 22),
                      ),
                    ),
                  ),
                  Text(DateFormat('MMM').format(date).toUpperCase(),
                      style: AsrioText.label),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(DateFormat('EEEE').format(date),
                      style: AsrioText.diaryDate),
                  const SizedBox(height: 3),
                  Text('Continue writing...',
                      style: AsrioText.diaryPreview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const SizedBox(width: 12),
            const Icon(Icons.lock_outline_rounded,
                size: 13, color: AsrioColors.muted),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// EDITOR — ZEN MODE
// ══════════════════════════════════════════════════════════════════════════════

class _DiaryEditor extends ConsumerStatefulWidget {
  const _DiaryEditor({super.key, required this.date, required this.onClose});
  final DateTime date;
  final VoidCallback onClose;

  @override
  ConsumerState<_DiaryEditor> createState() => _DiaryEditorState();
}

class _DiaryEditorState extends ConsumerState<_DiaryEditor>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  QuillController? _ctrl;
  final FocusNode _focus = FocusNode();
  bool _initialized = false;
  bool _isBlurred = false;
  bool _pendingAuth = false;
  bool _toolbarVisible = false;

  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _pulseAnim = Tween<double>(begin: 1.0, end: 0.55).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    WidgetsBinding.instance.addPostFrameCallback((_) => _initCtrl());
  }

  void _initCtrl() {
    if (_initialized) return;
    final session = ref.read(diaryNotifierProvider).valueOrNull;
    if (session == null || !mounted) return;

    final page = session.pages.isNotEmpty
        ? session.pages[session.currentPageIndex]
        : null;

    Document doc;
    if (page != null && page.content.isNotEmpty) {
      try {
        doc = Document.fromJson(
            jsonDecode(page.content) as List<dynamic>);
      } catch (_) {
        doc = Document();
      }
    } else {
      doc = Document();
    }

    final controller = QuillController(
      document: doc,
      selection: const TextSelection.collapsed(offset: 0),
    );

    controller.document.changes.listen((_) {
      if (!mounted || _ctrl == null) return;
      final deltaJson = _ctrl!.document.toDelta().toJson();
      final content   = jsonEncode(deltaJson);
      ref.read(diaryNotifierProvider.notifier)
          .updatePageContent(session.currentPageIndex, content);
      final hasSel = !_ctrl!.selection.isCollapsed;
      if (hasSel != _toolbarVisible && mounted) {
        setState(() => _toolbarVisible = hasSel);
      }
    });

    setState(() {
      _ctrl        = controller;
      _initialized = true;
    });
    _pulseCtrl.forward().then((_) => _pulseCtrl.reverse());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      setState(() { _isBlurred = true; _pendingAuth = true; });
    } else if (state == AppLifecycleState.resumed && _pendingAuth) {
      _requestAuth();
    }
  }

  Future<void> _requestAuth() async {
    final lock = ref.read(diaryLockEnabledProvider);
    final result = await BiometricService()
        .authenticate(lockEnabled: lock,
            reason: 'Authenticate to continue writing.');
    if (!mounted) return;
    if (result == BiometricResult.success ||
        result == BiometricResult.lockDisabled) {
      setState(() { _isBlurred = false; _pendingAuth = false; });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pulseCtrl.dispose();
    _ctrl?.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(diaryNotifierProvider);

    return Scaffold(
      backgroundColor: AsrioColors.white,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
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
                        child: Hero(
                          tag: heroDateTag(widget.date),
                          child: Material(
                            color: Colors.transparent,
                            child: AnimatedBuilder(
                              animation: _pulseAnim,
                              builder: (_, child) =>
                                  Opacity(opacity: _pulseAnim.value, child: child),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    DateFormat('EEEE, d MMMM')
                                        .format(widget.date),
                                    style: AsrioText.diaryDate,
                                  ),
                                  Text(
                                    DateFormat('yyyy').format(widget.date),
                                    style: AsrioText.caption,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      session.when(
                        data: (s) => AnimatedOpacity(
                          opacity: s.isSaving ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 300),
                          child: const SizedBox(
                            width: 12, height: 12,
                            child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                color: AsrioColors.muted),
                          ),
                        ),
                        loading: () => const SizedBox.shrink(),
                        error:   (_, __) => const SizedBox.shrink(),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.lock_outline_rounded,
                          size: 14, color: AsrioColors.muted),
                    ],
                  ),
                ),
                const Divider(
                    color: AsrioColors.border, height: 1, thickness: 0.8),
                Expanded(
                  child: _ctrl == null
                      ? const Center(
                          child: SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                color: AsrioColors.muted),
                          ),
                        )
                      : GestureDetector(
                          onTap: () => _focus.requestFocus(),
                          child: QuillEditor.basic(
                            controller: _ctrl!,
                            focusNode: _focus,
                            config: QuillEditorConfig(
                              padding: const EdgeInsets.fromLTRB(
                                  24, 24, 24, 60),
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

          // Floating format bar
          if (_toolbarVisible && _ctrl != null)
            Positioned(
              bottom: MediaQuery.of(context).viewInsets.bottom + 8,
              left: 16, right: 16,
              child: _FormatBar(controller: _ctrl!),
            ),

          // Ghost Mode blur
          if (_isBlurred)
            Positioned.fill(
              child: GestureDetector(
                onTap: _requestAuth,
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
                  child: Container(
                    color: AsrioColors.white.withAlpha(200),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 64, height: 64,
                            decoration: const BoxDecoration(
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
                            onTap: _requestAuth,
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

// ── Floating toolbar ──────────────────────────────────────────────────────────

class _FormatBar extends StatelessWidget {
  const _FormatBar({required this.controller});
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
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: QuillSimpleToolbar(
        controller: controller,
        config: QuillSimpleToolbarConfig(
          showBoldButton: true,
          showItalicButton: true,
          showListBullets: true,
          showUnderLineButton: false,
          showStrikeThrough: false,
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
                iconButtonUnselectedData:
                    const IconButtonData(color: AsrioColors.muted),
                iconButtonSelectedData:
                    const IconButtonData(color: AsrioColors.white),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
