// The comet rule — two lights running toward each other along a hairline.
//
// Historical comet-rule implementation retained for explicit legacy
// loading-style previews. The production splash and Splash Lab moved to the
// dot-free SelahSplashMotion family on 2026-08-26 and no longer import this.
//
//   SPLASH   plays it once. The lights arrive, overlap, and fade, leaving
//            the rail under the wordmark for the still second at the end.
//   LOADING  used to play it on a loop. Founder-selected Meet and Pass
//            superseded that default on 2026-08-20.
//
// Extracted from splash_screen.dart on 2026-08-09 the moment the second
// caller appeared. This codebase has already paid for the alternative
// today: four private copies of the same age-fetching method meant one
// bug in four places and no guarantee a fix reached all of them (I3, "one
// path, or the paths will drift"). A second copy of an animation is the
// same trade with a prettier surface.
//
// ── WHAT REPLACED THE ORBS, AND WHY. Founder, 2026-08-08: "I just don't
// like the purple ball the pink and blue creates in end." Two soft discs
// meeting concentrically make a large area of a colour nobody chose —
// screen(#D4868F, #3D5A80) over the mid-gradient lands on ~#EBC7E1, a pale
// lilac. The merge was never the problem; the surface area was. Two lines
// meeting make the same colour across a few pixels.
//
// ── WHY BlendMode.screen. royalBlue (#3D5A80) is DARKER than the purple
// it sits on (~#644A74 mid-screen). Painted normally it is a muddy smear;
// screened it lifts to a light periwinkle and reads as light rather than
// ink. Measured, not guessed.
//
// RepaintBoundary is required, not decorative: backgroundBlendMode
// composites against whatever is already painted in the current layer, so
// each comet needs a layer to blend into.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/selah_colors.dart';

/// How the historical comet sequence resolves after the lights meet.
///
/// FIVE ALTERNATIVES + THE ORIGINAL — 2026-08-12 (Founder: the ending
/// "doesn't feel smooth… almost looks like there's a small glitch or
/// visual jump. Propose five alternative versions… same visual style").
///
/// The diagnosed glitch in [classic]: travel decelerates into 0.62 and a
/// UNIFORM opacity fade begins the same instant. On a gradient tail, a
/// uniform fade kills the faintest pixels first, so the visible line
/// appears to SHRINK BACK outward — motion nobody authored, read as the
/// lines "moving back the other way". Every variant below either removes
/// the uniform fade or gives the ending authored motion of its own.
/// All five keep the rail, the two comets, the palette and the timing
/// window; only the resolution differs. The Founder chose PASS THROUGH
/// (2026-08-12) for the former splash implementation. These variants are
/// retained only for explicit historical loading-style previews; the current
/// splash and Splash Lab use the dot-free SelahSplashMotion family.
enum SelahCometEnding {
  /// The original: arrive, then uniform fade in place.
  classic,

  /// 1 · SETTLE — the comets hold their arrival for a beat, then dim
  /// slowly and evenly-in-time (sine ease), like an ember settling into
  /// the rail. The hold is what removes the glitch: nothing fades while
  /// anything still moves.
  settle,

  /// 2 · PASS THROUGH — the meeting is a crossing, not a collision: each
  /// light continues along its own path, through the other, off the far
  /// end of the rail, fading as it goes. Connection as two paths carrying
  /// each other forward.
  passThrough,

  /// 3 · MERGE — on meeting, the two lights become ONE small glow at the
  /// centre that breathes once and settles into a faint bright midpoint
  /// the still second keeps. The union stays visible.
  merge,

  /// 4 · IGNITE — the meeting lights the rail: a brightness sweep runs
  /// from the centre out to both ends, the comets dissolve into it, and
  /// the rail holds slightly brighter than it began. Their meeting
  /// completes the line.
  ignite,

  /// 5 · ASCEND — the merged point of light rises gently from the rail
  /// toward the wordmark and dissolves, the connection lifting into the
  /// name. The rail stays exactly as it was.
  ascend,
}

class SelahCometRule extends StatelessWidget {
  /// Total width of the rule in logical pixels.
  final double width;

  /// 0 = both comets off-stage, 1 = arrived and overlapping.
  final double travel;

  /// 0 = comets at full strength, 1 = fully gone. The rail is unaffected —
  /// in the historical one-shot composition it survived into the hold.
  final double fade;

  /// The faint rail's own fade-in, so it is established before anything
  /// travels along it. Pass 1 to have it simply present.
  final double railOpacity;

  final double thickness;

  /// Clip the comets to the rule's own width.
  ///
  /// FALSE in the historical one-shot composition: at travel 0 each comet
  /// sits a full half-rule outside the box and enters from off-screen.
  ///
  /// TRUE for the looping loading indicator, which may be 118px wide
  /// inside a card — unclipped, its comets would paint 59px into whatever
  /// is beside them.
  final bool clip;

