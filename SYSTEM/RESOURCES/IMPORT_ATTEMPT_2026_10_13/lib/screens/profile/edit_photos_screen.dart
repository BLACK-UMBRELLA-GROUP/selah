import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import '../../dev/selah_app_gold_preview.dart';
import 'package:flutter/services.dart';

import '../../services/selah_auth.dart';
import '../../services/selah_internal_preview_client.dart';
import '../../services/selah_photo_service.dart';
import '../../services/selah_profile_photo_processor.dart';
import '../../state/app_state.dart';
import '../../theme/selah_colors.dart';
import '../../theme/selah_interaction_style.dart';
import '../../theme/selah_text.dart';
import '../../widgets/selah_glass_dialog.dart';
import '../../widgets/selah_loading.dart';
import '../../widgets/selah_profile_image.dart';
import '../../widgets/selah_state_widgets.dart';
import 'avatar_adjust_screen.dart';
import 'photo_crop_review_screen.dart';
import 'selah_photo_batch_flow.dart';

class EditPhotosScreen extends StatefulWidget {
  const EditPhotosScreen({super.key, this.photoBatchRunner})
    : _preview = false,
      _canAct = null,
      _initialPhotos = null,
      _gender = null,
      _initialAlignmentX = 0,
      _initialAlignmentY = 0,
      _onPhotosChanged = null,
      _onAvatarChanged = null,
      hapticLevel = null,
      embedded = false;

  /// Reuses the member editor with a caller-owned, memory-only photo draft.
  /// This route never becomes a member editor after its admission is revoked.
  /// Public argument names intentionally initialize private mode fields.
  const EditPhotosScreen.preview({
    super.key,
    required bool Function() canAct,
    required List<String> initialPhotos,
    required String? gender,
    required double initialAlignmentX,
    required double initialAlignmentY,
    required ValueChanged<List<String>> onPhotosChanged,
    required ValueChanged<Offset> onAvatarChanged,
    this.hapticLevel = SelahInteractionStyle.currentDefaultHapticLevel,
    this.photoBatchRunner,
    this.embedded = true,
  }) : _preview = true,
       // ignore: prefer_initializing_formals
       _canAct = canAct,
       // ignore: prefer_initializing_formals
       _initialPhotos = initialPhotos,
       // ignore: prefer_initializing_formals
       _gender = gender,
       // ignore: prefer_initializing_formals
       _initialAlignmentX = initialAlignmentX,
       // ignore: prefer_initializing_formals
       _initialAlignmentY = initialAlignmentY,
       // ignore: prefer_initializing_formals
       _onPhotosChanged = onPhotosChanged,
       // ignore: prefer_initializing_formals
       _onAvatarChanged = onAvatarChanged;

  final bool _preview;
  final bool Function()? _canAct;
  final List<String>? _initialPhotos;
  final String? _gender;
  final double _initialAlignmentX;
  final double _initialAlignmentY;
  final ValueChanged<List<String>>? _onPhotosChanged;
  final ValueChanged<Offset>? _onAvatarChanged;
  final SelahHapticLevel? hapticLevel;
  final bool embedded;

  @visibleForTesting
  final SelahPhotoBatchRunner? photoBatchRunner;

  @override
  State<EditPhotosScreen> createState() => _EditPhotosScreenState();
}

class _EditPhotosScreenState extends State<EditPhotosScreen> {
  static const int _maximumPhotos = 6;

  final List<String> _photos = [];
  bool _loading = true;
  bool _working = false;
  String? _error;
  String? _progressLabel;
  late final PageController _pageController = PageController(
    viewportFraction: 0.98,
  );
  int _currentPage = 0;
  int _compactSelected = 0;
  bool _compactView = false;

  late final bool _previewMode;
  late final bool _embedded;
  late final bool Function()? _previewOwnerCanAct;
  late final ValueChanged<List<String>>? _onPhotosChanged;
  late final ValueChanged<Offset>? _onAvatarChanged;
  late final String? _previewGender;
  bool _previewRevoked = false;
  double _alignmentX = 0;
  double _alignmentY = 0;

  bool get _localPreview => _previewMode || SelahInternalPreviewClient.isActive;

