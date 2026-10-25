// Wires the Matches tab (Potential Journeys) and Chat screen to the
// real matches/conversations/messages tables. Matches are created
// server-side the instant a mutual Like exists, by the
// create_match_on_mutual_like trigger (see supabase/migrations/
// match_creation_on_mutual_like.sql) — this service is purely a
// read/write layer over what the trigger already produced; the app
// never creates a match row directly (matches has no client INSERT
// policy by design, per SELAH_DATABASE_SCHEMA_CURRENT_VERSION_V1.md §5).
//
// The Potential-Journey vs Active-Journey distinction stays UX-only
// and client-side, exactly as it was before real backend wiring — the
// schema has no column for it (matches.status only tracks
// active/paused/ended), per MATCH_UX_SPEC_CURRENT_VERSION_V1.md.

import 'package:flutter/foundation.dart' show debugPrint;

import '../main.dart';
import '../models/seeker_profile.dart';
import 'selah_auth.dart';
import 'selah_photo_service.dart';
import 'selah_ages_service.dart';
import 'selah_mentor_link_service.dart' show SelahSourceFailure, SelahSourceResult;

class SelahChatMessage {
  final String id;
  final String text;
  final bool fromMe;
  final DateTime createdAt;
  final DateTime? readAt;
  const SelahChatMessage({
    required this.id,
    required this.text,
    required this.fromMe,
    required this.createdAt,
    this.readAt,
  });
}

class SelahMilestone {
  final String
  type; // match_created / conversation_started / family_stage / meeting / marriage
  final DateTime occurredAt;
  const SelahMilestone({required this.type, required this.occurredAt});
}

/// A meeting/marriage proposal awaiting the other Seeker's confirmation
/// (Founder 2026-08-12: both Seekers confirm before it reaches the
/// Timeline). Mirrors selah_milestone_attestation_state().
class SelahMilestoneAttestation {
  final String id;
  final String type; // 'meeting' | 'marriage'
  final DateTime occurredOn;
  final String proposedBy;
  const SelahMilestoneAttestation({
    required this.id,
    required this.type,
    required this.occurredOn,
    required this.proposedBy,
  });
}

/// What the Timeline screen needs beyond the milestones themselves:
/// whether milestones can be recorded right now, and any pending
/// proposal. Defaults are the safe nothing-doing state.
class SelahTimelineContext {
  final String? matchId;
  final bool active;
  final bool paused;
  final SelahMilestoneAttestation? pending;
  const SelahTimelineContext({
    this.matchId,
    this.active = false,
    this.paused = false,
    this.pending,
  });
}

class SelahMatchService {
  SelahMatchService._();

  /// Real mutual matches for the signed-in user, mapped to
  /// SeekerProfile so they can be merged straight into
  /// AppState.potentialJourneys. Empty (never an error surfaced to
  /// the UI) if not signed in, no real matches yet, or on any
  /// failure — the Matches tab already has its own empty-state copy.
  static Future<List<SeekerProfile>> fetchRealMatches() async {
    final user = SelahAuth.currentUser;
    if (user == null) return [];

    try {
      final rows =
          await supabase
                  .from('matches')
                  .select('seeker_a_id, seeker_b_id')
                  .eq('status', 'active')
                  .or('seeker_a_id.eq.${user.id},seeker_b_id.eq.${user.id}')
              as List;

      if (rows.isEmpty) return [];

      final otherIds = rows
          .map((r) {
            final map = r as Map<String, dynamic>;
            final a = map['seeker_a_id'] as String;
            final b = map['seeker_b_id'] as String;
            return a == user.id ? b : a;
          })
          .toSet()
          .toList();

      if (otherIds.isEmpty) return [];

      final profileRows =
          await supabase
                  .from('profiles')
                  .select(
                    'id, first_name, location_text, gender, profile_photos(storage_path, display_order)',
                  )
                  .inFilter('id', otherIds)
              as List;

      // Raw date_of_birth is no longer selectable by the client — see
      // 20260726120000_hide_raw_dob_expose_age.sql. Ages come from the
      // ages_for() SECURITY DEFINER function instead.
      final ages = await _fetchAges(otherIds);

      final results = <SeekerProfile>[];
      for (final row in profileRows) {
        final map = row as Map<String, dynamic>;
        final photosRaw = List<Map<String, dynamic>>.from(
          (map['profile_photos'] as List?) ?? const [],
        );
        photosRaw.sort(
          (a, b) =>
              (a['display_order'] as int).compareTo(b['display_order'] as int),
        );
        final photos = await SelahPhotoService.signedUrlsFor(
          photosRaw.map((p) => p['storage_path'] as String).toList(),
        );
        results.add(
          SeekerProfile(
            id: map['id'] as String,
            firstName: map['first_name'] as String,
            age: ages[map['id'] as String] ?? 0,
            city: (map['location_text'] as String?) ?? '—',
            photos: photos.isEmpty
                ? ['https://picsum.photos/seed/${map['id']}/700/1000']
                : photos,
            gender: map['gender'] as String,
          ),
        );
      }
      return results;
    } catch (_) {
      return [];
    }
  }

