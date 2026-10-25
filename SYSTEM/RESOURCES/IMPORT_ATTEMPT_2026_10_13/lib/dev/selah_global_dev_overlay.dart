// App-wide developer overlay.
//
// The former controls lived inside HomeShell/ShepherdHomeShell, so every pushed
// route — Settings, Journey, Developer Access and onboarding — painted above
// them and hid the rail. This owner sits in MaterialApp.builder instead. The
// active shell still supplies its real tab callback; entry/signup gets a small
// truthful control panel rather than borrowing a Seeker or Shepherd scenario.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthChangeEvent, AuthState, User;

import '../config/selah_app_variant.dart';
import '../config/selah_internal_founder_policy.dart';
import '../screens/auth_gate.dart';
import '../screens/dev/developer_access_screen.dart';
import '../services/selah_account_state.dart';
import '../services/selah_auth.dart';
import '../services/selah_developer_access.dart';
import '../services/selah_promotion_engine.dart';
import '../theme/selah_colors.dart';
import '../theme/selah_text.dart';
import 'dev_onboarding_directions.dart';
import 'dev_role_choice_design.dart';
import 'dev_scenario_panel_v2.dart';
import 'shepherd_dev_scenario_panel.dart';
import 'selah_concept_preview_boundary.dart';
import 'selah_dev_control_system.dart';
import 'selah_dev_page_options.dart';
import 'selah_dev_scenario.dart';
import 'selah_dev_surface_coordinator.dart';
import 'selah_dev_signup.dart';
import 'selah_dev_home.dart';
import 'selah_dev_tool_section.dart';
import 'selah_page_preview_screen.dart';

/// Installs the developer controls into the app Navigator's own Overlay.
/// MaterialApp.builder sits above Navigator, so drawing the rail there as a
/// sibling would break Tooltip/Navigator lookups. An OverlayEntry is both
/// app-wide and still a real descendant of Navigator.
class SelahGlobalDevOverlayHost extends StatefulWidget {
  final Widget child;
  final GlobalKey<NavigatorState> navigatorKey;

  @visibleForTesting
  final Stream<AuthState>? authStateChangesOverride;

  @visibleForTesting
  final bool Function()? authorizationReaderOverride;

  @visibleForTesting
  final WidgetBuilder? authorityLossDestinationBuilder;

  /// Replaces the resume-time Founder authorization refresh in lifecycle
  /// regression tests. Production always uses the protected service.
  @visibleForTesting
  final Future<bool> Function()? resumeAuthorizationRefreshOverride;

  const SelahGlobalDevOverlayHost({
    super.key,
    required this.child,
    required this.navigatorKey,
    this.authStateChangesOverride,
    this.authorizationReaderOverride,
    this.authorityLossDestinationBuilder,
    this.resumeAuthorizationRefreshOverride,
  });

  @override
  State<SelahGlobalDevOverlayHost> createState() =>
      _SelahGlobalDevOverlayHostState();
}

