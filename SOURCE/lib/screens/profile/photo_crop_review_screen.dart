import 'dart:typed_data';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';
import '../../dev/selah_app_gold_preview.dart';

import '../../services/selah_profile_photo_processor.dart';
import '../../state/app_state.dart';
import '../../theme/selah_colors.dart';
import '../../theme/selah_text.dart';
import '../../widgets/selah_loading.dart';
import '../../widgets/selah_pull_down_back_scope.dart';

/// SELAH-owned crop queue for a batch selected from the native
/// photo picker. Nothing leaves this screen until every photo is approved.
class PhotoCropReviewScreen extends StatefulWidget {
  const PhotoCropReviewScreen({
    super.key,
    required this.photos,
    this.preview = false,
    this.gender,
    this.canAct,
  });

  final List<Uint8List> photos;
  final bool preview;
  final String? gender;
  final bool Function()? canAct;

  @override
  State<PhotoCropReviewScreen> createState() => _PhotoCropReviewScreenState();
}

class _PhotoCropReviewScreenState extends State<PhotoCropReviewScreen> {
  static const double _profileRatio = 3 / 4;

  final List<Uint8List> _approved = [];
  late Uint8List _current;
  late CropController _cropController;
  int _index = 0;
  int _editorRevision = 0;
  bool _ready = false;
  bool _cropping = false;
  bool _rotating = false;
  String? _error;
  late final bool _preview = widget.preview;
  late final bool Function()? _ownerGuard = widget.canAct;
  final Object _returnIdentity = Object();
  bool _revoked = false;
  late final List<Uint8List> _reviewPhotos;
  // The shared pull scope binds this callback for the route's whole lifetime.
  // ignore: prefer_function_declarations_over_variables
  late final VoidCallback _return = () {
    if (_canUse && !_busy) {
      Navigator.of(context).pop();
    } else if (mounted) {
      setState(() {});
    }
  };

  bool get _canUse {
    if (!mounted || _revoked || widget.preview != _preview) return false;
    if (!_preview && _ownerGuard == null) return true;
    try {
      if (_ownerGuard?.call() != true || widget.canAct?.call() != true) {
        _revoked = true;
        return false;
      }
    } catch (_) {
      _revoked = true;
      return false;
    }
    return ModalRoute.of(context)?.isCurrent ?? true;
  }

  bool _checkCurrent() {
    if (_canUse) return true;
    if (mounted) setState(() {});
    return false;
  }

  @override
  void initState() {
    super.initState();
    _reviewPhotos = _preview
        ? List<Uint8List>.unmodifiable(widget.photos.map(Uint8List.fromList))
        : widget.photos;
    _current = _reviewPhotos.first;
    _cropController = CropController();
  }

  bool get _busy => _cropping || _rotating;
  bool get _last => _index == _reviewPhotos.length - 1;

  void _confirmCrop() {
    if (!_checkCurrent() || !_ready || _busy) return;
    setState(() {
      _cropping = true;
      _error = null;
    });
    _cropController.crop();
  }

  void _onCropped(CropResult result) {
    if (!_checkCurrent()) return;
    switch (result) {
      case CropSuccess(:final croppedImage):
        _acceptCrop(croppedImage);
      case CropFailure():
        setState(() {
          _cropping = false;
          _error = "That crop couldn't be prepared. Please adjust and retry.";
        });
    }
  }

  Future<void> _rotate() async {
    if (!_checkCurrent() || _busy) return;
    setState(() {
      _rotating = true;
      _error = null;
    });
    try {
      final rotated = await SelahProfilePhotoProcessor.rotateClockwise(
        _current,
      );
      if (!_checkCurrent()) return;
      setState(() {
        _current = rotated;
        _cropController = CropController();
        _editorRevision++;
        _ready = false;
        _rotating = false;
      });
    } catch (_) {
      if (!_checkCurrent()) return;
      setState(() {
        _rotating = false;
        _error = "That photo couldn't be rotated.";
      });
    }
  }

  void _resetCrop() {
    if (!_checkCurrent() || _busy) return;
    setState(() {
      _cropController = CropController();
      _editorRevision++;
      _ready = false;
      _error = null;
    });
  }