  bool get _ownerCanAct {
    if (!mounted) return false;
    if (!_previewMode) return !widget._preview;
    if (_previewRevoked) return false;
    try {
      if (!widget._preview ||
          _previewOwnerCanAct?.call() != true ||
          widget._canAct?.call() != true) {
        _previewRevoked = true;
        return false;
      }
      return true;
    } catch (_) {
      _previewRevoked = true;
      return false;
    }
  }

  bool get _canUse =>
      _ownerCanAct &&
      (!_previewMode || (ModalRoute.of(context)?.isCurrent ?? true));

  static bool _localPhotoReference(String value) {
    if (value.startsWith('data:image/')) return value.contains(';base64,');
    final uri = Uri.tryParse(value);
    return value.startsWith('assets/') &&
        uri != null &&
        !uri.hasScheme &&
        !uri.hasAuthority &&
        !uri.hasQuery &&
        !uri.hasFragment &&
        !value.contains('..') &&
        !value.contains('\\');
  }

  void _hideRevokedPreview() {
    if (mounted && _previewMode) setState(() {});
  }

  void _saveAvatar(Offset alignment) {
    if (!_canUse) return;
    if (_previewMode) {
      _alignmentX = alignment.dx.clamp(-1.0, 1.0).toDouble();
      _alignmentY = alignment.dy.clamp(-1.0, 1.0).toDouble();
      _onAvatarChanged!(Offset(_alignmentX, _alignmentY));
    } else {
      AppState.instance.setAvatarAlignment(x: alignment.dx, y: alignment.dy);
    }
  }

  Future<Uint8List> _preparePhoto(String photo) async {
    if (!_previewMode) {
      return SelahPhotoService.prepareDisplayPhotoForReview(photo);
    }
    if (!_ownerCanAct || !_localPhotoReference(photo)) {
      throw const SelahProfilePhotoProcessingException(
        'local photo unavailable',
      );
    }
    final Uint8List bytes;
    if (photo.startsWith('data:image/')) {
      bytes = base64Decode(photo.substring(photo.indexOf(',') + 1));
    } else {
      final data = await rootBundle.load(photo);
      if (!_ownerCanAct) {
        throw const SelahProfilePhotoProcessingException(
          'local photo unavailable',
        );
      }
      bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    }
    return SelahProfilePhotoProcessor.process(bytes);
  }

  @override
  void initState() {
    super.initState();
    _previewMode = widget._preview;
    _embedded = widget.embedded;
    _previewOwnerCanAct = widget._canAct;
    _onPhotosChanged = widget._onPhotosChanged;
    _onAvatarChanged = widget._onAvatarChanged;
    _previewGender = widget._gender;
    if (_previewMode) {
      final initial = List<String>.unmodifiable(widget._initialPhotos!);
      _previewRevoked =
          initial.length > _maximumPhotos ||
          initial.any((photo) => !_localPhotoReference(photo));
      if (!_previewRevoked) _photos.addAll(initial);
      _alignmentX = widget._initialAlignmentX.clamp(-1.0, 1.0).toDouble();
      _alignmentY = widget._initialAlignmentY.clamp(-1.0, 1.0).toDouble();
      _loading = false;
      return;
    }
    _photos.addAll(AppState.instance.photos);
    _restore();
  }

