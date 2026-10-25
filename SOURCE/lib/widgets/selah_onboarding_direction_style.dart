// Shared onboarding visual language. Ordinary onboarding uses the selected
// Luma direction; protected comparisons may explicitly override its appearance.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/selah_colors.dart';

/// The developer flow may override this scope; it is deliberately independent
/// of the preview-picker enum so normal onboarding never imports developer code.
class OnboardingPreviewStyle extends InheritedWidget {
  const OnboardingPreviewStyle({
    super.key,
    required this.directionName,
    required super.child,
  }) : assert(
         directionName == 'current' ||
             directionName == 'structured' ||
             directionName == 'luma' ||
             directionName == 'revolut' ||
             directionName == 'headspace' ||
             directionName == 'mozi' ||
             directionName == 'wise' ||
             directionName == 'uber' ||
             directionName == 'ahead' ||
             directionName == 'howWeFeel' ||
             directionName == 'atoms',
       );

  final String directionName;

  /// A preview-only lookup, retained for isolated design studies. Shared
  /// onboarding screens use [effectiveStyleOf] so they also receive Luma.
  static OnboardingPreviewStyle? maybeOf(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<OnboardingPreviewStyle>();
    return scope?.directionName == 'current' ? null : scope;
  }

  /// Founder-selected visual default for ordinary onboarding. This resolver
  /// changes presentation only: it grants no preview or developer authority.
  /// An explicit Current comparison still returns null and keeps its layout.
  static OnboardingPreviewStyle? effectiveStyleOf(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<OnboardingPreviewStyle>();
    if (scope != null) {
      return scope.directionName == 'current' ? null : scope;
    }
    return const OnboardingPreviewStyle(
      directionName: 'luma',
      child: SizedBox.shrink(),
    );
  }

  bool get centered => switch (directionName) {
    'luma' || 'headspace' || 'mozi' || 'ahead' || 'atoms' => true,
    _ => false,
  };

  bool get spacious => switch (directionName) {
    'headspace' || 'luma' || 'ahead' => true,
    _ => false,
  };

  double get titleSize => switch (directionName) {
    'revolut' || 'uber' || 'howWeFeel' => 31,
    'luma' || 'headspace' => 29,
    _ => 27,
  };

  double get cardRadiusValue => switch (directionName) {
    'uber' => 8,
    'wise' => 12,
    'structured' => 16,
    'atoms' => 20,
    'revolut' || 'howWeFeel' => 23,
    'ahead' => 27,
    'luma' || 'mozi' => 30,
    'headspace' => 34,
    _ => 16,
  };

  BorderRadius get cardRadius => BorderRadius.circular(cardRadiusValue);

  double get buttonRadius => switch (directionName) {
    'uber' => 9,
    'wise' || 'structured' => 16,
    'revolut' => 21,
    _ => 999,
  };

  double get cardVerticalPadding => switch (directionName) {
    'luma' || 'headspace' || 'mozi' => 21,
    'uber' || 'wise' => 15,
    _ => 17,
  };

  double get sectionGap => spacious ? 29 : 19;

  IconData get markerIcon => switch (directionName) {
    'structured' => Icons.view_timeline_outlined,
    'luma' => Icons.auto_awesome_rounded,
    'revolut' => Icons.layers_outlined,
    'headspace' => Icons.spa_outlined,
    'mozi' => Icons.people_outline_rounded,
    'wise' => Icons.alt_route_rounded,
    'uber' => Icons.shield_outlined,
    'ahead' => Icons.blur_circular_rounded,
    'howWeFeel' => Icons.grid_view_rounded,
    'atoms' => Icons.radio_button_checked_rounded,
    _ => Icons.auto_awesome_rounded,
  };

  /// Keep the Midnight Plum / gold palette. Composition, not a new brand
  /// colour, distinguishes each option.
  LinearGradient get backgroundGradient => SelahColors.brandGradient;

  BoxDecoration cardDecoration({bool selected = false}) {
    final isCrisp = directionName == 'wise' || directionName == 'uber';
    final isGlowing = directionName == 'luma' || directionName == 'ahead';
    return BoxDecoration(
      color: selected
          ? SelahColors.journeyGold.withValues(alpha: .14)
          : isCrisp
          // Frost fill is white-tinted: replacing its ~10% alpha with 65%
          // washed out Wise/Uber cards behind white labels. Use a dark-plum
          // overlay for their crisp, high-contrast treatment instead.
          ? SelahColors.luxuryDarkPurple.withValues(alpha: .55)
          : SelahColors.frostFill,
      border: Border.all(
        color: selected
            ? SelahColors.journeyGold.withValues(alpha: .68)
            : SelahColors.frostBorder,
        width: isCrisp ? 1 : .7,
      ),
      borderRadius: cardRadius,
      boxShadow: isGlowing
          ? [
              BoxShadow(
                color: SelahColors.journeyGold.withValues(alpha: .055),
                blurRadius: 24,
                spreadRadius: 1,
              ),
            ]
          : null,
    );
  }

