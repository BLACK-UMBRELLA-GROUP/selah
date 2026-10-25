import '../models/onboarding_question.dart';
import 'chapter3_categories.dart';

/// The twelve categories the compatibility reveal will eventually calculate.
///
/// Eleven come from the private Values/Preferences bank. Culture, Language &
/// Location comes from Chapter 2's structured profile preferences, so those
/// questions are not duplicated in Your Values merely to create another bar.
class CompatibilityCategoryDefinition {
  final String id;
  final String name;
  final List<String> questionIds;
  final List<String> chapter2Keys;

  const CompatibilityCategoryDefinition({
    required this.id,
    required this.name,
    this.questionIds = const [],
    this.chapter2Keys = const [],
  });

  bool get comesFromProfile => chapter2Keys.isNotEmpty;
}

CompatibilityCategoryDefinition _fromValues(OnboardingCategory category) =>
    CompatibilityCategoryDefinition(
      id: category.id,
      name: category.name,
      questionIds: Set<String>.unmodifiable(
        category.questions
            .where((question) => question.ch4Status != Ch4Status.none)
            .map((question) => question.id),
      ).toList(growable: false),
    );

final List<CompatibilityCategoryDefinition> compatibilityCategories = [
  for (final category in chapter3Categories.take(10)) _fromValues(category),
  const CompatibilityCategoryDefinition(
    id: 'culture_location',
    name: 'Culture, Language & Location',
    chapter2Keys: [
      'location',
      'sect',
      'revert',
      'country_of_birth',
      'nationality',
      'ethnicity',
      'languages',
    ],
  ),
  _fromValues(chapter3Categories.last),
];
