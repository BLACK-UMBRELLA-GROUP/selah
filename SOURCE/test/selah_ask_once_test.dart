import 'package:flutter_test/flutter_test.dart';
import 'package:selah/data/chapter3_categories.dart';
import 'package:selah/dev/selah_request_account_session.dart';
import 'package:selah/models/journey_bio.dart';
import 'package:selah/models/onboarding_question.dart';
import 'package:selah/models/selah_marriage_values.dart';
import 'package:selah/models/selah_sign_up_compatibility.dart';
import 'package:selah/screens/profile/compatibility_editors.dart';
import 'package:selah/services/selah_onboarding_answers_service.dart';
import 'package:selah/services/selah_seeker_details_service.dart';
import 'package:selah/theme/selah_colors.dart';
import 'package:selah/theme/selah_interaction_style.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SelahRequestAccountSession session(bool Function() canAct) =>
      SelahRequestAccountSession(
        canAct: canAct,
        palette: SelahDevPalette.stillWater,
        hapticLevel: SelahHapticLevel.off,
        goldEnabled: false,
      );
  final childrenCategory = chapter3Categories.singleWhere(
    (category) => category.id == 'children_parenting',
  );
  SelahMarriageValuesAnswers complete(String wouldLikeChildren) =>
      SelahMarriageValuesAnswers(
        marriedBefore: 'No',
        children: 'No',
        wouldLikeChildren: wouldLikeChildren,
        rolesInMarriage: 'Somewhere in between',
        openToDivorced: 'No',
        whereToLive: 'Near where I live now',
        hopingToMarry: 'Within a year',
      );
  SelahOnboardingAnswersSnapshot oldSnapshot() =>
      SelahOnboardingAnswersSnapshot(
        ch3Answers: {
          for (final id in selahSignUpQuestionIds) id: 'old bank value',
          'ch3_q24': 'old child timing',
        },
        ch4Preferences: {
          'ch3_q1': {
            'Divorced': TrafficLight.green,
            'Never Married': TrafficLight.green,
          },
          'ch3_q2': {'No': TrafficLight.yellow},
        },
        ch4HardRequirements: {
          'ch3_q1': {'Divorced'},
          'ch3_q2': {'No'},
        },
        journeyBio: const JourneyBio(),
      );

  test(
    'current owner projection changes q24 visibility without another saved copy',
    () {
      final owner = session(() => true);
      addTearDown(owner.dispose);
      expect(owner.saveMarriageValues(complete('No')), isTrue);
      final draft = SelahCompatibilityDraft.fromSnapshot(
        gender: 'male',
        snapshot: oldSnapshot(),
        readSignUpPreferences: () => owner.compatibility.signUpPreferences,
      );
      expect(draft.compatibilityAnswers['ch3_q3'], 'No');
      expect(
        draft
            .visibleQuestions(childrenCategory)
            .any((question) => question.id == 'ch3_q24'),
        isFalse,
      );
      expect(owner.saveMarriageValues(complete('Open to it')), isTrue);
      expect(draft.compatibilityAnswers['ch3_q3'], 'If God wills');
      expect(
        draft
            .visibleQuestions(childrenCategory)
            .any((question) => question.id == 'ch3_q24'),
        isTrue,
      );
      expect(draft.copy().compatibilityAnswers['ch3_q3'], 'If God wills');
    },
  );

  test(
    'retired raw answers/preferences survive save/load but never override signup',
    () async {
      final owner = session(() => true);
      addTearDown(owner.dispose);
      expect(owner.saveMarriageValues(complete('Open to it')), isTrue);
      final snapshot = oldSnapshot();
      final draft = SelahCompatibilityDraft.fromSnapshot(
        gender: 'male',
        snapshot: snapshot,
        readSignUpPreferences: () => owner.compatibility.signUpPreferences,
      );
      expect(draft.compatibilityAnswers['ch3_q1'], 'Never Married');
      expect(draft.compatibilityAnswers.containsKey('ch3_q46'), isFalse);
      expect(draft.compatibilityPreferences['ch3_q1'], {
        'Divorced': TrafficLight.red,
      });
      expect(
        draft.compatibilityHardRequirements.containsKey('ch3_q1'),
        isFalse,
      );
      expect(
        draft.compatibilityPreferences['ch3_q2'],
        snapshot.ch4Preferences['ch3_q2'],
      );
      expect(draft.compatibilityHardRequirements['ch3_q2'], {'No'});
      final retired = chapter3CompatibilityCategories
          .expand((category) => category.questions)
          .firstWhere((question) => question.id == 'ch3_q1');
      draft.setAnswer(retired, 'Divorced');
      expect(draft.answers['ch3_q1'], 'old bank value');
      expect(await owner.compatibility.save('draft-self', draft), isTrue);
      draft.answers['ch3_q1'] = 'caller mutation';
      final restored = await owner.compatibility.load('draft-self');
      for (final id in selahSignUpQuestionIds) {
        expect(
          restored!.ch3Answers[id],
          'old bank value',
          reason: 'raw $id retained',
        );
      }
      expect(
        restored!.ch4Preferences['ch3_q1'],
        snapshot.ch4Preferences['ch3_q1'],
      );
      expect(restored.ch4HardRequirements['ch3_q1'], {'Divorced'});
      final nextDraft = SelahCompatibilityDraft.fromSnapshot(
        gender: 'male',
        snapshot: restored,
        readSignUpPreferences: () => owner.compatibility.signUpPreferences,
      );
      expect(nextDraft.compatibilityAnswers['ch3_q1'], 'Never Married');
    },
  );

  test(
    'missing signup remains neutral even with complete retired bank values',
    () {
      final draft = SelahCompatibilityDraft.fromSnapshot(
        gender: 'female',
        snapshot: oldSnapshot(),
      );
      expect(
        draft.compatibilityAnswers.keys.toSet().intersection(
          selahSignUpQuestionIds,
        ),
        isEmpty,
      );
      expect(draft.compatibilityPreferences.containsKey('ch3_q1'), isFalse);
      expect(
        draft.compatibilityHardRequirements.containsKey('ch3_q1'),
        isFalse,
      );
      expect(
        draft
            .visibleQuestions(childrenCategory)
            .any((question) => question.id == 'ch3_q24'),
        isTrue,
      );
      expect(draft.toSnapshot().ch3Answers['ch3_q3'], 'old bank value');
    },
  );

  test(
    'revoked repository hides projection and cannot revive for another account',
    () async {
      var current = true;
      final owner = session(() => current);
      addTearDown(owner.dispose);
      expect(owner.saveMarriageValues(complete('No')), isTrue);
      final draft = SelahCompatibilityDraft.fromSnapshot(
        gender: 'male',
        snapshot: oldSnapshot(),
        readSignUpPreferences: () => owner.compatibility.signUpPreferences,
      );
      expect(draft.compatibilityAnswers['ch3_q3'], 'No');
      current = false;
      expect(draft.compatibilityAnswers.containsKey('ch3_q3'), isFalse);
      current = true;
      expect(owner.compatibility.signUpPreferences, isEmpty);
      expect(await owner.compatibility.save('draft-self', draft), isFalse);
      expect(await owner.compatibility.load('draft-self'), isNull);
    },
  );

  test('throwing optional owner reader cannot expose stale bank answers', () {
    final draft = SelahCompatibilityDraft.fromSnapshot(
      gender: 'male',
      snapshot: oldSnapshot(),
      readSignUpPreferences: () => throw StateError('owner unavailable'),
    );
    expect(
      draft.compatibilityAnswers.keys.toSet().intersection(
        selahSignUpQuestionIds,
      ),
      isEmpty,
    );
    expect(draft.compatibilityPreferences.containsKey('ch3_q1'), isFalse);
    expect(draft.toSnapshot().ch3Answers['ch3_q1'], 'old bank value');
  });

  test(
    'languages uses the same guarded details owner and preserves signup values',
    () {
      var current = true;
      var notices = 0;
      final owner = session(() => current)..addListener(() => notices++);
      addTearDown(owner.dispose);
      expect(
        owner.seedDetails(
          const SeekerDetails(
            christianFamily: 'Protestant',
            faithJourney: 'I was raised Christian',
            preferences: {
              'faith_profile': {'tradition': 'Baptist'},
              'unknown': {'keep': true},
            },
          ),
        ),
        isTrue,
      );
      expect(owner.saveMarriageValues(complete('No')), isTrue);
      notices = 0;
      expect(owner.saveLanguages([]), isFalse);
      expect(owner.saveLanguages(['invented language']), isFalse);
      expect(notices, 0);
      final input = ['English', 'French', 'English'];
      expect(owner.saveLanguages(input), isTrue);
      input.add('Spanish');
      expect(owner.details.languages, ['English', 'French']);
      expect(
        () => owner.details.languages.add('Spanish'),
        throwsUnsupportedError,
      );
      expect(owner.faithAnswers.tradition, 'Baptist');
      expect(owner.marriageAnswers.toMap(), complete('No').toMap());
      expect(owner.details.preferences['unknown'], {'keep': true});
      expect(owner.details.christianFamily, 'Protestant');
      expect(owner.details.faithJourney, 'I was raised Christian');
      expect(notices, 1);
      current = false;
      expect(owner.saveLanguages(['Spanish']), isFalse);
      current = true;
      expect(owner.saveLanguages(['Spanish']), isFalse);
      expect(owner.details.languages, isEmpty);
      expect(notices, 1);
    },
  );
}
