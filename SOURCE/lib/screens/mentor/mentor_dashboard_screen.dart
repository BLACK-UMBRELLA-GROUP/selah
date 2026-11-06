// Shepherd Dashboard — one person-first family-support home.
//
// Each linked Seeker owns one swipeable page. Their authorised current state,
// updates and Shepherd-safe Insights live together beneath their name rather
// than being split into abstract Now / Insights destinations.
//
// 2026-08-13, inherited decision 152: the Shepherd dev panel composes wards,
// journeys and the staged review only for a protected developer-capable
// session — real rows first, stand-ins topping up, 0 meaning zero. The
// production target calls none of it, including in release mode.
// 2026-08-14 (inherited decision 166): loading is checked before empty.
// 2026-08-15: the journeys fetch distinguishes FAILURE from empty
// (inherited decision 167's rule) — a failed load shows an error with Try again,
// never an empty state with an invite button.
//
// An Additional Shepherd contributes to the linked-Seeker count but never to
// Journey-derived copy or aggregates. Main authority is partitioned before
// any Journey field is read, matching inherited decision 225.
//
// Rosters, invitations and per-person Journey context are owned by their
// dedicated pages. This Dashboard only summarises and routes.

import 'package:flutter/material.dart';
import '../../data/selah_membership_catalog.dart';
import '../../dev/selah_app_gold_preview.dart';
import 'package:flutter/foundation.dart';
import '../../dev/selah_dev_scenario.dart';
import '../../models/selah_dashboard_lab.dart';
import '../../models/selah_dashboard_resolution.dart';
import '../../models/seeker_profile.dart';
import '../../services/selah_discovery_service.dart';
import '../../services/selah_shepherd_dashboard_resolver.dart';
import '../../services/selah_dashboard_updates_service.dart';
import '../../services/selah_journey_service.dart';
import '../../services/selah_notification_service.dart';
import '../../services/selah_product_telemetry.dart';
import '../../services/selah_mentor_journey_service.dart';
import '../../services/selah_mentor_link_service.dart';
import '../../services/selah_developer_access.dart';
import '../../services/selah_account_state.dart';
import '../../state/app_state.dart';
import '../../theme/selah_colors.dart';
import '../../theme/selah_text.dart';
import '../../widgets/selah_state_widgets.dart';
import '../../widgets/floating_nav_bar.dart';
import '../../widgets/selah_fade_edges.dart';
import '../../widgets/selah_segmented_toggle.dart';
import '../../widgets/selah_scrollable_seeker_selector.dart';
import 'mentor_journey_detail_screen.dart';
import '../../widgets/selah_loading.dart';
import '../subscription/upgrade_screen.dart';
import '../profile/seeker_profile_screen.dart';

class MentorDashboardScreen extends StatefulWidget {
  /// A protected zero-linked, no-network result after local onboarding.
  final bool initialOnboardingPreview;
  final bool hasShepherdPlus;
  final int notificationCount;
  final VoidCallback? onOpenNetwork;
  final VoidCallback? onOpenSeekers;
  final ValueChanged<String>? onOpenSeeker;
  final Future<List<SeekerProfile>> Function(List<String> ids)? loadProfiles;
  final VoidCallback? onNotificationsChanged;
  final Future<List<MentorJourneyView>?> Function()? loadJourneys;
  final Future<SelahDashboardUpdatesPage?> Function()? loadUpdates;
  final Future<SelahSourceResult<Set<String>>> Function(List<String> matchIds)?
  loadOpenReviews;
  final DateTime? comparisonNow;

  const MentorDashboardScreen({
    super.key,
    this.initialOnboardingPreview = false,
    this.hasShepherdPlus = false,
    this.notificationCount = 0,
    this.onOpenNetwork,
    this.onOpenSeekers,
    this.onOpenSeeker,
    this.loadProfiles,
    this.onNotificationsChanged,
    this.loadJourneys,
    this.loadUpdates,
    this.loadOpenReviews,
    this.comparisonNow,
  });

  @override
  State<MentorDashboardScreen> createState() => _MentorDashboardScreenState();
}

class _MentorDashboardScreenState extends State<MentorDashboardScreen> {
  static const _dashboardResolver = SelahShepherdDashboardResolver();

  bool _loading = true;
  late PageController _pager;
  int _pagerOrigin = 0;
  List<String> _pagerPeople = const [];
  double _pagerPosition = 0;
  int _selectorInteractionRevision = 0;

  /// True when the LAST journeys fetch failed (null from the service).
  /// Rows already on screen stay (stale beats blank); with nothing to
  /// show, the error state owns the body. inherited decision 167's pattern.
  bool _loadFailed = false;
  bool _hasJourneyTruth = false;
  bool _reviewLoadFailed = false;
  bool _hasReviewTruth = false;
  bool _reviewsLoading = true;
  List<MentorJourneyView> _journeys = [];
  Map<String, SeekerProfile> _profiles = const {};
  List<String> _profileRosterIds = const [];
  int _profileGeneration = 0;
  int _loadRevision = 0;
  late final String? _ownerUserId;
  late final int _ownerGeneration;
  // Retained preparation for source-only profile routing; Dashboard no longer renders the snapshot.
  // ignore: unused_field
  bool _profilesLoading = true;

