// Caller-owned return navigation. This scope has no route, account, provider,
// persistence or Journey-stage authority; it only invokes the bound onBack.
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

/// A downward pull returns from a temporary page without an on-screen arrow.
///
/// Child scrollables keep their existing physics and gesture ownership. A
/// scroll-owned pull is eligible only when it begins at the physical top of
/// every enclosing vertical scrollable, including a Journey's stage PageView.
/// Header/blank-space pulls are handled by Flutter's vertical drag recognizer.
/// Supply a stable callback and a new [routeIdentity] whenever its owner changes.
class SelahPullDownBackScope extends StatefulWidget {
  const SelahPullDownBackScope({
    super.key,
    required this.child,
    required this.onBack,
    required this.routeIdentity,
    this.enabled = true,
  });

  final Widget child;
  final VoidCallback onBack;
  final Object routeIdentity;
  final bool enabled;

  @override
  State<SelahPullDownBackScope> createState() => _SelahPullDownBackScopeState();
}

enum _PullOwner { viewport, scrollable }

class _SelahPullDownBackScopeState extends State<SelahPullDownBackScope>
    with SingleTickerProviderStateMixin {
  static const _minimumFlingPull = 24.0;
  static const _commitVelocity = 650.0;
  static const _topTolerance = .5;
  static const _commitDuration = Duration(milliseconds: 420);
  static const _restDuration = Duration(milliseconds: 300);
  static const _commitCurve = Cubic(.22, .25, .30, 1);

  late final AnimationController _motion;
  Animation<double>? _animation;
  int _epoch = 0;
  int _motionEpoch = 0;
  ModalRoute<dynamic>? _modalRoute;
  bool _modalCurrent = true;
  final Set<int> _pointers = <int>{};
  int? _pointer;
  int? _gestureEpoch;
  Object? _gestureRoute;
  VoidCallback? _gestureBack;
  VelocityTracker? _velocity;
  Offset _origin = Offset.zero;
  Offset _travel = Offset.zero;
  bool? _downward;
  bool _cancelled = false;
  bool _released = false;
  bool _releaseReceipt = false;
  bool _finishQueued = false;
  bool _settling = false;
  bool _backTaken = false;
  _PullOwner? _owner;
  ScrollableState? _scrollOwner;
  final List<ScrollableState> _verticalAncestors = <ScrollableState>[];
  double _height = 0;
  double _offset = 0;
  double _pull = 0;
  double _releasePull = 0;
  double _releaseVelocity = 0;

  @override
  void initState() {
    super.initState();
    _motion = AnimationController(vsync: this)
      ..addListener(() {
        final animation = _animation;
        if (mounted && animation != null) {
          setState(() => _offset = animation.value);
        }
      });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    final current = route?.isCurrent ?? true;
    if (!identical(route, _modalRoute) || current != _modalCurrent) {
      _modalRoute = route;
      _modalCurrent = current;
      _invalidateBinding();
    }
  }

  void _invalidateBinding() {
    ++_epoch;
    ++_motionEpoch;
    _motion.stop(canceled: true);
    _animation = null;
    _offset = 0;
    _settling = false;
    _backTaken = false;
    _clearGesture();
    // Keep real down-pointer IDs until their actual up/cancel. An old finger
    // cannot start a fresh gesture after a route/callback ownership change.
  }

  @override
  void didUpdateWidget(covariant SelahPullDownBackScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.routeIdentity != widget.routeIdentity ||
        !identical(oldWidget.onBack, widget.onBack) ||
        oldWidget.enabled != widget.enabled) {
      _invalidateBinding();
    }
  }

  @override
  void dispose() {
    ++_epoch;
    ++_motionEpoch;
    _motion.dispose();
    super.dispose();
  }

  bool _validBinding(int epoch, Object route, VoidCallback back) =>
      mounted &&
      widget.enabled &&
      _modalCurrent &&
      (ModalRoute.of(context)?.isCurrent ?? true) &&
      epoch == _epoch &&
      route == widget.routeIdentity &&
      identical(back, widget.onBack) &&
      !_backTaken;

  bool get _validGesture =>
      _gestureEpoch != null &&
      _gestureRoute != null &&
      _gestureBack != null &&
      _validBinding(_gestureEpoch!, _gestureRoute!, _gestureBack!);

  void _clearGesture() {
    _pointer = null;
    _gestureEpoch = null;
    _gestureRoute = null;
    _gestureBack = null;
    _velocity = null;
    _owner = null;
    _scrollOwner = null;
    _verticalAncestors.clear();
    _downward = null;
    _travel = Offset.zero;
    _cancelled = false;
    _released = false;
    _releaseReceipt = false;
    _finishQueued = false;
    _pull = 0;
    _releasePull = 0;
    _releaseVelocity = 0;
  }

  void _pointerDown(PointerDownEvent event) {
    _pointers.add(event.pointer);
    if (_pointers.length > 1) {
      _cancel();
      return;
    }
    if (_settling) {
      _cancel();
      return;
    }
    if (!widget.enabled || _backTaken) return;
    _clearGesture();
    _pointer = event.pointer;
    _gestureEpoch = _epoch;
    _gestureRoute = widget.routeIdentity;
    _gestureBack = widget.onBack;
    _origin = event.position;
    _velocity = VelocityTracker.withKind(event.kind)
      ..addPosition(event.timeStamp, event.position);
  }

  void _pointerMove(PointerMoveEvent event) {
    if (!_validGesture || event.pointer != _pointer || _cancelled) return;
    _velocity?.addPosition(event.timeStamp, event.position);
    _travel = event.position - _origin;
    if (_downward == null && _travel.distance > kTouchSlop) {
      _downward = _travel.dy > 0 && _travel.dy.abs() > _travel.dx.abs() * 1.1;
      if (_downward != true) _cancel();
    }
  }

  void _pointerUp(PointerUpEvent event) {
    _pointers.remove(event.pointer);
    if (!_validGesture || event.pointer != _pointer || _cancelled) return;
    _velocity?.addPosition(event.timeStamp, event.position);
    _released = true;
    _releasePull = _pull;
    _releaseVelocity = _velocity?.getVelocity().pixelsPerSecond.dy ?? 0;
    // A raw release is not navigation. A child must also have acknowledged
    // its accepted scroll gesture ending (or beginning its release ballistic).
    _queueScrollFinish();
  }

  void _pointerCancel(PointerCancelEvent event) {
    _pointers.remove(event.pointer);
    if (event.pointer == _pointer) _cancel();
  }

  void _verticalStart(DragStartDetails details) {
    if (!_validGesture ||
        _cancelled ||
        _downward == false ||
        _owner == _PullOwner.scrollable) {
      return;
    }
    // A child's recognizer can observe the threshold-crossing move before the
    // outer Listener. Read the accepted start rather than requiring that
    // listener to have already latched the direction.
    final startTravel = details.globalPosition - _origin;
    if (startTravel.distance > kTouchSlop) {
      _downward =
          startTravel.dy > 0 && startTravel.dy.abs() > startTravel.dx.abs();
      if (_downward != true) {
        _cancel();
        return;
      }
    }
    _owner = _PullOwner.viewport;
  }

  void _verticalUpdate(DragUpdateDetails details) {
    if (!_validGesture || _cancelled || _owner != _PullOwner.viewport) return;
    setState(() {
      _pull = math.max(0, _pull + details.delta.dy);
      _offset = _visualPull(_pull);
    });
  }

  void _verticalEnd(DragEndDetails details) {
    if (!_validGesture ||
        _cancelled ||
        !_released ||
        _owner != _PullOwner.viewport) {
      return;
    }
    _releasePull = _pull;
    _releaseVelocity = details.primaryVelocity ?? _releaseVelocity;
    _finishPull();
  }

  void _verticalCancel() {
    // Losing the gesture arena to a child list is normal, not cancellation of
    // the accepted child-owned pull. Actual pointer cancellation revokes both.
    if (_owner == _PullOwner.viewport) _cancel();
  }

  bool _atTop(ScrollMetrics metrics) => switch (metrics.axisDirection) {
    AxisDirection.down =>
      metrics.pixels <= metrics.minScrollExtent + _topTolerance,
    AxisDirection.up =>
      metrics.pixels >= metrics.maxScrollExtent - _topTolerance,
    _ => false,
  };

  double _pastTop(ScrollMetrics metrics) => switch (metrics.axisDirection) {
    AxisDirection.down => math.max(0, metrics.minScrollExtent - metrics.pixels),
    AxisDirection.up => math.max(0, metrics.pixels - metrics.maxScrollExtent),
    _ => 0,
  };

  List<ScrollableState> _scrollChain(BuildContext notificationContext) {
    final states = <ScrollableState>[];
    BuildContext? cursor = notificationContext;
    while (cursor != null) {
      final state = Scrollable.maybeOf(cursor, axis: Axis.vertical);
      if (state == null || states.contains(state)) break;
      states.add(state);
      cursor = state.context;
    }
    return states;
  }

  bool _scrollNotification(ScrollNotification notification) {
    if (!_validGesture ||
        _cancelled ||
        notification.metrics.axis != Axis.vertical) {
      return false;
    }
    final notificationContext = notification.context;
    if (notificationContext == null) return false;
    final scrollable = Scrollable.maybeOf(
      notificationContext,
      axis: Axis.vertical,
    );
    if (notification is ScrollStartNotification &&
        notification.dragDetails != null) {
      if (_owner != null) return false;
      final chain = _scrollChain(notificationContext);
      if (chain.isEmpty || chain.any((state) => !_atTop(state.position))) {
        _cancel();
        return false;
      }
      _owner = _PullOwner.scrollable;
      _scrollOwner = scrollable;
      _verticalAncestors.addAll(chain);
    }
    if (_owner != _PullOwner.scrollable ||
        !identical(scrollable, _scrollOwner)) {
      return false;
    }
    if (_released &&
        (notification is ScrollEndNotification ||
            (notification is ScrollUpdateNotification &&
                notification.dragDetails == null))) {
      _releaseReceipt = true;
      _queueScrollFinish();
      return false;
    }
    if (_downward != true || _released || _settling) return false;
    if (notification is OverscrollNotification &&
        notification.dragDetails != null) {
      final pastStart = notification.metrics.axisDirection == AxisDirection.up
          ? notification.overscroll
          : -notification.overscroll;
      if (pastStart > 0) {
        setState(() {
          _pull += pastStart;
          _offset = _visualPull(_pull);
        });
      }
    } else if (notification is ScrollUpdateNotification &&
        notification.dragDetails != null) {
      final nativePull = _pastTop(notification.metrics);
      if (nativePull > 0) {
        _pull = math.max(0, _travel.dy - kTouchSlop);
        // Native bouncing already moves this content. Adding a viewport
        // translation here would double its displacement.
      } else if (!_atTop(notification.metrics)) {
        _cancel();
      }
    }
    return false;
  }

  void _queueScrollFinish() {
    if (!_validGesture ||
        _cancelled ||
        _settling ||
        !_released ||
        !_releaseReceipt ||
        _owner != _PullOwner.scrollable ||
        _finishQueued) {
      return;
    }
    _finishQueued = true;
    final epoch = _gestureEpoch;
    scheduleMicrotask(() {
      if (!_validGesture ||
          _gestureEpoch != epoch ||
          _cancelled ||
          _settling ||
          !_released ||
          !_releaseReceipt) {
        return;
      }
      _finishPull();
    });
  }

  void _finishPull() {
    if (!_validGesture || _cancelled || _settling || _downward != true) return;
    if (_height <= 0) {
      _cancel();
      return;
    }
    if (_verticalAncestors.any(
      (state) => !state.mounted || !_atTop(state.position),
    )) {
      _cancel();
      return;
    }
    final commit =
        _releasePull >= _height * .14 ||
        (_releasePull >= _minimumFlingPull &&
            _releaseVelocity >= _commitVelocity);
    unawaited(_settle(commit: commit));
  }

  void _cancel() {
    if (!_validGesture || _cancelled) return;
    _cancelled = true;
    if (_owner != null) {
      // A second touch/cancel can arrive after release while the commit is
      // already animating. Revoke that motion and return, never strand the
      // viewport at the dismissed target with no navigation callback.
      ++_motionEpoch;
      _motion.stop(canceled: true);
      _animation = null;
      _settling = false;
      unawaited(_settle(commit: false));
    }
  }

  double _visualPull(double pull) {
    // Only soften the scope's extra translation. Native bouncing scrollables
    // already follow the finger and must not receive a second displacement.
    // Keep raw distance/velocity for the existing commit decision, while a long
    // pull stays below the exit target instead of reversing when released.
    final capacity = _height * .30;
    if (capacity <= 0) return 0;
    return capacity * (1 - math.exp(-pull / capacity));
  }

  Future<void> _settle({required bool commit}) async {
    if (!_validGesture || _settling) return;
    final epoch = _gestureEpoch!;
    final route = _gestureRoute!;
    final back = _gestureBack!;
    final motion = ++_motionEpoch;
    _settling = true;
    // The child's first release-ballistic frame may begin this close motion;
    // do not make a deliberate return wait for a native spring to finish.
    // Its bounce continues untouched: this scope never changes child physics,
    // list offsets or stage-pager position, and added no translation while the
    // finger was pulling already-bouncing content.
    final target = commit ? _height : 0.0;
    final immediate =
        MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context);
    if (immediate) {
      setState(() => _offset = target);
      // Drain the current pointer dispatch so its cancellation can revoke a
      // proxied release even when no animation is requested.
      await Future<void>.value();
    } else {
      _motion.duration = commit ? _commitDuration : _restDuration;
      _animation = Tween<double>(begin: _offset, end: target)
          .chain(CurveTween(curve: commit ? _commitCurve : Curves.easeOutCubic))
          .animate(_motion);
      try {
        await _motion.forward(from: 0).orCancel;
      } on TickerCanceled {
        return;
      }
    }
    if (!_validBinding(epoch, route, back) ||
        motion != _motionEpoch ||
        (commit && _cancelled)) {
      return;
    }
    _animation = null;
    _settling = false;
    _clearGesture();
    if (commit) _takeBack(epoch, route, back);
  }

  void _takeBack(int epoch, Object route, VoidCallback back) {
    if (!_validBinding(epoch, route, back)) return;
    _backTaken = true;
    ++_motionEpoch;
    _motion.stop(canceled: true);
    _animation = null;
    back();
  }

  @override
  Widget build(BuildContext context) {
    final epoch = _epoch;
    final route = widget.routeIdentity;
    final back = widget.onBack;
    void accessibleBack() => _takeBack(epoch, route, back);
    // The caller's existing PopScope retains operating-system Back. Do not
    // introduce a Router-only listener or a competing Navigator pop handler.
    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.escape): DismissIntent(),
      },
      child: Actions(
        actions: {
          DismissIntent: CallbackAction<DismissIntent>(
            onInvoke: (_) {
              accessibleBack();
              return null;
            },
          ),
        },
        child: Semantics(
          key: const ValueKey('selah_pull_down_back_semantics'),
          container: true,
          explicitChildNodes: true,
          onDismiss: widget.enabled ? accessibleBack : null,
          customSemanticsActions: widget.enabled
              ? {CustomSemanticsAction(label: 'Back'): accessibleBack}
              : null,
          child: LayoutBuilder(
            builder: (context, constraints) {
              _height = constraints.hasBoundedHeight
                  ? constraints.maxHeight
                  : MediaQuery.sizeOf(context).height;
              return ClipRect(
                child: Listener(
                  key: const ValueKey('selah_pull_down_back_pointer'),
                  behavior: HitTestBehavior.translucent,
                  onPointerDown: _pointerDown,
                  onPointerMove: _pointerMove,
                  onPointerUp: _pointerUp,
                  onPointerCancel: _pointerCancel,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onVerticalDragStart: _verticalStart,
                    onVerticalDragUpdate: _verticalUpdate,
                    onVerticalDragEnd: _verticalEnd,
                    onVerticalDragCancel: _verticalCancel,
                    child: NotificationListener<ScrollNotification>(
                      onNotification: _scrollNotification,
                      child: Transform.translate(
                        key: const ValueKey('selah_pull_down_back_surface'),
                        offset: Offset(0, _offset),
                        child: widget.child,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
