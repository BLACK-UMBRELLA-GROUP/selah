// Shepherd Suggestions — profiles a Seeker's Shepherd has put forward.
//
// Backs the Connections › Activity section renamed from "Family
// Introductions" on 2026-08-05 (Founder: "it shouldn't be family
// introductions so it seems like you're already matched — I reckon family
// or shepherd suggestions"). "Family Introductions" named the Family Stage
// of an active Journey; sitting above Considered and Saved it implied a
// match had already happened.
//
// The `mentor_suggestions` table has existed since the initial schema and has
// never been read by anything. Its RLS already lets a Seeker select their
// own rows (`mentor_suggestions_select`: mentor_id = me OR seeker_id = me), so
// this needs no new policy and no SECURITY DEFINER function — the suggested
// profiles themselves come through the same `profiles_select` Browse uses.
//
// The Shepherd-side UI for CREATING a suggestion is still unbuilt. Seeded
// server rows may still exist, but the visual developer control now uses
// deterministic local-only cards so testing this read path never mutates the
// signed-in account. Nothing here is dev-only: the read path is the real one
// and will keep working unchanged the day a Shepherd can suggest for real.

import 'package:flutter/foundation.dart';
import '../main.dart';
import '../models/seeker_profile.dart';
import 'selah_auth.dart';
import 'selah_photo_service.dart';
import 'selah_ages_service.dart';
import 'selah_mentor_link_service.dart' show SelahSourceFailure, SelahSourceResult;

class ShepherdSuggestion {
  /// The suggested Seeker, ready to render with the same card as everything
  /// else in Connections.
  final SeekerProfile profile;

  /// Who suggested them — used for the human line the UX Writing standard
  /// asks for ("Suggested by Ibrahim"), rather than a system label.
  final String suggestedBy;

  /// True until the Seeker has landed on Introductions with this suggestion
  /// present. Drives the badge, and ONLY the badge.
  ///
  /// Seen and resolved are different questions, which is the whole reason
  /// this exists — see BADGE_STANDARD:
  ///
  ///   badge      counts UNSEEN     clears on arrival at the surface
  ///   list count counts UNRESOLVED clears when the item is resolved
  ///
  /// Not exposed to the Shepherd. They must not learn that their suggestion
  /// has been looked at and not yet answered — that is pressure, and the
  /// Seeker is entitled to take three days over it.
  final bool unseen;

  const ShepherdSuggestion({
    required this.profile,
    required this.suggestedBy,
    this.unseen = false,
  });
}

class SelahShepherdSuggestionService {
  SelahShepherdSuggestionService._();

  /// Pending suggestions for the signed-in Seeker, newest first.
  ///
  /// Legacy collection adapter. User-visible truth states consume the typed
  /// result so failed refreshes cannot clear an already-known introduction.
  static Future<List<ShepherdSuggestion>> fetchPending() async {
    return (await fetchPendingResult()).valueOr(const []);
  }

