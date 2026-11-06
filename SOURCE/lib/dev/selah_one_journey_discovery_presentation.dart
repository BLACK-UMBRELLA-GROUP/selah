// Pure presentation for the protected One Journey comparison.
// LOCK 1 supplies the common visual tokens; callers retain content and flows.
// No account, service, persistence, matching or permission authority lives here.
// Callers supply only local profiles, images and already-guarded callbacks.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/seeker_profile.dart';
import '../screens/connections/connections_section_controller.dart';
import '../theme/selah_card_metrics.dart';
import '../theme/selah_colors.dart';
import '../theme/selah_text.dart';
import '../widgets/selah_profile_image.dart';
import '../widgets/selah_invitation_label.dart';
import '../widgets/selah_press_feedback.dart';
import '../widgets/selah_segmented_toggle.dart';
import '../widgets/floating_nav_bar.dart' show SelahNavBarMetrics;
import 'selah_one_journey_card_content.dart';

/// A caller can resolve an existing bundled sample without a network provider.
typedef SelahOneJourneyPhotoBuilder =
    Widget Function(BuildContext context, String photo);

Widget _profileImage(BuildContext context, String photo) =>
    SelahProfileImage(photo, width: double.infinity, height: double.infinity);

/// Full-photo inspection keeps the existing gallery and public identity.
/// Common LOCK 1 tokens replace the old photo scrim and floating styling.
class SelahOneJourneyBrowsePresentation extends StatefulWidget {
  const SelahOneJourneyBrowsePresentation({
    super.key,
    required this.profile,
    required this.onMenu,
    this.onPreviousProfile,
    this.onNextProfile,
    this.onRequest,
    this.onSave,
    this.requestLabel = 'Request a Journey',
    this.invitationSent,
    this.saved = false,
    this.imageBuilder = _profileImage,
    this.previousKey,
    this.nextKey,
    this.requestKey,
    this.saveKey,
    this.menuKey,
    this.menuButton,
    this.menuLabel = 'Profile options',
    this.menuIcon = Icons.more_horiz,
    this.menuOnLeft = false,
    this.showMenu = true,
    this.identityBottom,
    this.actionsBottom,
    this.showActions = true,
    this.showSave = true,
    this.onDismiss,
  });

  final SeekerProfile profile;
  final VoidCallback onMenu;
  final VoidCallback? onPreviousProfile;
  final VoidCallback? onNextProfile;
  final VoidCallback? onRequest;
  final VoidCallback? onSave;
  final String requestLabel;
  final bool? invitationSent;
  final bool saved;
  final SelahOneJourneyPhotoBuilder imageBuilder;
  final Key? previousKey;
  final Key? nextKey;
  final Key? requestKey;
  final Key? saveKey;
  final Key? menuKey;
  final Widget? menuButton;
  final String menuLabel;
  final IconData menuIcon;
  final bool menuOnLeft;
  final bool showMenu;
  final double? identityBottom;
  final double? actionsBottom;
  final bool showActions;
  final bool showSave;

  /// Opt-in dismissal for a temporary full-photo inspection. The caller owns
  /// the return destination and supplies an already-guarded callback. Other
  /// viewers retain their existing tap-only photo navigation.
  final VoidCallback? onDismiss;

  @override
  State<SelahOneJourneyBrowsePresentation> createState() =>
      _SelahOneJourneyBrowsePresentationState();
}

