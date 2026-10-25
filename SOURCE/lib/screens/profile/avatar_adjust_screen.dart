import 'dart:async';

import 'package:flutter/material.dart';
import '../../dev/selah_app_gold_preview.dart';

import '../../state/app_state.dart';
import '../../theme/selah_colors.dart';
import '../../theme/selah_interaction_style.dart';
import '../../theme/selah_text.dart';
import '../../widgets/selah_profile_image.dart';
import '../../widgets/selah_pull_down_back_scope.dart';

class AvatarAdjustScreen extends StatefulWidget {
  const AvatarAdjustScreen({
    super.key,
    required this.photo,
    required this.initialAlignmentX,
    required this.initialAlignmentY,
    this.preview = false,
    this.gender,
    this.canAct,
    this.hapticLevel,
  });

  final String photo;
  final double initialAlignmentX;
  final double initialAlignmentY;
  final bool preview;
  final String? gender;
  final bool Function()? canAct;
  final SelahHapticLevel? hapticLevel;

  @override
  State<AvatarAdjustScreen> createState() => _AvatarAdjustScreenState();
}

class _AvatarAdjustScreenState extends State<AvatarAdjustScreen> {
  late final bool _preview = widget.preview;
  late final bool Function()? _ownerGuard = widget.canAct;
  late final String? _gender = widget.gender;
  final Object _returnIdentity = Object();
  bool _revoked = false;
  // The shared pull scope binds this callback for the route's whole lifetime.
  // ignore: prefer_function_declarations_over_variables
  late final VoidCallback _return = () {
    if (_current) {
      Navigator.of(context).pop();
    } else if (mounted) {
      setState(() {});
    }
  };

  bool get _current {
    if (!mounted || _revoked || widget.preview != _preview) return false;
    if (!_preview && _ownerGuard == null) return true;
    try {
      final uri = Uri.tryParse(widget.photo);
      final local =
          widget.photo.startsWith('data:image/') &&
              widget.photo.contains(';base64,') ||
          widget.photo.startsWith('assets/') &&
              uri != null &&
              !uri.hasScheme &&
              !uri.hasAuthority &&
              !uri.hasQuery &&
              !uri.hasFragment &&
              !widget.photo.contains('..') &&
              !widget.photo.contains('\\');
      if ((_preview && !local) ||
          _ownerGuard?.call() != true ||
          widget.canAct?.call() != true) {
        _revoked = true;
        return false;
      }
    } catch (_) {
      _revoked = true;
      return false;
    }
    return ModalRoute.of(context)?.isCurrent ?? true;
  }

  late double _alignmentX = widget.initialAlignmentX
      .clamp(-1.0, 1.0)
      .toDouble();
  late double _alignmentY = widget.initialAlignmentY
      .clamp(-1.0, 1.0)
      .toDouble();

  void _move(DragUpdateDetails details) {
    if (!_current) {
      if (mounted) setState(() {});
      return;
    }
    setState(() {
      // Alignment offsets move the rendered image opposite to their sign.
      // Subtracting the finger delta makes the photo follow the member's
      // finger, which is how a direct-manipulation crop should feel.
      _alignmentX = (_alignmentX - (details.delta.dx / 120))
          .clamp(-1.0, 1.0)
          .toDouble();
      _alignmentY = (_alignmentY - (details.delta.dy / 120))
          .clamp(-1.0, 1.0)
          .toDouble();
    });
  }

  void _save() {
    if (!_current) {
      if (mounted) setState(() {});
      return;
    }
    unawaited(
      SelahInteractionStyle.emitSelectionHaptic(
        level: _preview
            ? widget.hapticLevel ??
                  SelahInteractionStyle.currentDefaultHapticLevel
            : null,
      ),
    );
    Navigator.of(context).pop(Offset(_alignmentX, _alignmentY));
  }

