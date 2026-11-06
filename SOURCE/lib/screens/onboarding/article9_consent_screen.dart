// Explicit consent for special-category data — Founder approved 2026-08-04.
//
// Sits between Chapter 2's location questions and its faith/background
// questions, because that is the last moment before the app asks for
// anything special-category. Consent has to come BEFORE the collection,
// not at the end of the chapter.
//
// WHAT MAKES THIS EXPLICIT CONSENT RATHER THAN A NOTICE
//
//   Specific    it names the exact categories, not "some personal data".
//   Informed    it says what they are used for and what other members see.
//   Unbundled   it is its own screen with its own decision, not a line in
//               a Terms checkbox.
//   Freely      declining is a REAL option that continues the flow. The
//   given       decline path is not a dead end and not a nag — if it were,
//               the consent would not be freely given and would not count.
//   Withdrawable  stated on screen, and Settings honours it.
//
// There is deliberately NO pre-ticked box and no styling that makes accept
// louder than decline beyond ordinary primary/secondary weighting.
//
// NOT LEGAL ADVICE. Wording is a draft. The Founder has confirmed a
// solicitor will review this text, the Privacy Policy, the Terms and the
// Compatibility Unlock flow before public launch. `kArticle9PolicyVersion`
// exists so that review can change the words without orphaning consent
// already recorded — bump it and prior consent stops counting.

import 'package:flutter/material.dart';

import '../../services/selah_consent_service.dart';
import '../../services/selah_developer_access.dart';
import '../../theme/selah_colors.dart';
import '../../theme/selah_text.dart';
import '../../widgets/selah_shepherd_invite_views.dart';
import '../../widgets/selah_state_widgets.dart';

enum SelahConsentPreviewState { idle, saving, failed }

class Article9ConsentScreen extends StatefulWidget {
  const Article9ConsentScreen({
    super.key,
    required this.onDecision,
    this.background = SelahBackgroundVariant.neutral,
    this.devPreview = false,
    this.onBack,
    this.previewState = SelahConsentPreviewState.idle,
  });
  final SelahBackgroundVariant background;

  /// The existing detached rehearsal never records a real consent decision.
  final bool devPreview;
  final ValueChanged<bool> onDecision;
  final VoidCallback? onBack;
  final SelahConsentPreviewState previewState;
  @override
  State<Article9ConsentScreen> createState() => _Article9ConsentScreenState();
}

class _Article9ConsentScreenState extends State<Article9ConsentScreen> {
  bool _busy = false;
  bool _failed = false;
  bool _lastChoice = true;

  Future<void> _decide(bool granted) async {
    if (_busy ||
        (widget.devPreview && !SelahDeveloperAccess.canUseDeveloperTools)) {
      return;
    }
    _lastChoice = granted;
    if (widget.devPreview) {
      widget.onDecision(granted);
      return;
    }
    setState(() {
      _busy = true;
      _failed = false;
    });
    final ok = await SelahConsentService.record(granted: granted);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _failed = !ok;
    });
    if (ok) widget.onDecision(granted);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: SelahDeveloperAccess.authorizationChanges,
    builder: (context, _) {
      if (widget.devPreview && !SelahDeveloperAccess.canUseDeveloperTools) {
        return Scaffold(
          key: const ValueKey('article9_preview_denied'),
          backgroundColor: SelahColors.modalSheetSurface,
          body: const SizedBox.expand(),
        );
      }
      final preview =
          widget.devPreview && SelahDeveloperAccess.canUseDeveloperTools;
      final saving =
          _busy ||
          (preview && widget.previewState == SelahConsentPreviewState.saving);
      final failed =
          _failed ||
          (preview && widget.previewState == SelahConsentPreviewState.failed);
      return Scaffold(
        key: const ValueKey('consent_screen'),
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
                      key: const ValueKey('consent_back'),
                      onPressed: saving
                          ? null
                          : widget.onBack ??
                                () => Navigator.of(context).maybePop(),
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
                      'Before your faith questions',
                      style: SelahText.subtext(),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, bounds) => SingleChildScrollView(
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
                              if (failed) ...[
                                SelahErrorBanner(
                                  key: const ValueKey('consent_failure'),
                                  message:
                                      'We couldn’t save your choice. Try again.',
                                  retryKey: const ValueKey('consent_retry'),
                                  onRetry: () => _decide(_lastChoice),
                                ),
                                const SizedBox(height: 14),
                              ],
                              Text(
                                kArticle9ConsentTitle,
                                style: SelahText.pageTitle(),
                              ),
                              const SizedBox(height: 14),
                              for (final paragraph
                                  in kArticle9ConsentBody.split('\n\n')) ...[
                                Text(
                                  paragraph,
                                  style: SelahText.body().copyWith(
                                    height: 1.55,
                                  ),
                                ),
                                const SizedBox(height: 14),
                              ],
                              Text(
                                kArticle9ConsentWithdrawalNote,
                                style: SelahText.subtext().copyWith(
                                  height: 1.55,
                                ),
                              ),
                              const SizedBox(height: 14),
                              const Spacer(),
                              Opacity(
                                opacity: saving ? .75 : 1,
                                child: SelahInviteButton(
                                  key: const ValueKey('consent_agree'),
                                  label: saving
                                      ? 'Saving…'
                                      : 'I agree, ask me these',
                                  onPressed: saving
                                      ? null
                                      : () => _decide(true),
                                ),
                              ),
                              if (!saving) ...[
                                const SizedBox(height: 10),
                                SelahInviteButton(
                                  key: const ValueKey('consent_skip'),
                                  label: 'Skip these questions',
                                  ghost: true,
                                  onPressed: () => _decide(false),
                                ),
                              ] else
                                const SizedBox(height: 42),
                              const SizedBox(height: 10),
                              Text(
                                kArticle9ConsentDeclineNote,
                                textAlign: TextAlign.center,
                                style: SelahText.subtext(),
                              ),
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
    },
  );
}
