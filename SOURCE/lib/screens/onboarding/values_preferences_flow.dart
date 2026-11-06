// Compatibility onboarding — two calm, separate modes over the existing
// Chapter 3/4 storage contract.
//
// Part 1 asks every private "About You" question, grouped into the 11
// Founder-approved sections. Part 2 then revisits those same sections as 11
// scrolling Partner Preference pages. The traffic-light map remains
// per-option, so score_candidates() and saved onboarding rows do not change.

import 'package:flutter/material.dart';

import '../../data/chapter3_categories.dart';
import '../../models/onboarding_question.dart';
import '../../models/selah_sign_up_compatibility.dart';
import '../../services/selah_onboarding_answers_service.dart';
import '../../services/selah_account_state.dart';
import '../../services/selah_auth.dart';
import '../../services/selah_developer_access.dart';
import '../../services/selah_internal_preview_client.dart';
import '../../state/app_state.dart';
import '../../theme/selah_colors.dart';
import '../../theme/selah_text.dart';
import '../../widgets/onboarding_scaffold.dart';
import '../../widgets/privacy_indicator.dart';
import '../../widgets/selah_loading.dart';
import '../../widgets/selah_state_widgets.dart';
import 'category_summary_screen.dart';
import 'compatibility_category_intro_screen.dart';
import 'generic_select_question_screen.dart';
import 'onboarding_stage_intro_screen.dart';
import 'profile_ready_screen.dart';
import 'seeker_setup_navigation.dart';
import 'traffic_light_question_screen.dart';

enum _FlowStepKind {
  categoryIntro,
  answer,
  summary,
  aboutYouComplete,
  preferencesIntro,
  preferenceGuide,
  preferenceSection,
}

class _FlowStep {
  final _FlowStepKind kind;
  final OnboardingCategory? category;
  final OnboardingQuestion? question;

  const _FlowStep(this.kind, {this.category, this.question});

  String get anchor => switch (kind) {
    _FlowStepKind.categoryIntro => 'intro:${category!.id}',
    _FlowStepKind.answer => 'answer:${question!.responseKey}',
    _FlowStepKind.summary => 'summary:${category!.id}',
    _FlowStepKind.aboutYouComplete => 'about-complete',
    _FlowStepKind.preferencesIntro => 'preferences-intro',
    _FlowStepKind.preferenceGuide => 'preferences-guide',
    _FlowStepKind.preferenceSection => 'preferences:${category!.id}',
  };
}

class ValuesPreferencesFlow extends StatefulWidget {
  /// Non-null by construction: Gender is a mandatory Essentials answer.
  /// Making that contract explicit prevents both `ch3_q26` variants from
  /// silently disappearing when Compatibility is entered with no gender.
  final String gender;
  final bool devPreview;
  final SelahSignUpPreferencesReader? readSignUpPreferences;

  const ValuesPreferencesFlow({
    super.key,
    required this.gender,
    this.devPreview = false,
    this.readSignUpPreferences,
  });

  @override
  State<ValuesPreferencesFlow> createState() => _ValuesPreferencesFlowState();
}

class _ValuesPreferencesFlowState extends State<ValuesPreferencesFlow> {
  int _stepIndex = 0;
  bool _restoring = false;
  bool _saving = false;
  bool _leaving = false;
  String? _restoreError;
  String? _ownerId;
  late final int _ownerGeneration;

  final Map<String, dynamic> _ch3Answers = {};
  final Map<String, Map<String, TrafficLight>> _ch4Preferences = {};
  final Map<String, Set<String>> _ch4HardRequirement = {};

  // A revoked preview is denied, never reclassified as a live signup.
  bool get _devPreview => widget.devPreview;
  bool get _canProceed =>
      mounted &&
      !_restoring &&
      !_saving &&
      !_leaving &&
      _restoreError == null &&
      (_devPreview ? SelahDeveloperAccess.canUseDeveloperTools : _ownerCurrent);

  bool get _ownerCurrent =>
      SelahOnboardingAnswersService.clientReady &&
      !SelahInternalPreviewClient.isActive &&
      !SelahAccountState.isSigningOut &&
      _ownerId != null &&
      SelahAuth.currentUser?.id == _ownerId &&
      SelahAccountState.generation == _ownerGeneration;

