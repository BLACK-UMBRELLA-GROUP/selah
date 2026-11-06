import 'dart:collection';

import '../data/selah_journey_stages.dart';
import '../data/selah_reference_data.dart' show selahRelationshipLabel;
import '../models/selah_marriage_values.dart';

/// Disposable request/transition UI, not a new canonical server lifecycle.
/// This model has no account, storage, entitlement or backend dependency.
enum DraftJourneyState {
  received,
  sent,
  preparing,
  active,
  pauseRequested,
  paused,
  resumeRequested,
  ended,
}

/// Invented preview plans only; these never prove a real entitlement.
enum DraftShepherdMembership { basic, one }

/// Invented adult fixtures. Heritage labels and residence metadata below are
/// independent sample values, not inferred from names, photos or city labels,
/// and never loaded from a real member's private compatibility answers.
class DraftProfile {
  const DraftProfile({
    required this.id,
    required this.firstName,
    this.surname = '',
    required this.age,
    required this.city,
    this.residenceCountryCode,
    this.nationalityCode,
    this.ethnicityCode,
    this.sampleLatitude,
    this.sampleLongitude,
    this.faithTradition,
    this.churchAttendance,
    this.baptised,
    this.faithWords = '',
    this.marriageValues = const {},
  });

  final String id;
  final String firstName;
  final String surname;
  final int age;
  final String city;
  final String? residenceCountryCode;
  final String? nationalityCode;
  final String? ethnicityCode;
  final double? sampleLatitude;
  final double? sampleLongitude;
  final String? faithTradition;
  final String? churchAttendance;
  final String? baptised;
  final String faithWords;
  final Map<String, String> marriageValues;
  SelahMarriageValuesAnswers get marriageAnswers =>
      SelahMarriageValuesAnswers.fromMap(marriageValues);
}

