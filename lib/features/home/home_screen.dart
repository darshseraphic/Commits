// lib/features/home/home_screen.dart
//
// ══════════════════════════════════════════════════════════════════════════════
// Home Screen — Bento Dashboard
// ══════════════════════════════════════════════════════════════════════════════
//
// Layout (top → bottom):
//   1. Greeting header    — "Good morning, Darsh" + notification icon
//   2. Focus Card (black) — highest-priority task from DB
//   3. Bento Grid         — Masonry: left col (habit tile) + right col (tasks)
//   4. Quick Stats card   — 7-day streak mini line chart
// ══════════════════════════════════════════════════════════════════════════════

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/asrio_colors.dart';
import '../../core/theme/asrio_text_styles.dart';
import '../../providers/consistency_provider.dart';
import '../../data/models/habit_model.dart';
import '../../providers/task_provider.dart';
import '../shared/widgets/bento_card.dart';
import '../shared/widgets/circular_ring.dart';
import 'widgets/mood_card.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allTasks = ref.watch(watchAllTasksProvider);
    final streak = ref.watch(streakProvider);

    return Scaffold(
      backgroundColor: AsrioColors.offWhite,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ── Greeting Header ──────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                child: _GreetingHeader(),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            // ── Focus Card ────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: allTasks.when(
                  data: (tasks) {
                    final priority = tasks
                        .where((t) => !t.isCompleted)
                        .toList()
                      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
                    return _FocusCard(
                      taskTitle: priority.isEmpty
                          ? 'No tasks yet. Add one below.'
                          : priority.first.title,
                    );
                  },
                  loading: () => _FocusCard(taskTitle: 'Loading...'),
                  error: (_, __) => _FocusCard(taskTitle: 'Could not load tasks.'),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            // ── Mood Card ─────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: const MoodCard(),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            // ── Bento Grid ────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: allTasks.when(
                  data: (tasks) => _BentoGrid(tasks: tasks),
                  loading: () => const _BentoGridSkeleton(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            // ── Quick Stats ───────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: streak.when(
                  data: (s) => _QuickStatsCard(streakModel: s),
                  loading: () => const _StatsSkeleton(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }
}

// ── Greeting Header ───────────────────────────────────────────────────────────

class _GreetingHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(greeting, style: AsrioText.greeting),
              const SizedBox(height: 2),
              Text(
                DateFormat('EEEE, d MMMM').format(DateTime.now()),
                style: AsrioText.bodyMuted,
              ),
            ],
          ),
        ),
        // Settings/profile icon
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AsrioColors.white,
            shape: BoxShape.circle,
            border: Border.all(color: AsrioColors.border, width: 0.8),
          ),
          child: const Icon(Icons.person_outline_rounded,
              size: 20, color: AsrioColors.black),
        ),
      ],
    );
  }
}

// ── Focus Card (Black Hero) ───────────────────────────────────────────────────

class _FocusCard extends StatelessWidget {
  const _FocusCard({required this.taskTitle});
  final String taskTitle;

  @override
  Widget build(BuildContext context) {
    return BentoCard.black(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bolt_rounded,
                  color: AsrioColors.white, size: 14),
              const SizedBox(width: 6),
              Text('CURRENT FOCUS', style: AsrioText.labelWhite),
            ],
          ),
          const SizedBox(height: 12),
          Text(taskTitle,
              style: AsrioText.cardTitleWhite,
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AsrioColors.white.withAlpha(25),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('Top Priority',
                    style: AsrioText.caption.copyWith(color: AsrioColors.white)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Bento Grid ────────────────────────────────────────────────────────────────

class _BentoGrid extends StatelessWidget {
  const _BentoGrid({required this.tasks});
  final List tasks;

  @override
  Widget build(BuildContext context) {
    final active = tasks.where((t) => !t.isCompleted).take(4).toList();
    final completedToday =
        tasks.where((t) => t.isCompleted).length;
    final total = tasks.length;
    final progress = total == 0 ? 0.0 : completedToday / total;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Left column (shorter) ──────────────────────────────────────
          SizedBox(
            width: (MediaQuery.of(context).size.width - 48) * 0.42,
            child: Column(
              children: [
                // Habit / Progress tile
                BentoCard.white(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircularRing(
                        progress: progress,
                        size: 48,
                        strokeWidth: 3,
                      ),
                      const SizedBox(height: 12),
                      Text('Daily\nProgress',
                          style: AsrioText.taskTitle),
                      const SizedBox(height: 4),
                      Text(
                        '${(progress * 100).toInt()}%',
                        style: AsrioText.cardTitle,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Completed count tile (black)
                BentoCard.black(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$completedToday',
                          style: AsrioText.streakHero.copyWith(fontSize: 36)),
                      const SizedBox(height: 4),
                      Text('done\ntoday', style: AsrioText.labelWhite),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // ── Right column (taller — task list) ─────────────────────────
          Expanded(
            child: BentoCard.white(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Upcoming', style: AsrioText.cardTitle),
                  const SizedBox(height: 12),
                  if (active.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text('All done for today 🎉',
                          style: AsrioText.bodyMuted),
                    )
                  else
                    ...active.map((t) => _MiniTaskRow(title: t.title)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniTaskRow extends StatelessWidget {
  const _MiniTaskRow({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 5,
            height: 5,
            margin: const EdgeInsets.only(top: 5, right: 8),
            decoration: const BoxDecoration(
              color: AsrioColors.black,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Text(title,
                style: AsrioText.taskTitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

class _BentoGridSkeleton extends StatelessWidget {
  const _BentoGridSkeleton();

  @override
  Widget build(BuildContext context) => const SizedBox(height: 160);
}

// ── Quick Stats Card ──────────────────────────────────────────────────────────

class _QuickStatsCard extends StatelessWidget {
  const _QuickStatsCard({required this.streakModel});
  final StreakModel streakModel;

  @override
  Widget build(BuildContext context) {
    return BentoCard.white(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('7-Day Streak', style: AsrioText.cardTitle),
              Row(
                children: [
                  const Icon(Icons.local_fire_department_rounded,
                      size: 16, color: AsrioColors.black),
                  const SizedBox(width: 4),
                  Text('${streakModel.currentStreak} days',
                      style: AsrioText.label
                          .copyWith(color: AsrioColors.black)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 56,
            child: _MiniLineChart(activeDates: streakModel.activeDates),
          ),
        ],
      ),
    );
  }
}

class _MiniLineChart extends StatelessWidget {
  const _MiniLineChart({required this.activeDates});
  final Set<DateTime> activeDates;

  @override
  Widget build(BuildContext context) {
    // Build 7 data points: 1 = active, 0 = inactive.
    final spots = List.generate(7, (i) {
      final day = DateTime.now().subtract(Duration(days: 6 - i));
      final key = DateTime(day.year, day.month, day.day);
      return FlSpot(i.toDouble(), activeDates.contains(key) ? 1.0 : 0.0);
    });

    return LineChart(
      LineChartData(
        minY: -0.1,
        maxY: 1.3,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: const FlTitlesData(show: false),
        lineTouchData: const LineTouchData(enabled: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.4,
            color: AsrioColors.black,
            barWidth: 2,
            dotData: FlDotData(
              show: true,
              getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                radius: 3,
                color: AsrioColors.black,
                strokeWidth: 0,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: const LinearGradient(
                colors: [AsrioColors.chartFillTop, AsrioColors.chartFillBottom],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsSkeleton extends StatelessWidget {
  const _StatsSkeleton();

  @override
  Widget build(BuildContext context) => const SizedBox(height: 100);
}
