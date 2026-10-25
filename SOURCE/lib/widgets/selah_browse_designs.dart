// Shared Portrait Browse with caller-owned identity, selection and actions.
// This presenter owns only per-profile gallery position and layout. It has no
// services, account, matching, admission, entitlement or persistence authority.
// Photo rendering is required and explicitly supplied by the caller; this
// widget has no default image provider or ability to fetch a photo.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../models/seeker_profile.dart';
import '../theme/selah_card_metrics.dart';
import '../theme/selah_colors.dart';
import '../theme/selah_interaction_style.dart';
import '../theme/selah_text.dart';
import 'floating_nav_bar.dart';
import 'selah_browse_options_button.dart';
import 'selah_browse_next_photo_motion.dart';
import 'selah_invitation_label.dart';
import 'selah_invitation_outline.dart';
import 'selah_press_feedback.dart';
import 'selah_profile_name_block.dart';

/// Explicit rendering seam. The caller supplies already-authorised photo
/// references and the renderer; a reference alone never initiates a fetch here.
/// Dimensions and alignment preserve the current bounded photo presentation.
typedef SelahBrowsePhotoBuilder =
    Widget Function(
      BuildContext context,
      String photo, {
      required double width,
      required double height,
      required Alignment alignment,
    });

enum SelahOneJourneyBrowseDesign {
  portraitCard(
    'Portrait card',
    'A bounded swipeable photo gallery, with identity on the photo.',
  );

  const SelahOneJourneyBrowseDesign(this.label, this.description);

  final String label;
  final String description;
}

/// Bounded Portrait Browse with caller-owned selection and actions.
/// Previous/Next are neutral navigation, never Pass or Dislike.
class SelahBrowseDesigns extends StatefulWidget {
  const SelahBrowseDesigns({
    super.key,
    required this.profiles,
    required this.selectedIndex,
    required this.design,
    required this.photoBuilder,
    this.onPrevious,
    this.onNext,
    this.onFilters,
    this.onBrowseMenu,
    this.onProfile,
    this.onRequest,
    this.onSave,
    this.showSave = true,
    this.savedIds = const <String>{},
    this.requestLabel,
    this.invitationSent,
    this.canRequest,
    this.bottomPadding = 100,
    this.alignHeaderActions = false,
    this.nextProfileMotion = SelahBrowseNextMotion.current,
    this.nextProfileMotionEpoch = 0,
    this.hapticLevel,
  });

  final List<SeekerProfile> profiles;
  final SelahBrowsePhotoBuilder photoBuilder;
  final int selectedIndex;
  final SelahOneJourneyBrowseDesign design;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback? onFilters;
  final ValueChanged<SeekerProfile?>? onBrowseMenu;
  final ValueChanged<SeekerProfile>? onProfile;
  final ValueChanged<SeekerProfile>? onRequest;
  final ValueChanged<SeekerProfile>? onSave;
  final bool showSave;
  final Set<String> savedIds;
  final String Function(SeekerProfile)? requestLabel;
  final bool Function(SeekerProfile)? invitationSent;
  final bool Function(SeekerProfile)? canRequest;
  final double bottomPadding;
  final bool alignHeaderActions;
  // Optional presentation-only preview. Callers own selection and actions;
  // unchanged default and token zero preserve all existing shared callers.
  final SelahBrowseNextMotion nextProfileMotion;
  final int nextProfileMotionEpoch;

  /// Explicit local feedback choice. Null preserves member preferences.
  final SelahHapticLevel? hapticLevel;

  @override
  State<SelahBrowseDesigns> createState() => _SelahBrowseDesignsState();
}

class _SelahBrowseDesignsState extends State<SelahBrowseDesigns> {
  static const _backPillWidth = 50.0;
  static const _nextPillWidth = 72.0;
  static const _footerGap = 8.0;
  static const _pillBorderExtent = 2.0;
  static const _pillMinTapHeight = 48.0;
  static const _pillHorizontalTextPadding = 10.0;
  static const _pillVerticalPadding = 8.0;
  final Map<String, int> _photoIndices = <String, int>{};
  final Map<String, GlobalKey> _cardAnchors = <String, GlobalKey>{};
  int _layoutRevision = 0;

