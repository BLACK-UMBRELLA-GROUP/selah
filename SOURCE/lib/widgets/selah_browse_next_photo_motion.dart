// Session-only presentation choices for an explicitly owned Next-profile
// change. This widget never retains the previous member or owns navigation.
import 'dart:math' as math;
import 'package:flutter/material.dart';

enum SelahBrowseNextMotion {
  current,
  cardGlide,
  cardRise,
  springPop,
  cardRock,
  fanTurn,
  hingeTurn,
  cardDeal,
  forwardFlip,
  arcEntrance,
  elasticCard;

  String get label => switch (this) {
    current => 'Current',
    cardGlide => '1 · Card glide',
    cardRise => '2 · Rise & settle',
    springPop => '3 · Spring pop',
    cardRock => '4 · Rocking card',
    fanTurn => '5 · Fan turn',
    hingeTurn => '6 · 3D hinge',
    cardDeal => '7 · Card deal',
    forwardFlip => '8 · Forward flip',
    arcEntrance => '9 · Arc entrance',
    elasticCard => '10 · Elastic card',
  };

  Duration get _duration => Duration(
    milliseconds: switch (this) {
      cardGlide => 680,
      cardRise || fanTurn || cardDeal => 720,
      springPop => 850,
      cardRock => 900,
      hingeTurn || forwardFlip => 800,
      arcEntrance => 880,
      elasticCard => 760,
      current => 0,
    },
  );
}

/// A whole-card entrance of the current child, never an outgoing member copy.
/// The caller increments [epoch] only for an actual Next-profile selection.
/// Changing only a person, epoch or preview choice cancels rather than animates.
class SelahBrowseNextPhotoMotion extends StatefulWidget {
  const SelahBrowseNextPhotoMotion({
    super.key,
    required this.child,
    required this.profileId,
    required this.epoch,
    this.style = SelahBrowseNextMotion.current,
  });

  final Widget child;
  final String profileId;
  final int epoch;
  final SelahBrowseNextMotion style;

  @override
  State<SelahBrowseNextPhotoMotion> createState() =>
      _SelahBrowseNextPhotoMotionState();
}

