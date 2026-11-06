import 'package:flutter/material.dart';
import '../../widgets/selah_loading.dart';
import '../../dev/selah_app_gold_preview.dart';

import '../../data/chapter3_categories.dart';
import '../../models/onboarding_question.dart';
import '../../models/journey_bio.dart';
import '../../models/selah_sign_up_compatibility.dart';
import '../../services/selah_onboarding_answers_service.dart';
import '../../state/app_state.dart';
import '../../theme/selah_colors.dart';
import '../../theme/selah_text.dart';
import '../../widgets/selah_pull_down_back_scope.dart';
import '../onboarding/generic_select_question_screen.dart';

enum CompatibilityEditorKind {
  aboutYou,
  lifestyle,
  marriagePreferences,
  trafficLights,
  hardRequirements,
}

extension CompatibilityEditorKindUi on CompatibilityEditorKind {
  String get label => switch (this) {
    CompatibilityEditorKind.aboutYou => 'About you',
    CompatibilityEditorKind.lifestyle => 'Lifestyle',
    CompatibilityEditorKind.marriagePreferences => 'Marriage preferences',
    CompatibilityEditorKind.trafficLights => 'Green / Yellow / Red',
    CompatibilityEditorKind.hardRequirements => 'Hard requirements',
  };

  String get description => switch (this) {
    CompatibilityEditorKind.aboutYou =>
      'Your faith, values, personality and connection style.',
    CompatibilityEditorKind.lifestyle =>
      'Your work, finances, wellbeing, digital life and daily choices.',
    CompatibilityEditorKind.marriagePreferences =>
      'Your intentions, family expectations, home life and communication.',
    CompatibilityEditorKind.trafficLights =>
      'How every possible partner answer feels to you.',
    CompatibilityEditorKind.hardRequirements =>
      'Answers that must prevent an introduction.',
  };

  IconData get icon => switch (this) {
    CompatibilityEditorKind.aboutYou => Icons.person_outline_rounded,
    CompatibilityEditorKind.lifestyle => Icons.wb_sunny_outlined,
    CompatibilityEditorKind.marriagePreferences => Icons.tune_rounded,
    CompatibilityEditorKind.trafficLights => Icons.traffic_outlined,
    CompatibilityEditorKind.hardRequirements => Icons.gpp_maybe_outlined,
  };

  List<String> get categoryIds => switch (this) {
    CompatibilityEditorKind.aboutYou => const ['faith_practice'],
    CompatibilityEditorKind.lifestyle => const [
      'finances_provision',
      'lifestyle_wellbeing',
    ],
    CompatibilityEditorKind.marriagePreferences => const [
      'marriage_intentions',
      'family_in_laws',
      'home_roles',
      'communication_conflict',
    ],
    CompatibilityEditorKind.trafficLights ||
    CompatibilityEditorKind.hardRequirements => const [],
  };
}

class SelahCompatibilityDraft {
  SelahCompatibilityDraft({
    required this.gender,
    required this.answers,
    required this.preferences,
    required this.hardRequirements,
    this.readSignUpPreferences,
  });

  factory SelahCompatibilityDraft.fromSnapshot({
    required String? gender,
    SelahOnboardingAnswersSnapshot? snapshot,
    SelahSignUpPreferencesReader? readSignUpPreferences,
  }) {
    final answers = <String, dynamic>{
      ...?snapshot?.journeyBio.toOnboardingAnswers(),
      for (final entry
          in snapshot?.ch3Answers.entries ?? <MapEntry<String, dynamic>>[])
        entry.key: _copyAnswerValue(entry.value),
    };
    final preferences = <String, Map<String, TrafficLight>>{
      for (final entry
          in snapshot?.ch4Preferences.entries ??
              <MapEntry<String, Map<String, TrafficLight>>>[])
        entry.key: Map.of(entry.value),
    };
    final hard = <String, Set<String>>{
      for (final entry
          in snapshot?.ch4HardRequirements.entries ??
              <MapEntry<String, Set<String>>>[])
        entry.key: Set.of(entry.value),
    };
    // The one gender-specific qid keeps its established in-memory response
    // key; every unasked/hidden raw value remains detached and untouched.
    for (final category in chapter3CompatibilityCategories) {
      for (final question in category.questions) {
        if (!question.visibleFor(gender) ||
            question.responseKey == question.id) {
          continue;
        }
        final persisted = question.id;
        if (answers.containsKey(persisted)) {
          answers[question.responseKey] = _copyAnswerValue(
            answers.remove(persisted),
          );
        }
        if (preferences.containsKey(persisted)) {
          preferences[question.responseKey] = preferences.remove(persisted)!;
        }
        if (hard.containsKey(persisted)) {
          hard[question.responseKey] = hard.remove(persisted)!;
        }
      }
    }

    final draft = SelahCompatibilityDraft(
      gender: gender,
      answers: answers,
      preferences: preferences,
      hardRequirements: hard,
      readSignUpPreferences: readSignUpPreferences,
    );
    draft.pruneHiddenAnswers();
    return draft;
  }

