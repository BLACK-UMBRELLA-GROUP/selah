import 'selah_signup_membership_choice.dart';
import '../data/selah_reference_data.dart';

export 'selah_signup_membership_choice.dart' show SelahSignupRole;

/// Private, same-device form recovery only. Never an identity or access grant.

class SelahInitialSignupDraft {
  final SelahSignupRole role;

  /// First unanswered essentials question, or questionCount for membership
  /// choice followed by verification. Membership never shifts these indices.
  final int step;
  final bool showIntroduction;
  final String? firstName;
  final String? lastName;
  final String? gender;
  final DateTime? dob;
  final String? relationship;

  /// Tokenless private Storage reference, never photo bytes or a signed URL.
  final String? firstPhotoPath;
  final SelahSignupMembershipChoice? membershipChoice;

  const SelahInitialSignupDraft({
    required this.role,
    this.step = 0,
    this.showIntroduction = false,
    this.firstName,
    this.lastName,
    this.gender,
    this.dob,
    this.relationship,
    this.firstPhotoPath,
    this.membershipChoice,
  });

  int get questionCount => role == SelahSignupRole.seeker ? 4 : 5;
  bool get needsMembershipChoice =>
      step == questionCount && membershipChoice == null;
  bool get awaitsVerification =>
      step == questionCount && membershipChoice != null;

  bool isValid({DateTime? now}) => _isValid(now: now, requireLastName: true);

  bool _isValid({
    DateTime? now,
    required bool requireLastName,
    bool legacyPhotoStep = false,
    bool legacyShepherdPhotoStep = false,
  }) {
    final today = now ?? DateTime.now();
    final count = legacyPhotoStep && role == SelahSignupRole.seeker
        ? 3
        : legacyShepherdPhotoStep && role == SelahSignupRole.shepherd
        ? 4
        : questionCount;
    if (step < 0 || step > count) return false;
    if (membershipChoice != null && !membershipChoice!.isValidFor(role)) {
      return false;
    }
    if (showIntroduction && (role != SelahSignupRole.seeker || step != 0)) {
      return false;
    }
    if (firstName != null &&
        (firstName!.trim() != firstName ||
            firstName!.isEmpty ||
            firstName!.length > 60)) {
      return false;
    }
    if (gender != null && gender != 'male' && gender != 'female') return false;
    if (lastName != null &&
        (lastName!.trim() != lastName ||
            lastName!.isEmpty ||
            lastName!.length > 60)) {
      return false;
    }
    if (dob != null) {
      final adult = DateTime(today.year - 18, today.month, today.day);
      if (dob!.year < 1900 ||
          dob!.isAfter(adult) ||
          dob!.hour != 0 ||
          dob!.minute != 0 ||
          dob!.second != 0 ||
          dob!.millisecond != 0 ||
          dob!.microsecond != 0) {
        return false;
      }
    }
    if (step > 0 && firstName == null) return false;
    if (requireLastName && step > 0 && lastName == null) return false;
    if (firstPhotoPath != null && !isPrivatePhotoPath(firstPhotoPath!)) {
      return false;
    }
    if (role == SelahSignupRole.seeker) {
      if (relationship != null) return false;
      if (step > 1 && gender == null) return false;
      if (step > 2 && dob == null) return false;
      if (!legacyPhotoStep && step > 3 && firstPhotoPath == null) return false;
    } else {
      if (legacyShepherdPhotoStep && firstPhotoPath != null) return false;
      if (step > 1 && dob == null) return false;
      if (step > 2 && gender == null) return false;
      if (relationship != null &&
          !relationshipsFor(gender).contains(relationship)) {
        return false;
      }
      if (step > 3 && relationship == null) return false;
      if (!legacyShepherdPhotoStep && step > 4 && firstPhotoPath == null) {
        return false;
      }
    }
    return true;
  }

  /// The current privacy processor writes one JPEG directly inside the
  /// owner's folder. Reject URLs, encoded traversal and arbitrary extra paths.
  static bool isPrivatePhotoPath(String path, {String? expectedUserId}) =>
      path.length <= 200 &&
      RegExp(
        r'^[A-Za-z0-9_-]{1,64}/[A-Za-z0-9_-]{1,128}\.jpg$',
      ).hasMatch(path) &&
      (expectedUserId == null || path.startsWith('$expectedUserId/'));

