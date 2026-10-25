import 'dart:ui';

/// The three intentional decisions available from the Browse photo deck.
enum SelahBrowseSwipeDecision { pass, save, consider }

/// The physical edge that must carry the live and commit-time cue.
enum SelahBrowseSwipeCueEdge { left, top, right }

/// The intent acquired during one continuous press-and-drag.
///
/// Once Browse recognises a horizontal or vertical gesture it keeps that axis
/// until the finger lifts. This prevents a small downward drift while a person
/// returns a horizontal swipe towards centre from flashing the Save cue.
enum SelahBrowseSwipeAxis { horizontal, vertical }

/// One authoritative translation from finger movement to a Browse decision.
///
/// Flutter reports a left-to-right drag with a positive [Offset.dx] and a
/// right-to-left drag with a negative one. Keeping that coordinate rule here
/// prevents the live preview, released action, fling and edge cue from drifting
/// into different meanings as the developer lab treatments evolve.
abstract final class SelahBrowseSwipePolicy {
  static const double previewActivation = 20;
  static const double commitThreshold = 120;

  static SelahBrowseSwipeAxis? previewAxis(Offset offset) {
    final horizontalDistance = offset.dx.abs();
    final downwardDistance = offset.dy;
    if (horizontalDistance <= previewActivation &&
        downwardDistance <= previewActivation) {
      return null;
    }
    return horizontalDistance > downwardDistance.abs()
        ? SelahBrowseSwipeAxis.horizontal
        : SelahBrowseSwipeAxis.vertical;
  }

  static SelahBrowseSwipeDecision? previewDecision(
    Offset offset, {
    SelahBrowseSwipeAxis? lockedAxis,
  }) => _decisionFor(
    offset,
    threshold: previewActivation,
    lockedAxis: lockedAxis,
  );

  static SelahBrowseSwipeDecision? committedDecision(
    Offset offset, {
    SelahBrowseSwipeAxis? lockedAxis,
  }) =>
      _decisionFor(offset, threshold: commitThreshold, lockedAxis: lockedAxis);

  static SelahBrowseSwipeDecision? _decisionFor(
    Offset offset, {
    required double threshold,
    SelahBrowseSwipeAxis? lockedAxis,
  }) {
    final axis =
        lockedAxis ??
        (offset.dx.abs() > offset.dy.abs()
            ? SelahBrowseSwipeAxis.horizontal
            : SelahBrowseSwipeAxis.vertical);
    if (axis == SelahBrowseSwipeAxis.horizontal) {
      // Finger/card moves left: negative/Consider.
      if (offset.dx < -threshold) return SelahBrowseSwipeDecision.consider;
      // Finger/card moves right: positive/Pass.
      if (offset.dx > threshold) return SelahBrowseSwipeDecision.pass;
      return null;
    }
    if (offset.dy > threshold) return SelahBrowseSwipeDecision.save;
    return null;
  }

  static Offset flingTarget(SelahBrowseSwipeDecision decision) =>
      switch (decision) {
        SelahBrowseSwipeDecision.pass => const Offset(600, 0),
        SelahBrowseSwipeDecision.save => const Offset(0, 900),
        SelahBrowseSwipeDecision.consider => const Offset(-600, 0),
      };

  static SelahBrowseSwipeCueEdge cueEdge(SelahBrowseSwipeDecision decision) =>
      switch (decision) {
        // The growing line counterbalances the moving card: Pass travels
        // right while its red line rises on the LEFT; Consider travels left
        // while its green line rises on the RIGHT.
        SelahBrowseSwipeDecision.pass => SelahBrowseSwipeCueEdge.left,
        // A downward drag reveals the Save cue from behind the card's top edge.
        SelahBrowseSwipeDecision.save => SelahBrowseSwipeCueEdge.top,
        SelahBrowseSwipeDecision.consider => SelahBrowseSwipeCueEdge.right,
      };
}
