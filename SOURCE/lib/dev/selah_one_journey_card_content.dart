// Locked Journey-card interior. The caller retains the existing card shell,
// true per-person data and guarded actions; this file owns no app authority.
import 'package:flutter/material.dart';

import '../models/seeker_profile.dart';
import '../theme/selah_colors.dart';
import '../theme/selah_text.dart';

enum SelahOneJourneyCardDesign {
  classic('Classic', 'The current photo, identity and full-width action.'),
  quietMinimal(
    'Quiet minimal',
    'A smaller portrait and a calmer, left-aligned hierarchy.',
  );

  const SelahOneJourneyCardDesign(this.label, this.description);
  final String label;
  final String description;
}

class SelahOneJourneyCardContent extends StatelessWidget {
  const SelahOneJourneyCardContent({
    super.key,
    required this.design,
    required this.profile,
    required this.photo,
    required this.action,
    required this.fillHeight,
    this.report,
    this.stateLabel,
    this.stageLabel,
    this.inlineOptions,
    this.inlineOptionsFillHeight = true,
  });

  final SelahOneJourneyCardDesign design;
  final SeekerProfile profile;
  final Widget photo;
  final Widget action;
  final Widget? report;
  // Retained caller metadata, deliberately not displayed by the locked layout.
  final String? stateLabel;
  final String? stageLabel;
  final bool fillHeight;
  final Widget? inlineOptions;
  final bool inlineOptionsFillHeight;

  Widget _portrait() => ClipRRect(
    borderRadius: BorderRadius.circular(14),
    child: SizedBox(width: 104, height: 104, child: photo),
  );

  Widget _identity() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(profile.firstName, style: SelahText.heading(size: 19)),
          if ((profile.surnameLine ?? '').trim().isNotEmpty)
            Text(
              profile.surnameLine!.trim(),
              style: SelahText.heading(size: 15, color: SelahColors.ink(.86)),
            ),
        ],
      ),
      const SizedBox(height: 4),
      Text(
        '${profile.age} · ${profile.city}',
        style: SelahText.subtext(size: 12.5, color: SelahColors.ink(.78)),
      ),
    ],
  );

  Widget _header() => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _portrait(),
      const SizedBox(width: 12),
      Expanded(child: _identity()),
      ?report,
    ],
  );

  @override
  Widget build(BuildContext context) => switch (design) {
    // Classic is rendered by the original presenter, not reconstructed here.
    SelahOneJourneyCardDesign.classic => throw StateError(
      'Classic retains its original interior',
    ),
    SelahOneJourneyCardDesign.quietMinimal => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(),
        const SizedBox(height: 8),
        if (fillHeight && inlineOptions == null) const Spacer(),
        action,
        if (inlineOptions != null) ...[
          const SizedBox(height: 16),
          if (inlineOptionsFillHeight)
            Expanded(child: inlineOptions!)
          else
            inlineOptions!,
        ],
      ],
    ),
  };
}