const List<DraftProfile> draftProfiles = [
  DraftProfile(
    id: 'draft-amira',
    firstName: 'Grace',
    marriageValues: {
      'marriedBefore': 'No',
      'children': 'No',
      'wouldLikeChildren': 'Yes',
      'rolesInMarriage': 'Equal partners who decide together',
      'openToDivorced': 'Yes',
      'whereToLive': 'Near where I live now',
      'hopingToMarry': 'In 1–2 years',
    },
    surname: 'Clarke',
    age: 29,
    city: 'Leeds',
    residenceCountryCode: 'GB',
    nationalityCode: 'GB',
    ethnicityCode: 'mixed',
    sampleLatitude: 53.80,
    sampleLongitude: -1.55,
    faithTradition: 'Anglican',
    churchAttendance: 'Every week',
    baptised: 'Yes',
    faithWords:
        'Church is my second family. I serve on the welcome team and I want a home where faith is part of every day.',
  ),
  DraftProfile(
    id: 'draft-sara',
    firstName: 'Esther',
    marriageValues: {
      'marriedBefore': 'No',
      'children': 'No',
      'wouldLikeChildren': 'Yes',
      'rolesInMarriage': 'Somewhere in between',
      'openToDivorced': 'It depends on the situation',
      'whereToLive': 'Open to moving within my country',
      'hopingToMarry': 'When it’s the right person',
    },
    surname: 'Mensah',
    age: 31,
    city: 'Birmingham',
    residenceCountryCode: 'GB',
    nationalityCode: 'GB',
    ethnicityCode: 'black_african',
    sampleLatitude: 52.48,
    sampleLongitude: -1.90,
    faithTradition: 'Pentecostal',
    churchAttendance: 'Every week',
    baptised: 'Yes',
    faithWords:
        'I lead a small group on Thursdays. Looking for someone who prays with me and laughs easily.',
  ),
  DraftProfile(
    id: 'draft-aisha',
    firstName: 'Naomi',
    marriageValues: {
      'marriedBefore': 'Yes, widowed',
      'children': 'Yes, they live with me',
      'wouldLikeChildren': 'Open to it',
      'rolesInMarriage': 'Equal partners who decide together',
      'openToDivorced': 'Yes',
      'whereToLive': 'Near where I live now',
      'hopingToMarry': 'Within a year',
    },
    surname: 'Fernandes',
    age: 27,
    city: 'London',
    residenceCountryCode: 'GB',
    nationalityCode: 'GB',
    ethnicityCode: 'mixed',
    sampleLatitude: 51.51,
    sampleLongitude: -0.13,
    faithTradition: 'Non-denominational',
    churchAttendance: 'Most weeks',
    baptised: 'Yes',
    faithWords:
        'I sing in the worship team. Family matters a lot to me and I would love children one day.',
  ),
  DraftProfile(
    id: 'draft-maryam',
    firstName: 'Abigail',
    marriageValues: {
      'marriedBefore': 'Yes, divorced',
      'children': 'No',
      'wouldLikeChildren': 'Yes',
      'rolesInMarriage': 'The husband leads, with love and care',
      'openToDivorced': 'Yes',
      'whereToLive': 'Open to moving abroad',
      'hopingToMarry': 'In 1–2 years',
    },
    surname: 'Reyes',
    age: 33,
    city: 'Manchester',
    residenceCountryCode: 'GB',
    nationalityCode: 'GB',
    ethnicityCode: 'mixed',
    sampleLatitude: 53.48,
    sampleLongitude: -2.24,
    faithTradition: 'Catholic',
    churchAttendance: 'Every week',
    baptised: 'Yes',
    faithWords:
        'Faith, family, then work. I volunteer at our parish food bank on Saturdays.',
  ),
  DraftProfile(
    id: 'draft-hana',
    firstName: 'Ruth',
    surname: 'Adeyemi',
    age: 30,
    city: 'Bristol',
    residenceCountryCode: 'GB',
    nationalityCode: 'GB',
    ethnicityCode: 'black_african',
    sampleLatitude: 51.45,
    sampleLongitude: -2.59,
    faithTradition: 'Baptist',
    churchAttendance: 'Every week',
    baptised: 'Yes',
  ),
  DraftProfile(
    id: 'draft-noor',
    firstName: 'Lydia',
    surname: 'Thomas',
    age: 25,
    city: 'Nottingham',
    residenceCountryCode: 'GB',
    nationalityCode: 'GB',
    ethnicityCode: 'mixed',
    sampleLatitude: 52.95,
    sampleLongitude: -1.15,
    faithTradition: 'Methodist',
    churchAttendance: 'Most weeks',
    baptised: 'Not yet',
  ),
  DraftProfile(
    id: 'draft-zainab',
    firstName: 'Phoebe',
    surname: 'Wright',
    age: 28,
    city: 'Cardiff',
    residenceCountryCode: 'GB',
    nationalityCode: 'GB',
    ethnicityCode: 'white',
    sampleLatitude: 51.48,
    sampleLongitude: -3.18,
    faithTradition: 'Presbyterian',
    churchAttendance: 'Sometimes',
    baptised: 'Yes',
  ),
  DraftProfile(
    id: 'draft-safiya',
    firstName: 'Chloe',
    surname: 'Bennett',
    age: 27,
    city: 'Liverpool',
    residenceCountryCode: 'GB',
    nationalityCode: 'GB',
    ethnicityCode: 'white',
    sampleLatitude: 53.41,
    sampleLongitude: -2.98,
    faithTradition: 'Orthodox',
    churchAttendance: 'Most weeks',
    baptised: 'Yes',
  ),
];

/// Presentation-only relationships. These never become live Shepherd grants.
class DraftShepherd {
  const DraftShepherd({
    required this.id,
    required this.firstName,
    required this.surname,
    required this.relationshipCode,
    required this.linkedAt,
    required this.isMain,
  });

