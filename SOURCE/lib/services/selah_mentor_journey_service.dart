// Shepherd-side Journey/Timeline/Conversation reads. Product presentation is
// split by membership in mentor_journey_detail_screen.dart: Shepherd Free sees
// Journey and Timeline; SELAH One — Shepherd may also see the current read-only
// Conversation. Backed by 20260726130000_mentor_journey_visibility.sql,
// which extends matches/conversations/messages/timelines/
// timeline_milestones RLS to a Mentor with an 'active' mentor_links row,
// scoped to matches that have left 'potential' status (an Active
// Journey exists) — Browse-stage activity stays out of scope
// entirely, per that migration's own header comment and the separate
// DR draft covering the wider visibility conflict.
//
// Read-only throughout: no INSERT/UPDATE grants were added for a Shepherd
// on any of these tables (except journey_family_answers, which
// already permitted Shepherd writes before this — see
// MentorFamilyStageScreen).
//
// 2026-07-26 (#31): mentorReviewDecision()/myReviewDecision()/
// reopenFamilyReview() below add the ONE real write capability a Shepherd
// has beyond journey_family_answers — Continue/Pause during a Family
// Review Period (MENTOR_ARCHITECTURE_CURRENT_VERSION_V6.md's "Family
// Review Period" section). Enforced server-side by mentor_review_
// decision()/reopen_family_review() (20260726190000_family_review_
// period.sql), which check the caller is an active main Mentor for one
// of the two Seekers on the match — not by anything client-side here.

import '../main.dart';
import '../data/selah_journey_pause_state.dart';
import '../models/seeker_profile.dart';
import 'package:flutter/foundation.dart' show debugPrint;

import 'selah_auth.dart';
import 'selah_match_service.dart';
import 'selah_mentor_link_service.dart';

class MentorJourneyView {
  /// Current attempt identity when this row came from the caller-scoped
  /// participation view. It is never rendered; the workspace uses it only to
  /// join a server-returned summary row to the separately-authorised current
  /// Journey route.
  final String? attemptId;
  final String matchId;
  final String linkedSeekerId;
  final String linkedSeekerName;

  /// The counterpart, as the COUNTERPART CARD allows — first name and age
  /// only. `city` is '—' and `photos` is empty by design, not by failure.
  ///
  /// 2026-08-08: this used to be a full profile read straight off
  /// `profiles`. A Shepherd could see the other family's Seeker, their
  /// Shepherds, and the co-Shepherds on their own side — gender-blind,
  /// mutually, for everyone attached to the Journey. Clause 3 no longer
  /// grants Shepherds anything, so this is now built from
  /// selah_counterpart_card().
  final SeekerProfile partner;

  /// The other family's MAIN Shepherd, from the same card. Null when they
  /// have no Main Shepherd — a real state worth showing, not an error.
  /// Additional Shepherds never receive a card at all.
  final String? counterpartShepherdName;
  final String? counterpartShepherdSurname;

  final String
  status; // 'active' | 'paused' | 'ended' (never 'potential' — out of scope)
  final String? journeyStage;
  final SelahJourneyPauseState pause;

  /// A dev-panel stand-in, not a row. ADDED 2026-08-13 with the Shepherd
  /// dev panel (inherited decision 152), and it carries real weight rather than
  /// being a label: [matchId] on a stand-in is `dev-wj0`, not a uuid, so
  /// every server call made against it — fetchTimeline, fetchMessages,
  /// mentor_review_decision — is handed something that is not an id. The
  /// Seeker side learned this the expensive way, where a fabricated
  /// Active Journey made the Reveal button silently do nothing for a day
  /// (see JourneyMatch.isMock and composeJourneys' own note).
  ///
  /// Screens must branch on this BEFORE calling the server, not after.
  final bool isMock;

  const MentorJourneyView({
    this.attemptId,
    required this.matchId,
    required this.linkedSeekerId,
    required this.linkedSeekerName,
    required this.partner,
    required this.counterpartShepherdName,
    required this.counterpartShepherdSurname,
    required this.status,
    required this.journeyStage,
    this.pause = SelahJourneyPauseState.active,
    this.isMock = false,
  });

