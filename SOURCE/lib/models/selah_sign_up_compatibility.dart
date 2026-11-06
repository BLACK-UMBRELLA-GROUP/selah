import 'onboarding_question.dart';
import 'selah_faith_profile.dart';
import 'selah_marriage_values.dart';
import 'selah_your_values.dart';

/// Retained definitions remain available for compatibility and old storage.
/// These nine self-answers are now asked only in the sign-up profile.
const selahSignUpQuestionIds = <String>{
  'ch3_q46',
  'ch3_q39',
  'ch3_q40',
  'ch3_q1',
  'ch3_q2',
  'ch3_q3',
  'ch3_q23',
  'ch3_q28',
  'ch3_q70',
};

typedef SelahSignUpPreferencesReader = Map<String, dynamic> Function();

/// A computed read projection, never another saved answer store. Missing
/// sign-up answers remove old bank values from effective compatibility reads.
class SelahSignUpCompatibility {
  SelahSignUpCompatibility.fromPreferences(Map<String, dynamic> preferences) {
    Map<dynamic, dynamic> section(String key) =>
        preferences[key] is Map ? preferences[key] as Map : const {};
    final faith = SelahFaithProfileAnswers.fromMap(section('faith_profile'));
    final marriage = SelahMarriageValuesAnswers.fromMap(
      section('marriage_values'),
    );
    final serving = faith.serving;
    bankAnswers = Map.unmodifiable({
      if (_tradition[faith.tradition] case final String value) 'ch3_q46': value,
      if (_church[faith.church] case final String value) 'ch3_q39': value,
      if (serving.isNotEmpty)
        'ch3_q40': serving.contains('Not right now')
            ? 'Rarely'
            : serving.length == 1
            ? 'Occasionally'
            : 'Regularly',
      if (_married[marriage.marriedBefore] case final String value)
        'ch3_q1': value,
      if (_children[marriage.children] case final String value) 'ch3_q2': value,
      if (_wouldLikeChildren[marriage.wouldLikeChildren]
          case final String value)
        'ch3_q3': value,
      if (_when[marriage.hopingToMarry] case final String value)
        'ch3_q23': value,
      if (_where[marriage.whereToLive] case final String value)
        'ch3_q28': value,
      if (_roles[marriage.rolesInMarriage] case final String value)
        'ch3_q70': value,
    });
    divorcedPreference = switch (marriage.openToDivorced) {
      'Yes' || 'It depends on the situation' => TrafficLight.yellow,
      'No' => TrafficLight.red,
      _ => null,
    };
  }

  late final Map<String, dynamic> bankAnswers;
  late final TrafficLight? divorcedPreference;

  static const _tradition = {
    'Anglican': 'Anglican',
    'Baptist': 'Baptist',
    'Catholic': 'Catholic',
    'Methodist': 'Methodist',
    'Orthodox': 'Orthodox',
    'Pentecostal': 'Pentecostal or charismatic',
    'Presbyterian': 'Reformed or Presbyterian',
    'Non-denominational': 'Non-denominational',
    'Another tradition': 'Another Christian tradition',
  };
  static const _church = {
    'Every week': 'Most weeks',
    'Most weeks': 'Several times a month',
    'Sometimes': 'Occasionally',
    'Rarely right now': 'Occasionally',
  };
  static const _married = {
    'No': 'Never Married',
    'Yes, divorced': 'Divorced',
    'Yes, widowed': 'Widowed',
    'Yes, annulled': 'Annulled',
  };
  static const _children = {
    'No': 'No',
    'Yes, they live with me': 'Yes, living with me',
    'Yes, they don’t live with me': 'Yes, living elsewhere',
  };
  static const _wouldLikeChildren = {
    'Yes': 'Yes',
    'Open to it': 'If God wills',
    'No': 'No',
    'Not sure yet': 'Unsure',
  };
  static const _when = {
    'Within a year': 'Within 1 year',
    'In 1–2 years': 'Within 2 years',
    'When it’s the right person': "I'm flexible",
    'Not sure yet': "I'm flexible",
  };
  static const _where = {
    'Near where I live now': "I'd prefer not to relocate",
    'Open to moving within my country': 'Within my country',
    'Open to moving abroad': 'Internationally',
  };
  static const _roles = {
    'The husband leads, with love and care': 'Husband leads after discussion',
    'Equal partners who decide together': 'Every decision should be mutual',
    'Somewhere in between': 'Depends on the situation',
  };

  Map<String, dynamic> answersOver(Map<String, dynamic> raw) => {
    for (final entry in raw.entries)
      if (selahYourValuesQuestionIds.contains(entry.key.split('::').first))
        entry.key: entry.value,
    ...bankAnswers,
  };

  /// Only the explicit Divorced preference changes. Other existing Chapter 4
  /// option preferences remain as they were; q1 is no longer asked there.
  Map<String, Map<String, TrafficLight>> preferencesOver(
    Map<String, Map<String, TrafficLight>> raw,
  ) => {
    if (divorcedPreference case final TrafficLight value)
      'ch3_q1': {'Divorced': value},
  };

  Map<String, Set<String>> hardRequirementsOver(Map<String, Set<String>> raw) =>
      {
        for (final entry in raw.entries)
          if (selahDealbreakerRequirements[entry.key] case final allowed?)
            if (entry.value.containsAll(allowed)) entry.key: Set.of(allowed),
      };
}
