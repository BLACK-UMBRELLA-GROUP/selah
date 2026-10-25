// Developer-only iOS Home Screen icon selector.
//
// Current remains the unchanged primary icon; ten original comparison studies
// are bundled as iOS alternates. Previewing these exact PNGs is read-only.
// Only an explicit Use on iPhone action calls this controller. The existing
// developer access guard owns availability; iOS owns Home Screen persistence.

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum SelahDevAppIcon {
  goldHorizonCurrent(
    alternateName: null,
    label: 'Current',
    detail: 'Original Gold Horizon · Default',
  ),
  goldHalo(
    alternateName: 'SelahGoldHalo',
    label: '1 · Gold Halo',
    detail: 'A fine gold circle around the wordmark',
  ),
  orbitLight(
    alternateName: 'SelahOrbitLight',
    label: '2 · Orbit Light',
    detail: 'A tilted orbit with one warm point of light',
  ),
  twinGlow(
    alternateName: 'SelahTwinGlow',
    label: '3 · Together',
    detail: 'Two soft lights joined by the SELAH name',
  ),
  openFrame(
    alternateName: 'SelahOpenFrame',
    label: '4 · Open Frame',
    detail: 'Four open corners, with room to breathe',
  ),
  editorialGold(
    alternateName: 'SelahEditorialGold',
    label: '5 · Editorial Gold',
    detail: 'An asymmetric wordmark and vertical gold rule',
  ),
  risingDawn(
    alternateName: 'SelahRisingDawn',
    label: '6 · Rising Dawn',
    detail: 'A gold sun rising above a quiet horizon',
  ),
  quietMonogram(
    alternateName: 'SelahQuietMonogram',
    label: '7 · Quiet Monogram',
    detail: 'The locked Syne Z, with a small gold accent',
  ),
  silkRibbon(
    alternateName: 'SelahSilkRibbon',
    label: '8 · Silk Ribbon',
    detail: 'A sweeping gold ribbon on dark plum',
  ),
  constellation(
    alternateName: 'SelahConstellation',
    label: '9 · Constellation',
    detail: 'Three connected gold stars above the wordmark',
  ),
  royalSeal(
    alternateName: 'SelahRoyalSeal',
    label: '10 · Royal Seal',
    detail: 'A compact monogram inside a double gold seal',
  );

  final String? alternateName;
  final String label;
  final String detail;
  String get previewAsset => 'assets/icon/previews/$name.png';

  const SelahDevAppIcon({
    required this.alternateName,
    required this.label,
    required this.detail,
  });

  static SelahDevAppIcon fromAlternateName(String? name) => values.firstWhere(
    (option) => option.alternateName == name,
    orElse: () => goldHorizonCurrent,
  );
}

class SelahDevAppIconController extends ChangeNotifier {
  static const MethodChannel _defaultChannel = MethodChannel(
    'selah/app_icon',
  );

  static final SelahDevAppIconController instance = SelahDevAppIconController();

  final MethodChannel _channel;
  @visibleForTesting
  final bool? isIOSOverride;

  bool _loaded = false;
  bool _supported = false;
  bool _busy = false;
  SelahDevAppIcon _selected = SelahDevAppIcon.goldHorizonCurrent;
  String? _message;
  bool _messageIsError = false;
  bool _hasRetiredIcon = false;

  SelahDevAppIconController({MethodChannel? channel, this.isIOSOverride})
    : _channel = channel ?? _defaultChannel;

  bool get loaded => _loaded;
  bool get supported => _supported;
  bool get busy => _busy;
  SelahDevAppIcon get selected => _selected;
  String? get message => _message;
  bool get messageIsError => _messageIsError;
  bool get hasRetiredIcon => _hasRetiredIcon;

  bool get _isIOS =>
      isIOSOverride ?? (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> load({bool force = false}) async {
    if (_busy || (_loaded && !force)) return;
    if (!_isIOS) {
      _loaded = true;
      _supported = false;
      _message = 'Home Screen icon switching is available on iPhone only.';
      _messageIsError = false;
      notifyListeners();
      return;
    }

    _busy = true;
    _message = null;
    notifyListeners();
    try {
      final state = await _channel.invokeMapMethod<String, dynamic>(
        'getAppIconState',
      );
      _supported = state?['supported'] == true;
      final iconName = state?['iconName'] as String?;
      _hasRetiredIcon =
          iconName != null &&
          !SelahDevAppIcon.values.any(
            (option) => option.alternateName == iconName,
          );
      _selected = SelahDevAppIcon.fromAlternateName(iconName);
      if (_hasRetiredIcon) {
        _message =
            'Your previous study icon is retired. Choose a new design or restore Current.';
      }
      if (!_supported) {
        _message = 'This iPhone does not allow alternate app icons.';
      }
      _messageIsError = false;
    } on PlatformException catch (error) {
      debugPrint('SELAH developer app-icon state failed — $error');
      _supported = false;
      _message = 'The current Home Screen icon could not be read.';
      _messageIsError = true;
    } finally {
      _loaded = true;
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> select(SelahDevAppIcon option) async {
    if (!_loaded) await load();
    if (!_supported || _busy || (option == _selected && !_hasRetiredIcon)) {
      return;
    }

    _busy = true;
    _message = null;
    notifyListeners();
    try {
      final state = await _channel.invokeMapMethod<String, dynamic>(
        'setAppIcon',
        {'iconName': option.alternateName},
      );
      _selected = SelahDevAppIcon.fromAlternateName(
        state?['iconName'] as String?,
      );
      _hasRetiredIcon = false;
      _message =
          '${_selected.label} · ${_selected.detail} is on your Home Screen.';
      _messageIsError = false;
    } on PlatformException catch (error) {
      debugPrint('SELAH developer app-icon change failed — $error');
      _message = 'The Home Screen icon did not change. Please try again.';
      _messageIsError = true;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }
}
