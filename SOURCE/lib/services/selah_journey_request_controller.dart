import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/selah_journey_request.dart';
import 'selah_account_state.dart';
import 'selah_auth.dart';
import 'selah_journey_request_repository.dart';

/// Bounded local integration preparation, not an activated real-member screen.
/// Requests never mutate AppState or optimistically create canonical Journeys.
/// Retry keys live only for this captured account lifetime; durable lost-ACK
/// recovery remains a requirement for the production transport before rollout.
final class SelahJourneyRequestController extends ChangeNotifier {
  SelahJourneyRequestController({
    required this.owner,
    required this.ownerIsCurrent,
    this.repository = const SelahHeldJourneyRequestRepository(),
  });

  factory SelahJourneyRequestController.forCurrentMember() {
    final owner = SelahJourneyRequestOwner(
      SelahAccountState.userId ?? '',
      SelahAccountState.generation,
    );
    return SelahJourneyRequestController(
      owner: owner,
      ownerIsCurrent: (captured) =>
          SelahAccountState.isCurrent(captured.actorId, captured.generation) &&
          SelahAuth.currentUser?.id == captured.actorId,
    );
  }

  final SelahJourneyRequestOwner owner;
  final bool Function(SelahJourneyRequestOwner) ownerIsCurrent;
  final SelahJourneyRequestRepository repository;
  final Map<String, String> _retryKeys = {};
  SelahJourneyRequestInbox? _inbox;
  SelahJourneyRequestResult? _lastResult;
  bool _writing = false;
  bool _disposed = false;
  bool _revoked = false;
  bool _freshBindingRead = false;
  bool _mustRefresh = false;
  int _revision = 0;

  bool get _current =>
      !_disposed &&
      !_revoked &&
      selahRequestIdentifierIsValid(owner.actorId) &&
      ownerIsCurrent(owner);

  // Never expose cached identities/receipts to a subsequent account or epoch.
  SelahJourneyRequestInbox? get inbox => _checkOwner() ? _inbox : null;
  SelahJourneyRequestResult? get lastResult =>
      _current ? _lastResult : SelahJourneyRequestResult.staleOwner;
  bool get isWriting => _current && _writing;

  bool _checkOwner() {
    if (_current) return true;
    _revoked = true;
    _inbox = null;
    _freshBindingRead = false;
    _retryKeys.clear();
    return false;
  }

  SelahJourneyRequestResult _publish(SelahJourneyRequestResult result) {
    if (!_checkOwner()) return SelahJourneyRequestResult.staleOwner;
    _lastResult = result;
    notifyListeners();
    return _checkOwner() ? result : SelahJourneyRequestResult.staleOwner;
  }

  Future<SelahJourneyRequestResult> refresh() async {
    if (!_checkOwner()) return SelahJourneyRequestResult.staleOwner;
    if (_writing) return SelahJourneyRequestResult.busy;
    final revision = ++_revision;
    _freshBindingRead = false;
    // Retain cached records for display, not as permission to issue a command
    // during/after an unsuccessful authoritative refresh. Retry keys survive.
    _mustRefresh = true;
    try {
      final value = await repository.read(owner);
      if (!_checkOwner()) return SelahJourneyRequestResult.staleOwner;
      if (revision != _revision) return SelahJourneyRequestResult.staleResponse;
      if (!value.validFor(owner.actorId)) {
        return _publish(SelahJourneyRequestResult.invalidResponse);
      }
      if (value.availability == SelahJourneyRequestAvailability.unavailable) {
        return _publish(SelahJourneyRequestResult.unavailable);
      }
      _inbox = value;
      _freshBindingRead =
          value.availability == SelahJourneyRequestAvailability.available;
      _mustRefresh = false;
      return _publish(
        value.availability == SelahJourneyRequestAvailability.held
            ? SelahJourneyRequestResult.held
            : SelahJourneyRequestResult.applied,
      );
    } catch (_) {
      if (!_checkOwner()) return SelahJourneyRequestResult.staleOwner;
      if (revision != _revision) return SelahJourneyRequestResult.staleResponse;
      // Keep last-known data; a failed read is not an empty successful inbox.
      return _publish(SelahJourneyRequestResult.unavailable);
    }
  }