  @override
  Widget build(BuildContext context) {
    if ((_preview && !_current) || widget.preview != _preview) {
      return const SizedBox.expand(key: ValueKey('avatar-preview-unavailable'));
    }
    final page = Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: _preview
            ? null
            : SelahAppGoldDecoration(
                gradient: SelahColors.genderGradient(
                  _preview ? _gender : AppState.instance.gender,
                ),
              ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (_needsScroll(context, constraints)) {
                return SingleChildScrollView(
                  key: const ValueKey('avatar-adjust-accessible-scroll'),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Column(
                      children: [
                        _header(),
                        const SizedBox(height: 24),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 34),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox.square(
                                dimension: (constraints.maxWidth - 68)
                                    .clamp(128.0, 286.0)
                                    .toDouble(),
                                child: _avatar(),
                              ),
                              const SizedBox(height: 24),
                              _instructions(),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        _controls(),
                      ],
                    ),
                  ),
                );
              }
              return Column(
                children: [
                  _header(),
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 34),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              fit: FlexFit.loose,
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 286,
                                  maxHeight: 286,
                                ),
                                child: AspectRatio(
                                  aspectRatio: 1,
                                  child: _avatar(),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            _instructions(),
                          ],
                        ),
                      ),
                    ),
                  ),
                  _controls(),
                ],
              );
            },
          ),
        ),
      ),
    );
    if (!_preview) return page;
    return SelahPullDownBackScope(
      routeIdentity: _returnIdentity,
      onBack: _return,
      enabled: _current,
      child: page,
    );
  }

  bool _needsScroll(BuildContext context, BoxConstraints constraints) {
    final inherited = DefaultTextStyle.of(context).style;
    double textHeight(String text, TextStyle style, double width) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: inherited.merge(style)),
        textScaler: MediaQuery.textScalerOf(context),
        textDirection: Directionality.of(context),
      )..layout(maxWidth: width.clamp(1.0, double.infinity).toDouble());
      final height = painter.height;
      painter.dispose();
      return height;
    }

    final title = textHeight(
      'Adjust avatar',
      SelahText.heading(size: _preview ? 28 : 20),
      constraints.maxWidth - (_preview ? 40 : 82),
    );
    final instructions = textHeight(
      'Drag in any direction to position your avatar.',
      SelahText.subtext(size: 13),
      constraints.maxWidth - 95,
    );
    // Preserve full-size text and a usable avatar when the title/instructions
    // exhaust the viewport. Ordinary screens retain the centered composition.
    final label = Theme.of(context).textTheme.labelLarge!;
    final controls = textHeight(
      'Reset',
      label,
      (constraints.maxWidth - 60) / 2 - 48,
    );
    final headerHeight =
        (title < 48 && !_preview ? 48.0 : title) + (_preview ? 24 : 15);
    final controlsHeight = (controls + 16).clamp(48.0, double.infinity) + 30;
    return constraints.maxHeight <
        headerHeight + controlsHeight + instructions + 24 + 128 + 24;
  }

  Widget _header() => Padding(
    padding: _preview
        ? const EdgeInsets.fromLTRB(20, 16, 20, 8)
        : const EdgeInsets.fromLTRB(10, 7, 20, 8),
    child: Row(
      children: [
        if (!_preview)
          IconButton(
            tooltip: 'Back',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          ),
        if (!_preview) const SizedBox(width: 4),
        Expanded(
          child: Text(
            'Adjust avatar',
            style: SelahText.heading(size: _preview ? 28 : 20),
          ),
        ),
      ],
    ),
  );

  Widget _avatar() => GestureDetector(
    key: const ValueKey('avatar-adjust-drag'),
    behavior: HitTestBehavior.opaque,
    onPanUpdate: _move,
    child: Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: SelahColors.journeyGold, width: 2.4),
        boxShadow: [
          BoxShadow(
            color: SelahColors.journeyGold.withValues(alpha: .18),
            blurRadius: 22,
          ),
        ],
      ),
      child: ClipOval(
        child: _preview && widget.photo.startsWith('assets/')
            ? Transform.scale(
                scale: SelahAvatarImage.cropScale,
                alignment: Alignment(_alignmentX, _alignmentY),
                child: Image.asset(
                  widget.photo,
                  fit: BoxFit.cover,
                  alignment: Alignment(_alignmentX, _alignmentY),
                ),
              )
            : SelahAvatarImage(
                widget.photo,
                alignmentX: _alignmentX,
                alignmentY: _alignmentY,
                showLoader: true,
              ),
      ),
    ),
  );

  Widget _instructions() => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(Icons.open_with_rounded, size: 18, color: SelahColors.ink(.68)),
      const SizedBox(width: 9),
      Flexible(
        child: Text(
          'Drag in any direction to position your avatar.',
          textAlign: TextAlign.center,
          style: SelahText.subtext(size: 13),
        ),
      ),
    ],
  );

  Widget _controls() => Padding(
    padding: const EdgeInsets.fromLTRB(24, 8, 24, 22),
    child: Row(
      children: [
        Expanded(
          child: OutlinedButton(
            key: const ValueKey('avatar-adjust-reset'),
            onPressed: () {
              if (!_current) {
                if (mounted) setState(() {});
                return;
              }
              setState(() {
                _alignmentX = 0;
                _alignmentY = 0;
              });
            },
            child: const Text('Reset'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton(
            key: const ValueKey('avatar-adjust-save'),
            onPressed: _save,
            child: const Text('Save'),
          ),
        ),
      ],
    ),
  );
}
