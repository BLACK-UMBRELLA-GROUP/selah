// OA151 integration ports, not a new canonical Journey lifecycle. No client
// model, selected plan, receipt-shaped value or retry key confers access.
import 'package:flutter/foundation.dart' show immutable;

enum SelahJourneyRequestState {
  pending,
  accepted,
  declined,
  cancelled,
  expired,
  bridged,
}

enum SelahJourneyRequestAction { send, cancel, decline, accept, confirmReady }

enum SelahJourneyRequestAvailability { available, held, unavailable }

enum SelahJourneyRequestWriteStatus { applied, refused, held, unavailable }

enum SelahJourneyRequestResult {
  applied,
  refused,
  held,
  unavailable,
  staleOwner,
  staleResponse,
  invalidResponse,
  invalidAction,
  busy,
}

bool selahRequestIdentifierIsValid(String value) => RegExp(
  // PostgreSQL emits canonical lower-case UUIDs. Reject noncanonical spellings
  // so string equality, participant checks and retry identities agree.
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
).hasMatch(value);

@immutable
class SelahJourneyRequestOwner {
  const SelahJourneyRequestOwner(this.actorId, this.generation);
  final String actorId;
  final int generation;
}

/// Only a trusted production repository may supply this binding after the
/// server's atomic reservation-to-canonical bridge. It selects an existing
/// route; that route must still rehydrate its authorized attempt and ritual.
/// It does NOT grant compatibility, Shepherd, chat or Open Conversation access.
@immutable
class SelahJourneyRequestBinding {
  const SelahJourneyRequestBinding({
    required this.requestId,
    required this.matchId,
    required this.attemptId,
  });
  final String requestId;
  final String matchId;
  final String attemptId;

  bool get structurallyValid =>
      selahRequestIdentifierIsValid(requestId) &&
      selahRequestIdentifierIsValid(matchId) &&
      selahRequestIdentifierIsValid(attemptId) &&
      requestId != matchId &&
      requestId != attemptId &&
      matchId != attemptId;
}

@immutable
class SelahJourneyRequestRecord {
  const SelahJourneyRequestRecord({
    required this.id,
    required this.senderId,
    required this.recipientId,
    required this.state,
    required this.senderReady,
    required this.recipientReady,
    this.binding,
  });
  final String id;
  final String senderId;
  final String recipientId;
  final SelahJourneyRequestState state;
  final bool senderReady;
  final bool recipientReady;
  final SelahJourneyRequestBinding? binding;

  bool belongsTo(String actorId) =>
      senderId == actorId || recipientId == actorId;

  bool validFor(String actorId) =>
      selahRequestIdentifierIsValid(id) &&
      selahRequestIdentifierIsValid(senderId) &&
      selahRequestIdentifierIsValid(recipientId) &&
      senderId != recipientId &&
      belongsTo(actorId) &&
      (state == SelahJourneyRequestState.bridged
          ? binding != null &&
                binding!.structurallyValid &&
                binding!.requestId == id &&
                senderReady &&
                recipientReady
          : binding == null) &&
      (state != SelahJourneyRequestState.pending ||
          (!senderReady && !recipientReady));
}

/// An unavailable read never means an empty inbox. Policy values, entitlement
/// calculations and deadline selection belong on the server, not in this port.
@immutable
class SelahJourneyRequestInbox {
  SelahJourneyRequestInbox({
    required this.actorId,
    required this.availability,
    Iterable<SelahJourneyRequestRecord> records = const [],
  }) : records = List.unmodifiable(records);
  final String actorId;
  final SelahJourneyRequestAvailability availability;
  final List<SelahJourneyRequestRecord> records;

  bool validFor(String expectedActor) =>
      actorId == expectedActor &&
      selahRequestIdentifierIsValid(actorId) &&
      (availability == SelahJourneyRequestAvailability.available ||
          records.isEmpty) &&
      records.every((record) => record.validFor(actorId)) &&
      records.map((record) => record.id).toSet().length == records.length;
}

@immutable
class SelahJourneyRequestCommand {
  const SelahJourneyRequestCommand({
    required this.action,
    required this.subjectId,
    required this.operationKey,
  });
  final SelahJourneyRequestAction action;
  // Target member for send; request ID for every other action. Never a match ID.
  final String subjectId;
  final String operationKey;
}

@immutable
class SelahJourneyRequestAcknowledgement {
  const SelahJourneyRequestAcknowledgement({
    required this.actorId,
    required this.action,
    required this.subjectId,
    required this.operationKey,
    required this.status,
  });
  final String actorId;
  final SelahJourneyRequestAction action;
  final String subjectId;
  final String operationKey;
  final SelahJourneyRequestWriteStatus status;

  bool matches(
    SelahJourneyRequestOwner owner,
    SelahJourneyRequestCommand command,
  ) =>
      actorId == owner.actorId &&
      action == command.action &&
      subjectId == command.subjectId &&
      operationKey == command.operationKey;
}
