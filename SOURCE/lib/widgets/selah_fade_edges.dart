// Fades the top and bottom edges of a scrollable instead of cutting them.
//
// ADDED 2026-08-07, after four wrong diagnoses of the same complaint
// (Founder, repeatedly: "there's a line at the top… and a line at the bottom
// when I scroll down").
//
// WHAT IT ACTUALLY WAS. Screens using `extendBodyBehindAppBar: true` let
// content scroll UNDER a transparent app bar. Nothing hides the transition,
// so a widget passing the viewport edge is CUT — cleanly, in a straight
// horizontal line. On text it reads as a crop. On a solid shape like the
// Shepherd monogram it reads as a hard rule across the screen, because half
// a circle with a flat top IS a line.
//
// Measuring the still image found no seam anywhere, twice, which is exactly
// what you would expect: the line is not painted, it is the ABSENCE of the
// pixels above it. That is why removing the refresh indicator, the Material
// 3 app-bar tint, the duplicated gradient and the overscroll indicator each
// fixed something real and none of them fixed this.
//
// THE FIX. A ShaderMask that ramps alpha from 0 to 1 over the first few
// points and back to 0 over the last few. Content dissolves into the
// gradient rather than meeting a boundary. Nothing is drawn — the mask
// removes pixels, so it cannot introduce a colour of its own, which is what
// made every earlier attempt at this fail on a gradient background.

import 'package:flutter/material.dart';

class SelahFadeEdges extends StatelessWidget {
  final Widget child;

  /// How far the fade runs, in logical pixels. Short enough not to hide
  /// content, long enough that the eye reads it as a soft edge.
  final double top;
  final double bottom;

  const SelahFadeEdges({
    super.key,
    required this.child,
    this.top = 28,
    this.bottom = 28,
  });

  /// Fades only the lower viewport edge. This is the correct treatment for
  /// scrollable content passing behind floating bottom chrome: the first item
  /// remains fully opaque while card borders dissolve before reaching the
  /// navigation bar.
  const SelahFadeEdges.bottomOnly({
    super.key,
    required this.child,
    this.bottom = 28,
  }) : top = 0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;
        final effectiveTop = top > 0 ? top : 0.0;
        final effectiveBottom = bottom > 0 ? bottom : 0.0;
        if (effectiveTop == 0 && effectiveBottom == 0) return child;
        // Guard against a zero or unbounded height: the stops must stay
        // ordered and within 0..1 or the shader throws.
        if (!h.isFinite || h <= (effectiveTop + effectiveBottom)) return child;
        final t = (effectiveTop / h).clamp(0.0, 0.5);
        final b = 1.0 - (effectiveBottom / h).clamp(0.0, 0.5);

        final colors = effectiveTop == 0
            ? const [Colors.black, Colors.black, Colors.transparent]
            : effectiveBottom == 0
            ? const [Colors.transparent, Colors.black, Colors.black]
            : const [
                Colors.transparent,
                Colors.black,
                Colors.black,
                Colors.transparent,
              ];
        final stops = effectiveTop == 0
            ? <double>[0.0, b, 1.0]
            : effectiveBottom == 0
            ? <double>[0.0, t, 1.0]
            : <double>[0.0, t, b, 1.0];

        return ShaderMask(
          // The mask must be sampled over the whole child, not the layer
          // bounds, or the fade drifts as the list scrolls.
          shaderCallback: (rect) => LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: colors,
            stops: stops,
          ).createShader(rect),
          // dstIn keeps the child's colour and takes only the mask's alpha,
          // so this can never tint anything.
          blendMode: BlendMode.dstIn,
          child: child,
        );
      },
    );
  }
}
