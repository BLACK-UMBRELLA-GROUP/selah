// Mentor account linking — Paths 1/2 (Seeker invites Mentor) and Path 3
// (Mentor invites Seeker), per MENTOR_ARCHITECTURE_CURRENT_VERSION_V5.md.
// One symmetric mechanism serves both directions: whoever initiates
// creates a mentor_invites row (a shareable 8-character code — no SMS/
// email backend exists, so sharing is manual/copy-paste for v1); the
// other party enters that code and accept_mentor_invite() (a SECURITY
// DEFINER function — see supabase/migrations/mentor_invites_and_
// linking.sql) creates the resulting mentor_links row regardless of
// which side is signed in.
//
// Deliberately out of scope here: the Mentor One capability/
// entitlement resolution engine (Primary Mentor, Path A/B grants) —
// that's unbuilt architecture with no schema representation yet.
// This service only creates the LINK, not any capability grant.

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;
import '../data/selah_reference_data.dart';
import '../data/selah_shepherd_capacity.dart';
import '../state/app_state.dart' show SelahPlan;
import '../main.dart';
import 'selah_account_state.dart';
import 'selah_auth.dart';

/// Truth-preserving result for an authenticated server read.
///
/// A successful read may contain an empty collection. [unavailable] means the
/// server did not answer authoritatively, so callers must not turn it into an
/// empty-state claim. Legacy collection-returning methods remain below while
/// older surfaces migrate to this contract.
enum SelahSourceFailure { notReady, signedOut, requestFailed, invalidResponse }

class SelahSourceResult<T> {
  final T? _value;
  final SelahSourceFailure? failure;

  const SelahSourceResult.available(T value) : _value = value, failure = null;

  const SelahSourceResult.unavailable(SelahSourceFailure reason)
    : _value = null,
      failure = reason;

  bool get isAvailable => failure == null;
  bool get isUnavailable => !isAvailable;
  T? get valueOrNull => isAvailable ? _value : null;
  T valueOr(T fallback) => valueOrNull ?? fallback;
}

enum SelahJourneyShepherdGate {
  ready,
  selfMissing,
  otherMissing,
  bothMissing,
  unavailable,
}

class MentorLinkedPerson {
  final String id;
  final String firstName;

  /// ADDED 2026-08-01. `mentor_links.is_main` has existed since the table
  /// was built and is auto-designated on the first active link, but
  /// nothing ever read it — the Seeker's Shepherd tab listed every linked
  /// Shepherd identically, so the one person who actually acts on the
  /// Journey was indistinguishable from the rest.
  ///
  /// Exactly one link per Seeker carries this. A Seeker has one Main
  /// Shepherd; any others are Additional.
  final bool isMain;

  /// How this Shepherd is related to their Seeker — the stored CODE
  /// ('father', 'uncle'…), never the label. Use [relationshipLabel] to
  /// display it.
  ///
  /// FIXED 2026-08-06. This field has existed since 2026-08-01 and is
  /// rendered on the Seeker's Shepherd tab, but [fetchLinkedPeople] never
  /// selected the column, so it was null for every real user. The only
  /// place "Father" or "Brother" appeared was `SelahDevScenario.fakeShepherds`
  /// — which is precisely why the tab looked correct in testing and would
  /// have been blank in production.
  ///
  /// Still nullable, and legitimately so: links created before the column
  /// existed have no relationship, and nobody has been asked. A guess would
  /// be inventing data about real people.
  final String? relationship;

  /// Start of this link row's current continuous active period. This is the
  /// server-owned inherited decision 225 boundary, not the row's original creation time.
  /// It remains null for legacy/malformed-free responses where no date was
  /// recorded; callers must say "Not recorded" rather than invent one.
  final DateTime? linkedAt;

  const MentorLinkedPerson({
    required this.id,
    required this.firstName,
    this.isMain = false,
    this.relationship,
    this.linkedAt,
  });

  /// "Paternal Uncle" for the code 'uncle'. Null when unrecorded.
  String? get relationshipLabel => selahRelationshipLabel(relationship);

  String? get linkedDateLabel => linkedAt == null
      ? null
      : '${linkedAt!.day} ${_shortMonths[linkedAt!.month - 1]} '
            '${linkedAt!.year}';
}

