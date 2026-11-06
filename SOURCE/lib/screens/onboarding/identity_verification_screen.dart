// Mandatory identity-verification step — inherited decision 220/221, inherited upstream action 266.
//
// Phase A owns the exact consent surface, coarse-state presentation and the
// fail-closed navigation boundary. It contains no provider SDK and no local
// production "verified" switch. Developer state never leaves this widget.

import 'package:flutter/material.dart';
import '../../widgets/selah_loading.dart';

import '../../models/selah_identity_verification.dart';
import '../../services/selah_auth.dart';
import '../../services/selah_developer_access.dart';
import '../../services/selah_identity_verification_service.dart';
import '../../services/selah_product_telemetry.dart';
import '../../theme/selah_colors.dart';
import '../../theme/selah_text.dart';
import '../../widgets/selah_onboarding_direction_style.dart';
import '../../widgets/selah_onboarding_continue_action.dart';
import '../settings/privacy_and_data_screen.dart';
import '../welcome_screen.dart';

const String kIdentityVerificationConsentTitle = 'Verify your identity';
const String kIdentityVerificationConsentBody =
    'Selah checks that every member is a real, unique person. You\'ll '
    'photograph your ID document and take a short selfie. Our verification '
    'partner (Sumsub) processes your document and face data on its own '
    'systems to confirm your identity and that you don\'t already have a '
    'Selah account — Selah never stores your document, your selfie, or your '
    'face data; we only receive the result. This uses biometric data, and '
    'we need your explicit consent.';

class InitialIdentityCheckScreen extends StatefulWidget {
  final bool devPreview;
  final SelahIdentityVerificationState? initialState;
  final bool requireDuplicateResolution;
  final Future<String?> Function()? finalizeOnboarding;
  final Future<void> Function(BuildContext context)? onContinue;

  /// Local rehearsal only. This never grants an identity result or calls the
  /// production finalizer; the owning preview route supplies its destination.
  final Future<void> Function(BuildContext context)? onDevSkip;

  const InitialIdentityCheckScreen({
    super.key,
    this.devPreview = false,
    this.initialState,
    this.requireDuplicateResolution = false,
    this.finalizeOnboarding,
    this.onContinue,
    this.onDevSkip,
  });

  @override
  State<InitialIdentityCheckScreen> createState() =>
      _InitialIdentityCheckScreenState();
}

