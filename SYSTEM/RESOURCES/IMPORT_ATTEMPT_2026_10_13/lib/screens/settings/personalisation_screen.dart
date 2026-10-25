import 'package:flutter/material.dart';

import '../../dev/selah_app_gold_preview.dart';
import '../../services/selah_account_state.dart';
import '../../services/selah_local_prefs.dart';
import '../../state/app_state.dart';
import '../../theme/selah_app_gold_style.dart';
import '../../theme/selah_colors.dart';
import '../../theme/selah_interaction_style.dart';
import '../../theme/selah_text.dart';
import '../../widgets/selah_personalisation_content.dart';

/// Member choices retain the existing preference coordinators. The explicit
/// preview constructor publishes caller-owned presentation intentions only.
class PersonalisationScreen extends StatefulWidget {
  const PersonalisationScreen({super.key})
    : _preview = false,
      _canAct = null,
      palette = null,
      hapticLevel = null,
      goldEnabled = null,
      onPaletteChanged = null,
      onHapticChanged = null,
      onGoldChanged = null,
      embedded = false;

  const PersonalisationScreen.preview({
    super.key,
    required bool Function() canAct,
    required SelahDevPalette this.palette,
    required SelahHapticLevel this.hapticLevel,
    required bool this.goldEnabled,
    required ValueChanged<SelahDevPalette> this.onPaletteChanged,
    required ValueChanged<SelahHapticLevel> this.onHapticChanged,
    required ValueChanged<bool> this.onGoldChanged,
    this.embedded = true,
  }) : _preview = true,
       // Public guard name stays separate from private admission storage.
       // ignore: prefer_initializing_formals
       _canAct = canAct;

  final bool _preview;
  final bool Function()? _canAct;
  final SelahDevPalette? palette;
  final SelahHapticLevel? hapticLevel;
  final bool? goldEnabled;
  final ValueChanged<SelahDevPalette>? onPaletteChanged;
  final ValueChanged<SelahHapticLevel>? onHapticChanged;
  final ValueChanged<bool>? onGoldChanged;
  final bool embedded;

  static List<SelahDevPalette> get availablePalettes =>
      SelahDevPalette.values.where((palette) => !palette.isLight).toList();

  @override
  State<PersonalisationScreen> createState() => _PersonalisationScreenState();
}

