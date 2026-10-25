// Writes the `profiles` row once onboarding has collected the fields
// the schema requires (SELAH_DATABASE_SCHEMA_CURRENT_VERSION_V1.md —
// first_name, date_of_birth, gender are all NOT NULL). Called from
// OnboardingFlow (Seeker, Chapter 1 completion) and MentorOnboardingFlow
// (Mentor, onboarding completion).
//
// Guarded by SelahAuth.isSignedIn throughout this build: if Supabase
// isn't configured, or the user reached onboarding without a real
// session (shouldn't happen in the real flow, but the mock/dev-access
// jump-menu can land here directly for testing), this silently no-ops
// rather than throwing — AppState's in-memory fields keep working
// exactly as before either way.

import 'package:flutter/foundation.dart' show debugPrint;
import '../main.dart';
import 'selah_account_state.dart';
import 'selah_auth.dart';
import 'selah_internal_preview_client.dart';

/// The three things a reset can do, kept apart because they need three
/// different sentences. A blocked reset is not a failure — it is the
/// feature working — and reporting it as "something went wrong" would send
/// someone to support over a rule we chose on purpose.
enum SelahResetOutcome { done, blockedByJourney, refused, failed }

class SelahResetResult {
  final SelahResetOutcome outcome;
  final int activeJourneys;
  const SelahResetResult(this.outcome, {this.activeJourneys = 0});
}

/// Server-owned progress for the deferred Seeker profile journey.
///
/// Account access and profile readiness are deliberately separate. A Seeker
/// may enter the app after the short account setup while this object remains
/// incomplete; Browse publication and Journey eligibility continue to use
/// the server's existing completeness gate.
class SelahOnboardingProgress {
  final bool complete;
  final int due;
  final int missing;
  final bool hasChapter2;
  final bool basicProfile;

  const SelahOnboardingProgress({
    required this.complete,
    required this.due,
    required this.missing,
    required this.hasChapter2,
    required this.basicProfile,
  });

  int get answered => (due - missing).clamp(0, due);
}

class SelahProfileService {
  SelahProfileService._();

  static Map<String, dynamic> createProfileParams({
    required String role,
    required String firstName,
    required String gender,
    required DateTime dob,
  }) => {
    'p_role': role,
    'p_first_name': firstName,
    'p_gender': gender,
    'p_dob': dob.toIso8601String().split('T').first,
  };

  /// Reset profile — start fresh without deleting the account.
  ///
  /// Founder decision 2026-08-07. Clears answers, details, photos, bio,
  /// location AND all discovery history in both directions — including
  /// other people's likes, saves and passes about this user, which is the
  /// only way "start fresh" actually means anything. Someone who has been
  /// passed over stays invisible to those people otherwise, which is
  /// exactly who they were trying to reach.
  ///
  /// KEEPS identity (still frozen — a reset is not a route to becoming
  /// someone else), Shepherds, unlock credits, subscription, matches,
  /// consent evidence and any reports made against them.
  ///
  /// Refuses while an Active Journey exists. See selah_reset_profile() for
  /// the full reasoning on each of those.
  static Future<SelahResetResult> resetProfile() async {
    if (!SelahAuth.isSignedIn) {
      return const SelahResetResult(SelahResetOutcome.failed);
    }
    try {
      final res =
          await supabase.rpc('selah_reset_profile') as Map<String, dynamic>;
      final status = res['status'] as String?;

      if (status == 'blocked') {
        return SelahResetResult(
          SelahResetOutcome.blockedByJourney,
          activeJourneys: (res['active'] as num?)?.toInt() ?? 1,
        );
      }
      if (status == 'refused') {
        return const SelahResetResult(SelahResetOutcome.refused);
      }
      if (status != 'reset') {
        debugPrint(
          'SELAH: selah_reset_profile returned an unknown status — $res',
        );
        return const SelahResetResult(SelahResetOutcome.failed);
      }

      // The rows are already gone; this clears the objects behind them.
      // Best-effort by design — the reset itself has committed, so failing
      // here must not report failure and invite a retry that would do
      // nothing. Orphaned objects are a storage cost, not a broken account.
      //
      // The RPC returns ONLY paths under this user's own prefix, so there
      // is nothing here that could remove someone else's file even if the
      // bucket would allow it.
      try {
        final paths =
            (res['storage_paths'] as List?)?.cast<String>() ?? const <String>[];
        if (paths.isNotEmpty) {
          await supabase.storage.from('profile-photos').remove(paths);
        }
      } catch (e) {
        debugPrint(
          'SELAH: profile reset succeeded, photo objects were not removed.\n$e',
        );
      }

      return const SelahResetResult(SelahResetOutcome.done);
    } catch (e) {
      debugPrint('SELAH: selah_reset_profile failed.\n$e');
      return const SelahResetResult(SelahResetOutcome.failed);
    }
  }

