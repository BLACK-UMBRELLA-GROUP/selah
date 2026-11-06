// Home shell — bottom navigation across Browse / Connections / Dashboard /
// Shepherd / Profile.
//
// 2026-08-13 (inherited decision 149, Founder via the ChatGPT nav brief + his own
// placement correction): NOTIFICATIONS BECAME THE FIFTH TAB — "left of
// profile, right of shepherd" — and the floating Bell overlay that sat
// top-right over every tab since 2026-07-26 is GONE. This supersedes
// APP/Navigation/SEEKER NAVIGATION Summary's "Notifications are not a
// navigation tab" rule (doc update raised as inherited upstream action 206). The Bell's
// unread badge survives the move: this shell now owns the 20s unread
// poll the Bell used to run, feeding the tab's badge; opening the tab
// marks rows read in the screen itself, and leaving it re-reads the
// count. The Mentor side keeps its Bell — the Shepherd shell was not part
// of this ruling.
//
// 2026-07-26 (inherited decision 101 audit, nav bar fix): rebuilt from 3 tabs
// (Browse/Matches/Profile) to the 4 tabs approved in APP/Navigation/
// SEEKER NAVIGATION/Summary.md's NAVIGATION STRUCTURE table for both
// SELAH Basic and SELAH One Seekers. That spec document itself flagged
// this exact gap under CURRENT STATUS (2026-07-19, unresolved): "live
// Seeker nav has only 3 tabs... matches neither the 4-tab spec nor any
// coherent variant." A separate 2026-07-19 discussion item (inherited upstream action 129)
// proposed a 5th tab (Network, locked for Seekers) — Founder decision
// 2026-07-26 was to build the ratified 4-tab structure and NOT add
// Network, since "Network is never available to Seekers (any tier)"
// is an explicitly confirmed rule (2026-06-27) and inherited upstream action 129 was
// never ratified against it. The Matches tab is renamed Connections
// and now also houses Passed/Saved/Considered per that same spec's
// CONNECTIONS section — see screens/connections/connections_screen.dart.
// The new Mentor tab is screens/mentor/seeker_mentor_tab.dart, a tab-body
// wrapper around the existing LinkMentorScreen mechanism.
//
// 2026-07-19 (inherited upstream action 125 §3, inherited decision 089): the fixed solid dark-purple
// `bottomNavigationBar` bar was replaced with a floating glassmorphic
// pill. `extendBody: true` was already set, so BrowseScreen's
// full-bleed photo already reached the bottom of the screen — the
// change is purely about what floats on top of it.
//
// 2026-07-19, inherited decision 091: nav bar itself rebuilt onto the shared
// FloatingNavBar widget (widgets/floating_nav_bar.dart) — Founder
// supplied Instagram + Lovable reference recordings; the icon-grows-
// when-selected behaviour and the single sliding circular highlight
// (rather than each item having its own static background) both come
// from those references. See that file's header for full detail.

import 'dart:async';

import 'package:flutter/foundation.dart' show setEquals, visibleForTesting;
import 'package:flutter/material.dart';

import '../../dev/selah_dev_scenario.dart';
import '../../dev/selah_dev_surface_coordinator.dart';
import '../../services/selah_notification_service.dart';
import '../../services/selah_developer_access.dart';
import '../../services/selah_internal_preview_client.dart';
import '../../services/selah_promotion_engine.dart';
import '../../services/selah_profile_service.dart';
import '../../services/selah_auth.dart';
import '../../services/selah_account_state.dart';
import '../../services/selah_product_telemetry.dart';
import '../../state/app_state.dart';
import '../../theme/selah_colors.dart';
import '../../widgets/selah_bottom_promotion.dart';
import '../../widgets/floating_nav_bar.dart';
import '../../widgets/selah_shell_navigation.dart';
import '../../widgets/selah_keyboard_dismiss_scope.dart';
import '../../theme/selah_interaction_style.dart';
import '../browse/browse_screen.dart';
import '../browse/find_by_selah_code_screen.dart';
import '../connections/connections_screen.dart';
import '../connections/connections_section_controller.dart';
import '../onboarding/account_path_overview_screen.dart';
import '../profile/edit_profile_screen.dart';
import '../profile/profile_screen.dart';
import '../settings/help_support_screen.dart';
import '../subscription/upgrade_screen.dart';
import '../mentor/seeker_mentor_tab.dart';
import 'seeker_dashboard_screen.dart';
import 'unread_badge_coordinator.dart';

