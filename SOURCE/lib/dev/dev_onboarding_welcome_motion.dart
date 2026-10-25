// Protected, session-local motion choices for the continuous opening story.
// This does not change ordinary member onboarding.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/selah_account_state.dart';
import '../services/selah_developer_access.dart';
import '../theme/selah_colors.dart';

enum SelahWelcomeTextMotionFamily { descent, typewriter, blend }

enum SelahWelcomeTextMotion {
  slowDescent(
    'Slow descent',
    1350,
    SelahWelcomeTextMotionFamily.descent,
    travel: 16,
  ),
  lighterDescent(
    'Lighter descent',
    1350,
    SelahWelcomeTextMotionFamily.descent,
    travel: 12,
  ),
  deeperDescent(
    'Deeper descent',
    1350,
    SelahWelcomeTextMotionFamily.descent,
    travel: 20,
  ),
  lingeringDescent(
    'Lingering descent',
    1550,
    SelahWelcomeTextMotionFamily.descent,
    travel: 16,
  ),
  softLanding(
    'Soft landing',
    1350,
    SelahWelcomeTextMotionFamily.descent,
    travel: 16,
    easeOut: true,
  ),
  quietTypewriter(
    'Quiet typewriter',
    2000,
    SelahWelcomeTextMotionFamily.typewriter,
  ),
  briskTypewriter(
    'Brisk typewriter',
    1600,
    SelahWelcomeTextMotionFamily.typewriter,
  ),
  measuredTypewriter(
    'Measured typewriter',
    2600,
    SelahWelcomeTextMotionFamily.typewriter,
  ),
  easedTypewriter(
    'Eased typewriter',
    2200,
    SelahWelcomeTextMotionFamily.typewriter,
    easedTyping: true,
  ),
  softTypewriter(
    'Soft typewriter',
    2200,
    SelahWelcomeTextMotionFamily.typewriter,
    easeOut: true,
  ),
  descentTypewriter(
    'Descent + typewriter',
    2200,
    SelahWelcomeTextMotionFamily.blend,
    travel: 16,
  ),
  lightDescentTypewriter(
    'Light descent + typewriter',
    2200,
    SelahWelcomeTextMotionFamily.blend,
    travel: 12,
  ),
  deepDescentTypewriter(
    'Deep descent + typewriter',
    2200,
    SelahWelcomeTextMotionFamily.blend,
    travel: 20,
  ),
  lingeringDescentTypewriter(
    'Lingering descent + typewriter',
    2700,
    SelahWelcomeTextMotionFamily.blend,
    travel: 16,
  ),
  softLandingTypewriter(
    'Soft landing + typewriter',
    2200,
    SelahWelcomeTextMotionFamily.blend,
    travel: 16,
    easeOut: true,
  );

  const SelahWelcomeTextMotion(
    this.label,
    this.milliseconds,
    this.family, {
    this.travel = 0,
    this.easeOut = false,
    this.easedTyping = false,
  });

  final String label;
  final int milliseconds;
  final SelahWelcomeTextMotionFamily family;
  final double travel;
  final bool easeOut;
  final bool easedTyping;
  bool get typesText => family != SelahWelcomeTextMotionFamily.descent;
  Duration get duration => Duration(milliseconds: milliseconds);
}

abstract final class SelahDevWelcomeTextMotion {
  static const defaultMotion = SelahWelcomeTextMotion.slowDescent;
  static final ValueNotifier<SelahWelcomeTextMotion> _selection = ValueNotifier(
    defaultMotion,
  );
  static int _accountGeneration = SelahAccountState.generation;

  static Listenable get changes => _selection;
  static SelahWelcomeTextMotion get current =>
      _accountGeneration == SelahAccountState.generation
      ? _selection.value
      : defaultMotion;

  static bool select(SelahWelcomeTextMotion motion) {
    if (!SelahDeveloperAccess.canUseDeveloperTools) return false;
    final generation = SelahAccountState.generation;
    if (_accountGeneration != generation) {
      _accountGeneration = generation;
      _selection.value = defaultMotion;
    }
    _selection.value = motion;
    return true;
  }

