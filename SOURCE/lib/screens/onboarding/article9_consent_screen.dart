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

class Article9ConsentScreen extends StatefulWidget {
  final SelahBackgroundVariant background;

  /// A requested local rehearsal never records a real Article 9 decision.
  final bool devPreview;

  /// Called with true if consent was granted, false if declined.
  /// The caller decides what to skip — this screen does not navigate.
  final ValueChanged<bool> onDecision;

  const Article9ConsentScreen({
    super.key,
    required this.onDecision,
    this.background = SelahBackgroundVariant.neutral,
    this.devPreview = false,
  });

  @override
  State<Article9ConsentScreen> createState() => _Article9ConsentScreenState();
}

class _Article9ConsentScreenState extends State<Article9ConsentScreen> {
  bool _busy = false;

  Future<void> _decide(bool granted) async {
    if (_busy ||
        (widget.devPreview && !SelahDeveloperAccess.canUseDeveloperTools)) {
      return;
    }
    if (widget.devPreview) {
      widget.onDecision(granted);
      return;
    }
    setState(() => _busy = true);
    final ok = await SelahConsentService.record(granted: granted);
    if (!mounted) return;
    setState(() => _busy = false);

    if (!ok) {
      // A consent we cannot evidence is a consent we do not have. Rather
      // than proceeding on an unrecorded "yes", say so and let them retry.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("We couldn't save your choice. Please try again."),
        ),
      );
      return;
    }
    widget.onDecision(granted);
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
      return _buildConsent(context);
    },
  );

  Widget _buildConsent(BuildContext context) => Scaffold(
    body: Container(
      constraints: const BoxConstraints.expand(),
      decoration: BoxDecoration(
        gradient: SelahColors.backgroundFor(widget.background),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(
                            Icons.lock_outline,
                            size: 16,
                            color: SelahColors.foreground.withValues(alpha: 0.6),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'YOUR PERMISSION',
                            style: SelahText.chapterLabel(
                              color: SelahColors.ink(0.70),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      Text(
                        kArticle9ConsentTitle,
                        style: SelahText.heading(size: 26),
                      ),
                      SizedBox(height: 18),
                      Text(
                        kArticle9ConsentBody,
                        style: SelahText.body(size: 15).copyWith(height: 1.55),
                      ),
                      SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: SelahColors.iconButtonBg,
                          border: Border.all(
                            color: SelahColors.iconButtonBorder,
                            width: 0.5,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          kArticle9ConsentDeclineNote,
                          style: SelahText.subtext(size: 12.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 20),
              // Accept carries primary weight; decline is plainly
              // available and not buried. Making decline hard to find is
              // the single most common way consent stops being freely
              // given.
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _busy ? null : () => _decide(true),
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(50),
                    ),
                  ),
                  child: Text(
                    'I agree — use these answers to match me',
                    textAlign: TextAlign.center,
                    style: SelahText.button(size: 14),
                  ),
                ),
              ),
              SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: TextButton(
                  onPressed: _busy ? null : () => _decide(false),
                  style: TextButton.styleFrom(foregroundColor: Colors.white),
                  child: Text(
                    'Skip these questions',
                    style: SelahText.button(
                      size: 14,
                      color: SelahColors.ink(0.70),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 8),
              Center(
                child: Text(
                  'You can change this at any time in Settings.',
                  style: SelahText.subtext(
                    size: 11.5,
                    color: SelahColors.ink(0.54),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