  /// Batch age lookup via the server-side ages_for() function — see
  /// 20260726120000_hide_raw_dob_expose_age.sql. Best-effort: on any
  /// failure, returns an empty map and callers fall back to age 0
  /// rather than breaking the Matches tab over an age lookup.
  static Future<Map<String, int>> _fetchAges(List<String> ids) async {
    // Delegates since 2026-08-08 — see SelahAgesService for why four
    // identical private copies of this became one.
    return SelahAgesService.forIds(ids, context: 'matches');
  }

  /// The signed-in user's CURRENT attempt on [matchId], or null.
  ///
  /// inherited upstream action 159 stage 4b, 2026-08-10. Conversations and timelines belong to
  /// an ATTEMPT now, not a pair, so anything that used to read them by
  /// `match_id` has to resolve the attempt first.
  ///
  /// READ THROUGH THE VIEW, NEVER BY JOINING journey_attempts. That table has
  /// RLS enabled with zero policies — every row is invisible to
  /// `authenticated`, so a client join to it returns nothing and the feature
  /// silently dies with no error to notice. `selah_my_attempt_participation`
  /// is the SECURITY DEFINER route that exists precisely for this.
  ///
  /// Ordered active-first, then newest: a pair with a live attempt is
  /// unambiguous, and a pair whose attempts have all ended should still
  /// resolve to the last one rather than to nothing. This mirrors the
  /// server-side `selah_set_attempt_from_match` trigger exactly — if either
  /// changes, change both, or the client and the database will disagree
  /// about which conversation is "the" conversation.
  /// Typed form used by summary surfaces that must distinguish a genuine
  /// no-attempt result from a failed read.
  static Future<({String? attemptId, bool failed})> currentAttemptIdResult(
    String matchId,
  ) async {
    try {
      final rows =
          await supabase
                  .from('selah_my_attempt_participation')
                  .select('attempt_id, attempt_status')
                  .eq('match_id', matchId)
              as List;
      if (rows.isEmpty) return (attemptId: null, failed: false);

      final maps = rows.cast<Map<String, dynamic>>().toList();
      final active = maps.where((r) => r['attempt_status'] == 'active');
      final attemptId = active.isNotEmpty
          ? active.first['attempt_id'] as String?
          : maps.last['attempt_id'] as String?;
      return (attemptId: attemptId, failed: false);
    } catch (e) {
      debugPrint('SELAH: currentAttemptId($matchId) failed — $e');
      return (attemptId: null, failed: true);
    }
  }

  /// Compatibility boundary for existing detail/chat consumers where null
  /// already means either unavailable or absent.
  static Future<String?> currentAttemptId(String matchId) async {
    final result = await currentAttemptIdResult(matchId);
    return result.attemptId;
  }

