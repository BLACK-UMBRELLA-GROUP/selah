import 'package:flutter_test/flutter_test.dart';
import 'package:selah/dev/selah_request_account_session.dart';
import 'package:selah/models/journey_bio.dart';
import 'package:selah/models/onboarding_question.dart';
import 'package:selah/models/selah_faith_profile.dart';
import 'package:selah/models/selah_marriage_values.dart';
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
  SelahFaithProfileAnswers faith() => SelahFaithProfileAnswers(
    tradition: 'Baptist',
    church: 'Every week',
    baptised: 'Yes',
    christianFor: 'All my life',
    serving: ['Prayer'],
    openness: 'Similar traditions only',
    words: 'My saved faith words.',
  );
  SelahMarriageValuesAnswers marriage() => SelahMarriageValuesAnswers(
    marriedBefore: 'No',
    children: 'No',
    wouldLikeChildren: 'Open to it',
    rolesInMarriage: 'Equal partners who decide together',
    openToDivorced: 'No',
    whereToLive: 'Open to moving abroad',
    hopingToMarry: 'In 1–2 years',
  );

  test(
    'consent Skip clears current Faith while preserving nonfaith and retired storage',
    () async {
      final owner = session(() => true);
      addTearDown(owner.dispose);
      expect(
        owner.seedDetails(
          const SeekerDetails(
            countryOfBirth: 'United Kingdom',
            nationality: 'British',
            ethnicity: 'Other',
            preferences: {
              'location': {
                'preference': 'same_country',
                'flexibility': 'yellow',
              },
              'faith_journey': {'flexibility': 'red'},
              'country_of_birth': {
                'preferred': ['GB'],
                'unknown': 'retain',
              },
              'unknown': {'retain': true},
            },
          ),
        ),
        isTrue,
      );
      expect(owner.saveFaithProfile(faith()), isTrue);
      expect(owner.saveMarriageValues(marriage()), isTrue);
      expect(owner.saveLanguages(['English', 'French']), isTrue);
      const photos = ['data:image/jpeg;base64,local-fixture'];
      expect(owner.setPhotos(false, photos), isTrue);
      final oldBank = SelahOnboardingAnswersSnapshot(
        ch3Answers: {
          'ch3_q46': 'Catholic',
          'ch3_q39': 'Most weeks',
          'ch3_q40': 'Regularly',
          'ch3_q1': 'Divorced',
          'ch3_q3': 'No',
        },
        ch4Preferences: {
          'ch3_q1': {'Divorced': TrafficLight.green},
          'ch3_q46': {'Catholic': TrafficLight.yellow},
        },
        ch4HardRequirements: {
          'ch3_q1': {'Divorced'},
        },
        journeyBio: const JourneyBio(),
      );
      final draft = SelahCompatibilityDraft.fromSnapshot(
        gender: 'male',
        snapshot: oldBank,
        readSignUpPreferences: () => owner.compatibility.signUpPreferences,
      );
      expect(await owner.compatibility.save('draft-self', draft), isTrue);
      final storedBank = await owner.compatibility.load('draft-self');
      expect(draft.compatibilityAnswers['ch3_q46'], 'Baptist');
      final before = owner.details;
      var notices = 0;
      owner.addListener(() => notices++);
      expect(owner.clearFaithProfile(), isTrue);
      expect(notices, 1);
      expect(owner.details.christianFamily, isNull);
      expect(owner.details.christianDenomination, isNull);
      expect(owner.details.christianDenominationOther, isNull);
      expect(owner.details.faithJourney, isNull);
      expect(owner.details.showChristianTraditionOnProfile, isFalse);
      expect(owner.details.preferences.containsKey('faith_profile'), isFalse);
      expect(
        owner.details.preferences.containsKey('church_background'),
        isFalse,
      );
      expect(owner.faithAnswers.requiredComplete, isFalse);
      expect(owner.faithAnswers.tradition, isNull);
      expect(owner.faithAnswers.church, isNull);
      expect(owner.faithAnswers.serving, isEmpty);
      expect(owner.faithAnswers.words, isEmpty);
      expect(owner.marriageAnswers.toMap(), marriage().toMap());
      expect(owner.details.languages, before.languages);
      expect(owner.details.countryOfBirth, before.countryOfBirth);
      expect(owner.details.nationality, before.nationality);
      expect(owner.details.ethnicity, before.ethnicity);
      for (final key in [
        'location',
        'faith_journey',
        'country_of_birth',
        'unknown',
      ]) {
        expect(
          owner.details.preferences[key],
          before.preferences[key],
          reason: 'retained $key',
        );
      }
      expect(owner.photos(false), photos);
      for (final id in ['ch3_q46', 'ch3_q39', 'ch3_q40']) {
        expect(
          draft.compatibilityAnswers.containsKey(id),
          isFalse,
          reason: 'no old $id fallback after Skip',
        );
      }
      expect(draft.compatibilityAnswers['ch3_q1'], 'Never Married');
      final afterBank = await owner.compatibility.load('draft-self');
      expect(afterBank!.ch3Answers, storedBank!.ch3Answers);
      expect(afterBank.ch4Preferences, storedBank.ch4Preferences);
      expect(afterBank.ch4HardRequirements, storedBank.ch4HardRequirements);
      expect(owner.clearFaithProfile(), isTrue);
      expect(
        notices,
        1,
        reason: 'already-cleared Skip does not emit a duplicate update',
      );
    },
  );

  test(
    'revoked/throwing owners cannot clear or revive; disposed clear is denied',
    () {
      for (final throws in [false, true]) {
        var current = true;
        final owner = session(
          () => current
              ? true
              : throws
              ? throw StateError('owner gone')
              : false,
        );
        expect(owner.saveFaithProfile(faith()), isTrue);
        final before = owner.details;
        var notices = 0;
        owner.addListener(() => notices++);
        current = false;
        expect(owner.clearFaithProfile(), isFalse);
        current = true;
        expect(owner.clearFaithProfile(), isFalse);
        expect(notices, 0);
        expect(before.christianFamily, 'Protestant');
        expect(before.preferences.containsKey('faith_profile'), isTrue);
        owner.dispose();
        expect(owner.clearFaithProfile(), isFalse);
      }
    },
  );
}
