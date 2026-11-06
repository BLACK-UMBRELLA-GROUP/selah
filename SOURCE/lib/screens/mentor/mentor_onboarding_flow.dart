// Mentor Onboarding — v1 draft. MENTOR_ARCHITECTURE_CURRENT_VERSION_V5.md is
// a fully approved, detailed architecture (account model, capability
// grants, three entry paths, screen flow diagram, navigation), but the
// actual onboarding QUESTION CONTENT is never specified anywhere in it —
// the flow diagram only references a black-box "[ Shepherd Onboarding ]"
// node between account creation and the Dashboard. This file fills that
// gap with a reasonable v1, recorded as a proposed decision (inherited decision 081)
// rather than silently treated as final, same discipline as the
// compatibility scoring (inherited decision 079) and error-state standard
// (inherited decision 080) drafts earlier in this build.
//
// Scoped to PATH 3 ("Shepherd Starts First") only — per MENTOR SCREEN FLOW,
// that's the only entry path reachable from this app's current Role
// Selection screen (Paths 1/2 require a Seeker-sent invite link/landing
// page, which doesn't exist as a flow yet). Relationship options and the
// "support and guidance, not surveillance" framing are taken directly
// from the spec's WHO IS A MENTOR and DESIGN PRINCIPLE sections.
//
// Date of birth added 2026-07-18 alongside real Supabase wiring (OA-102
// follow-on): SELAH_DATABASE_SCHEMA_CURRENT_VERSION_V1.md's `profiles`
// table has date_of_birth as NOT NULL for every role, Shepherd included,
// but the original v1 draft (inherited decision 081) only asked name + relationship
// since nothing else in the Shepherd UI uses a DOB. Adding the question here
// rather than relaxing the approved schema — small, faithful fix now
// that a real constraint exists to satisfy.

import 'package:flutter/material.dart';
import '../../widgets/selah_onboarding_choice_card.dart';
import '../../services/selah_developer_access.dart';
import '../../services/selah_account_state.dart';
import '../../services/selah_internal_preview_client.dart';
import '../../services/selah_initial_signup_draft_service.dart';
import '../../models/selah_initial_signup_draft.dart';
import '../../models/selah_signup_membership_choice.dart';
import '../../models/selah_identity_verification.dart';
import '../../services/selah_identity_verification_service.dart';
import '../../services/selah_photo_service.dart';
import '../../state/app_state.dart';
import '../../theme/selah_colors.dart';
import '../../theme/selah_text.dart';
import '../../widgets/selah_state_widgets.dart';
import '../../widgets/onboarding_scaffold.dart';
import '../../widgets/selah_onboarding_name_field.dart';
import '../../widgets/privacy_indicator.dart';
import '../../widgets/selah_onboarding_direction_style.dart';
import '../../widgets/selah_signup_first_photo_card.dart';
import '../profile/selah_photo_batch_flow.dart';
import '../onboarding/identity_verification_screen.dart';
import '../onboarding/signup_membership_choice_screen.dart';
import '../onboarding/transition_screen.dart';
import 'mentor_invite_seeker_screen.dart';

class MentorOnboardingFlow extends StatefulWidget {
  final bool devPreview;
  final SelahInitialSignupDraft? initialDraft;
  final String? signupUserId;
  final SelahIdentityVerificationState? initialVerificationState;
  final SelahPhotoBatchRunner? photoRunner;
  final bool recoverExistingPhoto;

  const MentorOnboardingFlow({
    super.key,
    this.devPreview = false,
    this.initialDraft,
    this.signupUserId,
    this.initialVerificationState,
    this.photoRunner,
    this.recoverExistingPhoto = false,
  });

  @override
  State<MentorOnboardingFlow> createState() => _MentorOnboardingFlowState();
}

class _MentorOnboardingFlowState extends State<MentorOnboardingFlow> {
  int _step = 0; // name, date of birth, gender, relationship, one photo
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  DateTime? _dob;
  String? _dobError;
  String? _gender;
  String? _relationship;
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

