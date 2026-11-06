// Founder-requested concept only. Fixtures never enter AppState, storage,
// entitlements, relationship APIs or the ordinary Browse route.
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../services/selah_account_state.dart';
import '../services/selah_developer_access.dart';
import '../services/selah_local_prefs.dart';
import '../state/app_state.dart';
import '../theme/selah_colors.dart';
import '../theme/selah_text.dart';
import 'selah_one_journey_concept_shell.dart';
import 'selah_concept_preview_boundary.dart';
import 'selah_dev_local_preview.dart';

class _DraftOwner extends ChangeNotifier {
  _DraftOwner({required this.generation, required this.userId})
    : _admitted = SelahDeveloperAccess.canUseDeveloperTools {
    SelahDeveloperAccess.authorizationChanges.addListener(_changed);
    AppState.instance.addListener(_changed);
  }

  final int generation;
  final String? userId;
  final bool _admitted;
  bool _revoked = false;
  bool _disposed = false;

  bool get current =>
      _admitted &&
      !_revoked &&
      SelahDeveloperAccess.canUseDeveloperTools &&
      !SelahAccountState.isSigningOut &&
      generation == SelahAccountState.generation &&
      userId == SelahAccountState.userId;

  void _changed() {
    if (current || _revoked) return;
    _revoked = true;
    notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _revoked = true;
    SelahDeveloperAccess.authorizationChanges.removeListener(_changed);
    AppState.instance.removeListener(_changed);
    super.dispose();
  }
}

class DevDiscoveryDirectionPicker extends StatefulWidget {
  const DevDiscoveryDirectionPicker({
    super.key,
    this.enabled = true,
    this.onBeforeOpen,
  });
  final bool enabled;
  final VoidCallback? onBeforeOpen;

  @override
  State<DevDiscoveryDirectionPicker> createState() =>
      _DevDiscoveryDirectionPickerState();
}

class _DevDiscoveryDirectionPickerState
    extends State<DevDiscoveryDirectionPicker> {
  late final _DraftOwner _owner = _DraftOwner(
    generation: SelahAccountState.generation,
    userId: SelahAccountState.userId,
  );
  bool _opening = false;

  @override
  void dispose() {
    _owner.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    if (!mounted || !widget.enabled || _opening || !_owner.current) return;
    if (SelahDeveloperAccess.isMainAppFounderPreview &&
        !SelahDeveloperAccess.isAuthorizedTester &&
        _owner.userId != null &&
        SelahLocalPrefs.accountOwner == _owner.userId) {
      // Replace the old shell with the new style, not another route on top.
      // Fresh launches also reset to new; the cached style only carries the
      // current session's comparison across persona changes. Admission was
      // checked before closing; open rechecks fresh proof and owner lifetime.
      _opening = true;
      final role = SelahLocalPrefs.cachedFounderPreviewRole;
      // Capture the still-mounted panel's navigator before refresh/collapse
      // retracts that panel. The entry method owns the awaited lifetime check.
      final opening = SelahDevLocalPreview.open(
        context,
        isMentor: role == 'shepherd',
        appStyle: 'request',
      );
      widget.onBeforeOpen?.call();
      await opening;
      if (mounted) setState(() => _opening = false);
      return;
    }
    final navigator = Navigator.of(context);
    final admission = _DraftOwner(
      generation: _owner.generation,
      userId: _owner.userId,
    );
    _opening = true;
    widget.onBeforeOpen?.call();
    // Closing the developer panel must not let a stale callback open a route
    // for a newly selected account. Bind the destination to this exact owner.
    if (!admission.current) {
      admission.dispose();
      _opening = false;
      return;
    }
    // Deny real-shell controls even during the incoming route's first frame.
    final launchLease = SelahConceptPreviewIsolation.acquire();
    try {
      await navigator.push<void>(
        MaterialPageRoute(
          builder: (_) => ViewRequestDraftScreen._(
            admission: admission,
            launchLease: launchLease,
          ),
        ),
      );
    } finally {
      admission.dispose();
      launchLease.release();
    }
    if (mounted) setState(() => _opening = false);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _owner,
    builder: (context, _) => !_owner.current
        ? const SizedBox.shrink()
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('App style', style: SelahText.body(size: 15)),
              const SizedBox(height: 8),
              _DraftButton(
                id: 'dev_discovery_view_request',
                label: 'Back to new style',
                icon: Icons.travel_explore_outlined,
                onTap: widget.enabled && !_opening ? _open : null,
              ),
            ],
          ),
  );
}

