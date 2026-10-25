import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../dev/selah_dev_scenario.dart';
import '../services/selah_account_state.dart';
import '../services/selah_developer_access.dart';

/// Denial-only lifetime for caller-owned Shepherd display state. A preview
/// request cannot grant authority, and a revoked route cannot become live or
/// rehydrate fixtures after an account switch or restored developer access.
class SelahShepherdPreviewLifetime extends ChangeNotifier {
  SelahShepherdPreviewLifetime({required this.preview})
    : _owner = SelahAccountState.userId,
      _generation = SelahAccountState.generation,
      _previewAdmitted = SelahDevScenario.instance.shepherdOverride {
    SelahDevScenario.instance.addListener(_changed);
    SelahDeveloperAccess.authorizationChanges.addListener(_changed);
  }

  final bool preview;
  final String? _owner;
  final int _generation;
  final bool _previewAdmitted;
  bool _revoked = false;

  bool get isCurrent =>
      !_revoked &&
      !SelahAccountState.isSigningOut &&
      _owner == SelahAccountState.userId &&
      _generation == SelahAccountState.generation &&
      (!preview ||
          (_previewAdmitted && SelahDevScenario.instance.shepherdOverride));

  bool get canPreview => preview && isCurrent;

  void _changed() {
    if (!isCurrent) revoke();
  }

  /// Invalidates an old person/source-mode binding before a replacement load.
  void revoke() {
    if (_revoked) return;
    _revoked = true;
    notifyListeners();
  }

  @override
  void dispose() {
    // Sheets own separate routes and can outlive a removed owner route.
    revoke();
    SelahDevScenario.instance.removeListener(_changed);
    SelahDeveloperAccess.authorizationChanges.removeListener(_changed);
    super.dispose();
  }
}

/// Clears an already-open sheet/destination immediately and removes only its
/// exact route after the frame. Unrelated routes are never popped.
class SelahShepherdPreviewRouteBoundary extends StatefulWidget {
  final SelahShepherdPreviewLifetime authority;
  final Widget child;

  const SelahShepherdPreviewRouteBoundary({
    super.key,
    required this.authority,
    required this.child,
  });

  @override
  State<SelahShepherdPreviewRouteBoundary> createState() =>
      _SelahShepherdPreviewRouteBoundaryState();
}

class _SelahShepherdPreviewRouteBoundaryState
    extends State<SelahShepherdPreviewRouteBoundary> {
  bool _closing = false;
  ModalRoute<dynamic>? _route;

  @override
  void initState() {
    super.initState();
    widget.authority.addListener(_changed);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route = ModalRoute.of(context);
    if (!widget.authority.isCurrent) _changed();
  }

  @override
  void didUpdateWidget(covariant SelahShepherdPreviewRouteBoundary oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.authority, widget.authority)) return;
    oldWidget.authority.removeListener(_changed);
    widget.authority.addListener(_changed);
    if (!widget.authority.isCurrent) _changed();
  }

  void _changed() {
    if (!mounted || _closing || widget.authority.isCurrent) return;
    // A separate owner may be disposing while Flutter's tree is locked.
    // Deny immediately, but defer UI/route mutation to the safe frame boundary.
    _closing = true;
    final binding = WidgetsBinding.instance;
    if (binding.schedulerPhase != SchedulerPhase.persistentCallbacks) {
      setState(() {});
    }
    final route = _route;
    binding.addPostFrameCallback((_) {
      if (!mounted) return;
      if (route == null || route.isFirst) {
        setState(() {});
      } else {
        route.navigator?.removeRoute(route);
      }
    });
    binding.ensureVisualUpdate();
  }

  @override
  void dispose() {
    widget.authority.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.authority.isCurrent && !_closing
      ? widget.child
      : const SizedBox.shrink();
}