  bool _allowed(SelahJourneyRequestAction action, String subjectId) {
    if (!selahRequestIdentifierIsValid(subjectId)) return false;
    if (action == SelahJourneyRequestAction.send) {
      return subjectId != owner.actorId;
    }
    SelahJourneyRequestRecord? record;
    for (final value in _inbox?.records ?? <SelahJourneyRequestRecord>[]) {
      if (value.id == subjectId) record = value;
    }
    if (record == null || !record.validFor(owner.actorId)) return false;
    return switch (action) {
      SelahJourneyRequestAction.send => false,
      SelahJourneyRequestAction.cancel =>
        record.senderId == owner.actorId &&
            record.state == SelahJourneyRequestState.pending,
      SelahJourneyRequestAction.decline || SelahJourneyRequestAction.accept =>
        record.recipientId == owner.actorId &&
            record.state == SelahJourneyRequestState.pending,
      SelahJourneyRequestAction.confirmReady =>
        record.state == SelahJourneyRequestState.accepted,
    };
  }

  Future<SelahJourneyRequestResult> execute(
    SelahJourneyRequestAction action,
    String subjectId,
  ) async {
    if (!_checkOwner()) return SelahJourneyRequestResult.staleOwner;
    if (_writing) return SelahJourneyRequestResult.busy;
    if (_mustRefresh) return _publish(SelahJourneyRequestResult.unavailable);
    if (_inbox?.availability != SelahJourneyRequestAvailability.available) {
      return _publish(
        _inbox?.availability == SelahJourneyRequestAvailability.held
            ? SelahJourneyRequestResult.held
            : SelahJourneyRequestResult.unavailable,
      );
    }
    if (!_allowed(action, subjectId)) {
      return _publish(SelahJourneyRequestResult.invalidAction);
    }
    final intent = '${action.name}:$subjectId';
    final command = SelahJourneyRequestCommand(
      action: action,
      subjectId: subjectId,
      operationKey: _retryKeys.putIfAbsent(intent, _operationKey),
    );
    _writing = true;
    _freshBindingRead = false;
    ++_revision; // Older reads must not overwrite a confirmed command.
    notifyListeners();
    SelahJourneyRequestResult result;
    try {
      // A synchronous observer can revoke/dispose this owner during notify.
      // It must not dispatch a write using the next account's transport.
      if (!_checkOwner()) return SelahJourneyRequestResult.staleOwner;
      final acknowledgement = await repository.execute(owner, command);
      if (!_checkOwner()) return SelahJourneyRequestResult.staleOwner;
      if (!acknowledgement.matches(owner, command)) {
        result = SelahJourneyRequestResult.invalidResponse;
      } else {
        result = switch (acknowledgement.status) {
          SelahJourneyRequestWriteStatus.applied =>
            SelahJourneyRequestResult.applied,
          SelahJourneyRequestWriteStatus.refused =>
            SelahJourneyRequestResult.refused,
          SelahJourneyRequestWriteStatus.held => SelahJourneyRequestResult.held,
          SelahJourneyRequestWriteStatus.unavailable =>
            SelahJourneyRequestResult.unavailable,
        };
        if (result == SelahJourneyRequestResult.applied ||
            result == SelahJourneyRequestResult.refused) {
          _retryKeys.remove(intent);
          // A second tap must not create a new operation while the visible
          // record still represents the pre-write snapshot.
          _mustRefresh = true;
        }
      }
    } catch (_) {
      if (!_checkOwner()) return SelahJourneyRequestResult.staleOwner;
      result = SelahJourneyRequestResult.unavailable;
    } finally {
      _writing = false;
    }
    // No local state transition. Read authoritative request/canonical binding
    // separately. A successful write cannot fabricate a Journey or readiness.
    return _publish(result);
  }

  SelahJourneyRequestBinding? canonicalBindingFor(String requestId) {
    if (!_checkOwner() ||
        !_freshBindingRead ||
        _lastResult != SelahJourneyRequestResult.applied ||
        _inbox?.availability != SelahJourneyRequestAvailability.available) {
      return null;
    }
    for (final record in _inbox!.records) {
      if (record.id == requestId &&
          record.state == SelahJourneyRequestState.bridged &&
          record.validFor(owner.actorId)) {
        return record.binding;
      }
    }
    return null;
  }

  static String _operationKey() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  @override
  void dispose() {
    _disposed = true;
    _revoked = true;
    _revision++;
    _inbox = null;
    _retryKeys.clear();
    super.dispose();
  }
}
