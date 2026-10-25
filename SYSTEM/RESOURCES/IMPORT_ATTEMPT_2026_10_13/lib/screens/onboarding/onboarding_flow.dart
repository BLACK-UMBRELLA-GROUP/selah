// Account essentials: names, gender, date of birth and first Seeker photo.
// Spec: APP/Onboarding/SEEKER ONBOARDING QUESTIONS/Onboarding Rules & UX.md.
//
// SCOPE NOTE UPDATE (2026-07-25, DR-SELAH-101 audit): the note below is
// superseded again by the progressive-onboarding model (Founder, 2026-08-26).
// This short account setup now hands off to the identity-check screen and
// then Dashboard. The existing profile, Bio and compatibility chapters stay
// intact and are resumed from inside the app rather than blocking entry.
// Original 2026-07-18 note, kept for history: "only Chapter 1 of 5 is
// built out with real questions... Continue going straight to Home for
// now... see Task #44 follow-up for building out the remaining
// chapters." That follow-up is complete.
//
// Privacy indicator assignment (from spec table, Chapter 1):
//   Name -> public, Gender -> public, Date of Birth -> private
// Background: neutral until gender is answered, then male/female per spec.

import 'package:flutter/material.dart';
import '../../state/app_state.dart';
import '../../dev/selah_dev_local_preview.dart';
import '../../theme/selah_colors.dart';
import '../../theme/selah_text.dart';
import '../../services/selah_developer_access.dart';
import '../../services/selah_account_state.dart';
import '../../services/selah_initial_signup_draft_service.dart';
import '../../models/selah_initial_signup_draft.dart';
import '../../models/selah_signup_membership_choice.dart';
import '../../models/selah_identity_verification.dart';
import '../../services/selah_identity_verification_service.dart';
import '../../services/selah_photo_service.dart';
import '../../widgets/onboarding_scaffold.dart';
import '../../widgets/selah_onboarding_name_field.dart';
import '../../widgets/selah_onboarding_choice_card.dart';
import '../../widgets/selah_signup_first_photo_card.dart';
import '../../widgets/privacy_indicator.dart';
import '../../widgets/selah_state_widgets.dart';
import '../../widgets/selah_onboarding_account_exit.dart';
import '../../widgets/selah_onboarding_direction_style.dart';
import 'account_path_overview_screen.dart';
import 'identity_verification_screen.dart';
import 'onboarding_stage_intro_screen.dart';
import 'signup_membership_choice_screen.dart';
import '../profile/selah_photo_batch_flow.dart';

class OnboardingFlow extends StatefulWidget {
  final String? welcomeName;
  final bool devPreview;
  final SelahInitialSignupDraft? initialDraft;
  final String? signupUserId;
  final SelahIdentityVerificationState? initialVerificationState;
  final SelahPhotoBatchRunner? photoRunner;
  final bool recoverExistingPhoto;

  const OnboardingFlow({
    super.key,
    this.welcomeName,
    this.devPreview = false,
    this.initialDraft,
    this.signupUserId,
    this.initialVerificationState,
    this.photoRunner,
    this.recoverExistingPhoto = false,
  });

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  bool _showStageIntroduction = true;
  int _step = 0; // 0 = name, 1 = gender, 2 = dob, 3 = first photo
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  String? _gender; // 'male' | 'female'
  DateTime? _dob;
  String? _dobError;
  String? _saveError;
  String? _signupUserId;
  late final int _signupGeneration;
  bool _saving = false;
  SelahIdentityVerificationState? _verificationState;
  SelahSignupMembershipChoice? _membershipChoice;
  bool _membershipCommitted = false;
  String? _firstPhotoPath;
  String? _firstPhotoUrl;
  bool _photoBusy = false;
  String? _photoProgress;
  int _savedPhotoCount = 0;
  bool _photoRestoreFailed = false;

  static const int _totalQuestions = 4;

