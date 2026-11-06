/// LOCK 10 / Prayer V2 session-only data. These records are never a message
/// delivery, a server identity, a permission grant or a persisted prayer ledger.
class SelahPrayerRequest {
  SelahPrayerRequest({
    required this.id,
    required this.seekerId,
    required this.seekerFirstName,
    required this.text,
    required this.sentAt,
    required Iterable<String> recipientShepherdIds,
    this.journeyName,
    this.seedPrayedCount = 0,
    Iterable<String> prayedByShepherdIds = const [],
  }) : recipientShepherdIds = Set.unmodifiable(recipientShepherdIds),
       prayedByShepherdIds = Set.unmodifiable(prayedByShepherdIds) {
    if (!_id(id) ||
        !_id(seekerId) ||
        seekerFirstName.trim().isEmpty ||
        text.trim().isEmpty ||
        this.recipientShepherdIds.isEmpty ||
        this.recipientShepherdIds.any((value) => !_id(value)) ||
        seedPrayedCount < 0 ||
        !this.recipientShepherdIds.containsAll(this.prayedByShepherdIds)) {
      throw ArgumentError('Invalid local prayer request.');
    }
  }

  final String id;
  final String seekerId;
  final String seekerFirstName;
  final String text;
  final DateTime sentAt;
  final Set<String> recipientShepherdIds;
  final String? journeyName;
  final int seedPrayedCount;
  final Set<String> prayedByShepherdIds;
  int get prayedCount => seedPrayedCount + prayedByShepherdIds.length;
  bool hasPrayed(String shepherdId) => prayedByShepherdIds.contains(shepherdId);

  SelahPrayerRequest _withPrayer(String shepherdId) => SelahPrayerRequest(
    id: id,
    seekerId: seekerId,
    seekerFirstName: seekerFirstName,
    text: text,
    sentAt: sentAt,
    recipientShepherdIds: recipientShepherdIds,
    journeyName: journeyName,
    seedPrayedCount: seedPrayedCount,
    prayedByShepherdIds: {...prayedByShepherdIds, shepherdId},
  );
}

enum SelahPrayerEventKind { asked, prayed }

class SelahPrayerEvent {
  const SelahPrayerEvent({
    required this.kind,
    required this.requestId,
    required this.seekerId,
    required this.shepherdId,
    required this.shepherdName,
    required this.sentAt,
    this.journeyName,
  });
  final SelahPrayerEventKind kind;
  final String requestId;
  final String seekerId;
  final String shepherdId;
  final String shepherdName;
  final DateTime sentAt;
  final String? journeyName;
  String get text => switch (kind) {
    SelahPrayerEventKind.asked => 'You asked $shepherdName for prayer.',
    SelahPrayerEventKind.prayed =>
      (journeyName ?? '').trim().isEmpty
          ? '$shepherdName prayed for you.'
          : '$shepherdName prayed for your Journey with $journeyName.',
  };
}

bool _id(String value) => value.isNotEmpty && value.trim() == value;

class SelahPrayerStore {
  // Keep the injected clock private behind the named constructor contract.
  // ignore: prefer_initializing_formals
  SelahPrayerStore({required DateTime Function() clock}) : _clock = clock;
  factory SelahPrayerStore.seeded({
    required String shepherdId,
    required String jamesId,
    required String joelId,
    required DateTime Function() clock,
  }) {
    final store = SelahPrayerStore(clock: clock);
    final now = clock();
    // All four use the actual supplied clock reading. The locked list order,
    // rather than fabricated earlier timestamps, breaks equal-time ties.
    final rows = <(String, String, String, int, String?)>[
      (jamesId, 'James', 'For wisdom in my Journey with Esther', 2, 'Esther'),
      (joelId, 'Joel', 'For patience while I wait', 5, null),
      (
        jamesId,
        'James',
        'For my family to be at peace with my choice',
        1,
        null,
      ),
      (joelId, 'Joel', 'For courage to ask someone to begin', 3, null),
    ];
    for (var index = 0; index < rows.length; index++) {
      final (seekerId, firstName, text, count, journey) = rows[index];
      final request = SelahPrayerRequest(
        id: 'prayer-seed-${index + 1}',
        seekerId: seekerId,
        seekerFirstName: firstName,
        text: text,
        sentAt: now,
        recipientShepherdIds: {shepherdId},
        journeyName: journey,
        seedPrayedCount: count,
      );
      store._requests[request.id] = request;
      store._order[request.id] = rows.length - index;
    }
    store._sequence = rows.length;
    return store;
  }

  final DateTime Function() _clock;
  final _requests = <String, SelahPrayerRequest>{};
  final _order = <String, int>{};
  final _events = <SelahPrayerEvent>[];
  int _sequence = 0;

