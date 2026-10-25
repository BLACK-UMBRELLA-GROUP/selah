import 'package:flutter/material.dart';

import '../dev/selah_journey_icon_selection.dart';
export '../dev/selah_journey_icon_selection.dart' show SelahJourneyIconDesign;

/// The Founder-selected Couple symbol is the canonical Journey icon.
/// The caller owns navigation size and tint. Historical explicit drawings are
/// paint-only references, not runtime account or developer choices.
class SelahJourneyIcon extends StatelessWidget {
  const SelahJourneyIcon({
    super.key,
    required this.color,
    this.size = 22,
    this.design,
  });

  final Color color;
  final double size;

  /// Historical explicit thumbnails are paint-only. Normal navigation omits
  /// this and always renders Couple, independent of account or preview role.
  final SelahJourneyIconDesign? design;

  @override
  Widget build(BuildContext context) =>
      _paint(design ?? SelahJourneyIconDesign.couple);

  Widget _paint(SelahJourneyIconDesign selected) => ExcludeSemantics(
    child: SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: SelahJourneyIconPainter(color: color, design: selected),
      ),
    ),
  );
}

@visibleForTesting
class SelahJourneyIconPainter extends CustomPainter {
  const SelahJourneyIconPainter({
    required this.color,
    this.design = SelahJourneyIconDesign.couple,
  });

