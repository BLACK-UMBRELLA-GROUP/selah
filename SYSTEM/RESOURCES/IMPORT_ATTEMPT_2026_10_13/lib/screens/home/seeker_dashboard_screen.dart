// Seeker Dashboard — one resolver, one production renderer.
//
// Developer scenarios use the same Quiet renderer and governed resolution as
// production. Scenario data never becomes account truth.

import 'package:flutter/material.dart';

import '../../dev/selah_dev_scenario.dart';
import '../../dev/selah_supportive_dashboard_preview.dart';
import '../../models/selah_dashboard_lab.dart';
import '../../models/selah_dashboard_resolution.dart';
import '../../models/journey_match.dart';
import '../../models/selah_supportive_dashboard.dart';
import '../../services/selah_dashboard_adapter.dart';
import '../../services/selah_developer_access.dart';
import '../../services/selah_internal_preview_client.dart';
import '../../services/selah_notification_service.dart';
import '../../services/selah_profile_service.dart';
import '../../services/selah_shepherd_link_service.dart';
import '../../state/app_state.dart';
import '../../widgets/selah_quiet_dashboard.dart';
import '../../widgets/selah_glass_dialog.dart';
import '../../theme/selah_text.dart';

typedef SelahDashboardSnapshotLoader = Future<DashboardSnapshot> Function();

class SeekerDashboardScreen extends StatefulWidget {
  final int unreadCount;
  final VoidCallback onOpenConnections;
  final VoidCallback? onOpenConnectionsActivity;
  final VoidCallback onOpenShepherd;
  final VoidCallback? onNotificationsChanged;
  final VoidCallback? onOpenDiscovery;
  final VoidCallback? onOpenProfile;
  final VoidCallback? onReviewPreferences;
  final VoidCallback? onResumeOnboarding;
  final SelahOnboardingProgress? initialOnboardingProgress;

  /// Only the protected first-use rehearsal may supply local incomplete
  /// onboarding truth. Ordinary members continue to use the server adapter.
  final bool onboardingEntryPreview;

  /// Test seam for measured production-state rendering. Normal app code uses
  /// [SelahSeekerDashboardAdapter.load].
  final SelahDashboardSnapshotLoader? loadDashboard;

  const SeekerDashboardScreen({
    super.key,
    required this.unreadCount,
    required this.onOpenConnections,
    this.onOpenConnectionsActivity,
    required this.onOpenShepherd,
    this.onNotificationsChanged,
    this.onOpenDiscovery,
    this.onOpenProfile,
    this.onReviewPreferences,
    this.onResumeOnboarding,
    this.initialOnboardingProgress,
    this.onboardingEntryPreview = false,
    this.loadDashboard,
  });

  @override
  State<SeekerDashboardScreen> createState() => _SeekerDashboardScreenState();
}

class _SeekerDashboardScreenState extends State<SeekerDashboardScreen> {
  static const _resolver = DashboardResolver();
  static const _adapter = SelahSeekerDashboardAdapter();

  late DashboardResolution _resolution;
  var _loadGeneration = 0;
  late bool _wasUsingLab;

  @override
  void initState() {
    super.initState();
    _resolution = _resolver.resolve(
      _localOnboardingPreviewAllowed
          ? _localOnboardingSnapshot()
          : _loadingSnapshot(),
    );
    _wasUsingLab = _usingLab;
    if (SelahDeveloperAccess.canUseDeveloperTools) {
      SelahDevScenario.instance.addListener(_scenarioChanged);
    }
    SupportiveDashboardPreview.instance.addListener(_scenarioChanged);
    SelahDeveloperAccess.authorizationChanges.addListener(_scenarioChanged);
    SelahShepherdLinkService.invitationRevision.addListener(_sourceChanged);
    SelahShepherdLinkService.linkRevision.addListener(_sourceChanged);
    if (!_wasUsingLab) _reload();
  }

