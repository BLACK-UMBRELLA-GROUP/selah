import 'package:flutter/material.dart';

import '../../theme/selah_colors.dart';
import '../../theme/selah_text.dart';
import '../../services/selah_profile_service.dart';
import '../../services/selah_developer_access.dart';
import '../../services/selah_internal_preview_client.dart';
import '../../services/selah_initial_signup_draft_service.dart';
import '../../services/selah_auth.dart';
import '../../services/selah_onboarding_answers_service.dart';
import '../../services/selah_seeker_details_service.dart';
import '../../services/selah_photo_service.dart';
import '../../services/selah_consent_service.dart';
import '../../services/selah_account_state.dart';
import '../../models/seeker_setup_checkpoint.dart';
import '../../state/app_state.dart';
import '../../widgets/selah_onboarding_account_exit.dart';
import '../../widgets/selah_loading.dart';
import '../../widgets/selah_glass_dialog.dart';
import '../../widgets/selah_onboarding_direction_style.dart';
import '../../widgets/selah_onboarding_continue_action.dart';
import '../home/home_shell.dart';
import '../mentor/mentor_onboarding_flow.dart';
import 'chapter2_flow.dart';
import 'bio_onboarding_flow.dart';
import 'onboarding_stage_intro_screen.dart';
import 'values_preferences_flow.dart';
import 'profile_ready_screen.dart';

/// The explicit Seeker handoff after the short account essentials and the
/// mandatory identity check. The account may open before the longer profile
/// journey is finished; neither action publishes an incomplete profile.
///
/// This screen never decides IDV admission. Its caller must first complete
/// the existing server-verified finalization. A protected local rehearsal
/// retains its requested mode even if developer authority disappears.
class SeekerPostIdentityChoiceScreen extends StatefulWidget {
  final bool devPreview;
  final String? expectedUserId;

  const SeekerPostIdentityChoiceScreen({
    super.key,
    this.devPreview = false,
    this.expectedUserId,
  });

  static const previewIncompleteProgress = SelahOnboardingProgress(
    complete: false,
    due: 0,
    missing: 0,
    hasChapter2: false,
    basicProfile: false,
  );

  @override
  State<SeekerPostIdentityChoiceScreen> createState() =>
      _SeekerPostIdentityChoiceScreenState();
}

