// Decides which screen a signed-in user lands on — used both right
// after sign-in (welcome_screen.dart, Google/Apple OAuth) and on cold
// app start when an existing session is found (auth_gate.dart), so
// both paths agree.
//
// Looks up the `profiles` row for the current session: role='seeker'
// -> HomeShell, role='mentor' -> MentorHomeShell. A Seeker with a profile row but
// unfinished long-form onboarding enters Dashboard and resumes there. Initial
// setup resumes from a protected same-device draft; an older IDV attempt can
// resume its server checkpoint even where the earlier app lost form answers.

import 'selah_local_prefs.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import '../main.dart';
import '../models/selah_error_state.dart';
import '../screens/auth/role_selection_screen.dart';
import '../dev/selah_founder_launch_screen.dart';
import '../screens/home/home_shell.dart';
import '../screens/onboarding/identity_verification_screen.dart';
import '../screens/onboarding/onboarding_flow.dart';
import '../screens/subscription/membership_required_screen.dart';
import '../screens/mentor/mentor_onboarding_flow.dart';
import '../models/selah_initial_signup_draft.dart';
import '../screens/mentor/mentor_home_shell.dart';
import '../state/app_state.dart';
import '../constants/selah_plan_names.dart';
import '../data/selah_release_gates.dart';
import 'selah_auth.dart';
import 'selah_account_state.dart';
import 'selah_discovery_service.dart';
import 'selah_developer_access.dart';
import 'selah_unlock_service.dart';
import 'selah_profile_service.dart';
import 'selah_identity_verification_service.dart';
import 'selah_identity_admission_policy.dart';
import 'selah_initial_signup_draft_service.dart';

class SelahSessionRouter {
  SelahSessionRouter._();

  static const readTimeout = Duration(seconds: 10);
  static Duration _effectiveReadTimeout = readTimeout;

  @visibleForTesting
  static void setReadTimeoutForTesting(Duration? value) {
    assert(() {
      _effectiveReadTimeout = value ?? readTimeout;
      return true;
    }());
  }