class _SelahOneJourneyBrowsePresentationState
    extends State<SelahOneJourneyBrowsePresentation>
    with SingleTickerProviderStateMixin {
  int _photoIndex = 0;
  int _renderEpoch = 0;
  int _motionEpoch = 0;
  int? _dragEpoch;
  String? _dragProfileId;
  VoidCallback? _dragDismiss;
  final Set<int> _dismissPointers = <int>{};
  double _dismissOffset = 0;
  bool _dragCancelled = false;
  bool _dismissCommitted = false;
  late final AnimationController _dismissMotion;
  Animation<double>? _dismissAnimation;

  static const _dismissVelocity = 650.0;
  static const _minimumFlingPull = 24.0;

  @override
  void initState() {
    super.initState();
    _dismissMotion = AnimationController(vsync: this)
      ..addListener(_followDismissAnimation);
  }

  void _followDismissAnimation() {
    final animation = _dismissAnimation;
    if (!mounted || animation == null) return;
    setState(() => _dismissOffset = animation.value);
  }

  void _resetDismissal() {
    ++_motionEpoch;
    _dismissMotion.stop(canceled: true);
    _dismissAnimation = null;
    _dragEpoch = null;
    _dragProfileId = null;
    _dragDismiss = null;
    _dismissPointers.clear();
    _dismissOffset = 0;
    _dragCancelled = false;
    _dismissCommitted = false;
  }

  @override
  void didUpdateWidget(covariant SelahOneJourneyBrowsePresentation oldWidget) {
    super.didUpdateWidget(oldWidget);
    ++_renderEpoch;
    _resetDismissal();
    if (oldWidget.profile.id != widget.profile.id ||
        _photoIndex >= widget.profile.photos.length) {
      _photoIndex = 0;
    }
  }

  @override
  void dispose() {
    ++_renderEpoch;
    ++_motionEpoch;
    _dismissMotion.dispose();
    super.dispose();
  }

  bool _validDismissGesture(int epoch) =>
      mounted &&
      epoch == _renderEpoch &&
      _dragEpoch == epoch &&
      _dragProfileId == widget.profile.id &&
      _dragDismiss != null &&
      identical(_dragDismiss, widget.onDismiss) &&
      !_dismissCommitted;

  void _startDismissDrag(int epoch) {
    if (!mounted || epoch != _renderEpoch || _dismissCommitted) return;
    final dismiss = widget.onDismiss;
    if (dismiss == null) return;
    ++_motionEpoch;
    _dismissMotion.stop(canceled: true);
    _dismissAnimation = null;
    _dragEpoch = epoch;
    _dragProfileId = widget.profile.id;
    _dragDismiss = dismiss;
    _dragCancelled = false;
  }

  void _updateDismissDrag(DragUpdateDetails details, int epoch) {
    if (!_validDismissGesture(epoch) || _dragCancelled) return;
    setState(() {
      _dismissOffset = math.max(0.0, _dismissOffset + details.delta.dy);
    });
  }

  void _endDismissDrag(DragEndDetails details, double height, int epoch) {
    if (!_validDismissGesture(epoch) || _dragCancelled) return;
    final velocity = details.primaryVelocity ?? 0;
    final commit =
        _dismissOffset >= height * .14 ||
        (_dismissOffset >= _minimumFlingPull && velocity >= _dismissVelocity);
    unawaited(
      _settleDismissal(
        epoch: epoch,
        target: commit ? height : 0,
        commit: commit,
      ),
    );
  }

  void _cancelDismissDrag(int epoch) {
    if (!_validDismissGesture(epoch)) return;
    _dragCancelled = true;
    unawaited(_settleDismissal(epoch: epoch, target: 0, commit: false));
  }

  void _cancelDismissPointer(PointerCancelEvent event, int epoch) {
    if (!mounted ||
        epoch != _renderEpoch ||
        !_dismissPointers.remove(event.pointer)) {
      return;
    }
    // An accepted Flutter drag reports PointerCancelEvent through onEnd, not
    // onCancel. Raw hit-test listeners run before recognizer routing, so this
    // revokes that release before it can commit, including reduced motion.
    _cancelDismissDrag(epoch);
  }

  Future<void> _settleDismissal({
    required int epoch,
    required double target,
    required bool commit,
  }) async {
    if (!_validDismissGesture(epoch)) return;
    // Capture this gesture's delegate before animation. A later render may
    // revoke it, but must never substitute a new owner's or person's callback.
    final dismiss = _dragDismiss!;
    final profileId = _dragProfileId;
    final motion = ++_motionEpoch;
    _dismissMotion.stop(canceled: true);
    final reduceMotion =
        MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context);
    if (reduceMotion) {
      setState(() => _dismissOffset = target);
      // No animation or timed delay. Allow raw cancellation later in the same
      // dispatch to revoke a proxied release before its callback is executed.
      if (commit) await Future<void>.value();
    } else {
      _dismissMotion.duration = Duration(milliseconds: commit ? 200 : 180);
      _dismissAnimation = Tween<double>(
        begin: _dismissOffset,
        end: target,
      ).chain(CurveTween(curve: Curves.easeOutCubic)).animate(_dismissMotion);
      try {
        await _dismissMotion.forward(from: 0).orCancel;
      } on TickerCanceled {
        return;
      }
    }
    if (!_validDismissGesture(epoch) ||
        motion != _motionEpoch ||
        (commit && _dragCancelled) ||
        profileId != widget.profile.id) {
      return;
    }
    _dismissAnimation = null;
    _dragEpoch = null;
    _dragProfileId = null;
    _dragDismiss = null;
    if (commit) {
      _dismissCommitted = true;
      dismiss();
    }
  }

  void _tapPhoto(TapUpDetails details, double width) {
    final count = widget.profile.photos.length;
    if (count <= 1) return;
    setState(() {
      _photoIndex = details.localPosition.dx >= width / 2
          ? (_photoIndex + 1) % count
          : (_photoIndex - 1).clamp(0, count - 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    final photos = profile.photos;
    final photo = photos.isEmpty ? '' : photos[_photoIndex];
    final actionsBottom = widget.actionsBottom ?? 85;
    final actionLabel = TextPainter(
      text: TextSpan(
        text: widget.requestLabel,
        style: SelahText.button(size: 15),
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final actionHeight = math.max(14.0, actionLabel.height) + 30;
    actionLabel.dispose();
    final identityBottom = widget.showActions
        ? math.max(
            widget.identityBottom ?? 130,
            actionsBottom + actionHeight + 14,
          )
        : widget.identityBottom ?? 130;
    final epoch = _renderEpoch;
    return LayoutBuilder(
      builder: (context, constraints) => Listener(
        key: widget.onDismiss == null
            ? null
            : const ValueKey('concept_browse_photo_dismiss_pointer'),
        onPointerDown: widget.onDismiss == null
            ? null
            : (event) {
                if (mounted && epoch == _renderEpoch) {
                  _dismissPointers.add(event.pointer);
                }
              },
        onPointerUp: widget.onDismiss == null
            ? null
            : (event) {
                if (mounted && epoch == _renderEpoch) {
                  _dismissPointers.remove(event.pointer);
                }
              },
        onPointerCancel: widget.onDismiss == null
            ? null
            : (event) => _cancelDismissPointer(event, epoch),
        child: GestureDetector(
          key: const ValueKey('concept_browse_photo_gallery'),
          behavior: HitTestBehavior.opaque,
          onTapUp: (details) => _tapPhoto(details, constraints.maxWidth),
          onVerticalDragStart: widget.onDismiss == null
              ? null
              : (_) => _startDismissDrag(epoch),
          onVerticalDragUpdate: widget.onDismiss == null
              ? null
              : (details) => _updateDismissDrag(details, epoch),
          onVerticalDragEnd: widget.onDismiss == null
              ? null
              : (details) =>
                    _endDismissDrag(details, constraints.maxHeight, epoch),
          onVerticalDragCancel: widget.onDismiss == null
              ? null
              : () => _cancelDismissDrag(epoch),
          child: Transform.translate(
            key: widget.onDismiss == null
                ? null
                : const ValueKey('concept_browse_photo_dismiss_surface'),
            offset: Offset(0, _dismissOffset),
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: widget.imageBuilder(context, photo),
                ),
                if (photos.length > 1)
                  Positioned(
                    left: 22,
                    right: 22,
                    top: MediaQuery.paddingOf(context).top + 12,
                    child: IgnorePointer(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (var i = 0; i < photos.length; i++)
                            Container(
                              key: ValueKey('concept_browse_photo_dot_$i'),
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              width: 28,
                              height: 3,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(3),
                                color: Colors.white.withValues(
                                  alpha: i == _photoIndex ? 1 : .5,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                Positioned(
                  left: 22,
                  right: 22,
                  bottom: identityBottom,
                  child: IgnorePointer(
                    child: _InspectionIdentity(profile: profile),
                  ),
                ),
                if (widget.showActions)
                  Positioned(
                    left: 22,
                    right: 22,
                    bottom: actionsBottom,
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: SelahOneJourneyConnectionsActionButton(
                            invitationSent: widget.invitationSent,
                            action: SelahOneJourneyConnectionsAction(
                              key: widget.requestKey,
                              label: widget.requestLabel,
                              icon: Icons.route_outlined,
                              onTap: widget.onRequest,
                            ),
                            primary: true,
                          ),
                        ),
                        if (widget.showSave) ...[
                          const SizedBox(width: 14),
                          Expanded(
                            child: SelahOneJourneyConnectionsActionButton(
                              action: SelahOneJourneyConnectionsAction(
                                key: widget.saveKey,
                                label: widget.saved ? 'Saved' : 'Save',
                                icon: widget.saved
                                    ? Icons.bookmark
                                    : Icons.bookmark_border,
                                onTap: widget.onSave,
                              ),
                              primary: true,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                SafeArea(
                  bottom: false,
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8, left: 22),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.onPreviousProfile != null)
                            _PhotoIcon(
                              key: widget.previousKey,
                              label: 'Previous profile · no decision',
                              icon: Icons.chevron_left,
                              onTap: widget.onPreviousProfile!,
                            ),
                          if (widget.onNextProfile != null)
                            _PhotoIcon(
                              key: widget.nextKey,
                              label: 'Next profile · no decision',
                              icon: Icons.chevron_right,
                              onTap: widget.onNextProfile!,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (widget.showMenu)
                  SafeArea(
                    bottom: false,
                    child: Align(
                      alignment: widget.menuOnLeft
                          ? Alignment.topLeft
                          : Alignment.topRight,
                      child: Padding(
                        padding: EdgeInsets.only(
                          top: 8,
                          left: widget.menuOnLeft ? 22 : 0,
                          right: widget.menuOnLeft ? 0 : 22,
                        ),
                        child:
                            (widget.menuButton == null
                                ? null
                                : SizedBox.square(
                                    dimension: 40,
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        color: SelahColors.surface,
                                        border: Border.all(
                                          color: SelahColors.line,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: widget.menuButton,
                                    ),
                                  )) ??
                            _PhotoIcon(
                              key: widget.menuKey,
                              label: widget.menuLabel,
                              icon: widget.menuIcon,
                              onTap: widget.onMenu,
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
}

/// No separate inspection master exists: retain its identity hierarchy while
/// applying LOCK 1's explicit flat card and member-name roles.
class _InspectionIdentity extends StatelessWidget {
  const _InspectionIdentity({required this.profile});
  final SeekerProfile profile;

  @override
  Widget build(BuildContext context) {
    final surname = (profile.surnameLine ?? '').trim();
    final city = profile.city.trim();
    final hasCity = city.isNotEmpty && city != '—';
    final meta = profile.age > 0
        ? (hasCity ? '${profile.age} · $city' : '${profile.age}')
        : (hasCity ? city : '');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SelahColors.surface,
        border: Border.all(color: SelahColors.line),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(profile.firstName, style: SelahText.memberName()),
          if (surname.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(surname, style: SelahText.memberName()),
          ],
          if (meta.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              meta,
              style: SelahText.subtext(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

class _PhotoIcon extends StatelessWidget {
  const _PhotoIcon({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    child: Tooltip(
      message: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: SelahColors.surface,
            border: Border.all(color: SelahColors.line),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 23, color: SelahColors.inkColor),
        ),
      ),
    ),
  );
}

/// The current Connections header and swipe-linked segment control. Pages
/// keep independent scroll positions; changing methodology does not replace
/// the app's established page motion with a conditional Column.
class SelahOneJourneyConnectionsPresentation extends StatefulWidget {
  const SelahOneJourneyConnectionsPresentation({
    super.key,
    required this.labels,
    required this.pages,
    required this.selectedIndex,
    required this.onChanged,
    this.segmentKeys = const [],
    this.badges = const [],
    this.bottomPadding = 100,
    this.pageTopPadding = 16,
    this.title = 'Connections',
    this.titleAlignment = Alignment.centerLeft,
    this.fillSinglePage = false,
    this.singlePageMaxHeight,
    this.expandedCard,
    this.onBack,
  }) : assert(labels.length == pages.length),
       assert(selectedIndex >= 0 && selectedIndex < labels.length);

  final List<String> labels;
  final List<List<Widget>> pages;
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final List<Key> segmentKeys;
  final List<int> badges;
  final double bottomPadding;
  final double pageTopPadding;
  final String title;
  final Alignment titleAlignment;
  final bool fillSinglePage;
  final double? singlePageMaxHeight;
  final Widget? expandedCard;
  final VoidCallback? onBack;

  @override
  State<SelahOneJourneyConnectionsPresentation> createState() =>
      _SelahOneJourneyConnectionsPresentationState();
}

class _SelahOneJourneyConnectionsPresentationState
    extends State<SelahOneJourneyConnectionsPresentation> {
  late final PageController _pager;
  late double _position;
  int _renderRevision = 0;
  int _selectionRevision = 0;

  @override
  void initState() {
    super.initState();
    _position = widget.selectedIndex.toDouble();
    _pager = PageController(initialPage: widget.selectedIndex, keepPage: false);
    _pager.addListener(_onScroll);
  }

  void _onScroll() {
    final page = _pager.page;
    if (page != null && mounted && page != _position) {
      setState(() => _position = page);
    }
  }

  void _select(int index) {
    if (!mounted ||
        !_pager.hasClients ||
        index < 0 ||
        index >= widget.pages.length) {
      return;
    }
    _selectionRevision++;
    if (MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context)) {
      _pager.jumpToPage(index);
    } else {
      unawaited(SelahSegmentedMotion.animateToPage(_pager, index));
    }
  }

  @override
  void didUpdateWidget(covariant SelahOneJourneyConnectionsPresentation old) {
    super.didUpdateWidget(old);
    final selection = ++_selectionRevision;
    final target = widget.selectedIndex;
    if (old.selectedIndex != widget.selectedIndex &&
        _position.round() != widget.selectedIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted &&
            selection == _selectionRevision &&
            target == widget.selectedIndex) {
          _select(target);
        }
      });
    }
  }

  @override
  void dispose() {
    _pager.removeListener(_onScroll);
    _pager.dispose();
    super.dispose();
  }

  Widget _filledPage(BuildContext context, BoxConstraints constraints) {
    // Reserve the expanded bar, not just its resting height, so a press cannot
    // cover the last card. Content uses the real remaining viewport height.
    final bottom =
        math.max(
          MediaQuery.paddingOf(context).bottom,
          SelahNavBarMetrics.bottomInset,
        ) +
        SelahNavBarMetrics.height +
        12;
    final available = math.max(
      0.0,
      constraints.maxHeight - widget.pageTopPadding - bottom,
    );
    final minimum = math.min(
      available,
      widget.singlePageMaxHeight ?? available,
    );
    return SingleChildScrollView(
      key: const PageStorageKey('concept_connections_page_0'),
      physics: const ClampingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(20, widget.pageTopPadding, 20, bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: minimum),
        child: IntrinsicHeight(
          // Equal cards fill the viewport when readable content fits. Intrinsic
          // height wins on short screens/large text, preserving real scrolling
          // rather than clipping, overflowing or reducing the user's font.
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final child in widget.pages.single)
                if (child is SizedBox) child else Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }

  Widget _expandedPage(BuildContext context) {
    final bottom =
        math.max(
          MediaQuery.paddingOf(context).bottom,
          SelahNavBarMetrics.bottomInset,
        ) +
        SelahNavBarMetrics.height +
        12;
    final quiet =
        MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context);
    // One finite card viewport replaces the whole list; no outgoing cards
    // remain mounted, interactive or exposed to assistive technology.
    return Padding(
      padding: EdgeInsets.fromLTRB(20, widget.pageTopPadding, 20, bottom),
      child: quiet
          ? widget.expandedCard
          : TweenAnimationBuilder<double>(
              key: const ValueKey('journey_card_options_expansion'),
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) => Transform.translate(
                offset: Offset(0, (1 - value) * 8),
                child: Opacity(opacity: .9 + value * .1, child: child),
              ),
              child: widget.expandedCard,
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final revision = ++_renderRevision;
    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Align(
                    alignment: widget.titleAlignment,
                    child: Text(
                      widget.title,
                      key: const ValueKey('concept_connections_title'),
                      textAlign: widget.titleAlignment.x > 0
                          ? TextAlign.right
                          : TextAlign.left,
                      style: SelahText.pageTitle(),
                    ),
                  ),
                ),
                if (widget.onBack != null)
                  IconButton(
                    key: const ValueKey('concept_activity_back'),
                    tooltip: 'Back',
                    onPressed: widget.onBack,
                    icon: Icon(
                      Icons.arrow_back,
                      color: SelahColors.accentOnCanvas,
                    ),
                  ),
              ],
            ),
          ),
          if (widget.labels.length > 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
              child: SelahSegmentedToggle(
                labels: widget.labels,
                position: _position,
                badges: widget.badges,
                segmentKeys: widget.segmentKeys,
                onChanged: (index) {
                  if (mounted && revision == _renderRevision) _select(index);
                },
              ),
            ),
          Expanded(
            child: widget.expandedCard != null
                ? _expandedPage(context)
                : widget.fillSinglePage && widget.pages.length == 1
                ? LayoutBuilder(
                    builder: (context, constraints) =>
                        _filledPage(context, constraints),
                  )
                : PageView(
                    controller: _pager,
                    physics: SelahSegmentedMotion.pagePhysics,
                    onPageChanged: widget.onChanged,
                    children: [
                      for (var index = 0; index < widget.pages.length; index++)
                        ListView(
                          key: PageStorageKey(
                            'concept_connections_page_$index',
                          ),
                          padding: EdgeInsets.fromLTRB(
                            20,
                            widget.pageTopPadding,
                            20,
                            widget.bottomPadding,
                          ),
                          children: widget.pages[index],
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

/// Current Connections accent-marker section heading, including its text case.
class SelahOneJourneyConnectionsSectionHeading extends StatelessWidget {
  const SelahOneJourneyConnectionsSectionHeading({
    super.key,
    required this.title,
    this.emphasised = false,
  });

  final String title;
  final bool emphasised;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 3,
        height: 28,
        decoration: BoxDecoration(
          color: SelahColors.accentOnCanvas.withValues(alpha: .85),
          borderRadius: BorderRadius.circular(999),
        ),
      ),
      const SizedBox(width: 9),
      Expanded(
        child: Text(
          title,
          style: SelahText.body(
            size: emphasised ? 16 : 14.5,
            color: emphasised ? SelahColors.foreground : SelahColors.ink(.82),
          ),
        ),
      ),
    ],
  );
}

class SelahOneJourneyConnectionsAction {
  const SelahOneJourneyConnectionsAction({
    required this.label,
    required this.icon,
    required this.onTap,
    this.key,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final Key? key;
}

/// The live Compact Chips action, with caller-owned draft callbacks.
class SelahOneJourneyConnectionsActionButton extends StatelessWidget {
  const SelahOneJourneyConnectionsActionButton({
    super.key,
    required this.action,
    this.primary = false,
    this.invitationSent,
  });

  final SelahOneJourneyConnectionsAction action;
  final bool primary;
  final bool? invitationSent;

  @override
  Widget build(BuildContext context) {
    final tint = primary ? SelahColors.onLake : SelahColors.inkColor;
    final button = Material(
      color: primary ? SelahColors.lake : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: primary ? SelahColors.lake : SelahColors.line,
          ),
        ),
        child: InkWell(
          key: action.key,
          borderRadius: BorderRadius.circular(12),
          onTap: action.onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: primary ? 18 : 14,
              vertical: primary ? 15 : 10,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (action.icon != null) ...[
                  Icon(action.icon, size: 14, color: tint),
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: invitationSent != null
                      ? SelahInvitationLabel(
                          label: action.label,
                          sent: invitationSent!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: SelahText.button(
                            size: primary ? 15 : 13.5,
                            color: tint,
                          ),
                        )
                      : Text(
                          action.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: SelahText.button(
                            size: primary ? 15 : 13.5,
                            color: tint,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (invitationSent == null) return button;
    return Semantics(
      button: true,
      enabled: action.onTap != null,
      label: invitationSent == true
          ? '${action.label}. Tap to cancel invitation'
          : action.label,
      onTap: action.onTap,
      excludeSemantics: true,
      child: SelahPressFeedback(enabled: action.onTap != null, child: button),
    );
  }
}

class SelahOneJourneyConnectionsActionDeck extends StatelessWidget {
  const SelahOneJourneyConnectionsActionDeck({
    super.key,
    required this.primary,
    this.actions = const [],
    this.journeyReference,
    this.primaryTrailing,
  });

  final SelahOneJourneyConnectionsAction primary;
  final List<SelahOneJourneyConnectionsAction> actions;
  final Widget? journeyReference;
  final Widget? primaryTrailing;

  Widget get primaryRow => primaryTrailing == null
      ? SelahOneJourneyConnectionsActionButton(action: primary, primary: true)
      : Row(
          children: [
            Expanded(
              child: SelahOneJourneyConnectionsActionButton(
                action: primary,
                primary: true,
              ),
            ),
            const SizedBox(width: 7),
            primaryTrailing!,
          ],
        );

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      primaryRow,
      if (journeyReference != null) ...[
        const SizedBox(height: 10),
        journeyReference!,
      ],
      if (actions.isNotEmpty) ...[
        const SizedBox(height: 9),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = actions.length.clamp(1, 3);
            final width = (constraints.maxWidth - 7 * (columns - 1)) / columns;
            return Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                for (final action in actions)
                  SizedBox(
                    width: width,
                    child: SelahOneJourneyConnectionsActionButton(
                      action: action,
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    ],
  );
}

/// Current persistent identity row with an inline expanding action deck. A
/// shared optional controller retains the production one-open-card behaviour.
class SelahOneJourneyConnectionsPersonCard extends StatefulWidget {
  const SelahOneJourneyConnectionsPersonCard({
    super.key,
    required this.profile,
    required this.subtitle,
    required this.actions,
    required this.cardId,
    this.controller,
    this.imageBuilder = _profileImage,
    this.onReport,
    this.headerKey,
    this.dimmed = false,
  });

  final SeekerProfile profile;
  final String subtitle;
  final Widget actions;
  final String cardId;
  final SelahConnectionsExpansionController? controller;
  final SelahOneJourneyPhotoBuilder imageBuilder;
  final VoidCallback? onReport;
  final Key? headerKey;
  final bool dimmed;

  @override
  State<SelahOneJourneyConnectionsPersonCard> createState() =>
      _SelahOneJourneyConnectionsPersonCardState();
}

class _SelahOneJourneyConnectionsPersonCardState
    extends State<SelahOneJourneyConnectionsPersonCard> {
  final GlobalKey _cardKey = GlobalKey();
  late final SelahConnectionsExpansionController _ownController;
  Timer? _settleTimer;

  SelahConnectionsExpansionController get _controller =>
      widget.controller ?? _ownController;

  @override
  void initState() {
    super.initState();
    _ownController = SelahConnectionsExpansionController();
  }

  void _ensureVisible() {
    final target = _cardKey.currentContext;
    if (!mounted || target == null || _controller.value != widget.cardId) {
      return;
    }
    unawaited(
      Scrollable.ensureVisible(
        target,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
        alignment: 0,
      ),
    );
  }

  void _toggle() {
    _settleTimer?.cancel();
    if (_controller.value == widget.cardId) {
      _controller.close(widget.cardId);
    } else {
      _controller.open(widget.cardId);
      WidgetsBinding.instance.addPostFrameCallback((_) => _ensureVisible());
      _settleTimer = Timer(const Duration(milliseconds: 240), _ensureVisible);
    }
  }

  @override
  void dispose() {
    _settleTimer?.cancel();
    _ownController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<String?>(
    valueListenable: _controller,
    builder: (context, selected, _) {
      final open = selected == widget.cardId;
      final profile = widget.profile;
      final reduceMotion =
          MediaQuery.disableAnimationsOf(context) ||
          MediaQuery.accessibleNavigationOf(context);
      return Opacity(
        opacity: widget.dimmed && !open ? .65 : 1,
        child: Padding(
          key: _cardKey,
          padding: const EdgeInsets.only(bottom: 10),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: open
                  ? SelahColors.surfaceEmphasisFill
                  : SelahColors.surfaceFill,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: open
                    ? SelahColors.surfaceEmphasisBorder
                    : SelahColors.surfaceBorder,
                width: 1,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: Column(
                children: [
                  InkWell(
                    key: widget.headerKey,
                    borderRadius: BorderRadius.circular(14),
                    onTap: _toggle,
                    child: Padding(
                      padding: const EdgeInsets.all(SelahCardMetrics.padding),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(
                              SelahCardMetrics.thumbRadius,
                            ),
                            child: SizedBox(
                              width: SelahCardMetrics.thumb,
                              height: SelahCardMetrics.thumb,
                              child: widget.imageBuilder(
                                context,
                                profile.photoUrl,
                              ),
                            ),
                          ),
                          const SizedBox(width: SelahCardMetrics.gap),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  profile.age > 0
                                      ? '${profile.firstName}, ${profile.age}'
                                      : profile.firstName,
                                  style: SelahText.body(
                                    size: 14,
                                    color: SelahColors.foreground,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  widget.subtitle,
                                  style: SelahText.subtext(size: 11.5),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          if (!open)
                            SizedBox(
                              width: 32,
                              child: Icon(
                                Icons.keyboard_arrow_down,
                                color: SelahColors.ink(.38),
                                size: 20,
                              ),
                            )
                          else if (widget.onReport != null)
                            _ReportFlag(
                              firstName: profile.firstName,
                              onTap: widget.onReport!,
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (reduceMotion)
                    if (open)
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: widget.actions,
                      )
                    else
                      const SizedBox(width: double.infinity)
                  else
                    AnimatedCrossFade(
                      duration: const Duration(milliseconds: 200),
                      crossFadeState: open
                          ? CrossFadeState.showSecond
                          : CrossFadeState.showFirst,
                      firstChild: const SizedBox(width: double.infinity),
                      secondChild: Padding(
                        padding: const EdgeInsets.all(12),
                        child: widget.actions,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

/// Current Active Journey card, compact only for a multi-Journey overview.
/// Its normal single-Journey geometry remains unchanged. The person header is
/// not a disguised navigation target: only supplied labelled actions act.
class SelahOneJourneyConnectionsActiveCard extends StatelessWidget {
  const SelahOneJourneyConnectionsActiveCard({
    super.key,
    required this.profile,
    required this.actions,
    this.imageBuilder = _profileImage,
    this.onReport,
    this.stateLabel,
    this.compact = false,
    this.fillHeight = false,
    this.cardDesign = SelahOneJourneyCardDesign.classic,
    this.primaryAction,
    this.stageLabel,
    this.inlineOptions,
    this.inlineOptionsFillHeight = true,
  });

  final SeekerProfile profile;
  final Widget actions;
  final SelahOneJourneyPhotoBuilder imageBuilder;
  final VoidCallback? onReport;
  final String? stateLabel;
  final bool compact;
  final bool fillHeight;
  final SelahOneJourneyCardDesign cardDesign;
  final Widget? primaryAction;
  final String? stageLabel;
  final Widget? inlineOptions;
  final bool inlineOptionsFillHeight;

  double _originalSingleInteriorHeight(BuildContext context, double width) {
    // Measure the existing single-card text, including its real inherited
    // line metrics and wrapping. This preserves its envelope without fixing
    // a pixel height that only works for one font or text scale.
    double textHeight(
      String text,
      TextStyle style,
      double maxWidth, {
      bool singleLine = false,
    }) {
      var inherited = DefaultTextStyle.of(context).style.merge(style);
      if (MediaQuery.boldTextOf(context)) {
        inherited = inherited.merge(
          const TextStyle(fontWeight: FontWeight.bold),
        );
      }
      final painter = TextPainter(
        text: TextSpan(text: text, style: inherited),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        locale: Localizations.maybeLocaleOf(context),
        maxLines: singleLine ? 1 : null,
        ellipsis: singleLine ? '…' : null,
      )..layout(maxWidth: math.max(1, maxWidth));
      final height = painter.height;
      painter.dispose();
      return height;
    }

    // The locked layout retains its original reference envelope even after
    // moving Report into options. Removing that visible glyph must not shrink
    // the natural single-card rectangle through wider reference text wrapping.
    final referenceReportWidth =
        cardDesign == SelahOneJourneyCardDesign.quietMinimal || onReport != null
        ? _ReportFlag.tapTargetExtent
        : 0;
    final identityWidth = width - 96 - 16 - referenceReportWidth;
    var identity = textHeight(
      profile.firstName,
      SelahText.rowTitle(),
      identityWidth,
    );
    if ((profile.surnameLine ?? '').trim().isNotEmpty) {
      identity += textHeight(
        profile.surnameLine!.trim(),
        SelahText.rowTitle(),
        identityWidth,
      );
    }
    identity +=
        6 +
        textHeight(
          '${profile.age} · ${profile.city}',
          SelahText.subtext(size: 12.5),
          identityWidth,
        );
    if (stateLabel != null) {
      identity +=
          8 +
          textHeight(stateLabel!, SelahText.subtext(size: 11), identityWidth);
    }
    final deck = actions;
    final label = deck is SelahOneJourneyConnectionsActionDeck
        ? deck.primary.label
        : 'View Journey';
    final button =
        math.max(
          14.0,
          textHeight(
            label,
            SelahText.button(size: 12.5),
            width - 50,
            singleLine: true,
          ),
        ) +
        24; // 22px explicit padding + Ink's 1px border on each edge.
    final reference = stageLabel == null
        ? 0.0
        : 10 + textHeight(stageLabel!, SelahText.subtext(size: 11), width);
    return math.max(96.0, identity) + 16 + button + reference;
  }

  Widget _alternateContent(BuildContext context) {
    final content = SelahOneJourneyCardContent(
      design: cardDesign,
      profile: profile,
      photo: imageBuilder(context, profile.photoUrl),
      action: primaryAction ?? actions,
      fillHeight: fillHeight || !compact,
      stateLabel: stateLabel,
      stageLabel: stageLabel,
      inlineOptions: inlineOptions,
      inlineOptionsFillHeight: inlineOptionsFillHeight,
      report: onReport == null
          ? null
          : _ReportFlag(firstName: profile.firstName, onTap: onReport!),
    );
    // Only a single natural-height card uses this measurement. Multi-card
    // interiors remain compatible with the page's IntrinsicHeight layout.
    return !compact && !fillHeight
        ? LayoutBuilder(
            builder: (context, constraints) => IntrinsicHeight(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: _originalSingleInteriorHeight(
                    context,
                    constraints.maxWidth,
                  ),
                ),
                child: content,
              ),
            ),
          )
        : content;
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: compact ? 0 : 14),
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: SelahColors.surfaceFill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: SelahColors.line),
      ),
      child: Material(
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: cardDesign != SelahOneJourneyCardDesign.classic
              ? Builder(builder: _alternateContent)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: SizedBox(
                            width: 56,
                            height: 56,
                            child: imageBuilder(context, profile.photoUrl),
                          ),
                        ),
                        SizedBox(width: compact ? 12 : 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (compact)
                                Text.rich(
                                  TextSpan(
                                    text: profile.firstName,
                                    children: [
                                      if ((profile.surnameLine ?? '')
                                          .trim()
                                          .isNotEmpty)
                                        TextSpan(
                                          text:
                                              ' ${profile.surnameLine!.trim()}',
                                          style: SelahText.heading(
                                            size: 15,
                                            color: SelahColors.ink(.86),
                                          ),
                                        ),
                                    ],
                                  ),
                                  style: SelahText.rowTitle(),
                                )
                              else
                                Text(
                                  profile.firstName,
                                  style: SelahText.rowTitle(),
                                ),
                              if (!compact &&
                                  (profile.surnameLine ?? '').trim().isNotEmpty)
                                Text(
                                  profile.surnameLine!.trim(),
                                  style: SelahText.heading(
                                    size: 15,
                                    color: SelahColors.ink(.86),
                                  ),
                                ),
                              SizedBox(height: compact ? 4 : 6),
                              Text(
                                '${profile.age} · ${profile.city}',
                                style: SelahText.subtext(
                                  size: 12.5,
                                  color: SelahColors.ink(.78),
                                ),
                              ),
                              if (stateLabel != null) ...[
                                SizedBox(height: compact ? 4 : 8),
                                Text(
                                  stateLabel!,
                                  style: SelahText.subtext(size: 11),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (onReport != null)
                          _ReportFlag(
                            firstName: profile.firstName,
                            onTap: onReport!,
                          ),
                      ],
                    ),
                    SizedBox(height: compact ? 8 : 16),
                    if (fillHeight) const Spacer(),
                    actions,
                  ],
                ),
        ),
      ),
    ),
  );
}

class _ReportFlag extends StatelessWidget {
  const _ReportFlag({required this.firstName, required this.onTap});

  static const double tapTargetExtent = 44;

  final String firstName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    button: true,
    label: 'Report $firstName',
    onTap: onTap,
    excludeSemantics: true,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      excludeFromSemantics: true,
      onTap: onTap,
      child: SizedBox(
        width: tapTargetExtent,
        height: tapTargetExtent,
        // The same 15px glyph stays at the header's original top-right edge;
        // only the invisible hit area grows downwards and towards the identity.
        child: Align(
          alignment: Alignment.topRight,
          child: Icon(
            Icons.flag_outlined,
            size: 15,
            color: SelahColors.ink(.75),
          ),
        ),
      ),
    ),
  );
}
