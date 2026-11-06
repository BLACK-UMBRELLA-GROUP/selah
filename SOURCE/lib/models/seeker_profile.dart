// Mock Seeker profile model — used by Browse today; will be replaced by
// the real Supabase `profiles`/`seeker_details` read model once the
// backend is wired up (see SYSTEM/DOCUMENTS/SELAH_DATABASE_SCHEMA_CURRENT_VERSION_V1.md).
// Fields limited to what BROWSE_UX_SPEC_CURRENT_VERSION_V1.md's Profile
// Card visible-information table actually shows: photo, first name, age,
// city. compatibility/values/education/career stay hidden by design.
//
// `photos` (2026-07-18): extended to multiple photos per profile after
// reviewing the founder's old Lovable prototype (src/routes/home.tsx) —
// its Browse card supports tap-left/right photo cycling with a side dot
// indicator, which needs more than one photo per candidate to matter.

import 'selah_faith_profile.dart';

class SeekerProfile {
  final String id;
  final String firstName;
  final int age;
  final String city;
  final List<String> photos;
  final String
  gender; // drives SelahBackgroundVariant on their own onboarding, not used in Browse UI directly

  /// 2026-07-26 (Founder, Browse review: "let's try add surname and see
  /// how it looks... put surname under first name, that includes middle
  /// name should anyone have it"). Nullable and deliberately NOT called
  /// `lastName` — it's whatever should render on that second line
  /// (surname, or "middle name + surname" together), a display string
  /// rather than a strict legal-name field.
  ///
  /// UPDATED 2026-07-27: real root cause of "surnames still aren't
  /// showing" (3rd report) — Browse renders whichever candidates
  /// `SelahDiscoveryService.fetchCandidates()` returns, and since 24 real
  /// seeded `profiles` rows exist today (Amina, Noor, etc.), it was
  /// returning THOSE, not this file's `mockProfiles` — so editing
  /// surnames here never had a visible effect once real data existed.
  /// `profiles` now has a `surname_line` column (added + backfilled for
  /// all seeded rows this same pass — see the Supabase migration and
  /// selah_discovery_service.dart's updated select/construction), so real
  /// candidates carry a surname too now. What's still genuinely missing:
  /// no onboarding step or profile-settings field lets a real NEW user
  /// enter their own surname yet — tracked as a follow-up Outstanding
  /// Action rather than built silently here, since that's an onboarding
  /// UX addition, not a bug fix.
  final String? surnameLine;

  /// Separately disclosed public labels, never copied from private
  /// compatibility answers. Only invented developer fixtures currently
  /// supply these; ordinary discovery leaves them null until a consent-backed
  /// production capture/projection exists.
  final String? publicNationality;
  final String? publicEthnicity;

  /// Explicit public faith projection. Missing/withheld answers stay absent;
  /// retained nationality, ethnicity and compatibility fields are not inferred.
  final SelahFaithProfileAnswers? faithProfile;
  final String? faithDenominationText;

  /// 2026-07-27 (Founder: "selah one account users can upload a video...
  /// maybe for on account show how the video will look and on the left
  /// side dots area... for a video its a play button"). Mock/UI-demo
  /// only, same honesty scope as `surnameLine` originally was — this is
  /// NOT a real video feature. There is no upload flow, no storage, no
  /// compression, no playback, and no spec document for one (checked;
  /// none exists, contrary beliefs aside — IMAGE_HANDLING_CURRENT_
  /// VERSION_V2.md covers photos only). Null = no video slot. When set,
  /// names which index in [photos] should render as a video slot in the
  /// left-side pagination dots (browse_screen.dart) — that "photo" is
  /// still just a static image URL standing in for a video's poster
  /// frame, purely to demonstrate the play-button dot treatment.
  final int? videoPhotoIndex;

  /// Mock stand-in for "this Seeker has already Liked you" — since there's
  /// no backend, a couple of mock profiles are pre-flagged so a mutual
  /// Like (Match event, per MATCH_UX_SPEC_CURRENT_VERSION_V1.md) is
  /// deterministically reachable for testing rather than random.
  final bool alreadyLikedYou;

  const SeekerProfile({
    required this.id,
    required this.firstName,
    required this.age,
    required this.city,
    required this.photos,
    required this.gender,
    this.surnameLine,
    this.publicNationality,
    this.publicEthnicity,
    this.faithProfile,
    this.faithDenominationText,
    this.videoPhotoIndex,
    this.alreadyLikedYou = false,
  });