  final Color color;
  final SelahJourneyIconDesign design;
  static const double viewBoxSize = 24;
  static const double strokeWidth = 1.8;
  static const double artworkExtent = 21;
  static final _artworks = <SelahJourneyIconDesign, _JourneyArtwork>{};

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }
    final artwork = _artworks.putIfAbsent(
      design,
      () => switch (design) {
        SelahJourneyIconDesign.current => _current(),
        SelahJourneyIconDesign.footsteps => _footsteps(),
        SelahJourneyIconDesign.sharedPath => _route(),
        SelahJourneyIconDesign.together => _handshake(),
        SelahJourneyIconDesign.linked => _links(),
        SelahJourneyIconDesign.lasting => _infinity(),
        SelahJourneyIconDesign.growing => _sprout(),
        SelahJourneyIconDesign.milestone => _flag(),
        SelahJourneyIconDesign.twoPaths => _fork(),
        SelahJourneyIconDesign.withIntention => _heartHands(),
        SelahJourneyIconDesign.couple => _couple(),
      },
    );
    // Fit the visible stroke/fill, not a nominal 24-unit box containing
    // uneven padding. Uniform scale retains each symbol's proportions.
    final bounds = artwork.bounds;
    final scale = artworkExtent / bounds.longestSide;
    canvas.save();
    canvas.scale(size.width / viewBoxSize, size.height / viewBoxSize);
    canvas.translate(viewBoxSize / 2, viewBoxSize / 2);
    canvas.scale(scale);
    canvas.translate(-bounds.center.dx, -bounds.center.dy);
    final outline = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      // Keep one line weight after fitting; narrow drawings do not become
      // heavier than the other choices just because they need more scaling.
      ..strokeWidth = strokeWidth / scale
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final path in artwork.outlines) {
      canvas.drawPath(path, outline);
    }
    if (artwork.fill case final fill?) {
      canvas.drawPath(fill, Paint()..color = color);
    }
    canvas.restore();
  }

  _JourneyArtwork _current() {
    // Retain the preceding default's path; only its optical fitting changes.
    final path = Path()
      ..moveTo(4.5, 20)
      ..cubicTo(4.5, 15, 12, 16, 12, 10.5)
      ..moveTo(19.5, 20)
      ..cubicTo(19.5, 15, 12, 16, 12, 10.5)
      ..moveTo(12, 10.5)
      ..lineTo(12, 4)
      ..moveTo(8.5, 7.5)
      ..lineTo(12, 4)
      ..lineTo(15.5, 7.5);
    return _JourneyArtwork([path]);
  }

  _JourneyArtwork _footsteps() {
    final path = Path()
      ..moveTo(6, 20)
      ..cubicTo(3.8, 20, 4.7, 13.7, 7.3, 12.4)
      ..cubicTo(9.1, 11.5, 10.1, 13.7, 9.2, 16.7)
      ..cubicTo(8.5, 19, 8, 20, 6, 20)
      ..close()
      ..moveTo(16.9, 14)
      ..cubicTo(14.7, 14, 13.9, 8.8, 15.7, 7.2)
      ..cubicTo(17.6, 5.6, 19.9, 6.7, 19.7, 9.2)
      ..cubicTo(19.6, 12.2, 19, 14, 16.9, 14)
      ..close();
    final toes = Path();
    for (final toe in [
      (const Offset(6.1, 10), 1.0),
      (const Offset(8.6, 9.2), .75),
      (const Offset(10.6, 10.8), .7),
      (const Offset(17.1, 3.3), 1.0),
      (const Offset(19.4, 3.9), .75),
      (const Offset(21, 5.7), .7),
    ]) {
      toes.addOval(Rect.fromCircle(center: toe.$1, radius: toe.$2));
    }
    return _JourneyArtwork([path], fill: toes);
  }

  _JourneyArtwork _route() => _JourneyArtwork([
    Path()..addOval(Rect.fromCircle(center: const Offset(6, 4), radius: 2)),
    Path()..addOval(Rect.fromCircle(center: const Offset(18, 20), radius: 2)),
    Path()
      ..moveTo(8, 4)
      ..lineTo(14, 4)
      ..cubicTo(20, 4, 20, 10, 14, 10)
      ..lineTo(10, 10)
      ..cubicTo(4, 10, 4, 16, 10, 16)
      ..lineTo(14, 16)
      ..cubicTo(17, 16, 18, 17, 18, 18),
  ]);

  _JourneyArtwork _handshake() => _JourneyArtwork([
    Path()
      ..moveTo(2.5, 10)
      ..lineTo(6, 6.5)
      ..lineTo(9, 8.5)
      ..lineTo(5.5, 12.3)
      ..close()
      ..moveTo(21.5, 10)
      ..lineTo(18, 6.5)
      ..lineTo(15, 8.5)
      ..lineTo(18.5, 12.3)
      ..close()
      ..moveTo(8, 9.5)
      ..lineTo(10.8, 8.6)
      ..lineTo(13.4, 8.6)
      ..lineTo(17.1, 12.5)
      ..cubicTo(18.1, 13.6, 16.7, 15, 15.6, 14)
      ..lineTo(12.7, 11.3)
      ..moveTo(15.6, 14)
      ..cubicTo(16.2, 15.5, 14.7, 16.4, 13.7, 15.4)
      ..lineTo(11.4, 13.3)
      ..moveTo(13.7, 15.4)
      ..cubicTo(14.1, 16.9, 12.5, 17.8, 11.5, 16.7)
      ..lineTo(8.6, 13.9)
      ..moveTo(11.5, 16.7)
      ..cubicTo(10.6, 18.6, 8.5, 16.8, 6.6, 14.6)
      ..lineTo(5.5, 12.3)
      ..moveTo(15, 8.5)
      ..lineTo(11.8, 7.5)
      ..lineTo(9.3, 10.1)
      ..cubicTo(8.4, 11.1, 9.6, 12.2, 10.6, 11.4)
      ..lineTo(12.7, 9.8),
  ]);

  _JourneyArtwork _links() => _JourneyArtwork([
    Path()
      ..moveTo(10.2, 6)
      ..cubicTo(7.5, 3.3, 3.2, 6.2, 5.6, 9.4)
      ..lineTo(8.4, 12.2)
      ..cubicTo(10.8, 14.6, 14.3, 11.3, 12.4, 9)
      ..moveTo(13.8, 18)
      ..cubicTo(16.5, 20.7, 20.8, 17.8, 18.4, 14.6)
      ..lineTo(15.6, 11.8)
      ..cubicTo(13.2, 9.4, 9.7, 12.7, 11.6, 15)
      ..moveTo(8.9, 15.1)
      ..lineTo(15.1, 8.9),
  ]);

  _JourneyArtwork _infinity() => _JourneyArtwork([
    Path()
      ..moveTo(12, 12)
      ..cubicTo(8, 6, 3, 7, 3, 12)
      ..cubicTo(3, 17, 8, 18, 12, 12)
      ..cubicTo(16, 6, 21, 7, 21, 12)
      ..cubicTo(21, 17, 16, 18, 12, 12),
  ]);

  _JourneyArtwork _sprout() => _JourneyArtwork([
    Path()
      ..moveTo(12, 21)
      ..lineTo(12, 10.8)
      ..cubicTo(10, 6, 6, 5, 3, 6)
      ..cubicTo(4, 11, 8, 13, 12, 10.8)
      ..cubicTo(13, 6, 16, 3, 21, 4)
      ..cubicTo(21, 9, 18, 12, 12, 10.8),
  ]);

  _JourneyArtwork _flag() => _JourneyArtwork([
    Path()
      ..moveTo(5, 21)
      ..lineTo(5, 3)
      ..moveTo(5, 4)
      ..cubicTo(9, 2, 13, 6, 19, 4)
      ..lineTo(19, 13)
      ..cubicTo(13, 15, 10, 10, 5, 12),
  ]);

  _JourneyArtwork _fork() => _JourneyArtwork([
    Path()
      ..moveTo(12, 18.4)
      ..lineTo(12, 15)
      ..cubicTo(12, 12, 6, 12, 6, 8)
      ..lineTo(6, 5.6)
      ..moveTo(12, 15)
      ..cubicTo(12, 12, 18, 12, 18, 8)
      ..lineTo(18, 5.6),
    for (final point in const [Offset(6, 4), Offset(18, 4), Offset(12, 20)])
      Path()..addOval(Rect.fromCircle(center: point, radius: 1.6)),
  ]);

  _JourneyArtwork _heartHands() => _JourneyArtwork([
    Path()
      ..moveTo(12, 10.5)
      ..cubicTo(6, 7.1, 5, 4.2, 7.8, 3.8)
      ..cubicTo(9.2, 3.6, 10.8, 4.7, 12, 6)
      ..cubicTo(13.2, 4.7, 14.8, 3.6, 16.2, 3.8)
      ..cubicTo(19, 4.2, 18, 7.1, 12, 10.5)
      ..moveTo(2.5, 17.4)
      ..lineTo(5.1, 13.3)
      ..lineTo(8.5, 15)
      ..lineTo(6, 19.5)
      ..close()
      ..moveTo(21.5, 17.4)
      ..lineTo(18.9, 13.3)
      ..lineTo(15.5, 15)
      ..lineTo(18, 19.5)
      ..close()
      ..moveTo(8.1, 15.7)
      ..lineTo(10.4, 14.6)
      ..lineTo(13.6, 14.6)
      ..lineTo(16.3, 17)
      ..cubicTo(17.1, 17.8, 16.2, 18.8, 15.3, 18.1)
      ..lineTo(13.6, 16.7)
      ..moveTo(15.3, 18.1)
      ..cubicTo(15.3, 19.7, 13.7, 19.8, 12.8, 18.9)
      ..lineTo(11.8, 18)
      ..moveTo(12.8, 18.9)
      ..cubicTo(12.4, 20.3, 10.7, 20.4, 9.8, 19.5)
      ..lineTo(7.8, 17.5),
  ]);

  _JourneyArtwork _couple() => _JourneyArtwork([
    Path()..addOval(Rect.fromCircle(center: const Offset(8, 6), radius: 2.5)),
    Path()..addOval(Rect.fromCircle(center: const Offset(17, 7), radius: 2.3)),
    Path()
      ..moveTo(3, 20)
      ..lineTo(3, 17)
      ..cubicTo(3, 11.8, 13, 11.8, 13, 17)
      ..lineTo(13, 20)
      ..moveTo(14.6, 12.8)
      ..cubicTo(18, 11.8, 21, 13.8, 21, 17)
      ..lineTo(21, 20),
  ]);

  @override
  bool shouldRepaint(covariant SelahJourneyIconPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.design != design;
}

