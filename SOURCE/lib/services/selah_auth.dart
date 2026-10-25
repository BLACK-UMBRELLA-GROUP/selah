// Thin wrapper around Supabase Auth — OA-102.
//
// Apple + Google remain the normal sign-in methods and SELAH never stores a
// password. Founder decision 2026-08-20 adds two recovery protections:
// another Apple/Google identity can be linked to the SAME Supabase user, and
// an already-authenticated member can verify a recovery email for one-time-
// code sign-in. Recovery OTP requests always set shouldCreateUser=false, so
// an unknown address cannot manufacture a second Seeker account.
//
// Sign-up and sign-in are the same action with OAuth — there's no
// separate "create account" step for the user to choose. A first-time
// Google/Apple sign-in produces a Supabase auth.users row with no
// matching `profiles` row yet; SelahSessionRouter already treats that
// as "onboarding incomplete" and routes to Role Selection, so this
// file doesn't need to know or care whether it's someone's first
// sign-in or their fifth.

import 'dart:convert';
import 'selah_account_state.dart';
import 'selah_developer_access.dart';
import 'selah_internal_preview_client.dart';
import 'selah_initial_signup_draft_service.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show debugPrint, visibleForTesting;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/oauth_config.dart';
import '../main.dart';

enum SelahAuthOutcome { success, cancelled, error }

class SelahAuthResult {
  final SelahAuthOutcome outcome;
  final String? errorMessage;
  // Binds recovery's local handoff to the principal returned by Auth. This
  // is not profile, identity-verification or membership authorization.
  final String? authenticatedUserId;
  const SelahAuthResult._(
    this.outcome,
    this.errorMessage, [
    this.authenticatedUserId,
  ]);

  const SelahAuthResult.success({String? authenticatedUserId})
    : this._(SelahAuthOutcome.success, null, authenticatedUserId);
  const SelahAuthResult.cancelled() : this._(SelahAuthOutcome.cancelled, null);
  const SelahAuthResult.error(String message)
    : this._(SelahAuthOutcome.error, message);
}

class SelahAuth {
  SelahAuth._();

  static const _googleScopes = <String>['email'];
  static Future<void>? _googleInitialization;
  static Future<void> Function()? _googleSignOutForTesting;

  static User? get currentUser => supabaseReady ? supabase.auth.currentUser : null;
  static bool get isSignedIn => currentUser != null;
  static Stream<AuthState> get authStateChanges => supabaseReady
      ? supabase.auth.onAuthStateChange
      : const Stream<AuthState>.empty();

  static Set<String> get linkedProviders {
    final providers = <String>{
      for (final identity in currentUser?.identities ?? const <UserIdentity>[])
        identity.provider.toLowerCase(),
    };
    final appMetadata = currentUser?.appMetadata;

    void addProvider(Object? value) {
      if (value is! String) return;
      final provider = value.trim().toLowerCase();
      if (provider.isNotEmpty) providers.add(provider);
    }

    // Supabase can expose the authoritative provider list only through
    // app_metadata (not identities), including immediately after an OAuth
    // exchange. This is provider detection, not an authorization decision.
    addProvider(appMetadata?['provider']);
    final metadataProviders = appMetadata?['providers'];
    if (metadataProviders is Iterable) {
      for (final provider in metadataProviders) {
        addProvider(provider);
      }
    }
    return providers;
  }

  @visibleForTesting
  static void setGoogleSignOutForTesting(Future<void> Function()? action) {
    assert(() {
      _googleSignOutForTesting = action;
      return true;
    }());
  }

  static bool get hasLinkedOAuth =>
      linkedProviders.contains('apple') || linkedProviders.contains('google');

  static String? get recoveryEmail {
    for (final identity in currentUser?.identities ?? const <UserIdentity>[]) {
      if (identity.provider != 'email') continue;
      final email = identity.identityData?['email'];
      if (email is String && email.trim().isNotEmpty) return email.trim();
    }
    return null;
  }

  static String? providerEmail(String provider) {
    for (final identity in currentUser?.identities ?? const <UserIdentity>[]) {
      if (identity.provider != provider) continue;
      final email = identity.identityData?['email'];
      if (email is String && email.trim().isNotEmpty) return email.trim();
    }
    return null;
  }

