// lib/features/consistency/consistency_screen.dart — Phase 7 fix
// Circular calendar cells, no marketing copy, compact cards

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/asrio_colors.dart';
import '../../core/theme/asrio_text_styles.dart';
import '../../data/models/habit_model.dart';
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

            // ── Header — no subtext ───────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text('Statistics', style: AsrioText.greeting),
                    const RangeSwitcher(),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            // ── Streak Hero ───────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _StreakHero(
                  current: state.currentStreak,
                  longest: state.longestStreak,
                  total:   state.totalActiveDays,
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            // ── Growth Chart ──────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: state.dailyOpenCounts.when(
                  data:    (c) => _GrowthChart(counts: c, range: state.selectedRange),
                  loading: () => const _Skeleton(height: 180),
                  error:   (_, __) => const SizedBox.shrink(),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            // ── Screen Time ───────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: const UsageListCard(),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            // ── Mood Correlation ──────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: const MoodCorrelationCard(),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            // ── Month Heatmap (CIRCULAR cells) ────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: state.activeDiaryDates.when(
                  data:    (d) => _Heatmap(activeDates: d),
                  loading: () => const _Skeleton(height: 140),
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

class _StreakHero extends StatelessWidget {
  const _StreakHero({
    required this.current,
    required this.longest,
    required this.total,
  });
  final int current, longest, total;

  @override
  Widget build(BuildContext context) {
    final pct = longest == 0 ? 0.0 : (current / longest).clamp(0.0, 1.0);
    return BentoCard.black(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$current', style: AsrioText.streakHero),
                const SizedBox(height: 2),
                Text('DAYS', style: AsrioText.labelWhite),
                const SizedBox(height: 16),
                Text(
                  current == 0
                      ? 'Start your streak today.'
                      : "Don't break the chain.",
                  style: AsrioText.bodyWhite.copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          CircularRing(
            progress: pct,
            size: 80,
            strokeWidth: 3,
            ringColor:  AsrioColors.white,
            trackColor: AsrioColors.white.withAlpha(35),
            child: Text(
              '${(pct * 100).toInt()}%',
              style: AsrioText.label.copyWith(
                color: AsrioColors.white,
                fontSize: 12,
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

class _GrowthChart extends StatefulWidget {
  const _GrowthChart({required this.counts, required this.range});
  final Map<DateTime, int> counts;
  final int range;

  @override
  State<_GrowthChart> createState() => _GrowthChartState();
}

class _GrowthChartState extends State<_GrowthChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>   _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    WidgetsBinding.instance.addPostFrameCallback((_) => _ctrl.forward());
  }

  @override
  void didUpdateWidget(_GrowthChart old) {
    super.didUpdateWidget(old);
    if (old.range != widget.range) { _ctrl.reset(); _ctrl.forward(); }
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final spots = <FlSpot>[];
    for (int i = widget.range - 1; i >= 0; i--) {
      final day = DateTime.now().subtract(Duration(days: i));
      final key = DateTime(day.year, day.month, day.day);
      spots.add(FlSpot(
        (widget.range - 1 - i).toDouble(),
        (widget.counts[key] ?? 0).toDouble(),
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
          const SizedBox(height: 20),
          SizedBox(
            height: 120,
            child: AnimatedBuilder(
              animation: _anim,
              builder: (_, __) => LineChart(
                LineChartData(
                  minY: 0,
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles:  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles:    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: (widget.range / 4).ceilToDouble(),
                        getTitlesWidget: (val, _) {
                          final day = DateTime.now().subtract(
                              Duration(days: widget.range - 1 - val.toInt()));
                          return Padding(
                            padding: const EdgeInsets.only(top: 5),
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
                      getTooltipItems: (s) => s.map((sp) =>
                        LineTooltipItem('${sp.y.toInt()} opens',
                            AsrioText.caption.copyWith(
                                color: AsrioColors.white))).toList(),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      curveSmoothness: 0.35,
                      color: AsrioColors.black,
                      barWidth: 2,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: AsrioColors.black
                            .withAlpha((20 * _anim.value).toInt()),
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

// ── Heatmap — CIRCULAR cells ─────────────────────────────────────────────────

class _Heatmap extends StatelessWidget {
  const _Heatmap({required this.activeDates});
  final Map<DateTime, bool> activeDates;

  @override
  Widget build(BuildContext context) {
    final now         = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final startWd     = DateTime(now.year, now.month, 1).weekday % 7;

    return BentoCard.white(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('This Month', style: AsrioText.cardTitle),
              Text(DateFormat('MMMM yyyy').format(now).toUpperCase(),
                  style: AsrioText.label),
            ],
          ),
          const SizedBox(height: 10),
          // Day-of-week labels
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: ['S','M','T','W','T','F','S']
                .map((d) => SizedBox(
                      width: 28,
                      child: Text(d,
                          textAlign: TextAlign.center,
                          style: AsrioText.caption),
                    ))
                .toList(),
          ),
          const SizedBox(height: 6),
          // ── CIRCULAR cells via BoxShape.circle ─────────────────────
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              ...List.generate(startWd,
                  (_) => const SizedBox(width: 28, height: 28)),
              ...List.generate(daysInMonth, (i) {
                final day    = DateTime(now.year, now.month, i + 1);
                final key    = DateTime(day.year, day.month, day.day);
                final active = activeDates[key] ?? false;
                final isToday = day.day == now.day;

                return Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    // CIRCULAR — changed from BorderRadius to BoxShape.circle
                    shape: BoxShape.circle,
                    color: active
                        ? AsrioColors.black
                        : isToday
                            ? AsrioColors.offWhite
                            : AsrioColors.border,
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
          const SizedBox(height: 10),
          Row(children: [
            _Dot(color: AsrioColors.border, label: 'No activity'),
            const SizedBox(width: 16),
            _Dot(color: AsrioColors.black,  label: 'Active'),
          ]),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color, required this.label});
  final Color color; final String label;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(label, style: AsrioText.caption),
        ],
      );
}

// ── Stats Row ─────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.current, required this.longest, required this.total});
  final int current, longest, total;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(child: _Tile(value: '$current', label: 'Current')),
          const SizedBox(width: 12),
          Expanded(child: _Tile(value: '$longest', label: 'Longest')),
          const SizedBox(width: 12),
          Expanded(child: _Tile(value: '$total',   label: 'Total Days')),
        ],
      );
}

class _Tile extends StatelessWidget {
  const _Tile({required this.value, required this.label});
  final String value, label;

  @override
  Widget build(BuildContext context) => BentoCard.white(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value,
                style: AsrioText.cardTitle
                    .copyWith(fontSize: 26, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(label, style: AsrioText.caption),
          ],
        ),
      );
}

class _Skeleton extends StatelessWidget {
  const _Skeleton({required this.height});
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
