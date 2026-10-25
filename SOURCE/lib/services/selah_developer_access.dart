// Server-controlled policy for SELAH's Founder/developer tools.
//
// The public identity (including email address and domain) is deliberately
// not authority. Supabase app_metadata can only be changed from a trusted
// server/admin context, so the role claim cannot be granted by editing a
// profile or OAuth metadata on the phone.

import 'dart:async';

import 'package:flutter/foundation.dart'
    show Listenable, ValueNotifier, visibleForTesting;
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase, User;

import '../config/selah_app_variant.dart';
import '../draft/selah_draft_runtime.dart';
import '../config/supabase_config.dart';
import '../config/selah_internal_founder_policy.dart';
import '../config/selah_external_tester_policy.dart';
import 'selah_internal_preview_client.dart';
import 'selah_account_state.dart';

class SelahAuthorizationRefreshSnapshot {
  final User? user;
  final bool founderAuthorized;

  const SelahAuthorizationRefreshSnapshot._({
    required this.user,
    required this.founderAuthorized,
  });

  const SelahAuthorizationRefreshSnapshot.denied()
    : this._(user: null, founderAuthorized: false);
}

class _SelahAuthorizationFlight {
  _SelahAuthorizationFlight({
    required this.generation,
    required this.userId,
    required this.identityKey,
    required this.refreshesSession,
  });

  final int generation;
  String? userId;
  String? identityKey;
  final bool refreshesSession;
  final Completer<SelahAuthorizationRefreshSnapshot> completer =
      Completer<SelahAuthorizationRefreshSnapshot>();
  _SelahAuthorizationFlight? successor;

  Future<SelahAuthorizationRefreshSnapshot> get future => completer.future;
}

class SelahDeveloperAccess {
  SelahDeveloperAccess._();

  static const String roleClaim = 'selah_role';
  static bool _authorizedForTesting = false;
  static bool _externalTesterAuthorized = false;
  static bool? _mainAppPreviewForTesting;

  static bool get isMainAppFounderPreview =>
      _mainAppPreviewForTesting ??
      (_currentVariant == SelahAppVariant.production &&
          SelahInternalFounderPolicy.enabled &&
          isAuthorizedOperator);

  /// A local preview is either the authenticated Founder preview or the
  /// explicitly compiled external-tester preview. It is not a production
  /// member session and never grants server-side authority.
  static bool get isMainAppPreview =>
      isMainAppFounderPreview || _externalTesterAuthorized;

  static bool get isAuthorizedTester => _externalTesterAuthorized;

  static bool authorizeExternalTester({
    required String username,
    required String password,
  }) {
    final accepted =
        SelahExternalTesterPolicy.enabled &&
        username.trim() == SelahExternalTesterPolicy.username &&
        password == SelahExternalTesterPolicy.password;
    if (_externalTesterAuthorized != accepted) {
      _externalTesterAuthorized = accepted;
      _notifyAuthorizationChanged();
    }
    return accepted;
  }

  static void clearExternalTesterAuthorization() {
    if (!_externalTesterAuthorized) return;
    _externalTesterAuthorized = false;
    _notifyAuthorizationChanged();
  }

  @visibleForTesting
  static void setMainAppFounderPreviewForTesting(bool? value) {
    assert(() {
      _mainAppPreviewForTesting = value;
      return true;
    }());
  }

  static String? _refreshedFounderUserId;
  static int _authorizationGeneration = 0;
  static _SelahAuthorizationFlight? _activeAuthorizationFlight;
  static final ValueNotifier<int> _authorizationRevision = ValueNotifier(0);

  static SelahAppVariant? _variantForTesting;
  static User? Function()? _currentUserForTesting;
  static Future<User?> Function()? _refreshSessionForTesting;
  static Duration _refreshTimeout = const Duration(seconds: 10);
  static bool Function(User user)? _founderIdentityMatchesForTesting;

  /// Notifies the app-wide guard whenever refreshed authority changes.
  static Listenable get authorizationChanges => _authorizationRevision;

  static void _notifyAuthorizationChanged() {
    _authorizationRevision.value += 1;
  }

  @visibleForTesting
  static void setAuthorizedForTesting(bool value) {
    assert(() {
      if (_authorizedForTesting != value) {
        _authorizedForTesting = value;
        _notifyAuthorizationChanged();
      }
      return true;
    }());
  }

  static void clearRefreshedClaims() {
    _authorizationGeneration += 1;
    _activeAuthorizationFlight = null;
    _replaceRefreshedProof(founderId: null);
  }

  static void _replaceRefreshedProof({required String? founderId}) {
    if (_refreshedFounderUserId == founderId) return;
    _refreshedFounderUserId = founderId;
    _notifyAuthorizationChanged();
  }