  final String id;
  final String firstName;
  final String surname;
  final String relationshipCode;
  final DateTime linkedAt;
  String get relationship =>
      selahRelationshipLabel(relationshipCode) ?? 'Shepherd';
  final bool isMain;
}

final List<DraftShepherd> draftShepherds = List.unmodifiable([
  DraftShepherd(
    id: 'draft-shepherd-hassan',
    firstName: 'David',
    surname: 'Okafor',
    relationshipCode: 'pastor',
    linkedAt: DateTime(2026, 9, 20),
    isMain: true,
  ),
  DraftShepherd(
    id: 'draft-shepherd-yusuf',
    firstName: 'Mark',
    surname: 'Carter',
    relationshipCode: 'brother',
    linkedAt: DateTime(2026, 9, 23),
    isMain: false,
  ),
]);

class _DraftJourneyProgress {
  bool ready = false;
  bool peerReady = false;
  int stageIndex = 0;
  bool greeting = false;
  bool peerGreeting = false;
  bool compatibilityConsent = false;
  bool peerCompatibilityConsent = false;
  bool stageContinue = false;
  bool peerStageContinue = false;
  final Set<int> marriagePrepCompleted = <int>{};
}

/// Shared fictional state for all five alternative app destinations.
///
/// Local scenario capacity is configurable from one to three. The shell owns
/// sample-plan selection; this model never proves paid entitlement. Pending
/// requests do not reserve capacity. Accepted preparation reserves BOTH places;
/// either one-sided readiness never starts the Journey or opens chat.
///
/// Pending Pause remains Active-counted. A settled mutual Pause releases the
/// place and restores discovery in this draft ONLY; that visibility policy
/// has not been adopted for production. Resume rechecks both participants.
///
/// Pending requests are bounded only by the finite fictional fixture set.
/// No production request quota, timer, expiry or subscription rule is chosen.
/// Stage labels come from the existing pure canonical source; walkthrough
/// advancement is not real answers, Family Review time or server enforcement.
class ViewRequestDraftModel {
  ViewRequestDraftModel({int capacity = 1}) : _capacity = capacity {
    if (capacity < 1 || capacity > 3) {
      throw RangeError.range(capacity, 1, 3, 'capacity');
    }
    _seed();
  }

  static final Set<String> _fixtureIds = {
    for (final profile in draftProfiles) profile.id,
  };

  int _capacity;
  final Map<String, DraftJourneyState> _states = {};
  final Set<String> _saved = {};
  final Set<String> _busyPeers = {};
  final Set<String> _hiddenPeers = {};
  final Set<String> _blockedPeers = {};
  final Map<String, _DraftJourneyProgress> _progress = {};
  final Map<String, bool> _peerMainShepherdOverrides = {};
  final Map<String, DraftShepherdMembership> _shepherdMemberships = {};
  final Map<String, ({bool view, bool chat})> _shepherdAccess = {};
  bool _ownMainShepherd = true;
  bool _peerMainShepherd = true;

  int get capacity => _capacity;
  Map<String, DraftJourneyState> get states => UnmodifiableMapView(_states);
  Set<String> get saved => UnmodifiableSetView(_saved);
  Set<String> get hiddenPeers => UnmodifiableSetView(_hiddenPeers);
  Set<String> get blockedPeers => UnmodifiableSetView(_blockedPeers);
  bool isHidden(String id) => _hiddenPeers.contains(id);
  bool isBlocked(String id) => _blockedPeers.contains(id);

  /// Only disposable fictional visibility changes; archive records survive.
  bool hide(String id) {
    if (!_fixtureIds.contains(id)) return false;
    _hiddenPeers.add(id);
    return true;
  }

  bool block(String id) {
    if (!_fixtureIds.contains(id)) return false;
    _blockedPeers.add(id);
    return true;
  }

