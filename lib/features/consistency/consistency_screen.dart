// lib/features/consistency/consistency_screen.dart — Phase 5

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/asrio_colors.dart';
import '../../core/theme/asrio_text_styles.dart';
import '../../providers/consistency_provider.dart';
import '../shared/widgets/bento_card.dart';
import '../shared/widgets/circular_ring.dart';
import 'widgets/mood_correlation_card.dart';
import 'widgets/range_switcher.dart';
import 'widgets/usage_list_card.dart';

class ConsistencyScreen extends ConsumerWidget {
  const ConsistencyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(consistencyStateProvider);

    return Scaffold(
      backgroundColor: AsrioColors.offWhite,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ── Header + Range Switcher ────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Consistency', style: AsrioText.greeting),
                        const SizedBox(height: 4),
                        Text('Your performance report.',
                            style: AsrioText.bodyMuted),
                      ],
                    ),
                    const RangeSwitcher(),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            // ── Streak Hero (Black) ───────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _StreakHeroCard(
                  current: state.currentStreak,
                  longest: state.longestStreak,
                  total:   state.totalActiveDays,
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            // ── Growth Line Chart ─────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: state.dailyOpenCounts.when(
                  data: (counts) => _GrowthChartCard(
                    dailyCounts: counts,
                    range: state.selectedRange,
                  ),
                  loading: () => const _CardSkeleton(height: 200),
                  error:   (_, __) => const SizedBox.shrink(),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            // ── Screen Time Usage List ────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: const UsageListCard(),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            // ── Mood Correlation Chart ────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: const MoodCorrelationCard(),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            // ── Month Heatmap ─────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: state.activeDiaryDates.when(
                  data: (dates) => _HeatmapCard(activeDates: dates),
                  loading: () => const _CardSkeleton(height: 140),
                  error:   (_, __) => const SizedBox.shrink(),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            // ── Stats Row ─────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _StatsRow(
                  current: state.currentStreak,
                  longest: state.longestStreak,
                  total:   state.totalActiveDays,
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

// ── Streak Hero ───────────────────────────────────────────────────────────────

class _StreakHeroCard extends StatelessWidget {
  const _StreakHeroCard({
    required this.current,
    required this.longest,
    required this.total,
  });
  final int current;
  final int longest;
  final int total;

