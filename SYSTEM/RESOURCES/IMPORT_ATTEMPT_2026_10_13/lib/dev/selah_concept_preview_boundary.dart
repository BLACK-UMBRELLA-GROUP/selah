import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Denial-only presentation ownership for a complete synthetic app preview.
///
/// This never grants developer authority, changes the account or releases the
/// local-preview network latch. The caller owns admission and every synthetic
/// callback. While any admitted preview is mounted, its own local navigation
/// replaces the ordinary developer rail's real-shell destinations.
abstract final class SelahConceptPreviewIsolation {
  static final _owners = HashSet<SelahConceptPreviewLease>.identity();
  static final _changes = ValueNotifier<int>(0);
  static int _revision = 0;
  static bool _notificationScheduled = false;

  static bool get active => _owners.isNotEmpty;
  static int get revision => _revision;
  static Listenable get changes => _changes;

  /// A unique route owner, not a mutable global on/off switch.
  static SelahConceptPreviewLease acquire() {
    final lease = SelahConceptPreviewLease._();
    _owners.add(lease);
    _changed();
    return lease;
  }

  static void _release(SelahConceptPreviewLease lease) {
    if (!_owners.remove(lease)) return;
    _changed();
  }

  static void _changed() {
    _revision++;
    final binding = WidgetsBinding.instance;
    if (binding.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      // A route may mount/dispose while Navigator is building. Change the
      // denial synchronously, but rebuild the sibling overlay safely later.
      if (_notificationScheduled) return;
      _notificationScheduled = true;
      binding.addPostFrameCallback((_) {
        _notificationScheduled = false;
        _changes.value = _revision;
      });
      binding.ensureVisualUpdate();
    } else {
      _changes.value = _revision;
    }
  }
}

/// Only this lease can release its own denial. Repeated/stale release is inert.
final class SelahConceptPreviewLease {
  SelahConceptPreviewLease._();

  bool _released = false;

  void release() {
    if (_released) return;
    _released = true;
    SelahConceptPreviewIsolation._release(this);
  }
}

/// Mount only around the admitted synthetic tree, not its revoked placeholder.
///
/// Nested preview destinations keep the owner's denial until that tree is
/// disposed. A replacement preview obtains an independent lease.
class SelahConceptPreviewBoundary extends StatefulWidget {
  const SelahConceptPreviewBoundary({super.key, required this.child});

  final Widget child;

  @override
  State<SelahConceptPreviewBoundary> createState() =>
      _SelahConceptPreviewBoundaryState();
}

class _SelahConceptPreviewBoundaryState
    extends State<SelahConceptPreviewBoundary> {
  late final SelahConceptPreviewLease _lease;

  @override
  void initState() {
    super.initState();
    _lease = SelahConceptPreviewIsolation.acquire();
  }

  @override
  void dispose() {
    _lease.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