class _SelahGlobalDevOverlayHostState extends State<SelahGlobalDevOverlayHost>
    with WidgetsBindingObserver {
  OverlayEntry? _entry;
  StreamSubscription<AuthState>? _authSubscription;
  bool _syncScheduled = false;
  bool _refreshingAuthorization = false;
  bool _accountTransition = false;
  int? _accountTransitionGeneration;
  late bool _lastAllowed;

  bool get _isAllowed =>
      !_accountTransition &&
      (widget.authorizationReaderOverride?.call() ??
          SelahDeveloperAccess.canUseDeveloperTools);

  @override
  void initState() {
    super.initState();
    _lastAllowed = _isAllowed;
    WidgetsBinding.instance.addObserver(this);
    SelahDeveloperAccess.authorizationChanges.addListener(
      _onAuthorizationChanged,
    );
  }

  void _ensureAuthSubscription() {
    if (_authSubscription != null) return;
    try {
      _authSubscription =
          (widget.authStateChangesOverride ?? SelahAuth.authStateChanges).listen(
            _onAuthState,
            onError: _onAuthStateError,
          );
    } catch (_) {
      // Supabase is intentionally absent for a locked/unconfigured build.
      // A later startup retry rebuilds this host and tries again.
    }
  }

  void _onAuthStateError(Object error, StackTrace stackTrace) {
    final wasAllowed = _lastAllowed;
    SelahDeveloperAccess.clearRefreshedClaims();
    _syncAuthorization(redirectIfLost: wasAllowed && !_isAllowed);
    debugPrint(
      'SELAH Developer Access authorization cleared after an auth stream '
      'failure.',
    );
  }

  void _onAuthState(AuthState state) {
    // Supabase has already replaced currentUser by the time this callback is
    // delivered. Preserve the capability observed before the event; reading
    // currentUser here would make a removed claim look as though it was never
    // authorized and would skip the guarded-route redirect.
    final wasAllowed = _lastAllowed;
    // Account reset begins synchronously, before any refreshed capability can
    // be published. Do not await disk cleanup inside the Auth event: an
    // explicit refresh can be waiting for this same event to finish.
    final userId = widget.authStateChangesOverride != null
        ? state.session?.user.id
        : SelahAuth.currentUser?.id;
    final previousUserId = SelahAccountState.userId;
    final cleanup = SelahAccountState.synchronize(userId);
    if ((_accountTransition ||
            (previousUserId != null && previousUserId != userId)) &&
        _accountTransitionGeneration != SelahAccountState.generation) {
      // Screen-local form/profile state is not cleared by resetting AppState.
      // Hide the outgoing tree and replace its whole stack for a new owner.
      final generation = SelahAccountState.generation;
      setState(() {
        _accountTransition = true;
        _accountTransitionGeneration = generation;
      });
      unawaited(_replaceAccountRoutes(cleanup, generation));
    }
    unawaited(
      cleanup.catchError((Object error) {
        if (!mounted) return;
        SelahDeveloperAccess.clearRefreshedClaims();
        _syncAuthorization(redirectIfLost: wasAllowed);
        debugPrint('SELAH account-local cleanup could not be confirmed.');
      }),
    );
    if (state.event == AuthChangeEvent.tokenRefreshed) {
      final user = state.session?.user;
      if (user != null) {
        // A persona's protected claim is not sufficient. Keep the overlay
        // absent while its caller-scoped synthetic IDV fixture is checked. If
        // refreshSession emitted this event, this joins that exact flight.
        unawaited(_acceptFreshTokenEvent(user, wasAllowed: wasAllowed));
        return;
      }
      SelahDeveloperAccess.clearRefreshedClaims();
      _syncAuthorization(redirectIfLost: wasAllowed && !_isAllowed);
      return;
    }

    if (state.event == AuthChangeEvent.userUpdated) {
      // userUpdated can carry a changed User object without proving that the
      // access token was refreshed. Never publish protected claims from it.
      // The replacement flight clears proof synchronously, then performs (or
      // supersedes with) an actual refresh before capability can return.
      unawaited(_refreshAfterUserUpdated(wasAllowed: wasAllowed));
      return;
    }

    if (state.session != null &&
        (state.event == AuthChangeEvent.initialSession ||
            state.event == AuthChangeEvent.signedIn ||
            state.event == AuthChangeEvent.passwordRecovery ||
            state.event == AuthChangeEvent.mfaChallengeVerified)) {
      // Initial-session replay can arrive after AuthGate has started its
      // refresh. Join that flight instead of discarding its pending result.
      // These events never prove claims: a real refresh is still required.
      unawaited(_refreshAfterSessionEvent(wasAllowed: wasAllowed));
      return;
    }

    // Sign-in, initial-session and recovery events are not the explicit
    // refresh required by the route policy. Clearing here also prevents one
    // principal's proof surviving a direct same-process account change.
    SelahDeveloperAccess.clearRefreshedClaims();
    _syncAuthorization(redirectIfLost: wasAllowed && !_isAllowed);
  }

  Future<void> _replaceAccountRoutes(
    Future<void> cleanup,
    int generation,
  ) async {
    await cleanup;
    if (!mounted || SelahAccountState.generation != generation) return;
    final binding = WidgetsBinding.instance;
    binding.addPostFrameCallback((_) {
      if (!mounted || SelahAccountState.generation != generation) return;
      widget.navigatorKey.currentState?.pushAndRemoveUntil(
        PageRouteBuilder<void>(
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
          pageBuilder: (context, _, _) =>
              widget.authorityLossDestinationBuilder?.call(context) ??
              const AuthGate(playSplash: false),
        ),
        (_) => false,
      );
      setState(() {
        _accountTransition = false;
        _accountTransitionGeneration = null;
      });
    });
    binding.scheduleFrame();
  }

  Future<void> _refreshAfterSessionEvent({required bool wasAllowed}) async {
    final authorization =
        SelahDeveloperAccess.refreshCurrentAuthorizationSnapshot();
    _syncAuthorization(redirectIfLost: wasAllowed && !_isAllowed);
    await authorization;
    if (!mounted) return;
    _syncAuthorization(redirectIfLost: wasAllowed && !_isAllowed);
  }

  Future<void> _acceptFreshTokenEvent(
    User user, {
    required bool wasAllowed,
  }) async {
    final authorization = SelahDeveloperAccess.acceptFreshTokenRefresh(user);
    _syncAuthorization(redirectIfLost: wasAllowed && !_isAllowed);
    await authorization;
    if (!mounted) return;
    _syncAuthorization(redirectIfLost: wasAllowed && !_isAllowed);
  }

  Future<void> _refreshAfterUserUpdated({required bool wasAllowed}) async {
    final authorization =
        SelahDeveloperAccess.refreshAuthorizationAfterUserUpdated();
    _syncAuthorization(redirectIfLost: wasAllowed && !_isAllowed);
    await authorization;
    if (!mounted) return;
    _syncAuthorization(redirectIfLost: wasAllowed && !_isAllowed);
  }

  void _onAuthorizationChanged() => _syncAuthorization();

  void _syncAuthorization({bool redirectIfLost = false}) {
    final allowed = _isAllowed;
    _lastAllowed = allowed;
    if (!allowed) {
      _entry?.remove();
      _entry = null;
      if (redirectIfLost) _redirectAfterAuthorityLoss();
      return;
    }
    _scheduleSync();
  }

  void _redirectAfterAuthorityLoss() {
    final binding = WidgetsBinding.instance;
    binding.addPostFrameCallback((_) {
      if (!mounted || _isAllowed) return;
      widget.navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(
          builder:
              widget.authorityLossDestinationBuilder ??
              (_) => const AuthGate(playSplash: false),
        ),
        (_) => false,
      );
    });
    // Async refresh completion can happen after the current frame's callback
    // phase. Request the frame explicitly so a revoked guarded route never
    // waits for unrelated UI activity before it is removed.
    binding.scheduleFrame();
  }

  Future<void> _refreshAuthorizationOnResume() async {
    final refreshOverride = widget.resumeAuthorizationRefreshOverride;
    if (_refreshingAuthorization ||
        (refreshOverride == null &&
            (SelahAppVariantPolicy.current != SelahAppVariant.production ||
                !SelahInternalFounderPolicy.enabled))) {
      return;
    }
    if (refreshOverride == null) {
      var signedIn = false;
      try {
        signedIn = SelahAuth.isSignedIn;
      } catch (_) {
        return;
      }
      if (!signedIn) return;
    }

    _refreshingAuthorization = true;
    final wasAllowed = _lastAllowed;
    var refreshed = false;
    try {
      final authorization =
          refreshOverride?.call() ??
          SelahDeveloperAccess.refreshCurrentAuthorization();
      // Starting a protected refresh invalidates the old proof immediately.
      // Retract the controls while it is in flight, but preserve the route:
      // iOS permission/share sheets generate a resume event and must not turn
      // that temporary fail-closed state into a Home-stack replacement.
      _syncAuthorization();
      refreshed = await authorization;
    } catch (error) {
      debugPrint('SELAH Developer Access resume refresh failed — $error');
    } finally {
      _refreshingAuthorization = false;
    }
    if (!mounted) return;
    _syncAuthorization(
      redirectIfLost: wasAllowed && (!refreshed || !_isAllowed),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshAuthorizationOnResume());
    }
  }

  void _scheduleSync() {
    _ensureAuthSubscription();
    if (_syncScheduled) return;
    _syncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncScheduled = false;
      if (!mounted) return;
      final allowed = _isAllowed;
      _lastAllowed = allowed;
      if (!allowed) {
        _entry?.remove();
        _entry = null;
        return;
      }
      if (_entry != null) return;
      final overlay = widget.navigatorKey.currentState?.overlay;
      if (overlay == null) {
        _scheduleSync();
        return;
      }
      final entry = OverlayEntry(builder: (_) => const SelahGlobalDevOverlay());
      overlay.insert(entry);
      _entry = entry;
    });
  }

  @override
  void didUpdateWidget(covariant SelahGlobalDevOverlayHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.navigatorKey != widget.navigatorKey) {
      _entry?.remove();
      _entry = null;
    }
    _scheduleSync();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    SelahDeveloperAccess.authorizationChanges.removeListener(
      _onAuthorizationChanged,
    );
    unawaited(_authSubscription?.cancel());
    _authSubscription = null;
    _entry?.remove();
    _entry = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _scheduleSync();
    return Stack(
      fit: StackFit.expand,
      children: [
        Offstage(offstage: _accountTransition, child: widget.child),
        if (_accountTransition) ColoredBox(color: SelahColors.modalSheetSurface),
      ],
    );
  }
}

