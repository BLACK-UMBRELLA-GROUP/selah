import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// A finger-distance swipe for the protected, read-only onboarding intros.
///
/// The inner scroll view owns readable overflow. A swipe may change pages only
/// when it *starts* near the relevant edge, so one long drag cannot scroll
/// past unread content and then accidentally skip the next introduction.
/// Listening to raw pointers avoids device-dependent overscroll resistance.
class SelahOnboardingEdgeSwipe extends StatefulWidget {
  const SelahOnboardingEdgeSwipe({
    super.key,
    required this.controller,
    required this.onForward,
    required this.child,
    this.onBackward,
    this.enabled = true,
  });

  final ScrollController controller;
  final VoidCallback onForward;
  final VoidCallback? onBackward;
  final bool enabled;
  final Widget child;

  @override
  State<SelahOnboardingEdgeSwipe> createState() =>
      _SelahOnboardingEdgeSwipeState();
}

class _SelahOnboardingEdgeSwipeState extends State<SelahOnboardingEdgeSwipe> {
  // A very small edge tolerance protects unread content on compact screens.
  // Pages overflowing by less than one short line behave like fitted pages.
  static const double _edgeTolerance = 10;
  static const double _minorOverflow = 40;
  static const double _travelToAdvance = 56;

  int? _pointer;
  Offset? _origin;
  bool _canForward = false;
  bool _canBackward = false;
  bool _multiTouch = false;
  bool _handoffQueued = false;
  int _gestureGeneration = 0;

  void _clear() {
    _pointer = null;
    _origin = null;
    _canForward = false;
    _canBackward = false;
    _multiTouch = false;
    _handoffQueued = false;
    _gestureGeneration++;
  }

  void _onDown(PointerDownEvent event) {
    if (!widget.enabled || _handoffQueued) return;
    if (_pointer != null) {
      _multiTouch = true;
      return;
    }
    if (!widget.controller.hasClients ||
        !widget.controller.position.hasContentDimensions) {
      return;
    }
    final position = widget.controller.position;
    _pointer = event.pointer;
    _origin = event.position;
    _canForward =
        position.maxScrollExtent <= _minorOverflow ||
        position.extentAfter <= _edgeTolerance;
    _canBackward =
        widget.onBackward != null &&
        (position.maxScrollExtent <= _minorOverflow ||
            position.extentBefore <= _edgeTolerance);
  }

  void _onUp(PointerUpEvent event) {
    if (event.pointer != _pointer || _origin == null) return;
    final travel = event.position - _origin!;
    final forward =
        widget.enabled &&
        !_multiTouch &&
        _canForward &&
        travel.dy <= -_travelToAdvance &&
        travel.dy.abs() > travel.dx.abs();
    final backward =
        widget.enabled &&
        !_multiTouch &&
        _canBackward &&
        travel.dy >= _travelToAdvance &&
        travel.dy.abs() > travel.dx.abs();
    _clear();
    if (!forward && !backward) return;
    final controller = widget.controller;
    final generation = _gestureGeneration;
    _handoffQueued = true;
    // The Scrollable still owns pointer-up when this Listener is called.
    // Let it finish that event, then stop any outgoing fling/bounce before
    // starting the caller's existing page animation. One gesture, one motion.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || generation != _gestureGeneration) {
        return;
      }
      _handoffQueued = false;
      if (!widget.enabled ||
          controller != widget.controller ||
          !controller.hasClients ||
          !controller.position.hasContentDimensions) {
        return;
      }
      final position = controller.position;
      controller.jumpTo(
        position.pixels
            .clamp(position.minScrollExtent, position.maxScrollExtent)
            .toDouble(),
      );
      if (forward) {
        widget.onForward();
      } else {
        widget.onBackward?.call();
      }
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  @override
  void didUpdateWidget(covariant SelahOnboardingEdgeSwipe oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled != oldWidget.enabled ||
        widget.controller != oldWidget.controller) {
      _clear();
    }
  }

  @override
  void dispose() {
    _clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: _onDown,
    onPointerUp: _onUp,
    onPointerCancel: (_) => _clear(),
    child: widget.child,
  );
}

/// Right reveals the next welcome card, left returns to the previous card.
/// The caller decides whether the current card has been fully read; this
/// listener does not let Flutter's PageView fling past a reveal step.
class SelahOnboardingHorizontalSwipe extends StatefulWidget {
  const SelahOnboardingHorizontalSwipe({
    super.key,
    required this.child,
    this.onNext,
    this.onPrevious,
    this.onTap,
    this.onTapHint,
  });

  final Widget child;
  final VoidCallback? onNext;
  final VoidCallback? onPrevious;
  final VoidCallback? onTap;
  final String? onTapHint;

  @override
  State<SelahOnboardingHorizontalSwipe> createState() =>
      _SelahOnboardingHorizontalSwipeState();
}

class _SelahOnboardingHorizontalSwipeState
    extends State<SelahOnboardingHorizontalSwipe> {
  static const _travelToChangePage = 40.0;
  static const _minimumFlickTravel = 20.0;
  static const _flickVelocity = 600.0;
  int? _pointer;
  Offset? _origin;
  VelocityTracker? _velocityTracker;
  bool _multiTouch = false;

  void _clear() {
    _pointer = null;
    _origin = null;
    _velocityTracker = null;
    _multiTouch = false;
  }

  void _onDown(PointerDownEvent event) {
    if (_pointer != null) {
      _multiTouch = true;
      return;
    }
    _pointer = event.pointer;
    _origin = event.position;
    _velocityTracker = VelocityTracker.withKind(event.kind)
      ..addPosition(event.timeStamp, event.position);
  }

  void _onMove(PointerMoveEvent event) {
    if (event.pointer == _pointer) {
      _velocityTracker?.addPosition(event.timeStamp, event.position);
    }
  }

  void _onUp(PointerUpEvent event) {
    if (event.pointer != _pointer || _origin == null) return;
    _velocityTracker?.addPosition(event.timeStamp, event.position);
    final travel = event.position - _origin!;
    final velocity =
        _velocityTracker?.getVelocity().pixelsPerSecond ?? Offset.zero;
    final horizontal = travel.dx.abs() > travel.dy.abs();
    final flick =
        travel.dx.abs() >= _minimumFlickTravel &&
        velocity.dx.abs() >= _flickVelocity &&
        velocity.dx.abs() > velocity.dy.abs();
    final next =
        !_multiTouch &&
        ((horizontal && travel.dx >= _travelToChangePage) ||
            (flick && travel.dx > 0 && velocity.dx > 0));
    final previous =
        !_multiTouch &&
        ((horizontal && travel.dx <= -_travelToChangePage) ||
            (flick && travel.dx < 0 && velocity.dx < 0));
    _clear();
    if (next) {
      widget.onNext?.call();
    } else if (previous) {
      widget.onPrevious?.call();
    }
  }

  @override
  Widget build(BuildContext context) => Semantics(
    onTap: widget.onTap,
    onTapHint: widget.onTap == null ? null : widget.onTapHint,
    child: Listener(
      onPointerDown: _onDown,
      onPointerMove: _onMove,
      onPointerUp: _onUp,
      onPointerCancel: (_) => _clear(),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        excludeFromSemantics: true,
        onTap: widget.onTap,
        child: widget.child,
      ),
    ),
  );
}
