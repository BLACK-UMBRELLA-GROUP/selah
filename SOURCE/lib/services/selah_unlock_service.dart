// Compatibility Unlock persistence.
//
// Founder approved 2026-08-03:
//   "A profile may only be Compatibility Unlocked once per user. Once
//    unlocked, the compatibility remains permanently accessible to that
//    user. Returning to the same profile must never consume another
//    Compatibility Unlock. The action button should permanently change
//    from Compatibility Unlock to View Compatibility after the initial
//    unlock."
//
// RENAMED FROM "Profile Unlock" in the same decision. The old pairing —
// `Profile Unlock` leading to `View Compatibility` — implied two different
// features. `Compatibility Unlock` → `View Compatibility` is one idea
// stated twice.
//
// WHAT IS REAL HERE AND WHAT IS NOT:
//
//   REAL   The unlock record. `profile_unlocks` rows are written and read,
//          RLS-scoped to the caller, with a unique index enforcing
//          once-per-profile-per-tier in the database rather than trusting
//          this class to check first.
//
//   NOT    The payment. There is no payment SDK in the project — verified
//          against pubspec.yaml: no in_app_purchase, no StoreKit, no
//          RevenueCat, no Stripe. The RPC still spends ledger credits; this
//          class never treats a missing checkout as a free live unlock.
//
//   REAL   The overall compatibility score, read by the presentation layer
//          from score_candidates().
//
//   NOT    Per-category compatibility totals. Until the server owns and
//          returns that contract, a new Compatibility Unlock+ is unavailable
//          and this service refuses it before any local or RPC write path.

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../main.dart';
import 'selah_auth.dart';
import 'selah_account_state.dart';
import 'selah_developer_access.dart';

/// What happened when an unlock was attempted.
///
/// REPLACES a bare `bool` (2026-08-04). The old signature could not
/// distinguish "you have no credits" from "the network failed", so the UI
/// showed the same retry message for both — one of which retrying will
/// never fix.
enum UnlockOutcome {
  /// A credit was spent and the profile is now unlocked.
  unlocked,

  /// Already unlocked at this tier. Nothing was charged — the permanence
  /// rule. Treated as success everywhere.
  alreadyUnlocked,

  /// No credits at this tier. Not an error; an answer.
  insufficientCredits,

  /// The requested tier cannot currently reveal a truthful result. Nothing
  /// was written and no credit was spent.
  unavailable,

  /// A non-persisted sample inside the existing protected Founder preview.
  /// Unlocked locally for the session, never a live entitlement or debit.
  /// Ordinary or signed-out sample calls cannot obtain this outcome.
  ///
  /// ADDED 2026-08-05 (Fable). Before this, tapping Unlock on a sample
  /// profile sent '1' to `selah_unlock_profile(p_target uuid, …)`, Postgres
  /// rejected it as invalid uuid syntax, and the screen showed "That didn't
  /// go through. Please try again." — advice that could never work, on the
  /// only profiles available to test with. The real cure is removing the
  /// sample deck entirely (independent review, H-6); until that happens the
  /// failure should at least be truthful.
  sampleProfile,

  /// The server requested recovery, or a write acknowledgement was lost or
  /// malformed. Read access again; do not blindly repeat a possible debit.
  recoveryRequired,

  /// The caller no longer owns this request, or has no ordinary authority.
  failed,
}

enum UnlockBalanceStatus { available, failed, stale }

/// A failed ledger lookup is not a zero-credit balance. The legacy Map API
/// remains compatible for older callers; transaction UI uses this result.
class UnlockBalanceResult {
  final UnlockBalanceStatus status;
  final Map<UnlockTier, int> values;

  const UnlockBalanceResult._(this.status, this.values);

  bool get available => status == UnlockBalanceStatus.available;
}

/// Which tier an unlock buys. Values must match `profile_unlocks`'
/// unlock_type CHECK constraint.
enum UnlockTier {
  /// Compatibility Unlock — the viewer's overall directional score only.
  standard('paid_single'),

  /// Existing Plus includes Standard. New Plus spending remains held; this
  /// enum does not activate the future reduced-disclosure projection.
  plus('paid_plus_single');

  const UnlockTier(this.dbValue);
  final String dbValue;
}

class SelahUnlockService {
  SelahUnlockService._();

  /// The one current Compatibility Unlock product uses the former full-detail
  /// entitlement. Stored tiers stay unchanged for permanent legacy access.
  static const currentTier = UnlockTier.plus;

  /// Compatibility Unlock+ remains held until real server-owned category
  /// totals are implemented and verified. Keeping the fuse in the service
  /// means a hidden, stale or future UI cannot debit a Plus credit either.
  static const bool categoryBreakdownAvailable = false;

