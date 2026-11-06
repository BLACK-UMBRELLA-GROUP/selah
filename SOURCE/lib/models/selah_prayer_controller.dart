import 'package:flutter/foundation.dart';

import '../services/selah_developer_access.dart';
import 'selah_prayer.dart';

enum SelahPrayerSendState { idle, sending, failed, sent }

/// A role/route-bound local presenter. The root owns the one pure store and
/// supplies guarded setters; no network, clipboard, delivery or persistence.
class SelahPrayerController extends ChangeNotifier {
  SelahPrayerController({
    required this.canAct,
    required SelahPrayerContext Function() readContext,
    required SelahPrayerRequest? Function(String) readRequest,
    required bool Function(SelahPrayerContext, String, String?) onSend,
    required bool Function(SelahPrayerContext, String) onPray,
    required bool Function(SelahPrayerContext) onPresetEmpty,
    VoidCallback? onChanged,
    // Public callback names are kept separate from private storage.
    // ignore: prefer_initializing_formals
  }) : _readContext = readContext,
       // ignore: prefer_initializing_formals
       _readRequest = readRequest,
       // ignore: prefer_initializing_formals
       _onSend = onSend,
       // ignore: prefer_initializing_formals
       _onPray = onPray,
       // ignore: prefer_initializing_formals
       _onPresetEmpty = onPresetEmpty,
       // ignore: prefer_initializing_formals
       _onChanged = onChanged;

  final bool Function() canAct;
  final SelahPrayerContext Function() _readContext;
  final SelahPrayerRequest? Function(String) _readRequest;
  final bool Function(SelahPrayerContext, String, String?) _onSend;
  final bool Function(SelahPrayerContext, String) _onPray;
  final bool Function(SelahPrayerContext) _onPresetEmpty;
  final VoidCallback? _onChanged;
  SelahPrayerContext? _binding;
  bool _revoked = false;
  bool _disposed = false;
  bool _dispatching = false;
  int _selectedSuggestion = 0;
  String _ownText = '';
  SelahPrayerSendState _sendState = SelahPrayerSendState.idle;

  bool get current {
    if (_revoked || _disposed) return false;
    try {
      if (canAct()) {
        final next = _readContext();
        if (next.actorId.isNotEmpty &&
            next.actorId.trim() == next.actorId &&
            next.actorFirstName.trim().isNotEmpty &&
            (_binding == null || _binding!.sameBinding(next))) {
          _binding ??= next;
          return true;
        }
      }
    } catch (_) {}
    _revoked = true;
    return false;
  }

  SelahPrayerContext? get context => current ? _binding : null;
  int get selectedSuggestion => current ? _selectedSuggestion : 0;
  String get ownText => current ? _ownText : '';
  List<String> get suggestions {
    if (!current) return const [];
    return _suggestionsFor(_binding!);
  }

  List<String> _suggestionsFor(SelahPrayerContext actor) {
    final journey = (actor.journeyName ?? '').trim();
    return List.unmodifiable([
      journey.isEmpty
          ? 'For wisdom in my Journey'
          : 'For wisdom in my Journey with $journey',
      'For patience while I wait',
      'For my family to be at peace with my choice',
    ]);
  }

  String get requestText {
    if (!current) return '';
    return _ownText.trim().isNotEmpty
        ? _ownText.trim()
        : _suggestionsFor(_binding!)[_selectedSuggestion];
  }

  SelahPrayerSendState get sendState =>
      current ? _sendState : SelahPrayerSendState.idle;
  bool get _busy => _dispatching || _sendState == SelahPrayerSendState.sending;

  void _notify() {
    if (!current) return;
    notifyListeners();
    if (current) _onChanged?.call();
  }

  void chooseSuggestion(int index) {
    if (!current ||
        _busy ||
        _binding!.role != SelahPrayerRole.seeker ||
        index < 0 ||
        index > 2 ||
        index == _selectedSuggestion) {
      return;
    }
    _selectedSuggestion = index;
    _sendState = SelahPrayerSendState.idle;
    _notify();
  }

  void setOwnText(String value) {
    if (!current ||
        _busy ||
        _binding!.role != SelahPrayerRole.seeker ||
        value == _ownText) {
      return;
    }
    _ownText = value;
    _sendState = SelahPrayerSendState.idle;
    _notify();
  }

  bool send() {
    if (!current || _busy || _sendState == SelahPrayerSendState.sent) {
      return false;
    }
    final actor = _binding!;
    if (actor.role != SelahPrayerRole.seeker ||
        (actor.shepherdId ?? '').isEmpty ||
        (actor.shepherdName ?? '').trim().isEmpty ||
        !actor.linkedShepherdIds.contains(actor.shepherdId)) {
      return false;
    }
    final text = requestText;
    final journey = _ownText.trim().isEmpty && _selectedSuggestion == 0
        ? actor.journeyName
        : null;
    if (!current || text.isEmpty) return false;
    _dispatching = true;
    var ok = false;
    try {
      ok = _onSend(actor, text, journey);
    } catch (_) {
      ok = false;
    }
    _dispatching = false;
    if (!current) return false;
    _sendState = ok ? SelahPrayerSendState.sent : SelahPrayerSendState.failed;
    _notify();
    return ok && current;
  }

  bool pray(String requestId) {
    if (!current ||
        _dispatching ||
        _binding!.role != SelahPrayerRole.shepherd) {
      return false;
    }
    final actor = _binding!;
    SelahPrayerRequest? request;
    try {
      request = _readRequest(requestId);
    } catch (_) {
      return false;
    }
    if (!current ||
        request == null ||
        !request.recipientShepherdIds.contains(actor.actorId) ||
        !actor.linkedSeekerIds.contains(request.seekerId) ||
        request.hasPrayed(actor.actorId)) {
      return false;
    }
    _dispatching = true;
    var ok = false;
    try {
      ok = _onPray(actor, requestId);
    } catch (_) {
      ok = false;
    }
    _dispatching = false;
    if (!current) return false;
    if (ok) _notify();
    return ok && current;
  }

  bool get _privateAllowed =>
      current && !_dispatching && SelahDeveloperAccess.canUseDeveloperTools;
  void showSending() {
    if (!_privateAllowed || _binding!.role != SelahPrayerRole.seeker) return;
    _sendState = SelahPrayerSendState.sending;
    _notify();
  }

  void showFailure() {
    if (!_privateAllowed || _binding!.role != SelahPrayerRole.seeker) return;
    _sendState = SelahPrayerSendState.failed;
    _notify();
  }

  bool presetEmpty() {
    if (!_privateAllowed || _binding!.role != SelahPrayerRole.shepherd) {
      return false;
    }
    var ok = false;
    try {
      ok = _onPresetEmpty(_binding!);
    } catch (_) {
      ok = false;
    }
    if (!current) return false;
    if (ok) _notify();
    return ok && current;
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _revoked = true;
    _binding = null;
    _ownText = '';
    super.dispose();
  }
}
