// Shepherd home shell — one stable navigation structure for every membership.
// Shepherd Basic sees paid destinations in place with a lock; entitlement
// changes access and content, never the shape of the app.
//
// 2026-07-19, inherited decision 089: moved to the floating glassmorphic pill
// nav — MENTOR ARCHITECTURE always specified "floating glass pill: same
// design as Seeker nav" (this file's own comment previously flagged the
// solid-bar version as a known deviation, "both should move to the
// floating-pill treatment together if that gets confirmed"). Confirmed
// today alongside removing Luxury Dark Purple (the bar's previous
// colour) from active use app-wide — inherited decision 090, selah_colors.dart.
//
// 2026-07-19, inherited decision 091: nav bar rebuilt onto the shared
// FloatingNavBar widget so this stays visually identical to Seeker's
// HomeShell — see widgets/floating_nav_bar.dart.
//
// 2026-08-13 (Founder) — THREE CHANGES, all parity with the Seeker shell:
//
//  1. THE DEV WRENCH IS GONE. It was the Shepherd's only route to the
//     account switcher when it was added; the dev side toggle
//     (DevScenarioPanel) replaced that, and the Seeker shell dropped its
//     own wrench for the same reason on 2026-07-26. Keeping it here left
//     the Shepherd with two doors to one room, one of which was a
//     debug-only icon sitting in the corner of a real screen.
//
//  2. THE BELL BECOMES A TAB, exactly as it did on the Seeker side
//     (inherited decision 149). The floating overlay is gone; Notifications sits in
//     the nav bar, left of Profile, carrying the unread badge the Bell
//     used to show. The shell owns the 20s unread poll now.
//
//     This DOES supersede the 2026-08-13 note in home_shell.dart that
//     "the Mentor side keeps its Bell — the Shepherd shell was not part of
//     this ruling". It is part of it now, by the Founder's instruction to
//     bring Shepherd into line with Seeker.
//
//  3. SEEKERS AND NETWORK SWAP PLACES. Network moves left of Seekers.
//
// 2026-07-26 (inherited upstream action 124 per-account-type UX review, #27): two parity
// gaps with the Seeker HomeShell fixed. (1) There was no Dev Access
// shortcut here at all — a Mentor test account had no way back to the
// account switcher without an app restart, unlike Seeker's HomeShell.
// (2) MentorProfileScreen's plan badge/"Manage Subscription" row had
// nowhere real to go — the real purchase surface is the Network tab's
// "Get Shepherd+" button (mentor_network_screen.dart), not the Seeker-
// only UpgradeScreen (which sells SELAH Basic/One via AppState.plan, a
// different entitlement entirely) — so a callback is threaded through,
// same pattern as HomeShell's onNavigateToConnections passed into
// BrowseScreen.

// 2026-08-13, inherited decision 152 — THE SHEPHERD DEV TOGGLE. The Seeker shell has
// had a pull-out scenario panel since 2026-08-01; this side had none, so
// every Shepherd state (a ward, their Journey, a Family Review waiting on
// you) needed two accounts and a live invite to reach. MentorDevScenarioPanel
// mounts as the LAST child of this Stack — above the nav bar, so its tab
// stays tappable — and the shell pushes the current tab into the shared
// scenario, exactly as HomeShell does with setCurrentPage, so the panel can
// draw only the controls for the page on screen.

import 'dart:async';

import 'package:flutter/material.dart';
import '../../dev/selah_app_gold_preview.dart';
import '../../dev/selah_dev_scenario.dart';
import '../../dev/selah_dev_surface_coordinator.dart';
import '../../services/selah_notification_service.dart';
import '../../services/selah_account_state.dart';
import '../../services/selah_developer_access.dart';
import '../../services/selah_internal_preview_client.dart';
import '../../services/selah_entitlement_service.dart';
import '../../services/selah_promotion_engine.dart';
import '../../services/selah_product_telemetry.dart';
import '../../widgets/floating_nav_bar.dart';
import '../../widgets/selah_shell_navigation.dart';
import '../../widgets/selah_keyboard_dismiss_scope.dart';
import '../../widgets/selah_bottom_promotion.dart';
import '../../theme/selah_colors.dart';
import '../../theme/selah_text.dart';
import '../../services/selah_mentor_link_service.dart';
import 'mentor_dashboard_screen.dart';
import 'mentor_network_screen.dart';
import 'mentor_profile_screen.dart';
import 'mentor_seekers_screen.dart';

