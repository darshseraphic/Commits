// lib/features/todo/todo_screen.dart — Phase 4 (AnimatedList + completion animation)
//
// PHASE 4 ADDITIONS vs Phase 3:
//   ✅ AnimatedList replaces static Column for active tasks
//   ✅ SizeTransition + FadeTransition on task removal
//   ✅ ScaleTransition on FocusBentoCard completion
//   ✅ Checkmark fill animation on circular checkbox tap

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/asrio_colors.dart';
import '../../core/theme/asrio_text_styles.dart';
import '../../data/models/task_model.dart';
import '../../providers/task_provider.dart';
import '../shared/widgets/bento_card.dart';

class TodoScreen extends ConsumerWidget {
  const TodoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dailyTasks = ref.watch(watchDailyTasksProvider);

    return Scaffold(
      backgroundColor: AsrioColors.offWhite,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(DateFormat('EEEE, d MMMM').format(DateTime.now()),
                        style: AsrioText.greeting),
                    const SizedBox(height: 4),
                    Text('Your tasks', style: AsrioText.bodyMuted),
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
            SliverToBoxAdapter(
              child: dailyTasks.when(
                data: (tasks) => _TaskBody(tasks: tasks),
                loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 60),
                      child: CircularProgressIndicator(color: AsrioColors.black),
                    )),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: BentoCard.white(
                    child: Text(e.toString(), style: AsrioText.bodyMuted),
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
      floatingActionButton: const _AddTaskFab(),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Task Body — owns the AnimatedList for active tasks
// ══════════════════════════════════════════════════════════════════════════════

class _TaskBody extends ConsumerStatefulWidget {
  const _TaskBody({required this.tasks});
  final List<TaskModel> tasks;

  @override
  ConsumerState<_TaskBody> createState() => _TaskBodyState();
}

class _TaskBodyState extends ConsumerState<_TaskBody> {
  // AnimatedList key — gives us programmatic insert/remove control.
  final _listKey = GlobalKey<AnimatedListState>();

  // Local copy of active tasks that the AnimatedList drives.
  // We maintain this separately so the remove animation plays
  // BEFORE the Drift stream emits the updated list.
  late List<TaskModel> _activeTasks;

  @override
  void initState() {
    super.initState();
    _activeTasks = widget.tasks.where((t) => !t.isCompleted).toList();
  }

  @override
  void didUpdateWidget(_TaskBody old) {
    super.didUpdateWidget(old);
    // When the Drift stream pushes a new list (e.g., after a DB write from
    // another trigger), sync the local list WITHOUT animating existing items.
    final newActive = widget.tasks.where((t) => !t.isCompleted).toList();

    // Add any tasks that appeared in the new list but not in our local copy.
    for (final task in newActive) {
      if (!_activeTasks.any((t) => t.id == task.id)) {
        final insertIndex = _activeTasks.length;
        _activeTasks.insert(insertIndex, task);
        _listKey.currentState?.insertItem(
          insertIndex,
          duration: const Duration(milliseconds: 250),
        );
      }
    }

    // Remove tasks that disappeared (completed from another screen, deleted, etc.)
    // We iterate backwards to keep indices valid during removal.
    for (int i = _activeTasks.length - 1; i >= 0; i--) {
      if (!newActive.any((t) => t.id == _activeTasks[i].id)) {
        _removeAt(i, animate: false);
      }
    }
  }

  /// Removes the task at [index] from the AnimatedList with a collapse animation.
  /// [animate]: false skips the animation (used during didUpdateWidget sync).
  void _removeAt(int index, {bool animate = true}) {
    if (index < 0 || index >= _activeTasks.length) return;
    final removed = _activeTasks.removeAt(index);

    if (animate) {
      _listKey.currentState?.removeItem(
        index,
        (context, animation) => _buildRemovedTile(removed, animation),
        duration: const Duration(milliseconds: 300),
      );
    }
  }

  Widget _buildRemovedTile(TaskModel task, Animation<double> animation) {
    return SizeTransition(
      sizeFactor: CurvedAnimation(
        parent: animation,
        curve: Curves.easeInCubic,
      ),
      child: FadeTransition(
        opacity: CurvedAnimation(
          parent: animation,
          curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
        ),
        child: _TaskCard(
          task: task,
          onComplete: (_) {}, // No-op: already being removed.
          onDelete: (_) {},
        ),
      ),
    );
  }

  Future<void> _handleComplete(int index, TaskModel task) async {
    HapticFeedback.mediumImpact();
    _removeAt(index);
    // DB write happens after animation starts — smooth feeling.
    await ref.read(taskNotifierProvider.notifier).completeTask(task);
  }

  Future<void> _handleDelete(int index, TaskModel task) async {
    HapticFeedback.heavyImpact();
    _removeAt(index);
    await ref.read(taskNotifierProvider.notifier).deleteTask(task);
  }

  @override
  Widget build(BuildContext context) {
    final completed = widget.tasks.where((t) => t.isCompleted).toList();
    final topPriority = _activeTasks.isNotEmpty ? _activeTasks.first : null;
    // Tasks shown in AnimatedList = all active except topPriority (index 0).
    final listTasks = _activeTasks.length > 1
        ? _activeTasks.sublist(1)
        : <TaskModel>[];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Focus card (top priority, black) ─────────────────────────
          if (topPriority != null) ...[
            _FocusBentoCard(
              task: topPriority,
              onComplete: () => _handleComplete(0, topPriority),
            ),
            const SizedBox(height: 16),
          ],

          // ── Animated task list ────────────────────────────────────────
          if (listTasks.isNotEmpty) ...[
            Text('TASKS', style: AsrioText.label),
            const SizedBox(height: 10),
            AnimatedList(
              key: _listKey,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              initialItemCount: listTasks.length,
              itemBuilder: (context, index, animation) {
                // index here maps into listTasks (which is _activeTasks[1..]).
                if (index >= listTasks.length) return const SizedBox.shrink();
                final task = listTasks[index];
                return SizeTransition(
                  sizeFactor: CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ),
                  child: FadeTransition(
                    opacity: CurvedAnimation(
                      parent: animation,
                      curve: const Interval(0.3, 1.0),
                    ),
                    child: _TaskCard(
                      task: task,
                      // +1 offset because _activeTasks[0] is topPriority.
                      onComplete: (t) => _handleComplete(index + 1, t),
                      onDelete: (t) => _handleDelete(index + 1, t),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
          ],

          // ── Completed section ─────────────────────────────────────────
          if (completed.isNotEmpty) ...[
            Text('COMPLETED', style: AsrioText.label),
            const SizedBox(height: 10),
            ...completed.map((t) => _CompletedTaskRow(task: t)),
          ],

          // ── Empty state ───────────────────────────────────────────────
          if (widget.tasks.isEmpty) _EmptyState(),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Focus Bento Card — with ScaleTransition on completion
// ══════════════════════════════════════════════════════════════════════════════

class _FocusBentoCard extends ConsumerStatefulWidget {
  const _FocusBentoCard({
    required this.task,
    required this.onComplete,
  });
  final TaskModel task;
  final VoidCallback onComplete;

  @override
  ConsumerState<_FocusBentoCard> createState() => _FocusBentoCardState();
}

class _FocusBentoCardState extends ConsumerState<_FocusBentoCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnim;
  bool _completing = false;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.94).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  Future<void> _handleComplete() async {
    if (_completing) return;
    _completing = true;

    // Scale down.
    await _scaleController.forward();
    await Future.delayed(const Duration(milliseconds: 80));

    // Trigger the remove animation in the parent and DB write.
    widget.onComplete();

    // Scale back (the card is about to be removed, but if it lingers, it bounces).
    if (mounted) _scaleController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnim,
      child: BentoCard.black(
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.bolt_rounded,
                        color: AsrioColors.white, size: 13),
                    const SizedBox(width: 5),
                    Text('PRIORITY ONE', style: AsrioText.labelWhite),
                  ]),
                  const SizedBox(height: 10),
                  Text(widget.task.title,
                      style: AsrioText.cardTitleWhite,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  if (widget.task.dueDate != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Due ${DateFormat("d MMM").format(widget.task.dueDate!)}',
                      style: AsrioText.caption
                          .copyWith(color: AsrioColors.muted),
                    ),
                  ],
                ],
              ),
            ),
            // Animated checkmark button.
            GestureDetector(
              onTap: _handleComplete,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _completing
                      ? AsrioColors.white
                      : AsrioColors.white.withAlpha(25),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AsrioColors.white.withAlpha(80),
                    width: 1,
                  ),
                ),
                child: Icon(
                  Icons.check_rounded,
                  color: _completing ? AsrioColors.black : AsrioColors.white,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Task Card — animated checkbox
// ══════════════════════════════════════════════════════════════════════════════

class _TaskCard extends StatefulWidget {
  const _TaskCard({
    required this.task,
    required this.onComplete,
    required this.onDelete,
  });
  final TaskModel task;
  final ValueChanged<TaskModel> onComplete;
  final ValueChanged<TaskModel> onDelete;

  @override
  State<_TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends State<_TaskCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _checkController;
  late Animation<double> _checkAnim;

  @override
  void initState() {
    super.initState();
    _checkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _checkAnim = CurvedAnimation(
      parent: _checkController,
      curve: Curves.easeOutBack,
    );
  }

  @override
  void dispose() {
    _checkController.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    HapticFeedback.selectionClick();
    await _checkController.forward();
    await Future.delayed(const Duration(milliseconds: 100));
    widget.onComplete(widget.task);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Dismissible(
        key: Key('task_${widget.task.id}'),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: AsrioColors.black,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(Icons.delete_outline_rounded,
              color: AsrioColors.white, size: 22),
        ),
        confirmDismiss: (_) async {
          HapticFeedback.heavyImpact();
          return true;
        },
        onDismissed: (_) => widget.onDelete(widget.task),
        child: BentoCard.white(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              // Animated circular checkbox.
              GestureDetector(
                onTap: _handleTap,
                child: AnimatedBuilder(
                  animation: _checkAnim,
                  builder: (_, __) {
                    final filled = _checkController.value > 0.5;
                    return Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: filled ? AsrioColors.black : Colors.transparent,
                        border: Border.all(
                          color: filled
                              ? AsrioColors.black
                              : AsrioColors.border,
                          width: 1.5,
                        ),
                      ),
                      child: filled
                          ? const Icon(Icons.check_rounded,
                              size: 13, color: AsrioColors.white)
                          : null,
                    );
                  },
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  widget.task.title,
                  style: AsrioText.taskTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (widget.task.priority != TaskPriority.none)
                Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.only(left: 8),
                  decoration: const BoxDecoration(
                    color: AsrioColors.black,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Completed Task Row ────────────────────────────────────────────────────────

class _CompletedTaskRow extends StatelessWidget {
  const _CompletedTaskRow({required this.task});
  final TaskModel task;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded,
              size: 18, color: AsrioColors.muted),
          const SizedBox(width: 12),
          Expanded(
            child: Text(task.title,
                style: AsrioText.taskTitleCompleted,
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

// ── Add Task FAB ──────────────────────────────────────────────────────────────

class _AddTaskFab extends ConsumerWidget {
  const _AddTaskFab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => _AddTaskSheet(ref: ref),
        );
      },
      child: Container(
        width: 52,
        height: 52,
        decoration: const BoxDecoration(
          color: AsrioColors.black,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.add_rounded,
            color: AsrioColors.white, size: 26),
      ),
    );
  }
}

// ── Add Task Bottom Sheet ─────────────────────────────────────────────────────

class _AddTaskSheet extends StatefulWidget {
  const _AddTaskSheet({required this.ref});
  final WidgetRef ref;

  @override
  State<_AddTaskSheet> createState() => _AddTaskSheetState();
}

class _AddTaskSheetState extends State<_AddTaskSheet> {
  final _controller = TextEditingController();
  TaskPriority _priority = TaskPriority.none;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_controller.text.trim().isEmpty) return;
    HapticFeedback.mediumImpact();
    widget.ref.read(taskNotifierProvider.notifier).addTask(
          title: _controller.text.trim(),
          priority: _priority,
        );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AsrioColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 3,
                decoration: BoxDecoration(
                  color: AsrioColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text('New Task', style: AsrioText.cardTitle),
            const SizedBox(height: 20),
            TextField(
              controller: _controller,
              autofocus: true,
              style: AsrioText.body,
              maxLines: null,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                hintText: 'What needs to be done?',
                hintStyle: AsrioText.bodyMuted,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: TaskPriority.values
                  .map((p) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () => setState(() => _priority = p),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: _priority == p
                                  ? AsrioColors.black
                                  : AsrioColors.offWhite,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _priority == p
                                    ? AsrioColors.black
                                    : AsrioColors.border,
                                width: 0.8,
                              ),
                            ),
                            child: Text(
                              p.name[0].toUpperCase() + p.name.substring(1),
                              style: AsrioText.label.copyWith(
                                color: _priority == p
                                    ? AsrioColors.white
                                    : AsrioColors.secondary,
                              ),
                            ),
                          ),
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: GestureDetector(
                onTap: _submit,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: AsrioColors.black,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: Text('Add Task',
                      style: AsrioText.cardTitleWhite
                          .copyWith(fontSize: 15)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Empty State ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Column(
          children: [
            const Icon(Icons.check_circle_outline_rounded,
                size: 48, color: AsrioColors.muted),
            const SizedBox(height: 16),
            Text('Nothing to do.', style: AsrioText.cardTitle),
            const SizedBox(height: 6),
            Text('Tap + to add your first task.',
                style: AsrioText.bodyMuted),
          ],
        ),
      ),
    );
  }
}