  ButtonStyle get primaryButtonStyle => FilledButton.styleFrom(
    backgroundColor: SelahColors.journeyGold,
    foregroundColor: SelahColors.luxuryDarkPurple,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(buttonRadius),
    ),
    minimumSize: const Size.fromHeight(50),
  );

  @override
  bool updateShouldNotify(OnboardingPreviewStyle oldWidget) =>
      directionName != oldWidget.directionName;
}

/// One small, repeatable motif throughout a selected route. It stays purely
/// decorative: no borrowed artwork, labels, hit areas or user data.
class OnboardingPreviewAccent extends StatelessWidget {
  const OnboardingPreviewAccent({
    super.key,
    required this.style,
    this.size = 84,
    this.progress = .5,
  });

  final OnboardingPreviewStyle style;
  final double size;
  final double progress;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox.square(
      dimension: size,
      child: CustomPaint(
        key: ValueKey('onboarding-preview-accent-${style.directionName}'),
        painter: _OnboardingPreviewAccentPainter(
          style.directionName,
          progress.clamp(0.0, 1.0).toDouble(),
        ),
      ),
    ),
  );
}

/// Fractional progress belongs to a named section. Exact journey stages use
/// the step constructor; decorative cells must never imply a false page count.
class OnboardingPreviewProgress extends StatelessWidget {
  const OnboardingPreviewProgress({
    super.key,
    required this.style,
    required this.progress,
    this.semanticValue,
  }) : currentStep = null,
       totalSteps = null,
       assert(progress != null);

  const OnboardingPreviewProgress.steps({
    super.key,
    required this.style,
    required int currentStep,
    required int totalSteps,
  }) : progress = null,
       semanticValue = null,
       currentStep = currentStep,
       totalSteps = totalSteps,
       assert(currentStep > 0),
       assert(totalSteps > 0),
       assert(currentStep <= totalSteps);

  final OnboardingPreviewStyle style;
  final double? progress;
  final String? semanticValue;
  final int? currentStep;
  final int? totalSteps;

  @override
  Widget build(BuildContext context) {
    final step = currentStep;
    if (step != null) {
      return OnboardingStageProgress(
        key: ValueKey('onboarding-preview-progress-${style.directionName}'),
        currentStep: step,
        totalSteps: totalSteps!,
      );
    }
    final value = progress!.clamp(0.0, 1.0).toDouble();
    return Semantics(
      label: semanticValue ?? 'Progress in this section',
      value: '${(value * 100).round()}%',
      child: ExcludeSemantics(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(
            style.directionName == 'uber' ? 0 : 8,
          ),
          child: SizedBox(
            key: ValueKey('onboarding-preview-progress-${style.directionName}'),
            height: style.directionName == 'uber' ? 3 : 5,
            child: LinearProgressIndicator(
              value: value,
              backgroundColor: SelahColors.foreground.withValues(alpha: .14),
              valueColor: AlwaysStoppedAnimation<Color>(SelahColors.journeyGold),
            ),
          ),
        ),
      ),
    );
  }
}

/// A finite, numbered journey indicator shared by ordinary onboarding and
/// every visual direction. The active segment and completed segments are
/// distinct, while screen readers hear the exact stage position once.
class OnboardingStageProgress extends StatelessWidget {
  const OnboardingStageProgress({
    super.key,
    required this.currentStep,
    required this.totalSteps,
  }) : assert(currentStep > 0),
       assert(totalSteps > 0),
       assert(currentStep <= totalSteps);