  String? get _selectedId => widget.profiles.isEmpty
      ? null
      : widget
            .profiles[widget.selectedIndex.clamp(0, widget.profiles.length - 1)]
            .id;

  int _photoIndex(SeekerProfile profile) {
    if (profile.photos.isEmpty) return 0;
    return (_photoIndices[profile.id] ?? 0).clamp(0, profile.photos.length - 1);
  }

  @override
  void didUpdateWidget(covariant SelahBrowseDesigns oldWidget) {
    super.didUpdateWidget(oldWidget);
    final currentIds = widget.profiles.map((profile) => profile.id).toSet();
    _photoIndices.removeWhere((id, _) => !currentIds.contains(id));
    _cardAnchors.removeWhere((id, _) => !currentIds.contains(id));
    final oldSelectedId = oldWidget.profiles.isEmpty
        ? null
        : oldWidget
              .profiles[oldWidget.selectedIndex.clamp(
                0,
                oldWidget.profiles.length - 1,
              )]
              .id;
    if (oldSelectedId != _selectedId) {
      // Profile navigation starts at that person's first photo; swiping
      // photos is not a profile decision or navigation event.
      _photoIndices.remove(_selectedId);
    }
    ++_layoutRevision;
  }

  void _selectPhoto(SeekerProfile profile, int index, int revision) {
    if (!mounted ||
        revision != _layoutRevision ||
        !_isCurrent(profile) ||
        profile.photos.isEmpty ||
        index < 0 ||
        index >= profile.photos.length ||
        index == _photoIndex(profile)) {
      return;
    }
    unawaited(
      SelahInteractionStyle.emitSelectionHaptic(level: widget.hapticLevel),
    );
    setState(() {
      _photoIndices[profile.id] = index;
    });
  }

  bool _isCurrent(SeekerProfile profile) =>
      widget.profiles.isNotEmpty &&
      widget
              .profiles[widget.selectedIndex.clamp(
                0,
                widget.profiles.length - 1,
              )]
              .id ==
          profile.id;

