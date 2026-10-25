// The plan-aware "Paused Journeys are full" refusal.
//
// EXTRACTED 2026-08-12 from journey_flow_screen._pauseJourney, the moment a
// second caller appeared: the Connections takeover popup now offers "Pause
// with <name>" as a first-class choice (B1 design, Founder-picked), and its
// pause can hit the same server cap. Two hand-written copies of a
// plan-branching dialog is exactly the drift the 2026-08-12 panel rebuild
// spent a day deleting — so the refusal moved here before the second copy
// could be typed.
//
// Capacity still follows data/selah_entitlements.dart. The refusal explains
// the current limit and the available actions without offering a purchase.

import 'package:flutter/material.dart';

import '../data/selah_entitlements.dart';
import '../state/app_state.dart';
import '../theme/selah_text.dart';
import 'selah_glass_dialog.dart';

/// Shows the current capacity refusal without changing membership or Journeys.
Future<void> showSelahPausedLimitRefusal(BuildContext context) async {
  final limits = SelahEntitlements.of(AppState.instance.plan);
  await showSelahGlassDialog<void>(
    context: context,
    builder: (ctx) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.pause_circle_outline, color: Colors.white, size: 30),
        const SizedBox(height: 14),
        Text(
          'Paused Journeys are full',
          style: SelahText.heading(size: 18),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Your current limit is ${limits.paused} paused Journeys, and '
          "you're at the limit. Resume or end one of them to pause "
          'this one.',
          style: SelahText.subtext(),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('OK', style: SelahText.button(size: 13)),
          ),
        ),
      ],
    ),
  );
}
