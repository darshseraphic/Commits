// lib/features/shared/widgets/bento_card.dart
//
// ══════════════════════════════════════════════════════════════════════════════
// BentoCard — The Foundation Component
// ══════════════════════════════════════════════════════════════════════════════
//
// Two variants:
//   BentoCard.black — Pure black surface, white text (focus/hero items)
//   BentoCard.white — White surface, thin border, black text (list items)
//
// All radius, padding, and shadow values are defined here.
// Every screen uses these — never hardcodes Card properties directly.
// ══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import '../../../core/theme/asrio_colors.dart';

enum BentoVariant { black, white, offWhite }

class BentoCard extends StatelessWidget {
  const BentoCard({
    super.key,
    required this.child,
    this.variant = BentoVariant.white,
    this.padding = const EdgeInsets.all(20),
    this.onTap,
    this.borderRadius = 20,
    this.border = true,
  });

  // ── Named Constructors ────────────────────────────────────────────────────

  const BentoCard.black({
    Key? key,
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(20),
    VoidCallback? onTap,
    double borderRadius = 20,
  }) : this(
          key: key,
          child: child,
          variant: BentoVariant.black,
          padding: padding,
          onTap: onTap,
          borderRadius: borderRadius,
          border: false,
        );

  const BentoCard.white({
    Key? key,
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(20),
    VoidCallback? onTap,
    double borderRadius = 20,
  }) : this(
          key: key,
          child: child,
          variant: BentoVariant.white,
          padding: padding,
          onTap: onTap,
          borderRadius: borderRadius,
          border: true,
        );

  final Widget child;
  final BentoVariant variant;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final double borderRadius;
  final bool border;

  Color get _surface => switch (variant) {
        BentoVariant.black   => AsrioColors.black,
        BentoVariant.white   => AsrioColors.white,
        BentoVariant.offWhite => AsrioColors.offWhite,
      };

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);

    return Material(
      color: _surface,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        splashColor: variant == BentoVariant.black
            ? Colors.white.withAlpha(20)
            : Colors.black.withAlpha(10),
        highlightColor: Colors.transparent,
        borderRadius: radius,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: radius,
            border: border
                ? Border.all(color: AsrioColors.border, width: 0.8)
                : null,
          ),
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}
