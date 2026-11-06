// Pure Dart model checks, no Flutter engine, backend, native plugin or wrappers.
import '../lib/dev/selah_view_request_draft_model.dart';
import '../lib/dev/selah_browse_history.dart';
import '../lib/data/chapter3_categories.dart';
import '../lib/data/selah_reference_data.dart';
import '../lib/models/onboarding_question.dart';
import 'package:selah/models/seeker_profile_completion.dart';
import 'package:selah/data/selah_christian_traditions.dart';

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
  check(
    model.stateFor(pending) == DraftJourneyState.sent,
    'sent state recorded',
  );
  check(
    !model.conversationOpen(pending),
    'request alone never opens conversation',
  );
  check(model.cancel(pending), 'second-tap cancellation works');
  check(model.stateFor(pending) == null, 'cancel removes pending state');
  check(model.request(pending), 'can request again after cancel');
  check(model.simulateRecipientAccept(pending), 'simulate mutual acceptance');
  check(
    model.stateFor(pending) == DraftJourneyState.preparing,
    'acceptance reserves preparation',
  );
  check(
    !model.conversationOpen(pending),
    'preparation alone does not disclose chat',
  );
  check(model.markReady(pending), 'first participant confirms');
  check(model.simulatePeerReady(pending), 'other participant confirms');
  check(
    model.beginPreparedJourney(pending),
    'both confirmations start Journey',
  );
  check(model.sendGreeting(pending), 'first participant greets');
  check(model.simulatePeerGreeting(pending), 'other participant greets');
  check(model.greetingComplete(pending), 'greeting handshake complete');
  check(model.end(pending), 'local end works');
  check(
    model.stateFor(pending) == DraftJourneyState.ended,
    'ended record retained',
  );
  check(!model.conversationOpen(pending), 'ended conversation not reopened');

  final full = ViewRequestDraftModel(capacity: 3);
  check(full.seedJourneys(3), 'three-Journey scenario');
  check(full.occupiedCount == 3, 'exactly three places');
  check(full.canBrowse, 'full monthly draft may still browse');
  check(full.request(pending), 'full monthly draft may request');
  check(!full.simulateRecipientAccept(pending), 'fourth reservation refused');
  check(
    full.canAttemptAccept(pending),
    'full acceptance reaches capacity choice',
  );
  final ending = draftProfiles[1].id;
  check(
    full.replaceJourneyForRequest(pending, ending, incoming: false),
    'explicit replacement is atomic',
  );
  check(
    full.stateFor(ending) == DraftJourneyState.ended,
    'selected Journey archived',
  );
  check(
    full.stateFor(pending) == DraftJourneyState.preparing,
    'pending request now preparing',
  );
  check(full.occupiedCount == 3, 'capacity never becomes four');
  check(!full.setCapacity(1), 'capacity cannot truncate current Journeys');
  final shepherd = draftShepherds.first.id;
  final active = draftProfiles[2].id;
  check(
    full.setSampleShepherdMembership(shepherd, DraftShepherdMembership.basic),
    'free Shepherd preset',
  );
  check(
    !full.sampleShepherdAccessFor(shepherd, active, isMain: true).chat,
    'free Shepherd has no chat',
  );
  check(
    !full.setSampleShepherdJourneyAccess(shepherd, active, chatEnabled: true),
    'cannot forge free chat grant',
  );
  check(full.block(active), 'block local profile');
  check(!full.canParticipateInJourney(active), 'block denies participation');

  final history = SelahBrowseHistory();
  for (var i = 0; i < 20; i++) {
    check(history.appendFrontier('person-$i'), 'record profile $i');
  }
  check(history.ids.length == 11, 'history retains ten back visits');
  for (var i = 0; i < 10; i++) check(history.back() != null, 'back $i');
  check(!history.canBack && history.back() == null, 'eleventh back is refused');
  for (var i = 0; i < 10; i++)
    check(history.forwardReplay() != null, 'forward replay $i');
  check(history.currentId == 'person-19', 'replay reaches original frontier');
  check(history.appendFrontier('person-20'), 'discovery resumes at frontier');
  history.reconcile(history.ids.where((id) => id != 'person-19'));
  check(!history.ids.contains('person-19'), 'hidden/blocked visit is pruned');

  final questions = chapter3Categories.expand((c) => c.questions).toList();
  final ids = questions.map((q) => q.id).toSet();
  check(ids.length == 104, 'all retained question IDs present');
  for (var i = 1; i <= 104; i++)
    check(ids.contains('ch3_q$i'), 'question $i retained');
  final church = questions.firstWhere((q) => q.id == 'ch3_q39');
  check(
    church.genderVisibility == GenderVisibility.all,
    'church question inclusive of both users',
  );
  final copy = questions
      .map((q) => '${q.prompt} ${q.options.join(' ')}')
      .join(' ');
  check(
    copy.contains('Bible') &&
        copy.contains('Christian') &&
        copy.toLowerCase().contains('church'),
    'Christian question bank is substantive',
  );
  for (final role in [
    'parent',
    'father',
    'mother',
    'pastor',
    'mentor',
    'church_elder',
  ]) {
    check(
      selahShepherdRelationships.any((item) => item.code == role),
      'Shepherd role $role',
    );
  }
  // Actual field predicate used by seekerProfileSectionComplete, without
  // importing the Flutter-dependent persistence services into this Dart tool.
  Map<String, dynamic> checkpointPreferences({
    String scope = 'same_family',
    Object? familyCodes = const ['catholic'],
    Object? outsideFlexibility = 'green',
    Object? faithJourneyFlexibility = 'yellow',
  }) => {
    'location': {'preference': 'same_country', 'flexibility': 'green'},
    'church_background': {
      'scope': scope,
      'family_codes': familyCodes,
      'outside_flexibility': outsideFlexibility,
    },
    'faith_journey': {'flexibility': faithJourneyFlexibility},
    'country_of_birth': {
      'preferred': ['GB'],
      'flexibility': 'green',
    },
    'nationality': {
      'preferred': ['GB'],
      'flexibility': 'yellow',
    },
    'ethnicity': {
      'preferred': ['other'],
      'flexibility': 'red',
    },
    'languages': {
      'preferred': ['en'],
      'flexibility': 'green',
    },
  };

  bool checkpointComplete({
    String? christianFamily = 'Catholic',
    String? faithJourney = 'I was raised Christian',
    String? countryOfBirth = 'United Kingdom',
    String? nationality = 'British',
    String? ethnicity = 'Other',
    List<String> languages = const ['English'],
    Map<String, dynamic>? preferences,
    int photoCount = 3,
    String? location = 'Manchester',
    bool? article9Consent = true,
  }) => seekerProfileFieldsComplete(
    christianFamily: christianFamily,
    faithJourney: faithJourney,
    countryOfBirth: countryOfBirth,
    nationality: nationality,
    ethnicity: ethnicity,
    languages: languages,
    preferences: preferences ?? checkpointPreferences(),
    photoCount: photoCount,
    location: location,
    article9Consent: article9Consent,
  );

  check(checkpointComplete(), 'checkpoint accepts complete Christian profile');
  check(
    !checkpointComplete(christianFamily: null),
    'checkpoint needs Christian family',
  );
  check(
    !checkpointComplete(christianFamily: '  '),
    'checkpoint rejects blank Christian family',
  );
  check(
    !checkpointComplete(faithJourney: null),
    'checkpoint needs faith journey',
  );
  check(
    checkpointComplete(faithJourney: ''),
    'checkpoint preserves non-null faith journey check',
  );
  check(
    !checkpointComplete(
      preferences: checkpointPreferences(
        scope: 'selected',
        familyCodes: const [],
      ),
    ),
    'selected church scope needs a family code',
  );
  check(
    !checkpointComplete(
      preferences: checkpointPreferences(
        scope: 'selected',
        familyCodes: 'catholic',
      ),
    ),
    'selected church scope needs a list, not a scalar',
  );
  check(
    !checkpointComplete(
      preferences: checkpointPreferences(faithJourneyFlexibility: null),
    ),
    'checkpoint needs faith journey flexibility',
  );
  check(
    !checkpointComplete(
      preferences: checkpointPreferences(faithJourneyFlexibility: 'blue'),
    ),
    'faith journey flexibility must be a traffic light',
  );
  for (final scope in selahChurchPreferenceScopeLabels.keys) {
    check(
      checkpointComplete(preferences: checkpointPreferences(scope: scope)),
      'church scope $scope accepts its completed questions',
    );
    check(
      !checkpointComplete(
        preferences: checkpointPreferences(
          scope: scope,
          outsideFlexibility: null,
        ),
      ),
      'church scope $scope requires the existing outside-flexibility question',
    );
  }
  check(
    !checkpointComplete(preferences: checkpointPreferences(scope: 'unknown')),
    'unknown church scope is incomplete',
  );
  check(
    checkpointComplete(
      christianFamily: null,
      faithJourney: null,
      countryOfBirth: null,
      nationality: null,
      ethnicity: null,
      article9Consent: false,
      preferences: {
        'location': {'preference': 'same_country', 'flexibility': 'green'},
        'languages': {'skipped': true},
      },
    ),
    'Article 9 refusal still bypasses the special-category block',
  );
  check(
    !checkpointComplete(christianFamily: null, article9Consent: null),
    'undecided Article 9 consent does not bypass special-category checks',
  );
  check(
    !checkpointComplete(photoCount: 2),
    'checkpoint still requires three photos',
  );
  check(
    !checkpointComplete(location: ' '),
    'checkpoint still requires location',
  );
  check(
    !checkpointComplete(languages: const [], article9Consent: false),
    'Article 9 refusal does not bypass the languages field',
  );
  final noDistanceLight = checkpointPreferences();
  (noDistanceLight['location'] as Map).remove('flexibility');
  check(
    !checkpointComplete(preferences: noDistanceLight),
    'checkpoint still requires distance flexibility',
  );
  final skippedCountry = checkpointPreferences();
  skippedCountry['country_of_birth'] = {'skipped': true};
  check(
    checkpointComplete(preferences: skippedCountry),
    'explicit country preference skip still bypasses its light',
  );
  final noCountryAnswer = checkpointPreferences();
  noCountryAnswer['country_of_birth'] = {'skipped': true};
  check(
    !checkpointComplete(countryOfBirth: null, preferences: noCountryAnswer),
    'country preference skip does not bypass own country answer',
  );
  final skippedLanguagePreference = checkpointPreferences();
  skippedLanguagePreference['languages'] = {'skipped': true};
  check(
    checkpointComplete(preferences: skippedLanguagePreference),
    'explicit language preference skip still works',
  );
  final legacyFaithOnly = checkpointPreferences();
  legacyFaithOnly.remove('church_background');
  legacyFaithOnly.remove('faith_journey');
  legacyFaithOnly['sect'] = {'outside_flexibility': 'green'};
  legacyFaithOnly['revert'] = {'flexibility': 'green'};
  check(
    !checkpointComplete(preferences: legacyFaithOnly),
    'legacy faith keys cannot satisfy Christian completion',
  );

  print('PASS: $checks pure local model, question-bank and history checks.');
}