@visibleForTesting
List<MentorPage> mentorPagesForMembership({required bool hasShepherdOne}) => [
  MentorPage.dashboard,
  MentorPage.network,
  MentorPage.seekers,
  MentorPage.profile,
];

class MentorHomeShell extends StatefulWidget {
  /// A protected, local-only landing after rehearsing Shepherd onboarding.
  /// This does not represent a created or verified member account.
  final bool initialOnboardingPreview;
  final Future<int?> Function()? loadUnreadCount;

  const MentorHomeShell({
    super.key,
    this.initialOnboardingPreview = false,
    this.loadUnreadCount,
  });

  @override
  State<MentorHomeShell> createState() => _MentorHomeShellState();
}

class _MentorHomeShellState extends State<MentorHomeShell> {
  MentorPage _page = MentorPage.dashboard;
  String? _requestedSeekerId;
  int _seekerSelectionRequest = 0;

  /// The Bell's unread count, relocated (2026-08-13) — the same 20s poll
  /// the Bell widget ran, now feeding the Dashboard tab's badge. Same
  /// mechanism as the Seeker shell, deliberately: two shells polling two
  /// different ways would drift.
  int _unread = 0;
  int _unreadRevision = 0;
  late final String? _ownerUserId;
  late final int _ownerGeneration;
  Timer? _unreadPoll;
  bool _hasShepherdPlus = false;

  bool get _currentAccount =>
      SelahAccountState.userId == _ownerUserId &&
      SelahAccountState.generation == _ownerGeneration;

  bool get _previewAllowed =>
      widget.initialOnboardingPreview &&
      SelahDeveloperAccess.canUseDeveloperTools &&
      SelahDeveloperAccess.isMainAppPreview &&
      SelahInternalPreviewClient.isActive;

  void _onPreviewAuthorityChanged() {
    if (mounted) setState(() {});
  }

  bool get _effectiveHasShepherdOne {
    if (!SelahDeveloperAccess.canUseDeveloperTools) return _hasShepherdPlus;
    return switch (SelahPromotionEngine.instance.developerShepherdNetworkState) {
      SelahDeveloperShepherdNetworkState.unlinkedBasic ||
      SelahDeveloperShepherdNetworkState.linkedBasic => false,
      _ => true,
    };
  }

  @override
  void initState() {
    super.initState();
    _ownerUserId = SelahAccountState.userId;
    _ownerGeneration = SelahAccountState.generation;
    if (widget.initialOnboardingPreview) {
      // The raw mode, not the current capability, owns this deny-only branch.
      // Losing authority must not fall through to ordinary member reads.
      SelahDeveloperAccess.authorizationChanges.addListener(
        _onPreviewAuthorityChanged,
      );
      SelahInternalPreviewClient.changes.addListener(_onPreviewAuthorityChanged);
    } else {
      SelahProductTelemetry.instance.record(
        feature: SelahTelemetryFeature.mySelah,
        name: SelahTelemetryEventName.opened,
        action: SelahTelemetryAction.pageView,
        surface: SelahTelemetrySurface.shepherd,
      );
      _refreshUnread();
      SelahEntitlementService.hasMentorOne().then((has) {
        if (!mounted || !_currentAccount) return;
        setState(() {
          _hasShepherdPlus = has;
        });
      });
      _unreadPoll = Timer.periodic(
        const Duration(seconds: 20),
        (_) => _refreshUnread(),
      );
    }
    if (SelahDeveloperAccess.canUseDeveloperTools) {
      // The panel needs to know where we ARE before the first tab change,
      // or its first open shows the wrong card.
      SelahDevScenario.instance.setCurrentMentorPage(_page);
      SelahDevScenario.instance.addListener(_onScenarioChange);
      SelahPromotionEngine.instance.addListener(_onMembershipPreviewChange);
      SelahDevSurfaceCoordinator.instance.attachShepherd(this, _openDevPage);
    }
  }

