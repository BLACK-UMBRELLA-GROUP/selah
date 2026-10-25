import '../models/selah_known_person_code.dart';
import '../services/selah_mentor_link_service.dart';

/// Founder-preview-only discovery codes.
///
/// These values deliberately do not match the live SELAH Code format. They
/// cannot be stored by the production schema or resolved by the live RPCs.
class SelahDevPersonalCodeFixtures {
  SelahDevPersonalCodeFixtures._();

  static const invalidEntryCode = 'SELAH-0000-0000-0000-0000-0000';
  static const validSeekerEntryCode = 'SELAH-DEMO-SEEKER-ADAM';
  static const validShepherdEntryCode = 'SELAH-DEMO-SHEPHERD-IBRAHIM';

  static String validKnownPersonEntryCode({required String? currentGender}) =>
      currentGender == 'female'
      ? 'SELAH-DEMO-SEEKER-ADAM'
      : 'SELAH-DEMO-SEEKER-MARYAM';

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
            firstName: 'Adam',
            age: 29,
            city: 'London',
          )
        : const SelahKnownPersonCodePreview(
            firstName: 'Maryam',
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
        (false, false) => 'SELAH-DEMO-SEEKER-ADAM',
        (false, true) => 'SELAH-DEMO-SEEKER-MARYAM',
        (true, false) => 'SELAH-DEMO-SHEPHERD-IBRAHIM',
        (true, true) => 'SELAH-DEMO-SHEPHERD-KHADIJA',
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
      firstName: asShepherd ? 'Adam' : 'Ibrahim',
      role: asShepherd ? 'seeker' : 'mentor',
    );
  }
}