  @override
  void didUpdateWidget(covariant EditPhotosScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_previewMode &&
        (!widget._preview ||
            !identical(widget._onPhotosChanged, _onPhotosChanged) ||
            !identical(widget._onAvatarChanged, _onAvatarChanged))) {
      _previewRevoked = true;
    }
  }

  Future<void> _restore() async {
    if (_previewMode || !_canUse) return;
    if (_photos.isNotEmpty || _localPreview || !SelahAuth.isSignedIn) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final restored = await SelahPhotoService.fetchOwnPhotos();
    if (!mounted) return;
    setState(() {
      _photos
        ..clear()
        ..addAll(restored);
      _loading = false;
    });
    AppState.instance.setProfilePhotos(restored);
  }

  void _apply(List<String> next) {
    _photos
      ..clear()
      ..addAll(next);
    final last = next.isEmpty ? 0 : next.length - 1;
    _currentPage = _currentPage.clamp(0, last);
    _compactSelected = _compactSelected.clamp(0, last);
    if (!_previewMode) AppState.instance.setProfilePhotos(next);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToPage(int index) {
    if (!_canUse || _photos.isEmpty) return;
    final target = index.clamp(0, _photos.length - 1);
    setState(() => _currentPage = target);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_canUse || !_pageController.hasClients) return;
      _pageController.animateToPage(
        target,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<bool> _commit(List<String> next) async {
    if (_working || !_canUse) {
      _hideRevokedPreview();
      return false;
    }
    if (_previewMode &&
        (next.isEmpty ||
            next.length > _maximumPhotos ||
            next.any((photo) => !_localPhotoReference(photo)))) {
      setState(
        () => _error = 'Those photos could not be added. Please try again.',
      );
      return false;
    }
    final previous = List<String>.of(_photos);
    setState(() {
      _working = true;
      _error = null;
      _apply(next);
    });

    final saved = _localPreview
        ? true
        : await SelahPhotoService.syncPhotosConfirmed(next);
    if (!_canUse) {
      _hideRevokedPreview();
      return false;
    }
    if (!saved) {
      setState(() {
        _apply(previous);
        _working = false;
        _error = "Your photo changes weren't saved. Please try again.";
      });
      return false;
    }
    if (_previewMode) _onPhotosChanged!(List<String>.unmodifiable(next));
    if (!_canUse) {
      _hideRevokedPreview();
      return false;
    }
    setState(() => _working = false);
    unawaited(
      SelahInteractionStyle.emitSelectionHaptic(
        level: _previewMode
            ? widget.hapticLevel ??
                  SelahInteractionStyle.currentDefaultHapticLevel
            : null,
      ),
    );
    return true;
  }

  Future<void> _addPhoto() async {
    if (!_canUse || _working || _photos.length >= _maximumPhotos) {
      _hideRevokedPreview();
      return;
    }
    if (!_localPreview && !SelahAuth.isSignedIn) {
      setState(() => _error = 'Sign in before adding a profile photo.');
      return;
    }

    setState(() {
      _working = true;
      _error = null;
      _progressLabel = null;
    });
    void updateProgress(String? value) {
      if (_ownerCanAct) setState(() => _progressLabel = value);
    }

    final firstNewIndex = _photos.length;
    final remaining = _maximumPhotos - firstNewIndex;
    final result = widget.photoBatchRunner != null
        ? await widget.photoBatchRunner!(context, remaining, updateProgress)
        : await runSelahPhotoBatchFlow(
            context,
            remaining: remaining,
            localPreview: _localPreview,
            onProgress: updateProgress,
            canProceed: _previewMode ? () => _ownerCanAct : null,
            preview: _previewMode,
            previewGender: _previewGender,
          );
    if (!_canUse) {
      _hideRevokedPreview();
      return;
    }
    setState(() {
      _working = false;
      _progressLabel = null;
    });
    switch (result.outcome) {
      case SelahPhotoBatchOutcome.added:
        final committed = await _commit([..._photos, ...result.urls]);
        if (committed && mounted) {
          setState(() => _compactView = false);
          _goToPage(firstNewIndex);
        }
      case SelahPhotoBatchOutcome.cancelled:
        return;
      case SelahPhotoBatchOutcome.error:
        setState(() {
          _error = result.memberErrorMessage;
        });
    }
  }

  Future<void> _removePhoto(int index) async {
    if (!_canUse || _working || index < 0 || index >= _photos.length) {
      _hideRevokedPreview();
      return;
    }
    if (_photos.length == 1) {
      setState(() {
        _error = 'Add a replacement before removing your only photo.';
      });
      return;
    }
    final confirmed = await showSelahGlassChoice(
      context: context,
      icon: Icons.delete_outline,
      title: 'Remove this photo?',
      body: index == 0
          ? 'The next photo will become your main profile photo.'
          : 'This photo will no longer appear on your profile.',
      primaryLabel: 'Remove photo',
      secondaryLabel: 'Keep photo',
    );
    if (confirmed != true || !_canUse) {
      _hideRevokedPreview();
      return;
    }
    final removed = _photos[index];
    final next = List<String>.of(_photos)..removeAt(index);
    final committed = await _commit(next);
    if (committed && !_localPreview) {
      await SelahPhotoService.discardNewUploads([removed]);
    }
    if (committed && mounted) {
      if (index == 0) _saveAvatar(Offset.zero);
      if (next.isNotEmpty) _goToPage(index.clamp(0, next.length - 1));
    }
  }

  Future<void> _makeMain(int index) async {
    if (!_canUse || _working || index <= 0 || index >= _photos.length) {
      _hideRevokedPreview();
      return;
    }
    final next = List<String>.of(_photos);
    final moved = next.removeAt(index);
    next.insert(0, moved);
    final committed = await _commit(next);
    if (!committed || !_canUse) return;
    _saveAvatar(Offset.zero);
    setState(() {
      _compactSelected = 0;
      _compactView = false;
    });
    _goToPage(0);
  }

  Future<void> _editPhoto(int index) async {
    if (!_canUse || _working || index < 0 || index >= _photos.length) {
      _hideRevokedPreview();
      return;
    }
    final original = _photos[index];
    setState(() {
      _working = true;
      _error = null;
      // Keep feedback while the original is prepared, but do not cover the
      // photo with a verbose temporary status message.
      _progressLabel = '';
    });

    try {
      final source = await _preparePhoto(original);
      if (!mounted || !_canUse) {
        _hideRevokedPreview();
        return;
      }
      setState(() {
        _working = false;
        _progressLabel = null;
      });
      final reviewed = await Navigator.of(context).push<List<Uint8List>>(
        MaterialPageRoute(
          builder: (_) => PhotoCropReviewScreen(
            photos: [source],
            preview: _previewMode,
            gender: _previewGender,
            canAct: _previewMode ? () => _ownerCanAct : null,
          ),
        ),
      );
      if (reviewed == null || reviewed.isEmpty || !_canUse) {
        _hideRevokedPreview();
        return;
      }

      setState(() {
        _working = true;
        _progressLabel = _localPreview ? 'Updating photo' : 'Uploading photo';
      });
      final saved = await SelahPhotoService.saveReviewedPhoto(
        reviewed.single,
        localPreview: _localPreview,
        canProceed: _previewMode ? () => _ownerCanAct : null,
      );
      if (!_canUse) {
        _hideRevokedPreview();
        return;
      }
      setState(() {
        _working = false;
        _progressLabel = null;
      });
      if (saved.outcome != SelahPhotoOutcome.uploaded || saved.url == null) {
        final kind = saved.failureKind ?? SelahPhotoFailureKind.unknown;
        setState(() {
          _error = '${kind.memberMessage} Reference: ${kind.referenceCode}.';
        });
        return;
      }

      final next = List<String>.of(_photos)..[index] = saved.url!;
      final committed = await _commit(next);
      if (!committed && !_localPreview) {
        await SelahPhotoService.discardNewUploads([saved.url!]);
      } else if (committed && !_localPreview) {
        await SelahPhotoService.discardNewUploads([original]);
      }
      if (committed && mounted) {
        if (index == 0) {
          _saveAvatar(Offset.zero);
        }
        _goToPage(index);
      }
    } catch (error) {
      if (!_canUse) {
        _hideRevokedPreview();
        return;
      }
      final kind = SelahPhotoService.classifyFailure(error);
      setState(() {
        _working = false;
        _progressLabel = null;
        _error = '${kind.memberMessage} Reference: ${kind.referenceCode}.';
      });
    }
  }

  Future<void> _adjustAvatar() async {
    if (!_canUse || _working || _photos.isEmpty) {
      _hideRevokedPreview();
      return;
    }
    final alignment = await Navigator.of(context).push<Offset>(
      MaterialPageRoute(
        builder: (_) => AvatarAdjustScreen(
          photo: _photos.first,
          initialAlignmentX: _previewMode
              ? _alignmentX
              : AppState.instance.avatarAlignmentX,
          initialAlignmentY: _previewMode
              ? _alignmentY
              : AppState.instance.avatarAlignmentY,
          preview: _previewMode,
          gender: _previewGender,
          canAct: _previewMode ? () => _ownerCanAct : null,
          hapticLevel: _previewMode ? widget.hapticLevel : null,
        ),
      ),
    );
    if (alignment == null || !_canUse) {
      _hideRevokedPreview();
      return;
    }
    _saveAvatar(alignment);
    if (_canUse) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if ((_previewMode && !_ownerCanAct) || widget._preview != _previewMode) {
      return const SizedBox.expand(key: ValueKey('photos-preview-unavailable'));
    }
    final page = SafeArea(
      child: Column(
        children: [
          Padding(
            padding: _previewMode
                ? const EdgeInsets.fromLTRB(20, 16, 20, 8)
                : const EdgeInsets.fromLTRB(12, 8, 20, 8),
            child: Row(
              children: [
                if (!_previewMode)
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                    color: SelahColors.foreground,
                    tooltip: 'Back',
                    onPressed: _working
                        ? null
                        : () => Navigator.of(context).pop(),
                  ),
                if (!_previewMode) const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Photos',
                    key: const ValueKey('photos-title'),
                    style: SelahText.heading(size: _previewMode ? 28 : 20),
                  ),
                ),
                IconButton(
                  key: const ValueKey('photos-compact-toggle'),
                  tooltip: _compactView ? 'Show large photos' : 'Manage photos',
                  onPressed: _working || _photos.isEmpty
                      ? null
                      : () {
                          if (!_canUse) {
                            _hideRevokedPreview();
                            return;
                          }
                          setState(() {
                            _compactView = !_compactView;
                            _compactSelected = _currentPage.clamp(
                              0,
                              _photos.isEmpty ? 0 : _photos.length - 1,
                            );
                          });
                        },
                  icon: _NineDotGridIcon(
                    active: _compactView,
                    enabled: !_working && _photos.isNotEmpty,
                  ),
                ),
              ],
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
              child: SelahErrorBanner(
                message: _error!,
                onDismiss: () {
                  if (_canUse) {
                    setState(() => _error = null);
                  } else {
                    _hideRevokedPreview();
                  }
                },
              ),
            ),
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 280),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position:
                            Tween<Offset>(
                              begin: const Offset(0.035, 0),
                              end: Offset.zero,
                            ).animate(
                              CurvedAnimation(
                                parent: animation,
                                curve: Curves.easeOutCubic,
                              ),
                            ),
                        child: child,
                      ),
                    ),
                    child: _loading
                        ? const Center(
                            key: ValueKey('photos-loading'),
                            child: SelahLoading(),
                          )
                        : _photos.isEmpty
                        ? _PhotoEmptyState(
                            key: const ValueKey('photos-empty'),
                            working: _working,
                            onAdd: _addPhoto,
                          )
                        : _compactView
                        ? _CompactPhotoView(
                            key: const ValueKey('photos-compact-view'),
                            photos: _photos,
                            selected: _compactSelected,
                            maximumPhotos: _maximumPhotos,
                            working: _working,
                            onSelected: (index) {
                              if (_canUse) {
                                setState(() => _compactSelected = index);
                              } else {
                                _hideRevokedPreview();
                              }
                            },
                            onAdd: _addPhoto,
                            onMakeMain: () => _makeMain(_compactSelected),
                          )
                        : _PhotoGallery(
                            key: const ValueKey('photos-large-view'),
                            photos: _photos,
                            controller: _pageController,
                            selected: _currentPage,
                            working: _working,
                            onChanged: (index) {
                              if (!_canUse) return;
                              setState(() {
                                _currentPage = index;
                                _compactSelected = index;
                              });
                            },
                            onEdit: _editPhoto,
                            onRemove: _removePhoto,
                            onAdjustAvatar: _adjustAvatar,
                            onMakeMain: _makeMain,
                          ),
                  ),
                ),
                if (_working && _progressLabel != null)
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 20,
                    child: _WorkingPill(label: _progressLabel!),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
    if (_previewMode && _embedded) {
      return Material(color: Colors.transparent, child: page);
    }
    final gender = _previewMode ? _previewGender : AppState.instance.gender;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: SelahAppGoldDecoration(
          gradient: SelahColors.genderGradient(gender),
        ),
        child: page,
      ),
    );
  }
}