  @override
  void dispose() {
    _unreadPoll?.cancel();
    ++_unreadRevision;
    SelahDeveloperAccess.authorizationChanges.removeListener(
      _onPreviewAuthorityChanged,
    );
    SelahInternalPreviewClient.changes.removeListener(
      _onPreviewAuthorityChanged,
    );
    // Capability can disappear before disposal when a persona signs out.
    // removeListener is a no-op when no matching listener was registered, so
    // removal must be unconditional to avoid a dead shell retaining callbacks.
    SelahDevScenario.instance.removeListener(_onScenarioChange);
    SelahPromotionEngine.instance.removeListener(_onMembershipPreviewChange);
    SelahDevSurfaceCoordinator.instance.detachShepherd(this);
    super.dispose();
  }

  void _openDevPage(MentorPage page) {
    if (!mounted) return;
    // The retired Notifications preview resolves to its live owner: Dashboard.
    final destination = page == MentorPage.notifications
        ? MentorPage.dashboard
        : page;
    _goToPage(destination);
    Navigator.of(
      context,
      rootNavigator: true,
    ).popUntil((route) => route.isFirst);
  }

  /// Repaints the badge when the panel's staged unread count changes.
  /// Debug/profile only — never registered in a release build.
  void _onScenarioChange() {
    if (mounted) setState(() {});
  }