  static Future<Widget> resolveHome() async {
    final user = SelahAuth.currentUser;
    final cleanup = SelahAccountState.synchronize(user?.id);
    final generation = SelahAccountState.generation;
    await cleanup.timeout(_effectiveReadTimeout);
    if (user == null) {
      if (SelahAccountState.generation != generation ||
          SelahAuth.currentUser != null) {
        throw StateError('Session expired during account routing.');
      }
      return const RoleSelectionScreen(); // shouldn't be reached without a session; safe fallback
    }
    final userId = user.id;
    _requireCurrent(userId, generation);

    // Fresh operator proof is checked before ordinary member routing.
    final authorization =
        await SelahDeveloperAccess.refreshCurrentAuthorizationSnapshot();
    _requireCurrent(userId, generation);

    if (authorization.founderAuthorized &&
        SelahDeveloperAccess.isAuthorizedOperator) {
      // The Founder approved switching the opening presentation, not granting
      // synthetic request data to real members. This guarded local entry owns
      // a fresh-launch reset to the new style. Option 1 remains available for
      // in-session comparison; member routing is unchanged.
      return SelahFounderLaunchScreen(
        ownerId: userId,
        ownerGeneration: generation,
      );
    }
    _requireMember(userId, generation);

    var resolvingSignup = false;
    var checkingIdentityGate = false;
    final identityGateEnabled =
        SelahIdentityVerificationService.enforceExistingAccountGate;
    var identityGatePassed = !identityGateEnabled;
    try {
      // FIXED 2026-08-01 (Founder: "the first time it loads it loads the
      // user page but with the OLD PURPLE background... I have to keep
      // clicking the homepage and selecting user for it to refresh").
      //
      // ROOT CAUSE: AppState was only ever written by onboarding
      // (saveChapter1) or by Developer Access (applyDevPreset). NOTHING
      // read it back from the database. So on every cold start with a
      // persisted session, the singleton was completely empty —
      // AppState.gender was null, SelahColors.genderGradient(null)
      // returned the NEUTRAL brand gradient, and every profile-context
      // screen rendered the pre-auth purple instead of the ratified
      // male-blue / female-pink (inherited decision 094). Picking a user in
      // Developer Access "fixed" it only because applyDevPreset happens
      // to set gender — hence the refresh dance.
      //
      // The gradient was the visible symptom; it was not the worst part.
      // The same emptiness meant, on every relaunch:
      //   • Profile showed "Your Profile" instead of the user's name
      //   • Location showed "—", age row vanished entirely
      //   • plan defaulted to SelahPlan.basic — so a REAL SELAH One
      //     subscriber saw sponsored cards, hit the daily Browse limit,
      //     and was refused Pause Journey until they happened to visit a
      //     screen that reset it. A paying user silently losing their
      //     entitlement on every launch.
      //
      // Fetched here because this is the single cold-start path (AuthGate
      // -> resolveHome) and it already had to read `profiles` for
      // routing. Widening that existing round trip costs nothing extra.
      //
      // NOTE: date_of_birth is deliberately NOT selected — that column's
      // client SELECT was revoked (audit C2). Age comes from ages_for(),
      // the same SECURITY DEFINER function Browse and Matches use.
      final row = await supabase
          .from('profiles')
          // surname_line ADDED 2026-08-07. It was already selectable and
          // already read by Browse for everyone ELSE — the owner's own
          // profile page was the one place still showing a bare first name.
          .select('role, first_name, surname_line, gender, location_text')
          .eq('id', userId)
          .maybeSingle()
          .timeout(_effectiveReadTimeout);
      _requireMember(userId, generation);
      if (row == null) {
        // New-account recovery is independent of the existing-member rollout
        // fuse. Its errors must never enter a remembered-role shell.
        resolvingSignup = true;
        return await _resolveInitialSignup(userId, generation);
      }

      if (SelahInitialSignupDraftService.supportedOnThisPlatform) {
        resolvingSignup = true;
        final unfinished = await SelahInitialSignupDraftService.repository
            .read(userId)
            .timeout(_effectiveReadTimeout);
        _requireMember(userId, generation);
        if (unfinished != null) {
          final expectedRole = unfinished.role == SelahSignupRole.seeker
              ? 'seeker'
              : 'mentor';
          if (row['role'] != expectedRole) {
            throw StateError(
              'Signup recovery role does not match this account.',
            );
          }
          return await _resolveInitialSignup(
            userId,
            generation,
            restoredDraft: unfinished,
            recoverExistingPhoto: true,
          );
        }
        // Same-device partial finalization survives a deliberate sign-out
        // without retaining private form answers or photo capabilities. This
        // narrow recovery marker never gates unrelated existing accounts and
        // is not server/identity proof or a cross-device admission guarantee.
        final pendingRole = await _pendingSignupRole(userId, generation);
        if (pendingRole != null) {
          final expectedRole = pendingRole == SelahSignupRole.seeker
              ? 'seeker'
              : 'mentor';
          if (row['role'] != expectedRole) {
            throw StateError(
              'Signup recovery role does not match this account.',
            );
          }
          return _pendingSignupFlow(userId, pendingRole);
        }
        resolvingSignup = false;
      }

      checkingIdentityGate = true;
      final blocked = await _existingIdentityGate(userId, generation);
      _requireMember(userId, generation);
      checkingIdentityGate = false;
      if (blocked != null) return blocked;
      identityGatePassed = true;

      // A crash after server creation but before draft erasure must not leave
      // private signup data indefinitely. Here the secure read already proved
      // there is no unfinished account checkpoint; no draft grants access.
      if (SelahInitialSignupDraftService.supportedOnThisPlatform) {
        try {
          await SelahInitialSignupDraftService.repository
              .clear(userId)
              .timeout(_effectiveReadTimeout);
          _requireMember(userId, generation);
        } catch (_) {
          debugPrint(
            'SELAH: completed signup draft cleanup could not be confirmed.',
          );
        }
      }
      _requireMember(userId, generation);

      final role = row['role'] as String?;
      if (SelahReleaseGates.paidOnlyMembershipEnforced) {
        final paid = await _hasPaidRole(role).timeout(_effectiveReadTimeout);
        _requireMember(userId, generation);
        if (!paid) {
          AppState.instance.hydrateFrom(
            name: row['first_name'] as String?,
            surnameLine: row['surname_line'] as String?,
            gender: row['gender'] as String?,
            location: row['location_text'] as String?,
            plan: SelahPlan.basic,
          );
          return MembershipRequiredScreen(shepherd: role == 'mentor');
        }
      }

      await _hydrate(userId, generation, row);
      _requireMember(userId, generation);

      // Remembered for the failure path below — see there for why.
      SelahLocalPrefs.setCachedRole(role);
      if (role == 'mentor') return const MentorHomeShell();

      // Dashboard is the normal authenticated landing surface. Progressive
      // onboarding also resumes there, where the saved setup journey can be
      // continued. Auth, missing-profile and operator routes above remain
      // explicit exceptions; deep links push their own destination and do not
      // resolve through this cold-start default.
      final onboarding = await SelahProfileService.fetchOnboardingProgress()
          .timeout(_effectiveReadTimeout);
      _requireMember(userId, generation);
      return HomeShell(initialTab: 2, initialOnboardingProgress: onboarding);
    } catch (e) {
      // Never let an old account's cached role, failed refresh or preview
      // denial turn into a member shell after an asynchronous boundary.
      _requireMember(userId, generation);
      if (resolvingSignup || checkingIdentityGate || !identityGatePassed) {
        rethrow;
      }
      // A failed profile read must not bypass a partly-created account by
      // opening its remembered shell. Check only owner-bound recovery state:
      // no draft answers are hydrated or displayed on this failure path.
      if (SelahInitialSignupDraftService.supportedOnThisPlatform) {
        final repository = SelahInitialSignupDraftService.repository;
        final unfinished = await repository
            .read(userId)
            .timeout(_effectiveReadTimeout);
        _requireMember(userId, generation);
        repository.requireOwner(userId);
        final pendingRole = await _pendingSignupRole(userId, generation);
        if (unfinished != null || pendingRole != null) rethrow;
      }
      // FALLS BACK TO THE REMEMBERED ROLE — 2026-08-14 (inherited decision 166).
      //
      // This returned HomeShell unconditionally. A Shepherd whose profile
      // lookup failed — a network hiccup, an RLS change, a cold start on
      // a bad connection — was handed the SEEKER app: Browse, a swipe
      // deck, Connections. Not a degraded Shepherd experience; someone
      // else's product. The 2026-08-12 pass logged this and left the
      // behaviour, which made it visible without making it right.
      //
      // The cache is written on every successful resolve, so any device
      // that has signed in once knows what it is. A remembered role is a
      // strictly better guess than a hardcoded one, and on a device that
      // has never resolved a role there is nothing to go on and the old
      // default stands.
      final remembered = SelahLocalPrefs.cachedRole;
      // A remembered role can safely open its own shell through an ordinary
      // connection hiccup. With no remembered role, guessing "Seeker" can
      // expose the wrong product to a Shepherd; and an expired session must
      // always return to sign-in rather than opening a cached shell. Let
      // AuthGate present the approved full-screen recovery in both cases.
      if (remembered == null ||
          selahErrorKindFor(e) == SelahErrorKind.sessionExpired) {
        debugPrint(
          'SELAH resolveHome failed [${selahErrorReference(e)}] '
          '(${e.runtimeType}) — recovery page required.',
        );
        rethrow;
      }
      debugPrint(
        'SELAH resolveHome failed [${selahErrorReference(e)}] '
        '(${e.runtimeType}) — falling back to $remembered.',
      );
      return remembered == 'mentor' ? const MentorHomeShell() : const HomeShell();
    }
  }

