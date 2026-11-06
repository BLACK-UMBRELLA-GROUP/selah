import 'package:flutter/material.dart';

import '../models/selah_faith_profile.dart';
import '../theme/selah_colors.dart';
import '../theme/selah_text.dart';

/// LOCK 4's Profile section. Answers always come from the local profile owner.
class SelahFaithProfileCard extends StatelessWidget {
  const SelahFaithProfileCard({super.key, required this.answers});

  final SelahFaithProfileAnswers answers;

  @override
  Widget build(BuildContext context) {
    final rows = <(String, String?)>[
      ('Church tradition', answers.tradition),
      ('Church', answers.church),
      ('Baptised', answers.baptised),
      ('Christian for', answers.christianFor),
      ('Serving', answers.serving.join(', ')),
      ('Open to other traditions', answers.openness),
    ];
    final words = answers.words.trim();
    return Column(
      key: const ValueKey('faith_profile_section'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'FAITH PROFILE',
          style: SelahText.chapterLabel().copyWith(height: 1),
        ),
        const SizedBox(height: 14),
        Container(
          key: const ValueKey('faith_profile_card'),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: SelahColors.surface,
            border: Border.all(color: SelahColors.line),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var index = 0; index < rows.length; index++) ...[
                if (index > 0) const SizedBox(height: 10),
                _row(rows[index].$1, rows[index].$2, index),
              ],
            ],
          ),
        ),
        if (words.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(
            '“$words”',
            key: const ValueKey('faith_profile_quote'),
            style: SelahText.quote(),
          ),
        ],
      ],
    );
  }

  Widget _row(String label, String? answer, int index) {
    final missing = answer == null || answer.trim().isEmpty;
    final value = missing ? 'Not answered' : answer;
    final labelStyle = SelahText.body(
      size: 14.5,
      color: SelahColors.muted,
    ).copyWith(height: 1.2);
    final valueStyle = SelahText.body(
      size: 14.5,
      color: missing ? SelahColors.muted : SelahColors.inkColor,
    ).copyWith(height: 1.2);
    return Container(
      key: ValueKey('faith_profile_row_$index'),
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: index == 0
          ? null
          : const BoxDecoration(
              border: Border(top: BorderSide(color: SelahColors.line)),
            ),
      child: LayoutBuilder(
        builder: (context, bounds) {
          double naturalWidth(String text, TextStyle style) {
            final painter = TextPainter(
              text: TextSpan(text: text, style: style),
              textDirection: Directionality.of(context),
              textScaler: MediaQuery.textScalerOf(context),
              locale: Localizations.maybeLocaleOf(context),
            )..layout();
            final width = painter.width;
            painter.dispose();
            return width;
          }

          final reservedValueWidth = naturalWidth(
            value,
            valueStyle,
          ).clamp(0.0, bounds.maxWidth * .55);
          final labelWidth = naturalWidth(label, labelStyle).clamp(
            0.0,
            (bounds.maxWidth - 10 - reservedValueWidth).clamp(
              0.0,
              double.infinity,
            ),
          );
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: labelWidth,
                child: Text(label, style: labelStyle),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  value,
                  textAlign: TextAlign.right,
                  style: valueStyle,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
