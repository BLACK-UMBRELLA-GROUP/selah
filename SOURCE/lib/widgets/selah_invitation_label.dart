import 'package:flutter/material.dart';

import '../theme/selah_colors.dart';

/// Feedback only. Sending, cancelling and permission checks belong to the
/// caller; animation completion never changes state or navigation.
class SelahInvitationLabel extends StatelessWidget {
  const SelahInvitationLabel({
    super.key,
    required this.label,
    required this.sent,
    required this.style,
    this.maxLines,
    this.overflow,
  });

  final String label;
  final bool sent;
  final TextStyle style;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    final quiet =
        MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context);
    return ExcludeSemantics(
      child: AnimatedSwitcher(
        duration: quiet ? Duration.zero : const Duration(milliseconds: 220),
        reverseDuration: quiet
            ? Duration.zero
            : const Duration(milliseconds: 180),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: AnimatedBuilder(
            animation: animation,
            child: child,
            builder: (context, child) => Transform.translate(
              offset: Offset(0, 3 * (1 - animation.value)),
              child: child,
            ),
          ),
        ),
        child: Text(
          label,
          key: ValueKey((label, sent)),
          textAlign: TextAlign.center,
          maxLines: maxLines,
          overflow: overflow,
          style: sent ? style.copyWith(color: SelahColors.journeyGold) : style,
        ),
      ),
    );
  }
}
