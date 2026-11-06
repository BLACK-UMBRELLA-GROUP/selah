import 'dart:async';

import '../data/journey_questions.dart';
import 'selah_family_answers.dart';

enum SelahFamilySendState { idle, sending, failed, sent }

/// Transient interaction state only. Every answer and sent flag is read from
/// the caller's existing owner; this controller never retains a saved copy.
class SelahFamilyStageController {
  SelahFamilyStageController({
    required bool Function() canAct,
    bool Function()? canDispatch,
    required SelahFamilyAnswers Function() readAnswers,
    required bool Function() readSent,
    required bool Function() readPeerSent,
    required bool Function(String questionId, String text) onSetAnswer,
    required FutureOr<bool> Function(Map<String, String> answers) onSend,
    required bool Function() canUsePresets,
  }) : this._(
         canAct,
         canDispatch ?? canAct,
         readAnswers,
         readSent,
         readPeerSent,
         onSetAnswer,
         onSend,
         canUsePresets,
       );

  SelahFamilyStageController._(
    this._canAct,
    this._canDispatch,
    this._readAnswers,
    this._readSent,
    this._readPeerSent,
    this._onSetAnswer,
    this._onSend,
    this._canUsePresets,
  );

  final bool Function() _canAct;
  final bool Function() _canDispatch;
  final SelahFamilyAnswers Function() _readAnswers;
  final bool Function() _readSent;
  final bool Function() _readPeerSent;
  final bool Function(String, String) _onSetAnswer;
  final FutureOr<bool> Function(Map<String, String>) _onSend;
  final bool Function() _canUsePresets;
  final _listeners = <void Function()>{};
  bool _revoked = false;
  bool _disposed = false;
  bool _pending = false;
  bool? _writeResult;
  SelahFamilySendState _state = SelahFamilySendState.idle;

  bool get current {
    if (_revoked || _disposed) return false;
    try {
      if (_canAct()) return true;
    } catch (_) {
      // A failed owner check cannot admit a stale account or Journey.
    }
    _revoked = true;
    return false;
  }

  static bool _allows(bool Function() guard) {
    try {
      return guard();
    } catch (_) {
      return false;
    }
  }

  bool get _dispatch => current && _allows(_canDispatch) && current;

  SelahFamilyAnswers get answers {
    if (!current) return SelahFamilyAnswers.fromMap(const {});
    try {
      final value = _readAnswers();
      return current ? value : SelahFamilyAnswers.fromMap(const {});
    } catch (_) {
      _revoked = true;
      return SelahFamilyAnswers.fromMap(const {});
    }
  }

  bool _sent(bool Function() read) {
    if (!current) return false;
    try {
      final value = read();
      return current && value;
    } catch (_) {
      _revoked = true;
      return false;
    }
  }

  bool get sent => _sent(_readSent);
  bool get peerSent => _sent(_readPeerSent);
  bool get bothSent => sent && peerSent;
  int get answeredCount => answers.answeredCount;
  int characterCount(String questionId) =>
      answers.answerFor(questionId).runes.length;
  SelahFamilySendState get sendState {
    if (!current) return SelahFamilySendState.idle;
    if (sent) return SelahFamilySendState.sent;
    if (!current) return SelahFamilySendState.idle;
    if (!_pending &&
        _state == SelahFamilySendState.sending &&
        _writeResult != null) {
      // A completed write only becomes Sent when the canonical owner says so.
      return SelahFamilySendState.failed;
    }
    return _state;
  }

  bool get canSend =>
      _dispatch &&
      !_pending &&
      sendState != SelahFamilySendState.sending &&
      !sent &&
      answers.canSend &&
      current;

  bool setAnswer(String questionId, String text) {
    if (!_dispatch ||
        _pending ||
        sendState == SelahFamilySendState.sending ||
        sent ||
        !JourneyQuestions.family.any((question) => question.id == questionId) ||
        !JourneyQuestions.familyAnswerFitsCharacterLimit(text)) {
      return false;
    }
    bool changed;
    try {
      if (!_dispatch) return false;
      changed = _onSetAnswer(questionId, text);
    } catch (_) {
      return false;
    }
    if (!changed || !_dispatch) return false;
    _state = SelahFamilySendState.idle;
    _writeResult = null;
    _emit();
    return true;
  }

  Future<bool> send() async {
    if (!canSend) return false;
    final submitted = answers;
    if (!submitted.canSend || !_dispatch) return false;
    _pending = true;
    _writeResult = null;
    _state = SelahFamilySendState.sending;
    _emit();
    var result = false;
    try {
      if (!_dispatch) return false;
      result = await _onSend(submitted.values);
    } catch (_) {
      result = false;
    } finally {
      _pending = false;
      _writeResult = result;
    }
    if (!_dispatch) return false;
    _emit();
    return result && sent && current;
  }

  bool showSending() => _preset(SelahFamilySendState.sending);
  bool showFailure() => _preset(SelahFamilySendState.failed);
  bool showIdle() => _preset(SelahFamilySendState.idle);

  bool _preset(SelahFamilySendState value) {
    if (!current || _pending || sent || !_allows(_canUsePresets) || !current) {
      return false;
    }
    _state = value;
    _writeResult = null;
    _emit();
    return true;
  }

  void addListener(void Function() listener) {
    if (!_disposed) _listeners.add(listener);
  }

  void removeListener(void Function() listener) => _listeners.remove(listener);

  void _emit() {
    for (final listener in _listeners.toList()) {
      if (!current) return;
      if (_listeners.contains(listener)) listener();
    }
  }

  void dispose() {
    _disposed = true;
    _revoked = true;
    _listeners.clear();
  }
}