  /// A Shepherd is chosen for the support they offer, not selected from a
  /// gendered paternal-family list. Keep the legacy parameter so recovered
  /// call sites do not become a migration hazard; it deliberately has no
  /// effect on the available relationships.
  static List<String> relationshipsFor(String? gender) =>
      selahShepherdRelationshipNames;

  Map<String, Object?> toJson() => {
    'version': 6,
    'role': role.name,
    'step': step,
    'showIntroduction': showIntroduction,
    'firstName': firstName,
    'lastName': lastName,
    'gender': gender,
    'dob': dob == null
        ? null
        : '${dob!.year.toString().padLeft(4, '0')}-${dob!.month.toString().padLeft(2, '0')}-${dob!.day.toString().padLeft(2, '0')}',
    'relationship': relationship,
    'firstPhotoPath': firstPhotoPath,
    'membershipChoice': membershipChoice?.toJson(),
  };

  static SelahInitialSignupDraft fromJson(Map<String, dynamic> value) {
    final legacy = value['version'] == 1;
    final legacyPhotoStep =
        value['version'] != 4 &&
        value['version'] != 5 &&
        value['version'] != 6;
    final legacyShepherdPhotoStep =
        value['version'] != 5 && value['version'] != 6;
    if (value['version'] is! int ||
        (!legacy &&
            value['version'] != 2 &&
            value['version'] != 3 &&
            value['version'] != 4 &&
            value['version'] != 5 &&
            value['version'] != 6) ||
        value['step'] is! int ||
        value['showIntroduction'] is! bool ||
        !SelahSignupRole.values.any((role) => role.name == value['role'])) {
      throw const FormatException('Invalid signup draft.');
    }
    for (final key in [
      'firstName',
      'lastName',
      'gender',
      'dob',
      'relationship',
      'firstPhotoPath',
    ]) {
      if (value[key] != null && value[key] is! String) {
        throw const FormatException('Invalid signup draft.');
      }
    }
    // Older Shepherd schemas explicitly prohibited profile photos. Reject
    // an injected reference before moving their membership checkpoint back
    // to the new photo question; migration is not validation bypass.
    if (legacyShepherdPhotoStep &&
        value['role'] == SelahSignupRole.shepherd.name &&
        value['firstPhotoPath'] != null) {
      throw const FormatException('Invalid signup draft.');
    }
    DateTime? dob;
    if (value['dob'] != null) {
      final raw = value['dob'] as String;
      if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(raw)) {
        throw const FormatException('Invalid signup draft.');
      }
      dob = DateTime.tryParse(raw);
      if (dob == null || dob.toIso8601String().split('T').first != raw) {
        throw const FormatException('Invalid signup draft.');
      }
    }
    final draft = SelahInitialSignupDraft(
      role: SelahSignupRole.values.byName(value['role']),
      step: value['step'],
      showIntroduction: value['showIntroduction'],
      firstName: value['firstName'],
      lastName: value['lastName'],
      gender: value['gender'],
      dob: dob,
      relationship: value['version'] == 6
          ? value['relationship']
          : value['relationship'] == 'Paternal Uncle'
          ? 'Uncle'
          : value['relationship'] == 'Paternal Aunt'
          ? 'Aunt'
          : value['relationship'],
      firstPhotoPath: legacyPhotoStep ? null : value['firstPhotoPath'],
      membershipChoice:
          (value['version'] == 3 ||
                  value['version'] == 4 ||
                  value['version'] == 5) &&
              value['membershipChoice'] != null
          ? SelahSignupMembershipChoice.fromJson(
              value['membershipChoice'],
              role: SelahSignupRole.values.byName(value['role']),
            )
          : null,
    );
    // Validate the original checkpoint before migrating. An old draft must
    // collect the new required public surname, not silently skip it, lose
    // later answers or guess a surname from a provider display name.
    if (!draft._isValid(
      requireLastName: !legacy,
      legacyPhotoStep: legacyPhotoStep,
      legacyShepherdPhotoStep: legacyShepherdPhotoStep,
    )) {
      throw const FormatException('Invalid signup draft.');
    }
    if (legacy && draft.lastName == null && draft.step > 0) {
      return SelahInitialSignupDraft(
        role: draft.role,
        firstName: draft.firstName,
        gender: draft.gender,
        dob: draft.dob,
        relationship: draft.relationship,
      );
    }
    return draft;
  }
}