  @override
  Widget build(BuildContext context) {
    final progress =
        longest == 0 ? 0.0 : (current / longest).clamp(0.0, 1.0);

    return BentoCard.black(
      padding: const EdgeInsets.all(28),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$current', style: AsrioText.streakHero),
                const SizedBox(height: 4),
                Text('DAYS OF CONSISTENCY',
                    style: AsrioText.labelWhite),
                const SizedBox(height: 20),
                Text(
                  current == 0
                      ? 'Start your streak today.'
                      : "Keep going. Don't break the chain.",
                  style: AsrioText.bodyWhite.copyWith(fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          CircularRing(
            progress: progress,
            size: 88,
            strokeWidth: 3.5,
            ringColor: AsrioColors.white,
            trackColor: AsrioColors.white.withAlpha(40),
            child: Text(
              '${(progress * 100).toInt()}%',
              style: AsrioText.label.copyWith(
                color: AsrioColors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Growth Chart ──────────────────────────────────────────────────────────────

class _GrowthChartCard extends StatefulWidget {
  const _GrowthChartCard({
    required this.dailyCounts,
    required this.range,
  });
  final Map<DateTime, int> dailyCounts;
  final int range;

  @override
  State<_GrowthChartCard> createState() => _GrowthChartCardState();
}

class _GrowthChartCardState extends State<_GrowthChartCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    WidgetsBinding.instance.addPostFrameCallback((_) => _ctrl.forward());
  }

  @override
  void didUpdateWidget(_GrowthChartCard old) {
    super.didUpdateWidget(old);
    if (old.range != widget.range) {
      _ctrl.reset();
      _ctrl.forward();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spots = <FlSpot>[];
    for (int i = widget.range - 1; i >= 0; i--) {
      final day = DateTime.now().subtract(Duration(days: i));
      final key = DateTime(day.year, day.month, day.day);
      spots.add(FlSpot(
        (widget.range - 1 - i).toDouble(),
        (widget.dailyCounts[key] ?? 0).toDouble(),
      ));
    }

    return BentoCard.white(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Activity', style: AsrioText.cardTitle),
              Text('LAST ${widget.range}D', style: AsrioText.label),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 140,
            child: AnimatedBuilder(
              animation: _anim,
              builder: (_, __) => LineChart(
                LineChartData(
                  minY: 0,
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: (widget.range / 4).ceilToDouble(),
                        getTitlesWidget: (val, _) {
                          final day = DateTime.now().subtract(
                              Duration(
                                  days: widget.range - 1 - val.toInt()));
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(DateFormat('d/M').format(day),
                                style: AsrioText.caption),
                          );
                        },
                      ),
                    ),
                  ),
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (_) => AsrioColors.black,
                      getTooltipItems: (spots) => spots
                          .map((s) => LineTooltipItem(
                                '${s.y.toInt()} opens',
                                AsrioText.caption.copyWith(
                                    color: AsrioColors.white),
                              ))
                          .toList(),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      curveSmoothness: 0.35,
                      color: AsrioColors.black,
                      barWidth: 2.5,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: AsrioColors.black.withAlpha(
                            (25 * _anim.value).toInt()),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Month Heatmap ─────────────────────────────────────────────────────────────

class _HeatmapCard extends StatelessWidget {
  const _HeatmapCard({required this.activeDates});
  final Map<DateTime, bool> activeDates;

  @override
  Widget build(BuildContext context) {
    final now          = DateTime.now();
    final daysInMonth  = DateTime(now.year, now.month + 1, 0).day;
    final startWeekday = DateTime(now.year, now.month, 1).weekday % 7;

    return BentoCard.white(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('This Month', style: AsrioText.cardTitle),
              Text(
                DateFormat('MMMM yyyy').format(now).toUpperCase(),
                style: AsrioText.label,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: ['S', 'M', 'T', 'W', 'T', 'F', 'S']
                .map((d) => SizedBox(
                      width: 28,
                      child: Text(d,
                          textAlign: TextAlign.center,
                          style: AsrioText.caption),
                    ))
                .toList(),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              ...List.generate(startWeekday,
                  (_) => const SizedBox(width: 28, height: 28)),
              ...List.generate(daysInMonth, (i) {
                final day    = DateTime(now.year, now.month, i + 1);
                final key    = DateTime(day.year, day.month, day.day);
                final active = activeDates[key] ?? false;
                final isToday = day.day == now.day;

                return Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: active
                        ? AsrioColors.black
                        : isToday
                            ? AsrioColors.offWhite
                            : AsrioColors.border,
                    borderRadius: BorderRadius.circular(6),
                    border: isToday
                        ? Border.all(color: AsrioColors.black, width: 1.5)
                        : null,
                  ),
                  child: isToday
                      ? Center(
                          child: Text(
                            '${i + 1}',
                            style: AsrioText.caption.copyWith(
                              color: active
                                  ? AsrioColors.white
                                  : AsrioColors.black,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        )
                      : null,
                );
              }),
            ],
          ),
          const SizedBox(height: 12),
          Row(children: [
            _LegendDot(color: AsrioColors.border, label: 'No activity'),
            const SizedBox(width: 16),
            _LegendDot(color: AsrioColors.black,  label: 'Active'),
          ]),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 6),
          Text(label, style: AsrioText.caption),
        ],
      );
}

// ── Stats Row ─────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.current,
    required this.longest,
    required this.total,
  });
  final int current;
  final int longest;
  final int total;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
              child: _StatTile(value: '$current', label: 'Current\nStreak')),
          const SizedBox(width: 12),
          Expanded(
              child: _StatTile(value: '$longest', label: 'Longest\nStreak')),
          const SizedBox(width: 12),
          Expanded(
              child: _StatTile(value: '$total', label: 'Total\nActive Days')),
        ],
      );
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => BentoCard.white(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value,
                style: AsrioText.cardTitle.copyWith(
                    fontSize: 28, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(label, style: AsrioText.caption),
          ],
        ),
      );
}

class _CardSkeleton extends StatelessWidget {
  const _CardSkeleton({required this.height});
  final double height;

  @override
  Widget build(BuildContext context) => Container(
        height: height,
        decoration: BoxDecoration(
          color: AsrioColors.border,
          borderRadius: BorderRadius.circular(20),
        ),
      );
}
