// Top bar for onboarding question screens.
// Spec: Onboarding Rules & UX §SCREEN ANATOMY — TOP BAR.
// Single row, always present: [progress area, flex-grows] [··· help button]

import 'package:flutter/material.dart';
import '../theme/selah_colors.dart';
import '../theme/selah_text.dart';
import 'selah_onboarding_direction_style.dart';

class OnboardingTopBar extends StatelessWidget {
  final String chapterName;
  final double chapterProgress; // 0.0 - 1.0, resets each chapter
  final String? progressLabel;
  final bool chapterComplete;
  final VoidCallback onHelpTap;
  final OnboardingPreviewStyle? previewStyle;

  const OnboardingTopBar({
    super.key,
    required this.chapterName,
    required this.chapterProgress,
    this.progressLabel,
    required this.onHelpTap,
    this.chapterComplete = false,
    this.previewStyle,
  });

  @override
  Widget build(BuildContext context) {
    final fillColor = chapterComplete
        ? SelahColors.progressCompleteFill
        : SelahColors.progressFill;
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (previewStyle != null) ...[
              Center(
                child: Text(
                  'SELAH',
                  style: SelahText.wordmark(
                    size: 17,
                    color: SelahColors.splashWordmark,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          chapterName.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: SelahText.chapterLabel(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          progressLabel ??
                              '${(chapterProgress * 100).round()}%',
                          textAlign: TextAlign.end,
                          maxLines: 2,
                          style: SelahText.chapterLabel(),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // ··· bare dots, no circle, no background — opens help sheet
                Semantics(
                  button: true,
                  label: 'Question details',
                  onTap: onHelpTap,
                  child: GestureDetector(
                    excludeFromSemantics: true,
                    onTap: onHelpTap,
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text('···', style: SelahText.body(size: 18)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (previewStyle != null)
              OnboardingPreviewProgress(
                style: previewStyle!,
                progress: chapterProgress,
                semanticValue: progressLabel,
              )
            else
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: SizedBox(
                  height: 1.5,
                  child: LinearProgressIndicator(
                    value: chapterProgress.clamp(0.0, 1.0),
                    semanticsLabel: progressLabel == null
                        ? chapterName
                        : '$chapterName, $progressLabel',
                    backgroundColor: SelahColors.progressTrack,
                    valueColor: AlwaysStoppedAnimation<Color>(fillColor),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