  SelahPrayerRequest? requestById(String id) => _requests[id];
  List<SelahPrayerRequest> requestsFor(String shepherdId) {
    final rows = _requests.values
        .where((request) => request.recipientShepherdIds.contains(shepherdId))
        .toList();
    rows.sort((a, b) {
      final time = b.sentAt.compareTo(a.sentAt);
      return time != 0 ? time : _order[b.id]!.compareTo(_order[a.id]!);
    });
    return List.unmodifiable(rows);
  }

  SelahPrayerRequest? send({
    required String seekerId,
    required String seekerFirstName,
    required String text,
    required Iterable<String> recipientShepherdIds,
    required String shepherdName,
    String? journeyName,
  }) {
    final recipients = Set<String>.of(recipientShepherdIds);
    if (!_id(seekerId) ||
        seekerFirstName.trim().isEmpty ||
        text.trim().isEmpty ||
        recipients.isEmpty ||
        recipients.any((value) => !_id(value)) ||
        shepherdName.trim().isEmpty) {
      return null;
    }
    DateTime now;
    try {
      now = _clock();
    } catch (_) {
      return null;
    }
    final sequence = ++_sequence;
    final request = SelahPrayerRequest(
      id: 'prayer-$sequence',
      seekerId: seekerId,
      seekerFirstName: seekerFirstName.trim(),
      text: text.trim(),
      sentAt: now,
      recipientShepherdIds: recipients,
      journeyName: (journeyName ?? '').trim().isEmpty
          ? null
          : journeyName!.trim(),
    );
    _requests[request.id] = request;
    _order[request.id] = sequence;
    _events.insert(
      0,
      SelahPrayerEvent(
        kind: SelahPrayerEventKind.asked,
        requestId: request.id,
        seekerId: seekerId,
        shepherdId: recipients.first,
        shepherdName: shepherdName.trim(),
        sentAt: now,
      ),
    );
    return request;
  }

  bool pray({
    required String requestId,
    required String shepherdId,
    required String shepherdName,
  }) {
    final request = _requests[requestId];
    if (request == null ||
        !request.recipientShepherdIds.contains(shepherdId) ||
        request.hasPrayed(shepherdId) ||
        shepherdName.trim().isEmpty) {
      return false;
    }
    DateTime now;
    try {
      now = _clock();
    } catch (_) {
      return false;
    }
    _requests[requestId] = request._withPrayer(shepherdId);
    _events.insert(
      0,
      SelahPrayerEvent(
        kind: SelahPrayerEventKind.prayed,
        requestId: requestId,
        seekerId: request.seekerId,
        shepherdId: shepherdId,
        shepherdName: shepherdName.trim(),
        sentAt: now,
        journeyName: request.journeyName,
      ),
    );
    return true;
  }

  List<SelahPrayerEvent> updatesFor(String seekerId) =>
      List.unmodifiable(_events.where((event) => event.seekerId == seekerId));

  /// Owner-lifetime reset only. The member UI has no deletion action; its
  /// private empty-state preset hides the view without calling this method.
  void clear() {
    _requests.clear();
    _order.clear();
    _events.clear();
    _sequence = 0;
  }
}

enum SelahPrayerRole { seeker, shepherd }

/// An existing root supplies the current local actor, links and binding token.
/// This context is not server authority and never supplies a made-up actor ID.
class SelahPrayerContext {
  SelahPrayerContext({
    required this.lifetime,
    required this.role,
    required this.actorId,
    required this.actorFirstName,
    this.shepherdId,
    this.shepherdName,
    this.journeyName,
    Iterable<String> linkedShepherdIds = const [],
    Iterable<String> linkedSeekerIds = const [],
  }) : linkedShepherdIds = Set.unmodifiable(linkedShepherdIds),
       linkedSeekerIds = Set.unmodifiable(linkedSeekerIds);
  final Object lifetime;
  final SelahPrayerRole role;
  final String actorId;
  final String actorFirstName;
  final String? shepherdId;
  final String? shepherdName;
  final String? journeyName;
  final Set<String> linkedShepherdIds;
  final Set<String> linkedSeekerIds;

  bool sameBinding(SelahPrayerContext other) =>
      identical(lifetime, other.lifetime) &&
      role == other.role &&
      actorId == other.actorId &&
      actorFirstName == other.actorFirstName &&
      shepherdId == other.shepherdId &&
      shepherdName == other.shepherdName &&
      journeyName == other.journeyName &&
      linkedShepherdIds.length == other.linkedShepherdIds.length &&
      linkedShepherdIds.containsAll(other.linkedShepherdIds) &&
      linkedSeekerIds.length == other.linkedSeekerIds.length &&
      linkedSeekerIds.containsAll(other.linkedSeekerIds);
}