  int get activeCount => _states.values
      .where(
        (state) =>
            state == DraftJourneyState.active ||
            state == DraftJourneyState.pauseRequested,
      )
      .length;
  int get preparingCount => _states.values
      .where((state) => state == DraftJourneyState.preparing)
      .length;
  int get occupiedCount => activeCount + preparingCount;
  bool get hasCapacity => occupiedCount < capacity;
  bool get discoverable => hasCapacity;

  /// Viewing/sending is independent of reserving a fourth place. The new
  /// full-capacity policy is scoped to monthly three-place previews; Basic
  /// keeps its current one-place presentation. Visibility to others is still
  /// [discoverable], not permission to inspect public profiles.
  bool get canBrowse => hasCapacity || capacity == 3;

  /// Ended peers can be viewed again without resurrecting the old attempt.
  /// A fresh request to the same peer remains held until distinct attempt
  /// history is modelled; terminal records are never overwritten.
  List<DraftProfile> get discoverableProfiles => List.unmodifiable(
    draftProfiles.where((profile) {
      final state = _states[profile.id];
      return !isHidden(profile.id) &&
          !isBlocked(profile.id) &&
          !peerOccupied(profile.id) &&
          state != DraftJourneyState.paused &&
          state != DraftJourneyState.resumeRequested;
    }),
  );
  List<DraftProfile> get availableProfiles => discoverableProfiles;

  bool get ownMainShepherdPresent => _ownMainShepherd;

  bool _knownShepherd(String id) => draftShepherds.any((g) => g.id == id);

  DraftShepherdMembership? sampleShepherdMembershipFor(String id) =>
      _knownShepherd(id)
      ? (_shepherdMemberships[id] ?? DraftShepherdMembership.one)
      : null;

  bool canUseSampleShepherdChat(String id) =>
      sampleShepherdMembershipFor(id) == DraftShepherdMembership.one;

  bool setSampleShepherdMembership(String id, DraftShepherdMembership value) {
    if (!_knownShepherd(id)) return false;
    _shepherdMemberships[id] = value;
    if (value == DraftShepherdMembership.basic) {
      // Revocation is stored, not merely painted disabled. Upgrading later
      // cannot silently restore an Additional Shepherd's earlier chat grant.
      for (final profile in draftProfiles) {
        final key = '$id|${profile.id}';
        final old = _shepherdAccess[key];
        _shepherdAccess[key] = (view: old?.view ?? true, chat: false);
      }
    }
    return true;
  }

  ({bool view, bool chat}) sampleShepherdAccessFor(
    String shepherdId,
    String peerId, {
    bool isMain = false,
  }) {
    if (!_knownShepherd(shepherdId) ||
        !_fixtureIds.contains(peerId) ||
        isBlocked(peerId)) {
      return (view: false, chat: false);
    }
    final grant =
        _shepherdAccess['$shepherdId|$peerId'] ?? (view: true, chat: true);
    final view = isMain || grant.view;
    return (
      view: view,
      chat:
          canUseSampleShepherdChat(shepherdId) &&
          view &&
          (isMain || grant.chat),
    );
  }

  /// Local write boundary, independently rejecting forged Basic chat grants
  /// and retired/stale Journey destinations before recording any change.
  bool setSampleShepherdJourneyAccess(
    String shepherdId,
    String peerId, {
    bool? viewEnabled,
    bool? chatEnabled,
  }) {
    final state = _states[peerId];
    if (!_knownShepherd(shepherdId) ||
        isBlocked(peerId) ||
        (state != DraftJourneyState.active &&
            state != DraftJourneyState.pauseRequested) ||
        (chatEnabled == true && !canUseSampleShepherdChat(shepherdId))) {
      return false;
    }
    final old = sampleShepherdAccessFor(shepherdId, peerId);
    final view = viewEnabled ?? old.view;
    if (chatEnabled == true && !view) return false;
    _shepherdAccess['$shepherdId|$peerId'] = (
      view: view,
      chat:
          view &&
          canUseSampleShepherdChat(shepherdId) &&
          (chatEnabled ?? old.chat),
    );
    return true;
  }

