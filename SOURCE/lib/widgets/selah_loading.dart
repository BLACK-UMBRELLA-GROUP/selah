// SELAH loading indicator — what a user sees in a GAP.
//
// NEW 2026-08-08. Founder: "the gaps when the app is loading… I'm thinking
// either the word SELAH jumping like it's loading, or just the purple
// background with 4 dots moving left to right."
//
// ── THIS IS NOT THE SPLASH, and the distinction is the whole point.
//
//   SPLASH   plays once at cold start, owns the screen for a fixed 3s, and
//            is a statement. It has its own bloom/draw-and-letters sequence.
//   LOADING  appears only when there is real waiting, for an unknown
//            length of time, and should be forgettable.
//
// Using the splash for a gap is what produced the bug this file was written
// alongside: picking a test account played the full four-second brand
// animation every time. A gap needs something that can appear for 80ms or
// 8 seconds and be right either way.
//
// ── ONE SHARED PRODUCTION MOTION. The Founder locked Comet line on
// 2026-08-29 after comparing the ten studies. Historical implementations stay
// available to focused tests, but there is no runtime selector in the app.
//
// ── REPLACED CircularProgressIndicator across the app, 2026-08-08.
// A Material spinner in a bespoke brand is the visual equivalent of a
// default ringtone. 28 of the 38 occurrences are now this widget: the 22
// full-area `Center(child: CircularProgressIndicator())` states, plus the
// six "Waiting for <name>" indicators in journey_flow_screen, which turned
// out to be the most important ones — those are literally the gap the
// Founder was describing.
//
// ── THE TEN THAT REMAIN ARE CORRECT AS THEY ARE, and should stay:
// 14-20px spinners inside buttons, image placeholders and sheets
// (welcome, feedback, app_lock, chapter2, profile_ready,
// selah_profile_image, report_profile_sheet, and two Shepherd buttons).
// The dot track is 106x10; it does not belong in a 16x16 slot, and a
// button that is working is not the same event as a screen that is
// waiting. Do not "finish the job" by migrating those.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme/selah_colors.dart';
import '../theme/selah_text.dart';
import 'selah_comet_rule.dart';
import 'selah_meet_and_pass_rule.dart';

/// How far the [SelahLoadingStyle.slidingDots] dots travel, in logical
/// pixels. File-level rather than declared inside the switch case: a local
/// in one `case` is scoped to the whole switch block in Dart, which is a
/// collision waiting for the second case that wants a `track`.
const double _track = 96.0;

/// The comet loop's rule width. Matches the footprint the four dots had,
/// so swapping the default does not change any screen's layout.
const double _railWidth = 118.0;

/// One approved accent for every shared loading study.
///
/// Keeping this public-for-tests prevents a legacy option or its accessible
/// still frame quietly drifting back to white/purple while the newer painters
/// remain gold. The splash wordmark is deliberately not part of this system.
@visibleForTesting
const Color kSelahLoadingAccent = SelahColors.journeyGold;

/// The historical comet loop's sweep, as a fraction of its controller — ONE
/// curve, originally matching the former splash's Pass-through fix
/// (2026-08-12; Founder: "you changed it for splash but not loading"). The old staged
/// travel-then-fade had the same frame-measured stall the splash had:
/// every cycle the lights decelerated to a visible dead stop at the
/// centre before vanishing. Now each cycle is one unbroken crossing —
/// enter, meet at speed, carry through, fade while leaving — with the
/// rail alone for the last ~12% as a breath before the next pass. The
/// loop boundary is invisible by construction: a cycle ends with the
/// stage empty, which is exactly how the next one begins.
const Interval _journeySweep = Interval(0.0, 0.88, curve: Curves.easeInOutSine);

enum SelahLoadingStyle {
  /// FORMER selection. Two gold dots meet, continue
  /// through one another, fade beyond the connection, then re-enter
  /// invisibly on the next loop. The splash moved to dot-free Bloom + Draw
  /// on 2026-08-26; loading remains intentionally separate and repeatable.
  meetAndPass,

