import 'package:flutter/material.dart';

import '../theme/selah_colors.dart';

/// Selah's code-native Quiet Sanctuary signature.
///
/// The arched threshold, central cross and low horizon express a Christian
/// place of stillness without relying on a stock church illustration. It is
/// decorative, contains no interaction and remains legible without motion.
class SelahSanctuaryMark extends StatelessWidget {
  const SelahSanctuaryMark({super.key, this.size = 112});

  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Selah sanctuary mark',
    image: true,
    child: SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _SanctuaryMarkPainter(
          ink: SelahColors.sanctuaryInk,
          ivory: SelahColors.warmIvory,
          bronze: SelahColors.candleBronze,
          sage: SelahColors.sanctuarySage,
        ),
      ),
    ),
  );
}

/// A quiet, non-interactive field of light for welcome and opening canvases.
/// This replaces inherited floating-particle decoration on the live Selah
/// entry surfaces; the very low contrast deliberately keeps copy dominant.
class SelahSanctuaryBackdrop extends StatelessWidget {
  const SelahSanctuaryBackdrop({super.key});

  @override
  Widget build(BuildContext context) => const IgnorePointer(
    child: ExcludeSemantics(child: ColoredBox(color: SelahColors.mist)),
  );
}

class _SanctuaryMarkPainter extends CustomPainter {
  const _SanctuaryMarkPainter({
    required this.ink,
    required this.ivory,
    required this.bronze,
    required this.sage,
  });

  final Color ink;
  final Color ivory;
  final Color bronze;
  final Color sage;

  Path _arch(Size size, double inset, double top, double bottom) {
    final left = size.width * inset;
    final right = size.width * (1 - inset);
    final crown = size.height * top;
    final shoulder = size.height * (top + 0.25);
    final floor = size.height * bottom;
    return Path()
      ..moveTo(left, floor)
      ..lineTo(left, shoulder)
      ..cubicTo(left, crown, right, crown, right, shoulder)
      ..lineTo(right, floor);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    canvas.drawPath(
      _arch(size, 0.14, 0.08, 0.89),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.shortestSide * 0.018
        ..strokeCap = StrokeCap.round
        ..color = bronze.withValues(alpha: 0.86),
    );
    canvas.drawPath(
      _arch(size, 0.27, 0.21, 0.83),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.shortestSide * 0.009
        ..strokeCap = StrokeCap.round
        ..color = ivory.withValues(alpha: 0.42),
    );

    final cross = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.shortestSide * 0.025
      ..strokeCap = StrokeCap.round
      ..color = ivory.withValues(alpha: 0.94);
    canvas
      ..drawLine(
        Offset(size.width * 0.5, size.height * 0.31),
        Offset(size.width * 0.5, size.height * 0.64),
        cross,
      )
      ..drawLine(
        Offset(size.width * 0.39, size.height * 0.44),
        Offset(size.width * 0.61, size.height * 0.44),
        cross,
      )
      ..drawLine(
        Offset(size.width * 0.27, size.height * 0.89),
        Offset(size.width * 0.73, size.height * 0.89),
        Paint()
          ..strokeWidth = size.shortestSide * 0.012
          ..strokeCap = StrokeCap.round
          ..color = sage.withValues(alpha: 0.72),
      );
  }

  @override
  bool shouldRepaint(covariant _SanctuaryMarkPainter oldDelegate) =>
      ink != oldDelegate.ink ||
      ivory != oldDelegate.ivory ||
      bronze != oldDelegate.bronze ||
      sage != oldDelegate.sage;
}
