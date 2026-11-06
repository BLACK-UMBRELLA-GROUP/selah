// SELAH splash motion — soft light, never loading.
//
// Founder-selected 2026-08-26: Soft Bloom + Centre Draw. A warm gold bloom
// establishes the wordmark while a short line opens symmetrically beneath the
// tagline. Neither element contains or resolves into a travelling dot.
//
// The five preserved review directions live in [SelahSplashMotion]. They all
// use this one progress model and the real SplashScreen timing, so the
// Developer Splash Lab cannot drift into a separate mock animation. Split
// Breath was explicitly rejected and is intentionally absent.
//
// This is not SelahLoading. The splash runs once at cold start for a known
// duration; loading remains the small repeatable wait indicator.

import 'package:flutter/material.dart';

import '../theme/selah_colors.dart';

enum SelahSplashMotion {
  softBloom,
  centreDraw,
  bloomDraw,
  horizonGlow,
  lightLift,
}

@visibleForTesting
class SelahSplashMotionFrame {
  final double bloomOpacity;
  final double bloomScale;
  final double lineProgress;
  final double lineOpacity;
  final double supportGlowOpacity;
  final double lineLift;

  const SelahSplashMotionFrame({
    required this.bloomOpacity,
    required this.bloomScale,
    required this.lineProgress,
    required this.lineOpacity,
    required this.supportGlowOpacity,
    required this.lineLift,
  });

  factory SelahSplashMotionFrame.at({
    required SelahSplashMotion motion,
    required double progress,
  }) {
    final p = progress.clamp(0.0, 1.0);
    final showsBloom =
        motion == SelahSplashMotion.softBloom ||
        motion == SelahSplashMotion.bloomDraw;
    final showsLine = motion != SelahSplashMotion.softBloom;

    final bloomIn = _interval(p, 0.02, 0.28, Curves.easeOutCubic);
    final bloomOut = _interval(p, 0.62, 0.90, Curves.easeInCubic);
    final bloomTravel = _interval(p, 0.02, 0.80, Curves.easeOutCubic);

    final (lineStart, lineEnd) = switch (motion) {
      SelahSplashMotion.horizonGlow => (0.34, 0.68),
      SelahSplashMotion.lightLift => (0.44, 0.76),
      _ => (0.50, 0.78),
    };
    final lineIn = _interval(p, lineStart, lineEnd, Curves.easeOutCubic);
    final lineOut = _interval(p, 0.88, 1.0, Curves.easeInCubic);
    // The production Bloom + Draw now resolves into a complete line and
    // keeps it for the splash's finished hold. Other preserved lab directions
    // retain their original release behaviour.
    final keepsFinishedLine = motion == SelahSplashMotion.bloomDraw;
    final supportingGlow = switch (motion) {
      SelahSplashMotion.horizonGlow =>
        _interval(p, 0.18, 0.52, Curves.easeOut) * (1 - lineOut),
      SelahSplashMotion.lightLift =>
        _interval(p, 0.32, 0.64, Curves.easeOut) * (1 - lineOut),
      _ => 0.0,
    };
    final lift = motion == SelahSplashMotion.lightLift
        ? -10 * _interval(p, 0.42, 0.94, Curves.easeInOutCubic)
        : 0.0;

    return SelahSplashMotionFrame(
      bloomOpacity: showsBloom ? bloomIn * (1 - bloomOut) : 0,
      bloomScale: 0.34 + 1.08 * bloomTravel,
      lineProgress: showsLine ? lineIn : 0,
      lineOpacity: showsLine
          ? lineIn * (keepsFinishedLine ? 1 : (1 - lineOut))
          : 0,
      supportGlowOpacity: supportingGlow,
      lineLift: lift,
    );
  }
}

double _interval(double value, double begin, double end, Curve curve) {
  if (value <= begin) return 0;
  if (value >= end) return 1;
  return curve.transform((value - begin) / (end - begin));
}

/// Positioned behind the wordmark by [SplashScreen]. It never contributes to
/// layout size, so changing the motion cannot shift the approved composition.
class SelahSplashBloom extends StatelessWidget {
  final SelahSplashMotion motion;
  final double progress;

  const SelahSplashBloom({
    super.key,
    required this.motion,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final frame = SelahSplashMotionFrame.at(motion: motion, progress: progress);
    return IgnorePointer(
      child: RepaintBoundary(
        child: Opacity(
          key: const ValueKey('splash_soft_bloom'),
          opacity: frame.bloomOpacity.clamp(0.0, 1.0),
          child: Transform.scale(
            scale: frame.bloomScale,
            child: const DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  radius: 0.56,
                  colors: [
                    Color(0x55E5C878),
                    Color(0x22E5C878),
                    Color(0x00E5C878),
                  ],
                  stops: [0, 0.44, 1],
                ),
              ),
              child: SizedBox.expand(),
            ),
          ),
        ),
      ),
    );
  }
}

/// The lower half of the approved motion. The line grows from its centre, so
/// there is no travelling point and no directional meaning.
class SelahSplashDrawRule extends StatelessWidget {
  final SelahSplashMotion motion;
  final double progress;
  final double width;

  const SelahSplashDrawRule({
    super.key,
    required this.motion,
    required this.progress,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    final frame = SelahSplashMotionFrame.at(motion: motion, progress: progress);
    final lineWidth = width * frame.lineProgress;
    final glowWidth = width * (0.34 + 0.66 * frame.lineProgress);

    return Semantics(
      label: 'Soft gold light opening beneath Selah',
      child: RepaintBoundary(
        child: SizedBox(
          key: ValueKey('splash_motion_${motion.name}'),
          width: width,
          height: 2,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              if (motion == SelahSplashMotion.horizonGlow ||
                  motion == SelahSplashMotion.lightLift)
                Transform.translate(
                  offset: Offset(0, frame.lineLift + 1),
                  child: Opacity(
                    opacity: frame.supportGlowOpacity.clamp(0.0, 1.0),
                    child: Container(
                      key: const ValueKey('splash_support_glow'),
                      width: glowWidth,
                      height: motion == SelahSplashMotion.horizonGlow ? 20 : 28,
                      decoration: const BoxDecoration(
                        gradient: RadialGradient(
                          radius: 0.72,
                          colors: [
                            Color(0x55E5C878),
                            Color(0x18E5C878),
                            Color(0x00E5C878),
                          ],
                          stops: [0, 0.48, 1],
                        ),
                      ),
                    ),
                  ),
                ),
              Transform.translate(
                offset: Offset(0, frame.lineLift),
                child: Opacity(
                  opacity: frame.lineOpacity.clamp(0.0, 1.0),
                  child: Container(
                    key: const ValueKey('splash_centre_draw'),
                    width: lineWidth,
                    height: 1.35,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      gradient: LinearGradient(
                        colors: [
                          SelahColors.journeyGold.withValues(alpha: 0),
                          SelahColors.journeyGold.withValues(alpha: 0.86),
                          SelahColors.journeyGold,
                          SelahColors.journeyGold.withValues(alpha: 0.86),
                          SelahColors.journeyGold.withValues(alpha: 0),
                        ],
                        stops: const [0, 0.18, 0.5, 0.82, 1],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: SelahColors.journeyGold.withValues(
                            alpha: 0.22 * frame.lineOpacity,
                          ),
                          blurRadius: 5,
                          spreadRadius: 0.4,
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