  SelahBackgroundVariant get _background => switch (widget.gender) {
    'male' => SelahBackgroundVariant.male,
    'female' => SelahBackgroundVariant.female,
    _ => SelahBackgroundVariant.neutral,
  };

  List<OnboardingQuestion> _visible(OnboardingCategory category) => category
      .questions
      .where(
        (question) =>
            question.visibleGiven(widget.gender, _answersByQuestionId),
      )
      .toList(growable: false);

  Map<String, dynamic> get _answersByQuestionId {
    final answers = <String, dynamic>{};
    final effective = _signUp.answersOver(_ch3Answers);
    for (final category in chapter3CompatibilityCategories) {
      for (final question in category.questions) {
        final key = question.responseKey;
        if (effective.containsKey(key)) {
          answers[question.id] = effective[key];
        }
      }
    }
    return answers;
  }

  SelahSignUpCompatibility get _signUp {
    try {
      return SelahSignUpCompatibility.fromPreferences(
        widget.readSignUpPreferences?.call() ?? const {},
      );
    } catch (_) {
      return SelahSignUpCompatibility.fromPreferences(const {});
    }
  }

  List<OnboardingQuestion> _preferenceQuestions(OnboardingCategory category) =>
      _visible(category)
          .where((question) => question.ch4Status != Ch4Status.none)
          .toList(growable: false);

  late List<_FlowStep> _steps = _buildSteps();

  @override
  void initState() {
    super.initState();
    _ownerGeneration = SelahAccountState.generation;
    if (!_devPreview) {
      _ownerId = SelahOnboardingAnswersService.clientReady
          ? SelahAuth.currentUser?.id
          : null;
      if (_ownerId == null) {
        _restoreError = 'Sign in again to continue your saved setup.';
      } else {
        _restoreSavedProgress();
      }
    }
  }

  Future<void> _restoreSavedProgress() async {
    if (_devPreview || _restoring || !_ownerCurrent) return;
    setState(() {
      _restoring = true;
      _restoreError = null;
    });
    try {
      final snapshot = await SelahOnboardingAnswersService.fetchOwn(
        expectedUserId: _ownerId,
        throwOnError: true,
      ).timeout(const Duration(seconds: 10));
      if (!mounted || !_ownerCurrent) return;
      if (snapshot == null) return;

      AppState.instance.saveJourneyBio(snapshot.journeyBio);
      for (final category in chapter3CompatibilityCategories) {
        for (final question in category.questions) {
          final persisted = SelahOnboardingAnswersService.persistedQuestionId(
            question.responseKey,
          );
          if (snapshot.ch3Answers.containsKey(persisted)) {
            _ch3Answers[question.responseKey] = snapshot.ch3Answers[persisted];
          }
          final preferences = snapshot.ch4Preferences[persisted];
          if (preferences != null) {
            _ch4Preferences[question.responseKey] = preferences;
          }
          final hard = snapshot.ch4HardRequirements[persisted];
          if (hard != null) {
            _ch4HardRequirement[question.responseKey] = hard;
          }
        }
      }
      _steps = _buildSteps();
      _stepIndex = _resumeStepIndex(snapshot);
    } catch (_) {
      if (mounted) {
        _restoreError =
            'We couldn’t restore your saved answers. Try again before continuing.';
      }
    } finally {
      if (mounted) setState(() => _restoring = false);
    }
  }

  int _resumeStepIndex(SelahOnboardingAnswersSnapshot snapshot) {
    if (snapshot.ch3Answers.keys.every((key) => key.startsWith('bio_'))) {
      return 0;
    }

    for (var index = 0; index < _steps.length; index++) {
      final step = _steps[index];
      if (step.kind == _FlowStepKind.answer &&
          !_answerComplete(step.question!)) {
        return index;
      }
    }

    if (snapshot.ch4Preferences.isEmpty) {
      return _steps.indexWhere(
        (step) => step.kind == _FlowStepKind.preferencesIntro,
      );
    }
    for (var index = 0; index < _steps.length; index++) {
      final step = _steps[index];
      if (step.kind == _FlowStepKind.preferenceSection &&
          !_preferenceSectionComplete(step.category!)) {
        return index;
      }
    }
    return _steps.length - 1;
  }