  static void _requireCurrent(String userId, int generation) {
    if (!SelahAccountState.isCurrent(userId, generation) ||
        SelahAuth.currentUser?.id != userId) {
      throw StateError('Session expired during account routing.');
    }
  }

  static void _requireMember(String userId, int generation) {
    _requireCurrent(userId, generation);
    if (SelahDeveloperAccess.blocksMemberRouting) {
      throw const SelahPreviewAuthorizationException();
    }
  }

  static Future<bool> _hasPaidRole(String? role) async {
    if (role != 'seeker' && role != 'mentor') return false;
    try {
      final value = await supabase.rpc(
        'selah_my_paid_access',
        params: {'p_role': role == 'mentor' ? 'shepherd' : 'seeker'},
      );
      return value == true;
    } catch (error) {
      debugPrint(
        'SELAH paid membership check failed closed '
        '(${error.runtimeType}).',
      );
      return false;
    }
  }

  static Future<Widget?> _existingIdentityGate(
    String userId,
    int generation,
  ) async {
    final enabled = SelahIdentityVerificationService.enforceExistingAccountGate;
    if (!enabled) return null;
    final verification = await SelahIdentityVerificationService.fetchMyState(
      expectedUserId: userId,
    ).timeout(_effectiveReadTimeout);
    _requireMember(userId, generation);
    if (SelahIdentityAdmissionPolicy.allowsExistingAccountEntry(
      productionRolloutEnabled: enabled,
      state: verification,
    )) {
      return null;
    }
    return InitialIdentityCheckScreen(
      initialState: verification,
      onContinue: (context) async {
        _requireMember(userId, generation);
        final home = await resolveHome();
        _requireMember(userId, generation);
        if (!context.mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => home),
          (_) => false,
        );
      },
    );
  }

  static Future<Widget> _resolveInitialSignup(
    String userId,
    int generation, {
    SelahInitialSignupDraft? restoredDraft,
    bool recoverExistingPhoto = false,
  }) async {
    final repository = SelahInitialSignupDraftService.repository;
    final draft =
        restoredDraft ??
        await repository.read(userId).timeout(_effectiveReadTimeout);
    _requireMember(userId, generation);
    repository.requireOwner(userId);
    final pendingRole = await _pendingSignupRole(userId, generation);
    if (draft != null) {
      if (pendingRole != null && draft.role != pendingRole) {
        throw StateError('Signup recovery role does not match this draft.');
      }
      final verification = draft.awaitsVerification
          ? await SelahIdentityVerificationService.fetchMyState(
              expectedUserId: userId,
            ).timeout(_effectiveReadTimeout)
          : null;
      _requireMember(userId, generation);
      repository.requireOwner(userId);
      return draft.role == SelahSignupRole.seeker
          ? OnboardingFlow(
              initialDraft: draft,
              signupUserId: userId,
              initialVerificationState: verification,
              recoverExistingPhoto: recoverExistingPhoto,
            )
          : MentorOnboardingFlow(
              initialDraft: draft,
              signupUserId: userId,
              initialVerificationState: verification,
              recoverExistingPhoto: recoverExistingPhoto,
            );
    }
    if (pendingRole != null) {
      return _pendingSignupFlow(userId, pendingRole);
    }
    // Builds before protected recovery saved consent, but not account details.
    // Resume the real server check; never fabricate the lost form answers.
    final verification = await SelahIdentityVerificationService.fetchMyState(
      expectedUserId: userId,
    ).timeout(_effectiveReadTimeout);
    _requireMember(userId, generation);
    repository.requireOwner(userId);
    if (verification == null) return const RoleSelectionScreen();
    const recovery = RoleSelectionScreen(
      recoveryNotice:
          'Your identity result is saved. This earlier app version did not save '
          'your account details on this device. Please enter them once more to finish setup.',
    );
    if (verification.allowsApp) return recovery;
    return InitialIdentityCheckScreen(
      initialState: verification,
      onContinue: (context) async {
        _requireMember(userId, generation);
        repository.requireOwner(userId);
        final fresh = await SelahIdentityVerificationService.fetchMyState(
          expectedUserId: userId,
        ).timeout(_effectiveReadTimeout);
        _requireMember(userId, generation);
        repository.requireOwner(userId);
        if (fresh?.allowsApp != true || !context.mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => recovery),
          (_) => false,
        );
      },
    );
  }

  /// An opaque, same-device retry only. Neither marker can prove a member's
  /// role or identity, and conflicting markers cannot choose one silently.
  static Future<SelahSignupRole?> _pendingSignupRole(
    String userId,
    int generation,
  ) async {
    final repository = SelahInitialSignupDraftService.repository;
    repository.requireOwner(userId);
    final seeker = await repository
        .readPendingSeekerFinalization(userId)
        .timeout(_effectiveReadTimeout);
    _requireMember(userId, generation);
    repository.requireOwner(userId);
    final shepherd = await repository
        .readPendingShepherdFinalization(userId)
        .timeout(_effectiveReadTimeout);
    _requireMember(userId, generation);
    repository.requireOwner(userId);
    if (seeker && shepherd) {
      throw StateError('Conflicting signup recovery markers.');
    }
    return seeker
        ? SelahSignupRole.seeker
        : shepherd
        ? SelahSignupRole.shepherd
        : null;
  }

  static Widget _pendingSignupFlow(String userId, SelahSignupRole role) =>
      role == SelahSignupRole.seeker
      ? OnboardingFlow(signupUserId: userId, recoverExistingPhoto: true)
      : MentorOnboardingFlow(signupUserId: userId, recoverExistingPhoto: true);

  /// Best-effort population of AppState. Deliberately never throws: a
  /// failure here degrades the app to its old behaviour (neutral
  /// gradient, Basic plan) rather than blocking sign-in, which is what
  /// resolveHome's own catch is protecting against.
  static Future<void> _hydrate(
    String userId,
    int generation,
    Map<String, dynamic> row,
  ) async {
    int? age;
    SelahPlan? plan;

    // PARALLEL, not sequential — 2026-08-01 (Founder: "when the app loads
    // it still switches from purple to pink on the user for about a
    // second").
    //
    // That flash is the cold-start wait: main.dart's `builder:` paints the
    // NEUTRAL brand gradient behind everything, and the gender-matched
    // gradient can only replace it once we know the gender, which needs a
    // round trip. My first version of this method made it worse by adding
    // two MORE sequential round trips after the profile read — three trips
    // of latency stacked end to end, all of them blocking the first paint.
    //
    // Neither of these is needed to resolve the gradient, so they run
    // together instead of one after the other: total wait is now one round
    // trip, not three.
    //
    // FULLY removing the flash needs the gender cached on-device so launch
    // N+1 paints correctly with no network at all. That means adding
    // shared_preferences as a direct dependency — a call worth making
    // deliberately rather than slipping into a UI fix, so it is not done
    // here. Flagged for the Founder.
    await Future.wait([
      () async {
        try {
          // ages_for_one, not ages_for — one id, one visibility
          // hypothesis (I10, 2026-08-08). The batch form is now capped at
          // 50 and reserved for callers that genuinely have a page of ids.
          final one = await supabase
              .rpc('ages_for_one', params: {'p_id': userId})
              .timeout(_effectiveReadTimeout);
          _requireMember(userId, generation);
          if (one != null) age = (one as num).toInt();
        } catch (_) {
          _requireMember(userId, generation);
          // age stays null — Profile hides the row, nothing else needs it
        }
      }(),
      () async {
        try {
          // subscriptions has a UNIQUE index on (user_id) WHERE status =
          // 'active', so there is at most one row to find.
          final sub = await supabase
              .from('subscriptions')
              .select('plan_type')
              .eq('user_id', userId)
              .eq('status', 'active')
              .maybeSingle()
              .timeout(_effectiveReadTimeout);
          _requireMember(userId, generation);
          final planType = sub?['plan_type'] as String?;
          // Only seeker_premium maps to SELAH One. mentor_premium is the
          // Shepherd's own entitlement, resolved separately by
          // SelahEntitlementService.hasMentorOne(), not through AppState.plan.
          //
          // 2026-08-12: compares against the canonical db value from
          // constants/selah_plan_names.dart instead of a raw literal — that
          // file existed precisely for this and had zero importers.
          plan = planType == SelahSubscriptionPlanType.seekerPremium.dbValue
              ? SelahPlan.one
              : SelahPlan.basic;
        } catch (e) {
          _requireMember(userId, generation);
          debugPrint('SELAH plan fetch failed (${e.runtimeType}).');
          // plan stays null -> hydrateFrom leaves the existing default
        }
      }(),
    ]);
    _requireMember(userId, generation);

    AppState.instance.hydrateFrom(
      name: row['first_name'] as String?,
      surnameLine: row['surname_line'] as String?,
      gender: row['gender'] as String?,
      location: row['location_text'] as String?,
      age: age,
      plan: plan,
    );

    // DECISION HYDRATION — ADDED 2026-08-01.
    //
    // Founder, on device: "when I close the app the data goes. I'm
    // assuming this is temporary in dev mode and of course the real user
    // won't experience this."
    //
    // They would have. `saves`, `likes` and `passes` were all being
    // WRITTEN and none of them were ever READ BACK. AppState was filled
    // only by acting in Browse during that session, so every Connections
    // list emptied on relaunch while the rows sat in Postgres untouched.
    // Nothing about it was dev-only.
    //
    // Deliberately NOT inside the Future.wait above. Everything in that
    // block is needed to resolve the gender gradient and therefore blocks
    // first paint; this is not, and it is the heaviest call in the method
    // (three table reads, a profile read and a batched Storage signing
    // pass). Blocking launch on it would trade one bug for a slower cold
    // start — the exact mistake the note above records making once.
    //
    // Fire-and-forget with a notifyListeners() at the end, so Connections
    // fills in a beat after Home rather than delaying Home.
    unawaited(_hydrateDecisions(userId, generation));
  }

  /// Best-effort, never throws. A failure leaves the lists empty, which is
  /// the pre-2026-08-01 behaviour — degraded, not broken.
  static Future<void> _hydrateDecisions(String userId, int generation) async {
    try {
      _requireMember(userId, generation);
      // Unlocks load alongside decisions — both are "what has this Seeker
      // already done", both are needed before Connections renders, and
      // neither blocks first paint.
      await SelahUnlockService.load();
      _requireMember(userId, generation);
      final d = await SelahDiscoveryService.fetchDecisions().timeout(
        _effectiveReadTimeout,
      );
      _requireMember(userId, generation);
      AppState.instance.hydrateDecisions(
        saved: d.saved,
        considered: d.considered,
        passed: d.passed,
      );
    } catch (_) {
      debugPrint('SELAH decision hydration did not complete for its account.');
    }
  }
}
