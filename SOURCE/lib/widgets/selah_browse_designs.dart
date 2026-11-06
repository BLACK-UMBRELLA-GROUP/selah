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
import '../theme/selah_colors.dart';
import '../theme/selah_interaction_style.dart';
import '../theme/selah_text.dart';
import 'floating_nav_bar.dart';
import 'selah_browse_next_photo_motion.dart';
import 'selah_invitation_label.dart';
import 'selah_press_feedback.dart';
import 'selah_shepherd_invite_views.dart';

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
    this.waitingShepherdFirstName,
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

  /// Caller-owned pending invite display only. Null leaves the existing
  /// Portrait layout unchanged; this presenter does not decide eligibility.
  final String? waitingShepherdFirstName;
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
  static const _backPillWidth = 40.0;
  static const _nextPillWidth = 40.0;
  static const _footerGap = 14.0;
  static const _pillBorderExtent = 2.0;
  static const _pillMinTapHeight = 48.0;
  static const _pillHorizontalTextPadding = 18.0;
  static const _pillVerticalPadding = 15.0;
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

  List<String> _publicDetails(SeekerProfile profile) => [
    if (profile.publicNationality?.trim().isNotEmpty ?? false)
      'Nationality: ${profile.publicNationality!.trim()}',
    if (profile.publicEthnicity?.trim().isNotEmpty ?? false)
      'Ethnicity: ${profile.publicEthnicity!.trim()}',
  ];

  String _profileMeta(SeekerProfile profile) {
    final city = profile.city.trim();
    final hasCity = city.isNotEmpty && city != '—';
    return profile.age > 0
        ? (hasCity ? '${profile.age} · $city' : '${profile.age}')
        : (hasCity ? city : '');
  }

  Widget _identity(SeekerProfile profile) => KeyedSubtree(
    key: ValueKey('concept_browse_identity_${profile.id}'),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(profile.firstName, style: SelahText.memberName()),
        if (profile.surnameLine?.trim().isNotEmpty ?? false) ...[
          const SizedBox(height: 2),
          Text(profile.surnameLine!.trim(), style: SelahText.memberName()),
        ],
        if (_profileMeta(profile).isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(_profileMeta(profile), style: SelahText.subtext()),
        ],
        if (_publicDetails(profile).isNotEmpty) ...[
          const SizedBox(height: 14),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final detail in _publicDetails(profile))
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 7,
                    horizontal: 10,
                  ),
                  decoration: BoxDecoration(
                    color: SelahColors.soft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    detail,
                    style: SelahText.body(
                      size: 12.5,
                    ).copyWith(fontWeight: FontWeight.w500, height: 1),
                  ),
                ),
            ],
          ),
        ],
      ],
    ),
  );

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
              borderRadius: BorderRadius.circular(18),
              child: renderedPhoto,
            )
          : renderedPhoto,
    );
  }

  Widget _swipeGallery(SeekerProfile profile, double height) {
    final revision = _layoutRevision;
    return _BrowsePhotoPager(
      key: ValueKey('concept_browse_pager_${profile.id}'),
      profileId: profile.id,
      photoSources: List<String>.unmodifiable(profile.photos),
      photoCount: math.max(1, profile.photos.length),
      selectedIndex: _photoIndex(profile),
      height: height,
      // The viewport owns the shared radius, including moving photo seams.
      photo: (index) => _studyPhoto(profile, index, height, rounded: false),
      onPageChanged: (index) => _selectPhoto(profile, index, revision),
      tapToAdvance: true,
    );
  }

  Widget _portraitCard(SeekerProfile profile, double photoHeight) => Material(
    key: _cardAnchors.putIfAbsent(profile.id, GlobalKey.new),
    color: Colors.transparent,
    borderRadius: BorderRadius.circular(18),
    clipBehavior: Clip.antiAlias,
    child: _swipeGallery(profile, photoHeight),
  );

  Widget _header() {
    final person = widget.profiles.isEmpty
        ? null
        : widget.profiles[widget.selectedIndex.clamp(
            0,
            widget.profiles.length - 1,
          )];
    final name = person == null
        ? null
        : [
            person.firstName.trim(),
            if (person.surnameLine?.trim().isNotEmpty ?? false)
              person.surnameLine!.trim(),
          ].where((part) => part.isNotEmpty).join(' ');
    final open = widget.onBrowseMenu;
    return Row(
      key: const ValueKey('concept_browse_header'),
      children: [
        const Expanded(
          child: SelahWordmark(key: ValueKey('concept_browse_title')),
        ),
        if (open != null || widget.onFilters != null)
          SizedBox.square(
            dimension: 40,
            child: Material(
              color: SelahColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: SelahColors.line),
              ),
              child: IconButton(
                key: ValueKey(
                  open != null ? 'concept_browse_menu' : 'concept_filters',
                ),
                tooltip: open != null
                    ? (name == null || name.isEmpty
                          ? 'Browse options'
                          : 'Browse options for $name')
                    : 'Browse filters',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 40,
                  height: 40,
                ),
                onPressed: open != null ? () => open(person) : widget.onFilters,
                color: SelahColors.inkColor,
                icon: Icon(
                  open != null ? Icons.more_horiz_rounded : Icons.tune,
                  size: 23,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _compactPill({
    required Key key,
    required String label,
    required VoidCallback? onTap,
    IconData? icon,
    double iconSize = 20,
    bool primary = false,
    bool? invitationSent,
    double minimumHeight = _pillMinTapHeight,
  }) {
    final color = primary ? SelahColors.onLake : SelahColors.inkColor;
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: invitationSent == true
          ? '$label. Tap to cancel invitation'
          : label,
      onTap: onTap,
      excludeSemantics: true,
      child: SelahPressFeedback(
        enabled: primary && onTap != null,
        child: Material(
          color: primary
              ? SelahColors.lake
              : (icon == null ? Colors.transparent : SelahColors.surface),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: primary ? SelahColors.lake : SelahColors.line,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: key,
            onTap: onTap,
            excludeFromSemantics: true,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: 40,
                minHeight: icon == null ? minimumHeight : 40,
              ),
              child: Padding(
                padding: icon == null
                    ? const EdgeInsets.symmetric(
                        horizontal: _pillHorizontalTextPadding,
                        vertical: _pillVerticalPadding,
                      )
                    : EdgeInsets.zero,
                child: Center(
                  child: icon != null
                      ? Icon(icon, size: iconSize, color: color)
                      : invitationSent != null
                      ? SelahInvitationLabel(
                          label: label,
                          sent: invitationSent,
                          style: _requestStyle(color: color),
                        )
                      : Text(
                          label,
                          textAlign: TextAlign.center,
                          style: _requestStyle(color: color),
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

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

  TextStyle _requestStyle({Color? color}) =>
      SelahText.button(size: 15, color: color);

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
    var height = _textHeight(profile.firstName, SelahText.memberName(), width);
    if (profile.surnameLine?.trim().isNotEmpty ?? false) {
      height +=
          2 +
          _textHeight(
            profile.surnameLine!.trim(),
            SelahText.memberName(),
            width,
          );
    }
    if (_profileMeta(profile).isNotEmpty) {
      height +=
          4 + _textHeight(_profileMeta(profile), SelahText.subtext(), width);
    }
    final details = _publicDetails(profile);
    if (details.isNotEmpty) {
      var rowWidth = 0.0;
      var rowHeight = 0.0;
      var chipsHeight = 0.0;
      for (final detail in details) {
        final painter = TextPainter(
          text: TextSpan(
            text: detail,
            style: SelahText.body(
              size: 12.5,
            ).copyWith(fontWeight: FontWeight.w500, height: 1),
          ),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: math.max(1, width - 20));
        final chipWidth = painter.width + 20;
        final chipHeight = painter.height + 14;
        painter.dispose();
        if (rowWidth > 0 && rowWidth + 6 + chipWidth > width) {
          chipsHeight += rowHeight + 6;
          rowWidth = 0;
          rowHeight = 0;
        }
        rowWidth += (rowWidth > 0 ? 6 : 0) + chipWidth;
        rowHeight = math.max(rowHeight, chipHeight);
      }
      height += 14 + chipsHeight + rowHeight;
    }
    return height;
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
        final contentWidth = math.max(1.0, constraints.maxWidth - 44);
        final footerHeight =
            _requestPillHeight(profile, contentWidth) +
            _pillBorderExtent +
            (widget.showSave && profile != null ? 62 : 0);
        final headerHeight = math.max(
          40.0,
          _textHeight('Selah', SelahText.wordmark(), contentWidth - 54),
        );
        final identityHeight = profile == null
            ? 0.0
            : _identityMinimumHeight(profile, contentWidth);
        final waitingName = widget.waitingShepherdFirstName?.trim() ?? '';
        final showWaitingBanner = waitingName.isNotEmpty;
        // Match the shared banner's real text/circle footprint before sizing
        // the photo. The extra gap exists only while an invite is pending.
        final waitingHeight = showWaitingBanner
            ? 20 +
                  math.max(
                    30,
                    _textHeight(
                      'Waiting for $waitingName to accept. You can ask once they say yes.',
                      SelahText.body(size: 13.5).copyWith(height: 1.2),
                      contentWidth - 68,
                    ),
                  ) +
                  14
            : 0.0;
        final photoHeight = math.max(
          240.0,
          math.min(
            620.0,
            available -
                headerHeight -
                identityHeight -
                footerHeight -
                42 -
                waitingHeight,
          ),
        );
        return SingleChildScrollView(
          key: const ValueKey('concept_browse_design_scroll'),
          physics: const ClampingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(22, 16, 22, bottom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _header(),
              const SizedBox(height: 14),
              if (showWaitingBanner) ...[
                SelahShepherdWaitingBanner(firstName: waitingName),
                const SizedBox(height: 14),
              ],
              if (profile == null)
                Text(
                  'No profiles to view right now.',
                  style: SelahText.body(size: 14, color: SelahColors.muted),
                )
              else ...[
                KeyedSubtree(
                  key: const ValueKey('concept_browse_portrait_card'),
                  child: SizedBox(
                    height: photoHeight,
                    child: SelahBrowseNextPhotoMotion(
                      key: const ValueKey('concept_browse_next_motion'),
                      profileId: profile.id,
                      epoch: widget.nextProfileMotionEpoch,
                      style: widget.nextProfileMotion,
                      child: _portraitCard(profile, photoHeight),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _identity(profile),
              ],
              const SizedBox(height: 14),
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
    this.tapToAdvance = false,
  });

  final String profileId;
  final List<String> photoSources;
  final int photoCount;
  final int selectedIndex;
  final double height;
  final Widget Function(int) photo;
  final ValueChanged<int> onPageChanged;
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
          borderRadius: BorderRadius.circular(18),
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
              if (widget.photoCount > 1)
                Positioned(
                  top: 12,
                  left: 12,
                  right: 12,
                  child: IgnorePointer(
                    child: ExcludeSemantics(
                      child: Row(
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
                              width: 28,
                              height: 3,
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(
                                  alpha: index == widget.selectedIndex ? 1 : .5,
                                ),
                                borderRadius: BorderRadius.circular(3),
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