  bool get isSuspended => pause.isPaused;
  bool get isJourneyLocked => pause.isLocked;
  bool get isPauseDecisionPending => pause.isPending;
}

/// One row returned by `selah_attempt_summary_for_shepherd`.
///
/// No field is inferred from another. In particular [ended] stays the exact
/// server boolean and a null [endedAt] remains null so the UI can say that the
/// end date was not recorded rather than inventing one.
final class ShepherdAttemptSummary {
  final String attemptId;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final bool ended;

  const ShepherdAttemptSummary({
    required this.attemptId,
    required this.startedAt,
    required this.endedAt,
    required this.ended,
  });

  static ShepherdAttemptSummary? fromRow(Map<String, dynamic> row) {
    final rawAttemptId = row['attempt_id'];
    final rawStartedAt = row['started_at'];
    final rawEndedAt = row['ended_at'];
    final rawEnded = row['ended'];
    final startedAt = _dateOrNull(rawStartedAt);
    final endedAt = _dateOrNull(rawEndedAt);
    if (rawAttemptId is! String ||
        rawAttemptId.isEmpty ||
        rawEnded is! bool ||
        (rawStartedAt != null && startedAt == null) ||
        (rawEndedAt != null && endedAt == null)) {
      return null;
    }
    return ShepherdAttemptSummary(
      attemptId: rawAttemptId,
      startedAt: startedAt?.toLocal(),
      endedAt: endedAt?.toLocal(),
      ended: rawEnded,
    );
  }
}

/// Authoritative current context used by the ruled Shepherd roster.
///
/// [journeys] contains rich current-context rows authorised for this caller:
/// every Main Shepherdship and each exact active Journey to which a Seeker has
/// assigned an Additional Shepherd. Main-only decisions remain separately
/// gated by their owning server functions.
final class ShepherdSeekerRosterContext {
  final List<MentorJourneyView> journeys;
  final Set<String> openReviewMatchIds;
  final Map<String, DateTime> waitingSinceByMatchId;

  const ShepherdSeekerRosterContext({
    this.journeys = const [],
    this.openReviewMatchIds = const {},
    this.waitingSinceByMatchId = const {},
  });
}

DateTime? _dateOrNull(Object? value) => switch (value) {
  DateTime date => date,
  String text => DateTime.tryParse(text),
  _ => null,
};

class SelahMentorJourneyService {
  SelahMentorJourneyService._();

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