  bool get _currentAccount =>
      SelahAccountState.userId == _ownerUserId &&
      SelahAccountState.generation == _ownerGeneration;

  /// Updates has its own query truth. It must not inherit Today's empty or
  /// failure state, and Timeline failures must never become "all caught up".
  bool _updatesLoading = true;
  bool _updatesFailed = false;

  /// Journeys with a Family Review open — the one thing on this screen
  /// that is waiting on THE SHEPHERD. One batched query; Main-only under
  /// RLS, exactly like the detail screen.
  Set<String> _openReviews = const {};

  /// The one RPC-backed Updates page. A failed refresh retains these rows and
  /// marks them visibly last-known; only a successful empty response clears.
  List<SelahDashboardUpdate> _updates = const [];

  @override
  void initState() {
    super.initState();
    _ownerUserId = SelahAccountState.userId;
    _ownerGeneration = SelahAccountState.generation;
    if (widget.initialOnboardingPreview) {
      _loading = false;
      _hasJourneyTruth = true;
      _reviewsLoading = false;
      _hasReviewTruth = true;
      _updatesLoading = false;
      _profilesLoading = false;
    }
    _configurePager(_wards, selectedIndex: 0);
    AppState.instance.addListener(_onChange);
    if (SelahDeveloperAccess.canUseDeveloperTools) {
      SelahDevScenario.instance.addListener(_onChange);
    }
    if (!widget.initialOnboardingPreview) {
      _load();
      _loadProfiles();
    }
  }

  void _onPagerScroll() {
    if (!_pager.hasClients || _pagerPeople.isEmpty) return;
    final rawPage = (_pager.page ?? _pagerOrigin.toDouble()) - _pagerOrigin;
    final nearest = rawPage.roundToDouble();
    final page = (rawPage - nearest).abs() < .001 ? nearest : rawPage;
    if ((page - _pagerPosition).abs() < .000001 || !mounted) return;
    setState(() => _pagerPosition = page);
  }

  void _configurePager(
    List<MentorLinkedPerson> people, {
    required int selectedIndex,
  }) {
    _pagerPeople = [for (final person in people) person.id];
    // The origin is a whole number of laps, so logical page0 is person0.
    // Recentring at idle keeps repeated laps away from PageView's lower bound.
    _pagerOrigin = people.length > 3 ? people.length * 100000 : 0;
    _pagerPosition = selectedIndex.toDouble();
    _pager = PageController(
      initialPage: _pagerOrigin + selectedIndex,
      keepPage: false,
    )..addListener(_onPagerScroll);
  }