  final String? gender;
  final Map<String, dynamic> answers;
  final Map<String, Map<String, TrafficLight>> preferences;
  final Map<String, Set<String>> hardRequirements;
  final SelahSignUpPreferencesReader? readSignUpPreferences;

  SelahSignUpCompatibility get _signUp {
    try {
      return SelahSignUpCompatibility.fromPreferences(
        readSignUpPreferences?.call() ?? const {},
      );
    } catch (_) {
      return SelahSignUpCompatibility.fromPreferences(const {});
    }
  }

  Map<String, dynamic> get compatibilityAnswers => _signUp.answersOver(answers);
  Map<String, Map<String, TrafficLight>> get compatibilityPreferences =>
      _signUp.preferencesOver(preferences);
  Map<String, Set<String>> get compatibilityHardRequirements =>
      _signUp.hardRequirementsOver(hardRequirements);

  SelahCompatibilityDraft copy({
    SelahSignUpPreferencesReader? readSignUpPreferences,
  }) => SelahCompatibilityDraft(
    gender: gender,
    readSignUpPreferences: readSignUpPreferences ?? this.readSignUpPreferences,
    answers: {
      for (final entry in answers.entries)
        entry.key: _copyAnswerValue(entry.value),
    },
    preferences: {
      for (final entry in preferences.entries)
        entry.key: Map<String, TrafficLight>.from(entry.value),
    },
    hardRequirements: {
      for (final entry in hardRequirements.entries)
        entry.key: Set<String>.from(entry.value),
    },
  );

  /// A detached own-draft checkpoint. Uses the established canonical question
  /// IDs without consulting AppState, a member ledger or a network service.
  SelahOnboardingAnswersSnapshot toSnapshot() {
    final normalized = <String, dynamic>{
      for (final entry in answers.entries)
        SelahOnboardingAnswersService.persistedQuestionId(entry.key):
            _copyAnswerValue(entry.value),
    };
    return SelahOnboardingAnswersSnapshot(
      ch3Answers: normalized,
      ch4Preferences: {
        for (final entry in preferences.entries)
          SelahOnboardingAnswersService.persistedQuestionId(entry.key):
              Map<String, TrafficLight>.from(entry.value),
      },
      ch4HardRequirements: {
        for (final entry in hardRequirements.entries)
          SelahOnboardingAnswersService.persistedQuestionId(entry.key):
              Set<String>.from(entry.value),
      },
      journeyBio: JourneyBio.fromOnboardingAnswers(normalized),
    );
  }

  Map<String, dynamic> get _answersByQuestionId {
    final result = <String, dynamic>{};
    final effective = compatibilityAnswers;
    for (final category in chapter3CompatibilityCategories) {
      for (final question in category.questions) {
        if (effective.containsKey(question.responseKey)) {
          result[question.id] = effective[question.responseKey];
        }
      }
    }
    return result;
  }

  List<OnboardingQuestion> visibleQuestions(OnboardingCategory category) =>
      category.questions
          .where(
            (question) => question.visibleGiven(gender, _answersByQuestionId),
          )
          .toList(growable: false);