  /// Accepts a user returned by an explicit `tokenRefreshed` Auth event.
  ///
  /// Only the exact main Founder proof may publish after this fresh event.
  static Future<SelahAuthorizationRefreshSnapshot> acceptFreshTokenRefresh(
    User user,
  ) {
    final active = _activeAuthorizationFlight;
    final identityKey = _authorizationIdentityKey(user);
    if (active != null &&
        active.userId == user.id &&
        active.identityKey == identityKey &&
        (active.refreshesSession || !active.completer.isCompleted)) {
      return active.future;
    }
    return _startAuthorizationFlight(
      userId: user.id,
      identityKey: identityKey,
      refreshesSession: false,
      run: (flight) => _authorizeFreshUserWithinFlight(flight, user),
    );
  }

  static Future<SelahAuthorizationRefreshSnapshot>
  _authorizeFreshUserWithinFlight(
    _SelahAuthorizationFlight flight,
    User user,
  ) async {
    if (!_isFlightCurrent(flight, user)) {
      return _successorOrDenied(flight);
    }

    final variant = _currentVariant;
    final founderClaim = _founderIdentityMatches(user, variant);
    if (founderClaim) {
      if (!_isFlightCurrent(flight, user)) {
        return _successorOrDenied(flight);
      }
      if (variant == SelahAppVariant.production &&
          SelahInternalFounderPolicy.enabled) {
        SelahInternalPreviewClient.beginPreview();
      }
      _replaceRefreshedProof(founderId: user.id);
      return SelahAuthorizationRefreshSnapshot._(
        user: user,
        founderAuthorized: true,
      );
    }

    _replaceRefreshedProof(founderId: null);
    return SelahAuthorizationRefreshSnapshot._(
      user: user,
      founderAuthorized: false,
    );
  }

  static bool _isFlightCurrent(_SelahAuthorizationFlight flight, User user) {
    if (SelahAccountState.isSigningOut ||
        _authorizationGeneration != flight.generation ||
        !identical(_activeAuthorizationFlight, flight)) {
      return false;
    }
    return _currentUserOrNull?.id == user.id;
  }

  static Future<SelahAuthorizationRefreshSnapshot> _successorOrDenied(
    _SelahAuthorizationFlight flight,
  ) async {
    final successor = flight.successor;
    return successor == null
        ? const SelahAuthorizationRefreshSnapshot.denied()
        : successor.future;
  }

  static Future<SelahAuthorizationRefreshSnapshot> _startAuthorizationFlight({
    required String? userId,
    required String? identityKey,
    required bool refreshesSession,
    required Future<SelahAuthorizationRefreshSnapshot> Function(
      _SelahAuthorizationFlight flight,
    )
    run,
  }) {
    final prior = _activeAuthorizationFlight;
    final flight = _SelahAuthorizationFlight(
      generation: ++_authorizationGeneration,
      userId: userId,
      identityKey: identityKey,
      refreshesSession: refreshesSession,
    );
    if (prior != null && !prior.completer.isCompleted) {
      prior.successor = flight;
    }
    _activeAuthorizationFlight = flight;
    _replaceRefreshedProof(founderId: null);

    // Defer user-supplied/Auth work until the flight future is published. A
    // tokenRefreshed event may be delivered re-entrantly by refreshSession;
    // it must be able to join this exact future rather than start another RPC.
    scheduleMicrotask(() async {
      SelahAuthorizationRefreshSnapshot result;
      try {
        result = await run(flight);
      } catch (_) {
        result = await _successorOrDenied(flight);
      }
      if (!flight.completer.isCompleted) flight.completer.complete(result);
      if (identical(_activeAuthorizationFlight, flight)) {
        _activeAuthorizationFlight = null;
      }
    });
    return flight.future;
  }

  /// Refreshes Auth before retaining Founder capability. Any missing client,
  /// network failure, removed claim or identity mismatch clears the proof.
  static Future<SelahAuthorizationRefreshSnapshot>
  refreshCurrentAuthorizationSnapshot() async {
    final currentUser = _currentUserOrNull;
    final currentUserId = currentUser?.id;
    final identityKey = _authorizationIdentityKey(currentUser);
    final active = _activeAuthorizationFlight;
    if (active != null &&
        active.userId == currentUserId &&
        active.identityKey == identityKey) {
      return active.future;
    }
    return _startSessionRefresh(
      userId: currentUserId,
      identityKey: identityKey,
    );
  }

  /// `userUpdated` is not evidence of a new access token. It must invalidate
  /// current proof and force a real session refresh; concurrent callers follow
  /// this replacement flight rather than publishing stale results.
  static Future<SelahAuthorizationRefreshSnapshot>
  refreshAuthorizationAfterUserUpdated() {
    final currentUser = _currentUserOrNull;
    return _startSessionRefresh(
      userId: currentUser?.id,
      identityKey: _authorizationIdentityKey(currentUser),
    );
  }