  /// Resolves the real conversation id for a match between the
  /// signed-in user and [otherUserId], or null if none exists (a
  /// preview candidate, no real match yet, or not signed in). Null is never
  /// permission to simulate a successful conversation for a real member.
  static Future<String?> resolveConversationId(String otherUserId) async {
    final user = SelahAuth.currentUser;
    if (user == null) return null;

    try {
      final matchRows =
          await supabase
                  .from('matches')
                  .select('id')
                  .or(
                    'and(seeker_a_id.eq.${user.id},seeker_b_id.eq.$otherUserId),'
                    'and(seeker_a_id.eq.$otherUserId,seeker_b_id.eq.${user.id})',
                  )
                  .limit(1)
              as List;
      if (matchRows.isEmpty) return null;
      final matchId = (matchRows.first as Map<String, dynamic>)['id'] as String;

      // inherited upstream action 159 stage 4b, 2026-08-10. WAS: .eq('match_id', matchId).
      //
      // conversations moved from UNIQUE(match_id) to UNIQUE(attempt_id) in
      // stage 4a, so a pair can now hold one conversation PER ATTEMPT. Read
      // by match_id with .limit(1) and Postgres returns whichever row it
      // likes — no error, no warning, and after a second Journey with the
      // same person you would silently open the OLD conversation, with the
      // previous attempt's messages in it.
      //
      // Resolved through selah_my_attempt_participation, NOT by joining
      // journey_attempts: that table has RLS on with zero policies, so any
      // client join to it returns nothing at all. Learned 2026-08-09; this is
      // exactly the query where it would have bitten.
      final attemptId = await currentAttemptId(matchId);
      if (attemptId == null) return null;

      final convRows =
          await supabase
                  .from('conversations')
                  .select('id')
                  .eq('attempt_id', attemptId)
                  .limit(1)
              as List;
      if (convRows.isEmpty) return null;
      return (convRows.first as Map<String, dynamic>)['id'] as String;
    } catch (error) {
      debugPrint(
        'SELAH: conversation resolution failed (${error.runtimeType}).',
      );
      return null;
    }
  }

  /// Legacy collection adapter; the Timeline UI uses [fetchTimelineResult]
  /// to distinguish unavailable history from a successful empty history.
  static Future<List<SelahMilestone>> fetchTimeline(String otherUserId) async {
    return (await fetchTimelineResult(otherUserId)).valueOr(const []);
  }

  static Future<SelahSourceResult<List<SelahMilestone>>> fetchTimelineResult(
    String otherUserId,
  ) async {
    final user = SelahAuth.currentUser;
    if (user == null) {
      return const SelahSourceResult.unavailable(SelahSourceFailure.signedOut);
    }

    try {
      final matchRows =
          await supabase
                  .from('matches')
                  .select('id')
                  .or(
                    'and(seeker_a_id.eq.${user.id},seeker_b_id.eq.$otherUserId),'
                    'and(seeker_a_id.eq.$otherUserId,seeker_b_id.eq.${user.id})',
                  )
                  .limit(1)
              as List;
      if (matchRows.isEmpty) return const SelahSourceResult.available([]);
      final matchId = (matchRows.first as Map<String, dynamic>)['id'] as String;

      // inherited upstream action 159 stage 4b. WAS: .eq('match_id', matchId) — see
      // resolveConversationId above for why that is now wrong.
      final attempt = await currentAttemptIdResult(matchId);
      if (attempt.failed) {
        return const SelahSourceResult.unavailable(
          SelahSourceFailure.requestFailed,
        );
      }
      final attemptId = attempt.attemptId;
      if (attemptId == null) return const SelahSourceResult.available([]);

      final timelineRows =
          await supabase
                  .from('timelines')
                  .select('id')
                  .eq('attempt_id', attemptId)
                  .limit(1)
              as List;
      if (timelineRows.isEmpty) return const SelahSourceResult.available([]);
      final timelineId =
          (timelineRows.first as Map<String, dynamic>)['id'] as String;

      final milestoneRows =
          await supabase
                  .from('timeline_milestones')
                  .select('milestone_type, occurred_at')
                  .eq('timeline_id', timelineId)
                  // OLDEST FIRST — the Timeline reads top to bottom, earliest at the
                  // top, and you scroll down through the Journey. Founder, 2026-08-11.
                  //
                  // ⚠️ ascending: true IS NOT THE DEFAULT. postgrest-dart declares
                  // `order(column, {bool ascending = false})`, so a bare .order()
                  // sorts NEWEST FIRST. Every place in this app that WANTS newest
                  // first passes ascending: false explicitly, which made the bare
                  // calls read as "chronological" at a glance. They were not.
                  // Found 2026-08-11 when the Founder reported the Timeline showing
                  // the oldest event at the BOTTOM. Never write a bare .order().
                  .order('occurred_at', ascending: true)
              as List;

      return SelahSourceResult.available(
        milestoneRows.map((r) {
          final map = r as Map<String, dynamic>;
          return SelahMilestone(
            type: map['milestone_type'] as String,
            occurredAt: DateTime.parse(map['occurred_at'] as String),
          );
        }).toList(),
      );
    } catch (error) {
      debugPrint('SELAH: timeline unavailable (${error.runtimeType}).');
      return const SelahSourceResult.unavailable(
        SelahSourceFailure.requestFailed,
      );
    }
  }

