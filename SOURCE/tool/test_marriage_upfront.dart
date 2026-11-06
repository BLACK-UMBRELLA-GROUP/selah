import 'package:selah/data/selah_journey_life_snapshot.dart';
import 'package:selah/models/journey_bio.dart';
import 'package:selah/models/seeker_profile.dart';
import 'package:selah/models/selah_marriage_values.dart';

void runMarriageUpfrontChecks(void Function(bool, String) check) {
  String line(Map<String, String> map) => SeekerProfile(
    id: 'explicit-projection',
    firstName: 'Grace',
    age: 29,
    city: 'Leeds',
    photos: const [],
    gender: 'female',
    marriageValues: SelahMarriageValuesAnswers.fromMap(map),
  ).browseMarriageLine;
  final mappings = <String, Map<String, String>>{
    'marriedBefore': {
      'No': 'Never married',
      'Yes, divorced': 'Divorced',
      'Yes, widowed': 'Widowed',
      'Yes, annulled': 'Annulled',
      'I’d rather share later': '',
    },
    'children': {
      'No': 'No children',
      'Yes, they live with me': 'Has children',
      'Yes, they don’t live with me': 'Has children',
    },
    'wouldLikeChildren': {
      'Yes': 'Would like children',
      'Open to it': 'Open to children',
      'No': 'Doesn’t want children',
      'Not sure yet': 'Not sure about children',
    },
  };
  for (final field in mappings.entries) {
    for (final answer in field.value.entries) {
      check(
        line({field.key: answer.key}) == answer.value,
        'LOCK16 exact ${field.key}/${answer.key}',
      );
    }
  }
  check(line({}).isEmpty, 'LOCK16 no answers means no line');
  check(
    line({
          'marriedBefore': 'No',
          'children': 'No',
          'wouldLikeChildren': 'Yes',
        }) ==
        'Never married · No children · Would like children',
    'LOCK16 ordered line',
  );
  check(
    line({
          'marriedBefore': 'I’d rather share later',
          'children': 'No',
          'wouldLikeChildren': 'Yes',
        }) ==
        'No children · Would like children',
    'LOCK16 withheld part has no separator',
  );
  check(
    line({
          'rolesInMarriage': 'Somewhere in between',
          'whereToLive': 'Open to moving abroad',
        }) ==
        '',
    'LOCK16 other four answers never become Browse text',
  );
  check(
    line({'marriedBefore': 'invented'}) == '',
    'LOCK16 invalid value is absent',
  );

  final retired = JourneyBio.retiredFieldIds;
  check(retired.length == 4, 'LOCK16 four retired Bio fields');
  check(
    journeyBioFieldDefinitions.every((field) => !retired.contains(field.id)),
    'LOCK16 active Bio prompts exclude retired fields',
  );
  check(
    SelahJourneyLifeSnapshotMock.fields.every(
      (field) => !retired.contains(field.id),
    ),
    'LOCK16 Bio display fixture excludes retired fields',
  );
  check(
    !SelahJourneyLifeSnapshotMock.defaultVisibleFieldIds.any(retired.contains),
    'LOCK16 Bio visibility defaults exclude retired fields',
  );
  final saved = JourneyBio(
    fieldValues: {for (final id in retired) id: 'Retained original answer'},
    visibleFieldIds: retired,
    reviewed: true,
  );
  final restored = JourneyBio.fromOnboardingAnswers(
    saved.toOnboardingAnswers(),
  );
  check(
    restored.fieldValues.length == 4 && restored.visibleFieldIds.length == 4,
    'LOCK16 preserves retired values and visibility in storage',
  );
  check(
    restored.isEmpty && restored.sharedItemCount == 0,
    'LOCK16 retired-only Bio is unused in content and counts',
  );
  final withOccupation = restored.copyWith(
    fieldValues: {...restored.fieldValues, 'occupation': 'Teacher'},
    visibleFieldIds: {...restored.visibleFieldIds, 'occupation'},
  );
  check(
    !withOccupation.isEmpty && withOccupation.sharedItemCount == 1,
    'LOCK16 retains other Bio display choices',
  );
}
