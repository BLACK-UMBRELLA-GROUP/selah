// Final Seeker review: server-confirmed setup and an explicit publication
// action. Visiting this page never manufactures completion or verification.
import 'package:flutter/material.dart';

import '../../main.dart';
import '../../models/seeker_setup_checkpoint.dart';
import '../../models/selah_identity_verification.dart';
import '../../services/selah_account_state.dart';
import '../../services/selah_auth.dart';
import '../../services/selah_consent_service.dart';
import '../../services/selah_developer_access.dart';
import '../../services/selah_identity_verification_service.dart';
import '../../services/selah_photo_service.dart';
import '../../services/selah_profile_service.dart';
import '../../services/selah_seeker_details_service.dart';
import '../../state/app_state.dart';
import '../../theme/selah_colors.dart';
import '../../theme/selah_text.dart';
import '../../widgets/selah_loading.dart';
import '../../widgets/selah_onboarding_direction_style.dart';
import '../auth_gate.dart';
import '../home/home_shell.dart';
import '../profile/edit_profile_screen.dart';
import '../profile/my_profile_preview_screen.dart';
import 'account_path_overview_screen.dart';
import 'identity_verification_screen.dart';

class SelahProfileReviewSnapshot {
  final SelahOnboardingProgress progress;
  final SelahIdentityVerificationState? verification;
  // Injected fixtures default to a completed profile. Live reads always set
  // this from the actual saved fields, consent, location and three photos.
  final bool profileSectionComplete;
  final SeekerDetails? details;

  const SelahProfileReviewSnapshot({
    required this.progress,
    required this.verification,
    this.profileSectionComplete = true,
    this.details,
  });

  // Optional Journey Bio prose is deliberately not a publication gate.
  bool get readyToPublish =>
      verification?.allowsApp == true &&
      profileSectionComplete &&
      progress.hasChapter2 &&
      progress.due > 0 &&
      progress.missing == 0;
}

/// Injectable boundary for isolated tests; member routes use the existing
/// own-account services and publication RPC, not test/local completion.
abstract interface class SelahProfileReviewRepository {
  String? get currentUserId;
  int get accountGeneration;
  bool isCurrentOwner(String userId, int generation);
  Future<SelahProfileReviewSnapshot> load(String userId);
  Future<bool> publish(String userId);
}

class _ServerProfileReviewRepository implements SelahProfileReviewRepository {
  const _ServerProfileReviewRepository();

  @override
  String? get currentUserId => supabaseReady ? SelahAuth.currentUser?.id : null;
  @override
  int get accountGeneration => SelahAccountState.generation;
  @override
  bool isCurrentOwner(String userId, int generation) =>
      supabaseReady &&
      SelahAccountState.isCurrent(userId, generation) &&
      SelahIdentityVerificationService.isCurrentPrincipal(userId);

  @override
  Future<SelahProfileReviewSnapshot> load(String userId) async {
    final results = await Future.wait<Object?>([
      SelahProfileService.fetchOnboardingProgress(),
      SelahIdentityVerificationService.fetchMyState(expectedUserId: userId),
      SelahSeekerDetailsService.fetchOwn(
        expectedUserId: userId,
        throwOnError: true,
      ),
      SelahPhotoService.fetchOwnPhotos(
        expectedUserId: userId,
        throwOnError: true,
      ),
      SelahProfileService.fetchOwnLocation(expectedUserId: userId),
      SelahConsentService.currentArticle9Decision(
        expectedUserId: userId,
        throwOnError: true,
      ),
    ]).timeout(const Duration(seconds: 10));
    final progress = results[0] as SelahOnboardingProgress?;
    if (progress == null) throw StateError('Review status unavailable.');
    return SelahProfileReviewSnapshot(
      progress: progress,
      verification: results[1] as SelahIdentityVerificationState?,
      details: results[2] as SeekerDetails?,
      profileSectionComplete: seekerProfileSectionComplete(
        details: results[2] as SeekerDetails?,
        photoCount: (results[3] as List<String>).length,
        location: results[4] as String?,
        article9Consent: results[5] as bool?,
      ),
    );
  }

  @override
  Future<bool> publish(String userId) => SelahProfileService.setProfileComplete(
    true,
    expectedUserId: userId,
  ).timeout(const Duration(seconds: 10));
}

class ProfileReadyScreen extends StatefulWidget {
  final bool devPreview;
  final SelahProfileReviewRepository? repository;

  const ProfileReadyScreen({
    super.key,
    this.devPreview = false,
    this.repository,
  });

