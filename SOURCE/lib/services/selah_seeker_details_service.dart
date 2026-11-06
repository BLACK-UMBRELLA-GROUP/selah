// Chapter 2 persistence — Founder approved 2026-08-04.
//
// Before this, onboarding collected 31 values and persisted ONE (the city,
// wired 2026-08-04). `AppState.saveChapter2()` assigned three fields and
// called notifyListeners(). Close the app and Chapter 2 was gone.
//
// THE RULE THIS FILE EXISTS TO ENFORCE: store the code, never the label.
//
// Ratified when the production reference lists landed, and until today
// completely unexercised — `selahCodeFor()` had zero callers anywhere in
// the project. The pickers hand back DISPLAY STRINGS ("Pakistan",
// "Punjabi"), so every write has to convert and every read has to convert
// back. That conversion is this file's main job.
//
// Why it matters concretely: ISO 639-1 names two of this audience's
// most-spoken languages "Panjabi" and "Pushto" — spellings nobody would
// search for. Those labels are corrected in the reference data while the
// codes stay canonical. Had the label been the stored value, fixing the
// spelling would have orphaned every affected user's row.
//
// The database enforces this independently: CHECK constraints reject
// 'Pakistan' for a country and 'Pakistani' for an ethnicity outright.
// Verified 2026-08-04 — five label forms rejected, code row accepted.
//
// ARTICLE 9. Christian tradition, denomination, faith journey, ethnicity,
// country of birth and nationality are special-category data under UK GDPR.
// `saveDetails`
// refuses to write them without a recorded consent (see
// SelahConsentService). That check is here rather than only in the UI
// because a screen can be skipped, reordered or bypassed by a deep link,
// and this is the single point every write passes through.
//
// The Founder has confirmed a solicitor will review the consent wording,
// Privacy Policy, Terms and the Compatibility Unlock flow before public
// launch. NOT LEGAL ADVICE.

import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../data/selah_christian_traditions.dart';
import '../data/selah_reference_data.dart';
import '../main.dart';
import '../models/onboarding_question.dart';
import '../models/selah_marriage_values.dart';
import '../models/selah_non_faith_profile_save.dart';
import 'selah_account_state.dart';
import 'selah_auth.dart';
import 'selah_consent_service.dart';

/// One Seeker's Chapter 2 answers, in DISPLAY form.
///
/// Codes live in the database; this object holds labels, because that is
/// what every widget wants and what the pickers produce. Conversion
/// happens at the boundary — [toRow] on the way down, [fromRow] on the way
/// up — so no screen ever has to know a code exists.
class SeekerDetails {
  final String? christianFamily;
  final String? christianDenomination;
  final String? christianDenominationOther;
  final String? faithJourney;
  final bool showChristianTraditionOnProfile;
  final String? countryOfBirth;
  final String? nationality; // demonym, e.g. 'Pakistani'
  final String? ethnicity;
  final List<String> languages;
  final Map<String, dynamic> preferences;

  const SeekerDetails({
    this.christianFamily,
    this.christianDenomination,
    this.christianDenominationOther,
    this.faithJourney,
    this.showChristianTraditionOnProfile = false,
    this.countryOfBirth,
    this.nationality,
    this.ethnicity,
    this.languages = const [],
    this.preferences = const {},
  });