Widget _retainedPhotoImage(String photo, {bool showLoader = false}) =>
    photo.startsWith('assets/')
    ? Image.asset(
        photo,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) =>
            const ColoredBox(color: SelahColors.luxuryDarkPurple),
      )
    : SelahProfileImage(photo, showLoader: showLoader);

class _PhotoGallery extends StatelessWidget {
  const _PhotoGallery({
    super.key,
    required this.photos,
    required this.controller,
    required this.selected,
    required this.working,
    required this.onChanged,
    required this.onEdit,
    required this.onRemove,
    required this.onAdjustAvatar,
    required this.onMakeMain,
  });

  final List<String> photos;
  final PageController controller;
  final int selected;
  final bool working;
  final ValueChanged<int> onChanged;
  final ValueChanged<int> onEdit;
  final ValueChanged<int> onRemove;
  final VoidCallback onAdjustAvatar;
  final ValueChanged<int> onMakeMain;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Expanded(
        child: PageView.builder(
          key: const ValueKey('photos-page-view'),
          controller: controller,
          physics: const BouncingScrollPhysics(),
          itemCount: photos.length,
          onPageChanged: onChanged,
          itemBuilder: (context, index) => _LargePhotoCard(
            key: ValueKey('photo-card-$index-${photos[index]}'),
            photo: photos[index],
            index: index,
            count: photos.length,
            onEdit: working ? null : () => onEdit(index),
            onRemove: working ? null : () => onRemove(index),
            onAdjustAvatar: index == 0 && !working ? onAdjustAvatar : null,
            onMakeMain: index == 0 || working ? null : () => onMakeMain(index),
          ),
        ),
      ),
      if (photos.length > 1) ...[
        const SizedBox(height: 16),
        _PhotoPageDots(count: photos.length, selected: selected),
      ],
      const SizedBox(height: 16),
    ],
  );
}