  List<OnboardingQuestion> preferenceQuestions(OnboardingCategory category) =>
      visibleQuestions(category)
          .where((question) => question.ch4Status != Ch4Status.none)
          .toList(growable: false);

  void setAnswer(OnboardingQuestion question, dynamic value) {
    if (selahSignUpQuestionIds.contains(question.id)) return;
    answers[question.responseKey] = value;
    pruneHiddenAnswers();
  }

  // LOCK 17/18: hiding or retiring a question changes only its effective
  // read projection. Raw saved data must survive every unrelated round-trip.
  void pruneHiddenAnswers() {}

  int answeredIn(Iterable<OnboardingCategory> categories) => categories
      .expand(visibleQuestions)
      .where((question) => _hasValue(answers[question.responseKey]))
      .length;

  int questionsIn(Iterable<OnboardingCategory> categories) =>
      categories.expand(visibleQuestions).length;

  int get preferenceAnswerCount => preferences.entries
      .where((entry) => entry.key != 'ch3_q1')
      .fold<int>(0, (total, entry) => total + entry.value.length);

  int get preferenceOptionCount => chapter4Categories
      .expand(preferenceQuestions)
      .fold<int>(0, (total, question) => total + question.options.length);

  int get hardRequirementCount => compatibilityHardRequirements.values
      .fold<int>(0, (total, values) => total + values.length);

  static bool _hasValue(dynamic value) => switch (value) {
    List<dynamic> values => values.isNotEmpty,
    String value => value.trim().isNotEmpty,
    null => false,
    _ => true,
  };
}

dynamic _copyAnswerValue(dynamic value) => switch (value) {
  List<String> values => List<String>.from(values),
  Map<String, String> values => Map<String, String>.from(values),
  Set<String> values => Set<String>.from(values),
  List values => [for (final item in values) _copyAnswerValue(item)],
  Map values => {
    for (final entry in values.entries)
      entry.key: _copyAnswerValue(entry.value),
  },
  Set values => {for (final item in values) _copyAnswerValue(item)},
  _ => value,
};

class _CompatibilityPreviewOwner {
  _CompatibilityPreviewOwner(this.guard, this.gender, this.canEdit);
  final bool Function() guard;
  final String? gender;
  final bool Function() canEdit;
  bool revoked = false;
  bool get alive {
    if (revoked) return false;
    try {
      if (guard()) return true;
    } catch (_) {
      // A failed caller-owner check is permanent denial, not live fallback.
    }
    revoked = true;
    return false;
  }
}

bool _editorCurrent(
  BuildContext context,
  _CompatibilityPreviewOwner? owner, {
  bool editing = true,
}) =>
    context.mounted &&
    (ModalRoute.of(context)?.isCurrent ?? true) &&
    (owner == null || (owner.alive && (!editing || owner.canEdit())));

List<OnboardingCategory> categoriesForKind(CompatibilityEditorKind kind) {
  final ids = kind.categoryIds;
  if (ids.isEmpty) return chapter3Categories;
  return [
    for (final id in ids)
      chapter3Categories.firstWhere((category) => category.id == id),
  ];
}

class CompatibilityEditorScreen extends StatefulWidget {
  const CompatibilityEditorScreen({
    super.key,
    required this.kind,
    required this.initialDraft,
    required this.onPersist,
  }) : _preview = false,
       _previewCanAct = null;

  const CompatibilityEditorScreen.preview({
    super.key,
    required this.kind,
    required this.initialDraft,
    required this.onPersist,
    required bool Function() canAct,
  }) : _preview = true,
       _previewCanAct = canAct;

  final CompatibilityEditorKind kind;
  final SelahCompatibilityDraft initialDraft;
  final Future<bool> Function(SelahCompatibilityDraft draft) onPersist;
  final bool _preview;
  final bool Function()? _previewCanAct;

  @override
  State<CompatibilityEditorScreen> createState() =>
      _CompatibilityEditorScreenState();
}

