import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:selah/config/selah_native_identity_policy.dart';
import 'package:selah/dev/selah_request_account_session.dart';
import 'package:selah/draft/selah_draft_runtime.dart';
import 'package:selah/models/selah_faith_profile.dart';
import 'package:selah/models/selah_marriage_values.dart';
import 'package:selah/models/selah_marriage_values_controller.dart';
import 'package:selah/models/selah_marriage_values_details.dart';
import 'package:selah/services/selah_seeker_details_service.dart';
import 'package:selah/theme/selah_colors.dart';
import 'package:selah/theme/selah_interaction_style.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SelahMarriageValuesAnswers complete() => SelahMarriageValuesAnswers(
    marriedBefore: 'I’d rather share later',
    children: 'Yes, they don’t live with me',
    wouldLikeChildren: 'Open to it',
    rolesInMarriage: 'Equal partners who decide together',
    openToDivorced: 'It depends on the situation',
    whereToLive: 'Open to moving abroad',
    hopingToMarry: 'When it’s the right person',
  );
  SelahRequestAccountSession session(bool Function() canAct) =>
      SelahRequestAccountSession(
        canAct: canAct,
        palette: SelahDevPalette.stillWater,
        hapticLevel: SelahHapticLevel.off,
        goldEnabled: false,
      );
  tearDown(SelahDraftRuntime.stop);

  test(
    'all seven required questions validate without an optional Skip',
    () async {
      var writes = 0;
      final controller = SelahMarriageValuesController(
        canAct: () => true,
        read: SelahMarriageValuesAnswers.new,
        save: (_) {
          writes++;
          return true;
        },
      );
      addTearDown(controller.dispose);
      for (var question = 1; question <= 7; question++) {
        expect(controller.validateQuestion(question), isFalse);
        expect(controller.showRequiredErrorFor(question), isTrue);
        expect(await controller.save(), isFalse);
        controller.choose(question, 0);
        expect(controller.showRequiredErrorFor(question), isFalse);
        expect(controller.validateQuestion(question), isTrue);
      }
      expect(controller.validateQuestion(0), isFalse);
      expect(controller.validateQuestion(8), isFalse);
      expect(writes, 0);
      expect(await controller.save(), isTrue);
      expect(controller.saveState, SelahMarriageValuesSaveState.saved);
      expect(writes, 1);
    },
  );

  test(
    'failed and throwing saves preserve choices for an exact retry',
    () async {
      var attempt = 0;
      SelahMarriageValuesAnswers? saved;
      final controller = SelahMarriageValuesController(
        canAct: () => true,
        read: complete,
        save: (answers) {
          attempt++;
          if (attempt == 1) return false;
          if (attempt == 2) throw StateError('local failure');
          saved = answers;
          return true;
        },
      );
      addTearDown(controller.dispose);
      controller.choose(5, 0);
      expect(await controller.save(), isFalse);
      expect(controller.saveState, SelahMarriageValuesSaveState.failed);
      expect(controller.answers.openToDivorced, 'Yes');
      expect(await controller.save(), isFalse);
      expect(saved, isNull);
      expect(await controller.save(), isTrue);
      expect(saved!.openToDivorced, 'Yes');
      expect(attempt, 3);
    },
  );

  test(
    'real pending save blocks duplicate writes and draft mutations',
    () async {
      var calls = 0;
      final completion = Completer<bool>();
      final controller = SelahMarriageValuesController(
        canAct: () => true,
        read: complete,
        save: (_) {
          calls++;
          return completion.future;
        },
      );
      addTearDown(controller.dispose);
      final saving = controller.save();
      expect(controller.saveState, SelahMarriageValuesSaveState.saving);
      controller.choose(1, 0);
      expect(controller.answers.marriedBefore, 'I’d rather share later');
      expect(await controller.save(), isFalse);
      completion.complete(true);
      expect(await saving, isTrue);
      expect(calls, 1);
    },
  );

  test('revoked pending owner cannot notify or revive A B A', () async {
    var current = true;
    var notices = 0;
    final completion = Completer<bool>();
    final controller = SelahMarriageValuesController(
      canAct: () => current,
      read: complete,
      save: (_) => completion.future,
    )..addListener(() => notices++);
    addTearDown(controller.dispose);
    final saving = controller.save();
    expect(notices, 1);
    current = false;
    expect(controller.answers.canSave, isFalse);
    current = true;
    completion.complete(true);
    expect(await saving, isFalse);
    expect(await controller.save(), isFalse);
    expect(notices, 1);
  });

  test('disposed and throwing owner/read fail closed', () async {
    var writes = 0;
    var notices = 0;
    final completion = Completer<bool>();
    final pending = SelahMarriageValuesController(
      canAct: () => true,
      read: complete,
      save: (_) => completion.future,
    )..addListener(() => notices++);
    final saving = pending.save();
    pending.dispose();
    completion.complete(true);
    expect(await saving, isFalse);
    expect(notices, 1);
    for (final readThrows in [false, true]) {
      final denied = SelahMarriageValuesController(
        canAct: () => readThrows ? true : throw StateError('owner unavailable'),
        read: () => throw StateError('read unavailable'),
        save: (_) {
          writes++;
          return true;
        },
      )..addListener(() => notices++);
      denied.choose(1, 0);
      expect(await denied.save(), isFalse);
      denied.dispose();
    }
    expect(writes, 0);
    expect(notices, 1);
  });

  test(
    'private saving/failure presets require actual runtime and owner',
    () async {
      var current = true;
      final controller = SelahMarriageValuesController(
        canAct: () => current,
        read: complete,
        save: (_) => true,
      );
      addTearDown(controller.dispose);
      controller.showSaving();
      controller.showFailure();
      expect(controller.saveState, SelahMarriageValuesSaveState.idle);
      expect(
        SelahDraftRuntime.activate(bundleId: 'unapproved.bundle'),
        isFalse,
      );
      controller.showSaving();
      expect(controller.saveState, SelahMarriageValuesSaveState.idle);
      expect(
        SelahDraftRuntime.activate(
          bundleId: SelahNativeIdentityPolicy.productionBundleId,
        ),
        isTrue,
        reason: 'Use actual SELAH_DRAFT_LOCAL_ONLY=true, no guard bypass.',
      );
      controller.showSaving();
      expect(controller.saveState, SelahMarriageValuesSaveState.saving);
      expect(await controller.save(), isFalse);
      controller.showFailure();
      expect(controller.saveState, SelahMarriageValuesSaveState.failed);
      expect(await controller.save(), isTrue);
      current = false;
      controller.showFailure();
      expect(controller.saveState, SelahMarriageValuesSaveState.idle);
    },
  );

  test(
    'exact new fields round trip without changing retained details or contracts',
    () {
      final original = SeekerDetails(
        christianFamily: 'Protestant',
        christianDenomination: 'Baptist',
        christianDenominationOther: 'retained',
        faithJourney: 'I was raised Christian',
        showChristianTraditionOnProfile: true,
        countryOfBirth: 'United Kingdom',
        nationality: 'British',
        ethnicity: 'Other',
        languages: ['English'],
        preferences: {
          'faith_profile': {'tradition': 'Baptist', 'church': 'Every week'},
          'faith_journey': {'flexibility': 'red'},
          'ch3': {'ch3_q1': 'Never Married', 'ch3_q70': 'old role'},
          'ch4': {'Divorced': 'old preference'},
          'marriage_values': {'unknown': 'preserve'},
        },
      );
      final mapped = selahApplyMarriageValuesAnswers(original, complete());
      expect(mapped.christianFamily, original.christianFamily);
      expect(mapped.christianDenomination, original.christianDenomination);
      expect(
        mapped.christianDenominationOther,
        original.christianDenominationOther,
      );
      expect(mapped.faithJourney, original.faithJourney);
      expect(
        mapped.showChristianTraditionOnProfile,
        original.showChristianTraditionOnProfile,
      );
      expect(mapped.countryOfBirth, original.countryOfBirth);
      expect(mapped.nationality, original.nationality);
      expect(mapped.ethnicity, original.ethnicity);
      expect(mapped.languages, original.languages);
      for (final key in ['faith_profile', 'faith_journey', 'ch3', 'ch4']) {
        expect(mapped.preferences[key], original.preferences[key]);
      }
      final restored = SeekerDetails.fromRow(
        Map<String, dynamic>.from(
          jsonDecode(jsonEncode(mapped.toRow('local-model-check'))) as Map,
        ),
      );
      expect(
        selahMarriageValuesAnswersFromDetails(restored).toMap(),
        complete().toMap(),
      );
      expect(
        (restored.preferences['marriage_values'] as Map)['unknown'],
        'preserve',
      );
      expect(selahMarriageValuesAnswersFromDetails(original).canSave, isFalse);
    },
  );

  test(
    'one session owner preserves Faith when saving marriage and vice versa',
    () {
      final owner = session(() => true);
      addTearDown(owner.dispose);
      final faith = SelahFaithProfileAnswers(
        tradition: 'Baptist',
        church: 'Every week',
        baptised: 'Yes',
        christianFor: 'All my life',
        openness: 'Similar traditions only',
      );
      expect(owner.saveFaithProfile(faith), isTrue);
      expect(owner.saveMarriageValues(complete()), isTrue);
      expect(owner.faithAnswers.toMap(), faith.toMap());
      expect(owner.marriageAnswers.toMap(), complete().toMap());
      final changedFaith = faith.choose(2, 1);
      expect(owner.saveFaithProfile(changedFaith), isTrue);
      expect(owner.marriageAnswers.toMap(), complete().toMap());
      expect(owner.faithAnswers.toMap(), changedFaith.toMap());
      expect(
        () =>
            (owner.details.preferences['marriage_values'] as Map)['children'] =
                'No',
        throwsUnsupportedError,
      );
    },
  );

  test(
    'incomplete/revoked/session disposal cannot save or leak old marriage data',
    () {
      var current = true;
      var notices = 0;
      final owner = session(() => current)..addListener(() => notices++);
      expect(owner.saveMarriageValues(SelahMarriageValuesAnswers()), isFalse);
      expect(notices, 0);
      expect(owner.saveMarriageValues(complete()), isTrue);
      expect(notices, 1);
      current = false;
      expect(owner.saveMarriageValues(complete()), isFalse);
      current = true;
      expect(owner.marriageAnswers.canSave, isFalse);
      expect(owner.saveMarriageValues(complete()), isFalse);
      expect(notices, 1);
      owner.dispose();
      expect(owner.saveMarriageValues(complete()), isFalse);
      final fresh = session(() => true);
      addTearDown(fresh.dispose);
      expect(fresh.marriageAnswers.canSave, isFalse);
    },
  );
}