class _LargePhotoCard extends StatefulWidget {
  const _LargePhotoCard({
    super.key,
    required this.photo,
    required this.index,
    required this.count,
    required this.onEdit,
    required this.onRemove,
    required this.onAdjustAvatar,
    required this.onMakeMain,
  });

  final String photo;
  final int index;
  final int count;
  final VoidCallback? onEdit;
  final VoidCallback? onRemove;
  final VoidCallback? onAdjustAvatar;
  final VoidCallback? onMakeMain;

  @override
  State<_LargePhotoCard> createState() => _LargePhotoCardState();
}

class _LargePhotoCardState extends State<_LargePhotoCard> {
  // Leave a deliberate breathing space between the raised photo and its
  // actions. The previous 82px reveal made the delete control look attached
  // to the image rather than like a separate action tray.
  static const double _openDistance = 126;
  double _reveal = 0;

  void _updateReveal(DragUpdateDetails details) {
    setState(() {
      _reveal = (_reveal - details.delta.dy).clamp(0, _openDistance);
    });
  }

  void _settleReveal(DragEndDetails details) {
    final shouldOpen = _reveal > 28 || (details.primaryVelocity ?? 0) < -320;
    setState(() => _reveal = shouldOpen ? _openDistance : 0);
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: widget.index == 0
        ? 'Main photo. Swipe up for photo actions.'
        : 'Photo ${widget.index + 1} of ${widget.count}. Swipe up for photo actions.',
    child: Padding(
      padding: const EdgeInsets.fromLTRB(6, 3, 6, 0),
      child: SizedBox.expand(
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            Positioned(
              left: 10,
              right: 10,
              bottom: 8,
              height: 54,
              child: _RevealedPhotoActions(
                index: widget.index,
                onEdit: widget.onEdit,
                onRemove: widget.onRemove,
                onAdjustAvatar: widget.onAdjustAvatar,
                onMakeMain: widget.onMakeMain,
              ),
            ),
            // Keep the photo's top edge anchored inside the gallery. Moving
            // the whole card upward pushed its rounded top beyond PageView's
            // clipping boundary; shortening it from the bottom reveals the
            // actions without cutting off the photo frame.
            AnimatedPositioned(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              top: 0,
              left: 0,
              right: 0,
              bottom: _reveal,
              child: GestureDetector(
                key: ValueKey('photo-large-${widget.index}'),
                onVerticalDragUpdate: _updateReveal,
                onVerticalDragEnd: _settleReveal,
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(26),
                  clipBehavior: Clip.antiAlias,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: SelahColors.surfaceFill,
                      borderRadius: BorderRadius.circular(26),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.16),
                          blurRadius: 22,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _retainedPhotoImage(widget.photo, showLoader: true),
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.transparent, Color(0x3D000000)],
                              stops: [0.74, 1],
                            ),
                          ),
                        ),
                        Positioned.fill(
                          child: IgnorePointer(
                            child: DecoratedBox(
                              key: widget.index == 0
                                  ? const ValueKey(
                                      'main-photo-solid-gold-border',
                                    )
                                  : null,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(26),
                                border: Border.all(
                                  color: widget.index == 0
                                      ? SelahColors.journeyGold
                                      : SelahColors.surfaceBorder,
                                  width: widget.index == 0 ? 2 : 0.7,
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
            ),
          ],
        ),
      ),
    ),
  );
}