  @visibleForTesting
  static void resetForTesting() {
    assert(() {
      _accountGeneration = SelahAccountState.generation;
      _selection.value = defaultMotion;
      return true;
    }());
  }
}

/// A session-local Founder comparison; Balanced is the approved default.
abstract final class SelahDevWelcomePulseIntensity {
  static const defaultLevel = 3;
  static const minLevel = 1;
  static const maxLevel = 5;
  static const _labels = <String>[
    'Subtle',
    'Soft',
    'Balanced',
    'Strong',
    'Bold',
  ];
  static const _amplitudes = <double>[.08, .14, .20, .27, .35];
  static final ValueNotifier<int> _selection = ValueNotifier(defaultLevel);
  static int _accountGeneration = SelahAccountState.generation;

  static Listenable get changes => _selection;
  static int get level => _accountGeneration == SelahAccountState.generation
      ? _selection.value
      : defaultLevel;
  static String labelFor(int level) => _labels[level - 1];
  static String get label => labelFor(level);
  static double get amplitude => _amplitudes[level - 1];

  static bool select(int level) {
    if (!SelahDeveloperAccess.canUseDeveloperTools ||
        level < minLevel ||
        level > maxLevel) {
      return false;
    }
    final generation = SelahAccountState.generation;
    if (_accountGeneration != generation) {
      _accountGeneration = generation;
      _selection.value = defaultLevel;
    }
    _selection.value = level;
    return true;
  }

  @visibleForTesting
  static void resetForTesting() {
    assert(() {
      _accountGeneration = SelahAccountState.generation;
      _selection.value = defaultLevel;
      return true;
    }());
  }
}

enum SelahWelcomePulseDesign {
  goldRing('Gold ring'),
  rippleRing('Ripple ring'),
  twinHalo('Twin halo'),
  softBloom('Soft bloom'),
  orbitRing('Orbit ring');

  const SelahWelcomePulseDesign(this.label);
  final String label;
}

abstract final class SelahDevWelcomePulseDesign {
  static const defaultDesign = SelahWelcomePulseDesign.softBloom;
  static final ValueNotifier<SelahWelcomePulseDesign> _selection = ValueNotifier(
    defaultDesign,
  );
  static int _accountGeneration = SelahAccountState.generation;

  static Listenable get changes => _selection;
  static SelahWelcomePulseDesign get current =>
      _accountGeneration == SelahAccountState.generation
      ? _selection.value
      : defaultDesign;

  static bool select(SelahWelcomePulseDesign design) {
    if (!SelahDeveloperAccess.canUseDeveloperTools) return false;
    final generation = SelahAccountState.generation;
    if (_accountGeneration != generation) {
      _accountGeneration = generation;
      _selection.value = defaultDesign;
    }
    _selection.value = design;
    return true;
  }

  @visibleForTesting
  static void resetForTesting() {
    assert(() {
      _accountGeneration = SelahAccountState.generation;
      _selection.value = defaultDesign;
      return true;
    }());
  }
}

class SelahWelcomePulseMark extends StatelessWidget {
  const SelahWelcomePulseMark({
    super.key,
    required this.design,
    required this.progress,
    this.preview = false,
    this.size,
  });

  final SelahWelcomePulseDesign design;
  final double progress;
  final bool preview;
  final double? size;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: preview ? 34 : size ?? 56,
    height: preview ? 34 : size ?? 56,
    child: CustomPaint(
      key: const ValueKey('dev_onboarding_pulse_canvas'),
      painter: SelahWelcomePulsePainter(design, progress),
      child: Center(
        child: Container(
          key: preview ? null : const ValueKey('dev_onboarding_welcome_dot'),
          width: preview ? 6 : 12 * (size ?? 56) / 56,
          height: preview ? 6 : 12 * (size ?? 56) / 56,
          decoration: const BoxDecoration(
            color: SelahColors.splashWordmark,
            shape: BoxShape.circle,
          ),
        ),
      ),
    ),
  );
}