/// A disposable, local prototype. No live profiles or relationship writes.
class ViewRequestDraftScreen extends StatefulWidget {
  const ViewRequestDraftScreen({
    super.key,
    required this.ownerGeneration,
    required this.ownerId,
    this.onExit,
    this.onOption1,
    this.onDeveloperHome,
    this.onRoleChanged,
    this.initialShepherdRole = false,
    this.initialSeekerBasic = false,
    this.initialShepherdBasic = false,
  }) : _admission = null,
       _launchLease = null;
  ViewRequestDraftScreen._({
    required _DraftOwner admission,
    required this._launchLease,
  }) : onExit = null,
       onOption1 = null,
       onDeveloperHome = null,
       onRoleChanged = null,
       initialShepherdRole = false,
       initialSeekerBasic = false,
       initialShepherdBasic = false,
       _admission = admission,
       ownerGeneration = admission.generation,
       ownerId = admission.userId;
  final int ownerGeneration;
  final String? ownerId;
  final VoidCallback? onExit;
  final VoidCallback? onOption1;
  final VoidCallback? onDeveloperHome;
  final ValueChanged<bool>? onRoleChanged;
  final bool initialShepherdRole;
  final bool initialSeekerBasic;
  final bool initialShepherdBasic;
  final _DraftOwner? _admission;
  final SelahConceptPreviewLease? _launchLease;

  @override
  State<ViewRequestDraftScreen> createState() => _ViewRequestDraftScreenState();
}

class _ViewRequestDraftScreenState extends State<ViewRequestDraftScreen> {
  late final _DraftOwner _owner;
  @override
  void initState() {
    super.initState();
    _owner =
        widget._admission ??
        _DraftOwner(generation: widget.ownerGeneration, userId: widget.ownerId);
    _owner.addListener(_authorityChanged);
    // The mounted boundary takes over denial. Navigator disposal need not
    // complete push's Future, so the temporary launcher lease cannot rely on
    // that Future alone for cleanup.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => widget._launchLease?.release(),
    );
  }

  void _authorityChanged() {
    if (!mounted) return;
    if (!_owner.current) widget._launchLease?.release();
    final binding = WidgetsBinding.instance;
    if (binding.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      binding.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
      binding.scheduleFrame();
    } else {
      setState(() {});
    }
  }

  bool get _canAct =>
      mounted && _owner.current && (ModalRoute.of(context)?.isCurrent ?? false);

  bool _canActOnOwnedPause(Route<dynamic> pauseRoute) {
    if (!mounted || !_owner.current) return false;
    final hostRoute = ModalRoute.of(context);
    return hostRoute != null &&
        hostRoute.isActive &&
        !identical(hostRoute, pauseRoute) &&
        pauseRoute.isCurrent &&
        identical(hostRoute.navigator, pauseRoute.navigator);
  }

  void _close() {
    if (!_canAct) return;
    if (widget.onExit != null) {
      widget.onExit!();
      return;
    }
    Navigator.of(context).pop<void>();
  }

  @override
  void dispose() {
    _owner.removeListener(_authorityChanged);
    _owner.dispose();
    widget._launchLease?.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_owner.current) {
      return Scaffold(
        backgroundColor: SelahColors.luxuryDarkPurple,
        body: SafeArea(
          child: Center(child: Text('Preview closed', style: SelahText.body())),
        ),
      );
    }
    return SelahConceptPreviewBoundary(
      child: SelahOneJourneyConceptShell(
        canAct: () => _canAct,
        canActOnOwnedPause: _canActOnOwnedPause,
        appearanceCanAct: () => mounted && _owner.current,
        onExit: _close,
        onOption1: widget.onOption1 == null
            ? null
            : () {
                if (_canAct) widget.onOption1!();
              },
        onDeveloperHome: widget.onDeveloperHome == null
            ? null
            : () {
                if (_canAct) widget.onDeveloperHome!();
              },
        onRoleChanged: widget.onRoleChanged == null
            ? null
            : (shepherd) {
                if (_canAct) widget.onRoleChanged!(shepherd);
              },
        initialShepherdRole: widget.initialShepherdRole,
        initialSeekerBasic: widget.initialSeekerBasic,
        initialShepherdBasic: widget.initialShepherdBasic,
      ),
    );
  }
}

class _DraftButton extends StatelessWidget {
  const _DraftButton({
    required this.id,
    required this.label,
    required this.onTap,
    this.icon,
  });
  final String id;
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => OutlinedButton(
    key: ValueKey(id),
    onPressed: onTap,
    style: OutlinedButton.styleFrom(
      minimumSize: const Size(44, 44),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      foregroundColor: SelahColors.journeyGold,
      side: BorderSide(color: SelahColors.journeyGold.withValues(alpha: .4)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[Icon(icon, size: 17), const SizedBox(width: 9)],
        Flexible(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: SelahText.body(size: 12.5, color: SelahColors.journeyGold),
          ),
        ),
      ],
    ),
  );
}