  @override
  State<ProfileReadyScreen> createState() => _ProfileReadyScreenState();
}

class _ProfileReadyScreenState extends State<ProfileReadyScreen> {
  late final SelahProfileReviewRepository _repository;
  String? _owner;
  int _ownerGeneration = 0;
  SelahProfileReviewSnapshot? _snapshot;
  bool _busy = false;
  bool _publicationUnconfirmed = false;
  String? _error;

  // Requested preview mode remains sticky after authorization revocation.
  bool get _devPreview => widget.devPreview;
  bool get _currentOwner =>
      _owner != null && _repository.isCurrentOwner(_owner!, _ownerGeneration);
  bool get _canProceed =>
      mounted &&
      (_devPreview ? SelahDeveloperAccess.canUseDeveloperTools : _currentOwner);

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? const _ServerProfileReviewRepository();
    if (!_devPreview) {
      _owner = _repository.currentUserId;
      _ownerGeneration = _repository.accountGeneration;
      _loadReview();
    }
  }

  Future<void> _loadReview() async {
    if (_devPreview || _busy || !_canProceed) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final snapshot = await _repository.load(_owner!);
      if (!mounted) return;
      if (!_currentOwner) {
        setState(() => _busy = false);
        return;
      }
      setState(() {
        _snapshot = snapshot;
        _busy = false;
        _publicationUnconfirmed = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'We couldn’t confirm your saved setup. Please try again.';
      });
    }
  }

  Future<void> _goLive() async {
    if (_devPreview ||
        _busy ||
        !_canProceed ||
        _publicationUnconfirmed ||
        _snapshot?.readyToPublish != true) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // Re-read before publishing: stale progress cannot enable the action.
      final fresh = await _repository.load(_owner!);
      if (!mounted) return;
      if (!_currentOwner) {
        setState(() => _busy = false);
        return;
      }
      if (fresh.progress.complete || !fresh.readyToPublish) {
        setState(() {
          _snapshot = fresh;
          _busy = false;
        });
        return;
      }
      _publicationUnconfirmed = true;
      await _repository.publish(_owner!);
      if (!mounted) return;
      if (!_currentOwner) {
        setState(() => _busy = false);
        return;
      }
      final confirmed = await _repository.load(_owner!);
      if (!mounted) return;
      if (!_currentOwner) {
        setState(() => _busy = false);
        return;
      }
      setState(() {
        _snapshot = confirmed;
        _busy = false;
        _publicationUnconfirmed = false;
        if (!confirmed.progress.complete) {
          _error =
              'Your profile isn’t live yet. Check the remaining setup '
              'items or try again.';
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = _publicationUnconfirmed
            ? 'We couldn’t confirm whether your profile is live. Refresh '
                  'your status before trying again.'
            : 'We couldn’t confirm your saved setup. Please try again.';
      });
    }
  }

  void _openHome() {
    if (_busy || !_canProceed) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        allowSnapshotting: !_devPreview,
        builder: (_) => HomeShell(
          initialTab: 2,
          deferredOnboardingDevPreview: _devPreview,
          initialOnboardingProgress: _devPreview
              ? SeekerPostIdentityChoiceScreen.previewIncompleteProgress
              : _snapshot?.progress,
        ),
      ),
      (_) => false,
    );
  }

  Future<void> _viewProfile() async {
    if (_busy || !_canProceed) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        allowSnapshotting: !_devPreview,
        builder: (_) => const MyProfilePreviewScreen(),
      ),
    );
  }

  Future<void> _editCompatibility() async {
    // The existing editor persists member changes, so it is never opened by
    // the no-write local rehearsal.
    if (_devPreview || _busy || !_canProceed) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => EditProfileScreen(
          readSignUpPreferences: () => _canProceed
              ? _snapshot?.details?.preferences ?? const {}
              : const {},
        ),
      ),
    );
    if (_canProceed) await _loadReview();
  }

  Future<void> _verifyIdentity() async {
    if (_devPreview || _busy || !_canProceed) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => InitialIdentityCheckScreen(
          initialState: _snapshot?.verification,
          onContinue: (verificationContext) async {
            if (_canProceed && verificationContext.mounted) {
              Navigator.of(verificationContext).pop();
            }
          },
        ),
      ),
    );
    if (_canProceed) await _loadReview();
  }

  void _continueSetup() {
    if (_busy || !_canProceed) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        allowSnapshotting: !_devPreview,
        builder: (_) => SeekerOnboardingOverviewScreen(
          gender: AppState.instance.gender,
          progress: _snapshot?.progress,
          devPreview: _devPreview,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: SelahDeveloperAccess.authorizationChanges,
    builder: (context, _) {
      if (_devPreview && !SelahDeveloperAccess.canUseDeveloperTools) {
        return Scaffold(
          key: const ValueKey('profile_ready_preview_denied'),
          backgroundColor: SelahColors.modalSheetSurface,
          body: const SizedBox.expand(),
        );
      }
      final style = OnboardingPreviewStyle.effectiveStyleOf(context);
      return Scaffold(
        key: const ValueKey('profile_review_screen'),
        body: DecoratedBox(
          decoration: BoxDecoration(
            gradient: style?.backgroundGradient ?? SelahColors.brandGradient,
          ),
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
                  child: Column(
                    children: [
                      Text(
                        'Selah',
                        style: SelahText.wordmark(
                          size: 20,
                          color: SelahColors.splashWordmark,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'PROFILE SETUP · REVIEW',
                        style: SelahText.chapterLabel(),
                      ),
                    ],
                  ),
                ),
                if (_devPreview)
                  Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: TextButton(
                        key: const ValueKey('profile_ready_dev_skip'),
                        onPressed: _openHome,
                        child: Text(
                          'Skip · DEV',
                          style: SelahText.button(
                            size: 13,
                            color: SelahColors.journeyGold,
                          ),
                        ),
                      ),
                    ),
                  ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
                    child: _reviewContent(style),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                  child: _reviewActions(style),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );

  Widget _reviewContent(OnboardingPreviewStyle? style) {
    if (!_devPreview && !_currentOwner) {
      return Column(
        children: [
          Text('Your sign-in has changed.', style: SelahText.heading(size: 28)),
          const SizedBox(height: 16),
          Text(
            'Return to Selah to continue with the current account.',
            style: SelahText.body(size: 15),
            textAlign: TextAlign.center,
          ),
        ],
      );
    }
    final progress = _snapshot?.progress;
    final live = progress?.complete == true;
    final align = style?.centered == false ? TextAlign.left : TextAlign.center;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (style != null)
          Center(
            child: OnboardingPreviewAccent(style: style, size: 64, progress: 1),
          ),
        const SizedBox(height: 20),
        Text(
          live ? 'Your profile setup is complete.' : 'Review your profile.',
          textAlign: align,
          style: SelahText.heading(size: style?.titleSize ?? 29),
        ),
        const SizedBox(height: 12),
        Text(
          _devPreview
              ? 'This is a local preview. No answers, verification result or '
                    'publication are saved to your account.'
              : live
              ? 'Your setup is confirmed. You can return to My Selah.'
              : 'Check your profile and choices before you go live. You can '
                    'also leave your profile hidden and return later.',
          textAlign: align,
          style: SelahText.body(size: 14.5).copyWith(height: 1.5),
        ),
        const SizedBox(height: 24),
        if (_busy && _snapshot == null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 30),
            child: Center(child: SelahLoading(label: 'Checking saved setup…')),
          ),
        if (_devPreview || progress != null) ...[
          _ReviewStatus(
            style: style,
            icon: Icons.person_outline_rounded,
            title: 'Your profile',
            status: _devPreview
                ? 'Preview only'
                : _snapshot!.profileSectionComplete
                ? 'Saved'
                : 'Still to finish',
            complete: !_devPreview && _snapshot!.profileSectionComplete,
            // The read-only member preview still restores own photos from
            // the server; keep that reader out of the local no-write route.
            actionLabel: _devPreview ? null : 'View profile',
            onAction: _busy ? null : _viewProfile,
          ),
          const SizedBox(height: 12),
          _ReviewStatus(
            style: style,
            icon: Icons.article_outlined,
            title: 'Your Journey Bio',
            status: 'Optional · Shared only in a Journey',
          ),
          const SizedBox(height: 12),
          _ReviewStatus(
            style: style,
            icon: Icons.tune_rounded,
            title: 'Compatibility',
            status: _devPreview
                ? 'Preview only'
                : progress!.due <= 0
                ? 'Not confirmed'
                : progress.due > 0 && progress.missing == 0
                ? 'Answers and preferences saved'
                : '${progress.missing} '
                      '${progress.missing == 1 ? 'question' : 'questions'} '
                      'still to finish',
            complete:
                !_devPreview && progress!.due > 0 && progress.missing == 0,
            actionLabel: !_devPreview ? 'Review choices' : null,
            onAction: _busy ? null : _editCompatibility,
          ),
          const SizedBox(height: 12),
          _ReviewStatus(
            style: style,
            icon: Icons.verified_user_outlined,
            title: 'Identity verification',
            status: _devPreview
                ? 'Developer preview only — no production result recorded.'
                : _snapshot!.verification?.allowsApp == true
                ? 'Verified'
                : 'Not confirmed',
            complete:
                !_devPreview && _snapshot!.verification?.allowsApp == true,
          ),
          const SizedBox(height: 16),
          if (!_devPreview && !live)
            Text(
              _snapshot!.readyToPublish
                  ? 'Your saved setup is ready. Your profile becomes visible '
                        'only when you choose Go live.'
                  : 'Your profile is not ready to go live. Complete the '
                        'remaining setup items first.',
              style: SelahText.subtext(size: 13).copyWith(height: 1.5),
              textAlign: align,
            ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 16),
          Text(
            _error!,
            key: const ValueKey('profile_review_error'),
            style: SelahText.body(size: 14),
            textAlign: align,
          ),
          TextButton(
            key: const ValueKey('profile_review_retry'),
            onPressed: _busy ? null : _loadReview,
            child: Text(
              'Refresh status',
              style: SelahText.button(size: 14, color: SelahColors.journeyGold),
            ),
          ),
        ],
      ],
    );
  }

  Widget _reviewActions(OnboardingPreviewStyle? style) {
    if (!_devPreview && !_currentOwner) {
      return FilledButton(
        onPressed: () => Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AuthGate()),
          (_) => false,
        ),
        style: style?.primaryButtonStyle,
        child: Text(
          'Return to Selah',
          style: SelahText.button(color: SelahColors.luxuryDarkPurple),
        ),
      );
    }
    final progress = _snapshot?.progress;
    final live = progress?.complete == true;
    final ready = _snapshot?.readyToPublish == true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!_devPreview && !live)
          FilledButton(
            key: const ValueKey('profile_review_go_live'),
            style: style?.primaryButtonStyle,
            onPressed: _busy || !ready || _publicationUnconfirmed
                ? null
                : _goLive,
            child: Text(
              _busy ? 'Checking…' : 'Go live',
              style: SelahText.button(color: SelahColors.luxuryDarkPurple),
            ),
          ),
        if (!_devPreview &&
            !live &&
            progress != null &&
            _snapshot?.verification?.allowsApp != true)
          TextButton(
            key: const ValueKey('profile_review_verify_identity'),
            onPressed: _busy ? null : _verifyIdentity,
            child: Text(
              'Complete verification',
              style: SelahText.button(size: 14, color: SelahColors.journeyGold),
            ),
          ),
        if (!_devPreview &&
            !live &&
            progress != null &&
            (!_snapshot!.profileSectionComplete ||
                !progress.hasChapter2 ||
                progress.due <= 0 ||
                progress.missing > 0))
          TextButton(
            key: const ValueKey('profile_review_continue_setup'),
            onPressed: _busy ? null : _continueSetup,
            child: Text(
              'Continue setup',
              style: SelahText.button(size: 14, color: SelahColors.journeyGold),
            ),
          ),
        TextButton(
          key: const ValueKey('profile_review_my_selah'),
          onPressed: _busy ? null : _openHome,
          child: Text(
            'Return to My Selah',
            style: SelahText.button(size: 14, color: SelahColors.journeyGold),
          ),
        ),
      ],
    );
  }
}

class _ReviewStatus extends StatelessWidget {
  const _ReviewStatus({
    required this.style,
    required this.icon,
    required this.title,
    required this.status,
    this.complete = false,
    this.actionLabel,
    this.onAction,
  });

  final OnboardingPreviewStyle? style;
  final IconData icon;
  final String title;
  final String status;
  final bool complete;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Container(
    decoration:
        style?.cardDecoration() ??
        BoxDecoration(
          color: SelahColors.frostFill,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: SelahColors.frostBorder),
        ),
    padding: const EdgeInsets.all(16),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          complete ? Icons.check_circle_outline_rounded : icon,
          size: 22,
          color: complete ? SelahColors.journeyGold : SelahColors.ink(.54),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: SelahText.body(size: 15)),
              const SizedBox(height: 5),
              Text(status, style: SelahText.subtext(size: 12.5)),
              if (actionLabel != null)
                TextButton(
                  onPressed: onAction,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    alignment: Alignment.centerLeft,
                    foregroundColor: SelahColors.journeyGold,
                  ),
                  child: Text(
                    actionLabel!,
                    style: SelahText.button(
                      size: 13,
                      color: SelahColors.journeyGold,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}
