import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../models/selah_known_person_code.dart';
import '../theme/selah_colors.dart';
import '../theme/selah_text.dart';

/// Retained code-entry presentation with all lookup and action authority owned
/// by its caller. This widget does not resolve codes or create connections.
class SelahKnownPersonCodeContent extends StatelessWidget {
  const SelahKnownPersonCodeContent({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.preview,
    required this.busy,
    required this.onScan,
    required this.onCheck,
    required this.onReset,
    required this.resultAction,
    required this.resultActionLabel,
    this.resultActionKey = const ValueKey('known-person-consider'),
    this.introDetail,
    this.resultDetail,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final SelahKnownPersonCodePreview? preview;
  final bool busy;
  final VoidCallback? onScan;
  final VoidCallback onCheck;
  final VoidCallback onReset;
  final VoidCallback? resultAction;
  final String resultActionLabel;
  final Key? resultActionKey;
  final String? introDetail;
  final String? resultDetail;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _KnownPersonIntro(onScan: busy ? null : onScan, detail: introDetail),
      const SizedBox(height: 20),
      _KnownPersonEntryCard(
        controller: controller,
        focusNode: focusNode,
        preview: preview,
        busy: busy,
        onCheck: onCheck,
        onReset: onReset,
        resultAction: resultAction,
        resultActionLabel: resultActionLabel,
        resultActionKey: resultActionKey,
        detail: resultDetail,
      ),
    ],
  );
}

class _KnownPersonIntro extends StatelessWidget {
  const _KnownPersonIntro({required this.onScan, required this.detail});

  final VoidCallback? onScan;
  final String? detail;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: SelahColors.accentBg,
          border: Border.all(color: SelahColors.accentBorder),
        ),
        child: Icon(
          Icons.person_search_outlined,
          size: 27,
          color: SelahColors.surfaceSignal,
        ),
      ),
      const SizedBox(height: 16),
      Text(
        'Already know someone?',
        textAlign: TextAlign.center,
        style: SelahText.heading(size: 22),
      ),
      const SizedBox(height: 8),
      Text(
        detail ??
            'Scan or enter their permanent SELAH Code. You can then Consider '
                'them through the normal matching process.',
        textAlign: TextAlign.center,
        style: SelahText.subtext(size: 12.5),
      ),
      const SizedBox(height: 18),
      SelahKnownPersonCodePill(
        icon: Icons.qr_code_scanner_rounded,
        label: 'Scan code',
        onTap: onScan,
      ),
    ],
  );
}

class _KnownPersonEntryCard extends StatelessWidget {
  const _KnownPersonEntryCard({
    required this.controller,
    required this.focusNode,
    required this.preview,
    required this.busy,
    required this.onCheck,
    required this.onReset,
    required this.resultAction,
    required this.resultActionLabel,
    required this.resultActionKey,
    required this.detail,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final SelahKnownPersonCodePreview? preview;
  final bool busy;
  final VoidCallback onCheck;
  final VoidCallback onReset;
  final VoidCallback? resultAction;
  final String resultActionLabel;
  final Key? resultActionKey;
  final String? detail;

  Widget _resultActions(BuildContext context) {
    final reset = SelahKnownPersonCodePill(
      key: const ValueKey('known-person-different-code'),
      icon: Icons.refresh_rounded,
      label: 'Different code',
      onTap: busy ? null : onReset,
    );
    final result = SelahKnownPersonCodePill(
      key: resultActionKey,
      icon: Icons.person_add_alt_1_outlined,
      label: busy ? 'Sending…' : resultActionLabel,
      onTap: busy ? null : resultAction,
    );
    if (MediaQuery.textScalerOf(context).scale(12.5) > 18.75) {
      // Retain the original row at ordinary text sizes. At large text sizes,
      // full-width actions keep their names readable instead of truncating.
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [reset, const SizedBox(height: 10), result],
      );
    }
    return Row(
      children: [
        Expanded(child: reset),
        const SizedBox(width: 10),
        Expanded(child: result),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: SelahColors.surfaceFill,
      border: Border.all(color: SelahColors.surfaceBorder),
      borderRadius: BorderRadius.circular(22),
    ),
    child: AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: preview == null
          ? Column(
              key: const ValueKey('known-code-entry'),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  key: const ValueKey('known-person-code-field'),
                  controller: controller,
                  focusNode: focusNode,
                  textCapitalization: TextCapitalization.characters,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => busy ? null : onCheck(),
                  style: SelahText.body(size: 14),
                  decoration: InputDecoration(
                    hintText: 'SELAH-XXXX-XXXX-XXXX-XXXX-XXXX',
                    prefixIcon: Icon(
                      Icons.keyboard_outlined,
                      color: SelahColors.surfaceSignal,
                    ),
                    filled: true,
                    fillColor: SelahColors.iconButtonBg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                SelahKnownPersonCodePill(
                  key: const ValueKey('known-person-check-code'),
                  icon: Icons.search_rounded,
                  label: busy ? 'Checking…' : 'Check code',
                  onTap: busy ? null : onCheck,
                ),
              ],
            )
          : Column(
              key: const ValueKey('known-code-confirmation'),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: SelahColors.accentBg,
                        border: Border.all(color: SelahColors.accentBorder),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        preview!.firstName.substring(0, 1).toUpperCase(),
                        style: SelahText.heading(
                          size: 21,
                          color: SelahColors.surfaceSignal,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            preview!.firstName,
                            style: SelahText.heading(size: 17),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${preview!.age} · ${preview!.city}',
                            style: SelahText.subtext(size: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 13),
                Text(
                  detail ??
                      'Confirm this is the right person. They will only become '
                          'a Match if they also Consider you.',
                  style: SelahText.subtext(size: 11.5),
                ),
                const SizedBox(height: 16),
                _resultActions(context),
              ],
            ),
    ),
  );
}

/// The original code-entry action styling, shared without transport behavior.
class SelahKnownPersonCodePill extends StatelessWidget {
  const SelahKnownPersonCodePill({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: SelahColors.accentBg,
    borderRadius: BorderRadius.circular(999),
    child: InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          border: Border.all(color: SelahColors.accentBorder),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: SelahColors.surfaceSignal),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                label,
                maxLines: MediaQuery.textScalerOf(context).scale(12.5) > 18.75
                    ? null
                    : 1,
                overflow: MediaQuery.textScalerOf(context).scale(12.5) > 18.75
                    ? TextOverflow.visible
                    : TextOverflow.ellipsis,
                style: SelahText.body(
                  size: 12.5,
                  color: SelahColors.surfaceSignal,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Native camera capture only. Code lookup, admission and any result action
/// remain caller-owned; a captured prefix is not validation or payment proof.
///
/// Hosts must give this inline widget bounded camera-preview constraints and
/// rebuild or remove it when their capture authority changes.
class SelahCodeCapture extends StatefulWidget {
  const SelahCodeCapture({
    super.key,
    required this.canCapture,
    required this.onCode,
    required this.onManualEntry,
  });

  final bool Function() canCapture;
  final ValueChanged<String> onCode;
  final VoidCallback onManualEntry;

  @override
  State<SelahCodeCapture> createState() => _SelahCodeCaptureState();
}

class _SelahCodeCaptureState extends State<SelahCodeCapture>
    with WidgetsBindingObserver {
  final MobileScannerController _controller = MobileScannerController(
    autoStart: false,
  );
  Future<void> _cameraWork = Future<void>.value();
  ModalRoute<dynamic>? _route;
  AppLifecycleState? _lifecycleState;
  bool _handled = false;
  bool _cameraFailed = false;
  bool _disposed = false;
  bool _admissionRevoked = false;

  bool get _canAccept {
    if (!mounted ||
        _disposed ||
        _handled ||
        _admissionRevoked ||
        (_lifecycleState != null &&
            _lifecycleState != AppLifecycleState.resumed) ||
        !(_route?.isCurrent ?? false)) {
      return false;
    }
    try {
      if (widget.canCapture()) return true;
    } catch (_) {
      // A failed caller guard is a denial, never camera admission.
    }
    _admissionRevoked = true;
    return false;
  }

  @override
  void initState() {
    super.initState();
    _lifecycleState = WidgetsBinding.instance.lifecycleState;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route = ModalRoute.of(context);
    _scheduleCameraSync();
  }

  @override
  void didUpdateWidget(covariant SelahCodeCapture oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scheduleCameraSync();
  }

  void _scheduleCameraSync() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_disposed) _queueCameraSync();
    });
  }