  bool get peerMainShepherdPresent => _peerMainShepherd;
  bool peerMainShepherdPresentFor(String id) =>
      _fixtureIds.contains(id) &&
      (_peerMainShepherdOverrides[id] ?? _peerMainShepherd);
  bool _mainLeadershipPresent(String id) =>
      _ownMainShepherd && peerMainShepherdPresentFor(id);
  void setOwnMainShepherdPresent(bool present) => _ownMainShepherd = present;

  /// Without an id this retains the legacy uniform fixture control. An id
  /// changes only that fictional counterpart; own Main leadership is shared.
  bool setPeerMainShepherdPresent(bool present, {String? id}) {
    if (id != null) {
      if (!_fixtureIds.contains(id)) return false;
      _peerMainShepherdOverrides[id] = present;
    } else {
      _peerMainShepherd = present;
      _peerMainShepherdOverrides.clear();
    }
    return true;
  }

  DraftJourneyState? stateFor(String id) => _states[id];

  /// Includes this pair's reservation, without exposing another Journey's
  /// partner, reason, duration or any other private counterpart information.
  bool peerOccupied(String id) =>
      _busyPeers.contains(id) || _usesActivePlace(_states[id]);

  /// Explicit scenario control only. An occupied place already reserved for
  /// this pair cannot simultaneously be assigned to an unrelated sample pair.
  bool setPeerOccupied(String id, bool occupied) {
    if (!_fixtureIds.contains(id) ||
        (occupied && _usesActivePlace(_states[id]))) {
      return false;
    }
    if (occupied) {
      _busyPeers.add(id);
    } else {
      _busyPeers.remove(id);
    }
    return true;
  }

  bool canRequest(String id) =>
      _fixtureIds.contains(id) &&
      !isBlocked(id) &&
      !isHidden(id) &&
      !_states.containsKey(id) &&
      canBrowse &&
      !peerOccupied(id);
  bool canAccept(String id) =>
      (_states[id] == DraftJourneyState.received ||
          _states[id] == DraftJourneyState.sent) &&
      !isBlocked(id) &&
      hasCapacity &&
      !peerOccupied(id);

  /// A valid acceptance intent can reach the explicit capacity chooser while
  /// full. It does not itself accept, reserve a place or open conversation.
  bool canAttemptAccept(String id) =>
      canAccept(id) ||
      (capacity == 3 &&
          !hasCapacity &&
          (_states[id] == DraftJourneyState.received ||
              _states[id] == DraftJourneyState.sent) &&
          !isBlocked(id) &&
          !peerOccupied(id));

  bool canReplaceJourneyForRequest(
    String requestId,
    String endingId, {
    required bool incoming,
  }) =>
      capacity == 3 &&
      occupiedCount == capacity &&
      _fixtureIds.contains(requestId) &&
      _fixtureIds.contains(endingId) &&
      requestId != endingId &&
      _states[requestId] ==
          (incoming ? DraftJourneyState.received : DraftJourneyState.sent) &&
      !isBlocked(requestId) &&
      !peerOccupied(requestId) &&
      _usesActivePlace(_states[endingId]);

  /// One synchronous fictional transition after explicit End confirmation.
  /// Validate every condition before retiring anything. There is no await,
  /// intermediate notification, fourth reservation, erased old progress or
  /// implicit readiness/chat/reveal. Real replacement needs server authority.
  bool replaceJourneyForRequest(
    String requestId,
    String endingId, {
    required bool incoming,
  }) {
    if (!canReplaceJourneyForRequest(requestId, endingId, incoming: incoming)) {
      return false;
    }
    _states[endingId] = DraftJourneyState.ended;
    _states[requestId] = DraftJourneyState.preparing;
    _progress[requestId] = _DraftJourneyProgress();
    return true;
  }

  bool canResume(String id) =>
      _states[id] == DraftJourneyState.paused &&
      !isBlocked(id) &&
      _mainLeadershipPresent(id) &&
      hasCapacity &&
      !peerOccupied(id);

