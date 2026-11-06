import 'dart:async';
import 'dart:io';

import 'package:selah/data/journey_questions.dart';
import 'package:selah/dev/selah_view_request_draft_model.dart';
import 'package:selah/models/selah_family_answers.dart';
import 'package:selah/models/selah_family_stage_controller.dart';

Future<void> runFamilyStageChecks(void Function(bool, String) check) async {
  final ids = JourneyQuestions.family.map((question) => question.id).toList();
  check(
    ids.join('|') == 'fam_q1|fam_q2|fam_q3|fam_q4',
    'Exactly four new Family IDs',
  );
  final prompts = JourneyQuestions.familyFor('Esther');
  check(
    prompts.map((question) => question.text).join('|') ==
        'How have you seen God lead you in this Journey so far?|'
            'Which church would you belong to together, and how would you serve there?|'
            'How will you welcome Esther’s family and church into your life together?|'
            'Who will you turn to for counsel and prayer when things are hard?',
    'Four prompts match LOCK22 with the actual counterpart name',
  );
  final own = {for (final id in ids) id: 'Own answer for $id.'};
  final peer = {for (final id in ids) id: 'Peer answer for $id.'};
  for (var count = 0; count < 4; count++) {
    final partial = SelahFamilyAnswers.fromMap(
      Map.fromEntries(own.entries.take(count)),
    );
    check(
      !partial.canSend && partial.answeredCount == count,
      '$count answers cannot send',
    );
  }
  check(SelahFamilyAnswers.fromMap(own).canSend, 'Four valid answers can send');
  final old = {
    for (var i = 1; i <= 4; i++) 'fam_wts_q$i': 'Stored old answer',
    for (var i = 1; i <= 4; i++) 'fam_stw_q$i': 'Stored old answer',
  };
  check(
    !SelahFamilyAnswers.fromMap(old).canSend && old.length == 8,
    'Retired rows remain untouched and cannot imply new completion',
  );
  final unicode400 = List.filled(400, '🙏').join();
  final unicode401 = '$unicode400🙏';
  check(
    SelahFamilyAnswers.fromMap({...own, ids[0]: unicode400}).canSend,
    '400 supplementary Unicode characters fit',
  );
  check(
    !SelahFamilyAnswers.fromMap({...own, ids[0]: unicode401}).canSend,
    '401 Unicode characters cannot send',
  );
  check(
    !SelahFamilyAnswers.fromMap({...own, ids[0]: '   \n '}).canSend,
    'Whitespace is unanswered',
  );
  final mutable = Map<String, String>.from(own);
  final detached = SelahFamilyAnswers.fromMap(mutable);
  mutable[ids[0]] = 'Changed';
  check(
    detached.answerFor(ids[0]) == own[ids[0]],
    'Answer values detach mutable input',
  );
  var immutable = false;
  try {
    detached.values.clear();
  } on UnsupportedError {
    immutable = true;
  }
  check(immutable, 'Expected submission map is immutable');

  final first = draftProfiles[1].id;
  final second = draftProfiles[2].id;
  void reachFamily(ViewRequestDraftModel model, String id) {
    while (model.stageFor(id)?.value != 'family_stage') {
      final stage = model.stageFor(id)?.value;
      if (stage == null || stage == 'conversation') {
        throw StateError('Invalid test Journey');
      }
      if (stage == 'greeting_exchange') {
        model.sendGreeting(id);
        model.simulatePeerGreeting(id);
      } else if (stage == 'compatibility_reveal') {
        model.chooseCompatibilityReveal(id);
        model.simulatePeerCompatibilityReveal(id);
      }
      if (!model.chooseStageContinue(id) ||
          !model.simulatePeerStageContinue(id) ||
          !model.advanceStage(id)) {
        throw StateError('Cannot reach Family through public actions');
      }
    }
  }

  ViewRequestDraftModel familyModel() {
    final model = ViewRequestDraftModel(capacity: 3)..seedJourneys(2);
    reachFamily(model, first);
    return model;
  }

  final model = familyModel();
  check(
    model.familyAnswersFor(first).isEmpty &&
        model.familyAnswersFor(first, peer: true).isEmpty &&
        !model.familyBothSent(first),
    'Family starts with no own or peer assumptions',
  );
  check(
    !model.chooseStageContinue(first) && !model.canAdvanceStage(first),
    'Empty Family cannot complete through generic Continue',
  );
  for (final entry in own.entries.take(3)) {
    model.setFamilyAnswer(first, entry.key, entry.value);
  }
  check(
    !model.sendFamilyAnswers(first),
    'Three stored answers cannot mark sent',
  );
  check(
    !model.setFamilyAnswer(first, 'fam_wts_q1', 'Old question') &&
        !model.setFamilyAnswer(first, ids[3], unicode401),
    'Old IDs and oversized draft writes are rejected',
  );
  check(
    !model.setFamilyAnswer(second, ids[0], 'Wrong stage'),
    'Another Journey outside Family cannot collect answers',
  );
  check(
    !model.simulatePeerFamilyAnswers(first, peer, canSimulate: () => false),
    'Denied private simulation cannot fabricate peer answers',
  );
  check(
    !model.simulatePeerFamilyAnswers(
      first,
      peer,
      canSimulate: () => throw StateError('revoked'),
    ),
    'Throwing private guard cannot fabricate peer answers',
  );
  var guardReads = 0;
  check(
    !model.simulatePeerFamilyAnswers(
      first,
      peer,
      canSimulate: () => ++guardReads == 1,
    ),
    'Private peer simulation rechecks its original guard at commit',
  );
  check(
    model.simulatePeerFamilyAnswers(first, peer, canSimulate: () => true) &&
        !model.familyAnswersSent(first) &&
        !model.familyBothSent(first),
    'Explicit peer send never implies the own Seeker has sent',
  );
  model.setFamilyAnswer(first, ids[3], own[ids[3]]!);
  check(
    !model.sendFamilyAnswers(first, expectedAnswers: {...own, ids[0]: 'Stale'}),
    'Stale expected answers cannot publish a different submission',
  );
  final eventsBeforeSend = model.stageChangesFor(first).length;
  check(
    model.sendFamilyAnswers(first, expectedAnswers: own) &&
        model.familyBothSent(first),
    'Both independent four-answer submissions complete Family content',
  );
  check(
    model.familyAnswersFor(first, peer: true)[ids[0]] == peer[ids[0]] &&
        model.familyAnswersFor(first)[ids[0]] == own[ids[0]] &&
        model.familyAnswersFor(second).isEmpty,
    'Senders and Journeys keep separate answers',
  );
  check(
    !model.setFamilyAnswer(first, ids[0], 'After sent') &&
        !model.sendFamilyAnswers(first),
    'Sent side is immutable and repeated send is idempotent',
  );
  check(
    model.stageChangesFor(first).length == eventsBeforeSend &&
        !model.canAdvanceStage(first),
    'Both sends do not invent a stage event or bypass existing Continue choices',
  );
  model.chooseStageContinue(first);
  model.simulatePeerStageContinue(first);
  model.setOwnMainShepherdPresent(false);
  check(
    !model.advanceStage(first),
    'Both sent cannot bypass existing Main Shepherd guard',
  );
  model.setOwnMainShepherdPresent(true);
  check(
    model.advanceStage(first) && model.conversationOpen(first),
    'Both sent plus existing guarded choices reach Open Conversation',
  );
  check(
    !model.setFamilyAnswer(first, ids[0], 'Outside Family'),
    'Conversation cannot rewrite Family answers',
  );
  model.reset();
  check(
    model.familyAnswersFor(first).isEmpty &&
        !model.familyAnswersSent(first) &&
        !model.familyAnswersSent(first, peer: true),
    'Reset clears existing progress answers and both sent flags',
  );

  SelahFamilyStageController controllerFor(
    ViewRequestDraftModel owner, {
    bool Function()? canAct,
    bool Function()? canDispatch,
    bool Function()? presets,
    FutureOr<bool> Function(Map<String, String>)? send,
    bool Function(String, String)? set,
  }) => SelahFamilyStageController(
    canAct: canAct ?? () => true,
    canDispatch: canDispatch,
    readAnswers: () =>
        SelahFamilyAnswers.fromMap(owner.familyAnswersFor(first)),
    readSent: () => owner.familyAnswersSent(first),
    readPeerSent: () => owner.familyAnswersSent(first, peer: true),
    onSetAnswer: set ?? (id, value) => owner.setFamilyAnswer(first, id, value),
    onSend:
        send ??
        (answers) => owner.sendFamilyAnswers(first, expectedAnswers: answers),
    canUsePresets: presets ?? () => false,
  );
  void fill(SelahFamilyStageController controller) {
    for (final entry in own.entries) {
      controller.setAnswer(entry.key, entry.value);
    }
  }

  final owned = familyModel();
  final controller = controllerFor(owned);
  fill(controller);
  check(
    controller.canSend &&
        controller.answeredCount == 4 &&
        controller.characterCount(ids[0]) == own[ids[0]]!.runes.length,
    'Controller reads actual owner answers and exact character count',
  );
  check(
    !controller.showSending() &&
        !controller.showFailure() &&
        !controller.showIdle(),
    'Presets cannot bypass private permission',
  );
  check(
    await controller.send() &&
        controller.sent &&
        controller.sendState == SelahFamilySendState.sent &&
        !controller.peerSent,
    'Normal local send derives Sent only from its actual canonical owner',
  );
  check(
    !await controller.send() && !controller.setAnswer(ids[0], 'Late'),
    'Controller cannot resend or edit a sent side',
  );
  controller.dispose();

  var visible = false;
  var setterCalls = 0;
  var sendCalls = 0;
  final hiddenOwner = familyModel();
  final hidden = controllerFor(
    hiddenOwner,
    canDispatch: () => visible,
    presets: () => true,
    set: (id, value) {
      setterCalls++;
      return hiddenOwner.setFamilyAnswer(first, id, value);
    },
    send: (answers) {
      sendCalls++;
      return hiddenOwner.sendFamilyAnswers(first, expectedAnswers: answers);
    },
  );
  check(
    !hidden.setAnswer(ids[0], 'Hidden') &&
        !await hidden.send() &&
        setterCalls == 0 &&
        sendCalls == 0 &&
        hidden.sendState == SelahFamilySendState.idle,
    'Owned controls cover denies member dispatch before any transient or owner write',
  );
  check(
    hidden.showSending() && hidden.showFailure() && hidden.showIdle(),
    'Actual private presets may present states across the owned cover',
  );
  visible = true;
  fill(hidden);
  check(
    hidden.current && hidden.canSend,
    'Dispatch denial is nonterminal for an owned cover',
  );
  hidden.showSending();
  check(
    !hidden.setAnswer(ids[0], 'Busy preset edit') &&
        !hidden.canSend &&
        hidden.answers.matches(own) &&
        hidden.showIdle() &&
        hidden.canSend,
    'Private Sending is busy without changing answers and Idle restores dispatch',
  );
  hidden.dispose();

  var succeed = false;
  final failedOwner = familyModel();
  final failed = controllerFor(
    failedOwner,
    send: (answers) =>
        succeed &&
        failedOwner.sendFamilyAnswers(first, expectedAnswers: answers),
  );
  fill(failed);
  check(
    !await failed.send() &&
        failed.sendState == SelahFamilySendState.failed &&
        failed.answers.matches(own) &&
        !failed.sent,
    'Failed save retains all actual answers and honest retry state',
  );
  succeed = true;
  check(
    await failed.send() && failed.sent,
    'Retry succeeds without duplicate answers',
  );
  failed.dispose();

  final dishonest = controllerFor(familyModel(), send: (_) => true);
  fill(dishonest);
  check(
    !await dishonest.send() &&
        !dishonest.sent &&
        dishonest.sendState == SelahFamilySendState.failed,
    'Callback success cannot fake a canonical Sent flag',
  );
  dishonest.dispose();

  final deferredOwner = familyModel();
  final release = Completer<bool>();
  var writes = 0;
  final deferred = controllerFor(
    deferredOwner,
    presets: () => true,
    send: (_) {
      writes++;
      return release.future;
    },
  );
  fill(deferred);
  final inFlight = deferred.send();
  check(
    deferred.sendState == SelahFamilySendState.sending &&
        !deferred.canSend &&
        !deferred.setAnswer(ids[0], 'During write') &&
        !await deferred.send() &&
        !deferred.showFailure() &&
        !deferred.showIdle() &&
        writes == 1,
    'A real pending write excludes reentrant dispatch and cannot be cancelled by presets',
  );
  release.complete(false);
  check(
    !await inFlight && deferred.answers.matches(own),
    'Deferred failure preserves canonical answers',
  );
  deferred.dispose();

  var generation = 1;
  const originalGeneration = 1;
  final revokedOwner = familyModel();
  final finish = Completer<void>();
  late SelahFamilyStageController revoked;
  revoked = controllerFor(
    revokedOwner,
    canAct: () => generation == originalGeneration,
    send: (answers) async {
      await finish.future;
      if (!revoked.current) return false;
      return revokedOwner.sendFamilyAnswers(first, expectedAnswers: answers);
    },
  );
  fill(revoked);
  var notices = 0;
  revoked.addListener(() => notices++);
  final staleSend = revoked.send();
  final beforeRevocation = notices;
  generation = 2;
  generation = 3; // Same account name may return; its original lifetime cannot.
  finish.complete();
  check(
    !await staleSend &&
        !revokedOwner.familyAnswersSent(first) &&
        notices == beforeRevocation &&
        !revoked.current,
    'Async completion cannot publish or write through an account-generation ABA',
  );
  generation = 1;
  check(
    !revoked.current &&
        !revoked.setAnswer(ids[0], 'Revived') &&
        !revoked.showSending(),
    'Observed owner denial is terminal for the controller',
  );
  revoked.dispose();

  final throwing = controllerFor(
    familyModel(),
    canAct: () => throw StateError('owner'),
  );
  check(
    !throwing.current &&
        !throwing.setAnswer(ids[0], 'Denied') &&
        !await throwing.send(),
    'Throwing owner callbacks fail closed',
  );
  throwing.dispose();
  final disposed = controllerFor(familyModel());
  disposed.dispose();
  check(
    !disposed.current &&
        disposed.answers.values.isEmpty &&
        !disposed.setAnswer(ids[0], 'Disposed') &&
        !await disposed.send(),
    'Disposed controllers cannot read or mutate their previous owner',
  );
}

Future<void> main() async {
  var count = 0;
  await runFamilyStageChecks((value, label) {
    count++;
    if (!value) throw StateError(label);
  });
  stdout.writeln('PASS $count Family stage checks');
}
