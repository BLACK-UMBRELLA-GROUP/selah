import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../dev/dev_menu_directions.dart';
import '../services/selah_account_state.dart';
import '../theme/selah_colors.dart';
import '../theme/selah_interaction_style.dart';
import '../theme/selah_text.dart';
import 'floating_nav_bar.dart';
import 'selah_journey_icon.dart';
import 'selah_keyboard_dismiss_scope.dart';

/// Reserve real canvas space for the left rail, not a layer over page text.
/// All other layouts retain the shell's existing content and tab lifecycle.
class SelahMenuCanvas extends StatelessWidget {
  const SelahMenuCanvas({super.key, required this.child, this.enabled = true});
  final Widget child;
  final bool enabled;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: SelahDevMenuDesign.instance,
    child: child,
    builder: (context, child) => Padding(
      padding: EdgeInsets.only(
        left:
            enabled &&
                SelahDevMenuDesign.instance.effectiveDesign ==
                    SelahMenuDesign.rectangular
            ? 76 + MediaQuery.paddingOf(context).left
            : 0,
      ),
      child: child,
    ),
  );
}

/// Structural comparisons share the exact shell-owned destinations/callback.
/// Browse safety actions still use the canonical current bar, never a chooser.
class SelahShellNavigation extends StatefulWidget {
  const SelahShellNavigation({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
    this.forceCurrent = false,
    this.commitOnRelease = false,
    this.contentEdgeInset,
    this.hapticLevel,
  }) : assert(
         contentEdgeInset == null ||
             (contentEdgeInset >= 0 && contentEdgeInset < double.infinity),
       );

  final List<FloatingNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final bool forceCurrent;
  final bool commitOnRelease;

  /// Applied only to the current floating bar; comparison menus keep their
  /// original geometry. Null preserves existing callers unchanged.
  final double? contentEdgeInset;

  /// Explicit local feedback choice. Null preserves member preferences.
  final SelahHapticLevel? hapticLevel;

  @override
  State<SelahShellNavigation> createState() => _SelahShellNavigationState();
}

class _SelahShellNavigationState extends State<SelahShellNavigation> {
  final _selection = SelahDevMenuDesign.instance;
  DialogRoute<int>? _menuRoute;
  bool _changeScheduled = false;

  @override
  void initState() {
    super.initState();
    _selection.addListener(_changed);
  }

