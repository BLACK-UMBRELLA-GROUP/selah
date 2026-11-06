import '../data/journey_questions.dart';

/// Exact new Family answers only. Retired IDs are neither migrated nor used
/// to infer completion; reading this value never changes their saved rows.
class SelahFamilyAnswers {
  SelahFamilyAnswers.fromMap(Map<dynamic, dynamic> source)
    : values = Map<String, String>.unmodifiable({
        for (final question in JourneyQuestions.family)
          if (source[question.id] case final String answer) question.id: answer,
      });

  final Map<String, String> values;
  String answerFor(String questionId) => values[questionId] ?? '';
  int get answeredCount => JourneyQuestions.family.where((question) {
    final answer = answerFor(question.id);
    return answer.trim().isNotEmpty &&
        JourneyQuestions.familyAnswerFitsCharacterLimit(answer);
  }).length;
  bool get canSend => answeredCount == JourneyQuestions.family.length;

  bool matches(Map<String, String> other) =>
      values.length == other.length &&
      values.entries.every((entry) => other[entry.key] == entry.value);
}
