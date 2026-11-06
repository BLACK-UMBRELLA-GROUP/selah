import 'package:flutter/material.dart';

import '../theme/selah_colors.dart';
import '../theme/selah_text.dart';
import 'selah_shepherd_invite_views.dart';
import 'selah_state_widgets.dart';

/// One LOCKed question layout shared by faith and marriage values.
class SelahProfileQuestion {
  const SelahProfileQuestion({
    required this.title,
    this.help,
    this.options = const [],
  });
  final String title;
  final String? help;
  final List<String> options;
}

class SelahProfileQuestionPage extends StatelessWidget {
  const SelahProfileQuestionPage({
    super.key,
    required this.keyPrefix,
    required this.sectionLabel,
    required this.questions,
    required this.questionNumber,
    required this.scrollController,
    required this.onBack,
    required this.isSelected,
    required this.onChoose,
    required this.onContinue,
    this.customAnswer,
    this.showRequiredError = false,
    this.saving = false,
    this.failureMessage,
    this.onRetry,
    this.beforeButtons,
    this.onSkip,
  });

  final String keyPrefix;
  final String sectionLabel;
  final List<SelahProfileQuestion> questions;
  final int questionNumber;
  final ScrollController scrollController;
  final VoidCallback onBack;
  final bool Function(String) isSelected;
  final ValueChanged<int> onChoose;
  final VoidCallback onContinue;
  final Widget? customAnswer;
  final bool showRequiredError;
  final bool saving;
  final String? failureMessage;
  final VoidCallback? onRetry;
  final Widget? beforeButtons;
  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context) {
    final question = questions[questionNumber - 1];
    final last = questionNumber == questions.length;
    return Scaffold(
      key: ValueKey('${keyPrefix}_question_$questionNumber'),
      backgroundColor: SelahColors.mist,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 6, 22, 12),
              child: Row(
                children: [
                  TextButton(
                    key: ValueKey('${keyPrefix}_back'),
                    onPressed: onBack,
                    style: TextButton.styleFrom(
                      foregroundColor: SelahColors.lake,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      alignment: Alignment.centerLeft,
                    ),
                    child: Text(
                      '‹ Back',
                      style: SelahText.button(
                        size: 15,
                        color: SelahColors.lake,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '$sectionLabel · $questionNumber of ${questions.length}',
                    style: SelahText.subtext(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, bounds) => SingleChildScrollView(
                  controller: scrollController,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(22, 0, 22, 16),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: (bounds.maxHeight - 16).clamp(
                          0,
                          double.infinity,
                        ),
                      ),
                      child: IntrinsicHeight(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (failureMessage != null) ...[
                              SelahErrorBanner(
                                key: ValueKey('${keyPrefix}_failure'),
                                message: failureMessage!,
                                retryKey: ValueKey('${keyPrefix}_retry'),
                                onRetry: onRetry,
                              ),
                              const SizedBox(height: 14),
                            ],
                            ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                value: questionNumber / questions.length,
                                minHeight: 5,
                                color: SelahColors.lake,
                                backgroundColor: SelahColors.line,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(question.title, style: SelahText.pageTitle()),
                            if (question.help != null) ...[
                              const SizedBox(height: 14),
                              Text(
                                question.help!,
                                style: SelahText.body(color: SelahColors.muted),
                              ),
                            ],
                            const SizedBox(height: 14),
                            if (question.options.isNotEmpty)
                              for (
                                var i = 0;
                                i < question.options.length;
                                i++
                              ) ...[
                                if (i > 0) const SizedBox(height: 8),
                                SelahProfileQuestionChoice(
                                  key: ValueKey(
                                    '${keyPrefix}_choice_q${questionNumber}_$i',
                                  ),
                                  label: question.options[i],
                                  selected: isSelected(question.options[i]),
                                  onTap: () => onChoose(i),
                                ),
                              ]
                            else
                              ?customAnswer,
                            if (showRequiredError) ...[
                              const SizedBox(height: 14),
                              Text(
                                'Choose one answer to continue.',
                                key: ValueKey('${keyPrefix}_required_error'),
                                style: SelahText.subtext(
                                  color: SelahColors.dawn,
                                ),
                              ),
                            ],
                            const SizedBox(height: 14),
                            const Spacer(),
                            ?beforeButtons,
                            Opacity(
                              opacity: saving ? .75 : 1,
                              child: SelahInviteButton(
                                key: ValueKey(
                                  '${keyPrefix}_${last ? 'save' : 'continue'}',
                                ),
                                label: saving
                                    ? 'Saving…'
                                    : last
                                    ? 'Save and continue'
                                    : 'Continue',
                                onPressed: saving ? null : onContinue,
                              ),
                            ),
                            if (saving)
                              // The masters reserve the existing private demo-row space.
                              const SizedBox(height: 42)
                            else if (onSkip != null) ...[
                              const SizedBox(height: 10),
                              SelahInviteButton(
                                key: ValueKey('${keyPrefix}_skip'),
                                label: 'Skip',
                                ghost: true,
                                onPressed: onSkip,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SelahProfileQuestionChoice extends StatelessWidget {
  const SelahProfileQuestionChoice({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    button: true,
    child: Container(
      decoration: BoxDecoration(
        color: SelahColors.surface,
        border: Border.all(
          color: selected ? SelahColors.lake : SelahColors.line,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      foregroundDecoration: selected
          ? BoxDecoration(
              border: Border.all(color: SelahColors.lake, width: 2),
              borderRadius: BorderRadius.circular(14),
            )
          : null,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
            child: Text(
              label,
              style: SelahText.body(size: 14.5).copyWith(height: 1.2),
            ),
          ),
        ),
      ),
    ),
  );
}