class _CompatibilityEditorScreenState extends State<CompatibilityEditorScreen> {
  late final SelahCompatibilityDraft _draft = widget.initialDraft.copy();
  late final bool _previewMode = widget._preview;
  late final _CompatibilityPreviewOwner? _owner = _previewMode
      ? _CompatibilityPreviewOwner(
          widget._previewCanAct!,
          _draft.gender,
          () => mounted && !_saving,
        )
      : null;
  bool _saving = false;
  int _saveEpoch = 0;
  bool get _retiredPartnerEditor =>
      widget.kind == CompatibilityEditorKind.trafficLights ||
      widget.kind == CompatibilityEditorKind.hardRequirements;
  bool get _current =>
      mounted &&
      !_retiredPartnerEditor &&
      _editorCurrent(context, _owner, editing: false);

  @override
  void didUpdateWidget(covariant CompatibilityEditorScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_previewMode &&
        (!widget._preview ||
            oldWidget._previewCanAct != widget._previewCanAct ||
            oldWidget.onPersist != widget.onPersist ||
            oldWidget.kind != widget.kind ||
            !identical(oldWidget.initialDraft, widget.initialDraft))) {
      _owner!.revoked = true;
      ++_saveEpoch;
      _saving = false;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_previewMode &&
        _saving &&
        !(ModalRoute.of(context)?.isCurrent ?? true)) {
      ++_saveEpoch;
      _saving = false;
    }
  }

  @override
  void dispose() {
    ++_saveEpoch;
    if (_owner != null) _owner.revoked = true;
    super.dispose();
  }

  void _back() {
    if (_current && !_saving && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _save() async {
    if (_saving || !_current) return;
    final epoch = ++_saveEpoch;
    final route = ModalRoute.of(context);
    final candidate = _draft.copy();
    setState(() => _saving = true);
    bool saved;
    try {
      saved = await widget
          .onPersist(candidate)
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      saved = false;
    }
    if (!mounted || epoch != _saveEpoch) return;
    setState(() => _saving = false);
    if (!_current || !identical(route, ModalRoute.of(context))) return;
    if (saved) {
      Navigator.of(context).pop(candidate);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Your changes could not be saved. Please try again.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_retiredPartnerEditor) {
      return const SizedBox.shrink(
        key: ValueKey('compatibility_partner_editor_retired'),
      );
    }
    if (_previewMode && !_owner!.alive) {
      return const SizedBox.shrink(
        key: ValueKey('compatibility_editor_preview_denied'),
      );
    }
    final kind = widget.kind;
    final content = Column(
      children: [
        if (_previewMode)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(kind.label, style: SelahText.heading(size: 28)),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              kind.description,
              style: SelahText.subtext(
                size: 12.5,
                color: SelahColors.ink(0.56),
              ),
            ),
          ),
        ),
        Expanded(
          child: IgnorePointer(
            ignoring: _saving,
            child: switch (kind) {
              CompatibilityEditorKind.aboutYou ||
              CompatibilityEditorKind.lifestyle ||
              CompatibilityEditorKind.marriagePreferences => _AnswerGroups(
                kind: kind,
                draft: _draft,
                owner: _owner,
                onChanged: () {
                  if (mounted && _editorCurrent(context, _owner)) {
                    setState(() {});
                  }
                },
              ),
              CompatibilityEditorKind.trafficLights ||
              CompatibilityEditorKind.hardRequirements =>
                const SizedBox.shrink(),
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: const ValueKey('compatibility-save'),
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(width: 18, height: 18, child: SelahLoading())
                  : const Text('Save changes'),
            ),
          ),
        ),
      ],
    );
    final page = Scaffold(
      backgroundColor: Colors.transparent,
      appBar: _previewMode
          ? null
          : AppBar(
              title: Text(kind.label, style: SelahText.heading(size: 17)),
              iconTheme: IconThemeData(color: SelahColors.ink(0.70)),
            ),
      body: Container(
        decoration: _previewMode
            ? BoxDecoration(gradient: SelahColors.genderGradient(_draft.gender))
            : SelahAppGoldDecoration(
                gradient: SelahColors.genderGradient(AppState.instance.gender),
              ),
        child: SafeArea(top: _previewMode, child: content),
      ),
    );
    return _previewMode
        ? SelahPullDownBackScope(
            onBack: _back,
            routeIdentity: this,
            enabled: !_saving && _owner!.alive,
            child: page,
          )
        : page;
  }
}