  /// Current Journey context for the Shepherd-side Seeker roster.
  ///
  /// The caller-scoped participation view is the authority: Main rows are
  /// always present; Additional rows exist only while that Seeker has included
  /// this Shepherd in the active Journey. Main-only review actions remain
  /// independently protected and are not inferred from participation.
  static Future<SelahSourceResult<ShepherdSeekerRosterContext>>
  fetchRosterContextResult(List<MentorLinkedPerson> linkedPeople) async {
    if (!supabaseReady) {
      return const SelahSourceResult.unavailable(SelahSourceFailure.notReady);
    }
    if (SelahAuth.currentUser == null) {
      return const SelahSourceResult.unavailable(SelahSourceFailure.signedOut);
    }
    if (linkedPeople.isEmpty) {
      return const SelahSourceResult.available(ShepherdSeekerRosterContext());
    }
    final linkedById = {for (final person in linkedPeople) person.id: person};

    try {
      final rawParticipation =
          await supabase
                  .from('selah_my_attempt_participation')
                  .select('attempt_id, match_id, role, is_main, attempt_status')
                  .eq('role', 'shepherd')
                  .eq('attempt_status', 'active')
              as List;

      final attemptByMatch = <String, String>{};
      final mainRoleByMatch = <String, bool>{};
      for (final raw in rawParticipation) {
        if (raw is! Map) {
          return const SelahSourceResult.unavailable(
            SelahSourceFailure.invalidResponse,
          );
        }
        final row = Map<String, dynamic>.from(raw);
        final attemptId = row['attempt_id'];
        final matchId = row['match_id'];
        if (attemptId is! String ||
            attemptId.isEmpty ||
            matchId is! String ||
            matchId.isEmpty ||
            row['role'] != 'shepherd' ||
            row['is_main'] is! bool ||
            row['attempt_status'] != 'active') {
          return const SelahSourceResult.unavailable(
            SelahSourceFailure.invalidResponse,
          );
        }
        final previous = attemptByMatch[matchId];
        if (previous != null && previous != attemptId) {
          return const SelahSourceResult.unavailable(
            SelahSourceFailure.invalidResponse,
          );
        }
        attemptByMatch[matchId] = attemptId;
        mainRoleByMatch[matchId] = row['is_main'] as bool;
      }
      if (attemptByMatch.isEmpty) {
        return const SelahSourceResult.available(ShepherdSeekerRosterContext());
      }

      final rawMatches =
          await supabase
                  .from('matches')
                  .select(
                    'id, seeker_a_id, seeker_b_id, status, journey_stage, '
                    'suspended_by, pause_state, pause_initiated_by, '
                    'pause_requested_by, pause_requested_at, '
                    'pause_deadline_at, pause_version',
                  )
                  .inFilter('id', attemptByMatch.keys.toList())
              as List;
      final matchRows = <String, Map<String, dynamic>>{};
      for (final raw in rawMatches) {
        if (raw is! Map) {
          return const SelahSourceResult.unavailable(
            SelahSourceFailure.invalidResponse,
          );
        }
        final row = Map<String, dynamic>.from(raw);
        final id = row['id'];
        final seekerA = row['seeker_a_id'];
        final seekerB = row['seeker_b_id'];
        final status = row['status'];
        final stage = row['journey_stage'];
        if (id is! String ||
            id.isEmpty ||
            seekerA is! String ||
            seekerA.isEmpty ||
            seekerB is! String ||
            seekerB.isEmpty ||
            status is! String ||
            (stage != null && stage is! String) ||
            !attemptByMatch.containsKey(id)) {
          return const SelahSourceResult.unavailable(
            SelahSourceFailure.invalidResponse,
          );
        }
        matchRows[id] = row;
      }
      if (matchRows.length != attemptByMatch.length) {
        return const SelahSourceResult.unavailable(
          SelahSourceFailure.invalidResponse,
        );
      }

      final journeys = <MentorJourneyView>[];
      for (final matchId in attemptByMatch.keys) {
        final row = matchRows[matchId]!;
        final seekerA = row['seeker_a_id'] as String;
        final seekerB = row['seeker_b_id'] as String;
        final expectedMain = mainRoleByMatch[matchId]!;
        final candidates = [
          if (linkedById[seekerA]?.isMain == expectedMain) seekerA,
          if (linkedById[seekerB]?.isMain == expectedMain) seekerB,
        ];
        if (candidates.length != 1) {
          return const SelahSourceResult.unavailable(
            SelahSourceFailure.invalidResponse,
          );
        }
        final linkedSeekerId = candidates.single;
        final linked = linkedById[linkedSeekerId]!;
        final partnerId = linkedSeekerId == seekerA ? seekerB : seekerA;
        final cardResult = await _fetchCounterpartCardResult(
          matchId,
          partnerId,
        );
        if (cardResult.isUnavailable) {
          return SelahSourceResult.unavailable(cardResult.failure!);
        }
        final card = cardResult.valueOrNull;
        if (card == null) continue;
        journeys.add(
          MentorJourneyView(
            attemptId: attemptByMatch[matchId],
            matchId: matchId,
            linkedSeekerId: linkedSeekerId,
            linkedSeekerName: linked.firstName,
            partner: card.partner,
            counterpartShepherdName: card.shepherdFirstName,
            counterpartShepherdSurname: card.shepherdSurnameLine,
            status: row['status'] as String,
            journeyStage: row['journey_stage'] as String?,
            pause: _pauseFromRow(row),
          ),
        );
      }

      final liveMatchIds = journeys.map((journey) => journey.matchId).toSet();
      final openReviews = <String>{};
      final waitingSince = <String, DateTime>{};
      if (liveMatchIds.isNotEmpty) {
        final rawReviews =
            await supabase
                    .from('journey_family_reviews')
                    .select('match_id, opened_at')
                    .inFilter('match_id', liveMatchIds.toList())
                    .inFilter('status', ['pending', 'paused'])
                as List;
        for (final raw in rawReviews) {
          if (raw is! Map) {
            return const SelahSourceResult.unavailable(
              SelahSourceFailure.invalidResponse,
            );
          }
          final row = Map<String, dynamic>.from(raw);
          final matchId = row['match_id'];
          final openedAt = _dateOrNull(row['opened_at']);
          if (matchId is! String ||
              !liveMatchIds.contains(matchId) ||
              openedAt == null) {
            return const SelahSourceResult.unavailable(
              SelahSourceFailure.invalidResponse,
            );
          }
          openReviews.add(matchId);
          final local = openedAt.toLocal();
          final previous = waitingSince[matchId];
          if (previous == null || local.isBefore(previous)) {
            waitingSince[matchId] = local;
          }
        }
      }

      return SelahSourceResult.available(
        ShepherdSeekerRosterContext(
          journeys: journeys,
          openReviewMatchIds: openReviews,
          waitingSinceByMatchId: waitingSince,
        ),
      );
    } catch (e) {
      debugPrint('SELAH: Shepherd roster context failed — $e');
      return const SelahSourceResult.unavailable(
        SelahSourceFailure.requestFailed,
      );
    }
  }

