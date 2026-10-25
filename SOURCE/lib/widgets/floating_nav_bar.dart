// Shared floating glassmorphic nav bar — 2026-07-19.
//
// Styling reference, per Founder-supplied screen recordings:
//   - Instagram: icon grows when selected, shrinks when not, smooth
//     animated transition between states.
//   - Lovable's SELAH build: floating rounded glass pill, no fixed
//     per-item background — a single circular highlight "blob" sits
//     behind whichever icon is active and slides/morphs to the newly
//     selected tab rather than each item having its own static state.
//
// The single circular highlight slides between evenly-spaced tab cells.
// Founder 2026-10-13 supersedes glyph shrinking: every icon stays 22 px;
// the existing highlight and tint still identify selection. Both HomeShell and
// MentorHomeShell so the two navs stay visually identical, per MENTOR
// ARCHITECTURE's "floating glass pill: same design as Seeker nav."
//
// UPDATED 2026-07-25 (Founder request: "touch moving" — confirmed via
// clarifying question to mean "draggable along the bar... press and
// slide to preview/switch tabs, like scrubbing"). Previously each
// item only responded to a discrete onTap (tap-up). Now the whole bar
// is one GestureDetector: a horizontal drag (or a single tap) is
// tracked continuously, the highlight follows the raw finger position
// directly (no animation lag while actively dragging), and the active
// tab switches live the moment the finger crosses into a new cell —
// exactly like scrubbing. The eased AnimatedPositioned slide is kept
// for the "settle" moment once the finger lifts, and for programmatic
// tab changes that don't originate from this bar.
//
// RESOLVED 2026-07-26 — Founder supplied 3 reference screen
// recordings (2 from Instagram, 1 of the original Lovable SELAH
// prototype in motion) with explicit instruction: "drop the text."
// `showLabels` now defaults to false — icon-only, matching all 3
// references. The Lovable video is the authoritative spec for this
// bar specifically: a circular highlight badge (bigger + more
// opaque than this file previously had it, tuned below) behind the
// active icon only, not the labelled-pill look tried earlier. The
// Instagram clips corroborate the specific ask that started this
// pass — the deselect/shrink transition reading as smooth, not
// mechanical — hence the curve change below. Parameter kept (not
// deleted) in case a future context wants labels back; both current
// call sites (HomeShell, MentorHomeShell) rely on the new default.

import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/selah_colors.dart';
import '../theme/selah_interaction_style.dart';
import '../theme/selah_text.dart';
import 'selah_journey_icon.dart';
import 'selah_keyboard_dismiss_scope.dart';

bool _quietNavigationMotion(BuildContext context) {
  final media = MediaQuery.maybeOf(context);
  return (media?.disableAnimations ?? false) ||
      (media?.accessibleNavigation ?? false);
}

TextStyle _confirmationLabelStyle(BuildContext context, {Color? color}) {
  var style = (Theme.of(context).textTheme.bodyMedium ?? const TextStyle())
      .merge(SelahText.button(size: 13, color: color))
      .copyWith(inherit: false);
  if (MediaQuery.boldTextOf(context)) {
    style = style.merge(const TextStyle(fontWeight: FontWeight.bold));
  }
  return style;
}

/// THE BAR'S GEOMETRY, in one place — inherited decision 155, 2026-08-13.
///
/// Browse's action bar has to be the SAME BAR with different contents
/// (Founder: "the navigation bar should feel like it transforms, not
/// gets replaced... keep the exact same height, size, position, spacing,
/// visual weight"). Two widgets holding two copies of 24/28/58/0.86
/// would drift the first time one of them is tuned — which is precisely
/// how the action bar ended up visibly smaller than the bar it replaced
/// in the first place.
///
/// These are the IDLE values. The nav bar grows to [height] mid-drag;
/// nothing else does.
class SelahNavBarMetrics {
  SelahNavBarMetrics._();

  /// Inset from each screen edge.
  static const double sideInset = 24;

  /// Bottom inset applied inside SafeArea.
  static const double bottomInset = 14;

  /// Full height, reached while dragging.
  static const double height = 58;

  /// Resting height — what the bar is whenever nobody is touching it,
  /// and therefore what anything replacing it must match.
  static const double restingHeight = height * 0.86;

  static const double radius = 28;
  static const double blurSigma = 22;

