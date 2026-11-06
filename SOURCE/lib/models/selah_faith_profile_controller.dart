import 'dart:async';

import 'package:flutter/foundation.dart';

import '../services/selah_developer_access.dart';
import 'selah_faith_profile.dart';

enum SelahFaithProfileSaveState { idle, saving, failed, saved }

/// A transient editor. The caller's existing details owner is the only saved
/// source; draft answers are discarded when this controller is disposed.
class SelahFaithProfileController extends ChangeNotifier {
  SelahFaithProfileController({
    required this.canAct,
    required SelahFaithProfileAnswers Function() read,
    required FutureOr<bool> Function(SelahFaithProfileAnswers) save,
    // Keep the approved public callback names separate from private storage.
    // ignore: prefer_initializing_formals
  }) : _read = read,
       // ignore: prefer_initializing_formals
       _save = save;

  final bool Function() canAct;
  final SelahFaithProfileAnswers Function() _read;
  final FutureOr<bool> Function(SelahFaithProfileAnswers) _save;
  SelahFaithProfileAnswers? _draft;
  final _requiredErrors = <int>{};
  bool _lengthError = false;
  bool _revoked = false;
  bool _disposed = false;
  bool _saving = false;
  int _saveGeneration = 0;
  SelahFaithProfileSaveState _state = SelahFaithProfileSaveState.idle;

  bool get _allowed {
    if (_revoked || _disposed) return false;
    try {
      if (canAct()) return true;
    } catch (_) {}
    _revoked = true;
    return false;
  }

  SelahFaithProfileAnswers get answers {
    if (!_allowed) return SelahFaithProfileAnswers();
    if (_draft != null) return _draft!;
    try {
      return _draft = _read();
    } catch (_) {
      _revoked = true;
      return SelahFaithProfileAnswers();
    }
  }

  int get characterCount => answers.characterCount;
  bool get showLengthError => _allowed && _lengthError;
  bool showRequiredErrorFor(int question) =>
      _allowed && _requiredErrors.contains(question);
  SelahFaithProfileSaveState get saveState =>
      _allowed ? _state : SelahFaithProfileSaveState.idle;
  bool get _busy => _saving || _state == SelahFaithProfileSaveState.saving;

  void choose(int question, int optionIndex) {
    if (!_allowed || _busy) return;
    final previous = answers;
    if (!_allowed) return;
    final next = previous.choose(question, optionIndex);
    if (identical(previous, next)) return;
    _draft = next;
    _requiredErrors.remove(question);
    _state = SelahFaithProfileSaveState.idle;
    notifyListeners();
  }

  void clearServing() {
    if (!_allowed || _busy) return;
    final next = answers.withoutServing();
    if (!_allowed) return;
    _draft = next;
    _state = SelahFaithProfileSaveState.idle;
    notifyListeners();
  }

  void setWords(String value) {
    if (!_allowed || _busy) return;
    final previous = answers;
    if (!_allowed || previous.words == value) return;
    _draft = previous.withWords(value);
    _state = SelahFaithProfileSaveState.idle;
    notifyListeners();
  }

  bool validateQuestion(int question) {
    if (!_allowed || _busy || question < 1 || question > 7) return false;
    if (question == 5 || question == 7) return true;
    final missing = answers.answerFor(question) == null;
    if (!_allowed) return false;
    if (missing) {
      _requiredErrors.add(question);
    } else {
      _requiredErrors.remove(question);
    }
    notifyListeners();
    return !missing;
  }

  Future<bool> save({bool skipWords = false}) async {
    if (!_allowed || _busy) return false;
    final current = answers;
    if (!_allowed) return false;
    final next = skipWords ? current.withWords('') : current;
    _requiredErrors
      ..clear()
      ..addAll(const [1, 2, 3, 4, 6].where((q) => next.answerFor(q) == null));
    _lengthError = !next.withinWordLimit;
    if (_requiredErrors.isNotEmpty || _lengthError) {
      _state = SelahFaithProfileSaveState.idle;
      notifyListeners();
      return false;
    }
    _draft = next;
    _saving = true;
    final generation = ++_saveGeneration;
    // Normal local saves complete immediately. Retained asynchronous saves
    // truthfully paint Saving while pending; no delay is added to local saves.
    var result = false;
    try {
      final operation = _save(next);
      if (operation is Future<bool>) {
        if (!_allowed || generation != _saveGeneration) return false;
        _state = SelahFaithProfileSaveState.saving;
        notifyListeners();
        result = await operation;
      } else {
        result = operation;
      }
    } catch (_) {
      result = false;
    }
    if (!_allowed || generation != _saveGeneration) return false;
    _saving = false;
    _state = result
        ? SelahFaithProfileSaveState.saved
        : SelahFaithProfileSaveState.failed;
    notifyListeners();
    return result;
  }

  bool get _privateAllowed =>
      _allowed && SelahDeveloperAccess.canUseDeveloperTools;

  void showSaving() {
    if (!_privateAllowed || _saving) return;
    _state = SelahFaithProfileSaveState.saving;
    notifyListeners();
  }

  void showFailure() {
    if (!_privateAllowed || _saving) return;
    _state = SelahFaithProfileSaveState.failed;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _revoked = true;
    _saveGeneration++;
    _draft = null;
    _requiredErrors.clear();
    super.dispose();
  }
}
