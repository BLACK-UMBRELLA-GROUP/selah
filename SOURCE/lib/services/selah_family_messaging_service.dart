import 'package:flutter/foundation.dart' show debugPrint;

import '../data/selah_reference_data.dart' show selahRelationshipLabel;
import '../main.dart' show supabase, supabaseReady;
import 'selah_auth.dart';
import 'selah_mentor_link_service.dart' show SelahSourceFailure, SelahSourceResult;

enum SelahFamilyMessageAccess {
  ready,
  membershipRequired,
  linkInactive,
  blocked,
  unavailable,
}

enum SelahFamilyMessageContextKind { active, potential, paused, ended }

class SelahFamilyMessageContext {
  final String referenceId;
  final String firstName;
  final SelahFamilyMessageContextKind kind;

  const SelahFamilyMessageContext({
    required this.referenceId,
    required this.firstName,
    required this.kind,
  });

  String get stateLabel => switch (kind) {
    SelahFamilyMessageContextKind.active => 'Active Journey',
    SelahFamilyMessageContextKind.potential => 'Potential',
    SelahFamilyMessageContextKind.paused => 'Paused',
    SelahFamilyMessageContextKind.ended => 'Ended',
  };

  static SelahFamilyMessageContext? fromRow(Map<String, dynamic> row) {
    final referenceId = row['context_id'];
    final firstName = row['context_first_name'];
    final rawKind = row['context_kind'];
    if (referenceId == null && firstName == null && rawKind == null) {
      return null;
    }
    final kind = switch (rawKind) {
      'active' => SelahFamilyMessageContextKind.active,
      'potential' => SelahFamilyMessageContextKind.potential,
      'paused' => SelahFamilyMessageContextKind.paused,
      'ended' => SelahFamilyMessageContextKind.ended,
      _ => null,
    };
    if (referenceId is! String ||
        referenceId.isEmpty ||
        firstName is! String ||
        firstName.trim().isEmpty ||
        kind == null) {
      return null;
    }
    return SelahFamilyMessageContext(
      referenceId: referenceId,
      firstName: firstName.trim(),
      kind: kind,
    );
  }
}

class SelahFamilyCircleParticipant {
  final String userId;
  final String firstName;
  final String memberRole;
  final bool isMainShepherd;
  final bool isCurrentUser;

  const SelahFamilyCircleParticipant({
    required this.userId,
    required this.firstName,
    required this.memberRole,
    required this.isMainShepherd,
    required this.isCurrentUser,
  });

  String get roleLabel => switch (memberRole) {
    'seeker' => 'Seeker',
    'shepherd' when isMainShepherd => 'Main Shepherd',
    'shepherd' => 'Additional Shepherd',
    _ => 'Circle member',
  };

  static SelahFamilyCircleParticipant? fromRow(Map<String, dynamic> row) {
    final userId = row['user_id'];
    final firstName = row['first_name'];
    final memberRole = row['member_role'];
    final isMain = row['is_main_shepherd'];
    final isCurrent = row['is_current_user'];
    if (userId is! String ||
        userId.isEmpty ||
        firstName is! String ||
        firstName.trim().isEmpty ||
        (memberRole != 'seeker' && memberRole != 'shepherd') ||
        isMain is! bool ||
        isCurrent is! bool) {
      return null;
    }
    return SelahFamilyCircleParticipant(
      userId: userId,
      firstName: firstName.trim(),
      memberRole: memberRole as String,
      isMainShepherd: isMain,
      isCurrentUser: isCurrent,
    );
  }
}

class SelahShepherdCircleAccess {
  final String? threadId;
  final String seekerId;
  final String seekerFirstName;
  final int participantCount;
  final bool canSend;
  final bool muted;
  final SelahFamilyMessageAccess access;

  const SelahShepherdCircleAccess({
    required this.threadId,
    required this.seekerId,
    required this.seekerFirstName,
    required this.participantCount,
    required this.canSend,
    required this.muted,
    required this.access,
  });

  static SelahShepherdCircleAccess? fromRow(Map<String, dynamic> row) {
    final threadId = row['thread_id'];
    final seekerId = row['seeker_id'];
    final seekerName = row['seeker_first_name'];
    final participantCount = row['participant_count'];
    final canSend = row['can_send'];
    final muted = row['muted'];
    if ((threadId != null && threadId is! String) ||
        seekerId is! String ||
        seekerId.isEmpty ||
        seekerName is! String ||
        seekerName.trim().isEmpty ||
        participantCount is! num ||
        participantCount < 1 ||
        canSend is! bool ||
        muted is! bool) {
      return null;
    }
    return SelahShepherdCircleAccess(
      threadId: threadId as String?,
      seekerId: seekerId,
      seekerFirstName: seekerName.trim(),
      participantCount: participantCount.toInt(),
      canSend: canSend,
      muted: muted,
      access: _accessFrom(row['access_reason']),
    );
  }
}

