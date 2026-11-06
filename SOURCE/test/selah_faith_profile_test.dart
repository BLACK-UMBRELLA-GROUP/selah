import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:selah/config/selah_native_identity_policy.dart';
import 'package:selah/dev/selah_request_account_session.dart';
import 'package:selah/draft/selah_draft_runtime.dart';
import 'package:selah/models/selah_faith_profile.dart';
import 'package:selah/models/selah_faith_profile_controller.dart';
import 'package:selah/models/selah_faith_profile_details.dart';
import 'package:selah/services/selah_seeker_details_service.dart';
import 'package:selah/theme/selah_colors.dart';
import 'package:selah/theme/selah_interaction_style.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SelahFaithProfileAnswers valid() => SelahFaithProfileAnswers(
    tradition: 'Baptist',
    church: 'Most weeks',
    baptised: 'Not yet',
    christianFor: '5–10 years',
    serving: ['Prayer', 'Youth'],
    openness: 'Similar traditions only',
    words: 'Growing in faith.',
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
    'required errors clear on choice; optional serving has explicit Skip',
    () async {
      var calls = 0;
      final controller = SelahFaithProfileController(
        canAct: () => true,
        read: SelahFaithProfileAnswers.new,
        save: (_) {
          calls++;
          return true;
        },
      );
      addTearDown(controller.dispose);
      expect(controller.validateQuestion(1), isFalse);
      expect(controller.showRequiredErrorFor(1), isTrue);
      controller.choose(1, 1);
      expect(controller.showRequiredErrorFor(1), isFalse);
      expect(controller.validateQuestion(1), isTrue);
      controller.choose(5, 1);
      controller.choose(5, 5);
      expect(controller.answers.serving, ['Youth', 'Prayer']);
      controller.clearServing();
      expect(controller.answers.serving, isEmpty);
      expect(controller.validateQuestion(5), isTrue);
      expect(controller.validateQuestion(7), isTrue);
      expect(controller.validateQuestion(0), isFalse);
      expect(await controller.save(), isFalse);
      expect(controller.showRequiredErrorFor(2), isTrue);
      expect(calls, 0);
    },
  );

  test(
    'quote overflow remains editable and Skip saves an empty quote',
    () async {
      SelahFaithProfileAnswers? saved;
      final controller = SelahFaithProfileController(
        canAct: () => true,
        read: valid,
        save: (value) {
          saved = value;
          return true;
        },
      );
      addTearDown(controller.dispose);
      final overlength = List.filled(151, '🙏').join();
      controller.setWords(overlength);
      expect(controller.characterCount, 151);
      expect(controller.answers.words, overlength);
      expect(await controller.save(), isFalse);
      expect(controller.showLengthError, isTrue);
      expect(saved, isNull);
      controller.setWords(List.filled(150, '🙏').join());
      expect(await controller.save(), isTrue);
      expect(controller.showLengthError, isFalse);
      expect(saved!.characterCount, 150);
      controller.setWords(overlength);
      expect(await controller.save(skipWords: true), isTrue);
      expect(saved!.words, isEmpty);
      expect(controller.answers.words, isEmpty);
    },
  );

  test(
    'failed/throwing save retains draft and retry commits exactly once',
    () async {
      var attempt = 0;
      SelahFaithProfileAnswers? saved;
      final controller = SelahFaithProfileController(
        canAct: () => true,
        read: valid,
        save: (value) {
          attempt++;
          if (attempt == 1) return false;
          if (attempt == 2) throw StateError('local failure');
          saved = value;
          return true;
        },
      );
      addTearDown(controller.dispose);
      controller.choose(2, 0);
      expect(await controller.save(), isFalse);
      expect(controller.saveState, SelahFaithProfileSaveState.failed);
      expect(controller.answers.church, 'Every week');
      expect(await controller.save(), isFalse);
      expect(saved, isNull);
      expect(await controller.save(), isTrue);
      expect(controller.saveState, SelahFaithProfileSaveState.saved);
      expect(saved!.church, 'Every week');
      expect(attempt, 3);
    },
  );

  test(
    'real async save blocks duplicate submission and answer edits',
    () async {
      final completion = Completer<bool>();
      var calls = 0;
      final controller = SelahFaithProfileController(
        canAct: () => true,
        read: valid,
        save: (_) {
          calls++;
          return completion.future;
        },
      );
      addTearDown(controller.dispose);
      final saving = controller.save();
      expect(controller.saveState, SelahFaithProfileSaveState.saving);
      expect(await controller.save(), isFalse);
      controller.choose(2, 0);
      controller.clearServing();
      controller.setWords('changed while saving');
      expect(controller.answers.church, 'Most weeks');
      expect(controller.answers.serving, isNotEmpty);
      expect(controller.answers.words, 'Growing in faith.');
      completion.complete(true);
      expect(await saving, isTrue);
      expect(calls, 1);
    },
  );

  test(
    'revoked owner cannot receive stale completion or revive A B A',
    () async {
      var current = true;
      var notices = 0;
      final completion = Completer<bool>();
      final controller = SelahFaithProfileController(
        canAct: () => current,
        read: valid,
        save: (_) => completion.future,
      )..addListener(() => notices++);
      addTearDown(controller.dispose);
      final saving = controller.save();
      expect(notices, 1);
      current = false;
      expect(controller.answers.requiredComplete, isFalse);
      current = true;
      completion.complete(true);
      expect(await saving, isFalse);
      expect(notices, 1);
      expect(controller.answers.requiredComplete, isFalse);
      expect(await controller.save(), isFalse);
    },
  );

  test(
    'disposing during save cannot notify or complete into another owner',
    () async {
      var notices = 0;
      final completion = Completer<bool>();
      final controller = SelahFaithProfileController(
        canAct: () => true,
        read: valid,
        save: (_) => completion.future,
      )..addListener(() => notices++);
      final saving = controller.save();
      controller.dispose();
      completion.complete(true);
      expect(await saving, isFalse);
      expect(notices, 1);
      expect(controller.saveState, SelahFaithProfileSaveState.idle);
    },
  );

  test(
    'throwing owner/read fail closed without writes or notifications',
    () async {
      var writes = 0;
      var notices = 0;
      final ownerFailure = SelahFaithProfileController(
        canAct: () => throw StateError('no owner'),
        read: valid,
        save: (_) {
          writes++;
          return true;
        },
      )..addListener(() => notices++);
      addTearDown(ownerFailure.dispose);
      ownerFailure.choose(1, 0);
      expect(await ownerFailure.save(), isFalse);
      final readFailure = SelahFaithProfileController(
        canAct: () => true,
        read: () => throw StateError('no details'),
        save: (_) {
          writes++;
          return true;
        },
      )..addListener(() => notices++);
      addTearDown(readFailure.dispose);
      expect(await readFailure.save(), isFalse);
      expect(writes, 0);
      expect(notices, 0);
    },
  );

  test(
    'Saving/failure presets require real private runtime and current owner',
    () async {
      var current = true;
      final controller = SelahFaithProfileController(
        canAct: () => current,
        read: valid,
        save: (_) => true,
      );
      addTearDown(controller.dispose);
      controller.showSaving();
      controller.showFailure();
      expect(controller.saveState, SelahFaithProfileSaveState.idle);
      expect(
        SelahDraftRuntime.activate(bundleId: 'unapproved.bundle'),
        isFalse,
      );
      controller.showSaving();
      expect(controller.saveState, SelahFaithProfileSaveState.idle);
      expect(
        SelahDraftRuntime.activate(
          bundleId: SelahNativeIdentityPolicy.productionBundleId,
        ),
        isTrue,
        reason: 'Use --dart-define=SELAH_DRAFT_LOCAL_ONLY=true, no bypass.',
      );
      controller.showSaving();
      expect(controller.saveState, SelahFaithProfileSaveState.saving);
      expect(await controller.save(), isFalse);
      controller.showFailure();
      expect(controller.saveState, SelahFaithProfileSaveState.failed);
      expect(await controller.save(), isTrue);
      current = false;
      controller.showFailure();
      expect(controller.saveState, SelahFaithProfileSaveState.idle);
    },
  );

  test(
    'adapter keeps unrelated fields and exact answers across real row roundtrip',
    () {
      final existing = SeekerDetails(
        countryOfBirth: 'United Kingdom',
        nationality: 'British',
        ethnicity: 'Other',
        languages: ['English'],
        christianDenominationOther: 'old custom denomination',
        preferences: {
          'faith_journey': {'flexibility': 'red'},
          'location': {'preference': 'same_country', 'flexibility': 'green'},
          'unknown': {'key': 'retained'},
        },
      );
      final mapped = selahApplyFaithProfileAnswers(existing, valid());
      expect(mapped.christianFamily, 'Protestant');
      expect(mapped.christianDenomination, 'Baptist');
      expect(mapped.christianDenominationOther, isNull);
      expect(mapped.countryOfBirth, existing.countryOfBirth);
      expect(mapped.nationality, existing.nationality);
      expect(mapped.ethnicity, existing.ethnicity);
      expect(mapped.languages, existing.languages);
      expect(mapped.showChristianTraditionOnProfile, isTrue);
      expect(mapped.preferences['faith_journey'], {'flexibility': 'red'});
      expect(mapped.preferences['unknown'], {'key': 'retained'});
      final row = mapped.toRow('local-model-check');
      expect(row['christian_family_code'], 'protestant');
      expect(row['christian_denomination_code'], 'baptist');
      expect(row['faith_journey_code'], 'became_christian_later');
      final restored = SeekerDetails.fromRow(
        Map<String, dynamic>.from(jsonDecode(jsonEncode(row)) as Map),
      );
      final answers = selahFaithProfileAnswersFromDetails(restored);
      expect(answers.toMap(), valid().toMap());
      expect(restored.preferences['unknown'], {'key': 'retained'});
      expect(restored.preferences['faith_journey'], {'flexibility': 'red'});
    },
  );

  test(
    'old fields do not migrate into new answers; partial exact seed is supported',
    () {
      const oldOnly = SeekerDetails(
        christianFamily: 'Protestant',
        christianDenomination: 'Baptist',
        faithJourney: 'I was raised Christian',
      );
      expect(selahFaithProfileAnswersFromDetails(oldOnly).tradition, isNull);
      final owner = session(() => true);
      addTearDown(owner.dispose);
      expect(
        owner.seedDetails(
          const SeekerDetails(
            christianFamily: 'Protestant',
            christianDenomination: 'Baptist',
            preferences: {
              'faith_profile': {'tradition': 'Baptist'},
            },
          ),
        ),
        isTrue,
      );
      expect(owner.faithAnswers.tradition, 'Baptist');
      expect(owner.faithAnswers.church, isNull);
      expect(owner.seedDetails(oldOnly), isFalse);
      expect(owner.saveFaithProfile(valid()), isTrue);
      expect(owner.faithAnswers.toMap(), valid().toMap());
    },
  );

  test(
    'session detaches/locks saved data and rejects invalid/revoked updates',
    () {
      var current = true;
      var notices = 0;
      final owner = session(() => current)..addListener(() => notices++);
      addTearDown(owner.dispose);
      final raw = <String, dynamic>{
        'faith_profile': <String, dynamic>{'tradition': 'Baptist'},
      };
      expect(owner.seedDetails(SeekerDetails(preferences: raw)), isTrue);
      (raw['faith_profile'] as Map)['tradition'] = 'Catholic';
      expect(owner.faithAnswers.tradition, 'Baptist');
      expect(
        () => (owner.details.preferences['faith_profile'] as Map)['tradition'] =
            'Catholic',
        throwsUnsupportedError,
      );
      expect(owner.saveFaithProfile(SelahFaithProfileAnswers()), isFalse);
      expect(
        owner.saveFaithProfile(valid().withWords(List.filled(151, 'a').join())),
        isFalse,
      );
      expect(notices, 0);
      expect(owner.saveFaithProfile(valid()), isTrue);
      expect(notices, 1);
      expect(owner.details.christianFamily, 'Protestant');
      current = false;
      expect(owner.saveFaithProfile(valid()), isFalse);
      expect(owner.details.preferences, isEmpty);
      current = true;
      expect(owner.saveFaithProfile(valid()), isFalse);
      expect(owner.faithAnswers.requiredComplete, isFalse);
      expect(notices, 1);
    },
  );

  test('session disposal/new session clears local Faith answers', () {
    final owner = session(() => true);
    expect(owner.saveFaithProfile(valid()), isTrue);
    owner.dispose();
    expect(owner.details.preferences, isEmpty);
    expect(owner.saveFaithProfile(valid()), isFalse);
    final fresh = session(() => true);
    addTearDown(fresh.dispose);
    expect(fresh.faithAnswers.requiredComplete, isFalse);
  });
}