  void _onMembershipPreviewChange() {
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _refreshUnread() async {
    if (widget.initialOnboardingPreview || !_currentAccount) return;
    final revision = ++_unreadRevision;
    final count =
        await (widget.loadUnreadCount ??
            SelahNotificationService.fetchUnreadCount)();
    // Null = the fetch failed (BUG-05, inherited upstream action 225, 2026-08-15) — hold
    // the last known badge, same rule as the Seeker shell.
    if (mounted &&
        revision == _unreadRevision &&
        _currentAccount &&
        count != null &&
        count != _unread) {
      setState(() => _unread = count);
    }
  }

  /// What the badge shows.
  ///
  /// The staged count WINS while it is above zero, and only the badge is
  /// staged — the list behind it stays real rows. A count that disagreed
  /// with the list it labels would be worse than no control, so the panel
  /// says as much on the Notifications card.
  int get _badgeCount {
    if (!SelahDeveloperAccess.canUseDeveloperTools) return _unread;
    final staged = SelahDevScenario.instance.mentorUnread;
    return staged > 0 ? staged : _unread;
  }

  void _goToPage(MentorPage page, {bool preserveSeekerRequest = false}) {
    dismissSelahKeyboardAfterNavigation();
    final changed = page != _page;
    setState(() {
      _page = page;
      if (!preserveSeekerRequest && _requestedSeekerId != null) {
        _requestedSeekerId = null;
        _seekerSelectionRequest++;
      }
    });
    if (changed && !widget.initialOnboardingPreview) {
      SelahProductTelemetry.instance.record(
        feature: switch (page) {
          MentorPage.dashboard ||
          MentorPage.notifications => SelahTelemetryFeature.mySelah,
          MentorPage.network => SelahTelemetryFeature.connections,
          MentorPage.seekers => SelahTelemetryFeature.shepherd,
          MentorPage.profile => SelahTelemetryFeature.profile,
        },
        name: SelahTelemetryEventName.opened,
        action: SelahTelemetryAction.pageView,
        surface: SelahTelemetrySurface.shepherd,
      );
    }
    if (SelahDeveloperAccess.canUseDeveloperTools) {
      SelahDevScenario.instance.setCurrentMentorPage(page);
    }
    // Re-read on every tab change rather than waiting out the poll.
    _refreshUnread();
  }

  void _openSeeker(String seekerId) {
    // IDs, not names or Dashboard indexes: the roster groups people by role
    // and attention, and this tab stays mounted between visits.
    setState(() {
      _requestedSeekerId = seekerId;
      _seekerSelectionRequest++;
    });
    _goToPage(MentorPage.seekers, preserveSeekerRequest: true);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.initialOnboardingPreview && !_previewAllowed) {
      return Scaffold(
        key: const ValueKey('shepherd_onboarding_preview_denied'),
        body: DecoratedBox(
          decoration: SelahAppGoldDecoration(gradient: SelahColors.brandGradient),
          child: Center(
            child: Text(
              'Preview unavailable. Return to Developer Access.',
              style: SelahText.subtext(size: 15),
            ),
          ),
        ),
      );
    }
    final hasShepherdOne = _effectiveHasShepherdOne;
    final visiblePages = mentorPagesForMembership(hasShepherdOne: hasShepherdOne);
    final currentIndex = visiblePages
        .indexOf(_page)
        .clamp(0, visiblePages.length - 1);
    final pages = [
      MentorDashboardScreen(
        initialOnboardingPreview: widget.initialOnboardingPreview,
        hasShepherdPlus: hasShepherdOne,
        notificationCount: _badgeCount,
        onOpenNetwork: () => _goToPage(MentorPage.network),
        onOpenSeekers: () => _goToPage(MentorPage.seekers),
        onOpenSeeker: _openSeeker,
        onNotificationsChanged: _refreshUnread,
      ),
      // The preview is an uncreated account. Mounting live tabs in the
      // IndexedStack would eagerly read entitlements, links and profile data.
      // Keep the local Network experience, and inject an empty roster for
      // Seekers. Profile is intentionally unavailable until real sign-up.
      const MentorNetworkScreen(),
      MentorSeekersScreen(
        loadLinks: widget.initialOnboardingPreview
            ? () async => const SelahSourceResult.available(<MentorLinkedPerson>[])
            : null,
        hasShepherdOne: hasShepherdOne,
        requestedSeekerId: _requestedSeekerId,
        selectionRequest: _seekerSelectionRequest,
        onOpenNetwork: () => _goToPage(MentorPage.network),
      ),
      if (widget.initialOnboardingPreview)
        _localProfilePlaceholder()
      else
        MentorProfileScreen(
          onNavigateToNetwork: () => _goToPage(MentorPage.network),
        ),
    ];
    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          // IndexedStack, not `pages[_tab]` — 2026-08-13, parity with the
          // Seeker shell. A bare index swaps WIDGET TYPE on every tab
          // change, so Flutter disposed and rebuilt whichever screen you
          // left; the Network tab re-ran its entitlement fetch every single
          // visit. IndexedStack keeps every visible destination mounted and
          // just toggles which one paints.
          SelahMenuCanvas(
            child: IndexedStack(index: currentIndex, children: pages),
          ),
          // NO TOP-RIGHT CHROME. Notifications live in Dashboard and the dev
          // wrench retired to the side toggle, so this corner
          // belongs to each page again, exactly as it does on the Seeker
          // side. The history of both stays in git.
          SelahShellNavigation(
            currentIndex: currentIndex,
            onTap: (index) => _goToPage(visiblePages[index]),
            // Dashboard carries the live unread badge.
            items: [
              FloatingNavItem(
                icon: Icons.dashboard_outlined,
                label: 'Dashboard',
                badge: _badgeCount,
              ),
              FloatingNavItem(
                icon: Icons.diversity_3_outlined,
                label: 'Network',
                dimmed: !hasShepherdOne,
              ),
              FloatingNavItem(icon: Icons.people_outline, label: 'Seekers'),
              FloatingNavItem(icon: Icons.person_outline, label: 'Profile'),
            ],
          ),
          if (!widget.initialOnboardingPreview)
            SelahBottomPromotion(
              role: SelahPromotionRole.shepherd,
              placement: _page == MentorPage.profile
                  ? SelahPromotionPlacement.profile
                  : SelahPromotionPlacement.home,
              isCalmLanding: ModalRoute.of(context)?.isCurrent ?? true,
              isEntitled: hasShepherdOne,
              upgradeOfferAvailable: true,
              onOpenPlan: (_) => _goToPage(MentorPage.network),
            ),
          // Developer controls are app-wide in MaterialApp.builder. This
          // shell only registers the real Shepherd-tab callback.
        ],
      ),
    );
  }

  Widget _localProfilePlaceholder() => DecoratedBox(
    decoration: SelahAppGoldDecoration(gradient: SelahColors.brandGradient),
    child: SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'Your Shepherd profile will appear here after sign-up.',
            textAlign: TextAlign.center,
            style: SelahText.subtext(size: 16),
          ),
        ),
      ),
    ),
  );
}
