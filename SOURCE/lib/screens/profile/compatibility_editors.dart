import 'package:flutter/material.dart';
import '../../widgets/selah_loading.dart';
import '../../dev/selah_app_gold_preview.dart';

import '../../data/chapter3_categories.dart';
import '../../models/onboarding_question.dart';
import '../../models/journey_bio.dart';
import '../../services/selah_onboarding_answers_service.dart';
import '../../state/app_state.dart';
import '../../theme/selah_colors.dart';
import '../../theme/selah_text.dart';
import '../../widgets/selah_pull_down_back_scope.dart';
import '../onboarding/generic_select_question_screen.dart';
import '../onboarding/traffic_light_question_screen.dart';

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
    CompatibilityEditorKind.aboutYou => const [
      'faith_practice',
      'personality_connection',
    ],
    CompatibilityEditorKind.lifestyle => const [
      'finances_provision',
      'education_career',
      'lifestyle_wellbeing',
      'digital_boundaries',
    ],
    CompatibilityEditorKind.marriagePreferences => const [
      'marriage_intentions',
      'children_parenting',
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
  });

  factory SelahCompatibilityDraft.fromSnapshot({
    required String? gender,
    SelahOnboardingAnswersSnapshot? snapshot,
  }) {
    final answers = <String, dynamic>{};
    final preferences = <String, Map<String, TrafficLight>>{};
    final hard = <String, Set<String>>{};
    final rawAnswers = <String, dynamic>{
      ...?snapshot?.journeyBio.toOnboardingAnswers(),
      ...?snapshot?.ch3Answers,
    };

    for (final entry in rawAnswers.entries) {
      if (entry.key.startsWith('bio_')) {
        answers[entry.key] = _copyAnswerValue(entry.value);
      }
    }
    for (final category in chapter3Categories) {
      for (final question in category.questions) {
        if (!question.visibleFor(gender)) continue;
        final persisted = SelahOnboardingAnswersService.persistedQuestionId(
          question.responseKey,
        );
        if (rawAnswers.containsKey(persisted)) {
          answers[question.responseKey] = _copyAnswerValue(
            rawAnswers[persisted],
          );
        }
        final savedPreferences = snapshot?.ch4Preferences[persisted];
        if (savedPreferences != null) {
          preferences[question.responseKey] = Map<String, TrafficLight>.from(
            savedPreferences,
          );
        }
        final savedHard = snapshot?.ch4HardRequirements[persisted];
        if (savedHard != null) {
          hard[question.responseKey] = Set<String>.from(savedHard);
        }
      }
    }

    final draft = SelahCompatibilityDraft(
      gender: gender,
      answers: answers,
      preferences: preferences,
      hardRequirements: hard,
    );
    draft.pruneHiddenAnswers();
    return draft;
  }

  final String? gender;
  final Map<String, dynamic> answers;
  final Map<String, Map<String, TrafficLight>> preferences;
  final Map<String, Set<String>> hardRequirements;

  SelahCompatibilityDraft copy() => SelahCompatibilityDraft(
    gender: gender,
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
    for (final category in chapter3Categories) {
      for (final question in category.questions) {
        if (answers.containsKey(question.responseKey)) {
          result[question.id] = answers[question.responseKey];
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
    answers[question.responseKey] = value;
    pruneHiddenAnswers();
  }

  void pruneHiddenAnswers() {
    final visibleKeys = <String>{
      for (final category in chapter3Categories)
        for (final question in visibleQuestions(category)) question.responseKey,
    };
    answers.removeWhere(
      (key, _) => !key.startsWith('bio_') && !visibleKeys.contains(key),
    );
    preferences.removeWhere((key, _) => !visibleKeys.contains(key));
    hardRequirements.removeWhere((key, _) => !visibleKeys.contains(key));
  }

  int answeredIn(Iterable<OnboardingCategory> categories) => categories
      .expand(visibleQuestions)
      .where((question) => _hasValue(answers[question.responseKey]))
      .length;

  int questionsIn(Iterable<OnboardingCategory> categories) =>
      categories.expand(visibleQuestions).length;

  int get preferenceAnswerCount =>
      preferences.values.fold<int>(0, (total, values) => total + values.length);

  int get preferenceOptionCount => chapter3Categories
      .expand(preferenceQuestions)
      .fold<int>(0, (total, question) => total + question.options.length);

  int get hardRequirementCount => hardRequirements.values.fold<int>(
    0,
    (total, values) => total + values.length,
  );

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
  bool get _current =>
      mounted && _editorCurrent(context, _owner, editing: false);

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
              CompatibilityEditorKind.trafficLights => _PreferenceGroups(
                draft: _draft,
                owner: _owner,
                onChanged: () {
                  if (mounted && _editorCurrent(context, _owner)) {
                    setState(() {});
                  }
                },
              ),
              CompatibilityEditorKind.hardRequirements =>
                _HardRequirementsEditor(
                  draft: _draft,
                  owner: _owner,
                  onChanged: () {
                    if (mounted && _editorCurrent(context, _owner)) {
                      setState(() {});
                    }
                  },
                ),
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
            value: _answerLabel(widget.draft.answers[question.responseKey]),
            onTap: () async {
              if (!_editorCurrent(context, widget.owner)) return;
              final value = await Navigator.of(context).push<dynamic>(
                MaterialPageRoute(
                  builder: (_) => _AnswerQuestionEditor(
                    question: question,
                    initialValue: widget.draft.answers[question.responseKey],
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

class _PreferenceGroups extends StatelessWidget {
  const _PreferenceGroups({
    required this.draft,
    required this.onChanged,
    this.owner,
  });

  final SelahCompatibilityDraft draft;
  final VoidCallback onChanged;
  final _CompatibilityPreviewOwner? owner;

  @override
  Widget build(BuildContext context) => ListView(
    physics: const BouncingScrollPhysics(),
    padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
    children: [
      _MeaningCard(),
      const SizedBox(height: 14),
      for (final category in chapter3Categories)
        if (draft.preferenceQuestions(category).isNotEmpty)
          _CategoryDoor(
            key: ValueKey('edit-preferences-${category.id}'),
            label: category.name,
            status: _preferenceCategoryStatus(draft, category),
            onTap: () async {
              if (!_editorCurrent(context, owner)) return;
              await Navigator.of(context).push<void>(
                MaterialPageRoute(
                  builder: (_) => _PreferenceCategoryEditor(
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

class _PreferenceCategoryEditor extends StatefulWidget {
  const _PreferenceCategoryEditor({
    required this.category,
    required this.draft,
    this.owner,
  });

  final OnboardingCategory category;
  final SelahCompatibilityDraft draft;
  final _CompatibilityPreviewOwner? owner;

  @override
  State<_PreferenceCategoryEditor> createState() =>
      _PreferenceCategoryEditorState();
}

class _PreferenceCategoryEditorState extends State<_PreferenceCategoryEditor> {
  @override
  Widget build(BuildContext context) {
    final questions = widget.draft.preferenceQuestions(widget.category);
    return _EditorScaffold(
      title: widget.category.name,
      owner: widget.owner,
      child: ListView.builder(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 90),
        itemCount: questions.length,
        itemBuilder: (context, index) {
          final question = questions[index];
          final values = widget.draft.preferences[question.responseKey];
          return _QuestionDoor(
            key: ValueKey('edit-lights-${question.responseKey}'),
            question: question.prompt,
            value: values == null
                ? 'Not set'
                : '${values.length} of ${question.options.length} set',
            onTap: () async {
              if (!_editorCurrent(context, widget.owner)) return;
              final result = await Navigator.of(context)
                  .push<_PreferenceEditResult>(
                    MaterialPageRoute(
                      builder: (_) => _PreferenceQuestionEditor(
                        question: question,
                        yourAnswers: _asStringSet(
                          widget.draft.answers[question.responseKey],
                        ),
                        initialValues: values ?? const {},
                        initialHard:
                            widget.draft.hardRequirements[question
                                .responseKey] ??
                            const {},
                        owner: widget.owner,
                      ),
                    ),
                  );
              if (result == null ||
                  !mounted ||
                  !context.mounted ||
                  !_editorCurrent(context, widget.owner)) {
                return;
              }
              setState(() {
                widget.draft.preferences[question.responseKey] = result.values;
                if (result.hard.isEmpty) {
                  widget.draft.hardRequirements.remove(question.responseKey);
                } else {
                  widget.draft.hardRequirements[question.responseKey] =
                      result.hard;
                }
              });
            },
          );
        },
      ),
    );
  }
}

class _PreferenceEditResult {
  const _PreferenceEditResult(this.values, this.hard);

  final Map<String, TrafficLight> values;
  final Set<String> hard;
}

class _PreferenceQuestionEditor extends StatefulWidget {
  const _PreferenceQuestionEditor({
    required this.question,
    required this.yourAnswers,
    required this.initialValues,
    required this.initialHard,
    this.owner,
  });

  final OnboardingQuestion question;
  final Set<String> yourAnswers;
  final Map<String, TrafficLight> initialValues;
  final Set<String> initialHard;
  final _CompatibilityPreviewOwner? owner;

  @override
  State<_PreferenceQuestionEditor> createState() =>
      _PreferenceQuestionEditorState();
}

class _PreferenceQuestionEditorState extends State<_PreferenceQuestionEditor> {
  late Map<String, TrafficLight> _values = Map.from(widget.initialValues);
  late Set<String> _hard = Set.from(widget.initialHard);

  bool get _complete => widget.question.options.every(_values.containsKey);

  @override
  Widget build(BuildContext context) => _EditorScaffold(
    title: 'Partner preference',
    owner: widget.owner,
    bottom: _BottomSave(
      enabled: _complete,
      onPressed: () {
        if (_editorCurrent(context, widget.owner)) {
          Navigator.of(
            context,
          ).pop(_PreferenceEditResult(Map.from(_values), Set.from(_hard)));
        }
      },
    ),
    child: ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
      children: [
        Text(widget.question.prompt, style: SelahText.heading(size: 21)),
        const SizedBox(height: 20),
        TrafficLightQuestionScreen(
          key: ValueKey('edit-preference-${widget.question.responseKey}'),
          yourAnswer: '',
          yourAnswers: widget.yourAnswers,
          options: widget.question.options,
          hardRequirementSupported: widget.question.hardRequirementSupported,
          initialValues: widget.initialValues,
          initialHardRequirement: widget.initialHard,
          onChanged: (values) {
            if (mounted && _editorCurrent(context, widget.owner)) {
              setState(() => _values = Map.from(values));
            }
          },
          onHardRequirementChanged: (values) {
            if (mounted && _editorCurrent(context, widget.owner)) {
              setState(() => _hard = Set.from(values));
            }
          },
        ),
      ],
    ),
  );
}

class _HardRequirementsEditor extends StatelessWidget {
  const _HardRequirementsEditor({
    required this.draft,
    required this.onChanged,
    this.owner,
  });

  final SelahCompatibilityDraft draft;
  final VoidCallback onChanged;
  final _CompatibilityPreviewOwner? owner;

  @override
  Widget build(BuildContext context) {
    final eligible = <(OnboardingCategory, OnboardingQuestion, List<String>)>[];
    for (final category in chapter3Categories) {
      for (final question in draft.preferenceQuestions(category)) {
        if (!question.hardRequirementSupported) continue;
        final reds = question.options
            .where(
              (option) =>
                  draft.preferences[question.responseKey]?[option] ==
                  TrafficLight.red,
            )
            .toList(growable: false);
        if (reds.isNotEmpty) eligible.add((category, question, reds));
      }
    }

    if (eligible.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(34),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.gpp_good_outlined,
                size: 30,
                color: SelahColors.ink(0.42),
              ),
              const SizedBox(height: 14),
              Text('No hard requirements', style: SelahText.heading(size: 18)),
              const SizedBox(height: 8),
              Text(
                'First mark an answer red in Green / Yellow / Red. You can then decide here whether it must block an introduction.',
                textAlign: TextAlign.center,
                style: SelahText.subtext(size: 12.5),
              ),
            ],
          ),
        ),
      );
    }

    final children = <Widget>[];
    String? previousCategory;
    for (final item in eligible) {
      if (previousCategory != item.$1.id) {
        if (previousCategory != null) children.add(const SizedBox(height: 18));
        children
          ..add(
            Text(
              item.$1.name.toUpperCase(),
              style: SelahText.chapterLabel(color: SelahColors.ink(0.54)),
            ),
          )
          ..add(const SizedBox(height: 10));
        previousCategory = item.$1.id;
      }
      final question = item.$2;
      final selected =
          draft.hardRequirements[question.responseKey] ?? const <String>{};
      children
        ..add(
          _HardQuestionCard(
            question: question,
            redOptions: item.$3,
            selected: selected,
            onToggle: (option) {
              if (!_editorCurrent(context, owner)) return;
              final next = Set<String>.from(selected);
              if (!next.remove(option)) next.add(option);
              if (next.isEmpty) {
                draft.hardRequirements.remove(question.responseKey);
              } else {
                draft.hardRequirements[question.responseKey] = next;
              }
              onChanged();
            },
          ),
        )
        ..add(const SizedBox(height: 12));
    }
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      children: children,
    );
  }
}

class _HardQuestionCard extends StatelessWidget {
  const _HardQuestionCard({
    required this.question,
    required this.redOptions,
    required this.selected,
    required this.onToggle,
  });

  final OnboardingQuestion question;
  final List<String> redOptions;
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: SelahColors.surfaceFill,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: SelahColors.surfaceBorder),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(question.prompt, style: SelahText.body(size: 13.5)),
        const SizedBox(height: 12),
        for (final option in redOptions)
          InkWell(
            key: ValueKey('hard-option-${question.responseKey}-$option'),
            onTap: () => onToggle(option),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 9),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    selected.contains(option)
                        ? Icons.check_box_rounded
                        : Icons.check_box_outline_blank_rounded,
                    size: 19,
                    color: selected.contains(option)
                        ? SelahColors.negativeRed
                        : SelahColors.ink(0.50),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(option, style: SelahText.subtext(size: 12.5)),
                  ),
                ],
              ),
            ),
          ),
      ],
    ),
  );
}

