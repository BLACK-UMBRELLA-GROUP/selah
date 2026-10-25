import 'package:flutter/material.dart';

import '../theme/selah_colors.dart';

/// Decorative feedback only. This never captures a tap or changes invitations.
/// The caller places it above the photo so a full-bleed image cannot hide it.
class SelahInvitationOutline extends StatelessWidget {
  const SelahInvitationOutline({
    super.key,
    required this.sent,
    required this.borderRadius,
  });

  final bool sent;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final quiet =
        MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context);
    Widget decoration(double value) => DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        border: Border.all(
          color: SelahColors.journeyGold.withValues(alpha: .65 * value),
          width: 5,
        ),
      ),
    );
    return IgnorePointer(
      child: ExcludeSemantics(
        // Bypass, rather than merely shorten, an already-running fade when
        // the member enables quiet motion with the same invitation state.
        child: quiet
            ? decoration(sent ? 1 : 0)
            : TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: sent ? 1 : 0),
                duration: Duration(milliseconds: sent ? 260 : 180),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) => decoration(value),
              ),
      ),
    );
  }
}