  /// Idle glass, and what a touch lifts it to.
  ///
  /// THE BAR BREATHES ON TOUCH, and that turned out to be the missing
  /// half of "it doesn't feel like the same component" (Founder,
  /// 2026-08-13): the nav bar grows wider, taller and brighter under a
  /// finger and settles back when released. Anything claiming to BE
  /// this bar has to do the same, or it reads as a still photograph of
  /// it. All six values below move together on the same flag.
  static const double fill = 0.10;
  static const double fillTouched = 0.20;
  static const double borderAlpha = 0.18;
  static const double borderAlphaTouched = 0.30;

  /// Horizontal inset applied to the WHOLE glass unit at rest — the bar
  /// is narrower when nobody is touching it, and grows to 0 on touch.
  static const double restingSideSqueeze = 10;

  /// The moving circle behind the active icon.
  static const double highlightSize = 46;
  static const double restingHighlightSize = highlightSize * 0.86;

  /// Glyph size inside the bar.
  static const double iconSize = 22;

  /// Icon colours — full white when active, dimmed when not.
  static const double iconAlphaInactive = 0.45;

  /// How long the bar takes to grow or settle.
  static const Duration breath = Duration(milliseconds: 220);
}

/// The moving circle behind the active icon.
///
/// PUBLIC since 2026-08-13 (inherited decision 156) so Browse's action bar draws
/// THE highlight rather than a lookalike. It was `_Highlight`; nothing
/// about it changed in the move.
///
/// TUNED 2026-07-26 against the Lovable reference video: that badge
/// reads as a clearly-visible solid fill, not a thin outlined ring —
/// fill raised 0.20→0.28, border softened 0.28→0.12 (a faint edge for
/// definition against the bar's own blur, not a crisp outline that
/// competes with the fill for attention).
///
/// AnimatedContainer (was plain Container) as of the same pass that
/// made `size` itself vary with idle/touched state — without this,
/// toggling `dragging` would snap the badge to its new size instead
/// of resizing smoothly alongside the bar's own 220ms transition.
class SelahNavHighlight extends StatelessWidget {
  final double width;
  final double height;
  final SelahNavStyle style;

  const SelahNavHighlight({
    super.key,
    required this.width,
    required this.height,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    final quietMotion = _quietNavigationMotion(context);
    return AnimatedContainer(
      key: ValueKey('nav-highlight-quiet-$quietMotion'),
      duration: quietMotion ? Duration.zero : SelahNavBarMetrics.breath,
      curve: Curves.easeOut,
      width: width,
      height: height,
      decoration: _decoration,
    );
  }

  BoxDecoration get _decoration {
    final accent = SelahColors.isLightPalette
        ? SelahColors.devLightAccent.color
        : SelahColors.primaryAction;
    return switch (style) {
      SelahNavStyle.floatingGlass => BoxDecoration(
        shape: BoxShape.circle,
        color: SelahColors.isLightPalette
            ? accent.withValues(alpha: 0.16)
            : SelahColors.frostSelectedFill,
        border: Border.all(
          color: SelahColors.isLightPalette
              ? accent.withValues(alpha: 0.42)
              : SelahColors.frostSelectedBorder,
        ),
      ),
      SelahNavStyle.labelledDock => BoxDecoration(
        color: SelahColors.surfaceEmphasisFill,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: SelahColors.surfaceEmphasisBorder),
      ),
      SelahNavStyle.accentRing => BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.transparent,
        border: Border.all(color: accent, width: 2),
      ),
      SelahNavStyle.softTiles => BoxDecoration(
        color: accent.withValues(
          alpha: SelahColors.isLightPalette ? 0.13 : 0.22,
        ),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: accent.withValues(alpha: 0.42)),
      ),
      SelahNavStyle.goldUnderline => BoxDecoration(
        color: SelahColors.journeyGold,
        borderRadius: BorderRadius.circular(3),
      ),
      SelahNavStyle.raisedCapsule => BoxDecoration(
        color: accent,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.30),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      SelahNavStyle.quietDot => BoxDecoration(
        color: accent,
        shape: BoxShape.circle,
      ),
    };
  }
}

class FloatingNavItem {
  final IconData icon;
  final String label;

  /// Only the new-style Journey destination opts in. Existing material icons,
  /// destination metadata and all ordinary/Option 1 navigation stay unchanged.
  final bool useJourneyGlyph;

  /// Keeps a destination visible but visually quieter. It remains tappable so
  /// the destination itself can explain any access boundary in proper context.
  final bool dimmed;

  /// Unread count rendered as a small dot on the icon's shoulder —
  /// ADDED 2026-08-13 (inherited decision 149) when Notifications became a tab and
  /// the Bell's badge had to survive the move. 0 renders nothing.
  final int badge;