  /// The exact four-field inherited decision 225 projection for one linked Seeker.
  /// Returned order and row count are preserved; the client neither filters
  /// nor supplements the server result.
  static Future<SelahSourceResult<List<ShepherdAttemptSummary>>>
  fetchAttemptSummariesForSeeker(String seekerId) async {
    if (!supabaseReady) {
      return const SelahSourceResult.unavailable(SelahSourceFailure.notReady);
    }
    if (SelahAuth.currentUser == null) {
      return const SelahSourceResult.unavailable(SelahSourceFailure.signedOut);
    }
    if (seekerId.isEmpty) {
      return const SelahSourceResult.unavailable(
        SelahSourceFailure.invalidResponse,
      );
    }
    try {
      final raw = await supabase.rpc(
        'selah_attempt_summary_for_shepherd',
        params: {'p_seeker': seekerId},
      );
      if (raw is! List) {
        return const SelahSourceResult.unavailable(
          SelahSourceFailure.invalidResponse,
        );
      }
      final summaries = <ShepherdAttemptSummary>[];
      for (final item in raw) {
        if (item is! Map) {
          return const SelahSourceResult.unavailable(
            SelahSourceFailure.invalidResponse,
          );
        }
        final summary = ShepherdAttemptSummary.fromRow(
          Map<String, dynamic>.from(item),
        );
        if (summary == null) {
          return const SelahSourceResult.unavailable(
            SelahSourceFailure.invalidResponse,
          );
        }
        summaries.add(summary);
      }
      return SelahSourceResult.available(summaries);
    } catch (e) {
      debugPrint('SELAH: Shepherd Journey summary for $seekerId failed — $e');
      return const SelahSourceResult.unavailable(
        SelahSourceFailure.requestFailed,
      );
    }
  }

