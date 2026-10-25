// Chapter 3/4 onboarding answer persistence — inherited decision 082 (PROPOSED,
// awaiting Founder ratification). Syncs ValuesPreferencesFlow's local
// widget state (_ch3Answers/_ch4Preferences/_ch4HardRequirement) to
// the onboarding_answers table so answers survive beyond the widget's
// lifetime — previously they were held only in memory and lost the
// moment the flow was disposed.
//
// Checkpoints return confirmed own-row persistence. Onboarding callers await
// them and retain entered answers for retry when a save fails; they never
// present unsaved answers as durable progress.

// VERIFIED AGAINST THE LIVE DATABASE 2026-08-04, because the table had
// zero rows and it was not obvious whether that meant "broken" or "nobody
// has got there yet". Everything on the write path checks out:
//
//   PRIMARY KEY (user_id)      the upsert below has a real conflict target,
//                              so a second sync updates rather than
//                              duplicating or failing.
//   RLS insert/select/update   all three `user_id = auth.uid()`. An upsert
//                              needs BOTH insert and update policies to
//                              exist; both do.
//   FK -> profiles(id)         satisfied by Chapter 1, which runs first.
//   Payload shape              a test row carrying all three JSONB
//                              structures — including the nested
//                              question -> option -> traffic-light map —
//                              round-tripped exactly. Test row deleted;
//                              table confirmed back to zero rows.
//   Call site                  values_preferences_flow `_next()` fires this
//                              at every category summary.
//
// So the table is empty because no one has walked Chapter 3 while signed
// in to a real Supabase session — not because this is broken. Recorded so
// the next person does not re-investigate from scratch.

import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../main.dart';
import '../models/journey_bio.dart';
import '../models/onboarding_question.dart';
import '../state/app_state.dart';
import 'selah_auth.dart';
import 'selah_account_state.dart';
import 'selah_internal_preview_client.dart';

class SelahOnboardingAnswersSnapshot {
  final Map<String, dynamic> ch3Answers;
  final Map<String, Map<String, TrafficLight>> ch4Preferences;
  final Map<String, Set<String>> ch4HardRequirements;
  final JourneyBio journeyBio;

  const SelahOnboardingAnswersSnapshot({
    required this.ch3Answers,
    required this.ch4Preferences,
    required this.ch4HardRequirements,
    required this.journeyBio,
  });
}

class SelahOnboardingAnswersService {
  SelahOnboardingAnswersService._();

  static bool? _clientReadyForTesting;

  static bool get clientReady => _clientReadyForTesting ?? supabaseReady;

  @visibleForTesting
  static void setClientReadyForTesting(bool? ready) {
    assert(() {
      _clientReadyForTesting = ready;
      return true;
    }());
  }

  static (String, int) _captureActor(String? expectedUserId) {
    if (!clientReady ||
        SelahInternalPreviewClient.isActive ||
        SelahAccountState.isSigningOut) {
      throw StateError('The setup account is no longer available.');
    }
    final userId = SelahAuth.currentUser?.id;
    if (userId == null ||
        userId.isEmpty ||
        (expectedUserId != null && expectedUserId != userId)) {
      throw StateError('The setup account is no longer available.');
    }
    return (userId, SelahAccountState.generation);
  }

  static void _requireActor((String, int) actor) {
    if (!clientReady ||
        SelahInternalPreviewClient.isActive ||
        SelahAccountState.isSigningOut ||
        SelahAuth.currentUser?.id != actor.$1 ||
        SelahAccountState.generation != actor.$2) {
      throw StateError('The setup account changed.');
    }
  }

  /// `ch3_q26` has male and female client variants, but the persisted bank
  /// deliberately has one canonical qid. Strip only the explicit variant
  /// suffix at the persistence boundary; ordinary qids and Journey Bio keys
  /// pass through unchanged.
  static String persistedQuestionId(String responseKey) =>
      responseKey.split('::').first;

  /// Reads the signed-in Seeker's saved compatibility and Journey Bio draft.
  ///
  /// The former flow persisted category checkpoints but never read them on
  /// re-entry, so "continue later" restarted at question one and could
  /// overwrite already-saved answers. This is the inverse of [syncAnswers].
  static Future<SelahOnboardingAnswersSnapshot?> fetchOwn({
    String? expectedUserId,
    bool throwOnError = false,
  }) async {
    try {
      final actor = _captureActor(expectedUserId);
      final row = await supabase
          .from('onboarding_answers')
          .select('ch3_answers, ch4_preferences, ch4_hard_requirements')
          .eq('user_id', actor.$1)
          .maybeSingle();
      _requireActor(actor);
      if (row == null) return null;

      final rawCh3 = Map<String, dynamic>.from(
        row['ch3_answers'] as Map? ?? const {},
      );
      final preferences = <String, Map<String, TrafficLight>>{};
      final rawPreferences = row['ch4_preferences'];
      if (rawPreferences is Map) {
        for (final question in rawPreferences.entries) {
          if (question.key is! String || question.value is! Map) continue;
          final values = <String, TrafficLight>{};
          for (final option in (question.value as Map).entries) {
            if (option.key is! String || option.value is! String) continue;
            final light = switch (option.value as String) {
              'green' => TrafficLight.green,
              'yellow' => TrafficLight.yellow,
              'red' => TrafficLight.red,
              _ => null,
            };
            if (light != null) values[option.key as String] = light;
          }
          if (values.isNotEmpty) {
            preferences[question.key as String] = values;
          }
        }
      }

      final hardRequirements = <String, Set<String>>{};
      final rawHard = row['ch4_hard_requirements'];
      if (rawHard is Map) {
        for (final question in rawHard.entries) {
          if (question.key is! String || question.value is! List) continue;
          final options = (question.value as List).whereType<String>().toSet();
          if (options.isNotEmpty) {
            hardRequirements[question.key as String] = options;
          }
        }
      }

      return SelahOnboardingAnswersSnapshot(
        ch3Answers: rawCh3,
        ch4Preferences: preferences,
        ch4HardRequirements: hardRequirements,
        journeyBio: JourneyBio.fromOnboardingAnswers(rawCh3),
      );
    } catch (e) {
      debugPrint('SELAH: onboarding answer restore failed (${e.runtimeType}).');
      if (throwOnError) rethrow;
      return null;
    }
  }

