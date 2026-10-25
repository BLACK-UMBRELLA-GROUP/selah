// The onboarding "continue" FAB.
// Spec: Onboarding Rules & UX §SCREEN ANATOMY — FAB.
// Always visible, never hidden. Dimmed when the current answer is
// invalid/missing, active once valid. It sits inside the bottom-right
// corner with enough breathing room and respects the device safe area.

import 'package:flutter/material.dart';
import '../theme/selah_colors.dart';

class FabContinueButton extends StatelessWidget {
  final bool active;
  final VoidCallback? onPressed;

  const FabContinueButton({
    super.key,
    required this.active,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.paddingOf(context).bottom;

    return Positioned(
      bottom: safeBottom + 22,
      right: 28,
      child: GestureDetector(
        onTap: active ? onPressed : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? SelahColors.fabActiveBg : SelahColors.fabDimmedBg,
            border: Border.all(
              color: active
                  ? SelahColors.fabActiveBorder
                  : SelahColors.fabDimmedBorder,
              width: 0.5,
            ),
          ),
          child: Icon(
            Icons.arrow_forward,
            size: 20,
            color: active
                ? SelahColors.fabActiveArrow
                : SelahColors.fabDimmedArrow,
          ),
        ),
      ),
    );
  }
}