  /// THE FORMER SPLASH RULE, ON A LOOP. Two lights run along a hairline,
  /// overlap briefly at the centre, fade, and go again.
  ///
  /// CURRENT — Founder-selected 2026-08-29. The current splash remains a
  /// separate one-time brand arrival; this is the repeatable waiting motion.
  cometLoop,

  /// Four dots hold position; the bright one travels left to right.
  /// Superseded by [cometLoop] but kept — the Founder changed his mind
  /// once already between these two, and the implementation is four lines.
  travellingDots,

  /// Four dots physically cross the space and loop. The previous default.
  slidingDots,

  /// A quiet point of gold light expands and settles at the centre.
  softBloom,

  /// A fine gold horizon draws outwards from the centre and releases.
  centreDraw,

  /// The centre bloom arrives first, then resolves into a drawn horizon.
  bloomAndDraw,

  /// Two gold lights orbit a shared centre while remaining visibly linked.
  linkedOrbit,

  /// Five fixed points connect in sequence, like a small constellation.
  constellation,

  /// A hairline bridge holds while soft rings travel away from its centre.
  rippleBridge,
}

extension SelahLoadingStyleX on SelahLoadingStyle {
  /// Shared colour contract for both moving and reduced-motion frames.
  Color get accentColor => kSelahLoadingAccent;

  String get label => switch (this) {
    SelahLoadingStyle.meetAndPass => 'Meet & pass',
    SelahLoadingStyle.cometLoop => 'Comet line',
    SelahLoadingStyle.travellingDots => 'Travelling light',
    SelahLoadingStyle.slidingDots => 'Flowing dots',
    SelahLoadingStyle.softBloom => 'Soft bloom',
    SelahLoadingStyle.centreDraw => 'Centre draw',
    SelahLoadingStyle.bloomAndDraw => 'Bloom + draw',
    SelahLoadingStyle.linkedOrbit => 'Linked orbit',
    SelahLoadingStyle.constellation => 'Constellation',
    SelahLoadingStyle.rippleBridge => 'Ripple bridge',
  };

  String get description => switch (this) {
    SelahLoadingStyle.meetAndPass =>
      'The current two-light crossing with a quiet reset.',
    SelahLoadingStyle.cometLoop =>
      'Two lights cross a fine horizon in one continuous sweep.',
    SelahLoadingStyle.travellingDots =>
      'Four fixed points brighten in a calm left-to-right rhythm.',
    SelahLoadingStyle.slidingDots =>
      'Four lights flow physically across one compact track.',
    SelahLoadingStyle.softBloom =>
      'One restrained gold light breathes at the centre.',
    SelahLoadingStyle.centreDraw =>
      'A fine horizon grows outwards from a still centre.',
    SelahLoadingStyle.bloomAndDraw =>
      'A soft arrival resolves into a complete gold horizon.',
    SelahLoadingStyle.linkedOrbit =>
      'Two linked lights orbit a shared point without breaking apart.',
    SelahLoadingStyle.constellation =>
      'Five points connect progressively, then begin again quietly.',
    SelahLoadingStyle.rippleBridge =>
      'A stable connection sends subtle rings out from its centre.',
  };
}

// bounceWordmark and sweepWordmark were REMOVED 2026-08-09, not kept as
// options. Both drew the SELAH wordmark, and the wordmark now belongs to
// the splash — a loading state that renders the brand name competes with
// the screen whose whole job is to render the brand name. Neither was ever
// chosen. Their code is in git if anyone wants it back.

/// THE ONE KNOB. Change this and every loading state in the app follows.
///
/// CHOSEN 2026-08-29 — [SelahLoadingStyle.cometLoop]. This is an
/// unknown-duration wait loop, not the splash's one-time brand arrival.
///
/// Was slidingDots for a few hours on 2026-08-08, after the Founder picked
/// "idea 2, the four dots". The splash then moved from orbs to a comet
/// rule, and loading followed it so the two screens speak one language.
const SelahLoadingStyle kSelahLoadingStyle = SelahLoadingStyle.cometLoop;