  /// Real Journeys (status <> 'potential') for every Seeker linked to
  /// the signed-in Mentor. Empty if not signed in, not a Mentor, no linked
  /// Seekers, or no real Journey yet for any of them — and NULL when the
  /// fetch FAILED (inherited decision 171, applying inherited decision 167's rule to the
  /// Shepherd's front door): the Dashboard shows an error with Try
  /// again, never an invite CTA over a network failure.
  static Future<List<MentorJourneyView>?> fetchLinkedJourneys() async {
    final user = SelahAuth.currentUser;
    if (user == null) return [];

    try {
      final linked = await SelahMentorLinkService.fetchLinkedPeople(
        asMentor: true,
      );
      if (linked.isEmpty) return [];
      final linkedIds = {for (final p in linked) p.id: p.firstName};

      // RLS (20260726130000_mentor_journey_visibility.sql) already
      // restricts this to matches where the signed-in Mentor has an
      // active link to one of the two seekers, and status <>
      // 'potential' — the explicit filters below are defensive, not
      // load-bearing.
      List rows;
      try {
        rows =
            await supabase
                    .from('matches')
                    .select(
                      'id, seeker_a_id, seeker_b_id, status, journey_stage, '
                      'suspended_by, pause_state',
                    )
                    .neq('status', 'potential')
                as List;
      } catch (e) {
        final message = e.toString().toLowerCase();
        final migrationNotLive =
            message.contains('pause_state') &&
            (message.contains('42703') ||
                message.contains('pgrst204') ||
                message.contains('does not exist') ||
                message.contains('could not find'));
        if (!migrationNotLive) rethrow;
        debugPrint(
          'SELAH: Shepherd Pause decision columns not live yet; using the '
          'neutral legacy bridge - $e',
        );
        rows =
            await supabase
                    .from('matches')
                    .select(
                      'id, seeker_a_id, seeker_b_id, status, journey_stage, suspended_by',
                    )
                    .neq('status', 'potential')
                as List;
      }
      if (rows.isEmpty) return [];

      final results = <MentorJourneyView>[];
      for (final row in rows) {
        final map = row as Map<String, dynamic>;
        final a = map['seeker_a_id'] as String;
        final b = map['seeker_b_id'] as String;
        final String linkedSeekerId;
        final String partnerId;
        if (linkedIds.containsKey(a)) {
          linkedSeekerId = a;
          partnerId = b;
        } else if (linkedIds.containsKey(b)) {
          linkedSeekerId = b;
          partnerId = a;
        } else {
          continue; // shouldn't happen under RLS, but be defensive
        }

        // The card is keyed on the match, not the person — it is the
        // Journey that entitles a Main Shepherd to know who the other
        // family is, and only for as long as that Journey stands.
        final card = await _fetchCounterpartCard(
          map['id'] as String,
          partnerId,
        );
        if (card == null) continue; // not this Journey's Main Shepherd

        results.add(
          MentorJourneyView(
            matchId: map['id'] as String,
            linkedSeekerId: linkedSeekerId,
            linkedSeekerName: linkedIds[linkedSeekerId]!,
            partner: card.partner,
            counterpartShepherdName: card.shepherdFirstName,
            counterpartShepherdSurname: card.shepherdSurnameLine,
            status: map['status'] as String,
            journeyStage: map['journey_stage'] as String?,
            pause: _pauseFromRow(map),
          ),
        );
      }
      return results;
    } catch (e) {
      debugPrint('SELAH: fetchLinkedJourneys failed — $e');
      return null;
    }
  }

  /// The counterpart card — the ONLY route by which a Shepherd learns
  /// anything about the other family (selah_counterpart_card, 2026-08-08).
  ///
  /// Returns null when the caller is not the MAIN Shepherd of one of the
  /// two Seekers, when the Journey has not started, or when a block or a
  /// safety ending stands. All four are correct empty states, not errors.
  ///
  /// What it deliberately does NOT return: city, photos, gender, bio,
  /// Chapter answers — and no contact channel, because none exists in the
  /// schema yet and inventing one out of the Shepherd's auth email would
  /// be a new disclosure. Flagged for the Founder.
  ///
  /// The old implementation also fell back to a picsum.photos stock image
  /// when a counterpart had no photo, rendering a stranger's face as a
  /// real user's (audit R8). That path is gone with it.
  static Future<_CounterpartCard?> _fetchCounterpartCard(
    String matchId,
    String partnerId,
  ) async =>
      (await _fetchCounterpartCardResult(matchId, partnerId)).valueOrNull;

