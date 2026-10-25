// Pure Dart model checks, no Flutter engine, backend, native plugin or wrappers.
import '../lib/dev/selah_view_request_draft_model.dart';
import '../lib/dev/selah_browse_history.dart';
import '../lib/data/chapter3_categories.dart';
import '../lib/data/selah_reference_data.dart';
import '../lib/models/onboarding_question.dart';

void main() {
  var checks = 0;
  void check(bool value, String label) {
    checks++;
    if (!value) throw StateError('FAILED: $label');
  }
  final pending = draftProfiles[4].id;
  final model = ViewRequestDraftModel(capacity: 3);
  check(model.canBrowse, 'fresh draft can browse');
  check(model.request(pending), 'request local profile');
  check(model.stateFor(pending) == DraftJourneyState.sent, 'sent state recorded');
  check(!model.conversationOpen(pending), 'request alone never opens conversation');
  check(model.cancel(pending), 'second-tap cancellation works');
  check(model.stateFor(pending) == null, 'cancel removes pending state');
  check(model.request(pending), 'can request again after cancel');
  check(model.simulateRecipientAccept(pending), 'simulate mutual acceptance');
  check(model.stateFor(pending) == DraftJourneyState.preparing, 'acceptance reserves preparation');
  check(!model.conversationOpen(pending), 'preparation alone does not disclose chat');
  check(model.markReady(pending), 'first participant confirms');
  check(model.simulatePeerReady(pending), 'other participant confirms');
  check(model.beginPreparedJourney(pending), 'both confirmations start Journey');
  check(model.sendGreeting(pending), 'first participant greets');
  check(model.simulatePeerGreeting(pending), 'other participant greets');
  check(model.greetingComplete(pending), 'greeting handshake complete');
  check(model.end(pending), 'local end works');
  check(model.stateFor(pending) == DraftJourneyState.ended, 'ended record retained');
  check(!model.conversationOpen(pending), 'ended conversation not reopened');

  final full = ViewRequestDraftModel(capacity: 3);
  check(full.seedJourneys(3), 'three-Journey scenario');
  check(full.occupiedCount == 3, 'exactly three places');
  check(full.canBrowse, 'full monthly draft may still browse');
  check(full.request(pending), 'full monthly draft may request');
  check(!full.simulateRecipientAccept(pending), 'fourth reservation refused');
  check(full.canAttemptAccept(pending), 'full acceptance reaches capacity choice');
  final ending = draftProfiles[1].id;
  check(full.replaceJourneyForRequest(pending, ending, incoming: false),
      'explicit replacement is atomic');
  check(full.stateFor(ending) == DraftJourneyState.ended, 'selected Journey archived');
  check(full.stateFor(pending) == DraftJourneyState.preparing, 'pending request now preparing');
  check(full.occupiedCount == 3, 'capacity never becomes four');
  check(!full.setCapacity(1), 'capacity cannot truncate current Journeys');
  final shepherd = draftShepherds.first.id;
  final active = draftProfiles[2].id;
  check(full.setSampleShepherdMembership(shepherd, DraftShepherdMembership.basic), 'free Shepherd preset');
  check(!full.sampleShepherdAccessFor(shepherd, active, isMain: true).chat, 'free Shepherd has no chat');
  check(!full.setSampleShepherdJourneyAccess(shepherd, active, chatEnabled: true), 'cannot forge free chat grant');
  check(full.block(active), 'block local profile');
  check(!full.canParticipateInJourney(active), 'block denies participation');

  final history = SelahBrowseHistory();
  for (var i = 0; i < 20; i++) {
    check(history.appendFrontier('person-$i'), 'record profile $i');
  }
  check(history.ids.length == 11, 'history retains ten back visits');
  for (var i = 0; i < 10; i++) check(history.back() != null, 'back $i');
  check(!history.canBack && history.back() == null, 'eleventh back is refused');
  for (var i = 0; i < 10; i++) check(history.forwardReplay() != null, 'forward replay $i');
  check(history.currentId == 'person-19', 'replay reaches original frontier');
  check(history.appendFrontier('person-20'), 'discovery resumes at frontier');
  history.reconcile(history.ids.where((id) => id != 'person-19'));
  check(!history.ids.contains('person-19'), 'hidden/blocked visit is pruned');

  final questions = chapter3Categories.expand((c) => c.questions).toList();
  final ids = questions.map((q) => q.id).toSet();
  check(ids.length == 104, 'all retained question IDs present');
  for (var i = 1; i <= 104; i++) check(ids.contains('ch3_q$i'), 'question $i retained');
  final church = questions.firstWhere((q) => q.id == 'ch3_q39');
  check(church.genderVisibility == GenderVisibility.all, 'church question inclusive of both users');
  final copy = questions.map((q) => '${q.prompt} ${q.options.join(' ')}').join(' ');
  check(copy.contains('Bible') && copy.contains('Christian') && copy.toLowerCase().contains('church'),
      'Christian question bank is substantive');
  for (final role in ['parent', 'father', 'mother', 'pastor', 'mentor', 'church_elder']) {
    check(selahShepherdRelationships.any((item) => item.code == role), 'Shepherd role $role');
  }
  print('PASS: $checks pure local model, question-bank and history checks.');
}
