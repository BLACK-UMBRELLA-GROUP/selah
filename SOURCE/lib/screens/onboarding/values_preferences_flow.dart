// Retained onboarding adapter for LOCK17/18. The existing answer service and
// account generation remain the sole persistence boundary.
import 'package:flutter/material.dart';

import '../../models/selah_sign_up_compatibility.dart';
import '../../models/selah_your_values.dart';
import '../../models/selah_your_values_controller.dart';
import '../../services/selah_account_state.dart';
import '../../services/selah_auth.dart';
import '../../services/selah_developer_access.dart';
import '../../services/selah_internal_preview_client.dart';
import '../../services/selah_onboarding_answers_service.dart';
import '../../state/app_state.dart';
import '../../theme/selah_colors.dart';
import '../../widgets/selah_loading.dart';
import '../../widgets/selah_state_widgets.dart';
import '../profile/compatibility_editors.dart';
import 'onboarding_stage_intro_screen.dart';
import 'profile_ready_screen.dart';
import 'selah_your_values_flow.dart';

class ValuesPreferencesFlow extends StatefulWidget {
  const ValuesPreferencesFlow({
    super.key,
    required this.gender,
    this.devPreview = false,
    this.readSignUpPreferences,
  });
  final String gender;
  final bool devPreview;
  final SelahSignUpPreferencesReader? readSignUpPreferences;
  @override
  State<ValuesPreferencesFlow> createState() => _ValuesPreferencesFlowState();
}

class _ValuesPreferencesFlowState extends State<ValuesPreferencesFlow> {
  late final int _generation;
  String? _owner;
  bool _closed = false;
  bool _loading = true;
  bool _leaving = false;
  int _loadEpoch = 0;
  String? _loadError;
  SelahCompatibilityDraft? _draft;
  SelahYourValuesController? _controller;
  // The retained snapshot has no completion field for an empty hard-rule map.
  // Keep actual Save(None) completion only in this route's current lifetime;
  // a restored route must save again rather than infer completion from rules.
  bool _dealbreakersSaved = false;

  bool get _current {
    if (!mounted || _closed) return false;
    final allowed = widget.devPreview
        ? SelahDeveloperAccess.canUseDeveloperTools
        : SelahOnboardingAnswersService.clientReady &&
              !SelahInternalPreviewClient.isActive &&
              !SelahAccountState.isSigningOut &&
              _owner != null &&
              SelahAuth.currentUser?.id == _owner &&
              SelahAccountState.generation == _generation;
    if (!allowed) _closed = true;
    return allowed;
  }

  bool get _foreground =>
      _current && !_leaving && (ModalRoute.of(context)?.isCurrent ?? true);

  @override
  void initState() {
    super.initState();
    _generation = SelahAccountState.generation;
    if (!widget.devPreview) {
      _owner = SelahOnboardingAnswersService.clientReady
          ? SelahAuth.currentUser?.id
          : null;
    }
    _restore();
  }

  Map<String, dynamic> _signUp() =>
      widget.readSignUpPreferences?.call() ?? const {};

