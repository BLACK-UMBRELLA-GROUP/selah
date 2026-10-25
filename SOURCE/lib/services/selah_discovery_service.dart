// Browse discovery + decision persistence. Wires the Browse screen to
// the real `profiles`/`profile_photos` tables for candidate discovery,
// and to `saves`/`likes` for decision persistence.
//
// Real reads never fall back to fabricated people. Browse consumes the typed
// candidate result so a failed read is not presented as a successful empty
// search. Only the separately authorised developer UI composes fixtures.
//
// Decline is deliberately NOT persisted anywhere, per PROFILE
// DECISION SYSTEM/Summary.md ("no record, no notification") — only
// Save and Like write to the backend.
//
// Compatibility scoring (inherited decision 079, PROPOSED but wired in per that
// DR's own stated next step — see the score_candidates() SECURITY
// DEFINER function, 20260726120200_compatibility_scoring_security_
// definer.sql) is now applied to real candidates: a candidate who
// fails one of the
// signed-in user's Hard Requirements is excluded outright, and the
// remaining candidates are silently ordered by score. The numeric
// score itself is never attached to SeekerProfile or exposed to the
// UI — MATCH_UX_SPEC_CURRENT_VERSION_V1.md / BROWSE_UX_SPEC_CURRENT_
// VERSION_V1.md are both explicit that Compatibility % is "not shown
// anywhere until Active Journey begins." Ordering candidates by an
// unseen score doesn't violate that display rule, but showing the
// number would — so it stays entirely inside this service.

import 'package:flutter/foundation.dart' show debugPrint;

import '../main.dart';
import '../models/seeker_profile.dart';
import '../models/selah_known_person_code.dart';
import '../models/selah_gender.dart';
import 'selah_auth.dart';
import 'selah_photo_service.dart';
import 'selah_ages_service.dart';
import 'selah_mentor_link_service.dart' show SelahSourceFailure, SelahSourceResult;

class SelahDiscoveryService {
  SelahDiscoveryService._();

  /// Resolves a bearer-held permanent SELAH Code through the dedicated
  /// Seeker-only server boundary. An authoritative empty result deliberately
  /// does not reveal whether the code was unknown or the pair was ineligible.
  static Future<SelahKnownPersonCodeLookup> previewKnownPersonCode(
    String code,
  ) async {
    final user = SelahAuth.currentUser;
    if (!supabaseReady || user == null) {
      return const SelahKnownPersonCodeLookup.unavailable();
    }
    try {
      final raw = await supabase.rpc(
        'selah_preview_match_code',
        params: {'p_code': code},
      );
      if (raw is! List) return const SelahKnownPersonCodeLookup.unavailable();
      if (raw.isEmpty) return const SelahKnownPersonCodeLookup.available(null);
      if (raw.length != 1 || raw.single is! Map) {
        return const SelahKnownPersonCodeLookup.unavailable();
      }
      final person = SelahKnownPersonCodePreview.fromRow(
        Map<String, dynamic>.from(raw.single as Map),
      );
      return person == null
          ? const SelahKnownPersonCodeLookup.unavailable()
          : SelahKnownPersonCodeLookup.available(person);
    } catch (e) {
      debugPrint('SELAH: previewKnownPersonCode failed — $e');
      return const SelahKnownPersonCodeLookup.unavailable();
    }
  }

  /// Creates the same Consider fact as a Browse swipe. The server resolves the
  /// code and rechecks identity, visibility and matching rules at write time.
  static Future<SelahKnownPersonConsiderOutcome> considerKnownPersonCode(
    String code,
  ) async {
    final user = SelahAuth.currentUser;
    if (!supabaseReady || user == null) {
      return SelahKnownPersonConsiderOutcome.failed;
    }
    try {
      final raw = await supabase.rpc(
        'selah_consider_match_code',
        params: {'p_code': code},
      );
      return switch (raw) {
        'considered' => SelahKnownPersonConsiderOutcome.considered,
        'matched' => SelahKnownPersonConsiderOutcome.matched,
        null => SelahKnownPersonConsiderOutcome.noLongerAvailable,
        _ => SelahKnownPersonConsiderOutcome.failed,
      };
    } catch (e) {
      debugPrint('SELAH: considerKnownPersonCode failed — $e');
      return SelahKnownPersonConsiderOutcome.failed;
    }
  }