  void _acceptCrop(Uint8List croppedImage) {
    if (!_checkCurrent()) return;
    _approved.add(croppedImage);
    if (_last) {
      Navigator.of(context).pop(List<Uint8List>.unmodifiable(_approved));
      return;
    }
    setState(() {
      _index++;
      _current = _reviewPhotos[_index];
      _cropController = CropController();
      _editorRevision++;
      _ready = false;
      _cropping = false;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if ((_preview && !_canUse) || widget.preview != _preview) {
      return const SizedBox.expand(key: ValueKey('crop-preview-unavailable'));
    }
    final page = PopScope(
      canPop: !_busy,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Container(
          key: const ValueKey('photo-editor-selah-background'),
          decoration: _preview
              ? null
              : SelahAppGoldDecoration(
                  gradient: SelahColors.genderGradient(
                    AppState.instance.gender,
                  ),
                ),
          child: SafeArea(
            child: Column(
              children: [
                _Header(
                  index: _index,
                  total: _reviewPhotos.length,
                  enabled: !_busy,
                  preview: _preview,
                  onCancel: _return,
                ),
                Expanded(child: _cropEditor()),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                    child: Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: SelahText.subtext(
                        size: 12.5,
                        color: SelahColors.negativeRed,
                      ),
                    ),
                  ),
                _cropControls(),
              ],
            ),
          ),
        ),
      ),
    );
    if (!_preview) return page;
    return SelahPullDownBackScope(
      routeIdentity: _returnIdentity,
      onBack: _return,
      enabled: _canUse && !_busy,
      child: page,
    );
  }

  Widget _cropEditor() => Padding(
    key: const ValueKey('crop-editor'),
    padding: const EdgeInsets.fromLTRB(18, 8, 18, 4),
    child: Center(
      child: AspectRatio(
        key: const ValueKey('photo-crop-canvas'),
        aspectRatio: _profileRatio,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Crop(
            key: ValueKey('crop-$_index-$_editorRevision'),
            image: _current,
            controller: _cropController,
            onCropped: _onCropped,
            aspectRatio: _profileRatio,
            // The canvas itself is the final 3:4 crop. Keeping a smaller crop
            // rect inside a second dark frame made a fully zoomed-out photo
            // look as though it sat inside an unrelated larger box.
            initialRectBuilder: InitialRectBuilder.withSizeAndRatio(
              size: 1,
              aspectRatio: _profileRatio,
            ),
            interactive: true,
            fixCropRect: true,
            radius: 0,
            baseColor: SelahColors.luxuryDarkPurple,
            maskColor: Colors.transparent,
            // A fixed crop cannot be resized, so visible corner controls were
            // misleading. Pinch and drag are the only available gestures.
            cornerDotBuilder: (size, _) => SizedBox.square(dimension: size),
            filterQuality: FilterQuality.high,
            progressIndicator: const SelahLoading(),
            onStatusChanged: (status) {
              if (!mounted || !_canUse) return;
              final ready = status == CropStatus.ready;
              if (_ready != ready) setState(() => _ready = ready);
            },
            overlayBuilder: (_, _) => const _CropGuide(),
          ),
        ),
      ),
    ),
  );

  Widget _cropControls() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
    child: Column(
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                key: const ValueKey('photo-crop-rotate'),
                onPressed: _busy ? null : _rotate,
                icon: const Icon(Icons.rotate_90_degrees_cw_outlined),
                label: const Text('Rotate'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                key: const ValueKey('photo-crop-reset'),
                onPressed: _busy ? null : _resetCrop,
                icon: const Icon(Icons.refresh),
                label: const Text('Reset'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            key: const ValueKey('photo-crop-confirm'),
            onPressed: !_ready || _busy ? null : _confirmCrop,
            child: _busy
                ? const SizedBox(width: 18, height: 18, child: SelahLoading())
                : Text(
                    _reviewPhotos.length == 1
                        ? 'Confirm photo'
                        : (_last ? 'Finish' : 'Continue'),
                  ),
          ),
        ),
      ],
    ),
  );
}

class _Header extends StatelessWidget {
  const _Header({
    required this.index,
    required this.total,
    required this.enabled,
    required this.preview,
    required this.onCancel,
  });

  final int index;
  final int total;
  final bool enabled;
  final bool preview;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) => Padding(
    padding: preview
        ? const EdgeInsets.fromLTRB(20, 16, 20, 8)
        : const EdgeInsets.fromLTRB(8, 6, 20, 8),
    child: Row(
      children: [
        if (!preview)
          IconButton(
            tooltip: 'Cancel photo editing',
            onPressed: enabled ? onCancel : null,
            icon: const Icon(Icons.close, color: Colors.white),
          ),
        if (!preview) const SizedBox(width: 4),
        Expanded(
          child: Text(
            'Crop photo',
            style: SelahText.heading(
              size: preview ? 28 : 20,
              color: Colors.white,
            ),
          ),
        ),
        Text(
          '${index + 1} / $total',
          style: SelahText.subtext(size: 12.5, color: Colors.white70),
        ),
      ],
    ),
  );
}

class _CropGuide extends StatelessWidget {
  const _CropGuide();

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _CropGuidePainter(), child: const SizedBox.expand());
}

class _CropGuidePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = Colors.white.withValues(alpha: 0.30)
      ..strokeWidth = 0.7;
    for (final fraction in const [1 / 3, 2 / 3]) {
      canvas.drawLine(
        Offset(size.width * fraction, 0),
        Offset(size.width * fraction, size.height),
        grid,
      );
      canvas.drawLine(
        Offset(0, size.height * fraction),
        Offset(size.width, size.height * fraction),
        grid,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
