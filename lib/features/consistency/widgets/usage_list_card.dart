// lib/features/consistency/widgets/usage_list_card.dart
//
// Ranked app usage list — reference image style, strictly B/W.
// Thin notebook dividers between rows. Progress bar per app.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/asrio_colors.dart';
import '../../../core/theme/asrio_text_styles.dart';
import '../../../data/models/app_usage_model.dart';
import '../../../data/services/app_usage_service.dart';
import '../../../providers/consistency_provider.dart';
import '../../shared/widgets/bento_card.dart';

class UsageListCard extends ConsumerWidget {
  const UsageListCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(consistencyStateProvider);

    // ── Permission not granted ────────────────────────────────────────────
    if (state.needsUsagePermission) {
      return _PermissionCard(
        onGrant: () async {
          await AppUsageService().openPermissionSettings();
        },
      );
    }

    // ── Loading ───────────────────────────────────────────────────────────
    if (state.appUsageStats.isLoading) {
      return const BentoCard.white(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Screen Time', style: AsrioText.cardTitle),
            SizedBox(height: 20),
            Center(
              child: CircularProgressIndicator(
                  color: AsrioColors.black, strokeWidth: 2),
            ),
            SizedBox(height: 20),
          ],
        ),
      );
    }

    final apps = state.appUsageStats.valueOrNull ?? [];

    // ── No data ───────────────────────────────────────────────────────────
    if (apps.isEmpty) {
      return const BentoCard.white(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Screen Time', style: AsrioText.cardTitle),
            SizedBox(height: 16),
            Text('No usage data for today yet.',
                style: AsrioText.bodyMuted),
          ],
        ),
      );
    }

    // ── Compute total ─────────────────────────────────────────────────────
    final totalMs    = apps.fold<int>(0, (acc, a) => acc + a.durationMs);
    final totalModel = AppUsageModel(
      packageName: '__total__',
      appName:     'Total',
      durationMs:  totalMs,
      percentage:  1.0,
    );

    return BentoCard.white(
      padding: const EdgeInsets.all(0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Screen Time', style: AsrioText.cardTitle),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(totalModel.formattedDuration,
                        style: AsrioText.cardTitle.copyWith(
                            fontWeight: FontWeight.w800)),
                    const Text('TODAY', style: AsrioText.label),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          const Divider(
              color: AsrioColors.border, height: 1, thickness: 0.8),

          // ── App Rows ────────────────────────────────────────────────
          ...apps.asMap().entries.map((entry) {
            final i   = entry.key;
            final app = entry.value;
            return Column(
              children: [
                _AppUsageRow(app: app),
                if (i < apps.length - 1)
                  const Divider(
                      color: AsrioColors.border,
                      height: 1,
                      thickness: 0.8,
                      indent: 20,
                      endIndent: 20),
              ],
            );
          }),

          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

// ── App Usage Row ─────────────────────────────────────────────────────────────

class _AppUsageRow extends StatelessWidget {
  const _AppUsageRow({required this.app});
  final AppUsageModel app;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  app.appName,
                  style: AsrioText.taskTitle,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),
              Text(app.formattedDuration,
                  style: AsrioText.taskTitle.copyWith(
                      fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              SizedBox(
                width: 36,
                child: Text(
                  app.formattedPercentage,
                  textAlign: TextAlign.right,
                  style: AsrioText.caption,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Thin progress bar
          LayoutBuilder(
            builder: (_, constraints) => Stack(
              children: [
                // Track
                Container(
                  height: 3,
                  width: constraints.maxWidth,
                  decoration: BoxDecoration(
                    color: AsrioColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Fill
                AnimatedContainer(
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOutCubic,
                  height: 3,
                  width: constraints.maxWidth * app.percentage,
                  decoration: BoxDecoration(
                    color: AsrioColors.black,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Permission Card ───────────────────────────────────────────────────────────

class _PermissionCard extends StatelessWidget {
  const _PermissionCard({required this.onGrant});
  final VoidCallback onGrant;

  @override
  Widget build(BuildContext context) {
    return BentoCard.white(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.phone_android_outlined,
                  size: 24, color: AsrioColors.black),
              SizedBox(width: 12),
              Text('Screen Time', style: AsrioText.cardTitle),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Allow ASRIO to see your app usage to show screen time insights.',
            style: AsrioText.bodyMuted,
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: onGrant,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: AsrioColors.black,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('Grant Access',
                  style: AsrioText.label
                      .copyWith(color: AsrioColors.white)),
            ),
          ),
        ],
      ),
    );
  }
}
