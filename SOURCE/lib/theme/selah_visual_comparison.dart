import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// Presentation only, owned by one admitted request-preview lifetime.
/// No preferences, accounts, admission, routes or service writes live here.
/// A late disposal from an old route cannot clear a newer owner's selection.
class SelahVisualComparison extends ChangeNotifier {
  static final instance = SelahVisualComparison();

  Object? _owner;
  bool Function()? _canAct;
  bool _revoked = false;
  bool _white = false;
  bool _notificationQueued = false;

  bool get option2 {
    if (!_white || _owner == null || _revoked) return false;
    try {
      if (_canAct?.call() == true) return true;
    } catch (_) {
      // Failed freshness is Current, never permission to revive a study.
    }
    _revoked = true;
    return false;
  }

  void bind(Object owner, bool Function() canAct) {
    _owner = owner;
    _canAct = canAct;
    _revoked = false;
    _white = false;
    _changed();
  }

  bool select(Object owner, {required bool option2}) {
    if (!identical(owner, _owner) || _revoked) return false;
    try {
      if (_canAct?.call() != true) {
        _revoked = true;
        return false;
      }
    } catch (_) {
      _revoked = true;
      return false;
    }
    if (_white == option2) return true;
    _white = option2;
    _changed();
    return true;
  }

  void release(Object owner) {
    if (!identical(owner, _owner)) return;
    _owner = null;
    _canAct = null;
    _revoked = true;
    _white = false;
    _changed();
  }

  void _changed() {
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      if (_notificationQueued) return;
      _notificationQueued = true;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _notificationQueued = false;
        notifyListeners();
      });
      SchedulerBinding.instance.scheduleFrame();
      return;
    }
    notifyListeners();
  }
}
