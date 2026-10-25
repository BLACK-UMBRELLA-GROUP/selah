// Canonical mapping between the `subscriptions.plan_type` DB
// identifiers (20260718190011_initial_schema.sql: 'seeker_basic',
// 'seeker_premium', 'mentor_basic', 'mentor_premium' — a plain TEXT
// column with a CHECK constraint, not a Postgres enum) and the
// product-facing names used throughout the UI (SELAH Basic / SELAH One
// for Seekers, Standard Mentor / Mentor One for Mentors).
//
// Added 2026-07-26 (inherited decision 101 audit — "plan-name drift" flagged in
// SELAH_FABLE_BUILD_REVIEW_2026-07-19_V1.md §Open Decisions item 3).
//
// IMPORTANT — what this fixes and what it doesn't:
// The naming mismatch itself is intentional and not a bug: the DB
// identifiers are internal/stable, the product names are what users
// see, and that's a completely normal separation. The REAL gap this
// audit found was that nothing in the Flutter app ever read or wrote
// `subscriptions.plan_type` at all — AppState's `SelahPlan` enum
// (basic/one) was a fully separate, local-only mock entitlement flag.
//
// PARTIALLY CLOSED SINCE. Two things now cross the gap, both through
// this file's mapping:
//   READ   selah_session_router.dart (2026-08-12) reads plan_type back
//          into AppState.plan on every sign-in and cold start.
//   WRITE  the dev panel's Membership control (2026-08-12) writes it
//          for @selah.test accounts via selah_dev_set_seeker_plan(), so
//          server-enforced entitlements (pause caps) test against the
//          plan being simulated.
// What remains deliberately unwired is REAL purchasing — UpgradeScreen
// still flips only the mock, matching the known "no real payment
// processing" gap (Founder handover, Immediate Next Steps item 6).
// When IAP arrives, it drives the same column through this same
// mapping.
//
// mentor_premium (Mentor One) is doubly dormant: unused by any Dart
// code AND never granted by any real purchase flow — Mentor's
// Extended-Shepherd gate today is a local mock switch
// (AppState.mentorHasMentorOne via mentor_network_screen.dart's "Get
// Shepherd+" button), not backed by this column at all.

import '../data/selah_membership_catalog.dart';

/// The four real values `subscriptions.plan_type` accepts.
enum SelahSubscriptionPlanType {
  seekerBasic,
  seekerPremium,
  mentorBasic,
  mentorPremium;

  String get dbValue => switch (this) {
    SelahSubscriptionPlanType.seekerBasic => 'seeker_basic',
    SelahSubscriptionPlanType.seekerPremium => 'seeker_premium',
    SelahSubscriptionPlanType.mentorBasic => 'mentor_basic',
    SelahSubscriptionPlanType.mentorPremium => 'mentor_premium',
  };

  /// The name shown to users for this plan.
  String get displayName => switch (this) {
    SelahSubscriptionPlanType.seekerBasic => 'Seeker Basic',
    SelahSubscriptionPlanType.seekerPremium =>
      SelahMembershipCatalog.seekerOneTitle,
    SelahSubscriptionPlanType.mentorBasic => 'Shepherd Basic',
    SelahSubscriptionPlanType.mentorPremium =>
      SelahMembershipCatalog.shepherdOneTitle,
  };

  static SelahSubscriptionPlanType? fromDbValue(String? value) =>
      switch (value) {
        'seeker_basic' => SelahSubscriptionPlanType.seekerBasic,
        'seeker_premium' => SelahSubscriptionPlanType.seekerPremium,
        'mentor_basic' => SelahSubscriptionPlanType.mentorBasic,
        'mentor_premium' => SelahSubscriptionPlanType.mentorPremium,
        _ => null,
      };
}