class SelahShepherdCircleSummary {
  final String threadId;
  final String seekerId;
  final String seekerFirstName;
  final int participantCount;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final int unreadCount;
  final bool canSend;
  final bool muted;
  final SelahFamilyMessageAccess access;

  const SelahShepherdCircleSummary({
    required this.threadId,
    required this.seekerId,
    required this.seekerFirstName,
    required this.participantCount,
    required this.lastMessage,
    required this.lastMessageAt,
    required this.unreadCount,
    required this.canSend,
    required this.muted,
    required this.access,
  });

  static SelahShepherdCircleSummary? fromRow(Map<String, dynamic> row) {
    final threadId = row['thread_id'];
    final seekerId = row['seeker_id'];
    final seekerName = row['seeker_first_name'];
    final participantCount = row['participant_count'];
    final canSend = row['can_send'];
    final muted = row['muted'];
    final unread = row['unread_count'];
    if (threadId is! String ||
        threadId.isEmpty ||
        seekerId is! String ||
        seekerId.isEmpty ||
        seekerName is! String ||
        seekerName.trim().isEmpty ||
        participantCount is! num ||
        participantCount < 1 ||
        canSend is! bool ||
        muted is! bool ||
        unread is! num) {
      return null;
    }
    return SelahShepherdCircleSummary(
      threadId: threadId,
      seekerId: seekerId,
      seekerFirstName: seekerName.trim(),
      participantCount: participantCount.toInt(),
      lastMessage: row['last_message'] as String?,
      lastMessageAt: _date(row['last_message_at']),
      unreadCount: unread.toInt(),
      canSend: canSend,
      muted: muted,
      access: _accessFrom(row['access_reason']),
    );
  }
}

class SelahFamilyMessage {
  final String id;
  final String? senderId;
  final String? senderFirstName;
  final String? senderRelationship;
  final String? senderRoleLabel;
  final String body;
  final DateTime createdAt;
  final bool lifecycle;
  final SelahFamilyMessageContext? context;
  final List<SelahFamilyMessageReader> readBy;
  final bool unreadForMe;

  const SelahFamilyMessage({
    required this.id,
    required this.senderId,
    required this.senderFirstName,
    this.senderRelationship,
    this.senderRoleLabel,
    required this.body,
    required this.createdAt,
    this.lifecycle = false,
    this.context,
    this.readBy = const [],
    this.unreadForMe = false,
  });

  String? get senderIdentityLabel {
    final name = senderFirstName?.trim();
    if (name == null || name.isEmpty) return null;
    final relationship = selahRelationshipLabel(senderRelationship);
    final role = senderRoleLabel?.trim();
    return <String>[
      name,
      if (relationship != null && relationship.isNotEmpty) relationship,
      if (role != null && role.isNotEmpty && role != name) role,
    ].join(' · ');
  }

  static SelahFamilyMessage? fromRow(Map<String, dynamic> row) {
    final id = row['message_id'];
    final sender = row['sender_id'];
    final senderName = row['sender_first_name'];
    final senderRelationship = row['sender_relationship'];
    final senderRoleLabel = row['sender_role_label'];
    final body = row['body'];
    final createdAt = _date(row['created_at']);
    final kind = row['kind'];
    final readBy = row['read_by'];
    final unreadForMe = row['unread_for_me'];
    if (id is! String ||
        id.isEmpty ||
        (sender != null && sender is! String) ||
        (senderName != null && senderName is! String) ||
        (senderRelationship != null && senderRelationship is! String) ||
        (senderRoleLabel != null && senderRoleLabel is! String) ||
        body is! String ||
        body.trim().isEmpty ||
        createdAt == null ||
        readBy is! List ||
        unreadForMe is! bool ||
        (kind != 'message' && kind != 'lifecycle')) {
      return null;
    }
    return SelahFamilyMessage(
      id: id,
      senderId: sender as String?,
      senderFirstName: senderName is String ? senderName.trim() : null,
      senderRelationship: senderRelationship is String
          ? senderRelationship.trim()
          : null,
      senderRoleLabel: senderRoleLabel is String
          ? senderRoleLabel.trim()
          : null,
      body: body,
      createdAt: createdAt,
      lifecycle: kind == 'lifecycle',
      context: SelahFamilyMessageContext.fromRow(row),
      readBy: SelahFamilyMessageReader.listFrom(readBy),
      unreadForMe: unreadForMe,
    );
  }
}