class _InitialIdentityCheckScreenState
    extends State<InitialIdentityCheckScreen> {
  SelahIdentityVerificationState? _state;
  bool _busy = false;
  bool _attemptDeleted = false;
  SelahVerificationLaunchOutcome? _launchOutcome;
  String? _screenUserId;
  String? _error;

  // Isolation follows the requested mode, not current capability. Losing
  // capability must deny the preview rather than enable live IDV/sign-out.
  bool get _isDevPreview => widget.devPreview;

  bool get _providerUnavailable =>
      _launchOutcome == SelahVerificationLaunchOutcome.unavailable ||
      (!_isDevPreview &&
          !SelahIdentityVerificationService.isProviderConfigured);

  bool get _hasOriginalPrincipal => _isDevPreview
      ? SelahDeveloperAccess.canUseDeveloperTools
      : SelahIdentityVerificationService.isCurrentPrincipal(_screenUserId);

  bool get _showsSignupAccountExit =>
      !_isDevPreview && !widget.requireDuplicateResolution;

  bool _guardPrincipal() {
    if (!mounted) return false;
    if (_isDevPreview && !SelahDeveloperAccess.canUseDeveloperTools) {
      return false;
    }
    if (_hasOriginalPrincipal) return true;
    setState(() {
      _busy = false;
      _error = 'Your sign-in has changed. Close and reopen Selah to continue.';
    });
    return false;
  }

  bool _allowsState(SelahIdentityVerificationState? state) {
    if (!_hasOriginalPrincipal) return false;
    return widget.requireDuplicateResolution
        ? state?.allowsActiveJourney == true
        : state?.allowsApp == true;
  }

  @override
  void initState() {
    super.initState();
    _screenUserId = _isDevPreview ? null : SelahAuth.currentUser?.id;
    _state = widget.initialState;
    _recordIdentityEvent(
      SelahTelemetryEventName.opened,
      action: SelahTelemetryAction.pageView,
    );
  }

  SelahIdentityVerificationState _devState(
    SelahIdentityVerificationResult result, {
    SelahDuplicateReviewState duplicate =
        SelahDuplicateReviewState.notEvaluated,
    bool consentGranted = true,
  }) {
    final now = DateTime.now().toUtc();
    return SelahIdentityVerificationState(
      result: result,
      duplicateReview: duplicate,
      consentGranted: consentGranted,
      consentVersion: kIdentityVerificationConsentVersion,
      consentRecordedAt: now,
      updatedAt: now,
      decidedAt: result == SelahIdentityVerificationResult.verified
          ? now
          : null,
    );
  }

  Future<void> _recordConsent(bool granted) async {
    if (_busy || !_guardPrincipal()) return;
    setState(() {
      _busy = true;
      _error = null;
      _launchOutcome = null;
    });
    final state = _isDevPreview
        ? _devState(
            granted
                ? SelahIdentityVerificationResult.pending
                : SelahIdentityVerificationResult.cancelled,
            consentGranted: granted,
          )
        : await SelahIdentityVerificationService.recordConsent(
            granted: granted,
            expectedUserId: _screenUserId,
          );
    if (!_guardPrincipal()) return;
    if (state == null) {
      setState(() {
        _busy = false;
        _error = "We couldn't save your choice. Please try again.";
      });
      return;
    }
    setState(() {
      _busy = false;
      _state = state;
      _attemptDeleted = false;
    });
    if (granted) await _launchProvider();
  }

  Future<void> _launchProvider() async {
    if (_busy || !_guardPrincipal()) return;
    _recordIdentityEvent(SelahTelemetryEventName.started);
    setState(() {
      _busy = true;
      _error = null;
      _launchOutcome = null;
    });
    SelahVerificationLaunchOutcome outcome;
    try {
      outcome = _isDevPreview
          ? SelahVerificationLaunchOutcome.unavailable
          : await SelahIdentityVerificationService.launchProvider();
    } catch (error) {
      // An adapter exception is a launch failure, not progress. Never log
      // provider payloads, documents, tokens or identifying exception text.
      debugPrint('SELAH: identity check launch failed (${error.runtimeType}).');
      outcome = SelahVerificationLaunchOutcome.failed;
    }
    if (!_guardPrincipal()) return;
    setState(() {
      _busy = false;
      _launchOutcome = outcome;
    });
    if (outcome != SelahVerificationLaunchOutcome.launched) {
      _recordIdentityEvent(SelahTelemetryEventName.failed);
    }
    if (outcome == SelahVerificationLaunchOutcome.launched) await _refresh();
  }

  Future<void> _refresh() async {
    if (_busy || _isDevPreview || !_guardPrincipal()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final state = await SelahIdentityVerificationService.fetchMyState(
        expectedUserId: _screenUserId,
      );
      if (!_guardPrincipal()) return;
      setState(() {
        _busy = false;
        _state = state;
      });
      if (state == null) {
        _recordIdentityEvent(SelahTelemetryEventName.failed);
      } else {
        _recordIdentityState(state);
      }
    } catch (_) {
      _recordIdentityEvent(SelahTelemetryEventName.failed);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = "We couldn't refresh your result. Please try again.";
      });
    }
  }

  void _recordIdentityState(SelahIdentityVerificationState state) {
    if (state.result == SelahIdentityVerificationResult.verified) {
      _recordIdentityEvent(SelahTelemetryEventName.completed);
      return;
    }
    if (state.result == SelahIdentityVerificationResult.failed ||
        state.result == SelahIdentityVerificationResult.retryRequired ||
        state.result == SelahIdentityVerificationResult.expired ||
        state.result == SelahIdentityVerificationResult.cancelled) {
      _recordIdentityEvent(SelahTelemetryEventName.failed);
    }
  }

  void _recordIdentityEvent(
    SelahTelemetryEventName name, {
    SelahTelemetryAction action = SelahTelemetryAction.identityProvider,
  }) {
    if (_isDevPreview) return;
    SelahProductTelemetry.instance.record(
      feature: SelahTelemetryFeature.identityCheck,
      name: name,
      action: action,
      surface: SelahTelemetrySurface.entry,
    );
  }

  Future<void> _continue() async {
    if (_busy || !_guardPrincipal()) return;
    final allowed = _allowsState(_state);
    if (!allowed) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final error = await widget.finalizeOnboarding?.call();
      if (!_guardPrincipal()) return;
      if (error != null) {
        setState(() => _error = error);
        return;
      }
      if (!mounted) return;
      if (widget.onContinue != null) await widget.onContinue!(context);
    } catch (error) {
      debugPrint(
        'SELAH: verified setup completion failed (${error.runtimeType}).',
      );
      if (mounted) {
        setState(() {
          _error = "We couldn't finish setup. Please try again.";
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _devSkip() async {
    if (!_isDevPreview ||
        widget.requireDuplicateResolution ||
        widget.onDevSkip == null ||
        _busy ||
        !_guardPrincipal()) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // Deliberately separate from _continue: no consent, provider result,
      // verified-state fixture, or signup finalisation is manufactured here.
      if (_guardPrincipal()) await widget.onDevSkip!(context);
    } catch (_) {
      if (mounted && SelahDeveloperAccess.canUseDeveloperTools) {
        setState(() => _error = 'The preview could not continue. Try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _devSkipButton() => SizedBox(
    width: double.infinity,
    height: 42,
    child: TextButton(
      key: const ValueKey('identity_dev_skip'),
      onPressed: _busy ? null : _devSkip,
      child: Text(
        'Skip · DEV',
        style: SelahText.button(size: 12, color: SelahColors.journeyGold),
      ),
    ),
  );

  bool get _showDevSkip =>
      _isDevPreview &&
      !widget.requireDuplicateResolution &&
      widget.onDevSkip != null &&
      SelahDeveloperAccess.canUseDeveloperTools;

  Future<void> _leave({required bool deleteAttempt}) async {
    if (_busy || !_guardPrincipal()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (deleteAttempt && !_isDevPreview && !_attemptDeleted) {
        final deleted =
            await SelahIdentityVerificationService.deleteMyUnstartedAttempt(
              expectedUserId: _screenUserId,
            );
        if (!_guardPrincipal()) return;
        if (!deleted) {
          setState(() {
            _error = "We couldn't confirm deletion. Please try again.";
          });
          return;
        }
        _attemptDeleted = true;
      }
      if (!_guardPrincipal()) return;
      if (!_isDevPreview) {
        await SelahAuth.signOut(expectedUserId: _screenUserId);
      }
      if (!mounted) return;
      if (_isDevPreview) {
        setState(() {
          _state = null;
        });
        return;
      }
      // Successful sign-out removes A's session. Never navigate over B if
      // another sign-in completed while cleanup was awaiting its stores.
      if (SelahAuth.currentUser != null) {
        _guardPrincipal();
        return;
      }
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
        (_) => false,
      );
    } catch (error) {
      debugPrint('SELAH: identity check exit failed (${error.runtimeType}).');
      if (!mounted) return;
      if (!_isDevPreview && SelahAuth.currentUser == null) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const WelcomeScreen()),
          (_) => false,
        );
      } else {
        setState(() {
          _error = _attemptDeleted
              ? 'Your verification attempt was deleted, but sign-out could not '
                    'be completed. Please try signing out again.'
              : "We couldn't finish signing out. Please try again.";
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _setDevState(SelahIdentityVerificationResult result) {
    if (!_isDevPreview || !_guardPrincipal()) return;
    setState(() {
      _launchOutcome = null;
      _error = null;
      _state = _devState(
        result,
        duplicate: result == SelahIdentityVerificationResult.verified
            ? SelahDuplicateReviewState.clear
            : result == SelahIdentityVerificationResult.reviewRequired
            ? SelahDuplicateReviewState.reviewRequired
            : SelahDuplicateReviewState.notEvaluated,
        consentGranted: result != SelahIdentityVerificationResult.cancelled,
      );
    });
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: SelahDeveloperAccess.authorizationChanges,
    builder: (context, _) {
      if (_isDevPreview && !SelahDeveloperAccess.canUseDeveloperTools) {
        return Scaffold(
          key: const ValueKey('identity_preview_denied'),
          backgroundColor: SelahColors.modalSheetSurface,
          body: const SizedBox.expand(),
        );
      }
      return _buildIdentity(context);
    },
  );

  Widget _buildIdentity(BuildContext context) {
    final state = _state;
    final previewStyle = OnboardingPreviewStyle.effectiveStyleOf(context);
    return Scaffold(
      body: Container(
        constraints: const BoxConstraints.expand(),
        decoration: BoxDecoration(
          gradient:
              previewStyle?.backgroundGradient ?? SelahColors.brandGradient,
        ),
        child: SafeArea(
          child: !_hasOriginalPrincipal
              ? _buildSessionChanged()
              : state == null
              ? _buildConsent()
              : _buildState(state),
        ),
      ),
    );
  }

  Widget _buildSessionChanged() => Padding(
    key: const ValueKey('identity-session-changed'),
    padding: const EdgeInsets.fromLTRB(26, 22, 26, 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Text(
            'Selah',
            style: SelahText.wordmark(
              size: 20,
              color: SelahColors.splashWordmark,
            ),
          ),
        ),
        const Spacer(),
        const _IconMark(icon: Icons.lock_outline),
        const SizedBox(height: 22),
        Text('Your sign-in has changed.', style: SelahText.heading(size: 28)),
        const SizedBox(height: 12),
        Text(
          'Close and reopen Selah to continue with your current account. '
          'No verification access has been granted from this page.',
          style: SelahText.body(size: 14.2).copyWith(height: 1.5),
        ),
        const Spacer(),
      ],
    ),
  );

  Widget _buildConsent() => Padding(
    padding: const EdgeInsets.fromLTRB(26, 22, 26, 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Selah',
              style: SelahText.wordmark(
                size: 20,
                color: SelahColors.splashWordmark,
              ),
            ),
            const Spacer(),
            Text(
              'IDENTITY CHECK',
              style: SelahText.chapterLabel(color: SelahColors.ink(0.46)),
            ),
          ],
        ),
        const SizedBox(height: 34),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _IconMark(icon: Icons.verified_user_outlined),
                const SizedBox(height: 22),
                Text(
                  kIdentityVerificationConsentTitle,
                  style: SelahText.heading(size: 28),
                ),
                const SizedBox(height: 14),
                Text(
                  kIdentityVerificationConsentBody,
                  style: SelahText.body(size: 14.2).copyWith(height: 1.55),
                ),
                const SizedBox(height: 10),
                TextButton(
                  key: const ValueKey('identity-privacy-policy'),
                  onPressed: _busy
                      ? null
                      : () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                const IdentityVerificationPrivacyScreen(),
                          ),
                        ),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    foregroundColor: SelahColors.unlockText,
                  ),
                  child: Text(
                    'Privacy policy',
                    style: SelahText.body(
                      size: 13,
                      color: SelahColors.unlockText,
                    ),
                  ),
                ),
                if (_error != null) _ErrorText(_error!),
              ],
            ),
          ),
        ),
        if (_showDevSkip) _devSkipButton(),
        _PrimaryButton(
          key: const ValueKey('identity-consent-agree'),
          label: 'I agree — verify me',
          busy: _busy,
          onPressed: () => _recordConsent(true),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: TextButton(
            key: const ValueKey('identity-consent-decline'),
            onPressed: _busy ? null : () => _recordConsent(false),
            child: Text(
              "I don't consent",
              style: SelahText.button(size: 14, color: SelahColors.ink(0.70)),
            ),
          ),
        ),
        if (_showsSignupAccountExit) _signupAccountExitButton(),
      ],
    ),
  );

  Widget _buildState(SelahIdentityVerificationState state) {
    if (!state.consentGranted ||
        state.result == SelahIdentityVerificationResult.cancelled) {
      return _buildRefusal();
    }
    final activeJourneyHold =
        state.allowsApp &&
        widget.requireDuplicateResolution &&
        !state.allowsActiveJourney;
    final presentation = _presentationFor(
      state,
      activeJourneyHold: activeJourneyHold,
      providerUnavailable: _providerUnavailable,
      launchOutcome: _launchOutcome,
    );
    final mayContinue = _allowsState(state);

    return Padding(
      padding: const EdgeInsets.fromLTRB(26, 22, 26, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Text(
              'Selah',
              style: SelahText.wordmark(
                size: 20,
                color: SelahColors.splashWordmark,
              ),
            ),
          ),
          const SizedBox(height: 26),
          Expanded(
            child: ListView(
              children: [
                _IconMark(icon: presentation.icon),
                const SizedBox(height: 22),
                Text(presentation.title, style: SelahText.heading(size: 28)),
                const SizedBox(height: 12),
                Text(
                  presentation.body,
                  style: SelahText.body(size: 14.2).copyWith(height: 1.5),
                ),
                if (_error != null) _ErrorText(_error!),
                if (_isDevPreview) ...[
                  const SizedBox(height: 24),
                  _DevStateControls(
                    selected: state.result,
                    onSelected: _setDevState,
                  ),
                ],
              ],
            ),
          ),
          if (_showDevSkip) _devSkipButton(),
          if (mayContinue)
            if (_isDevPreview && SelahOnboardingArrowScope.enabledOf(context))
              Center(
                child: SelahOnboardingArrowAction(
                  key: const ValueKey('identity-continue'),
                  active: !_busy,
                  onPressed: _continue,
                  semanticLabel: widget.requireDuplicateResolution
                      ? 'Return to Journey'
                      : 'Continue to Selah',
                ),
              )
            else
              _PrimaryButton(
                key: const ValueKey('identity-continue'),
                label: widget.requireDuplicateResolution
                    ? 'Return to Journey'
                    : 'Continue to Selah',
                busy: _busy,
                onPressed: _continue,
              )
          else ...[
            if (state.result ==
                    SelahIdentityVerificationResult.reviewRequired ||
                activeJourneyHold)
              _PrimaryButton(
                key: const ValueKey('identity-refresh'),
                label: 'Check again',
                busy: _busy,
                onPressed: _isDevPreview ? null : _refresh,
              )
            else
              _PrimaryButton(
                key: const ValueKey('identity-retry'),
                label:
                    state.result == SelahIdentityVerificationResult.pending &&
                        !_providerUnavailable &&
                        _launchOutcome !=
                            SelahVerificationLaunchOutcome.failed &&
                        _launchOutcome !=
                            SelahVerificationLaunchOutcome.cancelled
                    ? 'Start or resume check'
                    : 'Try again',
                busy: _busy,
                onPressed: _launchProvider,
              ),
            if (state.result == SelahIdentityVerificationResult.pending) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  key: const ValueKey('identity-refresh'),
                  onPressed: _busy || _isDevPreview ? null : _refresh,
                  child: const Text('Check for a result'),
                ),
              ),
            ],
          ],
          if (_showsSignupAccountExit) _signupAccountExitButton(),
        ],
      ),
    );
  }

  Widget _buildRefusal() => Padding(
    padding: const EdgeInsets.fromLTRB(26, 22, 26, 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Text(
            'Selah',
            style: SelahText.wordmark(
              size: 20,
              color: SelahColors.splashWordmark,
            ),
          ),
        ),
        const Spacer(),
        const _IconMark(icon: Icons.lock_outline),
        const SizedBox(height: 22),
        Text('Verification is required.', style: SelahText.heading(size: 28)),
        const SizedBox(height: 12),
        Text(
          'Without identity verification, a Selah account cannot be created '
          'and the app cannot open. You can return and consent, or delete '
          'this verification attempt.',
          style: SelahText.body(size: 14.2).copyWith(height: 1.5),
        ),
        if (_error != null) _ErrorText(_error!),
        const Spacer(),
        if (_showDevSkip) _devSkipButton(),
        _PrimaryButton(
          key: const ValueKey('identity-return-to-consent'),
          label: 'Review consent again',
          busy: _busy,
          onPressed: () => setState(() {
            _state = null;
            _error = null;
          }),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: TextButton(
            key: const ValueKey('identity-delete-attempt'),
            onPressed: _busy
                ? null
                : () => _leave(deleteAttempt: !_attemptDeleted),
            child: Text(
              _attemptDeleted
                  ? 'Use a different account'
                  : 'Delete verification attempt',
              style: SelahText.button(size: 13, color: SelahColors.ink(0.62)),
            ),
          ),
        ),
        if (_showsSignupAccountExit && !_attemptDeleted)
          _signupAccountExitButton(),
      ],
    ),
  );

  Widget _signupAccountExitButton() => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: SizedBox(
      width: double.infinity,
      height: 44,
      child: TextButton(
        key: const ValueKey('identity-use-different-account'),
        onPressed: _busy ? null : () => _leave(deleteAttempt: false),
        child: Text(
          'Use a different account',
          style: SelahText.button(size: 13, color: SelahColors.ink(0.62)),
        ),
      ),
    ),
  );
}

