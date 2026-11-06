import 'package:flutter/material.dart';

import '../models/seeker_profile.dart';
import '../models/selah_marriage_values.dart';
import '../theme/selah_colors.dart';
import '../theme/selah_text.dart';
import 'selah_marriage_values_views.dart';
import 'selah_profile_image.dart';

/// LOCK 16: only the actual eligible Journey owner supplies this detail page.
/// No discovery, reveal, or Shepherd-link permission is granted here.
class SelahJourneyMarriageProfile extends StatelessWidget {
  const SelahJourneyMarriageProfile({
    super.key,
    required this.profile,
    required this.onBack,
  });

  final SeekerProfile profile;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => SafeArea(
    key: ValueKey('journey_marriage_profile_${profile.id}'),
    bottom: false,
    child: ListView(
      padding: const EdgeInsets.fromLTRB(22, 6, 22, 110),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            key: const ValueKey('journey_marriage_profile_back'),
            onPressed: onBack,
            style: TextButton.styleFrom(
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(vertical: 6),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              '‹ Back',
              style: SelahText.button(color: SelahColors.lake),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(profile.firstName, style: SelahText.pageTitle()),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: SelahColors.surface,
            border: Border.all(color: SelahColors.line),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: SelahProfileImage(
                      profile.photoUrl,
                      width: 78,
                      height: 78,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${profile.firstName}, ${profile.age}',
                          style: SelahText.rowTitle().copyWith(fontSize: 18),
                        ),
                        Text(profile.city, style: SelahText.subtext()),
                      ],
                    ),
                  ),
                ],
              ),
              if (profile.browseFaithChips.isNotEmpty) ...[
                const SizedBox(height: 14),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final chip in profile.browseFaithChips)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: SelahColors.soft,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          chip,
                          style: SelahText.body(
                            size: 12.5,
                          ).copyWith(fontWeight: FontWeight.w500, height: 1),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        SelahMarriageValuesCard(
          answers: profile.marriageValues ?? SelahMarriageValuesAnswers(),
          visibilityNote:
              'You can see these because you’re on a Journey together.',
        ),
      ],
    ),
  );
}
