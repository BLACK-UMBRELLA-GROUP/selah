import 'dart:async';
import 'package:flutter/foundation.dart';
import '../data/selah_reference_data.dart';
import '../services/selah_developer_access.dart';

enum SelahLanguagesSaveState { idle, saving, failed, saved }

/// A transient editor of the existing profile languages field.
class SelahLanguagesController extends ChangeNotifier {
  SelahLanguagesController({
    required bool Function() canAct,
    required List<String> Function() read,
    required FutureOr<bool> Function(List<String>) save,
  })
    // Keep public callback names separate from private storage.
    // ignore: prefer_initializing_formals
    : _canAct = canAct,
       // ignore: prefer_initializing_formals
       _read = read,
       // ignore: prefer_initializing_formals
       _save = save;
  final bool Function() _canAct;
  final List<String> Function() _read;
  final FutureOr<bool> Function(List<String>) _save;
  List<String>? _languages;
  bool _disposed = false;
  bool _revoked = false;
  bool _required = false;
  bool _saving = false;
  int _epoch = 0;
  SelahLanguagesSaveState _state = SelahLanguagesSaveState.idle;
  bool get current {
    if (_disposed || _revoked) return false;
    try {
      if (_canAct()) return true;
    } catch (_) {
      /* fail closed */
    }
    _revoked = true;
    return false;
  }

  List<String> get _values {
    if (!current) return const [];
    if (_languages != null) return _languages!;
    try {
      final values = _read()
          .where(selahLanguageNames.contains)
          .toSet()
          .toList();
      if (!current) return const [];
      return _languages = values;
    } catch (_) {
      _revoked = true;
      return const [];
    }
  }

  List<String> get languages => current ? List.unmodifiable(_values) : const [];
  bool get showRequiredError => current && _required && _values.isEmpty;
  SelahLanguagesSaveState get saveState =>
      current ? _state : SelahLanguagesSaveState.idle;
  bool get _busy => _saving || _state == SelahLanguagesSaveState.saving;

  void toggle(String value) {
    if (!current || _busy || !selahLanguageNames.contains(value)) return;
    final values = _values;
    if (!current) return;
    if (values.contains(value)) {
      values.remove(value);
    } else {
      values.add(value);
    }
    _state = SelahLanguagesSaveState.idle;
    notifyListeners();
  }

  Future<bool> save() async {
    if (!current || _busy) return false;
    final values = List<String>.unmodifiable(_values);
    if (!current) return false;
    if (values.isEmpty) {
      _required = true;
      notifyListeners();
      return false;
    }
    final epoch = ++_epoch;
    _saving = true;
    _state = SelahLanguagesSaveState.saving;
    notifyListeners();
    if (!current) return false;
    bool ok;
    try {
      ok = await _save(values);
    } catch (_) {
      ok = false;
    }
    if (!current || epoch != _epoch) return false;
    _saving = false;
    _state = ok
        ? SelahLanguagesSaveState.saved
        : SelahLanguagesSaveState.failed;
    notifyListeners();
    return ok && current;
  }

  void showSaving() => _preset(SelahLanguagesSaveState.saving);
  void showFailure() => _preset(SelahLanguagesSaveState.failed);
  void _preset(SelahLanguagesSaveState value) {
    if (!current || _saving || !SelahDeveloperAccess.canUseDeveloperTools) {
      return;
    }
    _epoch++;
    _state = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _epoch++;
    _languages = null;
    super.dispose();
  }
}