  static Future<SelahSourceResult<_CounterpartCard?>>
  _fetchCounterpartCardResult(String matchId, String partnerId) async {
    try {
      final rows = await supabase.rpc(
        'selah_counterpart_card',
        params: {'p_match_id': matchId},
      );
      if (rows is! List) {
        return const SelahSourceResult.unavailable(
          SelahSourceFailure.invalidResponse,
        );
      }
      if (rows.isEmpty) {
        return const SelahSourceResult.available(null);
      }
      final first = rows.first;
      if (first is! Map) {
        return const SelahSourceResult.unavailable(
          SelahSourceFailure.invalidResponse,
        );
      }
      final c = Map<String, dynamic>.from(first);
      final firstName = c['counterpart_first_name'];
      final age = c['counterpart_age'];
      final shepherdFirstName = c['shepherd_first_name'];
      final shepherdSurnameLine = c['shepherd_surname_line'];
      if (firstName is! String ||
          firstName.trim().isEmpty ||
          age is! num ||
          (shepherdFirstName != null && shepherdFirstName is! String) ||
          (shepherdSurnameLine != null && shepherdSurnameLine is! String)) {
        return const SelahSourceResult.unavailable(
          SelahSourceFailure.invalidResponse,
        );
      }
      return SelahSourceResult.available(
        _CounterpartCard(
          partner: SeekerProfile(
            id: partnerId,
            firstName: firstName.trim(),
            age: age.toInt(),
            city: '—', // withheld by the card, not missing
            photos: const [], // withheld by the card, not missing
            gender: '', // not disclosed to Shepherds
          ),
          shepherdFirstName: shepherdFirstName as String?,
          shepherdSurnameLine: shepherdSurnameLine as String?,
        ),
      );
    } catch (e) {
      // ES-08 — never silent. A Shepherd seeing an empty Journey list
      // because of a swallowed error looks identical to having none.
      debugPrint(
        '[SelahMentorJourneyService] counterpart card for $matchId failed: $e',
      );
      return const SelahSourceResult.unavailable(
        SelahSourceFailure.requestFailed,
      );
    }
  }

  /// Read-only Timeline for a Journey the Shepherd supervises.
  ///
  /// A successful empty list means there is genuinely no Timeline movement.
  /// Unavailable means the read did not return authoritative truth.
  static Future<SelahSourceResult<List<SelahMilestone>>> fetchTimelineSource(
    String matchId,
  ) async {
    if (!supabaseReady) {
      return const SelahSourceResult.unavailable(SelahSourceFailure.notReady);
    }
    if (SelahAuth.currentUser == null) {
      return const SelahSourceResult.unavailable(SelahSourceFailure.signedOut);
    }
    try {
      // inherited upstream action 159 stage 4b, 2026-08-10. WAS: .eq('match_id', matchId).
      // timelines belong to an ATTEMPT since stage 4a, so match_id no longer
      // identifies one row. Resolved through the typed attempt boundary, which
      // reads selah_my_attempt_participation — a Shepherd appears in that view
      // as a participant, so one helper serves both roles and there is a single
      // implementation to keep in step with the server-side trigger. The typed
      // result is required here so a failed attempt lookup cannot masquerade as
      // a genuinely empty Updates Timeline.
      final attemptResult = await SelahMatchService.currentAttemptIdResult(
        matchId,
      );
      if (attemptResult.failed) {
        return const SelahSourceResult.unavailable(
          SelahSourceFailure.requestFailed,
        );
      }
      final attemptId = attemptResult.attemptId;
      if (attemptId == null) {
        return const SelahSourceResult.available(<SelahMilestone>[]);
      }

      final timelineRows =
          await supabase
                  .from('timelines')
                  .select('id')
                  .eq('attempt_id', attemptId)
                  .limit(1)
              as List;
      if (timelineRows.isEmpty) {
        return const SelahSourceResult.available(<SelahMilestone>[]);
      }
      final firstTimeline = timelineRows.first;
      if (firstTimeline is! Map ||
          firstTimeline['id'] is! String ||
          (firstTimeline['id'] as String).isEmpty) {
        return const SelahSourceResult.unavailable(
          SelahSourceFailure.invalidResponse,
        );
      }
      final timelineId = firstTimeline['id'] as String;

      final milestoneRows =
          await supabase
                  .from('timeline_milestones')
                  .select('milestone_type, occurred_at')
                  .eq('timeline_id', timelineId)
                  // OLDEST FIRST, matching the Seeker's Timeline exactly. These two
                  // queries must move together: a Shepherd and the Seeker they support
                  // reading the same Journey in opposite orders is worse than either
                  // order being wrong.
                  .order('occurred_at', ascending: true)
              as List;

      final milestones = <SelahMilestone>[];
      for (final raw in milestoneRows) {
        if (raw is! Map) {
          return const SelahSourceResult.unavailable(
            SelahSourceFailure.invalidResponse,
          );
        }
        final type = raw['milestone_type'];
        final rawOccurredAt = raw['occurred_at'];
        final occurredAt = switch (rawOccurredAt) {
          DateTime value => value,
          String value => DateTime.tryParse(value),
          _ => null,
        };
        if (type is! String || type.isEmpty || occurredAt == null) {
          return const SelahSourceResult.unavailable(
            SelahSourceFailure.invalidResponse,
          );
        }
        milestones.add(SelahMilestone(type: type, occurredAt: occurredAt));
      }
      return SelahSourceResult.available(milestones);
    } catch (e) {
      debugPrint('SELAH: Shepherd Timeline for $matchId failed — $e');
      return const SelahSourceResult.unavailable(
        SelahSourceFailure.requestFailed,
      );
    }
  }