  void _recenterCarousel() {
    final count = _pagerPeople.length;
    if (count <= 3 || _pagerPosition.abs() < count * 100) return;
    final controller = _pager;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          controller != _pager ||
          !controller.hasClients ||
          controller.position.isScrollingNotifier.value) {
        return;
      }
      final index = _pagerPosition.round() % count;
      // A whole-lap shift leaves the same three names and person visible.
      setState(() => _selectorInteractionRevision++);
      controller.jumpToPage(_pagerOrigin + index);
    });
  }

  /// The authority context behind this compact summary — panel-composed in
  /// protected Test sessions and untouched for normal members. The Dashboard does not
  /// render these rows as a roster.
  List<MentorLinkedPerson> get _wards {
    if (widget.initialOnboardingPreview) return const [];
    final real = AppState.instance.mentorRealLinkedSeekers;
    if (!SelahDeveloperAccess.canUseDeveloperTools) return real;
    return SelahDevScenario.composeMentorWards(real: real);
  }

  /// The Journeys this screen draws.
  List<MentorJourneyView> get _visibleJourneys {
    if (widget.initialOnboardingPreview) return const [];
    if (!SelahDeveloperAccess.canUseDeveloperTools) return _journeys;
    return SelahDevScenario.composeMentorJourneys(
      wards: _wards,
      real: _journeys,
    );
  }

  Future<void> _loadProfiles({bool force = false}) async {
    if (widget.initialOnboardingPreview || !_currentAccount) return;
    final ids = [
      for (final person in _wards)
        if (widget.loadProfiles != null || !person.id.startsWith('dev-ws'))
          person.id,
    ];
    if (!force &&
        _profileGeneration > 0 &&
        listEquals(ids, _profileRosterIds)) {
      return;
    }
    _profileRosterIds = ids;
    final generation = ++_profileGeneration;
    setState(() {
      _profiles = const {};
      _profilesLoading = ids.isNotEmpty;
    });
    List<SeekerProfile> profiles;
    try {
      profiles = widget.loadProfiles != null
          ? await widget.loadProfiles!(ids)
          : await SelahDiscoveryService.profilesByIds(
              ids,
              includeWithoutPhotos: true,
            );
    } catch (_) {
      profiles = const [];
    }
    if (!mounted || generation != _profileGeneration || !_currentAccount) {
      return;
    }
    final linkedIds = {for (final person in _wards) person.id};
    setState(() {
      _profiles = {
        for (final profile in profiles)
          if (ids.contains(profile.id) && linkedIds.contains(profile.id))
            profile.id: profile,
      };
      _profilesLoading = false;
    });
  }

  SeekerProfile? _profileFor(MentorLinkedPerson person) {
    final confirmed = _profiles[person.id];
    if (confirmed != null) return confirmed;
    if (widget.loadProfiles != null ||
        !SelahDeveloperAccess.canUseDeveloperTools ||
        !person.id.startsWith('dev-ws')) {
      return null;
    }
    // Protected local stand-ins only. Never borrow Journey-partner details or
    // turn absent real member data into a demo profile.
    final index = int.tryParse(person.id.substring('dev-ws'.length)) ?? 0;
    final fixture = mockProfiles[index % mockProfiles.length];
    return SeekerProfile(
      id: person.id,
      firstName: person.firstName,
      age: fixture.age,
      city: fixture.city,
      photos: fixture.photos,
      gender: fixture.gender,
    );
  }

  // Profile inspection remains owned by Seekers; keep this legacy adapter source-only.
  // ignore: unused_element
  void _openProfile(MentorLinkedPerson person) {
    // Re-check current roster/model at tap time, after carousel or roster moves.
    if (!_wards.any((linked) => linked.id == person.id)) return;
    final profile = _profileFor(person);
    if (profile == null) return;
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => SeekerProfileScreen(
          profile: profile,
          swipeDownToDismiss: true,
          showCloseButtonWhenSwipeDismiss: true,
          emptyPhoto: profile.photos.isEmpty
              ? DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: SelahColors.brandGradient,
                  ),
                  child: Center(
                    child: Icon(
                      Icons.person_outline,
                      size: 104,
                      color: Colors.white.withValues(alpha: .16),
                    ),
                  ),
                )
              : null,
        ),
      ),
    );
  }

  Future<void> _load() async {
    if (widget.initialOnboardingPreview || !_currentAccount) return;
    final revision = ++_loadRevision;
    final reads = await Future.wait<Object?>([
      (widget.loadJourneys ?? SelahMentorJourneyService.fetchLinkedJourneys)(),
      (widget.loadUpdates ?? SelahDashboardUpdatesService.fetchPage)(),
    ]);
    final journeys = reads[0] as List<MentorJourneyView>?;
    final updates = reads[1] as SelahDashboardUpdatesPage?;
    if (!mounted || revision != _loadRevision || !_currentAccount) return;
    setState(() {
      if (journeys == null) {
        _loadFailed = true; // keep whatever we already had
        _reviewsLoading = false;
      } else {
        _loadFailed = false;
        _hasJourneyTruth = true;
        _journeys = journeys;
      }
      if (updates == null) {
        _updatesFailed = true;
      } else {
        _updatesFailed = false;
        _updates = updates.rows;
      }
      _updatesLoading = false;
      _loading = false;
    });
    if (journeys == null) return;

    // Second pass, deliberately not awaited before the list renders —
    // each of these makes the dashboard MORE specific, none is needed
    // for it to be correct.
    final mainSeekerIds = {
      for (final person in _wards)
        if (person.isMain) person.id,
    };
    final live = journeys
        .where(
          (j) =>
              mainSeekerIds.contains(j.linkedSeekerId) &&
              j.status != 'ended' &&
              !j.isJourneyLocked,
        )
        .map((j) => j.matchId)
        .toList();
    final openResult =
        await (widget.loadOpenReviews ??
            SelahJourneyService.fetchOpenReviewMatchIdsResult)(live);
    if (!mounted || revision != _loadRevision || !_currentAccount) return;
    setState(() {
      _reviewsLoading = false;
      if (openResult.isAvailable) {
        _reviewLoadFailed = false;
        _hasReviewTruth = true;
        _openReviews = openResult.valueOrNull ?? const <String>{};
      } else {
        _reviewLoadFailed = true;
      }
    });
  }

  Future<void> _retry() async {
    if (widget.initialOnboardingPreview || !_currentAccount) return;
    _loadProfiles(force: true);
    setState(() {
      _loading = true;
      _updatesLoading = true;
      _reviewsLoading = true;
    });
    await _load();
  }

  Future<void> _markAllNotificationsRead() async {
    if (widget.initialOnboardingPreview || !_currentAccount) return;
    await SelahNotificationService.markAllRead();
    if (!_currentAccount) return;
    await _load();
    widget.onNotificationsChanged?.call();
  }

  @override
  void dispose() {
    ++_loadRevision;
    ++_profileGeneration;
    AppState.instance.removeListener(_onChange);
    // UNGATED removes — inherited upstream action 250 (2026-08-23). The adds are gated,
    // and a gate that reads auth state can FLAP between initState and
    // dispose (the dev account switcher changes who is signed in), which
    // leaks the listener; the next notify then calls setState on a
    // defunct State and crashes. removeListener on a never-registered
    // listener is a documented no-op, so removing without gates is safe
    // in every build.
    SelahDevScenario.instance.removeListener(_onChange);
    _pager.removeListener(_onPagerScroll);
    _pager.dispose();
    super.dispose();
  }

  // Mounted-guarded — inherited upstream action 250: a notify arriving during teardown
  // must never reach setState on a defunct State.
  void _onChange() {
    if (!mounted || !_currentAccount) return;
    if (!widget.initialOnboardingPreview) _loadProfiles();
    final people = _wards;
    final ids = [for (final person in people) person.id];
    if (listEquals(ids, _pagerPeople)) {
      setState(() {});
      return;
    }
    final oldIndex = _pagerPeople.isEmpty
        ? 0
        : _pagerPosition.round() % _pagerPeople.length;
    final oldId = _pagerPeople.isEmpty ? null : _pagerPeople[oldIndex];
    final retained = oldId == null ? -1 : ids.indexOf(oldId);
    final selected = people.isEmpty
        ? 0
        : retained >= 0
        ? retained
        : oldIndex.clamp(0, people.length - 1);
    final retired = _pager..removeListener(_onPagerScroll);
    setState(() {
      _selectorInteractionRevision++;
      _configurePager(people, selectedIndex: selected);
    });
    // The rebuilt PageView detaches before its retired controller is disposed.
    WidgetsBinding.instance.addPostFrameCallback((_) => retired.dispose());
  }

  bool get _dashboardLabActive =>
      !widget.initialOnboardingPreview &&
      SelahDeveloperAccess.canUseDeveloperTools &&
      SelahDevScenario.instance.dashboardLabEnabled;

  /// Real open reviews plus the panel's staged one in debug/profile.
  Set<String> _reviewIds(List<MentorJourneyView> journeys) {
    if (widget.initialOnboardingPreview) return const {};
    if (!SelahDeveloperAccess.canUseDeveloperTools) return _openReviews;
    return {..._openReviews, ...SelahDevScenario.mentorOpenReviewIds(journeys)};
  }

  String _ago(DateTime at) {
    final d = (widget.comparisonNow ?? DateTime.now()).difference(at);
    if (d.inMinutes < 60) return 'just now';
    if (d.inHours < 24) return '${d.inHours}h ago';
    if (d.inDays < 7) return '${d.inDays}d ago';
    if (d.inDays < 30) return '${(d.inDays / 7).floor()}w ago';
    return '${(d.inDays / 30).floor()}mo ago';
  }

  void _openJourney(MentorJourneyView j) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MentorJourneyDetailScreen(
          journey: j,
          hasShepherdOne: widget.hasShepherdPlus,
        ),
      ),
    );
  }

  /// Everything waiting on the Shepherd, as cards: open Family Reviews
  /// first (a decision), then Journeys parked at the Shepherd Gate (a
  /// step only a Shepherd can complete).
  List<Widget> _attentionCards(List<ShepherdDashboardAttention> items) => [
    for (final item in items)
      _AttentionCard(
        title: item.title,
        body: item.detail,
        cta: item.actionLabel,
        onTap: () => _openJourney(item.journey),
      ),
  ];

  @override
  Widget build(BuildContext context) {
    // Composed ONCE per build — these walk the ward list, and calling
    // them per row would recompose for every card drawn.
    final rawLinked = _wards;
    final journeys = _visibleJourneys;
    final reviewIds = _reviewIds(journeys);
    final dev = SelahDeveloperAccess.canUseDeveloperTools
        ? SelahDevScenario.instance
        : null;
    final firstName =
        AppState.instance.mentorName?.trim() ?? AppState.instance.name?.trim();

    final greeting = firstName == null || firstName.isEmpty
        ? 'Your Selah, in one place.'
        : 'Hello, $firstName.';
    return Container(
      decoration: SelahAppGoldDecoration(
        gradient: SelahColors.genderGradient(AppState.instance.gender),
      ),
      child: Material(
        color: Colors.transparent,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Shepherd Dashboard',
                      style: SelahText.heading(size: 26),
                    ),
                    const SizedBox(height: 4),
                    Text(greeting, style: SelahText.subtext(size: 13.5)),
                  ],
                ),
              ),
              if (rawLinked.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                  child: _seekerNavigation(rawLinked),
                ),
              Expanded(
                child: rawLinked.isEmpty
                    ? _shepherdPage(
                        pageKey: 'empty',
                        children: _shepherdCombinedChildren(
                          person: null,
                          resolution: _dashboardResolver.resolve(
                            linkedPeople: const [],
                            journeys: journeys,
                            openReviewIds: reviewIds,
                          ),
                          attention: const [],
                          dev: dev,
                        ),
                      )
                    : NotificationListener<ScrollNotification>(
                        onNotification: (notification) {
                          if (notification is ScrollStartNotification &&
                              notification.depth == 0 &&
                              notification.dragDetails != null) {
                            setState(() => _selectorInteractionRevision++);
                          }
                          if (notification is ScrollEndNotification &&
                              notification.depth == 0) {
                            _recenterCarousel();
                          }
                          return false;
                        },
                        child: KeyedSubtree(
                          // A new roster/controller needs a fresh Scrollable;
                          // otherwise Flutter absorbs the retired pixel offset.
                          key: ObjectKey(_pager),
                          child: PageView.custom(
                            key: const ValueKey('shepherd-dashboard-pages'),
                            controller: _pager,
                            physics: SelahSegmentedMotion.pagePhysics,
                            childrenDelegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final personIndex = index % rawLinked.length;
                                final person = rawLinked[personIndex];
                                final personJourneys = [
                                  for (final journey in journeys)
                                    if (journey.linkedSeekerId == person.id)
                                      journey,
                                ];
                                final resolution = _dashboardResolver.resolve(
                                  linkedPeople: [person],
                                  journeys: personJourneys,
                                  openReviewIds: reviewIds,
                                );
                                final page = _shepherdPage(
                                  pageKey: person.id,
                                  children: _shepherdCombinedChildren(
                                    person: person,
                                    resolution: resolution,
                                    attention: _attentionCards(
                                      resolution.attention,
                                    ),
                                    dev: dev,
                                  ),
                                );
                                return Semantics(
                                  label:
                                      '${person.firstName}, Seeker ${personIndex + 1} of ${rawLinked.length}',
                                  child: page,
                                );
                              },
                              childCount: rawLinked.length > 3
                                  ? null
                                  : rawLinked.length,
                              // Virtual lap indexes are never accessibility ordinals.
                              addSemanticIndexes: false,
                            ),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _seekerNavigation(List<MentorLinkedPerson> people) =>
      SelahScrollableSeekerSelector(
        key: const ValueKey('shepherd-dashboard-seeker-selector'),
        labels: [for (final person in people) person.firstName],
        segmentKeys: [
          for (final person in people)
            ValueKey('shepherd-dashboard-seeker-${person.id}'),
        ],
        position: _pagerPosition,
        interactionRevision: _selectorInteractionRevision,
        onChanged: (index) {
          if (!_pager.hasClients) return;
          if (MediaQuery.disableAnimationsOf(context)) {
            _pager.jumpToPage(_pagerOrigin + index);
          } else {
            SelahSegmentedMotion.animateToPage(_pager, _pagerOrigin + index);
          }
        },
      );

  Widget _shepherdPage({
    required String pageKey,
    required List<Widget> children,
  }) => SelahFadeEdges.bottomOnly(
    key: ValueKey('shepherd-dashboard-fade-$pageKey'),
    bottom:
        SelahNavBarMetrics.restingHeight + SelahNavBarMetrics.bottomInset + 10,
    child: RefreshIndicator(
      color: SelahColors.accentOnCanvas,
      backgroundColor: SelahColors.surfaceFill,
      onRefresh: () async => _retry(),
      child: ListView(
        key: PageStorageKey('shepherd-dashboard-$pageKey'),
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 108),
        children: children,
      ),
    ),
  );

  List<Widget> _shepherdCombinedChildren({
    required MentorLinkedPerson? person,
    required ShepherdDashboardResolution resolution,
    required List<Widget> attention,
    required SelahDevScenario? dev,
  }) {
    final showNow =
        widget.initialOnboardingPreview ||
        !SelahDeveloperAccess.canUseDeveloperTools ||
        dev?.dashboardShepherdOptionSelected(SelahDashboardTab.now) == true ||
        dev?.dashboardShepherdOptionSelected(SelahDashboardTab.insights) ==
            true;
    if (!showNow) return const [];
    if (showNow &&
        _dashboardLabActive &&
        dev?.dashboardShepherdTodayState ==
            SelahShepherdDashboardTodayState.loading) {
      return [const SizedBox(height: 210, child: SelahLoading())];
    }
    if (showNow &&
        _dashboardLabActive &&
        dev?.dashboardShepherdTodayState ==
            SelahShepherdDashboardTodayState.fullFailure) {
      return [
        SizedBox(
          height: 300,
          child: SelahEmptyState(
            icon: Icons.cloud_off_outlined,
            title: "Couldn't load your dashboard",
            message: 'Check your connection.',
            ctaLabel: 'Try again',
            onCta: _retry,
          ),
        ),
      ];
    }
    if (showNow && (_loading || (_reviewsLoading && !_hasReviewTruth))) {
      return [const SizedBox(height: 210, child: SelahLoading())];
    }
    return [
      if (showNow) ...[
        ..._shepherdToday(resolution, attention, dev, person),
        const SizedBox(height: 22),
        ..._shepherdUpdates(dev, person),
      ],
    ];
  }

  List<Widget> _shepherdToday(
    ShepherdDashboardResolution resolution,
    List<Widget> attention,
    SelahDevScenario? dev,
    MentorLinkedPerson? person,
  ) {
    final truthFailed = _loadFailed || _reviewLoadFailed;
    final hasCompleteTruth = _hasJourneyTruth && _hasReviewTruth;
    if (resolution.linkedSeekerCount == 0) {
      return [
        if (truthFailed && hasCompleteTruth)
          _ErrorBanner(
            onRetry: _retry,
            message:
                "Couldn't refresh Shepherd priorities — showing last-known Dashboard state.",
          ),
        ..._emptyShepherdToday(resolution),
      ];
    }
    if (truthFailed && !hasCompleteTruth) {
      return [
        _ErrorBanner(
          onRetry: _retry,
          message: "Couldn't refresh Shepherd priorities.",
        ),
        _shepherdSection(
          key: const ValueKey('shepherd-dashboard-right-now'),
          label: 'NEEDS YOU',
          children: const [
            _ShepherdStatusCard(
              key: ValueKey('shepherd-dashboard-journey-unavailable'),
              icon: Icons.cloud_off_outlined,
              eyebrow: 'PRIORITIES UNAVAILABLE',
              title: 'Your Shepherd priorities could not be refreshed',
              detail: 'Try again before relying on this summary.',
            ),
          ],
        ),
      ];
    }
    return [
      if (truthFailed)
        _ErrorBanner(
          onRetry: _retry,
          message:
              "Couldn't refresh Shepherd priorities — showing last-known Dashboard state.",
        )
      else if (_dashboardLabActive &&
          dev?.dashboardShepherdTodayState ==
              SelahShepherdDashboardTodayState.partialFailure)
        _ErrorBanner(onRetry: _retry),
      _shepherdSection(
        key: const ValueKey('shepherd-dashboard-right-now'),
        label: 'NEEDS YOU',
        children: attention.isEmpty
            ? const [
                _ShepherdStatusCard(
                  icon: Icons.check_circle_outline_rounded,
                  eyebrow: 'ALL SETTLED',
                  title: 'Nothing needs you right now.',
                  detail: 'Your current Shepherd responsibilities are clear.',
                ),
              ]
            : [attention.first],
      ),
    ];
  }

  List<Widget> _emptyShepherdToday(ShepherdDashboardResolution resolution) => [
    _shepherdSection(
      key: const ValueKey('shepherd-dashboard-right-now'),
      label: 'NEEDS YOU',
      children: const [
        _ShepherdStatusCard(
          icon: Icons.check_circle_outline_rounded,
          eyebrow: 'ALL SETTLED',
          title: 'Nothing needs you right now.',
          detail: 'There are no linked Seeker responsibilities to review.',
        ),
      ],
    ),
  ];

  List<Widget> _shepherdUpdates(
    SelahDevScenario? dev,
    MentorLinkedPerson? person,
  ) {
    final previewRows = _dashboardLabActive
        ? _shepherdDevUpdateRows(dev!.dashboardUpdatesState, person?.firstName)
        : null;
    final visibleUpdates = person == null
        ? _updates
        : _updates.where((update) {
            if (update.relatedMatchId == null) return true;
            return _journeys.any(
              (journey) =>
                  journey.matchId == update.relatedMatchId &&
                  journey.linkedSeekerId == person.id,
            );
          });
    final rows =
        previewRows ??
        [for (final update in visibleUpdates) _updateRow(update)];
    final loading = !_dashboardLabActive && _updatesLoading;
    final failed = !_dashboardLabActive && _updatesFailed;
    return [
      if ((failed && rows.isNotEmpty) ||
          (_dashboardLabActive &&
              dev?.dashboardShepherdTodayState ==
                  SelahShepherdDashboardTodayState.partialFailure))
        _ErrorBanner(onRetry: _retry, lastKnown: rows.isNotEmpty),
      _shepherdSection(
        key: const ValueKey('shepherd-dashboard-updates'),
        label: 'UPDATES',
        action:
            !_dashboardLabActive &&
                widget.notificationCount > 0 &&
                widget.onNotificationsChanged != null
            ? TextButton(
                key: const ValueKey('shepherd-dashboard-mark-all-read'),
                onPressed: _markAllNotificationsRead,
                child: const Text('Mark all read'),
              )
            : null,
        children: loading && rows.isEmpty
            ? const [
                _ShepherdStatusCard(
                  key: ValueKey('shepherd-updates-loading'),
                  icon: Icons.sync_rounded,
                  eyebrow: 'UPDATES',
                  title: 'Checking for Shepherd updates',
                ),
              ]
            : failed && rows.isEmpty
            ? [
                _ShepherdStatusCard(
                  key: const ValueKey('shepherd-updates-unavailable'),
                  icon: Icons.sync_problem_outlined,
                  eyebrow: 'UPDATES UNAVAILABLE',
                  title: 'Shepherd updates could not be refreshed',
                  detail: 'Try again before relying on this list.',
                  actionLabel: 'Retry',
                  onTap: _retry,
                ),
              ]
            : rows.isEmpty
            ? const [
                _ShepherdStatusCard(
                  key: ValueKey('shepherd-updates-empty'),
                  icon: Icons.notifications_none_rounded,
                  eyebrow: 'ALL CAUGHT UP',
                  title: 'No Shepherd updates yet',
                  detail:
                      'Meaningful Journey and Family Review movement will appear here.',
                ),
              ]
            : rows,
      ),
    ];
  }

  List<Widget> _shepherdDevUpdateRows(
    SelahDashboardUpdatesState state,
    String? selectedName,
  ) {
    if (state == SelahDashboardUpdatesState.none ||
        state == SelahDashboardUpdatesState.allRead) {
      return const [];
    }
    final actionable = state == SelahDashboardUpdatesState.oneActionable;
    final count = switch (state) {
      SelahDashboardUpdatesState.several ||
      SelahDashboardUpdatesState.mixed => 3,
      _ => 1,
    };
    final person = selectedName?.trim().isNotEmpty == true
        ? selectedName!.trim()
        : 'Your Seeker';
    final entries = [
      (person, 'Journey moved forward', 'Today'),
      (person, 'Family Review completed', 'Yesterday'),
      (person, 'Shepherd step completed', '2d ago'),
    ];
    return [
      for (var index = 0; index < count; index++)
        _RecentRow(
          key: ValueKey('shepherd-dev-update-$index'),
          title: entries[index].$1,
          label: actionable && index == 0
              ? 'Family Review is ready'
              : entries[index].$2,
          when: entries[index].$3,
          // A synthetic update has no authorised Journey destination.
          // Keep it a fact, not a button that ripples without acting.
          onTap: null,
        ),
    ];
  }

  // Retained source-only insight rendering; LOCK20 removes its Dashboard entry.
  // ignore: unused_element
  List<Widget> _shepherdInsights(
    SelahDevScenario? dev,
    MentorLinkedPerson? person,
  ) {
    final insightOwner = person == null
        ? 'SHEPHERD INSIGHTS'
        : '${person.firstName.toUpperCase()} · INSIGHTS';
    final entitled = _dashboardLabActive
        ? dev?.dashboardShepherdPremium == true
        : widget.hasShepherdPlus;
    if (!entitled) {
      return [
        _ShepherdStatusCard(
          key: const ValueKey('shepherd-insights-locked'),
          icon: Icons.lock_rounded,
          eyebrow: insightOwner,
          title:
              'Shepherd Insights are part of ${SelahMembershipCatalog.shepherdOneTitle}',
          detail:
              'Upgrade to unlock deeper family-process and Shepherd-responsibility insights. Your existing responsibilities remain available.',
          actionLabel: 'View ${SelahMembershipCatalog.shepherdOneTitle}',
          actionKey: const ValueKey('shepherd-insights-upgrade'),
          premiumBoundary: true,
          onTap: () => Navigator.of(context).push<void>(
            MaterialPageRoute(
              builder: (_) => const UpgradeScreen(
                telemetrySurface: SelahTelemetrySurface.shepherd,
              ),
            ),
          ),
        ),
      ];
    }
    if (!_dashboardLabActive ||
        dev?.dashboardShepherdInsightsState ==
            SelahShepherdDashboardInsightsState.insufficient) {
      return [
        _ShepherdStatusCard(
          key: const ValueKey('shepherd-insights-empty'),
          icon: Icons.insights_outlined,
          eyebrow: insightOwner,
          title: 'No Shepherd insights available yet',
          detail:
              'Selah will only show a Shepherd insight when real, governed family-process evidence supports it.',
        ),
      ];
    }
    final (title, detail) = switch (dev!.dashboardShepherdInsightsState) {
      SelahShepherdDashboardInsightsState.familyProcess => (
        'A family handoff may need clearer timing',
        'A process insight about coordination only — never a private Seeker judgement.',
      ),
      SelahShepherdDashboardInsightsState.multiSeeker => (
        'One family responsibility may need attention sooner',
        'The overview prioritises permitted responsibilities across linked Seekers.',
      ),
      SelahShepherdDashboardInsightsState.journeyPreparation => (
        'A Journey is approaching a Shepherd step',
        'Preparing early can make the next family handoff feel calmer.',
      ),
      SelahShepherdDashboardInsightsState.shepherdNetwork => (
        'Your Shepherd Network has an open coordination step',
        'Open Network to review roles and current family connection status.',
      ),
      SelahShepherdDashboardInsightsState.premium => (
        'A deeper family-process view is ready',
        'This preview adds family-process context without exposing private Seeker behaviour.',
      ),
      SelahShepherdDashboardInsightsState.insufficient => throw StateError(''),
    };
    return [
      _ShepherdStatusCard(
        key: const ValueKey('shepherd-dev-insight'),
        icon: Icons.insights_outlined,
        eyebrow: 'DEV PREVIEW · $insightOwner',
        title: title,
        detail: detail,
      ),
    ];
  }

  Widget _shepherdSection({
    required Key key,
    required String label,
    required List<Widget> children,
    Widget? action,
  }) => Column(
    key: key,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(left: 2, bottom: 10),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: SelahText.chapterLabel(color: SelahColors.ink(0.54)),
              ),
            ),
            ?action,
          ],
        ),
      ),
      ...children,
    ],
  );

  // Retained source-only aggregate; no active Dashboard entry after LOCK20.
  // ignore: unused_element
  Widget _familySnapshot(
    ShepherdDashboardResolution resolution, {
    bool journeyStatusAvailable = true,
  }) {
    final linked = resolution.linkedSeekerCount;
    final needsYou = resolution.needsYouCount;
    final linkedLabel = '$linked linked ${linked == 1 ? 'Seeker' : 'Seekers'}';
    final needsLabel = !journeyStatusAvailable
        ? 'Journey status unavailable'
        : needsYou == 0
        ? 'Nothing needs you'
        : '$needsYou ${needsYou == 1 ? 'needs' : 'need'} you';
    return _shepherdSection(
      key: const ValueKey('shepherd-dashboard-family-orientation'),
      label: 'FAMILY SNAPSHOT',
      children: [
        _ShepherdStatusCard(
          key: const ValueKey('shepherd-dashboard-family-snapshot'),
          icon: Icons.people_outline_rounded,
          eyebrow: 'YOUR FAMILY',
          title: '$linkedLabel · $needsLabel',
          detail:
              'Open Seekers for relationships, roles and authorised context.',
          actionLabel: 'View Seekers',
          actionKey: const ValueKey('shepherd-dashboard-view-seekers'),
          onTap: widget.onOpenSeekers,
        ),
      ],
    );
  }

  Widget _updateRow(SelahDashboardUpdate update) {
    final mainSeekerIds = {
      for (final person in _wards)
        if (person.isMain) person.id,
    };
    MentorJourneyView? journey;
    for (final candidate in _journeys) {
      if (candidate.matchId == update.relatedMatchId &&
          mainSeekerIds.contains(candidate.linkedSeekerId)) {
        journey = candidate;
        break;
      }
    }
    final signal = update.toDashboardSignal(
      personContext: journey?.linkedSeekerName,
    );
    final VoidCallback? onTap = switch (signal.target) {
      SelahDashboardTarget.notifications => null,
      SelahDashboardTarget.connectionsJourneys when journey != null =>
        () => _openJourney(journey!),
      _ => null,
    };
    return _RecentRow(
      key: ValueKey('shepherd-update-${signal.id}'),
      title: signal.title,
      label: signal.detail ?? '',
      when: _ago(update.occurredAt),
      isUnread: signal.isUnread,
      onTap: onTap,
    );
  }
}