  @override
  void initState() {
    super.initState();
    _signupGeneration = SelahAccountState.generation;
    _verificationState = widget.initialVerificationState;
    if (!_devPreview) {
      try {
        _signupUserId =
            widget.signupUserId ??
            SelahInitialSignupDraftService.captureUserId();
        SelahInitialSignupDraftService.repository.requireOwner(_signupUserId!);
        final draft = widget.initialDraft;
        if (draft != null) {
          if (draft.role != SelahSignupRole.shepherd || !draft.isValid()) {
            throw StateError('Invalid setup recovery.');
          }
          _step = draft.step;
          _nameController.text = draft.firstName ?? '';
          _lastNameController.text = draft.lastName ?? '';
          _gender = draft.gender;
          _dob = draft.dob;
          _relationship = draft.relationship;
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

  static const int _totalQuestions = 5;

  // Revocation denies a requested preview; it must not become live signup.
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

  static const _maleRelationships = [
    'Father',
    'Grandfather',
    'Brother',
    'Paternal Uncle',
    'Other',
  ];

  static const _femaleRelationships = [
    'Mother',
    'Grandmother',
    'Sister',
    'Paternal Aunt',
    'Other',
  ];

  List<String> get _relationships =>
      _gender == 'female' ? _femaleRelationships : _maleRelationships;

  bool get _fabActive {
    if (_saving) return false;
    switch (_step) {
      case 0:
        return _nameController.text.trim().isNotEmpty &&
            _lastNameController.text.trim().isNotEmpty &&
            _nameController.text.trim().length <= 60 &&
            _lastNameController.text.trim().length <= 60;
      case 1:
        return _dob != null && _dobError == null;
      case 2:
        return _gender != null;
      case 3:
        return _relationship != null;
      case 4:
        return !_photoBusy &&
            !_photoRestoreFailed &&
            _firstPhotoUrl != null &&
            (_devPreview || _firstPhotoPath != null);
      default:
        return false;
    }
  }

  void _checkDob(DateTime picked) {
    // A date dialog can finish after the form or its captured principal
    // was replaced. Keep the existing owner/epoch/preview boundary.
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
          _nameController.text = 'Dev Shepherd';
        }
        if (_lastNameController.text.trim().isEmpty) {
          _lastNameController.text = 'Preview';
        }
      } else if (_step == 1) {
        _dob ??= DateTime(now.year - 45, 1, 1);
        _dobError = null;
      } else if (_step == 2) {
        _gender ??= 'male';
      } else if (_step == 3) {
        _relationship ??= _relationships.first;
      } else if (_step == 4) {
        // Local fixture only: preview cannot upload or create a photo record.
        _firstPhotoUrl ??=
            'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=';
      }
    });
    _next();
  }

