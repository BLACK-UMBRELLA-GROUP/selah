import 'dart:async';

import 'package:flutter/foundation.dart';

import '../services/selah_developer_access.dart';
import 'selah_action_pause.dart';

enum SelahActionPauseState { ready, working, failed, done }

/// Owns one confirmation lifetime, never the Journey or a backend repository.
class SelahActionPauseController extends ChangeNotifier {
  SelahActionPauseController({
    required this.pause,
    required bool Function() canAct,
    required FutureOr<bool> Function() commit,
    // Keep owner callbacks named at the public constructor boundary.
    // ignore: prefer_initializing_formals
  }) : _canAct = canAct,
       // ignore: prefer_initializing_formals
       _commit = commit;

  final SelahActionPause pause;
  final bool Function() _canAct;
  final FutureOr<bool> Function() _commit;
  SelahActionPauseState _state = SelahActionPauseState.ready;
  bool _closed = false;
  bool _disposed = false;
  bool _committing = false;

  bool get active {
    if (_closed || _disposed || kReleaseMode) return false;
    try {
      if (_canAct()) return true;
    } catch (_) {
      // Losing the supplied owner is terminal, even if it later returns.
    }
    _closed = true;
    return false;
  }

  SelahActionPauseState get state => _state;

  Future<bool> confirm() async {
    if (!active ||
        !pause.canOpen ||
        _committing ||
        _state == SelahActionPauseState.working ||
        _state == SelahActionPauseState.done) {
      return false;
    }
    _committing = true;
    bool committed;
    try {
      final result = _commit();
      if (result is Future<bool>) {
        _state = SelahActionPauseState.working;
        notifyListeners();
        committed = await result;
      } else {
        committed = result;
      }
    } catch (_) {
      committed = false;
    }
    _committing = false;
    if (!active) return false;
    _state = committed
        ? SelahActionPauseState.done
        : SelahActionPauseState.failed;
    notifyListeners();
    return committed;
  }

  bool cancel() {
    // Dismissing this owned route remains possible after admission is revoked.
    // It never authorizes a Journey mutation or a late completion callback.
    if (_disposed || _state == SelahActionPauseState.done) return false;
    _closed = true;
    return true;
  }

  void _preset(SelahActionPauseState state) {
    if (!active ||
        _committing ||
        !SelahDeveloperAccess.canUseDeveloperTools ||
        _state == SelahActionPauseState.done) {
      return;
    }
    _state = state;
    notifyListeners();
  }

  void showReady() => _preset(SelahActionPauseState.ready);
  void showWorking() => _preset(SelahActionPauseState.working);
  void showFailure() => _preset(SelahActionPauseState.failed);

  @override
  void dispose() {
    _closed = true;
    _disposed = true;
    super.dispose();
  }
}
