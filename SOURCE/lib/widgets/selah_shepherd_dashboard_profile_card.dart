import 'package:flutter/material.dart';

import '../models/seeker_profile.dart';
import '../services/selah_mentor_link_service.dart';
import '../theme/selah_colors.dart';
import '../theme/selah_text.dart';
import 'selah_profile_image.dart';

/// Linked-Seeker identity, not a Journey counterpart or authority summary.
class ShepherdDashboardProfileCard extends StatelessWidget {
  const ShepherdDashboardProfileCard({
    super.key,
    required this.person,
    this.profile,
    this.detailsLoading = false,
    this.onViewProfile,
  });

  final MentorLinkedPerson person;
  final SeekerProfile? profile;
  final bool detailsLoading;
  final VoidCallback? onViewProfile;

  @override
  Widget build(BuildContext context) {
    // Reject even an accidentally mismatched injected model at presentation.
    final details = profile?.id == person.id ? profile : null;
    final photo = details?.photoUrl ?? '';
    final relationship =
        person.relationshipLabel ?? 'Relationship not recorded';
    final role = person.isMain ? 'Main Shepherd' : 'Additional Shepherd';
    final age = details != null && details.age > 0
        ? '${details.age} years'
        : 'Age unavailable';
    final city = details?.city.trim() ?? '';
    final location = city.isEmpty || city == '—'
        ? 'Location unavailable'
        : city;

    return Container(
      key: ValueKey('shepherd-dashboard-seeker-snapshot-${person.id}'),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      decoration: BoxDecoration(
        color: SelahColors.surfaceFill,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: SelahColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Semantics(
                label: 'Profile photo of ${person.firstName}',
                image: true,
                child: Container(
                  key: ValueKey(
                    'shepherd-dashboard-profile-avatar-${person.id}',
                  ),
                  width: 62,
                  height: 62,
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: SelahColors.journeyGold.withValues(alpha: .48),
                    ),
                  ),
                  child: ClipOval(
                    child: photo.isEmpty
                        ? ColoredBox(
                            color: SelahColors.surfaceEmphasisFill,
                            child: Center(
                              child: Text(
                                person.firstName.isEmpty
                                    ? '?'
                                    : person.firstName.characters.first,
                                style: SelahText.heading(size: 24),
                              ),
                            ),
                          )
                        : SelahProfileImage(photo, width: 58, height: 58),
                  ),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(person.firstName, style: SelahText.heading(size: 18)),
                    const SizedBox(height: 3),
                    Semantics(
                      label:
                          'Your relationship to ${person.firstName}: '
                          '$relationship. Your role: $role.',
                      excludeSemantics: true,
                      child: Text(
                        '$relationship · $role',
                        style: SelahText.subtext(size: 11.5),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      detailsLoading && details == null
                          ? 'Loading profile details…'
                          : '$age · $location',
                      style: SelahText.subtext(
                        size: 11.5,
                        color: SelahColors.ink(.75),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              key: ValueKey('shepherd-dashboard-view-profile-${person.id}'),
              onPressed: detailsLoading || details == null
                  ? null
                  : onViewProfile,
              style: TextButton.styleFrom(
                foregroundColor: SelahColors.journeyGold,
                disabledForegroundColor: SelahColors.ink(.36),
                minimumSize: const Size(48, 44),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      'View profile',
                      style: SelahText.body(
                        size: 12,
                        color:
                            detailsLoading ||
                                details == null ||
                                onViewProfile == null
                            ? SelahColors.ink(.36)
                            : SelahColors.journeyGold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right_rounded, size: 17),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
