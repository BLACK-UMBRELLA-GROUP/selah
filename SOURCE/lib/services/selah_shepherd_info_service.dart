// Shepherds of ANOTHER Seeker, revealed by a Compatibility Unlock+.
//
// Founder decision, 2026-08-05: "For Compatibility Unlock+, I want the
// Shepherd to be visible. Show the Shepherd's details, not just the
// relationship. This is an intentional product decision… if no Shepherd is
// linked, I want that shown honestly rather than hiding the row."
//
// Consent and legal wording are handled at onboarding and in the Privacy
// Policy / Terms, which name exactly what an unlock reveals, with solicitor
// review before public launch.
//
// SECURITY MODEL — identical to SelahSeekerDetailsService.fetchUnlocked():
// there is no RLS policy that lets one Seeker read another's `mentor_links`,
// and this does not add one. Everything goes through
// `shepherds_for_unlocked()`, a SECURITY DEFINER function that verifies a
// **paid_plus_single** unlock (Plus tier only — a standard unlock does not
// reveal Shepherds) and honours blocks in either direction.
//
// WHAT IS RETURNED: first name, gender, city, relationship, and whether they
// are the main Shepherd. WHAT IS NOT: date of birth (revoked client-side
// system-wide, audit C2), bio, profile id, or any contact route. A reader
// learns who is involved in her Journey — not how to reach them off-platform.
//
// `city` STAYS. It was briefly unused when relationship replaced it, which
// raised a data-minimisation question — disclose nothing the product does
// not display. Founder resolved it on 2026-08-06 by choosing to show both,
// so the disclosure is deliberate and the question is closed.
//
// EMPTY IS AN ANSWER, NOT AN ERROR. `ShepherdInfo.none` is returned when a
// Seeker genuinely has no Shepherd linked, and the UI states that plainly.
// It is deliberately distinguishable from `null` (not unlocked / lookup
// failed), because those two must never render the same way.

import 'package:flutter/foundation.dart';
import '../data/selah_reference_data.dart';
import '../main.dart';
import 'selah_auth.dart';

/// One Shepherd of another Seeker, as revealed by Compatibility Unlock+.
class ShepherdInfo {
  final String firstName;
  final String? gender;
  final String? city;

  /// The Shepherd designated as primary for this Seeker. Listed first.
  final bool isMain;

  /// Stored CODE ('father', 'uncle'…), never the label. See
  /// [relationshipLabel].
  final String? relationship;

  const ShepherdInfo({
    required this.firstName,
    this.gender,
    this.city,
    this.isMain = false,
    this.relationship,
  });

  factory ShepherdInfo.fromRow(Map<String, dynamic> row) => ShepherdInfo(
    firstName: (row['first_name'] as String?) ?? '',
    gender: row['gender'] as String?,
    city: row['location_text'] as String?,
    isMain: (row['is_main'] as bool?) ?? false,
    relationship: row['relationship'] as String?,
  );

  /// "Paternal Uncle" for the code 'uncle'. Null when unrecorded.
  String? get relationshipLabel => selahRelationshipLabel(relationship);

  /// "Abdul · Father · Birmingham".
  ///
  /// CHANGED 2026-08-06. Was "Abdul · Birmingham" — Founder: *"Abdul ·
  /// Birmingham doesn't answer that. Abdul · Father immediately tells the
  /// user who they're likely to be communicating with if the Journey
  /// progresses."*
  ///
  /// REVISED the same day. The first build REPLACED city with relationship,
  /// which the plan called for. Founder on seeing it: *"I thought we said it
  /// should say Abdul - area - relationship."* Both facts are kept — who the
  /// Shepherd is, and where they are, which bears on how family meetings
  /// would actually work.
  ///
  /// Whatever is present is joined; whatever is missing is skipped. That
  /// makes an unrecorded relationship degrade to "Abdul · Birmingham" — the
  /// old line, which is a reasonable thing to show — rather than to a bare
  /// name, which is what the replace-only version did and which showed the
  /// reader LESS than before for every link with no relationship yet.
  String get displayLine => [
    if (firstName.isNotEmpty) firstName,
    ?relationshipLabel,
    if (city != null && city!.isNotEmpty) city!,
  ].join(' · ');
}

class SelahShepherdInfoService {
  SelahShepherdInfoService._();

  /// Shepherds linked to [profileId], or null if this user has not unlocked
  /// them at Plus tier (or the lookup failed).
  ///
  /// An EMPTY list means "unlocked, and she has no Shepherd" — a real
  /// answer the UI renders as "No Shepherd linked". Null means "you cannot
  /// see this", which renders as the locked state. Collapsing the two would
  /// tell a non-paying user something a paying one is entitled to know.
  static Future<List<ShepherdInfo>?> fetchUnlocked(String profileId) async {
    if (SelahAuth.currentUser == null) return null;
    try {
      final rows =
          await supabase.rpc(
                'shepherds_for_unlocked',
                params: {'p_target': profileId},
              )
              as List?;
      if (rows == null) return null;
      return rows
          .map((r) => ShepherdInfo.fromRow(Map<String, dynamic>.from(r as Map)))
          .toList();
    } catch (e) {
      // Named, not swallowed — a silent failure here would render as
      // "No Shepherd linked", which is a factual claim we would not have
      // earned. Null keeps it in the locked/unknown state instead.
      debugPrint('SELAH: shepherds_for_unlocked($profileId) failed — $e');
      return null;
    }
  }
}
