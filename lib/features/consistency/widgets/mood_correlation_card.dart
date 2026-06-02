// lib/features/consistency/widgets/mood_correlation_card.dart
//
// Dual-line fl_chart: solid black = task completion %, dashed grey = mood score.
// Gaps shown honestly where mood data is sparse — no interpolation.

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/asrio_colors.dart';
import '../../../core/theme/asrio_text_styles.dart';
import '../../../data/models/mood_model.dart';
import '../../../providers/consistency_provider.dart';
import '../../../providers/task_provider.dart';
import '../../shared/widgets/bento_card.dart';

class MoodCorrelationCard extends ConsumerWidget {
  const MoodCorrelationCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range       = ref.watch(selectedRangeProvider);
    final moodHistory = ref.watch(moodHistoryForChartProvider);
    final allTasks    = ref.watch(watchAllTasksProvider);

    return moodHistory.when(
      loading: () => const _CardSkeleton(),
      error:   (_, __) => const SizedBox.shrink(),
      data: (moods) {
        if (moods.isEmpty) return const _EmptyCorrelation();

        final tasks  = allTasks.valueOrNull ?? [];
        final points = _buildPoints(moods, tasks, range);

        return BentoCard.white(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Mood & Output', style: AsrioText.cardTitle),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _LegendItem(
                        color: AsrioColors.black,
                        label: 'Output',
                        dashed: false,
                      ),
                      const SizedBox(height: 4),
                      _LegendItem(
                        color: AsrioColors.muted,
                        label: 'Mood',
                        dashed: true,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Chart
              SizedBox(
                height: 140,
                child: LineChart(
                  LineChartData(
                    minY: 0,
                    maxY: 1.1,
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
                          interval: (range / 4).ceilToDouble(),
                          getTitlesWidget: (val, _) {
                            final day = DateTime.now()
                                .subtract(Duration(
                                    days: (range - val.toInt())));
                            return Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                DateFormat('d/M').format(day),
                                style: AsrioText.caption,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipColor: (_) => AsrioColors.black,
                        getTooltipItems: (spots) => spots.map((s) {
                          final label = s.barIndex == 0 ? 'Output' : 'Mood';
                          return LineTooltipItem(
                            '$label: ${(s.y * 100).round()}%',
                            AsrioText.caption
                                .copyWith(color: AsrioColors.white),
                          );
                        }).toList(),
                      ),
                    ),
                    lineBarsData: [
                      // Line 1: Task completion (solid black)
                      LineChartBarData(
                        spots: points.taskSpots,
                        isCurved: true,
                        curveSmoothness: 0.35,
                        color: AsrioColors.black,
                        barWidth: 2.5,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          color: AsrioColors.black.withAlpha(12),
                        ),
                      ),
                      // Line 2: Mood score (dashed grey)
                      LineChartBarData(
                        spots: points.moodSpots,
                        isCurved: true,
                        curveSmoothness: 0.35,
                        color: AsrioColors.muted,
                        barWidth: 1.5,
                        dashArray: [6, 4],
                        dotData: const FlDotData(show: false),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  _ChartPoints _buildPoints(
    List<MoodEntry> moods,
    List tasks,
    int rangeDays,
  ) {
    final taskSpots = <FlSpot>[];
    final moodSpots = <FlSpot>[];

    // Build mood lookup: dateOnly → normalised score (0–1)
    final moodMap = <DateTime, double>{};
    for (final m in moods) {
      final key = DateTime(m.loggedAt.year, m.loggedAt.month, m.loggedAt.day);
      moodMap[key] = (m.position - 1) / 4.0; // 1–5 → 0.0–1.0
    }

    for (int i = 0; i < rangeDays; i++) {
      final day = DateTime.now().subtract(Duration(days: rangeDays - 1 - i));
      final key = DateTime(day.year, day.month, day.day);
      final x   = i.toDouble();

      // Task completion for this day
      final dayTasks    = tasks.where((t) {
        final c = t.createdAt as DateTime;
        return c.year == day.year && c.month == day.month && c.day == day.day;
      }).toList();
      final total     = dayTasks.length;
      final completed = dayTasks.where((t) => t.isCompleted == true).length;
      final taskScore = total == 0 ? 0.0 : completed / total;
      taskSpots.add(FlSpot(x, taskScore));

      // Mood — only add spot if data exists (no interpolation for missing days)
      if (moodMap.containsKey(key)) {
        moodSpots.add(FlSpot(x, moodMap[key]!));
      }
    }

    return _ChartPoints(taskSpots: taskSpots, moodSpots: moodSpots);
  }
}

class _ChartPoints {
  const _ChartPoints({required this.taskSpots, required this.moodSpots});
  final List<FlSpot> taskSpots;
  final List<FlSpot> moodSpots;
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.color,
    required this.label,
    required this.dashed,
  });
  final Color color;
  final String label;
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 20,
          child: CustomPaint(
            size: const Size(20, 2),
            painter: _LinePainter(color: color, dashed: dashed),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: AsrioText.caption),
      ],
    );
  }
}

class _LinePainter extends CustomPainter {
  const _LinePainter({required this.color, required this.dashed});
  final Color color;
  final bool dashed;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    if (!dashed) {
      canvas.drawLine(Offset.zero, Offset(size.width, 0), paint);
      return;
    }

    double x = 0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 0), Offset(x + 4, 0), paint);
      x += 7;
    }
  }

  @override
  bool shouldRepaint(_LinePainter old) => false;
}

class _EmptyCorrelation extends StatelessWidget {
  const _EmptyCorrelation();

  @override
  Widget build(BuildContext context) {
    return BentoCard.white(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Mood & Output', style: AsrioText.cardTitle),
          const SizedBox(height: 12),
          Text(
            'Log your mood on the home screen to see how it correlates with your productivity.',
            style: AsrioText.bodyMuted,
          ),
        ],
      ),
    );
  }
}

class _CardSkeleton extends StatelessWidget {
  const _CardSkeleton();

  @override
  Widget build(BuildContext context) => Container(
        height: 200,
        decoration: BoxDecoration(
          color: AsrioColors.border,
          borderRadius: BorderRadius.circular(20),
        ),
      );
}