class _SelahBrowseNextPhotoMotionState extends State<SelahBrowseNextPhotoMotion>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: widget.style._duration,
    value: 1,
  );

  bool get _quiet =>
      MediaQuery.disableAnimationsOf(context) ||
      MediaQuery.accessibleNavigationOf(context);

  void _reset() {
    _entrance.stop();
    _entrance.value = 1;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_quiet) _reset();
  }

  @override
  void didUpdateWidget(covariant SelahBrowseNextPhotoMotion oldWidget) {
    super.didUpdateWidget(oldWidget);
    final choiceChanged = widget.style != oldWidget.style;
    final personChanged = widget.profileId != oldWidget.profileId;
    final epochChanged = widget.epoch != oldWidget.epoch;
    if (choiceChanged || personChanged || epochChanged) {
      _reset();
      if (!choiceChanged &&
          personChanged &&
          widget.epoch > oldWidget.epoch &&
          widget.epoch > 0 &&
          widget.style != SelahBrowseNextMotion.current &&
          !_quiet) {
        _entrance.duration = widget.style._duration;
        _entrance.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final viewport = MediaQuery.sizeOf(context);
      final width = math.max(
        1.0,
        constraints.maxWidth.isFinite ? constraints.maxWidth : viewport.width,
      );
      final height = math.max(
        1.0,
        constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : viewport.height,
      );
      return ClipRect(
        key: const ValueKey('browse_next_motion_clip'),
        child: AnimatedBuilder(
          animation: _entrance,
          child: KeyedSubtree(
            key: ValueKey(('browse-next-current-member', widget.profileId)),
            child: widget.child,
          ),
          builder: (context, child) {
            var matrix = Matrix4.identity();
            final t = _entrance.value;
            if (widget.style != SelahBrowseNextMotion.current &&
                !_quiet &&
                t < 1) {
              final eased = Curves.easeInOutCubic.transform(t);
              final remaining = 1 - eased;
              var scaleX = 1.0;
              var scaleY = 1.0;
              var x = 0.0;
              var y = 0.0;
              var angleX = 0.0;
              var angleY = 0.0;
              var angleZ = 0.0;
              switch (widget.style) {
                case SelahBrowseNextMotion.cardGlide:
                  x = width * .12 * remaining;
                  scaleX = scaleY = .78 + .22 * eased;
                case SelahBrowseNextMotion.cardRise:
                  y = height * .10 * remaining;
                  scaleX = scaleY = .80 + .20 * eased;
                case SelahBrowseNextMotion.springPop:
                  scaleX = scaleY = t < .32
                      ? _between(.64, .96, t / .32)
                      : t < .54
                      ? _between(.96, .87, (t - .32) / .22)
                      : _between(.87, 1, (t - .54) / .46);
                case SelahBrowseNextMotion.cardRock:
                  angleZ = .105 * math.cos(3 * math.pi * t) * (1 - t);
                  scaleX = scaleY = .82 + .18 * eased;
                case SelahBrowseNextMotion.fanTurn:
                  angleZ = -.20 * remaining;
                  y = height * .04 * remaining;
                  scaleX = scaleY = .74 + .26 * eased;
                case SelahBrowseNextMotion.hingeTurn:
                  angleY = .72 * remaining;
                  x = -width * .04 * remaining;
                  scaleX = scaleY = .88 + .12 * eased;
                case SelahBrowseNextMotion.cardDeal:
                  x = width * .09 * remaining;
                  y = -height * .10 * remaining;
                  angleZ = .13 * remaining;
                  scaleX = scaleY = .78 + .22 * eased;
                case SelahBrowseNextMotion.forwardFlip:
                  angleX = -.60 * remaining;
                  y = height * .025 * remaining;
                  scaleX = scaleY = .88 + .12 * eased;
                case SelahBrowseNextMotion.arcEntrance:
                  x = -width * .10 * (1 - t) * math.cos(1.5 * math.pi * t);
                  y = height * .05 * (1 - t) * math.sin(1.5 * math.pi * t);
                  angleZ = .045 * remaining * math.sin(2 * math.pi * t);
                  scaleX = scaleY = .80 + .20 * eased;
                case SelahBrowseNextMotion.elasticCard:
                  scaleX = .72 + .28 * eased;
                  scaleY = .95 - .09 * math.sin(math.pi * t) + .05 * eased;
                case SelahBrowseNextMotion.current:
                  break;
              }
              final base = Matrix4.identity();
              if (angleX != 0 || angleY != 0) {
                base.setEntry(3, 2, .85 / math.max(width, height));
              }
              if (angleX != 0) base.rotateX(angleX);
              if (angleY != 0) base.rotateY(angleY);
              if (angleZ != 0) base.rotateZ(angleZ);
              base.scaleByDouble(scaleX, scaleY, 1, 1);
              // Fit the projected *whole card* before applying screen-space
              // translation. Its own rounded clip moves with it; names, dots
              // and the invitation outline cannot hit a stationary mask.
              var extentX = .001;
              var extentY = .001;
              for (final corner in [
                Offset(-width / 2, -height / 2),
                Offset(width / 2, -height / 2),
                Offset(width / 2, height / 2),
                Offset(-width / 2, height / 2),
              ]) {
                final projected = MatrixUtils.transformPoint(base, corner);
                extentX = math.max(extentX, projected.dx.abs());
                extentY = math.max(extentY, projected.dy.abs());
              }
              final margin =
                  math.min(1.0, math.min(width, height) * .02) * remaining;
              final fit = math.min(
                1.0,
                math.min(
                  (width / 2 - x.abs() - margin) / extentX,
                  (height / 2 - y.abs() - margin) / extentY,
                ),
              );
              matrix = Matrix4.translationValues(x, y, 0)
                ..scaleByDouble(fit, fit, 1, 1)
                ..multiply(base);
            }
            // Keep this ancestry stable at rest and during a choice change:
            // photo-pager state is not remounted merely to add/remove an effect.
            return Transform(
              key: const ValueKey('browse_next_motion_transform'),
              transform: matrix,
              alignment: Alignment.center,
              transformHitTests: false,
              child: child,
            );
          },
        ),
      );
    },
  );
}

double _between(double start, double end, double t) =>
    start + (end - start) * Curves.easeOutCubic.transform(t.clamp(0.0, 1.0));