  /// A plain dot with NO NUMBER — "there is something here", nothing
  /// more.
  ///
  /// ADDED 2026-08-13 (inherited decision 154). Counts and dots answer different
  /// questions and the app already knew that: the Connections segment
  /// badges were changed from numbers to a bare dot on 2026-08-06 —
  /// "the heading already says how many; the dot only has to answer
  /// whether there is anything." A navigation indicator is that same
  /// question one level up. Notifications keeps its COUNT because it is
  /// an inbox and the size of the pile is the useful fact; Connections
  /// and Shepherd get a DOT because "3 things happened over there"
  /// changes nothing about whether you go and look.
  ///
  /// [badge] wins if both are set — a real count is strictly more
  /// information than a dot, so silently showing less would be the
  /// wrong way to resolve it.
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
  final bool showLabels;

  /// A protected/local caller may own its feedback setting independently.
  /// Null preserves the ordinary member's shared Personalisation choice.
  final SelahHapticLevel? hapticLevel;

  /// Optional alignment with the caller's content edges. When supplied, the
  /// bar keeps its full width at rest; height and touch feedback are unchanged.
  /// Null retains the original inset and resting-width breathing.
  final double? contentEdgeInset;

  /// When false (tabs), [onTap] fires the MOMENT a scrub crosses into a
  /// new cell — that is the scrubbing feel, and switching tab as your
  /// finger passes over it is the whole point of it.
  ///
  /// When true, a scrub only moves the highlight and [onTap] fires ONCE,
  /// on release, for the cell under the finger.
  ///
  /// ADDED 2026-08-13 (inherited decision 161) because Browse's action bar is this
  /// widget now, and for ACTIONS the live-fire behaviour is a bug rather
  /// than a feel: sliding left to right ran Hide Profile as the finger
  /// passed over it, before it had been lifted. A tab change is
  /// reversible by scrubbing onward; an action is not.
  final bool commitOnRelease;

  const FloatingNavBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
    this.showLabels = false,
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

/// Browse's deliberate second-step confirmation state.
///
/// It occupies the normal navigation footprint but replaces destination
/// icons with two equal, full-width pills. Cancel stays visually neutral;
/// Hide profile carries the app's destructive colour because it performs the
/// hide.
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

  /// Shared with a caller that reserves space above this temporary footer.
  /// Ordinary text keeps the existing footprint; enlarged labels may wrap
  /// without being shrunk, clipped or laid over the content above the bar.
  static double layoutHeight(
    BuildContext context, {
    required double viewportWidth,
    bool showOuterSurface = true,
    double? contentEdgeInset,
  }) {
    final border = showOuterSurface ? 2.0 : 0.0;
    final width =
        viewportWidth -
        2 * (contentEdgeInset ?? SelahNavBarMetrics.sideInset) -
        border -
        (contentEdgeInset == null ? 10 : 0);
    final labelWidth = math.max(1.0, (width - 6) / 2 - 16 - 18 - 7);
    final style = _confirmationLabelStyle(context);
    var labelHeight = 18.0;
    for (final label in ['Cancel', 'Hide profile']) {
      final painter = TextPainter(
        text: TextSpan(text: label, style: style),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        locale: Localizations.maybeLocaleOf(context),
      )..layout(maxWidth: labelWidth);
      labelHeight = math.max(labelHeight, painter.height);
      painter.dispose();
    }
    return math.max(
      SelahNavBarMetrics.height,
      border + 10 + math.max(44, labelHeight + 16),
    );
  }

  @override
  Widget build(BuildContext context) {
    final height = layoutHeight(
      context,
      viewportWidth: MediaQuery.sizeOf(context).width,
      showOuterSurface: showOuterSurface,
      contentEdgeInset: contentEdgeInset,
    );
    final actions = SizedBox(
      // The legacy surface's 1px border contributes its own layout inset.
      height: height - (showOuterSurface ? 2 : 0),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: contentEdgeInset == null ? 5 : 0,
          vertical: 5,
        ),
        child: Row(
          children: [
            Expanded(
              child: _ConfirmationPill(
                key: const ValueKey('browse-hide-cancel'),
                label: 'Cancel',
                icon: Icons.close_rounded,
                onTap: onCancel,
                hapticLevel: hapticLevel,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _ConfirmationPill(
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
    );
    return Positioned(
      left: contentEdgeInset ?? SelahNavBarMetrics.sideInset,
      right: contentEdgeInset ?? SelahNavBarMetrics.sideInset,
      bottom: 0,
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: SelahNavBarMetrics.bottomInset),
        child: !showOuterSurface
            ? actions
            : ClipRRect(
                key: const ValueKey('browse-hide-outer-surface'),
                borderRadius: BorderRadius.circular(SelahNavBarMetrics.radius),
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: SelahNavBarMetrics.blurSigma,
                    sigmaY: SelahNavBarMetrics.blurSigma,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: SelahColors.surfaceFill,
                      borderRadius: BorderRadius.circular(
                        SelahNavBarMetrics.radius,
                      ),
                      border: Border.all(color: SelahColors.surfaceBorder),
                    ),
                    child: actions,
                  ),
                ),
              ),
      ),
    );
  }
}