class _PersonalisationScreenState extends State<PersonalisationScreen>
    with WidgetsBindingObserver {
  late final bool _previewMode;
  late final bool _embedded;
  late final bool Function()? _previewOwner;
  late final String? _memberOwner;
  late final int _memberGeneration;
  late final int _preferenceGeneration;
  ModalRoute<dynamic>? _route;
  AppLifecycleState? _lifecycle;
  bool _revoked = false;
  bool _admissionObserved = false;
  bool _pickerOpen = false;
  int _revision = 0;

  bool get _routeCurrent => _route?.isCurrent ?? false;

  bool get _admitted {
    if (!mounted || _revoked) return false;
    if (widget._preview != _previewMode) {
      _revoke();
      return false;
    }
    if (_previewMode) {
      // An owner may include parent-route currentness. An owned choice sheet
      // temporarily covers that route; recheck admission before and after it,
      // not by treating its temporary cover as permanent owner revocation.
      if (!_routeCurrent) return _route != null && _admissionObserved;
      try {
        if (_previewOwner?.call() == true && widget._canAct?.call() == true) {
          _admissionObserved = true;
          return true;
        }
      } catch (_) {
        // An exceptional owner check is denial, never member preference access.
      }
      _revoke();
      return false;
    }
    if (!SelahAccountState.isSigningOut &&
        _memberOwner == SelahAccountState.userId &&
        _memberGeneration == SelahAccountState.generation &&
        _preferenceGeneration == SelahLocalPrefs.bindingGeneration) {
      return true;
    }
    _revoke();
    return false;
  }

  bool get _current =>
      mounted &&
      _routeCurrent &&
      (_lifecycle == null || _lifecycle == AppLifecycleState.resumed) &&
      _admitted;

  SelahPersonalisationSnapshot get _snapshot => SelahPersonalisationSnapshot(
    palette: _previewMode ? widget.palette! : SelahColors.devPalette,
    hapticLevel: _previewMode
        ? widget.hapticLevel!
        : SelahInteractionStyle.hapticLevel,
    goldEnabled: _previewMode
        ? widget.goldEnabled!
        : SelahAppGoldStyle.instance.enabled,
  );

  @override
  void initState() {
    super.initState();
    _previewMode = widget._preview;
    _embedded = widget.embedded;
    _previewOwner = widget._canAct;
    _memberOwner = SelahAccountState.userId;
    _memberGeneration = SelahAccountState.generation;
    _preferenceGeneration = SelahLocalPrefs.bindingGeneration;
    _lifecycle = WidgetsBinding.instance.lifecycleState;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route = ModalRoute.of(context);
    // Unrelated cover revokes retained callbacks. Our own sheet is independently
    // guarded and only returns an intent for the restored parent to evaluate.
    if (!_routeCurrent && !_pickerOpen) ++_revision;
  }

  @override
  void didUpdateWidget(covariant PersonalisationScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget._preview != _previewMode) {
      _revoke();
      return;
    }
    if (oldWidget._canAct != widget._canAct ||
        oldWidget.palette != widget.palette ||
        oldWidget.hapticLevel != widget.hapticLevel ||
        oldWidget.goldEnabled != widget.goldEnabled ||
        oldWidget.onPaletteChanged != widget.onPaletteChanged ||
        oldWidget.onHapticChanged != widget.onHapticChanged ||
        oldWidget.onGoldChanged != widget.onGoldChanged) {
      ++_revision;
    }
  }

  void _revoke() {
    _revoked = true;
    ++_revision;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycle = state;
    if (state != AppLifecycleState.resumed) ++_revision;
  }

  @override
  void dispose() {
    ++_revision;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<T?> _choose<T>(
    String title,
    List<T> options,
    T selected,
    String Function(T) labelFor, {
    String? Function(T)? detailFor,
    Widget Function(T)? leadingFor,
  }) async {
    if (!_current || _pickerOpen) return null;
    final revision = _revision;
    _pickerOpen = true;
    try {
      final choice = await showModalBottomSheet<T>(
        context: context,
        isScrollControlled: true,
        backgroundColor: SelahColors.sheetSurface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (sheetContext) => SelahPersonalisationChoiceSheet<T>(
          title: title,
          options: options,
          selected: selected,
          labelFor: labelFor,
          detailFor: detailFor,
          leadingFor: leadingFor,
          onSelected: (value) {
            if (!mounted ||
                !sheetContext.mounted ||
                ModalRoute.of(sheetContext)?.isCurrent != true) {
              return;
            }
            // No preference setter executes under the covering modal.
            Navigator.of(
              sheetContext,
            ).pop(revision == _revision && !_revoked ? value : null);
          },
        ),
      );
      if (!mounted || revision != _revision || !_current) return null;
      return choice;
    } finally {
      _pickerOpen = false;
    }
  }

  Future<void> _chooseBackground() async {
    final before = _snapshot.palette;
    final choice = await _choose<SelahDevPalette>(
      'Background',
      PersonalisationScreen.availablePalettes,
      before,
      (palette) => palette.label.replaceAll(' · Current', ''),
      detailFor: (palette) => palette.detail,
      leadingFor: (palette) => Container(
        width: 44,
        height: 34,
        decoration: BoxDecoration(
          gradient: palette.gradient,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: SelahColors.ink(0.16), width: 0.6),
        ),
      ),
    );
    if (choice == null ||
        !_current ||
        _snapshot.palette != before ||
        choice.isLight) {
      return;
    }
    if (_previewMode) {
      widget.onPaletteChanged!(choice);
    } else {
      SelahColors.selectAppPalette(choice);
      if (mounted && _current) setState(() {});
    }
  }

  Future<void> _chooseHaptic() async {
    final before = _snapshot.hapticLevel;
    final choice = await _choose<SelahHapticLevel>(
      'Haptic feel',
      SelahHapticLevel.values,
      before,
      (level) => level.label,
    );
    if (choice == null || !_current || _snapshot.hapticLevel != before) return;
    if (_previewMode) {
      widget.onHapticChanged!(choice);
    } else {
      final changed = SelahInteractionStyle.selectPersonalisationHapticLevel(
        choice,
      );
      if (changed && _current) {
        SelahInteractionStyle.emitSelectionHaptic(level: choice);
      }
      if (mounted && _current) setState(() {});
    }
  }

  Widget _content() {
    final snapshot = _snapshot;
    final revision = _revision;
    final goldRevision = SelahAppGoldStyle.instance.revision;
    bool current() => revision == _revision && _current;
    return SelahPersonalisationContent(
      snapshot: snapshot,
      previewGradient: _previewMode ? snapshot.palette.gradient : null,
      onChooseBackground: () {
        if (current()) _chooseBackground();
      },
      onChooseHaptic: () {
        if (current()) _chooseHaptic();
      },
      onGoldChanged: (value) {
        if (!current()) return;
        if (_previewMode) {
          widget.onGoldChanged!(value);
        } else {
          SelahAppGoldStyle.instance.select(
            value,
            expectedGeneration: _memberGeneration,
            expectedRevision: goldRevision,
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_admitted) {
      return const SizedBox.shrink(
        key: ValueKey('personalisation-unavailable'),
      );
    }
    if (_previewMode) {
      final content = Material(
        color: Colors.transparent,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Text(
                  'Personalisation',
                  key: const ValueKey('personalisation-preview-title'),
                  style: SelahText.heading(size: 28),
                ),
              ),
              Expanded(child: _content()),
            ],
          ),
        ),
      );
      if (_embedded) return content;
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: DecoratedBox(
          decoration: BoxDecoration(gradient: widget.palette!.gradient),
          child: content,
        ),
      );
    }
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text('Personalisation', style: SelahText.heading(size: 17)),
        iconTheme: IconThemeData(color: SelahColors.ink(0.70)),
      ),
      body: Container(
        decoration: SelahAppGoldDecoration(
          gradient: SelahColors.genderGradient(AppState.instance.gender),
        ),
        child: SafeArea(
          child: ListenableBuilder(
            listenable: Listenable.merge([
              SelahColors.devPaletteSelection,
              SelahInteractionStyle.hapticLevelSelection,
              SelahAppGoldStyle.instance,
            ]),
            builder: (context, _) => _content(),
          ),
        ),
      ),
    );
  }
}
