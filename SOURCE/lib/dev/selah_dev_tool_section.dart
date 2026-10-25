import 'package:flutter/material.dart';

import '../theme/selah_colors.dart';

/// One category, one surface. The enclosing developer panel owns scrolling;
/// sections never mix independent controls into a single catch-all menu.
class SelahDevToolSection extends StatelessWidget {
  const SelahDevToolSection({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: SelahColors.surfaceFill,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: SelahColors.surfaceBorder),
    ),
    child: Padding(padding: const EdgeInsets.all(14), child: child),
  );
}