  /// How far past centre each comet pushes, as a fraction of a half-rule.
  ///
  /// THIS IS THE MERGE. Each comet is exactly half the rule, so at 0 they
  /// would meet edge to edge and never touch — two colours arriving and
  /// stopping. At 0.09 the two bright ends overlap and produce the
  /// pink-blue mix across roughly 20 logical pixels, which is the whole
  /// point of the image and about a hundredth of the area the orbs used.
  final double overshoot;

  /// Which final sequence [fade] drives. [SelahCometEnding.classic] keeps
  /// the pre-2026-08-12 behaviour exactly; the loading loop uses it and is
  /// untouched by the variants.
  final SelahCometEnding ending;

  /// ONE UNBROKEN MOTION for [SelahCometEnding.passThrough] — 2026-08-12,
  /// same day it was chosen. The Founder's screen recording, measured
  /// frame by frame, showed the real problem: the travel curve decelerated
  /// so hard that all visible motion ended by ~0.6s and the line sat
  /// FROZEN for over a second before the hold ("theres like a second
  /// pause… i want it to flow seamlessly"). Splitting the crossing into
  /// travel-then-exit intervals could only ever stitch two curves together
  /// at the meeting point — a seam, exactly where every eye is looking.
  ///
  /// So Pass through no longer uses [travel]/[fade] staging at all. Pass
  /// [journey] (0→1, pre-curved by the caller with ONE curve) and each
  /// comet runs a single sweep: off one edge, through the centre AT SPEED,
  /// off the far edge, fading as it recedes. One curve, one velocity
  /// profile, no point where anything stops while visible. Null falls back
  /// to the staged behaviour (the lab's other variants, the loading loop).
  final double? journey;

  /// Optional single-colour treatment used by repeatable shared loaders.
  ///
  /// Null preserves the historical comet study for any explicit legacy
  /// caller. The loading system supplies SELAH gold so its rail, travelling
  /// lights and reduced-motion frame all share the same approved accent.
  final Color? accentColor;