  void _queueCameraSync() {
    if (_disposed) return;
    _cameraWork = _cameraWork.then((_) => _syncCamera());
  }

  Future<void> _syncCamera() async {
    if (_disposed || !mounted) return;
    try {
      if (!_canAccept || _cameraFailed) {
        await _controller.stop();
        return;
      }
      await _controller.start();
      if (_disposed || !mounted) return;
      if (!_canAccept) {
        await _controller.stop();
      } else if (_controller.value.error != null) {
        _showCameraFailure();
      }
    } catch (_) {
      if (_canAccept) _showCameraFailure();
    }
  }

  void _showCameraFailure() {
    if (!mounted || _disposed || _cameraFailed) return;
    setState(() => _cameraFailed = true);
    _queueCameraSync();
  }

  void _onDetect(BarcodeCapture capture) {
    if (!_canAccept || _cameraFailed) return;
    for (final barcode in capture.barcodes) {
      final code = barcode.rawValue?.trim();
      if (code == null ||
          code.length > 200 ||
          !code.toUpperCase().startsWith('SELAH-')) {
        continue;
      }
      _handled = true;
      _queueCameraSync();
      widget.onCode(code);
      return;
    }
  }

  void _onManualEntry() {
    if (!_canAccept) return;
    _handled = true;
    _queueCameraSync();
    widget.onManualEntry();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycleState = state;
    _queueCameraSync();
  }

  Future<void> _disposeCamera() async {
    try {
      await _cameraWork;
    } catch (_) {
      // Disposal still releases the controller if queued camera work failed.
    }
    try {
      await _controller.stop();
    } catch (_) {
      // A denied or detached camera may already be stopped.
    }
    try {
      await _controller.dispose();
    } catch (_) {
      // No camera failure may escape an already-disposed page.
    }
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_disposeCamera());
    super.dispose();
  }

  Widget _cameraFallback() => ColoredBox(
    color: Colors.black,
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.qr_code_scanner_rounded,
              color: SelahColors.surfaceSignal,
              size: 30,
            ),
            const SizedBox(height: 14),
            Text(
              'Camera unavailable. Enter the code instead.',
              textAlign: TextAlign.center,
              style: SelahText.subtext(size: 12.5),
            ),
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      if (_cameraFailed)
        _cameraFallback()
      else
        MobileScanner(
          controller: _controller,
          useAppLifecycleState: false,
          onDetect: _onDetect,
          onDetectError: (_, _) {
            if (_canAccept) _showCameraFailure();
          },
          errorBuilder: (_, _) => _cameraFallback(),
        ),
      Positioned(
        left: 24,
        right: 24,
        bottom: 24,
        child: SafeArea(
          top: false,
          child: SelahKnownPersonCodePill(
            key: const ValueKey('known-person-camera-manual-entry'),
            icon: Icons.keyboard_outlined,
            label: 'Enter code instead',
            onTap: _canAccept ? _onManualEntry : null,
          ),
        ),
      ),
    ],
  );
}