  @override
  void didUpdateWidget(covariant SeekerDashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.unreadCount != widget.unreadCount ||
        oldWidget.initialOnboardingProgress !=
            widget.initialOnboardingProgress ||
        oldWidget.onboardingEntryPreview != widget.onboardingEntryPreview ||
        oldWidget.loadDashboard != widget.loadDashboard) {
      _reload();
    }
  }

  @override
  void dispose() {
    SelahDevScenario.instance.removeListener(_scenarioChanged);
    SupportiveDashboardPreview.instance.removeListener(_scenarioChanged);
    SelahDeveloperAccess.authorizationChanges.removeListener(_scenarioChanged);
    SelahShepherdLinkService.invitationRevision.removeListener(_sourceChanged);
    SelahShepherdLinkService.linkRevision.removeListener(_sourceChanged);
    super.dispose();
  }

  void _sourceChanged() => _reload();

  bool get _requestedLocalOnboardingPreview =>
      widget.onboardingEntryPreview &&
      widget.initialOnboardingProgress?.complete == false;

  bool get _localOnboardingPreviewAllowed =>
      _requestedLocalOnboardingPreview &&
      SelahInternalPreviewClient.isActive &&
      SelahDeveloperAccess.canUseDeveloperTools;

  bool get _usingLab {
    if (_requestedLocalOnboardingPreview) return false;
    final preview = SupportiveDashboardPreview.instance;
    return SupportiveDashboardPreview.allowed &&
        preview.enabled &&
        !preview.useCurrentSources;
  }

  void _scenarioChanged() {
    if (_requestedLocalOnboardingPreview) {
      // Rebuild the same synthetic incomplete state if developer authority
      // returns; never resume by loading a real member snapshot.
      if (_localOnboardingPreviewAllowed) {
        _reload();
      } else {
        ++_loadGeneration;
      }
      return;
    }
    final usingLab = _usingLab;
    if (!_wasUsingLab && usingLab) ++_loadGeneration;
    if (_wasUsingLab && !usingLab) _reload();
    _wasUsingLab = usingLab;
  }

  Future<void> _reload() async {
    if (_requestedLocalOnboardingPreview) {
      // A revoked or unlatched rehearsal stays denied; it may not fall
      // through to real account reads or reuse a previous member snapshot.
      if (!_localOnboardingPreviewAllowed) return;
      ++_loadGeneration;
      setState(
        () => _resolution = _resolver.resolve(_localOnboardingSnapshot()),
      );
      return;
    }
    // Local candidates never initiate account reads or notification writes.
    if (_usingLab) return;
    final generation = ++_loadGeneration;
    try {
      final snapshot = await (widget.loadDashboard ?? _adapter.load)();
      if (!mounted || generation != _loadGeneration) return;
      final next = _resolver.resolve(snapshot).retainUpdatesFrom(_resolution);
      setState(() => _resolution = next);
    } catch (_) {
      if (!mounted || generation != _loadGeneration) return;
      final next = _resolver
          .resolve(_failedSnapshot())
          .retainUpdatesFrom(_resolution);
      setState(() => _resolution = next);
    }
  }

  @override
  Widget build(BuildContext context) {
    final firstName = AppState.instance.name?.trim();
    final scenario = SelahDevScenario.instance;
    final preview = SupportiveDashboardPreview.instance;
    return ListenableBuilder(
      listenable: Listenable.merge([
        scenario,
        preview,
        SelahDeveloperAccess.authorizationChanges,
      ]),
      builder: (context, _) {
        if (_requestedLocalOnboardingPreview) {
          if (!_localOnboardingPreviewAllowed) {
            return const SizedBox.expand(
              key: ValueKey('seeker_onboarding_preview_denied'),
            );
          }
          return _production(firstName);
        }
        if (SupportiveDashboardPreview.allowed && preview.enabled) {
          final fixtureMode = !preview.useCurrentSources;
          final fixture = fixtureMode ? preview.fixture : null;
          return SelahQuietDashboard(
            key: ValueKey(
              'supportive-${fixtureMode ? preview.scenario.name : 'sources'}-${preview.action.name}-${preview.status.name}-${preview.change.name}-${preview.editorial.name}-${preview.insight.name}-${preview.reflection.name}',
            ),
            resolution: fixture?.resolution ?? _resolution,
            fixtureCards: fixture?.cards ?? const [],
            fixtureMode: fixtureMode,
            comparisonClock: fixtureMode
                ? SupportiveDashboardFixtures.clock
                : null,
            firstName: firstName,
            selectedTabIndex: preview.tabIndex,
            onTabChanged: preview.selectTab,
            onRetry: fixtureMode ? null : _reload,
            onNavigate: (card) {
              // Capture the mode. A sample callback can never become live
              // after changing tabs, scenarios or accounts.
              if (!SupportiveDashboardPreview.allowed) return;
              if (fixtureMode) {
                _showPreviewDestination(card);
              } else {
                _navigate(card.target);
              }
            },
          );
        }
        return _production(
          firstName,
          blankUntilDeveloperSelection:
              SupportiveDashboardPreview.allowed && !preview.enabled,
        );
      },
    );
  }

  void _showPreviewDestination(SupportiveCard card) {
    final owner =
        card.ownerLabel ??
        switch (card.target) {
          SelahDashboardTarget.shepherd => 'Shepherd',
          SelahDashboardTarget.connectionsJourneys => 'Connections · Journey',
          SelahDashboardTarget.connectionsActivity => 'Connections · Activity',
          SelahDashboardTarget.onboarding => 'Onboarding',
          _ =>
            card.actionLabel == 'View membership'
                ? 'Membership'
                : 'Article / guide',
        };
    showSelahGlassDialog<void>(
      context: context,
      builder: (dialogContext) => ListenableBuilder(
        listenable: SelahDeveloperAccess.authorizationChanges,
        builder: (context, _) {
          if (!SupportiveDashboardPreview.allowed) {
            return const Text('Preview closed');
          }
          return SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Destination preview', style: SelahText.chapterLabel()),
                const SizedBox(height: 12),
                Text(card.title, style: SelahText.heading(size: 20)),
                if (card.detail != null) ...[
                  const SizedBox(height: 12),
                  Text(card.detail!, style: SelahText.body(size: 14)),
                ],
                const SizedBox(height: 16),
                Text('Owner page: $owner', style: SelahText.body(size: 14)),
                const SizedBox(height: 8),
                Text(
                  'This is a local design example. No request, payment, '
                  'Journey action or private note is sent or saved.',
                  style: SelahText.subtext(size: 12),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text('Back to My SELAH'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _markAllNotificationsRead() async {
    await SelahNotificationService.markAllRead();
    await _reload();
    widget.onNotificationsChanged?.call();
  }

  Widget _production(
    String? firstName, {
    bool blankUntilDeveloperSelection = false,
  }) => KeyedSubtree(
    key: const ValueKey('seeker-production-dashboard'),
    child: SelahQuietDashboard(
      resolution: _resolution,
      firstName: firstName,
      onNavigate: (card) => _navigate(card.target),
      onRetry: _reload,
      onRefresh: _reload,
      blankUntilDeveloperSelection: blankUntilDeveloperSelection,
      insightsEntitled: AppState.instance.plan == SelahPlan.one,
      onMarkAllNotificationsRead: _markAllNotificationsRead,
      unreadCount: widget.unreadCount,
      selectedTabIndex: SelahDeveloperAccess.canUseDeveloperTools
          ? SelahDevScenario.instance.dashboardTab.index
          : null,
      onTabChanged: (index) {
        if (SelahDeveloperAccess.canUseDeveloperTools) {
          SelahDevScenario.instance.setDashboardTab(
            SelahDashboardTab.values[index],
          );
        }
      },
    ),
  );

  void _navigate(SelahDashboardTarget target) {
    switch (target) {
      case SelahDashboardTarget.none:
        return;
      case SelahDashboardTarget.discovery:
        widget.onOpenDiscovery?.call();
      case SelahDashboardTarget.connectionsJourneys:
        widget.onOpenConnections();
      case SelahDashboardTarget.connectionsActivity:
        (widget.onOpenConnectionsActivity ?? widget.onOpenConnections)();
      case SelahDashboardTarget.shepherd:
        widget.onOpenShepherd();
      case SelahDashboardTarget.notifications:
        // My SELAH is the notification centre. Notification-only update rows
        // stay in Now instead of opening a second screen.
        return;
      case SelahDashboardTarget.profile:
        widget.onOpenProfile?.call();
      case SelahDashboardTarget.preferences:
        (widget.onReviewPreferences ?? widget.onOpenProfile)?.call();
      case SelahDashboardTarget.onboarding:
        widget.onResumeOnboarding?.call();
    }
  }

  DashboardSnapshot _loadingSnapshot() => const DashboardSnapshot(
    role: DashboardRole.seeker,
    onboarding: DashboardSource.loading(),
    journeys: DashboardSource.loading(),
    updates: DashboardSource.loading(),
    shepherdInvitations: DashboardSource.loading(),
    insights: DashboardSource.loading(),
    advisories: DashboardSource.loading(),
    stableState: DashboardStableState(
      orientationItems: DashboardSource.loading(),
      family: DashboardSource.loading(),
    ),
  );

  DashboardSnapshot _localOnboardingSnapshot() =>
      SelahSeekerDashboardAdapter.buildSnapshot(
        onboarding: DashboardSource.available(
          widget.initialOnboardingProgress!,
        ),
        journeys: const DashboardSource.available(<JourneyMatch>[]),
        updates: const DashboardSource.available(<DashboardSignal>[]),
        shepherdInvitations: const DashboardSource.available(<PendingInvite>[]),
        linkedPeople: const DashboardSource.available(<ShepherdLinkedPerson>[]),
      );

  DashboardSnapshot _failedSnapshot() {
    const failure = DashboardFailure(code: 'dashboard_load_failed');
    return const DashboardSnapshot(
      role: DashboardRole.seeker,
      onboarding: DashboardSource.unavailable(failure),
      journeys: DashboardSource.unavailable(failure),
      updates: DashboardSource.unavailable(failure),
      shepherdInvitations: DashboardSource.unavailable(failure),
      insights: DashboardSource.unavailable(failure),
      advisories: DashboardSource.unavailable(failure),
      stableState: DashboardStableState(
        orientationItems: DashboardSource.unavailable(failure),
        family: DashboardSource.unavailable(failure),
      ),
    );
  }
}
