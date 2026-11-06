import 'package:flutter/material.dart';

import '../theme/selah_interaction_style.dart';
import 'floating_nav_bar.dart';

/// LOCK 1 uses one dock; no alternate rail reserves space beside the content.
class SelahMenuCanvas extends StatelessWidget {
  const SelahMenuCanvas({super.key, required this.child, this.enabled = true});
  final Widget child;
  final bool enabled;

  @override
  Widget build(BuildContext context) => child;
}

/// Shell-owned destination metadata and callbacks share the Still Water dock.
class SelahShellNavigation extends StatelessWidget {
  const SelahShellNavigation({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
    this.forceCurrent = false,
    this.commitOnRelease = false,
    this.contentEdgeInset,
    this.hapticLevel,
  }) : assert(
         contentEdgeInset == null ||
             (contentEdgeInset >= 0 && contentEdgeInset < double.infinity),
       );

  final List<FloatingNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final bool forceCurrent;
  final bool commitOnRelease;
  final double? contentEdgeInset;
  final SelahHapticLevel? hapticLevel;

  @override
  Widget build(BuildContext context) => FloatingNavBar(
    items: items,
    currentIndex: currentIndex,
    onTap: onTap,
    commitOnRelease: commitOnRelease,
    contentEdgeInset: contentEdgeInset,
    hapticLevel: hapticLevel,
  );
}
