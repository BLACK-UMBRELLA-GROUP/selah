// SELAH loading — Founder-approved "Meet and Pass" loop.
//
// Loading has different semantics from the one-shot splash because it may
// repeat for an unknown amount of time. These dots meet at speed, continue
// through one another, fade beyond the connection, and re-enter only after
// they are invisible. Nothing visibly reverses at the loop boundary.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/selah_colors.dart';

class SelahMeetAndPassRule extends StatelessWidget {
  final double width;
  final double progress;

  const SelahMeetAndPassRule({
    super.key,
    required this.width,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading',
      child: RepaintBoundary(
        child: ClipRect(
          child: SizedBox(
            key: const ValueKey('loading_meet_and_pass_rule'),
            width: width,
            height: 12,
            child: CustomPaint(
              painter: SelahMeetAndPassPainter(progress: progress),
            ),
          ),
        ),
      ),
    );
  }
}

@visibleForTesting
class SelahMeetAndPassFrame {
  final double start;
  final double end;
  final double leftDot;
  final double rightDot;
  final double dotOpacity;
  final double railOpacity;

  const SelahMeetAndPassFrame({
    required this.start,
    required this.end,
    required this.leftDot,
    required this.rightDot,
    required this.dotOpacity,
    required this.railOpacity,
  });

  factory SelahMeetAndPassFrame.at({
    required double width,
    required double progress,
  }) {
    final p = progress.clamp(0.0, 1.0);
    final start = width * 0.135;
    final end = width - start;
    final exit = width + 2;
    final sweep = exit - start;

    final fadeIn = (p / 0.15).clamp(0.0, 1.0);
    final fadeOut = p <= 0.62 ? 1.0 : (1 - (p - 0.62) / 0.26).clamp(0.0, 1.0);
    final dotOpacity = math.min(fadeIn, fadeOut);
    final breath = 0.5 - 0.5 * math.cos(2 * math.pi * p);

    return SelahMeetAndPassFrame(
      start: start,
      end: end,
      leftDot: start + sweep * p,
      rightDot: end - sweep * p,
      dotOpacity: dotOpacity,
      railOpacity: 0.12 + 0.36 * breath,
    );
  }
}

@visibleForTesting
class SelahMeetAndPassPainter extends CustomPainter {
  final double progress;

  const SelahMeetAndPassPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0) return;
    final frame = SelahMeetAndPassFrame.at(
      width: size.width,
      progress: progress,
    );
    final y = size.height / 2;
    final radius = (size.width * 0.0355).clamp(3.6, 4.5);

    final rail = Paint()
      ..color = SelahColors.journeyGold.withValues(alpha: frame.railOpacity)
      ..strokeWidth = 1.15
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(frame.start, y), Offset(frame.end, y), rail);

    if (frame.dotOpacity <= 0) return;
    final glow = Paint()
      ..color = SelahColors.journeyGold.withValues(
        alpha: frame.dotOpacity * 0.32,
      )
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    final dot = Paint()
      ..color = SelahColors.journeyGold.withValues(alpha: frame.dotOpacity);

    for (final x in [frame.leftDot, frame.rightDot]) {
      canvas.drawCircle(Offset(x, y), radius * 1.45, glow);
      canvas.drawCircle(Offset(x, y), radius, dot);
    }
  }

  @override
  bool shouldRepaint(covariant SelahMeetAndPassPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