  /// Real candidates only. Returns an EMPTY LIST when there are none.
  ///
  /// MOCK FALLBACK REMOVED 2026-08-04 (independent review, H-6). This
  /// method had FIVE separate `return mockProfiles` paths — not signed in,
  /// no gender, no rows, no photos, and any exception. Every one of them
  /// put fabricated people in front of a real user, and every one of them
  /// made a failure look like success.
  ///
  /// That is not hypothetical: it is exactly how the `profile_complete` bug
  /// survived a month in July. No genuinely-onboarded Seeker could ever
  /// appear in Browse, and nobody noticed, because Browse always looked
  /// populated.
  ///
  /// An empty list is now an empty list. Browse shows its empty state,
  /// which is the truth, and every failure path logs its reason.
  ///
  /// `mockProfiles` still exists in seeker_profile.dart for widget tests
  /// and the dev colour deck. It is no longer reachable from the real path.
  static Future<List<SeekerProfile>> fetchCandidates() async {
    return (await fetchCandidatesResult()).valueOr(const []);
  }

  static Future<SelahSourceResult<List<SeekerProfile>>>
  fetchCandidatesResult() async {
    final user = SelahAuth.currentUser;
    if (user == null) {
      debugPrint(
        'SELAH: fetchCandidates — not signed in, returning no candidates.',
      );
      return const SelahSourceResult.unavailable(SelahSourceFailure.signedOut);
    }

    try {
      // Own gender first — Browse must "Never display same-gender
      // profiles" (APP/Browse/Script/Script_V1.md), which the original
      // wiring missed. The schema's (gender, is_active,
      // profile_complete) index exists for exactly this query.
      final me = await supabase
          .from('profiles')
          .select('gender')
          .eq('id', user.id)
          .maybeSingle();
      final myGender = me?['gender'] as String?;
      if (myGender == null) {
        // No profile row yet — mid-onboarding, or the row failed to write.
        debugPrint(
          'SELAH: fetchCandidates — no gender on own profile, so no '
          'target gender to search for. Returning no candidates.',
        );
        return const SelahSourceResult.unavailable(SelahSourceFailure.notReady);
      }
      final targetGender = SelahGender.oppositeCode(myGender);

      final rows =
          await supabase
                  .from('profiles')
                  // 2026-07-27: surname_line added — see 20260727 migration
                  // add_surname_line_to_profiles + SeekerProfile.surnameLine's
                  // updated doc comment for the full "why wasn't this showing"
                  // root cause. Without this, every real candidate silently
                  // constructed a SeekerProfile with surnameLine == null below,
                  // regardless of what the mockProfiles fallback had.
                  .select(
                    'id, first_name, surname_line, location_text, gender, profile_photos(storage_path, display_order)',
                  )
                  .eq(
                    'role',
                    'seeker',
                  ) // Mentor accounts must never appear as candidates
                  .eq('gender', targetGender)
                  .eq('is_active', true)
                  .eq('profile_complete', true)
                  .neq('id', user.id)
              as List;

      if (rows.isEmpty) {
        // A genuinely empty result. Early in a launch this is the normal
        // state, and saying so is more useful than pretending otherwise.
        debugPrint('SELAH: fetchCandidates — 0 $targetGender candidates match.');
        return const SelahSourceResult.available([]);
      }

      // Raw date_of_birth is no longer selectable by the client (see
      // 20260726120000_hide_raw_dob_expose_age.sql) — ages are fetched
      // in one batch call to the ages_for() SECURITY DEFINER function
      // instead, which returns only the derived age.
      final ids = rows
          .map((r) => (r as Map<String, dynamic>)['id'] as String)
          .toList();
      final ages = await _fetchAges(ids);

      // FIXED 2026-07-26 (photo preloading pass — CHATGPT_REPLY_NAVBAR_
      // PHOTO_MENU_2026-07-26.md §2, second bug named there): this used
      // to `await SelahPhotoService.signedUrlsFor(...)` once per
      // candidate inside this loop — one sequential Supabase Storage
      // round trip per candidate, when signedUrlsFor() already supports
      // signing every path in one batched call. Now every candidate's
      // paths are collected first, signed in exactly one call, then
      // sliced back out in order (createSignedUrls returns results in
      // the same order as the input paths, so a running cursor is
      // sufficient — no per-candidate correlation key needed).
      final validRows = <Map<String, dynamic>>[];
      final photoPathsPerRow = <List<String>>[];
      for (final row in rows) {
        final map = row as Map<String, dynamic>;
        final photosRaw = List<Map<String, dynamic>>.from(
          (map['profile_photos'] as List?) ?? const [],
        );
        if (photosRaw.isEmpty) {
          continue; // no photo — not browsable per Browse spec
        }
        photosRaw.sort(
          (a, b) =>
              (a['display_order'] as int).compareTo(b['display_order'] as int),
        );
        validRows.add(map);
        photoPathsPerRow.add(
          photosRaw.map((p) => p['storage_path'] as String).toList(),
        );
      }

      // REWRITTEN 2026-08-05 (Founder: "still no profiles showing up…
      // please do a deep fix").
      //
      // This used to sign every path in one call and slice the results back
      // out BY POSITION, which required the returned list to be exactly as
      // long as the one sent. It never can be here: the seeded profiles
      // share a pool of real photos, so a full deck asks for ~284 paths of
      // which only ~209 are distinct, the lengths disagreed, and the guard
      // below correctly refused to show anyone — an empty Browse with 69
      // perfectly good candidates behind it.
      //
      // Signing now returns a MAP keyed by path, so nothing depends on
      // order or count. A photo that fails to resolve is skipped; a person
      // is dropped only if NONE of their photos resolve. One bad object can
      // no longer empty the deck.
      final allPaths = <String>[for (final paths in photoPathsPerRow) ...paths];
      final signedByPath = await SelahPhotoService.signedUrlMap(allPaths);

      final results = <SeekerProfile>[];
      var droppedForPhotos = 0;
      for (var i = 0; i < validRows.length; i++) {
        final map = validRows[i];
        final photos = <String>[
          for (final path in photoPathsPerRow[i])
            if (signedByPath[path] != null) signedByPath[path]!,
        ];
        if (photos.isEmpty) {
          droppedForPhotos++;
          continue; // genuinely no viewable photo — not browsable per spec
        }

        results.add(
          SeekerProfile(
            id: map['id'] as String,
            firstName: map['first_name'] as String,
            age: ages[map['id'] as String] ?? 0,
            city: (map['location_text'] as String?) ?? '—',
            photos: photos,
            gender: map['gender'] as String,
            surnameLine: map['surname_line'] as String?,
          ),
        );
      }

      if (droppedForPhotos > 0) {
        debugPrint(
          'SELAH: fetchCandidates — ${results.length} candidates ready; '
          '$droppedForPhotos dropped because none of their photos signed.',
        );
      }
      if (results.isEmpty) {
        debugPrint(
          'SELAH: fetchCandidates — ${rows.length} candidate row(s) '
          'matched but none survived photo resolution.',
        );
        // A genuinely photo-less population can be empty. Failed signing of
        // existing photos is unavailable, not "everyone has been seen".
        return allPaths.isEmpty
            ? const SelahSourceResult.available([])
            : const SelahSourceResult.unavailable(
                SelahSourceFailure.requestFailed,
              );
      }

      return SelahSourceResult.available(
        await _applyCompatibility(user.id, results),
      );
    } catch (e) {
      // LOGGED 2026-08-04. This was `catch (_) { return mockProfiles; }` —
      // an exception anywhere above produced a full, plausible-looking
      // Browse deck of people who do not exist, with no trace in the
      // console. The single most misleading line in the codebase.
      debugPrint('SELAH: candidate read unavailable (${e.runtimeType}).');
      return const SelahSourceResult.unavailable(
        SelahSourceFailure.requestFailed,
      );
    }
  }

