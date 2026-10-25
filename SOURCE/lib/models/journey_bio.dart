/// A Seeker-controlled biography shown only inside an Active Journey after
/// both people choose to reveal their Journey profiles.
///
/// This is deliberately separate from compatibility answers. Prose is never
/// scored, and a person can leave every field empty without blocking their
/// onboarding.
class JourneyBio {
  static const int characterLimit = 400;

  final String aboutMe;
  final Map<String, String> fieldValues;
  final Set<String> visibleFieldIds;
  final bool showAboutMe;

  /// The optional section has been reviewed, even when left intentionally empty.
  final bool reviewed;

  const JourneyBio({
    this.aboutMe = '',
    this.fieldValues = const {},
    this.visibleFieldIds = const {},
    this.showAboutMe = false,
    this.reviewed = false,
  });

  bool get isEmpty =>
      aboutMe.trim().isEmpty &&
      fieldValues.values.every((value) => value.trim().isEmpty);

  int get sharedItemCount =>
      (showAboutMe && aboutMe.trim().isNotEmpty ? 1 : 0) +
      visibleFieldIds
          .where((id) => (fieldValues[id] ?? '').trim().isNotEmpty)
          .length;

  JourneyBio copyWith({
    String? aboutMe,
    Map<String, String>? fieldValues,
    Set<String>? visibleFieldIds,
    bool? showAboutMe,
    bool? reviewed,
  }) => JourneyBio(
    aboutMe: aboutMe ?? this.aboutMe,
    fieldValues: Map<String, String>.unmodifiable(
      fieldValues ?? this.fieldValues,
    ),
    visibleFieldIds: Set<String>.unmodifiable(
      visibleFieldIds ?? this.visibleFieldIds,
    ),
    showAboutMe: showAboutMe ?? this.showAboutMe,
    reviewed: reviewed ?? this.reviewed,
  );

  /// Stored alongside the private onboarding JSON. The `bio_` namespace
  /// prevents these display choices being mistaken for scored question IDs.
  Map<String, dynamic> toOnboardingAnswers() => {
    'bio_reviewed': reviewed,
    'bio_about_me': aboutMe.trim(),
    'bio_show_about_me': showAboutMe && aboutMe.trim().isNotEmpty,
    'bio_fields': {
      for (final entry in fieldValues.entries)
        if (entry.value.trim().isNotEmpty) entry.key: entry.value.trim(),
    },
    'bio_visible_field_ids': visibleFieldIds
        .where((id) => (fieldValues[id] ?? '').trim().isNotEmpty)
        .toList(growable: false),
  };

  /// Restores the Journey-only biography from the private onboarding JSON.
  /// Unknown or malformed values are ignored so an older draft cannot make
  /// the rest of onboarding unreadable after the schema evolves.
  factory JourneyBio.fromOnboardingAnswers(Map<String, dynamic> answers) {
    final rawFields = answers['bio_fields'];
    final fields = <String, String>{};
    if (rawFields is Map) {
      for (final entry in rawFields.entries) {
        if (entry.key is String && entry.value is String) {
          fields[entry.key as String] = entry.value as String;
        }
      }
    }

    final visible = <String>{};
    final rawVisible = answers['bio_visible_field_ids'];
    if (rawVisible is List) {
      visible.addAll(rawVisible.whereType<String>());
    }

    return JourneyBio(
      aboutMe: answers['bio_about_me'] as String? ?? '',
      fieldValues: Map<String, String>.unmodifiable(fields),
      visibleFieldIds: Set<String>.unmodifiable(visible),
      showAboutMe: answers['bio_show_about_me'] == true,
      reviewed: answers['bio_reviewed'] == true,
    );
  }
}

class JourneyBioFieldDefinition {
  final String id;
  final String section;
  final String label;
  final String prompt;
  final List<String> options;

  const JourneyBioFieldDefinition({
    required this.id,
    required this.section,
    required this.label,
    required this.prompt,
    this.options = const [],
  });

  bool get usesFreeText => options.isEmpty;
}

