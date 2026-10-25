// Shared scaffold for every onboarding question screen — wires together
// the gradient background, top bar, scrollable content, privacy
// indicator, and FAB per Onboarding Rules & UX §SCREEN ANATOMY.
// Back navigation uses the shared upward cue and a rightward swipe. The
// account-specific flow still owns validation, persistence and navigation.

import 'package:flutter/material.dart';
import '../services/selah_developer_access.dart';
import '../theme/selah_colors.dart';
import '../theme/selah_text.dart';
import 'onboarding_top_bar.dart';
import 'privacy_indicator.dart';
import 'selah_onboarding_account_exit.dart';
import 'selah_onboarding_continue_action.dart';
import 'selah_onboarding_direction_style.dart';

class OnboardingScaffold extends StatelessWidget {
  final SelahBackgroundVariant background;
  final String chapterName;
  final double chapterProgress;
  final String? progressLabel;
  final bool chapterComplete;
  final String question;
  final String? subtext;
  final Widget content;

  /// Standalone inputs can opt out of the generic answer card without
  /// changing the question chrome, progress, privacy or navigation.
  final bool frameContent;
  final PrivacyLevel? privacy;
  final String? privacyOverrideText;
  final bool fabActive;
  final VoidCallback? onContinue;
  final bool devPreview;
  final VoidCallback? onDevSkip;
  final String devSkipLabel;
  final bool showAccountExit;
  final String? accountExitExpectedUserId;
  final Key continueActionKey;

  /// Only optional, post-verification profile chapters supply this action.
  /// Its availability is independent of whether the current answer is valid.
  final VoidCallback? onFinishLater;

  /// Fix (2026-07-18): Onboarding Rules & UX §SCREEN ANATOMY specifies
  /// "No back button — users navigate back by swiping right (iOS
  /// standard gesture)." Every question screen in this app renders
  /// through this shared scaffold using a manual step index rather than
  /// a PageView, so that swipe gesture was never actually implemented —
  /// there was no way to correct an earlier answer across all ~200
  /// onboarding questions. This wires the swipe the spec always called
  /// for, without adding a visible back button (which the spec
  /// explicitly rules out).
  final VoidCallback? onSwipeBack;

  const OnboardingScaffold({
    super.key,
    required this.background,
    required this.chapterName,
    required this.chapterProgress,
    this.progressLabel,
    required this.question,
    required this.content,
    this.frameContent = true,
    required this.fabActive,
    required this.onContinue,
    this.chapterComplete = false,
    this.subtext,
    this.privacy,
    this.privacyOverrideText,
    this.onSwipeBack,
    this.devPreview = false,
    this.onDevSkip,
    this.devSkipLabel = 'Skip question',
    this.showAccountExit = false,
    this.accountExitExpectedUserId,
    this.continueActionKey = const ValueKey('onboarding_continue'),
    this.onFinishLater,
  });

