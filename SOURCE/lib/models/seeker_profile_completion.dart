import '../data/selah_christian_traditions.dart';
import 'selah_faith_profile.dart';

/// Field-only completion rules shared by the typed checkpoint and local model
/// checks. This does not save answers, change consent or grant app access.
bool seekerProfileFieldsComplete({
  required String? christianFamily,
  required String? faithJourney,
  required String? countryOfBirth,
  required String? nationality,
  required String? ethnicity,
  required List<String> languages,
  required Map<String, dynamic> preferences,
  required int photoCount,
  required String? location,
  required bool? article9Consent,
}) {
  if (photoCount < 3 || (location ?? '').trim().isEmpty) return false;

  bool light(Object? value) => const {'green', 'yellow', 'red'}.contains(value);
  Map<dynamic, dynamic> section(String key) =>
      preferences[key] is Map ? preferences[key] as Map : const {};

  final distance = section('location');
  if (distance['preference'] is! String ||
      (distance['preference'] as String).isEmpty ||
      !light(distance['flexibility'])) {
    return false;
  }

  if (article9Consent != false) {
    if ((christianFamily ?? '').trim().isEmpty ||
        faithJourney == null ||
        (countryOfBirth ?? '').isEmpty ||
        (nationality ?? '').isEmpty ||
        (ethnicity ?? '').isEmpty) {
      return false;
    }

    final church = section('church_background');
    final scope = church['scope'];
    if (!selahChurchPreferenceScopeLabels.containsKey(scope) ||
        (scope == 'selected' &&
            (church['family_codes'] is! List ||
                (church['family_codes'] as List).isEmpty))) {
      return false;
    }
    final faithProfile = section('faith_profile');
    if (!light(church['outside_flexibility']) ||
        !SelahFaithProfileAnswers.optionsFor(
          2,
        ).contains(faithProfile['church']) ||
        !SelahFaithProfileAnswers.optionsFor(
          3,
        ).contains(faithProfile['baptised'])) {
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

  if (languages.isEmpty) return false;
  final languagePreference = section('languages');
  return languagePreference['skipped'] == true ||
      (languagePreference['preferred'] is List &&
          (languagePreference['preferred'] as List).isNotEmpty &&
          light(languagePreference['flexibility']));
}