  const SelahCometRule({
    super.key,
    required this.width,
    required this.travel,
    this.fade = 0,
    this.railOpacity = 1,
    this.thickness = 2,
    this.overshoot = 0.09,
    this.clip = false,
    this.ending = SelahCometEnding.classic,
    this.journey,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final half = width / 2;
    final t = travel.clamp(0.0, 1.0);
    final endT = fade.clamp(0.0, 1.0);

    // Per-ending resolution: comet opacity, extra travel past the meeting
    // point, and any centre artefact (glow / sweep / rail boost).
    double alpha;
    double extraTravel = 0; // fraction of rule width, each along its own path
    double glowOpacity = 0; // centre glow (merge / ascend)
    double glowRise = 0; // px upward (ascend)
    double sweepT = 0; // 0-1 outward rail sweep (ignite)
    double railBoost = 0; // extra rail brightness that survives the hold
    switch (ending) {
      case SelahCometEnding.classic:
        alpha = 1 - endT;
      case SelahCometEnding.settle:
        // Hold a quarter of the window, then a sine ease — even in TIME,
        // so the dimming reads as settling rather than retreating.
        final f = ((endT - 0.25) / 0.75).clamp(0.0, 1.0);
        alpha = 0.5 + 0.5 * math.cos(math.pi * f);
      case SelahCometEnding.passThrough:
        // Keep travelling: the exit continues the arrival's momentum;
        // brightness falls with distance, gone before the far edge.
        extraTravel = 0.85 * Curves.easeInQuad.transform(endT);
        alpha = 1 - Curves.easeOutQuad.transform(endT);
      case SelahCometEnding.merge:
        alpha = 1 - (endT * 2.2).clamp(0.0, 1.0);
        // Breathe once: rise fast, settle to a kept midpoint.
        glowOpacity = endT < 0.45
            ? Curves.easeOut.transform(endT / 0.45)
            : 1 - 0.62 * Curves.easeInOut.transform((endT - 0.45) / 0.55);
      case SelahCometEnding.ignite:
        alpha = 1 - (endT * 1.8).clamp(0.0, 1.0);
        sweepT = Curves.easeOutCubic.transform(endT);
        railBoost = 0.22 * Curves.easeIn.transform(endT);
      case SelahCometEnding.ascend:
        alpha = 1 - (endT * 2.2).clamp(0.0, 1.0);
        glowOpacity = endT < 0.3
            ? Curves.easeOut.transform(endT / 0.3)
            : 1 - Curves.easeInSine.transform((endT - 0.3) / 0.7);
        glowRise = 34 * Curves.easeInOutSine.transform(endT);
    }
    alpha = alpha.clamp(0.0, 1.0);

    // Both comets are Positioned at left:0, so dx is measured from the
    // LEFT edge of the rule for both of them — which is why the two
    // expressions are not mirror images of each other.
    //
    //   rose  starts at -half   (entirely off the left edge)
    //         ends   at +overshoot*half   (right edge just past centre)
    //   blue  starts at  width  (entirely off the right edge)
    //         ends   at  half - overshoot*half  (left edge just past centre)
    //
    // Blue's start is `width`, NOT `half`. Written as `half` first time
    // through, which put it in its final resting place at t = 0 — it never
    // travelled, it just faded up already arrived. Spelled out here so it
    // does not have to be re-derived.
    final reach = half + overshoot * half;
    var roseDx = -half + t * reach + extraTravel * width;
    var blueDx = width - t * reach - extraTravel * width;

    // The continuous crossing — see [journey]. Total sweep per comet is
    // 1.5× the rule (fully off one edge to fully off the other); the
    // bright ends meet at exactly one third of it, where a single gentle
    // curve is near its fastest — the connection happens IN MOTION.
    // Brightness holds through the meeting, then falls as they recede,
    // gone before the journey ends so the hold begins on the rail alone.
    if (ending == SelahCometEnding.passThrough && journey != null) {
      final j = journey!.clamp(0.0, 1.0);
      final sweep = width + half;
      roseDx = -half + j * sweep;
      blueDx = width - j * sweep;
      alpha = 1 - ((j - 0.42) / 0.53).clamp(0.0, 1.0);
    }

    return SizedBox(
      width: width,
      height: thickness,
      child: Stack(
        clipBehavior: clip ? Clip.hardEdge : Clip.none,
        children: [
          Opacity(
            opacity: (railOpacity.clamp(0.0, 1.0) * (0.14 + railBoost)).clamp(
              0.0,
              1.0,
            ),
            child: Align(
              alignment: Alignment.center,
              child: Container(
                width: width,
                height: 1,
                color: accentColor ?? Colors.white,
              ),
            ),
          ),
          // IGNITE's outward sweep — a brighter line growing from the
          // centre to both ends, then settling into the boosted rail.
          if (sweepT > 0)
            Align(
              alignment: Alignment.center,
              child: Opacity(
                opacity: (0.45 * (1 - 0.55 * sweepT)).clamp(0.0, 1.0),
                child: Container(
                  width: width * sweepT,
                  height: 1,
                  color: accentColor ?? Colors.white,
                ),
              ),
            ),
          // Positioned lives HERE, not inside _Comet. A StatelessWidget
          // that returns a Positioned does work — the framework skips
          // component elements when looking for the Stack — but it breaks
          // the moment anyone wraps _Comet in anything owning a render
          // object, and the failure is a runtime "Incorrect use of
          // ParentDataWidget", not a compile error.
          Positioned(
            left: 0,
            top: 0,
            child: _Comet(
              colour: accentColor ?? SelahColors.royalPurple,
              width: half,
              thickness: thickness,
              dx: roseDx,
              opacity: alpha,
              brightEnd: _BrightEnd.right,
            ),
          ),
          Positioned(
            left: 0,
            top: 0,
            child: _Comet(
              colour: accentColor ?? SelahColors.royalPurple,
              width: half,
              thickness: thickness,
              dx: blueDx,
              opacity: alpha,
              brightEnd: _BrightEnd.left,
            ),
          ),
          // MERGE / ASCEND's single light — the union of the two, white
          // because white is what their overlap already reads as under
          // BlendMode.screen. Rises on ASCEND, settles in place on MERGE.
          if (glowOpacity > 0)
            Positioned(
              left: half - 13,
              top: thickness / 2 - 5 - glowRise,
              child: Opacity(
                opacity: glowOpacity.clamp(0.0, 1.0),
                child: Container(
                  width: 26,
                  height: 10,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.all(Radius.circular(999)),
                    gradient: RadialGradient(
                      colors: [
                        accentColor ?? Colors.white,
                        (accentColor ?? Colors.white).withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Which end of a comet carries the colour. Always the end facing centre —
/// the two bright ends are what meet.
///
/// An enum rather than an [Alignment], because comparing Alignments to pick
/// a gradient direction reads as geometry when it is really a two-state
/// choice, and it invites someone to pass topLeft.
enum _BrightEnd { left, right }

/// One half of the rule: a tail fading to nothing at the outer end and full
/// colour at the inner one.
class _Comet extends StatelessWidget {
  final Color colour;
  final double width;
  final double thickness;
  final double dx;
  final double opacity;
  final _BrightEnd brightEnd;

  const _Comet({
    required this.colour,
    required this.width,
    required this.thickness,
    required this.dx,
    required this.opacity,
    required this.brightEnd,
  });

  @override
  Widget build(BuildContext context) => Transform.translate(
    offset: Offset(dx, 0),
    child: Opacity(
      opacity: opacity.clamp(0.0, 1.0),
      child: RepaintBoundary(
        child: Container(
          width: width,
          height: thickness,
          decoration: BoxDecoration(
            backgroundBlendMode: BlendMode.screen,
            borderRadius: BorderRadius.circular(thickness),
            gradient: LinearGradient(
              begin: brightEnd == _BrightEnd.right
                  ? Alignment.centerLeft
                  : Alignment.centerRight,
              end: brightEnd == _BrightEnd.right
                  ? Alignment.centerRight
                  : Alignment.centerLeft,
              colors: [colour.withValues(alpha: 0.0), colour],
            ),
          ),
        ),
      ),
    ),
  );
}
