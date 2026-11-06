// Pure Dart checks for the real LOCK 5 answer model; no Flutter or storage.
import 'dart:convert';
import 'dart:io';

import 'package:selah/models/selah_marriage_values.dart';

void runMarriageValuesChecks(void Function(bool, String) check) {
  const locked = <int, List<String>>{
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
  const keys = <int, String>{
    1: 'marriedBefore',
    2: 'children',
    3: 'wouldLikeChildren',
    4: 'rolesInMarriage',
    5: 'openToDivorced',
    6: 'whereToLive',
    7: 'hopingToMarry',
  };
  var answers = SelahMarriageValuesAnswers();
  check(!answers.canSave, 'empty Marriage values cannot save');
  for (final question in [7, 4, 1, 6, 2, 5, 3]) {
    check(
      SelahMarriageValuesAnswers.optionsFor(question).join('|') ==
          locked[question]!.join('|'),
      'Marriage question $question uses the exact closed LOCK words and order',
    );
    check(
      answers.answerFor(question) == null,
      'Marriage question $question starts unanswered',
    );
    answers = answers.choose(question, 0);
    check(
      answers.answerFor(question) == locked[question]!.first,
      'Marriage question $question stores its actual selected label',
    );
  }
  check(
    answers.requiredComplete && answers.canSave,
    'all seven answers complete in any order',
  );
  for (final question in locked.keys) {
    final key = keys[question]!;
    final missing = answers.toMap()..remove(key);
    check(
      !SelahMarriageValuesAnswers.fromMap(missing).canSave,
      'Marriage question $question is independently required',
    );
    for (final invalid in [null, '', 'legacy or invented', false, 0]) {
      final invalidAnswers = {...answers.toMap(), key: invalid};
      final restored = SelahMarriageValuesAnswers.fromMap(invalidAnswers);
      check(
        restored.answerFor(question) == null && !restored.canSave,
        'Marriage question $question rejects non-LOCK answer $invalid',
      );
    }
    for (var index = 0; index < locked[question]!.length; index++) {
      final changed = answers.choose(question, index);
      final restored = SelahMarriageValuesAnswers.fromMap(
        jsonDecode(jsonEncode(changed.toMap())) as Map,
      );
      check(
        restored.answerFor(question) == locked[question]![index] &&
            restored.canSave,
        'Marriage question $question answer $index survives JSON without mapping',
      );
      for (final other in locked.keys.where((item) => item != question)) {
        check(
          changed.answerFor(other) == answers.answerFor(other),
          'changing Marriage question $question preserves question $other',
        );
      }
    }
    check(
      identical(answers.choose(question, -1), answers) &&
          identical(
            answers.choose(question, locked[question]!.length),
            answers,
          ),
      'Marriage question $question rejects invalid indexes',
    );
    var immutable = false;
    try {
      SelahMarriageValuesAnswers.optionsFor(question).add('invented');
    } on UnsupportedError {
      immutable = true;
    }
    check(
      immutable,
      'Marriage question $question options cannot be expanded by a caller',
    );
  }
  check(
    identical(answers.choose(0, 0), answers) &&
        identical(answers.choose(8, 0), answers) &&
        answers.answerFor(8) == null,
    'unknown Marriage question cannot gain an answer',
  );
  final exported = answers.toMap();
  exported['marriedBefore'] = 'Yes, divorced';
  check(
    answers.marriedBefore == 'No',
    'exported map cannot mutate immutable answers',
  );
  final previous = <String, dynamic>{
    'faith_profile': {'tradition': 'Baptist', 'words': 'Faith words'},
    'church_background': {
      'scope': 'same_family',
      'outside_flexibility': 'yellow',
    },
    'faith_journey': {'flexibility': 'green'},
    'marriage_values': {'unknown': 'preserve'},
    'ch3': {'ch3_q1': 'Never Married', 'ch3_q70': 'retained role'},
    'ch4': {'Divorced': 'retained preference'},
    'unknown': ['preserve'],
  };
  final before = jsonEncode(previous);
  final merged = answers.mergePreferences(previous);
  check(
    jsonEncode(previous) == before,
    'Marriage merge leaves prior saved details untouched',
  );
  check(
    (merged['marriage_values'] as Map)['unknown'] == 'preserve',
    'Marriage merge preserves unknown fields in its existing section',
  );
  for (final key in previous.keys.where((key) => key != 'marriage_values')) {
    check(
      jsonEncode(merged[key]) == jsonEncode(previous[key]),
      'Marriage merge preserves $key without compatibility or faith mapping',
    );
  }
  final reloaded = SelahMarriageValuesAnswers.fromMap(
    jsonDecode(jsonEncode(merged['marriage_values'])) as Map,
  );
  check(
    jsonEncode(reloaded.toMap()) == jsonEncode(answers.toMap()),
    'all exact Marriage fields use one round-trippable JSON section',
  );
  for (final legacy in [
    'Never Married',
    'Separated',
    'Currently Married',
    'Shared custody',
    'If God wills',
    'Unsure',
  ]) {
    check(
      !SelahMarriageValuesAnswers.fromMap({
        'marriedBefore': legacy,
        'children': legacy,
        'wouldLikeChildren': legacy,
        'hopingToMarry': legacy,
      }).canSave,
      'legacy value $legacy is not silently mapped into LOCK 5',
    );
  }
}

void main() {
  var checks = 0;
  runMarriageValuesChecks((value, label) {
    checks++;
    if (!value) throw StateError('FAILED: $label');
  });
  stdout.writeln('PASS: $checks pure Marriage values checks.');
}
