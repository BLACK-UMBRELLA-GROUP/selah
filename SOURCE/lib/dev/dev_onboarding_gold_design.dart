// Protected, session-local gold backdrop comparisons for the opening story.
// These are decorative only: no input, persistence, account or score changes.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/selah_account_state.dart';
import '../services/selah_developer_access.dart';
import '../theme/selah_colors.dart';

enum SelahOnboardingGoldDesign {
  goldDust('Gold dust'),
  fineDust('Fine dust'),
  sparseDust('Sparse dust'),
  brightDust('Bright dust'),
  highDrift('High drift'),
  lowDrift('Low drift'),
  edgeDust('Edge dust'),
  diagonalDust('Diagonal edge'),
  twinClouds('Twin clouds'),
  dustHalo('Dust halo'),
  gentleSweep('Gentle sweep');

  const SelahOnboardingGoldDesign(this.label);
  final String label;
}

enum SelahOnboardingGoldMotion {
  pageEntrance('Page entrance'),
  liveDrift('Live drift');

  const SelahOnboardingGoldMotion(this.label);
  final String label;
}

abstract final class SelahDevOnboardingGoldMotion {
  static const defaultMotion = SelahOnboardingGoldMotion.liveDrift;
  static final ValueNotifier<SelahOnboardingGoldMotion> _selection =
      ValueNotifier(defaultMotion);
  static final ValueNotifier<int> _pageEntry = ValueNotifier(0);
  static int _accountGeneration = SelahAccountState.generation;

  static Listenable get changes => _selection;
  static Listenable get pageEntries => _pageEntry;
  static SelahOnboardingGoldMotion get current =>
      _accountGeneration == SelahAccountState.generation
      ? _selection.value
      : defaultMotion;

  static bool select(SelahOnboardingGoldMotion motion) {
    if (!SelahDeveloperAccess.canUseDeveloperTools) return false;
    final generation = SelahAccountState.generation;
    if (_accountGeneration != generation) {
      _accountGeneration = generation;
      _selection.value = defaultMotion;
    }
    _selection.value = motion;
    return true;
  }

  static void pageEntered() {
    if (!SelahDeveloperAccess.canUseDeveloperTools) return;
    _pageEntry.value++;
  }

  @visibleForTesting
  static void resetForTesting() {
    assert(() {
      _accountGeneration = SelahAccountState.generation;
      _selection.value = defaultMotion;
      _pageEntry.value = 0;
      return true;
    }());
  }
}

abstract final class SelahDevOnboardingGoldDesign {
  static const defaultDesign = SelahOnboardingGoldDesign.diagonalDust;
  static final ValueNotifier<SelahOnboardingGoldDesign> _selection =
      ValueNotifier(defaultDesign);
  static int _accountGeneration = SelahAccountState.generation;

  static Listenable get changes => _selection;
  static SelahOnboardingGoldDesign get current =>
      _accountGeneration == SelahAccountState.generation
      ? _selection.value
      : defaultDesign;

  static bool select(SelahOnboardingGoldDesign design) {
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

/// Paints under the fixed purple canvas content, never above a tappable page.
class SelahOnboardingGoldBackdrop extends StatefulWidget {
  const SelahOnboardingGoldBackdrop({super.key});

  @override
  State<SelahOnboardingGoldBackdrop> createState() =>
      _SelahOnboardingGoldBackdropState();
}

class _SelahOnboardingGoldBackdropState extends State<SelahOnboardingGoldBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion = AnimationController(vsync: this);
  bool _reducedMotion = false;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    SelahDevOnboardingGoldMotion.changes.addListener(_startMotion);
    SelahDevOnboardingGoldMotion.pageEntries.addListener(_onPageEntered);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced =
        MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context);
    if (!_started || _reducedMotion != reduced) {
      _reducedMotion = reduced;
      _started = true;
      _startMotion();
    }
  }

  void _startMotion() {
    if (!mounted) return;
    _motion.stop();
    if (_reducedMotion) {
      _motion.value = 1;
      return;
    }
    switch (SelahDevOnboardingGoldMotion.current) {
      case SelahOnboardingGoldMotion.pageEntrance:
        _motion.duration = const Duration(milliseconds: 1050);
        _motion.forward(from: 0);
      case SelahOnboardingGoldMotion.liveDrift:
        _motion.duration = const Duration(milliseconds: 4800);
        _motion.repeat();
    }
  }

  void _onPageEntered() {
    if (SelahDevOnboardingGoldMotion.current ==
        SelahOnboardingGoldMotion.pageEntrance) {
      _startMotion();
    }
  }

  @override
  void dispose() {
    SelahDevOnboardingGoldMotion.changes.removeListener(_startMotion);
    SelahDevOnboardingGoldMotion.pageEntries.removeListener(_onPageEntered);
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: ListenableBuilder(
      listenable: Listenable.merge([
        SelahDevOnboardingGoldDesign.changes,
        SelahDevOnboardingGoldMotion.changes,
        _motion,
      ]),
      builder: (context, _) => CustomPaint(
        key: const ValueKey('dev_onboarding_gold_backdrop'),
        painter: SelahOnboardingGoldPainter(
          SelahDevOnboardingGoldDesign.current,
          motion: SelahDevOnboardingGoldMotion.current,
          motionValue: _motion.value,
          reducedMotion: _reducedMotion,
        ),
        child: const SizedBox.expand(),
      ),
    ),
  );
}

