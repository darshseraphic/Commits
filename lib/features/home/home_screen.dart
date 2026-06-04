// lib/features/home/home_screen.dart — Phase 7 fix
// Centred greeting, no profile icon, SafeArea, no emojis

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/asrio_colors.dart';
import '../../core/theme/asrio_text_styles.dart';
import '../../data/models/habit_model.dart';
import '../../providers/consistency_provider.dart';
import '../../providers/task_provider.dart';
import '../shared/widgets/bento_card.dart';
import '../shared/widgets/circular_ring.dart';
import 'widgets/mood_card.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allTasks = ref.watch(watchAllTasksProvider);
    final streak   = ref.watch(streakProvider);

    return Scaffold(
      backgroundColor: AsrioColors.offWhite,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ── Greeting (centred, no icon) ───────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                child: _GreetingHeader(),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            // ── Focus Card ────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: allTasks.when(
                  data: (tasks) {
                    final active = tasks
                        .where((t) => !t.isCompleted)
                        .toList()
                      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
                    return _FocusCard(
                      title: active.isEmpty
                          ? 'No tasks yet'
                          : active.first.title,
                    );
                  },
                  loading: () => const _FocusCard(title: '...'),
                  error:   (_, __) => const _FocusCard(title: 'Could not load'),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            // ── Mood Card ─────────────────────────────────────────────
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: MoodCard(),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            // ── Bento Grid ────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: allTasks.when(
                  data:    (t) => _BentoGrid(tasks: t),
                  loading: () => const _GridSkeleton(),
                  error:   (_, __) => const SizedBox.shrink(),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            // ── Quick Stats ───────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: streak.when(
                  data:    (s) => _QuickStats(streak: s),
                  loading: () => const _StatsSkeleton(),
                  error:   (_, __) => const SizedBox.shrink(),
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

// ── Greeting — centred, no profile icon ──────────────────────────────────────

class _GreetingHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final h = DateTime.now().hour;
    final greeting = h < 12 ? 'Good morning'
        : h < 17 ? 'Good afternoon'
        : 'Good evening';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(greeting, style: AsrioText.greeting),
        const SizedBox(height: 2),
        Text(
          DateFormat('EEEE, d MMMM').format(DateTime.now()),
          style: AsrioText.bodyMuted,
        ),
      ],
    );
  }
}

// ── Focus Card ────────────────────────────────────────────────────────────────

class _FocusCard extends StatelessWidget {
  const _FocusCard({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return BentoCard.black(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.bolt_rounded, color: AsrioColors.white, size: 13),
            SizedBox(width: 6),
            Text('CURRENT FOCUS', style: AsrioText.labelWhite),
          ]),
          const SizedBox(height: 12),
          Text(title,
              style: AsrioText.cardTitleWhite,
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AsrioColors.white.withAlpha(25),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('Top Priority',
                style: AsrioText.caption
                    .copyWith(color: AsrioColors.white)),
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
    final active    = tasks.where((t) => !t.isCompleted).take(4).toList();
    final completed = tasks.where((t) => t.isCompleted).length;
    final total     = tasks.length;
    final progress  = total == 0 ? 0.0 : completed / total;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: (MediaQuery.of(context).size.width - 52) * 0.40,
            child: Column(children: [
              BentoCard.white(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircularRing(progress: progress, size: 44, strokeWidth: 2.5),
                    const SizedBox(height: 10),
                    const Text('Progress', style: AsrioText.taskTitle),
                    Text('${(progress * 100).toInt()}%',
                        style: AsrioText.cardTitle),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              BentoCard.black(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$completed',
                        style: AsrioText.streakHero.copyWith(fontSize: 32)),
                    const SizedBox(height: 4),
                    const Text('done', style: AsrioText.labelWhite),
                  ],
                ),
              ),
            ]),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: BentoCard.white(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Upcoming', style: AsrioText.cardTitle),
                  const SizedBox(height: 12),
                  if (active.isEmpty)
                    const Text('All clear', style: AsrioText.bodyMuted)
                  else
                    ...active.map((t) => _MiniRow(title: t.title as String)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniRow extends StatelessWidget {
  const _MiniRow({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 4, height: 4,
              margin: const EdgeInsets.only(top: 6, right: 8),
              decoration: const BoxDecoration(
                color: AsrioColors.black, shape: BoxShape.circle),
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

class _GridSkeleton extends StatelessWidget {
  const _GridSkeleton();
  @override
  Widget build(BuildContext context) => const SizedBox(height: 160);
}

// ── Quick Stats ───────────────────────────────────────────────────────────────

class _QuickStats extends StatelessWidget {
  const _QuickStats({required this.streak});
  final StreakModel streak;

  @override
  Widget build(BuildContext context) {
    final spots = List.generate(7, (i) {
      final day = DateTime.now().subtract(Duration(days: 6 - i));
      final key = DateTime(day.year, day.month, day.day);
      return FlSpot(i.toDouble(),
          streak.activeDates.contains(key) ? 1.0 : 0.0);
    });

    return BentoCard.white(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('7-Day Streak', style: AsrioText.cardTitle),
              Text('${streak.currentStreak} days',
                  style: AsrioText.label
                      .copyWith(color: AsrioColors.black)),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 48,
            child: LineChart(
              LineChartData(
                minY: -0.1, maxY: 1.3,
                gridData:   const FlGridData(show: false),
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
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AsrioColors.black.withAlpha(15),
                    ),
                  ),
                ],
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
  Widget build(BuildContext context) => const SizedBox(height: 80);
}