class _AnswerGroups extends StatelessWidget {
  const _AnswerGroups({
    required this.kind,
    required this.draft,
    required this.onChanged,
    this.owner,
  });

  final CompatibilityEditorKind kind;
  final SelahCompatibilityDraft draft;
  final VoidCallback onChanged;
  final _CompatibilityPreviewOwner? owner;

  @override
  Widget build(BuildContext context) {
    final categories = categoriesForKind(kind);
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      children: [
        for (final category in categories)
          _CategoryDoor(
            key: ValueKey('edit-category-${category.id}'),
            label: category.name,
            status:
                '${draft.answeredIn([category])} of '
                '${draft.questionsIn([category])} answered',
            onTap: () async {
              if (!_editorCurrent(context, owner)) return;
              await Navigator.of(context).push<void>(
                MaterialPageRoute(
                  builder: (_) => _AnswerCategoryEditor(
                    category: category,
                    draft: draft,
                    owner: owner,
                  ),
                ),
              );
              if (context.mounted && _editorCurrent(context, owner)) {
                onChanged();
              }
            },
          ),
      ],
    );
  }
}

class _AnswerCategoryEditor extends StatefulWidget {
  const _AnswerCategoryEditor({
    required this.category,
    required this.draft,
    this.owner,
  });

  final OnboardingCategory category;
  final SelahCompatibilityDraft draft;
  final _CompatibilityPreviewOwner? owner;

  @override
  State<_AnswerCategoryEditor> createState() => _AnswerCategoryEditorState();
}

class _AnswerCategoryEditorState extends State<_AnswerCategoryEditor> {
  @override
  Widget build(BuildContext context) {
    final questions = widget.draft.visibleQuestions(widget.category);
    return _EditorScaffold(
      title: widget.category.name,
      owner: widget.owner,
      child: ListView.builder(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 90),
        itemCount: questions.length,
        itemBuilder: (context, index) {
          final question = questions[index];
          return _QuestionDoor(
            key: ValueKey('edit-answer-${question.responseKey}'),
            question: question.prompt,
            value: _answerLabel(
              widget.draft.compatibilityAnswers[question.responseKey],
            ),
            onTap: () async {
              if (!_editorCurrent(context, widget.owner)) return;
              final value = await Navigator.of(context).push<dynamic>(
                MaterialPageRoute(
                  builder: (_) => _AnswerQuestionEditor(
                    question: question,
                    initialValue:
                        widget.draft.compatibilityAnswers[question.responseKey],
                    owner: widget.owner,
                  ),
                ),
              );
              if (value == null ||
                  !mounted ||
                  !context.mounted ||
                  !_editorCurrent(context, widget.owner)) {
                return;
              }
              setState(() => widget.draft.setAnswer(question, value));
            },
          );
        },
      ),
    );
  }
}

class _AnswerQuestionEditor extends StatefulWidget {
  const _AnswerQuestionEditor({
    required this.question,
    required this.initialValue,
    this.owner,
  });

  final OnboardingQuestion question;
  final dynamic initialValue;
  final _CompatibilityPreviewOwner? owner;

  @override
  State<_AnswerQuestionEditor> createState() => _AnswerQuestionEditorState();
}

class _AnswerQuestionEditorState extends State<_AnswerQuestionEditor> {
  late dynamic _value = _copyAnswerValue(widget.initialValue);

  bool get _complete => SelahCompatibilityDraft._hasValue(_value);

  @override
  Widget build(BuildContext context) => _EditorScaffold(
    title: 'Edit answer',
    owner: widget.owner,
    bottom: _BottomSave(
      enabled: _complete,
      onPressed: () {
        if (_editorCurrent(context, widget.owner)) {
          Navigator.of(context).pop(_value);
        }
      },
    ),
    child: ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
      children: [
        Text(widget.question.prompt, style: SelahText.heading(size: 21)),
        const SizedBox(height: 20),
        GenericSelectQuestionScreen(
          key: ValueKey('answer-options-${widget.question.responseKey}'),
          prompt: widget.question.prompt,
          options: widget.question.options,
          selectionType: widget.question.selectionType,
          initialValue: _copyAnswerValue(widget.initialValue),
          onChanged: (value) {
            if (mounted && _editorCurrent(context, widget.owner)) {
              setState(() => _value = _copyAnswerValue(value));
            }
          },
        ),
      ],
    ),
  );
}