  static Future<String?> createSeekerProfile({
    required String firstName,
    required String gender,
    required DateTime dob,
    String? expectedUserId,
  }) => _createProfile(
    role: 'seeker',
    firstName: firstName,
    gender: gender,
    dob: dob,
    expectedUserId: expectedUserId,
  );

  static Future<String?> createMentorProfile({
    required String firstName,
    required String gender,
    required DateTime dob,
    String? expectedUserId,
    bool publishOnCreate = true,
  }) =>
      // The existing helper can publish through a separate guarded RPC.
      // Protected signup instead defers this until real IDV, both names and
      // exact own-row confirmation have passed. These are not atomic writes;
      // its secure draft remains recoverable until finalization succeeds.
      _createProfile(
        role: 'mentor',
        firstName: firstName,
        gender: gender,
        dob: dob,
        profileComplete: publishOnCreate,
        expectedUserId: expectedUserId,
      );

  /// Saves only the existing public surname column for the captured account.
  /// A successful HTTP status with zero rows is not confirmation. This cannot
  /// publish, change identity/role, or turn preview data into member data.
  static Future<bool> savePublicSurname(
    String surname, {
    required String expectedUserId,
    required String expectedRole,
    required int expectedGeneration,
  }) async {
    final trimmed = surname.trim();
    if (trimmed.isEmpty ||
        trimmed.length > 60 ||
        !const ['seeker', 'mentor'].contains(expectedRole)) {
      return false;
    }
    final session = supabase.auth.currentSession;
    bool ownsAccount() =>
        !SelahInternalPreviewClient.isActive &&
        !SelahAccountState.isSigningOut &&
        SelahAccountState.generation == expectedGeneration &&
        SelahAuth.currentUser?.id == expectedUserId &&
        session?.user.id == expectedUserId;
    if (!ownsAccount()) return false;
    try {
      final saved = await supabase
          .from('profiles')
          .update({'surname_line': trimmed})
          .eq('id', expectedUserId)
          .eq('role', expectedRole)
          .setHeader('Authorization', 'Bearer ${session!.accessToken}')
          .select('id, role, surname_line')
          .maybeSingle();
      return ownsAccount() &&
          saved?['id'] == expectedUserId &&
          saved?['role'] == expectedRole &&
          saved?['surname_line'] == trimmed;
    } catch (_) {
      debugPrint('SELAH: public surname save could not be confirmed.');
      return false;
    }
  }

  /// Marks the signed-in user's profile complete — the single switch that
  /// makes them visible to anyone else on the platform.
  ///
  /// ADDED 2026-08-01 (audit finding C3 — the highest-impact bug in the
  /// codebase). Nothing anywhere wrote `profile_complete`. It defaults to
  /// FALSE, and three separate things gate on it being true:
  ///   • profiles_select RLS — hides the whole row from other users
  ///   • profile_photos_select RLS + storage read policy — hides photos
  ///   • SelahDiscoveryService.fetchCandidates — `.eq('profile_complete', true)`
  /// So no genuinely new Seeker could EVER appear in Browse. The 24
  /// visible profiles in the dev database are visible only because the
  /// seed SQL set the flag by hand. The bug stayed hidden because
  /// fetchCandidates falls back to mockProfiles on an empty result, so
  /// Browse always looked populated.
  ///
  /// Returns true on success. Logged rather than silently swallowed
  /// (ES-08) — if this call fails the user is invisible to the entire
  /// platform, which is exactly the class of failure that must never be
  /// silent again.
  /// MOVED BEHIND AN RPC 2026-08-04 (C-3). `profile_complete` is a
  /// publication gate, not a user setting — it is what makes someone
  /// visible to the whole platform — so the client no longer writes it.
  /// `selah_set_profile_complete()` re-checks identity fields and, for a
  /// Seeker, that at least one photo exists.
  ///
  /// Returns true only when the server actually published. A false here can
  /// now mean "incomplete" as well as "failed", and the reason is logged.
  /// How far through onboarding this Seeker is, as the SERVER sees it.
  ///
  /// ADDED 2026-08-11 with the completeness gate (inherited upstream action 193c). The gate is
  /// enforced in selah_can_view_profile and selah_can_match, which means an
  /// unfinished Seeker sees an empty Browse and is told nothing about why.
  /// That is the failure this exists to prevent: a refusal with no
  /// explanation is indistinguishable from a broken app, and this codebase
  /// has already lost a month to exactly that with `profile_complete`.
  ///
  /// Read from the server rather than counted client-side on purpose. The
  /// client knows which questions it SHOWED; only the server knows which
  /// ones the gate is actually waiting on, and if the two ever disagree the
  /// one holding the door is the one worth asking.
  static Future<SelahOnboardingProgress?> fetchOnboardingProgress() async {
    try {
      final rows = await supabase.rpc('selah_my_onboarding_progress') as List;
      if (rows.isEmpty) return null;
      final r = rows.first as Map<String, dynamic>;
      return SelahOnboardingProgress(
        complete: r['complete'] == true,
        due: (r['questions_due'] as num?)?.toInt() ?? 0,
        missing: (r['questions_missing'] as num?)?.toInt() ?? 0,
        hasChapter2: r['has_chapter_2'] == true,
        basicProfile: r['basic_profile'] == true,
      );
    } catch (e) {
      debugPrint('SELAH: fetchOnboardingProgress failed - $e');
      return null;
    }
  }

