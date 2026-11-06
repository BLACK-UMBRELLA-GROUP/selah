// SELAH Still Water dock — LOCKs 1 and 2, 3 November 2026.
// Destination and action callbacks retain the existing shell ownership.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/selah_colors.dart';
import '../theme/selah_interaction_style.dart';
import '../theme/selah_text.dart';
import 'selah_journey_icon.dart';
import 'selah_keyboard_dismiss_scope.dart';

class SelahNavBarMetrics {
  SelahNavBarMetrics._();

  static const double sideInset = 0;
  static const double bottomInset = 26;
  // Top border + top padding + the 46px icon/label destination.
  static const double height = 55;
  static const double restingHeight = height;
  static const double radius = 0;
  static const double iconSize = 23;
}

class FloatingNavItem {
  final IconData icon;
  final String label;
  final bool useJourneyGlyph;
  final bool dimmed;
  final int badge;
  final bool dot;

  const FloatingNavItem({
    required this.icon,
    required this.label,
    this.useJourneyGlyph = false,
    this.badge = 0,
    this.dot = false,
    this.dimmed = false,
  });

  Widget buildIcon({required Color color, required double size}) =>
      useJourneyGlyph
      ? SelahJourneyIcon(color: color, size: size)
      : Icon(icon, color: color, size: size);
}

class FloatingNavBar extends StatefulWidget {
  final List<FloatingNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;
  // Kept for source compatibility. LOCK 1 displays every destination label.
  final bool showLabels;
  final SelahHapticLevel? hapticLevel;
  // Kept for callers reserving content space; the dock itself is full width.
  final double? contentEdgeInset;
  // Actions commit on release; ordinary destination scrubs remain live.
  final bool commitOnRelease;

  const FloatingNavBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
    this.showLabels = true,
    this.commitOnRelease = false,
    this.contentEdgeInset,
    this.hapticLevel,
  }) : assert(
         contentEdgeInset == null ||
             (contentEdgeInset >= 0 && contentEdgeInset < double.infinity),
       );

  @override
  State<FloatingNavBar> createState() => _FloatingNavBarState();
}

class _FloatingNavBarState extends State<FloatingNavBar> {
  double? _touchX;
  int? _lastIndex;
  int _semanticsEpoch = 0;

  @override
  void didUpdateWidget(covariant FloatingNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _semanticsEpoch++;
  }

  int _indexForX(double x, double width) => (x / (width / widget.items.length))
      .floor()
      .clamp(0, widget.items.length - 1);

  void _beginTouchAt(double x, double width) {
    dismissSelahKeyboardAfterNavigation();
    _lastIndex = widget.currentIndex;
    setState(() => _touchX = x.clamp(0, width));
  }

  void _handleTouchAt(double x, double width) {
    setState(() => _touchX = x.clamp(0, width));
    final index = _indexForX(x, width);
    final previous = _lastIndex ?? widget.currentIndex;
    _lastIndex = index;
    if (index != previous) {
      SelahInteractionStyle.emitSelectionHaptic(level: widget.hapticLevel);
      if (!widget.commitOnRelease) widget.onTap(index);
    }
  }

  void _endTouch({bool commit = false}) {
    final touching = _touchX != null;
    final index = _lastIndex;
    setState(() => _touchX = null);
    _lastIndex = null;
    if (widget.commitOnRelease && commit && touching && index != null) {
      widget.onTap(index);
    }
  }

  void _activateSemanticItem(int index, int epoch) {
    if (!mounted || epoch != _semanticsEpoch) return;
    if (index < 0 || index >= widget.items.length) return;
    final changed = index != widget.currentIndex;
    if (_touchX != null) setState(() => _touchX = null);
    _lastIndex = null;
    if (!changed && !widget.commitOnRelease) return;
    dismissSelahKeyboardAfterNavigation();
    if (changed) {
      SelahInteractionStyle.emitSelectionHaptic(level: widget.hapticLevel);
    }
    widget.onTap(index);
  }

