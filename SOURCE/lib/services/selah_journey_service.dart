// Pre-Journey Ritual + Journey Suspension data/service layer, per
// APP/Journey/PRE-JOURNEY RITUAL/Summary.md and APP/Journey/JOURNEY
// SUSPENSION/JOURNEY_SUSPENSION (CURRENT_VERSION).
//
// Replaces the old client-only Potential/Active Journey stand-in in
// AppState (a synchronous SeekerProfile-list move with no backend
// behind it) now that matches.status/journey_stage/suspended_by and
// the journey_* tables are real schema (2026-07-25 migration). Same
// style as selah_match_service.dart / selah_mentor_link_service.dart:
// static methods, the global `supabase` getter, SelahAuth.currentUser,
// try/catch swallowing to safe defaults everywhere except the three
// RPC calls that need to surface a specific error to the UI.
//
// Out of scope here, per the reduced v1 scope agreed for this pass:
// Part B (searchable personal question library), Mentor<->Mentor
// engagement in the Family Stage (marked TBC in the source spec
// itself), AI-adaptive question selection/summaries (no LLM
// integration exists in this codebase — see journey_questions.dart),
// push notifications (no notification system exists anywhere yet),
// and the 30-day Full-Suspension auto-end timer — which was never built
// and is now REMOVED BY DECISION (inherited upstream action 164, inherited decision 121 item 12: SELAH
// never ends a Journey automatically; it reminds at 30 and 90 days and
// leaves the choice to the people). Realtime is also out of scope for this pass —
// refetchOne() is a plain re-fetch meant to be driven by a
// Timer.periodic in the UI, the same polling approach used nowhere
// else yet but simpler and safer than standing up a new Realtime
// channel subscription for this task.

import 'package:flutter/foundation.dart'
    show debugPrint, immutable, visibleForTesting;
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthException, PostgrestException;

import '../data/journey_questions.dart';
import '../data/selah_journey_legacy_pass_through.dart';
export '../data/selah_journey_legacy_pass_through.dart'
    show SelahStageAdvance, confirmSelahVisibleThreshold;
import '../data/selah_journey_pause_state.dart';
import '../data/selah_release_gates.dart';
import '../main.dart';
import '../models/journey_match.dart';
import '../models/seeker_profile.dart';
import 'selah_auth.dart';
import 'selah_account_state.dart';
import 'selah_identity_verification_service.dart';
import 'selah_photo_service.dart';
import 'selah_ages_service.dart';
import 'selah_truthful_write.dart';
import 'selah_mentor_link_service.dart';

typedef SelahFamilyReview = ({
  String id,
  String status,
  String toStage,
  DateTime deadlineAt,
});

/// inherited upstream action 284: an unavailable read is not evidence about either consent flag.
enum SelahCompatibilityReadStatus { available, empty, unavailable }

/// Safe reasons only. Provider messages and response payloads stay out of UI.
enum SelahCompatibilityReadFailure {
  signedOut,
  forbidden,
  configuration,
  transient,
  invalidResponse,
  staleOwner,
  unavailableJourney,
}

@immutable
class SelahCompatibilitySnapshot {
  final bool mine;
  final bool theirs;
  final double? overallScore;

  const SelahCompatibilitySnapshot({
    required this.mine,
    required this.theirs,
    required this.overallScore,
  });
}

/// A result may be published only within its captured member lifetime.
@immutable
class SelahCompatibilityReadScope {
  final String? actorId;
  final int accountGeneration;
  final String matchId;