  void _showHelpSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: SelahColors.modalSheetSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Question details', style: SelahText.heading(size: 16)),
              SizedBox(height: 14),
              Text(question, style: SelahText.body(size: 14)),
              if (subtext != null) ...[
                const SizedBox(height: 10),
                Text(subtext!, style: SelahText.subtext(size: 13)),
              ],
              if (privacy != null)
                PrivacyIndicator(
                  level: privacy!,
                  overrideText: privacyOverrideText,
                ),
              const SizedBox(height: 18),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final previewStyle = OnboardingPreviewStyle.effectiveStyleOf(context);
    final compactPreview =
        previewStyle != null &&
        (MediaQuery.sizeOf(context).height < 650 ||
            MediaQuery.textScalerOf(context).scale(1) > 1.2);
    final topBar = OnboardingTopBar(
      chapterName: chapterName,
      chapterProgress: chapterProgress,
      progressLabel: progressLabel,
      chapterComplete: chapterComplete,
      onHelpTap: () => _showHelpSheet(context),
      previewStyle: previewStyle,
    );
    final questionContent = Expanded(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          compactPreview ? 4 : 24,
          20,
          previewStyle == null ? 90 : 24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showAccountExit &&
                !devPreview &&
                accountExitExpectedUserId != null) ...[
              Align(
                alignment: Alignment.centerRight,
                child: SelahOnboardingAccountExit(
                  expectedUserId: accountExitExpectedUserId!,
                ),
              ),
              const SizedBox(height: 6),
            ],
            if (onFinishLater != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  key: const ValueKey('onboarding_finish_later'),
                  onPressed: onFinishLater,
                  child: Text(
                    'Finish later',
                    style: SelahText.subtext(
                      size: 12,
                      color: SelahColors.unlockText,
                    ),
                  ),
                ),
              ),
            if (onSwipeBack != null) ...[
              Align(
                alignment: Alignment.center,
                child: _OnboardingBackCue(
                  onPressed: onSwipeBack!,
                  showLabel: previewStyle == null,
                ),
              ),
              SizedBox(height: compactPreview ? 7 : 14),
            ],
            if (SelahDeveloperAccess.canUseDeveloperTools &&
                devPreview &&
                onDevSkip != null) ...[
              Align(
                alignment: Alignment.centerRight,
                child: _DevSkipButton(
                  label: devSkipLabel,
                  onPressed: onDevSkip!,
                ),
              ),
              SizedBox(height: compactPreview ? 4 : 10),
            ],
            if (previewStyle != null) ...[
              Align(
                alignment: previewStyle.centered
                    ? Alignment.center
                    : Alignment.centerLeft,
                child: OnboardingPreviewAccent(
                  style: previewStyle,
                  size: compactPreview ? 26 : 46,
                  progress: chapterProgress,
                ),
              ),
              SizedBox(height: compactPreview ? 4 : 14),
            ],
            SizedBox(
              width: double.infinity,
              child: Text(
                question,
                textAlign: previewStyle?.centered == true
                    ? TextAlign.center
                    : TextAlign.left,
                style: previewStyle == null
                    ? SelahText.heading()
                    : SelahText.heading(
                        size: compactPreview ? 22 : previewStyle.titleSize,
                      ),
              ),
            ),
            if (subtext != null) ...[
              SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: Text(
                  subtext!,
                  textAlign: previewStyle?.centered == true
                      ? TextAlign.center
                      : TextAlign.left,
                  style: SelahText.subtext(),
                ),
              ),
            ],
            SizedBox(height: compactPreview ? 8 : 28),
            if (previewStyle == null || !frameContent)
              content
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: previewStyle.cardDecoration(),
                child: content,
              ),
            if (privacy != null)
              PrivacyIndicator(
                level: privacy!,
                overrideText: privacyOverrideText,
              ),
          ],
        ),
      ),
    );
    final arrowMode = SelahOnboardingArrowScope.enabledOf(context);
    final continueButton = arrowMode
        ? Center(
            child: SelahOnboardingArrowAction(
              key: continueActionKey,
              active: fabActive,
              onPressed: onContinue,
            ),
          )
        : previewStyle == null
        ? _OnboardingContinueCue(
            actionKey: continueActionKey,
            active: fabActive,
            onPressed: onContinue,
          )
        : SizedBox(
            height: 52,
            child: FilledButton(
              key: continueActionKey,
              onPressed: fabActive ? onContinue : null,
              style: previewStyle.primaryButtonStyle,
              child: Text('Continue', style: SelahText.button()),
            ),
          );
    return Scaffold(
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragEnd: onSwipeBack == null
            ? null
            : (details) {
                final velocity = details.primaryVelocity ?? 0;
                if (velocity > 250) onSwipeBack!(); // rightward swipe
              },
        child: Container(
          decoration: BoxDecoration(
            gradient:
                previewStyle?.backgroundGradient ??
                SelahColors.backgroundFor(background),
          ),
          child: previewStyle == null
              ? Stack(
                  children: [
                    Column(children: [topBar, questionContent]),
                    Positioned(
                      left: 20,
                      right: 20,
                      bottom: MediaQuery.paddingOf(context).bottom + 14,
                      child: continueButton,
                    ),
                  ],
                )
              : Column(
                  children: [
                    topBar,
                    questionContent,
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        20,
                        8,
                        20,
                        MediaQuery.paddingOf(context).bottom + 14,
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        child: continueButton,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _DevSkipButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _DevSkipButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$label, developer only',
      child: TextButton.icon(
        key: const ValueKey('onboarding_dev_skip'),
        onPressed: onPressed,
        icon: Icon(
          Icons.skip_next_rounded,
          size: 17,
          color: SelahColors.unlockText,
        ),
        label: Text(
          '$label · DEV',
          style: SelahText.subtext(size: 11.5, color: SelahColors.unlockText),
        ),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          side: BorderSide(color: SelahColors.unlockDot.withValues(alpha: 0.45)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ),
    );
  }
}

class _OnboardingBackCue extends StatelessWidget {
  final VoidCallback onPressed;
  final bool showLabel;

  const _OnboardingBackCue({required this.onPressed, required this.showLabel});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Previous page',
      child: InkWell(
        key: const ValueKey('onboarding_back'),
        onTap: onPressed,
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
              if (showLabel)
                Text(
                  'Previous page',
                  style: SelahText.subtext(
                    size: 9.5,
                    color: SelahColors.ink(0.54),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingContinueCue extends StatelessWidget {
  final Key actionKey;
  final bool active;
  final VoidCallback? onPressed;

  const _OnboardingContinueCue({
    required this.actionKey,
    required this.active,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? SelahColors.unlockText : SelahColors.ink(0.24);
    return Semantics(
      button: true,
      enabled: active,
      label: 'Continue',
      child: InkWell(
        key: actionKey,
        onTap: active ? onPressed : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.keyboard_arrow_down_rounded, color: color, size: 25),
              SizedBox(height: 3),
              Text(
                'Continue',
                style: SelahText.subtext(size: 11.5, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
