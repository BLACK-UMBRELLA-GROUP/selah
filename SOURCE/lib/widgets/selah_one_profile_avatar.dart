import 'package:flutter/material.dart';

import '../data/selah_membership_catalog.dart';
import '../theme/selah_colors.dart';

/// The shared Profile avatar treatment. SELAH One is recognised with a quiet
/// gold ring; Basic keeps the same footprint without a decorative ring.
class SelahOneProfileAvatar extends StatelessWidget {
  const SelahOneProfileAvatar({
    super.key,
    required this.isOne,
    required this.child,
    this.shepherd = false,
  });

  final bool isOne;
  final Widget child;
  final bool shepherd;

  @override
  Widget build(BuildContext context) => Semantics(
    label: isOne
        ? '${shepherd ? SelahMembershipCatalog.shepherdOneTitle : SelahMembershipCatalog.seekerOneTitle} profile'
        : 'Profile',
    image: true,
    child: Container(
      key: const ValueKey('profile-membership-avatar'),
      width: 68,
      height: 68,
      padding: EdgeInsets.all(isOne ? 3 : 2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: isOne
            ? Border.all(color: SelahColors.journeyGold, width: 1.5)
            : null,
        boxShadow: isOne
            ? [
                BoxShadow(
                  color: SelahColors.journeyGold.withValues(alpha: 0.16),
                  blurRadius: 10,
                ),
              ]
            : null,
      ),
      child: ClipOval(child: child),
    ),
  );
}