  static bool isValidEmail(String value) =>
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value.trim());

  /// First name supplied by Apple/Google, when the provider made one
  /// available. Apple only returns the name on the first authorisation, so
  /// [signInWithApple] stores that one-time value in auth metadata for future
  /// launches. The onboarding question still lets the member correct it.
  static String? get onboardingFirstName =>
      firstNameFromMetadata(currentUser?.userMetadata);

  static String? firstNameFromMetadata(Map<String, dynamic>? metadata) {
    if (metadata == null) return null;
    for (final key in const ['given_name', 'first_name', 'name', 'full_name']) {
      final firstName = _normaliseFirstName(metadata[key]);
      if (firstName != null) return firstName;
    }
    return null;
  }

  static String? _normaliseFirstName(Object? value) {
    if (value is! String) return null;
    final clean = value.trim();
    if (clean.isEmpty) return null;
    return clean.split(RegExp(r'\s+')).first;
  }

  static Future<void> _rememberProviderFirstName(String? providerName) async {
    final firstName = _normaliseFirstName(providerName);
    if (firstName == null || onboardingFirstName != null) return;
    try {
      await supabase.auth.updateUser(
        UserAttributes(data: {'given_name': firstName}),
      );
    } catch (error) {
      // A greeting must never turn a successful sign-in into a failure.
      // The member can still enter their name on the first question.
      debugPrint('SELAH provider first-name metadata save failed: $error');
    }
  }

  /// google_sign_in 7 uses one process-wide client and requires exactly one
  /// completed initialization before authentication. Keep the same future for
  /// concurrent taps, but allow a later retry if initialization itself fails.
  static Future<void> _ensureGoogleInitialized() async {
    final existing = _googleInitialization;
    if (existing != null) return existing;

    final initialization = GoogleSignIn.instance.initialize(
      clientId: OAuthConfig.googleIosClientId,
      serverClientId: OAuthConfig.googleWebClientId,
    );
    _googleInitialization = initialization;
    try {
      await initialization;
    } catch (_) {
      if (identical(_googleInitialization, initialization)) {
        _googleInitialization = null;
      }
      rethrow;
    }
  }

  /// Supabase requires both Google tokens. In google_sign_in 7,
  /// authentication supplies the ID token while authorization supplies the
  /// access token, so request the email scope as part of the same user action.
  static Future<(GoogleSignInAccount, String, String)>
  _googleCredentials() async {
    await _ensureGoogleInitialized();
    final account = await GoogleSignIn.instance.authenticate(
      scopeHint: _googleScopes,
    );
    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw const GoogleSignInException(
        code: GoogleSignInExceptionCode.unknownError,
        description: 'Google returned no ID token.',
      );
    }

    final authorization =
        await account.authorizationClient.authorizationForScopes(
          _googleScopes,
        ) ??
        await account.authorizationClient.authorizeScopes(_googleScopes);
    return (account, idToken, authorization.accessToken);
  }

  static Future<SelahAuthResult> signInWithGoogle() async {
    if (!OAuthConfig.isGoogleConfigured) {
      return const SelahAuthResult.error(
        'Google sign-in isn\'t set up yet on this build — the Founder needs to add real Google OAuth client IDs.',
      );
    }
    try {
      final (googleUser, idToken, accessToken) = await _googleCredentials();

      await supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );
      await _rememberProviderFirstName(googleUser.displayName);
      return const SelahAuthResult.success();
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) {
        return const SelahAuthResult.cancelled();
      }
      debugPrint('SELAH Google sign-in failed: $error');
      return const SelahAuthResult.error("That didn't work. Please try again.");
    } on AuthException catch (e) {
      return SelahAuthResult.error(_mapError(e));
    } catch (error) {
      debugPrint('SELAH Google sign-in failed unexpectedly: $error');
      return const SelahAuthResult.error(
        'Having trouble connecting. Check your connection and try again.',
      );
    }
  }

  static Future<SelahAuthResult> signInWithApple() async {
    try {
      // Keep nonce creation on Supabase's maintained implementation so the
      // native Apple request and the subsequent token exchange cannot drift
      // onto subtly different nonce formats.
      final rawNonce = supabase.auth.generateRawNonce();
      final hashedNonce = _sha256(rawNonce);

      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );

      final idToken = credential.identityToken;
      if (idToken == null) {
        return const SelahAuthResult.error(
          "That didn't work. Please try again.",
        );
      }

      await supabase.auth.signInWithIdToken(
        provider: OAuthProvider.apple,
        idToken: idToken,
        nonce: rawNonce,
      );
      await _rememberProviderFirstName(credential.givenName);
      return const SelahAuthResult.success();
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        return const SelahAuthResult.cancelled();
      }
      debugPrint('SELAH Apple sign-in authorization failed: $e');
      return const SelahAuthResult.error("That didn't work. Please try again.");
    } on AuthException catch (e) {
      debugPrint('SELAH Apple token exchange failed: $e');
      return SelahAuthResult.error(_mapError(e));
    } catch (error) {
      debugPrint('SELAH Apple sign-in failed unexpectedly: $error');
      return const SelahAuthResult.error(
        'Having trouble connecting. Check your connection and try again.',
      );
    }
  }

  /// Adds Google as another way into the CURRENT SELAH account. This is not
  /// a sign-in and must never be replaced with signInWithIdToken here: the
  /// latter can switch sessions and strand the original profile. Supabase's
  /// linkIdentityWithIdToken keeps both provider identities under one user id.
  static Future<SelahAuthResult> linkGoogleIdentity() async {
    if (!isSignedIn) {
      return const SelahAuthResult.error(
        'Sign in again before adding a backup method.',
      );
    }
    if (linkedProviders.contains('google')) {
      return const SelahAuthResult.success();
    }
    if (!OAuthConfig.isGoogleConfigured) {
      return const SelahAuthResult.error(
        "Google sign-in isn't set up yet on this build.",
      );
    }

    try {
      final (_, idToken, accessToken) = await _googleCredentials();

      await supabase.auth.linkIdentityWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );
      return const SelahAuthResult.success();
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) {
        return const SelahAuthResult.cancelled();
      }
      debugPrint('SELAH Google identity linking failed: $error');
      return const SelahAuthResult.error("That didn't work. Please try again.");
    } on AuthException catch (error) {
      return SelahAuthResult.error(_mapLinkError(error));
    } catch (error) {
      debugPrint('SELAH Google identity linking failed unexpectedly: $error');
      return const SelahAuthResult.error(
        'Having trouble connecting. Check your connection and try again.',
      );
    }
  }

  /// Apple equivalent of [linkGoogleIdentity]. The nonce is required for
  /// replay protection exactly as it is in the normal Apple sign-in flow.
  static Future<SelahAuthResult> linkAppleIdentity() async {
    if (!isSignedIn) {
      return const SelahAuthResult.error(
        'Sign in again before adding a backup method.',
      );
    }
    if (linkedProviders.contains('apple')) {
      return const SelahAuthResult.success();
    }

    try {
      final rawNonce = supabase.auth.generateRawNonce();
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: _sha256(rawNonce),
      );
      final idToken = credential.identityToken;
      if (idToken == null) {
        return const SelahAuthResult.error(
          "That didn't work. Please try again.",
        );
      }

      await supabase.auth.linkIdentityWithIdToken(
        provider: OAuthProvider.apple,
        idToken: idToken,
        nonce: rawNonce,
      );
      return const SelahAuthResult.success();
    } on SignInWithAppleAuthorizationException catch (error) {
      if (error.code == AuthorizationErrorCode.canceled) {
        return const SelahAuthResult.cancelled();
      }
      debugPrint('SELAH Apple identity linking authorization failed: $error');
      return const SelahAuthResult.error("That didn't work. Please try again.");
    } on AuthException catch (error) {
      debugPrint('SELAH Apple identity linking token exchange failed: $error');
      return SelahAuthResult.error(_mapLinkError(error));
    } catch (error) {
      debugPrint('SELAH Apple identity linking failed unexpectedly: $error');
      return const SelahAuthResult.error(
        'Having trouble connecting. Check your connection and try again.',
      );
    }
  }

  /// Starts an authenticated email change. Supabase confirms the new address
  /// and, when Secure Email Change is enabled, also confirms the current one.
  /// Once complete it creates/updates the email identity on this same user.
  static Future<SelahAuthResult> requestRecoveryEmail(String email) async {
    final normalised = email.trim().toLowerCase();
    if (!isSignedIn) {
      return const SelahAuthResult.error(
        'Sign in again before adding a recovery email.',
      );
    }
    if (!hasLinkedOAuth) {
      return const SelahAuthResult.error(
        'A recovery email can only be added to an Apple or Google account.',
      );
    }
    if (!isValidEmail(normalised)) {
      return const SelahAuthResult.error('Enter a valid email address.');
    }
    if (currentUser?.email?.toLowerCase() == normalised) {
      return const SelahAuthResult.error(
        'Choose a different email address for recovery.',
      );
    }

    try {
      await supabase.auth.updateUser(UserAttributes(email: normalised));
      return const SelahAuthResult.success();
    } on AuthException catch (error) {
      return SelahAuthResult.error(_mapEmailError(error));
    } catch (_) {
      return const SelahAuthResult.error(
        'Having trouble connecting. Check your connection and try again.',
      );
    }
  }

  static Future<SelahAuthResult> verifyRecoveryEmailCode({
    required String email,
    required String code,
  }) async {
    try {
      await supabase.auth.verifyOTP(
        email: email.trim().toLowerCase(),
        token: code.trim(),
        type: OtpType.emailChange,
      );
      return const SelahAuthResult.success();
    } on AuthException catch (error) {
      return SelahAuthResult.error(_mapEmailError(error));
    } catch (_) {
      return const SelahAuthResult.error(
        'Having trouble connecting. Check your connection and try again.',
      );
    }
  }

  static Future<bool> isRecoveryEmailVerified(String email) async {
    final normalised = email.trim().toLowerCase();
    try {
      final identities = await supabase.auth.getUserIdentities();
      return identities.any((identity) {
        if (identity.provider != 'email') return false;
        return identity.identityData?['email']?.toString().toLowerCase() ==
            normalised;
      });
    } catch (_) {
      return recoveryEmail?.toLowerCase() == normalised;
    }
  }

  /// Passwordless recovery only. shouldCreateUser=false is the critical
  /// duplicate-account guard: a typo or unknown address gets the same calm UI
  /// response but can never create a new auth.users/profile identity.
  static Future<SelahAuthResult> sendRecoverySignInCode(String email) async {
    final normalised = email.trim().toLowerCase();
    if (!isValidEmail(normalised)) {
      return const SelahAuthResult.error('Enter a valid email address.');
    }
    try {
      await supabase.auth.signInWithOtp(
        email: normalised,
        shouldCreateUser: false,
      );
      return const SelahAuthResult.success();
    } on AuthException catch (error) {
      return SelahAuthResult.error(_mapEmailError(error));
    } catch (_) {
      return const SelahAuthResult.error(
        'Having trouble connecting. Check your connection and try again.',
      );
    }
  }

  static Future<SelahAuthResult> verifyRecoverySignInCode({
    required String email,
    required String code,
  }) async {
    try {
      final startingUserId = currentUser?.id;
      final startingGeneration = SelahAccountState.generation;
      if (SelahAccountState.isSigningOut) {
        return const SelahAuthResult.cancelled();
      }
      final response = await supabase.auth.verifyOTP(
        email: email.trim().toLowerCase(),
        token: code.trim(),
        type: OtpType.email,
      );
      if (response.session == null || response.user == null) {
        return const SelahAuthResult.error(
          "That code couldn't sign you in. Please request a new one.",
        );
      }
      final verifiedUserId = response.user!.id;
      final generation = SelahAccountState.generation;
      // The SDK applies the Auth session before returning. Permit only its
      // intended first sign-in transition, never a superseded local handoff.
      final unchanged = generation == startingGeneration;
      final firstSignIn =
          startingUserId == null &&
          generation == startingGeneration + 1 &&
          SelahAccountState.userId == verifiedUserId;
      if (SelahAccountState.isSigningOut ||
          currentUser?.id != verifiedUserId ||
          response.session!.user.id != verifiedUserId ||
          (!unchanged && !firstSignIn) ||
          (startingUserId != null && startingUserId != verifiedUserId)) {
        return const SelahAuthResult.cancelled();
      }
      return SelahAuthResult.success(authenticatedUserId: verifiedUserId);
    } on AuthException catch (error) {
      return SelahAuthResult.error(_mapEmailError(error));
    } catch (_) {
      return const SelahAuthResult.error(
        'Having trouble connecting. Check your connection and try again.',
      );
    }
  }

  // 2026-07-19: guarded against overlapping calls, same root cause as the
  // developer_access_screen.dart crash fixed earlier today. Any duplicate/
  // overlapping tap on a Sign Out button (profile_screen.dart,
  // mentor_profile_screen.dart both call this with no guard of their own)
  // raced two concurrent supabase.auth.signOut() calls at the native
  // layer and killed the app with no Dart exception. Fixing it here,
  // inside SelahAuth itself, protects every call site — present and
  // future — rather than requiring each screen to remember its own guard.
  static bool _signingOut = false;

  static void _requireSignOutPrincipal(String? expectedUserId) {
    if (expectedUserId == null) return;
    if (currentUser?.id != expectedUserId) {
      throw StateError('The authenticated principal changed before sign-out.');
    }
  }

  static Future<void> _forgetGoogleAccount() async {
    final testAction = _googleSignOutForTesting;
    if (testAction != null) {
      await testAction();
      return;
    }
    await _ensureGoogleInitialized();
    await GoogleSignIn.instance.signOut();
  }

  static Future<void> signOut({String? expectedUserId}) async {
    // Founder authority is proof from one successfully refreshed session. It
    // must disappear before sign-out begins — including duplicate calls and
    // failed network sign-outs — so same-process reauthentication cannot
    // inherit the previous principal's proof.
    SelahDeveloperAccess.clearRefreshedClaims();
    SelahDeveloperAccess.clearExternalTesterAuthorization();
    if (_signingOut) return;
    _requireSignOutPrincipal(expectedUserId);
    _signingOut = true;
    final signingOutUserId = currentUser?.id;
    final forgetGoogleAccount = linkedProviders.contains('google');
    // Invalidate displayed data and pending-result generations before either
    // protected-draft cleanup or remote Auth work can yield.
    final accountCleanup = SelahAccountState.beginSignOut();
    try {
      // Supabase owns the SELAH session, while google_sign_in separately keeps
      // the most recently authenticated Google account for this app. Clear
      // that app-local chooser state so "Use a different account" cannot
      // silently authenticate the same Google identity again. This is best
      // effort and deliberately uses signOut(), not disconnect(), so no
      // Google permission grant is revoked and a plugin failure cannot block
      // SELAH's own secure cleanup.
      if (forgetGoogleAccount) {
        try {
          await _forgetGoogleAccount();
        } catch (error) {
          debugPrint(
            'SELAH Google app-local sign-out failed (${error.runtimeType}).',
          );
        }
      }
      // Explicit sign-out erases only this account's device-local signup
      // draft, while we can still bind deletion to its authenticated owner.
      // Queueing behind in-flight writes prevents a late save resurrecting it.
      if (signingOutUserId != null &&
          !SelahInternalPreviewClient.isActive &&
          SelahInitialSignupDraftService.supportedOnThisPlatform) {
        await SelahInitialSignupDraftService.repository.signOut(
          signingOutUserId,
          () {
            _requireSignOutPrincipal(expectedUserId);
            return supabase.auth.signOut(scope: SignOutScope.local);
          },
        );
      } else {
        _requireSignOutPrincipal(expectedUserId);
        await supabase.auth.signOut(scope: SignOutScope.local);
      }
      await accountCleanup;
      if (SelahAuth.currentUser == null && SelahInternalPreviewClient.isActive) {
        // Cleanup never releases the denial latch after failed remote logout.
        // Successful sign-out has already reset member and sample state.
        SelahInternalPreviewClient.finishSignOut();
      }
    } finally {
      SelahDeveloperAccess.clearRefreshedClaims();
      SelahAccountState.endSignOutAttempt();
      _signingOut = false;
    }
  }

  /// #22 — real account deletion. Cleans up the user's own photo files
  /// in Storage first (while the session is still valid — the
  /// `profile-photos` bucket's RLS delete policy is scoped to the
  /// caller's own folder), then calls delete_own_account(), which
  /// deletes the auth.users row and cascades through every table that
  /// references it (profiles, matches, messages, mentor_links,
  /// subscriptions, notifications, etc. — see
  /// 20260726170000_delete_own_account.sql for the full verified
  /// list). Signs out the same account after successful deletion. A later
  /// sign-in must never become the target of this account's pending work.
  ///
  /// Returns true on success. On failure, the account is NOT deleted
  /// (the RPC's own exception aborts its transaction) — safe to retry.
  static Future<bool> deleteAccount() async {
    final user = currentUser;
    if (user == null) return false;
    final generation = SelahAccountState.generation;
    bool stillOwner() =>
        currentUser?.id == user.id &&
        SelahAccountState.generation == generation &&
        !SelahAccountState.isSigningOut;
    try {
      try {
        final rows =
            await supabase
                    .from('profile_photos')
                    .select('storage_path')
                    .eq('user_id', user.id)
                as List;
        final paths = rows
            .map((r) => (r as Map<String, dynamic>)['storage_path'] as String)
            .toList();
        if (!stillOwner()) return false;
        if (paths.isNotEmpty) {
          await supabase.storage.from('profile-photos').remove(paths);
        }
      } catch (error) {
        // Best-effort — a photo-cleanup failure shouldn't block account
        // deletion itself; delete_own_account()'s own storage.objects
        // cleanup by path prefix is a second, server-side attempt at
        // the same thing.
        debugPrint(
          'SELAH account photo cleanup could not complete (${error.runtimeType}).',
        );
      }
      if (!stillOwner()) return false;
      final deletionSession = supabase.auth.currentSession;
      if (deletionSession == null ||
          deletionSession.user.id != user.id ||
          deletionSession.expiresAt == null ||
          deletionSession.isExpired) {
        return false;
      }
      // AuthHttpClient may await a token refresh before dispatch. Pin this
      // destructive builder to the captured owner, never a subsequently
      // signed-in principal. The token remains in memory and is never logged.
      await supabase
          .rpc('delete_own_account')
          .setHeader('Authorization', 'Bearer ${deletionSession.accessToken}');
      // The RPC was sent as the original account. Preserve a different
      // account that signed in while its response was in flight.
      if (stillOwner()) {
        try {
          await signOut(expectedUserId: user.id);
        } catch (error) {
          // Deletion has already succeeded; do not tell the member it failed
          // merely because local/provider cleanup failed afterwards.
          debugPrint(
            'SELAH deleted-account sign-out could not complete (${error.runtimeType}).',
          );
        }
      }
      return true;
    } catch (e) {
      // 2026-08-12: an erasure failure was indistinguishable from a
      // refusal, with nothing logged anywhere (CLAUDE.md §3). Still
      // returns false — the UI copy handles it — but no longer invisible.
      debugPrint('SELAH delete_own_account failed: $e');
      return false;
    }
  }

  static String _sha256(String input) =>
      sha256.convert(utf8.encode(input)).toString();

  static String _mapLinkError(AuthException error) {
    final message = error.message.toLowerCase();
    if (message.contains('manual') ||
        message.contains('linking') && message.contains('disabled')) {
      return 'Backup sign-in is not enabled on this build yet.';
    }
    if (message.contains('already') || message.contains('identity')) {
      return 'That sign-in is already connected to a SELAH account.';
    }
    return _mapError(error);
  }

  static String _mapEmailError(AuthException error) {
    final message = error.message.toLowerCase();
    if (message.contains('expired') ||
        message.contains('invalid') ||
        message.contains('token')) {
      return "That code has expired or isn't correct. Request a new one.";
    }
    if (message.contains('rate') || message.contains('seconds')) {
      return 'Please wait a minute before requesting another code.';
    }
    if (message.contains('already') ||
        message.contains('exists') ||
        message.contains('registered')) {
      return 'That email is already connected to another SELAH account.';
    }
    return _mapError(error);
  }

  /// Maps Supabase's own error strings onto ERROR_AND_EMPTY_STATE_
  /// STANDARD's Category 2 copy (inherited decision 080). Worth re-checking
  /// against real responses once OAuth is actually configured and
  /// tested — this is written defensively, not from observed errors.
  static String _mapError(AuthException e) {
    final msg = e.message.toLowerCase();
    if (msg.contains('provider') &&
        (msg.contains('not enabled') || msg.contains('disabled'))) {
      return "This sign-in method isn't turned on yet for this build.";
    }
    return "Something didn't quite work. Please try again — and if it keeps happening, let us know.";
  }
}