class SelahFamilyMessageReader {
  final String userId;
  final String firstName;
  final String? roleLabel;
  final DateTime? readAt;

  const SelahFamilyMessageReader({
    required this.userId,
    required this.firstName,
    required this.roleLabel,
    required this.readAt,
  });

  static List<SelahFamilyMessageReader> listFrom(Object? value) {
    if (value == null) return const [];
    if (value is! List) return const [];
    final readers = <SelahFamilyMessageReader>[];
    for (final item in value) {
      if (item is! Map) return const [];
      final row = Map<String, dynamic>.from(item);
      final userId = row['user_id'];
      final firstName = row['first_name'];
      final roleLabel = row['role_label'];
      final readAt = _date(row['read_at']);
      if (userId is! String ||
          userId.isEmpty ||
          firstName is! String ||
          firstName.trim().isEmpty ||
          (roleLabel != null && roleLabel is! String) ||
          readAt == null) {
        return const [];
      }
      readers.add(
        SelahFamilyMessageReader(
          userId: userId,
          firstName: firstName.trim(),
          roleLabel: roleLabel is String ? roleLabel.trim() : null,
          readAt: readAt,
        ),
      );
    }
    return readers;
  }
}

class SelahFamilyMessagingService {
  SelahFamilyMessagingService._();

  static Future<SelahSourceResult<SelahShepherdCircleAccess>> openCircle(
    String seekerId,
  ) async {
    if (!supabaseReady) {
      return const SelahSourceResult.unavailable(SelahSourceFailure.notReady);
    }
    if (SelahAuth.currentUser == null) {
      return const SelahSourceResult.unavailable(SelahSourceFailure.signedOut);
    }
    try {
      final raw = await supabase.rpc(
        'selah_open_family_message_circle',
        params: {'p_seeker': seekerId},
      );
      final row = _oneRow(raw);
      final value = row == null ? null : SelahShepherdCircleAccess.fromRow(row);
      return value == null
          ? const SelahSourceResult.unavailable(
              SelahSourceFailure.invalidResponse,
            )
          : SelahSourceResult.available(value);
    } catch (error) {
      debugPrint('SELAH Shepherd Circle access failed (${error.runtimeType}).');
      return const SelahSourceResult.unavailable(
        SelahSourceFailure.requestFailed,
      );
    }
  }

  static Future<SelahSourceResult<List<SelahShepherdCircleSummary>>>
  fetchCircles() async {
    if (!supabaseReady) {
      return const SelahSourceResult.unavailable(SelahSourceFailure.notReady);
    }
    if (SelahAuth.currentUser == null) {
      return const SelahSourceResult.unavailable(SelahSourceFailure.signedOut);
    }
    try {
      final raw = await supabase.rpc('selah_family_message_circles');
      final rows = _rows(raw);
      if (rows == null) {
        return const SelahSourceResult.unavailable(
          SelahSourceFailure.invalidResponse,
        );
      }
      final result = <SelahShepherdCircleSummary>[];
      for (final row in rows) {
        final parsed = SelahShepherdCircleSummary.fromRow(row);
        if (parsed == null) {
          return const SelahSourceResult.unavailable(
            SelahSourceFailure.invalidResponse,
          );
        }
        result.add(parsed);
      }
      return SelahSourceResult.available(result);
    } catch (error) {
      debugPrint('SELAH Shepherd Circles failed (${error.runtimeType}).');
      return const SelahSourceResult.unavailable(
        SelahSourceFailure.requestFailed,
      );
    }
  }