class _CategoryDoor extends StatelessWidget {
  const _CategoryDoor({
    super.key,
    required this.label,
    required this.status,
    required this.onTap,
  });

  final String label;
  final String status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 11),
    child: Material(
      color: SelahColors.surfaceFill,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: SelahColors.surfaceBorder),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(15, 14, 12, 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: SelahText.body(size: 14)),
                      const SizedBox(height: 4),
                      Text(status, style: SelahText.subtext(size: 11.5)),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 19,
                  color: SelahColors.ink(0.48),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _QuestionDoor extends StatelessWidget {
  const _QuestionDoor({
    super.key,
    required this.question,
    required this.value,
    required this.onTap,
  });

  final String question;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Material(
      color: SelahColors.surfaceFill,
      borderRadius: BorderRadius.circular(15),
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: SelahColors.surfaceBorder),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(15),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(question, style: SelahText.body(size: 13.5)),
                      const SizedBox(height: 6),
                      Text(
                        value,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: SelahText.subtext(
                          size: 11.5,
                          color: value == 'Not answered'
                              ? SelahColors.negativeRed
                              : SelahColors.ink(0.58),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: SelahColors.ink(0.44),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _EditorScaffold extends StatelessWidget {
  const _EditorScaffold({
    required this.title,
    required this.child,
    this.bottom,
    this.owner,
  });

  final String title;
  final Widget child;
  final Widget? bottom;
  final _CompatibilityPreviewOwner? owner;

  @override
  Widget build(BuildContext context) {
    if (owner != null && !owner!.alive) {
      return const SizedBox.shrink(
        key: ValueKey('compatibility_editor_preview_denied'),
      );
    }
    final preview = owner != null;
    final content = Stack(
      children: [
        Positioned.fill(child: child),
        if (bottom != null)
          Positioned(left: 0, right: 0, bottom: 0, child: bottom!),
      ],
    );
    final page = Scaffold(
      backgroundColor: Colors.transparent,
      appBar: preview
          ? null
          : AppBar(
              title: Text(title, style: SelahText.heading(size: 17)),
              iconTheme: IconThemeData(color: SelahColors.ink(0.70)),
            ),
      body: Container(
        decoration: preview
            ? BoxDecoration(gradient: SelahColors.genderGradient(owner!.gender))
            : SelahAppGoldDecoration(
                gradient: SelahColors.genderGradient(AppState.instance.gender),
              ),
        child: SafeArea(
          top: preview,
          child: preview
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                      child: Text(title, style: SelahText.heading(size: 28)),
                    ),
                    Expanded(child: content),
                  ],
                )
              : content,
        ),
      ),
    );
    if (!preview) return page;
    return SelahPullDownBackScope(
      routeIdentity: (ModalRoute.of(context), owner),
      onBack: () {
        if (_editorCurrent(context, owner) && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      },
      enabled: owner!.alive,
      child: page,
    );
  }
}

class _BottomSave extends StatelessWidget {
  const _BottomSave({required this.enabled, required this.onPressed});

  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          SelahColors.luxuryDarkPurple.withValues(alpha: 0),
          SelahColors.luxuryDarkPurple.withValues(alpha: 0.94),
        ],
      ),
    ),
    child: SizedBox(
      width: double.infinity,
      child: FilledButton(
        key: const ValueKey('question-save'),
        onPressed: enabled ? onPressed : null,
        child: const Text('Use this answer'),
      ),
    ),
  );
}

String _answerLabel(dynamic value) {
  if (value is List) return value.isEmpty ? 'Not answered' : value.join(', ');
  if (value == null || value.toString().trim().isEmpty) return 'Not answered';
  return value.toString();
}
