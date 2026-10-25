// The Splash lab — full-screen previews of the preserved splash motions.
//
// BUILT 2026-08-12 (Founder: the splash's final movement "doesn't feel
// smooth… propose five alternative versions that all match the existing
// design language. I want five options to choose from").
//
// The choosing happens by WATCHING, not by reading descriptions: each
// button plays the real SplashScreen with that motion, at real timing, on
// the real gradient. Tap anywhere to leave; Replay runs it again. When the
// Founder picks, the winner becomes SplashScreen's `motion` default and this
// lab stays for the next comparison.
//
// UPDATED 2026-08-26. Soft Bloom + Centre Draw is current. Soft Bloom,
// Centre Draw, Horizon Glow and Light Lift remain available for another
// review. Split Breath was explicitly removed by the Founder and is not kept
// as a hidden sixth option.
//
// MOVED 2026-08-12, evening: reached from DEVELOPER ACCESS now (via
// DevSplashLabMenu below), not from the toggle panel. Founder review that
// evening: the panel is per-page scenario controls only, and the splash is
// not a page — global dev destinations live on the dev home. Every lab route
// also repeats the protected developer capability check at its destination.

import 'package:flutter/material.dart';

import '../screens/splash_screen.dart';
import '../services/selah_developer_access.dart';
import '../theme/selah_colors.dart';
import '../theme/selah_text.dart';
import '../widgets/selah_splash_motion.dart';
import 'selah_developer_route_gate.dart';

/// Founder-facing labels, in the order they were proposed.
const List<({SelahSplashMotion motion, String label, String blurb})>
selahSplashLabOptions = [
  (
    motion: SelahSplashMotion.softBloom,
    label: '1 · Soft Bloom',
    blurb: 'Warm gold light opens behind the wordmark, with no line or dot.',
  ),
  (
    motion: SelahSplashMotion.centreDraw,
    label: '2 · Centre Draw',
    blurb: 'A short gold line opens evenly from the centre.',
  ),
  (
    motion: SelahSplashMotion.bloomDraw,
    label: '3 · Bloom + Draw — Original',
    blurb: 'The bloom establishes SELAH, then the centred line completes it.',
  ),
  (
    motion: SelahSplashMotion.horizonGlow,
    label: '4 · Horizon Glow',
    blurb: 'A wide soft glow gently sharpens into a fine gold horizon.',
  ),
  (
    motion: SelahSplashMotion.lightLift,
    label: '5 · Light Lift',
    blurb: 'A clean underline rises softly and dissolves beneath the name.',
  ),
];

/// The lab's front door: the five motions as a list, each playing the real
/// splash. Pushed from Developer Access — one tile there, the detail here,
/// so the dev home stays a directory rather than growing five buttons.
class DevSplashLabMenu extends StatelessWidget {
  const DevSplashLabMenu({super.key});

  @override
  Widget build(BuildContext context) {
    if (!SelahDeveloperAccess.canUseDeveloperTools) {
      return const _DevSplashLabDenied();
    }
    return SelahDeveloperRouteGate(
      child: Scaffold(
        backgroundColor: SelahColors.brandGradient.colors.last,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: Text('Splash lab', style: SelahText.heading(size: 18)),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Text(
              'Five saved directions, same wordmark and real launch timing. '
              'Preserved original motions. Quiet Horizon is the main opening.',
              style: SelahText.subtext(size: 12, color: Colors.white54),
            ),
            const SizedBox(height: 14),
            for (final o in selahSplashLabOptions) ...[
              InkWell(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        DevSplashLabScreen(motion: o.motion, label: o.label),
                  ),
                ),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.16),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(o.label, style: SelahText.button(size: 13.5)),
                      const SizedBox(height: 3),
                      Text(
                        o.blurb,
                        style: SelahText.subtext(
                          size: 10.5,
                          color: Colors.white38,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class DevSplashLabScreen extends StatefulWidget {
  final SelahSplashMotion motion;
  final String label;
  const DevSplashLabScreen({
    super.key,
    required this.motion,
    required this.label,
  });

  @override
  State<DevSplashLabScreen> createState() => _DevSplashLabScreenState();
}

class _DevSplashLabScreenState extends State<DevSplashLabScreen> {
  /// Bumped to remount SplashScreen, which replays it from zero.
  int _run = 0;

  @override
  Widget build(BuildContext context) {
    if (!SelahDeveloperAccess.canUseDeveloperTools) {
      return const _DevSplashLabDenied();
    }
    return SelahDeveloperRouteGate(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(context).maybePop(),
        child: Scaffold(
          body: Stack(
            children: [
              SplashScreen(key: ValueKey(_run), motion: widget.motion),
              SafeArea(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${widget.label} — tap anywhere to leave',
                          style: SelahText.subtext(
                            size: 11,
                            color: Colors.white38,
                          ),
                        ),
                        const SizedBox(height: 6),
                        OutlinedButton(
                          onPressed: () => setState(() => _run++),
                          child: Text(
                            'Replay',
                            style: SelahText.button(size: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DevSplashLabDenied extends StatelessWidget {
  const _DevSplashLabDenied();

  @override
  Widget build(BuildContext context) => const Scaffold(
    key: ValueKey('dev_splash_lab_denied'),
    body: SizedBox.shrink(),
  );
}