  @override
  Widget build(BuildContext context) {
    final epoch = _semanticsEpoch;
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: _DockSurface(
        child: LayoutBuilder(
          builder: (context, bounds) {
            final width = bounds.maxWidth;
            final selectedIndex = _touchX == null
                ? widget.currentIndex
                : _indexForX(_touchX!, width);
            return Listener(
              onPointerCancel: (_) => _endTouch(),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                excludeFromSemantics: true,
                onTapDown: (event) =>
                    _beginTouchAt(event.localPosition.dx, width),
                onTapUp: (event) {
                  _handleTouchAt(event.localPosition.dx, width);
                  _endTouch(commit: true);
                },
                onTapCancel: _endTouch,
                onHorizontalDragStart: (event) =>
                    _handleTouchAt(event.localPosition.dx, width),
                onHorizontalDragUpdate: (event) =>
                    _handleTouchAt(event.localPosition.dx, width),
                onHorizontalDragEnd: (_) => _endTouch(commit: true),
                onHorizontalDragCancel: _endTouch,
                child: Row(
                  children: [
                    for (var i = 0; i < widget.items.length; i++)
                      Expanded(
                        child: Semantics(
                          key: ValueKey('floating-nav-item-$i'),
                          container: true,
                          button: true,
                          selected: i == widget.currentIndex,
                          label: widget.items[i].label,
                          value: widget.items[i].badge > 0
                              ? '${widget.items[i].badge} unread'
                              : widget.items[i].dot
                              ? 'New activity'
                              : null,
                          onTap: () => _activateSemanticItem(i, epoch),
                          excludeSemantics: true,
                          child: IgnorePointer(
                            child: _DockDestination(
                              item: widget.items[i],
                              selected: i == selectedIndex,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _DockSurface extends StatelessWidget {
  const _DockSurface({required this.child, this.showSurface = true});
  final Widget child;
  final bool showSurface;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: showSurface ? SelahColors.surface : Colors.transparent,
      border: showSurface
          ? Border(top: BorderSide(color: SelahColors.surfaceBorder))
          : null,
    ),
    padding: const EdgeInsets.fromLTRB(6, 8, 6, 26),
    child: child,
  );
}

class _DockDestination extends StatelessWidget {
  const _DockDestination({required this.item, required this.selected});
  final FloatingNavItem item;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? SelahColors.primaryAction
        : SelahColors.foregroundSecondary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox.square(
            dimension: SelahNavBarMetrics.iconSize,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                _DockIcon(item: item, color: color, selected: selected),
                if (item.badge > 0 || item.dot)
                  Positioned(
                    top: -5,
                    right: -7,
                    child: Container(
                      padding: item.badge > 0
                          ? const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 1,
                            )
                          : EdgeInsets.zero,
                      constraints: BoxConstraints(
                        minWidth: item.badge > 0 ? 15 : 7,
                        minHeight: item.badge > 0 ? 15 : 7,
                      ),
                      decoration: BoxDecoration(
                        color: SelahColors.primaryAction,
                        shape: BoxShape.circle,
                      ),
                      child: item.badge > 0
                          ? Text(
                              item.badge > 9 ? '9+' : '${item.badge}',
                              textAlign: TextAlign.center,
                              textScaler: TextScaler.noScaling,
                              style:
                                  SelahText.body(
                                    size: 9,
                                    color: SelahColors.onAction,
                                  ).copyWith(
                                    fontWeight: FontWeight.w600,
                                    height: 1.4,
                                  ),
                            )
                          : null,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            item.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: SelahText.body(
              size: 11,
              color: color,
            ).copyWith(fontWeight: FontWeight.w500, height: 1),
          ),
        ],
      ),
    );
  }
}

// The locked prototype's outline drawings, scaled from its 24px SVG viewBox.
class _DockIcon extends StatelessWidget {
  const _DockIcon({
    required this.item,
    required this.color,
    required this.selected,
  });
  final FloatingNavItem item;
  final Color color;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final name = item.label.toLowerCase();
    final drawing = switch (name) {
      'browse' => 'browse',
      'journey' => 'journey',
      'my selah' => 'my',
      'shepherd' => 'shepherd',
      'profile' => 'profile',
      'seekers' => 'people',
      _ => null,
    };
    if (drawing == null) {
      return item.buildIcon(color: color, size: SelahNavBarMetrics.iconSize);
    }
    return CustomPaint(
      size: const Size.square(SelahNavBarMetrics.iconSize),
      painter: _DockIconPainter(drawing, color, selected ? 2.2 : 1.7),
    );
  }
}

class _DockIconPainter extends CustomPainter {
  const _DockIconPainter(this.drawing, this.color, this.strokeWidth);
  final String drawing;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24, size.height / 24);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path();
    switch (drawing) {
      case 'browse':
        canvas.drawCircle(const Offset(11, 11), 6.5, paint);
        path.moveTo(20, 20);
        path.lineTo(16, 16);
      case 'journey':
        path.moveTo(4, 19);
        path.cubicTo(8, 19, 8, 13, 12, 13);
        path.cubicTo(16, 13, 16, 7, 20, 7);
        canvas.drawCircle(const Offset(4, 19), 1.6, paint);
        canvas.drawCircle(const Offset(20, 7), 1.6, paint);
      case 'my':
        path.addRect(const Rect.fromLTRB(4, 6, 20, 18));
        path.moveTo(4, 7);
        path.lineTo(12, 13);
        path.lineTo(20, 7);
      case 'shepherd':
        path.moveTo(9, 21);
        path.lineTo(9, 9);
        path.arcToPoint(
          const Offset(15, 9),
          radius: const Radius.circular(3),
          largeArc: true,
        );
        path.lineTo(15, 11);
        path.moveTo(6, 21);
        path.lineTo(18, 21);
      case 'profile':
        canvas.drawCircle(const Offset(12, 8.5), 3.8, paint);
        path.moveTo(4.5, 20);
        path.cubicTo(6, 16.4, 8.8, 14.8, 12, 14.8);
        path.cubicTo(15.2, 14.8, 18, 16.4, 19.5, 20);
      case 'people':
        canvas.drawCircle(const Offset(9, 9), 3.3, paint);
        canvas.drawCircle(const Offset(17, 8), 2.5, paint);
        path.moveTo(3, 19);
        path.cubicTo(4, 16, 6.3, 14.5, 9, 14.5);
        path.cubicTo(11.7, 14.5, 14, 16, 15, 19);
        path.moveTo(16, 14);
        path.cubicTo(18.2, 14, 20, 15.2, 21, 17.6);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _DockIconPainter oldDelegate) =>
      oldDelegate.drawing != drawing ||
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth;
}

class FloatingNavConfirmationBar extends StatelessWidget {
  final VoidCallback onCancel;
  final VoidCallback onConfirm;
  final bool showOuterSurface;
  final double? contentEdgeInset;
  final SelahHapticLevel? hapticLevel;

  const FloatingNavConfirmationBar({
    super.key,
    required this.onCancel,
    required this.onConfirm,
    this.showOuterSurface = true,
    this.contentEdgeInset,
    this.hapticLevel,
  }) : assert(
         contentEdgeInset == null ||
             (contentEdgeInset >= 0 && contentEdgeInset < double.infinity),
       );

  static double layoutHeight(
    BuildContext context, {
    required double viewportWidth,
    bool showOuterSurface = true,
    double? contentEdgeInset,
  }) {
    final width = math.max(1.0, (viewportWidth - 12 - 14) / 2 - 36 - 18 - 7);
    var labelHeight = 18.0;
    for (final label in ['Cancel', 'Hide profile']) {
      final painter = TextPainter(
        text: TextSpan(text: label, style: SelahText.button(size: 15)),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        locale: Localizations.maybeLocaleOf(context),
      )..layout(maxWidth: width);
      labelHeight = math.max(labelHeight, painter.height);
      painter.dispose();
    }
    return (showOuterSurface ? 1 : 0) + 8 + math.max(46, labelHeight + 30);
  }

  @override
  Widget build(BuildContext context) => Positioned(
    left: 0,
    right: 0,
    bottom: 0,
    child: _DockSurface(
      showSurface: showOuterSurface,
      child: SizedBox(
        height:
            layoutHeight(
              context,
              viewportWidth: MediaQuery.sizeOf(context).width,
              showOuterSurface: showOuterSurface,
              contentEdgeInset: contentEdgeInset,
            ) -
            8 -
            (showOuterSurface ? 1 : 0),
        child: Row(
          children: [
            Expanded(
              child: _ConfirmationButton(
                key: const ValueKey('browse-hide-cancel'),
                label: 'Cancel',
                icon: Icons.close_rounded,
                onTap: onCancel,
                hapticLevel: hapticLevel,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _ConfirmationButton(
                key: const ValueKey('browse-hide-confirm'),
                label: 'Hide profile',
                icon: Icons.visibility_off_outlined,
                destructive: true,
                onTap: onConfirm,
                hapticLevel: hapticLevel,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ConfirmationButton extends StatelessWidget {
  const _ConfirmationButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    required this.hapticLevel,
    this.destructive = false,
  });
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final SelahHapticLevel? hapticLevel;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive
        ? SelahColors.destructive
        : SelahColors.foreground;
    return Material(
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: destructive ? color : SelahColors.surfaceBorder,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          dismissSelahKeyboardAfterNavigation();
          SelahInteractionStyle.emitSelectionHaptic(level: hapticLevel);
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 18),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: SelahText.button(size: 15, color: color),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
