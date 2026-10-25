/// Disposable, ID-only viewing history. This is not eligibility, an invitation,
/// a Journey state, a permission, or a persisted member record.
///
/// The caller supplies the currently eligible IDs and selects normal discovery
/// candidates only after [hasForwardReplay] becomes false. Recorded forward
/// visits must be replayed before [appendFrontier] can extend the trail.
class SelahBrowseHistory {
  static const int maxPreviousProfiles = 10;
  static const int maxStoredProfiles = maxPreviousProfiles + 1;

  final List<String> _ids = [];
  int _cursor = -1;

  /// A defensive snapshot, not a live or mutable view of the trail.
  List<String> get ids => List<String>.unmodifiable(_ids);

  /// -1 when the trail is empty; otherwise an index into [ids].
  int get cursor => _cursor;
  String? get currentId => _cursor < 0 ? null : _ids[_cursor];
  bool get canBack => _cursor > 0;
  bool get hasForwardReplay => _cursor >= 0 && _cursor < _ids.length - 1;

  /// Move exactly one retained visit, or return null at the bounded beginning.
  String? back() {
    if (!canBack) return null;
    _cursor--;
    return currentId;
  }

  /// Replay exactly one retained visit. Normal discovery is caller-owned.
  String? forwardReplay() {
    if (!hasForwardReplay) return null;
    _cursor++;
    return currentId;
  }

  /// Record a new visit only at the frontier. Repeated nonadjacent visits are
  /// meaningful and retained; an adjacent repeat is not a navigation event.
  ///
  /// This method does not certify the candidate's eligibility. The caller must
  /// select it from its fresh eligible projection and reconcile before moving.
  bool appendFrontier(String id) {
    if (!_validId(id) || hasForwardReplay || currentId == id) return false;
    _ids.add(id);
    if (_ids.length > maxStoredProfiles) _ids.removeAt(0);
    _cursor = _ids.length - 1;
    return true;
  }

  /// Remove every visit excluded by the current eligible projection. Removed
  /// IDs cannot return merely because they become eligible again later.
  ///
  /// Keep the current occurrence when it survives. If it is excluded, choose
  /// the nearest surviving future visit, then the nearest surviving prior one.
  /// Coalesce repeats made adjacent by pruning, avoiding no-op Back/Next steps.
  /// Only an otherwise empty trail may be seeded from [fallbackId], and that
  /// exact ID must be valid and present in [eligibleIds].
  void reconcile(Iterable<String> eligibleIds, {String? fallbackId}) {
    final eligible = eligibleIds.where(_validId).toSet();
    final retained = <String>[];
    final oldToNew = <int, int>{};
    for (var index = 0; index < _ids.length; index++) {
      final id = _ids[index];
      if (!eligible.contains(id)) continue;
      if (retained.isEmpty || retained.last != id) retained.add(id);
      oldToNew[index] = retained.length - 1;
    }

    int? nextCursor = oldToNew[_cursor];
    if (nextCursor == null) {
      for (var index = _cursor + 1; index < _ids.length; index++) {
        final mapped = oldToNew[index];
        if (mapped == null) continue;
        nextCursor = mapped;
        break;
      }
    }
    if (nextCursor == null) {
      for (var index = _cursor - 1; index >= 0; index--) {
        final mapped = oldToNew[index];
        if (mapped == null) continue;
        nextCursor = mapped;
        break;
      }
    }

    if (retained.isEmpty &&
        fallbackId != null &&
        _validId(fallbackId) &&
        eligible.contains(fallbackId)) {
      retained.add(fallbackId);
      nextCursor = 0;
    }
    _ids
      ..clear()
      ..addAll(retained);
    _cursor = retained.isEmpty ? -1 : nextCursor!;
  }

  void reset() {
    _ids.clear();
    _cursor = -1;
  }

  static bool _validId(String id) => id.isNotEmpty && id.trim() == id;
}
