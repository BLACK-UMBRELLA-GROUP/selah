// A presentation-only advance option for the isolated onboarding comparison.
// Validation, navigation and account writes remain with the existing caller.
import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/selah_colors.dart';

/// The current onboarding uses the gold arrow. A scoped comparison can still
/// choose a labelled Continue action. This is presentation, never authority.
class SelahOnboardingArrowScope extends InheritedWidget {
  const SelahOnboardingArrowScope({
    super.key,
    required this.enabled,
    required super.child,
  });

  final bool enabled;

  static bool enabledOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<SelahOnboardingArrowScope>()
          ?.enabled ??
      true;

  @override
  bool updateShouldNotify(SelahOnboardingArrowScope oldWidget) =>
      enabled != oldWidget.enabled;
}

/// A compact, accessible gold advance cue. Checkpoint pages may opt into a
/// gently repeating cue; ordinary actions keep their finite entrance pulse.
/// Reduced-motion users always get a stationary arrow.
/// The same `active` and callback gates used by the original Continue action
/// determine whether it can advance.
class SelahOnboardingArrowAction extends StatefulWidget {
  const SelahOnboardingArrowAction({
    super.key,
    required this.active,
    required this.onPressed,
    this.semanticLabel = 'Continue',
    this.repeatCue = false,
  });

  final bool active;
  final VoidCallback? onPressed;
  final String semanticLabel;
  final bool repeatCue;

  @override
  State<SelahOnboardingArrowAction> createState() =>
      _SelahOnboardingArrowActionState();
}

class _SelahOnboardingArrowActionState extends State<SelahOnboardingArrowAction>
    with SingleTickerProviderStateMixin {
  Timer? _repeatDelay;
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 760),
  );
  late final Animation<double> _travel = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(
        begin: 0.0,
        end: 1.0,
      ).chain(CurveTween(curve: Curves.easeOutCubic)),
      weight: 42,
    ),
    TweenSequenceItem(
      tween: Tween(
        begin: 1.0,
        end: 0.0,
      ).chain(CurveTween(curve: Curves.easeInOutCubic)),
      weight: 58,
    ),
  ]).animate(_pulse);

  bool get _canAdvance => widget.active && widget.onPressed != null;

  void _onPulseStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || !widget.repeatCue) return;
    _repeatDelay?.cancel();
    _repeatDelay = Timer(const Duration(milliseconds: 600), () {
      if (mounted &&
          _canAdvance &&
          !MediaQuery.disableAnimationsOf(context) &&
          !MediaQuery.accessibleNavigationOf(context)) {
        _pulse.forward(from: 0);
      }
    });
  }

  void _syncPulse() {
    _repeatDelay?.cancel();
    if (!_canAdvance ||
        MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context)) {
      _pulse.stop();
      _pulse.value = 0;
      return;
    }
    _pulse.forward(from: 0);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _pulse.removeStatusListener(_onPulseStatus);
    _pulse.addStatusListener(_onPulseStatus);
    _syncPulse();
  }

  @override
  void didUpdateWidget(covariant SelahOnboardingArrowAction oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active != oldWidget.active ||
        (widget.onPressed != null) != (oldWidget.onPressed != null) ||
        widget.repeatCue != oldWidget.repeatCue) {
      _syncPulse();
    }
  }

  @override
  void dispose() {
    _repeatDelay?.cancel();
    _pulse.removeStatusListener(_onPulseStatus);
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = _canAdvance;
    final gold = SelahColors.journeyGold;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.semanticLabel,
      onTap: enabled ? widget.onPressed : null,
      child: SizedBox.square(
        dimension: 52,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          onTap: enabled ? widget.onPressed : null,
          child: Center(
            child: AnimatedBuilder(
              animation: _travel,
              builder: (context, child) => Transform.translate(
                offset: Offset(0, -4 * _travel.value),
                child: child,
              ),
              child: ExcludeSemantics(
                child: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  key: const ValueKey('onboarding_animated_down_arrow'),
                  size: 34,
                  color: enabled ? gold : gold.withValues(alpha: 0.34),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