  /// inherited decision 236: missing Main leadership holds ordinary Active participation,
  /// not just the Shepherd Gate. Pause and End remain independently available.
  bool canParticipateInJourney(String id) =>
      _states[id] == DraftJourneyState.active &&
      !isBlocked(id) &&
      _mainLeadershipPresent(id);

  bool request(String id) {
    if (!canRequest(id)) return false;
    _states[id] = DraftJourneyState.sent;
    return true;
  }

  bool cancel(String id) {
    if (_states[id] != DraftJourneyState.sent) return false;
    _states.remove(id);
    return true;
  }

  bool declineReceived(String id) {
    if (_states[id] != DraftJourneyState.received) return false;
    _states.remove(id);
    return true;
  }

  bool acceptReceived(String id) => _accept(id, DraftJourneyState.received);
  bool simulateRecipientAccept(String id) =>
      _accept(id, DraftJourneyState.sent);

  bool _accept(String id, DraftJourneyState expected) {
    if (_states[id] != expected || !canAccept(id)) return false;
    _states[id] = DraftJourneyState.preparing;
    _progress[id] = _DraftJourneyProgress();
    return true;
  }

  bool isReady(String id) => _progress[id]?.ready ?? false;
  bool peerIsReady(String id) => _progress[id]?.peerReady ?? false;

  bool markReady(String id) {
    if (isBlocked(id) ||
        _states[id] != DraftJourneyState.preparing ||
        isReady(id)) {
      return false;
    }
    _progress[id]!.ready = true;
    return true;
  }

  bool simulatePeerReady(String id) {
    if (isBlocked(id) ||
        _states[id] != DraftJourneyState.preparing ||
        peerIsReady(id)) {
      return false;
    }
    _progress[id]!.peerReady = true;
    return true;
  }

  /// Readiness is mutual; beginning is deliberate and starts at Greeting.
  bool beginPreparedJourney(String id) {
    if (isBlocked(id) ||
        _states[id] != DraftJourneyState.preparing ||
        !isReady(id) ||
        !peerIsReady(id) ||
        _busyPeers.contains(id) ||
        occupiedCount > capacity) {
      return false;
    }
    _states[id] = DraftJourneyState.active;
    return true;
  }

  /// Legacy explicit both-person simulation, never an automatic acceptance.
  /// New UI uses the two readiness actions and deliberate begin separately.
  bool completePreparation(String id) {
    if (isBlocked(id) || _states[id] != DraftJourneyState.preparing) {
      return false;
    }
    _progress[id]!
      ..ready = true
      ..peerReady = true;
    return beginPreparedJourney(id);
  }

  SelahJourneyStage? stageFor(String id) {
    final progress = _progress[id];
    return progress == null
        ? null
        : SelahJourneyStages.all[progress.stageIndex];
  }

  bool conversationOpen(String id) =>
      canParticipateInJourney(id) && stageFor(id)?.value == 'conversation';

  /// Shared local Journey facts, not a viewer's own copy or a server record.
  /// Existing readers cannot mutate the set or bypass the Journey's gates.
  Set<int> marriagePrepCompletedFor(String id) => UnmodifiableSetView<int>(
    _progress[id]?.marriagePrepCompleted ?? const <int>{},
  );

  /// LOCK 9 has three independent steps, freely markable in any order at
  /// Open Conversation. A true result means the requested toggle was applied.
  bool toggleMarriagePrepStep(String id, int step) {
    if (step < 0 || step >= 3 || !conversationOpen(id)) return false;
    final completed = _progress[id]!.marriagePrepCompleted;
    if (!completed.add(step)) completed.remove(step);
    return true;
  }

  bool hasSentGreeting(String id) => _progress[id]?.greeting ?? false;
  bool peerHasSentGreeting(String id) => _progress[id]?.peerGreeting ?? false;
  bool greetingComplete(String id) =>
      hasSentGreeting(id) && peerHasSentGreeting(id);