class _RevealedPhotoActions extends StatelessWidget {
  const _RevealedPhotoActions({
    required this.index,
    required this.onEdit,
    required this.onRemove,
    required this.onAdjustAvatar,
    required this.onMakeMain,
  });

  final int index;
  final VoidCallback? onEdit;
  final VoidCallback? onRemove;
  final VoidCallback? onAdjustAvatar;
  final VoidCallback? onMakeMain;

  @override
  Widget build(BuildContext context) {
    final isMainPhoto = index == 0;

    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            key: ValueKey('adjust-photo-$index'),
            onPressed: onEdit,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              foregroundColor: SelahColors.foreground,
              side: BorderSide(color: SelahColors.surfaceBorder),
              backgroundColor: SelahColors.surfaceFill,
              shape: const StadiumBorder(),
            ),
            icon: const Icon(Icons.crop_rounded, size: 19),
            label: const Text('Adjust'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            key: isMainPhoto
                ? const ValueKey('adjust-main-avatar')
                : ValueKey('make-main-revealed-$index'),
            onPressed: isMainPhoto ? onAdjustAvatar : onMakeMain,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              foregroundColor: SelahColors.foreground,
              side: BorderSide(color: SelahColors.surfaceBorder),
              backgroundColor: SelahColors.surfaceFill,
              shape: const StadiumBorder(),
            ),
            icon: Icon(
              isMainPhoto
                  ? Icons.account_circle_outlined
                  : Icons.star_outline_rounded,
              size: 20,
            ),
            label: Text(isMainPhoto ? 'Edit avatar' : 'Make main'),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 52,
          height: 52,
          child: Tooltip(
            message: 'Delete photo',
            child: OutlinedButton(
              key: ValueKey('remove-photo-$index'),
              onPressed: onRemove,
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.zero,
                foregroundColor: SelahColors.destructive,
                side: BorderSide(color: SelahColors.destructiveBorder),
                backgroundColor: SelahColors.destructive.withValues(alpha: 0.08),
                shape: const CircleBorder(),
              ),
              child: const Icon(Icons.delete_outline_rounded, size: 21),
            ),
          ),
        ),
      ],
    );
  }
}

