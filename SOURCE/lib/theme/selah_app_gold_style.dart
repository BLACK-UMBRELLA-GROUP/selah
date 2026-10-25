import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart';

import '../services/selah_account_state.dart';
import '../services/selah_local_prefs.dart';

/// Member-owned presentation preference, independent of developer authority.
/// Stored only for the bound account on this device; missing values stay Off.
class SelahAppGoldStyle extends ChangeNotifier {
  SelahAppGoldStyle._();

  static final instance = SelahAppGoldStyle._();
  bool _selected = false;
  int _generation = SelahAccountState.generation;
  int _revision = 0;

  bool get enabled =>
      _selected &&
      _generation == SelahAccountState.generation &&
      !SelahAccountState.isSigningOut;
  int get revision => _revision;

  bool select(
    bool value, {
    required int expectedGeneration,
    required int expectedRevision,
  }) {
    if (SelahAccountState.isSigningOut ||
        expectedGeneration != SelahAccountState.generation ||
        expectedRevision != _revision) {
      return false;
    }
    _selected = value;
    _generation = expectedGeneration;
    _revision++;
    unawaited(SelahLocalPrefs.setCachedAppGoldEnabled(value));
    // Even a repeated choice clears a temporary developer preview.
    notifyListeners();
    return true;
  }

  /// Hydration/reset never writes a preference or changes account authority.
  void restore(bool value) {
    final changed =
        _selected != value || _generation != SelahAccountState.generation;
    if (!changed) return;
    _selected = value;
    _generation = SelahAccountState.generation;
    _revision++;
    notifyListeners();
  }

  void restoreCurrent() => restore(SelahLocalPrefs.cachedAppGoldEnabled);
}