  static Future<List<SelahChatMessage>> fetchMessages(
    String conversationId,
  ) async => (await fetchMessagesResult(conversationId)).valueOr(const []);

  /// A failed history read must not look like a successfully empty chat.
  /// The legacy list method remains for callers which do not render truth
  /// states; ChatScreen consumes this typed result directly.
  static Future<SelahSourceResult<List<SelahChatMessage>>> fetchMessagesResult(
    String conversationId,
  ) async {
    final user = SelahAuth.currentUser;
    if (user == null) {
      return const SelahSourceResult.unavailable(SelahSourceFailure.signedOut);
    }
    try {
      final rows =
          await supabase
                  .from('messages')
                  .select('id, sender_id, content, created_at, read_at')
                  .eq('conversation_id', conversationId)
                  // OLDEST FIRST. ChatScreen appends new messages to the end of its
                  // list and renders it with reverse: true plus a reversed index — a
                  // double flip that displays list order top to bottom while anchoring
                  // to the newest. That only works if history arrives oldest first,
                  // and it was arriving newest first: the whole loaded history read
                  // backwards, with live messages appended after it the right way up.
                  //
                  // Never seen because no dev account had sent a message yet. Fixed in
                  // the same sweep as the Timeline — it is the same one-word mistake.
                  .order('created_at', ascending: true)
              as List;
      return SelahSourceResult.available(
        rows.map((r) {
          final map = r as Map<String, dynamic>;
          return SelahChatMessage(
            id: map['id'] as String,
            text: map['content'] as String,
            fromMe: map['sender_id'] == user.id,
            createdAt: DateTime.parse(map['created_at'] as String),
            readAt: map['read_at'] == null
                ? null
                : DateTime.parse(map['read_at'] as String),
          );
        }).toList(),
      );
    } catch (error) {
      debugPrint('SELAH: message history failed (${error.runtimeType}).');
      return const SelahSourceResult.unavailable(
        SelahSourceFailure.requestFailed,
      );
    }
  }