/// One overlay above the Navigator. This is what keeps the four doors visible
/// on pushed routes instead of only on the two home-shell roots.
class SelahGlobalDevOverlay extends StatelessWidget {
  const SelahGlobalDevOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    if (!SelahDeveloperAccess.canUseDeveloperTools) {
      return const SizedBox.shrink();
    }
    final coordinator = SelahDevSurfaceCoordinator.instance;
    return ListenableBuilder(
      listenable: Listenable.merge([
        coordinator,
        SelahConceptPreviewIsolation.changes,
      ]),
      builder: (context, _) =>
          !SelahDeveloperAccess.canUseDeveloperTools ||
              SelahConceptPreviewIsolation.active
          ? const SizedBox.shrink()
          : Stack(
              children: [
                switch (coordinator.surface) {
                  SelahDevSurface.seeker => DevScenarioPanelV2(
                    onOpenPage: coordinator.openSeeker,
                    onOpenConnectionsSection:
                        coordinator.openSeekerConnectionsSection,
                    onOpenIntroductions: coordinator.openSeekerIntroductions,
                  ),
                  SelahDevSurface.shepherd => ShepherdDevScenarioPanel(
                    onOpenPage: coordinator.openShepherd,
                  ),
                  SelahDevSurface.entry => SelahEntryDevPanel(
                    pageLabel: coordinator.entryLabel,
                  ),
                },
              ],
            ),
    );
  }
}