  const SelahCompatibilityReadScope({
    required this.actorId,
    required this.accountGeneration,
    required this.matchId,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SelahCompatibilityReadScope &&
          actorId == other.actorId &&
          accountGeneration == other.accountGeneration &&
          matchId == other.matchId;

  @override
  int get hashCode => Object.hash(actorId, accountGeneration, matchId);
}

@immutable
class SelahCompatibilityReadResult {
  final SelahCompatibilityReadStatus status;
  final SelahCompatibilityReadScope scope;
  final SelahCompatibilitySnapshot? snapshot;
  final SelahCompatibilityReadFailure? failure;

  const SelahCompatibilityReadResult._({
    required this.status,
    required this.scope,
    this.snapshot,
    this.failure,
  });

  const SelahCompatibilityReadResult.available({
    required SelahCompatibilityReadScope scope,
    required SelahCompatibilitySnapshot snapshot,
  }) : this._(
         status: SelahCompatibilityReadStatus.available,
         scope: scope,
         snapshot: snapshot,
       );

  const SelahCompatibilityReadResult.empty({
    required SelahCompatibilityReadScope scope,
  }) : this._(status: SelahCompatibilityReadStatus.empty, scope: scope);

  const SelahCompatibilityReadResult.unavailable({
    required SelahCompatibilityReadScope scope,
    required SelahCompatibilityReadFailure failure,
  }) : this._(
         status: SelahCompatibilityReadStatus.unavailable,
         scope: scope,
         failure: failure,
       );
}

/// Thrown by [SelahJourneyService.promoteToActive] when the caller
/// already holds an Active Journey — SELAH is one-Active-Journey-at-a-
/// time per seeker. The UI needs to show a specific message for this
/// case rather than a generic failure.
class OneActiveJourneyLimitException implements Exception {}

/// Resume refused: the other Seeker currently holds an Active Journey.
///
/// NOT an ending. The Journey stays exactly as it was — paused, intact,
/// resumable later. This is a "not yet", and the copy must say so.
class OtherPartyInActiveJourneyException implements Exception {}

/// Resume refused: one of the two has blocked the other, or one is now the
/// other's Shepherd. Server code `not_eligible_to_continue`.
///
/// This one IS terminal, and the copy must NOT imply otherwise — unlike
/// [OtherPartyInActiveJourneyException], waiting will not help. The
/// Journey stays paused and the only real exit is ending it.
///
/// Added 2026-08-08 with inherited upstream action 174. The shared transition RPC uses the
/// narrower `not_eligible_to_continue` check rather than the full match
/// predicate, which
/// included Tier-1 (the two share a Shepherd) — so a third party's action
/// could trap a Journey with an error the Seeker could not act on. Tier-1
/// is now grandfathered for Journeys already under way; only blocks and
/// Tier-0 refuse a resume, and both are visible to the two parties.
class NotEligibleToContinueException implements Exception {}

/// Mutual resume was refused because the caller already holds their plan's
/// Active capacity. The shared Pause remains intact.
class SelfInActiveJourneyException implements Exception {}

class PauseTransitionStaleException implements Exception {}

class PauseTransitionNotAllowedException implements Exception {}

class PauseCapacityConflictException implements Exception {}

/// Unreferenced since 2026-08-06 (inherited upstream action 154) — the 24-hour restart
/// cooling period it reported no longer exists.
///
/// Kept, not deleted: V3 §9 gives Request New Journey a **6-month** cooldown
/// after a decline (inherited upstream action 159), so a cooldown exception returns shortly.
/// Deleting and re-adding it would lose the trail between the two rules.
class CoolingPeriodActiveException implements Exception {}

/// Outcome of [SelahJourneyService.openFamilyReview].
///
/// Deliberately the same shape as [SelahStageAdvance], and deliberately
/// the same vocabulary where the two overlap. These are the TWO DOORS
/// into one state machine — selah_advance_stage for the three direct
/// transitions, open_family_review for the four gated ones — and a
/// caller should not have to learn two dialects to ask "why didn't that
/// work".
///
/// [reason] carries the server's own word:
///   opened · stage_moved · journey_paused · journey_not_active ·
///   not_a_gated_transition · invalid_transition · not_a_party ·
///   call_failed
///
/// ADDED 2026-08-09 with the audit 2.2 fix. Until then this call returned
/// `String?` from inside a bare `catch (_)`, and its one caller discarded
/// even that — so a refusal and a success were the same event: a tap, a
/// refresh, and nothing moving. That is the exact shape of the 2026-08-07
/// release blocker, and tightening the server made it MORE reachable, not
/// less. A validation you cannot see refuse you is indistinguishable from
/// a bug.
class SelahReviewOpen {
  /// The pending review — newly created, or the existing one, since the
  /// RPC is idempotent. Null means it was refused.
  final String? reviewId;
  final String reason;
  const SelahReviewOpen(this.reviewId, this.reason);

  bool get ok => reviewId != null;

  static const failed = SelahReviewOpen(null, 'call_failed');
}

class SelahJourneyService {
  SelahJourneyService._();

  /// Maps the caller-relative RPC result. The database never returns a side
  /// label, counterpart score, legacy category JSON, user id or attempt id.
  @visibleForTesting
  static ({bool mine, bool theirs, double? overallScore})
  compatibilityResultFromRpcRow(Map<String, dynamic> row) => (
    mine: row['mine_revealed'] == true,
    theirs: row['counterpart_revealed'] == true,
    overallScore: (row['my_score'] as num?)?.toDouble(),
  );

  /// Transitional compatibility for the short interval between shipping the
  /// client and applying the repository migration. Existing fully paused rows
  /// map to the new neutral mutual-Pause state; pending states only exist once
  /// the new columns and RPC are live.
  static SelahJourneyPauseState _pauseFromRow(Map<String, dynamic> row) {
    if (row.containsKey('pause_state')) {
      return SelahJourneyPauseState.fromStorage(
        phase: row['pause_state'] as String?,
        initiatedBy: row['pause_initiated_by'] as String?,
        requestedBy: row['pause_requested_by'] as String?,
        requestedAt: row['pause_requested_at'],
        deadlineAt: row['pause_deadline_at'],
        version: row['pause_version'],
      );
    }
    final legacyPauser = row['suspended_by'] as String?;
    return legacyPauser == null
        ? SelahJourneyPauseState.active
        : SelahJourneyPauseState(
            phase: SelahPausePhase.paused,
            initiatedBy: legacyPauser,
          );
  }

  /// Actor ids are intentionally not selectable from matches because a Main
  /// Shepherd can read that row. This party-scoped RPC returns them only to
  /// the two Seekers, in one batch. Null means the migration is not live yet;
  /// other failures remain failures rather than being painted as Active.
  static Future<Map<String, SelahJourneyPauseState>?> _fetchPauseStates(
    List<String> matchIds,
  ) async {
    if (matchIds.isEmpty) return const {};
    try {
      final raw = await supabase.rpc(
        'selah_my_pause_states',
        params: {'p_match_ids': matchIds},
      );
      return {
        for (final value in (raw as List? ?? const []))
          if ((value as Map)['match_id'] != null)
            value['match_id'] as String: _pauseFromRow(
              Map<String, dynamic>.from(value),
            ),
      };
    } catch (e) {
      final message = e.toString();
      if (message.contains('selah_my_pause_states') &&
          (message.contains('PGRST202') ||
              message.toLowerCase().contains('not find'))) {
        debugPrint(
          'SELAH: shared Pause RPC not live yet; using neutral legacy bridge.',
        );
        return null;
      }
      rethrow;
    }
  }

  /// Real matches for the signed-in user in any of [statuses], mapped
  /// to JourneyMatch with the OTHER party's profile attached. Empty if
  /// not signed in or the server answered with no linked profiles.
  /// Null = the fetch FAILED; [] = the server answered "none". The
  /// distinction is inherited decision 179's whole lesson — see the catch below.
  static Future<List<JourneyMatch>?> fetchJourneyMatches({
    required List<String> statuses,
  }) async {
    final user = SelahAuth.currentUser;
    if (user == null) return [];

    try {
      final rows =
          await supabase
                  .from('matches')
                  .select(
                    'id, seeker_a_id, seeker_b_id, status, journey_stage, '
                    'suspended_by, suspended_at, ended_at',
                  )
                  .inFilter('status', statuses)
                  .or('seeker_a_id.eq.${user.id},seeker_b_id.eq.${user.id}')
              as List;

      if (rows.isEmpty) return [];

      final pauseByMatchId = await _fetchPauseStates([
        for (final row in rows) (row as Map<String, dynamic>)['id'] as String,
      ]);

      final busyByMatchId = await _fetchBusyFlags([
        for (final row in rows) (row as Map<String, dynamic>)['id'] as String,
      ]);

      final matchByOtherId = <String, Map<String, dynamic>>{};
      for (final r in rows) {
        final map = r as Map<String, dynamic>;
        final a = map['seeker_a_id'] as String;
        final b = map['seeker_b_id'] as String;
        final otherId = a == user.id ? b : a;
        matchByOtherId[otherId] = map;
      }

      final otherIds = matchByOtherId.keys.toList();
      if (otherIds.isEmpty) return [];

      final profileRows =
          await supabase
                  .from('profiles')
                  .select(
                    'id, first_name, surname_line, location_text, gender, profile_photos(storage_path, display_order)',
                  )
                  .inFilter('id', otherIds)
              as List;

      // Raw date_of_birth is no longer selectable by the client — see
      // 20260726120000_hide_raw_dob_expose_age.sql. Ages come from the
      // ages_for() SECURITY DEFINER function instead.
      final ages = await _fetchAges(otherIds);

      final photoPathsById = <String, List<String>>{};
      for (final row in profileRows) {
        final map = row as Map<String, dynamic>;
        final otherId = map['id'] as String;
        if (!matchByOtherId.containsKey(otherId)) continue;
        final photosRaw = List<Map<String, dynamic>>.from(
          (map['profile_photos'] as List?) ?? const [],
        );
        photosRaw.sort(
          (a, b) =>
              (a['display_order'] as int).compareTo(b['display_order'] as int),
        );
        photoPathsById[otherId] = [
          for (final photo in photosRaw) photo['storage_path'] as String,
        ];
      }
      // Sign the linked profiles together, then correlate by path rather
      // than by position. A missing photo stays neutral; it must not turn
      // into a fabricated person's image or remove an existing Journey.
      final signedPhotos = await SelahPhotoService.signedUrlMap([
        for (final paths in photoPathsById.values) ...paths,
      ]);

      final results = <JourneyMatch>[];
      for (final row in profileRows) {
        final map = row as Map<String, dynamic>;
        final otherId = map['id'] as String;
        final matchRow = matchByOtherId[otherId];
        if (matchRow == null) continue;

        final photos = <String>[
          for (final path in photoPathsById[otherId] ?? const <String>[])
            if (signedPhotos[path]?.isNotEmpty == true) signedPhotos[path]!,
        ];

        final profile = SeekerProfile(
          id: otherId,
          firstName: map['first_name'] as String,
          surnameLine: map['surname_line'] as String?,
          age: ages[otherId] ?? 0,
          city: (map['location_text'] as String?) ?? '—',
          photos: photos,
          gender: map['gender'] as String,
        );

        results.add(
          JourneyMatch(
            matchId: matchRow['id'] as String,
            profile: profile,
            status: matchRow['status'] as String,
            journeyStage: matchRow['journey_stage'] as String?,
            pause:
                pauseByMatchId?[matchRow['id'] as String] ??
                _pauseFromRow(matchRow),
            suspendedAt: matchRow['suspended_at'] == null
                ? null
                : DateTime.parse(matchRow['suspended_at'] as String),
            endedAt: matchRow['ended_at'] == null
                ? null
                : DateTime.parse(matchRow['ended_at'] as String),
            inAnotherJourney: busyByMatchId[matchRow['id'] as String] ?? false,
          ),
        );
      }
      return results;
    } catch (e) {
      // inherited decision 179. This catch used to return [] — which is how a 403
      // (matches' column-scoped grant missing the new pause columns)
      // spent three days reading as "you have no Journeys" while the
      // dev panel's stand-ins painted over the hole. A failed fetch is
      // not an empty list; callers hold their last-known list on null
      // and say so.
      debugPrint('SELAH: fetchJourneyMatches failed (${e.runtimeType}).');
      return null;
    }
  }

  /// Batch age lookup via the server-side ages_for() function — see
  /// 20260726120000_hide_raw_dob_expose_age.sql. Best-effort: on any
  /// failure, returns an empty map and callers fall back to age 0
  /// rather than breaking Journey/Matches over an age lookup.
  static Future<Map<String, int>> _fetchAges(List<String> ids) async {
    // Delegates since 2026-08-08 — see SelahAgesService for why four
    // identical private copies of this became one.
    return SelahAgesService.forIds(ids, context: 'journeys');
  }

  /// Server-computed availability of the other party for each Journey row.
  ///
  /// This call is deliberately not best-effort. Returning false after a
  /// failed availability read would tell the Seeker that a busy person is
  /// ready. Its exception therefore reaches fetchJourneyMatches/refetchOne,
  /// whose truthful failure contract keeps the last-known UI instead.
  static Future<Map<String, bool>> _fetchBusyFlags(
    List<String> matchIds,
  ) async {
    if (matchIds.isEmpty) return const {};
    final rows = await supabase.rpc(
      'selah_journey_busy_flags',
      params: {'p_match_ids': matchIds},
    );
    return busyFlagsFromRows(rows);
  }

  @visibleForTesting
  static Map<String, bool> busyFlagsFromRows(Object? value) {
    final result = <String, bool>{};
    for (final raw in (value as List? ?? const [])) {
      final row = Map<String, dynamic>.from(raw as Map);
      final matchId = row['match_id'] as String?;
      if (matchId != null) {
        result[matchId] = row['in_another_journey'] == true;
      }
    }
    return result;
  }

  /// DEV ONLY (inherited decision 180). Creates a REAL Journey — live match row,
  /// attempt, conversation and timeline shells — between this seeded
  /// account and the first free seeded browse account of the opposite
  /// gender. Returns the server's own sentence about what it did:
  /// seeded with whom, or slots full and with whom you already are.
  /// Guarded server-side to @selah.test accounts on both sides; throws
  /// on refusal so the panel shows the truth rather than pretending.
  /// (Since inherited decision 183 the seeded Journey starts at Greeting Exchange.)
  static Future<String> devSeedJourney() async {
    final res = await supabase.rpc('selah_dev_seed_journey');
    return res as String;
  }

  /// Potential -> Active. Throws [OneActiveJourneyLimitException] if
  /// the caller already has an Active Journey; returns false (never
  /// throws) for any other failure.
  static Future<bool> promoteToActive(String matchId) async {
    try {
      if (SelahIdentityVerificationService.enforceExistingAccountGate) {
        final verification =
            await SelahIdentityVerificationService.fetchMyState();
        if (verification?.allowsActiveJourney != true) return false;
      }
      await supabase.rpc(
        'promote_journey_to_active',
        params: {'p_match_id': matchId},
      );
      return true;
    } catch (e) {
      if (e.toString().contains('one_active_journey_limit')) {
        throw OneActiveJourneyLimitException();
      }
      return false;
    }
  }

  /// Best-effort. Swallows errors — the Greeting Exchange screen re-reads
  /// state via fetchGreetingStatus rather than trusting this call succeeded.
  /// True when the Greeting is on the server (a duplicate send counts —
  /// the state it asked for exists). False means IT DID NOT HAPPEN, and
  /// the page says so — inherited decision 192 retired the silent catch here: a
  /// swallowed failure left the button looking pressed and the Greeting
  /// unsent, indistinguishable from success.
  static Future<bool> sendGreeting(String matchId) async {
    final user = SelahAuth.currentUser;
    if (user == null) return false;
    try {
      // ignoreDuplicates: true — RELEASE BLOCKER FIX 2026-08-09, audit
      // finding 1.1. A bare .upsert() sends ON CONFLICT DO UPDATE, which
      // needs the UPDATE privilege at plan time; `authenticated` has
      // INSERT on this table and no UPDATE, so every Greeting was refused
      // with 42501 and swallowed here. selah_advance_stage then returned
      // waiting_for_greeting forever and the Journey could not leave the
      // Greeting Exchange — a SECOND, independent cause of the same stuck
      // screen the advanceStage no-op caused on 2026-08-07.
      //
      // DO NOTHING is also the right semantics: the primary key IS
      // (match_id, seeker_id) and there is no payload. A Greeting is sent
      // once; sending it again is a no-op, not an overwrite.
      await supabase
          .from('journey_greetings')
          .upsert(
            {'match_id': matchId, 'seeker_id': user.id},
            onConflict: 'match_id,seeker_id',
            ignoreDuplicates: true,
          );
      return true;
    } catch (e) {
      debugPrint('SELAH: sendGreeting($matchId) failed - $e');
      return false;
    }
  }

  /// Null means THE READ FAILED — the caller holds its last known state.
  /// It used to return (false, false) on error, which flickered a
  /// waiting user back to the send state on any transient failure and
  /// made "you have sent no Greeting" indistinguishable from "the network
  /// dropped" (inherited decision 192; the same truthful-failure rule as
  /// fetchJourneyMatches).
  static Future<({bool mine, bool theirs})?> fetchGreetingStatus(
    String matchId,
    String otherUserId,
  ) async {
    final user = SelahAuth.currentUser;
    if (user == null) return null;
    try {
      final rows =
          await supabase
                  .from('journey_greetings')
                  .select('seeker_id')
                  .eq('match_id', matchId)
              as List;
      final ids = rows
          .map((r) => (r as Map<String, dynamic>)['seeker_id'] as String)
          .toSet();
      return (mine: ids.contains(user.id), theirs: ids.contains(otherUserId));
    } catch (e) {
      debugPrint('SELAH: fetchGreetingStatus($matchId) failed - $e');
      return null;
    }
  }

  /// Whether [userId] has a linked, active Main Mentor — the Mentor Gate
  /// requirement. Written generically taking a userId param, though in
  /// practice the Mentor Gate only ever checks the ACTING seeker (`me`),
  /// per Summary.md: "A Seeker must have a linked, active Main Shepherd to
  /// proceed" (their own Mentor, not the other party's).
  static Future<bool> hasActiveMainMentor(String userId) async {
    try {
      final rows =
          await supabase
                  .from('mentor_links')
                  .select('id')
                  .eq('seeker_id', userId)
                  .eq('is_main', true)
                  .eq('status', 'active')
                  .limit(1)
              as List;
      return rows.isNotEmpty;
    } catch (e) {
      debugPrint('SELAH: hasActiveMainMentor($userId) failed - $e');
      return false;
    }
  }

  /// Sets the caller's own reveal flag and computes THEIR OWN compatibility
  /// figure — how well this other person's answers fit what the caller said
  /// they were looking for. Callers read it back via [fetchCompatibility].
  ///
  /// The doc this replaces described the retired behaviour: wait for both
  /// parties, then compute one shared number guarded by `overall_score IS
  /// NULL`. That column no longer exists (inherited upstream action 193 a2).
  ///
  /// The mutual gate has NOT gone away — it moved to where it belongs. Both
  /// still have to choose to reveal before either is shown anything; that is
  /// the ritual. What changed is only whose number is behind it.
  static Future<void> revealCompatibility(
    String matchId,
    // Transitional positional argument retained so the Journey screen does
    // not need a broad edit in this security patch. It is deliberately never
    // sent to or trusted by the database; auth.uid() and the match row derive
    // the counterpart inside the RPC.
    String otherUserId,
  ) async {
    final user = SelahAuth.currentUser;
    if (user == null) return;
    try {
      await supabase.rpc(
        'selah_reveal_journey_compatibility',
        params: {'p_match_id': matchId},
      );
    } catch (e) {
      // 2026-08-12: the reveal write could fail on every poll with no
      // trace — the score simply never persisted. Logged (CLAUDE.md §3).
      debugPrint('SELAH compatibility write($matchId) failed: $e');
    }
  }

  /// Returns only the caller-owned overall score and the mutual reveal flags.
  ///
  /// No server-owned, provenance-safe category scoring contract exists yet.
  /// Historical rows can contain a synthetic map made by copying the overall
  /// score into every category, so category columns are deliberately not even
  /// selected. A future rollout needs a versioned real-data contract and a
  /// deliberate legacy-row cleanup before category detail returns.
  static Future<SelahCompatibilityReadResult> fetchCompatibility(
    String matchId,
  ) async {
    final scope = SelahCompatibilityReadScope(
      actorId: SelahAuth.currentUser?.id,
      accountGeneration: SelahAccountState.generation,
      matchId: matchId,
    );
    if (scope.actorId == null) {
      return SelahCompatibilityReadResult.unavailable(
        scope: scope,
        failure: SelahCompatibilityReadFailure.signedOut,
      );
    }
    if (!_compatibilityScopeIsCurrent(scope)) {
      return SelahCompatibilityReadResult.unavailable(
        scope: scope,
        failure: SelahCompatibilityReadFailure.staleOwner,
      );
    }
    try {
      final rows = await supabase.rpc(
        'selah_journey_compatibility_state',
        params: {'p_match_id': matchId},
      );
      if (!_compatibilityScopeIsCurrent(scope)) {
        return SelahCompatibilityReadResult.unavailable(
          scope: scope,
          failure: SelahCompatibilityReadFailure.staleOwner,
        );
      }
      if (rows is! List) {
        return SelahCompatibilityReadResult.unavailable(
          scope: scope,
          failure: SelahCompatibilityReadFailure.invalidResponse,
        );
      }
      if (rows.isEmpty) return SelahCompatibilityReadResult.empty(scope: scope);
      if (rows.length != 1 || rows.single is! Map) {
        return SelahCompatibilityReadResult.unavailable(
          scope: scope,
          failure: SelahCompatibilityReadFailure.invalidResponse,
        );
      }
      final row = rows.single as Map;
      final mine = row['mine_revealed'];
      final theirs = row['counterpart_revealed'];
      final score = row['my_score'];
      if (mine is! bool ||
          theirs is! bool ||
          !row.containsKey('my_score') ||
          (score != null && (score is! num || !score.isFinite)) ||
          (score != null && (!mine || !theirs))) {
        return SelahCompatibilityReadResult.unavailable(
          scope: scope,
          failure: SelahCompatibilityReadFailure.invalidResponse,
        );
      }
      final mapped = compatibilityResultFromRpcRow(
        Map<String, dynamic>.from(row),
      );
      return SelahCompatibilityReadResult.available(
        scope: scope,
        snapshot: SelahCompatibilitySnapshot(
          mine: mapped.mine,
          theirs: mapped.theirs,
          overallScore: mapped.overallScore,
        ),
      );
    } catch (error) {
      // Check the lifetime in the catch window too: an old owner's failure
      // cannot invalidate or repaint the replacement member's confirmed state.
      if (!_compatibilityScopeIsCurrent(scope)) {
        return SelahCompatibilityReadResult.unavailable(
          scope: scope,
          failure: SelahCompatibilityReadFailure.staleOwner,
        );
      }
      return SelahCompatibilityReadResult.unavailable(
        scope: scope,
        failure: _compatibilityReadFailure(error),
      );
    }
  }

  static bool _compatibilityScopeIsCurrent(SelahCompatibilityReadScope scope) {
    final actorId = scope.actorId;
    return actorId != null &&
        SelahAuth.currentUser?.id == actorId &&
        SelahAccountState.isCurrent(actorId, scope.accountGeneration);
  }

  static SelahCompatibilityReadFailure _compatibilityReadFailure(Object error) {
    if (error is AuthException) return SelahCompatibilityReadFailure.signedOut;
    if (error is PostgrestException) {
      final code = error.code;
      if (code == '401' ||
          code == 'PGRST301' ||
          code == 'PGRST302' ||
          code == 'PGRST303' ||
          code == '28000' ||
          code == '28P01' ||
          (code == '42501' && error.message == 'not_signed_in')) {
        return SelahCompatibilityReadFailure.signedOut;
      }
      if (code == '403' || code == '42501') {
        return SelahCompatibilityReadFailure.forbidden;
      }
      if (code == '55000') {
        return SelahCompatibilityReadFailure.unavailableJourney;
      }
      if (const {
        '404',
        '42883',
        '42P01',
        '42703',
        'PGRST106',
        'PGRST202',
        'PGRST204',
        'PGRST205',
        'PGRST300',
      }.contains(code)) {
        return SelahCompatibilityReadFailure.configuration;
      }
      final status = int.tryParse(code ?? '');
      if ((status != null && status >= 200 && status < 300) ||
          code == '400' ||
          (code?.startsWith('22') ?? false)) {
        return SelahCompatibilityReadFailure.invalidResponse;
      }
      return SelahCompatibilityReadFailure.transient;
    }
    if (error is FormatException || error is TypeError) {
      return SelahCompatibilityReadFailure.invalidResponse;
    }
    return SelahCompatibilityReadFailure.transient;
  }

  /// Plain insert, matching the "answer all, then reveal" flow.
  /// A duplicate retry counts as already saved; every other failure returns
  /// false so the screen can stay on server-derived state and offer Retry.
  static Future<bool> submitPhaseAnswer(
    String matchId,
    int phase,
    String questionId,
    String answerText,
  ) async {
    final user = SelahAuth.currentUser;
    if (user == null) return false;
    // The field formatter is the first boundary. Keep the same rule here so
    // another caller cannot bypass the Faith & Values cap by invoking the
    // service directly.
    if (!JourneyQuestions.answerFitsCharacterLimit(phase, answerText)) {
      return false;
    }
    return runSelahTruthfulWrite(
      context: 'submitPhaseAnswer($matchId/$phase/$questionId)',
      duplicateIsSuccess: true,
      write: () => supabase.from('journey_phase_answers').insert({
        'match_id': matchId,
        'phase': phase,
        'seeker_id': user.id,
        'question_id': questionId,
        'answer_text': answerText,
      }),
    );
  }

  /// {otherPartyOrMineUserId: {questionId: answerText}} for both
  /// seekers in this phase — used both to check "have both submitted
  /// everything" and to render the simultaneous reveal.
  static Future<Map<String, Map<String, String>>> fetchPhaseAnswers(
    String matchId,
    int phase,
  ) async {
    try {
      final rows =
          await supabase
                  .from('journey_phase_answers')
                  .select('seeker_id, question_id, answer_text')
                  .eq('match_id', matchId)
                  .eq('phase', phase)
              as List;

      final result = <String, Map<String, String>>{};
      for (final r in rows) {
        final map = r as Map<String, dynamic>;
        final seekerId = map['seeker_id'] as String;
        final questionId = map['question_id'] as String;
        final answerText = map['answer_text'] as String;
        result.putIfAbsent(seekerId, () => {})[questionId] = answerText;
      }
      return result;
    } catch (e) {
      debugPrint('SELAH: fetchPhaseAnswers($matchId/$phase) failed - $e');
      return {};
    }
  }

  /// [rating] is one of 'reassured' / 'discuss_further' / 'concerns'
  /// (Summary.md's private rating phrases). Private to the rater by
  /// RLS — never shown to the other party or the Mentor.
  static Future<bool> submitRating(
    String matchId,
    int phase,
    String questionId,
    String rating,
  ) async {
    final user = SelahAuth.currentUser;
    if (user == null) return false;
    return runSelahTruthfulWrite(
      context: 'submitRating($matchId/$phase/$questionId)',
      duplicateIsSuccess: true,
      write: () => supabase.from('journey_phase_ratings').insert({
        'match_id': matchId,
        'phase': phase,
        'rater_id': user.id,
        'question_id': questionId,
        'rating': rating,
      }),
    );
  }

  /// [decision] is one of 'continue' / 'ask_more' / 'end'.
  static Future<bool> submitCheckpoint(
    String matchId,
    int phase,
    String decision,
  ) async {
    final user = SelahAuth.currentUser;
    if (user == null) return false;
    return runSelahTruthfulWrite(
      context: 'submitCheckpoint($matchId/$phase/$decision)',
      write: () async {
        // ignoreDuplicates: true — audit finding 1.1, same 42501 as the
        // Greeting above.
        //
        // THIS ONE CARRIES A PAYLOAD, so DO NOTHING is a real behavioural
        // choice and not just a permission workaround: the FIRST decision
        // stands and a later submission is ignored. Checked before making
        // it — journey_flow_screen renders the Continue / End buttons only
        // `if (myCheckpoint == null)`, so there is no path in the app to
        // change a checkpoint once it is recorded. First-write-wins matches
        // what the UI already promises.
        //
        // If a "change your mind" flow is ever added, this needs an RPC or
        // a self-scoped UPDATE grant — not a bare upsert. Leaving that note
        // here rather than discovering it as a silent no-op later.
        await supabase
            .from('journey_phase_checkpoints')
            .upsert(
              {
                'match_id': matchId,
                'phase': phase,
                'seeker_id': user.id,
                'decision': decision,
              },
              onConflict: 'match_id,phase,seeker_id',
              ignoreDuplicates: true,
            );
      },
    );
  }

  static Future<Map<String, String>> fetchCheckpoints(
    String matchId,
    int phase,
  ) async {
    try {
      final rows =
          await supabase
                  .from('journey_phase_checkpoints')
                  .select('seeker_id, decision')
                  .eq('match_id', matchId)
                  .eq('phase', phase)
              as List;
      return {
        for (final r in rows)
          (r as Map<String, dynamic>)['seeker_id'] as String:
              r['decision'] as String,
      };
    } catch (e) {
      debugPrint('SELAH: fetchCheckpoints($matchId/$phase) failed - $e');
      return {};
    }
  }

  /// Advances one of the THREE ungated Pre-Journey Ritual transitions:
  /// greeting_exchange -> compatibility_reveal -> mentor_gate -> phase_1
  /// (Greeting first since inherited decision 183; the server owns this map).
  ///
  /// Takes the stage the caller believes it has COMPLETED, not the one
  /// it wants next. The server owns the map, so a client cannot name a
  /// destination and there is no skip-ahead to validate; it also acts as
  /// a compare-and-swap token, so a stale screen gets 'stage_moved'
  /// rather than dragging the Journey backwards.
  ///
  /// The four Family-Review-gated transitions (phase_1->2, phase_2->3,
  /// phase_3->family_stage, family_stage->conversation) are REFUSED by
  /// the server — they go through [openFamilyReview]. Accepting them
  /// here would be a way to skip the 48-hour review period.
  ///
  /// REPLACED 2026-08-08 (release blocker, Founder-classified
  /// 2026-08-07). The previous implementation wrote matches.journey_stage
  /// directly. `matches` has a SELECT policy and no UPDATE policy, so
  /// RLS discarded the write: 0 rows, no exception, inside catch (_) {}.
  /// Because these are the FIRST three transitions, no Journey could ever
  /// leave compatibility_reveal. Verified live before and after.
  ///
  /// The 'conversation' branch is gone with it: that stage is reachable
  /// only via the gated path, and resolve_family_review_if_due() /
  /// mentor_review_decision() already open the conversation row server-side.
  static Future<SelahStageAdvance> advanceStage(
    String matchId,
    String fromStage,
  ) async {
    try {
      final rows = await supabase.rpc(
        'selah_advance_stage',
        params: {'p_match_id': matchId, 'p_from_stage': fromStage},
      );
      if (rows is! List || rows.isEmpty) {
        debugPrint(
          '[SelahJourneyService.advanceStage] $matchId from=$fromStage returned no row',
        );
        return SelahStageAdvance.failed;
      }
      final r = rows.first as Map<String, dynamic>;
      return SelahStageAdvance(
        r['advanced'] == true,
        r['stage'] as String?,
        (r['reason'] as String?) ?? 'unknown',
      );
    } catch (e) {
      // ES-08. Never silent again — this is the exact call site whose
      // silence hid the blocker.
      debugPrint(
        '[SelahJourneyService.advanceStage] $matchId from=$fromStage failed: $e',
      );
      return SelahStageAdvance.failed;
    }
  }

  /// LOCK 21 client pass-through; every write still uses the existing RPC.
  static Future<SelahStageAdvance?> advanceVisibleThreshold(
    String matchId,
    String fromStage, {
    required bool Function() canAct,
  }) => advanceSelahVisibleThreshold(
    fromStage: fromStage,
    canAct: canAct,
    advance: (stage) => advanceStage(matchId, stage),
  );

  // --- Family Review Period (#31) ---------------------------------------
  //
  // MENTOR_ARCHITECTURE_CURRENT_VERSION_V6.md: "After both Seekers
  // complete a Journey stage, the next stage does not unlock
  // immediately. Instead, the Journey enters a 48-hour Family Review
  // Period." Backed by 20260726190000_family_review_period.sql — see
  // that migration's own header comment for the full v1 scope
  // reasoning (which transitions are gated, who participates,
  // resolution rules) and inherited decision 110.

  /// Opens (or returns the existing) pending Family Review for
  /// [matchId]'s transition from [fromStage] to [toStage]. Safe to call
  /// from both Seekers' clients without double-opening — the RPC is
  /// idempotent.
  ///
  /// SINCE 2026-08-09 the server VALIDATES this call rather than trusting
  /// it (audit 2.2 — it used to accept any stage pair, so one Seeker
  /// alone could jump the whole Journey to Conversation). It now refuses
  /// a transition that is not one of the four gated ones, a to_stage that
  /// is not the real successor, a from_stage that is not where the
  /// Journey actually is, and an ended or paused Journey.
  ///
  /// Which means this can now legitimately FAIL for a user doing nothing
  /// wrong — most realistically `stage_moved`, when the other Seeker's
  /// client opened the review a moment earlier. So it returns a reason
  /// instead of null. See [SelahReviewOpen].
  static Future<SelahReviewOpen> openFamilyReview(
    String matchId,
    String fromStage,
    String toStage,
  ) async {
    try {
      final id = await supabase.rpc(
        'open_family_review',
        params: {
          'p_match_id': matchId,
          'p_from_stage': fromStage,
          'p_to_stage': toStage,
        },
      );
      if (id == null) {
        debugPrint(
          '[SelahJourneyService.openFamilyReview] $matchId '
          '$fromStage->$toStage returned null',
        );
        return SelahReviewOpen.failed;
      }
      return SelahReviewOpen(id as String, 'opened');
    } catch (e) {
      // Named server errors are matched on the message, which is the
      // idiom already used for one_active_journey_limit,
      // suspension_requires_one and not_eligible_to_continue above.
      debugPrint(
        '[SelahJourneyService.openFamilyReview] $matchId '
        '$fromStage->$toStage refused: $e',
      );
      final s = e.toString();
      if (s.contains('stage_moved')) {
        return const SelahReviewOpen(null, 'stage_moved');
      }
      if (s.contains('journey_paused')) {
        return const SelahReviewOpen(null, 'journey_paused');
      }
      if (s.contains('journey_not_active')) {
        return const SelahReviewOpen(null, 'journey_not_active');
      }
      if (s.contains('not_a_gated_transition')) {
        return const SelahReviewOpen(null, 'not_a_gated_transition');
      }
      if (s.contains('invalid_transition')) {
        return const SelahReviewOpen(null, 'invalid_transition');
      }
      if (s.contains('not a party')) {
        return const SelahReviewOpen(null, 'not_a_party');
      }
      return SelahReviewOpen.failed;
    }
  }

  /// Current review for [matchId] (pending OR paused — resolved/
  /// 'continued' reviews are historical and not returned once the stage has
  /// moved on). An available null means there is no live review; unavailable
  /// means that claim could not be established.
  static Future<SelahSourceResult<SelahFamilyReview?>> fetchFamilyReviewResult(
    String matchId,
  ) async {
    if (!supabaseReady) {
      return const SelahSourceResult.unavailable(SelahSourceFailure.notReady);
    }
    if (SelahAuth.currentUser == null) {
      return const SelahSourceResult.unavailable(SelahSourceFailure.signedOut);
    }
    try {
      final row = await supabase
          .from('journey_family_reviews')
          .select('id, status, to_stage, deadline_at')
          .eq('match_id', matchId)
          .inFilter('status', ['pending', 'paused'])
          .maybeSingle();
      if (row == null) return const SelahSourceResult.available(null);
      final id = row['id'];
      final status = row['status'];
      final toStage = row['to_stage'];
      final rawDeadline = row['deadline_at'];
      final deadlineAt = switch (rawDeadline) {
        DateTime value => value,
        String value => DateTime.tryParse(value),
        _ => null,
      };
      if (id is! String ||
          id.isEmpty ||
          status is! String ||
          !const {'pending', 'paused'}.contains(status) ||
          toStage is! String ||
          toStage.isEmpty ||
          deadlineAt == null) {
        debugPrint(
          'SELAH: fetchFamilyReviewResult($matchId) returned an invalid row',
        );
        return const SelahSourceResult.unavailable(
          SelahSourceFailure.invalidResponse,
        );
      }
      return SelahSourceResult.available((
        id: id,
        status: status,
        toStage: toStage,
        deadlineAt: deadlineAt,
      ));
    } catch (e) {
      debugPrint('SELAH: fetchFamilyReviewResult($matchId) failed - $e');
      return const SelahSourceResult.unavailable(
        SelahSourceFailure.requestFailed,
      );
    }
  }

  /// Compatibility bridge for older consumers where no review and an
  /// unavailable read both map to null. Truthful surfaces use
  /// [fetchFamilyReviewResult].
  static Future<SelahFamilyReview?> fetchFamilyReview(String matchId) async =>
      (await fetchFamilyReviewResult(matchId)).valueOrNull;

  /// Which of [matchIds] currently have an OPEN Family Review — ONE
  /// query for the whole list.
  ///
  /// [fetchFamilyReview] answers "what is the review" for a single match
  /// and is right for a detail screen. This answers only "is one open"
  /// and is the one a LIST must use: a per-card fetchFamilyReview is N+1,
  /// and on the Shepherd Dashboard N is the number of Seekers a Shepherd
  /// looks after.
  ///
  /// Same definition of open as fetchFamilyReview — 'pending' or 'paused'
  /// — deliberately, so the two can never disagree about whether a
  /// Journey is stalled.
  ///
  /// RLS (20260726190000_family_review_period.sql) grants this to a party
  /// to the match, or to a linked Shepherd with is_main = TRUE. An
  /// ADDITIONAL Shepherd reads nothing here and so never sees the Family
  /// Review override on their list. That is the existing policy, not a
  /// limitation introduced by this method — the detail screen has always
  /// behaved the same way.
  ///
  /// An available empty set means none of the supplied matches has an open
  /// review. Unavailable means that claim could not be established; summary
  /// surfaces must not translate it into "nothing needs you".
  static Future<SelahSourceResult<Set<String>>> fetchOpenReviewMatchIdsResult(
    List<String> matchIds,
  ) async {
    if (matchIds.isEmpty) {
      return const SelahSourceResult.available(<String>{});
    }
    if (!supabaseReady) {
      return const SelahSourceResult.unavailable(SelahSourceFailure.notReady);
    }
    if (SelahAuth.currentUser == null) {
      return const SelahSourceResult.unavailable(SelahSourceFailure.signedOut);
    }
    try {
      final raw = await supabase
          .from('journey_family_reviews')
          .select('match_id')
          .inFilter('match_id', matchIds)
          .inFilter('status', ['pending', 'paused']);
      final result = <String>{};
      for (final row in raw) {
        final matchId = row['match_id'];
        if (matchId is! String || matchId.isEmpty) {
          return const SelahSourceResult.unavailable(
            SelahSourceFailure.invalidResponse,
          );
        }
        result.add(matchId);
      }
      return SelahSourceResult.available(result);
    } catch (e) {
      debugPrint('SELAH: fetchOpenReviewMatchIdsResult failed - $e');
      return const SelahSourceResult.unavailable(
        SelahSourceFailure.requestFailed,
      );
    }
  }

  /// Compatibility bridge for older consumers whose fail-closed behaviour is
  /// to suppress review-derived controls. Truthful summary surfaces use
  /// [fetchOpenReviewMatchIdsResult].
  static Future<Set<String>> fetchOpenReviewMatchIds(
    List<String> matchIds,
  ) async =>
      (await fetchOpenReviewMatchIdsResult(matchIds)).valueOrNull ??
      const <String>{};

  // ── REQUEST NEW JOURNEY — inherited upstream action 159, inherited decision 121 item 8 ──────────────
  //
  // "One person requests; the other decides. Never unilateral, never a
  //  resurrection — a new attempt starts fresh with its own timeline."
  //
  // Replaces restartJourney(), which has thrown since inherited upstream action 154.

  /// The ended matches on which the signed-in user may request a new Journey.
  ///
  /// BATCHED, for the same reason fetchOpenReviewMatchIds is: the Connections
  /// screen draws every ended Journey at once, and a per-row call is the N+1
  /// this project has a written rule against.
  ///
  /// A MATCH'S ABSENCE CARRIES NO REASON. A 6-month cooldown, a permanent
  /// "don't ask again", a block, a Tier-1 exclusion, an active Journey
  /// elsewhere and an already-pending request all look identical from here —
  /// they are simply not in the set. Do not add a variant of this that
  /// reports why; the asymmetry is the design (inherited upstream action 159), not an
  /// oversight to be helpfully corrected later.
  ///
  /// Empty on any failure, which hides the button. Failing closed is right:
  /// showing an option that will be refused is worse than not showing it.
  static Future<Set<String>> fetchMayRequestNewJourneyIds() async {
    if (!SelahReleaseGates.requestNewJourneyEnabled) return const <String>{};
    try {
      final rows =
          await supabase.rpc('selah_may_request_new_journey_ids') as List;
      return rows.map((r) => r as String).toSet();
    } catch (e) {
      debugPrint('SELAH: fetchMayRequestNewJourneyIds failed — $e');
      return {};
    }
  }

  /// The caller's recent Paused/Ended rows where both people are currently
  /// below the three-Active-Journey cap. Absence never explains which person
  /// is unavailable or why; the UI renders only the approved green/red fact.
  static Future<Set<String>> fetchAvailableJourneyReturnIds() async {
    if (!SelahReleaseGates.requestNewJourneyEnabled) return const <String>{};
    try {
      final rows =
          await supabase.rpc('selah_available_journey_return_ids') as List;
      return rows.whereType<String>().toSet();
    } catch (e) {
      debugPrint('SELAH: fetchAvailableJourneyReturnIds failed — $e');
      return const <String>{};
    }
  }

  /// Expires Journey requests past their 30-day window. Expiry counts as a
  /// decline (DR-121 item 8) — same cooldown, same notification, deliberately
  /// indistinguishable.
  ///
  /// LAZY, like [resolveFamilyReviewIfDue]. There is no scheduler in this
  /// database, so a request that lapsed while nobody was looking resolves the
  /// moment either party next opens the screen. Pass null to sweep all.
  static Future<void> expireDueJourneyRequests([String? matchId]) async {
    try {
      await supabase.rpc(
        'selah_expire_due_journey_requests',
        params: {'p_match_id': matchId},
      );
    } catch (e) {
      debugPrint('SELAH: expireDueJourneyRequests($matchId) failed — $e');
    }
  }

  /// Asks the other Seeker to begin a new Journey.
  ///
  /// Returns null on success, or a user-facing message.
  ///
  /// EVERY REFUSAL THE SERVER CAN GIVE MAPS TO THE SAME SENTENCE. `not_available`
  /// covers a cooldown, a permanent refusal, a block and a Tier-1 exclusion,
  /// and it must keep covering all of them — the requester learning WHICH is
  /// the one thing inherited upstream action 159 exists to prevent. If a future error name
  /// needs its own copy, check first that it cannot be inferred backwards.
  static Future<String?> requestNewJourney(String matchId) async {
    if (!SelahReleaseGates.requestNewJourneyEnabled) {
      return SelahReleaseGates.requestNewJourneyUnavailable;
    }
    try {
      await supabase.rpc(
        'request_new_journey',
        params: {'p_match_id': matchId},
      );
      return null;
    } catch (e) {
      final m = e.toString();
      if (m.contains('not_available')) {
        return "You can't begin a new Journey with them right now.";
      }
      if (m.contains('one_active_journey_limit')) {
        return 'One of you is not currently available to reconnect.';
      }
      if (m.contains('journey_capacity_unavailable')) {
        return 'One of you is not currently available to reconnect.';
      }
      if (m.contains('request_already_pending')) {
        return "You've already asked. They haven't answered yet.";
      }
      if (m.contains('cooling_period_active')) {
        return 'This Journey ended less than 24 hours ago.';
      }
      debugPrint('SELAH: requestNewJourney($matchId) failed — $e');
      return "That didn't go through. Please try again.";
    }
  }

  /// Answers a request. [decision] is 'accept', 'decline' or 'decline_never'.
  ///
  /// The two declines differ ONLY in the hold they leave behind — 6 months
  /// versus permanent — and the requester is told the same thing either way.
  static Future<String?> respondToJourneyRequest(
    String requestId,
    String decision,
  ) async {
    if (!SelahReleaseGates.requestNewJourneyEnabled) {
      return SelahReleaseGates.requestNewJourneyUnavailable;
    }
    try {
      await supabase.rpc(
        'respond_to_journey_request',
        params: {'p_request_id': requestId, 'p_decision': decision},
      );
      return null;
    } catch (e) {
      final m = e.toString();
      if (m.contains('request_expired')) return 'That request has expired.';
      if (m.contains('already_answered')) {
        return 'That request was already answered.';
      }
      if (m.contains('one_active_journey_limit')) {
        return 'One of you is not currently available to reconnect.';
      }
      if (m.contains('journey_capacity_unavailable')) {
        return 'One of you is not currently available to reconnect.';
      }
      if (m.contains('not_available')) {
        return "You can't begin a new Journey with them right now.";
      }
      debugPrint(
        'SELAH: respondToJourneyRequest($requestId, $decision) failed — $e',
      );
      return "That didn't go through. Please try again.";
    }
  }

  /// Best-effort lazy timeout check — called from the same 3-second
  /// poll journey_flow_screen.dart already runs for every other stage.
  /// No-op server-side if there's nothing due yet.
  static Future<void> resolveFamilyReviewIfDue(String matchId) async {
    try {
      await supabase.rpc(
        'resolve_family_review_if_due',
        params: {'p_match_id': matchId},
      );
    } catch (e) {
      // Lazy and best-effort by design, but never invisible. A later poll
      // retries; the log distinguishes that delay from a successful no-op.
      debugPrint('SELAH: resolveFamilyReviewIfDue($matchId) failed - $e');
    }
  }

  /// [direction] is 'seeker_to_mentor' or 'mentor_to_seeker'. Plain
  /// insert, same reasoning as submitPhaseAnswer.
  /// inherited decision 167: true when the answer is ON THE SERVER — including the
  /// duplicate-key case, which means a retry of an insert that already
  /// landed. False is a real failure the caller must SAY, not swallow.
  static Future<bool> submitFamilyAnswer(
    String matchId,
    String direction,
    String questionId,
    String answerText,
  ) async {
    final user = SelahAuth.currentUser;
    if (user == null) return false;
    return runSelahTruthfulWrite(
      context: 'submitFamilyAnswer($matchId/$questionId)',
      duplicateIsSuccess: true,
      write: () => supabase.from('journey_family_answers').insert({
        'match_id': matchId,
        'direction': direction,
        'question_id': questionId,
        'answerer_id': user.id,
        'answer_text': answerText,
      }),
    );
  }

  /// {questionId: answerText}. Ordered by created_at ASCENDING so that if
  /// multiple rows ever share a question_id (multiple answerers on
  /// one side), the later insert wins in the returned map.
  ///
  /// The `ascending: true` is load-bearing and was missing until 2026-08-11.
  /// postgrest-dart defaults .order() to DESCENDING, so the map was being
  /// built newest-to-oldest and the last write to win was the OLDEST answer —
  /// the exact opposite of what the sentence above promised. The doc was
  /// right about the intent and the code had never matched it.
  static Future<Map<String, String>> fetchFamilyAnswers(
    String matchId,
    String direction,
  ) async {
    try {
      final rows =
          await supabase
                  .from('journey_family_answers')
                  .select('question_id, answer_text, created_at')
                  .eq('match_id', matchId)
                  .eq('direction', direction)
                  .order('created_at', ascending: true)
              as List;

      final result = <String, String>{};
      for (final r in rows) {
        final map = r as Map<String, dynamic>;
        result[map['question_id'] as String] = map['answer_text'] as String;
      }
      return result;
    } catch (e) {
      debugPrint('SELAH: fetchFamilyAnswers($matchId/$direction) failed - $e');
      return {};
    }
  }

  /// Applies one compare-and-swap Pause decision through the authoritative
  /// database state machine. The expected version makes a stale decision page
  /// fail rather than overwrite an answer that has already landed.
  static Future<SelahJourneyPauseState> transitionPause({
    required String matchId,
    required SelahPauseAction action,
    required int expectedVersion,
  }) async {
    try {
      if (SelahIdentityVerificationService.enforceExistingAccountGate &&
          action == SelahPauseAction.agreeResume) {
        final verification =
            await SelahIdentityVerificationService.fetchMyState();
        if (verification?.allowsActiveJourney != true) {
          throw PauseTransitionNotAllowedException();
        }
      }
      final raw = await supabase.rpc(
        'transition_journey_pause',
        params: {
          'p_match_id': matchId,
          'p_action': action.storageValue,
          'p_expected_version': expectedVersion,
        },
      );
      final row = raw is List
          ? Map<String, dynamic>.from(raw.single as Map)
          : Map<String, dynamic>.from(raw as Map);
      return SelahJourneyPauseState.fromStorage(
        phase: row['pause_state'] as String?,
        initiatedBy: row['pause_initiated_by'] as String?,
        requestedBy: row['pause_requested_by'] as String?,
        requestedAt: row['pause_requested_at'],
        deadlineAt: row['pause_deadline_at'],
        version: row['pause_version'],
      );
    } catch (e) {
      final message = e.toString();
      if (message.contains('stale_pause_decision')) {
        throw PauseTransitionStaleException();
      }
      if (message.contains('pause_transition_not_allowed')) {
        throw PauseTransitionNotAllowedException();
      }
      if (message.contains('paused_capacity_conflict')) {
        throw PauseCapacityConflictException();
      }
      if (message.contains('self_in_active_journey')) {
        throw SelfInActiveJourneyException();
      }
      if (message.contains('other_party_in_active_journey')) {
        throw OtherPartyInActiveJourneyException();
      }
      if (message.contains('not_eligible_to_continue')) {
        throw NotEligibleToContinueException();
      }
      debugPrint(
        'SELAH: transitionPause($matchId/${action.storageValue}) failed - $e',
      );
      rethrow;
    }
  }

  /// Preflight for the decision page. The RPC still repeats this check under
  /// lock because capacity can change between paint and tap.
  static Future<bool?> fetchPauseCapacity(String matchId) async {
    try {
      final raw = await supabase.rpc(
        'selah_pause_capacity_status',
        params: {'p_match_id': matchId},
      );
      final row = raw is List
          ? Map<String, dynamic>.from(raw.single as Map)
          : Map<String, dynamic>.from(raw as Map);
      return row['can_pause'] as bool?;
    } catch (e) {
      debugPrint('SELAH: fetchPauseCapacity($matchId) failed - $e');
      return null;
    }
  }

  /// inherited decision 167: true only when the server accepted the end. A failed
  /// end must not play the ended moment — the caller gates on this.
  static Future<bool> endJourney(String matchId) async {
    try {
      await supabase.rpc('end_journey', params: {'p_match_id': matchId});
      return true;
    } catch (e) {
      debugPrint('SELAH endJourney($matchId) failed: $e');
      return false;
    }
  }

  /// Plain re-fetch of one match's current status/stage/suspension —
  /// meant to be driven by a Timer.periodic (e.g. every 3 seconds)
  /// while the UI waits on the other party, rather than a Realtime
  /// channel subscription (out of scope for this pass). Null on any
  /// failure or if the match/profile can no longer be found.
  static Future<JourneyMatch?> refetchOne(
    String matchId,
    String otherUserId,
  ) async {
    final user = SelahAuth.currentUser;
    if (user == null) return null;
    try {
      final matchRow = await supabase
          .from('matches')
          .select(
            'id, status, journey_stage, suspended_by, suspended_at, ended_at',
          )
          .eq('id', matchId)
          .maybeSingle();
      if (matchRow == null) return null;
      final pauseByMatchId = await _fetchPauseStates([matchId]);

      final profileRow = await supabase
          .from('profiles')
          .select(
            'id, first_name, location_text, gender, profile_photos(storage_path, display_order)',
          )
          .eq('id', otherUserId)
          .maybeSingle();
      if (profileRow == null) return null;

      // Raw date_of_birth is no longer selectable by the client — see
      // 20260726120000_hide_raw_dob_expose_age.sql.
      final ages = await _fetchAges([otherUserId]);
      final busyByMatchId = await _fetchBusyFlags([matchId]);

      final photosRaw = List<Map<String, dynamic>>.from(
        (profileRow['profile_photos'] as List?) ?? const [],
      );
      photosRaw.sort(
        (a, b) =>
            (a['display_order'] as int).compareTo(b['display_order'] as int),
      );
      final photos = await SelahPhotoService.signedUrlsFor(
        photosRaw.map((p) => p['storage_path'] as String).toList(),
      );

      final profile = SeekerProfile(
        id: profileRow['id'] as String,
        firstName: profileRow['first_name'] as String,
        age: ages[otherUserId] ?? 0,
        city: (profileRow['location_text'] as String?) ?? '—',
        photos: photos.isEmpty
            ? ['https://picsum.photos/seed/${profileRow['id']}/700/1000']
            : photos,
        gender: profileRow['gender'] as String,
      );

      return JourneyMatch(
        matchId: matchRow['id'] as String,
        profile: profile,
        status: matchRow['status'] as String,
        journeyStage: matchRow['journey_stage'] as String?,
        pause: pauseByMatchId?[matchId] ?? _pauseFromRow(matchRow),
        suspendedAt: matchRow['suspended_at'] == null
            ? null
            : DateTime.parse(matchRow['suspended_at'] as String),
        endedAt: matchRow['ended_at'] == null
            ? null
            : DateTime.parse(matchRow['ended_at'] as String),
        inAnotherJourney: busyByMatchId[matchId] ?? false,
      );
    } catch (e) {
      debugPrint('SELAH: refetchOne($matchId) failed - $e');
      return null;
    }
  }

  /// RETIRED 2026-08-06 — inherited upstream action 154, inherited decision 121. Always throws.
  ///
  /// `restart_journey()` reopened an ended Journey on ONE party's request.
  /// It deleted six tables of history and cleared `ended_at` before doing
  /// so, meaning someone who ended a Journey because they felt unsafe could
  /// be returned to it without consent and with no record that it had ever
  /// ended. The server now refuses, and the UI no longer offers it.
  ///
  /// Kept rather than deleted so a caller reappearing during the Journey
  /// migration fails loudly here, with the reason, instead of getting a
  /// bare Postgres error from the RPC.
  ///
  /// Replaced by Request New Journey — V3 §9, inherited upstream action 159.
  @Deprecated(
    'Use Request New Journey (inherited upstream action 159). Restart is not permitted: '
    'a Journey cannot be reopened without the other person agreeing.',
  )
  static Future<void> restartJourney(String matchId) async {
    throw StateError(
      'restart_journey is retired (inherited upstream action 154). Starting again requires the '
      'other party to accept — see Request New Journey, inherited upstream action 159.',
    );
  }

  /// DEV ONLY — jump an Active Journey straight to any stage.
  ///
  /// Founder request 2026-08-10, so a section can be reached for testing
  /// without walking the whole Journey to get there.
  ///
  /// ⚠️ THIS SKIPS EVERY GATE: the Pre-Journey Ritual, the Shepherd Gate and
  /// the 48-hour Family Review Period. Those three are what make SELAH a
  /// marriage process rather than a chat app.
  ///
  /// ⚠️ THE GUARD IS SERVER-SIDE, in `selah_dev_set_journey_stage`, which reads
  /// `auth.users.email` and refuses anything that is not `@selah.test`. Hiding
  /// the control in Dart is presentation, not protection — contradiction-audit
  /// §3.1 is an entire section on this project trusting client-side gates. If
  /// you are tempted to "just check it in the widget", that finding is why the
  /// real check is not there.
  ///
  /// ⚠️ DROP BEFORE PUBLIC LAUNCH, alongside `mock_purchase_mentor_premium()`
  /// and `mock_set_mentor_plan()` — engineering audit item #20. It rests on the
  /// `@selah.test` guard, which is inherited upstream action 171 and still open.
  ///
  /// Throws [DevOnlyException] when the signed-in account is not a seeded test
  /// account, so the caller can say so rather than swallowing it.
  static Future<String> devSetStage(String matchId, String stage) async {
    try {
      final res = await supabase.rpc(
        'selah_dev_set_journey_stage',
        params: {'p_match_id': matchId, 'p_stage': stage},
      );
      return res as String;
    } catch (e) {
      // Matches this file's RPC convention: string-match the server's error name rather than
      // catching a typed PostgrestException, which is not imported here.
      if (e.toString().contains('dev_only')) throw const DevOnlyException();
      if (e.toString().contains('journey_not_active')) {
        throw const JourneyNotActiveException();
      }
      debugPrint('SELAH: devSetStage($matchId, $stage) failed — $e');
      rethrow;
    }
  }

  /// DEV ONLY — set the OTHER party's Compatibility Reveal flag.
  ///
  /// Founder request 2026-08-10. The reveal is a two-sided gate and one person
  /// testing alone can only ever see one side of it.
  ///
  /// ⚠️ Server-guarded on `@selah.test`, like [devSetStage]. It sets the
  /// COUNTERPART's column, never the caller's — verified both ways round
  /// against the live database on 2026-08-10.
  ///
  /// ⚠️ It deliberately does NOT compute the score. Scoring belongs to the
  /// real reveal path, so the correct test is: set the counterpart revealed,
  /// then press Reveal and watch the real code run. A dev function that also
  /// scored would be testing itself.
  ///
  /// ⚠️ DROP BEFORE PUBLIC LAUNCH — inherited upstream action 184, which now covers eight
  /// functions rather than seven.
  static Future<bool> devSetCounterpartReveal(
    String matchId,
    bool revealed,
  ) async {
    try {
      final res = await supabase.rpc(
        'selah_dev_set_counterpart_reveal',
        params: {'p_match_id': matchId, 'p_revealed': revealed},
      );
      return res as bool;
    } catch (e) {
      if (e.toString().contains('dev_only')) throw const DevOnlyException();
      debugPrint(
        'SELAH: devSetCounterpartReveal($matchId, $revealed) failed — $e',
      );
      rethrow;
    }
  }

  /// Whether the OTHER party has revealed. Read back so the dev toggle shows
  /// the real state rather than whatever it last set — the two diverge the
  /// moment the other account reveals for real, and a toggle that shows its
  /// own last write is a toggle that lies.
  static Future<SelahCompatibilityReadResult> fetchCounterpartRevealed(
    String matchId,
  ) => fetchCompatibility(matchId);

  // ── PROFILE UNLOCK+ EARLY SIGHT — inherited decision 135, closing inherited upstream action 152 ─────

  /// The compatibility score for a Plus holder, before the other Seeker has
  /// revealed. Null if the caller has no Plus unlock on them, or on failure.
  ///
  /// inherited decision 135, Founder-approved 2026-08-10. It resolved a real conflict:
  /// the Reveal is built as a consent gate — "neither of you sees it until you
  /// both choose" — and Unlock+ sells that number to one person. Both could
  /// not be true. The Founder chose the purchase.
  ///
  /// THE LINE THIS DOES NOT CROSS: the result is bought, the relationship is
  /// not. It sets no reveal flag, advances no stage, and tells the other
  /// person nothing — asserted server-side, checks 4–6 of the DR-135 run.
  /// If you are tempted to have this also mark the caller as revealed
  /// "since they've seen it anyway", that is the consent gate, and it is
  /// theirs to open.
  ///
  /// The entitlement is checked SERVER-SIDE, in selah_compatibility_for_plus.
  /// Contradiction-audit §3.1 is a whole section on this project gating
  /// entitlements in Dart and believing it.
  static Future<double?> fetchCompatibilityForPlus(String matchId) async {
    try {
      final res = await supabase.rpc(
        'selah_compatibility_for_plus',
        params: {'p_match_id': matchId},
      );
      if (res == null) return null;
      return (res as num).toDouble();
    } catch (e) {
      // plus_required is the ORDINARY case, not a failure: most people have
      // not bought Plus. Returning null quietly is correct; logging it would
      // fill the console with the normal path.
      if (e.toString().contains('plus_required')) return null;
      debugPrint('SELAH: fetchCompatibilityForPlus($matchId) failed — $e');
      return null;
    }
  }

  /// DEV ONLY — simulate buying (or refunding) Compatibility Unlock+.
  ///
  /// ⚠️ NINTH consumer of the `@selah.test` guard. inherited upstream action 184 lists them all;
  /// it said seven this morning and eight by lunch. DROP BEFORE LAUNCH.
  ///
  /// Removing only ever deletes the simulated `paid_plus_single` row, never a
  /// real unlock of another type — a dev tool that deleted a `paid_single`
  /// would be destroying a record of money.
  /// DEV ONLY. Forces a Compatibility Reveal RESULT — both flags set and a
  /// score of your choosing — so the mutual-reveal screen can be seen at both
  /// ends of the scale.
  ///
  /// WHY THIS EXISTS RATHER THAN REAL DATA. After the 2026-08-10 backfills
  /// every seeded profile scores 77-100 against every other, because they all
  /// carry similar synthetic answers. A low score is not reachable by playing
  /// the product properly, and testing how a bad result READS matters as much
  /// as testing a good one.
  ///
  /// TENTH dev RPC — inherited upstream action 184 holds the drop list.
  static Future<double?> devSetCompatibility(
    String matchId,
    double score,
  ) async {
    try {
      final v = await supabase.rpc(
        'selah_dev_set_compatibility',
        params: {'p_match_id': matchId, 'p_score': score},
      );
      return (v as num?)?.toDouble();
    } catch (e) {
      debugPrint('SELAH: devSetCompatibility failed — $e');
      rethrow;
    }
  }

  /// The signed-in Seeker's OWN private ratings for a phase — questionId to
  /// 'reassured' | 'discuss_further' | 'concerns'.
  ///
  /// ADDED 2026-08-11 for the SELAH intelligence layer, which has nothing to
  /// say without them. Scoped to the caller on purpose and not by accident of
  /// RLS: "Your ratings are private and used only to guide your journey"
  /// (PRE-JOURNEY RITUAL/Summary.md) is a promise made on screen every phase,
  /// so this must never grow an `otherUserId` parameter.
  static Future<Map<String, String>> fetchMyRatings(
    String matchId,
    int phase,
  ) async {
    final user = SelahAuth.currentUser;
    if (user == null) return {};
    try {
      final rows =
          await supabase
                  .from('journey_phase_ratings')
                  .select('question_id, rating')
                  .eq('match_id', matchId)
                  .eq('phase', phase)
                  .eq('rater_id', user.id)
              as List;
      return {
        for (final r in rows)
          (r as Map<String, dynamic>)['question_id'] as String:
              r['rating'] as String,
      };
    } catch (e) {
      debugPrint('SELAH: fetchMyRatings($matchId, $phase) failed - $e');
      return {};
    }
  }

  /// All of this Seeker's private ratings across phases 1-3, merged.
  /// Open Conversation is where the whole Journey is finally one thing, so
  /// its topic suggestions read from all of it rather than the last phase.
  static Future<Map<String, String>> fetchAllMyRatings(String matchId) async {
    final startingUser = SelahAuth.currentUser;
    if (startingUser == null) return {};
    final startingGeneration = SelahAccountState.generation;
    bool isCurrent() =>
        SelahAuth.currentUser?.id == startingUser.id &&
        SelahAccountState.isCurrent(startingUser.id, startingGeneration);

    final out = <String, String>{};
    for (final phase in const [1, 2, 3]) {
      if (!isCurrent()) return {};
      final ratings = await fetchMyRatings(matchId, phase);
      if (!isCurrent()) return {};
      out.addAll(ratings);
    }
    return out;
  }

  /// DEV ONLY. Completes the OTHER party's half of whatever stage the Journey
  /// is standing on, so the flow can be walked alone.
  ///
  /// Every stage from the Greeting onwards is a mutual act by design, which
  /// means a single tester stops at the second stage and the remaining six
  /// have never been seen running. This ends the wait and nothing else: it
  /// does not advance the stage, does not skip one, and does not touch the
  /// caller's own half. The server decides what "their half" means from the
  /// current stage - see selah_dev_counterpart_complete.
  ///
  /// [questionIds] is the current stage's question set, sent because the
  /// bank lives in data/journey_questions.dart and the database has never
  /// been told about it. Empty for the stages that have no questions.
  ///
  /// ELEVENTH dev RPC - inherited upstream action 184 holds the drop list.
  static Future<String> devCounterpartComplete(
    String matchId, {
    List<String> questionIds = const [],
  }) async {
    try {
      final res = await supabase.rpc(
        'selah_dev_counterpart_complete',
        params: {'p_match_id': matchId, 'p_question_ids': questionIds},
      );
      return res?.toString() ?? 'Done.';
    } catch (e) {
      if (e.toString().contains('dev_only')) throw const DevOnlyException();
      debugPrint('SELAH: devCounterpartComplete($matchId) failed - $e');
      rethrow;
    }
  }

  /// DEV ONLY, DESTRUCTIVE. Rewinds ONE Journey to Compatibility Reveal and
  /// clears everything the pair did inside it — answers, ratings, greetings,
  /// reveals, checkpoints, family answers, reviews, messages, milestones.
  ///
  /// Founder, 2026-08-11: "the reset button in toggle doesn't reset the
  /// journey stage.. say if i wanna start again." Neither Reset was ever
  /// going to: one clears the panel's own toggles and never touches the
  /// server, and the red account reset deliberately leaves matches alone
  /// because they are expensive to rebuild. This is the third thing, named
  /// for what it does.
  ///
  /// ⚠️ NOT [restartJourney]. Starting again for real needs both people to
  /// agree and keeps all history (inherited upstream action 154 / inherited upstream action 159). This deletes
  /// it, and must never be reachable from a member-facing screen.
  ///
  /// TWELFTH dev RPC - inherited upstream action 184 holds the drop list.
  /// [matchId] null rewinds EVERY Journey on this account — which is what the
  /// dev panel's Reset needs, since it runs from HomeShell with no Journey in
  /// front of it.
  static Future<String> devRewindJourney({String? matchId}) async {
    try {
      final res = await supabase.rpc(
        'selah_dev_rewind_journey',
        params: {'p_match_id': matchId},
      );
      return res?.toString() ?? 'Journey rewound.';
    } catch (e) {
      if (e.toString().contains('dev_only')) throw const DevOnlyException();
      debugPrint('SELAH: devRewindJourney($matchId) failed - $e');
      rethrow;
    }
  }

  static Future<bool> devSetPlusUnlock(String otherId, bool has) async {
    try {
      final res = await supabase.rpc(
        'selah_dev_set_plus_unlock',
        params: {'p_other_id': otherId, 'p_has': has},
      );
      return res == true;
    } catch (e) {
      if (e.toString().contains('dev_only')) throw const DevOnlyException();
      debugPrint('SELAH: devSetPlusUnlock($otherId, $has) failed — $e');
      rethrow;
    }
  }

  /// Whether the signed-in user holds a Plus unlock on [otherId]. Read back
  /// from the server so the dev switch shows the real state rather than its
  /// own last write.
  static Future<bool> fetchHasPlusUnlock(String otherId) async {
    final user = SelahAuth.currentUser;
    if (user == null) return false;
    try {
      final rows =
          await supabase
                  .from('profile_unlocks')
                  .select('unlock_type')
                  .eq('unlocker_id', user.id)
                  .eq('unlocked_id', otherId)
              as List;
      return rows.any(
        (r) => (r as Map<String, dynamic>)['unlock_type'].toString().startsWith(
          'paid_plus',
        ),
      );
    } catch (e) {
      debugPrint('SELAH: fetchHasPlusUnlock($otherId) failed — $e');
      return false;
    }
  }
}

/// The signed-in account is not a seeded `@selah.test` account, so a developer
/// tool refused it. Raised by the server, never inferred on the client.
class DevOnlyException implements Exception {
  const DevOnlyException();
  @override
  String toString() =>
      'Stage jumping is limited to seeded @selah.test accounts.';
}

/// A stage jump was attempted on a Journey that is not active — an ended or
/// potential Journey has no stages to move between.
class JourneyNotActiveException implements Exception {
  const JourneyNotActiveException();
  @override
  String toString() => 'Only an Active Journey has stages to move between.';
}