class SelahLoading extends StatefulWidget {
  /// Overrides [kSelahLoadingStyle] for one call site. Leave null.
  final SelahLoadingStyle? style;

  /// Paints the brand gradient behind the indicator and fills the screen.
  /// False (the default) draws the indicator alone, for use inside a card,
  /// a list, or a button.
  final bool fullScreen;

  /// Optional line under the indicator. Use it only when the wait has a
  /// reason worth naming ("Checking your invite…"); silence beats filler.
  final String? label;

  const SelahLoading({super.key, this.style, this.label}) : fullScreen = false;

  const SelahLoading.fullScreen({super.key, this.style, this.label})
    : fullScreen = true;

  @override
  State<SelahLoading> createState() => _SelahLoadingState();
}

class _SelahLoadingState extends State<SelahLoading>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  AnimationController get _c => _controller ??= AnimationController(
    vsync: this,
    // Matches the measured preview for Meet and Pass. The former 1400ms
    // comet cycle was intentionally busier; the gold-dot language needs a
    // calmer pace so the meeting remains legible on small inline loaders.
    duration: const Duration(milliseconds: 2800),
  )..repeat();

  @override
  void dispose() {
    // Reduced-motion builds never request the controller. Do not create an
    // animation solely in order to dispose it during unmount.
    _controller?.dispose();
    super.dispose();
  }

  /// Where dot/letter [i] sits in the loop, 0..1, wrapped.
  ///
  /// Wrapped rather than an [Interval], because an Interval clamps at both
  /// ends — the stagger has to survive crossing the loop boundary or the
  /// wave visibly restarts instead of continuing.
  double _phase(int i, double stagger) {
    final t = (_c.value - i * stagger) % 1.0;
    return t < 0 ? t + 1 : t;
  }

  /// A single smooth peak at [at], zero elsewhere. 0..1.
  double _peak(double t, {double at = 0.30, double width = 0.30}) {
    final d = (t - at).abs();
    if (d >= width) return 0;
    return Curves.easeInOut.transform(1 - d / width);
  }

  @override
  Widget build(BuildContext context) {
    final pinnedStyle = widget.style;
    if (pinnedStyle != null) return _buildForStyle(context, pinnedStyle);

    // A call-site override remains useful for focused historical visual
    // tests. Every real wait state uses the one Founder-approved motion.
    return _buildForStyle(context, kSelahLoadingStyle);
  }

  Widget _buildForStyle(BuildContext context, SelahLoadingStyle style) {
    // ACCESSIBILITY. Flutter's equivalent of prefers-reduced-motion. The
    // shape stays and the motion stops — a static indicator still says
    // "waiting", which a blank screen does not.
    final still = MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    final Widget motion = still
        ? _StillFallback(style: style)
        : AnimatedBuilder(
            animation: _c,
            builder: (context, _) => _build(style),
          );
    final indicator = Semantics(
      label: 'Loading',
      child: KeyedSubtree(
        key: ValueKey('selah_loading_${style.name}'),
        child: motion,
      ),
    );

    final Widget content = widget.label == null
        ? indicator
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              indicator,
              SizedBox(height: 18),
              Text(
                widget.label!,
                textAlign: TextAlign.center,
                style: SelahText.subtext(color: SelahColors.ink(0.70)),
              ),
            ],
          );

    if (!widget.fullScreen) return Center(child: content);

    return DecoratedBox(
      // GENDER-MATCHED — Founder, 2026-08-08: "if the app is in purple it
      // should be purple with 4 dots, if it's a female account should be
      // pink/purple 4 dots, and if it's male it should be blue/purple with
      // 4 dots."
      //
      // ── THIS IS THE OPPOSITE RULE TO THE SPLASH, AND DELIBERATELY SO.
      //
      //   SPLASH   brand purple always. It is the brand introducing
      //            itself, before the app knows or should care who is
      //            holding the phone (inherited decision 125).
      //   LOADING  matches whatever it is interrupting. It appears INSIDE
      //            a session, over a background that is already the
      //            member's colour — so painting brand purple here drops a
      //            purple panel over a pink app, which is the same flash
      //            the splash rule exists to avoid, arriving from the
      //            other direction.
      //
      // genderGradient() gives all three of the Founder's cases from one
      // call: null gender (signed out, cold start, first launch) returns
      // the neutral brand purple, and the two known genders return their
      // own. No branching needed here.
      decoration: BoxDecoration(
        gradient: SelahColors.genderGradient(AppState.instance.gender),
      ),
      child: Center(child: content),
    );
  }

  Widget _build(SelahLoadingStyle style) {
    switch (style) {
      case SelahLoadingStyle.meetAndPass:
        return SelahMeetAndPassRule(
          width: _railWidth,
          progress: Curves.easeInOutSine.transform(_c.value),
        );

      case SelahLoadingStyle.cometLoop:
        // The splash's own gesture, looped — same widget, same continuous
        // Pass-through motion (see _journeySweep), so the launch and the
        // gaps speak one language and can never drift apart.
        //
        // clip: true — inline in a card this box is ~118px, and the sweep
        // deliberately runs from outside one edge to outside the other.
        return SelahCometRule(
          width: _railWidth,
          travel: 0,
          ending: SelahCometEnding.passThrough,
          journey: _journeySweep.transform(_c.value),
          clip: true,
          accentColor: style.accentColor,
        );

      case SelahLoadingStyle.travellingDots:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(4, (i) {
            final p = _peak(_phase(i, 0.09));
            return Padding(
              padding: EdgeInsets.only(right: i == 3 ? 0 : 10),
              child: Transform.scale(
                scale: 1 + 0.42 * p,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    // Lerp, not two colours — the dot never "switches",
                    // it brightens.
                    color:
                        Color.lerp(
                          style.accentColor.withValues(alpha: 0.24),
                          style.accentColor,
                          p,
                        ) ??
                        style.accentColor.withValues(alpha: 0.24),
                  ),
                ),
              ),
            );
          }),
        );

      case SelahLoadingStyle.slidingDots:
        return SizedBox(
          width: _track + 10,
          height: 10,
          child: Stack(
            children: List.generate(4, (i) {
              final t = _phase(i, 0.08);
              // Fade in over the first 14% and out over the last 18%, so
              // dots enter and leave rather than popping at the edges.
              final o = t < 0.14 ? t / 0.14 : (t > 0.82 ? (1 - t) / 0.18 : 1.0);
              return Positioned(
                left: Curves.easeInOut.transform(t) * _track,
                top: 0,
                child: Opacity(
                  opacity: o.clamp(0.0, 1.0) * 0.92,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: style.accentColor,
                    ),
                  ),
                ),
              );
            }),
          ),
        );

      case SelahLoadingStyle.softBloom:
      case SelahLoadingStyle.centreDraw:
      case SelahLoadingStyle.bloomAndDraw:
      case SelahLoadingStyle.linkedOrbit:
      case SelahLoadingStyle.constellation:
      case SelahLoadingStyle.rippleBridge:
        return CustomPaint(
          size: const Size(_railWidth, 34),
          painter: _SelahLoadingMotionPainter(style: style, progress: _c.value),
        );
    }
  }
}

