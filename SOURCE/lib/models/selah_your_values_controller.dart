import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/chapter3_categories.dart';
import '../services/selah_developer_access.dart';
import 'onboarding_question.dart';
import 'selah_your_values.dart';

enum SelahYourValuesSaveState { idle, saving, failed, saved }

/// A transient editor over the caller's existing compatibility owner. Reads
/// happen only after admission; the caller captures its exact owner lifetime.
class SelahYourValuesController extends ChangeNotifier {
  SelahYourValuesController({
    required this.canAct,
    required this.gender,
    required this.readAnswers,
    required this.readSignUpPreferences,
    required this.onSavePart,
    required this.readHardRequirements,
    required this.onSaveDealbreakers,
    this.readDealbreakersSaved,
  });

  final bool Function() canAct;
  final String gender;
  final Map<String, dynamic> Function() readAnswers;
  final Map<String, dynamic> Function() readSignUpPreferences;
  final FutureOr<bool> Function(String, Map<String, dynamic>) onSavePart;
  final Map<String, Set<String>> Function() readHardRequirements;
  final FutureOr<bool> Function(Map<String, Set<String>>) onSaveDealbreakers;
  final bool Function()? readDealbreakersSaved;
  bool _closed = false;
  bool _disposed = false;
  bool _loaded = false;
  bool _dispatching = false;
  Map<String, dynamic> _draft = {};
  Map<String, dynamic> _saved = {};
  Set<int> _dealbreakers = {};
  bool _dealbreakersDone = false;
  String? _errorQuestion;
  String? _savingPartId;
  SelahYourValuesSaveState _saveState = SelahYourValuesSaveState.idle;

  bool get current {
    if (_closed || _disposed) return false;
    try {
      if (canAct() && (gender == 'male' || gender == 'female')) return true;
    } catch (_) {
      // Failed ownership is terminal, never a live/account fallback.
    }
    _closed = true;
    return false;
  }

  bool _load() {
    if (!current) return false;
    if (_loaded) return true;
    try {
      final answers = _copy(readAnswers());
      final choices = selahDealbreakerChoicesFrom(readHardRequirements());
      final dealbreakersSaved = readDealbreakersSaved?.call() ?? false;
      if (!current) return false;
      _saved = answers;
      _draft = _copy(answers);
      _dealbreakers = Set.of(choices);
      _dealbreakersDone = dealbreakersSaved;
      _loaded = true;
      return true;
    } catch (_) {
      _closed = true;
      return false;
    }
  }

  Map<String, dynamic>? _signUp() {
    if (!current) return null;
    try {
      final preferences = readSignUpPreferences();
      return current ? preferences : null;
    } catch (_) {
      _closed = true;
      return null;
    }
  }

  List<OnboardingCategory> get parts =>
      current ? List.unmodifiable(chapter3Categories) : const [];
  List<OnboardingQuestion> questionsFor(String partId) {
    if (!_load()) return const [];
    final preferences = _signUp();
    final part = chapter3Categories
        .where((part) => part.id == partId)
        .firstOrNull;
    if (part == null || preferences == null) return const [];
    return selahYourValuesQuestionsFor(part, gender, _draft, preferences);
  }

  dynamic answerFor(OnboardingQuestion question) =>
      _load() ? _freeze(_draft[question.responseKey]) : null;
  bool isSelected(OnboardingQuestion question, String option) {
    final answer = answerFor(question);
    return answer is List ? answer.contains(option) : answer == option;
  }

  bool isPartDone(String partId) {
    if (!_load()) return false;
    final preferences = _signUp();
    final part = chapter3Categories
        .where((part) => part.id == partId)
        .firstOrNull;
    return part != null &&
        preferences != null &&
        selahYourValuesPartComplete(part, gender, _saved, preferences);
  }

  bool get allPartsDone =>
      _load() && chapter3Categories.every((part) => isPartDone(part.id));
  int get questionsRemaining => !_load()
      ? 0
      : chapter3Categories
            .where((part) => !isPartDone(part.id))
            .fold(0, (total, part) => total + questionsFor(part.id).length);
  bool get dealbreakersDone => _load() && _dealbreakersDone;
  Set<int> get selectedDealbreakers =>
      _load() ? Set.unmodifiable(_dealbreakers) : const {};
  SelahYourValuesSaveState get saveState =>
      current ? _saveState : SelahYourValuesSaveState.idle;
  String? get savingPartId => current ? _savingPartId : null;
  bool get showRequiredError => current && _errorQuestion != null;
  bool get showDealbreakerFailure =>
      current &&
      _savingPartId == 'dealbreakers' &&
      _saveState == SelahYourValuesSaveState.failed;