/// Paint data also supplies the fit bounds, so future path edits cannot leave
/// a separate, stale sizing table. Separate outlines retain their draw order.
class _JourneyArtwork {
  _JourneyArtwork(this.outlines, {this.fill});

  final List<Path> outlines;
  final Path? fill;

  late final Rect bounds = _paintedBounds();

  Rect _paintedBounds() {
    var result = _visiblePathBounds(
      outlines.first,
    ).inflate(SelahJourneyIconPainter.strokeWidth / 2);
    for (final path in outlines.skip(1)) {
      result = result.expandToInclude(
        _visiblePathBounds(
          path,
        ).inflate(SelahJourneyIconPainter.strokeWidth / 2),
      );
    }
    if (fill case final path?) {
      result = result.expandToInclude(_visiblePathBounds(path));
    }
    return result;
  }

  // getBounds includes unused Bezier control-point space (most visibly in
  // Linked). Measure each drawn contour instead, at <=1/8 of a viewBox unit.
  // This paint-only geometry and its bounds are cached once per design, never
  // recomputed during the nav's animation or stored as a member preference.
  static Rect _visiblePathBounds(Path path) {
    Rect? result;
    for (final contour in path.computeMetrics()) {
      final samples = (contour.length * 8).ceil().clamp(1, 1024);
      for (var index = 0; index <= samples; index++) {
        final point = contour
            .getTangentForOffset(contour.length * index / samples)
            ?.position;
        if (point == null) continue;
        final bounds = Rect.fromLTWH(point.dx, point.dy, 0, 0);
        result = result == null ? bounds : result.expandToInclude(bounds);
      }
    }
    return result ?? path.getBounds();
  }
}