  static Future<bool> setProfileComplete(
    bool complete, {
    String? expectedUserId,
  }) async {
    final user = SelahAuth.currentUser;
    if (user == null || (expectedUserId != null && user.id != expectedUserId)) {
      return false;
    }
    final session = supabase.auth.currentSession;
    if (expectedUserId != null && session?.user.id != expectedUserId) {
      return false;
    }
    try {
      var request = supabase.rpc(
        'selah_set_profile_complete',
        params: {'p_complete': complete},
      );
      if (expectedUserId != null) {
        request = request.setHeader(
          'Authorization',
          'Bearer ${session!.accessToken}',
        );
      }
      final res = await request;
      if (expectedUserId != null &&
          SelahAuth.currentUser?.id != expectedUserId) {
        return false;
      }
      final status = (res as Map?)?['status'] as String?;
      if (status == 'published' || status == 'unpublished') return true;
      debugPrint(
        'SELAH: setProfileComplete refused — $res. '
        'Profile stays invisible to other users.',
      );
      return false;
    } catch (e) {
      debugPrint(
        'SELAH: setProfileComplete($complete) failed — profile stays invisible to other users. $e',
      );
      return false;
    }
  }

  /// Writes the Seeker's city to `profiles.location_text`.
  ///
  /// ADDED 2026-08-04. `location_text` has existed since the table was
  /// built and THREE services read it:
  ///
  ///   selah_discovery_service.dart:123   `city: map['location_text'] ?? '—'`
  ///   selah_discovery_service.dart:264   same
  ///   selah_match_service.dart:86        same
  ///
  /// Nothing anywhere wrote it. Chapter 2 asks "Where do you currently
  /// live?", stores the answer in AppState, and that was the end of it —
  /// so every genuinely-onboarded Seeker showed an em-dash where their
  /// city should be, on their Browse card and on every match.
  ///
  /// It stayed invisible for the same reason the `profile_complete` bug
  /// did: the seeded dev profiles have the column filled in by hand, so
  /// the only profiles anyone ever looked at already had a city.
  ///
  /// UPDATE, not upsert. An upsert here would need the full row and would
  /// risk the same un-publishing failure mode documented on `_createProfile`
  /// below. By Chapter 2 the row already exists — Chapter 1 created it.
  ///
  /// Free text by design: there is no geocoding in this project and no plan
  /// for any (see chapter2_flow.dart's note on why mileage bands were
  /// dropped). "London" and "london" are two different strings here and
  /// nothing pretends otherwise.
  static Future<bool> saveLocation(
    String? city, {
    String? expectedUserId,
  }) async {
    final trimmed = city?.trim();
    if (trimmed == null || trimmed.isEmpty) return false;
    try {
      final user = SelahAuth.currentUser;
      final generation = SelahAccountState.generation;
      if (user == null ||
          SelahAccountState.isSigningOut ||
          (expectedUserId != null && user.id != expectedUserId)) {
        return false;
      }
      final saved = await supabase
          .from('profiles')
          .update({'location_text': trimmed})
          .eq('id', user.id)
          .select('id')
          .maybeSingle();
      return saved?['id'] == user.id &&
          !SelahAccountState.isSigningOut &&
          SelahAccountState.generation == generation &&
          SelahAuth.currentUser?.id == user.id;
    } catch (e) {
      // Logged, not swallowed (ES-08). A failure here is not fatal, but it
      // reproduces exactly the em-dash this method exists to fix, and a
      // silent version of that is what hid the bug for a month.
      debugPrint(
        'SELAH: saveLocation failed — city will show as "—" (${e.runtimeType}).',
      );
      return false;
    }
  }

