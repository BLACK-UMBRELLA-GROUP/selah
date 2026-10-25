// Protected sample wrapper for the shared Portrait Browse presentation.
// Only in-memory data:image references may reach its image widget. No member
// lookup, services or persistence lives here.
import 'package:flutter/material.dart';

import '../models/seeker_profile.dart';
import '../theme/selah_interaction_style.dart';
import '../widgets/selah_browse_designs.dart';
import '../widgets/selah_browse_next_photo_motion.dart';
import '../widgets/selah_profile_image.dart';

export '../widgets/selah_browse_designs.dart' show SelahOneJourneyBrowseDesign;

Widget _samplePhoto(
  BuildContext context,
  String photo, {
  required double width,
  required double height,
  required Alignment alignment,
}) => SelahProfileImage(
  photo.startsWith('data:image/') ? photo : '',
  width: width,
  height: height,
  alignment: alignment,
);

/// Previous/Next are neutral navigation, never Pass or Dislike. The caller
/// owns local sample eligibility and actions; the Portrait layout stays shared.
class SelahOneJourneyBrowseDesigns extends StatefulWidget {
  const SelahOneJourneyBrowseDesigns({
    super.key,
    required this.profiles,
    required this.selectedIndex,
    required this.design,
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
    this.photoBuilder,
    this.alignHeaderActions = false,
    this.nextProfileMotion = SelahBrowseNextMotion.current,
    this.nextProfileMotionEpoch = 0,
    this.hapticLevel,
  });

  final List<SeekerProfile> profiles;
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

  /// Optional owner-prepared offline renderer. The existing sample-only
  /// default remains unchanged for existing callers and fixtures.
  final SelahBrowsePhotoBuilder? photoBuilder;
  final bool alignHeaderActions;
  final SelahBrowseNextMotion nextProfileMotion;
  final int nextProfileMotionEpoch;
  final SelahHapticLevel? hapticLevel;

  @override
  State<SelahOneJourneyBrowseDesigns> createState() =>
      _SelahOneJourneyBrowseDesignsState();
}

class _SelahOneJourneyBrowseDesignsState
    extends State<SelahOneJourneyBrowseDesigns> {
  Widget _photo(
    BuildContext context,
    String source, {
    required double width,
    required double height,
    required Alignment alignment,
  }) => (widget.photoBuilder ?? _samplePhoto)(
    context,
    source.startsWith('data:image/') ? source : '',
    width: width,
    height: height,
    alignment: alignment,
  );

  @override
  Widget build(BuildContext context) => SelahBrowseDesigns(
    profiles: widget.profiles,
    selectedIndex: widget.selectedIndex,
    design: widget.design,
    photoBuilder: _photo,
    onPrevious: widget.onPrevious,
    onNext: widget.onNext,
    onFilters: widget.onFilters,
    onBrowseMenu: widget.onBrowseMenu,
    onProfile: widget.onProfile,
    onRequest: widget.onRequest,
    onSave: widget.onSave,
    showSave: widget.showSave,
    savedIds: widget.savedIds,
    requestLabel: widget.requestLabel,
    invitationSent: widget.invitationSent,
    canRequest: widget.canRequest,
    bottomPadding: widget.bottomPadding,
    alignHeaderActions: widget.alignHeaderActions,
    nextProfileMotion: widget.nextProfileMotion,
    nextProfileMotionEpoch: widget.nextProfileMotionEpoch,
    hapticLevel: widget.hapticLevel,
  );
}