  // A requested preview remains isolated when authority is revoked: never
  // reinterpret it as live signup. Capability only controls presentation/CTA.
  bool get _devPreview => widget.devPreview;
  bool get _signupAuthorized {
    if (_devPreview) return SelahDeveloperAccess.canUseDeveloperTools;
    if (_signupUserId == null ||
        SelahAccountState.isSigningOut ||
        SelahAccountState.generation != _signupGeneration) {
      return false;
    }
    try {
      SelahInitialSignupDraftService.repository.requireOwner(_signupUserId!);
      return true;
    } catch (_) {
      return false;
    }
  }

  bool get _canProceed => mounted && _signupAuthorized;

  @override
  void initState() {
    super.initState();
    _signupGeneration = SelahAccountState.generation;
    _verificationState = widget.initialVerificationState;
    final firstName = widget.welcomeName?.trim();
    if (firstName != null && firstName.isNotEmpty) {
      _nameController.text = firstName.split(RegExp(r'\s+')).first;
    }
    if (!_devPreview) {
      try {
        _signupUserId =
            widget.signupUserId ??
            SelahInitialSignupDraftService.captureUserId();
        SelahInitialSignupDraftService.repository.requireOwner(_signupUserId!);
        final draft = widget.initialDraft;
        if (draft != null) {
          if (draft.role != SelahSignupRole.seeker || !draft.isValid()) {
            throw StateError('Invalid setup recovery.');
          }
          _step = draft.step;
          _showStageIntroduction = draft.showIntroduction;
          _nameController.text = draft.firstName ?? _nameController.text;
          _lastNameController.text = draft.lastName ?? '';
          _gender = draft.gender;
          _dob = draft.dob;
          _membershipChoice = draft.membershipChoice;
          _membershipCommitted = draft.membershipChoice != null;
          _firstPhotoPath = draft.firstPhotoPath;
        }
        if (widget.recoverExistingPhoto) {
          _restoreExistingFirstPhoto();
        } else if (_firstPhotoPath != null) {
          _restoreFirstPhoto();
        }
      } catch (_) {
        _saveError =
            'Your saved setup could not be opened. Return to sign in and try again.';
      }
    }
  }

  SelahBackgroundVariant get _background {
    if (_gender == 'male') return SelahBackgroundVariant.male;
    if (_gender == 'female') return SelahBackgroundVariant.female;
    return SelahBackgroundVariant.neutral;
  }

  bool get _fabActive {
    if (_saving || _photoBusy || _photoRestoreFailed) return false;
    switch (_step) {
      case 0:
        return _nameController.text.trim().isNotEmpty &&
            _lastNameController.text.trim().isNotEmpty &&
            _nameController.text.trim().length <= 60 &&
            _lastNameController.text.trim().length <= 60;
      case 1:
        return _gender != null;
      case 2:
        return _dob != null && _dobError == null;
      case 3:
        return _firstPhotoUrl != null &&
            (_devPreview || _firstPhotoPath != null);
      default:
        return false;
    }
  }

  /// Swipe-right-to-go-back (Onboarding Rules & UX §SCREEN ANATOMY —
  /// "No back button... swipe right"). At step 0 there's nowhere earlier
  /// to go within this route (Role Selection was pushReplacement'd away),
  /// so it's a no-op there — same boundary limitation as every chapter
  /// transition in this build.
  void _back() {
    if (_canProceed && _step > 0 && !_saving && !_photoBusy) {
      setState(() {
        _step--;
        _membershipCommitted = false;
      });
    }
  }

  void _devSkipCurrentQuestion() {
    if (!_devPreview || !_canProceed || _saving || _photoBusy) return;
    final now = DateTime.now();
    setState(() {
      if (_step == 0) {
        if (_nameController.text.trim().isEmpty) {
          _nameController.text = widget.welcomeName?.trim().isNotEmpty == true
              ? widget.welcomeName!.trim().split(RegExp(r'\s+')).first
              : 'Dev Seeker';
        }
        if (_lastNameController.text.trim().isEmpty) {
          _lastNameController.text = 'Preview';
        }
      } else if (_step == 1) {
        _gender ??= 'male';
      } else if (_step == 2) {
        _dob ??= DateTime(now.year - 30, 1, 1);
        _dobError = null;
      } else if (_step == 3) {
        // Labelled protected walkthrough fixture; never saved or uploaded.
        _firstPhotoUrl ??=
            'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=';
      }
    });
    _next();
  }

