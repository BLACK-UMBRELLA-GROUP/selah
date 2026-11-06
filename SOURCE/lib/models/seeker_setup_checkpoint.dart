import '../services/selah_profile_service.dart';
import '../services/selah_seeker_details_service.dart';
import 'seeker_profile_completion.dart';

/// Account admission is already complete. This selects the first unfinished
/// profile section; it never grants identity, discovery or publication.
enum SeekerSetupCheckpoint {
  profile,
  bio,
  compatibility,
  review;

  static SeekerSetupCheckpoint select({
    required SelahOnboardingProgress progress,
    required bool bioReviewed,
    bool compatibilityStarted = false,
    bool? profileSectionComplete,
  }) {
    if (progress.complete) return review;
    if (!(profileSectionComplete ?? progress.hasChapter2)) return profile;
    // Legacy saved compatibility proves the optional Bio step was already
    // passed. An intentionally empty Bio is otherwise tracked explicitly.
    if (!bioReviewed && !compatibilityStarted) return bio;
    if (progress.due <= 0 || progress.missing > 0) return compatibility;
    return review;
  }
}

/// `has_chapter_2` means a saved preferences row exists, not that every
/// profile question is finished. Resume checks the actual saved fields.
bool seekerProfileSectionComplete({
  required SeekerDetails? details,
  required int photoCount,
  required String? location,
  required bool? article9Consent,
}) {
  if (details == null) return false;
  return seekerProfileFieldsComplete(
    christianFamily: details.christianFamily,
    faithJourney: details.faithJourney,
    countryOfBirth: details.countryOfBirth,
    nationality: details.nationality,
    ethnicity: details.ethnicity,
    languages: details.languages,
    preferences: details.preferences,
    photoCount: photoCount,
    location: location,
    article9Consent: article9Consent,
  );
}