  Future<void> _next() async {
    if (!_canProceed || _saving || _photoBusy || !_fabActive) return;
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
        _membershipChoice?.isValidFor(SelahSignupRole.shepherd) != true) {
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
    AppState.instance.saveMentorOnboarding(
      name: _nameController.text.trim(),
      surnameLine: _lastNameController.text.trim(),
      relationship: _relationship!,
      gender: _gender!,
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

  SelahInitialSignupDraft _draft({required int step}) => SelahInitialSignupDraft(
    role: SelahSignupRole.shepherd,
    step: step,
    firstName: _nameController.text.trim().isEmpty
        ? null
        : _nameController.text.trim(),
    lastName: _lastNameController.text.trim().isEmpty
        ? null
        : _lastNameController.text.trim(),
    gender: _gender,
    dob: _dob,
    relationship: _relationship,
    // A local-only fixture keeps downstream rehearsal validation faithful;
    // preview persistence/finalization are denied and this is not an object.
    firstPhotoPath: _devPreview && _firstPhotoUrl != null
        ? 'shepherd-signup-preview/first.jpg'
        : _firstPhotoPath,
    membershipChoice: _membershipChoice,
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
        if (_step > 4) _step = 4;
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
      }
      if (_firstPhotoUrl == null) {
        if (_step > 4) _step = 4;
        _membershipCommitted = false;
        if (_firstPhotoPath != null) {
          _saveError =
              'Your saved photo could not be loaded. Choose a photo to continue.';
        }
      }
    } catch (_) {
      if (_canProceed) {
        _photoRestoreFailed = true;
        if (_step > 4) _step = 4;
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
        _step != 4 ||
        _saving ||
        _photoBusy ||
        _photoRestoreFailed ||
        _savedPhotoCount >= 6 ||
        ModalRoute.of(context)?.isCurrent != true) {
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
              // The chooser/crop sheets temporarily cover this form; the
              // batch retains its captured owner/epoch through those routes.
              canProceed: () => _canProceed,
            );
      if (!mounted ||
          !_canProceed ||
          _step != 4 ||
          ModalRoute.of(context)?.isCurrent != true) {
        return;
      }
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
        if (!await _persist(_draft(step: 4))) {
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

  Widget _verificationScreen(SelahInitialSignupDraft draft) {
    Future<void> continueAfterIdentity(BuildContext verificationContext) async {
      if (!verificationContext.mounted ||
          !_signupAuthorized ||
          (_devPreview &&
              (!SelahDeveloperAccess.canUseDeveloperTools ||
                  !SelahInternalPreviewClient.isActive))) {
        return;
      }
      if (!_devPreview) {
        SelahInitialSignupDraftService.repository.requireOwner(_signupUserId!);
      }
      AppState.instance.saveMentorOnboarding(
        name: draft.firstName!,
        surnameLine: draft.lastName!,
        gender: draft.gender!,
        relationship: draft.relationship!,
      );
      // This latch belongs to the replacement support route, not to this
      // form's mounted state: the form is disposed before support continues.
      var openingCode = false;
      Navigator.of(verificationContext).pushReplacement(
        MaterialPageRoute(
          allowSnapshotting: !_devPreview,
          builder: (transitionContext) {
            void openCode() {
              if (openingCode ||
                  !transitionContext.mounted ||
                  ModalRoute.of(transitionContext)?.isCurrent != true ||
                  !_signupAuthorized) {
                return;
              }
              if (_devPreview &&
                  (!SelahDeveloperAccess.canUseDeveloperTools ||
                      !SelahInternalPreviewClient.isActive)) {
                return;
              }
              openingCode = true;
              Navigator.of(transitionContext).pushReplacement(
                MaterialPageRoute(
                  allowSnapshotting: !_devPreview,
                  builder: (_) => MentorInviteSeekerScreen(
                    signupPreview: _devPreview,
                    signupPreviewIdentity: _devPreview ? draft : null,
                  ),
                ),
              );
            }

            return TransitionScreen(
              background: draft.gender == 'female'
                  ? SelahBackgroundVariant.female
                  : SelahBackgroundVariant.male,
              title: 'Support and guidance',
              body:
                  'Selah treats you as a full part of this journey — not as an observer. '
                  "You'll see your linked Seeker's progress, and you can read the "
                  'conversation once a Journey becomes active. Both Seekers are told '
                  'this before they begin.\n\n'
                  'That openness is the point: Selah is built for a marriage process '
                  'with trusted support. It is a trust placed in you — guidance, not '
                  'surveillance.',
              buttonLabel: 'Continue',
              onContinue: openCode,
              devPreview: _devPreview,
              onDevSkip: _devPreview ? openCode : null,
            );
          },
        ),
      );
    }

    return InitialIdentityCheckScreen(
      devPreview: _devPreview,
      initialState: _verificationState,
      // Shepherds inherit the same mandatory gate. Keeping profile
      // creation after the verified result also prevents a relaunch from
      // treating an interrupted Shepherd verification as onboarding done.
      finalizeOnboarding: () async {
        if (_devPreview) return null;
        if (!_signupAuthorized) return 'Sign in again to continue setup.';
        return SelahInitialSignupDraftService.finalize(_signupUserId!, draft);
      },
      onContinue: continueAfterIdentity,
      onDevSkip: _devPreview ? continueAfterIdentity : null,
    );
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
          key: const ValueKey('shepherd_signup_preview_denied'),
          backgroundColor: SelahColors.modalSheetSurface,
          body: const SizedBox.expand(),
        );
      }
      return _buildFlow(context);
    },
  );

