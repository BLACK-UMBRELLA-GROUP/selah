// Shared anchored "card" overlay — 2026-07-26 (Founder, Browse review:
// Bell and the 3-dot Help/Report menu should not push a new page or a
// bottom sheet; instead "a card to open or expand in the same screen
// which can be closed by clicking anywhere else on page but there").
// Used by both NotificationBell and HomeShell's Help/Report menu so the
// interaction reads identically everywhere a small icon-triggered menu
// appears, rather than each call site inventing its own positioning math.
//
// Mechanism: a full-screen transparent barrier (dismisses on any tap
// outside the card) plus a Positioned card anchored just below-and-right
// of the triggering icon, both inserted into the nearest Overlay. No
// route is pushed — the current screen never leaves the widget tree,
// matching "in the same screen" exactly. [anchorKey] must belong to the
// widget the card should appear under (its RenderBox is used purely for
// positioning).
//
// [cardBuilder] receives a `close` callback in addition to the overlay's
// own BuildContext — needed for rows inside the card that navigate
// elsewhere (Overlay entries float above pushed routes too, so a card
// that triggers navigation must close itself first or it would keep
// showing on top of the new screen). Rows that only act in place (e.g.
// marking a notification read) can ignore it and let the outside-tap
// barrier be the only way to dismiss.

import 'package:flutter/material.dart';

void showAnchoredCard({
  required BuildContext context,
  required GlobalKey anchorKey,
  required Widget Function(BuildContext context, VoidCallback close)
  cardBuilder,
  double cardWidth = 240,
}) {
  final overlayState = Overlay.of(context);
  final renderObject = anchorKey.currentContext?.findRenderObject();
  if (renderObject is! RenderBox) return;

  final anchorTopLeft = renderObject.localToGlobal(Offset.zero);
  final anchorSize = renderObject.size;
  final screenSize = MediaQuery.of(context).size;

  final top = anchorTopLeft.dy + anchorSize.height + 8;
  final left = (anchorTopLeft.dx + anchorSize.width - cardWidth).clamp(
    12.0,
    (screenSize.width - cardWidth - 12.0).clamp(12.0, double.infinity),
  );

  late final OverlayEntry entry;
  void close() {
    if (entry.mounted) entry.remove();
  }

  entry = OverlayEntry(
    builder: (ctx) => Stack(
      children: [
        // Tap-outside-to-dismiss barrier — sits above the current screen
        // but below the card itself, and is fully transparent so nothing
        // about the underlying page visually changes while the card is
        // open (no dimming), matching "closed by clicking anywhere else
        // on page but there" literally.
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: close,
            child: const SizedBox.shrink(),
          ),
        ),
        Positioned(
          top: top,
          left: left,
          width: cardWidth,
          child: cardBuilder(ctx, close),
        ),
      ],
    ),
  );

  overlayState.insert(entry);
}