  /// Nullable compatibility bridge retained for existing callers.
  static Future<List<SelahMilestone>?> fetchTimelineResult(
    String matchId,
  ) async {
    final result = await fetchTimelineSource(matchId);
    return result.isAvailable ? result.valueOr(const <SelahMilestone>[]) : null;
  }

  /// List compatibility bridge for detail screens whose existing contract
  /// treats a failed Timeline as no rows. Truthful surfaces use
  /// [fetchTimelineSource].
  static Future<List<SelahMilestone>> fetchTimeline(String matchId) async =>
      (await fetchTimelineSource(matchId)).valueOr(const []);

  /// #31 — Family Review Period. Records this Mentor's Continue/Pause
  /// decision on [reviewId] (from SelahJourneyService.fetchFamilyReview()).
  /// The RPC itself verifies the caller is an active main Shepherd for one
  /// of the two Seekers on the review's match — this is the only
  /// enforcement point, not a client-side gate, so there's nothing to
  /// check here beyond swallowing failures. [decision] is 'continue' or
  /// 'pause'. Returns true on success.
  static Future<bool> mentorReviewDecision(
    String reviewId,
    String decision,
  ) async {
    try {
      await supabase.rpc(
        'mentor_review_decision',
        params: {'p_review_id': reviewId, 'p_decision': decision},
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// #31 — this Shepherd's own decision (if any) already recorded on
  /// [reviewId], so the UI can show "You chose Continue — waiting on
  /// the other family" instead of re-showing the buttons. An available null
  /// means this Shepherd has not responded; unavailable remains distinct.
  static Future<SelahSourceResult<String?>> myReviewDecisionResult(
    String reviewId,
  ) async {
    if (!supabaseReady) {
      return const SelahSourceResult.unavailable(SelahSourceFailure.notReady);
    }
    final user = SelahAuth.currentUser;
    if (user == null) {
      return const SelahSourceResult.unavailable(SelahSourceFailure.signedOut);
    }
    try {
      final row = await supabase
          .from('journey_family_review_responses')
          .select('decision')
          .eq('review_id', reviewId)
          .eq('mentor_id', user.id)
          .maybeSingle();
      if (row == null) return const SelahSourceResult.available(null);
      final decision = row['decision'];
      if (decision is! String ||
          !const {'continue', 'pause'}.contains(decision)) {
        return const SelahSourceResult.unavailable(
          SelahSourceFailure.invalidResponse,
        );
      }
      return SelahSourceResult.available(decision);
    } catch (e) {
      debugPrint('SELAH: Shepherd review decision for $reviewId failed — $e');
      return const SelahSourceResult.unavailable(
        SelahSourceFailure.requestFailed,
      );
    }
  }

  /// Compatibility bridge for older consumers where null combines no decision
  /// with an unavailable read. Truthful surfaces use [myReviewDecisionResult].
  static Future<String?> myReviewDecision(String reviewId) async =>
      (await myReviewDecisionResult(reviewId)).valueOrNull;

  /// #31 — reopens a 'paused' review for a fresh 48h window once the
  /// family has actually spoken (see the migration's own scope note:
  /// the source spec never specifies a resolution mechanic for a
  /// Pause beyond "SELAH support is available to assist"). Returns true
  /// on success.
  static Future<bool> reopenFamilyReview(String reviewId) async {
    try {
      await supabase.rpc(
        'reopen_family_review',
        params: {'p_review_id': reviewId},
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Read-only conversation messages for a Journey the Mentor
  /// supervises. Mentor has no send capability — no insert path exists
  /// for this role on `messages` (see the visibility migration's own
  /// comment). Empty and unavailable remain distinct at this boundary.
  static Future<SelahSourceResult<List<SelahChatMessage>>> fetchMessagesResult(
    String matchId,
  ) async {
    if (!supabaseReady) {
      return const SelahSourceResult.unavailable(SelahSourceFailure.notReady);
    }
    if (SelahAuth.currentUser == null) {
      return const SelahSourceResult.unavailable(SelahSourceFailure.signedOut);
    }
    try {
      // inherited upstream action 159 stage 4b, 2026-08-10. WAS: .eq('match_id', matchId).
      //
      // This one matters most of the four. A Shepherd reading by match_id
      // after a second Journey with the same person would have been shown
      // the PREVIOUS attempt's messages — a conversation the current Journey
      // did not consent to exposing, and inherited decision 121 item 11 makes Shepherd
      // involvement per-attempt precisely so a new Shepherd inherits nothing.
      // Silent, and a privacy failure rather than a display bug.
      final attemptResult = await SelahMatchService.currentAttemptIdResult(
        matchId,
      );
      if (attemptResult.failed) {
        return const SelahSourceResult.unavailable(
          SelahSourceFailure.requestFailed,
        );
      }
      final attemptId = attemptResult.attemptId;
      if (attemptId == null) {
        return const SelahSourceResult.available(<SelahChatMessage>[]);
      }

      final convRows =
          await supabase
                  .from('conversations')
                  .select('id')
                  .eq('attempt_id', attemptId)
                  .limit(1)
              as List;
      if (convRows.isEmpty) {
        return const SelahSourceResult.available(<SelahChatMessage>[]);
      }
      final firstConversation = convRows.first;
      if (firstConversation is! Map ||
          firstConversation['id'] is! String ||
          (firstConversation['id'] as String).isEmpty) {
        return const SelahSourceResult.unavailable(
          SelahSourceFailure.invalidResponse,
        );
      }
      final conversationId = firstConversation['id'] as String;

      final rows =
          await supabase
                  .from('messages')
                  .select('id, sender_id, content, created_at')
                  // OLDEST FIRST, matching the Seeker's chat. Same reason.
                  .eq('conversation_id', conversationId)
                  .order('created_at', ascending: true)
              as List;
      final messages = <SelahChatMessage>[];
      for (final raw in rows) {
        if (raw is! Map) {
          return const SelahSourceResult.unavailable(
            SelahSourceFailure.invalidResponse,
          );
        }
        final id = raw['id'];
        final content = raw['content'];
        final rawCreatedAt = raw['created_at'];
        final createdAt = switch (rawCreatedAt) {
          DateTime value => value,
          String value => DateTime.tryParse(value),
          _ => null,
        };
        if (id is! String ||
            id.isEmpty ||
            content is! String ||
            createdAt == null) {
          return const SelahSourceResult.unavailable(
            SelahSourceFailure.invalidResponse,
          );
        }
        messages.add(
          SelahChatMessage(
            id: id,
            text: content,
            fromMe: false,
            createdAt: createdAt,
          ),
        );
      }
      return SelahSourceResult.available(messages);
    } catch (e) {
      debugPrint('SELAH: Shepherd messages for $matchId failed — $e');
      return const SelahSourceResult.unavailable(
        SelahSourceFailure.requestFailed,
      );
    }
  }

  /// Compatibility bridge for older consumers where failure becomes empty.
  /// Truthful user-facing surfaces use [fetchMessagesResult].
  static Future<List<SelahChatMessage>> fetchMessages(String matchId) async =>
      (await fetchMessagesResult(matchId)).valueOr(const []);
}

/// Internal holder for one selah_counterpart_card() row.
class _CounterpartCard {
  final SeekerProfile partner;
  final String? shepherdFirstName;
  final String? shepherdSurnameLine;
  const _CounterpartCard({
    required this.partner,
    required this.shepherdFirstName,
    required this.shepherdSurnameLine,
  });
}