class _ConfirmationPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool destructive;
  final VoidCallback onTap;
  final SelahHapticLevel? hapticLevel;

  const _ConfirmationPill({
    super.key,
    required this.label,
    required this.icon,
    this.destructive = false,
    required this.onTap,
    this.hapticLevel,
  });

  @override
  Widget build(BuildContext context) {
    final tint = destructive ? SelahColors.destructive : SelahColors.foreground;
    return Material(
      color: destructive
          ? SelahColors.destructive.withValues(alpha: 0.16)
          : SelahColors.ink(0.08),
      shape: StadiumBorder(
        side: BorderSide(
          color: destructive
              ? SelahColors.destructive.withValues(alpha: 0.62)
              : SelahColors.ink(0.18),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          SelahInteractionStyle.emitSelectionHaptic(level: hapticLevel);
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18, color: tint),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: _confirmationLabelStyle(context, color: tint),
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

class _FloatingNavBarState extends State<FloatingNavBar> {
  // Slimmer than before (62) now the bar is icon-only — matches the
  // Lovable reference video's proportions once the label row is gone.
  static const double _barHeight = SelahNavBarMetrics.height;
  // Bigger relative to the icon than before (44) — the reference
  // video's badge clearly reads as larger than the icon's own tap
  // target, not a tight halo around it.
  static const double _highlightSize = SelahNavBarMetrics.highlightSize;

  // Raw finger x-position while actively dragging/pressing, relative to
  // the bar's own width — null when not touching, in which case the
  // highlight falls back to the eased, animated position for
  // widget.currentIndex (tap or programmatic change).
  double? _touchX;
  int _semanticsEpoch = 0;
  bool? _lastQuietMotion;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final quietMotion = _quietNavigationMotion(context);
    if (_lastQuietMotion != null && quietMotion != _lastQuietMotion) {
      // Recreating an implicit-animation subtree settles any in-flight visual
      // motion. An interrupted pointer preview must not remain latched to it.
      _touchX = null;
      _lastIndex = null;
      _semanticsEpoch++;
    }
    _lastQuietMotion = quietMotion;
  }

  @override
  void didUpdateWidget(covariant FloatingNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A retained accessibility callback must not invoke a destination/action
    // from the previous bar after its caller, selection or contents change.
    _semanticsEpoch++;
  }

  void _activateSemanticItem(int index, int epoch) {
    if (!mounted || epoch != _semanticsEpoch) return;
    if (index < 0 || index >= widget.items.length) return;
    final changed = index != widget.currentIndex;
    // A semantic tap identifies one cell directly, not a coordinate scrub.
    // Cancel any pointer preview so its later release cannot repeat an action.
    if (_touchX != null) {
      setState(() => _touchX = null);
    }
    _lastIndex = null;
    if (!changed && !widget.commitOnRelease) return;
    dismissSelahKeyboardAfterNavigation();
    if (changed) {
      SelahInteractionStyle.emitSelectionHaptic(level: widget.hapticLevel);
    }
    widget.onTap(index);
  }

  int _indexForX(double x, double barWidth) {
    final cellWidth = barWidth / widget.items.length;
    final i = (x / cellWidth).floor();
    return i.clamp(0, widget.items.length - 1);
  }

  void _beginTouchAt(double x, double barWidth) {
    // The shell uses IndexedStack so the field in the previous tab remains
    // mounted. Dismiss before changing the visible child or its native iOS
    // keyboard can otherwise remain painted over the destination tab.
    dismissSelahKeyboardAfterNavigation();
    _lastIndex = widget.currentIndex;
    setState(() => _touchX = x.clamp(0, barWidth));
  }

  void _handleTouchAt(double x, double barWidth) {
    setState(() => _touchX = x.clamp(0, barWidth));
    final index = _indexForX(x, barWidth);
    final previousIndex = _lastIndex ?? widget.currentIndex;
    _lastIndex = index;
    if (index != previousIndex) {
      // 2026-07-26 (nav bar refinement pass — CHATGPT_REPLY_NAVBAR_
      // PHOTO_MENU_2026-07-26.md §1): a small, cheap "premium app"
      // detail that was simply missing — every native tab bar (iOS
      // Control Center, Instagram, Flutter's own Switch/Radio) gives a
      // light tap on selection change. Fires on crossing into a new
      // cell during a drag-scrub too, not just a discrete tap, since
      // both paths call this same method.
      SelahInteractionStyle.emitSelectionHaptic(level: widget.hapticLevel);
      // The haptic fires once per crossed cell — feeling the cells go by
      // makes a scrub legible, while comparing against _lastIndex prevents
      // repeated ticks when several pointer updates remain inside one cell.
      // Only the ACTION waits (see [commitOnRelease]).
      if (!widget.commitOnRelease) widget.onTap(index);
    }
  }

  /// [commit] is true for a release, false for a cancel.
  ///
  /// Cancels must never fire: a gesture the arena took away from this
  /// widget, or one interrupted by a route change, is not a choice. Only
  /// matters when [commitOnRelease] is set — otherwise onTap has already
  /// fired live and there is nothing left to do here.
  void _endTouch({bool commit = false}) {
    final x = _touchX;
    final index = _lastIndex;
    setState(() => _touchX = null);
    _lastIndex = null;
    if (!widget.commitOnRelease || !commit || x == null) return;
    // barWidth is not in scope here, and does not need to be: the index
    // was resolved on the last move, so recompute from the same clamped
    // x against the width the layout last reported.
    if (index != null) widget.onTap(index);
  }

  /// The cell the finger was last over. Written by [_handleTouchAt] so
  /// [_endTouch] does not need the bar's width to resolve it again.
  int? _lastIndex;

  Color _barFill(SelahNavStyle style, bool dragging) => switch (style) {
    SelahNavStyle.labelledDock =>
      dragging ? SelahColors.surfaceEmphasisFill : SelahColors.surfaceFill,
    SelahNavStyle.softTiles when SelahColors.devPalette.usesWhiteGlass =>
      dragging ? SelahColors.surfaceEmphasisFill : SelahColors.surfaceFill,
    SelahNavStyle.goldUnderline || SelahNavStyle.quietDot =>
      dragging ? SelahColors.surfaceEmphasisFill : SelahColors.surfaceFill,
    _ => dragging ? SelahColors.surfaceEmphasisFill : SelahColors.surfaceFill,
  };

  Color _barBorder(SelahNavStyle style, bool dragging) => switch (style) {
    SelahNavStyle.labelledDock =>
      dragging ? SelahColors.surfaceEmphasisBorder : SelahColors.surfaceBorder,
    _ => dragging ? SelahColors.surfaceEmphasisBorder : SelahColors.surfaceBorder,
  };

  Color _iconColor(SelahNavStyle style, bool selected) {
    if (style == SelahNavStyle.labelledDock) {
      return selected
          ? SelahColors.surfaceSignal
          : SelahColors.foregroundSecondary;
    }
    if (style == SelahNavStyle.goldUnderline && selected) {
      return SelahColors.journeyGold;
    }
    if (style == SelahNavStyle.raisedCapsule && selected) {
      return SelahColors.onAction;
    }
    return selected ? SelahColors.foreground : SelahColors.ink(0.45);
  }

  @override
  Widget build(BuildContext context) {
    // 2026-07-26 (Founder: "when not touched it becomes more
    // transparent, when touched less transparent") — the bar's own
    // glass fill now reacts to touch state, not just the highlight
    // badge. `dragging` is hoisted up here (previously computed inside
    // LayoutBuilder's builder) since the container's decoration needs
    // it too, and it never actually depended on `constraints` anyway.
    final dragging = _touchX != null;
    final navStyle = SelahInteractionStyle.navStyle;
    final quietMotion = _quietNavigationMotion(context);
    final semanticsEpoch = _semanticsEpoch;
    // FIXED 2026-07-26 (Founder screenshot: "when it's smaller the blob
    // is out of place now so that needs to be fixed to match new size
    // also"). The highlight's size and vertical centring were still
    // hardcoded against the constant `_barHeight`/`_highlightSize` —
    // correct for the full (touched) size, but wrong the moment the bar
    // itself started shrinking when idle (added this same session).
    // These mirror the exact height expression the AnimatedContainer
    // below uses, so the badge always matches whatever size the bar
    // actually is right now, not just its full-size resting state.
    final currentBarHeight = dragging
        ? _barHeight
        : SelahNavBarMetrics.restingHeight;
    final currentHighlightSize = dragging
        ? _highlightSize
        : SelahNavBarMetrics.restingHighlightSize;
    return Positioned(
      left: widget.contentEdgeInset ?? SelahNavBarMetrics.sideInset,
      right: widget.contentEdgeInset ?? SelahNavBarMetrics.sideInset,
      bottom: 0,
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: SelahNavBarMetrics.bottomInset),
        // 2026-07-26 (Founder, repeated across several passes: "the
        // navigation bar (NOT ICONS) — bar smaller when it's not
        // clicked"). Every earlier pass only changed the ICONS' scale
        // or the bar's opacity — never the bar's own footprint. This
        // AnimatedPadding shrinks the whole glass unit's WIDTH —
        // wrapping the ClipRRect so the blur/fill/border all shrink
        // together, not just the content inside them (doing this only
        // on the inner Container would leave a mismatched blurred
        // rectangle showing around a smaller pill). Height shrinks via
        // the AnimatedContainer below, same `dragging` flag. `dragging`
        // is true for the whole press (tap or drag), not just an
        // active drag — touch to expand to full size, release to
        // shrink back, matching "smaller when not clicked."
        child: AnimatedPadding(
          key: ValueKey('floating-nav-quiet-$quietMotion'),
          duration: quietMotion ? Duration.zero : SelahNavBarMetrics.breath,
          curve: Curves.easeOut,
          padding: EdgeInsets.symmetric(
            horizontal: widget.contentEdgeInset != null || dragging
                ? 0
                : SelahNavBarMetrics.restingSideSqueeze,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
              child: AnimatedContainer(
                duration: quietMotion
                    ? Duration.zero
                    : SelahNavBarMetrics.breath,
                curve: Curves.easeOut,
                height: currentBarHeight,
                decoration: BoxDecoration(
                  color: _barFill(navStyle, dragging),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: _barBorder(navStyle, dragging),
                    width: 1,
                  ),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final barWidth = constraints.maxWidth;
                    // FIXED 2026-08-01 (Founder: "the blob is closer to the
                    // bottom then the top... the magnifier glass doesnt seem to
                    // be dead in middle"). This is real, not perception —
                    // measured off the Founder's own screenshots at 3x: 15
                    // physical px of gap above the badge against 9 below.
                    //
                    // ROOT CAUSE: `currentBarHeight` is the AnimatedContainer's
                    // OUTER height, but this Stack sits INSIDE that container's
                    // 1px border. A BoxDecoration border insets the child —
                    // Container wraps it in Padding(decoration.padding), which
                    // for Border.all(width: 1) is EdgeInsets.all(1) — so the
                    // Stack is 2px shorter than `currentBarHeight`. Centring the
                    // badge against the outer height therefore parked it exactly
                    // 1 logical px (3 physical px at 3x) below true centre.
                    //
                    // NOT the two bar sizes, which was the standing hypothesis:
                    // the error is a constant 1px in BOTH the idle and touched
                    // states, because the border is 1px in both. Note the icon
                    // Row was never wrong — it's a non-Positioned child of a
                    // centre-aligned Stack, so it centres against the real inner
                    // height. That mismatch is exactly why the badge and the
                    // glyph inside it disagreed with each other.
                    //
                    // constraints.maxHeight IS this Stack's real height, so the
                    // fix also survives any future border/padding change, and it
                    // tracks the container's ANIMATED height through the 220ms
                    // resize rather than snapping to the target value — the
                    // badge now stays centred during the transition, not just at
                    // each end of it.
                    final innerHeight = constraints.maxHeight;
                    final cellWidth = barWidth / widget.items.length;
                    final highlightWidth = switch (navStyle) {
                      SelahNavStyle.labelledDock => cellWidth - 5,
                      SelahNavStyle.softTiles => 41.0,
                      SelahNavStyle.goldUnderline => 28.0,
                      SelahNavStyle.raisedCapsule => cellWidth - 10,
                      SelahNavStyle.quietDot => 6.0,
                      _ => currentHighlightSize,
                    };
                    final highlightHeight = switch (navStyle) {
                      SelahNavStyle.labelledDock => 42.0,
                      SelahNavStyle.softTiles => 41.0,
                      SelahNavStyle.goldUnderline => 3.0,
                      SelahNavStyle.raisedCapsule => 38.0,
                      SelahNavStyle.quietDot => 6.0,
                      _ => currentHighlightSize,
                    };
                    final highlightTop = switch (navStyle) {
                      SelahNavStyle.goldUnderline => innerHeight - 7,
                      SelahNavStyle.quietDot => innerHeight - 9,
                      _ => (innerHeight - highlightHeight) / 2,
                    };
                    final highlightLeft = dragging
                        ? (_touchX! - highlightWidth / 2).clamp(
                            0.0,
                            barWidth - highlightWidth,
                          )
                        : cellWidth * widget.currentIndex +
                              (cellWidth - highlightWidth) / 2;
                    final liveIndex = dragging
                        ? _indexForX(_touchX!, barWidth)
                        : widget.currentIndex;

                    return Listener(
                      // Flutter can report an accepted drag's cancellation as
                      // drag-end. Clear the raw pointer state before that end
                      // callback so an OS interruption can never commit it.
                      onPointerCancel: (_) => _endTouch(),
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        // The bar-wide coordinate recognizer owns real pointer
                        // scrubs only. Each cell exposes its own semantic action.
                        excludeFromSemantics: true,
                        onTapDown: (d) =>
                            _beginTouchAt(d.localPosition.dx, barWidth),
                        onTapUp: (d) {
                          _handleTouchAt(d.localPosition.dx, barWidth);
                          _endTouch(commit: true);
                        },
                        onTapCancel: _endTouch,
                        onHorizontalDragStart: (d) =>
                            _handleTouchAt(d.localPosition.dx, barWidth),
                        onHorizontalDragUpdate: (d) =>
                            _handleTouchAt(d.localPosition.dx, barWidth),
                        onHorizontalDragEnd: (_) => _endTouch(commit: true),
                        onHorizontalDragCancel: _endTouch,
                        child: Stack(
                          // FIXED 2026-07-26 (root cause identified in
                          // CHATGPT_REPLY_NAVBAR_PHOTO_MENU_2026-07-26.md §1
                          // — this one line was the entire "icon sits too
                          // high" / "circle feels like it's sitting on top
                          // of the bar rather than belonging to it" bug).
                          // Stack's default alignment is topStart. The
                          // highlight circle below is wrapped in its own
                          // Positioned/AnimatedPositioned so it was already
                          // correctly centred — but the icon+label Row is a
                          // plain (non-Positioned) Stack child, so without
                          // this line it fell back to topStart and pinned
                          // to the top of the 62px bar instead of sitting in
                          // the middle with the (correctly centred) circle
                          // behind it. The two symptoms were one bug.
                          alignment: Alignment.center,
                          children: [
                            // The sliding highlight — Lovable-style single blob,
                            // not a per-item background. Follows the finger
                            // directly (no easing) while actively touching;
                            // eases to the settled tab centre otherwise.
                            dragging
                                ? Positioned(
                                    left: highlightLeft,
                                    top: highlightTop,
                                    child: SelahNavHighlight(
                                      width: highlightWidth,
                                      height: highlightHeight,
                                      style: navStyle,
                                    ),
                                  )
                                : AnimatedPositioned(
                                    // FIXED 2026-07-26 (Founder reference videos —
                                    // "gets smaller when user clicks off it" /
                                    // shrink transition should feel smooth, not
                                    // mechanical). easeOutCubic arrives and stops
                                    // dead on time; easeOutBack overshoots very
                                    // slightly past the target then settles,
                                    // which is what a spring-driven native tab
                                    // bar actually does. Slowed 260ms→320ms to
                                    // give that overshoot room to read instead
                                    // of feeling rushed.
                                    duration: quietMotion
                                        ? Duration.zero
                                        : const Duration(milliseconds: 320),
                                    curve: Curves.easeOutBack,
                                    left: highlightLeft,
                                    top: highlightTop,
                                    child: SelahNavHighlight(
                                      width: highlightWidth,
                                      height: highlightHeight,
                                      style: navStyle,
                                    ),
                                  ),
                            Row(
                              children: List.generate(widget.items.length, (i) {
                                final selected = i == liveIndex;
                                final item = widget.items[i];
                                final color = _iconColor(navStyle, selected);
                                final iconColor = item.dimmed
                                    ? color.withValues(
                                        alpha: selected ? 0.58 : 0.28,
                                      )
                                    : color;
                                // Founder 2026-10-13: all navigation glyphs
                                // retain their common 22 px size. The existing
                                // halo and tint identify selection; inactive
                                // tabs no longer shrink their artwork.
                                final icon = Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    AnimatedScale(
                                      scale: 1,
                                      duration: quietMotion
                                          ? Duration.zero
                                          : const Duration(milliseconds: 280),
                                      curve: Curves.easeOutBack,
                                      child: item.buildIcon(
                                        color: iconColor,
                                        size: SelahNavBarMetrics.iconSize,
                                      ),
                                    ),
                                    // The badge sits OUTSIDE the scale so an
                                    // unselected tab's count doesn't shrink
                                    // with its icon (inherited decision 149).
                                    // The bare dot — same shoulder, same
                                    // colour, no number. Sized to the
                                    // numbered badge's minWidth so the two
                                    // sit on the same optical line when a
                                    // bar carries one of each.
                                    if (item.badge == 0 && item.dot)
                                      const Positioned(
                                        top: -2,
                                        right: -3,
                                        child: SizedBox(
                                          width: 15,
                                          height: 15,
                                          child: Center(
                                            child: SizedBox(
                                              width: 7,
                                              height: 7,
                                              child: DecoratedBox(
                                                decoration: BoxDecoration(
                                                  color: SelahColors.unlockDot,
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    if (item.badge > 0)
                                      Positioned(
                                        top: -5,
                                        right: -7,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 4,
                                            vertical: 1,
                                          ),
                                          constraints: const BoxConstraints(
                                            minWidth: 15,
                                            minHeight: 15,
                                          ),
                                          decoration: BoxDecoration(
                                            color: SelahColors.unlockDot,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Text(
                                            item.badge > 9
                                                ? '9+'
                                                : '${item.badge}',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              color:
                                                  SelahColors.luxuryDarkPurple,
                                              fontSize: 9,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                );
                                return Expanded(
                                  child: Semantics(
                                    key: ValueKey('floating-nav-item-$i'),
                                    container: true,
                                    button: true,
                                    selected: i == widget.currentIndex,
                                    label: item.label,
                                    value: item.badge > 0
                                        ? '${item.badge} unread'
                                        : item.dot
                                        ? 'New activity'
                                        : null,
                                    onTap: () => _activateSemanticItem(
                                      i,
                                      semanticsEpoch,
                                    ),
                                    excludeSemantics: true,
                                    child: SizedBox(
                                      height: innerHeight,
                                      child: Center(
                                        child: IgnorePointer(
                                          // Touch handling now lives on the bar-wide
                                          // GestureDetector above so a press/drag
                                          // anywhere on the bar is tracked as one
                                          // continuous gesture — individual cells no
                                          // longer need (or intercept) their own taps.
                                          //
                                          // FIXED 2026-07-26 (Founder: blob looks
                                          // "unprofessional" — icon sits with more
                                          // space below it than above, inside the
                                          // highlight). `Center` here guarantees
                                          // true geometric centring regardless of
                                          // any Column min-size quirk — the
                                          // showLabels branch below still needs the
                                          // Column (two children to stack
                                          // vertically), but the far more common
                                          // icon-only case no longer goes through it
                                          // at all. If the badge still looks
                                          // off-centre after this on a specific
                                          // icon (e.g. a shield glyph), that's the
                                          // glyph's own optical weight, not layout —
                                          // see the Shepherd icon swap note in
                                          // home_shell.dart from this same pass.
                                          child: widget.showLabels
                                              ? Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    icon,
                                                    SizedBox(height: 2),
                                                    AnimatedDefaultTextStyle(
                                                      duration: quietMotion
                                                          ? Duration.zero
                                                          : SelahNavBarMetrics
                                                                .breath,
                                                      style: SelahText.subtext(
                                                        size: 10,
                                                        color: color,
                                                      ),
                                                      child: Text(item.label),
                                                    ),
                                                  ],
                                                )
                                              : navStyle ==
                                                        SelahNavStyle
                                                            .labelledDock &&
                                                    selected
                                              ? Center(
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 5,
                                                        ),
                                                    child: FittedBox(
                                                      fit: BoxFit.scaleDown,
                                                      child: Row(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          icon,
                                                          const SizedBox(
                                                            width: 5,
                                                          ),
                                                          Text(
                                                            item.label,
                                                            maxLines: 1,
                                                            style:
                                                                SelahText.button(
                                                                  size: 11,
                                                                  color: color,
                                                                ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                )
                                              : Center(child: icon),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// _Highlight became the public SelahNavHighlight, above (inherited decision 156).