  /// Display labels -> stored codes.
  ///
  /// An unrecognised label is a BUG, not a value: it means a picker and the
  /// reference list have drifted apart. `selahCodeFor` returns null in that
  /// case and its own doc comment says callers must never store it. So an
  /// unconvertible answer is dropped and logged loudly rather than written
  /// as-is — writing the label would defeat the entire rule and the CHECK
  /// constraint would reject it anyway.
  Map<String, dynamic> toRow(String userId) {
    String? code(List<SelahRefItem> list, String? label, String field) {
      if (label == null) return null;
      final c = selahCodeFor(list, label);
      if (c == null) {
        debugPrint(
          'SELAH: no reference code for $field="$label" — NOT SAVED. '
          'A picker and selah_reference_data have drifted apart.',
        );
      }
      return c;
    }

    final family = selahChristianFamilyForLabel(christianFamily);
    final denomination = selahChristianDenominationForLabel(
      christianDenomination,
    );
    final denominationBelongsToFamily =
        family == null ||
        denomination == null ||
        family.denominations.any((item) => item.code == denomination.code);
    if (!denominationBelongsToFamily) {
      debugPrint(
        'SELAH: Christian denomination does not belong to the selected '
        'tradition — NOT SAVED.',
      );
    }
    final faithJourneyCode = selahFaithJourneyCodeForLabel(faithJourney);

    final countryCode = countryOfBirth == null
        ? null
        : selahCountryCodeFor(countryOfBirth);
    final natCode = nationality == null
        ? null
        : selahNationalityCodeFor(nationality);
    if (countryOfBirth != null && countryCode == null) {
      debugPrint(
        'SELAH: no ISO code for country_of_birth="$countryOfBirth" — NOT SAVED.',
      );
    }
    if (nationality != null && natCode == null) {
      debugPrint(
        'SELAH: no ISO code for nationality="$nationality" — NOT SAVED.',
      );
    }

    final langCodes = <String>[];
    for (final l in languages) {
      final c = selahCodeFor(selahLanguages, l);
      if (c == null) {
        debugPrint('SELAH: no ISO 639-1 code for language="$l" — NOT SAVED.');
      } else {
        langCodes.add(c);
      }
    }

    return {
      'user_id': userId,
      'christian_family_code': family?.code,
      'christian_denomination_code': denominationBelongsToFamily
          ? denomination?.code
          : null,
      'christian_denomination_other':
          denomination != null &&
              denomination.code.startsWith('other_') &&
              christianDenominationOther != null
          ? (christianDenominationOther!.length > 80
                ? christianDenominationOther!.substring(0, 80)
                : christianDenominationOther)
          : null,
      'faith_journey_code': faithJourneyCode,
      'faith_visibility': showChristianTraditionOnProfile
          ? 'profile'
          : 'compatibility_only',
      'christian_taxonomy_version': selahChristianTaxonomyVersion,
      'country_of_birth': countryCode,
      'nationality': natCode,
      'ethnicity': code(selahEthnicities, ethnicity, 'ethnicity'),
      'languages': langCodes,
      'preferences': preferences,
    };
  }

  /// Stored codes -> display labels.
  static SeekerDetails fromRow(Map<String, dynamic> r) {
    String? label(List<SelahRefItem> list, Object? code) {
      if (code == null) return null;
      for (final i in list) {
        if (i.code == code) return i.name;
      }
      // A code with no label means the reference list dropped an entry
      // that users already hold. Surfaced rather than rendered blank.
      debugPrint(
        'SELAH: stored code "$code" has no label in the current '
        'reference list — an entry was removed without a migration.',
      );
      return null;
    }

    final family = selahChristianFamilyForCode(
      r['christian_family_code'] as String?,
    );
    final denomination = selahChristianDenominationForCode(
      r['christian_denomination_code'] as String?,
    );
    final faithJourneyCode = r['faith_journey_code'] as String?;
    return SeekerDetails(
      // Selah never infers a Christian answer from inherited faith fields.
      // A missing new code means the member re-answers.
      christianFamily: family?.label,
      christianDenomination: denomination?.label,
      christianDenominationOther: r['christian_denomination_other'] as String?,
      faithJourney: faithJourneyCode == null
          ? null
          : selahFaithJourneyLabels[faithJourneyCode],
      showChristianTraditionOnProfile: r['faith_visibility'] == 'profile',
      countryOfBirth: () {
        final c = r['country_of_birth'];
        if (c == null) return null;
        for (final x in selahCountries) {
          if (x.code == c) return x.name;
        }
        return null;
      }(),
      nationality: () {
        final c = r['nationality'];
        if (c == null) return null;
        for (final x in selahCountries) {
          if (x.code == c) return x.nationality;
        }
        return null;
      }(),
      ethnicity: label(selahEthnicities, r['ethnicity']),
      languages: [
        for (final c in (r['languages'] as List? ?? const []))
          ?label(selahLanguages, c),
      ],
      preferences: Map<String, dynamic>.from(
        r['preferences'] as Map? ?? const {},
      ),
    );
  }
}

class SelahSeekerDetailsService {
  SelahSeekerDetailsService._();

