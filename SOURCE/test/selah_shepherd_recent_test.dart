import 'package:flutter_test/flutter_test.dart';
import 'package:selah/dev/selah_shepherd_circle_preview.dart';
import 'package:selah/services/selah_family_messaging_service.dart';

import '../tool/test_shepherd_recent.dart';

void main() {
  test('Recent projection order, filtering, exact words, dates and limit', () {
    runShepherdRecentChecks(
      (value, label) => expect(value, isTrue, reason: label),
    );
  });
  test(
    'One Circle owner survives immutable viewer rebinding without lost sends',
    () {
      const people = [
        SelahFamilyCircleParticipant(
          userId: 'self',
          firstName: 'James',
          memberRole: 'seeker',
          isMainShepherd: false,
          isCurrentUser: true,
        ),
        SelahFamilyCircleParticipant(
          userId: 'main',
          firstName: 'David',
          memberRole: 'shepherd',
          isMainShepherd: true,
          isCurrentUser: false,
        ),
      ];
      final owner = SelahShepherdCirclePreviewData(
        seekerId: 'self',
        senderId: 'self',
        participants: people,
        canSend: true,
      );
      SelahFamilyMessage message(
        String id,
        String sender, {
        String body = 'Existing words',
        SelahFamilyMessageContext? context,
      }) => SelahFamilyMessage(
        id: id,
        senderId: sender,
        senderFirstName: sender,
        body: body,
        createdAt: DateTime(2026, 11, 6),
        context: context,
      );
      final snapshot = owner.messages;
      expect(owner.appendSentMessage(message('first', 'self')), isTrue);
      expect(snapshot, isEmpty);
      expect(() => owner.messages.clear(), throwsUnsupportedError);
      final shepherd = owner.forViewer(
        senderId: 'main',
        canSend: true,
        contexts: [],
        participants: const [
          SelahFamilyCircleParticipant(
            userId: 'self',
            firstName: 'James',
            memberRole: 'seeker',
            isMainShepherd: false,
            isCurrentUser: false,
          ),
          SelahFamilyCircleParticipant(
            userId: 'main',
            firstName: 'David',
            memberRole: 'shepherd',
            isMainShepherd: true,
            isCurrentUser: true,
          ),
        ],
      );
      expect(shepherd.appendSentMessage(message('second', 'main')), isTrue);
      expect(owner.messages.map((m) => m.id), ['first', 'second']);
      expect(shepherd.messages.map((m) => m.id), ['first', 'second']);
      expect(shepherd.appendSentMessage(message('first', 'main')), isFalse);
      expect(shepherd.appendSentMessage(message('wrong', 'self')), isFalse);
      expect(
        shepherd.appendSentMessage(message('blank', 'main', body: '  ')),
        isFalse,
      );
      expect(
        shepherd.appendSentMessage(message('long', 'main', body: 'x' * 2001)),
        isFalse,
      );
      expect(
        shepherd.appendSentMessage(
          message(
            'context',
            'main',
            context: const SelahFamilyMessageContext(
              referenceId: 'unknown',
              firstName: 'Esther',
              kind: SelahFamilyMessageContextKind.active,
            ),
          ),
        ),
        isFalse,
      );
      final denied = owner.forViewer(
        senderId: 'self',
        participants: people,
        contexts: [],
        canSend: false,
      );
      expect(denied.appendSentMessage(message('denied', 'self')), isFalse);
      expect(owner.messages, hasLength(2));
      expect(owner.messageCount, 2);
    },
  );
}