  /// Excludes candidates who fail a Hard Requirement and orders the
  /// rest by compatibility score, without ever exposing the score
  /// itself. A failed check propagates to the unavailable result above:
  /// showing unfiltered candidates would bypass the Hard Requirements.
  ///
  /// FIXED 2026-07-26 (Founder decision — see SELAH_FABLE_BUILD_REVIEW_
  /// 2026-07-19_V1.md §Open Decisions item 1): scoring now happens
  /// entirely inside the score_candidates() SECURITY DEFINER function
  /// (20260726120200_compatibility_scoring_security_definer.sql),
  /// which reads both the signed-in user's Ch4 preferences AND each
  /// candidate's Ch3 answers server-side — bypassing the client-facing
  /// own-row-only RLS on onboarding_answers, which stays exactly as
  /// restrictive as before for direct table reads. The client never
  /// sees another user's raw answers, only the returned score.
  static Future<List<SeekerProfile>> _applyCompatibility(
    String userId,
    List<SeekerProfile> candidates,
  ) async {
    try {
      final candidateIds = candidates.map((c) => c.id).toList();
      final rows =
          await supabase.rpc(
                'score_candidates',
                params: {'p_candidate_ids': candidateIds},
              )
              as List;
      // NULL-TOLERANT AS OF 2026-08-11 (inherited upstream action 193). score_candidates used
      // to return a neutral 50 when it had nothing to go on. On the ratified
      // plain-count scale there is no neutral value, so it returns NULL —
      // and `(row['score'] as num)` on a null would have thrown into the
      // catch below, silently dropping ALL ordering for everyone.
      //
      // THREE OUTCOMES NOW, and they are different things:
      //   absent row   excluded by a Hard Requirement — do not show at all
      //   NULL score   exists, cannot be scored yet   — show, rank last
      //   a number     scored                          — rank by it
      final scoreByCandidateId = <String, double?>{
        for (final row in rows)
          (row as Map<String, dynamic>)['candidate_id'] as String:
              (row['score'] as num?)?.toDouble(),
      };

      final scored = <MapEntry<SeekerProfile, double?>>[
        for (final candidate in candidates)
          if (scoreByCandidateId.containsKey(candidate.id))
            MapEntry(candidate, scoreByCandidateId[candidate.id]),
      ];
      // Unscored last, rather than treated as zero — "we cannot say" is not
      // the same claim as "nothing matched".
      scored.sort((a, b) {
        if (a.value == null && b.value == null) return 0;
        if (a.value == null) return 1;
        if (b.value == null) return -1;
        return b.value!.compareTo(a.value!);
      });
      return scored.map((e) => e.key).toList();
    } catch (_) {
      rethrow;
    }
  }