  Widget _buildFlow(BuildContext context) {
    // Signing/restoring an owned reference must finish before a resumed
    // membership or verification screen can become actionable.
    if (_step >= 4 &&
        (_photoBusy || _photoRestoreFailed || _firstPhotoUrl == null)) {
      return _photoQuestion();
    }
    if (_step == _totalQuestions) {
      if (_membershipCommitted) return _verificationScreen(_draft(step: _step));
      return SignupMembershipChoiceScreen(
        role: SelahSignupRole.shepherd,
        choice: _membershipChoice,
        onChanged: (choice) {
          if (_canProceed && !_saving) {
            setState(() => _membershipChoice = choice);
          }
        },
        onContinue: _continueAfterMembership,
        onBack: _back,
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
    switch (_step) {
      case 0:
        return _MentorQuestionScaffold(
          questionNumber: 1,
          question: "What's your name?",
          subtext:
              _saveError ?? 'Both names will appear on your public profile.',
          fabActive: _fabActive,
          onContinue: _next,
          devPreview: _devPreview,
          onDevSkip: _devSkipCurrentQuestion,
          onSwipeBack: null,
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
              ],
            ),
          ),
        );
      case 1:
        return _MentorQuestionScaffold(
          questionNumber: 2,
          question: 'When were you born?',
          subtext: _saveError ?? 'You must be 18 or older to use Selah.',
          fabActive: _fabActive,
          onContinue: _next,
          devPreview: _devPreview,
          onDevSkip: _devSkipCurrentQuestion,
          onSwipeBack: _back,
          accountExitExpectedUserId: _signupUserId,
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _MentorDobPicker(value: _dob, onPicked: _checkDob),
              SelahFieldError(_dobError),
            ],
          ),
        );
      case 2:
        return _MentorQuestionScaffold(
          questionNumber: 3,
          question: 'What’s your gender?',
          frameContent: false,
          subtext:
              _saveError ??
              'This keeps identity details and profile wording correct.',
          fabActive: _fabActive,
          onContinue: _next,
          devPreview: _devPreview,
          onDevSkip: _devSkipCurrentQuestion,
          onSwipeBack: _back,
          accountExitExpectedUserId: _signupUserId,
          content: SelahOnboardingChoiceEntrance(
            key: const ValueKey('shepherd_gender_choice_entrance'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final option in const [
                  ('Male', 'male', Icons.male_rounded),
                  ('Female', 'female', Icons.female_rounded),
                ])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: SelahOnboardingChoiceCard(
                      key: ValueKey('shepherd_gender_${option.$2}'),
                      label: option.$1,
                      icon: option.$3,
                      selected: _gender == option.$2,
                      onTap: () => setState(() {
                        _gender = option.$2;
                        _relationship = null;
                      }),
                    ),
                  ),
              ],
            ),
          ),
        );
      case 3:
        return _MentorQuestionScaffold(
          questionNumber: 4,
          question: 'What is your relationship to the Seeker you support?',
          frameContent: false,
          subtext:
              _saveError ??
              'Choose the relationship that best describes your support.',
          fabActive: _fabActive,
          onContinue: _next,
          devPreview: _devPreview,
          onDevSkip: _devSkipCurrentQuestion,
          onSwipeBack: _back,
          accountExitExpectedUserId: _signupUserId,
          content: SelahOnboardingChoiceEntrance(
            key: const ValueKey('shepherd_relationship_choice_entrance'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ..._relationships.map(
                  (r) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: SelahOnboardingChoiceCard(
                      key: ValueKey('shepherd_relationship_$r'),
                      label: r,
                      selected: _relationship == r,
                      onTap: () => setState(() => _relationship = r),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      default:
        return _photoQuestion();
    }
  }

  Widget _photoQuestion() => OnboardingScaffold(
    key: const ValueKey('shepherd_signup_first_photo_question'),
    background: SelahBackgroundVariant.neutral,
    chapterName: 'Account essentials',
    chapterProgress: 1,
    progressLabel: 'QUESTION 5 OF $_totalQuestions',
    question: 'Add your photo',
    subtext:
        _saveError ?? 'One photo is all you need for your Shepherd account.',
    privacy: null,
    frameContent: false,
    fabActive: _step == 4 && _fabActive,
    onContinue: _next,
    onSwipeBack: _back,
    devPreview: _devPreview,
    onDevSkip: _devSkipCurrentQuestion,
    devSkipLabel: 'Skip',
    showAccountExit: true,
    accountExitExpectedUserId: _signupUserId,
    continueActionKey: const ValueKey('mentor_onboarding_continue'),
    content: _photoRestoreFailed
        ? _photoRecoveryError()
        : SelahSignupFirstPhotoCard(
            photo: _firstPhotoUrl,
            busy: _photoBusy || _saving,
            progress: _photoProgress,
            onChoose: _chooseFirstPhoto,
            canChoose: _savedPhotoCount < 6,
            readyText: 'Your saved photo is ready.',
            footerText: null,
          ),
  );
}

class _MentorDobPicker extends StatelessWidget {
  final DateTime? value;
  final ValueChanged<DateTime> onPicked;
  const _MentorDobPicker({required this.value, required this.onPicked});

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
        final restored = value ?? DateTime(now.year - 45, now.month, now.day);
        // Preserve the existing picker range even for an older recovery
        // answer, without overwriting it merely by opening the dialog.
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

/// Both roles use one question presentation. Shepherd fields retain their
/// own count and visibility; none is labelled as a Browse-visible profile.
class _MentorQuestionScaffold extends StatelessWidget {
  final int questionNumber;
  final String question;
  final String? subtext;
  final Widget content;
  final bool frameContent;
  final bool fabActive;
  final VoidCallback onContinue;
  final VoidCallback? onSwipeBack;
  final bool devPreview;
  final VoidCallback? onDevSkip;
  final String? accountExitExpectedUserId;

  const _MentorQuestionScaffold({
    required this.questionNumber,
    required this.question,
    required this.content,
    this.frameContent = true,
    required this.fabActive,
    required this.onContinue,
    this.subtext,
    this.onSwipeBack,
    this.devPreview = false,
    this.onDevSkip,
    this.accountExitExpectedUserId,
  });

  @override
  Widget build(BuildContext context) {
    const totalQuestions = _MentorOnboardingFlowState._totalQuestions;
    return OnboardingScaffold(
      background: SelahBackgroundVariant.neutral,
      chapterName: 'Account essentials',
      chapterProgress: questionNumber / totalQuestions,
      progressLabel: 'QUESTION $questionNumber OF $totalQuestions',
      question: question,
      subtext: subtext,
      content: content,
      frameContent: frameContent,
      privacy: questionNumber == 1
          ? PrivacyLevel.public
          : questionNumber == 2
          ? PrivacyLevel.private
          : null,
      privacyOverrideText: questionNumber == 2
          ? 'Your date of birth stays private.'
          : null,
      fabActive: fabActive,
      onContinue: onContinue,
      onSwipeBack: onSwipeBack,
      devPreview: devPreview,
      onDevSkip: onDevSkip,
      devSkipLabel: 'Skip',
      showAccountExit: true,
      accountExitExpectedUserId: accountExitExpectedUserId,
      continueActionKey: const ValueKey('mentor_onboarding_continue'),
    );
  }
}