/// What reduced-motion users see. Deliberately not nothing.
class _StillFallback extends StatelessWidget {
  final SelahLoadingStyle style;
  const _StillFallback({required this.style});

  @override
  Widget build(BuildContext context) {
    if (style == SelahLoadingStyle.meetAndPass) {
      // A completed connection, held still: the accessible alternative
      // communicates waiting without repeatedly separating the dots.
      return const SelahMeetAndPassRule(width: _railWidth, progress: 0.44);
    }
    if (style == SelahLoadingStyle.cometLoop) {
      // The finished frame: both comets arrived and overlapping. Static,
      // but it is the composition rather than an arbitrary pose.
      return SelahCometRule(
        width: _railWidth,
        travel: 1,
        clip: true,
        accentColor: style.accentColor,
      );
    }
    if (style == SelahLoadingStyle.softBloom ||
        style == SelahLoadingStyle.centreDraw ||
        style == SelahLoadingStyle.bloomAndDraw ||
        style == SelahLoadingStyle.linkedOrbit ||
        style == SelahLoadingStyle.constellation ||
        style == SelahLoadingStyle.rippleBridge) {
      return CustomPaint(
        size: const Size(_railWidth, 34),
        painter: _SelahLoadingMotionPainter(style: style, progress: 0.48),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        4,
        (i) => Padding(
          padding: EdgeInsets.only(right: i == 3 ? 0 : 10),
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: style.accentColor.withValues(alpha: 0.38),
            ),
          ),
        ),
      ),
    );
  }
}

