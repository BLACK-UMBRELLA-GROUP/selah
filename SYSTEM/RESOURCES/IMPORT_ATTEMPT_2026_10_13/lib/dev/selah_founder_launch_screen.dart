import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../services/selah_account_state.dart';
import '../services/selah_developer_access.dart';
import '../services/selah_internal_preview_client.dart';
import '../services/selah_local_prefs.dart';
import '../theme/selah_colors.dart';
import '../theme/selah_text.dart';
import '../widgets/selah_loading.dart';
import 'dev_discovery_directions.dart';
import 'selah_concept_preview_boundary.dart';
import 'selah_dev_home.dart';
import 'selah_dev_local_preview.dart';

/// Only returned by the router after fresh exact-Founder proof. Every fresh
/// launch opens the new local presentation; Option 1 is an in-session choice.
/// Neither presentation admits a real member.
class SelahFounderLaunchScreen extends StatefulWidget {
  const SelahFounderLaunchScreen({
    super.key,
    required this.ownerId,
    required this.ownerGeneration,
  });
  final String ownerId;
  final int ownerGeneration;

  @override
  State<SelahFounderLaunchScreen> createState() =>
      _SelahFounderLaunchScreenState();
}

class _SelahFounderLaunchScreenState extends State<SelahFounderLaunchScreen> {
  bool _opening = false;
  bool _failed = false;

  bool get _current =>
      mounted &&
      SelahAccountState.isCurrent(widget.ownerId, widget.ownerGeneration) &&
      (ModalRoute.of(context)?.isCurrent ?? false);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _open());
  }

  Future<void> _open() async {
    if (!_current || _opening) return;
    setState(() {
      _opening = true;
      _failed = false;
    });
    // Recovery re-establishes proof first; a failed refresh must not trap the
    // protected launch in a button that requires the proof it is retrying.
    if (!SelahDeveloperAccess.canUseDeveloperTools) {
      final authorization =
          await SelahDeveloperAccess.refreshCurrentAuthorizationSnapshot();
      if (!_current) return;
      if (!authorization.founderAuthorized ||
          authorization.user?.id != widget.ownerId) {
        setState(() {
          _opening = false;
          _failed = true;
        });
        return;
      }
    }
    if (!mounted || !_current) return;
    final opened = await SelahDevLocalPreview.open(
      context,
      isShepherd: SelahLocalPrefs.cachedFounderPreviewRole == 'shepherd',
      appStyle: 'request',
    );
    if (!_current) return;
    setState(() {
      _opening = false;
      _failed = !opened;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_failed) {
      return const SelahLoading.fullScreen();
    }
    return Scaffold(
      backgroundColor: SelahColors.luxuryDarkPurple,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Could not open your preview.', style: SelahText.body()),
                const SizedBox(height: 20),
                OutlinedButton(
                  key: const ValueKey('founder_launch_retry'),
                  onPressed: _open,
                  child: const Text('Try again'),
                ),
                OutlinedButton(
                  key: const ValueKey('founder_launch_developer_home'),
                  onPressed: () => SelahDevHome.open(context),
                  child: const Text('Developer Home'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Replaces (never resurrects) the disposable preview owner after a successful
/// Auth refresh. Old callbacks stay revoked. The network latch and isolation
/// boundary remain in force while access is being rechecked.
class SelahFounderReviewSurface extends StatefulWidget {
  const SelahFounderReviewSurface({
    super.key,
    required this.ownerId,
    required this.ownerGeneration,
    this.initialShepherdRole = false,
    this.initialSeekerBasic = false,
    this.initialShepherdBasic = false,
  });
  final String ownerId;
  final int ownerGeneration;
  final bool initialShepherdRole;
  final bool initialSeekerBasic;
  final bool initialShepherdBasic;

  @override
  State<SelahFounderReviewSurface> createState() =>
      _SelahFounderReviewSurfaceState();
}

class _SelahFounderReviewSurfaceState extends State<SelahFounderReviewSurface> {
  late final int _preferenceGeneration = SelahLocalPrefs.bindingGeneration;
  bool _hadProof = false;
  bool _revoked = false;
  int _proofEpoch = 0;
  late bool _shepherdRole = widget.initialShepherdRole;

  bool get _sameOwner =>
      !_revoked &&
      SelahAccountState.isCurrent(widget.ownerId, widget.ownerGeneration) &&
      _preferenceGeneration == SelahLocalPrefs.bindingGeneration;
  bool get _hasProof =>
      _sameOwner &&
      SelahDeveloperAccess.isMainAppFounderPreview &&
      SelahDeveloperAccess.canUseDeveloperTools &&
      !SelahDeveloperAccess.isAuthorizedTester &&
      SelahInternalPreviewClient.isActive;

  bool _callbackCurrent(int epoch) =>
      mounted &&
      epoch == _proofEpoch &&
      _hasProof &&
      (ModalRoute.of(context)?.isCurrent ?? false);

  @override
  void initState() {
    super.initState();
    _hadProof = _hasProof;
    SelahDeveloperAccess.authorizationChanges.addListener(_proofChanged);
    SelahInternalPreviewClient.changes.addListener(_proofChanged);
  }

  void _proofChanged() {
    if (!mounted) return;
    if (!_sameOwner) _revoked = true;
    final proof = _hasProof;
    if (proof && !_hadProof) _proofEpoch++;
    _hadProof = proof;
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

  void _rememberRole(bool shepherd) {
    if (!_hasProof || !(ModalRoute.of(context)?.isCurrent ?? false)) return;
    _shepherdRole = shepherd;
    SelahLocalPrefs.setFounderPreviewRole(
      shepherd ? 'shepherd' : 'seeker',
      expectedOwner: widget.ownerId,
      expectedBindingGeneration: _preferenceGeneration,
    );
  }

  @override
  void dispose() {
    _revoked = true;
    SelahDeveloperAccess.authorizationChanges.removeListener(_proofChanged);
    SelahInternalPreviewClient.changes.removeListener(_proofChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final epoch = _proofEpoch;
    return SelahConceptPreviewBoundary(
      child: !_hasProof
          ? const SelahLoading.fullScreen()
          : ViewRequestDraftScreen(
              key: ValueKey('founder_request_style_$_proofEpoch'),
              ownerId: widget.ownerId,
              ownerGeneration: widget.ownerGeneration,
              initialShepherdRole: _shepherdRole,
              initialSeekerBasic: widget.initialSeekerBasic,
              initialShepherdBasic: widget.initialShepherdBasic,
              onExit: () {
                if (_callbackCurrent(epoch)) {
                  SelahDevHome.open(context, replacePreviewRoot: true);
                }
              },
              onDeveloperHome: () {
                if (_callbackCurrent(epoch)) {
                  SelahDevHome.open(context, replacePreviewRoot: true);
                }
              },
              onRoleChanged: (shepherd) {
                if (_callbackCurrent(epoch)) _rememberRole(shepherd);
              },
              onOption1: () {
                if (!_callbackCurrent(epoch)) return;
                SelahDevLocalPreview.open(
                  context,
                  isShepherd: _shepherdRole,
                  premium: _shepherdRole
                      ? !widget.initialShepherdBasic
                      : !widget.initialSeekerBasic,
                  appStyle: 'option1',
                );
              },
            ),
    );
  }
}