class _ShepherdStatusCard extends StatelessWidget {
  final IconData icon;
  final String eyebrow;
  final String title;
  final String? detail;
  final String? actionLabel;
  final Key? actionKey;
  final VoidCallback? onTap;
  final bool premiumBoundary;

  const _ShepherdStatusCard({
    super.key,
    required this.icon,
    required this.eyebrow,
    required this.title,
    this.detail,
    this.actionLabel,
    this.actionKey,
    this.onTap,
    this.premiumBoundary = false,
  });

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: SelahColors.surfaceFill,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: SelahColors.surfaceBorder, width: 0.5),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 21,
          color: premiumBoundary
              ? SelahColors.journeyGold
              : SelahColors.ink(0.72),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                eyebrow,
                style: SelahText.chapterLabel(color: SelahColors.ink(0.50)),
              ),
              const SizedBox(height: 4),
              Text(title, style: SelahText.body(size: 14.2)),
              if (detail?.trim().isNotEmpty == true) ...[
                const SizedBox(height: 4),
                Text(detail!, style: SelahText.subtext(size: 11.7)),
              ],
              if (actionLabel != null && onTap != null) ...[
                const SizedBox(height: 8),
                TextButton(
                  key:
                      actionKey ??
                      const ValueKey('shepherd-dashboard-status-action'),
                  onPressed: onTap,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    actionLabel!,
                    style: premiumBoundary
                        ? SelahText.button(
                            size: 13,
                            color: SelahColors.journeyGold,
                          )
                        : null,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

/// One thing waiting on the Shepherd — the accent surface the Family
/// Review badge already used, grown into a card with a verb.
class _AttentionCard extends StatelessWidget {
  final String title;
  final String body;
  final String cta;
  final VoidCallback onTap;
  const _AttentionCard({
    required this.title,
    required this.body,
    required this.cta,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: SelahColors.surfaceEmphasisFill,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: SelahColors.surfaceEmphasisBorder,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: SelahText.body(size: 13.5, color: Colors.white),
                      ),
                      SizedBox(height: 3),
                      Text(body, style: SelahText.subtext(size: 11.5)),
                    ],
                  ),
                ),
                SizedBox(width: 10),
                Text(
                  cta,
                  style: SelahText.body(size: 12.5, color: Colors.white),
                ),
                Icon(
                  Icons.chevron_right,
                  color: SelahColors.ink(0.54),
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A quiet recency row — fact, then when. Taps through to the Journey.
class _RecentRow extends StatelessWidget {
  final String title;
  final String label;
  final String when;
  final bool? isUnread;
  final VoidCallback? onTap;
  const _RecentRow({
    super.key,
    required this.title,
    required this.label,
    required this.when,
    this.isUnread,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            if (isUnread != null) ...[
              Icon(
                Icons.circle,
                key: isUnread == true
                    ? ValueKey('shepherd-update-unread-$title')
                    : null,
                size: isUnread == true ? 7 : 5,
                color: isUnread == true
                    ? SelahColors.actionFill
                    : SelahColors.foreground.withValues(alpha: 0.4),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Text(
                label.trim().isEmpty ? title : '$title — $label',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: SelahText.subtext(
                  size: 12.5,
                  color: SelahColors.ink(0.70),
                ),
              ),
            ),
            Text(
              when,
              style: SelahText.subtext(
                size: 11,
                color: SelahColors.foreground.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The stale-but-shown state: rows render, the truth about the refresh
/// failing is said out loud. inherited decision 167's rule on this screen.
class _ErrorBanner extends StatelessWidget {
  final VoidCallback onRetry;
  final bool lastKnown;
  final String? message;
  const _ErrorBanner({
    required this.onRetry,
    this.lastKnown = false,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: SelahColors.surfaceFill,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: SelahColors.surfaceBorder, width: 0.5),
        ),
        child: Row(
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 15,
              color: SelahColors.foreground.withValues(alpha: 0.5),
            ),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                message ??
                    (lastKnown
                        ? "Couldn't refresh Updates — showing last-known rows."
                        : "Couldn't refresh — showing what was loaded."),
                style: SelahText.subtext(size: 11.5),
              ),
            ),
            TextButton(
              onPressed: onRetry,
              child: Text(
                'Try again',
                style: SelahText.body(size: 12, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
