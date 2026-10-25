import 'package:flutter/material.dart';

import '../../data/onboarding_category_guidance.dart';
import '../../models/onboarding_question.dart';
import '../../theme/selah_colors.dart';
import '../../theme/selah_text.dart';
import '../../widgets/selah_onboarding_continue_action.dart';

/// A quiet boundary between compatibility subjects.
///
/// The screen says where the Seeker is, gives one brief description and keeps
/// the question count separate. It deliberately does not duplicate question
/// copy or explain the next phase before the Seeker reaches it.
class CompatibilityCategoryIntroScreen extends StatelessWidget {
  final OnboardingCategory category;
  final int sectionIndex;
  final int totalSections;
  final int questionCount;
  final VoidCallback onContinue;
  final VoidCallback? onBack;

  const CompatibilityCategoryIntroScreen({
    super.key,
    required this.category,
    required this.sectionIndex,
    required this.totalSections,
    required this.questionCount,
    required this.onContinue,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final guidance = guidanceForOnboardingCategory(category.id);
    return Scaffold(
      body: Container(
        constraints: const BoxConstraints.expand(),
        decoration: BoxDecoration(gradient: SelahColors.brandGradient),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              key: const ValueKey('compatibility_section_scrollable'),
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(27, 14, 27, 22),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'PART 1 — ABOUT YOU',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: SelahText.chapterLabel(
                                  color: SelahColors.ink(0.54),
                                ),
                              ),
                            ),
                            SizedBox(width: 12),
                            Text(
                              'SECTION $sectionIndex OF $totalSections',
                              key: const ValueKey(
                                'compatibility_section_position',
                              ),
                              style: SelahText.chapterLabel(
                                color: SelahColors.ink(0.54),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 11),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: sectionIndex / totalSections,
                            minHeight: 1.5,
                            backgroundColor: SelahColors.progressTrack,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              SelahColors.unlockDot,
                            ),
                          ),
                        ),
                        if (onBack != null) ...[
                          SizedBox(height: 12),
                          _CategoryUpCue(onTap: onBack!),
                        ],
                        const Spacer(flex: 2),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'COMPATIBILITY SECTION',
                            style: SelahText.chapterLabel(
                              color: SelahColors.unlockText,
                            ),
                          ),
                        ),
                        SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            category.name,
                            key: ValueKey(
                              'compatibility_section_${category.id}',
                            ),
                            style: SelahText.heading(size: 29),
                          ),
                        ),
                        SizedBox(height: 14),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            guidance.description,
                            style: SelahText.body(size: 14.5),
                          ),
                        ),
                        SizedBox(height: 18),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '$questionCount ${questionCount == 1 ? 'question' : 'questions'}',
                            style: SelahText.subtext(
                              size: 11.5,
                              color: SelahColors.unlockText,
                            ),
                          ),
                        ),
                        SizedBox(height: 28),
                        const _VisibilityLine(
                          icon: Icons.lock_outline_rounded,
                          label: 'PRIVATE',
                          text: 'Used to calculate your compatibility score.',
                        ),
                        const Spacer(flex: 3),
                        if (SelahOnboardingArrowScope.enabledOf(context))
                          SelahOnboardingArrowAction(
                            key: const ValueKey(
                              'compatibility_section_continue',
                            ),
                            active: true,
                            onPressed: onContinue,
                            semanticLabel: 'Begin section',
                          )
                        else
                          _CategoryDownCue(
                            label: 'Begin section',
                            onTap: onContinue,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _VisibilityLine extends StatelessWidget {
  final IconData icon;
  final String label;
  final String text;

  const _VisibilityLine({
    required this.icon,
    required this.label,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: SelahColors.ink(0.12), width: 0.7),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: SelahColors.unlockText, size: 16),
          SizedBox(width: 10),
          SizedBox(
            width: 86,
            child: Text(
              label,
              style: SelahText.chapterLabel(color: SelahColors.unlockText),
            ),
          ),
          Expanded(child: Text(text, style: SelahText.subtext(size: 12))),
        ],
      ),
    );
  }
}

class _CategoryUpCue extends StatelessWidget {
  final VoidCallback onTap;

  const _CategoryUpCue({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Previous compatibility page',
      child: InkWell(
        key: const ValueKey('compatibility_section_back'),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.keyboard_arrow_up_rounded,
                color: SelahColors.ink(0.70),
                size: 21,
              ),
              Text(
                'Previous page',
                style: SelahText.subtext(size: 9.5, color: SelahColors.ink(0.54)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryDownCue extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _CategoryDownCue({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        key: const ValueKey('compatibility_section_continue'),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.keyboard_arrow_down_rounded,
                color: SelahColors.unlockText,
                size: 25,
              ),
              SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: SelahText.subtext(
                  size: 11.5,
                  color: SelahColors.ink(0.70),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
