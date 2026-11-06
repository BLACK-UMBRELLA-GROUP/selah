import 'seeker_profile.dart';

/// The existing Introduction DTO, shared by the retained read service and
/// the same-account offline draft. It carries no server or account authority.
class ShepherdSuggestion {
  final SeekerProfile profile;
  final String suggestedBy;

  /// Badge state only. Reading is distinct from resolving an Introduction;
  /// neither state is exposed to the suggesting Shepherd.
  final bool unseen;

  const ShepherdSuggestion({
    required this.profile,
    required this.suggestedBy,
    this.unseen = false,
  });

  /// Detach mutable photo input before retaining a local Introduction. All
  /// remaining public profile projections are immutable value objects.
  ShepherdSuggestion snapshot({bool? unseen}) => ShepherdSuggestion(
    profile: SeekerProfile(
      id: profile.id,
      firstName: profile.firstName,
      age: profile.age,
      city: profile.city,
      photos: List<String>.unmodifiable(profile.photos),
      gender: profile.gender,
      surnameLine: profile.surnameLine,
      publicNationality: profile.publicNationality,
      publicEthnicity: profile.publicEthnicity,
      faithProfile: profile.faithProfile,
      faithDenominationText: profile.faithDenominationText,
      marriageValues: profile.marriageValues,
      videoPhotoIndex: profile.videoPhotoIndex,
      alreadyLikedYou: profile.alreadyLikedYou,
    ),
    suggestedBy: suggestedBy,
    unseen: unseen ?? this.unseen,
  );
}