  /// This Seeker's OWN compatibility figure for one profile: how well THEIR
  /// answers fit MY stated preferences.
  ///
  /// ADDED 2026-08-11 so Compatibility Unlock can show a real number instead
  /// of a constant. Deliberately the same call Browse curation makes, not a
  /// second scorer — the price of a credit should not buy a different method.
  ///
  /// Null means one of two honest things and the screen says so rather than
  /// guessing which: nothing scoreable yet, or excluded outright by a Hard
  /// Requirement (in which case no row comes back at all).
  static Future<double?> fetchMyScoreFor(String otherId) async {
    try {
      final rows =
          await supabase.rpc(
                'score_candidates',
                params: {
                  'p_candidate_ids': [otherId],
                },
              )
              as List;
      if (rows.isEmpty) return null;
      return ((rows.first as Map<String, dynamic>)['score'] as num?)
          ?.toDouble();
    } catch (e) {
      debugPrint('SELAH: fetchMyScoreFor($otherId) failed - $e');
      return null;
    }
  }

  /// Batch age lookup via the server-side ages_for() function — see
  /// 20260726120000_hide_raw_dob_expose_age.sql. Best-effort: on any
  /// failure, returns an empty map and callers fall back to age 0
  /// rather than breaking Browse over an age lookup.
  static Future<Map<String, int>> _fetchAges(List<String> ids) async {
    // Delegates since 2026-08-08. Was a private copy that sent every id
    // in ONE call and swallowed the refusal — with 72 candidates against
    // ages_for()'s 50-id cap, that is why every age read 0.
    return SelahAgesService.forIds(ids, context: 'browse candidates');
  }