  static bool isTierAvailable(UnlockTier tier) =>
      tier != UnlockTier.plus || categoryBreakdownAvailable;

  /// Everything this Seeker has already unlocked, as `'<profileId>:<tier>'`.
  ///
  /// Cached in memory for the session after the first read. The set only
  /// grows — an unlock is permanent, so nothing can invalidate it — which
  /// is what lets every card check ownership without a round trip.
  static final Set<String> _unlocked = {};
  static bool _loaded = false;
  static String? _owner;
  static int _epoch = 0;
  static int _loadRequest = 0;
  static final Map<String, Future<UnlockOutcome>> _pending = {};
  static final Map<String, String> _pendingTargets = {};
  static final Set<String> _recoveryRequired = {};
  static StreamSubscription<dynamic>? _authSubscription;

  static String? _currentOwner() {
    try {
      return SelahAuth.currentUser?.id;
    } catch (_) {
      return null;
    }
  }

  static void _synchronizeOwner() {
    try {
      _authSubscription ??= SelahAuth.authStateChanges.listen(
        (event) {
          final current = event.session?.user.id;
          if (_owner == current) return;
          clearForSignOut();
          _owner = current;
        },
        onError: (Object _, StackTrace _) {
          // A refresh failure is not a success acknowledgement. Retain no
          // in-flight transaction authority. Keep uncertain targets held for
          // this owner, so a refresh error cannot reopen a possible debit.
          _recoveryRequired.addAll(_pendingTargets.values);
          _epoch++;
          _loadRequest++;
          _pending.clear();
          _pendingTargets.clear();
          _unlocked.clear();
          _loaded = false;
          debugPrint('SELAH: unlock auth lifetime could not be confirmed.');
        },
      );
    } catch (_) {
      // Protected local sample previews can run without a Supabase instance.
    }
    final owner = _currentOwner();
    if (_owner == owner) return;
    clearForSignOut();
    _owner = owner;
  }

  static bool _isCurrent(String? owner, int epoch, int generation) =>
      !SelahAccountState.isSigningOut &&
      generation == SelahAccountState.generation &&
      epoch == _epoch &&
      owner == _owner &&
      owner == _currentOwner();

  static UnlockTier? _storedTier(Object? type) => switch (type) {
    'paid_single' || 'paid_bundle' || 'automatic_match' => UnlockTier.standard,
    'paid_plus_single' || 'paid_plus_bundle' => UnlockTier.plus,
    _ => null,
  };

  static String _key(String profileId, UnlockTier tier) =>
      '${_uuid.hasMatch(profileId) ? profileId.toLowerCase() : profileId}:${tier.dbValue}';

  /// Real rows have UUID ids; `mockProfiles` uses '1', '2', '3'…
  /// Anything sent to a `uuid` parameter must pass this first, or Postgres
  /// throws a syntax error the UI can only report as a generic failure.
  static final RegExp _uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  static bool isSampleProfile(String profileId) => !_uuid.hasMatch(profileId);

  /// A non-persisted Browse card may exercise Compatibility Unlock only
  /// inside the authenticated Founder preview. This never turns an email,
  /// profile id or debug-looking string into authority: the existing
  /// refreshed Founder capability remains the gate.
  static bool isDeveloperPreviewProfile(String profileId) =>
      SelahDeveloperAccess.canUseDeveloperTools && isSampleProfile(profileId);

  /// Deterministic fixture score for the isolated Founder preview. Real
  /// profiles never use this; their score remains server-owned by
  /// `score_candidates()`.
  static double? developerPreviewScore(String profileId) {
    if (!isDeveloperPreviewProfile(profileId)) return null;
    final seed = profileId.codeUnits.fold<int>(0, (sum, unit) => sum + unit);
    return (68 + (seed % 23)).toDouble();
  }

  static bool isUnlocked(String profileId, UnlockTier tier) {
    _synchronizeOwner();
    if (isSampleProfile(profileId) &&
        !SelahDeveloperAccess.canUseDeveloperTools) {
      return false;
    }
    return _unlocked.contains(_key(profileId, tier)) ||
        (tier == UnlockTier.standard &&
            _unlocked.contains(_key(profileId, UnlockTier.plus)));
  }

