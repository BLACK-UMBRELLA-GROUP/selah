import 'dart:io';

import 'package:selah/dev/selah_view_request_draft_model.dart';
import 'package:selah/models/seeker_profile.dart';
import 'package:selah/models/selah_faith_profile.dart';
import 'package:selah/models/selah_marriage_values.dart';
import 'package:selah/models/selah_shepherd_suggestion.dart';

void runShepherdIntroduceModelChecks(void Function(bool, String) check) {
  bool refuses(void Function() change) {
    try {
      change();
      return false;
    } on UnsupportedError {
      return true;
    }
  }

  final photos = ['data:image/jpeg;base64,synthetic'];
  final faith = SelahFaithProfileAnswers(
    tradition: 'Anglican',
    church: 'Every week',
    baptised: 'Yes',
    words: 'Explicit public words.',
  );
  final marriage = SelahMarriageValuesAnswers(
    marriedBefore: 'No',
    children: 'No',
    wouldLikeChildren: 'Yes',
  );
  final input = ShepherdSuggestion(
    profile: SeekerProfile(
      id: 'synthetic-candidate',
      firstName: 'Grace',
      surnameLine: 'Clarke',
      age: 29,
      city: 'Leeds',
      photos: photos,
      gender: 'female',
      publicNationality: 'British',
      publicEthnicity: 'Mixed',
      faithProfile: faith,
      faithDenominationText: 'Explicit label',
      marriageValues: marriage,
      videoPhotoIndex: 0,
      alreadyLikedYou: true,
    ),
    suggestedBy: 'Pastor David',
  );
  final snapshot = input.snapshot(unseen: true);
  photos.add('another synthetic photo');
  check(
    snapshot.profile.photos.length == 1 && input.profile.photos.length == 2,
    'retained Introduction detaches caller-owned photo input',
  );
  check(
    refuses(() => snapshot.profile.photos.add('mutation')),
    'retained Introduction photo snapshot is immutable',
  );
  check(
    snapshot.profile.id == input.profile.id &&
        snapshot.profile.firstName == 'Grace' &&
        snapshot.profile.surnameLine == 'Clarke' &&
        snapshot.profile.age == 29 &&
        snapshot.profile.city == 'Leeds' &&
        snapshot.profile.gender == 'female',
    'snapshot preserves exact public identity fields',
  );
  check(
    identical(snapshot.profile.faithProfile, faith) &&
        identical(snapshot.profile.marriageValues, marriage) &&
        snapshot.profile.faithDenominationText == 'Explicit label' &&
        snapshot.profile.publicNationality == 'British' &&
        snapshot.profile.publicEthnicity == 'Mixed' &&
        snapshot.profile.videoPhotoIndex == 0 &&
        snapshot.profile.alreadyLikedYou,
    'snapshot preserves explicit existing public projections without inference',
  );
  check(
    snapshot.unseen && !input.unseen && snapshot.suggestedBy == 'Pastor David',
    'local unseen state does not mutate the retained DTO input',
  );
  final seen = snapshot.snapshot(unseen: false);
  check(
    !seen.unseen && snapshot.unseen && snapshot.snapshot().unseen,
    'markSeen can replace badge state without mutating earlier snapshots',
  );

  final james = ViewRequestDraftModel(capacity: 3);
  final joel = ViewRequestDraftModel.freshSeeker(capacity: 3);
  check(
    james.stateFor(draftProfiles.first.id) == DraftJourneyState.received &&
        james.peerOccupied(draftProfiles.last.id),
    'existing default scenario retains its original request and busy peer',
  );
  check(
    joel.states.isEmpty && joel.occupiedCount == 0 && joel.activeCount == 0,
    'fresh Joel has no copied request or Journey state',
  );
  check(
    joel.saved.isEmpty && joel.hiddenPeers.isEmpty && joel.blockedPeers.isEmpty,
    'fresh Joel has no copied saved hidden or blocked data',
  );
  check(
    draftProfiles.every((profile) => !joel.peerOccupied(profile.id)),
    'fresh Joel has no inherited busy-peer seed',
  );
  check(
    joel.discoverableProfiles.length == draftProfiles.length &&
        joel.discoverableProfiles.first.firstName == 'Grace',
    'fresh discovery preserves the locked cast order with Grace first',
  );
  check(
    draftProfiles.every((profile) => joel.canRequest(profile.id)),
    'fresh discovery uses the existing new-Seeker request rules',
  );
  james.hide(draftProfiles[0].id);
  james.block(draftProfiles[1].id);
  james.setPeerOccupied(draftProfiles[4].id, true);
  james.save(draftProfiles[3].id);
  check(
    joel.hiddenPeers.isEmpty &&
        joel.blockedPeers.isEmpty &&
        joel.saved.isEmpty &&
        joel.discoverableProfiles.length == draftProfiles.length,
    'James visibility and saved changes cannot contaminate Joel discovery',
  );
  check(
    joel.request(draftProfiles.first.id) &&
        joel.stateFor(draftProfiles.first.id) == DraftJourneyState.sent &&
        james.stateFor(draftProfiles.first.id) == DraftJourneyState.received,
    'a real local request changes only its owning Seeker model',
  );
  joel.hide(draftProfiles[1].id);
  joel.block(draftProfiles[2].id);
  joel.setPeerOccupied(draftProfiles[3].id, true);
  joel.save(draftProfiles[4].id);
  joel.reset();
  check(
    joel.states.isEmpty &&
        joel.saved.isEmpty &&
        joel.hiddenPeers.isEmpty &&
        joel.blockedPeers.isEmpty &&
        draftProfiles.every((profile) => !joel.peerOccupied(profile.id)),
    'fresh model reset remains fresh rather than seeding James private state',
  );
  check(
    joel.capacity == 3 &&
        joel.ownMainShepherdPresent &&
        joel.discoverableProfiles.length == draftProfiles.length,
    'fresh reset preserves its own capacity and Main Shepherd defaults',
  );
  james.reset();
  check(
    james.stateFor(draftProfiles.first.id) == DraftJourneyState.received &&
        james.peerOccupied(draftProfiles.last.id) &&
        james.hiddenPeers.isEmpty,
    'existing default reset behavior stays unchanged',
  );
  check(
    refuses(() => joel.states['unknown'] = DraftJourneyState.active),
    'fresh model exposes immutable request snapshots',
  );
  for (final capacity in [0, 4]) {
    var refused = false;
    try {
      ViewRequestDraftModel.freshSeeker(capacity: capacity);
    } on RangeError {
      refused = true;
    }
    check(refused, 'fresh model rejects invalid capacity $capacity');
  }
}

void main() {
  var checks = 0;
  var failures = 0;
  runShepherdIntroduceModelChecks((condition, label) {
    checks++;
    if (!condition) {
      failures++;
      stderr.writeln('FAIL: $label');
    }
  });
  stdout.writeln(
    '$checks Shepherd Introduce model checks; $failures failures.',
  );
  if (failures != 0) exitCode = 1;
}
