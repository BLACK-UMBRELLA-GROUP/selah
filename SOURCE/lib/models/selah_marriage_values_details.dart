import '../services/selah_seeker_details_service.dart';
import 'selah_marriage_values.dart';

SelahMarriageValuesAnswers selahMarriageValuesAnswersFromDetails(
  SeekerDetails? details,
) {
  final saved = details?.preferences['marriage_values'];
  return SelahMarriageValuesAnswers.fromMap(saved is Map ? saved : const {});
}

/// Keeps all seven exact answers in the existing profile's preferences JSON.
/// Faith and retained compatibility fields are preserved without new mapping.
SeekerDetails selahApplyMarriageValuesAnswers(
  SeekerDetails? details,
  SelahMarriageValuesAnswers answers,
) {
  final previous = details ?? const SeekerDetails();
  return SeekerDetails(
    christianFamily: previous.christianFamily,
    christianDenomination: previous.christianDenomination,
    christianDenominationOther: previous.christianDenominationOther,
    faithJourney: previous.faithJourney,
    showChristianTraditionOnProfile: previous.showChristianTraditionOnProfile,
    countryOfBirth: previous.countryOfBirth,
    nationality: previous.nationality,
    ethnicity: previous.ethnicity,
    languages: List.unmodifiable(previous.languages),
    preferences: answers.mergePreferences(previous.preferences),
  );
}
