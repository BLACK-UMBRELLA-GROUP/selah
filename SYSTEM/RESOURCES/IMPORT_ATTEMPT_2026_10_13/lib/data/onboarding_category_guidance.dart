/// Concise, user-facing orientation for each private compatibility section.
///
/// Question IDs and scoring stay in [chapter3_categories.dart]. Keeping the
/// transition copy separate means presentation can improve without creating a
/// second question bank or changing the server-owned answer contract.
class OnboardingCategoryGuidance {
  final String categoryId;
  final String description;

  const OnboardingCategoryGuidance({
    required this.categoryId,
    required this.description,
  });
}

const onboardingCategoryGuidance = <OnboardingCategoryGuidance>[
  OnboardingCategoryGuidance(
    categoryId: 'faith_practice',
    description:
        'Your worship, Christian practice and the place Faith holds in daily life.',
  ),
  OnboardingCategoryGuidance(
    categoryId: 'marriage_intentions',
    description:
        'The marriage you are seeking, its structure and the future you intend to build.',
  ),
  OnboardingCategoryGuidance(
    categoryId: 'children_parenting',
    description:
        'Your hopes for children, parenting and the family life you imagine.',
  ),
  OnboardingCategoryGuidance(
    categoryId: 'family_in_laws',
    description:
        'Family involvement, responsibilities, living arrangements and healthy boundaries.',
  ),
  OnboardingCategoryGuidance(
    categoryId: 'finances_provision',
    description:
        'Financial habits, responsibilities, provision and the expectations you bring to marriage.',
  ),
  OnboardingCategoryGuidance(
    categoryId: 'education_career',
    description:
        'Education, work, ambition and how career may fit around married life.',
  ),
  OnboardingCategoryGuidance(
    categoryId: 'home_roles',
    description:
        'Daily responsibilities, household roles and the way you hope to share a home.',
  ),
  OnboardingCategoryGuidance(
    categoryId: 'communication_conflict',
    description:
        'How you communicate, handle disagreement, repair hurt and feel understood.',
  ),
  OnboardingCategoryGuidance(
    categoryId: 'personality_connection',
    description:
        'Personality, emotional connection and the kind of companionship that suits you.',
  ),
  OnboardingCategoryGuidance(
    categoryId: 'lifestyle_wellbeing',
    description:
        'Everyday routines, social life, health, wellbeing and how you spend your time.',
  ),
  OnboardingCategoryGuidance(
    categoryId: 'digital_boundaries',
    description:
        'Technology, privacy, online habits and the digital boundaries you value.',
  ),
];

OnboardingCategoryGuidance guidanceForOnboardingCategory(String categoryId) =>
    onboardingCategoryGuidance.firstWhere(
      (guidance) => guidance.categoryId == categoryId,
    );
