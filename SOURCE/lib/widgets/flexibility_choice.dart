// Reusable "Flexibility" question — the single 🟢/🟡/🔴 sentence-choice
// pattern used throughout Chapter 2 (Questions Section 2 Profile
// Information.md), distinct from Chapter 4's per-option traffic-light
// matrix (traffic_light_question_screen.dart handles that one instead).

import 'package:flutter/material.dart';
import '../models/onboarding_question.dart';
import '../theme/selah_colors.dart';
import 'selah_onboarding_choice_card.dart';

class FlexibilityChoice extends StatelessWidget {
  final String greenText;
  final String yellowText;
  final String redText;
  final TrafficLight? value;
  final ValueChanged<TrafficLight> onChanged;

  const FlexibilityChoice({
    super.key,
    required this.greenText,
    required this.yellowText,
    required this.redText,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final entries = [
      (TrafficLight.green, greenText),
      (TrafficLight.yellow, yellowText),
      (TrafficLight.red, redText),
    ];
    return Column(
      children: entries.map((e) {
        final selected = value == e.$1;
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: SelahOnboardingChoiceCard(
            key: ValueKey('profile_flexibility_${e.$1.name}'),
            label: e.$2,
            selected: selected,
            leading: Icon(
              Icons.circle,
              size: 14,
              color: switch (e.$1) {
                TrafficLight.green => SelahColors.positiveGreen,
                TrafficLight.yellow => SelahColors.journeyGold,
                TrafficLight.red => SelahColors.negativeRed,
              },
            ),
            onTap: () => onChanged(e.$1),
          ),
        );
      }).toList(),
    );
  }
}