class HomeShell extends StatefulWidget {
  final int initialTab;
  final SelahOnboardingProgress? initialOnboardingProgress;
  final bool deferredOnboardingDevPreview;

  const HomeShell({
    super.key,
    this.initialTab = 2,
    this.initialOnboardingProgress,
    this.deferredOnboardingDevPreview = false,
  });

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  late int _tab;
  late final (String?, int) _ownerScope;
  late final SelahUnreadBadgeCoordinator _unreadCoordinator;
  SelahOnboardingProgress? _onboardingProgress;
  bool _resumingOnboarding = false;
  final SelahConnectionsSectionController _connectionsSection =
      SelahConnectionsSectionController();

  /// True while a tab is showing something that must own the entire
  /// screen — currently only Browse's sponsored card. Hides the Bell and
  /// the nav bar, which otherwise render above the tab content and cover
  /// its corners (2026-08-01, Founder: "the skip in the top right is
  /// behind the bell icon").
  bool _chromeHidden = false;

  /// Tab index -> the page the dev scenario panel gates on. The panel is
  /// a sibling of the IndexedStack, not a child, so it cannot read this
  /// itself — it has to be pushed. Debug-only work; in a release build the
  /// panel does not exist and this is a field assignment nothing reads.
  static const _devPages = [
    DevPage.browse,
    DevPage.connections,
    DevPage.dashboard,
    DevPage.shepherd,
    DevPage.profile,
  ];

  static const _telemetryFeatures = [
    SelahTelemetryFeature.browse,
    SelahTelemetryFeature.connections,
    SelahTelemetryFeature.mySelah,
    SelahTelemetryFeature.shepherd,
    SelahTelemetryFeature.profile,
  ];

  /// The Bell's unread count, relocated (inherited decision 149): same 20s poll the
  /// Bell widget ran, now feeding the Dashboard tab's notification badge.
  int _unread = 0;
  Timer? _unreadPoll;

  /// Sections with something waiting — the nav bar's dots (inherited decision 154).
  ///
  /// A SET, not counts: the dot says whether, not how many. See
  /// SelahNotificationService.fetchSectionsWithUnread.
  Set<SelahNavSection> _sectionDots = const {};

  /// ACTION MODE — 2026-08-13 (inherited decision 150, Founder's ChatGPT brief,
  /// built on his word over the counter-proposal): Browse's ⋮ asks this
  /// shell to transform the nav bar into the profile-action destinations,
  /// and a tap anywhere else restores it. Choosing Hide transforms the bar
  /// once more into equal Cancel / Confirm pills. Non-null IS
  /// the mode: the value is what Report should do right now (Browse
  /// hands over "report whoever is on the card"), so the shell never
  /// needs to know who is on screen.
  /// Hide Profile left the report sheet and became its own option, so the card
  /// hands the shell the already-bound action plus presentation-ready warning
  /// copy. The shell never has to resolve or retain the profile identity.
  ({
    VoidCallback report,
    VoidCallback hide,
    String hideWarning,
    VoidCallback compatibility,
  })?
  _cardActions;
  bool get _actionMode => _cardActions != null;
  bool _hideConfirmation = false;
  bool get _hideConfirmationMode => _actionMode && _hideConfirmation;

  /// Which action the bar is sitting on while in action mode.
  ///
  /// STARTS AT 0, AND THAT IS SAFE NOW IN A WAY IT WAS NOT. inherited decision 153
  /// refused to show any resting highlight, because Report Profile was
  /// the first option and a circle resting on it would have said that
  /// option was already chosen. The Founder's 2026-08-13 reorder put
  /// Compatibility Unlock first and Report last, so the resting
  /// highlight now sits on the most benign action on the bar — and the
  /// bar can look exactly like the nav bar, which always highlights
  /// something.
  int _actionIndex = 0;