  bool sendGreeting(String id) {
    if (!_atInteractiveStage(id, 'greeting_exchange') || hasSentGreeting(id)) {
      return false;
    }
    _progress[id]!.greeting = true;
    return true;
  }

  bool simulatePeerGreeting(String id) {
    if (!_atInteractiveStage(id, 'greeting_exchange') ||
        peerHasSentGreeting(id)) {
      return false;
    }
    _progress[id]!.peerGreeting = true;
    return true;
  }

  bool hasChosenCompatibilityReveal(String id) =>
      _progress[id]?.compatibilityConsent ?? false;
  bool peerHasChosenCompatibilityReveal(String id) =>
      _progress[id]?.peerCompatibilityConsent ?? false;
  bool compatibilityRevealed(String id) =>
      hasChosenCompatibilityReveal(id) && peerHasChosenCompatibilityReveal(id);

  bool chooseCompatibilityReveal(String id) {
    if (!_atInteractiveStage(id, 'compatibility_reveal') ||
        hasChosenCompatibilityReveal(id)) {
      return false;
    }
    _progress[id]!.compatibilityConsent = true;
    return true;
  }

  bool simulatePeerCompatibilityReveal(String id) {
    if (!_atInteractiveStage(id, 'compatibility_reveal') ||
        peerHasChosenCompatibilityReveal(id)) {
      return false;
    }
    _progress[id]!.peerCompatibilityConsent = true;
    return true;
  }

  bool hasChosenStageContinue(String id) =>
      _progress[id]?.stageContinue ?? false;
  bool peerHasChosenStageContinue(String id) =>
      _progress[id]?.peerStageContinue ?? false;

  bool canChooseStageContinue(String id) =>
      _stageCanBeCompleted(id) && !hasChosenStageContinue(id);
  bool canPeerChooseStageContinue(String id) =>
      _stageCanBeCompleted(id) && !peerHasChosenStageContinue(id);

  bool chooseStageContinue(String id) {
    if (!canChooseStageContinue(id)) return false;
    _progress[id]!.stageContinue = true;
    return true;
  }

  bool simulatePeerStageContinue(String id) {
    if (!canPeerChooseStageContinue(id)) {
      return false;
    }
    _progress[id]!.peerStageContinue = true;
    return true;
  }

  bool canAdvanceStage(String id) =>
      _stageCanBeCompleted(id) &&
      hasChosenStageContinue(id) &&
      peerHasChosenStageContinue(id);

  /// Guided phase actions are sample walkthroughs, not private answers or the
  /// real timed Family Review gates. No scoring is performed anywhere here.
  bool advanceStage(String id) {
    if (!canAdvanceStage(id)) return false;
    final progress = _progress[id]!;
    progress
      ..stageIndex += 1
      ..stageContinue = false
      ..peerStageContinue = false;
    return true;
  }

  bool _atInteractiveStage(String id, String stage) =>
      canParticipateInJourney(id) && stageFor(id)?.value == stage;

  bool _stageCanBeCompleted(String id) {
    final stage = stageFor(id);
    if (!canParticipateInJourney(id) ||
        stage == null ||
        stage.order >= SelahJourneyStages.all.length) {
      return false;
    }
    return switch (stage.value) {
      'greeting_exchange' => greetingComplete(id),
      'compatibility_reveal' => compatibilityRevealed(id),
      'mentor_gate' => _mainLeadershipPresent(id),
      _ => true,
    };
  }

  bool requestPause(String id) =>
      _move(id, DraftJourneyState.active, DraftJourneyState.pauseRequested);
  bool agreePause(String id) =>
      _move(id, DraftJourneyState.pauseRequested, DraftJourneyState.paused);
  bool continueJourney(String id) =>
      _move(id, DraftJourneyState.pauseRequested, DraftJourneyState.active);

