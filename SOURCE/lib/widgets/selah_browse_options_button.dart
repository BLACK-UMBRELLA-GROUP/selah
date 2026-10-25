import 'package:flutter/material.dart';

import '../models/seeker_profile.dart';
import '../theme/selah_colors.dart';

/// Browse's existing action-navigation destinations, not profile mutations.
/// The caller owns the action bar, consent and permission checks.
enum SelahBrowseAction {
  compatibility('Compatibility', Icons.insights_outlined),
  scan('Scan', Icons.qr_code_scanner_rounded),
  hide('Hide profile', Icons.visibility_off_outlined),
  filters('Filters', Icons.tune),
  report('Report', Icons.flag_outlined);

  const SelahBrowseAction(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// Opens caller-owned action navigation for this exact displayed person.
/// A null context still permits global Scan/Filters; the caller must hold
/// person-specific actions and never substitute another selected profile.
class SelahBrowseOptionsButton extends StatefulWidget {
  const SelahBrowseOptionsButton({
    super.key,
    required this.profile,
    required this.onOpen,
    this.alignToContentEdge = false,
  });

  final SeekerProfile? profile;
  final ValueChanged<SeekerProfile?> onOpen;
  final bool alignToContentEdge;

  @override
  State<SelahBrowseOptionsButton> createState() =>
      _SelahBrowseOptionsButtonState();
}

class _SelahBrowseOptionsButtonState extends State<SelahBrowseOptionsButton>
    with SingleTickerProviderStateMixin {
  final _states = WidgetStatesController();
  late final AnimationController _feedback;
  double _feedbackAlpha = .1;
  bool _quiet = false;

  @override
  void initState() {
    super.initState();
    _feedback = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _states.addListener(_syncFeedback);
  }

  void _syncFeedback() {
    final states = _states.value;
    final active =
        widget.alignToContentEdge &&
        (states.contains(WidgetState.pressed) ||
            states.contains(WidgetState.focused) ||
            states.contains(WidgetState.hovered));
    if (active) {
      _feedbackAlpha =
          states.contains(WidgetState.pressed) ||
              states.contains(WidgetState.focused)
          ? .1
          : .08;
      // Native pressed state can start/end within a single frame. Start at
      // full strength, then fade so even a quick tap retains visible feedback.
      _feedback.value = 1;
    } else if (_quiet || !widget.alignToContentEdge) {
      _feedback.value = 0;
    } else {
      _feedback.reverse();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final media = MediaQuery.maybeOf(context);
    _quiet =
        (media?.disableAnimations ?? false) ||
        (media?.accessibleNavigation ?? false);
    if (_quiet) _syncFeedback();
  }

  @override
  void didUpdateWidget(SelahBrowseOptionsButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.alignToContentEdge != widget.alignToContentEdge) {
      _syncFeedback();
    }
  }

  @override
  void dispose() {
    _states.removeListener(_syncFeedback);
    _states.dispose();
    _feedback.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final person = widget.profile;
    final name = person == null
        ? null
        : [
            person.firstName.trim(),
            if (person.surnameLine?.trim().isNotEmpty ?? false)
              person.surnameLine!.trim(),
          ].where((part) => part.isNotEmpty).join(' ');
    final open = widget.onOpen;
    return IconButton(
      key: const ValueKey('concept_browse_menu'),
      tooltip: name == null || name.isEmpty
          ? 'Browse options'
          : 'Browse options for $name',
      onPressed: () => open(person),
      color: SelahColors.journeyGold,
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      padding: widget.alignToContentEdge
          ? EdgeInsets.zero
          : const EdgeInsets.all(8),
      alignment: widget.alignToContentEdge
          ? Alignment.centerRight
          : Alignment.center,
      statesController: _states,
      style: widget.alignToContentEdge
          ? ButtonStyle(
              overlayColor: const WidgetStatePropertyAll(Colors.transparent),
              splashFactory: NoSplash.splashFactory,
              // The foreground builder shares the icon's alignment, not the
              // wider native touch target. Neither target nor glyph moves.
              foregroundBuilder: (context, states, child) => Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: -12,
                    top: -12,
                    width: 48,
                    height: 48,
                    child: IgnorePointer(
                      child: ExcludeSemantics(
                        child: AnimatedBuilder(
                          animation: _feedback,
                          builder: (context, _) => DecoratedBox(
                            key: const ValueKey('browse-menu-tap-feedback'),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: SelahColors.journeyGold.withValues(
                                alpha: _feedback.value * _feedbackAlpha,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  ?child,
                ],
              ),
            )
          : null,
      icon: const Icon(Icons.more_horiz_rounded, size: 24),
    );
  }
}
