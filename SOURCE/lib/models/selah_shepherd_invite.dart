import 'package:flutter/foundation.dart';

import '../services/selah_developer_access.dart';

/// The six locked choices; an invite never accepts a free-text relation.
enum SelahShepherdRelation {
  parent,
  pastor,
  mentor,
  churchElder,
  familyMember,
  matureChristianFriend;

  String get label => switch (this) {
    parent => 'Parent',
    pastor => 'Pastor',
    mentor => 'Mentor',
    churchElder => 'Church elder',
    familyMember => 'Family member',
    matureChristianFriend => 'A mature Christian friend',
  };
}

enum SelahShepherdInviteSendState { idle, sending, failed, sent }

/// Session-only presentation state for LOCK 3. Sending and accepting here
/// never sends a message, copies a link, persists data or grants server access.
class SelahShepherdInviteController extends ChangeNotifier {
  SelahShepherdInviteController({required this.canAct});

  final bool Function() canAct;
  SelahShepherdRelation? _relation;
  String _fullName = '';
  bool _showChoiceError = false;
  bool _showNameError = false;
  SelahShepherdInviteSendState _sendState = SelahShepherdInviteSendState.idle;
  bool _hasInvite = false;
  bool _accepted = false;
  bool _revoked = false;
  bool _disposed = false;

  bool get _allowed {
    if (_disposed || _revoked || kReleaseMode) return false;
    try {
      if (canAct()) return true;
    } catch (_) {
      // A missing or invalid owner cannot leave this fixture actionable.
    }
    _revoked = true;
    return false;
  }

  SelahShepherdRelation? get relation => _allowed ? _relation : null;
  String get fullName => _allowed ? _fullName.trim() : '';
  String get firstName {
    final name = fullName;
    return name.isEmpty ? '' : name.split(RegExp(r'\s+')).first;
  }

  bool get showChoiceError => _allowed && _showChoiceError;
  bool get showNameError =>
      _allowed && _showNameError && _fullName.trim().isEmpty;
  SelahShepherdInviteSendState get sendState =>
      _allowed ? _sendState : SelahShepherdInviteSendState.idle;
  bool get hasInvite => _allowed && _hasInvite;
  bool get accepted => _allowed && _hasInvite && _accepted;
  bool get pending => _allowed && _hasInvite && !_accepted;

  void chooseRelation(SelahShepherdRelation value) {
    if (!_allowed || (_relation == value && !_showChoiceError)) return;
    _relation = value;
    _showChoiceError = false;
    notifyListeners();
  }

  void setName(String value) {
    if (!_allowed || value == _fullName) return;
    _fullName = value;
    // LOCK 3 keeps the name error until the next send attempt.
    notifyListeners();
  }

  bool continueChoice() {
    if (!_allowed) return false;
    final missing = _relation == null;
    if (_showChoiceError != missing) {
      _showChoiceError = missing;
      notifyListeners();
    }
    return !missing;
  }

  bool send({bool copied = false}) {
    if (!_allowed || _sendState == SelahShepherdInviteSendState.sending) {
      return false;
    }
    final missingName = _fullName.trim().isEmpty;
    if (missingName) {
      if (!_showNameError) {
        _showNameError = true;
        notifyListeners();
      }
      return false;
    }
    _showNameError = false;
    _sendState = SelahShepherdInviteSendState.sent;
    _hasInvite = true;
    _accepted = false;
    // Both normal Send and Copy finish locally; callers own the exact toast.
    // The copied argument never calls a clipboard or constructs a URL.
    notifyListeners();
    return true;
  }

  bool get _privatePresetAllowed =>
      _allowed && SelahDeveloperAccess.canUseDeveloperTools;

  void showSending() {
    if (!_privatePresetAllowed || _fullName.trim().isEmpty) return;
    _showNameError = false;
    _sendState = SelahShepherdInviteSendState.sending;
    notifyListeners();
  }

  void showFailure() {
    if (!_privatePresetAllowed || _fullName.trim().isEmpty) return;
    _showNameError = false;
    _sendState = SelahShepherdInviteSendState.failed;
    notifyListeners();
  }

  bool accept() {
    if (!_allowed ||
        !_hasInvite ||
        _accepted ||
        _sendState != SelahShepherdInviteSendState.sent) {
      return false;
    }
    _accepted = true;
    notifyListeners();
    return true;
  }

  void reset() {
    if (!_allowed) return;
    _relation = null;
    _fullName = '';
    _showChoiceError = false;
    _showNameError = false;
    _sendState = SelahShepherdInviteSendState.idle;
    _hasInvite = false;
    _accepted = false;
    notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    super.dispose();
  }
}
