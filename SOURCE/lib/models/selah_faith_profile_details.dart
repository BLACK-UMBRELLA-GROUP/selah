import '../services/selah_seeker_details_service.dart';
import 'selah_faith_profile.dart';

SelahFaithProfileAnswers selahFaithProfileAnswersFromDetails(
  SeekerDetails? details,
) {
  final saved = details?.preferences['faith_profile'];
  return SelahFaithProfileAnswers.fromMap(saved is Map ? saved : const {});
}

/// Updates the existing details owner and JSON preferences contract. No second
/// saved Faith snapshot or inference from old Chapter 2 answers is introduced.
SeekerDetails selahApplyFaithProfileAnswers(
  SeekerDetails? details,
  SelahFaithProfileAnswers answers,
) {
  final previous = details ?? const SeekerDetails();
  return SeekerDetails(
    christianFamily: answers.christianFamily,
    christianDenomination: answers.christianDenomination,
    christianDenominationOther: null,
    faithJourney: answers.faithJourneyLabel,
    showChristianTraditionOnProfile: true,
    countryOfBirth: previous.countryOfBirth,
    nationality: previous.nationality,
    ethnicity: previous.ethnicity,
    languages: List.unmodifiable(previous.languages),
    preferences: answers.mergePreferences(previous.preferences),
  );
}
