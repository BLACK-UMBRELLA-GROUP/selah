import 'package:selah/data/selah_journey_stages.dart';
import 'package:selah/data/journey_questions.dart';
import 'package:selah/dev/selah_view_request_draft_model.dart';
import 'package:selah/models/selah_journey_stage_change.dart';
import 'package:selah/models/selah_shepherd_dashboard.dart';

void runShepherdCheckInChecks(void Function(bool, String) check) {
  final now = DateTime.utc(2026, 11, 6, 12);
  const identity = SelahShepherdCheckInIdentity(
    seekerId: 'self',
    seekerFirstName: 'James',
    counterpartFirstName: 'Esther',
  );
  DraftJourneyStageChange event(
    String id,
    Duration age, {
    String to = 'phase_1',
  }) => DraftJourneyStageChange(
    journeyId: id,
    fromStage: 'compatibility_reveal',
    toStage: to,
    occurredAt: now.subtract(age),
  );
  final events = [
    event('old', const Duration(days: 7, microseconds: 1)),
    event('edge', const Duration(days: 7)),
    event('first', const Duration(days: 4)),
    event('second', const Duration(days: 3)),
    event('third', const Duration(days: 1)),
    event('future', const Duration(seconds: -1)),
    event('not-linked', const Duration(hours: 1)),
    event('unknown', const Duration(hours: 2), to: 'unknown'),
  ];
  final admitted = {
    for (final id in [
      'old',
      'edge',
      'first',
      'second',
      'third',
      'future',
      'unknown',
    ])
      id: identity,
  };
  final rows = selahShepherdCheckIns(
    events: events,
    admittedJourneys: admitted,
    now: now,
  );
  check(rows.length == 3, 'Check-ins never exceed three');
  check(
    rows.map((row) => row.journeyId).join('|') == 'third|second|first',
    'Check-ins are newest first',
  );
  check(
    rows.first.title == 'James and Esther reached Faith & Values',
    'Check-in uses canonical stage and admitted actual names',
  );
  final boundary = selahShepherdCheckIns(
    events: [events[0], events[1]],
    admittedJourneys: admitted,
    now: now,
  );
  check(
    boundary.length == 1 && boundary.single.journeyId == 'edge',
    'Exactly seven days is included; earlier is excluded',
  );
  check(
    selahShepherdCheckIns(
      events: events,
      admittedJourneys: {},
      now: now,
    ).isEmpty,
    'Unadmitted Journeys never contribute copy',
  );
  check(
    selahShepherdCheckIns(
      events: [events[5]],
      admittedJourneys: admitted,
      now: now,
    ).isEmpty,
    'Future timestamps never create a check-in',
  );
  check(
    selahShepherdCheckIns(
      events: [events[7]],
      admittedJourneys: admitted,
      now: now,
    ).isEmpty,
    'Unknown stage is not guessed',
  );
  var immutable = false;
  try {
    rows.clear();
  } on UnsupportedError {
    immutable = true;
  }
  check(immutable, 'Check-ins return immutable projection');

  var reads = 0;
  final model = ViewRequestDraftModel(
    capacity: 3,
    clock: () {
      reads++;
      return now.add(Duration(seconds: reads));
    },
  );
  final id = draftProfiles[1].id;
  check(
    model.stageChangesFor(id).isEmpty && reads == 0,
    'Initial fixture has no invented stage timestamp',
  );
  model.seedJourneys(1);
  check(
    model.stageChangesFor(id).isEmpty && reads == 0,
    'Private current-stage seed is not a historical event',
  );
  check(
    !model.advanceStage(id) && reads == 0,
    'Incomplete stage emits nothing and does not read clock',
  );
  final initialSnapshot = model.stageChangesFor(id);
  while (model.stageFor(id)!.order < SelahJourneyStages.count) {
    final stage = model.stageFor(id)!;
    if (stage.value == 'greeting_exchange') {
      model.sendGreeting(id);
      model.simulatePeerGreeting(id);
    }
    if (stage.value == 'compatibility_reveal') {
      model.chooseCompatibilityReveal(id);
      model.simulatePeerCompatibilityReveal(id);
    }
    if (stage.value == 'family_stage') {
      final answers = {
        for (final question in JourneyQuestions.family)
          question.id: 'Local answer to ${question.id}.',
      };
      for (final answer in answers.entries) {
        model.setFamilyAnswer(id, answer.key, answer.value);
      }
      model.sendFamilyAnswers(id);
      model.simulatePeerFamilyAnswers(id, answers, canSimulate: () => true);
    }
    model.chooseStageContinue(id);
    model.simulatePeerStageContinue(id);
    check(model.advanceStage(id), 'Admitted completed ${stage.value} advances');
    final record = model.stageChangesFor(id).last;
    check(
      record.journeyId == id &&
          record.fromStage == stage.value &&
          record.toStage == model.stageFor(id)!.value &&
          record.occurredAt == now.add(Duration(seconds: reads)),
      'Successful ${stage.value} records only its exact transition and actual supplied clock',
    );
  }
  check(
    model.stageChangesFor(id).length == SelahJourneyStages.count - 1,
    'Finite stage sequence bounds history',
  );
  check(
    !model.advanceStage(id) && reads == SelahJourneyStages.count - 1,
    'Terminal stage cannot emit a duplicate',
  );
  check(
    initialSnapshot.isEmpty,
    'Earlier immutable snapshot cannot acquire later facts',
  );
  immutable = false;
  try {
    model.stageChangesFor(id).clear();
  } on UnsupportedError {
    immutable = true;
  }
  check(immutable, 'Callers cannot mutate canonical stage facts');
  model.reset();
  check(
    model.stageChangesFor(id).isEmpty,
    'Existing reset clears its own per-Journey facts',
  );

  final blocked = ViewRequestDraftModel(capacity: 3, clock: () => now)
    ..seedJourneys(1);
  blocked.sendGreeting(id);
  blocked.simulatePeerGreeting(id);
  blocked.chooseStageContinue(id);
  blocked.simulatePeerStageContinue(id);
  blocked.block(id);
  check(
    !blocked.advanceStage(id) && blocked.stageChangesFor(id).isEmpty,
    'Blocked Journey emits no stage fact',
  );

  void prepareGreeting(ViewRequestDraftModel owner, String journeyId) {
    owner.sendGreeting(journeyId);
    owner.simulatePeerGreeting(journeyId);
    owner.chooseStageContinue(journeyId);
    owner.simulatePeerStageContinue(journeyId);
  }

  var throwClock = true;
  var failedClockReads = 0;
  final retry = ViewRequestDraftModel(
    capacity: 3,
    clock: () {
      failedClockReads++;
      if (throwClock) throw StateError('clock unavailable');
      return now;
    },
  )..seedJourneys(1);
  prepareGreeting(retry, id);
  final beforeFailure = retry.stageFor(id);
  check(
    !retry.advanceStage(id) &&
        retry.stageFor(id) == beforeFailure &&
        retry.hasChosenStageContinue(id) &&
        retry.peerHasChosenStageContinue(id) &&
        retry.stageChangesFor(id).isEmpty,
    'Clock failure atomically preserves stage, both Continue choices and empty history',
  );
  throwClock = false;
  check(
    retry.advanceStage(id) &&
        retry.stageChangesFor(id).length == 1 &&
        failedClockReads == 2 &&
        retry.stageChangesFor(id).single.occurredAt == now,
    'Retry after clock failure records exactly one actual transition',
  );
  check(
    !retry.advanceStage(id) && failedClockReads == 2,
    'Duplicate advance cannot read the clock or duplicate the successful event',
  );

  for (final denial in <(String, void Function(ViewRequestDraftModel))>[
    (
      'missing own Main Shepherd',
      (owner) => owner.setOwnMainShepherdPresent(false),
    ),
    (
      'missing peer Main Shepherd',
      (owner) => owner.setPeerMainShepherdPresent(false),
    ),
    ('pending Pause', (owner) => owner.requestPause(id)),
    ('ended Journey', (owner) => owner.end(id)),
  ]) {
    var clockReads = 0;
    final denied = ViewRequestDraftModel(
      capacity: 3,
      clock: () {
        clockReads++;
        return now;
      },
    )..seedJourneys(1);
    prepareGreeting(denied, id);
    denial.$2(denied);
    check(
      !denied.advanceStage(id) &&
          denied.stageChangesFor(id).isEmpty &&
          clockReads == 0,
      '${denial.$1} cannot create an event or read the clock',
    );
  }

  late ViewRequestDraftModel revokedAtClock;
  revokedAtClock = ViewRequestDraftModel(
    capacity: 3,
    clock: () {
      revokedAtClock.setOwnMainShepherdPresent(false);
      return now;
    },
  )..seedJourneys(1);
  prepareGreeting(revokedAtClock, id);
  check(
    !revokedAtClock.advanceStage(id) &&
        revokedAtClock.stageFor(id)?.value == 'greeting_exchange' &&
        revokedAtClock.hasChosenStageContinue(id) &&
        revokedAtClock.peerHasChosenStageContinue(id) &&
        revokedAtClock.stageChangesFor(id).isEmpty,
    'A guard revoked during the clock read cannot commit stage or history',
  );

  late ViewRequestDraftModel resetAtClock;
  resetAtClock = ViewRequestDraftModel(
    capacity: 3,
    clock: () {
      resetAtClock.seedJourneys(1);
      return now;
    },
  )..seedJourneys(1);
  prepareGreeting(resetAtClock, id);
  check(
    !resetAtClock.advanceStage(id) &&
        resetAtClock.stageFor(id)?.value == 'greeting_exchange' &&
        resetAtClock.stageChangesFor(id).isEmpty,
    'Replaced progress cannot acquire a stale callback transition',
  );

  final isolated = ViewRequestDraftModel(capacity: 3, clock: () => now)
    ..seedJourneys(2);
  prepareGreeting(isolated, id);
  isolated.advanceStage(id);
  final secondId = draftProfiles[2].id;
  check(
    isolated.stageChangesFor(id).length == 1 &&
        isolated.stageChangesFor(secondId).isEmpty &&
        isolated.stageFor(secondId)?.value == 'greeting_exchange',
    'An actual transition belongs only to its own Journey progress',
  );
  prepareGreeting(isolated, secondId);
  isolated.advanceStage(secondId);
  check(
    isolated.stageChangesFor(secondId).single.journeyId == secondId &&
        isolated.stageChangesFor(id).single.journeyId == id,
    'Concurrent Journey records keep their actual independent IDs',
  );

  var freshClockReads = 0;
  final fresh = ViewRequestDraftModel.freshSeeker(
    capacity: 3,
    clock: () {
      freshClockReads++;
      return now;
    },
  );
  check(
    fresh.states.isEmpty &&
        freshClockReads == 0 &&
        fresh.stageChangesFor(id).isEmpty,
    'Fresh Joel constructor reads no clock and invents no history',
  );
  fresh.seedJourneys(1);
  fresh.seedHistory();
  check(
    freshClockReads == 0 &&
        draftProfiles.every(
          (profile) => fresh.stageChangesFor(profile.id).isEmpty,
        ),
    'Private current-state and archive seeds never manufacture dated events',
  );
  prepareGreeting(fresh, id);
  fresh.advanceStage(id);
  check(
    freshClockReads == 1 && fresh.stageChangesFor(id).length == 1,
    'Fresh constructor uses the supplied clock only for a real transition',
  );
  fresh.reset();
  check(
    fresh.states.isEmpty &&
        fresh.stageChangesFor(id).isEmpty &&
        freshClockReads == 1 &&
        !fresh.peerOccupied(draftProfiles.last.id),
    'Fresh reset clears its own facts without importing default request or busy seeds',
  );

  const joelIdentity = SelahShepherdCheckInIdentity(
    seekerId: 'joel',
    seekerFirstName: 'Joel',
    counterpartFirstName: 'Esther',
  );
  final jamesRows = selahShepherdCheckIns(
    events: [event('same-peer', const Duration(hours: 1))],
    admittedJourneys: {'same-peer': identity},
    now: now,
  );
  final joelRows = selahShepherdCheckIns(
    events: [event('same-peer', Duration.zero)],
    admittedJourneys: {'same-peer': joelIdentity},
    now: now,
  );
  final combined = selahMergeShepherdCheckIns([...jamesRows, ...joelRows]);
  check(
    combined.length == 2 &&
        combined.first.identity.seekerId == 'joel' &&
        combined.last.identity.seekerId == 'self' &&
        combined.first.key != combined.last.key,
    'Identical peer Journey IDs cannot merge or misname distinct Seekers',
  );
  check(
    selahMergeShepherdCheckIns([...combined, ...combined]).length == 2,
    'Re-reading the same events cannot duplicate a check-in',
  );
  final capped = selahMergeShepherdCheckIns([...rows, ...combined]);
  check(
    capped.length == 3 &&
        capped[0].identity.seekerId == 'joel' &&
        capped[1].identity.seekerId == 'self' &&
        capped[2].journeyId == 'third',
    'Combined linked-Seeker projections apply one global newest-first limit',
  );
  immutable = false;
  try {
    capped.clear();
  } on UnsupportedError {
    immutable = true;
  }
  check(immutable, 'Combined check-ins are immutable');
  final replayed = selahShepherdCheckIns(
    events: [
      event('same-peer', const Duration(hours: 1)),
      event('same-peer', const Duration(days: 1)),
    ],
    admittedJourneys: {'same-peer': identity},
    now: now,
  );
  check(
    replayed.single.occurredAt == now.subtract(const Duration(hours: 1)),
    'An older duplicate read cannot replace the newest exact transition',
  );
  check(
    selahShepherdCheckIns(
      events: [event('same-peer', Duration.zero)],
      admittedJourneys: const {
        'same-peer': SelahShepherdCheckInIdentity(
          seekerId: 'self',
          seekerFirstName: 'James',
          counterpartFirstName: ' ',
        ),
      },
      now: now,
    ).isEmpty,
    'Missing admitted names never produce guessed member copy',
  );
}

void main() {
  var count = 0;
  runShepherdCheckInChecks((value, label) {
    count++;
    if (!value) throw StateError(label);
  });
  // ignore: avoid_print
  print('PASS $count Shepherd check-in checks');
}
