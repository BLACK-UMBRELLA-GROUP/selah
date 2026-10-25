// Protected, session-local motion comparisons for the four welcome-story
// pages. This never selects a production onboarding transition.
import 'package:flutter/material.dart';

import '../services/selah_account_state.dart';
import '../services/selah_developer_access.dart';
import '../theme/selah_colors.dart';

enum SelahOnboardingPageTransition {
  current('Current slide', Duration(milliseconds: 260), Curves.easeOutCubic),
  quietFade('Quiet fade', Duration(milliseconds: 280), Curves.easeInOut),
  softLift('Soft lift', Duration(milliseconds: 320), Curves.easeOutCubic),
  sideGlide('Side glide', Duration(milliseconds: 320), Curves.easeInOutCubic),
  focusZoom('Focus zoom', Duration(milliseconds: 340), Curves.easeOutCubic),
  cardTilt('Card tilt', Duration(milliseconds: 760), Curves.easeInOutSine);

  const SelahOnboardingPageTransition(this.label, this.duration, this.curve);

  final String label;
  final Duration duration;
  final Curve curve;
}

abstract final class SelahDevOnboardingTransition {
  static const _default = SelahOnboardingPageTransition.cardTilt;
  static final ValueNotifier<SelahOnboardingPageTransition> _selection =
      ValueNotifier(_default);
  static int _accountGeneration = SelahAccountState.generation;

  static Listenable get changes => _selection;

  static SelahOnboardingPageTransition get current =>
      _accountGeneration == SelahAccountState.generation
      ? _selection.value
      : _default;

  static bool select(SelahOnboardingPageTransition transition) {
    if (!SelahDeveloperAccess.canUseDeveloperTools) return false;
    final generation = SelahAccountState.generation;
    if (_accountGeneration != generation) {
      _accountGeneration = generation;
      _selection.value = _default;
    }
    _selection.value = transition;
    return true;
  }

  @visibleForTesting
  static void resetForTesting() {
    assert(() {
      _accountGeneration = SelahAccountState.generation;
      _selection.value = _default;
      return true;
    }());
  }
}

/// Applies the selected introduction-page style to the handoff from the
/// simulated provider screen into the first welcome line. The brand canvas
/// covers the previous route immediately, so provider labels never blend
/// with welcome text. The first line itself starts after this route settles.
class SelahOnboardingEntryTransition extends StatelessWidget {
  const SelahOnboardingEntryTransition({
    super.key,
    required this.transition,
    required this.animation,
    required this.child,
  });