  Widget _identity(
    SeekerProfile profile, {
    double nameSize = 28,
    bool onPhoto = false,
  }) => KeyedSubtree(
    key: ValueKey('concept_browse_identity_${profile.id}'),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SelahProfileNameBlock(
          profile: profile,
          nameSize: nameSize,
          onPhoto: onPhoto,
        ),
        for (final detail in [
          if (profile.publicNationality?.trim().isNotEmpty ?? false)
            'Nationality: ${profile.publicNationality!.trim()}',
          if (profile.publicEthnicity?.trim().isNotEmpty ?? false)
            'Ethnicity: ${profile.publicEthnicity!.trim()}',
        ]) ...[
          const SizedBox(height: 4),
          Text(
            detail,
            style: SelahText.body(
              size: 12,
              color: SelahColors.ink(.85),
            ).copyWith(shadows: onPhoto ? kSelahOnPhotoTextShadows : null),
          ),
        ],
      ],
    ),
  );

  Widget _surface({
    required SeekerProfile profile,
    required Widget child,
    bool selectOnTap = false,
    bool edgeToEdge = false,
  }) {
    // Snapshot the guarded caller delegate for this render. An old card
    // callback must not borrow a newer delegate after Next or a route change.
    final onProfile = widget.onProfile;
    return Material(
      key: _cardAnchors.putIfAbsent(profile.id, GlobalKey.new),
      color: edgeToEdge ? Colors.transparent : SelahColors.surfaceFill,
      borderRadius: BorderRadius.circular(SelahCardMetrics.cardRadius),
      clipBehavior: edgeToEdge ? Clip.antiAlias : Clip.none,
      child: Stack(
        children: [
          InkWell(
            key: ValueKey('concept_browse_open_${profile.id}'),
            borderRadius: BorderRadius.circular(SelahCardMetrics.cardRadius),
            onTap: selectOnTap && onProfile != null
                ? () => onProfile(profile)
                : null,
            child: Padding(
              // Portrait uses the same outer bounds, with the photo filling
              // its former inset.
              padding: edgeToEdge
                  ? EdgeInsets.zero
                  : const EdgeInsets.all(SelahCardMetrics.padding + 1),
              child: child,
            ),
          ),
          Positioned.fill(
            child: SelahInvitationOutline(
              key: ValueKey('browse_invitation_outline_${profile.id}'),
              sent: widget.invitationSent?.call(profile) == true,
              borderRadius: BorderRadius.circular(SelahCardMetrics.cardRadius),
            ),
          ),
        ],
      ),
    );
  }

  Widget _studyPhoto(
    SeekerProfile profile,
    int index,
    double height, {
    String keyPrefix = 'concept_browse_photo',
    bool rounded = true,
  }) {
    final photo = profile.photos.isEmpty
        ? ''
        : profile.photos[index.clamp(0, profile.photos.length - 1)];
    final renderedPhoto = widget.photoBuilder(
      context,
      photo,
      width: double.infinity,
      height: height,
      alignment: Alignment.topCenter,
    );
    return SizedBox(
      key: ValueKey('${keyPrefix}_${profile.id}_$index'),
      height: height,
      width: double.infinity,
      child: rounded
          ? ClipRRect(
              borderRadius: BorderRadius.circular(SelahCardMetrics.thumbRadius),
              child: renderedPhoto,
            )
          : renderedPhoto,
    );
  }

  Widget _swipeGallery(
    SeekerProfile profile,
    double height, {
    bool identityOnPhoto = false,
    bool sideIndicators = false,
    bool tapToAdvance = false,
  }) {
    final revision = _layoutRevision;
    return _BrowsePhotoPager(
      key: ValueKey('concept_browse_pager_${profile.id}'),
      profileId: profile.id,
      photoSources: List<String>.unmodifiable(profile.photos),
      photoCount: math.max(1, profile.photos.length),
      selectedIndex: _photoIndex(profile),
      height: height,
      // Only the outer Current viewport is rounded. Rounding each sliding
      // photo creates dark triangular notches at their moving seam.
      photo: (index) =>
          _studyPhoto(profile, index, height, rounded: !tapToAdvance),
      onPageChanged: (index) => _selectPhoto(profile, index, revision),
      overlay: identityOnPhoto ? _identity(profile, onPhoto: true) : null,
      sideIndicators: sideIndicators,
      tapToAdvance: tapToAdvance,
    );
  }

  Widget _portraitCard(SeekerProfile profile, double photoHeight) => _surface(
    profile: profile,
    edgeToEdge: true,
    child: _swipeGallery(
      profile,
      photoHeight + 2 * SelahCardMetrics.padding + 2,
      identityOnPhoto: true,
      sideIndicators: true,
      tapToAdvance: true,
    ),
  );

  Widget _header() => Row(
    key: const ValueKey('concept_browse_header'),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Text(
          'Browse',
          key: const ValueKey('concept_browse_title'),
          textAlign: TextAlign.left,
          style: SelahText.pageTitle(),
        ),
      ),
      if (widget.onBrowseMenu != null)
        SelahBrowseOptionsButton(
          alignToContentEdge: widget.alignHeaderActions,
          profile: widget.profiles.isEmpty
              ? null
              : widget.profiles[widget.selectedIndex.clamp(
                  0,
                  widget.profiles.length - 1,
                )],
          onOpen: widget.onBrowseMenu!,
        )
      else if (widget.onFilters != null)
        IconButton(
          key: const ValueKey('concept_filters'),
          tooltip: 'Browse filters',
          onPressed: widget.onFilters,
          color: SelahColors.journeyGold,
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          icon: const Icon(Icons.tune, size: 20),
        ),
    ],
  );

  Widget _compactPill({
    required Key key,
    required String label,
    required VoidCallback? onTap,
    IconData? icon,
    double iconSize = 20,
    bool primary = false,
    bool? invitationSent,
    double minimumHeight = _pillMinTapHeight,
  }) => Semantics(
    button: true,
    enabled: onTap != null,
    label: invitationSent == true ? '$label. Tap to cancel invitation' : label,
    onTap: onTap,
    excludeSemantics: true,
    child: SelahPressFeedback(
      enabled: primary && onTap != null,
      child: Material(
        color: SelahColors.isWafaPreview && primary
            ? SelahColors.wafaMint
            : SelahColors.surfaceFill,
        borderRadius: BorderRadius.circular(SelahColors.isWafaPreview ? 14 : 999),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(SelahColors.isWafaPreview ? 14 : 999),
            border: Border.all(
              color: SelahColors.isWafaPreview
                  ? SelahColors.wafaLine
                  : primary
                  ? SelahColors.journeyGold.withValues(
                      alpha: invitationSent == true ? .85 : .55,
                    )
                  : SelahColors.surfaceBorder,
            ),
          ),
          child: InkWell(
            key: key,
            onTap: onTap,
            excludeFromSemantics: true,
            borderRadius: BorderRadius.circular(SelahColors.isWafaPreview ? 14 : 999),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: 48,
                minHeight: minimumHeight,
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: icon == null ? _pillHorizontalTextPadding : 8,
                  vertical: _pillVerticalPadding,
                ),
                child: Center(
                  child: icon == null
                      ? invitationSent != null
                            ? SelahInvitationLabel(
                                label: label,
                                sent: invitationSent,
                                style: _requestStyle(
                                  color: SelahColors.ink(
                                    onTap == null ? .34 : .90,
                                  ),
                                ),
                              )
                            : Text(
                                label,
                                textAlign: TextAlign.center,
                                style: primary
                                    ? _requestStyle(
                                        color: SelahColors.ink(
                                          onTap == null ? .34 : .90,
                                        ),
                                      )
                                    : SelahText.button(
                                        size: 12.5,
                                        color: SelahColors.ink(
                                          onTap == null ? .34 : .90,
                                        ),
                                      ),
                              )
                      : Icon(
                          icon,
                          size: iconSize,
                          color: onTap == null
                              ? SelahColors.ink(.34)
                              : SelahColors.isWafaPreview
                              ? SelahColors.wafaGreen
                              : SelahColors.journeyGold,
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _compactFooter(SeekerProfile? profile) {
    final onPrevious = widget.onPrevious;
    final onNext = widget.onNext;
    final onRequest = widget.onRequest;
    final onSave = widget.onSave;
    final requestAllowed =
        profile != null &&
        onRequest != null &&
        (widget.canRequest?.call(profile) ?? true);
    return LayoutBuilder(
      builder: (context, constraints) => Column(
        key: const ValueKey('concept_browse_footer'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SizedBox(
                width: _backPillWidth,
                child: _compactPill(
                  key: const ValueKey('concept_previous_profile'),
                  label: 'Previous profile · no decision',
                  icon: Icons.chevron_left,
                  onTap: onPrevious,
                ),
              ),
              const SizedBox(width: _footerGap),
              Expanded(
                child: _compactPill(
                  key: ValueKey('draft_profile_${profile?.id ?? 'empty'}'),
                  label: profile == null
                      ? 'Request Journey'
                      : widget.requestLabel?.call(profile) ?? 'Request Journey',
                  primary: true,
                  invitationSent: profile == null
                      ? null
                      : widget.invitationSent?.call(profile),
                  minimumHeight:
                      profile != null && widget.invitationSent != null
                      ? _requestPillHeight(profile, constraints.maxWidth)
                      : _pillMinTapHeight,
                  onTap: requestAllowed ? () => onRequest(profile) : null,
                ),
              ),
              const SizedBox(width: _footerGap),
              SizedBox(
                width: _nextPillWidth,
                child: _compactPill(
                  key: const ValueKey('concept_next_profile'),
                  label: 'Next profile · no decision',
                  icon: Icons.chevron_right,
                  iconSize: 24,
                  onTap: onNext,
                ),
              ),
            ],
          ),
          if (widget.showSave && profile != null) ...[
            const SizedBox(height: 8),
            _compactPill(
              key: ValueKey('concept_save_${profile.id}'),
              label: widget.savedIds.contains(profile.id) ? 'Saved' : 'Save',
              onTap: onSave == null ? null : () => onSave(profile),
            ),
          ],
        ],
      ),
    );
  }

  double _textHeight(String text, TextStyle style, double width) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(maxWidth: math.max(1, width));
    final height = painter.height;
    painter.dispose();
    return height;
  }

  TextStyle _requestStyle({Color? color}) => SelahText.button(
    size: 14,
    color: color,
  ).copyWith(fontWeight: FontWeight.w400, height: 1.25, letterSpacing: .1);

  double _requestTextWidth(double footerWidth) => math.max(
    1.0,
    footerWidth -
        _backPillWidth -
        _nextPillWidth -
        2 * _footerGap -
        _pillBorderExtent -
        2 * _pillHorizontalTextPadding,
  );

  double _requestPillHeight(SeekerProfile? profile, double footerWidth) {
    final labels = [
      profile == null
          ? 'Request Journey'
          : widget.requestLabel?.call(profile) ?? 'Request Journey',
      if (profile != null && widget.invitationSent != null) ...[
        'Request a Journey',
        'Journey invitation sent',
      ],
    ];
    final textHeight = labels
        .map(
          (label) => _textHeight(
            label,
            _requestStyle(),
            _requestTextWidth(footerWidth),
          ),
        )
        .reduce(math.max);
    return math.max(_pillMinTapHeight, 2 * _pillVerticalPadding + textHeight);
  }

  double _identityMinimumHeight(SeekerProfile profile, double width) {
    var height = _textHeight(
      profile.firstName,
      SelahText.heading(size: 28).copyWith(fontWeight: FontWeight.w600),
      width,
    );
    if (profile.surnameLine?.trim().isNotEmpty ?? false) {
      height +=
          2 +
          _textHeight(
            profile.surnameLine!.trim(),
            SelahText.heading(size: 16.8).copyWith(fontWeight: FontWeight.w500),
            width,
          );
    }
    height += 4 + _textHeight('28 · City', SelahText.body(size: 14.924), width);
    for (final detail in [
      if (profile.publicNationality?.trim().isNotEmpty ?? false)
        'Nationality: ${profile.publicNationality!.trim()}',
      if (profile.publicEthnicity?.trim().isNotEmpty ?? false)
        'Ethnicity: ${profile.publicEthnicity!.trim()}',
    ]) {
      height += 4 + _textHeight(detail, SelahText.body(size: 12), width);
    }
    return height + 72; // Room for pagination and padding above the identity.
  }

  double _footerReserve(BuildContext context) => math.max(
    widget.bottomPadding,
    math.max(
          MediaQuery.paddingOf(context).bottom,
          SelahNavBarMetrics.bottomInset,
        ) +
        SelahNavBarMetrics.height +
        12,
  );

  Widget _portraitPage(SeekerProfile? profile) => SafeArea(
    bottom: false,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final bottom = _footerReserve(context);
        final available = math.max(0.0, constraints.maxHeight - 16 - bottom);
        final contentWidth = math.max(1.0, constraints.maxWidth - 40);
        final requestHeight = _requestPillHeight(profile, contentWidth);
        // Ink's one-pixel borders contribute two pixels to each pill/card.
        final footerHeight =
            requestHeight +
            _pillBorderExtent +
            (widget.showSave && profile != null ? 58 : 0);
        final headerHeight = math.max(
          widget.onFilters == null && widget.onBrowseMenu == null ? 0.0 : 48.0,
          _textHeight('Browse', SelahText.pageTitle(), contentWidth - 48),
        );
        final photoHeight = math.max(
          profile == null
              ? 240.0
              : math.max(
                  240.0,
                  _identityMinimumHeight(profile, contentWidth - 64),
                ),
          math.min(
            620.0,
            available -
                headerHeight -
                32 -
                footerHeight -
                2 * SelahCardMetrics.padding -
                2,
          ),
        );
        return SingleChildScrollView(
          key: const ValueKey('concept_browse_design_scroll'),
          physics: const ClampingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(20, 16, 20, bottom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _header(),
              const SizedBox(height: 16),
              profile == null
                  ? Text(
                      'No profiles to view right now.',
                      style: SelahText.body(
                        size: 14,
                        color: SelahColors.ink(.65),
                      ),
                    )
                  : KeyedSubtree(
                      key: const ValueKey('concept_browse_portrait_card'),
                      child: SizedBox(
                        height: photoHeight + 2 * SelahCardMetrics.padding + 2,
                        child: SelahBrowseNextPhotoMotion(
                          key: const ValueKey('concept_browse_next_motion'),
                          profileId: profile.id,
                          epoch: widget.nextProfileMotionEpoch,
                          style: widget.nextProfileMotion,
                          child: _portraitCard(profile, photoHeight),
                        ),
                      ),
                    ),
              const SizedBox(height: 16),
              _compactFooter(profile),
            ],
          ),
        );
      },
    ),
  );

  @override
  Widget build(BuildContext context) {
    final profiles = widget.profiles;
    final current = profiles.isEmpty
        ? null
        : profiles[widget.selectedIndex.clamp(0, profiles.length - 1)];
    return _portraitPage(current);
  }
}