  /// Best-effort. Mock profile ids aren't real `profiles` rows, so the
  /// FK check fails and the write is silently swallowed — harmless,
  /// since mock candidates have nothing real to persist against.
  // ═══════════════════════════════════════════════════════════════════
  // ignoreDuplicates: true — RELEASE BLOCKER FIX, 2026-08-09.
  // Audit finding 1.1. Do not remove it.
  // ═══════════════════════════════════════════════════════════════════
  //
  // A BARE .upsert() sends `Prefer: resolution=merge-duplicates`, which
  // PostgREST turns into INSERT … ON CONFLICT DO UPDATE. PostgreSQL
  // demands the UPDATE privilege at PLAN time — whether or not a row
  // actually conflicts. `authenticated` holds INSERT on these tables and
  // UPDATE on none of them, so EVERY Save, Like and Pass was refused with
  // 42501 and swallowed by the catch below.
  //
  // Consequence: no `likes` row was ever written, so
  // create_match_on_mutual_like never fired and NO USER COULD EVER MATCH.
  // The app showed a spinner and moved on.
  //
  // ignoreDuplicates: true sends `resolution=ignore-duplicates` instead →
  // ON CONFLICT DO NOTHING, which needs no UPDATE privilege. It is also
  // the actual intent here: these rows are a bare fact — "A liked B" —
  // with no payload to merge. Re-liking is a no-op, not an overwrite.
  //
  // Verified against the live database 2026-08-09, as `authenticated`,
  // rolled back:
  //   ON CONFLICT DO UPDATE  → 42501 permission denied for table likes
  //   ON CONFLICT DO NOTHING → succeeded; a mutual pair then produced a
  //                            matches row with status='potential'
  //
  // Granting UPDATE would also have worked and was REJECTED: it would let
  // a user rewrite a row they do not own. onConflict names the pair
  // explicitly because the primary key on these tables is a surrogate
  // `id`, not the pair.
  // ALL THREE DECISION WRITES REPORT WHETHER THEY LANDED — BUG-02 of the
  // 2026-08-14 audit (inherited upstream action 225 path 1, fixed 2026-08-15). They
  // swallowed every failure, so a Save/Consider/Pass could vanish on
  // relaunch and a failed Like could silently prevent a match (the
  // create_match_on_mutual_like trigger only fires off a row that
  // exists). Callers keep the optimistic UI — reverting a card
  // mid-swipe would be worse — but a failure now SAYS SO and offers a
  // retry, which is safe because all three writes are idempotent
  // upserts: re-recording an already-recorded decision is a no-op.
  static Future<bool> recordSave(String savedId) async {
    final user = SelahAuth.currentUser;
    if (user == null) return false;
    try {
      await supabase
          .from('saves')
          .upsert(
            {'saver_id': user.id, 'saved_id': savedId},
            onConflict: 'saver_id,saved_id',
            ignoreDuplicates: true,
          );
      return true;
    } catch (e) {
      debugPrint('SELAH: recordSave($savedId) failed — $e');
      return false;
    }
  }

  static Future<bool> recordLike(String likedId) async {
    final user = SelahAuth.currentUser;
    if (user == null) return false;
    try {
      await supabase
          .from('likes')
          .upsert(
            {'liker_id': user.id, 'liked_id': likedId},
            onConflict: 'liker_id,liked_id',
            ignoreDuplicates: true,
          );
      return true;
    } catch (e) {
      debugPrint('SELAH: recordLike($likedId) failed — $e');
      return false;
    }
  }

