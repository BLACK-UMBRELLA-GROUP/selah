/// Presentation meanings only. These never create a request or change a Journey.
enum JourneyPresentationKind {
  startRequest,
  continueRequest,
  resumeRequest,
  endRequest,
  requestDeclined,
  started,
  resumed,
  paused,
  ended,
}

/// Attribution must be proved by the source of the current request. A Journey's
/// counterpart is not automatically the person who requested or ended it.
enum JourneyRequestActor { unknown, counterpart, viewer }

/// Uses only an already-authorised first-name field, never a surname or a name
/// inferred from rendered copy. Preserve compound and non-Latin first names.
String? journeyCounterpartFirstName(String? value) {
  final name = value?.trim();
  if (name == null || name.isEmpty) return null;
  if (const {
    'unknown',
    'member',
    'user',
    'seeker',
    'someone',
    'hidden profile',
    'deleted user',
    'deleted account',
    'unavailable',
    'not available',
    'n/a',
    'null',
    '—',
    '–',
    '-',
  }.contains(name.toLowerCase())) {
    return null;
  }
  return name;
}

String journeyPresentationTitle(
  JourneyPresentationKind kind, {
  String? counterpartFirstName,
  JourneyRequestActor actor = JourneyRequestActor.unknown,
}) {
  final name = journeyCounterpartFirstName(counterpartFirstName);
  final journey = name == null ? 'Your Journey' : 'Your Journey with $name';
  final yourJourney = name == null ? 'your Journey' : 'your Journey with $name';
  final requestAction = switch (kind) {
    JourneyPresentationKind.startRequest => 'start',
    JourneyPresentationKind.continueRequest => 'continue',
    JourneyPresentationKind.resumeRequest => 'resume',
    JourneyPresentationKind.endRequest => 'end',
    _ => null,
  };
  if (requestAction != null) {
    final starting = kind == JourneyPresentationKind.startRequest;
    if (actor == JourneyRequestActor.counterpart && name != null) {
      return starting
          ? '$name would like to start a Journey with you'
          : '$name would like to $requestAction your Journey';
    }
    if (actor == JourneyRequestActor.viewer) {
      final object = starting
          ? (name == null ? 'a Journey' : 'a Journey with $name')
          : yourJourney;
      return 'You have asked to $requestAction $object';
    }
    final object = starting
        ? (name == null ? 'a Journey' : 'a Journey with $name')
        : yourJourney;
    return 'A request to $requestAction $object is ready to review';
  }
  return switch (kind) {
    JourneyPresentationKind.requestDeclined =>
      name == null
          ? 'A Journey request is no longer moving forward'
          : 'Your Journey request with $name is no longer moving forward',
    JourneyPresentationKind.started => '$journey has started',
    JourneyPresentationKind.resumed => '$journey has resumed',
    JourneyPresentationKind.paused => '$journey is paused',
    JourneyPresentationKind.ended => '$journey has ended',
    _ => throw StateError('Request kinds were handled above'),
  };
}