/// A local photo pager only. It never moves to another profile or borrows a
/// request delegate. The caller owns index validity and account/route guards.
class _BrowsePhotoPager extends StatefulWidget {
  const _BrowsePhotoPager({
    super.key,
    required this.profileId,
    required this.photoSources,
    required this.photoCount,
    required this.selectedIndex,
    required this.height,
    required this.photo,
    required this.onPageChanged,
    this.overlay,
    this.sideIndicators = false,
    this.tapToAdvance = false,
  });

  final String profileId;
  final List<String> photoSources;
  final int photoCount;
  final int selectedIndex;
  final double height;
  final Widget Function(int) photo;
  final ValueChanged<int> onPageChanged;
  final Widget? overlay;
  final bool sideIndicators;
  final bool tapToAdvance;

  @override
  State<_BrowsePhotoPager> createState() => _BrowsePhotoPagerState();
}

class _BrowsePhotoPagerState extends State<_BrowsePhotoPager>
    with SingleTickerProviderStateMixin {
  static const _currentPhotoDuration = Duration(milliseconds: 420);
  late final PageController _controller;
  late final AnimationController _wrapMotion;
  late Animation<Offset> _wrapIncomingOffset;
  late Animation<Offset> _wrapOutgoingOffset;
  Widget? _wrapPhoto;
  int? _tapTargetIndex;
  int _motionEpoch = 0;
  int _revision = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController(initialPage: widget.selectedIndex);
    _wrapMotion =
        AnimationController(
          vsync: this,
          duration: _currentPhotoDuration,
          value: 1,
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed &&
              mounted &&
              _wrapPhoto != null) {
            setState(() {
              _wrapPhoto = null;
              _tapTargetIndex = null;
            });
          }
        });
    _configureWrapMotion(1);
  }

  void _configureWrapMotion(int direction) {
    final motion = _wrapMotion.drive(CurveTween(curve: Curves.easeInOutCubic));
    _wrapIncomingOffset = motion.drive(
      Tween<Offset>(begin: Offset(direction.toDouble(), 0), end: Offset.zero),
    );
    _wrapOutgoingOffset = motion.drive(
      Tween<Offset>(begin: Offset.zero, end: Offset(-direction.toDouble(), 0)),
    );
  }

  bool get _quiet =>
      MediaQuery.disableAnimationsOf(context) ||
      (widget.tapToAdvance && MediaQuery.accessibleNavigationOf(context));

  void _cancelPhotoMotion() {
    ++_motionEpoch;
    _wrapMotion.stop();
    _wrapPhoto = null;
    _tapTargetIndex = null;
    _wrapMotion.value = 1;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_quiet || _tapTargetIndex == null) return;
    final target = _tapTargetIndex!;
    _cancelPhotoMotion();
    final epoch = _motionEpoch;
    // A dependency change can occur during parent layout. Finish the owned
    // tap on the next frame, never dispatch a parent selection during build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          epoch != _motionEpoch ||
          !_quiet ||
          !_controller.hasClients) {
        return;
      }
      _controller.jumpToPage(target.clamp(0, widget.photoCount - 1));
    });
  }

  @override
  void didUpdateWidget(covariant _BrowsePhotoPager oldWidget) {
    super.didUpdateWidget(oldWidget);
    ++_revision;
    final sourceChanged =
        oldWidget.profileId != widget.profileId ||
        oldWidget.tapToAdvance != widget.tapToAdvance ||
        !listEquals(oldWidget.photoSources, widget.photoSources);
    final externalSelection =
        oldWidget.selectedIndex != widget.selectedIndex &&
        widget.selectedIndex != _tapTargetIndex;
    if (sourceChanged || externalSelection) _cancelPhotoMotion();
    if (!sourceChanged &&
        oldWidget.selectedIndex == widget.selectedIndex &&
        oldWidget.photoCount == widget.photoCount) {
      return;
    }
    final selected = widget.selectedIndex;
    final profileId = widget.profileId;
    final epoch = _motionEpoch;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          epoch != _motionEpoch ||
          widget.profileId != profileId ||
          widget.selectedIndex != selected ||
          !_controller.hasClients ||
          (!sourceChanged && _controller.position.isScrollingNotifier.value)) {
        return;
      }
      // A same-count source replacement must terminate the old driven
      // activity even when its fractional position rounds to this index.
      if (sourceChanged || _controller.page?.round() != selected) {
        _controller.jumpToPage(selected);
      }
    });
  }

  @override
  void dispose() {
    _wrapMotion.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _showPhoto(int index, int revision, {int? cyclicDirection}) {
    if (!mounted ||
        revision != _revision ||
        widget.photoCount < 2 ||
        index < 0 ||
        index >= widget.photoCount ||
        !_controller.hasClients ||
        (widget.tapToAdvance &&
            (_controller.position.isScrollingNotifier.value ||
                _wrapPhoto != null))) {
      return;
    }
    // The bounded pager rebases once at a wrap. Both prepared photos slide
    // across that boundary at the ordinary tap speed, never dissolve or travel
    // through intermediate photos. Identity, markers and actions stay fixed.
    final visible = _controller.page?.round() ?? widget.selectedIndex;
    final wraps =
        widget.tapToAdvance &&
        ((cyclicDirection == 1 &&
                visible == widget.photoCount - 1 &&
                index == 0) ||
            (cyclicDirection == -1 &&
                visible == 0 &&
                index == widget.photoCount - 1));
    if (_quiet) {
      _controller.jumpToPage(index);
    } else if (wraps) {
      ++_motionEpoch;
      setState(() {
        _tapTargetIndex = index;
        _wrapPhoto = widget.photo(visible);
        _configureWrapMotion(cyclicDirection!);
      });
      _controller.jumpToPage(index);
      _wrapMotion.forward(from: 0);
    } else {
      _tapTargetIndex = index;
      final epoch = ++_motionEpoch;
      unawaited(
        _controller
            .animateToPage(
              index,
              duration: widget.tapToAdvance
                  ? _currentPhotoDuration
                  : const Duration(milliseconds: 220),
              curve: widget.tapToAdvance
                  ? Curves.easeInOutCubic
                  : Curves.easeOutCubic,
            )
            .whenComplete(() {
              if (mounted && epoch == _motionEpoch) _tapTargetIndex = null;
            }),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final onPageChanged = widget.onPageChanged;
    final revision = _revision;
    final selected = widget.selectedIndex;
    final count = widget.photoCount;
    final advance = widget.tapToAdvance && count > 1
        ? () => _showPhoto((selected + 1) % count, revision, cyclicDirection: 1)
        : null;
    Widget pager = PageView.builder(
      key: ValueKey('concept_browse_photo_swipe_${widget.profileId}'),
      controller: _controller,
      itemCount: widget.photoCount,
      onPageChanged: onPageChanged,
      itemBuilder: (_, index) => widget.photo(index),
    );
    if (widget.tapToAdvance) {
      pager = SlideTransition(
        key: ValueKey('concept_browse_photo_wrap_incoming_${widget.profileId}'),
        position: _wrapIncomingOffset,
        // Keep the full viewport interactive while its painted frame slides.
        transformHitTests: false,
        child: pager,
      );
      pager = NotificationListener<ScrollStartNotification>(
        onNotification: (notification) {
          if (notification.dragDetails != null) {
            setState(_cancelPhotoMotion);
          }
          return false;
        },
        child: pager,
      );
      pager = GestureDetector(
        key: ValueKey('concept_browse_photo_tap_${widget.profileId}'),
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTap: advance,
        child: pager,
      );
    }
    return Semantics(
      label: 'Photo ${widget.selectedIndex + 1} of ${widget.photoCount}',
      button: advance != null,
      onTap: advance,
      hint: widget.photoCount > 1
          ? widget.tapToAdvance
                ? 'Tap or swipe to view photos'
                : 'Swipe to view photos'
          : null,
      customSemanticsActions: widget.photoCount < 2
          ? null
          : {
              CustomSemanticsAction(label: 'Previous photo'): () => _showPhoto(
                (selected - 1) % count,
                revision,
                cyclicDirection: -1,
              ),
              CustomSemanticsAction(label: 'Next photo'): () => _showPhoto(
                (selected + 1) % count,
                revision,
                cyclicDirection: 1,
              ),
            },
      child: SizedBox(
        height: widget.height,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(SelahCardMetrics.thumbRadius),
          child: Stack(
            fit: StackFit.expand,
            children: [
              pager,
              if (_wrapPhoto != null)
                IgnorePointer(
                  child: ExcludeSemantics(
                    child: SlideTransition(
                      key: ValueKey(
                        'concept_browse_photo_wrap_${widget.profileId}',
                      ),
                      position: _wrapOutgoingOffset,
                      child: _wrapPhoto,
                    ),
                  ),
                ),
              if (widget.overlay != null) ...[
                const IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: [.25, .60, 1],
                        colors: [
                          Colors.transparent,
                          Color(0x35000000),
                          Color(0xE6000000),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 18,
                  child: IgnorePointer(child: widget.overlay!),
                ),
              ],
              if (widget.photoCount > 1)
                Positioned(
                  top: widget.sideIndicators ? 0 : 12,
                  bottom: widget.sideIndicators ? 0 : null,
                  left: widget.sideIndicators ? 16 : 12,
                  right: widget.sideIndicators ? null : 12,
                  child: IgnorePointer(
                    child: ExcludeSemantics(
                      child: Flex(
                        direction: widget.sideIndicators
                            ? Axis.vertical
                            : Axis.horizontal,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (
                            var index = 0;
                            index < widget.photoCount;
                            index++
                          )
                            Container(
                              key: ValueKey(
                                'concept_browse_photo_dot_${widget.profileId}_$index',
                              ),
                              width:
                                  !widget.sideIndicators &&
                                      index == widget.selectedIndex
                                  ? 16
                                  : 6,
                              height: 6,
                              margin: widget.sideIndicators
                                  ? const EdgeInsets.symmetric(vertical: 3)
                                  : const EdgeInsets.symmetric(horizontal: 3),
                              decoration: BoxDecoration(
                                color: index == widget.selectedIndex
                                    ? SelahColors.journeyGold
                                    : Colors.white.withValues(alpha: .65),
                                borderRadius: BorderRadius.circular(999),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black54,
                                    blurRadius: 3,
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
