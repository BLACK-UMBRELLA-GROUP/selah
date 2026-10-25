// Shared app-canvas renderer. The member choice is saved by SelahAppGoldStyle;
// the authorized developer override is temporary. Never a foreground overlay.
import 'package:flutter/material.dart';

import '../services/selah_account_state.dart';
import '../services/selah_developer_access.dart';
import '../state/app_state.dart';
import '../theme/selah_app_gold_style.dart';
import '../theme/selah_colors.dart';
import '../theme/selah_text.dart';
import 'dev_onboarding_gold_design.dart';

class SelahDevAppGold extends ChangeNotifier {
  SelahDevAppGold._() {
    SelahDeveloperAccess.authorizationChanges.addListener(_authorityChanged);
    AppState.instance.addListener(_accountChanged);
    SelahAppGoldStyle.instance.addListener(_memberChanged);
  }

  static final instance = SelahDevAppGold._();
  bool _selected = false;
  bool _hasOverride = false;
  int _generation = SelahAccountState.generation;
  int _revision = 0;
  bool _reducedMotion = false;
  final ValueNotifier<double> frame = ValueNotifier(1);
  int _painterCount = 0;

  bool get enabled =>
      _selected &&
      _generation == SelahAccountState.generation &&
      !SelahAccountState.isSigningOut &&
      SelahDeveloperAccess.canUseDeveloperTools;
  int get revision => _revision;
  bool get reducedMotion => _reducedMotion;
  bool get renderingEnabled =>
      _hasOverride &&
          _generation == SelahAccountState.generation &&
          !SelahAccountState.isSigningOut &&
          SelahDeveloperAccess.canUseDeveloperTools
      ? enabled
      : SelahAppGoldStyle.instance.enabled;

  bool select(
    bool value, {
    required int expectedGeneration,
    required int expectedRevision,
  }) {
    if (!SelahDeveloperAccess.canUseDeveloperTools ||
        SelahAccountState.isSigningOut ||
        expectedGeneration != SelahAccountState.generation ||
        expectedRevision != _revision) {
      return false;
    }
    _generation = SelahAccountState.generation;
    if (_hasOverride && _selected == value) return true;
    _hasOverride = true;
    _selected = value;
    _revision++;
    notifyListeners();
    return true;
  }

  void _authorityChanged() => _resetSelection();
  void _memberChanged() => _resetSelection();

  void _accountChanged() {
    if (_generation != SelahAccountState.generation) _resetSelection();
  }

  void _resetSelection() {
    _selected = false;
    _hasOverride = false;
    _generation = SelahAccountState.generation;
    _revision++;
    notifyListeners();
  }

  void _setReducedMotion(bool value) {
    if (_reducedMotion == value) return;
    _reducedMotion = value;
    frame.notifyListeners();
  }

  @visibleForTesting
  int get debugPainterCount => _painterCount;

  @visibleForTesting
  void resetForTesting() {
    assert(() {
      _resetSelection();
      _reducedMotion = false;
      frame.value = 1;
      return true;
    }());
  }
}

/// One clock inside the app-lock boundary. Decoration painters repaint without
/// rebuilding forms, lists, cards or the Navigator on each animation frame.
class SelahAppGoldPreviewHost extends StatefulWidget {
  const SelahAppGoldPreviewHost({super.key, required this.child});
  final Widget child;

  @override
  State<SelahAppGoldPreviewHost> createState() => _SelahAppGoldPreviewHostState();
}

