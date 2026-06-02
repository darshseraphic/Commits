// lib/features/consistency/widgets/range_switcher.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/asrio_colors.dart';
import '../../../core/theme/asrio_text_styles.dart';
import '../../../providers/consistency_provider.dart';

class RangeSwitcher extends ConsumerWidget {
  const RangeSwitcher({super.key});

  static const _ranges = [
    _RangeOption(days: 7,   label: '7D'),
    _RangeOption(days: 30,  label: '30D'),
    _RangeOption(days: 90,  label: '3M'),
    _RangeOption(days: 365, label: 'Year'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedRangeProvider);

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AsrioColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AsrioColors.border, width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: _ranges.map((r) {
          final isSelected = r.days == selected;
          return GestureDetector(
            onTap: () {
              if (isSelected) return;
              HapticFeedback.selectionClick();
              ref.read(selectedRangeProvider.notifier).state = r.days;
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: isSelected ? AsrioColors.black : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                r.label,
                style: AsrioText.label.copyWith(
                  color: isSelected ? AsrioColors.white : AsrioColors.secondary,
                  fontWeight: isSelected
                      ? FontWeight.w700
                      : FontWeight.w500,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _RangeOption {
  const _RangeOption({required this.days, required this.label});
  final int days;
  final String label;
}