  List<_FlowStep> _buildSteps() {
    final steps = <_FlowStep>[];

    for (final category in chapter3Categories) {
      final questions = _visible(category);
      if (questions.isEmpty) continue;
      steps.add(_FlowStep(_FlowStepKind.categoryIntro, category: category));
      for (final question in questions) {
        steps.add(
          _FlowStep(
            _FlowStepKind.answer,
            category: category,
            question: question,
          ),
        );
      }
      steps.add(_FlowStep(_FlowStepKind.summary, category: category));
    }

    steps.add(const _FlowStep(_FlowStepKind.aboutYouComplete));
    steps.add(const _FlowStep(_FlowStepKind.preferencesIntro));
    steps.add(const _FlowStep(_FlowStepKind.preferenceGuide));

    for (final category in chapter4Categories) {
      if (_preferenceQuestions(category).isEmpty) continue;
      steps.add(_FlowStep(_FlowStepKind.preferenceSection, category: category));
    }

    return steps;
  }

  void _recordCh3Answer(OnboardingQuestion question, dynamic value) {
    if (!_canProceed) return;
    setState(() {
      _ch3Answers[question.responseKey] = value;

      final anchor = _steps[_stepIndex].anchor;
      _steps = _buildSteps();

      final stillVisible = <String>{
        for (final category in chapter3Categories)
          for (final question in _visible(category)) question.responseKey,
      };
      _ch3Answers.removeWhere(
        (id, _) =>
            !selahSignUpQuestionIds.contains(id) && !stillVisible.contains(id),
      );
      final preferenceVisible = <String>{
        for (final category in chapter4Categories)
          for (final question in _preferenceQuestions(category))
            question.responseKey,
      };
      _ch4Preferences.removeWhere(
        (id, _) => id != 'ch3_q1' && !preferenceVisible.contains(id),
      );
      _ch4HardRequirement.removeWhere(
        (id, _) => id != 'ch3_q1' && !preferenceVisible.contains(id),
      );

      final reanchored = _steps.indexWhere((step) => step.anchor == anchor);
      if (reanchored != -1) _stepIndex = reanchored;
      if (_stepIndex >= _steps.length) _stepIndex = _steps.length - 1;
    });
  }

  void _back() {
    if (!_canProceed) return;
    if (_stepIndex > 0) setState(() => _stepIndex--);
  }

  Future<bool> _syncAnswers() async {
    if (_devPreview) return true;
    if (!_ownerCurrent) return false;
    return SelahOnboardingAnswersService.syncAnswers(
      ch3Answers: _ch3Answers,
      ch4Preferences: _ch4Preferences,
      ch4HardRequirements: _ch4HardRequirement,
      expectedUserId: _ownerId,
    );
  }