  /// Serialises the traffic-light structures Chapter 2 collects.
  ///
  /// Uses the SAME green/yellow/red vocabulary as
  /// `onboarding_answers.ch4_preferences`, deliberately: `score_candidates()`
  /// already reads that vocabulary in Postgres, so a future Chapter-2-aware
  /// scorer reuses its logic unchanged instead of learning a second dialect.
  static Map<String, dynamic> buildPreferences({
    String? distancePref,
    TrafficLight? distanceFlex,
    String? traditionPreferenceScope,
    List<String> selectedChristianFamilies = const [],
    bool traditionHardRequirement = false,
    TrafficLight? traditionOutsideFlex,
    TrafficLight? faithJourneyFlex,
    List<String> countryPrefs = const [],
    bool countrySkipped = false,
    TrafficLight? countryFlex,
    List<String> nationalityPrefs = const [],
    bool nationalitySkipped = false,
    TrafficLight? nationalityFlex,
    List<String> ethnicityPrefs = const [],
    bool ethnicitySkipped = false,
    TrafficLight? ethnicityFlex,
    List<String> languagePrefs = const [],
    bool languageSkipped = false,
    TrafficLight? languageFlex,
  }) {
    List<String> codes(List<SelahRefItem> list, List<String> labels) => [
      for (final l in labels) ?selahCodeFor(list, l),
    ];

    return {
      'location': {
        'preference': selahCodeFor(selahLocationPreferences, distancePref),
        'flexibility': distanceFlex?.name,
      },
      'church_background': {
        'scope': selahChurchPreferenceScopeCodeForLabel(
          traditionPreferenceScope,
        ),
        'family_codes': [
          for (final label in selectedChristianFamilies)
            ?selahChristianFamilyForLabel(label)?.code,
        ],
        'hard_requirement': traditionHardRequirement,
        'outside_flexibility': traditionOutsideFlex?.name,
      },
      'faith_journey': {'flexibility': faithJourneyFlex?.name},
      'country_of_birth': {
        'preferred': codes([
          for (final c in selahCountries) SelahRefItem(c.code, c.name),
        ], countryPrefs),
        'skipped': countrySkipped,
        'flexibility': countryFlex?.name,
      },
      'nationality': {
        'preferred': [
          for (final l in nationalityPrefs) ?selahNationalityCodeFor(l),
        ],
        'skipped': nationalitySkipped,
        'flexibility': nationalityFlex?.name,
      },
      'ethnicity': {
        'preferred': codes(selahEthnicities, ethnicityPrefs),
        'skipped': ethnicitySkipped,
        'flexibility': ethnicityFlex?.name,
      },
      'languages': {
        'preferred': codes(selahLanguages, languagePrefs),
        'skipped': languageSkipped,
        'flexibility': languageFlex?.name,
      },
    };
  }

  /// Writes the signed-in Seeker's Chapter 2 answers.
  ///
  /// Returns false without writing if Article 9 consent has not been
  /// recorded. That is not belt-and-braces: a UI gate can be skipped by a
  /// deep link, a reordered flow or a future refactor, and this is the one
  /// place every write passes through.
  static Future<bool> saveDetails(
    SeekerDetails d, {
    String? expectedUserId,
  }) async {
    try {
      final user = SelahAuth.currentUser;
      final generation = SelahAccountState.generation;
      if (user == null ||
          SelahAccountState.isSigningOut ||
          (expectedUserId != null && user.id != expectedUserId)) {
        return false;
      }
      // Preferences and languages can be mutable. Capture the submitted
      // draft before the consent read yields, not when that read completes.
      final payload = Map<String, dynamic>.from(
        jsonDecode(jsonEncode(d.toRow(user.id))),
      );
      if (!await SelahConsentService.hasArticle9Consent()) {
        debugPrint(
          'SELAH: refusing to save Chapter 2 — no Article 9 consent on '
          'record for this user. Special-category data (religious belief, '
          'ethnic origin) must not be stored without it.',
        );
        return false;
      }

      if (SelahAccountState.isSigningOut ||
          SelahAccountState.generation != generation ||
          SelahAuth.currentUser?.id != user.id) {
        return false;
      }
      final saved = await supabase
          .from('seeker_details')
          .upsert(payload)
          .select('user_id')
          .maybeSingle();
      return saved?['user_id'] == user.id &&
          !SelahAccountState.isSigningOut &&
          SelahAccountState.generation == generation &&
          SelahAuth.currentUser?.id == user.id;
    } catch (e) {
      // Logged, never silent (ES-08). These answers are half the input the
      // compatibility score will ever have; a persistent failure here makes
      // the premium feature compute from nothing while the app looks fine.
      debugPrint(
        'SELAH: saveDetails failed — Chapter 2 answers not persisted (${e.runtimeType}).',
      );
      return false;
    }
  }