  static Future<String?> fetchOwnLocation({
    required String expectedUserId,
  }) async {
    final generation = SelahAccountState.generation;
    if (SelahAccountState.isSigningOut ||
        SelahAuth.currentUser?.id != expectedUserId) {
      throw StateError('Account changed.');
    }
    final row = await supabase
        .from('profiles')
        .select('id, location_text')
        .eq('id', expectedUserId)
        .maybeSingle();
    if (SelahAuth.currentUser?.id != expectedUserId ||
        SelahAccountState.isSigningOut ||
        SelahAccountState.generation != generation ||
        row == null ||
        row['id'] != expectedUserId) {
      throw StateError('Profile unavailable.');
    }
    return row['location_text'] as String?;
  }

  /// Toggles the signed-in user's own `is_active` flag — the same
  /// column Browse's discovery query already filters on
  /// (selah_discovery_service.dart: `.eq('is_active', true)`) and that
  /// profiles_select's RLS policy uses to decide whether a row is
  /// visible to anyone other than its owner. Setting this false
  /// genuinely removes the Seeker from Browse for everyone else —
  /// this is real, not cosmetic. Added 2026-07-26 for the Privacy
  /// settings screen (Settings/Search/Notifications build-out).
  /// Returns true on success.
  static Future<bool> setVisibility(bool visible) async {
    final user = SelahAuth.currentUser;
    if (user == null) return false;
    try {
      await supabase
          .from('profiles')
          .update({'is_active': visible})
          .eq('id', user.id);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Current `is_active` value for the signed-in user, or null if not
  /// signed in / on any failure (caller should treat null as unknown,
  /// not as a specific value).
  static Future<bool?> fetchVisibility() async {
    final user = SelahAuth.currentUser;
    if (user == null) return null;
    try {
      final row = await supabase
          .from('profiles')
          .select('is_active')
          .eq('id', user.id)
          .maybeSingle();
      return row?['is_active'] as bool?;
    } catch (_) {
      return null;
    }
  }

  /// Returns an error message on failure, or null on success/no-op.
  static Future<String?> _createProfile({
    required String role,
    required String firstName,
    required String gender,
    required DateTime dob,
    // Seekers are NOT complete at this point — this runs after the short
    // account essentials, before their deferred profile journey. Publication
    // remains server-owned and must never be awarded by an onboarding screen.
    // Shepherds pass true under the existing Shepherd rule (see above).
    bool profileComplete = false,
    String? expectedUserId,
  }) async {
    final user = SelahAuth.currentUser;
    if (expectedUserId != null && user?.id != expectedUserId) {
      return 'Your sign-in changed. Please sign in again before continuing.';
    }
    final session = supabase.auth.currentSession;
    if (expectedUserId != null && session?.user.id != expectedUserId) {
      return 'Your sign-in changed. Please sign in again before continuing.';
    }
    if (user == null) {
      return null; // not signed in via Supabase — mock-only path, nothing to write
    }

    try {
      // RPC, not an upsert — C-3, 2026-08-04. `authenticated` no longer
      // holds INSERT or unrestricted UPDATE on `profiles`, because that
      // grant let any user set role='admin' (a value the column's own CHECK
      // explicitly permits), rewrite their date of birth, switch gender past
      // the segregation rule, and publish themselves.
      //
      // The RPC refuses 'admin' outright, enforces 18+, and freezes gender
      // and DOB once a profile is published — while still allowing a name
      // correction, which is the one thing people legitimately come back for.
      //
      // The old upsert's careful `profile_complete` handling is no longer
      // needed here: the RPC never touches that column at all, so
      // re-entering Chapter 1 cannot un-publish a live Seeker. The failure
      // mode is gone rather than guarded against.
      var request = supabase.rpc(
        'selah_create_profile',
        params: createProfileParams(
          role: role,
          firstName: firstName,
          gender: gender,
          dob: dob,
        ),
      );
      if (expectedUserId != null) {
        request = request.setHeader(
          'Authorization',
          'Bearer ${session!.accessToken}',
        );
      }
      final res = await request;
      if (expectedUserId != null &&
          SelahAuth.currentUser?.id != expectedUserId) {
        return 'Your sign-in changed. Please sign in again before continuing.';
      }
      debugPrint('SELAH: selah_create_profile -> $res');

      // Explicit publication callers still use the RPC, never a direct
      // column write. Initial Shepherd signup passes publishOnCreate:false
      // and confirms its required first photo before the separate publish.
      if (profileComplete) {
        final published = await setProfileComplete(
          true,
          expectedUserId: expectedUserId,
        );
        if (expectedUserId != null && !published) {
          return "We couldn't confirm your Shepherd setup. Please try again.";
        }
      }
      return null;
    } catch (_) {
      return "Something didn't quite work. Please try again — and if it keeps happening, let us know.";
    }
  }
}