  Future<void> _restore() async {
    if (!_current) {
      _loading = false;
      _loadError = 'Your account changed. Sign in again to continue setup.';
      return;
    }
    final epoch = ++_loadEpoch;
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final snapshot = widget.devPreview
          ? null
          : await SelahOnboardingAnswersService.fetchOwn(
              expectedUserId: _owner,
              throwOnError: true,
            ).timeout(const Duration(seconds: 10));
      if (!_current || epoch != _loadEpoch) return;
      if (snapshot != null && !widget.devPreview) {
        AppState.instance.saveJourneyBio(snapshot.journeyBio);
      }
      final draft = SelahCompatibilityDraft.fromSnapshot(
        gender: widget.gender,
        snapshot: snapshot,
        readSignUpPreferences: _signUp,
      );
      _controller?.dispose();
      _draft = draft;
      _controller = SelahYourValuesController(
        canAct: () => _foreground,
        gender: widget.gender,
        readAnswers: () => _draft!.copy().answers,
        readSignUpPreferences: _signUp,
        readHardRequirements: () => _draft!.copy().hardRequirements,
        readDealbreakersSaved: () => _dealbreakersSaved,
        onSavePart: _savePart,
        onSaveDealbreakers: _saveDealbreakers,
      );
      setState(() => _loading = false);
    } catch (_) {
      if (!mounted || epoch != _loadEpoch) return;
      setState(() {
        _loading = false;
        _loadError =
            'We couldn’t restore your saved answers. Try again before continuing.';
      });
    }
  }

  Future<bool> _persist(SelahCompatibilityDraft candidate) async {
    if (!_foreground) return false;
    final saved =
        widget.devPreview ||
        await SelahOnboardingAnswersService.syncAnswers(
          ch3Answers: candidate.answers,
          ch4Preferences: candidate.preferences,
          ch4HardRequirements: candidate.hardRequirements,
          expectedUserId: _owner,
        );
    if (!saved || !_foreground) return false;
    _draft = candidate;
    return true;
  }

  Future<bool> _savePart(String partId, Map<String, dynamic> answers) async {
    if (!_foreground || _draft == null) return false;
    final candidate = _draft!.copy();
    final merged = selahMergeYourValuesPart(
      existing: candidate.answers,
      gender: widget.gender,
      partId: partId,
      answers: answers,
      signUpPreferences: _signUp(),
    );
    if (merged == null || !_foreground) return false;
    candidate.answers
      ..clear()
      ..addAll(merged);
    return _persist(candidate);
  }

  Future<bool> _saveDealbreakers(Map<String, Set<String>> requirements) async {
    if (!_foreground ||
        _draft == null ||
        !(_controller?.allPartsDone ?? false)) {
      return false;
    }
    final candidate = _draft!.copy();
    final merged = selahMergeDealbreakers(
      existing: candidate.hardRequirements,
      requirements: requirements,
    );
    if (merged == null || !_foreground) return false;
    candidate.hardRequirements
      ..clear()
      ..addAll(merged);
    final saved = await _persist(candidate);
    if (!saved || !_foreground) return false;
    _dealbreakersSaved = true;
    return true;
  }

  Future<void> _finish() async {
    if (!_foreground ||
        !(_controller?.allPartsDone ?? false) ||
        !(_controller?.dealbreakersDone ?? false)) {
      return;
    }
    _leaving = true;
    var stageLeaving = false;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (stageContext) {
          void openReview() {
            if (stageLeaving ||
                !stageContext.mounted ||
                ModalRoute.of(stageContext)?.isCurrent != true ||
                !_current) {
              return;
            }
            stageLeaving = true;
            Navigator.of(stageContext).pushReplacement(
              MaterialPageRoute<void>(
                builder: (_) =>
                    ProfileReadyScreen(devPreview: widget.devPreview),
              ),
            );
          }

          return OnboardingStageIntroScreen(
            stage: SeekerOnboardingStage.review,
            devPreview: widget.devPreview,
            onDevSkip: widget.devPreview ? openReview : null,
            onContinue: openReview,
          );
        },
      ),
    );
    if (mounted) setState(() => _leaving = false);
  }

  @override
  void dispose() {
    _closed = true;
    _loadEpoch++;
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_current) {
      return const SizedBox.shrink(key: ValueKey('values_preview_denied'));
    }
    if (_loading) {
      return const SelahLoading.fullScreen(
        label: 'Restoring your saved progress…',
      );
    }
    if (_loadError != null) {
      return Scaffold(
        backgroundColor: SelahColors.mist,
        body: SafeArea(
          child: SelahEmptyState(
            icon: Icons.cloud_off_outlined,
            message: _loadError!,
            ctaLabel: 'Try again',
            onCta: _restore,
          ),
        ),
      );
    }
    return SelahYourValuesFlow(
      controller: _controller!,
      onBack: () {
        if (_foreground) Navigator.of(context).maybePop();
      },
      onFinished: _finish,
    );
  }
}
