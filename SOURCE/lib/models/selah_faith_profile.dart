import '../data/selah_christian_traditions.dart';

/// Exact LOCK 4 answers. Canonical Chapter 2 fields are derived from these
/// values; no legacy answer is inferred or migrated into a new question.
class SelahFaithProfileAnswers {
  factory SelahFaithProfileAnswers({
    String? tradition,
    String? church,
    String? baptised,
    String? christianFor,
    List<String> serving = const [],
    String? openness,
    String words = '',
  }) => SelahFaithProfileAnswers.fromMap({
    'tradition': tradition,
    'church': church,
    'baptised': baptised,
    'christianFor': christianFor,
    'serving': serving,
    'openness': openness,
    'words': words,
  });

  SelahFaithProfileAnswers._({
    this.tradition,
    this.church,
    this.baptised,
    this.christianFor,
    required List<String> serving,
    this.openness,
    required this.words,
  }) : serving = List.unmodifiable(serving);

  factory SelahFaithProfileAnswers.fromMap(Map<dynamic, dynamic> value) {
    String? choice(String key, int question) =>
        optionsFor(question).contains(value[key]) ? value[key] as String : null;
    final rawServing = value['serving'];
    final selected = rawServing is List
        ? optionsFor(5).where(rawServing.contains).toList()
        : <String>[];
    return SelahFaithProfileAnswers._(
      tradition: choice('tradition', 1),
      church: choice('church', 2),
      baptised: choice('baptised', 3),
      christianFor: choice('christianFor', 4),
      serving: selected.contains('Not right now')
          ? const ['Not right now']
          : selected,
      openness: choice('openness', 6),
      words: value['words'] is String ? value['words'] as String : '',
    );
  }

  final String? tradition;
  final String? church;
  final String? baptised;
  final String? christianFor;
  final List<String> serving;
  final String? openness;
  final String words;

  static const _options = <int, List<String>>{
    1: [
      'Anglican',
      'Baptist',
      'Catholic',
      'Methodist',
      'Orthodox',
      'Pentecostal',
      'Presbyterian',
      'Non-denominational',
      'Another tradition',
    ],
    2: ['Every week', 'Most weeks', 'Sometimes', 'Rarely right now'],
    3: ['Yes', 'Not yet', 'I’d rather not say'],
    4: [
      'All my life',
      'More than 10 years',
      '5–10 years',
      '1–5 years',
      'Less than a year',
    ],
    5: [
      'Worship',
      'Youth',
      'Children’s work',
      'Welcome team',
      'Small group',
      'Prayer',
      'Missions',
      'Not right now',
    ],
    6: [
      'Yes, any tradition',
      'Similar traditions only',
      'My own tradition only',
    ],
  };

  static List<String> optionsFor(int question) =>
      _options[question] ?? const [];
  String? answerFor(int question) => switch (question) {
    1 => tradition,
    2 => church,
    3 => baptised,
    4 => christianFor,
    6 => openness,
    _ => null,
  };

  /// Counts Unicode scalar values, so a supplementary character is one rather
  /// than two UTF-16 code units. The editor keeps overlength text for validation.
  int get characterCount => words.runes.length;
  bool get requiredComplete =>
      const [1, 2, 3, 4, 6].every((question) => answerFor(question) != null);
  bool get withinWordLimit => characterCount <= 150;
  bool get canSave => requiredComplete && withinWordLimit;

  SelahFaithProfileAnswers choose(int question, int optionIndex) {
    final options = optionsFor(question);
    if (optionIndex < 0 || optionIndex >= options.length) return this;
    final value = options[optionIndex];
    final updated = toMap();
    if (question == 5) {
      final next = List<String>.of(serving);
      if (next.contains(value)) {
        next.remove(value);
      } else if (value == 'Not right now') {
        next
          ..clear()
          ..add(value);
      } else {
        next
          ..remove('Not right now')
          ..add(value);
      }
      updated['serving'] = next;
    } else {
      updated[switch (question) {
            1 => 'tradition',
            2 => 'church',
            3 => 'baptised',
            4 => 'christianFor',
            6 => 'openness',
            _ => '',
          }] =
          value;
    }
    return SelahFaithProfileAnswers.fromMap(updated);
  }

  SelahFaithProfileAnswers withWords(String value) =>
      SelahFaithProfileAnswers.fromMap({...toMap(), 'words': value});
  SelahFaithProfileAnswers withoutServing() => SelahFaithProfileAnswers.fromMap(
    {...toMap(), 'serving': const <String>[]},
  );

  Map<String, dynamic> toMap() => {
    'tradition': tradition,
    'church': church,
    'baptised': baptised,
    'christianFor': christianFor,
    'serving': List<String>.of(serving),
    'openness': openness,
    'words': words,
  };

  String? get christianFamily => switch (tradition) {
    'Anglican' => 'Anglican & Episcopal',
    'Baptist' || 'Methodist' || 'Presbyterian' => 'Protestant',
    'Catholic' => 'Catholic',
    'Orthodox' => 'Orthodox & Eastern Christian',
    'Pentecostal' => 'Pentecostal, Charismatic & Apostolic',
    'Non-denominational' => 'Independent & Non-denominational',
    'Another tradition' => 'Another Christian tradition or movement',
    _ => null,
  };

  String? get christianDenomination {
    if (!const ['Baptist', 'Methodist', 'Presbyterian'].contains(tradition)) {
      return null;
    }
    final family = selahChristianFamilyForLabel('Protestant');
    for (final denomination
        in family?.denominations ?? <SelahChristianDenomination>[]) {
      if (denomination.label == tradition) return denomination.label;
    }
    return null;
  }

  String? get faithJourneyCode => christianFor == null
      ? null
      : christianFor == 'All my life'
      ? 'raised_christian'
      : 'became_christian_later';
  String? get faithJourneyLabel => selahFaithJourneyLabels[faithJourneyCode];
  String? get churchPreferenceScope => switch (openness) {
    'Yes, any tradition' => 'no_preference',
    'Similar traditions only' || 'My own tradition only' => 'same_family',
    _ => null,
  };
  String? get outsideFlexibility => switch (openness) {
    'Yes, any tradition' => 'green',
    'Similar traditions only' => 'yellow',
    'My own tradition only' => 'red',
    _ => null,
  };
  bool get firmPreference => openness == 'My own tradition only';

  Map<String, dynamic> mergePreferences(Map<String, dynamic> existing) {
    Map<String, dynamic> section(String key) => existing[key] is Map
        ? Map<String, dynamic>.from(existing[key] as Map)
        : <String, dynamic>{};
    return {
      ...existing,
      'faith_profile': {...section('faith_profile'), ...toMap()},
      'church_background': {
        ...section('church_background'),
        'scope': churchPreferenceScope,
        'outside_flexibility': outsideFlexibility,
        'hard_requirement': firmPreference,
      },
    };
  }
}