  final int currentStep;
  final int totalSteps;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Sign-up journey stage',
    value: 'Stage $currentStep of $totalSteps',
    child: ExcludeSemantics(
      child: SizedBox(
        height: 7,
        child: Row(
          children: [
            for (var index = 0; index < totalSteps; index++) ...[
              if (index != 0) const SizedBox(width: 7),
              Expanded(
                child: AnimatedContainer(
                  key: ValueKey('onboarding-stage-progress-segment-$index'),
                  duration: const Duration(milliseconds: 220),
                  height: 5,
                  decoration: BoxDecoration(
                    color: index == currentStep - 1
                        ? SelahColors.journeyGold
                        : index < currentStep - 1
                        ? SelahColors.journeyGold.withValues(alpha: .65)
                        : SelahColors.foreground.withValues(alpha: .18),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

class _OnboardingPreviewAccentPainter extends CustomPainter {
  const _OnboardingPreviewAccentPainter(this.directionName, this.progress);

  final String directionName;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(size.width, size.height) / 100;
    canvas.save();
    canvas.translate(
      (size.width - 100 * scale) / 2,
      (size.height - 100 * scale) / 2,
    );
    canvas.scale(scale);
    final gold = SelahColors.journeyGold;
    final muted = gold.withValues(alpha: .25);
    final stroke = Paint()
      ..color = gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    final softStroke = Paint()
      ..color = muted
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    final fill = Paint()..color = gold.withValues(alpha: .16);
    switch (directionName) {
      case 'structured':
        canvas.drawLine(const Offset(21, 12), const Offset(21, 88), softStroke);
        for (var i = 0; i < 3; i++) {
          final y = 20.0 + i * 30;
          canvas.drawCircle(
            Offset(21, y),
            5,
            i == 0 ? (Paint()..color = gold) : softStroke,
          );
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(39, y - 8, 48, 16),
              const Radius.circular(5),
            ),
            fill,
          );
          canvas.drawLine(Offset(47, y), Offset(75 - i * 5, y), softStroke);
        }
      case 'luma':
        canvas.drawCircle(const Offset(50, 50), 38, softStroke);
        canvas.drawCircle(const Offset(50, 50), 27, fill);
        canvas.drawCircle(const Offset(50, 50), 11, Paint()..color = gold);
        for (var i = 0; i < 6; i++) {
          final a = i * math.pi / 3;
          canvas.drawCircle(
            Offset(50 + 43 * math.cos(a), 50 + 43 * math.sin(a)),
            2,
            Paint()..color = gold,
          );
        }
      case 'revolut':
        for (var i = 0; i < 3; i++) {
          final rect = Rect.fromLTWH(18 + i * 8, 20 + i * 15, 57, 43);
          canvas.drawRRect(
            RRect.fromRectAndRadius(rect, const Radius.circular(9)),
            i == 2 ? fill : softStroke,
          );
        }
        canvas.drawLine(const Offset(48, 63), const Offset(68, 63), stroke);
      case 'headspace':
        canvas.drawCircle(
          const Offset(58, 37),
          18,
          Paint()..color = gold.withValues(alpha: .78),
        );
        final hill = Path()
          ..moveTo(5, 76)
          ..quadraticBezierTo(32, 29, 64, 65)
          ..quadraticBezierTo(82, 79, 96, 55)
          ..lineTo(96, 93)
          ..lineTo(5, 93)
          ..close();
        canvas.drawPath(hill, fill);
        canvas.drawPath(hill, softStroke);
      case 'mozi':
        for (final x in [25.0, 50.0, 75.0]) {
          canvas.drawCircle(
            Offset(x, x == 50 ? 38 : 48),
            x == 50 ? 15 : 12,
            softStroke,
          );
          canvas.drawCircle(Offset(x, x == 50 ? 38 : 48), 5, fill);
        }
        canvas.drawArc(
          const Rect.fromLTWH(18, 42, 64, 48),
          0,
          math.pi,
          false,
          stroke,
        );
      case 'wise':
        final path = Path()
          ..moveTo(14, 74)
          ..cubicTo(40, 74, 30, 25, 55, 25)
          ..cubicTo(76, 25, 64, 73, 88, 51);
        canvas.drawPath(path, stroke);
        for (final at in [
          const Offset(14, 74),
          const Offset(55, 25),
          const Offset(88, 51),
        ]) {
          canvas.drawCircle(at, 6, Paint()..color = gold);
        }
      case 'uber':
        final shield = Path()
          ..moveTo(50, 9)
          ..lineTo(82, 22)
          ..lineTo(79, 57)
          ..quadraticBezierTo(72, 76, 50, 90)
          ..quadraticBezierTo(28, 76, 21, 57)
          ..lineTo(18, 22)
          ..close();
        canvas.drawPath(shield, fill);
        canvas.drawPath(shield, stroke);
        canvas.drawLine(const Offset(35, 50), const Offset(65, 50), stroke);
      case 'ahead':
        canvas.drawOval(const Rect.fromLTWH(8, 28, 84, 44), softStroke);
        canvas.save();
        canvas.translate(50, 50);
        canvas.rotate(-.63);
        canvas.translate(-50, -50);
        canvas.drawOval(const Rect.fromLTWH(8, 28, 84, 44), softStroke);
        canvas.restore();
        canvas.drawCircle(const Offset(50, 50), 18, fill);
        canvas.drawCircle(const Offset(50, 50), 5, Paint()..color = gold);
      case 'howWeFeel':
        for (var i = 0; i < 4; i++) {
          final rect = Rect.fromLTWH(
            14 + (i % 2) * 38,
            14 + (i ~/ 2) * 38,
            32,
            32,
          );
          canvas.drawRRect(
            RRect.fromRectAndRadius(rect, Radius.circular(i.isEven ? 16 : 6)),
            i == 0 ? (Paint()..color = gold.withValues(alpha: .4)) : fill,
          );
        }
      case 'atoms':
        for (var x = 12; x <= 88; x += 11) {
          for (var y = 12; y <= 88; y += 11) {
            canvas.drawCircle(
              Offset(x.toDouble(), y.toDouble()),
              .8,
              Paint()..color = muted,
            );
          }
        }
        canvas.drawArc(
          const Rect.fromLTWH(20, 20, 60, 60),
          -math.pi / 2,
          2 * math.pi * progress,
          false,
          stroke..strokeWidth = 8,
        );
        canvas.drawCircle(const Offset(50, 50), 8, fill);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_OnboardingPreviewAccentPainter oldDelegate) =>
      directionName != oldDelegate.directionName ||
      progress != oldDelegate.progress;
}