  /// Loads the caller's unlocks. Called once per launch from the session
  /// router; safe to call again.
  static Future<void> load() async {
    _synchronizeOwner();
    final user = SelahAuth.currentUser;
    if (user == null) return;
    final epoch = _epoch;
    final generation = SelahAccountState.generation;
    final request = ++_loadRequest;
    try {
      final rows =
          await supabase
                  .from('profile_unlocks')
                  .select('unlocked_id, unlock_type')
                  .eq('unlocker_id', user.id)
              as List;
      if (!_isCurrent(user.id, epoch, generation) || request != _loadRequest) {
        return;
      }
      final keys = <String>{};
      for (final row in rows) {
        if (row is! Map) continue;
        final target = row['unlocked_id'];
        final tier = _storedTier(row['unlock_type']);
        if (target is String && _uuid.hasMatch(target) && tier != null) {
          keys.add(_key(target, tier));
        }
      }
      // Entitlements are permanent. An older read must not erase a write
      // confirmed while that snapshot was in flight. Account resets still
      // clear the entire cache and invalidate every pending request.
      _unlocked.addAll(keys);
      _loaded = true;
    } catch (e) {
      // Logged, not swallowed. A failure here makes an already-unlocked
      // profile look locked, which would read as having lost something
      // paid for — worth seeing in the console rather than guessing at.
      debugPrint('SELAH: unlock load failed.');
    }
  }

  static bool get loaded {
    _synchronizeOwner();
    return _loaded;
  }

  /// Spends one credit to unlock a profile.
  ///
  /// REWRITTEN 2026-08-04 to close C-1 (independent review, reproduced
  /// end-to-end before the fix).
  ///
  /// This used to be a direct `INSERT INTO profile_unlocks`. The client
  /// decided that an unlock had been paid for, and the database believed
  /// it — so two HTTP requests with the publishable key that ships in this
  /// app bundle granted anyone another member's sect, revert status,
  /// ethnicity, birth country and nationality.
  ///
  /// `authenticated` no longer holds INSERT, UPDATE or DELETE on
  /// `profile_unlocks` at all. The row can only be created by
  /// `selah_unlock_profile()`, which verifies a credit balance in the
  /// `unlock_credits` ledger and writes the unlock and the debit in one
  /// transaction.
  ///
  /// Permanence is enforced server-side too: revisiting a profile already
  /// unlocked returns `already_unlocked` with `charged: false`, so a double
  /// tap on a slow connection cannot spend twice.
  static Future<UnlockOutcome> unlock(String profileId, UnlockTier tier) async {
    if (isUnlocked(profileId, tier)) return UnlockOutcome.alreadyUnlocked;

    // Preserve access already held above, but refuse every new Plus attempt
    // before the mock/offline, sample-profile and server RPC paths.
    if (!isTierAvailable(tier)) return UnlockOutcome.unavailable;
    if (_recoveryRequired.contains(_key(profileId, tier))) {
      return UnlockOutcome.recoveryRequired;
    }

    // Founder preview cards are deliberately non-persisted. Complete their
    // standard unlock locally before touching Auth or Supabase so the test
    // flow exercises the feature without resembling a live purchase.
    if (isDeveloperPreviewProfile(profileId)) {
      _unlocked.add(_key(profileId, tier));
      return UnlockOutcome.sampleProfile;
    }

    final user = SelahAuth.currentUser;
    final epoch = _epoch;
    final generation = SelahAccountState.generation;
    if (user == null ||
        isSampleProfile(profileId) ||
        !_isCurrent(user.id, epoch, generation)) {
      return UnlockOutcome.failed;
    }

    final key = '${user.id}:$epoch:$generation:${_key(profileId, tier)}';
    final existing = _pending[key];
    if (existing != null) return existing;
    final pending = _unlockOnce(profileId, tier, user.id, epoch, generation);
    _pending[key] = pending;
    _pendingTargets[key] = _key(profileId, tier);
    try {
      return await pending;
    } finally {
      if (identical(_pending[key], pending)) {
        _pending.remove(key);
        _pendingTargets.remove(key);
      }
    }
  }

  static Future<UnlockOutcome> _unlockOnce(
    String profileId,
    UnlockTier tier,
    String owner,
    int epoch,
    int generation,
  ) async {
    try {
      final res = await supabase.rpc(
        'selah_unlock_profile',
        params: {'p_target': profileId, 'p_tier': tier.dbValue},
      );
      if (!_isCurrent(owner, epoch, generation)) return UnlockOutcome.failed;
      final status = (res as Map?)?['status'] as String?;
      switch (status) {
        case 'unlocked':
          _unlocked.add(_key(profileId, tier));
          return UnlockOutcome.unlocked;
        case 'already_unlocked':
          _unlocked.add(_key(profileId, tier));
          return UnlockOutcome.alreadyUnlocked;
        case 'insufficient_credits':
          return UnlockOutcome.insufficientCredits;
        case 'plus_unavailable':
          return UnlockOutcome.unavailable;
        case 'recovery_required':
          _recoveryRequired.add(_key(profileId, tier));
          return UnlockOutcome.recoveryRequired;
        default:
          debugPrint('SELAH: unlock acknowledgement requires recovery.');
          _recoveryRequired.add(_key(profileId, tier));
          return UnlockOutcome.recoveryRequired;
      }
    } catch (e) {
      if (!_isCurrent(owner, epoch, generation)) return UnlockOutcome.failed;
      debugPrint('SELAH: unlock acknowledgement could not be confirmed.');
      _recoveryRequired.add(_key(profileId, tier));
      return UnlockOutcome.recoveryRequired;
    }
  }