  bool requestResume(String id) {
    if (!canResume(id)) return false;
    return _move(
      id,
      DraftJourneyState.paused,
      DraftJourneyState.resumeRequested,
    );
  }

  bool agreeResume(String id) {
    if (!_mainLeadershipPresent(id) || !hasCapacity || peerOccupied(id)) {
      return false;
    }
    return _move(
      id,
      DraftJourneyState.resumeRequested,
      DraftJourneyState.active,
    );
  }

  bool keepPaused(String id) =>
      _move(id, DraftJourneyState.resumeRequested, DraftJourneyState.paused);

  bool end(String id) {
    final state = _states[id];
    if (state == null ||
        state == DraftJourneyState.received ||
        state == DraftJourneyState.sent ||
        state == DraftJourneyState.ended) {
      return false;
    }
    _states[id] = DraftJourneyState.ended;
    return true;
  }

  /// Private bookmark: no request, disclosure, notification or capacity cost.
  bool save(String id) {
    if (!_fixtureIds.contains(id)) return false;
    if (!_saved.add(id)) _saved.remove(id);
    return true;
  }

  /// Changes only the disposable scenario's capacity. A reduction must not
  /// silently truncate a preparation, Active Journey or pending Pause.
  bool setCapacity(int value) {
    if (value < 1 || value > 3 || value < occupiedCount) return false;
    _capacity = value;
    return true;
  }

  /// Clears fictional interaction state, retaining the configured local cap.
  void reset() {
    _shepherdMemberships.clear();
    _seed();
  }

  /// Explicitly replaces the fictional scenario with one to three Active
  /// Journeys at Greeting. Invalid counts preserve every existing fixture state.
  /// Each Journey owns fresh progress; this never changes a real account.
  bool seedJourneys(int count) {
    if (count < 1 || count > capacity) return false;
    _seed();
    for (final profile in draftProfiles.skip(1).take(count)) {
      _states[profile.id] = DraftJourneyState.active;
      _progress[profile.id] = _DraftJourneyProgress()
        ..ready = true
        ..peerReady = true;
    }
    return true;
  }

  /// Explicit local full-capacity scenario. Never changes the real account.
  void fillCapacity() => seedJourneys(capacity);

  /// Optional history walkthrough, absent from a fresh draft. Repeated calls
  /// never overwrite requests, an existing Journey or checkpoint progress.
  void seedHistory({bool includePaused = true}) {
    for (final entry in [
      if (includePaused) (draftProfiles[4].id, DraftJourneyState.paused),
      (draftProfiles[5].id, DraftJourneyState.ended),
    ]) {
      if (_states.containsKey(entry.$1)) continue;
      _states[entry.$1] = entry.$2;
      _progress[entry.$1] = _DraftJourneyProgress()
        ..ready = true
        ..peerReady = true;
    }
  }

  void _seed() {
    _states
      ..clear()
      ..[draftProfiles.first.id] = DraftJourneyState.received;
    _saved.clear();
    _hiddenPeers.clear();
    _blockedPeers.clear();
    for (final progress in _progress.values) {
      progress.marriagePrepCompleted.clear();
    }
    _progress.clear();
    _shepherdAccess.clear();
    for (final entry in _shepherdMemberships.entries.toList()) {
      if (entry.value == DraftShepherdMembership.basic) {
        setSampleShepherdMembership(entry.key, entry.value);
      }
    }
    _peerMainShepherdOverrides.clear();
    _busyPeers
      ..clear()
      ..add(draftProfiles.last.id);
    _ownMainShepherd = _peerMainShepherd = true;
  }

  bool _usesActivePlace(DraftJourneyState? state) =>
      state == DraftJourneyState.preparing ||
      state == DraftJourneyState.active ||
      state == DraftJourneyState.pauseRequested;

  bool _move(String id, DraftJourneyState expected, DraftJourneyState next) {
    if (_states[id] != expected) return false;
    _states[id] = next;
    return true;
  }
}
