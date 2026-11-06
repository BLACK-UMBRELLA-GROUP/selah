import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selah/config/selah_native_identity_policy.dart';
import 'package:selah/data/chapter3_categories.dart';
import 'package:selah/dev/selah_request_account_session.dart';
import 'package:selah/draft/selah_draft_runtime.dart';
import 'package:selah/models/journey_bio.dart';
import 'package:selah/models/onboarding_question.dart';
import 'package:selah/models/selah_your_values.dart';
import 'package:selah/models/selah_your_values_controller.dart';
import 'package:selah/screens/profile/compatibility_editors.dart';
import 'package:selah/services/selah_onboarding_answers_service.dart';

class _Owner {
  bool allowed = true;
  bool throws = false;
  bool success = true;
  bool writeThrows = false;
  int reads = 0;
  int writes = 0;
  Completer<bool>? pending;
  Map<String, dynamic> answers = {};
  Map<String, dynamic> signup = {};
  Map<String, Set<String>> hard = {};
  late final controller = SelahYourValuesController(
    canAct: () {
      if (throws) throw StateError('owner changed');
      return allowed;
    },
    gender: 'male',
    readAnswers: () {
      reads++;
      return answers;
    },
    readSignUpPreferences: () => signup,
    readHardRequirements: () => hard,
    onSavePart: (partId, patch) async {
      writes++;
      if (writeThrows) throw StateError('save failed');
      final saved = pending == null ? success : await pending!.future;
      if (!saved || !allowed) return false;
      final next = selahMergeYourValuesPart(
        existing: answers,
        gender: 'male',
        partId: partId,
        answers: patch,
        signUpPreferences: signup,
      );
      if (next == null) return false;
      answers = next;
      return true;
    },
    onSaveDealbreakers: (rules) async {
      writes++;
      if (writeThrows) throw StateError('save failed');
      final saved = pending == null ? success : await pending!.future;
      if (!saved || !allowed) return false;
      hard = selahMergeDealbreakers(existing: hard, requirements: rules)!;
      return true;
    },
  );
  void fill(String partId) {
    for (final question in controller.questionsFor(partId)) {
      if (question.selfAnswerOptional) {
        controller.skip(question);
      } else {
        controller.choose(question, 0);
      }
    }
  }

  Future<void> finishParts() async {
    for (final part in chapter3Categories) {
      fill(part.id);
      expect(await controller.savePart(part.id), isTrue);
    }
  }
}

SelahYourValuesController _forRepository(
  SelahRequestCompatibilityRepository repo,
) => SelahYourValuesController(
  canAct: () => repo.isCurrentOwner('draft-self', 0),
  gender: 'male',
  readAnswers: () => repo.rawAnswers,
  readSignUpPreferences: () => repo.signUpPreferences,
  readHardRequirements: () => repo.rawHardRequirements,
  readDealbreakersSaved: () => repo.dealbreakersSaved,
  onSavePart: repo.saveYourValuesPart,
  onSaveDealbreakers: repo.saveDealbreakers,
);