  final SelahOnboardingPageTransition transition;
  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context)) {
      return child;
    }
    return DecoratedBox(
      key: ValueKey('dev_onboarding_entry_${transition.name}'),
      decoration: BoxDecoration(gradient: SelahColors.brandGradient),
      child: AnimatedBuilder(
        animation: animation,
        child: child,
        builder: (context, child) {
          final visible = transition.curve.transform(animation.value);
          final hidden = 1 - visible;
          final offset = switch (transition) {
            SelahOnboardingPageTransition.current => Offset(24 * hidden, 0),
            SelahOnboardingPageTransition.softLift => Offset(0, 16 * hidden),
            SelahOnboardingPageTransition.sideGlide => Offset(32 * hidden, 0),
            SelahOnboardingPageTransition.cardTilt => Offset(10 * hidden, 0),
            _ => Offset.zero,
          };
          final scale = switch (transition) {
            SelahOnboardingPageTransition.focusZoom => 1 - .045 * hidden,
            SelahOnboardingPageTransition.cardTilt => 1 - .025 * hidden,
            _ => 1.0,
          };
          final matrix = Matrix4.identity();
          if (transition == SelahOnboardingPageTransition.cardTilt) {
            matrix.setEntry(3, 2, .001);
            matrix.rotateY(-.08 * hidden);
          }
          matrix.scaleByDouble(scale, scale, 1, 1);
          return Opacity(
            key: const ValueKey('dev_onboarding_entry_opacity'),
            opacity: visible,
            child: Transform.translate(
              offset: offset,
              child: Transform(
                alignment: Alignment.center,
                transform: matrix,
                child: child,
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Cancels the pager's full-screen travel for the five alternative effects,
/// then paints a controlled transform driven by the same page position.
/// Card Tilt stages transparent story content in separate canvas regions;
/// the shared purple background stays fixed while text and artwork move.
/// Gestures and the bottom arrow reveal the same in-between frames; the
/// underlying PageView still owns one-page settling and focus.
class SelahOnboardingTransitionFrame extends StatelessWidget {
  const SelahOnboardingTransitionFrame({
    super.key,
    required this.controller,
    required this.pageIndex,
    required this.axis,
    required this.transition,
    required this.child,
    this.reverse = false,
  });

  final PageController controller;
  final int pageIndex;
  final Axis axis;
  final bool reverse;
  final SelahOnboardingPageTransition transition;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (transition == SelahOnboardingPageTransition.current ||
        MediaQuery.disableAnimationsOf(context)) {
      return child;
    }
    return LayoutBuilder(
      builder: (context, constraints) => AnimatedBuilder(
        animation: controller,
        child: child,
        builder: (context, child) {
          final currentPage = controller.hasClients
              ? controller.page ?? controller.initialPage.toDouble()
              : controller.initialPage.toDouble();
          final distance = (pageIndex - currentPage).clamp(-1.0, 1.0);
          // The story pages have text in nearly identical positions. An
          // ordinary cross-fade makes both headlines readable at once, so
          // these styles fade through the shared purple canvas instead.
          // Side glide separates the pages spatially and needs no fading.
          final visibility =
              transition == SelahOnboardingPageTransition.sideGlide
              ? 1.0
              : ((0.5 - distance.abs()) * 2).clamp(0.0, 1.0);
          final isActivePage = pageIndex == currentPage.round();
          final pageTravel = axis == Axis.vertical
              ? Offset(0, -distance * constraints.maxHeight)
              : Offset(distance * constraints.maxWidth * (reverse ? 1 : -1), 0);
          if (transition == SelahOnboardingPageTransition.cardTilt) {
            return _cardTiltFrame(
              distance: distance,
              pageTravel: pageTravel,
              viewport: constraints.biggest,
              isActivePage: isActivePage,
              child: child!,
            );
          }
          final offset = switch (transition) {
            SelahOnboardingPageTransition.softLift => Offset(0, distance * 100),
            SelahOnboardingPageTransition.sideGlide => Offset(
              distance * constraints.maxWidth * (reverse ? -1 : 1),
              0,
            ),
            _ => Offset.zero,
          };
          final scale = switch (transition) {
            SelahOnboardingPageTransition.focusZoom => 1 - distance.abs() * .22,
            _ => 1.0,
          };
          final matrix = Matrix4.identity()
            ..setEntry(3, 2, .001)
            ..scaleByDouble(scale, scale, 1, 1);
          return Transform.translate(
            offset: pageTravel + offset,
            child: IgnorePointer(
              ignoring: !isActivePage,
              child: ExcludeSemantics(
                excluding: !isActivePage,
                child: Opacity(
                  opacity: visibility,
                  child: Transform(
                    alignment: Alignment.center,
                    transform: matrix,
                    child: child,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _cardTiltFrame({
    required double distance,
    required Offset pageTravel,
    required Size viewport,
    required bool isActivePage,
    required Widget child,
  }) {
    final depth = distance.abs();
    final isVertical = axis == Axis.vertical;
    final travel =
        distance *
        (isVertical ? viewport.height : viewport.width) *
        .5 *
        (reverse && !isVertical ? -1 : 1);
    // A small vertical lift lets the artwork and copy travel as one page,
    // while the horizontal card tilt and fixed brand canvas remain intact.
    final separation = isVertical
        ? Offset(0, travel)
        : Offset(travel, distance * viewport.height * .18);
    // Each transparent story occupies its proportional part of the hand-off
    // stage, while the gradient behind the pager remains stationary.
    final scale = (1 - depth * 1.08).clamp(.02, 1.0);
    final surfaceVisibility = 1 - depth * depth;
    final contentVisibility = ((scale - .18) / .45).clamp(0.0, 1.0);
    final matrix = Matrix4.identity()..setEntry(3, 2, .0013);
    if (isVertical) {
      matrix.rotateX(distance * .75);
    } else {
      matrix.rotateY(distance * .75);
    }
    matrix.scaleByDouble(scale, scale, 1, 1);

    return Transform.translate(
      offset: pageTravel + separation,
      child: IgnorePointer(
        ignoring: !isActivePage,
        child: ExcludeSemantics(
          excluding: !isActivePage,
          child: Opacity(
            opacity: surfaceVisibility * contentVisibility,
            child: Transform(
              alignment: Alignment.center,
              transform: matrix,
              child: KeyedSubtree(
                key: ValueKey('onboarding-card-tilt-content-$pageIndex'),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
