// Pure Dart model checks, no Flutter engine, backend, native plugin or wrappers.
import '../lib/dev/selah_view_request_draft_model.dart';
import '../lib/dev/selah_browse_history.dart';
import '../lib/data/chapter3_categories.dart';
import '../lib/data/selah_reference_data.dart';
import '../lib/models/onboarding_question.dart';
import 'package:selah/models/seeker_profile_completion.dart';
import 'package:selah/models/selah_faith_profile.dart';
import 'package:selah/data/selah_christian_traditions.dart';
import 'package:selah/data/compatibility_categories.dart';
import 'package:selah/models/selah_your_values.dart';
import 'test_ask_once.dart' show runAskOnceChecks;
import 'test_marriage_values.dart' show runMarriageValuesChecks;
import 'test_prayer_models.dart' show runPrayerModelChecks;
import 'test_shepherd_recent.dart' show runShepherdRecentChecks;
import 'test_your_values.dart' show runYourValuesChecks;
import 'test_marriage_upfront.dart' show runMarriageUpfrontChecks;

void main() {
  var checks = 0;
  void check(bool value, String label) {
    checks++;
    if (!value) throw StateError('FAILED: $label');
  }

  runAskOnceChecks(check);
  runMarriageValuesChecks(check);
  runPrayerModelChecks(check);
  runShepherdRecentChecks(check);
  runYourValuesChecks(check);
  runMarriageUpfrontChecks(check);

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
  check(ids.length == 27, 'LOCK17 asks exactly27 questions');
  for (var i = 1; i <= 104; i++)
    check(
      ids.contains('ch3_q$i') == selahYourValuesQuestionIds.contains('ch3_q$i'),
      'question $i follows the explicit LOCK17 keep set',
    );
  final church = chapter3CompatibilityCategories
      .expand((category) => category.questions)
      .firstWhere((q) => q.id == 'ch3_q39');
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
  check(
    compatibilityCategories.length == 8,
    'LOCK17 has seven parts plus Location & Language',
  );
  final profileCompatibility = compatibilityCategories.singleWhere(
    (category) => category.id == 'culture_location',
  );
  check(
    profileCompatibility.chapter2Keys.join('|') == 'location|languages',
    'profile compatibility reads only location and languages',
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
    'faith_profile': <String, dynamic>{
      'church': 'Every week',
      'baptised': 'Yes',
    },
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
    checkpointComplete(
      preferences: checkpointPreferences(faithJourneyFlexibility: null),
    ),
    'locked Faith completion no longer requires old faith journey flexibility',
  );
  check(
    checkpointComplete(
      preferences: checkpointPreferences(faithJourneyFlexibility: 'blue'),
    ),
    'unused old faith journey flexibility does not block locked completion',
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
    checkpointComplete(
      countryOfBirth: null,
      nationality: null,
      ethnicity: null,
      preferences: noCountryAnswer,
    ),
    'removed background answers are no longer required',
  );
  final skippedLanguagePreference = checkpointPreferences();
  skippedLanguagePreference['languages'] = {'skipped': true};
  check(
    checkpointComplete(preferences: skippedLanguagePreference),
    'explicit language preference skip still works',
  );
  final languagesOnly = checkpointPreferences();
  for (final key in [
    'country_of_birth',
    'nationality',
    'ethnicity',
    'languages',
  ]) {
    languagesOnly.remove(key);
  }
  check(
    checkpointComplete(preferences: languagesOnly),
    'removed background and language preferences do not block completion',
  );
  check(
    !checkpointComplete(preferences: languagesOnly, languages: const []),
    'one own language remains required',
  );
  check(
    profileCompatibility.name == 'Location & Language',
    'category uses the locked Location & Language name',
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

  // The new Faith questions use real shared pure answer/mapping logic.
  final emptyFaith = SelahFaithProfileAnswers();
  check(!emptyFaith.requiredComplete, 'Faith requires answers before saving');
  final completeFaith = SelahFaithProfileAnswers(
    tradition: 'Baptist',
    church: 'Every week',
    baptised: 'Yes',
    christianFor: '5–10 years',
    openness: 'Similar traditions only',
  );
  check(completeFaith.canSave, 'optional serving and words may stay empty');
  for (final question in const [1, 2, 3, 4, 6]) {
    final raw = completeFaith.toMap();
    raw[const {
          1: 'tradition',
          2: 'church',
          3: 'baptised',
          4: 'christianFor',
          6: 'openness',
        }[question]!] =
        null;
    check(
      !SelahFaithProfileAnswers.fromMap(raw).requiredComplete,
      'Faith required question $question cannot be omitted',
    );
    raw[const {
          1: 'tradition',
          2: 'church',
          3: 'baptised',
          4: 'christianFor',
          6: 'openness',
        }[question]!] =
        'invented answer';
    check(
      !SelahFaithProfileAnswers.fromMap(raw).requiredComplete,
      'Faith required question $question rejects answers outside LOCK',
    );
  }
  for (final entry in const {
    'Anglican': 'Anglican & Episcopal',
    'Baptist': 'Protestant',
    'Methodist': 'Protestant',
    'Presbyterian': 'Protestant',
    'Catholic': 'Catholic',
    'Orthodox': 'Orthodox & Eastern Christian',
    'Pentecostal': 'Pentecostal, Charismatic & Apostolic',
    'Non-denominational': 'Independent & Non-denominational',
    'Another tradition': 'Another Christian tradition or movement',
  }.entries) {
    final answer = SelahFaithProfileAnswers(tradition: entry.key);
    check(
      answer.christianFamily == entry.value,
      'Faith ${entry.key} maps to the locked canonical family',
    );
    check(
      selahChristianFamilyForLabel(answer.christianFamily) != null,
      'Faith ${entry.key} canonical family exists in real taxonomy',
    );
  }
  check(
    completeFaith.christianDenomination == 'Baptist',
    'exact Protestant Baptist denomination is retained',
  );
  for (final choice in const ['Methodist', 'Presbyterian']) {
    check(
      SelahFaithProfileAnswers(tradition: choice).christianDenomination == null,
      '$choice does not guess a broader denomination label',
    );
  }
  for (final label in SelahFaithProfileAnswers.optionsFor(4)) {
    final answer = SelahFaithProfileAnswers(christianFor: label);
    check(
      answer.faithJourneyCode ==
          (label == 'All my life'
              ? 'raised_christian'
              : 'became_christian_later'),
      'Christian duration $label maps to locked saved code',
    );
    check(
      selahFaithJourneyCodeForLabel(answer.faithJourneyLabel) ==
          answer.faithJourneyCode,
      'Christian duration $label remains display typed at serializer boundary',
    );
    check(
      answer.toMap()['christianFor'] == label,
      'Christian duration $label remains exact for Profile',
    );
  }
  for (final entry in const {
    'Yes, any tradition': ['no_preference', 'green', false],
    'Similar traditions only': ['same_family', 'yellow', false],
    'My own tradition only': ['same_family', 'red', true],
  }.entries) {
    final answer = SelahFaithProfileAnswers(openness: entry.key);
    check(
      answer.churchPreferenceScope == entry.value[0] &&
          answer.outsideFlexibility == entry.value[1] &&
          answer.firmPreference == entry.value[2],
      'Faith openness ${entry.key} has exact scope/light/firm mapping',
    );
  }
  var serving = emptyFaith.choose(5, 0).choose(5, 1);
  check(
    serving.serving.join(', ') == 'Worship, Youth',
    'Faith serving accepts multiple selected options',
  );
  serving = serving.choose(5, 7);
  check(
    serving.serving.length == 1 && serving.serving.single == 'Not right now',
    'Not right now clears every serving selection',
  );
  serving = serving.choose(5, 5);
  check(
    serving.serving.length == 1 && serving.serving.single == 'Prayer',
    'a real serving selection clears Not right now',
  );
  check(
    serving.choose(5, 5).serving.isEmpty,
    'serving selection can be unmarked',
  );
  check(
    serving.withoutServing().serving.isEmpty,
    'optional serving Skip clears selections',
  );
  check(
    identical(serving.choose(5, -1), serving) &&
        identical(serving.choose(5, 8), serving),
    'invalid serving indexes do not mutate answers',
  );
  check(
    SelahFaithProfileAnswers(
          serving: ['Youth', 'Not right now', 'Prayer'],
        ).serving.single ==
        'Not right now',
    'restored serving preserves exclusive Not right now',
  );
  final inputServing = <String>['Youth'];
  final detachedServing = SelahFaithProfileAnswers(serving: inputServing);
  inputServing.add('Prayer');
  check(
    detachedServing.serving.length == 1,
    'Faith serving owns a detached list',
  );
  var servingMutationRejected = false;
  try {
    detachedServing.serving.add('Prayer');
  } on UnsupportedError {
    servingMutationRejected = true;
  }
  check(servingMutationRejected, 'Faith serving read is immutable');
  final ascii150 = completeFaith.withWords(List.filled(150, 'a').join());
  final emoji150 = completeFaith.withWords(List.filled(150, '🙏').join());
  check(
    ascii150.characterCount == 150 && ascii150.canSave,
    '150 ordinary characters are accepted',
  );
  check(
    emoji150.characterCount == 150 && emoji150.canSave,
    '150 supplementary Unicode characters are accepted without UTF16 double count',
  );
  final over150 = emoji150.withWords('${emoji150.words}🙏');
  check(
    over150.characterCount == 151 && !over150.canSave,
    '151 Unicode characters remain present and block saving',
  );
  final retainedPreferences = <String, dynamic>{
    'unknown': {'keep': true},
    'faith_journey': {'flexibility': 'red'},
    'faith_profile': {'unknown': 'keep'},
    'church_background': {
      'scope': 'selected',
      'family_codes': ['catholic'],
      'hard_requirement': true,
      'unknown': 'keep',
    },
  };
  final mergedFaith = completeFaith.mergePreferences(retainedPreferences);
  check(
    (mergedFaith['faith_journey'] as Map)['flexibility'] == 'red',
    'Faith save preserves unused old faith journey preference',
  );
  check(
    (mergedFaith['unknown'] as Map)['keep'] == true &&
        (mergedFaith['faith_profile'] as Map)['unknown'] == 'keep' &&
        (mergedFaith['church_background'] as Map)['unknown'] == 'keep',
    'Faith save preserves unrelated and unknown preferences',
  );
  check(
    (mergedFaith['church_background'] as Map)['hard_requirement'] == false,
    'Similar tradition choice clears stale own-tradition hard requirement',
  );
  check(
    (retainedPreferences['church_background'] as Map)['scope'] == 'selected' &&
        !(retainedPreferences['faith_profile'] as Map).containsKey('church'),
    'Faith preference merge does not mutate the prior saved object',
  );
  final roundTripFaith = SelahFaithProfileAnswers.fromMap(
    mergedFaith['faith_profile'] as Map,
  );
  check(
    roundTripFaith.tradition == completeFaith.tradition &&
        roundTripFaith.christianFor == '5–10 years' &&
        roundTripFaith.church == completeFaith.church &&
        roundTripFaith.baptised == completeFaith.baptised &&
        roundTripFaith.openness == completeFaith.openness,
    'exact Faith profile choices round trip through existing preferences JSON shape',
  );
  for (final field in const ['church', 'baptised']) {
    for (final invalid in [null, '', 'invented answer', false]) {
      final preferences = checkpointPreferences();
      (preferences['faith_profile'] as Map)[field] = invalid;
      check(
        !checkpointComplete(preferences: preferences),
        'checkpoint requires closed Faith $field answer ($invalid)',
      );
      check(
        checkpointComplete(preferences: preferences, article9Consent: false),
        'Article 9 false still bypasses Faith $field answer ($invalid)',
      );
    }
  }
  for (final label in SelahFaithProfileAnswers.optionsFor(2)) {
    final preferences = checkpointPreferences();
    (preferences['faith_profile'] as Map)['church'] = label;
    check(
      checkpointComplete(preferences: preferences),
      'checkpoint accepts locked Church answer $label',
    );
  }
  for (final label in SelahFaithProfileAnswers.optionsFor(3)) {
    final preferences = checkpointPreferences();
    (preferences['faith_profile'] as Map)['baptised'] = label;
    check(
      checkpointComplete(preferences: preferences),
      'checkpoint accepts locked Baptised answer $label',
    );
  }

  final marriage = ViewRequestDraftModel(capacity: 3);
  check(
    marriage.seedJourneys(2),
    'marriage preparation uses two real local Journeys',
  );
  final firstJourney = draftProfiles[1].id;
  final secondJourney = draftProfiles[2].id;
  check(
    !marriage.toggleMarriagePrepStep(firstJourney, 0),
    'marriage preparation is unavailable before Open Conversation',
  );
  check(
    !marriage.toggleMarriagePrepStep('unknown-journey', 0),
    'unknown Journeys cannot acquire marriage preparation',
  );
  check(
    marriage.marriagePrepCompletedFor('unknown-journey').isEmpty,
    'unknown Journey has no marriage preparation facts',
  );

  void reachConversation(String id) {
    // Reach the destination through the existing public two-person actions;
    // this never writes a stage index or skips a gate for the new card.
    while (marriage.stageFor(id)?.value != 'conversation') {
      final stage = marriage.stageFor(id)!;
      if (stage.value == 'greeting_exchange') {
        check(marriage.sendGreeting(id), 'marriage fixture sends own greeting');
        check(
          marriage.simulatePeerGreeting(id),
          'marriage fixture receives peer greeting',
        );
      } else if (stage.value == 'compatibility_reveal') {
        check(
          marriage.chooseCompatibilityReveal(id),
          'marriage fixture chooses reveal',
        );
        check(
          marriage.simulatePeerCompatibilityReveal(id),
          'marriage fixture receives reveal',
        );
      }
      check(
        marriage.chooseStageContinue(id),
        'marriage fixture chooses stage continuation',
      );
      check(
        marriage.simulatePeerStageContinue(id),
        'marriage fixture receives peer continuation',
      );
      check(
        marriage.advanceStage(id),
        'marriage fixture advances with both choices',
      );
    }
    check(
      marriage.conversationOpen(id),
      'marriage fixture reaches Open Conversation',
    );
  }

  reachConversation(firstJourney);
  final firstMemberRead = marriage.marriagePrepCompletedFor(firstJourney);
  check(firstMemberRead.isEmpty, 'marriage preparation starts with no ticks');
  check(
    marriage.toggleMarriagePrepStep(firstJourney, 2),
    'course may be finished before earlier ticks',
  );
  check(
    marriage.toggleMarriagePrepStep(firstJourney, 0),
    'first preparation step toggles independently',
  );
  check(
    marriage.toggleMarriagePrepStep(firstJourney, 1),
    'all three preparation steps can be marked',
  );
  check(
    firstMemberRead.length == 3,
    'existing member read observes shared Journey ticks',
  );
  final otherMemberRead = marriage.marriagePrepCompletedFor(firstJourney);
  check(
    otherMemberRead.containsAll(const [0, 1, 2]),
    'another presentation of the same Journey sees the same facts',
  );
  check(
    marriage.toggleMarriagePrepStep(firstJourney, 0),
    'marked preparation step may be unmarked',
  );
  check(
    firstMemberRead.length == 2 && !otherMemberRead.contains(0),
    'unmark is visible to both member presentations',
  );
  check(
    marriage.marriagePrepCompletedFor(secondJourney).isEmpty,
    'ticks are isolated from another Journey',
  );
  check(
    !marriage.toggleMarriagePrepStep(secondJourney, 1),
    'another Journey must independently reach Open Conversation',
  );
  for (final invalid in const [-1, 3, 99]) {
    check(
      !marriage.toggleMarriagePrepStep(firstJourney, invalid),
      'invalid preparation index $invalid is refused',
    );
  }
  check(
    firstMemberRead.length == 2 && firstMemberRead.containsAll(const [1, 2]),
    'invalid indexes preserve the completed steps',
  );
  var readIsImmutable = false;
  try {
    firstMemberRead.add(0);
  } on UnsupportedError {
    readIsImmutable = true;
  }
  check(
    readIsImmutable &&
        !marriage.marriagePrepCompletedFor(firstJourney).contains(0),
    'a read cannot mutate marriage preparation',
  );
  marriage.setOwnMainShepherdPresent(false);
  check(
    !marriage.toggleMarriagePrepStep(firstJourney, 0),
    'missing own Shepherd cannot bypass the existing Journey gate',
  );
  marriage.setOwnMainShepherdPresent(true);
  marriage.setPeerMainShepherdPresent(false, id: firstJourney);
  check(
    !marriage.toggleMarriagePrepStep(firstJourney, 0),
    'missing peer Shepherd cannot bypass the existing Journey gate',
  );
  marriage.setPeerMainShepherdPresent(true, id: firstJourney);
  check(
    marriage.requestPause(firstJourney),
    'marriage fixture requests existing Journey pause',
  );
  check(
    !marriage.toggleMarriagePrepStep(firstJourney, 0),
    'pending pause retains the existing participation gate',
  );
  check(
    marriage.continueJourney(firstJourney),
    'marriage fixture continues existing Journey',
  );
  reachConversation(secondJourney);
  check(
    marriage.toggleMarriagePrepStep(secondJourney, 0),
    'another Open Conversation owns its own tick set',
  );
  check(
    firstMemberRead.length == 2,
    'another Journey tick does not overwrite the first',
  );
  check(
    marriage.end(secondJourney),
    'marriage fixture ends an existing Journey',
  );
  check(
    !marriage.toggleMarriagePrepStep(secondJourney, 1),
    'ended Journey cannot change preparation',
  );
  check(
    marriage.marriagePrepCompletedFor(secondJourney).contains(0),
    'ended Journey retains its existing preparation facts',
  );
  check(
    marriage.block(firstJourney),
    'marriage fixture blocks its existing peer',
  );
  check(
    !marriage.toggleMarriagePrepStep(firstJourney, 0),
    'blocked peer cannot change preparation',
  );
  marriage.reset();
  check(
    marriage.marriagePrepCompletedFor(firstJourney).isEmpty &&
        marriage.marriagePrepCompletedFor(secondJourney).isEmpty &&
        firstMemberRead.isEmpty &&
        otherMemberRead.isEmpty,
    'reset clears preparation, including existing read views',
  );

  print('PASS: $checks pure local model, question-bank and history checks.');
}