/// The small toggle preview uses the same geometry with stronger visibility.
class SelahOnboardingGoldSwatch extends StatelessWidget {
  const SelahOnboardingGoldSwatch(this.design, {super.key});
  final SelahOnboardingGoldDesign design;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(7),
    child: DecoratedBox(
      decoration: BoxDecoration(gradient: SelahColors.brandGradient),
      child: SizedBox(
        width: 56,
        height: 36,
        child: CustomPaint(
          painter: SelahOnboardingGoldPainter(design, preview: true),
        ),
      ),
    ),
  );
}

// Normalised, deterministic coordinates keep Gold dust as the reference
// pattern while the comparisons vary its density, placement and brightness.
const _goldDustPoints = <(double, double, double)>[
  (.08, .12, .38),
  (.23, .15, .58),
  (.39, .09, .32),
  (.66, .16, .48),
  (.89, .11, .7),
  (.13, .28, .52),
  (.81, .29, .38),
  (.95, .42, .53),
  (.07, .48, .4),
  (.17, .63, .64),
  (.87, .57, .58),
  (.73, .7, .38),
  (.09, .83, .46),
  (.31, .9, .5),
  (.55, .86, .3),
  (.91, .88, .64),
  (.49, .19, .25),
  (.63, .94, .42),
];

class SelahOnboardingGoldPainter extends CustomPainter {
  const SelahOnboardingGoldPainter(
    this.design, {
    this.preview = false,
    this.motion = SelahOnboardingGoldMotion.pageEntrance,
    this.motionValue = 1,
    this.reducedMotion = false,
  });
  final SelahOnboardingGoldDesign design;
  final bool preview;
  final SelahOnboardingGoldMotion motion;
  final double motionValue;
  final bool reducedMotion;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    Iterable<(double, double, double)> points = _goldDustPoints;
    var opacity = .28;
    var radiusScale = 1.0;