  Future<void> _next() async {
    if (!_canProceed || _saving || !_fabActive) return;
    final draft = _draft(step: _step + 1);
    if (!await _persist(draft)) return;
    if (!_canProceed) return;
    if (_step < _totalQuestions - 1) {
      setState(() => _step++);
      return;
    }
    setState(() {
      _step = _totalQuestions;
      _membershipCommitted = false;
    });
  }

  Future<void> _continueAfterMembership() async {
    if (!_canProceed ||
        _saving ||
        _photoBusy ||
        _photoRestoreFailed ||
        _firstPhotoUrl == null ||
        (!_devPreview && _firstPhotoPath == null) ||
        _membershipChoice?.isValidFor(SelahSignupRole.seeker) != true) {
      return;
    }
    final draft = _draft(step: _totalQuestions);
    if (!await _persist(draft) || !_canProceed) return;

    if (!_devPreview) {
      setState(() => _saving = true);
      try {
        SelahInitialSignupDraftService.repository.requireOwner(_signupUserId!);
        _verificationState = await SelahIdentityVerificationService.fetchMyState(
          expectedUserId: _signupUserId!,
        );
        if (!_canProceed) return;
        SelahInitialSignupDraftService.repository.requireOwner(_signupUserId!);
      } catch (_) {
        if (mounted) {
          setState(() {
            _saving = false;
            _saveError =
                "Your details are saved. We couldn't load your identity check. Please try again.";
          });
        }
        return;
      }
      if (!mounted) return;
      setState(() => _saving = false);
    }

    AppState.instance.saveChapter1(
      name: _nameController.text.trim(),
      surnameLine: _lastNameController.text.trim(),
      gender: _gender!,
      dob: _dob!,
    );

    if (!mounted || !_canProceed) return;
    setState(() => _membershipCommitted = true);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        allowSnapshotting: !_devPreview,
        builder: (_) => _verificationScreen(draft),
      ),
    );
  }

  SelahInitialSignupDraft _draft({
    required int step,
    bool introduction = false,
  }) => SelahInitialSignupDraft(
    role: SelahSignupRole.seeker,
    step: step,
    showIntroduction: introduction,
    firstName: _nameController.text.trim().isEmpty
        ? null
        : _nameController.text.trim(),
    lastName: _lastNameController.text.trim().isEmpty
        ? null
        : _lastNameController.text.trim(),
    gender: _gender,
    dob: _dob,
    membershipChoice: _membershipChoice,
    firstPhotoPath: _firstPhotoPath,
  );

  Future<void> _restoreFirstPhoto() async {
    if (!_canProceed || _firstPhotoPath == null || _signupUserId == null) {
      return;
    }
    _photoBusy = true;
    final path = _firstPhotoPath!;
    String? url;
    try {
      url = await SelahPhotoService.signupPhotoUrl(
        path,
        expectedUserId: _signupUserId!,
        expectedGeneration: _signupGeneration,
      ).timeout(const Duration(seconds: 10));
    } catch (_) {
      // A failed capability refresh is not permission to continue.
    }
    if (!_canProceed || path != _firstPhotoPath) return;
    setState(() {
      _photoBusy = false;
      _firstPhotoUrl = url;
      if (url == null) {
        if (_step > 3) {
          _step = 3;
        }
        _membershipCommitted = false;
        _saveError =
            'Your saved photo could not be loaded. Choose a photo to continue.';
      }
    });
  }

  Future<void> _restoreExistingFirstPhoto() async {
    if (!_canProceed || _signupUserId == null) return;
    _photoBusy = true;
    try {
      final photos = await SelahPhotoService.fetchOwnPhotos(
        expectedUserId: _signupUserId!,
        throwOnError: true,
      ).timeout(const Duration(seconds: 10));
      if (!_canProceed) return;
      _savedPhotoCount = photos.length;
      if (photos.isNotEmpty &&
          (_firstPhotoPath == null || photos.length >= 6)) {
        final path = SelahPhotoService.signupStoragePathFor(
          photos.first,
          expectedUserId: _signupUserId!,
        );
        if (path == null) throw StateError('Invalid saved photo.');
        _firstPhotoPath = path;
        _firstPhotoUrl = photos.first;
      } else if (_firstPhotoPath != null) {
        _firstPhotoUrl = await SelahPhotoService.signupPhotoUrl(
          _firstPhotoPath!,
          expectedUserId: _signupUserId!,
          expectedGeneration: _signupGeneration,
        ).timeout(const Duration(seconds: 10));
        if (!_canProceed) return;
        if (_firstPhotoUrl == null) {
          if (_step > 3) {
            _step = 3;
          }
          _membershipCommitted = false;
          _saveError =
              'Your saved photo could not be loaded. Choose a photo to continue.';
        }
      }
    } catch (_) {
      if (_canProceed) {
        _photoRestoreFailed = true;
        if (_step > 3) {
          _step = 3;
        }
        _membershipCommitted = false;
        _saveError =
            'Your saved photos could not be loaded. Try again before changing your photo.';
      }
    } finally {
      if (_canProceed) setState(() => _photoBusy = false);
    }
  }

  Widget _photoRecoveryError() => SelahErrorBanner(
    message: 'Load your saved photo before continuing.',
    onRetry: () {
      if (!_canProceed || _saving || _photoBusy) return;
      setState(() {
        _photoRestoreFailed = false;
        _saveError = null;
        _photoBusy = true;
      });
      _restoreExistingFirstPhoto();
    },
  );

  Future<void> _chooseFirstPhoto() async {
    if (!_canProceed ||
        _saving ||
        _photoBusy ||
        _photoRestoreFailed ||
        _savedPhotoCount >= 6) {
      return;
    }
    setState(() {
      _photoBusy = true;
      _photoProgress = null;
      _saveError = null;
    });
    void progress(String? value) {
      if (_canProceed) setState(() => _photoProgress = value);
    }

    try {
      final result = widget.photoRunner != null
          ? await widget.photoRunner!(context, 1, progress)
          : await runSelahPhotoBatchFlow(
              context,
              remaining: 1,
              localPreview: _devPreview,
              onProgress: progress,
              canProceed: () => _canProceed,
            );
      if (!_canProceed) return;
      if (result.outcome == SelahPhotoBatchOutcome.added &&
          result.urls.length == 1) {
        final url = result.urls.single;
        final path = _devPreview
            ? null
            : SelahPhotoService.signupStoragePathFor(
                url,
                expectedUserId: _signupUserId!,
              );
        if (!_devPreview && path == null) {
          throw StateError('Invalid signup photo owner.');
        }
        final oldPath = _firstPhotoPath;
        final oldUrl = _firstPhotoUrl;
        _firstPhotoPath = path;
        _firstPhotoUrl = url;
        if (!await _persist(_draft(step: 3))) {
          if (_canProceed) {
            _firstPhotoPath = oldPath;
            _firstPhotoUrl = oldUrl;
          }
        }
      } else if (result.outcome == SelahPhotoBatchOutcome.error) {
        setState(() => _saveError = result.memberErrorMessage);
      }
    } catch (_) {
      if (_canProceed) {
        setState(
          () => _saveError = "We couldn't save your photo. Please try again.",
        );
      }
    } finally {
      if (_canProceed) {
        setState(() {
          _photoBusy = false;
          _photoProgress = null;
        });
      }
    }
  }

  void _projectFirstPhoto() {
    if (_devPreview && _firstPhotoUrl != null) {
      AppState.instance.setProfilePhotos([_firstPhotoUrl!]);
    }
  }

  Future<bool> _persist(SelahInitialSignupDraft draft) async {
    if (!_canProceed) return false;
    if (_devPreview) return _canProceed;
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      if (_signupUserId == null) throw StateError('Missing signup account.');
      await SelahInitialSignupDraftService.repository.save(
        _signupUserId!,
        draft,
      );
      if (!_canProceed) return false;
      if (draft.membershipChoice != null) {
        await SelahInitialSignupDraftService.repository.saveMembershipIntent(
          _signupUserId!,
          SelahSignupMembershipIntent(
            role: draft.role,
            choice: draft.membershipChoice!,
          ),
        );
      }
      if (!mounted || !_signupAuthorized) return false;
      setState(() => _saving = false);
      return true;
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _saveError =
              "We couldn't save your progress securely. Please try again on this device.";
        });
      }
      return false;
    }
  }

  Widget _verificationScreen(
    SelahInitialSignupDraft draft,
  ) => InitialIdentityCheckScreen(
    devPreview: _devPreview,
    initialState: _verificationState,
    // DR-SELAH-221: create the ordinary profile row only AFTER the
    // server result is verified. Before this change, closing the app on
    // the verification placeholder left a routable profile row, so a
    // relaunch could step around the onboarding gate.
    finalizeOnboarding: () async {
      if (_devPreview) return null;
      if (!_signupAuthorized) return 'Sign in again to continue setup.';
      return SelahInitialSignupDraftService.finalize(_signupUserId!, draft);
    },
    onContinue: (verificationContext) async {
      if (!verificationContext.mounted || !_signupAuthorized) {
        return;
      }
      if (!_devPreview) {
        SelahInitialSignupDraftService.repository.requireOwner(_signupUserId!);
      }
      AppState.instance.saveChapter1(
        name: draft.firstName!,
        surnameLine: draft.lastName!,
        gender: draft.gender!,
        dob: draft.dob!,
      );
      _projectFirstPhoto();
      if (_devPreview) {
        final applied = SelahDevLocalPreview.applySignupMembershipPreview(
          role: draft.role,
          choice: draft.membershipChoice!,
        );
        if (!applied) return;
      }
      Navigator.of(verificationContext).pushAndRemoveUntil(
        MaterialPageRoute(
          allowSnapshotting: !_devPreview,
          builder: (_) => SeekerPostIdentityChoiceScreen(
            devPreview: _devPreview,
            expectedUserId: _signupUserId,
          ),
        ),
        (_) => false,
      );
    },
    onDevSkip: _devPreview
        ? (verificationContext) async {
            if (!verificationContext.mounted ||
                !SelahDeveloperAccess.canUseDeveloperTools) {
              return;
            }
            // A protected walkthrough shortcut only: no verification
            // state, profile finalisation or live account grant.
            AppState.instance.saveChapter1(
              name: draft.firstName!,
              surnameLine: draft.lastName!,
              gender: draft.gender!,
              dob: draft.dob!,
            );
            _projectFirstPhoto();
            final applied = SelahDevLocalPreview.applySignupMembershipPreview(
              role: draft.role,
              choice: draft.membershipChoice!,
            );
            if (!applied) return;
            Navigator.of(verificationContext).pushAndRemoveUntil(
              MaterialPageRoute(
                allowSnapshotting: false,
                builder: (_) =>
                    const SeekerPostIdentityChoiceScreen(devPreview: true),
              ),
              (_) => false,
            );
          }
        : null,
  );

  void _checkDob(DateTime picked) {
    // The root dialog can outlive this form, a sign-out or a replaced
    // same-ID session. A late result is not the current owner's answer.
    if (!_canProceed || _saving) return;
    final now = DateTime.now();
    var age = now.year - picked.year;
    final hadBirthdayThisYear =
        now.month > picked.month ||
        (now.month == picked.month && now.day >= picked.day);
    if (!hadBirthdayThisYear) age -= 1;
    setState(() {
      _dob = picked;
      _dobError = age < 18 ? "You'll need to be 18 or over to continue." : null;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: SelahDeveloperAccess.authorizationChanges,
    builder: (context, _) {
      if (_devPreview && !SelahDeveloperAccess.canUseDeveloperTools) {
        return Scaffold(
          key: const ValueKey('seeker_signup_preview_denied'),
          backgroundColor: SelahColors.modalSheetSurface,
          body: const SizedBox.expand(),
        );
      }
      return _buildFlow(context);
    },
  );

  Widget _buildFlow(BuildContext context) {
    if (_step == _totalQuestions) {
      if (_photoBusy) {
        return OnboardingScaffold(
          background: _background,
          chapterName: 'Account essentials',
          chapterProgress: 1,
          progressLabel: 'QUESTION 4 OF $_totalQuestions',
          question: 'Restoring your first photo…',
          content: const SizedBox.shrink(),
          fabActive: false,
          onContinue: null,
          showAccountExit: true,
          accountExitExpectedUserId: _signupUserId,
        );
      }
      if (_membershipCommitted) return _verificationScreen(_draft(step: _step));
      return SignupMembershipChoiceScreen(
        role: SelahSignupRole.seeker,
        choice: _membershipChoice,
        onChanged: (choice) {
          if (_canProceed && !_saving) {
            setState(() => _membershipChoice = choice);
          }
        },
        onContinue: _continueAfterMembership,
        onBack: _back,
        background: _background,
        saving: _saving,
        error: _saveError,
        devPreview: _devPreview,
        onDevSkip: _devPreview
            ? () {
                if (!_canProceed || _saving) return;
                setState(
                  () => _membershipChoice ??= const SelahSignupMembershipChoice(
                    kind: SelahSignupMembershipKind.basic,
                  ),
                );
                _continueAfterMembership();
              }
            : null,
        expectedUserId: _signupUserId,
      );
    }
    if (_showStageIntroduction) {
      return Stack(
        children: [
          AccountEssentialsIntroScreen(
            devPreview: _devPreview,
            onDevSkip: _devPreview
                ? () {
                    if (_canProceed && !_saving) {
                      setState(() => _showStageIntroduction = false);
                    }
                  }
                : null,
            // The protected continuous rehearsal must remain reachable on a
            // compact/large-text phone. Live signup keeps the original default.
            accountExit: _devPreview || _signupUserId == null
                ? null
                : SelahOnboardingAccountExit(expectedUserId: _signupUserId!),
            onContinue: () async {
              if (!_canProceed || _saving) return;
              if (await _persist(_draft(step: 0))) {
                if (_canProceed) {
                  setState(() => _showStageIntroduction = false);
                }
              }
            },
          ),
          // Photo recovery can finish while this orientation is still open.
          // Its reachable retry belongs to the retained question below, not
          // an overlay that covers this page's Continue control.
          if (_saveError != null && !_photoRestoreFailed)
            Positioned(
              left: 24,
              right: 24,
              bottom: 110,
              child: SelahFieldError(_saveError),
            ),
        ],
      );
    }

    switch (_step) {
      case 0:
        return OnboardingScaffold(
          background: _background,
          chapterName: 'Account essentials',
          chapterProgress: 1 / _totalQuestions,
          progressLabel: 'QUESTION 1 OF $_totalQuestions',
          question: 'What\'s your name?',
          subtext:
              _saveError ?? 'Both names will appear on your public profile.',
          privacy: PrivacyLevel.public,
          fabActive: _fabActive,
          onContinue: _next,
          devPreview: _devPreview,
          onDevSkip: _devSkipCurrentQuestion,
          onSwipeBack: _step > 0 ? _back : null,
          showAccountExit: true,
          accountExitExpectedUserId: _signupUserId,
          frameContent: false,
          content: AutofillGroup(
            child: Column(
              children: [
                SelahOnboardingNameField(
                  controller: _nameController,
                  onChanged: (_) => setState(() {}),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 14),
                SelahOnboardingNameField(
                  controller: _lastNameController,
                  lastName: true,
                  onChanged: (_) => setState(() {}),
                ),
                if (_photoRestoreFailed) _photoRecoveryError(),
              ],
            ),
          ),
        );
      case 1:
        return OnboardingScaffold(
          background: _background,
          chapterName: 'Account essentials',
          chapterProgress: 2 / _totalQuestions,
          progressLabel: 'QUESTION 2 OF $_totalQuestions',
          question: 'What\'s your gender?',
          frameContent: false,
          subtext: _saveError,
          privacy: PrivacyLevel.public,
          fabActive: _fabActive,
          onContinue: _next,
          devPreview: _devPreview,
          onDevSkip: _devSkipCurrentQuestion,
          onSwipeBack: _back,
          showAccountExit: true,
          accountExitExpectedUserId: _signupUserId,
          content: SelahOnboardingChoiceEntrance(
            key: const ValueKey('seeker_gender_choice_entrance'),
            child: Column(
              children: [
                SelahOnboardingChoiceCard(
                  key: const ValueKey('seeker_gender_male'),
                  label: 'Male',
                  icon: Icons.male_rounded,
                  selected: _gender == 'male',
                  onTap: () => setState(() => _gender = 'male'),
                ),
                const SizedBox(height: 14),
                SelahOnboardingChoiceCard(
                  key: const ValueKey('seeker_gender_female'),
                  label: 'Female',
                  icon: Icons.female_rounded,
                  selected: _gender == 'female',
                  onTap: () => setState(() => _gender = 'female'),
                ),
                if (_photoRestoreFailed) _photoRecoveryError(),
              ],
            ),
          ),
        );
      case 2:
        return OnboardingScaffold(
          background: _background,
          chapterName: 'Account essentials',
          chapterProgress: 3 / _totalQuestions,
          progressLabel: 'QUESTION 3 OF $_totalQuestions',
          question: 'When were you born?',
          subtext: _saveError ?? 'You must be 18 or older to use SELAH.',
          privacy: PrivacyLevel.private,
          fabActive: _fabActive,
          onContinue: _next,
          devPreview: _devPreview,
          onDevSkip: _devSkipCurrentQuestion,
          onSwipeBack: _back,
          showAccountExit: true,
          accountExitExpectedUserId: _signupUserId,
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DobPicker(value: _dob, onPicked: _checkDob),
              SelahFieldError(_dobError),
              if (_photoRestoreFailed) _photoRecoveryError(),
            ],
          ),
        );
      case 3:
      default:
        return OnboardingScaffold(
          key: const ValueKey('signup_first_photo_question'),
          background: _background,
          chapterName: 'Account essentials',
          chapterProgress: 1,
          progressLabel: 'QUESTION 4 OF $_totalQuestions',
          question: 'Add your first photo',
          subtext:
              _saveError ??
              'One photo to begin. You can add more during profile setup.',
          privacy: PrivacyLevel.public,
          frameContent: false,
          fabActive: _fabActive,
          onContinue: _next,
          devPreview: _devPreview,
          onDevSkip: _devSkipCurrentQuestion,
          onSwipeBack: _back,
          showAccountExit: true,
          accountExitExpectedUserId: _signupUserId,
          content: _photoRestoreFailed
              ? _photoRecoveryError()
              : SelahSignupFirstPhotoCard(
                  photo: _firstPhotoUrl,
                  busy: _photoBusy || _saving,
                  progress: _photoProgress,
                  onChoose: _chooseFirstPhoto,
                  canChoose: _savedPhotoCount < 6,
                ),
        );
    }
  }
}

