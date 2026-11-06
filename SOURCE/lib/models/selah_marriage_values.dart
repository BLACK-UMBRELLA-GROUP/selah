/// Exact LOCK 5 profile answers. Compatibility mapping is a separate locked
/// change; these values never infer or overwrite retained ch3/ch4 answers.
class SelahMarriageValuesAnswers {
  factory SelahMarriageValuesAnswers({
    String? marriedBefore,
    String? children,
    String? wouldLikeChildren,
    String? rolesInMarriage,
    String? openToDivorced,
    String? whereToLive,
    String? hopingToMarry,
  }) => SelahMarriageValuesAnswers.fromMap({
    'marriedBefore': marriedBefore,
    'children': children,
    'wouldLikeChildren': wouldLikeChildren,
    'rolesInMarriage': rolesInMarriage,
    'openToDivorced': openToDivorced,
    'whereToLive': whereToLive,
    'hopingToMarry': hopingToMarry,
  });

  const SelahMarriageValuesAnswers._({
    this.marriedBefore,
    this.children,
    this.wouldLikeChildren,
    this.rolesInMarriage,
    this.openToDivorced,
    this.whereToLive,
    this.hopingToMarry,
  });

  factory SelahMarriageValuesAnswers.fromMap(Map<dynamic, dynamic> value) {
    String? choice(int question) =>
        optionsFor(question).contains(value[_keys[question]])
        ? value[_keys[question]] as String
        : null;
    return SelahMarriageValuesAnswers._(
      marriedBefore: choice(1),
      children: choice(2),
      wouldLikeChildren: choice(3),
      rolesInMarriage: choice(4),
      openToDivorced: choice(5),
      whereToLive: choice(6),
      hopingToMarry: choice(7),
    );
  }

  final String? marriedBefore;
  final String? children;
  final String? wouldLikeChildren;
  final String? rolesInMarriage;
  final String? openToDivorced;
  final String? whereToLive;
  final String? hopingToMarry;

  static const _keys = <int, String>{
    1: 'marriedBefore',
    2: 'children',
    3: 'wouldLikeChildren',
    4: 'rolesInMarriage',
    5: 'openToDivorced',
    6: 'whereToLive',
    7: 'hopingToMarry',
  };
  static const _options = <int, List<String>>{
    1: [
      'No',
      'Yes, divorced',
      'Yes, widowed',
      'Yes, annulled',
      'I’d rather share later',
    ],
    2: ['No', 'Yes, they live with me', 'Yes, they don’t live with me'],
    3: ['Yes', 'Open to it', 'No', 'Not sure yet'],
    4: [
      'The husband leads, with love and care',
      'Equal partners who decide together',
      'Somewhere in between',
      'I’m still thinking about it',
    ],
    5: ['Yes', 'It depends on the situation', 'No'],
    6: [
      'Near where I live now',
      'Open to moving within my country',
      'Open to moving abroad',
    ],
    7: [
      'Within a year',
      'In 1–2 years',
      'When it’s the right person',
      'Not sure yet',
    ],
  };

  static List<String> optionsFor(int question) =>
      _options[question] ?? const [];
  String? answerFor(int question) => switch (question) {
    1 => marriedBefore,
    2 => children,
    3 => wouldLikeChildren,
    4 => rolesInMarriage,
    5 => openToDivorced,
    6 => whereToLive,
    7 => hopingToMarry,
    _ => null,
  };
  bool get requiredComplete =>
      _keys.keys.every((question) => answerFor(question) != null);
  bool get canSave => requiredComplete;

  SelahMarriageValuesAnswers choose(int question, int optionIndex) {
    final options = optionsFor(question);
    if (optionIndex < 0 || optionIndex >= options.length) return this;
    final value = options[optionIndex];
    if (answerFor(question) == value) return this;
    return SelahMarriageValuesAnswers.fromMap({
      ...toMap(),
      _keys[question]!: value,
    });
  }

  Map<String, dynamic> toMap() => {
    for (final question in _keys.keys) _keys[question]!: answerFor(question),
  };

  Map<String, dynamic> mergePreferences(Map<String, dynamic> existing) => {
    ...existing,
    'marriage_values': {
      if (existing['marriage_values'] is Map)
        ...Map<String, dynamic>.from(existing['marriage_values'] as Map),
      ...toMap(),
    },
  };
}
