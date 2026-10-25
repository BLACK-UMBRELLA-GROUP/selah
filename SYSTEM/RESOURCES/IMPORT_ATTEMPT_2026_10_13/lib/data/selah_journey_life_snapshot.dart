/// One optional fact a Seeker may choose to place in their Journey-only Bio
/// section. These values are mock data for the Active Journey preview; they do
/// not read or expose the private onboarding answer store.
class SelahJourneyLifeSnapshotField {
  final String id;
  final String section;
  final String label;
  final String value;

  const SelahJourneyLifeSnapshotField({
    required this.id,
    required this.section,
    required this.label,
    required this.value,
  });
}

enum SelahJourneyLifeSnapshotRevealState {
  neither,
  mineWaiting,
  theirsWaiting,
  revealed,
}

abstract final class SelahJourneyLifeSnapshotRevealPolicy {
  static SelahJourneyLifeSnapshotRevealState resolve({
    required bool mine,
    required bool theirs,
  }) {
    if (mine && theirs) return SelahJourneyLifeSnapshotRevealState.revealed;
    if (mine) return SelahJourneyLifeSnapshotRevealState.mineWaiting;
    if (theirs) return SelahJourneyLifeSnapshotRevealState.theirsWaiting;
    return SelahJourneyLifeSnapshotRevealState.neither;
  }

  static bool canRevealMine({required bool mine}) => !mine;

  static bool canViewSnapshot({required bool mine, required bool theirs}) =>
      mine && theirs;
}

abstract final class SelahJourneyLifeSnapshotMock {
  static const int bioCharacterLimit = 1000;

  static const String bio =
      'I am someone who values faith, family and a peaceful home. I work in '
      'product design and enjoy thoughtful conversations, long walks, cooking '
      'for the people close to me and continuing to learn about my Faith. I am '
      'looking for a marriage built on kindness, honesty and teamwork, where '
      'we can laugh together, speak openly when life is difficult and help '
      'each other grow without expecting perfection.';

  static const List<SelahJourneyLifeSnapshotField> fields = [
    SelahJourneyLifeSnapshotField(
      id: 'occupation',
      section: 'Work & education',
      label: 'Occupation',
      value: 'Product designer',
    ),
    SelahJourneyLifeSnapshotField(
      id: 'employment',
      section: 'Work & education',
      label: 'Employment',
      value: 'Employed full-time',
    ),
    SelahJourneyLifeSnapshotField(
      id: 'work_pattern',
      section: 'Work & education',
      label: 'Working pattern',
      value: 'Hybrid · Standard daytime hours',
    ),
    SelahJourneyLifeSnapshotField(
      id: 'education',
      section: 'Work & education',
      label: 'Education',
      value: "Bachelor's degree",
    ),
    SelahJourneyLifeSnapshotField(
      id: 'marriage_status',
      section: 'Family & marriage',
      label: 'Marriage status',
      value: 'Never married',
    ),
    SelahJourneyLifeSnapshotField(
      id: 'children',
      section: 'Family & marriage',
      label: 'Children',
      value: 'No children',
    ),
    SelahJourneyLifeSnapshotField(
      id: 'future_children',
      section: 'Family & marriage',
      label: 'Future children',
      value: 'If God wills',
    ),
    SelahJourneyLifeSnapshotField(
      id: 'responsibilities',
      section: 'Family & marriage',
      label: 'Family responsibilities',
      value: 'Supports parents occasionally',
    ),
    SelahJourneyLifeSnapshotField(
      id: 'income',
      section: 'Practical life',
      label: 'Income range',
      value: '£40,000 – £59,999',
    ),
    SelahJourneyLifeSnapshotField(
      id: 'financial_position',
      section: 'Practical life',
      label: 'Financial position',
      value: 'Mostly ready · Student finance only',
    ),
    SelahJourneyLifeSnapshotField(
      id: 'home',
      section: 'Practical life',
      label: 'Current home',
      value: 'Living with family',
    ),
    SelahJourneyLifeSnapshotField(
      id: 'relocation',
      section: 'Practical life',
      label: 'Relocation',
      value: 'Open for the right person',
    ),
  ];

  static const Set<String> defaultVisibleFieldIds = {
    'occupation',
    'employment',
    'work_pattern',
    'education',
    'marriage_status',
    'children',
    'future_children',
    'responsibilities',
    'income',
    'financial_position',
    'home',
    'relocation',
  };

  static Set<String> toggle(Set<String> current, String id) {
    if (!fields.any((field) => field.id == id)) {
      return Set<String>.unmodifiable(current);
    }
    final next = <String>{...current};
    if (!next.remove(id)) next.add(id);
    return Set<String>.unmodifiable(next);
  }
}
