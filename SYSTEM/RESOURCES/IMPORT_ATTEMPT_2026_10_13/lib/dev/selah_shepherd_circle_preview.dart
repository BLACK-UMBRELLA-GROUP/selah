import '../services/selah_family_messaging_service.dart';

/// Immutable caller-owned examples for the retained Circle presentation.
/// These values are never a link, membership, identity or server grant.
class SelahShepherdCirclePreviewData {
  SelahShepherdCirclePreviewData({
    required this.seekerId,
    required this.senderId,
    required Iterable<SelahFamilyCircleParticipant> participants,
    Iterable<SelahFamilyMessage> messages = const [],
    Iterable<SelahFamilyMessageContext> contexts = const [],
    required this.canSend,
  }) : participants = List.unmodifiable(participants),
       messages = List.unmodifiable(messages.map(_snapshotMessage)),
       contexts = List.unmodifiable(contexts);

  final String seekerId;
  final String senderId;
  final List<SelahFamilyCircleParticipant> participants;
  final List<SelahFamilyMessage> messages;
  final List<SelahFamilyMessageContext> contexts;
  final bool canSend;

  bool validFor(String expectedSeeker, {bool? viewerIsSeeker}) =>
      seekerId.isNotEmpty &&
      seekerId == expectedSeeker &&
      senderId.isNotEmpty &&
      participants.isNotEmpty &&
      participants.map((person) => person.userId).toSet().length ==
          participants.length &&
      participants.every(
        (person) =>
            person.userId.isNotEmpty &&
            person.firstName.trim().isNotEmpty &&
            (person.memberRole == 'seeker' || person.memberRole == 'shepherd'),
      ) &&
      participants.where((person) => person.memberRole == 'seeker').length ==
          1 &&
      participants.any(
        (person) => person.memberRole == 'seeker' && person.userId == seekerId,
      ) &&
      participants.where((person) => person.isCurrentUser).length == 1 &&
      participants.any(
        (person) =>
            person.isCurrentUser &&
            person.userId == senderId &&
            (viewerIsSeeker == null ||
                person.memberRole == (viewerIsSeeker ? 'seeker' : 'shepherd')),
      ) &&
      contexts.map((context) => context.referenceId).toSet().length ==
          contexts.length &&
      contexts.every(
        (context) =>
            context.kind == SelahFamilyMessageContextKind.active &&
            context.referenceId.isNotEmpty &&
            context.firstName.trim().isNotEmpty,
      ) &&
      messages.map((message) => message.id).toSet().length == messages.length &&
      messages.every(
        (message) =>
            message.id.isNotEmpty &&
            message.body.trim().isNotEmpty &&
            message.body.length <= 2000 &&
            (message.context == null || includesContext(message.context!)),
      );

  bool includesContext(SelahFamilyMessageContext context) => contexts.any(
    (known) =>
        known.referenceId == context.referenceId &&
        known.firstName == context.firstName &&
        known.kind == context.kind,
  );
}

SelahFamilyMessage _snapshotMessage(SelahFamilyMessage message) =>
    SelahFamilyMessage(
      id: message.id,
      senderId: message.senderId,
      senderFirstName: message.senderFirstName,
      senderRelationship: message.senderRelationship,
      senderRoleLabel: message.senderRoleLabel,
      body: message.body,
      createdAt: message.createdAt,
      lifecycle: message.lifecycle,
      context: message.context,
      readBy: List.unmodifiable(message.readBy),
      unreadForMe: message.unreadForMe,
    );
