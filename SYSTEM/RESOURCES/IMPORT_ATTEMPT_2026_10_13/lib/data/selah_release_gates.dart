/// Release controls that deliberately ship as compile-time facts.
///
/// Request New Journey is temporarily held for the Founder-only TestFlight
/// under DR-SELAH-227 while OA-SELAH-156 converts every ritual row to an
/// attempt-owned model. The server independently revokes the four public
/// request/read RPCs; this client gate keeps the unavailable path out of the
/// interface and prevents trusted code from calling it accidentally.
abstract final class SelahReleaseGates {
  static const bool requestNewJourneyEnabled = false;

  /// Turns on only with verified StoreKit/Play receipt authority, the Family
  /// seat migration and the restricted account screen all deployed together.
  /// False keeps the internal build testable; it does not prove a Basic
  /// joining fee was paid. DR-SELAH-252 requires this staged paid-only boundary
  /// to be reconciled with funded Basic before public commercial activation.
  static const bool paidOnlyMembershipEnforced = false;

  /// The client and migration are staged together, but the live project has
  /// not received OA-SELAH-298. Developer Access may exercise the isolated
  /// local preview; ordinary accounts must not call absent production RPCs.
  static const bool familyMessagingEnabled = false;

  static const String requestNewJourneyUnavailable =
      'Beginning a new Journey together is temporarily unavailable.';
}