  /// Builds SeekerProfiles for a specific set of ids.
  ///
  /// Extracted 2026-08-01 from fetchCandidates so [fetchDecisions] can
  /// reuse the photo handling rather than reimplement it. That handling is
  /// not incidental: photo paths are collected across ALL rows and signed
  /// in ONE batched call, because signing per row was a real performance
  /// bug once (one sequential Storage round trip per profile).
  ///
  /// Deliberately does NOT filter on `is_active` or `profile_complete`.
  /// Someone you saved last week who has since hidden their profile should
  /// still appear in your own Saved list — dropping them silently would
  /// look like data loss, which is the exact complaint this work exists to
  /// answer. RLS still governs what is readable.
  /// Made public 2026-08-03 for BlockedUsersScreen, which needs the same
  /// id-to-profile lookup and must not reimplement the batched photo
  /// signing that lives here.
  /// [includeWithoutPhotos] is for already-linked identity surfaces: retain
  /// readable profile fields even when no photo row is visible or signing
  /// fails. Other callers keep their established photo-backed deck behavior.
  /// This does not bypass profile or photo RLS; both reads remain caller-scoped.
  static Future<List<SeekerProfile>> profilesByIds(
    List<String> ids, {
    bool includeWithoutPhotos = false,
  }) async {
    if (ids.isEmpty) return const [];
    try {
      final rows =
          await supabase
                  .from('profiles')
                  .select(
                    'id, first_name, surname_line, location_text, gender, profile_photos(storage_path, display_order)',
                  )
                  .inFilter('id', ids)
              as List;
      if (rows.isEmpty) return const [];

      final foundIds = rows
          .map((r) => (r as Map<String, dynamic>)['id'] as String)
          .toList();
      final ages = await _fetchAges(foundIds);

      final validRows = <Map<String, dynamic>>[];
      final photoPathsPerRow = <List<String>>[];
      for (final row in rows) {
        final map = row as Map<String, dynamic>;
        final photosRaw = List<Map<String, dynamic>>.from(
          (map['profile_photos'] as List?) ?? const [],
        );
        if (photosRaw.isEmpty && !includeWithoutPhotos) continue;
        photosRaw.sort(
          (a, b) =>
              (a['display_order'] as int).compareTo(b['display_order'] as int),
        );
        validRows.add(map);
        photoPathsPerRow.add(
          photosRaw.map((p) => p['storage_path'] as String).toList(),
        );
      }

      // Map-keyed signing, same reasoning as fetchCandidates above — this
      // had the identical all-or-nothing length check, so the Connections
      // lists emptied for exactly the same reason Browse did.
      final allPaths = <String>[for (final paths in photoPathsPerRow) ...paths];
      final signedByPath = await SelahPhotoService.signedUrlMap(allPaths);

      final byId = <String, SeekerProfile>{};
      for (var i = 0; i < validRows.length; i++) {
        final map = validRows[i];
        final photos = <String>[
          for (final path in photoPathsPerRow[i])
            if (signedByPath[path] != null) signedByPath[path]!,
        ];
        if (photos.isEmpty && !includeWithoutPhotos) continue;
        final id = map['id'] as String;
        byId[id] = SeekerProfile(
          id: id,
          firstName: map['first_name'] as String,
          age: ages[id] ?? 0,
          city: (map['location_text'] as String?) ?? '—',
          photos: photos,
          gender: map['gender'] as String,
          surnameLine: map['surname_line'] as String?,
        );
      }
      // Returned in the caller's order, so "most recently saved last"
      // survives the round trip.
      return [
        for (final id in ids)
          if (byId[id] != null) byId[id]!,
      ];
    } catch (_) {
      return const [];
    }
  }