  /// Upserts the full current answer state for the signed-in user.
  /// The caller decides checkpoint frequency. Capture a detached JSON payload
  /// before awaiting so edits and principal changes cannot mutate a request.
  static Future<bool> syncAnswers({
    required Map<String, dynamic> ch3Answers,
    required Map<String, Map<String, TrafficLight>> ch4Preferences,
    required Map<String, Set<String>> ch4HardRequirements,
    String? expectedUserId,
  }) async {
    try {
      final actor = _captureActor(expectedUserId);
      // Journey Bio metadata shares this own-row-only JSON store, but is not
      // a scored question. Always merge it back at a Values checkpoint so
      // the Chapter 3 write cannot erase the preceding Bio chapter.
      final completeCh3Answers = <String, dynamic>{
        ...AppState.instance.journeyBio.toOnboardingAnswers(),
        for (final entry in ch3Answers.entries)
          persistedQuestionId(entry.key): entry.value,
      };
      final payload = Map<String, dynamic>.from(
        jsonDecode(
          jsonEncode({
            'user_id': actor.$1,
            'ch3_answers': completeCh3Answers,
            'ch4_preferences': {
              for (final entry in ch4Preferences.entries)
                persistedQuestionId(entry.key): {
                  for (final option in entry.value.entries)
                    option.key: option.value.name,
                },
            },
            // PER-OPTION SINCE 2026-08-10 —
            // {question_id: [option_label, ...]}. WAS {question_id: bool}.
            // Empty sets are dropped rather than written as `[]`.
            'ch4_hard_requirements': {
              for (final entry in ch4HardRequirements.entries)
                if (entry.value.isNotEmpty)
                  persistedQuestionId(entry.key): entry.value.toList(),
            },
          }),
        ),
      );
      _requireActor(actor);
      final saved = await supabase
          .from('onboarding_answers')
          .upsert(payload)
          // A successful request is not enough proof under RLS: an UPDATE
          // can match zero rows without throwing. Returning the own row makes
          // Profile editing confirm that the write actually landed.
          .select('user_id')
          .single();
      _requireActor(actor);
      return saved['user_id'] == actor.$1;
    } catch (e) {
      // LOGGED 2026-08-04. This was `catch (_) {}` — completely silent.
      //
      // The entered draft remains in the calling screen. False means retry;
      // it must never be translated into a saved/complete claim.
      debugPrint(
        'SELAH: onboarding answer sync failed — Chapter 3/4 answers '
        'not saved for this checkpoint. Compatibility cannot be computed '
        'without them (${e.runtimeType}).',
      );
      return false;
    }
  }

  /// Saves the optional Journey Bio before Chapter 3 begins, using the
  /// existing own-row-only onboarding JSON. No schema change is needed and
  /// the public `profiles.bio` column is deliberately not used: its profile
  /// visibility is broader than the Founder-approved Journey-only reveal.
  static Future<bool> syncJourneyBio(
    JourneyBio bio, {
    String? expectedUserId,
  }) async {
    try {
      final actor = _captureActor(expectedUserId);
      final incoming = Map<String, dynamic>.from(
        jsonDecode(jsonEncode(bio.toOnboardingAnswers())),
      );
      final existing = await supabase
          .from('onboarding_answers')
          .select('ch3_answers, ch4_preferences, ch4_hard_requirements')
          .eq('user_id', actor.$1)
          .maybeSingle();
      _requireActor(actor);

      final existingCh3 = Map<String, dynamic>.from(
        (existing?['ch3_answers'] as Map?) ?? const {},
      );
      existingCh3.removeWhere((key, _) => key.startsWith('bio_'));
      existingCh3.addAll(incoming);

      final saved = await supabase
          .from('onboarding_answers')
          .upsert({
            'user_id': actor.$1,
            'ch3_answers': existingCh3,
            'ch4_preferences': Map<String, dynamic>.from(
              (existing?['ch4_preferences'] as Map?) ?? const {},
            ),
            'ch4_hard_requirements': Map<String, dynamic>.from(
              (existing?['ch4_hard_requirements'] as Map?) ?? const {},
            ),
          })
          .select('user_id')
          .single();
      _requireActor(actor);
      return saved['user_id'] == actor.$1;
    } catch (e) {
      debugPrint(
        'SELAH: Journey Bio sync failed — the draft remains available in '
        'this onboarding session (${e.runtimeType}).',
      );
      return false;
    }
  }
}