  void _changed() {
    // Fresh authorization can reset menu selection while another route builds.
    // Permission/revision checks already deny stale actions synchronously;
    // defer sibling Navigator removal and visual refresh to a safe frame.
    if (WidgetsBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      if (_changeScheduled || !mounted) return;
      _changeScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _changeScheduled = false;
        if (!mounted) return;
        _dismissOwnedMenu();
        setState(() {});
      });
      WidgetsBinding.instance.scheduleFrame();
      return;
    }
    _dismissOwnedMenu();
    if (mounted) setState(() {});
  }

  void _dismissOwnedMenu() {
    final route = _menuRoute;
    _menuRoute = null;
    if (route?.navigator != null) route!.navigator!.removeRoute(route);
  }

  @override
  void didUpdateWidget(covariant SelahShellNavigation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.forceCurrent != oldWidget.forceCurrent ||
        widget.currentIndex != oldWidget.currentIndex ||
        widget.items.length != oldWidget.items.length) {
      _dismissOwnedMenu();
    }
  }

  @override
  void dispose() {
    _selection.removeListener(_changed);
    _dismissOwnedMenu();
    super.dispose();
  }

  Future<void> _openMenu(SelahMenuDesign design) async {
    if (_menuRoute != null || widget.forceCurrent) return;
    final generation = SelahAccountState.generation;
    final revision = _selection.revision;
    if (!_selection.isCurrent(generation, revision) ||
        _selection.effectiveDesign != design) {
      return;
    }
    dismissSelahKeyboard();
    final reduce =
        MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context);
    late final DialogRoute<int> route;
    route = DialogRoute<int>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: .32),
      barrierLabel: 'Close navigation menu',
      builder: (context) => _MenuPanel(
        design: design,
        items: List.of(widget.items),
        currentIndex: widget.currentIndex,
        onSelect: (index) {
          if (route.isCurrent && route.navigator != null) {
            route.navigator!.pop(index);
          }
        },
        onClose: () {
          if (route.isCurrent && route.navigator != null) {
            route.navigator!.pop();
          }
        },
      ),
      animationStyle: reduce
          ? AnimationStyle.noAnimation
          : const AnimationStyle(
              duration: Duration(milliseconds: 260),
              reverseDuration: Duration(milliseconds: 200),
            ),
    );
    _menuRoute = route;
    setState(() {});
    final index = await Navigator.of(context).push(route);
    // Finish the dismissal before the shell changes its visible destination.
    await route.completed;
    if (_menuRoute == route) {
      _menuRoute = null;
      if (mounted) setState(() {});
    }
    if (!mounted ||
        index == null ||
        widget.forceCurrent ||
        !_selection.isCurrent(generation, revision) ||
        _selection.effectiveDesign != design ||
        index < 0 ||
        index >= widget.items.length ||
        !(ModalRoute.of(context)?.isCurrent ?? true)) {
      return;
    }
    _select(index);
  }

  void _select(int index) {
    if (index != widget.currentIndex) {
      unawaited(
        SelahInteractionStyle.emitSelectionHaptic(level: widget.hapticLevel),
      );
    }
    widget.onTap(index);
  }

  @override
  Widget build(BuildContext context) {
    final design = widget.forceCurrent
        ? SelahMenuDesign.current
        : _selection.effectiveDesign;
    if (design == SelahMenuDesign.current) {
      if (widget.forceCurrent && SelahColors.isWafaPreview) {
        return Positioned(
          left: widget.contentEdgeInset ?? 20,
          right: widget.contentEdgeInset ?? 20,
          bottom: 0,
          child: SafeArea(
            top: false,
            minimum: const EdgeInsets.only(bottom: 14),
            child: Material(
              key: const ValueKey('option2_navigation'),
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: SelahColors.wafaLine),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                child: Row(
                  children: [
                    for (var i = 0; i < widget.items.length; i++)
                      Expanded(
                        child: Semantics(
                          selected: i == widget.currentIndex,
                          button: true,
                          label: widget.items[i].label,
                          excludeSemantics: true,
                          child: InkWell(
                            key: ValueKey('option2_navigation_$i'),
                            onTap: () => _select(i),
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              constraints: const BoxConstraints(minHeight: 48),
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              decoration: BoxDecoration(
                                color: i == widget.currentIndex
                                    ? SelahColors.wafaMint
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      if (widget.items[i].useJourneyGlyph)
                                        SelahJourneyIcon(
                                          size: SelahNavBarMetrics.iconSize,
                                          color: SelahColors.wafaGreen,
                                        )
                                      else
                                        Icon(
                                          widget.items[i].icon,
                                          size: SelahNavBarMetrics.iconSize,
                                          color: i == widget.currentIndex
                                              ? SelahColors.wafaGreen
                                              : SelahColors.wafaMuted,
                                        ),
                                      if (widget.items[i].dot || widget.items[i].badge > 0)
                                        const Positioned(
                                          top: -2,
                                          right: -3,
                                          child: DecoratedBox(
                                            decoration: BoxDecoration(
                                              color: SelahColors.wafaGreen,
                                              shape: BoxShape.circle,
                                            ),
                                            child: SizedBox.square(dimension: 5),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    widget.items[i].label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: SelahText.button(
                                      size: 11,
                                      color: i == widget.currentIndex
                                          ? SelahColors.wafaGreen
                                          : SelahColors.wafaMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      }
      return FloatingNavBar(
        items: widget.items,
        currentIndex: widget.currentIndex,
        onTap: widget.onTap,
        commitOnRelease: widget.commitOnRelease,
        contentEdgeInset: widget.contentEdgeInset,
        hapticLevel: widget.hapticLevel,
      );
    }
    if (design.opensMenu && _menuRoute != null) {
      return const SizedBox.shrink();
    }
    if (design == SelahMenuDesign.rectangular) {
      return Positioned(
        left: 8,
        top: 12,
        bottom: 12,
        child: SafeArea(
          right: false,
          child: Center(
            child: _MenuSurface(
              radius: 18,
              child: SizedBox(
                width: 60,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < widget.items.length; i++)
                        _destination(i, iconOnly: true),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }
    if (design == SelahMenuDesign.tabBar || design == SelahMenuDesign.rudder) {
      final hub = widget.items.indexWhere(
        (item) => item.icon == Icons.dashboard_outlined,
      );
      final other = [
        for (var i = 0; i < widget.items.length; i++)
          if (i != hub) i,
      ];
      return Positioned(
        left: 16,
        right: 16,
        bottom: 0,
        child: SafeArea(
          top: false,
          minimum: const EdgeInsets.only(bottom: 14),
          child: _MenuSurface(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                2,
                design == SelahMenuDesign.rudder ? 20 : 6,
                2,
                6,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: design == SelahMenuDesign.tabBar || hub < 0
                    ? [
                        for (var i = 0; i < widget.items.length; i++)
                          Expanded(child: _destination(i, compact: true)),
                      ]
                    : [
                        for (final i in other.take(2))
                          Expanded(child: _destination(i, compact: true)),
                        Expanded(
                          child: Transform.translate(
                            offset: const Offset(0, -12),
                            child: _destination(
                              hub,
                              compact: true,
                              raised: true,
                            ),
                          ),
                        ),
                        for (final i in other.skip(2))
                          Expanded(child: _destination(i, compact: true)),
                        if (other.length == 3)
                          const Expanded(child: SizedBox()),
                      ],
              ),
            ),
          ),
        ),
      );
    }
    return Positioned(
      left: design == SelahMenuDesign.fab || design == SelahMenuDesign.threeDots
          ? null
          : 20,
      right: design == SelahMenuDesign.fab || design == SelahMenuDesign.threeDots
          ? 20
          : null,
      bottom: 0,
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 14),
        child: Semantics(
          button: true,
          label: 'Open ${design.label} navigation',
          child: _MenuSurface(
            radius: design == SelahMenuDesign.fab ? 32 : 20,
            gold: design == SelahMenuDesign.fab,
            child: InkWell(
              key: const ValueKey('menu-open'),
              borderRadius: BorderRadius.circular(32),
              onTap: () => _openMenu(design),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      design.icon,
                      size: 24,
                      color: design == SelahMenuDesign.fab
                          ? SelahColors.onAction
                          : SelahColors.journeyGold,
                    ),
                    if (design != SelahMenuDesign.fab &&
                        design != SelahMenuDesign.threeDots) ...[
                      const SizedBox(width: 9),
                      Text('Menu', style: SelahText.body(size: 14)),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _destination(
    int index, {
    bool iconOnly = false,
    bool compact = false,
    bool raised = false,
  }) {
    final generation = SelahAccountState.generation;
    final revision = _selection.revision;
    return _MenuDestination(
      index: index,
      item: widget.items[index],
      selected: index == widget.currentIndex,
      onTap: () {
        if (_selection.isCurrent(generation, revision)) _select(index);
      },
      iconOnly: iconOnly,
      compact: compact,
      raised: raised,
    );
  }
}

class _MenuSurface extends StatelessWidget {
  const _MenuSurface({
    required this.child,
    this.radius = 24,
    this.gold = false,
  });
  final Widget child;
  final double radius;
  final bool gold;
  @override
  Widget build(BuildContext context) => Material(
    color: gold ? SelahColors.journeyGold : SelahColors.modalSheetSurface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: BorderSide(color: SelahColors.journeyGold.withValues(alpha: .3)),
    ),
    clipBehavior: Clip.antiAlias,
    child: child,
  );
}

class _MenuDestination extends StatelessWidget {
  const _MenuDestination({
    required this.index,
    required this.item,
    required this.selected,
    required this.onTap,
    this.iconOnly = false,
    this.compact = false,
    this.raised = false,
    this.tile = false,
  });
  final int index;
  final FloatingNavItem item;
  final bool selected, iconOnly, compact, raised, tile;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = raised
        ? SelahColors.onAction
        : selected
        ? SelahColors.journeyGold
        : SelahColors.foreground;
    final indicator = item.badge > 0
        ? '${item.badge} unread'
        : item.dot
        ? 'New activity'
        : null;
    final icon = SizedBox(
      width: 32,
      height: 32,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          item.buildIcon(
            size: 24,
            color: item.dimmed ? color.withValues(alpha: .48) : color,
          ),
          if (item.badge > 0 || item.dot)
            Positioned(
              top: -3,
              right: -5,
              child: Container(
                key: ValueKey('menu-badge-$index'),
                padding: EdgeInsets.all(item.badge > 0 ? 3 : 4),
                decoration: BoxDecoration(
                  color: SelahColors.journeyGold,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: item.badge > 0
                    ? Text(
                        item.badge > 99 ? '99+' : '${item.badge}',
                        textScaler: TextScaler.noScaling,
                        style: SelahText.body(
                          size: 9,
                          color: SelahColors.onAction,
                        ),
                      )
                    : null,
              ),
            ),
        ],
      ),
    );
    final label = Text(
      item.label,
      textAlign: compact || tile ? TextAlign.center : TextAlign.start,
      maxLines: compact ? 1 : null,
      overflow: compact ? TextOverflow.ellipsis : null,
      style: SelahText.body(size: compact ? 10.5 : 15, color: color),
    );
    final content = iconOnly
        ? icon
        : compact || tile
        ? Column(
            mainAxisSize: MainAxisSize.min,
            children: [icon, const SizedBox(height: 5), label],
          )
        : Row(
            children: [
              icon,
              const SizedBox(width: 14),
              Expanded(child: label),
              if (selected) ...[
                const SizedBox(width: 8),
                Icon(
                  Icons.check_rounded,
                  color: SelahColors.journeyGold,
                  size: 19,
                ),
              ],
            ],
          );
    return Semantics(
      button: true,
      selected: selected,
      label:
          '${item.label}${item.dimmed ? ', membership access limited' : ''}'
          '${indicator == null ? '' : ', $indicator'}',
      child: Tooltip(
        message: item.label,
        child: Material(
          color: raised
              ? SelahColors.journeyGold
              : selected
              ? SelahColors.journeyGold.withValues(alpha: .11)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(raised ? 30 : 16),
          child: InkWell(
            key: ValueKey('menu-destination-$index'),
            borderRadius: BorderRadius.circular(raised ? 30 : 16),
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 52, minWidth: 48),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: compact || iconOnly ? 2 : 14,
                  vertical: iconOnly ? 12 : 10,
                ),
                child: ExcludeSemantics(child: content),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuPanel extends StatelessWidget {
  const _MenuPanel({
    required this.design,
    required this.items,
    required this.currentIndex,
    required this.onSelect,
    required this.onClose,
  });
  final SelahMenuDesign design;
  final List<FloatingNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final side = design == SelahMenuDesign.sideMenu;
      final width = side
          ? math.min(320.0, bounds.maxWidth - 36)
          : design == SelahMenuDesign.threeDots || design == SelahMenuDesign.fab
          ? math.min(300.0, bounds.maxWidth - 32)
          : bounds.maxWidth - 32;
      if (design == SelahMenuDesign.fab) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            16,
            20,
            16 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Align(
            alignment: Alignment.bottomRight,
            child: SizedBox(
              width: width,
              child: Material(
                type: MaterialType.transparency,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < items.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: _MenuSurface(
                                    radius: 14,
                                    child: InkWell(
                                      key: ValueKey('menu-shortcut-label-$i'),
                                      onTap: () => onSelect(i),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                        child: Text(
                                          items[i].label,
                                          textAlign: TextAlign.end,
                                          style: SelahText.body(size: 14),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              SizedBox(
                                width: 56,
                                child: _MenuDestination(
                                  index: i,
                                  item: items[i],
                                  selected: i == currentIndex,
                                  onTap: () => onSelect(i),
                                  iconOnly: true,
                                  raised: true,
                                ),
                              ),
                            ],
                          ),
                        ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text('Go to', style: SelahText.body(size: 12)),
                          const SizedBox(width: 14),
                          _MenuSurface(
                            radius: 30,
                            gold: true,
                            child: IconButton(
                              key: const ValueKey('menu-close'),
                              constraints: const BoxConstraints(
                                minWidth: 56,
                                minHeight: 56,
                              ),
                              tooltip: 'Close navigation menu',
                              onPressed: onClose,
                              icon: Icon(
                                Icons.close_rounded,
                                color: SelahColors.onAction,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }
      return Padding(
        padding: EdgeInsets.fromLTRB(
          side ? 0 : 16,
          16,
          side ? 36 : 16,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Align(
          alignment: side
              ? Alignment.centerLeft
              : design == SelahMenuDesign.threeDots ||
                    design == SelahMenuDesign.fab
              ? Alignment.bottomRight
              : Alignment.bottomCenter,
          child: _MenuSurface(
            radius: side ? 20 : 28,
            child: SizedBox(
              width: width,
              height: side ? double.infinity : null,
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (design == SelahMenuDesign.sheet)
                        Center(
                          child: Container(
                            width: 36,
                            height: 4,
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: SelahColors.journeyGold.withValues(
                                alpha: .5,
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      Row(
                        children: [
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Go to',
                              style: SelahText.heading(size: 22),
                            ),
                          ),
                          IconButton(
                            key: const ValueKey('menu-close'),
                            tooltip: 'Close navigation menu',
                            onPressed: onClose,
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (design == SelahMenuDesign.grid)
                        LayoutBuilder(
                          builder: (context, grid) => Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (var i = 0; i < items.length; i++)
                                SizedBox(
                                  width: (grid.maxWidth - 8) / 2,
                                  child: _item(i, tile: true),
                                ),
                            ],
                          ),
                        )
                      else
                        for (var i = 0; i < items.length; i++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: _item(i),
                          ),
                      const SizedBox(height: 4),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );

  Widget _item(int index, {bool tile = false}) => _MenuDestination(
    index: index,
    item: items[index],
    selected: index == currentIndex,
    onTap: () => onSelect(index),
    tile: tile,
  );
}