  /// The action bar's items, in the Founder's display order.
  static const List<({IconData icon, String label, _CardAct act})>
  _actionOptions = [
    // insights_outlined, matching the Compatibility action on the
    // Connections cards exactly — one idea, one glyph, wherever it is
    // reached from.
    (
      icon: Icons.insights_outlined,
      label: 'Compatibility',
      act: _CardAct.compatibility,
    ),
    (
      icon: Icons.qr_code_scanner_rounded,
      label: 'Selah Code',
      act: _CardAct.findByCode,
    ),
    (icon: Icons.visibility_off_outlined, label: 'Hide', act: _CardAct.hide),
    (icon: Icons.help_outline, label: 'Help', act: _CardAct.help),
    (icon: Icons.flag_outlined, label: 'Report', act: _CardAct.report),
  ];

  /// Runs the chosen action and closes action mode.
  ///
  /// COMMIT-ON-RELEASE IS OPTED INTO, VIA FloatingNavBar.commitOnRelease.
  ///
  /// CORRECTED 2026-08-13 (inherited decision 161). This comment previously claimed
  /// commit-on-release was already the bar's behaviour. It was not, and
  /// the claim was made without reading _handleTouchAt closely enough:
  /// the bar fires onTap the moment a scrub CROSSES a cell, which is
  /// right for tabs and was a live bug here — sliding left to right ran
  /// Hide Profile as the finger passed over it, before it was lifted.
  /// The behaviour is now a property on the shared widget rather than an
  /// assumption about it.
  ///
  /// Two things changed. Report is now LAST, furthest from the thumb.
  /// And — checked before adopting this, not assumed — NONE of the four
  /// actions fires irreversibly on its own: Report opens a sheet that
  /// requires a reason, Hide enters the dedicated Cancel / Confirm nav,
  /// Help and
  /// Compatibility push a screen you can leave. Every one of them has a
  /// next step, so an accidental tap costs a dismissal.
  void _runAction(int index) {
    final act = _actionOptions[index].act;
    final actions = _cardActions;
    if (actions == null) return;
    if (act == _CardAct.hide) {
      setState(() {
        _actionIndex = index;
        _hideConfirmation = true;
      });
      return;
    }
    setState(() {
      _actionIndex = index;
      _cardActions = null;
      _hideConfirmation = false;
    });
    switch (act) {
      case _CardAct.compatibility:
        actions.compatibility();
      case _CardAct.findByCode:
        SelahProductTelemetry.instance.record(
          feature: SelahTelemetryFeature.selahCode,
          name: SelahTelemetryEventName.opened,
          action: SelahTelemetryAction.pageView,
          surface: SelahTelemetrySurface.seeker,
        );
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const FindBySelahCodeScreen()));
      case _CardAct.hide:
        return;
      case _CardAct.help:
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const HelpSupportScreen()));
      case _CardAct.report:
        actions.report();
    }
  }

  void _closeCardActions() {
    setState(() {
      _cardActions = null;
      _hideConfirmation = false;
    });
  }

  void _confirmHide() {
    final hide = _cardActions?.hide;
    if (hide == null) return;
    _closeCardActions();
    hide();
  }

  @override
  void initState() {
    super.initState();
    _ownerScope = (SelahAccountState.userId, SelahAccountState.generation);
    _unreadCoordinator = SelahUnreadBadgeCoordinator(
      fetchUnreadCount: SelahNotificationService.fetchUnreadCount,
      fetchSectionsWithUnread: SelahNotificationService.fetchSectionsWithUnread,
      markSectionRead: SelahNotificationService.markSectionRead,
      onSnapshot: _applyUnreadSnapshot,
      currentScope: () =>
          (SelahAccountState.userId, SelahAccountState.generation),
    );
    _tab = widget.initialTab.clamp(0, _devPages.length - 1);
    _onboardingProgress = widget.initialOnboardingProgress;
    SelahDevScenario.instance.setCurrentPage(_devPages[_tab]);
    SelahProductTelemetry.instance.record(
      feature: _telemetryFeatures[_tab],
      name: SelahTelemetryEventName.opened,
      action: SelahTelemetryAction.pageView,
      surface: SelahTelemetrySurface.seeker,
    );
    if (SelahDeveloperAccess.canUseDeveloperTools) {
      SelahDevSurfaceCoordinator.instance.attachSeeker(
        this,
        _openDevPage,
        onOpenConnectionsSection: (section) =>
            _openConnectionsSection(SelahConnectionsSection.fromPage(section)),
        onOpenIntroductions: () =>
            _openConnectionsSection(SelahConnectionsSection.introductions),
      );
    }
    if (!widget.deferredOnboardingDevPreview) {
      _refreshUnread();
      _unreadPoll = Timer.periodic(
        const Duration(seconds: 20),
        (_) => _refreshUnread(),
      );
    }
  }

  Future<void> _resumeOnboarding() async {
    if (_resumingOnboarding) return;
    _resumingOnboarding = true;
    final owner = widget.deferredOnboardingDevPreview
        ? null
        : SelahAuth.currentUser?.id;
    final generation = SelahAccountState.generation;
    try {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => SeekerOnboardingOverviewScreen(
            gender: AppState.instance.gender,
            progress: _onboardingProgress,
            devPreview: widget.deferredOnboardingDevPreview,
          ),
        ),
      );
      // The protected onboarding rehearsal has no server-side profile to read.
      if (widget.deferredOnboardingDevPreview) return;
      final progress = await SelahProfileService.fetchOnboardingProgress();
      if (!mounted ||
          progress == null ||
          SelahAuth.currentUser?.id != owner ||
          SelahAccountState.generation != generation) {
        return;
      }
      setState(() => _onboardingProgress = progress);
    } finally {
      _resumingOnboarding = false;
    }
  }

  @override
  void dispose() {
    _unreadPoll?.cancel();
    _unreadCoordinator.dispose();
    _connectionsSection.dispose();
    SelahDevSurfaceCoordinator.instance.detachSeeker(this);
    super.dispose();
  }

  void _openDevPage(DevPage page) {
    if (!mounted) return;
    _goToTab(_devPages.indexOf(page));
    Navigator.of(
      context,
      rootNavigator: true,
    ).popUntil((route) => route.isFirst);
  }

  Future<void> _refreshUnread() {
    if (widget.deferredOnboardingDevPreview || !_currentAccount) {
      return Future<void>.value();
    }
    return _unreadCoordinator.refresh();
  }

  bool get _currentAccount =>
      _ownerScope == (SelahAccountState.userId, SelahAccountState.generation);

  void _applyUnreadSnapshot(int? count, Set<SelahNavSection>? dots) {
    if (!mounted) return;
    // NULL = THE FETCH FAILED — BUG-05 (inherited upstream action 225, 2026-08-15): hold
    // the last known badge and dots rather than zeroing marks that may
    // still be earned. A lie in the optimistic direction is still a lie.
    final newCount = count ?? _unread;
    final newDots = dots ?? _sectionDots;
    if (newCount != _unread || !setEquals(newDots, _sectionDots)) {
      setState(() {
        _unread = newCount;
        _sectionDots = newDots;
      });
    }
  }

  /// Which section each tab IS, for the dot-clearing rule. Index-matched
  /// to the nav items below; null where a tab is nobody's destination.
  static const List<SelahNavSection?> _tabSections = [
    null, // Browse
    SelahNavSection.connections,
    // My SELAH is deliberately null. Entering the notification centre does not
    // silently mark anything read; Now owns the explicit mark-read action.
    null,
    SelahNavSection.shepherd,
    null, // Profile
  ];

  void _goToTab(int index) {
    dismissSelahKeyboardAfterNavigation();
    final changed = index != _tab;
    if (index != 1) _connectionsSection.collapseCards();
    setState(() => _tab = index);
    if (changed) {
      SelahProductTelemetry.instance.record(
        feature: _telemetryFeatures[index],
        name: SelahTelemetryEventName.opened,
        action: SelahTelemetryAction.pageView,
        surface: SelahTelemetrySurface.seeker,
      );
    }
    SelahDevScenario.instance.setCurrentPage(_devPages[index]);
    if (widget.deferredOnboardingDevPreview || !_currentAccount) return;
    // OPENING A SECTION CLEARS ITS DOT — inherited decision 154 (Founder: "the user
    // does NOT need to open the exact notification item for the dot to
    // disappear"). The coordinator invalidates earlier polls and waits for
    // the mark before fetching a new badge snapshot.
    final section = _tabSections[index];
    if (section != null) {
      unawaited(_unreadCoordinator.openSection(section));
    } else {
      // Re-read on other tab changes instead of waiting out the poll.
      unawaited(_refreshUnread());
    }
  }

  void _openConnectionsSection(SelahConnectionsSection section) {
    _connectionsSection.open(section);
    _goToTab(1);
  }

  void _openPreferenceEditor() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const EditProfileScreen()));
  }

  @override
  Widget build(BuildContext context) {
    if (widget.deferredOnboardingDevPreview) {
      return ListenableBuilder(
        listenable: Listenable.merge([
          SelahDeveloperAccess.authorizationChanges,
          SelahInternalPreviewClient.changes,
        ]),
        builder: (context, _) {
          if (!SelahDeveloperAccess.canUseDeveloperTools ||
              !SelahInternalPreviewClient.isActive) {
            return Scaffold(
              key: const ValueKey('seeker_home_preview_denied'),
              backgroundColor: SelahColors.modalSheetSurface,
              body: const SizedBox.expand(),
            );
          }
          return _buildShell(context);
        },
      );
    }
    return _buildShell(context);
  }

  Widget _buildShell(BuildContext context) {
    final pages = [
      BrowseScreen(
        onNavigateToConnections: () => _goToTab(1),
        onFullScreenTakeover: (taking) {
          if (_chromeHidden == taking) return;
          setState(() => _chromeHidden = taking);
        },
        onOpenActions: (actions) => setState(() {
          _cardActions = actions;
          _hideConfirmation = false;
          // Always opens on Compatibility. Leaving the highlight where
          // the last visit left it would mean the bar sometimes opened
          // sitting on Report.
          _actionIndex = 0;
        }),
      ),
      // "View profile" on a Shepherd Suggestion parks the profile in
      // AppState and asks for the Browse tab (Founder, 2026-08-05). Browse
      // consumes it on its next build. Done through the shell because
      // Connections cannot change the tab itself — it doesn't own the
      // IndexedStack.
      ConnectionsScreen(
        onNavigateToBrowse: () => _goToTab(0),
        onNavigateToShepherd: () => _goToTab(3),
        sectionController: _connectionsSection,
      ),
      // My SELAH is the notification centre: Now combines current priorities
      // with updates, while Insights is the deeper SELAH One view.
      SeekerDashboardScreen(
        unreadCount: _unread,
        initialOnboardingProgress: _onboardingProgress,
        onboardingEntryPreview: widget.deferredOnboardingDevPreview,
        onOpenDiscovery: () => _goToTab(0),
        onOpenProfile: () => _goToTab(4),
        onResumeOnboarding: _resumeOnboarding,
        onOpenConnections: () =>
            _openConnectionsSection(SelahConnectionsSection.journeys),
        onOpenConnectionsActivity: () =>
            _openConnectionsSection(SelahConnectionsSection.activity),
        onOpenShepherd: () => _goToTab(3),
        onReviewPreferences: _openPreferenceEditor,
        onNotificationsChanged: _refreshUnread,
      ),
      const SeekerMentorTab(),
      const ProfileScreen(),
    ];
    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          // FIXED 2026-07-27 (Founder, dev-mode report: "when on dev i
          // click home and change profiles a old picture shows up
          // before it changes to the profile photos"). Was
          // `pages[_tab]` — a single child that swaps WIDGET TYPE every
          // time `_tab` changes (BrowseScreen ↔ ConnectionsScreen ↔
          // SeekerMentorTab ↔ ProfileScreen all sit at the same Stack
          // position), so Flutter fully disposed and recreated whatever
          // screen you left, every single tab switch. Returning to
          // Browse therefore re-ran its initState() from scratch each
          // time — re-triggering the fresh-fetch flash fixed in
          // browse_screen.dart this same pass, repeatedly, and also
          // silently losing your place in the swipe deck (_index reset
          // to 0) on every trip back. IndexedStack keeps all 5 tabs
          // mounted with their State preserved and just toggles which
          // one paints, so BrowseScreen's fetch now genuinely only runs
          // once, and switching tabs and back leaves you exactly where
          // you were.
          // The bounded onboarding rehearsal lands on My SELAH before a real
          // account exists. Mount only its active tab: otherwise IndexedStack
          // eagerly starts Browse and the other account readers behind it,
          // even though the network-deny latch rejects their requests.
          // Ordinary member navigation keeps the persistent five-tab stack.
          SelahMenuCanvas(
            enabled: !_actionMode && !_chromeHidden,
            child: IndexedStack(
              index: _tab,
              children: widget.deferredOnboardingDevPreview
                  ? [
                      for (var index = 0; index < pages.length; index++)
                        index == _tab ? pages[index] : const SizedBox.shrink(),
                    ]
                  : pages,
            ),
          ),
          // 2026-07-26 (Founder review of the Browse page): the Dev
          // Access wrench that used to sit here is gone — it was
          // redundant with DevNavOverlay's Home button (Back also
          // removed from that overlay this same pass, per "I don't use
          // it, for dev let's just keep the home button"). Home resets
          // to WelcomeScreen, which already has its own Dev Access entry
          // point (welcome_screen.dart) — so nothing is actually lost,
          // just one fewer redundant shortcut in release-adjacent chrome.
          // CHANGED 2026-07-26 (Founder: "move the bell icon to right
          // underneath the 3 dots... meaning u might have to move the
          // home button on left"). Bell no longer sits top-left — it
          // sits top-right. DevNavOverlay's Home button moved to the
          // left this same pass to stay clear of it (dev_nav_overlay.dart).
          //
          // CHANGED 2026-07-27 (Founder: "im thinking of removing the 3
          // [dot] button" — chose "remove icon, centre placecard" when
          // asked to decide between that and a bottom-sheet variant,
          // over keeping the icon as a discoverable fallback). The "..."
          // (more_horiz) icon that used to sit above the Bell here is
          // gone — the Help/Report card it opened is now reached via a
          // long-press held in the centre of the Browse photo instead
          // (see browse_screen.dart _onCentreLongPress). This Column
          // collapsed to a single item now that there's only the Bell —
          // simplified to Align directly rather than leaving a
          // now-pointless Column wrapper around one child.
          // 2026-08-01: hidden while Browse is showing a full-screen
          // takeover (the sponsored card). The Bell and the nav bar below
          // are siblings of the tab content in this Stack, so they render
          // ON TOP of it — the sponsored card's own Skip button sat
          // underneath the Bell and could not be tapped.
          // THE BELL OVERLAY IS GONE — 2026-08-13 (inherited decision 149): its
          // destination now lives inside Dashboard, and its badge lives there,
          // and the top-right corner belongs to each page again. The
          // long history of this corner (bell top-left -> top-right,
          // the retired ⋯) stays in git.
          // 2026-07-26 (Founder: "connections icon is not a hear[t]... use
          // these icons I have from Lovable" — reference image showed a
          // magnifying glass, then a pill of bookmark / shield-check /
          // person icons). Mapped 1:1 onto the four existing tabs — the
          // Founder's instruction was explicitly to copy the icon glyphs
          // only, not the reference image's circle+pill layout, which
          // stays exactly as it was. Heart (favorite_border) is gone
          // entirely; Connections is a bookmark now, matching the "Save"
          // terminology already used elsewhere in this app (inherited decision 099).
          // Mid action-mode: one full-screen catcher UNDER the action
          // bar — "user clicks anywhere and the nav bar returns". It
          // deliberately swallows that tap (dismissing is the tap's
          // whole meaning; letting it also page a photo would make one
          // gesture do two things).
          if (_actionMode)
            Positioned.fill(
              child: SelahBrowseActionModeDismissLayer(
                onDismiss: _closeCardActions,
              ),
            ),
          // ONE BAR — 2026-08-13 (inherited decision 159). Action mode swaps the
          // ITEMS; it does not build a second bar. Everything the
          // Founder kept pointing at — height, width, inset, spacing,
          // icon scale, the highlight, the way it grows under a
          // finger — is now identical because it is the same widget,
          // not because four decisions in a row got the numbers to
          // agree.
          if (!_chromeHidden)
            if (_hideConfirmationMode)
              FloatingNavConfirmationBar(
                onCancel: _closeCardActions,
                onConfirm: _confirmHide,
              )
            else
              SelahShellNavigation(
                forceCurrent: _actionMode,
                currentIndex: _actionMode ? _actionIndex : _tab,
                onTap: _actionMode ? _runAction : _goToTab,
                // ACTIONS WAIT FOR THE FINGER TO LIFT — inherited decision 161. Tabs
                // keep firing live as you scrub, which is what makes the
                // nav bar feel scrubable; running Report or Hide as a
                // finger passes over them is a different thing entirely.
                commitOnRelease: _actionMode,
                // My SELAH carries the unread badge because it is the
                // notification centre.
                items: _actionMode
                    ? [
                        for (final o in _actionOptions)
                          FloatingNavItem(icon: o.icon, label: o.label),
                      ]
                    : [
                        FloatingNavItem(icon: Icons.search, label: 'Browse'),
                        FloatingNavItem(
                          icon: Icons.bookmark_border,
                          label: 'Connections',
                          dot: _sectionDots.contains(
                            SelahNavSection.connections,
                          ),
                        ),
                        FloatingNavItem(
                          icon: Icons.dashboard_outlined,
                          label: 'My Selah',
                          badge: _unread,
                        ),
                        // 2026-07-26: swapped from verified_user_outlined —
                        // Founder reported the active highlight badge looks
                        // vertically unbalanced specifically on this tab. The
                        // plainer gpp_good shield sits symmetrically in its box.
                        FloatingNavItem(
                          icon: Icons.gpp_good_outlined,
                          label: 'Shepherd',
                          dot: _sectionDots.contains(SelahNavSection.shepherd),
                        ),
                        FloatingNavItem(
                          icon: Icons.person_outline,
                          label: 'Profile',
                        ),
                      ],
              ),
          if (!_chromeHidden)
            SelahBottomPromotion(
              role: SelahPromotionRole.seeker,
              placement: _tab == 4
                  ? SelahPromotionPlacement.profile
                  : SelahPromotionPlacement.home,
              isCalmLanding:
                  !_actionMode && (ModalRoute.of(context)?.isCurrent ?? true),
              isEntitled: AppState.instance.plan == SelahPlan.one,
              // The invitation opens governed plan information only; it never
              // auto-opens checkout. Actual payment availability is explained
              // on that user-initiated surface.
              upgradeOfferAvailable: true,
              onOpenPlan: (_) => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const UpgradeScreen())),
            ),
          // Developer controls are app-wide in MaterialApp.builder. This
          // shell only registers the real tab callback with that overlay,
          // which keeps the rail visible when a Settings/Journey route is
          // pushed above this shell.
        ],
      ),
    );
  }
}