/// The six new compact motion studies. They share a footprint and palette so
/// changing the developer option never moves the surrounding layout.
class _SelahLoadingMotionPainter extends CustomPainter {
  final SelahLoadingStyle style;
  final double progress;

  const _SelahLoadingMotionPainter({
    required this.style,
    required this.progress,
  });

  static const _gold = kSelahLoadingAccent;

  double get _pulse => 0.5 - 0.5 * math.cos(progress * math.pi * 2);

  Paint _line({double alpha = 0.72, double width = 1}) => Paint()
    ..color = _gold.withValues(alpha: alpha.clamp(0.0, 1.0))
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;

  void _dot(
    Canvas canvas,
    Offset centre, {
    double radius = 2.2,
    double alpha = 1,
    double glow = 0,
  }) {
    if (glow > 0) {
      canvas.drawCircle(
        centre,
        glow,
        Paint()
          ..shader = RadialGradient(
            colors: [
              _gold.withValues(alpha: 0.30 * alpha),
              _gold.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: centre, radius: glow)),
      );
    }
    canvas.drawCircle(
      centre,
      radius,
      Paint()..color = _gold.withValues(alpha: alpha.clamp(0.0, 1.0)),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    switch (style) {
      case SelahLoadingStyle.softBloom:
        _paintSoftBloom(canvas, centre);
      case SelahLoadingStyle.centreDraw:
        _paintCentreDraw(canvas, centre);
      case SelahLoadingStyle.bloomAndDraw:
        _paintBloomAndDraw(canvas, centre);
      case SelahLoadingStyle.linkedOrbit:
        _paintLinkedOrbit(canvas, centre);
      case SelahLoadingStyle.constellation:
        _paintConstellation(canvas, centre);
      case SelahLoadingStyle.rippleBridge:
        _paintRippleBridge(canvas, centre);
      case SelahLoadingStyle.meetAndPass:
      case SelahLoadingStyle.cometLoop:
      case SelahLoadingStyle.travellingDots:
      case SelahLoadingStyle.slidingDots:
        // These four retain their dedicated widgets above.
        return;
    }
  }

  void _paintSoftBloom(Canvas canvas, Offset centre) {
    final radius = 7 + 12 * _pulse;
    canvas.drawCircle(
      centre,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            _gold.withValues(alpha: 0.32 + 0.16 * _pulse),
            _gold.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: centre, radius: radius)),
    );
    _dot(
      canvas,
      centre,
      radius: 1.8 + 0.8 * _pulse,
      alpha: 0.82 + 0.18 * _pulse,
    );
  }

  void _paintCentreDraw(Canvas canvas, Offset centre) {
    final raw = progress < 0.72
        ? progress / 0.72
        : (1 - (progress - 0.72) / 0.28).clamp(0.0, 1.0);
    final extent = 49 * Curves.easeInOutCubic.transform(raw);
    canvas.drawLine(
      Offset(centre.dx - extent, centre.dy),
      Offset(centre.dx + extent, centre.dy),
      _line(alpha: 0.35 + raw * 0.55, width: 1.25),
    );
    _dot(canvas, centre, radius: 1.65, alpha: 0.72 + 0.28 * raw);
  }

  void _paintBloomAndDraw(Canvas canvas, Offset centre) {
    final bloom = progress < 0.42
        ? Curves.easeOutCubic.transform((progress / 0.42).clamp(0.0, 1.0))
        : (1 - (progress - 0.42) / 0.58).clamp(0.0, 1.0);
    final draw = progress < 0.18
        ? 0.0
        : progress < 0.76
        ? Curves.easeInOutCubic.transform((progress - 0.18) / 0.58)
        : (1 - (progress - 0.76) / 0.24).clamp(0.0, 1.0);
    final glowRadius = 5 + 11 * bloom;
    canvas.drawCircle(
      centre,
      glowRadius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            _gold.withValues(alpha: 0.28 * bloom),
            _gold.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: centre, radius: glowRadius)),
    );
    final extent = 48 * draw;
    canvas.drawLine(
      Offset(centre.dx - extent, centre.dy),
      Offset(centre.dx + extent, centre.dy),
      _line(alpha: 0.22 + 0.68 * draw, width: 1.15),
    );
    _dot(canvas, centre, radius: 1.6 + bloom, alpha: 0.70 + 0.30 * bloom);
  }

  void _paintLinkedOrbit(Canvas canvas, Offset centre) {
    final angle = progress * math.pi * 2;
    final offset = Offset(math.cos(angle) * 31, math.sin(angle) * 8);
    final first = centre + offset;
    final second = centre - offset;
    canvas.drawLine(first, second, _line(alpha: 0.34, width: 0.8));
    _dot(canvas, centre, radius: 1.1, alpha: 0.42);
    _dot(canvas, first, radius: 2.2, glow: 7, alpha: 0.78 + 0.22 * _pulse);
    _dot(canvas, second, radius: 2.2, glow: 7, alpha: 0.78 + 0.22 * _pulse);
  }

  void _paintConstellation(Canvas canvas, Offset centre) {
    final points = <Offset>[
      centre + const Offset(-49, 5),
      centre + const Offset(-27, -5),
      centre + const Offset(-4, 3),
      centre + const Offset(22, -6),
      centre + const Offset(49, 4),
    ];
    final draw = progress < 0.78
        ? Curves.easeInOutCubic.transform(progress / 0.78)
        : (1 - (progress - 0.78) / 0.22).clamp(0.0, 1.0);
    for (var i = 0; i < points.length - 1; i++) {
      canvas.drawLine(points[i], points[i + 1], _line(alpha: 0.16));
    }
    final scaled = draw * (points.length - 1);
    final completeSegments = scaled.floor().clamp(0, points.length - 1);
    for (var i = 0; i < completeSegments; i++) {
      canvas.drawLine(points[i], points[i + 1], _line(alpha: 0.78, width: 1.1));
    }
    if (completeSegments < points.length - 1) {
      final local = scaled - completeSegments;
      canvas.drawLine(
        points[completeSegments],
        Offset.lerp(
          points[completeSegments],
          points[completeSegments + 1],
          local,
        )!,
        _line(alpha: 0.78, width: 1.1),
      );
    }
    for (var i = 0; i < points.length; i++) {
      final reached = i <= scaled.ceil();
      _dot(
        canvas,
        points[i],
        radius: reached ? 1.9 : 1.35,
        alpha: reached ? 0.88 : 0.24,
        glow: reached && (scaled - i).abs() < 0.8 ? 6 : 0,
      );
    }
  }

  void _paintRippleBridge(Canvas canvas, Offset centre) {
    canvas.drawLine(
      Offset(centre.dx - 48, centre.dy),
      Offset(centre.dx + 48, centre.dy),
      _line(alpha: 0.32, width: 0.8),
    );
    for (var i = 0; i < 3; i++) {
      final phase = (progress + i / 3) % 1.0;
      final alpha = math.sin(phase * math.pi).clamp(0.0, 1.0) * 0.38;
      canvas.drawCircle(
        centre,
        3 + 18 * phase,
        _line(alpha: alpha, width: 0.9),
      );
    }
    _dot(
      canvas,
      centre,
      radius: 1.8 + _pulse * 0.7,
      alpha: 0.78 + _pulse * 0.22,
      glow: 7,
    );
  }

  @override
  bool shouldRepaint(covariant _SelahLoadingMotionPainter oldDelegate) =>
      oldDelegate.style != style || oldDelegate.progress != progress;
}
