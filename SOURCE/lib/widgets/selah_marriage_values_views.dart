import 'package:flutter/material.dart';

import '../models/selah_marriage_values.dart';
import '../theme/selah_colors.dart';
import '../theme/selah_text.dart';

/// LOCK 5's Profile card, reading only the existing profile owner's answers.
class SelahMarriageValuesCard extends StatelessWidget {
  const SelahMarriageValuesCard({
    super.key,
    required this.answers,
    this.visibilityNote = ownVisibilityNote,
  });
  final SelahMarriageValuesAnswers answers;
  static const ownVisibilityNote =
      'Marriage history and children show on your Browse card. All seven show once a Journey begins. Your Shepherds can see them.';
  final String? visibilityNote;
  static const _labels = [
    'Married before',
    'Children',
    'Would like children',
    'Roles in marriage',
    'Open to someone divorced',
    'Where to live',
    'Hoping to marry',
  ];

  @override
  Widget build(BuildContext context) => Column(
    key: const ValueKey('marriage_values_section'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        'MARRIAGE VALUES',
        style: SelahText.chapterLabel().copyWith(height: 1),
      ),
      const SizedBox(height: 14),
      Container(
        key: const ValueKey('marriage_values_card'),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: SelahColors.surface,
          border: Border.all(color: SelahColors.line),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < _labels.length; i++) ...[
              if (i > 0) const SizedBox(height: 10),
              _row(i),
            ],
          ],
        ),
      ),
      if (visibilityNote != null) ...[
        const SizedBox(height: 14),
        Text(
          visibilityNote!,
          key: const ValueKey('marriage_values_visibility_note'),
          style: SelahText.body(size: 13, color: SelahColors.muted),
        ),
      ],
    ],
  );

  Widget _row(int index) {
    final answer = answers.answerFor(index + 1);
    final missing = answer == null || answer.trim().isEmpty;
    final value = missing ? 'Not answered' : answer;
    return Container(
      key: ValueKey('marriage_values_row_$index'),
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: index == 0
          ? null
          : const BoxDecoration(
              border: Border(top: BorderSide(color: SelahColors.line)),
            ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              _labels[index],
              style: SelahText.body(
                size: 14.5,
                color: SelahColors.muted,
              ).copyWith(height: 1.2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 6,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: SelahText.body(
                size: 14.5,
                color: missing ? SelahColors.muted : SelahColors.inkColor,
              ).copyWith(height: 1.2),
            ),
          ),
        ],
      ),
    );
  }
}
