import 'dart:convert';

import '../data/selah_reference_data.dart';
import 'selah_marriage_values.dart';

/// Retired/unasked sections keep their stored values rather than being rebuilt
/// from the old widgets' defaults or normalised through their reference lists.
Map<String, dynamic> selahMergeAskedProfilePreferences(
  Map<String, dynamic> stored,
  Map<String, dynamic> updated,
) => {
  ...stored,
  for (final entry in updated.entries)
    if (!const {
      'country_of_birth',
      'nationality',
      'ethnicity',
      'languages',
      'faith_journey',
    }.contains(entry.key))
      entry.key: entry.value is Map && stored[entry.key] is Map
          ? {...stored[entry.key] as Map, ...entry.value as Map}
          : entry.value,
};

/// The actual narrow save coordinator, shared by the retained service and
/// local guard/payload checks. It never accepts faith/background column values.
Future<bool> selahSaveNonFaithProfile({
  required String userId,
  List<String>? languages,
  SelahMarriageValuesAnswers? marriageValues,
  Map<String, dynamic>? locationPreference,
  required bool Function() canAct,
  required Future<Map<String, dynamic>> Function() readStoredPreferences,
  required Future<bool> Function(Map<String, dynamic> payload) write,
}) async {
  var denied = false;
  bool current() {
    if (denied) return false;
    try {
      if (canAct()) return true;
    } catch (_) {}
    denied = true;
    return false;
  }

  if (!current() ||
      userId.isEmpty ||
      (languages == null &&
          marriageValues == null &&
          locationPreference == null)) {
    return false;
  }
  final languageCodes = <String>[];
  if (languages != null) {
    if (languages.isEmpty) return false;
    for (final label in List<String>.of(languages)) {
      final code = selahCodeFor(selahLanguages, label);
      if (code == null) return false;
      if (!languageCodes.contains(code)) languageCodes.add(code);
    }
  }
  if (marriageValues != null && !marriageValues.canSave) return false;
  Map<String, dynamic>? location;
  if (locationPreference != null) {
    final preference = locationPreference['preference'];
    final flexibility = locationPreference['flexibility'];
    if (!selahLocationPreferences.any((item) => item.code == preference) ||
        !const {'green', 'yellow', 'red'}.contains(flexibility)) {
      return false;
    }
    location = {'preference': preference, 'flexibility': flexibility};
  }

  try {
    final payload = <String, dynamic>{
      'user_id': userId,
      if (languages != null) 'languages': languageCodes,
    };
    if (marriageValues != null || location != null) {
      final stored = await readStoredPreferences();
      if (!current()) return false;
      // Capture all stored sections without changing an old special-category
      // value. Only the two explicitly supplied nonfaith sections are merged.
      final preferences = Map<String, dynamic>.from(
        jsonDecode(jsonEncode(stored)) as Map,
      );
      if (marriageValues != null) {
        preferences['marriage_values'] = {
          if (preferences['marriage_values'] is Map)
            ...preferences['marriage_values'] as Map,
          ...marriageValues.toMap(),
        };
      }
      if (location != null) {
        preferences['location'] = {
          if (preferences['location'] is Map) ...preferences['location'] as Map,
          ...location,
        };
      }
      payload['preferences'] = preferences;
    }
    if (!current()) return false;
    final saved = await write(payload);
    return current() && saved;
  } catch (_) {
    return false;
  }
}