    switch (design) {
      case SelahOnboardingGoldDesign.goldDust:
        break;
      case SelahOnboardingGoldDesign.fineDust:
        points = [
          ..._goldDustPoints,
          (.05, .35, .38),
          (.3, .25, .46),
          (.72, .08, .31),
          (.93, .68, .42),
          (.36, .79, .35),
          (.78, .93, .4),
        ];
        radiusScale = .68;
      case SelahOnboardingGoldDesign.sparseDust:
        points = [
          for (var index = 0; index < _goldDustPoints.length; index += 2)
            _goldDustPoints[index],
        ];
        radiusScale = 1.12;
      case SelahOnboardingGoldDesign.brightDust:
        opacity = .4;
        radiusScale = 1.12;
      case SelahOnboardingGoldDesign.highDrift:
        points = _goldDustPoints.map(
          (point) => (point.$1, .06 + point.$2 * .52, point.$3),
        );
      case SelahOnboardingGoldDesign.lowDrift:
        points = _goldDustPoints.map(
          (point) => (point.$1, .42 + point.$2 * .52, point.$3),
        );
      case SelahOnboardingGoldDesign.edgeDust:
        points = _goldDustPoints.map(
          (point) => (
            point.$1 < .5 ? point.$1 * .62 : .38 + point.$1 * .62,
            point.$2,
            point.$3,
          ),
        );
      case SelahOnboardingGoldDesign.diagonalDust:
        points = _goldDustPoints.map(
          (point) => (
            point.$1,
            .76 - .55 * point.$1 + .23 * (point.$2 - .5),
            point.$3,
          ),
        );
      case SelahOnboardingGoldDesign.twinClouds:
        points = const <(double, double, double)>[
          (.09, .17, .55),
          (.2, .24, .45),
          (.13, .32, .7),
          (.29, .38, .3),
          (.07, .48, .5),
          (.24, .6, .62),
          (.12, .74, .38),
          (.28, .86, .52),
          (.8, .12, .5),
          (.91, .22, .68),
          (.75, .33, .36),
          (.88, .43, .55),
          (.72, .56, .42),
          (.94, .65, .72),
          (.79, .78, .5),
          (.9, .88, .36),
        ];
      case SelahOnboardingGoldDesign.dustHalo:
        points = const <(double, double, double)>[
          (.37, .1, .48),
          (.5, .07, .4),
          (.65, .1, .58),
          (.78, .18, .45),
          (.85, .3, .62),
          (.88, .44, .36),
          (.85, .62, .52),
          (.76, .76, .4),
          (.63, .88, .58),
          (.48, .92, .42),
          (.33, .87, .52),
          (.2, .77, .35),
          (.12, .61, .6),
          (.11, .45, .38),
          (.16, .29, .5),
          (.24, .17, .43),
        ];
      case SelahOnboardingGoldDesign.gentleSweep:
        points = const <(double, double, double)>[
          (.08, .78, .4),
          (.13, .68, .52),
          (.19, .58, .32),
          (.26, .5, .6),
          (.34, .44, .42),
          (.43, .39, .36),
          (.53, .38, .62),
          (.61, .4, .32),
          (.7, .44, .55),
          (.78, .5, .4),
          (.85, .59, .64),
          (.9, .69, .38),
          (.94, .81, .52),
          (.17, .86, .28),
          (.81, .74, .3),
        ];
    }

    final gold = SelahColors.splashWordmark;
    // The old full-page flecks were sub-pixel on a phone and almost invisible
    // against purple, even though the toggle swatches looked different. Keep
    // the swatches compact, but give each full-page fleck a soft halo and a
    // readable core so choosing a pattern has a visible effect on-device.
    final previewStrength = preview ? 2.8 : 1.8;
    var index = 0;
    for (final (x, y, weight) in points) {
      var opacityFactor = 1.0;
      var verticalShift = 0.0;
      if (!preview && !reducedMotion) {
        switch (motion) {
          case SelahOnboardingGoldMotion.pageEntrance:
            final staggered = (motionValue - index * .018).clamp(0.0, 1.0);
            final eased = Curves.easeOutCubic.transform(staggered);
            opacityFactor = eased;
            verticalShift = (1 - eased) * 10;
          case SelahOnboardingGoldMotion.liveDrift:
            final wave = math.sin(motionValue * 2 * math.pi + index * .77);
            opacityFactor = .7 + .3 * ((wave + 1) / 2);
            verticalShift = wave * 7;
        }
      }
      final radius =
          (preview ? 1.2 : size.shortestSide * .018) * weight * radiusScale;
      final center = Offset(size.width * x, size.height * y + verticalShift);
      if (!preview) {
        final haloRadius = radius * 3.2;
        canvas.drawCircle(
          center,
          haloRadius,
          Paint()
            ..shader = RadialGradient(
              colors: [
                gold.withValues(alpha: .16 * weight * opacityFactor),
                gold.withValues(alpha: 0),
              ],
            ).createShader(Rect.fromCircle(center: center, radius: haloRadius)),
        );
      }
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = gold.withValues(
            alpha: (opacity * weight * previewStrength * opacityFactor).clamp(
              0.0,
              1.0,
            ),
          ),
      );
      index++;
    }
  }

  @override
  bool shouldRepaint(covariant SelahOnboardingGoldPainter oldDelegate) =>
      oldDelegate.design != design ||
      oldDelegate.preview != preview ||
      oldDelegate.motion != motion ||
      oldDelegate.motionValue != motionValue ||
      oldDelegate.reducedMotion != reducedMotion;
}