  bool _ownsQuestion(OnboardingQuestion question) => chapter3Categories.any(
    (part) => questionsFor(
      part.id,
    ).any((candidate) => identical(candidate, question)),
  );
  bool get _editable =>
      _load() && !_dispatching && _saveState != SelahYourValuesSaveState.saving;
  void choose(OnboardingQuestion question, int optionIndex) {
    if (!_editable ||
        !_ownsQuestion(question) ||
        optionIndex < 0 ||
        optionIndex >= question.options.length) {
      return;
    }
    final option = question.options[optionIndex];
    if (question.selectionType == QuestionSelectionType.multi) {
      final values = _draft[question.responseKey] is List
          ? List<String>.of(
              (_draft[question.responseKey] as List).cast<String>(),
            )
          : <String>[];
      values.contains(option) ? values.remove(option) : values.add(option);
      _draft[question.responseKey] = values;
    } else {
      _draft[question.responseKey] = option;
    }
    _errorQuestion = null;
    _saveState = SelahYourValuesSaveState.idle;
    _changed();
  }

  void skip(OnboardingQuestion question) {
    if (!_editable ||
        !_ownsQuestion(question) ||
        !question.selfAnswerOptional) {
      return;
    }
    _draft.remove(question.responseKey);
    _errorQuestion = null;
    _changed();
  }

  bool validate(OnboardingQuestion question) {
    if (!_editable || !_ownsQuestion(question)) return false;
    final valid =
        question.selfAnswerOptional ||
        selahYourValuesAnswerValid(question, _draft[question.responseKey]);
    _errorQuestion = valid ? null : question.responseKey;
    _changed();
    return valid;
  }

  Future<bool> savePart(String partId) async {
    if (!_editable) return false;
    final questions = questionsFor(partId);
    if (questions.isEmpty) return false;
    for (final question in questions) {
      if (!validate(question)) return false;
    }
    final patch = <String, dynamic>{
      for (final question in questions)
        question.responseKey: _freeze(_draft[question.responseKey]),
    };
    return _save(partId, () => onSavePart(partId, Map.unmodifiable(patch)), () {
      for (final entry in patch.entries) {
        entry.value == null
            ? _saved.remove(entry.key)
            : _saved[entry.key] = _freeze(entry.value);
      }
    });
  }

  void toggleDealbreaker(int index) {
    if (!_editable ||
        !allPartsDone ||
        index < 0 ||
        index >= selahDealbreakerLabels.length) {
      return;
    }
    if (index == 5) {
      _dealbreakers = _dealbreakers.contains(5) ? {} : {5};
    } else {
      _dealbreakers.remove(5);
      _dealbreakers.contains(index)
          ? _dealbreakers.remove(index)
          : _dealbreakers.add(index);
    }
    _saveState = SelahYourValuesSaveState.idle;
    _changed();
  }

  Future<bool> saveDealbreakers() async {
    if (!_editable || !allPartsDone) return false;
    final requirements = selahDealbreakersFor(_dealbreakers);
    return _save(
      'dealbreakers',
      () => onSaveDealbreakers(requirements),
      () => _dealbreakersDone = true,
    );
  }

  Future<bool> _save(
    String partId,
    FutureOr<bool> Function() write,
    VoidCallback committed,
  ) async {
    if (!current || _dispatching) return false;
    _dispatching = true;
    _savingPartId = partId;
    _saveState = SelahYourValuesSaveState.saving;
    _changed();
    bool saved = false;
    try {
      if (current) saved = await write();
    } catch (_) {
      saved = false;
    } finally {
      _dispatching = false;
    }
    if (!current) return false;
    if (saved) committed();
    _saveState = saved
        ? SelahYourValuesSaveState.saved
        : SelahYourValuesSaveState.failed;
    _changed();
    return saved;
  }

  void showSaving({String? partId}) =>
      _preset(SelahYourValuesSaveState.saving, partId);
  void showFailure({String? partId}) =>
      _preset(SelahYourValuesSaveState.failed, partId);
  void _preset(SelahYourValuesSaveState state, String? partId) {
    if (!_load() ||
        _dispatching ||
        !SelahDeveloperAccess.canUseDeveloperTools) {
      return;
    }
    final target = partId ?? _savingPartId ?? chapter3Categories.first.id;
    if (target == 'dealbreakers'
        ? !allPartsDone
        : !chapter3Categories.any((part) => part.id == target)) {
      return;
    }
    _savingPartId = target;
    _saveState = state;
    _changed();
  }

  void _changed() {
    if (current) notifyListeners();
  }

  static Map<String, dynamic> _copy(Map<String, dynamic> value) => {
    for (final entry in value.entries) entry.key: _freeze(entry.value),
  };
  static dynamic _freeze(dynamic value) => value is List
      ? List.unmodifiable(value.map(_freeze))
      : value is Map
      ? Map.unmodifiable(
          value.map((key, value) => MapEntry(key, _freeze(value))),
        )
      : value;
  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    super.dispose();
  }
}