  /// Reads back this Seeker's own decisions so they survive a restart.
  ///
  /// THIS IS THE GAP THE FOUNDER HIT (2026-08-01: "when I close the app
  /// the data goes... I'm assuming this is temporary in dev mode").
  ///
  /// It was not dev mode, and a real user would have hit it identically.
  /// `saves` and `likes` have been written since they were built, and
  /// `passes` since earlier today — but nothing ever read any of them back.
  /// AppState was populated only by acting in Browse during that session,
  /// so every Connections list emptied on relaunch while the rows sat in
  /// the database untouched.
  ///
  /// Ordered oldest-first by `created_at` so the Passed section's
  /// "showing last 10" really is the last ten.
  static Future<
    ({
      List<SeekerProfile> saved,
      List<SeekerProfile> considered,
      List<SeekerProfile> passed,
    })
  >
  fetchDecisions() async {
    final user = SelahAuth.currentUser;
    const empty = (
      saved: <SeekerProfile>[],
      considered: <SeekerProfile>[],
      passed: <SeekerProfile>[],
    );
    if (user == null) return empty;

    try {
      // BEHAVIOUR UNCHANGED — `ascending: false` is what a bare .order() has
      // always meant in postgrest-dart, and most recent decision first is the
      // right order for these three lists. Written out on 2026-08-11 only
      // because relying on that default cost four real bugs elsewhere in this
      // sweep (Timeline, chat history both sides, family answers), and a bare
      // .order() reads as "chronological" to everyone who has not been bitten.
      final results = await Future.wait([
        supabase
            .from('saves')
            .select('saved_id, created_at')
            .eq('saver_id', user.id)
            .order('created_at', ascending: false),
        supabase
            .from('likes')
            .select('liked_id, created_at')
            .eq('liker_id', user.id)
            .order('created_at', ascending: false),
        supabase
            .from('passes')
            .select('passed_id, created_at')
            .eq('passer_id', user.id)
            .order('created_at', ascending: false),
      ]);

      List<String> ids(List rows, String key) => [
        for (final r in rows) (r as Map<String, dynamic>)[key] as String,
      ];

      final savedIds = ids(results[0], 'saved_id');
      final likedIds = ids(results[1], 'liked_id');
      final passedIds = ids(results[2], 'passed_id');

      // One profile read for all three lists, not three. A profile can
      // legitimately appear in two of them — Saved is a bookmark and sits
      // alongside a decision — so the union is deduplicated first.
      final all = {...savedIds, ...likedIds, ...passedIds}.toList();
      if (all.isEmpty) return empty;

      final profiles = await profilesByIds(all);
      final byId = {for (final p in profiles) p.id: p};
      List<SeekerProfile> pick(List<String> want) => [
        for (final id in want)
          if (byId[id] != null) byId[id]!,
      ];

      return (
        saved: pick(savedIds),
        considered: pick(likedIds),
        passed: pick(passedIds),
      );
    } catch (_) {
      return empty;
    }
  }

  /// ADDED 2026-08-01 with the `passes` table.
  ///
  /// Declines had no table at all before this — they lived only in
  /// AppState, so every one of them was forgotten on app restart and
  /// passed-on profiles walked straight back into Browse. That is the
  /// other half of why the same person could be decided on twice.
  ///
  /// The `passes_clear_like` trigger removes any prior Like server-side,
  /// so a decision stays exclusive even if a client forgets to. It does
  /// not touch `saves` — a bookmark survives every decision.
  static Future<bool> recordPass(String passedId) async {
    final user = SelahAuth.currentUser;
    if (user == null) return false;
    try {
      // ignoreDuplicates: see recordSave/recordLike above — finding 1.1.
      // bool return: see the BUG-02 block above recordSave.
      await supabase
          .from('passes')
          .upsert(
            {'passer_id': user.id, 'passed_id': passedId},
            onConflict: 'passer_id,passed_id',
            ignoreDuplicates: true,
          );
      return true;
    } catch (e) {
      debugPrint('SELAH: recordPass($passedId) failed — $e');
      return false;
    }
  }

  /// Removes a bookmark. ADDED 2026-08-01 with the Connections move
  /// actions (Founder: "there's no way to open the profile card and move
  /// a user to save or decline").
  ///
  /// Saves were write-only until now — every other decision could be
  /// changed and this one could not, so a bookmark was permanent by
  /// accident.
  ///
  /// Touches `saves` only. Removing a bookmark says nothing about the
  /// decision: someone you un-save but are still Considering is still
  /// Considering.
  static Future<void> removeSave(String savedId) async {
    final user = SelahAuth.currentUser;
    if (user == null) return;
    try {
      await supabase
          .from('saves')
          .delete()
          .eq('saver_id', user.id)
          .eq('saved_id', savedId);
    } catch (_) {}
  }

  /// Reset Search — clears Declined ONLY. Considering, Saved, Journeys
  /// and Matches are deliberately untouched (Founder, 2026-08-01).
  ///
  /// Returns how many profiles came back, so the confirmation can say
  /// something true rather than a generic "done". Null means the call
  /// failed and the UI must not claim success.
  static Future<int?> resetSearch() async {
    final user = SelahAuth.currentUser;
    if (user == null) return null;
    try {
      final result = await supabase.rpc('selah_reset_search');
      return result is int ? result : int.tryParse('$result');
    } catch (_) {
      return null;
    }
  }
}