const List<JourneyBioFieldDefinition> journeyBioFieldDefinitions = [
  JourneyBioFieldDefinition(
    id: 'occupation',
    section: 'Work & education',
    label: 'Occupation',
    prompt: 'What do you do?',
  ),
  JourneyBioFieldDefinition(
    id: 'employment',
    section: 'Work & education',
    label: 'Employment',
    prompt: 'What is your current employment situation?',
    options: [
      'Employed full-time',
      'Employed part-time',
      'Self-employed',
      'Student',
      'Between roles',
      'Unable to work',
      'Retired',
      'Prefer not to say',
    ],
  ),
  JourneyBioFieldDefinition(
    id: 'work_pattern',
    section: 'Work & education',
    label: 'Working pattern',
    prompt: 'What does your usual working pattern look like?',
    options: [
      'Standard daytime hours',
      'Shift work',
      'Night work',
      'Remote',
      'Hybrid',
      'Frequent travel',
      'Flexible or varies',
      'Not currently working',
    ],
  ),
  JourneyBioFieldDefinition(
    id: 'education',
    section: 'Work & education',
    label: 'Education',
    prompt: 'Which education detail would you like to share?',
    options: [
      'Secondary school or equivalent',
      'College or A Levels',
      'Diploma',
      "Bachelor's degree",
      "Master's degree",
      'Doctorate',
      'Christian studies qualification',
      'Prefer not to say',
    ],
  ),
  JourneyBioFieldDefinition(
    id: 'marriage_status',
    section: 'Family & marriage',
    label: 'Marriage status',
    prompt: 'Which marriage-history detail would you like to share?',
    options: [
      'Never married',
      'Separated',
      'Divorced',
      'Annulled',
      'Widowed',
      'Currently married',
      'Prefer not to say',
    ],
  ),
  JourneyBioFieldDefinition(
    id: 'children',
    section: 'Family & marriage',
    label: 'Children',
    prompt: 'What would you like to share about children you have?',
    options: [
      'No children',
      'Children living with me',
      'Shared custody',
      'Children living elsewhere',
      'Prefer to discuss later',
    ],
  ),
  JourneyBioFieldDefinition(
    id: 'future_children',
    section: 'Family & marriage',
    label: 'Future children',
    prompt: 'What would you like to share about future children?',
    options: [
      'Yes',
      'No',
      'If God wills',
      'Unsure',
      'Prefer to discuss later',
    ],
  ),
  JourneyBioFieldDefinition(
    id: 'responsibilities',
    section: 'Family & marriage',
    label: 'Family responsibilities',
    prompt: 'Do you want to mention an ongoing family responsibility?',
  ),
  JourneyBioFieldDefinition(
    id: 'income',
    section: 'Practical life',
    label: 'Income range',
    prompt: 'Which income range would you like to share?',
    options: [
      'Under £20,000',
      '£20,000 – £39,999',
      '£40,000 – £59,999',
      '£60,000 – £79,999',
      '£80,000 – £99,999',
      '£100,000+',
      'Prefer not to say',
    ],
  ),
  JourneyBioFieldDefinition(
    id: 'financial_position',
    section: 'Practical life',
    label: 'Financial position',
    prompt: 'How would you describe your financial position for marriage?',
    options: [
      'Ready now',
      'Mostly ready',
      'Still preparing',
      'Beginning my journey',
      'Prefer to discuss later',
    ],
  ),
  JourneyBioFieldDefinition(
    id: 'home',
    section: 'Practical life',
    label: 'Current home',
    prompt: 'What would you like to share about where you live?',
    options: [
      'Living independently',
      'Living with family',
      'Shared accommodation',
      'Other arrangement',
      'Prefer not to say',
    ],
  ),
  JourneyBioFieldDefinition(
    id: 'relocation',
    section: 'Practical life',
    label: 'Relocation',
    prompt: 'What would you like to share about relocation?',
    options: [
      'Open to relocating anywhere',
      'Open within my country',
      'Open internationally',
      'Open for the right person',
      'Prefer not to relocate',
      'Prefer to discuss later',
    ],
  ),
];