/// Auth/signup/onboarding control. It uses the same four doors, but its
/// Actions remain entry-flow actions instead of pretending shell scenarios
/// have readers on an onboarding page.
class SelahEntryDevPanel extends StatefulWidget {
  final String pageLabel;

  const SelahEntryDevPanel({super.key, required this.pageLabel});

  @override
  State<SelahEntryDevPanel> createState() => _SelahEntryDevPanelState();
}

class _SelahEntryDevPanelState extends State<SelahEntryDevPanel> {
  static const double _panelWidth = 310;

  bool _open = false;
  SelahDevControlSection _section = SelahDevControlSection.preview;

  SelahCompatibilityDevControls? get _compatibility =>
      SelahDevSurfaceCoordinator.instance.activeCompatibilityControls;

  String get _pageContext {
    final controls = _compatibility;
    if (controls != null) {
      return 'entry:compatibility-${identityHashCode(controls)}';
    }
    final coordinator = SelahDevSurfaceCoordinator.instance;
    final roleOwner = coordinator.activeRoleChoiceOwner;
    return roleOwner == null
        ? 'entry:${widget.pageLabel}'
        : 'entry:${widget.pageLabel}:role-${identityHashCode(roleOwner)}'
              '-${coordinator.roleChoiceRevision}';
  }

