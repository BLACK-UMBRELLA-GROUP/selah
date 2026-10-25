import 'dart:async';

import '../../services/selah_notification_service.dart';

/// Keeps navigation-driven mark-read operations ahead of unread badge reads.
/// An older poll must never restore a dot after the user opens its section.
class SelahUnreadBadgeCoordinator {
  SelahUnreadBadgeCoordinator({
    required this.fetchUnreadCount,
    required this.fetchSectionsWithUnread,
    required this.markSectionRead,
    required this.onSnapshot,
    this.currentScope,
    this.markTimeout = const Duration(seconds: 10),
  });

  final Future<int?> Function() fetchUnreadCount;
  final Future<Set<SelahNavSection>?> Function() fetchSectionsWithUnread;
  final Future<void> Function(SelahNavSection) markSectionRead;
  final void Function(int?, Set<SelahNavSection>?) onSnapshot;
  final Object? Function()? currentScope;
  final Duration markTimeout;

  int _revision = 0;
  int _pendingMarks = 0;
  bool _disposed = false;

  bool _isCurrent(int revision, Object? scope) =>
      !_disposed &&
      _pendingMarks == 0 &&
      revision == _revision &&
      currentScope?.call() == scope;

  Future<void> refresh() async {
    if (_disposed || _pendingMarks > 0) return;
    final revision = ++_revision;
    final scope = currentScope?.call();
    final count = await fetchUnreadCount();
    if (!_isCurrent(revision, scope)) return;
    final sections = await fetchSectionsWithUnread();
    if (!_isCurrent(revision, scope)) return;
    onSnapshot(count, sections);
  }

  Future<void> openSection(SelahNavSection section) async {
    if (_disposed) return;
    final scope = currentScope?.call();
    // Invalidate a poll that began before the section was marked read.
    ++_revision;
    ++_pendingMarks;
    try {
      await markSectionRead(section).timeout(markTimeout);
    } on TimeoutException {
      // A hung mark must not suspend all badge polling forever. Refetch only
      // confirmed server state; timing out never claims a dot was cleared.
    } finally {
      --_pendingMarks;
      if (!_disposed && _pendingMarks == 0 && currentScope?.call() == scope) {
        await refresh();
      }
    }
  }

  void dispose() {
    _disposed = true;
    ++_revision;
  }
}
