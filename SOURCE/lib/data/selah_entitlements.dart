// THE CANONICAL JOURNEY LIMITS — one definition, every surface.
//
// Founder-approved 2026-08-09. Supersedes every scattered number that
// described how many Journeys a plan may hold.
//
// ═══════════════════════════════════════════════════════════════════════
// THE MATRIX
// ═══════════════════════════════════════════════════════════════════════
//
//                    Seeker Basic       Seeker One
//   Active                 1                  3
//   Potential             10              unlimited
//   Paused                 1                 10
//   Paused returns         0                  5
//   Ended returns          0                  5
//
// Basic restored by inherited decision 252, 2026-10-03. Client capacity policy only;
// neither an enum nor this matrix proves a joining payment or grants access.
// Existing records survive. Server/receipt reconciliation remains separate.
//
// ── WHY A FILE AND NOT FOUR CONSTANTS. This project has paid three times
// today for the same mistake: four copies of an age fetch, two copies of
// a comet animation, three copies of a Journey stage switch. Limits are
// worse than labels, because a limit that disagrees with the server does
// not look wrong — it looks like the app refusing you for no reason.
//
// So: add a FIELD to [SelahJourneyLimits], never a second table of numbers
// somewhere else. If a plan gains a fifth countable thing, it goes here.
//
// ── POTENTIAL IS NULLABLE, AND null MEANS UNLIMITED — not zero, and not
// "unknown". SELAH One has no ceiling on Potential Journeys. Anything
// comparing against this must handle null explicitly; [isWithin] exists
// so that nobody writes `count < limit` against a null and gets it wrong.
//
// SERVER ENFORCEMENT
//
// Active caps have been server-enforced per plan since 2026-08-12. The
// shared Pause decision migration staged on 2026-08-25 made the capacity
// boundary explicit. Its previous Basic pause cap (5) is NOT migrated by
// this client's Founder revision to 1; server reconciliation is separate:
//
//   pause_requested / continue_requested  -> still Active capacity
//   paused / resume_requested             -> Paused capacity for both
//
// Paused capacity is checked for BOTH Seekers under the same locked state
// transition. The new Journey does not move to Paused, or release the Active
// slot, until a valid mutual outcome is accepted.
//
// STILL UNBUILT: [potential]'s cap-with-choice flow. Journey history is
// visible to every plan; paid entitlement controls only who may initiate a
// return and only within the five most recent rows of that state. Incoming
// requests remain actionable regardless of plan. The ended-return server path
// remains held under inherited upstream action 156 until attempt-owned ritual state is complete.

import '../state/app_state.dart' show SelahPlan;

/// How many Journeys of each kind a plan may hold.
///
/// [potential] is null when unlimited. Every other field is a real cap.
class SelahJourneyLimits {
  /// Running Journeys — not paused. The headline entitlement.
  ///
  /// Server-enforced per plan since 2026-08-12: these numbers are
  /// duplicated in selah_active_journey_cap() (migration
  /// plan_aware_active_journey_limit) — change one, change both.
  final int active;

  /// Mutual matches nobody has opened yet. Null means unlimited.
  ///
  /// On a capped plan, reaching this number does NOT block new matches.
  /// The agreed behaviour is a CHOICE at the moment of matching: end one
  /// of the existing Potential Journeys, or discard the new one. That
  /// flow is not built yet — see the header.
  final int? potential;

  /// Mutually Paused Journeys, including a pending mutual resume. Independent
  /// of [active]; an unresolved initial Pause/Continue decision still counts
  /// Active and does not consume this capacity.
  final int paused;

  /// Maximum ended rows produced by Developer Access scenario controls.
  /// Production history is never truncated by this value.
  final int ended;

  /// Most recent Paused rows from which this member may initiate a return.
  final int pausedReturnWindow;

  /// Most recent Ended rows from which this member may request a new Journey.
  final int endedReturnWindow;

  const SelahJourneyLimits({
    required this.active,
    required this.potential,
    required this.paused,
    required this.ended,
    required this.pausedReturnWindow,
    required this.endedReturnWindow,
  });
}

class SelahEntitlements {
  SelahEntitlements._();

  /// Restored Basic client capacities. Default/legacy Basic state is not
  /// evidence that the £4.99 joining fee was paid. Public activation still
  /// requires authoritative membership/payment checks, not this table.
  static const SelahJourneyLimits basic = SelahJourneyLimits(
    active: 1,
    potential: 10,
    paused: 1,
    ended: 0,
    pausedReturnWindow: 0,
    endedReturnWindow: 0,
  );

  static const SelahJourneyLimits one = SelahJourneyLimits(
    active: 3,
    potential: null, // unlimited
    paused: 10,
    ended: 10,
    pausedReturnWindow: 5,
    endedReturnWindow: 5,
  );

  static SelahJourneyLimits of(SelahPlan plan) =>
      plan == SelahPlan.one ? one : basic;

  /// True when [count] is within [limit], treating null as unlimited.
  ///
  /// Exists so that no call site writes `count < limit` against a
  /// nullable and either crashes or silently treats unlimited as zero.
  static bool isWithin(int count, int? limit) => limit == null || count < limit;

  // ── DEV PANEL ONLY ────────────────────────────────────────────────────

  /// The most segments the dev panel will draw for one control.
  ///
  /// Founder, 2026-08-09: "SELAH One Potential is unlimited but show max 10
  /// in toggle." Applied to every control. Basic's revised Potential cap
  /// is also 10, so the panel can now show the cap itself. The "choose one
  /// to end" overflow flow remains unbuilt and is not implied by this control.
  static const int devSegmentCeiling = 10;

  /// Highest value the dev panel offers for a control whose real cap is
  /// [realCap]. Null (unlimited) and anything above the ceiling both come
  /// back as [devSegmentCeiling].
  static int devMaxFor(int? realCap) {
    if (realCap == null || realCap > devSegmentCeiling) {
      return devSegmentCeiling;
    }
    return realCap;
  }

  /// Segment labels '0'..devMaxFor(realCap), inclusive. Always starts at
  /// '0' — Founder, 2026-08-09: "make sure each option have option for 0
  /// also."
  static List<String> devOptions(int? realCap) => [
    for (var i = 0; i <= devMaxFor(realCap); i++) '$i',
  ];

  /// Clamps a stored dev value to what the CURRENT plan allows.
  ///
  /// Needed because the dev panel keeps its counts across a plan switch:
  /// set Paused to 8 on SELAH One, drop to Basic, and 8 is now above
  /// Basic's 1. Used by both the panel (so the row shows a real value) and
  /// the fake-journey generator (so the list matches the row), which is
  /// the whole point of putting it here rather than in either of them.
  static int devClamp(int value, int? realCap) {
    final max = devMaxFor(realCap);
    if (value < 0) return 0;
    return value > max ? max : value;
  }
}
