import '../models/onboarding_question.dart';
import 'chapter3_categories.dart';

/// LOCK 17: the seven Your values parts and Location & Language.
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
        category.questions.map((question) => question.id),
      ).toList(growable: false),
    );

final List<CompatibilityCategoryDefinition> compatibilityCategories = [
  for (final category in chapter3CompatibilityCategories) _fromValues(category),
  const CompatibilityCategoryDefinition(
    id: 'culture_location',
    name: 'Location & Language',
    chapter2Keys: ['location', 'languages'],
  ),
];