  @override
  void initState() {
    super.initState();
    SelahDevSurfaceCoordinator.instance.addListener(_onContextChanged);
    SelahDeveloperAccess.authorizationChanges.addListener(_onContextChanged);
  }

  @override
  void dispose() {
    SelahDevSurfaceCoordinator.instance.removeListener(_onContextChanged);
    SelahDeveloperAccess.authorizationChanges.removeListener(_onContextChanged);
    super.dispose();
  }

  void _onContextChanged() {
    if (mounted) setState(() {});
  }

  List<SelahDevPageOption> _compatibilityOptions(
    SelahCompatibilityDevControls controls,
  ) => [
    for (final count in const [0, 1, 5])
      SelahDevPageOption(
        id: 'compatibility-plus-$count',
        label: '$count Compatibility Unlock${count == 1 ? '' : 's'}',
        group: 'Compatibility Unlock',
        selected: controls.balance(true) == count,
        onSelected: () {
          // The signup presentation remains Entry even after its nested
          // Home reaches a product page. Only that current sample route
          // owns these local balances; a retained menu cannot act later.
          if (!mounted ||
              !SelahDeveloperAccess.canUseDeveloperTools ||
              !identical(_compatibility, controls) ||
              !controls.isCurrent()) {
            return;
          }
          controls.setBalance(true, count);
        },
      ),
  ];

  void _select(SelahDevControlSection section) {
    setState(() {
      if (_open && section == _section) {
        _open = false;
      } else {
        _section = section;
        _open = true;
      }
    });
  }

  void _close() => setState(() => _open = false);