const _shortMonths = <String>[
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// Server-confirmed inherited decision 233 past-summary permission for one Shepherd link.
///
/// The opaque link id is retained only to validate response shape and future
/// refreshes; it is never rendered. A null link/Shepherd pair is the
/// authoritative no-active-link state and is necessarily OFF. The nullable
/// role flag exists only for that no-link state and is not an authority input.
class ShepherdHistoryConsentState {
  final bool enabled;
  final String? activeShepherdLinkId;
  final String? shepherdId;
  final bool? shepherdIsMain;

  const ShepherdHistoryConsentState({
    required this.enabled,
    required this.activeShepherdLinkId,
    required this.shepherdId,
    required this.shepherdIsMain,
  });

  static ShepherdHistoryConsentState? fromRow(Map<String, dynamic> row) {
    final rawEnabled = row['enabled'];
    final legacy = row.containsKey('active_main_link_id');
    final rawLinkId = legacy
        ? row['active_main_link_id']
        : row['active_shepherd_link_id'];
    final rawShepherdId = legacy ? row['main_shepherd_id'] : row['shepherd_id'];
    final rawIsMain = legacy
        ? (rawLinkId == null ? null : true)
        : row['shepherd_is_main'];
    if (rawEnabled is! bool ||
        (rawLinkId != null && rawLinkId is! String) ||
        (rawShepherdId != null && rawShepherdId is! String) ||
        (rawIsMain != null && rawIsMain is! bool) ||
        (rawLinkId is String && rawLinkId.isEmpty) ||
        (rawShepherdId is String && rawShepherdId.isEmpty) ||
        ((rawLinkId == null) != (rawShepherdId == null)) ||
        ((rawLinkId == null) != (rawIsMain == null)) ||
        (rawEnabled && rawLinkId == null)) {
      return null;
    }
    return ShepherdHistoryConsentState(
      enabled: rawEnabled,
      activeShepherdLinkId: rawLinkId as String?,
      shepherdId: rawShepherdId as String?,
      shepherdIsMain: rawIsMain as bool?,
    );
  }
}

/// Server-confirmed per-Journey access for one Shepherd linked to the
/// signed-in Seeker.
///
/// Main is always included and cannot be changed. An Additional Shepherd may
/// be included or removed by the Seeker for each active Journey. The client
/// never infers access from role labels or keeps an optimistic switch state.
class ShepherdJourneyAccessState {
  final String attemptId;
  final String matchId;
  final String counterpartFirstName;
  final bool included;
  final bool canChange;
  final bool shepherdIsMain;
  final bool chatAvailable;
  final bool chatEnabled;

  const ShepherdJourneyAccessState({
    required this.attemptId,
    required this.matchId,
    required this.counterpartFirstName,
    required this.included,
    required this.canChange,
    required this.shepherdIsMain,
    this.chatAvailable = false,
    this.chatEnabled = false,
  });

  static ShepherdJourneyAccessState? fromRow(Map<String, dynamic> row) {
    final attemptId = row['attempt_id'];
    final matchId = row['match_id'];
    final counterpart = row['counterpart_first_name'];
    final included = row['included'];
    final canChange = row['can_change'];
    final shepherdIsMain = row['shepherd_is_main'];
    final chatAvailable = row['chat_available'];
    final chatEnabled = row['chat_enabled'];
    // Separate from the Seeker's permission switch: the server must confirm
    // paid Shepherd chat authority for THIS linked Shepherd. A legacy true
    // chat_available, the Main role, or the viewer's plan is not payment proof.
    // Until that producer is deployed, retain View but fail closed for Chat.
    final chatEntitled = row['shepherd_chat_entitled'];
    if (attemptId is! String ||
        attemptId.isEmpty ||
        matchId is! String ||
        matchId.isEmpty ||
        counterpart is! String ||
        counterpart.trim().isEmpty ||
        included is! bool ||
        canChange is! bool ||
        shepherdIsMain is! bool ||
        (chatAvailable != null && chatAvailable is! bool) ||
        (chatEnabled != null && chatEnabled is! bool) ||
        (chatEntitled != null && chatEntitled is! bool) ||
        (chatEnabled == true && included != true) ||
        (shepherdIsMain && (!included || canChange))) {
      return null;
    }
    return ShepherdJourneyAccessState(
      attemptId: attemptId,
      matchId: matchId,
      counterpartFirstName: counterpart.trim(),
      included: included,
      canChange: canChange,
      shepherdIsMain: shepherdIsMain,
      chatAvailable: chatEntitled == true && chatAvailable == true,
      chatEnabled:
          chatEntitled == true && chatAvailable == true && chatEnabled == true,
    );
  }
}

/// One thing a Shepherd actually did. Never synthesised — every instance
/// corresponds to a real row with a real timestamp.
///
/// Founder, 2026-08-06: *"I don't want fake activity. Only show activity
/// when something has genuinely happened."* Two requested types are
/// deliberately absent, and their absence is the honest answer rather than a
/// gap: `became_main` has no timestamp anywhere (and would duplicate
/// `linked` on the same day for a first Shepherd), and `invited_to_journey`
/// has no event at all, because participation is derived from the link
/// rather than granted by an invitation.
class ShepherdActivity {
  final String mentorId;
  final String type;
  final DateTime occurredAt;
  final String? detail;

  const ShepherdActivity({
    required this.mentorId,
    required this.type,
    required this.occurredAt,
    this.detail,
  });

  /// Null when a row cannot safely be represented. A structurally valid
  /// unknown type is retained with [line] == null so raw server vocabulary is
  /// never exposed while the caller can still distinguish it from a malformed
  /// response.
  static ShepherdActivity? fromRow(Map<String, dynamic> r) {
    final rawMentorId = r['mentor_id'];
    final rawType = r['activity_type'];
    final rawOccurredAt = r['occurred_at'];
    if (rawMentorId is! String ||
        rawMentorId.isEmpty ||
        rawType is! String ||
        rawType.isEmpty) {
      return null;
    }
    final occurredAt = switch (rawOccurredAt) {
      DateTime value => value,
      String value => DateTime.tryParse(value),
      _ => null,
    };
    if (occurredAt == null) return null;
    final rawDetail = r['detail'];
    return ShepherdActivity(
      mentorId: rawMentorId,
      type: rawType,
      occurredAt: occurredAt.toLocal(),
      detail: rawDetail is String ? rawDetail : null,
    );
  }

  /// Privacy-safe summary vocabulary agreed in inherited decision 216. Detail values are
  /// deliberately absent: a suggestion's third-party name and a Family
  /// Review's raw decision do not belong on a summary card.
  String? get line => switch (type) {
    'linked' => 'Shepherd link active',
    'suggested' => 'Shared a profile suggestion',
    'review_answered' => 'Family Review completed',
    'review_waiting' => 'Family Review is open',
    _ => null,
  };

  /// Context for the stored timestamp. `review_waiting.occurred_at` is the
  /// review opening time, while `linked.occurred_at` is the link date.
  String? get timingLabel => timingLabelAt(DateTime.now());

  String? timingLabelAt(DateTime comparisonNow) => switch (type) {
    'linked' => 'Linked ${whenLabelAt(comparisonNow)}',
    'review_waiting' => 'Opened ${whenLabelAt(comparisonNow)}',
    'suggested' || 'review_answered' => whenLabelAt(comparisonNow),
    _ => null,
  };

  /// Current review state, not an accusation or an action the Seeker can take.
  bool get isOutstanding => type == 'review_waiting';

  /// "today", "3 days ago", then a date once relative time stops helping.
  String get whenLabel => whenLabelAt(DateTime.now());

  String whenLabelAt(DateTime comparisonNow) {
    final d = comparisonNow.difference(occurredAt);
    if (d.inDays == 0) return 'today';
    if (d.inDays == 1) return 'yesterday';
    if (d.inDays < 30) return '${d.inDays} days ago';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${occurredAt.day} ${months[occurredAt.month - 1]} ${occurredAt.year}';
  }
}

/// An invite code that has been generated but not yet redeemed.
///
/// [label] is the SENDER'S private note for who they meant it for, and is
/// never shown to anyone else — `mentor_invites_select` is scoped to
/// `inviter_id`, and `preview_mentor_invite` cannot return it. It is not a
/// claim about who holds the code: whoever redeems it becomes the Shepherd.
class PendingInvite {
  final String token;
  final String? label;
  final DateTime createdAt;
  final DateTime? expiresAt;

  const PendingInvite({
    required this.token,
    required this.createdAt,
    this.label,
    this.expiresAt,
  });

  static PendingInvite? fromRow(Map<String, dynamic> row) {
    final token = row['token'];
    final rawCreatedAt = row['created_at'];
    if (token is! String || token.isEmpty) return null;
    final createdAt = switch (rawCreatedAt) {
      DateTime value => value,
      String value => DateTime.tryParse(value),
      _ => null,
    };
    if (createdAt == null) return null;
    final rawExpiresAt = row['expires_at'];
    final expiresAt = switch (rawExpiresAt) {
      null => null,
      DateTime value => value,
      String value => DateTime.tryParse(value),
      _ => null,
    };
    if (rawExpiresAt != null && expiresAt == null) return null;
    final rawLabel = row['label'];
    return PendingInvite(
      token: token,
      label: rawLabel is String ? rawLabel : null,
      createdAt: createdAt.toLocal(),
      expiresAt: expiresAt?.toLocal(),
    );
  }

  /// Days until it lapses, or null where no expiry is recorded.
  int? get daysLeft {
    return daysLeftAt(DateTime.now());
  }

  /// Clock-injected expiry calculation for deterministic visual fixtures.
  int? daysLeftAt(DateTime comparisonNow) {
    if (expiresAt == null) return null;
    final d = expiresAt!.difference(comparisonNow).inDays;
    return d < 0 ? 0 : d;
  }
}

/// The caller's permanent, role-specific discovery handle.
class SelahPersonalCode {
  final String code;
  final String roleContext;

  const SelahPersonalCode({required this.code, required this.roleContext});

  static SelahPersonalCode? fromRow(Map<String, dynamic> row) {
    final code = row['code'];
    final role = row['role_context'];
    if (code is! String ||
        !RegExp(r'^SELAH-[0-9A-F]{4}(?:-[0-9A-F]{4}){4}$').hasMatch(code) ||
        (role != 'seeker' && role != 'mentor')) {
      return null;
    }
    return SelahPersonalCode(code: code, roleContext: role as String);
  }
}

/// Privacy-minimised code preview. The server intentionally returns no photo
/// and no verification claim.
class SelahPersonalCodePreview {
  final String firstName;
  final String role;

  const SelahPersonalCodePreview({required this.firstName, required this.role});

  static SelahPersonalCodePreview? fromRow(Map<String, dynamic> row) {
    final firstName = row['owner_first_name'];
    final role = row['owner_role'];
    if (firstName is! String ||
        firstName.trim().isEmpty ||
        (role != 'seeker' && role != 'mentor')) {
      return null;
    }
    return SelahPersonalCodePreview(
      firstName: firstName.trim(),
      role: role as String,
    );
  }
}

class SelahShepherdLinkRequest {
  final String id;
  final String direction;
  final String otherFirstName;
  final String otherRole;
  final String status;
  final String? relationship;
  final DateTime createdAt;
  final DateTime expiresAt;

  const SelahShepherdLinkRequest({
    required this.id,
    required this.direction,
    required this.otherFirstName,
    required this.otherRole,
    required this.status,
    required this.createdAt,
    required this.expiresAt,
    this.relationship,
  });

  bool get isIncoming => direction == 'incoming';
  bool get isPending => status == 'pending';

  static SelahShepherdLinkRequest? fromRow(Map<String, dynamic> row) {
    final id = row['request_id'];
    final direction = row['direction'];
    final name = row['other_first_name'];
    final role = row['other_role'];
    final status = row['status'];
    final created = DateTime.tryParse(row['created_at']?.toString() ?? '');
    final expires = DateTime.tryParse(row['expires_at']?.toString() ?? '');
    final relationship = row['relationship'];
    if (id is! String ||
        id.isEmpty ||
        (direction != 'incoming' && direction != 'outgoing') ||
        name is! String ||
        name.trim().isEmpty ||
        (role != 'seeker' && role != 'mentor') ||
        status is! String ||
        created == null ||
        expires == null ||
        (relationship != null && relationship is! String)) {
      return null;
    }
    return SelahShepherdLinkRequest(
      id: id,
      direction: direction as String,
      otherFirstName: name.trim(),
      otherRole: role as String,
      status: status,
      relationship: relationship as String?,
      createdAt: created.toLocal(),
      expiresAt: expires.toLocal(),
    );
  }
}

class SelahMentorLinkService {
  static bool? _shepherdAccessReadyForTesting;

  /// Synthetic SDK tests only; assertions are disabled in delivered builds.
  @visibleForTesting
  static void setShepherdAccessReadyForTesting(bool? value) {
    assert(() {
      _shepherdAccessReadyForTesting = value;
      return true;
    }());
  }

  SelahMentorLinkService._();

  /// In-process refresh signal for screens that present the same Shepherd
  /// link state in different tabs. The database remains authoritative; this
  /// notifier carries no rows and grants no capability. It only tells an
  /// already-mounted reader to fetch again after a successful mutation.
  static final ValueNotifier<int> linkRevision = ValueNotifier<int>(0);
  static final ValueNotifier<int> invitationRevision = ValueNotifier<int>(0);

  static void _markLinksChanged() {
    linkRevision.value += 1;
  }

  static void _markInvitationsChanged() {
    invitationRevision.value += 1;
  }

  static Future<SelahSourceResult<SelahPersonalCode>> personalCode({
    String? roleContext,
  }) async {
    if (!supabaseReady) {
      return const SelahSourceResult.unavailable(SelahSourceFailure.notReady);
    }
    if (SelahAuth.currentUser == null) {
      return const SelahSourceResult.unavailable(SelahSourceFailure.signedOut);
    }
    try {
      final raw = await supabase.rpc(
        'selah_my_personal_code',
        params: {'p_role_context': roleContext},
      );
      if (raw is! List || raw.length != 1 || raw.single is! Map) {
        return const SelahSourceResult.unavailable(
          SelahSourceFailure.invalidResponse,
        );
      }
      final code = SelahPersonalCode.fromRow(
        Map<String, dynamic>.from(raw.single as Map),
      );
      return code == null
          ? const SelahSourceResult.unavailable(
              SelahSourceFailure.invalidResponse,
            )
          : SelahSourceResult.available(code);
    } catch (e) {
      debugPrint('SELAH: personalCode failed — $e');
      return const SelahSourceResult.unavailable(
        SelahSourceFailure.requestFailed,
      );
    }
  }

  static Future<SelahSourceResult<SelahPersonalCode>> rotatePersonalCode({
    String? roleContext,
  }) async {
    if (!supabaseReady) {
      return const SelahSourceResult.unavailable(SelahSourceFailure.notReady);
    }
    if (SelahAuth.currentUser == null) {
      return const SelahSourceResult.unavailable(SelahSourceFailure.signedOut);
    }
    try {
      final raw = await supabase.rpc(
        'selah_rotate_my_personal_code',
        params: {'p_role_context': roleContext},
      );
      if (raw is! List || raw.length != 1 || raw.single is! Map) {
        return const SelahSourceResult.unavailable(
          SelahSourceFailure.invalidResponse,
        );
      }
      final code = SelahPersonalCode.fromRow(
        Map<String, dynamic>.from(raw.single as Map),
      );
      return code == null
          ? const SelahSourceResult.unavailable(
              SelahSourceFailure.invalidResponse,
            )
          : SelahSourceResult.available(code);
    } catch (e) {
      debugPrint('SELAH: rotatePersonalCode failed — $e');
      return const SelahSourceResult.unavailable(
        SelahSourceFailure.requestFailed,
      );
    }
  }

  /// Available(null) is an authoritative invalid/unavailable code. A failed
  /// server read remains unavailable and must not be rendered as that claim.
  static Future<SelahSourceResult<SelahPersonalCodePreview?>> previewPersonalCode(
    String code,
  ) async {
    if (!supabaseReady) {
      return const SelahSourceResult.unavailable(SelahSourceFailure.notReady);
    }
    if (SelahAuth.currentUser == null) {
      return const SelahSourceResult.unavailable(SelahSourceFailure.signedOut);
    }
    try {
      final raw = await supabase.rpc(
        'selah_preview_personal_code',
        params: {'p_code': code},
      );
      if (raw is! List) {
        return const SelahSourceResult.unavailable(
          SelahSourceFailure.invalidResponse,
        );
      }
      if (raw.isEmpty) {
        return const SelahSourceResult.available(null);
      }
      if (raw.length != 1 || raw.single is! Map) {
        return const SelahSourceResult.unavailable(
          SelahSourceFailure.invalidResponse,
        );
      }
      final preview = SelahPersonalCodePreview.fromRow(
        Map<String, dynamic>.from(raw.single as Map),
      );
      return preview == null
          ? const SelahSourceResult.unavailable(
              SelahSourceFailure.invalidResponse,
            )
          : SelahSourceResult.available(preview);
    } catch (e) {
      debugPrint('SELAH: previewPersonalCode failed — $e');
      return const SelahSourceResult.unavailable(
        SelahSourceFailure.requestFailed,
      );
    }
  }

  static Future<String?> requestShepherdLink(
    String code, {
    String? relationship,
    required SelahPlan? currentSeekerPlan,
  }) async {
    final userId = SelahAuth.currentUser?.id;
    if (userId == null) return 'You are not signed in.';
    final generation = SelahAccountState.generation;
    const staleMessage =
        'Your account changed. Please check your Shepherd requests before continuing.';
    bool isCurrentAccount() =>
        SelahAuth.currentUser?.id == userId &&
        SelahAccountState.isCurrent(userId, generation);

    if (!isCurrentAccount()) return staleMessage;
    if (currentSeekerPlan != null) {
      final capacity = await shepherdCapacityForCurrentSeeker(
        plan: currentSeekerPlan,
      );
      if (!isCurrentAccount()) return staleMessage;
      if (!capacity.canAdd) return capacity.message;
    }
    try {
      if (!isCurrentAccount()) return staleMessage;
      final requestId = await supabase.rpc(
        'selah_request_shepherd_link',
        params: {'p_code': code, 'p_relationship': relationship},
      );
      if (!isCurrentAccount()) return staleMessage;
      if (requestId is! String || requestId.isEmpty) {
        return 'That code is not available.';
      }
      _markInvitationsChanged();
      return null;
    } catch (e) {
      if (!isCurrentAccount()) return staleMessage;
      final message = e.toString();
      if (message.contains('request_already_pending')) {
        return 'You already have a request waiting with this person.';
      }
      if (message.contains('relationship_required')) {
        return 'Choose how you are related before sending the request.';
      }
      if (message.contains('already_linked')) {
        return 'You are already linked.';
      }
      if (message.contains('code_unavailable')) {
        return 'That code is not available.';
      }
      debugPrint('SELAH: requestShepherdLink failed — $e');
      return "That request didn't go through. Please try again.";
    }
  }

  static Future<SelahSourceResult<List<SelahShepherdLinkRequest>>>
  shepherdLinkRequests() async {
    if (!supabaseReady) {
      return const SelahSourceResult.unavailable(SelahSourceFailure.notReady);
    }
    if (SelahAuth.currentUser == null) {
      return const SelahSourceResult.unavailable(SelahSourceFailure.signedOut);
    }
    try {
      final raw = await supabase.rpc('selah_my_shepherd_requests');
      if (raw is! List) {
        return const SelahSourceResult.unavailable(
          SelahSourceFailure.invalidResponse,
        );
      }
      final requests = <SelahShepherdLinkRequest>[];
      for (final row in raw) {
        if (row is! Map) {
          return const SelahSourceResult.unavailable(
            SelahSourceFailure.invalidResponse,
          );
        }
        final request = SelahShepherdLinkRequest.fromRow(
          Map<String, dynamic>.from(row),
        );
        if (request == null) {
          return const SelahSourceResult.unavailable(
            SelahSourceFailure.invalidResponse,
          );
        }
        requests.add(request);
      }
      return SelahSourceResult.available(requests);
    } catch (e) {
      debugPrint('SELAH: shepherdLinkRequests failed — $e');
      return const SelahSourceResult.unavailable(
        SelahSourceFailure.requestFailed,
      );
    }
  }

  static Future<String?> acceptShepherdLinkRequest(
    String requestId, {
    String? relationship,
    required SelahPlan? currentSeekerPlan,
  }) async {
    final userId = SelahAuth.currentUser?.id;
    if (userId == null) return 'You are not signed in.';
    final generation = SelahAccountState.generation;
    const staleMessage =
        'Your account changed. Please check your Shepherd requests before continuing.';
    bool isCurrentAccount() =>
        SelahAuth.currentUser?.id == userId &&
        SelahAccountState.isCurrent(userId, generation);

    if (!isCurrentAccount()) return staleMessage;
    if (currentSeekerPlan != null) {
      final capacity = await shepherdCapacityForCurrentSeeker(
        plan: currentSeekerPlan,
      );
      if (!isCurrentAccount()) return staleMessage;
      if (!capacity.canAdd) return capacity.message;
    }
    try {
      if (!isCurrentAccount()) return staleMessage;
      await supabase.rpc(
        'selah_accept_shepherd_request',
        params: {'p_request_id': requestId, 'p_relationship': relationship},
      );
      if (!isCurrentAccount()) return staleMessage;
      _markLinksChanged();
      _markInvitationsChanged();
      return null;
    } catch (e) {
      if (!isCurrentAccount()) return staleMessage;
      final message = e.toString();
      if (message.contains('relationship_required')) {
        return 'Choose how you are related before accepting.';
      }
      if (message.contains('request_expired')) {
        return 'This request has expired.';
      }
      if (message.contains('request_not_pending')) {
        return 'This request has already been answered.';
      }
      debugPrint('SELAH: acceptShepherdLinkRequest failed — $e');
      return "That didn't go through. Please try again.";
    }
  }

  static Future<bool> declineShepherdLinkRequest(String requestId) async {
    try {
      final userId = SelahAuth.currentUser?.id;
      if (userId == null) return false;
      final generation = SelahAccountState.generation;
      bool isCurrentAccount() =>
          SelahAuth.currentUser?.id == userId &&
          SelahAccountState.isCurrent(userId, generation);

      if (!isCurrentAccount()) return false;
      final dynamic ok;
      try {
        ok = await supabase.rpc(
          'selah_decline_shepherd_request',
          params: {'p_request_id': requestId},
        );
      } catch (_) {
        if (!isCurrentAccount()) return false;
        rethrow;
      }
      if (!isCurrentAccount()) return false;
      if (ok == true) _markInvitationsChanged();
      return ok == true;
    } catch (e) {
      debugPrint('SELAH: declineShepherdLinkRequest failed — $e');
      return false;
    }
  }

  static Future<bool> cancelShepherdLinkRequest(String requestId) async {
    try {
      final userId = SelahAuth.currentUser?.id;
      if (userId == null) return false;
      final generation = SelahAccountState.generation;
      bool isCurrentAccount() =>
          SelahAuth.currentUser?.id == userId &&
          SelahAccountState.isCurrent(userId, generation);

      if (!isCurrentAccount()) return false;
      final dynamic ok;
      try {
        ok = await supabase.rpc(
          'selah_cancel_shepherd_request',
          params: {'p_request_id': requestId},
        );
      } catch (_) {
        if (!isCurrentAccount()) return false;
        rethrow;
      }
      if (!isCurrentAccount()) return false;
      if (ok == true) _markInvitationsChanged();
      return ok == true;
    } catch (e) {
      debugPrint('SELAH: cancelShepherdLinkRequest failed — $e');
      return false;
    }
  }

  /// Every Shepherd's activity, grouped by Shepherd, newest first.
  ///
  /// A successful empty map means the server recorded no activity. Any failed
  /// or malformed read remains unavailable so a surface cannot claim that
  /// nothing happened when it simply could not refresh.
  static Future<SelahSourceResult<Map<String, List<ShepherdActivity>>>>
  fetchActivityResult() async {
    if (!supabaseReady) {
      return const SelahSourceResult.unavailable(SelahSourceFailure.notReady);
    }
    if (SelahAuth.currentUser == null) {
      return const SelahSourceResult.unavailable(SelahSourceFailure.signedOut);
    }
    try {
      final raw = await supabase.rpc('selah_shepherd_activity');
      if (raw is! List) {
        debugPrint('SELAH: selah_shepherd_activity returned an invalid response');
        return const SelahSourceResult.unavailable(
          SelahSourceFailure.invalidResponse,
        );
      }
      final out = <String, List<ShepherdActivity>>{};
      for (final row in raw) {
        if (row is! Map) {
          debugPrint('SELAH: selah_shepherd_activity returned a malformed row');
          return const SelahSourceResult.unavailable(
            SelahSourceFailure.invalidResponse,
          );
        }
        final activity = ShepherdActivity.fromRow(
          Map<String, dynamic>.from(row),
        );
        if (activity == null) {
          debugPrint('SELAH: selah_shepherd_activity returned a malformed row');
          return const SelahSourceResult.unavailable(
            SelahSourceFailure.invalidResponse,
          );
        }
        final a = activity;
        (out[a.mentorId] ??= []).add(a);
      }
      return SelahSourceResult.available(out);
    } catch (e) {
      debugPrint('SELAH: selah_shepherd_activity failed — $e');
      return const SelahSourceResult.unavailable(
        SelahSourceFailure.requestFailed,
      );
    }
  }

  /// Compatibility bridge for callers not yet migrated to
  /// [fetchActivityResult]. New user-facing surfaces must use the typed result.
  static Future<Map<String, List<ShepherdActivity>>> fetchActivity() async =>
      (await fetchActivityResult()).valueOr(const {});

  /// Server-confirmed Main-Shepherd hold for one shared Journey.
  ///
  /// During the staged migration interval the new RPC is not present. The
  /// narrow fallback checks only the caller and is safe under the previously
  /// live inherited decision 136 invariant, which did not permit either party in an
  /// Active Journey to enter a no-Main state. Once inherited decision 236 is applied,
  /// the RPC exists and both sides are checked without disclosing identity.
  static Future<SelahJourneyShepherdGate> fetchJourneyShepherdGate(
    String matchId,
  ) async {
    try {
      final raw = await supabase.rpc(
        'selah_journey_main_shepherd_gate',
        params: {'p_match_id': matchId},
      );
      final row = raw is List
          ? Map<String, dynamic>.from(raw.single as Map)
          : Map<String, dynamic>.from(raw as Map);
      final selfHasMain = row['self_has_main'] as bool?;
      final otherHasMain = row['other_has_main'] as bool?;
      if (selfHasMain == null || otherHasMain == null) {
        return SelahJourneyShepherdGate.unavailable;
      }
      return switch ((selfHasMain, otherHasMain)) {
        (true, true) => SelahJourneyShepherdGate.ready,
        (false, true) => SelahJourneyShepherdGate.selfMissing,
        (true, false) => SelahJourneyShepherdGate.otherMissing,
        (false, false) => SelahJourneyShepherdGate.bothMissing,
      };
    } catch (error) {
      final message = error.toString();
      final stagedRpcMissing =
          message.contains('PGRST202') ||
          (message.contains('selah_journey_main_shepherd_gate') &&
              message.contains('Could not find'));
      if (!stagedRpcMissing) {
        debugPrint('SELAH: fetchJourneyShepherdGate($matchId) failed — $error');
        return SelahJourneyShepherdGate.unavailable;
      }

      final links = await fetchLinkedPeopleResult(asMentor: false);
      if (links.isUnavailable) return SelahJourneyShepherdGate.unavailable;
      return links
              .valueOr(const <MentorLinkedPerson>[])
              .any((person) => person.isMain)
          ? SelahJourneyShepherdGate.ready
          : SelahJourneyShepherdGate.selfMissing;
    }
  }

  /// Promotes a linked Shepherd to Main. Returns true on success.
  ///
  /// Exactly one Main per Seeker is enforced by a partial unique index,
  /// `mentor_links_one_main_per_seeker`, so this cannot produce two — the RPC
  /// demotes the incumbent before promoting, which is also the only order
  /// that satisfies the `auto_designate_main_mentor` trigger sitting on the
  /// same column.
  static Future<bool> setMainShepherd(String mentorId) async {
    if (SelahAuth.currentUser == null) return false;
    try {
      final ok = await supabase.rpc(
        'selah_set_main_shepherd',
        params: {'p_mentor_id': mentorId},
      );
      if (ok == true) _markLinksChanged();
      return ok == true;
    } catch (e) {
      debugPrint('SELAH: setMainShepherd($mentorId) failed — $e');
      return false;
    }
  }

  /// Demotes the caller's current Main Shepherd without unlinking them.
  ///
  /// The resulting no-Main state is deliberate under inherited decision 236: My SELAH
  /// raises an action and ordinary Active Journey participation stays held
  /// until the Seeker assigns a Main Shepherd. The Shepherd remains linked as
  /// an Additional Shepherd, so this is distinct from [removeShepherd].
  static Future<bool> clearMainShepherd(String mentorId) async {
    if (SelahAuth.currentUser == null) return false;
    try {
      final ok = await supabase.rpc(
        'selah_clear_main_shepherd',
        params: {'p_mentor_id': mentorId},
      );
      if (ok == true) _markLinksChanged();
      return ok == true;
    } catch (e) {
      debugPrint('SELAH: clearMainShepherd($mentorId) failed — $e');
      return false;
    }
  }

  /// Unlinks a Shepherd.
  ///
  /// Returns `null` on success, or a user-facing message on failure.
  ///
  /// Removing a Main Shepherd does not silently promote someone else. Under
  /// inherited decision 236 the resulting no-Main state is surfaced in My SELAH and holds
  /// ordinary Active Journey participation until the Seeker chooses a Main.
  static Future<String?> removeShepherd(String mentorId) async {
    if (SelahAuth.currentUser == null) return 'You are not signed in.';
    try {
      final ok = await supabase.rpc(
        'selah_remove_shepherd',
        params: {'p_mentor_id': mentorId},
      );
      if (ok == true) {
        _markLinksChanged();
        return null;
      }
      return "That didn't go through. Please try again.";
    } on PostgrestException catch (e) {
      final m = e.message;
      if (m.contains('main_shepherd_must_be_reassigned')) {
        return 'Choose a new Main Shepherd before removing this one.';
      }
      if (m.contains('not_your_shepherd')) {
        return 'They are no longer linked to you.';
      }
      if (m.contains('shepherd_required_during_journey')) {
        return e.hint?.trim().isNotEmpty == true
            ? e.hint!.trim()
            : 'An active or paused Journey requires you to keep a Shepherd. '
                  'Assign another Shepherd where possible, or end the Journey '
                  'through the governed flow before removing this one.';
      }
      debugPrint('SELAH: removeShepherd($mentorId) failed — $e');
      return "That didn't go through. Please try again.";
    } catch (e) {
      final m = e.toString();
      if (m.contains('main_shepherd_must_be_reassigned')) {
        return 'Choose a new Main Shepherd before removing this one.';
      }
      if (m.contains('not_your_shepherd')) {
        return 'They are no longer linked to you.';
      }
      // inherited decision 136 / inherited upstream action 173, added 2026-08-10. Removing your LAST
      // Shepherd during a live Journey is refused server-side, because it
      // hands your family's Family Review vote to the other family.
      //
      // The message names both ways out on purpose. A refusal that only says
      // no reads as the app trapping you in a Journey, which is exactly the
      // harm the Founder accepted this rule's cost against — ending and
      // pausing are always free, and the copy has to say so.
      if (m.contains('shepherd_required_during_journey')) {
        return 'An active or paused Journey requires you to keep a Shepherd. '
            'Assign another Shepherd where possible, or end the Journey '
            'through the governed flow before removing this one.';
      }
      debugPrint('SELAH: removeShepherd($mentorId) failed — $e');
      return "That didn't go through. Please try again.";
    }
  }

  /// Reads or changes one linked Shepherd's inherited decision 233 past-summary
  /// permission and returns only the state confirmed by the server. Null
  /// reads; true grants; false revokes.
  static Future<SelahSourceResult<ShepherdHistoryConsentState>>
  shepherdHistoryConsent({
    required String shepherdId,
    bool shepherdIsMain = false,
    bool? enabled,
  }) async {
    if (!supabaseReady) {
      return const SelahSourceResult.unavailable(SelahSourceFailure.notReady);
    }
    if (SelahAuth.currentUser == null) {
      return const SelahSourceResult.unavailable(SelahSourceFailure.signedOut);
    }
    if (shepherdId.isEmpty) {
      return const SelahSourceResult.unavailable(
        SelahSourceFailure.invalidResponse,
      );
    }
    try {
      final raw = await supabase.rpc(
        'selah_shepherd_history_consent',
        params: {'p_shepherd': shepherdId, 'p_enabled': enabled},
      );
      if (raw is! List || raw.length != 1 || raw.single is! Map) {
        debugPrint(
          'SELAH: Shepherd history permission returned an invalid response',
        );
        return const SelahSourceResult.unavailable(
          SelahSourceFailure.invalidResponse,
        );
      }
      final state = ShepherdHistoryConsentState.fromRow(
        Map<String, dynamic>.from(raw.single as Map),
      );
      if (state == null || state.shepherdId != shepherdId) {
        debugPrint(
          'SELAH: Shepherd history permission returned a malformed row',
        );
        return const SelahSourceResult.unavailable(
          SelahSourceFailure.invalidResponse,
        );
      }
      return SelahSourceResult.available(state);
    } catch (e) {
      debugPrint('SELAH: shepherdHistoryConsent failed — $e');
      // The generic RPC is staged behind inherited decision 233. Preserve the already-
      // live Main-Shepherd control while the migration is awaiting its
      // separate apply gate; Additional Shepherds fail closed until then.
      if (shepherdIsMain) {
        return mainShepherdHistoryConsent(enabled: enabled);
      }
      return const SelahSourceResult.unavailable(
        SelahSourceFailure.requestFailed,
      );
    }
  }

  /// Compatibility client for the already-live Main-only RPC. Retained so an
  /// older server remains readable during the staged migration interval.
  static Future<SelahSourceResult<ShepherdHistoryConsentState>>
  mainShepherdHistoryConsent({bool? enabled}) async {
    if (!supabaseReady) {
      return const SelahSourceResult.unavailable(SelahSourceFailure.notReady);
    }
    if (SelahAuth.currentUser == null) {
      return const SelahSourceResult.unavailable(SelahSourceFailure.signedOut);
    }
    try {
      final raw = await supabase.rpc(
        'selah_main_shepherd_history_consent',
        params: {'p_enabled': enabled},
      );
      if (raw is! List || raw.length != 1 || raw.single is! Map) {
        debugPrint('SELAH: history consent returned an invalid response');
        return const SelahSourceResult.unavailable(
          SelahSourceFailure.invalidResponse,
        );
      }
      final state = ShepherdHistoryConsentState.fromRow(
        Map<String, dynamic>.from(raw.single as Map),
      );
      if (state == null) {
        debugPrint('SELAH: history consent returned a malformed row');
        return const SelahSourceResult.unavailable(
          SelahSourceFailure.invalidResponse,
        );
      }
      return SelahSourceResult.available(state);
    } catch (e) {
      debugPrint('SELAH: mainShepherdHistoryConsent failed — $e');
      return const SelahSourceResult.unavailable(
        SelahSourceFailure.requestFailed,
      );
    }
  }

  /// Reads or changes one linked Shepherd's access to the caller's active
  /// Journeys. A null [attemptId]/[enabled] pair is a read. Writes are accepted
  /// only when the response confirms the requested server state.
  static Future<SelahSourceResult<List<ShepherdJourneyAccessState>>>
  shepherdJourneyAccess({
    required String shepherdId,
    String? attemptId,
    bool? enabled,
    bool? chatEnabled,
  }) async {
    if (!(_shepherdAccessReadyForTesting ?? supabaseReady)) {
      return const SelahSourceResult.unavailable(SelahSourceFailure.notReady);
    }
    final ownerId = SelahAuth.currentUser?.id;
    if (ownerId == null) {
      return const SelahSourceResult.unavailable(SelahSourceFailure.signedOut);
    }
    final generation = SelahAccountState.generation;
    bool stillOwner() =>
        SelahAuth.currentUser?.id == ownerId &&
        SelahAccountState.isCurrent(ownerId, generation);
    if (!stillOwner()) {
      return const SelahSourceResult.unavailable(SelahSourceFailure.signedOut);
    }
    if (shepherdId.isEmpty ||
        (attemptId == null && (enabled != null || chatEnabled != null)) ||
        (attemptId != null && enabled == null && chatEnabled == null)) {
      return const SelahSourceResult.unavailable(
        SelahSourceFailure.invalidResponse,
      );
    }
    // A direct caller cannot bypass the disabled widget. Confirm current
    // server-owned availability before asking to enable Chat; do not use a
    // cached local Shepherd plan or borrow the Seeker's subscription.
    if (chatEnabled == true) {
      final access = await shepherdJourneyAccess(shepherdId: shepherdId);
      if (!stillOwner()) {
        return const SelahSourceResult.unavailable(SelahSourceFailure.signedOut);
      }
      final target = access.valueOrNull
          ?.where((state) => state.attemptId == attemptId)
          .firstOrNull;
      if (target == null || !target.included || !target.chatAvailable) {
        return const SelahSourceResult.unavailable(SelahSourceFailure.notReady);
      }
    }
    try {
      final raw = await supabase.rpc(
        'selah_shepherd_journey_access',
        params: {
          'p_shepherd': shepherdId,
          'p_attempt': attemptId,
          'p_enabled': enabled,
          'p_chat_enabled': chatEnabled,
        },
      );
      if (!stillOwner()) {
        return const SelahSourceResult.unavailable(SelahSourceFailure.signedOut);
      }
      if (raw is! List) {
        return const SelahSourceResult.unavailable(
          SelahSourceFailure.invalidResponse,
        );
      }
      final states = <ShepherdJourneyAccessState>[];
      final attempts = <String>{};
      for (final item in raw) {
        if (item is! Map) {
          return const SelahSourceResult.unavailable(
            SelahSourceFailure.invalidResponse,
          );
        }
        final state = ShepherdJourneyAccessState.fromRow(
          Map<String, dynamic>.from(item),
        );
        if (state == null || !attempts.add(state.attemptId)) {
          return const SelahSourceResult.unavailable(
            SelahSourceFailure.invalidResponse,
          );
        }
        states.add(state);
      }
      if (attemptId != null) {
        final confirmed = states.where((state) => state.attemptId == attemptId);
        if (confirmed.length != 1 ||
            (enabled != null && confirmed.single.included != enabled) ||
            (chatEnabled != null &&
                confirmed.single.chatEnabled != chatEnabled)) {
          return const SelahSourceResult.unavailable(
            SelahSourceFailure.invalidResponse,
          );
        }
      }
      return SelahSourceResult.available(List.unmodifiable(states));
    } catch (e) {
      debugPrint('SELAH: shepherdJourneyAccess failed — $e');
      return const SelahSourceResult.unavailable(
        SelahSourceFailure.requestFailed,
      );
    }
  }

  /// Cancels an invite code you sent. Returns true if it was still pending
  /// and is now revoked.
  ///
  /// Only pending invites can be revoked. An accepted invite is a live
  /// Shepherd link, and unlinking a real person is a different action with
  /// different consequences — it does not happen quietly from a list of
  /// codes.
  static Future<bool> revokeInvite(String token) async {
    if (SelahAuth.currentUser == null) return false;
    try {
      final ok = await supabase.rpc(
        'selah_revoke_mentor_invite',
        params: {'p_token': token},
      );
      if (ok == true) _markInvitationsChanged();
      return ok == true;
    } catch (e) {
      debugPrint('SELAH: revokeInvite($token) failed — $e');
      return false;
    }
  }

  /// Declines an invitation code the signed-in recipient has previewed.
  /// Returns null on success or a user-facing failure message.
  static Future<String?> declineInvite(String token) async {
    if (SelahAuth.currentUser == null) return 'You are not signed in.';
    try {
      final ok = await supabase.rpc(
        'selah_decline_mentor_invite',
        params: {'p_token': token.trim().toUpperCase()},
      );
      if (ok == true) _markInvitationsChanged();
      return ok == true ? null : "That didn't go through. Please try again.";
    } catch (e) {
      final message = e.toString();
      if (message.contains('invite_expired')) {
        return 'This code has expired.';
      }
      if (message.contains('invite_not_pending')) {
        return 'That invitation has already been answered.';
      }
      if (message.contains('cannot_decline_own_invite')) {
        return "That's your own invite code.";
      }
      debugPrint('SELAH: declineInvite($token) failed — $e');
      return "That didn't go through. Please try again.";
    }
  }

  /// Lazy Shepherd-invite lifecycle sweep. The server scopes this to invites
  /// sent by the signed-in account and makes both reminders one-shot.
  static Future<void> expireDueInvites() async {
    if (SelahAuth.currentUser == null) return;
    try {
      await supabase.rpc('selah_expire_due_mentor_invites');
    } catch (e) {
      // Loading the Shepherd surface must still work if the lifecycle sweep
      // is temporarily unavailable; logging keeps the delay observable.
      debugPrint('SELAH: expireDueInvites failed — $e');
    }
  }

  /// Invite codes this user has sent that nobody has redeemed yet.
  /// Successful empty and failed refresh remain distinct.
  static Future<SelahSourceResult<List<PendingInvite>>>
  fetchPendingInvitesResult() async {
    if (!supabaseReady) {
      return const SelahSourceResult.unavailable(SelahSourceFailure.notReady);
    }
    final user = SelahAuth.currentUser;
    if (user == null) {
      return const SelahSourceResult.unavailable(SelahSourceFailure.signedOut);
    }
    await expireDueInvites();
    try {
      final rows =
          await supabase
                  .from('mentor_invites')
                  .select('token, label, created_at, expires_at')
                  .eq('inviter_id', user.id)
                  .eq('source', 'legacy_code')
                  .eq('status', 'pending')
                  .order('created_at', ascending: false)
              as List;
      final invites = <PendingInvite>[];
      for (final row in rows) {
        if (row is! Map) {
          debugPrint('SELAH: fetchPendingInvites returned a malformed row');
          return const SelahSourceResult.unavailable(
            SelahSourceFailure.invalidResponse,
          );
        }
        final invite = PendingInvite.fromRow(Map<String, dynamic>.from(row));
        if (invite == null) {
          debugPrint('SELAH: fetchPendingInvites returned a malformed row');
          return const SelahSourceResult.unavailable(
            SelahSourceFailure.invalidResponse,
          );
        }
        invites.add(invite);
      }
      return SelahSourceResult.available(invites);
    } catch (e) {
      debugPrint('SELAH: fetchPendingInvites failed — $e');
      return const SelahSourceResult.unavailable(
        SelahSourceFailure.requestFailed,
      );
    }
  }

  /// Compatibility bridge for callers not yet migrated to
  /// [fetchPendingInvitesResult].
  static Future<List<PendingInvite>> fetchPendingInvites() async =>
      (await fetchPendingInvitesResult()).valueOr(const []);

  /// Creates a new invite as the signed-in user (role is looked up
  /// from their own profiles row) and returns the shareable token, or
  /// null on failure.
  /// [label] is an optional private note for who the code is meant for —
  /// "Dad", "Uncle Ibrahim". It exists so the Pending Invitations section
  /// can read as people rather than as a list of eight-character codes.
  /// Trimmed, capped at the column's 40, and dropped if blank so an
  /// untouched field stores null rather than an empty string.
  /// [relationship] is the CODE, and applies only when a **Shepherd** is
  /// inviting a Seeker (Flow B).
  ///
  /// Founder rule, 2026-08-07: *"The relationship is a statement about the
  /// Shepherd, so the Shepherd makes it — once per link, at the point they
  /// create that link."* In Flow B the Shepherd is gone by the time the
  /// link exists, so their answer travels on the invite and
  /// `accept_mentor_invite` transfers it to `mentor_links.relationship`.
  ///
  /// Ignored for a Seeker-sent invite — the database refuses it there
  /// anyway, because the Shepherd is asked at acceptance instead.
  static Future<String?> createInvite({
    String? label,
    String? relationship,
  }) async {
    final user = SelahAuth.currentUser;
    if (user == null) return null;

    try {
      final profileRow = await supabase
          .from('profiles')
          .select('role')
          .eq('id', user.id)
          .maybeSingle();
      final role = profileRow?['role'] as String?;
      if (role == null) return null;

      final clean = label?.trim();
      final row = await supabase
          .from('mentor_invites')
          .insert({
            'inviter_id': user.id,
            'inviter_role': role,
            if (clean != null && clean.isNotEmpty)
              'label': clean.length > 40 ? clean.substring(0, 40) : clean,
            if (role == 'mentor' && relationship != null)
              'relationship': relationship,
          })
          .select('token')
          .single();
      final token = row['token'] as String?;
      if (token != null) _markInvitationsChanged();
      return token;
    } catch (e) {
      debugPrint('SELAH: createInvite failed — $e');
      return null;
    }
  }

  /// The relationship this Shepherd last used, for pre-filling the next
  /// invite. Null when they have no links yet.
  ///
  /// Founder, 2026-08-07: *"If a Shepherd has no linked Seekers yet, the
  /// field should start blank. If they already have linked Seekers, prefill
  /// with their most recently used relationship, but never lock it."*
  ///
  /// A convenience, never an assumption — the caller must keep it editable.
  /// A man who invited his daughter last month must not silently label his
  /// niece "Daughter".
  static Future<String?> lastUsedRelationship() async {
    final user = SelahAuth.currentUser;
    if (user == null) return null;
    try {
      final rows =
          await supabase
                  .from('mentor_links')
                  .select('relationship, created_at')
                  .eq('mentor_id', user.id)
                  .not('relationship', 'is', null)
                  .order('created_at', ascending: false)
                  .limit(1)
              as List;
      if (rows.isEmpty) return null;
      return (rows.first as Map<String, dynamic>)['relationship'] as String?;
    } catch (e) {
      debugPrint('SELAH: lastUsedRelationship failed — $e');
      return null;
    }
  }

  /// Looks up who sent an invite before the user commits to
  /// accepting it. Returns null if the token is invalid/unknown —
  /// distinct from a thrown error, which the caller treats as a
  /// generic failure per ERROR_AND_EMPTY_STATE_STANDARD.
  static Future<Map<String, String>?> previewInvite(String token) async {
    try {
      final rows =
          await supabase.rpc(
                'preview_mentor_invite',
                params: {'p_token': token.trim().toUpperCase()},
              )
              as List;
      if (rows.isEmpty) return null;
      final row = rows.first as Map<String, dynamic>;
      return {
        'inviterFirstName': row['inviter_first_name'] as String? ?? '',
        'inviterRole': row['inviter_role'] as String? ?? '',
        'status': row['invite_status'] as String? ?? '',
        // 2026-08-08, Founder-approved. How many Seekers this person
        // already guards. Shown so someone can see whether they are being
        // asked to join a family or a collection — the adversarial review
        // found no cap on Shepherds per person, and every hard cap refuses
        // somebody legitimate (the uncle with four nieces). The number
        // costs an honest Shepherd nothing.
        //
        // Only meaningful when inviterRole is a Shepherd; the UI decides
        // whether to render it. Active links only — a present-tense fact.
        'wardCount':
            (row['inviter_ward_count'] as num?)?.toInt().toString() ?? '',
      };
    } catch (e) {
      debugPrint('SELAH: previewInvite($token) failed — $e');
      return null;
    }
  }

  /// Accepts an invite. Returns null on success, or a user-facing
  /// error message on failure (invite already used, wrong role for
  /// this invite, not signed in, etc. — accept_mentor_invite raises a
  /// specific message for each case, surfaced here directly since
  /// they're already written as plain-language copy).
  ///
  /// [relationship] is the stored CODE ('father', 'uncle'…) and applies only
  /// when a Shepherd is accepting: it describes how they are related to the
  /// Seeker they are about to be linked to. A Seeker accepting a Shepherd's
  /// invite passes null, because the question is not theirs to answer about
  /// themselves. Null also leaves any relationship already on the link
  /// intact, so re-accepting never blanks it.
  static Future<String?> acceptInvite(
    String token, {
    String? relationship,
    required SelahPlan? currentSeekerPlan,
  }) async {
    if (currentSeekerPlan != null) {
      final capacity = await shepherdCapacityForCurrentSeeker(
        plan: currentSeekerPlan,
      );
      if (!capacity.canAdd) return capacity.message;
    }
    try {
      await supabase.rpc(
        'accept_mentor_invite',
        params: {
          'p_token': token.trim().toUpperCase(),
          'p_relationship': relationship,
        },
      );
      _markLinksChanged();
      _markInvitationsChanged();
      return null;
    } catch (e) {
      final message = e.toString();
      if (message.contains('Cannot accept your own invite')) {
        return "That's your own invite code.";
      }
      if (message.contains('Invite not found or already used')) {
        return 'That code is invalid or already used.';
      }
      if (message.contains('This invite is for a Shepherd account')) {
        return 'That code is for a Shepherd to accept, not a Seeker.';
      }
      if (message.contains('This invite is for a Seeker account')) {
        return 'That code is for a Seeker to accept, not a Shepherd.';
      }
      if (message.contains('This invite code has expired')) {
        return 'This code has expired — ask them to generate a new one.';
      }
      return "That didn't work. Check the code and try again.";
    }
  }

  /// Fresh client preflight, counting active accepted links including Main.
  /// Pending invitations/requests never occupy a link place. This is a UI
  /// boundary only: concurrent writes and a Shepherd accepting for another
  /// Seeker require the separately audited atomic server limit.
  static Future<SelahShepherdCapacity> shepherdCapacityForCurrentSeeker({
    required SelahPlan plan,
    @visibleForTesting
    Future<SelahSourceResult<List<MentorLinkedPerson>>> Function()? loadLinks,
  }) async {
    SelahSourceResult<List<MentorLinkedPerson>> links;
    try {
      links =
          await (loadLinks?.call() ?? fetchLinkedPeopleResult(asMentor: false));
    } catch (_) {
      debugPrint('SELAH: Shepherd capacity read unavailable');
      links = const SelahSourceResult.unavailable(
        SelahSourceFailure.requestFailed,
      );
    }
    final people = links.valueOrNull;
    return SelahShepherdCapacity.fromCount(
      plan: plan,
      linkedShepherdCount: people?.map((person) => person.id).toSet().length,
    );
  }

  /// Seeker's own linked Shepherd(s), or Shepherd's own linked Seeker(s).
  /// A successful empty list means no active links; authentication, network
  /// and malformed-response failures remain unavailable.
  static Future<SelahSourceResult<List<MentorLinkedPerson>>>
  fetchLinkedPeopleResult({required bool asMentor}) async {
    if (!supabaseReady) {
      return const SelahSourceResult.unavailable(SelahSourceFailure.notReady);
    }
    final user = SelahAuth.currentUser;
    if (user == null) {
      return const SelahSourceResult.unavailable(SelahSourceFailure.signedOut);
    }

    try {
      final column = asMentor ? 'mentor_id' : 'seeker_id';
      final otherColumn = asMentor ? 'seeker_id' : 'mentor_id';
      // is_main added to the select 2026-08-01 — see MentorLinkedPerson.
      // relationship added 2026-08-06, closing the gap where the field was
      // rendered but never fetched.
      final linkRows =
          await supabase
                  .from('mentor_links')
                  .select('$otherColumn, is_main, relationship, active_since')
                  .eq(column, user.id)
                  .eq('status', 'active')
              as List;
      if (linkRows.isEmpty) {
        return const SelahSourceResult.available(<MentorLinkedPerson>[]);
      }

      final linkByOtherId = <String, Map<String, dynamic>>{};
      for (final row in linkRows) {
        if (row is! Map) {
          return const SelahSourceResult.unavailable(
            SelahSourceFailure.invalidResponse,
          );
        }
        final map = Map<String, dynamic>.from(row);
        final otherId = map[otherColumn];
        final rawMain = map['is_main'];
        final rawRelationship = map['relationship'];
        final rawActiveSince = map['active_since'];
        final activeSince = switch (rawActiveSince) {
          DateTime value => value,
          String value => DateTime.tryParse(value),
          _ => null,
        };
        if (otherId is! String ||
            otherId.isEmpty ||
            (rawMain != null && rawMain is! bool) ||
            (rawRelationship != null && rawRelationship is! String) ||
            rawActiveSince == null ||
            activeSince == null) {
          return const SelahSourceResult.unavailable(
            SelahSourceFailure.invalidResponse,
          );
        }
        linkByOtherId[otherId] = map;
      }
      final otherIds = linkByOtherId.keys.toList();
      final profileRows =
          await supabase
                  .from('profiles')
                  .select('id, first_name')
                  .inFilter('id', otherIds)
              as List;

      final people = <MentorLinkedPerson>[];
      for (final row in profileRows) {
        if (row is! Map) {
          return const SelahSourceResult.unavailable(
            SelahSourceFailure.invalidResponse,
          );
        }
        final map = Map<String, dynamic>.from(row);
        final rawId = map['id'];
        final rawFirstName = map['first_name'];
        if (rawId is! String ||
            rawId.isEmpty ||
            rawFirstName is! String ||
            rawFirstName.trim().isEmpty ||
            !linkByOtherId.containsKey(rawId)) {
          return const SelahSourceResult.unavailable(
            SelahSourceFailure.invalidResponse,
          );
        }
        final id = rawId;
        final link = linkByOtherId[id];
        people.add(
          MentorLinkedPerson(
            id: id,
            firstName: rawFirstName.trim(),
            isMain: (link?['is_main'] as bool?) ?? false,
            relationship: link?['relationship'] as String?,
            linkedAt: switch (link?['active_since']) {
              DateTime value => value.toLocal(),
              String value => DateTime.parse(value).toLocal(),
              _ => null,
            },
          ),
        );
      }
      if (people.length != linkByOtherId.length) {
        debugPrint('SELAH: linked people response omitted one or more profiles');
        return const SelahSourceResult.unavailable(
          SelahSourceFailure.invalidResponse,
        );
      }

      // Main first. The Seeker's tab renders it as its own section, and a
      // caller should not have to sort to find the one that matters.
      people.sort((a, b) => (b.isMain ? 1 : 0).compareTo(a.isMain ? 1 : 0));
      return SelahSourceResult.available(people);
    } catch (e) {
      debugPrint('SELAH: fetchLinkedPeople(asMentor: $asMentor) failed — $e');
      return const SelahSourceResult.unavailable(
        SelahSourceFailure.requestFailed,
      );
    }
  }

  /// Compatibility bridge for callers not yet migrated to
  /// [fetchLinkedPeopleResult].
  static Future<List<MentorLinkedPerson>> fetchLinkedPeople({
    required bool asMentor,
  }) async => (await fetchLinkedPeopleResult(asMentor: asMentor)).valueOr(const []);
}
