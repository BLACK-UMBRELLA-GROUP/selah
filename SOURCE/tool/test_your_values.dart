import 'dart:io';

import 'package:selah/data/chapter3_categories.dart';
import 'package:selah/data/compatibility_categories.dart';
import 'package:selah/models/onboarding_question.dart';
import 'package:selah/models/selah_sign_up_compatibility.dart';
import 'package:selah/models/selah_your_values.dart';

void runYourValuesChecks(void Function(bool, String) check) {
  const expected = <String, List<int>>{
    'Faith at home': [33, 34, 44, 51, 38],
    'Marriage': [25, 26, 32, 24],
    'Family': [4, 6, 8, 48],
    'Money': [47, 67, 68, 13],
    'Home and roles': [64, 18, 73],
    'Talking things through': [75, 76, 83, 81],
    'Everyday life': [52, 53, 84],
  };
  check(
    chapter3Categories.map((part) => part.name).join('|') ==
        expected.keys.join('|'),
    'LOCK17 exact seven-part order',
  );
  for (final gender in ['male', 'female']) {
    final questions = <OnboardingQuestion>[];
    for (final part in chapter3Categories) {
      final visible = selahYourValuesQuestionsFor(part, gender, {}, {});
      questions.addAll(visible);
      check(
        visible.map((question) => question.id).join(',') ==
            expected[part.name]!.map((id) => 'ch3_q$id').join(','),
        '$gender ${part.name} exact question order',
      );
      check(
        !selahYourValuesPartComplete(part, gender, {}, {}),
        '$gender ${part.name} starts genuinely incomplete',
      );
      final answered = {
        for (final question in visible.where(
          (question) => !question.selfAnswerOptional,
        ))
          question.responseKey: question.options.first,
      };
      check(
        selahYourValuesPartComplete(part, gender, answered, {}),
        '$gender ${part.name} permits only locked optional skips',
      );
      for (final question in visible) {
        check(
          question.selfAnswerOptional ==
              {'ch3_q44', 'ch3_q51'}.contains(question.id),
          '${question.responseKey} optional flag independent of Ch4',
        );
        if (!question.selfAnswerOptional) {
          final missing = Map<String, dynamic>.of(answered)
            ..remove(question.responseKey);
          check(
            !selahYourValuesPartComplete(part, gender, missing, {}),
            '${question.responseKey} required boundary',
          );
        }
      }
    }
    check(
      questions.length == 27 &&
          questions.map((question) => question.id).toSet().length == 27,
      '$gender exactly27 unique asked questions',
    );
    check(
      questions
              .where((question) => question.id == 'ch3_q26')
              .single
              .responseKey ==
          'ch3_q26::$gender',
      '$gender q26 response identity retained',
    );
  }
  final marriage = chapter3Categories[1];
  for (final answer in [null, 'Yes', 'Open to it', 'Not sure yet', 'No']) {
    final visible = selahYourValuesQuestionsFor(
      marriage,
      'male',
      {'ch3_q3': 'No'},
      {
        'marriage_values': {'wouldLikeChildren': answer},
      },
    );
    check(
      visible.any((question) => question.id == 'ch3_q24') == (answer != 'No'),
      'q24 follows canonical Marriage Q3=$answer, never old raw fallback',
    );
  }
  check(
    compatibilityCategories.length == 8,
    'seven compatibility parts plus Location & Language',
  );
  check(
    compatibilityCategories.map((part) => part.name).join('|') ==
        [...expected.keys, 'Location & Language'].join('|'),
    'exact eight compatibility names/order',
  );
  final membership = {
    for (final category in compatibilityCategories)
      category.name: category.questionIds.toSet(),
  };
  for (final entry in {
    'Faith at home': [46, 39, 40],
    'Marriage': [1, 23, 28],
    'Family': [2, 3],
    'Home and roles': [70],
  }.entries) {
    check(
      membership[entry.key]!.containsAll(entry.value.map((id) => 'ch3_q$id')),
      '${entry.key} counts the exact sign-up projection IDs',
    );
  }
  check(
    compatibilityCategories
            .expand((category) => category.questionIds)
            .toSet()
            .length ==
        36,
    '36 unique compatibility question IDs, no retired membership',
  );
  final faith = chapter3Categories.first;
  final patch = {
    for (final question in faith.questions)
      question.responseKey: question.selfAnswerOptional
          ? null
          : question.options.first,
  };
  final raw = <String, dynamic>{
    'ch3_q12': 'retired income',
    'ch3_q24': 'hidden family timing',
    'ch3_q46': 'old tradition',
    'ch3_q52': "I don't smoke or vape",
    'unknown': ['keep'],
  };
  final merged = selahMergeYourValuesPart(
    existing: raw,
    gender: 'male',
    partId: faith.id,
    answers: patch,
    signUpPreferences: {},
  )!;
  for (final key in raw.keys) {
    check(merged[key] == raw[key], 'part save preserves unedited raw $key');
  }
  check(
    !merged.containsKey('ch3_q44') && !merged.containsKey('ch3_q51'),
    'optional Skip writes no fabricated answer',
  );
  check(
    selahMergeYourValuesPart(
          existing: raw,
          gender: 'male',
          partId: faith.id,
          answers: {...patch, 'ch3_q12': 'changed'},
          signUpPreferences: {},
        ) ==
        null,
    'retired field injection cannot enter a part save',
  );
  check(
    selahMergeYourValuesPart(
          existing: raw,
          gender: 'male',
          partId: faith.id,
          answers: {...patch, 'ch3_q33': null},
          signUpPreferences: {},
        ) ==
        null,
    'required null cannot be skipped',
  );
  check(
    selahMergeYourValuesPart(
          existing: raw,
          gender: 'male',
          partId: 'retired',
          answers: {},
          signUpPreferences: {},
        ) ==
        null,
    'retired category cannot save',
  );
  final effective = SelahSignUpCompatibility.fromPreferences(
    {},
  ).answersOver(raw);
  check(
    !effective.containsKey('ch3_q12') &&
        !effective.containsKey('unknown') &&
        !effective.containsKey('ch3_q46'),
    'retired/unknown/raw sign-up fields do not affect effective compatibility',
  );
  check(
    effective['ch3_q52'] == raw['ch3_q52'] &&
        raw['ch3_q12'] == 'retired income',
    'kept scoring answer survives without destroying retired storage',
  );
  check(
    chapter4Categories.isEmpty,
    'LOCK18 partner question list is unreachable',
  );
  final prefs =
      SelahSignUpCompatibility.fromPreferences({
        'marriage_values': {'openToDivorced': 'No'},
      }).preferencesOver({
        'ch3_q52': {'I smoke only': TrafficLight.green},
        'ch3_q1': {'Divorced': TrafficLight.green},
      });
  check(
    prefs.length == 1 && prefs['ch3_q1']?['Divorced'] == TrafficLight.red,
    'only canonical Divorced preference remains effective',
  );
  const spec = <String, Set<String>>{
    'ch3_q52': {'I vape only', 'I smoke only', 'I both smoke and vape'},
    'ch3_q53': {'I drink occasionally', 'I drink socially in moderation'},
    'ch3_q3': {'No'},
    'ch3_q2': {'Yes, living with me', 'Yes, living elsewhere'},
    'ch3_q28': {'Internationally'},
  };
  for (var index = 0; index < spec.length; index++) {
    final expected = spec.entries.elementAt(index);
    final actual = selahDealbreakersFor([index]);
    check(
      actual.length == 1 &&
          actual[expected.key]!.length == expected.value.length &&
          actual[expected.key]!.containsAll(expected.value),
      'dealbreaker$index writes exact existing rows',
    );
  }
  check(
    selahDealbreakersFor([]).isEmpty && selahDealbreakersFor([0, 1, 5]).isEmpty,
    'nothing chosen or None writes no dealbreaker keys',
  );
  final savedHard = <String, Set<String>>{
    ...spec,
    'retired': {'keep'},
    'ch3_q1': {'Divorced'},
  };
  final cleared = selahMergeDealbreakers(
    existing: savedHard,
    requirements: {},
  )!;
  check(
    cleared.length == 2 &&
        cleared['retired']!.contains('keep') &&
        cleared['ch3_q1']!.contains('Divorced'),
    'None clears all five active rows, retaining unused raw storage',
  );
  check(
    selahMergeDealbreakers(
          existing: savedHard,
          requirements: {
            'ch3_q52': {'I smoke only'},
          },
        ) ==
        null,
    'partial/invented hard rules denied',
  );
  check(
    selahMergeDealbreakers(
          existing: savedHard,
          requirements: {
            'ch3_q12': {'income'},
          },
        ) ==
        null,
    'unlocked hard-rule key denied',
  );
  var immutable = false;
  try {
    selahDealbreakersFor([0])['ch3_q52']!.clear();
  } on UnsupportedError {
    immutable = true;
  }
  check(immutable, 'dealbreaker rule snapshots are immutable');
}

void main() {
  var count = 0;
  runYourValuesChecks((condition, description) {
    if (!condition) throw StateError(description);
    count++;
  });
  stdout.writeln('$count Your values checks passed.');
}