class SelahWelcomePulsePainter extends CustomPainter {
  const SelahWelcomePulsePainter(this.design, this.progress);
  final SelahWelcomePulseDesign design;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final factor = size.shortestSide / 56;
    final p = progress.clamp(0.0, 1.0);
    final gold = SelahColors.splashWordmark;
    void ring(double radius, double opacity, {double width = 1.5}) {
      canvas.drawCircle(
        center,
        radius * factor,
        Paint()
          ..color = gold.withValues(alpha: opacity.clamp(0.0, 1.0))
          ..style = PaintingStyle.stroke
          ..strokeWidth = width * factor,
      );
    }

    switch (design) {
      case SelahWelcomePulseDesign.goldRing:
        ring(18 + 2 * p, .68);
      case SelahWelcomePulseDesign.rippleRing:
        ring(16, .5);
        ring(16 + 9 * p, .62 - .43 * p);
      case SelahWelcomePulseDesign.twinHalo:
        ring(16 + 2 * p, .7);
        ring(24 - 2 * p, .36);
      case SelahWelcomePulseDesign.softBloom:
        canvas.drawCircle(
          center,
          27 * factor,
          Paint()
            ..shader =
                RadialGradient(
                  colors: [
                    gold.withValues(alpha: .21 + .07 * p),
                    gold.withValues(alpha: .08),
                    gold.withValues(alpha: 0),
                  ],
                  stops: const [0, .56, 1],
                ).createShader(
                  Rect.fromCircle(center: center, radius: 27 * factor),
                ),
        );
        ring(18, .46);
      case SelahWelcomePulseDesign.orbitRing:
        ring(20, .52);
        final angle = -math.pi / 2 + math.pi * 1.25 * p;
        canvas.drawCircle(
          center + Offset(math.cos(angle), math.sin(angle)) * 20 * factor,
          2.4 * factor,
          Paint()..color = gold.withValues(alpha: .85),
        );
    }
  }

  @override
  bool shouldRepaint(covariant SelahWelcomePulsePainter oldDelegate) =>
      oldDelegate.design != design || oldDelegate.progress != progress;
}

/// Keeps the full line's layout and accessibility label while progressively
/// revealing whole grapheme clusters (never half of an emoji or diacritic).
class SelahWelcomeLine extends StatelessWidget {
  const SelahWelcomeLine({
    super.key,
    required this.text,
    required this.style,
    this.visibleFraction = 1,
    this.entranceAnimation,
    this.entranceMotion,
    this.textAlign = TextAlign.center,
    this.textKey,
  });

  final String text;
  final TextStyle style;
  final double visibleFraction;
  final Animation<double>? entranceAnimation;
  final SelahWelcomeTextMotion? entranceMotion;
  final TextAlign textAlign;
  final Key? textKey;

  SelahWelcomeLine withVisibleFraction(double fraction) => SelahWelcomeLine(
    text: text,
    style: style,
    visibleFraction: fraction,
    entranceAnimation: entranceAnimation,
    entranceMotion: entranceMotion,
    textAlign: textAlign,
    textKey: textKey,
  );

  @override
  Widget build(BuildContext context) {
    if (entranceAnimation case final entrance?) {
      return SelahWelcomeTextMotionFrame(
        key: const ValueKey('dev_welcome_first_line_entrance'),
        motion: entranceMotion!,
        animation: entrance,
        child: SelahWelcomeLine(
          text: text,
          style: style,
          visibleFraction: visibleFraction,
          textAlign: textAlign,
          textKey: textKey,
        ),
      );
    }
    if (visibleFraction >= 1) {
      return Text(text, key: textKey, textAlign: textAlign, style: style);
    }
    final clusters = text.characters.toList(growable: false);
    final visibleCount = (clusters.length * visibleFraction).ceil().clamp(
      0,
      clusters.length,
    );
    return Text.rich(
      key: textKey,
      TextSpan(
        children: [
          TextSpan(text: clusters.take(visibleCount).join()),
          TextSpan(
            text: clusters.skip(visibleCount).join(),
            style: const TextStyle(color: Colors.transparent),
          ),
        ],
      ),
      textAlign: textAlign,
      style: style,
      semanticsLabel: text,
    );
  }
}