Future<void> _saveAllParts(SelahYourValuesController controller) async {
  for (final part in controller.parts) {
    for (final question in controller.questionsFor(part.id)) {
      if (question.selfAnswerOptional) {
        controller.skip(question);
      } else {
        controller.choose(question, 0);
      }
    }
    expect(await controller.savePart(part.id), isTrue);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(SelahDraftRuntime.stop);
  test(
    'lazy initial read; required error clears on a real valid choice and optionality is independent',
    () async {
      final owner = _Owner();
      addTearDown(owner.controller.dispose);
      expect(owner.reads, 0);
      final questions = owner.controller.questionsFor('faith_practice');
      expect(owner.reads, 1);
      expect(owner.controller.validate(questions.first), isFalse);
      expect(owner.controller.showRequiredError, isTrue);
      owner.controller.choose(questions.first, 0);
      expect(owner.controller.showRequiredError, isFalse);
      expect(owner.controller.validate(questions.first), isTrue);
      for (final question in questions.where(
        (question) => question.selfAnswerOptional,
      )) {
        expect(owner.controller.validate(question), isTrue);
        owner.controller.choose(question, 1);
        owner.controller.skip(question);
        expect(owner.controller.answerFor(question), isNull);
      }
      owner.controller.skip(questions.first);
      expect(
        owner.controller.answerFor(questions.first),
        questions.first.options.first,
      );
    },
  );
  test(
    'a part becomes Done only after a successful actual write; failure/retry keeps answers',
    () async {
      final owner = _Owner()..success = false;
      addTearDown(owner.controller.dispose);
      owner.fill('faith_practice');
      expect(owner.controller.isPartDone('faith_practice'), isFalse);
      expect(await owner.controller.savePart('faith_practice'), isFalse);
      expect(owner.controller.saveState, SelahYourValuesSaveState.failed);
      expect(owner.controller.isPartDone('faith_practice'), isFalse);
      owner.success = true;
      expect(await owner.controller.savePart('faith_practice'), isTrue);
      expect(owner.controller.isPartDone('faith_practice'), isTrue);
      expect(owner.controller.questionsRemaining, 22);
      expect(owner.writes, 2);
    },
  );
  test(
    'one part save preserves other parts, hidden q24, retired answers, and separately changed sign-up',
    () async {
      final owner = _Owner();
      owner.answers = {
        'ch3_q12': 'retired income',
        'ch3_q24': 'After 3 years',
        'ch3_q52': "I don't smoke or vape",
      };
      owner.signup = {
        'marriage_values': {'wouldLikeChildren': 'No'},
      };
      addTearDown(owner.controller.dispose);
      owner.fill('faith_practice');
      owner.signup['faith_profile'] = {'tradition': 'Baptist'};
      expect(await owner.controller.savePart('faith_practice'), isTrue);
      expect(owner.answers['ch3_q12'], 'retired income');
      expect(owner.answers['ch3_q24'], 'After 3 years');
      expect(owner.answers['ch3_q52'], "I don't smoke or vape");
      expect((owner.signup['faith_profile'] as Map)['tradition'], 'Baptist');
      expect(
        owner.controller
            .questionsFor('marriage_intentions')
            .map((question) => question.id),
        isNot(contains('ch3_q24')),
      );
      owner.signup = {
        'marriage_values': {'wouldLikeChildren': 'Yes'},
      };
      expect(
        owner.controller
            .questionsFor('marriage_intentions')
            .map((question) => question.id),
        contains('ch3_q24'),
      );
    },
  );
  test(
    'pending write locks answer edits, duplicate saves and private presets',
    () async {
      SelahDraftRuntime.activate(
        bundleId: SelahNativeIdentityPolicy.productionBundleId,
      );
      final owner = _Owner()..pending = Completer<bool>();
      addTearDown(owner.controller.dispose);
      owner.fill('faith_practice');
      final question = owner.controller.questionsFor('faith_practice').first;
      final before = owner.controller.answerFor(question);
      final saving = owner.controller.savePart('faith_practice');
      owner.controller.choose(question, 1);
      owner.controller.showFailure(partId: 'faith_practice');
      expect(await owner.controller.savePart('faith_practice'), isFalse);
      expect(owner.writes, 1);
      expect(owner.controller.answerFor(question), before);
      expect(owner.controller.saveState, SelahYourValuesSaveState.saving);
      owner.pending!.complete(true);
      expect(await saving, isTrue);
    },
  );
  test(
    'revocation while awaiting write cannot mark Done or publish old results; ABA stays denied',
    () async {
      final owner = _Owner()..pending = Completer<bool>();
      addTearDown(owner.controller.dispose);
      owner.fill('faith_practice');
      final saving = owner.controller.savePart('faith_practice');
      var notices = 0;
      owner.controller.addListener(() => notices++);
      owner.allowed = false;
      expect(owner.controller.current, isFalse);
      owner.pending!.complete(true);
      expect(await saving, isFalse);
      owner.allowed = true;
      expect(owner.controller.current, isFalse);
      expect(owner.controller.isPartDone('faith_practice'), isFalse);
      expect(owner.answers, isEmpty);
      expect(notices, 0);
    },
  );
  test(
    'throwing owner/read/write and disposal fail closed without fabricated completion',
    () async {
      final owner = _Owner()..throws = true;
      expect(owner.controller.parts, isEmpty);
      expect(owner.reads, 0);
      owner.controller.dispose();
      final failure = _Owner()..writeThrows = true;
      failure.fill('faith_practice');
      expect(await failure.controller.savePart('faith_practice'), isFalse);
      expect(failure.controller.saveState, SelahYourValuesSaveState.failed);
      failure.controller.dispose();
      expect(await failure.controller.savePart('faith_practice'), isFalse);
      expect(failure.controller.selectedDealbreakers, isEmpty);
    },
  );
  test(
    'private presets require actual draft runtime and do not fill or save answers',
    () {
      final owner = _Owner();
      addTearDown(owner.controller.dispose);
      owner.controller.showFailure(partId: 'faith_practice');
      expect(owner.controller.saveState, SelahYourValuesSaveState.idle);
      SelahDraftRuntime.activate(
        bundleId: SelahNativeIdentityPolicy.productionBundleId,
      );
      owner.controller.showSaving(partId: 'faith_practice');
      expect(owner.controller.saveState, SelahYourValuesSaveState.saving);
      owner.controller.showFailure(partId: 'faith_practice');
      expect(owner.controller.saveState, SelahYourValuesSaveState.failed);
      owner.controller.showFailure(partId: 'dealbreakers');
      expect(owner.controller.savingPartId, 'faith_practice');
      expect(owner.answers, isEmpty);
      expect(owner.controller.allPartsDone, isFalse);
      expect(owner.writes, 0);
    },
  );
  test(
    'deal-breakers cannot open/save before real completion; None is exclusive and clears active rules only',
    () async {
      final owner = _Owner();
      owner.hard = {
        'retired': {'keep'},
      };
      addTearDown(owner.controller.dispose);
      owner.controller.toggleDealbreaker(0);
      expect(owner.controller.selectedDealbreakers, isEmpty);
      expect(await owner.controller.saveDealbreakers(), isFalse);
      await owner.finishParts();
      owner.controller.toggleDealbreaker(0);
      owner.controller.toggleDealbreaker(3);
      expect(owner.controller.selectedDealbreakers, {0, 3});
      owner.controller.toggleDealbreaker(5);
      expect(owner.controller.selectedDealbreakers, {5});
      owner.controller.toggleDealbreaker(1);
      expect(owner.controller.selectedDealbreakers, {1});
      expect(await owner.controller.saveDealbreakers(), isTrue);
      expect(owner.hard['ch3_q53'], {
        'I drink occasionally',
        'I drink socially in moderation',
      });
      expect(owner.controller.dealbreakersDone, isTrue);
      owner.controller.toggleDealbreaker(5);
      expect(await owner.controller.saveDealbreakers(), isTrue);
      expect(owner.hard, {
        'retired': {'keep'},
      });
    },
  );
  test(
    'deal-breaker failed retry preserves selection without fake Done',
    () async {
      final owner = _Owner();
      addTearDown(owner.controller.dispose);
      await owner.finishParts();
      owner.controller.toggleDealbreaker(4);
      owner.success = false;
      expect(await owner.controller.saveDealbreakers(), isFalse);
      expect(owner.controller.dealbreakersDone, isFalse);
      expect(owner.controller.showDealbreakerFailure, isTrue);
      expect(owner.controller.selectedDealbreakers, {4});
      owner.success = true;
      expect(await owner.controller.saveDealbreakers(), isTrue);
      expect(owner.controller.dealbreakersDone, isTrue);
    },
  );
  test(
    'repository round-trip retains retired/hidden raw storage and enforces independent part/hard validation',
    () async {
      var allowed = true;
      final repo = SelahRequestCompatibilityRepository(
        canAct: () => allowed,
        readSignUpPreferences: () => {
          'marriage_values': {'wouldLikeChildren': 'No'},
        },
      );
      addTearDown(repo.close);
      final snapshot = SelahOnboardingAnswersSnapshot(
        ch3Answers: {'ch3_q12': 'Retained income', 'ch3_q24': 'After 3 years'},
        ch4Preferences: {
          'ch3_q12': {'Income': TrafficLight.red},
        },
        ch4HardRequirements: {
          'retired': {'Keep'},
        },
        journeyBio: const JourneyBio(),
      );
      expect(
        await repo.save(
          'draft-self',
          SelahCompatibilityDraft.fromSnapshot(
            gender: 'male',
            snapshot: snapshot,
          ),
        ),
        isTrue,
      );
      expect(await repo.saveDealbreakers({}), isFalse);
      for (final part in chapter3Categories) {
        final questions = selahYourValuesQuestionsFor(
          part,
          'male',
          repo.rawAnswers,
          repo.signUpPreferences,
        );
        expect(
          await repo.saveYourValuesPart(part.id, {
            for (final question in questions)
              question.responseKey: question.selfAnswerOptional
                  ? null
                  : question.options.first,
          }),
          isTrue,
        );
      }
      expect(repo.rawAnswers['ch3_q24'], 'After 3 years');
      expect(await repo.saveDealbreakers(selahDealbreakersFor([0, 2])), isTrue);
      final saved = await repo.load('draft-self');
      expect(saved!.ch3Answers['ch3_q12'], 'Retained income');
      expect(saved.ch4Preferences, snapshot.ch4Preferences);
      expect(saved.ch4HardRequirements['retired'], {'Keep'});
      expect(
        await repo.saveYourValuesPart('faith_practice', {'ch3_q12': 'Changed'}),
        isFalse,
      );
      expect(
        await repo.saveDealbreakers({
          'ch3_q12': {'Changed'},
        }),
        isFalse,
      );
      allowed = false;
      expect(repo.rawAnswers, isEmpty);
      allowed = true;
      expect(await repo.saveDealbreakers({}), isFalse);
      expect(await repo.load('draft-self'), isNull);
    },
  );

  test(
    'a throwing source read terminally hides this buffer without dispatch',
    () async {
      var reads = 0;
      var writes = 0;
      final controller = SelahYourValuesController(
        canAct: () => true,
        gender: 'male',
        readAnswers: () {
          reads++;
          throw StateError('owner snapshot unavailable');
        },
        readSignUpPreferences: () => {},
        readHardRequirements: () => {},
        onSavePart: (_, _) {
          writes++;
          return true;
        },
        onSaveDealbreakers: (_) {
          writes++;
          return true;
        },
      );
      addTearDown(controller.dispose);
      expect(controller.questionsFor('faith_practice'), isEmpty);
      expect(controller.current, isFalse);
      expect(await controller.savePart('faith_practice'), isFalse);
      expect(reads, 1);
      expect(writes, 0);
    },
  );

  test(
    'actual Save None remains Done on same-owner Values reentry without saved hard keys',
    () async {
      final repo = SelahRequestCompatibilityRepository(canAct: () => true);
      addTearDown(repo.close);
      final first = _forRepository(repo);
      await _saveAllParts(first);
      first.toggleDealbreaker(5);
      expect(await first.saveDealbreakers(), isTrue);
      expect(repo.rawHardRequirements, isEmpty);
      expect(repo.dealbreakersSaved, isTrue);
      first.dispose();
      final reentry = _forRepository(repo);
      addTearDown(reentry.dispose);
      expect(reentry.allPartsDone, isTrue);
      expect(reentry.dealbreakersDone, isTrue);
      expect(reentry.selectedDealbreakers, isEmpty);
      repo.close();
      expect(repo.dealbreakersSaved, isFalse);
    },
  );

  test(
    'legacy nonempty hard rules and failed save never fabricate Deal-breakers Done',
    () async {
      final repo = SelahRequestCompatibilityRepository(canAct: () => true);
      addTearDown(repo.close);
      final first = _forRepository(repo);
      await _saveAllParts(first);
      first.dispose();
      final raw = SelahCompatibilityDraft.fromSnapshot(
        gender: 'male',
        snapshot: await repo.load('draft-self'),
      );
      raw.hardRequirements.addAll(selahDealbreakersFor([0]));
      expect(await repo.save('draft-self', raw), isTrue);
      final restored = _forRepository(repo);
      addTearDown(restored.dispose);
      expect(restored.selectedDealbreakers, {0});
      expect(restored.dealbreakersDone, isFalse);
      expect(
        await repo.saveDealbreakers({
          'unlocked': {'No'},
        }),
        isFalse,
      );
      expect(repo.dealbreakersSaved, isFalse);
      final failedReentry = _forRepository(repo);
      addTearDown(failedReentry.dispose);
      expect(failedReentry.dealbreakersDone, isFalse);
    },
  );

  for (final kind in [
    CompatibilityEditorKind.trafficLights,
    CompatibilityEditorKind.hardRequirements,
  ]) {
    testWidgets(
      'retired $kind route cannot render options or persist old partner answers',
      (tester) async {
        var writes = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: CompatibilityEditorScreen(
              kind: kind,
              initialDraft: SelahCompatibilityDraft(
                gender: 'male',
                answers: {},
                preferences: {
                  'ch3_q52': {'I smoke only': TrafficLight.red},
                },
                hardRequirements: {
                  'ch3_q52': {'I smoke only'},
                },
              ),
              onPersist: (_) async {
                writes++;
                return true;
              },
            ),
          ),
        );
        expect(
          find.byKey(const ValueKey('compatibility_partner_editor_retired')),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('compatibility-save')), findsNothing);
        expect(find.text('I smoke only'), findsNothing);
        expect(writes, 0);
      },
    );
  }
}