class _SelahAppGoldPreviewHostState extends State<SelahAppGoldPreviewHost>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _motion;
  bool _foreground = true;
  bool _reduce = false;
  bool _tickerEnabled = true;
  final _selection = SelahDevAppGold.instance;

  @override
  void initState() {
    super.initState();
    _foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    _motion = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4800),
    )..addListener(_onFrame);
    _selection.addListener(_syncMotion);
    WidgetsBinding.instance.addObserver(this);
  }

  void _onFrame() => _selection.frame.value = _motion.value;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduce =
        MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context);
    _tickerEnabled = TickerMode.valuesOf(context).enabled;
    _selection._setReducedMotion(_reduce);
    _syncMotion();
  }

  void _syncMotion() {
    if (!mounted) return;
    if (_selection.renderingEnabled &&
        _foreground &&
        _tickerEnabled &&
        !_reduce) {
      if (!_motion.isAnimating) _motion.repeat();
    } else {
      _motion.stop();
      if (_reduce) _selection.frame.value = 1;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _syncMotion();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _selection.removeListener(_syncMotion);
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Use on full-page gradient canvases only, never on a card/photo/dialog.
/// The base BoxDecoration paints identically when Off. Gold paints after the
/// background but before the owning widget's child, so content stays above it.
class SelahAppGoldDecoration extends BoxDecoration {
  const SelahAppGoldDecoration({
    super.color,
    super.image,
    super.border,
    super.borderRadius,
    super.boxShadow,
    super.gradient,
    super.backgroundBlendMode,
    super.shape,
  });

  static SelahAppGoldDecoration _from(BoxDecoration decoration) =>
      SelahAppGoldDecoration(
        color: decoration.color,
        image: decoration.image,
        border: decoration.border,
        borderRadius: decoration.borderRadius,
        boxShadow: decoration.boxShadow,
        gradient: decoration.gradient,
        backgroundBlendMode: decoration.backgroundBlendMode,
        shape: decoration.shape,
      );

  @override
  BoxDecoration? lerpFrom(Decoration? a, double t) {
    if (a == null || a is BoxDecoration) {
      return _from(BoxDecoration.lerp(a as BoxDecoration?, this, t)!);
    }
    return super.lerpFrom(a, t);
  }

  @override
  BoxDecoration? lerpTo(Decoration? b, double t) {
    if (b == null || b is BoxDecoration) {
      return _from(BoxDecoration.lerp(this, b as BoxDecoration?, t)!);
    }
    return super.lerpTo(b, t);
  }

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) =>
      _AppGoldPainter(super.createBoxPainter(onChanged), this, onChanged);
}

class _AppGoldPainter extends BoxPainter {
  _AppGoldPainter(this._base, this._decoration, VoidCallback? onChanged)
    : super(onChanged) {
    if (onChanged != null) {
      _listening = true;
      _selection._painterCount++;
      _selection.addListener(_repaint);
      _selection.frame.addListener(_repaint);
    }
  }
  final BoxPainter _base;
  final SelahAppGoldDecoration _decoration;
  final _selection = SelahDevAppGold.instance;
  bool _listening = false;

  void _repaint() => onChanged?.call();

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    _base.paint(canvas, offset, configuration);
    final size = configuration.size;
    if (!_selection.renderingEnabled || size == null || size.isEmpty) return;
    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    canvas.clipPath(
      _decoration.getClipPath(
        Offset.zero & size,
        configuration.textDirection ?? TextDirection.ltr,
      ),
    );
    SelahOnboardingGoldPainter(
      SelahOnboardingGoldDesign.diagonalDust,
      motion: SelahOnboardingGoldMotion.liveDrift,
      motionValue: _selection.frame.value,
      reducedMotion: _selection.reducedMotion,
    ).paint(canvas, size);
    canvas.restore();
  }

  @override
  void dispose() {
    if (_listening) {
      _selection.removeListener(_repaint);
      _selection.frame.removeListener(_repaint);
      _selection._painterCount--;
      _listening = false;
    }
    _base.dispose();
    super.dispose();
  }
}

class DevAppGoldPicker extends StatelessWidget {
  const DevAppGoldPicker({super.key, this.enabled = true});
  final bool enabled;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: SelahDevAppGold.instance,
    builder: (context, _) {
      if (!SelahDeveloperAccess.canUseDeveloperTools) {
        return const SizedBox.shrink();
      }
      final selection = SelahDevAppGold.instance;
      final generation = SelahAccountState.generation;
      final revision = selection.revision;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('App gold accents', style: SelahText.body(size: 13)),
          const SizedBox(height: 6),
          Text(
            'The live diagonal gold dust on app backgrounds. Onboarding stays unchanged.',
            style: SelahText.subtext(size: 11.5),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const SelahOnboardingGoldSwatch(
                SelahOnboardingGoldDesign.diagonalDust,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  selection.renderingEnabled ? 'On' : 'Off',
                  style: SelahText.body(size: 13),
                ),
              ),
              Semantics(
                label: 'App gold accents',
                child: Switch.adaptive(
                  key: const ValueKey('dev_app_gold_toggle'),
                  value: selection.renderingEnabled,
                  activeTrackColor: SelahColors.journeyGold,
                  onChanged: enabled
                      ? (value) => selection.select(
                          value,
                          expectedGeneration: generation,
                          expectedRevision: revision,
                        )
                      : null,
                ),
              ),
            ],
          ),
        ],
      );
    },
  );
}
