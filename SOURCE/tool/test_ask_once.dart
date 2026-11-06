import 'dart:convert';
import 'dart:io';

import 'package:selah/data/chapter3_categories.dart';
import 'package:selah/data/compatibility_categories.dart';
import 'package:selah/models/onboarding_question.dart';
import 'package:selah/models/selah_sign_up_compatibility.dart';

void runAskOnceChecks(void Function(bool, String) check) {
  SelahSignUpCompatibility project(String section, String key, dynamic value) =>
      SelahSignUpCompatibility.fromPreferences({
        section: {key: value},
      });
  final rows = <(String, String, String, Map<String, String?>)>[
    (
      'faith_profile',
      'tradition',
      'ch3_q46',
      {
        'Anglican': 'Anglican',
        'Baptist': 'Baptist',
        'Catholic': 'Catholic',
        'Methodist': 'Methodist',
        'Orthodox': 'Orthodox',
        'Pentecostal': 'Pentecostal or charismatic',
        'Presbyterian': 'Reformed or Presbyterian',
        'Non-denominational': 'Non-denominational',
        'Another tradition': 'Another Christian tradition',
      },
    ),
    (
      'faith_profile',
      'church',
      'ch3_q39',
      {
        'Every week': 'Most weeks',
        'Most weeks': 'Several times a month',
        'Sometimes': 'Occasionally',
        'Rarely right now': 'Occasionally',
      },
    ),
    (
      'marriage_values',
      'marriedBefore',
      'ch3_q1',
      {
        'No': 'Never Married',
        'Yes, divorced': 'Divorced',
        'Yes, widowed': 'Widowed',
        'Yes, annulled': 'Annulled',
        'I’d rather share later': null,
      },
    ),
    (
      'marriage_values',
      'children',
      'ch3_q2',
      {
        'No': 'No',
        'Yes, they live with me': 'Yes, living with me',
        'Yes, they don’t live with me': 'Yes, living elsewhere',
      },
    ),
    (
      'marriage_values',
      'wouldLikeChildren',
      'ch3_q3',
      {
        'Yes': 'Yes',
        'Open to it': 'If God wills',
        'No': 'No',
        'Not sure yet': 'Unsure',
      },
    ),
    (
      'marriage_values',
      'hopingToMarry',
      'ch3_q23',
      {
        'Within a year': 'Within 1 year',
        'In 1–2 years': 'Within 2 years',
        'When it’s the right person': "I'm flexible",
        'Not sure yet': "I'm flexible",
      },
    ),
    (
      'marriage_values',
      'whereToLive',
      'ch3_q28',
      {
        'Near where I live now': "I'd prefer not to relocate",
        'Open to moving within my country': 'Within my country',
        'Open to moving abroad': 'Internationally',
      },
    ),
    (
      'marriage_values',
      'rolesInMarriage',
      'ch3_q70',
      {
        'The husband leads, with love and care':
            'Husband leads after discussion',
        'Equal partners who decide together': 'Every decision should be mutual',
        'Somewhere in between': 'Depends on the situation',
        'I’m still thinking about it': null,
      },
    ),
  ];
  final definitions = chapter3CompatibilityCategories
      .expand((category) => category.questions)
      .toList();
  for (final (section, key, qid, mapping) in rows) {
    final definition = definitions.firstWhere((question) => question.id == qid);
    for (final entry in mapping.entries) {
      final projection = project(section, key, entry.key);
      check(
        projection.bankAnswers[qid] == entry.value,
        'ask-once $qid maps ${entry.key} exactly',
      );
      check(
        entry.value == null || definition.options.contains(entry.value),
        'ask-once $qid mapping uses a real retained bank option',
      );
      final raw = {qid: 'old answer', 'unrelated': 'keep'};
      final effective = projection.answersOver(raw);
      check(
        effective[qid] == entry.value && !effective.containsKey('unrelated'),
        'ask-once $qid overwrites or removes old storage on read',
      );
      check(
        raw[qid] == 'old answer',
        'ask-once $qid does not rewrite old saved answer',
      );
    }
    for (final invalid in [null, 'invented', false, 42]) {
      check(
        !project(section, key, invalid).bankAnswers.containsKey(qid),
        'ask-once $qid treats invalid/missing signup $invalid as unanswered',
      );
    }
  }
  for (final (selected, expected) in <(List<String>, String?)>[
    ([], null),
    (['Not right now'], 'Rarely'),
    (['Prayer'], 'Occasionally'),
    (['Worship', 'Youth'], 'Regularly'),
    (['Worship', 'Youth', 'Prayer'], 'Regularly'),
  ]) {
    check(
      project('faith_profile', 'serving', selected).bankAnswers['ch3_q40'] ==
          expected,
      'ask-once serving $selected maps to $expected',
    );
  }
  for (final entry in {
    'Yes': TrafficLight.yellow,
    'It depends on the situation': TrafficLight.yellow,
    'No': TrafficLight.red,
  }.entries) {
    final projection = project('marriage_values', 'openToDivorced', entry.key);
    final raw = {
      'ch3_q1': {
        'Never Married': TrafficLight.green,
        'Divorced': TrafficLight.green,
      },
      'ch3_q2': {'Yes, living with me': TrafficLight.red},
    };
    final effective = projection.preferencesOver(raw);
    check(
      effective['ch3_q1']?.length == 1 &&
          effective['ch3_q1']?['Divorced'] == entry.value,
      'ask-once divorced ${entry.key} maps only the exact Divorced preference',
    );
    check(
      !effective.containsKey('ch3_q2'),
      'LOCK18 other raw partner preferences stay unused',
    );
    check(
      !projection
          .hardRequirementsOver({
            'ch3_q1': {'Divorced'},
            'ch3_q2': {'Yes, living with me'},
          })
          .containsKey('ch3_q1'),
      'ask-once divorced preference never inherits a hard requirement',
    );
    check(
      raw['ch3_q1']!.length == 2 &&
          raw['ch3_q1']!['Divorced'] == TrafficLight.green,
      'ask-once divorced projection leaves raw stored preferences alone',
    );
  }
  final empty = SelahSignUpCompatibility.fromPreferences(const {});
  check(
    empty.answersOver({
      for (final id in selahSignUpQuestionIds) id: 'old answer',
    }).isEmpty,
    'every retired bank answer is unused when signup is missing',
  );
  check(
    !empty
        .preferencesOver({
          'ch3_q1': {'Divorced': TrafficLight.red},
        })
        .containsKey('ch3_q1'),
    'missing divorced signup never falls back to saved q1 preferences',
  );
  final fullIds = definitions.map((question) => question.id).toSet();
  final visibleIds = chapter3Categories
      .expand((category) => category.questions)
      .map((question) => question.id)
      .toSet();
  check(
    fullIds.length == 36 && visibleIds.length == 27,
    'LOCK17 active compatibility36 contains27 asked plus9 mapped',
  );
  check(
    fullIds.difference(visibleIds).length == 9 &&
        fullIds.difference(visibleIds).containsAll(selahSignUpQuestionIds),
    'exactly the nine explicit ask-once IDs leave self-answer lists',
  );
  check(
    chapter3Categories.length == 7 &&
        chapter3Categories.every((category) => category.questions.isNotEmpty),
    'all seven LOCK17 self-answer parts remain nonempty',
  );
  for (final (id, before, after) in [
    ('faith_practice', 8, 5),
    ('marriage_intentions', 7, 4),
    ('family_in_laws', 6, 4),
    ('home_roles', 4, 3),
  ]) {
    check(
      chapter3CompatibilityCategories
                  .singleWhere((category) => category.id == id)
                  .questions
                  .map((question) => question.id)
                  .toSet()
                  .length ==
              before &&
          chapter3Categories
                  .singleWhere((category) => category.id == id)
                  .questions
                  .map((question) => question.id)
                  .toSet()
                  .length ==
              after,
      'ask-once category $id keeps compatibility membership and updates self count',
    );
  }
  for (final category in chapter3CompatibilityCategories) {
    final expected = category.questions.map((question) => question.id).toSet();
    final actual = compatibilityCategories
        .singleWhere((item) => item.id == category.id)
        .questionIds
        .toSet();
    check(
      actual.length == expected.length && actual.containsAll(expected),
      'ask-once preserves ${category.id} compatibility category membership',
    );
  }
  final preferenceIds = chapter4Categories
      .expand((category) => category.questions)
      .where((question) => question.ch4Status != Ch4Status.none)
      .map((question) => question.id)
      .toSet();
  check(preferenceIds.isEmpty, 'LOCK18 removes all partner question lists');
  check(
    visibleIds.contains('ch3_q64'),
    'household responsibilities q64 remains asked',
  );
  final dependent = definitions.firstWhere(
    (question) => question.id == 'ch3_q24',
  );
  for (final entry in {
    'Yes': true,
    'Open to it': true,
    'No': false,
    'Not sure yet': true,
  }.entries) {
    final projected = project(
      'marriage_values',
      'wouldLikeChildren',
      entry.key,
    ).answersOver({'ch3_q3': 'No'});
    check(
      dependent.visibleGiven('male', projected) == entry.value,
      'q24 visibility reads current signup ${entry.key} instead of old bank No',
    );
  }
  check(
    dependent.visibleGiven('female', empty.answersOver({'ch3_q3': 'No'})),
    'q24 keeps unanswered semantics when signup is missing, ignoring old bank No',
  );
  final source = {
    'marriage_values': {'wouldLikeChildren': 'No'},
  };
  final sourceBefore = jsonEncode(source);
  project(
    'marriage_values',
    'wouldLikeChildren',
    'No',
  ).answersOver({'ch3_q3': 'Yes'});
  check(
    jsonEncode(source) == sourceBefore,
    'ask-once read projection never mutates saved signup',
  );
}

void main() {
  var checks = 0;
  runAskOnceChecks((value, label) {
    checks++;
    if (!value) throw StateError('FAILED: $label');
  });
  stdout.writeln('PASS: $checks pure ask-once checks.');
}
