// Founder-selected Quiet Horizon artwork, promoted 2026-09-27.
// Original/Hulu-family comparisons remain available through protected Home.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/selah_colors.dart';
import '../theme/selah_text.dart';
import 'selah_splash_motion.dart';

enum SelahSplashDirection {
  current('Original'),
  hulu('Hulu'),
  goldBloom('1 · Gold Bloom'),
  centreDraw('2 · Centre Draw'),
  bloomDraw('3 · Bloom + Draw'),
  silkGlow('4 · Plum Silk'),
  halo('5 · Gold Halo'),
  dawnHorizon('6 · Quiet Horizon · Main'),
  verticalLight('7 · Editorial Gold'),
  twinGlow('8 · Together'),
  quietFrame('9 · Open Frame'),
  royalSpotlight('10 · Royal Spotlight');

  const SelahSplashDirection(this.label);
  final String label;
}

/// The Founder-selected production design; previews cannot change this.
const selahPrimarySplashDirection = SelahSplashDirection.dawnHorizon;

// Shared by the production splash and protected design previews. Founder
// shortened only the completed-frame pause twice on 2026-09-30; the
// arrival sequence remains 2400ms.
const int selahSplashMotionMilliseconds = 2400;
const int selahSplashFinishedHoldMilliseconds = 650;
const Duration selahSplashTotalDuration = Duration(
  milliseconds:
      selahSplashMotionMilliseconds + selahSplashFinishedHoldMilliseconds,
);
const double selahSplashMotionFraction =
    selahSplashMotionMilliseconds /
    (selahSplashMotionMilliseconds + selahSplashFinishedHoldMilliseconds);

/// Original Hulu-family studies. The source Hulu reference is preserved;
/// these ten directions are original brand artwork, not new Mobbin claims.
class SelahSplashStudy extends StatefulWidget {
  const SelahSplashStudy({super.key, required this.direction});
  final SelahSplashDirection direction;

  @override
  State<SelahSplashStudy> createState() => _SelahSplashStudyState();
}

class _SelahSplashStudyState extends State<SelahSplashStudy>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    animationBehavior: AnimationBehavior.preserve,
    vsync: this,
    duration: selahSplashTotalDuration,
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) => SelahSplashArtworkFrame(
      direction: widget.direction,
      progress: MediaQuery.disableAnimationsOf(context)
          ? 1.0
          : (_controller.value / selahSplashMotionFraction).clamp(0.0, 1.0),
    ),
  );
}

/// Shared code-native artwork. Production supplies its own lifecycle progress;
/// developer previews animate this exact frame without touching AuthGate.
class SelahSplashArtworkFrame extends StatelessWidget {
  const SelahSplashArtworkFrame({
    super.key,
    required this.direction,
    required this.progress,
    this.tagline = 'Connecting with trust',
  });

  final SelahSplashDirection direction;
  final double progress;
  final String tagline;