  void _saveFailure(VoidCallback retry, {bool returningToApp = false}) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(
          returningToApp
              ? 'We couldn’t return to My SELAH. Your answers are still here; try again.'
              : 'Your answers weren’t saved. They’re still here; try again.',
        ),
        action: SnackBarAction(label: 'Try again', onPressed: retry),
      ),
    );
  }

  Future<void> _finishLater() async {
    if (!_canProceed) return;
    setState(() => _saving = true);
    var returned = false;
    try {
      // A break may be taken without finishing the current question. Save
      // exactly the entered draft, without marking this chapter complete.
      final saved = await _syncAnswers();
      if (!mounted || (!_devPreview && !_ownerCurrent)) return;
      if (!saved) {
        _saveFailure(_finishLater);
        return;
      }
      returned = await returnToMySelah(
        context,
        devPreview: _devPreview,
        expectedUserId: _ownerId,
        expectedGeneration: _ownerGeneration,
      );
      if (!mounted) return;
      if (returned) {
        _leaving = true;
      } else {
        _saveFailure(_finishLater, returningToApp: true);
      }
    } finally {
      if (mounted && !returned) setState(() => _saving = false);
    }
  }

  Future<void> _next() async {
    if (!_canProceed ||
        ModalRoute.of(context)?.isCurrent != true ||
        (!_devPreview && !_canContinue)) {
      return;
    }
    final step = _steps[_stepIndex];
    if (step.kind == _FlowStepKind.answer ||
        step.kind == _FlowStepKind.summary ||
        step.kind == _FlowStepKind.preferenceSection) {
      if (!_devPreview) {
        setState(() => _saving = true);
        final saved = await _syncAnswers();
        if (!mounted) return;
        setState(() => _saving = false);
        if (!_ownerCurrent) return;
        if (!saved) {
          _saveFailure(_next);
          return;
        }
      }
    }

    if (!_canProceed || ModalRoute.of(context)?.isCurrent != true) return;

    if (_stepIndex < _steps.length - 1) {
      setState(() => _stepIndex++);
      return;
    }

    final devPreview = _devPreview;
    final owner = _ownerId;
    final ownerGeneration = _ownerGeneration;
    var stageLeaving = false;
    setState(() => _leaving = true);
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (stageContext) {
          void openReview() {
            if (stageLeaving ||
                !stageContext.mounted ||
                ModalRoute.of(stageContext)?.isCurrent != true) {
              return;
            }
            if (devPreview
                ? !SelahDeveloperAccess.canUseDeveloperTools
                : owner == null ||
                      SelahAuth.currentUser?.id != owner ||
                      !SelahAccountState.isCurrent(owner, ownerGeneration)) {
              return;
            }
            stageLeaving = true;
            Navigator.of(stageContext).pushReplacement(
              MaterialPageRoute(
                builder: (_) => ProfileReadyScreen(devPreview: devPreview),
              ),
            );
          }

          return OnboardingStageIntroScreen(
            stage: SeekerOnboardingStage.review,
            devPreview: devPreview,
            onDevSkip: devPreview ? openReview : null,
            onContinue: openReview,
          );
        },
      ),
    );
    if (mounted) setState(() => _leaving = false);
  }

  Set<String> _answerOptions(OnboardingQuestion question) {
    final answer = _signUp.answersOver(_ch3Answers)[question.responseKey];
    if (answer == null) return const {};
    if (answer is List) {
      return answer.map((value) => value.toString()).toSet();
    }
    return {answer.toString()};
  }

  bool _answerComplete(OnboardingQuestion question) {
    final value = _ch3Answers[question.responseKey];
    if (value is List) {
      return value.isNotEmpty &&
          value.every(
            (item) => item is String && question.options.contains(item),
          );
    }
    return value is String && question.options.contains(value);
  }

  bool _preferenceSectionComplete(OnboardingCategory category) =>
      _preferenceQuestions(category).every((question) {
        final values = _ch4Preferences[question.responseKey];
        return values != null && question.options.every(values.containsKey);
      });

  bool get _canContinue {
    final step = _steps[_stepIndex];
    return switch (step.kind) {
      _FlowStepKind.answer => _answerComplete(step.question!),
      _FlowStepKind.preferenceSection => _preferenceSectionComplete(
        step.category!,
      ),
      _ => true,
    };
  }

  int _sectionIndex(OnboardingCategory category) =>
      chapter3Categories.indexWhere((item) => item.id == category.id) + 1;

  Widget _buildPreferenceSection(_FlowStep step) {
    final category = step.category!;
    final questions = _preferenceQuestions(category);
    final sectionIndex = _sectionIndex(category);

    return OnboardingScaffold(
      background: _background,
      chapterName: 'Compatibility · Part 2',
      chapterProgress: sectionIndex / chapter3Categories.length,
      progressLabel: 'SECTION $sectionIndex OF ${chapter3Categories.length}',
      question: category.name,
      subtext:
          'Section $sectionIndex of ${chapter3Categories.length} · '
          '${questions.length} partner ${questions.length == 1 ? 'preference' : 'preferences'}',
      privacy: PrivacyLevel.private,
      privacyOverrideText:
          'Private. Used to calculate your compatibility score.',
      fabActive: _canProceed && _canContinue,
      onContinue: _next,
      onFinishLater: _canProceed ? _finishLater : null,
      devPreview: _devPreview,
      onDevSkip: _next,
      devSkipLabel: 'Skip section',
      onSwipeBack: _back,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var index = 0; index < questions.length; index++) ...[
            _PreferenceQuestionBlock(
              question: questions[index],
              position: index + 1,
              total: questions.length,
              yourAnswers: _answerOptions(questions[index]),
              initialValues:
                  _ch4Preferences[questions[index].responseKey] ?? const {},
              initialHardRequirement:
                  _ch4HardRequirement[questions[index].responseKey] ?? const {},
              onChanged: (values) {
                if (!_canProceed) return;
                setState(
                  () => _ch4Preferences[questions[index].responseKey] = values,
                );
              },
              onHardRequirementChanged: (values) {
                if (!_canProceed) return;
                setState(() {
                  if (values.isEmpty) {
                    _ch4HardRequirement.remove(questions[index].responseKey);
                  } else {
                    _ch4HardRequirement[questions[index].responseKey] = values;
                  }
                });
              },
            ),
            if (index != questions.length - 1) SizedBox(height: 18),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([
      SelahDeveloperAccess.authorizationChanges,
      AppState.instance,
    ]),
    builder: (context, _) {
      if (_devPreview && !SelahDeveloperAccess.canUseDeveloperTools) {
        return Scaffold(
          key: const ValueKey('values_preview_denied'),
          backgroundColor: SelahColors.modalSheetSurface,
          body: const SizedBox.expand(),
        );
      }
      if (!_devPreview && !_ownerCurrent) {
        return _recoveryScreen(
          'Your account changed. Sign in again to continue setup.',
        );
      }
      if (_restoreError != null) {
        return _recoveryScreen(_restoreError!, onRetry: _restoreSavedProgress);
      }
      return Stack(
        children: [
          AbsorbPointer(
            absorbing: _saving || _leaving,
            child: _buildFlow(context),
          ),
          if (_saving)
            const SelahLoading.fullScreen(label: 'Saving your progress…'),
        ],
      );
    },
  );

  Widget _recoveryScreen(String message, {VoidCallback? onRetry}) => Scaffold(
    key: const ValueKey('values_recovery'),
    body: Container(
      decoration: BoxDecoration(gradient: SelahColors.brandGradient),
      child: SafeArea(
        child: SelahEmptyState(
          icon: Icons.cloud_off_outlined,
          message: message,
          ctaLabel: onRetry == null ? null : 'Try again',
          onCta: onRetry,
        ),
      ),
    ),
  );

  Widget _withDevSkip(Widget child) {
    if (!_devPreview) return child;
    return Stack(
      children: [
        child,
        Positioned(
          top: MediaQuery.paddingOf(context).top + 12,
          right: 18,
          child: SafeArea(
            top: false,
            child: TextButton.icon(
              key: const ValueKey('deferred_onboarding_dev_skip'),
              onPressed: _canProceed ? _next : null,
              icon: const Icon(Icons.skip_next_rounded, size: 18),
              label: const Text('Skip · DEV'),
              style: TextButton.styleFrom(
                foregroundColor: SelahColors.unlockText,
                backgroundColor: SelahColors.modalSheetSurface,
                minimumSize: const Size(104, 44),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFlow(BuildContext context) {
    if (_restoring) {
      return const SelahLoading.fullScreen(
        label: 'Restoring your saved progress…',
      );
    }
    final step = _steps[_stepIndex];

    if (step.kind == _FlowStepKind.categoryIntro) {
      final category = step.category!;
      return _withDevSkip(
        CompatibilityCategoryIntroScreen(
          category: category,
          sectionIndex: _sectionIndex(category),
          totalSections: chapter3Categories.length,
          questionCount: _visible(category).length,
          onContinue: _next,
          onBack: _stepIndex > 0 ? _back : null,
        ),
      );
    }

    if (step.kind == _FlowStepKind.summary) {
      final category = step.category!;
      return _withDevSkip(
        CategorySummaryScreen(
          background: _background,
          categoryName: category.name,
          questions: _visible(category),
          answers: _ch3Answers,
          onContinue: _next,
          onBack: _back,
        ),
      );
    }

    if (step.kind == _FlowStepKind.aboutYouComplete) {
      return _withDevSkip(
        _CompatibilityBoundaryScreen(
          eyebrow: 'COMPATIBILITY · PART 1 COMPLETE',
          title: 'About You saved.',
          description:
              'Your private answers across all 11 sections are complete.',
          count: chapter3Categories.expand(_visible).length.toString(),
          countLabel: 'about-you answers',
          continueLabel: 'Continue',
          onContinue: _next,
          onBack: _back,
        ),
      );
    }

    if (step.kind == _FlowStepKind.preferencesIntro) {
      return _withDevSkip(
        _CompatibilityBoundaryScreen(
          eyebrow: 'COMPATIBILITY · PART 2',
          title: 'Partner Preferences',
          description:
              'Move through the same sections again and set what you prefer, feel neutral about or would rather avoid.',
          count: '11',
          countLabel: 'scrolling sections',
          continueLabel: 'Begin Partner Preferences',
          onContinue: _next,
          onBack: _back,
        ),
      );
    }

    if (step.kind == _FlowStepKind.preferenceGuide) {
      return _withDevSkip(
        _PreferenceGuideScreen(onContinue: _next, onBack: _back),
      );
    }

    if (step.kind == _FlowStepKind.preferenceSection) {
      return _buildPreferenceSection(step);
    }

    final question = step.question!;
    final category = step.category!;
    final visibleQuestions = _visible(category);
    final questionIndex =
        visibleQuestions.indexWhere(
          (item) => item.responseKey == question.responseKey,
        ) +
        1;
    final sectionIndex = _sectionIndex(category);

    return OnboardingScaffold(
      background: _background,
      chapterName: 'Compatibility · Part 1',
      frameContent: false,
      // The rail tracks the eleven sections, including position within the
      // current section. It must not jump back to zero when the next section
      // begins, nor imply each category end completes all of Part 1.
      chapterProgress:
          (sectionIndex - 1 + questionIndex / visibleQuestions.length) /
          chapter3Categories.length,
      progressLabel: 'SECTION $sectionIndex OF ${chapter3Categories.length}',
      question: question.prompt,
      subtext:
          'Section $sectionIndex of ${chapter3Categories.length} · '
          'Question $questionIndex of ${visibleQuestions.length}',
      privacy: PrivacyLevel.private,
      privacyOverrideText:
          'Private. Used to calculate your compatibility score.',
      fabActive: _canProceed && _canContinue,
      onContinue: _next,
      onFinishLater: _canProceed ? _finishLater : null,
      devPreview: _devPreview,
      onDevSkip: _next,
      onSwipeBack: _stepIndex > 0 ? _back : null,
      content: GenericSelectQuestionScreen(
        key: ValueKey('ch3_${question.responseKey}_${widget.gender}'),
        prompt: question.prompt,
        options: question.options,
        selectionType: question.selectionType,
        guidedChoices: true,
        initialValue: _ch3Answers[question.responseKey],
        onChanged: (value) => _recordCh3Answer(question, value),
      ),
    );
  }
}

class _PreferenceQuestionBlock extends StatelessWidget {
  final OnboardingQuestion question;
  final int position;
  final int total;
  final Set<String> yourAnswers;
  final Map<String, TrafficLight> initialValues;
  final Set<String> initialHardRequirement;
  final ValueChanged<Map<String, TrafficLight>> onChanged;
  final ValueChanged<Set<String>> onHardRequirementChanged;

  const _PreferenceQuestionBlock({
    required this.question,
    required this.position,
    required this.total,
    required this.yourAnswers,
    required this.initialValues,
    required this.initialHardRequirement,
    required this.onChanged,
    required this.onHardRequirementChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      decoration: BoxDecoration(
        color: SelahColors.iconButtonBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: SelahColors.iconButtonBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 5,
                height: 22,
                decoration: BoxDecoration(
                  color: SelahColors.unlockDot,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              SizedBox(width: 10),
              Text(
                'QUESTION $position OF $total',
                style: SelahText.chapterLabel(color: SelahColors.unlockText),
              ),
            ],
          ),
          SizedBox(height: 12),
          Text(question.prompt, style: SelahText.heading(size: 18)),
          SizedBox(height: 16),
          TrafficLightQuestionScreen(
            key: ValueKey('ch4_grouped_${question.id}'),
            yourAnswer: '',
            yourAnswers: yourAnswers,
            options: question.options,
            hardRequirementSupported: question.hardRequirementSupported,
            initialValues: initialValues,
            initialHardRequirement: initialHardRequirement,
            onChanged: onChanged,
            onHardRequirementChanged: onHardRequirementChanged,
          ),
        ],
      ),
    );
  }
}

class _PreferenceGuideScreen extends StatelessWidget {
  final VoidCallback onContinue;
  final VoidCallback onBack;

  const _PreferenceGuideScreen({
    required this.onContinue,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        constraints: const BoxConstraints.expand(),
        decoration: BoxDecoration(gradient: SelahColors.brandGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(27, 16, 27, 22),
            child: Column(
              children: [
                _BoundaryCue(
                  key: const ValueKey('preference_guide_back'),
                  icon: Icons.keyboard_arrow_up_rounded,
                  label: 'Partner Preferences above',
                  onTap: onBack,
                ),
                const Spacer(),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'COMPATIBILITY · PART 2',
                    style: SelahText.chapterLabel(
                      color: SelahColors.unlockText,
                    ),
                  ),
                ),
                SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Choose how each answer feels.',
                    style: SelahText.heading(size: 27),
                  ),
                ),
                SizedBox(height: 11),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Each question has several possible answers. Choose one response for every answer.',
                    style: SelahText.body(size: 14),
                  ),
                ),
                SizedBox(height: 24),
                const _PreferenceMeaningRow(
                  color: SelahColors.positiveGreen,
                  title: 'Prefer this',
                  description:
                      'This is something you would welcome in a partner.',
                ),
                SizedBox(height: 10),
                const _PreferenceMeaningRow(
                  color: SelahColors.journeyGold,
                  title: 'No preference',
                  description: 'You neither prefer nor avoid this.',
                ),
                SizedBox(height: 10),
                const _PreferenceMeaningRow(
                  color: SelahColors.negativeRed,
                  title: 'Not for me',
                  description: 'This would not suit what you are looking for.',
                ),
                SizedBox(height: 21),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: PrivacyIndicator(
                    level: PrivacyLevel.private,
                    overrideText:
                        'Private. Used to calculate your compatibility score.',
                  ),
                ),
                const Spacer(flex: 2),
                _BoundaryCue(
                  key: const ValueKey('preference_guide_continue'),
                  icon: Icons.keyboard_arrow_down_rounded,
                  label: 'Start with Faith & Christian Practice',
                  onTap: onContinue,
                  accent: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PreferenceMeaningRow extends StatelessWidget {
  final Color color;
  final String title;
  final String description;

  const _PreferenceMeaningRow({
    required this.color,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: SelahColors.iconButtonBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: SelahColors.iconButtonBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 12,
            height: 12,
            margin: const EdgeInsets.only(top: 3),
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: SelahText.option(size: 13.5)),
                SizedBox(height: 3),
                Text(description, style: SelahText.subtext(size: 11.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CompatibilityBoundaryScreen extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String description;
  final String count;
  final String countLabel;
  final String continueLabel;
  final VoidCallback onContinue;
  final VoidCallback onBack;

  const _CompatibilityBoundaryScreen({
    required this.eyebrow,
    required this.title,
    required this.description,
    required this.count,
    required this.countLabel,
    required this.continueLabel,
    required this.onContinue,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        constraints: const BoxConstraints.expand(),
        decoration: BoxDecoration(gradient: SelahColors.brandGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(27, 16, 27, 22),
            child: Column(
              children: [
                _BoundaryCue(
                  key: const ValueKey('compatibility_boundary_back'),
                  icon: Icons.keyboard_arrow_up_rounded,
                  label: 'Previous page',
                  onTap: onBack,
                ),
                const Spacer(flex: 2),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    eyebrow,
                    style: SelahText.chapterLabel(
                      color: SelahColors.unlockText,
                    ),
                  ),
                ),
                SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(title, style: SelahText.heading(size: 29)),
                ),
                SizedBox(height: 13),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(description, style: SelahText.body(size: 14.5)),
                ),
                SizedBox(height: 25),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: SelahColors.unlockDot,
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          count,
                          style: SelahText.heading(
                            size: 15,
                            color: SelahColors.unlockText,
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Text(countLabel, style: SelahText.subtext(size: 12.5)),
                    ],
                  ),
                ),
                SizedBox(height: 24),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: PrivacyIndicator(
                    level: PrivacyLevel.private,
                    overrideText:
                        'Private. Used to calculate your compatibility score.',
                  ),
                ),
                const Spacer(flex: 3),
                _BoundaryCue(
                  key: const ValueKey('compatibility_boundary_continue'),
                  icon: Icons.keyboard_arrow_down_rounded,
                  label: continueLabel,
                  onTap: onContinue,
                  accent: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BoundaryCue extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool accent;

  const _BoundaryCue({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = accent ? SelahColors.unlockText : SelahColors.ink(0.70);
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 24),
              SizedBox(height: 3),
              Text(
                label,
                textAlign: TextAlign.center,
                style: SelahText.subtext(size: 11.5, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
