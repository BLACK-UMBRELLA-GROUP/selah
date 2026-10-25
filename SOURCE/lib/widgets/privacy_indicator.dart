// Privacy indicator shown at the bottom of onboarding question content.
// Spec: Onboarding Rules & UX §SCREEN ANATOMY — Privacy indicator, and
// §PRIVACY INDICATOR — ASSIGNMENT BY QUESTION.

import 'package:flutter/material.dart';
import '../theme/selah_colors.dart';
import '../theme/selah_text.dart';

enum PrivacyLevel { public, unlock, private }

class PrivacyIndicator extends StatelessWidget {
  final PrivacyLevel level;
  final String? overrideText;

  const PrivacyIndicator({super.key, required this.level, this.overrideText});

  @override
  Widget build(BuildContext context) {
    late Color dot;
    late Color textColor;
    late String label;
    switch (level) {
      case PrivacyLevel.public:
        dot = SelahColors.publicDot;
        textColor = SelahColors.publicText;
        label = 'Shown on your profile.';
        break;
      case PrivacyLevel.unlock:
        dot = SelahColors.unlockDot;
        textColor = SelahColors.unlockText;
        label = 'Shown inside a mutual Journey.';
        break;
      case PrivacyLevel.private:
        dot = SelahColors.privateDot;
        textColor = SelahColors.privateText;
        label = 'Private. Used only by SELAH.';
        break;
    }
    return Padding(
      padding: const EdgeInsets.only(right: 52, top: 12, bottom: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              overrideText ?? label,
              style: SelahText.privacyText(color: textColor),
            ),
          ),
        ],
      ),
    );
  }
}