  @override
  Widget build(BuildContext context) {
    final arrival = Curves.easeOutCubic.transform(
      (progress / .68).clamp(0.0, 1.0),
    );
    final taglineArrival = Curves.easeOut.transform(
      ((progress - .35) / .5).clamp(0.0, 1.0),
    );
    final design = MediaQuery.sizeOf(context).shortestSide.clamp(280.0, 480.0);
    final editorial = direction == SelahSplashDirection.verticalLight;
    final wordmarkSize = design * (editorial ? .17 : .19);
    // The small onboarding header is Syne at 18 with 4 points of tracking.
    // Scale the tracking with the letters so the splash is the same mark,
    // rather than a more tightly spaced version at a larger size.
    final wordmarkTracking =
        SelahText.wordmark(size: 18).letterSpacing! * wordmarkSize / 18;
    final hybrid =
        direction == SelahSplashDirection.centreDraw ||
        direction == SelahSplashDirection.bloomDraw;
    final line = switch (direction) {
      SelahSplashDirection.centreDraw || SelahSplashDirection.bloomDraw => true,
      _ => false,
    };
    final brand = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: editorial
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        if (hybrid)
          FittedBox(
            fit: BoxFit.scaleDown,
            child: _HuluLetterArrival(
              progress: progress,
              size: wordmarkSize,
              tracking: wordmarkTracking,
            ),
          )
        else
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Opacity(
              opacity: arrival,
              child: Transform.translate(
                offset: Offset(0, 10 * (1 - arrival)),
                child: Text(
                  'SELAH',
                  key: const ValueKey('splash_study_wordmark'),
                  style: SelahText.wordmark(
                    size: wordmarkSize,
                    color: SelahColors.splashWordmark,
                  ).copyWith(letterSpacing: wordmarkTracking),
                ),
              ),
            ),
          ),
        const SizedBox(height: 8),
        Opacity(
          opacity: taglineArrival,
          child: Text(
            tagline,
            style: SelahText.subtext(
              size: SelahText.taglineSize(context),
              color: SelahColors.splashTagline,
            ),
          ),
        ),
        if (line) ...[
          SizedBox(height: design * .0667),
          SelahSplashDrawRule(
            width: design * .60,
            progress: progress,
            // Both studies keep the finished centre-drawn line. The
            // bloom itself is a separate artwork/background choice.
            motion: SelahSplashMotion.bloomDraw,
          ),
        ],
      ],
    );
    return DecoratedBox(
      key: ValueKey('splash_study_${direction.name}'),
      // One palette across all twelve studies; artwork/motion alone varies.
      decoration: BoxDecoration(gradient: SelahColors.brandGradient),
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(painter: _HuluArtwork(direction, progress, design)),
          Align(
            alignment: const Alignment(0, -.06),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: editorial
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Opacity(
                          opacity: arrival,
                          child: Container(
                            key: const ValueKey('editorial_gold_rule'),
                            width: 2,
                            height: design * .25,
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Color(0x00E5CE8E),
                                  SelahColors.splashWordmark,
                                  Color(0x00E5CE8E),
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: design * .045),
                        Flexible(child: brand),
                      ],
                    )
                  : brand,
            ),
          ),
        ],
      ),
    );
  }
}

/// Reuses the original letter-by-letter arrival idea in a gold Hulu treatment.
class _HuluLetterArrival extends StatelessWidget {
  const _HuluLetterArrival({
    required this.progress,
    required this.size,
    required this.tracking,
  });
  final double progress;
  final double size;
  final double tracking;

  @override
  Widget build(BuildContext context) => Row(
    key: const ValueKey('hulu_letter_arrival'),
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var i = 0; i < 4; i++)
        Builder(
          builder: (_) {
            final start = .16 + i * .085;
            final t = Interval(
              start,
              start + .30,
              curve: const Cubic(.22, .9, .3, 1),
            ).transform(progress);
            return Opacity(
              opacity: t,
              child: Transform.translate(
                offset: Offset(0, 12 * (1 - t)),
                child: Text(
                  'SELAH'[i],
                  style: SelahText.wordmark(
                    size: size,
                    color: SelahColors.splashWordmark,
                  ).copyWith(letterSpacing: i == 3 ? 0 : tracking),
                ),
              ),
            );
          },
        ),
    ],
  );
}

class _HuluArtwork extends CustomPainter {
  const _HuluArtwork(this.direction, this.progress, this.design);
  final SelahSplashDirection direction;
  final double progress;
  final double design;
  static const gold = SelahColors.splashWordmark;
  static const plumLight = Color(0xFFB691C9);