  void _preview() {
    _close();
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => SelahPagePreviewScreen.entry(widget.pageLabel),
      ),
    );
  }

  Future<void> _accounts() async {
    final navigator = Navigator.of(context);
    _close();
    final authorized = await SelahDeveloperAccess.refreshCurrentAuthorization();
    if (!authorized || !SelahDeveloperAccess.isAuthorizedOperator) {
      try {
        await SelahAuth.signOut();
      } catch (error) {
        debugPrint('SELAH Developer Access recheck sign-out failed: $error');
      }
      if (!navigator.mounted) return;
      navigator.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthGate(playSplash: false)),
        (route) => false,
      );
      return;
    }
    if (!navigator.mounted) return;
    navigator.push<void>(
      MaterialPageRoute(builder: (_) => const DeveloperAccessScreen()),
    );
  }

  void _signUp() {
    _close();
    SelahDevSignUp.start(context);
  }

  void _home(bool Function()? onboardingExit) {
    if (!mounted || !SelahDeveloperAccess.canUseDeveloperTools) return;
    if (onboardingExit != null) {
      // Bind the rendered action to its exact rehearsal owner. A stale tap
      // must not close a newer flow or fall through to generic navigation.
      if (onboardingExit()) _close();
      return;
    }
    unawaited(SelahDevHome.open(context));
    _close();
  }

  Future<void> _restart() async {
    _close();
    try {
      await SelahAuth.signOut();
    } catch (error) {
      debugPrint('SELAH global developer Home sign-out failed: $error');
    }
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthGate(playSplash: true)),
      (route) => false,
    );
  }

  void _reset() {
    SelahDevScenario.instance.reset();
    unawaited(SelahPromotionEngine.instance.resetDeveloperPolicy());
  }

  @override
  Widget build(BuildContext context) {
    if (!SelahDeveloperAccess.canUseDeveloperTools) {
      return const SizedBox.shrink();
    }
    final compatibility = _compatibility;
    final coordinator = SelahDevSurfaceCoordinator.instance;
    final onboardingExit = coordinator.onboardingExit;
    final roleChoiceOwner = coordinator.activeRoleChoiceOwner;
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      top: 0,
      bottom: 0,
      right: _open ? 0 : -_panelWidth,
      width: _panelWidth + SelahDevControlRail.width,
      child: Row(
        children: [
          SelahDevControlRail(
            open: _open,
            selected: _section,
            onSelected: _select,
          ),
          Expanded(
            child: Material(
              color: SelahColors.modalSheetSurface,
              child: SafeArea(
                left: false,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 8, 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _section == SelahDevControlSection.home
                                      ? 'Developer Access'
                                      : widget.pageLabel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: SelahText.heading(size: 18),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: _close,
                            icon: const Icon(
                              Icons.close,
                              size: 18,
                              color: Colors.white54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: Colors.white12),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(14, 14, 14, 30),
                        children: [
                          switch (_section) {
                            SelahDevControlSection.preview =>
                              SelahDevPreviewLauncher(
                                pageLabel: widget.pageLabel,
                                onOpen: _preview,
                              ),
                            SelahDevControlSection.actions => Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                SelahDevToolSection(
                                  key: const ValueKey(
                                    'dev_entry_section_onboarding',
                                  ),
                                  child: DevOnboardingDirectionPicker(
                                    onBeforeOpen: _close,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                const SelahDevToolSection(
                                  key: ValueKey(
                                    'dev_entry_section_onboarding_transitions',
                                  ),
                                  child: DevOnboardingTransitionPicker(),
                                ),
                                const SizedBox(height: 16),
                                SelahDevPageOptions(
                                  contextKey: _pageContext,
                                  options: [
                                    if (compatibility != null)
                                      ..._compatibilityOptions(compatibility),
                                    if (roleChoiceOwner != null)
                                      for (final design
                                          in SelahRoleChoiceDesign.values)
                                        SelahDevPageOption(
                                          id: 'dev_role_choice_${design.name}',
                                          label: design.label,
                                          group: 'Role choice design',
                                          selected:
                                              SelahDevRoleChoiceDesign.current ==
                                              design,
                                          onSelected: () {
                                            if (!coordinator
                                                .selectRoleChoiceDesign(
                                                  roleChoiceOwner,
                                                  design,
                                                )) {
                                              throw StateError(
                                                'Role choice route is no longer current.',
                                              );
                                            }
                                          },
                                        ),
                                    SelahDevPageOption(
                                      id: 'dev_entry_accounts',
                                      label: 'Switch test account',
                                      group: 'Entry',
                                      onSelected: _accounts,
                                    ),
                                    SelahDevPageOption(
                                      id: 'dev_entry_signup',
                                      label: 'Onboarding',
                                      group: 'Onboarding',
                                      onSelected: _signUp,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            SelahDevControlSection.home => SelahDevHomeTools(
                              busy: false,
                              onHome: () => _home(onboardingExit),
                              onOpenSplashPreview: _close,
                              onRestart: _restart,
                              onReset: _reset,
                              onAccounts: _accounts,
                              onSeekerSignUp: _signUp,
                              onShepherdSignUp: _signUp,
                            ),
                          },
                          if (_section == SelahDevControlSection.preview) ...[
                            const SizedBox(height: 18),
                            Text(
                              'Internal preview',
                              textAlign: TextAlign.center,
                              style: SelahText.subtext(
                                size: 10,
                                color: Colors.white24,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