  /// Saves only asked nonfaith fields when the faith questions were skipped.
  /// The full-details Article 9 guard above remains unchanged.
  static Future<bool> saveNonFaithDetails({
    List<String>? languages,
    SelahMarriageValuesAnswers? marriageValues,
    Map<String, dynamic>? locationPreference,
    String? expectedUserId,
  }) async {
    try {
      final user = SelahAuth.currentUser;
      final generation = SelahAccountState.generation;
      if (user == null ||
          (expectedUserId != null && user.id != expectedUserId)) {
        return false;
      }
      bool current() =>
          !SelahAccountState.isSigningOut &&
          SelahAuth.currentUser?.id == user.id &&
          SelahAccountState.generation == generation;
      return selahSaveNonFaithProfile(
        userId: user.id,
        languages: languages,
        marriageValues: marriageValues,
        locationPreference: locationPreference,
        canAct: current,
        readStoredPreferences: () async {
          if (!current()) throw StateError('Account changed.');
          final row = await supabase
              .from('seeker_details')
              .select('user_id,preferences')
              .eq('user_id', user.id)
              .maybeSingle();
          if (!current() || (row != null && row['user_id'] != user.id)) {
            throw StateError('Account changed.');
          }
          return Map<String, dynamic>.from(
            row?['preferences'] as Map? ?? const {},
          );
        },
        write: (payload) async {
          if (!current()) return false;
          final saved = await supabase
              .from('seeker_details')
              .upsert(payload)
              .select('user_id')
              .maybeSingle();
          return current() && saved?['user_id'] == user.id;
        },
      );
    } catch (_) {
      return false;
    }
  }

  /// The signed-in Seeker's own answers, for re-entering Chapter 2.
  static Future<SeekerDetails?> fetchOwn({
    String? expectedUserId,
    bool throwOnError = false,
  }) async {
    try {
      final user = SelahAuth.currentUser;
      final generation = SelahAccountState.generation;
      if (user == null ||
          SelahAccountState.isSigningOut ||
          (expectedUserId != null && user.id != expectedUserId)) {
        throw StateError('Account changed.');
      }
      final row = await supabase
          .from('seeker_details')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();
      if (SelahAuth.currentUser?.id != user.id ||
          SelahAccountState.isSigningOut ||
          SelahAccountState.generation != generation) {
        throw StateError('Account changed.');
      }
      if (row != null && row['user_id'] != user.id) {
        throw StateError('Saved profile details unavailable.');
      }
      return row == null ? null : SeekerDetails.fromRow(row);
    } catch (e) {
      debugPrint('SELAH: fetchOwn seeker_details failed (${e.runtimeType}).');
      if (throwOnError) rethrow;
      return null;
    }
  }

  /// Another Seeker's answers, and ONLY if this user has unlocked them.
  ///
  /// Goes through `seeker_details_for_unlocked()`, a SECURITY DEFINER
  /// function that checks `profile_unlocks` first. There is deliberately no
  /// RLS policy letting one Seeker select this table directly — verified
  /// 2026-08-04: a user holding a real unlock still reads zero rows by
  /// direct select, and gets the data only through this call.
  ///
  /// Returns null when not unlocked, which is indistinguishable from "no
  /// answers recorded". That is intended — the absence of a purchase should
  /// not be reported differently from the absence of data.
  static Future<SeekerDetails?> fetchUnlocked(String profileId) async {
    if (SelahAuth.currentUser == null) return null;
    try {
      final rows =
          await supabase.rpc(
                'seeker_details_for_unlocked',
                params: {'p_target': profileId},
              )
              as List?;
      if (rows == null || rows.isEmpty) return null;
      return SeekerDetails.fromRow(
        Map<String, dynamic>.from(rows.first as Map),
      );
    } catch (e) {
      debugPrint('SELAH: fetchUnlocked($profileId) failed — $e');
      return null;
    }
  }
}
