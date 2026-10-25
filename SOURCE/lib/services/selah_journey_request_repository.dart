import '../models/selah_journey_request.dart';

/// OA151 production integration port. A future implementation must authenticate
/// the captured owner, parse a versioned server contract and use caller-scoped
/// wrappers; it must never call oa151_kernel or write relationship tables.
/// No mock, developer override or membership choice is a production fallback.
abstract interface class SelahJourneyRequestRepository {
  Future<SelahJourneyRequestInbox> read(SelahJourneyRequestOwner owner);
  Future<SelahJourneyRequestAcknowledgement> execute(
    SelahJourneyRequestOwner owner,
    SelahJourneyRequestCommand command,
  );
}

/// The only shipped default. No endpoints are guessed, no network is attempted,
/// and no access is granted while the real adapter/bridge is unimplemented.
final class SelahHeldJourneyRequestRepository
    implements SelahJourneyRequestRepository {
  const SelahHeldJourneyRequestRepository();

  @override
  Future<SelahJourneyRequestInbox> read(SelahJourneyRequestOwner owner) async =>
      SelahJourneyRequestInbox(
        actorId: owner.actorId,
        availability: SelahJourneyRequestAvailability.held,
      );

  @override
  Future<SelahJourneyRequestAcknowledgement> execute(
    SelahJourneyRequestOwner owner,
    SelahJourneyRequestCommand command,
  ) async => SelahJourneyRequestAcknowledgement(
    actorId: owner.actorId,
    action: command.action,
    subjectId: command.subjectId,
    operationKey: command.operationKey,
    status: SelahJourneyRequestWriteStatus.held,
  );
}
