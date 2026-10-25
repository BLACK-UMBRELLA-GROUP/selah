// Real match + journey-lifecycle wrapper for the Pre-Journey Ritual
// (APP/Journey/PRE-JOURNEY RITUAL/Summary.md) and Journey Suspension
// (APP/Journey/JOURNEY SUSPENSION/JOURNEY_SUSPENSION (CURRENT_VERSION)).
//
// Replaces the old UX-only Potential/Active Journey distinction in
// AppState (which held plain SeekerProfile lists with no backend
// column behind them) now that matches.status/journey_stage/
// suspended_by are real schema, per the 2026-07-25 migration. See
// SelahJourneyService for how these are fetched.

import 'seeker_profile.dart';
import '../data/selah_journey_pause_state.dart';

class JourneyMatch {
  final String matchId;
  final SeekerProfile profile; // the OTHER party
  /// 'potential' | 'active' | 'ended'.
  ///
  /// 'paused' is deliberately not a match status. The shared [pause] state
  /// decides whether an active match is running, decision-locked or mutually
  /// Paused without inventing a fourth lifecycle status.
  final String status;
  final String? journeyStage; // null while potential
  /// The single authoritative Pause decision state.
  final SelahJourneyPauseState pause;

  /// When the current pause episode began. Drives the time-honesty line
  /// ("Paused · 3 months") on the Journeys rows — DR-SELAH-142's answer to
  /// "how long may a pause last": forever (the system never ends what
  /// people haven't — DR-SELAH-121 item 12), but honestly.
  final DateTime? suspendedAt;

  /// Set when status == 'ended'; drives the 24-hour cooling period. Return
  /// initiation is now based on the caller's five most recent Ended Journeys,
  /// not an arbitrary age limit.
  final DateTime? endedAt;

  /// The OTHER person is currently in an Active Journey with someone else,
  /// so beginning (or restarting) with them would be refused right now —
  /// the server's one_active_journey_limit / other_party guards are the
  /// truth behind this flag. Real rows receive the server-computed signal
  /// from selah_journey_busy_flags; dev stand-ins use the same field so the
  /// busy card can still be exercised without remote data.
  final bool inAnotherJourney;
  final bool isMock; // true for demo/mock entries with no real backing row

  const JourneyMatch({
    required this.matchId,
    required this.profile,
    required this.status,
    this.journeyStage,
    this.pause = SelahJourneyPauseState.active,
    this.suspendedAt,
    this.endedAt,
    this.inAnotherJourney = false,
    this.isMock = false,
  });

  /// Only a mutually settled pause belongs in Paused Journeys and frees the
  /// Active slot. Pending decisions remain Active but locked.
  bool get isSuspended => pause.isPaused;
  bool get isPauseDecisionPending => pause.isPending;
  bool get isJourneyLocked => pause.isLocked;

  /// "3 months" / "6 weeks" / "12 days" — empty under 30 days, because a
  /// young pause needs no commentary. Time-honesty is a mirror, not a
  /// deadline: informative, never manipulative (DR-SELAH-142).
  String get pausedFor {
    if (suspendedAt == null) return '';
    final days = DateTime.now().difference(suspendedAt!).inDays;
    if (days < 30) return '';
    if (days < 61) return '${(days / 7).floor()} weeks';
    final months = (days / 30).floor();
    return '$months month${months == 1 ? '' : 's'}';
  }

  /// #17 — APP/Journey/JOURNEY AVAILABILITY/Summary.md: "24-hour
  /// cooling period begins (no actions possible)" after End Journey,
  /// "after 24 hours, journey officially disconnects" and Restart
  /// becomes available.
  bool get isInCoolingPeriod =>
      status == 'ended' &&
      endedAt != null &&
      DateTime.now().isBefore(endedAt!.add(const Duration(hours: 24)));

  /// Kept as a compatibility getter for callers written before the Founder
  /// replaced the 60-day age rule with a five-most-recent rule. Any ended row
  /// is age-eligible; the ranked server lookup decides whether this member may
  /// initiate from it.
  bool get isWithinNewJourneyRequestWindow =>
      status == 'ended' && endedAt != null;

  bool get canRestart => isWithinNewJourneyRequestWindow && !isInCoolingPeriod;

  /// "You can ask again in 4 hours".
  ///
  /// ADDED 2026-08-07 with the copy review. The Founder asked for "Restart
  /// available in 24 hours" in place of "Ended — cooling period", and the
  /// reasoning was right — users care what happens next, not what the
  /// internal state is called.
  ///
  /// REWORDED 2026-08-10, OA-SELAH-159. The word "Restart" had to go: it names
  /// a capability that has refused since 2026-08-06 and promises something
  /// unilateral. What actually becomes available is the right to ASK, which
  /// the other person may decline. The getter name stays `restartAvailableIn`
  /// for now — renaming it touches call sites for no behavioural gain, and
  /// OA-SELAH-156 step 7 will be through this file anyway.
  ///
  /// But a fixed "24 hours" would be WRONG for all but the first moment of
  /// the period. A Journey ended twenty hours ago has four hours left, and
  /// telling that user twenty-four is worse than the jargon it replaced:
  /// jargon is merely unclear, an incorrect number is untrue and they will
  /// come back and find it wasn't.
  ///
  /// Rounds UP, so it never promises sooner than it can deliver.
  String get restartAvailableIn {
    if (endedAt == null) return '';
    final left = endedAt!
        .add(const Duration(hours: 24))
        .difference(DateTime.now());
    if (left.inMinutes <= 0) return 'you can ask again';
    if (left.inMinutes < 60) return 'you can ask again in under an hour';
    final hours = (left.inMinutes / 60).ceil();
    return 'you can ask again in $hours ${hours == 1 ? "hour" : "hours"}';
  }
}