  static Future<SelahSourceResult<List<ShepherdSuggestion>>>
  fetchPendingResult() async {
    final user = SelahAuth.currentUser;
    if (user == null) {
      return const SelahSourceResult.unavailable(SelahSourceFailure.signedOut);
    }

    try {
      final rows =
          await supabase
                  .from('mentor_suggestions')
                  .select('suggested_id, mentor_id, created_at, seen_at')
                  .eq('seeker_id', user.id)
                  .eq('status', 'pending')
                  .order('created_at', ascending: false)
              as List;
      if (rows.isEmpty) return const SelahSourceResult.available([]);

      final suggestedIds = <String>[];
      final mentorIds = <String>{};
      for (final r in rows) {
        final m = Map<String, dynamic>.from(r as Map);
        suggestedIds.add(m['suggested_id'] as String);
        mentorIds.add(m['mentor_id'] as String);
      }

      // One read for the suggested profiles, one for the Shepherds' names.
      final profileRows =
          await supabase
                  .from('profiles')
                  .select(
                    'id, first_name, gender, location_text, profile_photos(storage_path, display_order)',
                  )
                  .inFilter('id', suggestedIds)
              as List;
      final mentorRows =
          await supabase
                  .from('profiles')
                  .select('id, first_name')
                  .inFilter('id', mentorIds.toList())
              as List;

      final mentorNames = <String, String>{
        for (final r in mentorRows)
          (r as Map<String, dynamic>)['id'] as String:
              (r['first_name'] as String?) ?? 'your Shepherd',
      };

      // date_of_birth is not selectable client-side (audit C2); age comes
      // from ages_for(), the same SECURITY DEFINER call Browse uses.
      //
      // Delegates since 2026-08-08. This copy was the only one of the four
      // that already logged its failure — which is the single reason the
      // ages_for cap breach was diagnosable at all. The shared service
      // keeps that behaviour and gives it to the other three.
      final ages = await SelahAgesService.forIds(
        suggestedIds,
        context: 'shepherd suggestions',
      );

      // FIXED 2026-08-05 (Founder: "the Shepherd Suggestions don't show
      // people's photos on that page, but when I click View profile I see
      // photos").
      //
      // This signed each suggestion's photos in its own call, inside the
      // loop — ten sequential storage round trips for ten suggestions.
      // Enough of them were refused that roughly half the list rendered
      // with the no-photo placeholder, while the same people showed photos
      // everywhere else in the app, because every other screen signs in one
      // batch. The data was never the problem; the request pattern was.
      final allPaths = <String>[];
      final pathsById = <String, List<String>>{};
      for (final r in profileRows) {
        final map = Map<String, dynamic>.from(r as Map);
        final photosRaw = List<Map<String, dynamic>>.from(
          (map['profile_photos'] as List?) ?? const [],
        );
        photosRaw.sort(
          (a, b) =>
              (a['display_order'] as int).compareTo(b['display_order'] as int),
        );
        final paths = photosRaw
            .map((p) => p['storage_path'] as String)
            .toList();
        pathsById[map['id'] as String] = paths;
        allPaths.addAll(paths);
      }
      final signedByPath = await SelahPhotoService.signedUrlMap(allPaths);

      final byId = <String, SeekerProfile>{};
      for (final r in profileRows) {
        final map = Map<String, dynamic>.from(r as Map);
        final id = map['id'] as String;
        final photos = <String>[
          for (final path in (pathsById[id] ?? const <String>[]))
            if (signedByPath[path] != null) signedByPath[path]!,
        ];
        byId[id] = SeekerProfile(
          id: id,
          firstName: (map['first_name'] as String?) ?? '',
          age: ages[id] ?? 0,
          city: (map['location_text'] as String?) ?? '—',
          photos: photos,
          gender: (map['gender'] as String?) ?? '',
        );
      }

      // Suggestion order preserved; anything whose profile is no longer
      // visible (deactivated, blocked, deleted) simply drops out.
      final out = <ShepherdSuggestion>[];
      for (final r in rows) {
        final m = Map<String, dynamic>.from(r as Map);
        final p = byId[m['suggested_id'] as String];
        if (p == null) continue;
        out.add(
          ShepherdSuggestion(
            profile: p,
            suggestedBy: mentorNames[m['mentor_id'] as String] ?? 'your Shepherd',
            unseen: m['seen_at'] == null,
          ),
        );
      }
      return SelahSourceResult.available(out);
    } catch (e) {
      debugPrint('SELAH: shepherd suggestions unavailable (${e.runtimeType}).');
      return const SelahSourceResult.unavailable(
        SelahSourceFailure.requestFailed,
      );
    }
  }

  /// Stamps every unseen pending suggestion as seen. Called when the Seeker
  /// lands on Introductions.
  ///
  /// Returns true if anything was actually stamped, so the caller can skip a
  /// needless rebuild on the common case of arriving with nothing new.
  ///
  /// An RPC, not a direct UPDATE. `authenticated` holds no UPDATE grant on
  /// `mentor_suggestions` — deliberately, from the C-3 column lockdown — so a
  /// client update fails with "permission denied for table" no matter what
  /// the RLS policy says. Re-granting UPDATE would hand the Seeker every
  /// column including `status`; this grants exactly one capability, and it
  /// takes no arguments, so there is nothing to point at someone else.
  ///
  /// Failure is swallowed on purpose. The worst outcome is a dot that stays
  /// lit one visit longer; blocking the screen or showing an error over it
  /// would be a far worse trade for something the user never asked for.
  static Future<bool> markSeen() async {
    if (SelahAuth.currentUser == null) return false;
    try {
      final n = await supabase.rpc('selah_mark_suggestions_seen');
      return (n as int? ?? 0) > 0;
    } catch (e) {
      debugPrint('SELAH: markSeen (shepherd suggestions) failed — $e');
      return false;
    }
  }
}