({String title, String body, IconData icon}) _presentationFor(
  SelahIdentityVerificationState state, {
  required bool activeJourneyHold,
  required bool providerUnavailable,
  required SelahVerificationLaunchOutcome? launchOutcome,
}) {
  if (activeJourneyHold) {
    return (
      title: 'A review is still in progress.',
      body:
          'Your identity is confirmed, but the additional review required '
          'for an Active Journey has not finished. No other account details '
          'are shown to you. Your Journey remains safe and unchanged.',
      icon: Icons.manage_search_outlined,
    );
  }
  // Pending is also written when consent is recorded, before any capture.
  // The public state has no provider-start signal: neither consent, a local
  // launch callback nor an app restart proves that a check is in progress.
  final canStartCheck =
      !state.allowsApp &&
      state.result != SelahIdentityVerificationResult.reviewRequired;
  if (canStartCheck &&
      providerUnavailable &&
      (state.result == SelahIdentityVerificationResult.pending ||
          state.result == SelahIdentityVerificationResult.retryRequired ||
          launchOutcome == SelahVerificationLaunchOutcome.unavailable)) {
    return (
      title: 'Verification is unavailable.',
      body:
          'The identity check cannot open right now. Your identity has not '
          'been verified, and Selah remains locked. Please try again later.',
      icon: Icons.shield_outlined,
    );
  }
  if (canStartCheck && launchOutcome == SelahVerificationLaunchOutcome.failed) {
    return (
      title: "The identity check couldn't open.",
      body:
          'Your identity has not been verified. Please try opening the '
          'check again. Selah remains locked.',
      icon: Icons.refresh_rounded,
    );
  }
  if (canStartCheck &&
      launchOutcome == SelahVerificationLaunchOutcome.cancelled) {
    return (
      title: 'The identity check was closed.',
      body:
          'Your identity has not been verified. You can reopen the check '
          'when you are ready. Selah remains locked.',
      icon: Icons.refresh_rounded,
    );
  }
  return switch (state.result) {
    SelahIdentityVerificationResult.pending => (
      title: "Your identity isn't verified yet.",
      body:
          'Complete the identity check to continue. If you have already '
          'submitted it, check for the latest result. Selah stays locked '
          'until verification is confirmed.',
      icon: Icons.verified_user_outlined,
    ),
    SelahIdentityVerificationResult.verified => (
      title: 'Identity verified.',
      body:
          'Your verification result has been confirmed. Selah stores only '
          'this result and the minimal provider reference — never your ID '
          'document, selfie or face data.',
      icon: Icons.verified_outlined,
    ),
    SelahIdentityVerificationResult.retryRequired => (
      title: "Let's try that again.",
      body:
          'No verification grant was made. Start the check again when you '
          'are ready; a retry does not count against you.',
      icon: Icons.refresh_rounded,
    ),
    SelahIdentityVerificationResult.reviewRequired => (
      title: 'A manual review is needed.',
      body:
          'A trained reviewer will check the verification. This does not '
          'automatically reject or ban you, and Selah will not reveal any '
          'other account.',
      icon: Icons.manage_search_outlined,
    ),
    SelahIdentityVerificationResult.failed => (
      title: "We couldn't verify your identity.",
      body:
          'No account access was granted. You can try the verification '
          'again; the result is neutral and no automatic ban is applied.',
      icon: Icons.shield_outlined,
    ),
    SelahIdentityVerificationResult.expired => (
      title: 'This check expired.',
      body:
          'No account access was granted. Start a new check when you are '
          'ready.',
      icon: Icons.schedule_outlined,
    ),
    SelahIdentityVerificationResult.cancelled => (
      title: 'Verification cancelled.',
      body: 'No account access was granted.',
      icon: Icons.lock_outline,
    ),
  };
}

