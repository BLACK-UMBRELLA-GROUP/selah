import 'package:flutter/material.dart';

import '../../models/seeker_profile.dart';
import '../../services/selah_auth.dart';
import '../../services/selah_internal_preview_client.dart';
import '../../services/selah_photo_service.dart';
import '../../state/app_state.dart';
import '../../theme/selah_colors.dart';
import 'seeker_profile_screen.dart';

/// Read-only owner preview using the same full-screen profile presentation
/// used when another member opens a Seeker profile.
class MyProfilePreviewScreen extends StatefulWidget {
  const MyProfilePreviewScreen({super.key})
    : _preview = false,
      _profile = null,
      _canAct = null,
      _onBack = null;

  /// Public argument names intentionally initialize private preview fields.
  const MyProfilePreviewScreen.preview({
    super.key,
    required SeekerProfile profile,
    required bool Function() canAct,
    required VoidCallback onBack,
  }) : _preview = true,
       // ignore: prefer_initializing_formals
       _profile = profile,
       // ignore: prefer_initializing_formals
       _canAct = canAct,
       // ignore: prefer_initializing_formals
       _onBack = onBack;

  final bool _preview;
  final SeekerProfile? _profile;
  final bool Function()? _canAct;
  final VoidCallback? _onBack;

  @override
  State<MyProfilePreviewScreen> createState() => _MyProfilePreviewScreenState();
}

class _MyProfilePreviewScreenState extends State<MyProfilePreviewScreen> {
  late List<String> _photos;
  late final bool _previewMode;
  late final SeekerProfile? _previewProfile;
  late final bool Function()? _ownerGuard;
  late final VoidCallback? _onBack;
  bool _revoked = false;

  bool get _canAct {
    if (!mounted || _revoked || widget._preview != _previewMode) return false;
    if (!_previewMode) return true;
    try {
      if (_ownerGuard?.call() != true || widget._canAct?.call() != true) {
        _revoked = true;
        return false;
      }
      return true;
    } catch (_) {
      _revoked = true;
      return false;
    }
  }

  @override
  void initState() {
    super.initState();
    _previewMode = widget._preview;
    _ownerGuard = widget._canAct;
    _onBack = widget._onBack;
    final p = widget._profile;
    _previewProfile = p == null
        ? null
        : SeekerProfile(
            id: p.id,
            firstName: p.firstName,
            surnameLine: p.surnameLine,
            age: p.age,
            city: p.city,
            gender: p.gender,
            photos: List<String>.unmodifiable(p.photos),
            publicNationality: p.publicNationality,
            publicEthnicity: p.publicEthnicity,
            faithProfile: p.faithProfile,
            faithDenominationText: p.faithDenominationText,
          );
    if (_previewMode) {
      _photos = _previewProfile!.photos;
      _revoked = _photos.any((photo) {
        if (photo.startsWith('data:image/') && photo.contains(';base64,')) {
          return false;
        }
        final uri = Uri.tryParse(photo);
        return !photo.startsWith('assets/') ||
            uri == null ||
            uri.hasScheme ||
            uri.hasAuthority ||
            uri.hasQuery ||
            uri.hasFragment ||
            photo.contains('..') ||
            photo.contains('\\');
      });
      return;
    }
    _photos = List<String>.of(AppState.instance.photos);
    if (_photos.isEmpty &&
        !SelahInternalPreviewClient.isActive &&
        SelahAuth.isSignedIn) {
      _restoreOwnPhotos();
    }
  }

  @override
  void didUpdateWidget(covariant MyProfilePreviewScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_previewMode &&
        (!widget._preview || !identical(widget._onBack, _onBack))) {
      _revoked = true;
    }
  }

  Future<void> _restoreOwnPhotos() async {
    final photos = await SelahPhotoService.fetchOwnPhotos();
    if (!mounted || photos.isEmpty) return;
    setState(() => _photos = photos);
  }

  int _age(AppState state) {
    if (state.age != null) return state.age!;
    final dob = state.dob;
    if (dob == null) return 0;
    final now = DateTime.now();
    var age = now.year - dob.year;
    final birthdayPassed =
        now.month > dob.month || (now.month == dob.month && now.day >= dob.day);
    if (!birthdayPassed) age -= 1;
    return age;
  }

  @override
  Widget build(BuildContext context) {
    if (widget._preview != _previewMode || (_previewMode && !_canAct)) {
      return const SizedBox.expand(
        key: ValueKey('my-profile-preview-unavailable'),
      );
    }
    if (_previewMode) {
      return SeekerProfileScreen(
        profile: _previewProfile!,
        swipeDownToDismiss: true,
        revealRouteOnSwipeDismiss: true,
        matchBrowseIdentityLayout: true,
        emptyPhoto: _OwnProfileEmptyPhoto(gender: _previewProfile.gender),
        canAct: () => _canAct,
        onDismiss: _onBack,
      );
    }
    final state = AppState.instance;
    final name = state.name?.trim();
    final profile = SeekerProfile(
      id: 'my-profile-preview',
      firstName: name == null || name.isEmpty ? 'Your Profile' : name,
      surnameLine: state.surnameLine,
      age: _age(state),
      city: state.location?.trim() ?? '',
      photos: _photos,
      gender: state.gender ?? '',
    );

    return SeekerProfileScreen(
      profile: profile,
      swipeDownToDismiss: true,
      revealRouteOnSwipeDismiss: true,
      matchBrowseIdentityLayout: true,
      emptyPhoto: _OwnProfileEmptyPhoto(gender: state.gender),
    );
  }
}

class _OwnProfileEmptyPhoto extends StatelessWidget {
  const _OwnProfileEmptyPhoto({required this.gender});

  final String? gender;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(gradient: SelahColors.genderGradient(gender)),
    child: Center(
      child: Icon(
        Icons.person_outline,
        size: 104,
        color: Colors.white.withValues(alpha: 0.16),
      ),
    ),
  );
}
