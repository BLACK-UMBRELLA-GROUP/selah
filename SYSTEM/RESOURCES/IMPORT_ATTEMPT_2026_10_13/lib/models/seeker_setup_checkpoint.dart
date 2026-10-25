import '../services/selah_profile_service.dart';
import '../services/selah_seeker_details_service.dart';

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
  if (photoCount < 3 || (location ?? '').trim().isEmpty || details == null) {
    return false;
  }
  bool light(Object? value) => const {'green', 'yellow', 'red'}.contains(value);
  Map<dynamic, dynamic> section(String key) => details.preferences[key] is Map
      ? details.preferences[key] as Map
      : const {};
  final distance = section('location');
  if (distance['preference'] is! String ||
      (distance['preference'] as String).isEmpty ||
      !light(distance['flexibility'])) {
    return false;
  }
  if (article9Consent != false) {
    if ((details.sect ?? '').trim().isEmpty ||
        details.revertStatus == null ||
        (details.countryOfBirth ?? '').isEmpty ||
        (details.nationality ?? '').isEmpty ||
        (details.ethnicity ?? '').isEmpty) {
      return false;
    }
    final sect = section('sect');
    final matrix = sect['matrix'];
    final other = const {'Sunni', 'Shia'}.contains(details.sect)
        ? 'other'
        : selahSectCodeFor(details.sect!);
    if (matrix is! Map ||
        !['sunni', 'shia', other].every((key) => light(matrix[key])) ||
        !light(sect['outside_flexibility']) ||
        !light(section('revert')['flexibility'])) {
      return false;
    }
    for (final key in ['country_of_birth', 'nationality', 'ethnicity']) {
      final value = section(key);
      if (value['skipped'] == true) continue;
      if (value['preferred'] is! List ||
          (value['preferred'] as List).isEmpty ||
          !light(value['flexibility'])) {
        return false;
      }
    }
  }
  if (details.languages.isEmpty) return false;
  final languages = section('languages');
  return languages['skipped'] == true ||
      (languages['preferred'] is List &&
          (languages['preferred'] as List).isNotEmpty &&
          light(languages['flexibility']));
}