class _IconMark extends StatelessWidget {
  final IconData icon;
  const _IconMark({required this.icon});

  @override
  Widget build(BuildContext context) {
    final previewStyle = OnboardingPreviewStyle.effectiveStyleOf(context);
    if (previewStyle != null) {
      return SizedBox(
        width: 70,
        height: 70,
        child: Stack(
          children: [
            OnboardingPreviewAccent(style: previewStyle, size: 70, progress: 1),
            Positioned(
              right: 0,
              bottom: 0,
              child: Icon(icon, color: SelahColors.unlockText, size: 19),
            ),
          ],
        ),
      );
    }
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: SelahColors.frostFill,
        border: Border.all(
          color: SelahColors.unlockDot.withValues(alpha: 0.72),
        ),
      ),
      child: Icon(icon, color: SelahColors.unlockText, size: 25),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final bool busy;
  final VoidCallback? onPressed;

  const _PrimaryButton({
    super.key,
    required this.label,
    required this.busy,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final previewStyle = OnboardingPreviewStyle.effectiveStyleOf(context);
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton(
        onPressed: busy ? null : onPressed,
        style: previewStyle?.primaryButtonStyle,
        child: busy
            ? const SizedBox(width: 18, height: 18, child: SelahLoading())
            : Text(label, textAlign: TextAlign.center),
      ),
    );
  }
}