/// The outgoing line gently clears before the incoming line begins. Even at
/// the midpoint there are never two readable lines on top of each other.
/// Every option animates only text; the wordmark and gradient stay fixed.
class SelahWelcomeTextMotionFrame extends StatelessWidget {
  const SelahWelcomeTextMotionFrame({
    super.key,
    required this.motion,
    required this.animation,
    required this.child,
  });

  final SelahWelcomeTextMotion motion;
  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: animation,
    child: child,
    builder: (context, child) {
      // AnimatedSwitcher reverses the outgoing animation. Its text clears
      // before the incoming line becomes visible, even for typed variants.
      // Typewriter has a shorter outgoing phase, leaving more time to read
      // the grapheme-by-grapheme entrance without a long blank midpoint.
      final outgoing = animation.status == AnimationStatus.reverse;
      final progress = motion.typesText
          ? outgoing
                ? ((animation.value - .7) / .3).clamp(0.0, 1.0)
                : ((animation.value - .3) / .7).clamp(0.0, 1.0)
          : ((animation.value - .5) * 2).clamp(0.0, 1.0);
      final reveal = motion.easeOut
          ? Curves.easeOutCubic.transform(progress)
          : Curves.easeInOutSine.transform(progress);
      final hidden = 1 - reveal;
      final typingProgress = motion.easedTyping
          ? Curves.easeInOutSine.transform(progress)
          : progress;
      final content = motion.typesText && child is SelahWelcomeLine
          ? child.withVisibleFraction(outgoing ? 1 : typingProgress)
          : child!;
      final transformed = motion.travel == 0
          ? content
          : Transform.translate(
              offset: Offset(0, -motion.travel * hidden),
              child: content,
            );
      return Opacity(opacity: reveal, child: transformed);
    },
  );
}

/// Uses the same clear-then-enter rhythm as the opening Welcome cards while
/// the protected continuous story remains inside its existing PageView.
/// The underlying page travel is cancelled so only artwork and copy move;
/// the shared brand canvas never slides across the screen.
class SelahWelcomePageTransitionFrame extends StatelessWidget {
  const SelahWelcomePageTransitionFrame({
    super.key,
    required this.controller,
    required this.pageIndex,
    required this.axis,
    required this.motion,
    required this.child,
    this.reverse = false,
    this.opacityKey,
  });

  final PageController controller;
  final int pageIndex;
  final Axis axis;
  final SelahWelcomeTextMotion motion;
  final Widget child;
  final bool reverse;
  final Key? opacityKey;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context)) {
      return child;
    }
    return LayoutBuilder(
      builder: (context, constraints) => AnimatedBuilder(
        animation: controller,
        child: child,
        builder: (context, child) {
          final currentPage = controller.hasClients
              ? controller.page ?? controller.initialPage.toDouble()
              : controller.initialPage.toDouble();
          final distance = (pageIndex - currentPage).clamp(-1.0, 1.0);
          final visible = ((.5 - distance.abs()) * 2).clamp(0.0, 1.0);
          final isActive = pageIndex == currentPage.round();
          final pageTravel = axis == Axis.vertical
              ? Offset(0, -distance * constraints.maxHeight)
              : Offset(distance * constraints.maxWidth * (reverse ? 1 : -1), 0);
          final contentTravel = Offset(
            0,
            distance.sign * (36 + motion.travel / 2) * (1 - visible),
          );
          final matrix = Matrix4.identity()..setEntry(3, 2, .0008);
          matrix.rotateX(distance.sign * .06 * (1 - visible));
          return Transform.translate(
            offset: pageTravel + contentTravel,
            child: IgnorePointer(
              ignoring: !isActive,
              child: ExcludeSemantics(
                excluding: !isActive,
                child: Opacity(
                  key: opacityKey,
                  opacity:
                      (motion.easeOut
                              ? Curves.easeOutCubic
                              : Curves.easeInOutSine)
                          .transform(visible),
                  child: Transform(
                    alignment: Alignment.center,
                    transform: matrix,
                    child: child,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
