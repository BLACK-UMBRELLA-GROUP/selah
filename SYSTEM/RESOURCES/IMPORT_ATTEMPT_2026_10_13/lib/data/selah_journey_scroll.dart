/// Pure scroll-settling maths for the Active Journey's vertical chapters.
///
/// The UI supplies one full viewport per completed ending and per current
/// arrival. When a drag ends between them, this returns the closest resting
/// boundary so two chapters are never left sharing the screen.
class SelahJourneyScroll {
  SelahJourneyScroll._();

  /// Stable page addresses inside the current stage shell. Keeping these
  /// derived from the completed-stage count prevents a nested action view
  /// from relying on `previousPage()`, whose destination depends on a
  /// partially settled controller position.
  static int arrivalPage(int completedStageCount) =>
      completedStageCount.clamp(0, 1 << 30);

  static int actionPage(int completedStageCount) =>
      arrivalPage(completedStageCount) + 1;

  static int decisionPage(int completedStageCount) =>
      actionPage(completedStageCount) + 1;

  static bool isActionPage({
    required int page,
    required int completedStageCount,
  }) => page == actionPage(completedStageCount);

  /// Which chapter the persistent Journey ribbon should name for a settled
  /// page. Completed pages map to their own history index; arrival, action and
  /// decision pages all map to the current chapter after that history.
  static int viewedStageIndex({
    required int page,
    required int completedStageCount,
  }) => page.clamp(0, completedStageCount);

  static double nearestBoundary({
    required double offset,
    required double pageExtent,
    required int headerPageCount,
  }) {
    if (pageExtent <= 0 || headerPageCount < 1) return 0;
    final maxOffset = pageExtent * headerPageCount;
    final safeOffset = offset.clamp(0.0, maxOffset).toDouble();
    final page = (safeOffset / pageExtent).round().clamp(0, headerPageCount);
    return page * pageExtent;
  }

  /// Settles one section in the direction of a deliberate drag, even when
  /// the finger did not travel half a screen. Tiny movements still return to
  /// the nearest resting point. This makes the Journey feel like chapters,
  /// rather than a long sheet that can stop between two pages.
  static double boundaryAfterDrag({
    required double offset,
    required double dragStartOffset,
    required double pageExtent,
    required int headerPageCount,
    double activationDistance = 36,
  }) {
    if (pageExtent <= 0 || headerPageCount < 1) return 0;
    final maxOffset = pageExtent * headerPageCount;
    final safeOffset = offset.clamp(0.0, maxOffset).toDouble();
    final safeStart = dragStartOffset.clamp(0.0, maxOffset).toDouble();
    final travelled = safeOffset - safeStart;
    if (travelled.abs() < activationDistance) {
      return nearestBoundary(
        offset: safeOffset,
        pageExtent: pageExtent,
        headerPageCount: headerPageCount,
      );
    }

    final startPage = (safeStart / pageExtent).round();
    final direction = travelled.isNegative ? -1 : 1;
    final targetPage = (startPage + direction).clamp(0, headerPageCount);
    return targetPage * pageExtent;
  }

  /// Accumulates a deliberate completion movement from any input device.
  /// [forwardDelta] is positive when the member moves forward through the
  /// Journey: `-PointerMoveEvent.delta.dy` for touch, and
  /// `PointerScrollEvent.scrollDelta.dy` for a wheel or trackpad.
  static double completionDistanceAfterInput({
    required double currentDistance,
    required double forwardDelta,
    double threshold = 22,
  }) {
    if (threshold <= 0) return 0;
    return (currentDistance + forwardDelta).clamp(0.0, threshold).toDouble();
  }

  /// Returns the next page when a deliberate forward swipe began on Journey
  /// history but the surrounding PageView did not settle forward itself.
  ///
  /// Tall action pages own their own scrollables and iOS can occasionally
  /// leave the shared vertical PageView with a cancelled gesture after the
  /// member returns to completed history. This is a safety net, not a second
  /// navigation system: it only acts on completed pages, only after a clear
  /// forward gesture, and never if the PageView already reached the target.
  static int? missedHistoryForwardTarget({
    required int startPage,
    required double currentPage,
    required int arrivalPage,
    required double forwardDistance,
    double activationDistance = 36,
  }) {
    if (startPage < 0 || startPage >= arrivalPage) return null;
    if (forwardDistance < activationDistance) return null;
    final target = (startPage + 1).clamp(0, arrivalPage);
    if (currentPage >= target - 0.01) return null;
    return target;
  }
}

/// Pure eligibility for Compatibility's one-time reveal moment.
///
/// The action page is deliberately preloaded to avoid a loader appearing
/// halfway through the stage gesture. Preloading must not consume the reveal
/// animation while that page is still off-screen, so visibility is an
/// explicit part of the rule.
class SelahCompatibilityRevealPolicy {
  SelahCompatibilityRevealPolicy._();

  static bool shouldAnimate({
    required bool isActionVisible,
    required bool mineRevealed,
    required bool theirsRevealed,
    required bool hasScore,
    required bool alreadyCelebrated,
  }) =>
      isActionVisible &&
      mineRevealed &&
      theirsRevealed &&
      hasScore &&
      !alreadyCelebrated;
}

/// Visual truth for the Greeting connection between the two portraits.
///
/// A moving dot means one greeting is still travelling. Once both Greetings are
/// confirmed the motion must stop, otherwise the completed state still reads
/// as pending.
enum SelahGreetingConnectionMotion { idle, outbound, inbound, settled }

class SelahGreetingConnectionPolicy {
  SelahGreetingConnectionPolicy._();

  static SelahGreetingConnectionMotion resolve({
    required bool mine,
    required bool theirs,
  }) {
    if (mine && theirs) return SelahGreetingConnectionMotion.settled;
    if (mine) return SelahGreetingConnectionMotion.outbound;
    if (theirs) return SelahGreetingConnectionMotion.inbound;
    return SelahGreetingConnectionMotion.idle;
  }
}