class _ErrorText extends StatelessWidget {
  final String text;
  const _ErrorText(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 14),
    child: Text(
      text,
      style: SelahText.subtext(size: 12, color: SelahColors.destructive),
    ),
  );
}

class _DevStateControls extends StatelessWidget {
  final SelahIdentityVerificationResult selected;
  final ValueChanged<SelahIdentityVerificationResult> onSelected;

  const _DevStateControls({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final previewStyle = OnboardingPreviewStyle.maybeOf(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration:
          previewStyle?.cardDecoration() ??
          BoxDecoration(
            color: SelahColors.iconButtonBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: SelahColors.iconButtonBorder),
          ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'DEVELOPER STATE · LOCAL ONLY',
            style: SelahText.chapterLabel(color: SelahColors.ink(0.46)),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              for (final result in SelahIdentityVerificationResult.values)
                ChoiceChip(
                  key: ValueKey('identity-dev-${result.storageValue}'),
                  label: Text(result.storageValue.replaceAll('_', ' ')),
                  selected: selected == result,
                  onSelected: (_) => onSelected(result),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Temporary Phase A destination. It links to the truthful current summary
/// while making clear that Fable's full policy is not yet published.
class IdentityVerificationPrivacyScreen extends StatelessWidget {
  const IdentityVerificationPrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final previewStyle = OnboardingPreviewStyle.effectiveStyleOf(context);
    return Scaffold(
      body: Container(
        constraints: const BoxConstraints.expand(),
        decoration: BoxDecoration(
          gradient:
              previewStyle?.backgroundGradient ?? SelahColors.brandGradient,
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  tooltip: 'Back',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.chevron_left, color: SelahColors.ink(0.70)),
                ),
                const SizedBox(height: 22),
                if (previewStyle != null) ...[
                  OnboardingPreviewAccent(
                    style: previewStyle,
                    size: 50,
                    progress: 1,
                  ),
                  const SizedBox(height: 12),
                ],
                Text(
                  'Identity verification privacy',
                  style: SelahText.heading(size: 27),
                ),
                const SizedBox(height: 12),
                Text(
                  'The full Privacy Policy is being prepared. In this flow, '
                  'Sumsub processes the ID document, selfie and face data on '
                  'its systems. Selah is designed to retain only the consent '
                  'record, provider reference, coarse result, duplicate-review '
                  'flag and timestamps.',
                  style: SelahText.body(size: 14).copyWith(height: 1.5),
                ),
                const SizedBox(height: 18),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const PrivacyAndDataScreen(),
                    ),
                  ),
                  child: const Text('Read current privacy & data summary'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