  void _glow(
    Canvas canvas,
    Offset centre,
    double width,
    double height,
    Color color,
    double alpha,
  ) {
    final rect = Rect.fromCenter(center: centre, width: width, height: height);
    canvas.save();
    canvas.translate(centre.dx, centre.dy);
    canvas.scale(1, height / width);
    canvas.drawCircle(
      Offset.zero,
      width / 2,
      Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: alpha),
            color.withValues(alpha: alpha * .25),
            color.withValues(alpha: 0),
          ],
          stops: const [0, .48, 1],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: width / 2)),
    );
    canvas.restore();
    // Keep rect construction explicit for proportional geometry debugging.
    assert(rect.width > 0 && rect.height > 0);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final t = Curves.easeOutCubic.transform(progress);
    final centre = Offset(size.width / 2, size.height * .47);
    final unit = design / 390;
    final stroke = Paint()
      ..color = gold.withValues(alpha: .48 * t)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;
    switch (direction) {
      case SelahSplashDirection.hulu:
        final radius = design * .8;
        canvas.drawCircle(
          centre,
          radius,
          Paint()
            ..shader = RadialGradient(
              colors: [
                const Color(0xFF8A6A9E).withValues(alpha: .20 * t),
                const Color(0x008A6A9E),
              ],
            ).createShader(Rect.fromCircle(center: centre, radius: radius)),
        );
      case SelahSplashDirection.goldBloom:
        _glow(canvas, centre, design * 1.25, design * 1.1, gold, .22 * t);
        _glow(
          canvas,
          centre + Offset(0, -95 * unit),
          design * .70,
          design * .60,
          plumLight,
          .12 * t,
        );
      case SelahSplashDirection.centreDraw:
        _glow(canvas, centre, design * 1.6, design * 1.5, plumLight, .10 * t);
      case SelahSplashDirection.bloomDraw:
        _glow(
          canvas,
          centre + Offset(0, -14 * unit),
          design * 1.2,
          design * .85,
          gold,
          .17 * t,
        );
        _glow(
          canvas,
          centre + Offset(0, -100 * unit),
          design * 1.2,
          design * 1.2,
          plumLight,
          .11 * t,
        );
      case SelahSplashDirection.silkGlow:
        canvas.save();
        canvas.translate(centre.dx, centre.dy);
        canvas.rotate(-.48);
        _glow(
          canvas,
          const Offset(0, -80),
          design * 1.8,
          design * .45,
          plumLight,
          .24 * t,
        );
        _glow(
          canvas,
          const Offset(0, 38),
          design * 1.9,
          design * .16,
          gold,
          .085 * t,
        );
        canvas.restore();
      case SelahSplashDirection.halo:
        _glow(canvas, centre, design * .9, design * .9, plumLight, .14 * t);
        final rect = Rect.fromCenter(
          center: centre,
          width: design * .85,
          height: design * .85,
        );
        canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * t, false, stroke);
        canvas.drawArc(
          rect.inflate(7 * unit),
          math.pi / 3,
          math.pi * 1.1 * t,
          false,
          Paint()
            ..color = gold.withValues(alpha: .12 * t)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1,
        );
      case SelahSplashDirection.dawnHorizon:
        final horizon = centre + Offset(0, design * .24);
        _glow(canvas, horizon, design * 1.6, design * .32, gold, .18 * t);
        canvas.drawLine(
          horizon - Offset(design * .32 * t, 0),
          horizon + Offset(design * .32 * t, 0),
          stroke,
        );
        _glow(
          canvas,
          horizon + Offset(0, 44 * unit),
          design * 1.2,
          design * .55,
          plumLight,
          .16 * t,
        );
      case SelahSplashDirection.verticalLight:
        _glow(
          canvas,
          centre + Offset(-design * .32, 0),
          design * .45,
          design * 1.8,
          gold,
          .11 * t,
        );
      case SelahSplashDirection.twinGlow:
        final spread = design * (.30 - .10 * t);
        _glow(
          canvas,
          centre - Offset(spread, 22 * unit),
          design * .86,
          design * 1.1,
          gold,
          .15 * t,
        );
        _glow(
          canvas,
          centre + Offset(spread, 22 * unit),
          design * .86,
          design * 1.1,
          plumLight,
          .32 * t,
        );
      case SelahSplashDirection.quietFrame:
        final rect = Rect.fromCenter(
          center: centre,
          width: design * .86,
          height: design * .49,
        );
        final length = 26 * unit * t;
        final path = Path()
          ..moveTo(rect.left, rect.top + length)
          ..lineTo(rect.left, rect.top)
          ..lineTo(rect.left + length, rect.top)
          ..moveTo(rect.right - length, rect.top)
          ..lineTo(rect.right, rect.top)
          ..lineTo(rect.right, rect.top + length)
          ..moveTo(rect.left, rect.bottom - length)
          ..lineTo(rect.left, rect.bottom)
          ..lineTo(rect.left + length, rect.bottom)
          ..moveTo(rect.right - length, rect.bottom)
          ..lineTo(rect.right, rect.bottom)
          ..lineTo(rect.right, rect.bottom - length);
        canvas.drawPath(path, stroke);
      case SelahSplashDirection.royalSpotlight:
        _glow(
          canvas,
          Offset(size.width / 2, size.height * .22),
          design * 1.1,
          design * 1.65,
          gold,
          .105 * t,
        );
        _glow(canvas, centre, design * .92, design * 1.4, plumLight, .20 * t);
        final ruleY = centre.dy - design * .22;
        canvas.drawLine(
          Offset(centre.dx - 17 * unit * t, ruleY),
          Offset(centre.dx + 17 * unit * t, ruleY),
          stroke,
        );
      case SelahSplashDirection.current:
        break;
    }
  }

  @override
  bool shouldRepaint(_HuluArtwork oldDelegate) =>
      oldDelegate.direction != direction ||
      oldDelegate.progress != progress ||
      oldDelegate.design != design;
}