class _MeaningCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: SelahColors.surfaceFill,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: SelahColors.surfaceBorder),
    ),
    child: const Row(
      children: [
        Expanded(
          child: _LightMeaning(
            color: SelahColors.positiveGreen,
            label: 'Prefer',
          ),
        ),
        Expanded(
          child: _LightMeaning(
            color: SelahColors.journeyGold,
            label: 'Neutral',
          ),
        ),
        Expanded(
          child: _LightMeaning(
            color: SelahColors.negativeRed,
            label: 'Not for me',
          ),
        ),
      ],
    ),
  );
}

class _LightMeaning extends StatelessWidget {
  const _LightMeaning({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(height: 6),
      Text(label, style: SelahText.subtext(size: 10.5)),
    ],
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

Set<String> _asStringSet(dynamic value) {
  if (value is List) return value.map((item) => item.toString()).toSet();
  if (value == null) return const {};
  return {value.toString()};
}

String _preferenceCategoryStatus(
  SelahCompatibilityDraft draft,
  OnboardingCategory category,
) {
  final questions = draft.preferenceQuestions(category);
  final total = questions.fold<int>(
    0,
    (count, question) => count + question.options.length,
  );
  final answered = questions.fold<int>(
    0,
    (count, question) =>
        count + (draft.preferences[question.responseKey]?.length ?? 0),
  );
  return '$answered of $total preferences set';
}
