import '../models/selah_known_person_code.dart';
import '../services/selah_mentor_link_service.dart';

/// Founder-preview-only discovery codes.
///
/// These values deliberately do not match the live SELAH Code format. They
/// cannot be stored by the production schema or resolved by the live RPCs.
class SelahDevPersonalCodeFixtures {
  SelahDevPersonalCodeFixtures._();

  static const invalidEntryCode = 'SELAH-0000-0000-0000-0000-0000';
  static const validSeekerEntryCode = 'SELAH-DEMO-SEEKER-JAMES';
  static const validShepherdEntryCode = 'SELAH-DEMO-SHEPHERD-DAVID';

  static String validKnownPersonEntryCode({required String? currentGender}) =>
      currentGender == 'female'
      ? 'SELAH-DEMO-SEEKER-JAMES'
      : 'SELAH-DEMO-SEEKER-ABIGAIL';

  static SelahKnownPersonCodePreview? previewKnownPersonCode(
    String code, {
    required String? currentGender,
  }) {
    if (code.trim().toUpperCase() !=
        validKnownPersonEntryCode(currentGender: currentGender)) {
      return null;
    }
    return currentGender == 'female'
        ? const SelahKnownPersonCodePreview(
            firstName: 'James',
            age: 29,
            city: 'London',
          )
        : const SelahKnownPersonCodePreview(
            firstName: 'Abigail',
            age: 27,
            city: 'Birmingham',
          );
  }

  static SelahPersonalCode forPersona({
    required bool asShepherd,
    required String? gender,
  }) {
    final female = gender == 'female';
    return SelahPersonalCode(
      code: switch ((asShepherd, female)) {
        (false, false) => 'SELAH-DEMO-SEEKER-JAMES',
        (false, true) => 'SELAH-DEMO-SEEKER-ABIGAIL',
        (true, false) => 'SELAH-DEMO-SHEPHERD-DAVID',
        (true, true) => 'SELAH-DEMO-SHEPHERD-AMA',
      },
      roleContext: asShepherd ? 'mentor' : 'seeker',
    );
  }

  static String validEntryCode({required bool asShepherd}) =>
      asShepherd ? validSeekerEntryCode : validShepherdEntryCode;

  /// Resolves only the deliberate local test counterpart for this role.
  /// Nothing in this namespace is accepted by the live parser or RPC.
  static SelahPersonalCodePreview? previewEntryCode(
    String code, {
    required bool asShepherd,
  }) {
    if (code.trim().toUpperCase() != validEntryCode(asShepherd: asShepherd)) {
      return null;
    }
    return SelahPersonalCodePreview(
      firstName: asShepherd ? 'James' : 'David',
      role: asShepherd ? 'seeker' : 'mentor',
    );
  }
}
