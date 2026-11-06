import 'dart:io';

import 'package:selah/data/selah_journey_stages.dart';
import 'package:selah/dev/selah_view_request_draft_model.dart';

void runJourneyStageChecks(void Function(bool, String) check) {
  const values = [
    'greeting_exchange',
    'compatibility_reveal',
    'phase_1',
    'phase_2',
    'phase_3',
    'family_stage',
    'conversation',
  ];
  const labels = [
    'First greeting',
    'Compatibility Reveal',
    'Faith & Values',
    'Building a Life',
    'Navigating Life',
    'Family Compatibility',
    'Open Conversation',
  ];
  check(
    SelahJourneyStages.count == 7 && SelahJourneyStages.all.length == 7,
    'LOCK 21 has exactly seven member-visible stages',
  );
  check(
    SelahJourneyStages.all.map((stage) => stage.value).join('|') ==
        values.join('|'),
    'Canonical stage order matches the exact seven locked stored values',
  );
  check(
    SelahJourneyStages.previewAll.map((stage) => stage.value).join('|') ==
        values.join('|'),
    'Preview cannot add Shepherd Gate or Life Snapshot numbered steps',
  );
  for (var i = 0; i < values.length; i++) {
    final stage = SelahJourneyStages.all[i];
    check(
      stage.order == i + 1 && stage.label == labels[i],
      '${values[i]} has its exact locked label and seven-stage number',
    );
    check(
      identical(SelahJourneyStages.of(values[i]), stage) &&
          identical(SelahJourneyStages.previewOf(values[i]), stage),
      '${values[i]} resolves identically across canonical and preview lookup',
    );
  }
  final faith = SelahJourneyStages.of('phase_1')!;
  check(
    identical(SelahJourneyStages.of('mentor_gate'), faith) &&
        identical(SelahJourneyStages.previewOf('mentor_gate'), faith) &&
        faith.order == 3 &&
        faith.value == 'phase_1',
    'Legacy mentor_gate safely displays the canonical Faith & Values stage',
  );
  check(
    SelahJourneyStages.of('unknown') == null &&
        SelahJourneyStages.of(null) == null &&
        SelahJourneyStages.previewOf('life_snapshot_preview') == null,
    'Unknown absent and retired preview values do not invent a numbered stage',
  );
  check(
    SelahJourneyStages.completedBefore(
          'mentor_gate',
        ).map((stage) => stage.value).join('|') ==
        values.take(2).join('|'),
    'A legacy gate does not imply completion of Faith & Values',
  );
  check(
    SelahJourneyStages.labelFor('mentor_gate', reviewOpen: true) ==
            'Family Review' &&
        SelahJourneyStages.previewLabelFor('phase_2', reviewOpen: true) ==
            'Family Review',
    'Family Review still overrides canonical and legacy stage presentation',
  );
  check(
    SelahJourneyStages.phase(1)?.kind == SelahStageKind.sustained &&
        SelahJourneyStages.phase(2)?.kind == SelahStageKind.sustained &&
        SelahJourneyStages.phase(3)?.kind == SelahStageKind.sustained &&
        SelahJourneyStages.of('family_stage')?.kind ==
            SelahStageKind.sustained &&
        SelahJourneyStages.of('conversation')?.kind ==
            SelahStageKind.destination,
    'Sustained phase Family Review classification and terminal kind stay intact',
  );
  check(
    SelahJourneyStages.ofTimelineMilestone('phase_1_complete') == faith &&
        SelahJourneyStages.ofTimelineMilestone('shepherd_linked') == null,
    'Legacy Shepherd linkage cannot be mistaken for completed Faith & Values',
  );
  for (final list in [SelahJourneyStages.all, SelahJourneyStages.previewAll]) {
    var immutable = false;
    try {
      list.clear();
    } on UnsupportedError {
      immutable = true;
    }
    check(immutable, 'Shared stage sequence cannot be mutated by a caller');
  }

  const names = {
    'draft-amira': 'Her mother, Ruth',
    'draft-sara': 'Pastor Ama Mensah',
    'draft-aisha': 'Her father, Peter',
    'draft-maryam': 'Her aunt, Teresa',
  };
  for (final profile in draftProfiles) {
    check(
      profile.otherMainShepherdName == names[profile.id],
      '${profile.firstName} has only the explicit Q15 local Shepherd name or null',
    );
  }
  check(
    draftProfiles
            .where((profile) => profile.otherMainShepherdName != null)
            .length ==
        4,
    'Only the four permitted draft cast records have Shepherd name metadata',
  );

  final id = draftProfiles[1].id;
  final now = DateTime.utc(2026, 11, 6, 12);
  var clockReads = 0;
  final model = ViewRequestDraftModel(
    capacity: 3,
    clock: () {
      clockReads++;
      return now.add(Duration(seconds: clockReads));
    },
  )..seedJourneys(1);
  model.sendGreeting(id);
  model.simulatePeerGreeting(id);
  model.chooseStageContinue(id);
  model.simulatePeerStageContinue(id);
  check(model.advanceStage(id), 'Both completed greetings reach Compatibility');
  model.chooseCompatibilityReveal(id);
  check(
    !model.chooseStageContinue(id) &&
        !model.advanceStage(id) &&
        clockReads == 1,
    'One reveal cannot bypass mutual Compatibility consent or emit an event',
  );
  model.simulatePeerCompatibilityReveal(id);
  model.chooseStageContinue(id);
  check(
    !model.advanceStage(id) && clockReads == 1,
    'One Continue cannot bypass the existing two-person stage action',
  );
  model.simulatePeerStageContinue(id);
  check(
    model.advanceStage(id) && model.stageFor(id) == faith && clockReads == 2,
    'Both Compatibility choices advance directly to Faith & Values',
  );
  final transition = model.stageChangesFor(id).last;
  check(
    transition.fromStage == 'compatibility_reveal' &&
        transition.toStage == 'phase_1' &&
        transition.occurredAt == now.add(const Duration(seconds: 2)) &&
        model.stageChangesFor(id).length == 2,
    'Direct advancement emits one actual destination fact with no fake gate event',
  );
  check(
    !model.hasChosenStageContinue(id) && !model.peerHasChosenStageContinue(id),
    'Direct transition resets existing per-stage Continue choices once',
  );
  model.chooseStageContinue(id);
  model.simulatePeerStageContinue(id);
  model.setOwnMainShepherdPresent(false);
  check(
    !model.advanceStage(id) &&
        model.stageFor(id) == faith &&
        clockReads == 2 &&
        model.stageChangesFor(id).length == 2,
    'Removing a visible gate never removes the own-Main action guard',
  );
  model.setOwnMainShepherdPresent(true);
  model.setPeerMainShepherdPresent(false, id: id);
  check(
    !model.advanceStage(id) && clockReads == 2,
    'The other Main Shepherd remains required for ordinary progression',
  );
  model.setPeerMainShepherdPresent(true, id: id);
  check(
    model.advanceStage(id) && model.stageFor(id)?.value == 'phase_2',
    'Restored Main leadership continues through the existing next phase',
  );
  check(
    model
        .stageChangesFor(id)
        .every(
          (event) =>
              event.fromStage != 'mentor_gate' &&
              event.toStage != 'mentor_gate',
        ),
    'Local history contains no removed stage semantics',
  );
}

void main() {
  var count = 0;
  runJourneyStageChecks((condition, label) {
    count++;
    if (!condition) {
      stderr.writeln('FAIL: $label');
      exitCode = 1;
    }
  });
  stdout.writeln('$count Journey stage checks.');
}
