import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/selah_colors.dart';
import '../theme/selah_text.dart';
import 'selah_segmented_toggle.dart';

/// A continuous name strip within the app's fixed segmented capsule.
///
/// Three whole names fit at rest. More than three people form a continuous
/// circular strip, with the selected person centred and neighbours wrapping.
/// Header dragging is a preview: the owner changes pages only on release.
class SelahScrollableSeekerSelector extends StatefulWidget {
  const SelahScrollableSeekerSelector({
    super.key,
    required this.labels,
    required this.segmentKeys,
    required this.position,
    required this.onChanged,
    this.interactionRevision = 0,
  }) : assert(labels.length > 0),
       assert(labels.length == segmentKeys.length);

  final List<String> labels;
  final List<Key> segmentKeys;

  /// Logical page position. For >3 people it can continue across multiple
  /// laps; the owner maps the committed logical index back to the real roster.
  final double position;
  final ValueChanged<int> onChanged;

  /// Increment when an owner-side gesture takes over from header animation.
  final int interactionRevision;

  @override
  State<SelahScrollableSeekerSelector> createState() =>
      _SelahScrollableSeekerSelectorState();
}

class _SelahScrollableSeekerSelectorState
    extends State<SelahScrollableSeekerSelector>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion;
  bool _dragging = false;
  bool _settling = false;
  int _settleGeneration = 0;
  int? _target;

  bool get _loops => widget.labels.length > 3;

  double _bounded(double value) =>
      _loops ? value : value.clamp(0.0, (widget.labels.length - 1).toDouble());

  double get _position =>
      _bounded(_dragging || _settling ? _motion.value : widget.position);

  @override
  void initState() {
    super.initState();
    _motion = AnimationController.unbounded(
      vsync: this,
      value: _bounded(widget.position),
    )..addListener(_repaint);
  }

  void _repaint() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant SelahScrollableSeekerSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.segmentKeys, widget.segmentKeys) ||
        oldWidget.interactionRevision != widget.interactionRevision) {
      // A roster change must not leave a gesture selecting a removed person.
      _settleGeneration++;
      _motion.stop();
      _dragging = _settling = false;
      _target = null;
    } else if (!_dragging &&
        _settling &&
        !_motion.isAnimating &&
        (_bounded(widget.position) - (_target ?? _motion.value)).abs() < .001) {
      _settling = false;
    }
  }

  Future<void> _settle(int target, {required bool commit}) async {
    final from = _position;
    final generation = ++_settleGeneration;
    _motion.stop();
    setState(() {
      _dragging = false;
      _settling = true;
      _target = target;
      _motion.value = from;
    });
    if (commit) widget.onChanged(target);
    if (!mounted) return;
    try {
      if (MediaQuery.disableAnimationsOf(context)) {
        _motion.value = target.toDouble();
      } else {
        await _motion
            .animateTo(
              target.toDouble(),
              duration: SelahSegmentedMotion.selectionDuration,
              curve: SelahSegmentedMotion.selectionCurve,
            )
            .orCancel;
      }
    } on TickerCanceled {
      return;
    }
    if (!mounted || generation != _settleGeneration) return;
    // Hold the settled highlight until the body reaches the same page. Never
    // flash back to the body's old position for a frame during handover.
    if (!commit || (_bounded(widget.position) - target).abs() < .001) {
      setState(() => _settling = false);
    }
  }

  @override
  void dispose() {
    _settleGeneration++;
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final slots = math.min(3, widget.labels.length);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final position = _position;
    final window = _loops ? position - 1 : 0.0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: SelahColors.frostFill,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: SelahColors.frostBorder),
          ),
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth / slots;
                double left(double slot) => rtl
                    ? constraints.maxWidth - (slot + 1) * width
                    : slot * width;
                return Listener(
                  onPointerCancel: (_) {
                    // An accepted Flutter drag can report pointer cancellation
                    // as a zero-velocity end. Cancel before that end can commit.
                    if (_dragging) {
                      _settle(_bounded(widget.position).round(), commit: false);
                    }
                  },
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onHorizontalDragStart: (_) {
                      final from = _position;
                      _settleGeneration++;
                      _motion.stop();
                      setState(() {
                        _dragging = true;
                        _settling = false;
                        _motion.value = from;
                      });
                    },
                    onHorizontalDragUpdate: (details) {
                      if (!_dragging) return;
                      _motion.value = _bounded(
                        _motion.value +
                            (rtl ? 1 : -1) *
                                (details.primaryDelta ?? 0) /
                                width,
                      );
                    },
                    onHorizontalDragEnd: (details) {
                      if (!_dragging) return;
                      final velocity =
                          (rtl ? 1 : -1) *
                          (details.primaryVelocity ?? 0) /
                          width;
                      final projected = velocity.abs() > 4
                          ? _position + (velocity * .08).clamp(-.6, .6)
                          : _position;
                      _settle(_bounded(projected).round(), commit: true);
                    },
                    onHorizontalDragCancel: () {
                      if (_dragging) {
                        _settle(
                          _bounded(widget.position).round(),
                          commit: false,
                        );
                      }
                    },
                    child: SizedBox(
                      height: 34,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(17),
                        child: Stack(
                          children: [
                            Positioned(
                              left: left(position - window),
                              top: 0,
                              bottom: 0,
                              width: width,
                              child: DecoratedBox(
                                key: const ValueKey(
                                  'seeker-selector-highlight',
                                ),
                                decoration: BoxDecoration(
                                  color: SelahColors.isLightPalette
                                      ? SelahColors.devLightAccent.color
                                            .withValues(alpha: .14)
                                      : SelahColors.frostSelectedFill,
                                  borderRadius: BorderRadius.circular(17),
                                  border: Border.all(
                                    color: SelahColors.isLightPalette
                                        ? SelahColors.devLightAccent.color
                                              .withValues(alpha: .38)
                                        : SelahColors.frostSelectedBorder,
                                  ),
                                ),
                              ),
                            ),
                            for (
                              var index = window.floor();
                              index < (window + slots).ceil();
                              index++
                            )
                              Positioned(
                                left: left(index - window),
                                top: 0,
                                bottom: 0,
                                width: width,
                                child: _name(index, position, window, slots),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _name(int index, double position, double window, int slots) {
    final personIndex = index % widget.labels.length;
    final visible =
        (math.min(index + 1.0, window + slots) -
                math.max(index.toDouble(), window))
            .clamp(0.0, 1.0);
    final weight = (1 - (position - index).abs()).clamp(0.0, 1.0);
    return ExcludeSemantics(
      excluding: visible < .999,
      child: Semantics(
        label: widget.labels[personIndex],
        button: true,
        selected: position.round() == index,
        excludeSemantics: true,
        onTap: () => _settle(index, commit: true),
        child: GestureDetector(
          key: widget.segmentKeys[personIndex],
          behavior: HitTestBehavior.opaque,
          onTap: () => _settle(index, commit: true),
          child: Opacity(
            // Moving edge names fade away instead of leaving a hard-cut peek.
            opacity: visible * visible,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Center(
                child: Text(
                  widget.labels[personIndex],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SelahText.button(
                    size: slots > 2 ? 10.8 : 12.5,
                    color: SelahColors.ink(.45 + .55 * weight),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