class _PhotoPageDots extends StatelessWidget {
  const _PhotoPageDots({required this.count, required this.selected});

  final int count;
  final int selected;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Photo ${selected + 1} of $count',
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var index = 0; index < count; index++)
          AnimatedContainer(
            key: ValueKey('photo-page-dot-$index'),
            duration: const Duration(milliseconds: 180),
            width: index == selected ? 22 : 5,
            height: 5,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color: index == selected
                  ? SelahColors.journeyGold
                  : SelahColors.journeyGold.withValues(alpha: 0.28),
              borderRadius: BorderRadius.circular(20),
            ),
          ),
      ],
    ),
  );
}

class _CompactPhotoView extends StatelessWidget {
  const _CompactPhotoView({
    super.key,
    required this.photos,
    required this.selected,
    required this.maximumPhotos,
    required this.working,
    required this.onSelected,
    required this.onAdd,
    required this.onMakeMain,
  });

  final List<String> photos;
  final int selected;
  final int maximumPhotos;
  final bool working;
  final ValueChanged<int> onSelected;
  final VoidCallback onAdd;
  final VoidCallback onMakeMain;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 2),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            photos.length == maximumPhotos
                ? 'All photo spaces used'
                : '${maximumPhotos - photos.length} photo ${maximumPhotos - photos.length == 1 ? 'space' : 'spaces'} available',
            style: SelahText.subtext(size: 11.5),
          ),
        ),
      ),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 10, 22, 12),
          child: LayoutBuilder(
            builder: (context, constraints) {
              const gap = 12.0;
              final tileWidth = (constraints.maxWidth - gap) / 2;
              final tileHeight = (constraints.maxHeight - (gap * 2)) / 3;
              return SizedBox(
                key: const ValueKey('photos-compact-grid'),
                width: double.infinity,
                child: Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    for (var index = 0; index < maximumPhotos; index++)
                      SizedBox(
                        width: tileWidth,
                        height: tileHeight,
                        child: index >= photos.length
                            ? _CompactAddTile(
                                index: index,
                                onTap: working ? null : onAdd,
                              )
                            : _CompactPhotoTile(
                                photo: photos[index],
                                index: index,
                                selected: index == selected,
                                working: working,
                                onSelected: onSelected,
                              ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
      SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 8, 22, 18),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: selected == 0
                ? const SizedBox(
                    key: ValueKey('compact-main-status'),
                    height: 48,
                  )
                : SizedBox(
                    key: ValueKey('make-main-$selected'),
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: working ? null : onMakeMain,
                      child: const Text('Make main photo'),
                    ),
                  ),
          ),
        ),
      ),
    ],
  );
}