class _SeekerPostIdentityChoiceScreenState
    extends State<SeekerPostIdentityChoiceScreen> {
  late final int _ownerGeneration;
  bool _navigating = false;
  bool get devPreview => widget.devPreview;
  String? get expectedUserId => widget.expectedUserId;

  bool get _previewAllowed =>
      SelahDeveloperAccess.canUseDeveloperTools &&
      SelahInternalPreviewClient.isActive;

  @override
  void initState() {
    super.initState();
    _ownerGeneration = SelahAccountState.generation;
  }

  bool _mayNavigate(BuildContext context) {
    if (!mounted ||
        !context.mounted ||
        ModalRoute.of(context)?.isCurrent != true ||
        _navigating) {
      return false;
    }
    if (devPreview) return _previewAllowed;
    try {
      if (SelahAccountState.isSigningOut ||
          SelahAccountState.generation != _ownerGeneration) {
        throw StateError('Account epoch changed.');
      }
      final userId = expectedUserId;
      if (userId == null || userId.isEmpty) throw StateError('No owner.');
      SelahInitialSignupDraftService.repository.requireOwner(userId);
      return true;
    } catch (_) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text(
            'Your account changed. Sign in again to continue setup.',
          ),
        ),
      );
      return false;
    }
  }

  void _continueSetup(BuildContext context) {
    if (!_mayNavigate(context)) return;
    _navigating = true;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        allowSnapshotting: !devPreview,
        builder: (_) => SeekerOnboardingOverviewScreen(
          gender: AppState.instance.gender,
          progress: devPreview
              ? SeekerPostIdentityChoiceScreen.previewIncompleteProgress
              : null,
          devPreview: devPreview,
        ),
      ),
      (_) => false,
    );
  }

  void _finishLater(BuildContext context) {
    if (!_mayNavigate(context)) return;
    _navigating = true;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        allowSnapshotting: !devPreview,
        builder: (_) => HomeShell(
          initialTab: 2,
          deferredOnboardingDevPreview: devPreview,
          initialOnboardingProgress: devPreview
              ? SeekerPostIdentityChoiceScreen.previewIncompleteProgress
              : null,
        ),
      ),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: SelahDeveloperAccess.authorizationChanges,
    builder: (context, _) {
      if (devPreview && !_previewAllowed) {
        return Scaffold(
          key: const ValueKey('seeker_post_identity_preview_denied'),
          backgroundColor: SelahColors.modalSheetSurface,
          body: const SizedBox.expand(),
        );
      }
      final previewStyle = OnboardingPreviewStyle.effectiveStyleOf(context);
      final compact = MediaQuery.sizeOf(context).height < 650;
      return Scaffold(
        key: const ValueKey('seeker_post_identity_choice'),
        body: Container(
          constraints: const BoxConstraints.expand(),
          decoration: BoxDecoration(
            gradient:
                previewStyle?.backgroundGradient ?? SelahColors.brandGradient,
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Selah',
                    textAlign: TextAlign.center,
                    style: SelahText.wordmark(
                      size: 20,
                      color: SelahColors.splashWordmark,
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: previewStyle?.centered == true
                            ? CrossAxisAlignment.center
                            : CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: compact ? 30 : 64),
                          if (previewStyle != null) ...[
                            OnboardingPreviewAccent(
                              style: previewStyle,
                              size: compact ? 38 : 52,
                              progress: 1,
                            ),
                            const SizedBox(height: 18),
                          ] else ...[
                            Icon(
                              Icons.check_circle_outline,
                              size: 42,
                              color: SelahColors.unlockText,
                            ),
                            const SizedBox(height: 20),
                          ],
                          Text(
                            'Your account is ready.',
                            textAlign: previewStyle?.centered == true
                                ? TextAlign.center
                                : TextAlign.left,
                            style: SelahText.heading(
                              size: compact
                                  ? 24
                                  : previewStyle?.titleSize ?? 30,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'Would you like to keep building your profile now, '
                            'or explore My Selah and finish later?',
                            textAlign: previewStyle?.centered == true
                                ? TextAlign.center
                                : TextAlign.left,
                            style: SelahText.body(
                              size: 14,
                            ).copyWith(height: 1.5),
                          ),
                          SizedBox(height: compact ? 24 : 36),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: SelahColors.modalSheetSurface,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: SelahColors.splashWordmark.withValues(
                                  alpha: .18,
                                ),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    ExcludeSemantics(
                                      child: Icon(
                                        Icons.lock_outline_rounded,
                                        size: 16,
                                        color: SelahColors.splashWordmark,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'IF YOU FINISH LATER',
                                        style: SelahText.chapterLabel(
                                          color: SelahColors.splashWordmark,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Your progress is waiting in My Selah. Your '
                                  'profile stays hidden and Discovery and '
                                  'Journeys remain locked until your setup is '
                                  'complete.',
                                  style: SelahText.body(
                                    size: 13.5,
                                  ).copyWith(height: 1.5),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    key: const ValueKey('seeker_post_identity_continue_setup'),
                    onPressed: () => _continueSetup(context),
                    // This handoff is a choice, not another full-gold question
                    // CTA. Keep its treatment local to avoid changing the
                    // selected direction's buttons on other onboarding pages.
                    style: FilledButton.styleFrom(
                      backgroundColor: Color.alphaBlend(
                        SelahColors.splashWordmark.withValues(alpha: .06),
                        SelahColors.modalSheetSurface,
                      ),
                      foregroundColor: SelahColors.foreground,
                      side: BorderSide(
                        color: SelahColors.splashWordmark.withValues(
                          alpha: .55,
                        ),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      minimumSize: const Size.fromHeight(56),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      textStyle: SelahText.button(size: 14),
                    ),
                    child: Row(
                      children: [
                        const Expanded(child: Text('Continue profile setup')),
                        const SizedBox(width: 12),
                        ExcludeSemantics(
                          child: Icon(
                            Icons.arrow_forward_rounded,
                            size: 20,
                            color: SelahColors.splashWordmark,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    key: const ValueKey('seeker_post_identity_finish_later'),
                    onPressed: () => _finishLater(context),
                    style: TextButton.styleFrom(
                      foregroundColor: SelahColors.foregroundSecondary,
                      minimumSize: const Size.fromHeight(48),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      textStyle: SelahText.button(size: 13),
                    ),
                    child: const Text(
                      'Go to My Selah · finish later',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

/// A calm orientation screen before a long onboarding path begins.
///
/// Founder-approved direction, 2026-08-19: signup chooses which experience
/// to begin with, but one trusted identity can later carry both the Seeker
/// and Shepherd experiences. This screen explains the chosen path without
/// presenting it as a permanent account-type decision.
class SeekerOnboardingOverviewScreen extends StatefulWidget {
  final String? gender;
  final bool migrationGatedPreview;
  final SelahOnboardingProgress? progress;
  final bool devPreview;
  final Future<SelahOnboardingProgress?> Function()? progressLoader;
  final Future<SelahOnboardingAnswersSnapshot?> Function()? answersLoader;
  final Future<bool> Function()? profileCompleteLoader;

  const SeekerOnboardingOverviewScreen({
    super.key,
    required this.gender,
    this.migrationGatedPreview = false,
    this.progress,
    this.devPreview = false,
    this.progressLoader,
    this.answersLoader,
    this.profileCompleteLoader,
  });

  @override
  State<SeekerOnboardingOverviewScreen> createState() =>
      _SeekerOnboardingOverviewScreenState();
}

class _SeekerOnboardingOverviewScreenState
    extends State<SeekerOnboardingOverviewScreen> {
  SeekerSetupCheckpoint? _checkpoint;
  String? _error;
  String? _owner;
  late int _ownerGeneration;
  bool _loading = true;
  bool _navigating = false;
  SeekerDetails? _loadedDetails;

  @override
  void initState() {
    super.initState();
    _ownerGeneration = SelahAccountState.generation;
    if (!widget.devPreview &&
        !widget.migrationGatedPreview &&
        widget.progressLoader == null) {
      try {
        _owner = SelahAuth.currentUser?.id;
      } catch (_) {
        /* Fail closed in _load. */
      }
    }
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    if (widget.devPreview || widget.migrationGatedPreview) {
      final progress =
          widget.progress ??
          SeekerPostIdentityChoiceScreen.previewIncompleteProgress;
      _checkpoint = SeekerSetupCheckpoint.select(
        progress: progress,
        bioReviewed: AppState.instance.journeyBio.reviewed,
      );
      setState(() => _loading = false);
      return;
    }
    try {
      if (widget.progressLoader == null &&
          (_owner == null || SelahAuth.currentUser?.id != _owner)) {
        throw StateError('Account changed.');
      }
      // A Dashboard count may be stale. Refresh before choosing the route;
      // failed reads must not start an empty chapter over a saved draft.
      final progress =
          await (widget.progressLoader?.call() ??
                  SelahProfileService.fetchOnboardingProgress())
              .timeout(const Duration(seconds: 10));
      final snapshot =
          await (widget.answersLoader?.call() ??
                  SelahOnboardingAnswersService.fetchOwn(
                    expectedUserId: _owner,
                    throwOnError: true,
                  ))
              .timeout(const Duration(seconds: 10));
      final profileComplete =
          await (widget.profileCompleteLoader?.call() ?? _loadProfileComplete())
              .timeout(const Duration(seconds: 10));
      if (!mounted) return;
      if (progress == null ||
          (widget.progressLoader == null &&
              (SelahAuth.currentUser?.id != _owner ||
                  SelahAccountState.generation != _ownerGeneration))) {
        throw StateError('Progress unavailable.');
      }
      if (snapshot != null) {
        AppState.instance.saveJourneyBio(snapshot.journeyBio);
      }
      _checkpoint = SeekerSetupCheckpoint.select(
        progress: progress,
        profileSectionComplete: profileComplete,
        bioReviewed: snapshot?.journeyBio.reviewed ?? false,
        compatibilityStarted:
            snapshot?.ch3Answers.keys.any((key) => !key.startsWith('bio_')) ==
                true ||
            snapshot?.ch4Preferences.isNotEmpty == true,
      );
      setState(() => _loading = false);
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error =
              'Your saved setup could not be loaded. Try again to continue safely.';
        });
      }
    }
  }

  Future<bool> _loadProfileComplete() async {
    final owner = _owner;
    if (owner == null) throw StateError('No owner.');
    final values = await Future.wait<dynamic>([
      SelahSeekerDetailsService.fetchOwn(
        expectedUserId: owner,
        throwOnError: true,
      ),
      SelahPhotoService.fetchOwnPhotos(
        expectedUserId: owner,
        throwOnError: true,
      ),
      SelahProfileService.fetchOwnLocation(expectedUserId: owner),
      SelahConsentService.currentArticle9Decision(
        expectedUserId: owner,
        throwOnError: true,
      ),
    ]);
    if (!mounted ||
        SelahAuth.currentUser?.id != owner ||
        !SelahAccountState.isCurrent(owner, _ownerGeneration)) {
      throw StateError('Account changed.');
    }
    _loadedDetails = values[0] as SeekerDetails?;
    return seekerProfileSectionComplete(
      details: values[0] as SeekerDetails?,
      photoCount: (values[1] as List).length,
      location: values[2] as String?,
      article9Consent: values[3] as bool?,
    );
  }

  void _openQuestions() {
    if (_navigating || _checkpoint == null || !mounted) return;
    if (widget.devPreview &&
        (!SelahDeveloperAccess.canUseDeveloperTools ||
            !SelahInternalPreviewClient.isActive)) {
      return;
    }
    if (!widget.devPreview &&
        widget.progressLoader == null &&
        (SelahAuth.currentUser?.id != _owner ||
            SelahAccountState.generation != _ownerGeneration)) {
      setState(
        () => _error = 'Your account changed. Sign in again to continue.',
      );
      return;
    }
    final gender = widget.gender ?? AppState.instance.gender;
    if (_checkpoint == SeekerSetupCheckpoint.compatibility &&
        gender != 'male' &&
        gender != 'female') {
      setState(
        () => _error =
            'Your account details could not be loaded. Sign in again to continue.',
      );
      return;
    }
    _navigating = true;
    final preferences =
        _loadedDetails?.preferences ?? const <String, dynamic>{};
    final owner = _owner;
    final generation = _ownerGeneration;
    final devPreview = widget.devPreview;
    Map<String, dynamic> readSignUpPreferences() =>
        !devPreview &&
            owner != null &&
            SelahAuth.currentUser?.id == owner &&
            SelahAccountState.isCurrent(owner, generation)
        ? preferences
        : const {};
    final Widget next = switch (_checkpoint!) {
      SeekerSetupCheckpoint.profile => Chapter2Flow(
        gender: gender,
        devPreview: widget.devPreview,
      ),
      SeekerSetupCheckpoint.bio => BioOnboardingFlow(
        gender: gender,
        devPreview: widget.devPreview,
        readSignUpPreferences: readSignUpPreferences,
      ),
      SeekerSetupCheckpoint.compatibility => ValuesPreferencesFlow(
        gender: gender!,
        devPreview: widget.devPreview,
        readSignUpPreferences: readSignUpPreferences,
      ),
      SeekerSetupCheckpoint.review => ProfileReadyScreen(
        devPreview: widget.devPreview,
      ),
    };
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        allowSnapshotting: !widget.devPreview,
        builder: (_) => next,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.devPreview &&
        (!SelahDeveloperAccess.canUseDeveloperTools ||
            !SelahInternalPreviewClient.isActive)) {
      return Scaffold(
        key: const ValueKey('seeker_overview_preview_denied'),
        backgroundColor: SelahColors.modalSheetSurface,
        body: const SizedBox.expand(),
      );
    }
    if (widget.migrationGatedPreview) {
      return _AccountPathOverview(
        eyebrow: 'COMPLETE YOUR PROFILE',
        title: 'Continue when it suits you.',
        description:
            'Your Selah account is ready. Finish the profile journey in your '
            'own time; your saved progress will be waiting here.',
        items: [
          _OverviewItem(
            // Account essentials were completed before this four-stage
            // profile journey; the checkmark is not an extra numbered stage.
            number: '',
            title: 'Account essentials',
            description: 'Trusted identity and verification carried across',
            state: 'Shared',
            complete: true,
          ),
          _OverviewItem(
            number: '01',
            title: 'Your Profile',
            description: 'Photos and background',
            state: 'Next',
            active: true,
          ),
          const _OverviewItem(
            number: '02',
            title: 'Journey Bio',
            description: 'What you choose to share in a Journey',
            state: 'In your time',
          ),
          _OverviewItem(
            number: '03',
            title: 'Compatibility',
            description: 'Private answers and partner preferences',
            state: 'Private answers and preferences',
          ),
          if (widget.migrationGatedPreview)
            const _OverviewItem(
              number: '',
              title: 'Seeker Membership',
              description: 'Chosen and billed separately for this account',
              state: 'Choose later',
            ),
          _OverviewItem(
            number: '04',
            title: 'Review & go live',
            description: 'Review before your profile can be seen',
            state: 'Review',
          ),
        ],
        note:
            'You can use Selah now. Discovery and Journeys unlock only after '
            'your profile journey is complete.',
        buttonLabel: 'Seeker Setup Ready',
        onContinue: () {
          if (widget.devPreview &&
              (!SelahDeveloperAccess.canUseDeveloperTools ||
                  !SelahInternalPreviewClient.isActive)) {
            return;
          }
          if (widget.migrationGatedPreview) {
            showSelahGlassNotice(
              context: context,
              icon: Icons.verified_user_outlined,
              title: 'Ready for activation',
              body:
                  'The Seeker setup is ready. Activating it for an existing '
                  'Shepherd requires the approved account-context migration, '
                  'which has not been run.',
              buttonLabel: 'Understood',
            );
            return;
          }
        },
        showAccountExit: false,
        accountExitExpectedUserId: null,
        devPreview: widget.devPreview,
      );
    }
    if (_loading || _error != null) {
      return Scaffold(
        key: const ValueKey('seeker_setup_loading'),
        body: Container(
          decoration: BoxDecoration(
            gradient:
                OnboardingPreviewStyle.effectiveStyleOf(
                  context,
                )?.backgroundGradient ??
                SelahColors.brandGradient,
          ),
          child: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: _loading
                    ? const SelahLoading()
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: SelahText.body(),
                          ),
                          const SizedBox(height: 20),
                          TextButton(
                            onPressed: _load,
                            child: const Text('Try again'),
                          ),
                          if (Navigator.of(context).canPop())
                            TextButton(
                              onPressed: () => Navigator.of(context).maybePop(),
                              child: const Text('Back'),
                            ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      );
    }
    return OnboardingStageIntroScreen(
      stage: SeekerOnboardingStage.values[_checkpoint!.index],
      welcomeName: AppState.instance.name,
      devPreview: widget.devPreview,
      allowPreviewScrolling: true,
      onContinue: _openQuestions,
      onDevSkip: widget.devPreview ? _openQuestions : null,
    );
  }
}

class ShepherdOnboardingOverviewScreen extends StatefulWidget {
  /// True when this is opened from an existing Seeker account during the
  /// migration-gated preview. The screen can be reviewed end to end, but it
  /// must not call the current create-Mentor RPC: that RPC permanently assigns
  /// one role and would reject or corrupt a dual-context account.
  final bool migrationGatedPreview;
  final String? signupUserId;
  final bool devPreview;

  const ShepherdOnboardingOverviewScreen({
    super.key,
    this.migrationGatedPreview = false,
    this.signupUserId,
    this.devPreview = false,
  });

  @override
  State<ShepherdOnboardingOverviewScreen> createState() =>
      _ShepherdOnboardingOverviewScreenState();
}

class _ShepherdOnboardingOverviewScreenState
    extends State<ShepherdOnboardingOverviewScreen> {
  bool _continuing = false;
  bool get migrationGatedPreview => widget.migrationGatedPreview;
  String? get signupUserId => widget.signupUserId;
  bool get devPreview => widget.devPreview;

  void _continue() {
    if (!mounted || _continuing || ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    if (devPreview) {
      if (!SelahDeveloperAccess.canUseDeveloperTools ||
          !SelahInternalPreviewClient.isActive) {
        return;
      }
      _continuing = true;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          allowSnapshotting: false,
          builder: (_) => const MentorOnboardingFlow(devPreview: true),
        ),
      );
      return;
    }
    if (migrationGatedPreview) {
      _continuing = true;
      showSelahGlassNotice(
        context: context,
        icon: Icons.verified_user_outlined,
        title: 'Ready for activation',
        body:
            'The Shepherd setup is ready. Activating it for an existing '
            'Seeker requires the approved account-context migration, '
            'which has not been run.',
        buttonLabel: 'Understood',
      ).whenComplete(() {
        if (mounted) _continuing = false;
      });
      return;
    }
    _continuing = true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => MentorOnboardingFlow(signupUserId: signupUserId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (devPreview &&
        (!SelahDeveloperAccess.canUseDeveloperTools ||
            !SelahInternalPreviewClient.isActive)) {
      return Scaffold(
        key: const ValueKey('shepherd_overview_preview_denied'),
        backgroundColor: SelahColors.modalSheetSurface,
        body: const SizedBox.expand(),
      );
    }
    return _AccountPathOverview(
      eyebrow: 'SHEPHERD ACCOUNT',
      title: 'First, your Shepherd account.',
      description:
          'Add your account essentials, choose your membership and verify your identity. Then we’ll '
          'introduce your role, ready to support a Seeker.',
      items: [
        _OverviewItem(
          number: '',
          title: 'Account essentials',
          description: migrationGatedPreview
              ? 'Trusted identity and verification carried across'
              : 'Name, date of birth, gender, relationship and one photo',
          state: migrationGatedPreview ? 'Shared' : 'Required',
          active: true,
        ),
        if (!migrationGatedPreview)
          const _OverviewItem(
            number: '',
            title: 'Choose your membership',
            description: 'Basic, Shepherd One or Selah Family',
            state: 'Your choice',
          ),
        const _OverviewItem(
          number: '',
          title: 'Verify your identity',
          description: 'A private identity check before entering Selah',
          state: 'Required',
        ),
        const _OverviewItem(
          number: '',
          title: 'Responsibilities',
          description: 'Guidance, privacy and consent',
          state: 'Required',
        ),
      ],
      note: migrationGatedPreview
          ? 'Your login and identity stay shared. Activating the Shepherd experience is not available in this preview.'
          : 'Once your account is ready, you can invite a Seeker or accept their invitation. You do not need to be a family member.',
      buttonLabel: migrationGatedPreview
          ? 'Shepherd Setup Ready'
          : 'Begin Shepherd Setup',
      onContinue: _continue,
      showAccountExit: !migrationGatedPreview && !devPreview,
      accountExitExpectedUserId: devPreview ? null : signupUserId,
      devPreview: devPreview,
    );
  }
}

class _AccountPathOverview extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String description;
  final List<_OverviewItem> items;
  final String? note;
  final String buttonLabel;
  final VoidCallback onContinue;
  final bool showAccountExit;
  final String? accountExitExpectedUserId;
  final bool devPreview;

  const _AccountPathOverview({
    required this.eyebrow,
    required this.title,
    required this.description,
    required this.items,
    required this.buttonLabel,
    required this.onContinue,
    required this.showAccountExit,
    required this.accountExitExpectedUserId,
    required this.devPreview,
    this.note,
  });

  @override
  Widget build(BuildContext context) {
    final previewStyle = OnboardingPreviewStyle.effectiveStyleOf(context);
    final compactPreview =
        previewStyle != null &&
        (MediaQuery.sizeOf(context).height < 650 ||
            MediaQuery.textScalerOf(context).scale(1) > 1.2);
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient:
              previewStyle?.backgroundGradient ?? SelahColors.brandGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(22, 18, 22, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            tooltip: 'Back',
                            onPressed: () => Navigator.of(context).maybePop(),
                            icon: Icon(
                              Icons.chevron_left,
                              color: SelahColors.ink(0.70),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            'Selah',
                            style: SelahText.wordmark(
                              size: 18,
                              color: SelahColors.splashWordmark,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: compactPreview ? 12 : 34),
                      if (previewStyle != null) ...[
                        Align(
                          alignment: previewStyle.centered
                              ? Alignment.center
                              : Alignment.centerLeft,
                          child: OnboardingPreviewAccent(
                            style: previewStyle,
                            size: compactPreview ? 42 : 54,
                            progress: 0,
                          ),
                        ),
                        SizedBox(height: compactPreview ? 8 : 16),
                      ],
                      SizedBox(
                        width: double.infinity,
                        child: Text(
                          eyebrow,
                          textAlign: previewStyle?.centered == true
                              ? TextAlign.center
                              : TextAlign.left,
                          style: SelahText.chapterLabel(
                            color: SelahColors.ink(0.54),
                          ),
                        ),
                      ),
                      SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: Text(
                          title,
                          textAlign: previewStyle?.centered == true
                              ? TextAlign.center
                              : TextAlign.left,
                          style: SelahText.heading(
                            size: compactPreview
                                ? 20
                                : previewStyle?.titleSize ?? 27,
                          ),
                        ),
                      ),
                      SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: Text(
                          description,
                          textAlign: previewStyle?.centered == true
                              ? TextAlign.center
                              : TextAlign.left,
                          style: SelahText.subtext(size: 13.5),
                        ),
                      ),
                      SizedBox(height: 24),
                      for (final item in items) ...[
                        _OverviewRow(item: item, previewStyle: previewStyle),
                        SizedBox(height: 9),
                      ],
                      if (note != null) ...[
                        SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: SelahColors.foreground.withValues(
                              alpha: 0.05,
                            ),
                            border: Border(
                              left: BorderSide(
                                color: SelahColors.unlockDot,
                                width: 2,
                              ),
                            ),
                          ),
                          child: Text(
                            note!,
                            style: SelahText.subtext(size: 11.5),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 10, 22, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (SelahOnboardingArrowScope.enabledOf(context))
                      Center(
                        child: SelahOnboardingArrowAction(
                          key: const ValueKey('account_path_overview_continue'),
                          active: true,
                          onPressed: onContinue,
                          semanticLabel: buttonLabel,
                        ),
                      )
                    else
                      ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 50),
                        child: SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            key: const ValueKey(
                              'account_path_overview_continue',
                            ),
                            onPressed: onContinue,
                            style: previewStyle?.primaryButtonStyle,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 11),
                              child: Text(
                                buttonLabel,
                                maxLines: 2,
                                textAlign: TextAlign.center,
                                style: SelahText.button(),
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (devPreview) ...[
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          key: const ValueKey('onboarding_dev_skip'),
                          onPressed:
                              SelahDeveloperAccess.canUseDeveloperTools &&
                                  SelahInternalPreviewClient.isActive
                              ? onContinue
                              : null,
                          child: Text(
                            'Skip · DEV',
                            style: SelahText.button(
                              size: 12,
                              color: SelahColors.unlockText,
                            ),
                          ),
                        ),
                      ),
                    ],
                    if (showAccountExit &&
                        accountExitExpectedUserId != null) ...[
                      const SizedBox(height: 4),
                      SelahOnboardingAccountExit(
                        expectedUserId: accountExitExpectedUserId!,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OverviewItem {
  final String number;
  final String title;
  final String description;
  final String state;
  final bool active;
  final bool complete;

  const _OverviewItem({
    required this.number,
    required this.title,
    required this.description,
    required this.state,
    this.active = false,
    this.complete = false,
  });
}

class _OverviewRow extends StatelessWidget {
  final _OverviewItem item;
  final OnboardingPreviewStyle? previewStyle;

  const _OverviewRow({required this.item, this.previewStyle});

  @override
  Widget build(BuildContext context) {
    final stackedState =
        MediaQuery.sizeOf(context).width < 360 ||
        MediaQuery.textScalerOf(context).scale(1) > 1.2;
    final accent = item.complete
        ? SelahColors.publicText
        : item.active
        ? SelahColors.unlockText
        : SelahColors.ink(0.30);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration:
          previewStyle?.cardDecoration(
            selected: item.active || item.complete,
          ) ??
          BoxDecoration(
            color: SelahColors.frostFill,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: SelahColors.frostBorder, width: 0.5),
          ),
      child: Row(
        children: [
          Container(
            width: stackedState ? 24 : 32,
            height: stackedState ? 24 : 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withValues(alpha: 0.12),
              border: Border.all(color: accent.withValues(alpha: 0.75)),
            ),
            child: item.complete
                ? Icon(Icons.check, color: accent, size: 15)
                : item.number.isEmpty
                ? Icon(Icons.circle, color: accent, size: 6)
                : Text(
                    item.number,
                    style: SelahText.chapterLabel(color: accent),
                  ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title, style: SelahText.body(size: 14)),
                SizedBox(height: 2),
                Text(
                  item.description,
                  style: SelahText.subtext(
                    size: 10.5,
                    color: SelahColors.ink(0.38),
                  ),
                ),
                if (stackedState) ...[
                  const SizedBox(height: 5),
                  Text(
                    item.state,
                    style: SelahText.subtext(size: 10, color: accent),
                  ),
                ],
              ],
            ),
          ),
          if (!stackedState) ...[
            SizedBox(width: 10),
            Text(item.state, style: SelahText.subtext(size: 10, color: accent)),
          ],
        ],
      ),
    );
  }
}