  static Future<SelahSourceResult<List<SelahFamilyCircleParticipant>>>
  fetchParticipants(String threadId) async {
    if (!supabaseReady) {
      return const SelahSourceResult.unavailable(SelahSourceFailure.notReady);
    }
    if (SelahAuth.currentUser == null) {
      return const SelahSourceResult.unavailable(SelahSourceFailure.signedOut);
    }
    try {
      final raw = await supabase.rpc(
        'selah_family_message_participants',
        params: {'p_thread': threadId},
      );
      final rows = _rows(raw);
      if (rows == null) {
        return const SelahSourceResult.unavailable(
          SelahSourceFailure.invalidResponse,
        );
      }
      final participants = <SelahFamilyCircleParticipant>[];
      for (final row in rows) {
        final participant = SelahFamilyCircleParticipant.fromRow(row);
        if (participant == null) {
          return const SelahSourceResult.unavailable(
            SelahSourceFailure.invalidResponse,
          );
        }
        participants.add(participant);
      }
      return SelahSourceResult.available(participants);
    } catch (error) {
      debugPrint(
        'SELAH Shepherd Circle participants failed (${error.runtimeType}).',
      );
      return const SelahSourceResult.unavailable(
        SelahSourceFailure.requestFailed,
      );
    }
  }

  static Future<SelahSourceResult<List<SelahFamilyMessage>>> fetchMessages(
    String threadId, {
    DateTime? before,
  }) async {
    try {
      final raw = await supabase.rpc(
        'selah_family_messages_v3',
        params: {
          'p_thread': threadId,
          'p_before': before?.toUtc().toIso8601String(),
          'p_limit': 50,
        },
      );
      final rows = _rows(raw);
      if (rows == null) {
        return const SelahSourceResult.unavailable(
          SelahSourceFailure.invalidResponse,
        );
      }
      final result = <SelahFamilyMessage>[];
      for (final row in rows.reversed) {
        final parsed = SelahFamilyMessage.fromRow(row);
        if (parsed == null) {
          return const SelahSourceResult.unavailable(
            SelahSourceFailure.invalidResponse,
          );
        }
        result.add(parsed);
      }
      return SelahSourceResult.available(result);
    } catch (error) {
      debugPrint(
        'SELAH Shepherd Circle messages failed (${error.runtimeType}).',
      );
      return const SelahSourceResult.unavailable(
        SelahSourceFailure.requestFailed,
      );
    }
  }

  static Future<bool> send(String threadId, String body) async {
    final clean = body.trim();
    if (clean.isEmpty || clean.length > 2000) return false;
    try {
      await supabase.rpc(
        'selah_send_family_message',
        params: {'p_thread': threadId, 'p_body': clean},
      );
      return true;
    } catch (error) {
      debugPrint('SELAH Shepherd Circle send failed (${error.runtimeType}).');
      return false;
    }
  }

  static Future<void> markRead(String threadId) async {
    try {
      await supabase.rpc(
        'selah_mark_family_messages_read',
        params: {'p_thread': threadId},
      );
    } catch (error) {
      debugPrint(
        'SELAH Shepherd Circle read marker failed (${error.runtimeType}).',
      );
    }
  }

  static Future<bool> setMuted(String threadId, {required bool muted}) async {
    try {
      await supabase.rpc(
        'selah_set_family_message_muted',
        params: {'p_thread': threadId, 'p_muted': muted},
      );
      return true;
    } catch (error) {
      debugPrint('SELAH Shepherd Circle mute failed (${error.runtimeType}).');
      return false;
    }
  }

  static Future<bool> report({
    required String threadId,
    required String messageId,
    required String reason,
  }) async {
    try {
      await supabase.rpc(
        'selah_report_family_message',
        params: {
          'p_thread': threadId,
          'p_message': messageId,
          'p_reason': reason,
        },
      );
      return true;
    } catch (error) {
      debugPrint('SELAH Shepherd Circle report failed (${error.runtimeType}).');
      return false;
    }
  }
}

SelahFamilyMessageAccess _accessFrom(Object? value) => switch (value) {
  'ready' => SelahFamilyMessageAccess.ready,
  'membership_required' => SelahFamilyMessageAccess.membershipRequired,
  'link_inactive' => SelahFamilyMessageAccess.linkInactive,
  'blocked' => SelahFamilyMessageAccess.blocked,
  _ => SelahFamilyMessageAccess.unavailable,
};

DateTime? _date(Object? value) => value is String
    ? DateTime.tryParse(value)?.toLocal()
    : value is DateTime
    ? value.toLocal()
    : null;

Map<String, dynamic>? _oneRow(Object? raw) {
  if (raw is Map) return Map<String, dynamic>.from(raw);
  final rows = _rows(raw);
  return rows?.length == 1 ? rows!.single : null;
}

List<Map<String, dynamic>>? _rows(Object? raw) {
  if (raw is! List) return null;
  final rows = <Map<String, dynamic>>[];
  for (final item in raw) {
    if (item is! Map) return null;
    rows.add(Map<String, dynamic>.from(item));
  }
  return rows;
}
