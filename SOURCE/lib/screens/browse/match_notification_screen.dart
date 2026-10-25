// Match Notification — E1, THE moment (inherited decision 147/148, 2026-08-13).
//
// Was a single fade-in per MATCH_UX_SPEC's "warm, calm, human" — right
// instinct, functional execution, and the Founder named it the single
// biggest gap in the transitional-moments audit: mutuality is the first
// two-sided fact in the product, and it deserved a MOMENT, not a screen.
//
// Now it speaks the ratified grammar via SelahMomentScreen (embedded —
// this screen IS the route, so the actions run callbacks instead of
// popping a pushed moment): the pair leads, "You've both chosen each
// other" lands, then orientation — she waits in Potential Journeys, one
// person at a time, both families present. Tap-through everywhere, per
// the engine's rule.
//
// The old placeholder self-photo (picsum "you") died with the rewrite —
// the viewer's side is now the engine's honest frost "You" circle.

import 'package:flutter/material.dart';
import '../../models/seeker_profile.dart';
import '../../widgets/selah_moment.dart';

class MatchNotificationScreen extends StatelessWidget {
  final SeekerProfile matchedWith;
  final VoidCallback onViewMatch;

  const MatchNotificationScreen({
    super.key,
    required this.matchedWith,
    required this.onViewMatch,
  });

  @override
  Widget build(BuildContext context) {
    final name = matchedWith.firstName;
    return SelahMomentScreen(
      pairWith: matchedWith,
      glow: true,
      lines: [
        SelahMomentLine.whisper('$name said yes. So did you.'),
        const SelahMomentLine.heading("You've both chosen each other."),
        const SelahMomentLine.body(
          'A quiet congratulations — every Journey starts exactly here.',
        ),
        SelahMomentLine.quiet(
          '$name now waits in your Potential Journeys. Begin whenever '
          "you're both ready — one person at a time, with both families "
          'present.',
        ),
      ],
      ctaLabel: 'See $name in Journeys',
      secondaryLabel: 'Later',
      onPrimary: onViewMatch,
      onSecondary: () => Navigator.of(context).pop(),
    );
  }
}