/// The full-screen dismissal target shown while Browse's action rail is open.
///
/// This sits above the Browse card, including above the visible three-dot
/// glyph. A second press on that glyph therefore lands here rather than on
/// [SelahBrowseMoreActionsButton]. Keep the same selection haptic on this
/// close transition so opening and closing the rail both acknowledge the
/// member's press instead of producing the former every-other-tap pattern.
@visibleForTesting
class SelahBrowseActionModeDismissLayer extends StatelessWidget {
  final VoidCallback onDismiss;

  const SelahBrowseActionModeDismissLayer({super.key, required this.onDismiss});

  @override
  Widget build(BuildContext context) => GestureDetector(
    key: const ValueKey('browse-action-mode-dismiss-layer'),
    behavior: HitTestBehavior.opaque,
    onTap: () {
      unawaited(SelahInteractionStyle.emitSelectionHaptic());
      onDismiss();
    },
  );
}

/// What an action-bar option DOES, independent of where it sits.
///
/// The order below is display order (Founder, 2026-08-13): most
/// relevant profile action first, then privacy, support, and
/// safety/reporting. Each item carries its act, so reordering the list
/// cannot rewire the buttons.
enum _CardAct { compatibility, findByCode, hide, help, report }

/// _ActionModeBar DELETED 2026-08-13 (inherited decision 159).
///
/// It was a hand-built replica of FloatingNavBar: same metrics, same
/// highlight widget, same gesture wiring, same glass — reached across
/// four decisions (153, 155, 156, 158), each closing another visible
/// gap between the copy and the original. The Founder's side-by-side
/// screenshots closed the argument: a replica converges on the thing it
/// copies and never arrives, because every future change to the real
/// bar has to be noticed and mirrored by hand.
///
/// Browse's ⋯ now swaps the ITEMS in the real FloatingNavBar. There is
/// one bar. Its contents change. Nothing can drift because there is
/// nothing to keep in step — which is what "the same navigation
/// component changing state, not a separate design" actually requires.
