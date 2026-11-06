import 'package:flutter/material.dart';

import '../theme/selah_colors.dart';
import '../theme/selah_text.dart';
import 'selah_state_widgets.dart';

/// LOCK 9's presentation; the caller owns the shared Journey and its writes.
class SelahMarriagePrepCard extends StatelessWidget {
  const SelahMarriagePrepCard({
    super.key,
    required this.completedSteps,
    required this.onToggle,
    this.saveFailed = false,
    this.onRetry,
  });

  final Set<int> completedSteps;
  final ValueChanged<int> onToggle;
  final bool saveFailed;
  final VoidCallback? onRetry;

  static const _steps = [
    (
      'Talk with your pastor or Shepherds',
      'Ask who runs marriage preparation near you.',
    ),
    ('Choose a course together', 'Many churches run one over a few weeks.'),
    ('Finish the course', 'Mark it here when you both have.'),
  ];

  @override
  Widget build(BuildContext context) {
    final allDone = const {0, 1, 2}.every(completedSteps.contains);
    return Container(
      key: const ValueKey('marriage_prep_card'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SelahColors.surface,
        border: Border.all(color: SelahColors.line),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Material(
        color: Colors.transparent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (saveFailed) ...[
              SelahErrorBanner(
                key: const ValueKey('marriage_prep_failure'),
                message: 'That didn’t save. Try again.',
                onRetry: onRetry,
                retryKey: const ValueKey('marriage_prep_retry'),
              ),
              const SizedBox(height: 10),
            ],
            Text(
              'WHEN YOU’RE BOTH READY',
              style: SelahText.chapterLabel().copyWith(height: 1),
            ),
            const SizedBox(height: 10),
            Text(
              'Preparing for marriage',
              style: SelahText.option(size: 16).copyWith(height: 1.2),
            ),
            const SizedBox(height: 10),
            Text(
              allDone
                  ? 'You’ve finished your marriage preparation together. Well done.'
                  : 'Your Shepherds can help you find a marriage preparation course.',
              style: SelahText.body(size: 13, color: SelahColors.muted),
            ),
            for (var index = 0; index < _steps.length; index++) ...[
              const SizedBox(height: 10),
              _step(index),
            ],
          ],
        ),
      ),
    );
  }

  Widget _step(int index) {
    final step = _steps[index];
    final completed = completedSteps.contains(index);
    void toggle() => onToggle(index);

    return Semantics(
      checked: completed,
      button: true,
      label: '${step.$1}. ${step.$2}',
      onTap: toggle,
      child: ExcludeSemantics(
        child: InkWell(
          key: ValueKey('marriage_prep_step_$index'),
          onTap: toggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 20,
                  height: 17.4,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Icon(
                      completed ? Icons.check : Icons.circle_outlined,
                      size: completed ? 16 : 11,
                      color: SelahColors.lake,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '${step.$1}\n',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        TextSpan(
                          text: step.$2,
                          style: const TextStyle(
                            fontSize: 13,
                            color: SelahColors.muted,
                          ),
                        ),
                      ],
                    ),
                    style: SelahText.body(size: 14.5).copyWith(height: 1.2),
                    strutStyle: const StrutStyle(fontSize: 14.5, height: 1.2),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