class _DobPicker extends StatelessWidget {
  final DateTime? value;
  final ValueChanged<DateTime> onPicked;

  const _DobPicker({required this.value, required this.onPicked});

  @override
  Widget build(BuildContext context) {
    final previewStyle = OnboardingPreviewStyle.effectiveStyleOf(context);
    final label = value == null
        ? 'Select date of birth'
        : '${value!.day.toString().padLeft(2, '0')}/${value!.month.toString().padLeft(2, '0')}/${value!.year}';
    return InkWell(
      borderRadius: previewStyle?.cardRadius ?? BorderRadius.circular(14),
      onTap: () async {
        final now = DateTime.now();
        final firstDate = DateTime(now.year - 100);
        final restored = value ?? DateTime(now.year - 25, now.month, now.day);
        // Recovery accepts older calendar dates; keep the existing picker
        // range without asserting or replacing that answer on dialog open.
        final initialDate = restored.isBefore(firstDate)
            ? firstDate
            : restored.isAfter(now)
            ? now
            : restored;
        final picked = await showDatePicker(
          context: context,
          initialDate: initialDate,
          firstDate: firstDate,
          lastDate: now,
        );
        if (context.mounted && picked != null) onPicked(picked);
      },
      child: Container(
        width: double.infinity,
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration:
            previewStyle?.cardDecoration() ??
            BoxDecoration(
              color: SelahColors.iconButtonBg,
              border: Border.all(
                color: SelahColors.iconButtonBorder,
                width: 0.5,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            Icon(
              Icons.calendar_today_outlined,
              color: SelahColors.ink(0.54),
              size: 18,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: SelahText.body(
                  size: 15,
                  color: value == null ? SelahColors.ink(0.38) : Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
