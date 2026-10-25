import 'package:flutter/material.dart';

import '../screens/auth_gate.dart';
import '../services/selah_developer_access.dart';
import '../widgets/selah_loading.dart';

/// Revalidates protected Developer Access before a route paints its content.
/// Cached capability may hide a control, but it is never sufficient to open a
/// fresh destination after the server has removed a role or persona claim.
class SelahDeveloperRouteGate extends StatefulWidget {
  const SelahDeveloperRouteGate({
    super.key,
    required this.child,
    this.requireFounderOperator = false,
    this.refreshOverride,
    this.deniedDestinationBuilder,
  });

  final Widget child;
  final bool requireFounderOperator;

  @visibleForTesting
  final Future<bool> Function()? refreshOverride;

  @visibleForTesting
  final WidgetBuilder? deniedDestinationBuilder;

  @override
  State<SelahDeveloperRouteGate> createState() => _SelahDeveloperRouteGateState();
}

class _SelahDeveloperRouteGateState extends State<SelahDeveloperRouteGate> {
  late Future<bool> _authorization;
  bool _redirectScheduled = false;

  @override
  void initState() {
    super.initState();
    _authorization = _refresh();
  }

  Future<bool> _refresh() async {
    final refreshed =
        await (widget.refreshOverride?.call() ??
            SelahDeveloperAccess.refreshCurrentAuthorization());
    if (!refreshed) return false;
    return widget.requireFounderOperator
        ? SelahDeveloperAccess.isAuthorizedOperator
        : SelahDeveloperAccess.canUseDeveloperTools;
  }

  void _scheduleDeniedRedirect() {
    if (_redirectScheduled) return;
    _redirectScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder:
              widget.deniedDestinationBuilder ??
              (_) => const AuthGate(playSplash: false),
        ),
        (_) => false,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _authorization,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SelahLoading.fullScreen(label: 'Checking access…');
        }
        final cachedStillAllowed = widget.requireFounderOperator
            ? SelahDeveloperAccess.isAuthorizedOperator
            : SelahDeveloperAccess.canUseDeveloperTools;
        if (snapshot.data != true || !cachedStillAllowed) {
          _scheduleDeniedRedirect();
          return const SizedBox.shrink();
        }
        return widget.child;
      },
    );
  }
}