  /// Credit balance per tier, from the `unlock_credits` ledger.
  ///
  /// ADDED 2026-08-04. Balances previously existed only as an in-memory
  /// enum in the dev panel — there was no server-side notion of how many
  /// unlocks anyone owned, which is precisely why nothing could check one.
  ///
  /// Compatibility-only wrapper for existing Map callers. This never grants
  /// credits on failure, but cannot express unknown. New transaction UI must
  /// use [readBalances] instead. The older Profile consumer remains a held
  /// presentation limitation until separately scoped.
  static Future<Map<UnlockTier, int>> balances() async {
    final result = await readBalances();
    return result.available
        ? result.values
        : {for (final tier in UnlockTier.values) tier: 0};
  }

  static Future<UnlockBalanceResult> readBalances() async {
    _synchronizeOwner();
    final out = {for (final t in UnlockTier.values) t: 0};
    final owner = _owner;
    final epoch = _epoch;
    final generation = SelahAccountState.generation;
    if (owner == null || !_isCurrent(owner, epoch, generation)) {
      return const UnlockBalanceResult._(UnlockBalanceStatus.stale, {});
    }
    try {
      final rows = await supabase.rpc('unlock_balance');
      if (!_isCurrent(owner, epoch, generation)) {
        return const UnlockBalanceResult._(UnlockBalanceStatus.stale, {});
      }
      if (rows is! List) throw const FormatException('Invalid balance rows');
      final seen = <UnlockTier>{};
      for (final r in rows) {
        final m = Map<String, dynamic>.from(r as Map);
        if (!UnlockTier.values.any((tier) => tier.dbValue == m['tier'])) {
          throw const FormatException('Unknown balance tier');
        }
        // Plain loop rather than `.firstOrNull`, which lives in
        // package:collection and is not a dependency of this project.
        for (final t in UnlockTier.values) {
          if (t.dbValue == m['tier']) {
            final balance = m['balance'];
            if (balance is! num ||
                !balance.isFinite ||
                balance < 0 ||
                balance != balance.toInt() ||
                !seen.add(t)) {
              throw const FormatException('Invalid ledger balance');
            }
            out[t] = balance.toInt();
            break;
          }
        }
      }
      return UnlockBalanceResult._(
        UnlockBalanceStatus.available,
        Map.unmodifiable(out),
      );
    } catch (e) {
      if (!_isCurrent(owner, epoch, generation)) {
        return const UnlockBalanceResult._(UnlockBalanceStatus.stale, {});
      }
      debugPrint('SELAH: unlock balance is unavailable.');
      return const UnlockBalanceResult._(UnlockBalanceStatus.failed, {});
    }
  }

  /// Legacy server-backed credit grant retains its client capability guard.
  /// Internal Founder previews use local credits and deny all data HTTP; this
  /// retained RPC helper does not grant them live credit-writing authority.
  /// Production server authorization remains unchanged.
  ///
  /// Exists because payments do not, and without it Compatibility Unlock
  /// would be untestable: a Seeker with no purchase route has a permanent
  /// balance of zero.
  static Future<bool> debugGrant(UnlockTier tier, int count) async {
    if (!SelahDeveloperAccess.canUseDeveloperTools) return false;
    _synchronizeOwner();
    final owner = _owner;
    final epoch = _epoch;
    final generation = SelahAccountState.generation;
    try {
      await supabase.rpc(
        'selah_debug_grant_credits',
        params: {'p_tier': tier.dbValue, 'p_count': count},
      );
      return _isCurrent(owner, epoch, generation);
    } catch (e) {
      debugPrint('SELAH: debug credit grant refused — $e');
      return false;
    }
  }

  /// Test-account ids are not real `profiles` rows, so the FK would reject
  /// them. Mirrors SelahReportService.isPersistableId.
  static void clearForSignOut() {
    // Invalidates in-flight reads/writes even for an A -> B -> A switch.
    _epoch++;
    _loadRequest++;
    _pending.clear();
    _pendingTargets.clear();
    _recoveryRequired.clear();
    _owner = null;
    _unlocked.clear();
    _loaded = false;
  }
}