class _CompactPhotoTile extends StatelessWidget {
  const _CompactPhotoTile({
    required this.photo,
    required this.index,
    required this.selected,
    required this.working,
    required this.onSelected,
  });

  final String photo;
  final int index;
  final bool selected;
  final bool working;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: index == 0 ? 'Main photo' : 'Select photo ${index + 1}',
    child: GestureDetector(
      key: ValueKey('compact-photo-$index'),
      onTap: working ? null : () => onSelected(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(17)),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _retainedPhotoImage(photo),
            if (selected)
              Positioned(
                right: 7,
                bottom: 7,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: SelahColors.journeyGold,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    size: 16,
                    color: SelahColors.luxuryDarkPurple,
                  ),
                ),
              ),
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  key: ValueKey('compact-photo-border-$index'),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(17),
                    border: Border.all(
                      color: index == 0
                          ? SelahColors.journeyGold
                          : SelahColors.surfaceBorder,
                      width: index == 0 ? 1.8 : 0.7,
                    ),
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

class _CompactAddTile extends StatelessWidget {
  const _CompactAddTile({required this.index, required this.onTap});

  final int index;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: SelahColors.surfaceFill,
    borderRadius: BorderRadius.circular(17),
    child: InkWell(
      key: ValueKey('compact-add-$index'),
      borderRadius: BorderRadius.circular(17),
      onTap: onTap,
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: SelahColors.surfaceBorder),
        ),
        child: const Center(
          child: Icon(
            Icons.add_rounded,
            color: SelahColors.journeyGold,
            size: 34,
          ),
        ),
      ),
    ),
  );
}

class _PhotoEmptyState extends StatelessWidget {
  const _PhotoEmptyState({
    super.key,
    required this.working,
    required this.onAdd,
  });

  final bool working;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => Center(
    key: const ValueKey('photos-empty-state'),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.photo_library_outlined,
            color: SelahColors.ink(0.35),
            size: 30,
          ),
          const SizedBox(height: 14),
          Text(
            'No photos yet',
            style: SelahText.heading(size: 15),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'Add your first profile photo to begin.',
            style: SelahText.subtext(size: 13.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          Opacity(
            opacity: working ? 0.42 : 1,
            child: IgnorePointer(
              ignoring: working,
              child: SelahAddCircle(
                key: const ValueKey('edit-photos-add'),
                label: null,
                onTap: onAdd,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _NineDotGridIcon extends StatelessWidget {
  const _NineDotGridIcon({required this.active, required this.enabled});

  final bool active;
  final bool enabled;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 18,
    height: 18,
    child: GridView.count(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(3),
      crossAxisCount: 3,
      mainAxisSpacing: 2,
      crossAxisSpacing: 2,
      children: [
        for (var index = 0; index < 9; index++)
          DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active && enabled
                  ? SelahColors.journeyGold
                  : SelahColors.foreground.withValues(
                      alpha: enabled ? 0.72 : 0.24,
                    ),
            ),
          ),
      ],
    ),
  );
}

class _WorkingPill extends StatelessWidget {
  const _WorkingPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final hasLabel = label.trim().isNotEmpty;
    return Center(
      child: Container(
        padding: hasLabel
            ? const EdgeInsets.symmetric(horizontal: 16, vertical: 10)
            : const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: SelahColors.luxuryDarkPurple.withValues(alpha: 0.86),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: SelahColors.surfaceBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: 16, height: 16, child: SelahLoading()),
            if (hasLabel) ...[
              const SizedBox(width: 10),
              Text(label, style: SelahText.subtext(size: 12.5)),
            ],
          ],
        ),
      ),
    );
  }
}