  /// Best-effort. Returns true on success so the caller can decide
  /// whether to roll back an optimistic local append on failure.
  static Future<bool> sendMessage(String conversationId, String text) async {
    final user = SelahAuth.currentUser;
    if (user == null) return false;
    try {
      await supabase.from('messages').insert({
        'conversation_id': conversationId,
        'sender_id': user.id,
        'content': text,
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Records that the signed-in Seeker has viewed the other Seeker's Journey
  /// messages. The server proves the caller is one of the two Seekers and
  /// never lets a Shepherd manufacture a Seeker receipt.
  static Future<bool> markMessagesRead(String conversationId) async {
    if (!supabaseReady) return false;
    final user = SelahAuth.currentUser;
    if (user == null) return false;
    try {
      await supabase.rpc(
        'selah_mark_journey_messages_read',
        params: {'p_conversation': conversationId},
      );
      return true;
    } catch (error) {
      debugPrint('SELAH: message read receipt failed (${error.runtimeType}).');
      return false;
    }
  }

  /// The pair's match id, or null. Same lookup fetchTimeline performs;
  /// extracted 2026-08-12 for the attestation flow.
  static Future<String?> _matchIdWith(String otherUserId) async {
    final user = SelahAuth.currentUser;
    if (user == null) return null;
    final rows =
        await supabase
                .from('matches')
                .select('id')
                .or(
                  'and(seeker_a_id.eq.${user.id},seeker_b_id.eq.$otherUserId),'
                  'and(seeker_a_id.eq.$otherUserId,seeker_b_id.eq.${user.id})',
                )
                .limit(1)
            as List;
    if (rows.isEmpty) return null;
    return (rows.first as Map<String, dynamic>)['id'] as String;
  }

  /// Milestone-recording context for the Timeline screen (2026-08-12,
  /// Founder-approved meeting/marriage attestation). Safe-empty on any
  /// failure — the Timeline still renders, just without the affordance.
  static Future<SelahTimelineContext> fetchTimelineContext(
    String otherUserId,
  ) async {
    try {
      final matchId = await _matchIdWith(otherUserId);
      if (matchId == null) return const SelahTimelineContext();
      final row = await supabase
          .from('matches')
          .select('status, suspended_by')
          .eq('id', matchId)
          .maybeSingle();
      SelahMilestoneAttestation? pending;
      final rows =
          await supabase.rpc(
                'selah_milestone_attestation_state',
                params: {'p_match_id': matchId},
              )
              as List;
      if (rows.isNotEmpty) {
        final m = rows.first as Map<String, dynamic>;
        pending = SelahMilestoneAttestation(
          id: m['id'] as String,
          type: m['milestone_type'] as String,
          occurredOn: DateTime.parse(m['occurred_on'] as String),
          proposedBy: m['proposed_by'] as String,
        );
      }
      return SelahTimelineContext(
        matchId: matchId,
        active: row?['status'] == 'active',
        paused: row?['suspended_by'] != null,
        pending: pending,
      );
    } catch (e) {
      debugPrint('SELAH fetchTimelineContext failed: $e');
      return const SelahTimelineContext();
    }
  }

  /// Null on success, otherwise a short user-facing reason.
  static Future<String?> proposeMilestone(
    String matchId,
    String type,
    DateTime occurredOn,
  ) async {
    try {
      await supabase.rpc(
        'selah_propose_milestone',
        params: {
          'p_match_id': matchId,
          'p_type': type,
          'p_occurred_on': occurredOn.toIso8601String().substring(0, 10),
        },
      );
      return null;
    } catch (e) {
      final s = e.toString();
      if (s.contains('milestone_already_recorded')) {
        return 'That milestone is already on your Timeline.';
      }
      if (s.contains('confirm_theirs_instead')) {
        return "They've already proposed this — confirm theirs instead.";
      }
      if (s.contains('journey_paused')) {
        return 'This Journey is paused — resume it first.';
      }
      if (s.contains('journey_not_active')) {
        return 'Only an Active Journey can record milestones.';
      }
      if (s.contains('milestone_in_future')) {
        return 'A milestone records something that has happened.';
      }
      debugPrint('SELAH proposeMilestone failed: $e');
      return "That didn't go through. Please try again.";
    }
  }

  /// Null on success, otherwise a short user-facing reason.
  static Future<String?> confirmMilestone(String attestationId) async {
    try {
      await supabase.rpc(
        'selah_confirm_milestone',
        params: {'p_attestation_id': attestationId},
      );
      return null;
    } catch (e) {
      final s = e.toString();
      if (s.contains('not_yours_to_confirm')) {
        return 'The other Seeker confirms this one.';
      }
      if (s.contains('attestation_not_pending')) {
        return 'This proposal is no longer waiting.';
      }
      if (s.contains('journey_paused')) {
        return 'This Journey is paused — resume it first.';
      }
      if (s.contains('journey_not_active')) {
        return 'Only an Active Journey can record milestones.';
      }
      debugPrint('SELAH confirmMilestone failed: $e');
      return "That didn't go through. Please try again.";
    }
  }
}
