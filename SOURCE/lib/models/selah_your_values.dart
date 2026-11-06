import '../data/chapter3_categories.dart';
import 'onboarding_question.dart';
import 'selah_sign_up_compatibility.dart';

/// LOCK 17 question identities, independent of the retired source bank.
const selahYourValuesQuestionIds = <String>{
  'ch3_q33',
  'ch3_q34',
  'ch3_q44',
  'ch3_q51',
  'ch3_q38',
  'ch3_q25',
  'ch3_q26',
  'ch3_q32',
  'ch3_q24',
  'ch3_q4',
  'ch3_q6',
  'ch3_q8',
  'ch3_q48',
  'ch3_q47',
  'ch3_q67',
  'ch3_q68',
  'ch3_q13',
  'ch3_q64',
  'ch3_q18',
  'ch3_q73',
  'ch3_q75',
  'ch3_q76',
  'ch3_q83',
  'ch3_q81',
  'ch3_q52',
  'ch3_q53',
  'ch3_q84',
};

const selahDealbreakerLabels = <String>[
  'Smokes or vapes',
  'Drinks alcohol',
  'Doesn’t want children',
  'Already has children',
  'Wants to move abroad after marriage',
  'None of these',
];

/// These are existing hard-requirement keys and exact answer vocabularies.
/// The display choices do not add scoring or matching authority.
const selahDealbreakerRequirements = <String, Set<String>>{
  'ch3_q52': {'I vape only', 'I smoke only', 'I both smoke and vape'},
  'ch3_q53': {'I drink occasionally', 'I drink socially in moderation'},
  'ch3_q3': {'No'},
  'ch3_q2': {'Yes, living with me', 'Yes, living elsewhere'},
  'ch3_q28': {'Internationally'},
};

List<OnboardingQuestion> selahYourValuesQuestionsFor(
  OnboardingCategory part,
  String gender,
  Map<String, dynamic> rawAnswers,
  Map<String, dynamic> signUpPreferences,
) {
  final effective = SelahSignUpCompatibility.fromPreferences(
    signUpPreferences,
  ).answersOver(rawAnswers);
  return List.unmodifiable(
    part.questions.where((question) {
      return question.visibleGiven(gender, effective);
    }),
  );
}

bool selahYourValuesAnswerValid(OnboardingQuestion question, dynamic answer) {
  if (question.selectionType == QuestionSelectionType.multi) {
    return answer is List &&
        answer.isNotEmpty &&
        answer.every(
          (value) => value is String && question.options.contains(value),
        );
  }
  return answer is String && question.options.contains(answer);
}

bool selahYourValuesPartComplete(
  OnboardingCategory part,
  String gender,
  Map<String, dynamic> answers,
  Map<String, dynamic> signUpPreferences,
) => selahYourValuesQuestionsFor(part, gender, answers, signUpPreferences)
    .where((question) => !question.selfAnswerOptional)
    .every(
      (question) =>
          selahYourValuesAnswerValid(question, answers[question.responseKey]),
    );

Map<String, Set<String>> selahDealbreakersFor(Iterable<int> choices) {
  final selected = choices.toSet();
  if (selected.contains(5)) return const {};
  final entries = selahDealbreakerRequirements.entries.toList(growable: false);
  return Map.unmodifiable({
    for (var index = 0; index < entries.length; index++)
      if (selected.contains(index))
        entries[index].key: Set<String>.unmodifiable(entries[index].value),
  });
}

Set<int> selahDealbreakerChoicesFrom(Map<String, Set<String>> saved) {
  final entries = selahDealbreakerRequirements.entries.toList(growable: false);
  return Set.unmodifiable({
    for (var index = 0; index < entries.length; index++)
      if (saved[entries[index].key]?.containsAll(entries[index].value) ?? false)
        index,
  });
}

/// A part save patches only its visible questions. Null means an explicitly
/// skipped optional answer. Unasked, hidden and unrelated raw keys survive.
Map<String, dynamic>? selahMergeYourValuesPart({
  required Map<String, dynamic> existing,
  required String gender,
  required String partId,
  required Map<String, dynamic> answers,
  required Map<String, dynamic> signUpPreferences,
}) {
  final part = chapter3Categories
      .where((part) => part.id == partId)
      .firstOrNull;
  if (part == null || (gender != 'male' && gender != 'female')) return null;
  final visible = selahYourValuesQuestionsFor(
    part,
    gender,
    existing,
    signUpPreferences,
  );
  final byKey = {
    for (final question in visible) question.responseKey: question,
  };
  if (answers.keys.any((key) => !byKey.containsKey(key))) return null;
  final result = Map<String, dynamic>.of(existing);
  for (final entry in answers.entries) {
    final question = byKey[entry.key]!;
    if (entry.value == null && question.selfAnswerOptional) {
      result.remove(entry.key);
    } else if (selahYourValuesAnswerValid(question, entry.value)) {
      result[entry.key] = entry.value is List
          ? List<String>.of((entry.value as List).cast<String>())
          : entry.value;
    } else {
      return null;
    }
  }
  if (!selahYourValuesPartComplete(part, gender, result, signUpPreferences)) {
    return null;
  }
  return result;
}

Map<String, Set<String>>? selahMergeDealbreakers({
  required Map<String, Set<String>> existing,
  required Map<String, Set<String>> requirements,
}) {
  if (requirements.entries.any((entry) {
    final allowed = selahDealbreakerRequirements[entry.key];
    return allowed == null ||
        entry.value.length != allowed.length ||
        !entry.value.containsAll(allowed);
  })) {
    return null;
  }
  return {
    for (final entry in existing.entries)
      if (!selahDealbreakerRequirements.containsKey(entry.key))
        entry.key: Set.of(entry.value),
    for (final entry in requirements.entries) entry.key: Set.of(entry.value),
  };
}