  static Future<SelahAuthorizationRefreshSnapshot> _startSessionRefresh({
    required String? userId,
    required String? identityKey,
  }) => _startAuthorizationFlight(
    userId: userId,
    identityKey: identityKey,
    refreshesSession: true,
    run: (_SelahAuthorizationFlight flight) async {
      try {
        final user = await _refreshSessionUser().timeout(_refreshTimeout);
        if (user == null) return _successorOrDenied(flight);
        if (!identical(_activeAuthorizationFlight, flight)) {
          return _successorOrDenied(flight);
        }
        flight.userId = user.id;
        flight.identityKey = _authorizationIdentityKey(user);
        return _authorizeFreshUserWithinFlight(flight, user);
      } catch (_) {
        // Fail closed. The app-wide owner removes the controls and routes away
        // from guarded destinations when a previously authorized session loses
        // proof; normal member routing handles its own connection UI.
      }
      return _successorOrDenied(flight);
    },
  );

  static Future<bool> refreshCurrentAuthorization() async {
    await refreshCurrentAuthorizationSnapshot();
    return canUseDeveloperTools;
  }

  /// Default/public builds deny. The internal main-app opt-in requires the
  /// exact Founder user ID returned by a fresh session.
  static bool get isAuthorizedOperator {
    if (SelahAccountState.isSigningOut) return false;
    if (_externalTesterAuthorized) return true;
    if (_authorizedForTesting) return true;
    // Widget tests intentionally run without a Supabase singleton. Deny by
    // default rather than allowing an uninitialised auth client to crash a
    // normal screen that merely checks whether dev controls should exist.
    final user = _currentUserOrNull;
    return user != null &&
        user.id == _refreshedFounderUserId &&
        _founderIdentityMatches(user, _currentVariant);
  }

  // This separate private app has local fixture controls only. It grants no
  // authenticated server role, billing entitlement or production access.
  static bool get canUseDeveloperTools => SelahDraftRuntime.active;

  /// Denial only: this does not confer Founder capability from a cached ID.
  static bool get blocksMemberRouting =>
      SelahInternalPreviewClient.isActive ||
      (_currentUserOrNull?.id ==
              SelahInternalFounderPolicy.approvedFounderUserId &&
          (_mainAppPreviewForTesting ?? SelahInternalFounderPolicy.enabled));

  /// A caller asking for a preview never creates authority by itself.
  static bool allowsDevPreview(bool requested) =>
      requested && canUseDeveloperTools;

  static SelahAppVariant get _currentVariant =>
      _variantForTesting ?? SelahAppVariantPolicy.current;

  static bool _founderIdentityMatches(User user, SelahAppVariant variant) {
    final override = _founderIdentityMatchesForTesting;
    if (override != null) return override(user);
    return SelahInternalFounderPolicy.allows(
      variant: variant,
      internalBuildEnabled: SelahInternalFounderPolicy.enabled,
      suppliedFounderUserId: SelahInternalFounderPolicy.compiledFounderUserId,
      supabaseUrl: SupabaseConfig.url,
      userId: user.id,
      appMetadata: user.appMetadata,
      claimsAreFresh: true,
    );
  }

  static Future<User?> _refreshSessionUser() async {
    final override = _refreshSessionForTesting;
    if (override != null) return override();
    return (await Supabase.instance.client.auth.refreshSession()).user;
  }

  static String? _authorizationIdentityKey(User? user) {
    if (user == null) return null;
    String claim(Object? value) => value is String
        ? 'string:$value'
        : value == null
        ? 'null'
        : 'invalid:${value.runtimeType}';
    return [
      user.id,
      user.email ?? '',
      claim(user.appMetadata[roleClaim]),
    ].join('\u0000');
  }

  @visibleForTesting
  static void configureAuthorizationForTesting({
    required SelahAppVariant variant,
    required User? Function() currentUser,
    required Future<User?> Function() refreshSession,
    required bool Function(User user) founderIdentityMatches,
    Duration refreshTimeout = const Duration(seconds: 10),
  }) {
    assert(() {
      clearRefreshedClaims();
      _variantForTesting = variant;
      _currentUserForTesting = currentUser;
      _refreshSessionForTesting = refreshSession;
      _founderIdentityMatchesForTesting = founderIdentityMatches;
      _refreshTimeout = refreshTimeout;
      return true;
    }());
  }

  @visibleForTesting
  static void resetAuthorizationForTesting() {
    assert(() {
      clearRefreshedClaims();
      _variantForTesting = null;
      _mainAppPreviewForTesting = null;
      _currentUserForTesting = null;
      _refreshSessionForTesting = null;
      _founderIdentityMatchesForTesting = null;
      _refreshTimeout = const Duration(seconds: 10);
      return true;
    }());
  }

  static User? get _currentUserOrNull {
    final override = _currentUserForTesting;
    if (override != null) return override();
    try {
      return Supabase.instance.client.auth.currentUser;
    } catch (_) {
      return null;
    }
  }
}