  /// Convenience getter for screens that only ever show one photo
  /// (Matches list tiles, Chat header) — avoids touching every call site.
  // A privacy-filtered or not-yet-uploaded photo list is valid. The shared
  // image widget uses an empty URL for its neutral placeholder.
  String get photoUrl => photos.isEmpty ? '' : photos.first;

  /// LOCK 8's ordered projection of explicitly supplied faith answers.
  /// Absent and withheld values produce no replacement or inferred label.
  List<String> get browseFaithChips {
    final faith = faithProfile;
    if (faith == null) return const [];
    final tradition = faith.tradition == 'Another tradition'
        ? faithDenominationText?.trim()
        : faith.tradition;
    return List.unmodifiable([
      if (tradition != null && tradition.isNotEmpty) tradition,
      if (switch (faith.church) {
            'Every week' => 'Church weekly',
            'Most weeks' => 'Church most weeks',
            'Sometimes' => 'Church sometimes',
            _ => null,
          }
          case final String church)
        church,
      if (switch (faith.baptised) {
            'Yes' => 'Baptised',
            'Not yet' => 'Not yet baptised',
            _ => null,
          }
          case final String baptised)
        baptised,
    ]);
  }
}

/// Placeholder profile photos (public placeholder image service) so the
/// Browse screen has something to render before real photo storage exists.
final List<SeekerProfile> mockProfiles = [
  // 2026-07-26 (Founder: "we said surnames so change a few users and
  // give them surnames so I can see how it looks") — added to 4 more
  // profiles (Ibrahim deliberately left without one, so both the
  // with/without cases are still visible side by side), a mix of
  // lengths from a short single word to Bilal's existing two-word
  // example, to see how the identity block's second line reads across
  // different cases.
  const SeekerProfile(
    id: '1',
    firstName: 'Abigail',
    age: 27,
    city: 'London',
    gender: 'female',
    alreadyLikedYou: true,
    surnameLine: 'Reyes',
    // 2026-07-27 — demonstrates the SELAH One video-slot play-button dot
    // treatment (see SeekerProfile.videoPhotoIndex's doc comment). Photo
    // index 1 (the middle of these 3) is the mock "video" slot; it's
    // still a static image underneath — this is a visual mockup only.
    videoPhotoIndex: 1,
    photos: [
      'https://picsum.photos/seed/selah1a/700/1000',
      'https://picsum.photos/seed/selah1b/700/1000',
      'https://picsum.photos/seed/selah1c/700/1000',
    ],
  ),
  const SeekerProfile(
    id: '2',
    firstName: 'Elijah',
    age: 30,
    city: 'Birmingham',
    gender: 'male',
    surnameLine: 'Grant',
    photos: [
      'https://picsum.photos/seed/selah2a/700/1000',
      'https://picsum.photos/seed/selah2b/700/1000',
    ],
  ),
  const SeekerProfile(
    id: '3',
    firstName: 'Naomi',
    age: 25,
    city: 'Manchester',
    gender: 'female',
    alreadyLikedYou: true,
    surnameLine: 'Fernandes',
    photos: [
      'https://picsum.photos/seed/selah3a/700/1000',
      'https://picsum.photos/seed/selah3b/700/1000',
      'https://picsum.photos/seed/selah3c/700/1000',
    ],
  ),
  const SeekerProfile(
    id: '4',
    firstName: 'Matthew',
    age: 29,
    city: 'Leeds',
    gender: 'male',
    // 2026-07-26 (Founder: "add surnames for everyone please") — this
    // was the one profile deliberately left without one last round, for
    // with/without contrast; completed now that the layout's been seen.
    surnameLine: 'Rashid',
    photos: ['https://picsum.photos/seed/selah4a/700/1000'],
  ),
  const SeekerProfile(
    id: '5',
    firstName: 'Phoebe',
    age: 26,
    city: 'Bristol',
    gender: 'female',
    surnameLine: 'Wright',
    photos: [
      'https://picsum.photos/seed/selah5a/700/1000',
      'https://picsum.photos/seed/selah5b/700/1000',
    ],
  ),
  const SeekerProfile(
    id: '6',
    firstName: 'Nathan',
    age: 31,
    city: 'Glasgow',
    gender: 'male',
    surnameLine: 'Brooks',
    photos: ['https://picsum.photos/seed/selah6a/700/1000'],
  ),
];
