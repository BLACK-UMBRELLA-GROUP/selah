// Connections tab — per APP/Navigation/SEEKER NAVIGATION/Summary.md's
// CONNECTIONS section: "Relationship Journey = Save → Consider → Match
// → Conversation → Family Stage." Matches is NOT a conversation inbox
// (MATCH_UX_SPEC_CURRENT_VERSION_V1.md) — it houses Potential Journeys,
// with Active/Paused Journeys below leading into the Pre-Journey Ritual
// (JourneyFlowScreen) rather than straight to Chat.
//
// 2026-07-29 (Founder review — Connections-page redesign, Option 1 of 5
// presented in chat, chosen as-is): replaced the old flat
// MATCHES-then-everything layout with a two-panel "Journeys / Activity"
// segmented toggle (_SegmentedToggle, below).
//
// REVISED 2026-08-01 (Founder, screenshot review). Current layout:
//
//   Journeys   Active → Potential → Paused → Ended
//   Activity   Family Introductions → Considered → Saved → Passed
//
// Three changes and the reasoning, since the previous order was itself a
// deliberate decision and the comment describing it is now wrong:
//
//   1. POTENTIAL now precedes PAUSED. Potential Journeys are waiting on
//      you and are the most likely next action; Paused ones are, by
//      definition, not moving. Ordering by how live something is beats
//      ordering by lifecycle position.
//   2. ACTIVE JOURNEY is emphasised — full-white label, brighter card,
//      larger photo. Every header used to be identical white54, so the
//      one Journey you are actually in looked like everything else.
//   3. FAMILY INTRODUCTIONS moved to the top of Activity. It was placed
//      in Journeys on 2026-07-29 on the reasoning that a Family Stage is
//      part of a Journey's lifecycle. The Founder's read is better: the
//      Journeys tab answers "where are my Journeys up to" and every
//      other row there opens a Journey. An introduction between two
//      families is something that happened and wants attention — which
//      is Activity's job — and it outranks a bookmark, so it goes first.
//
// Activity rows use the same compact expansion language as Potential Journey:
// a persistent identity row, top-right Report flag, then profile, decision
// and compatibility actions. Journey rows use _JourneyExpandingCard.
// See _journeysChildren()/_activityChildren() for the two panels.
//
// 2026-07-26 (inherited decision 101 audit, nav bar fix — see SEEKER NAVIGATION
// Summary.md's own flagged inconsistency: live Seeker nav had only 3
// tabs, Browse/Matches/Profile, with no Connections or Shepherd tab at
// all). This screen used to be MatchesScreen (screens/matches/
// matches_screen.dart) and only covered the Matches section. Renamed
// and expanded to also surface Passed/Saved/Considered — reusing
// AppState.declined/saved/outgoingLikes exactly as profile_screen.dart
// already did for its own (now-superseded) connections counters — and
// a placeholder Family Introductions section, since the Shepherd-side
// Family Stage answering UI is a known, deliberately unbuilt gap (see
// the Founder handover's "Immediate Next Steps" item 1) rather than
// something to fake here.
//
// 2026-07-25 (inherited decision 101 audit): Matches section rewritten against
// real matches.status ('potential'/'active'/'ended') instead
// of the old client-only stand-in. "Start Journey" now calls
// SelahJourneyService.promoteToActive (a real RPC enforcing
// one-Active-Journey-at-a-time), and both journey lists are re-fetched
// from the backend rather than mutated locally. A PAUSED JOURNEYS
// section surfaces paused journeys (Journey Suspension,
// JOURNEY_SUSPENSION (CURRENT_VERSION)) with Resume/End actions.

// 'dart:ui' import removed 2026-08-13: ImageFilter.blur was used only by
// the private _SegmentedToggle, which moved to
// widgets/selah_segmented_toggle.dart in the same pass. Nothing in this
// file reaches into dart:ui any more.
import 'dart:async';

import '../../widgets/selah_profile_image.dart';

import 'package:flutter/material.dart';
import '../../dev/selah_app_gold_preview.dart';
import '../../data/selah_entitlements.dart';
import '../../data/selah_membership_catalog.dart';
import '../../data/selah_seeker_plan_limits.dart';
import '../../data/selah_journey_pause_state.dart';
import '../../data/selah_journey_stages.dart';
import '../../data/selah_release_gates.dart';
import '../../models/journey_match.dart';
import '../../models/seeker_profile.dart';
import '../../models/selah_gender.dart';
import '../../services/selah_auth.dart';
import '../../services/selah_account_state.dart';
import '../../services/selah_developer_access.dart';
import '../../services/selah_discovery_service.dart';
import '../../services/selah_shepherd_suggestion_service.dart';
import '../../services/selah_journey_service.dart';
import '../../services/selah_promotion_engine.dart';
import '../../services/selah_report_service.dart';
import '../../services/selah_seeker_basic_usage_store.dart';
import '../../theme/selah_card_metrics.dart';
import '../../services/selah_unlock_service.dart';
import '../../services/selah_mentor_link_service.dart';
import '../../dev/selah_dev_scenario.dart';
import '../../state/app_state.dart';
import '../../theme/selah_colors.dart';
import '../../theme/selah_text.dart';
import '../../widgets/report_profile_sheet.dart';
// selah_glass_dialog import retired 2026-08-13, round four: confirmation
// choices remain inline card extensions. Founder-selected Connections
// Option 4 (2026-08-20) adds one grouped Journey-options bottom sheet,
// but Pause/End still require their existing inline confirmation before
// anything is written. Report and rare server-refusal routes are unchanged.
import '../../widgets/selah_moment.dart';
import '../../widgets/selah_segmented_toggle.dart';
import '../../widgets/selah_state_widgets.dart';
import '../../widgets/selah_loading.dart';
import '../../widgets/selah_membership_history_lock.dart';
import '../journey/journey_flow_screen.dart';
import '../matches/journey_timeline_screen.dart';
import '../profile/seeker_profile_screen.dart';
import '../subscription/profile_unlock_screen.dart';
import 'connections_section_controller.dart';

/// The one profile-route contract for Connections.
///
/// A Connections profile is a temporary full-photo inspection surface, so it
/// rises modally and leaves by swiping down. Keeping the route here prevents
/// Active, Potential, Paused, Ended and Activity cards from quietly drifting
/// back to different dismissal controls.
@visibleForTesting
Future<T?> pushSelahConnectionsProfile<T>(
  BuildContext context, {
  required SeekerProfile profile,
  String? suggestedBy,
}) => Navigator.of(context).push<T>(
  MaterialPageRoute<T>(
    fullscreenDialog: true,
    builder: (_) => SeekerProfileScreen(
      profile: profile,
      suggestedBy: suggestedBy,
      swipeDownToDismiss: true,
    ),
  ),
);

bool _isIntroductionPreview(ShepherdSuggestion suggestion) =>
    suggestion.profile.id.startsWith(kSelahIntroductionTestProfilePrefix);

bool _isActivityPreview(SeekerProfile profile) =>
    profile.id.startsWith(kSelahActivityTestProfilePrefix);

bool _isLocalTestProfile(SeekerProfile profile) =>
    _isActivityPreview(profile) ||
    profile.id.startsWith(kSelahIntroductionTestProfilePrefix);

const String _kLocalIntroductionSuggestedBy = 'Ibrahim';

String? _localIntroductionAttribution(SeekerProfile profile) =>
    profile.id.startsWith(kSelahIntroductionTestProfilePrefix)
    ? _kLocalIntroductionSuggestedBy
    : null;

/// A local developer Introduction is already a complete renderable row and
/// must not sit behind an unrelated pending server read. Release never reads
/// the developer count, so it continues to wait for account truth.
@visibleForTesting
bool shouldSelahIntroductionShowLoading({
  required bool suggestionsLoaded,
  required int localPreviewCount,
  required bool releaseBuild,
}) => !suggestionsLoaded && (releaseBuild || localPreviewCount <= 0);

/// Adds deterministic local rows beside real Activity truth. The function
/// never mutates [AppState], and release builds never call it. Unique non-UUID
/// ids keep their production-style actions on explicit local-only paths.
@visibleForTesting
List<SeekerProfile> composeSelahActivityPreviewProfiles(
  List<SeekerProfile> real, {
  required SelahActivityTestState kind,
  required int previewCount,
  String? viewerGender,
}) {
  final count = previewCount.clamp(0, 5);
  if (count == 0) return List<SeekerProfile>.of(real);

  const women = ['Hana', 'Zara', 'Safiya', 'Inaya', 'Amira'];
  const men = ['Hamza', 'Omar', 'Idris', 'Zayd', 'Rayyan'];
  const surnames = ['Rahman', 'Khan', 'Malik', 'Ahmed', 'Hussain'];
  const cities = ['London', 'Birmingham', 'Manchester', 'Leeds', 'Glasgow'];
  final gender = SelahGender.oppositeCode(viewerGender);
  final names = gender == 'female' ? women : men;
  final ids = real.map((profile) => profile.id).toSet();
  final output = List<SeekerProfile>.of(real);

  for (var index = 0; index < count; index++) {
    final id = selahActivityTestProfileId(kind, index);
    if (!ids.add(id)) continue;
    output.add(
      SeekerProfile(
        id: id,
        firstName: names[index],
        surnameLine: surnames[index],
        age: 26 + index,
        city: cities[index],
        gender: gender,
        photos: [
          'https://picsum.photos/seed/selah-${kind.name}-$index/700/1000',
        ],
      ),
    );
  }
  return output;
}

/// Adds deterministic, local-only Introduction examples without replacing or
/// mutating any row returned by the real Shepherd Suggestions RPC.
///
/// The live screen bypasses this composition entirely in release mode and
/// does not even read the developer count.
@visibleForTesting
List<ShepherdSuggestion> composeSelahIntroductionPreviewSuggestions(
  List<ShepherdSuggestion> real, {
  required int previewCount,
}) {
  final count = previewCount.clamp(0, 5);
  if (count == 0) return List<ShepherdSuggestion>.of(real);
  final ids = real.map((suggestion) => suggestion.profile.id).toSet();
  final output = List<ShepherdSuggestion>.of(real);
  var added = 0;
  var candidate = 0;
  while (added < count) {
    final id = selahIntroductionTestProfileId(candidate);
    candidate++;
    if (!ids.add(id)) continue;
    final source = mockProfiles[added % mockProfiles.length];
    output.add(
      ShepherdSuggestion(
        profile: SeekerProfile(
          id: id,
          firstName: source.firstName,
          surnameLine: source.surnameLine,
          age: source.age,
          city: source.city,
          photos: source.photos,
          gender: source.gender,
        ),
        suggestedBy: _kLocalIntroductionSuggestedBy,
        unseen: false,
      ),
    );
    added++;
  }
  return output;
}

@visibleForTesting
typedef SelahActivityTestBuckets = ({
  List<SeekerProfile> considered,
  List<SeekerProfile> saved,
  List<SeekerProfile> passed,
});

/// Composes the Activity sections used in developer builds without touching
/// [AppState]. A fixture has one seed section until an action assigns one
/// local destination; it can therefore never appear in both its origin and
/// destination after a move.
@visibleForTesting
SelahActivityTestBuckets composeSelahActivityTestBuckets({
  required SelahDevScenario scenario,
  required List<SeekerProfile> realConsidered,
  required List<SeekerProfile> realSaved,
  required List<SeekerProfile> realPassed,
  String? viewerGender,
}) {
  final fixtures = <({SeekerProfile profile, SelahActivityTestState? origin})>[];

  void addActivityFixtures(SelahActivityTestState origin, int count) {
    fixtures.addAll(
      composeSelahActivityPreviewProfiles(
        const [],
        kind: origin,
        previewCount: count,
        viewerGender: viewerGender,
      ).map((profile) => (profile: profile, origin: origin)),
    );
  }

  addActivityFixtures(
    SelahActivityTestState.considered,
    scenario.consideredPreviewCount,
  );
  addActivityFixtures(SelahActivityTestState.saved, scenario.savedPreviewCount);
  addActivityFixtures(
    SelahActivityTestState.passed,
    scenario.passedPreviewCount,
  );
  fixtures.addAll(
    composeSelahIntroductionPreviewSuggestions(
      const [],
      previewCount: scenario.introductionPreviewCount,
    ).map((row) => (profile: row.profile, origin: null)),
  );

  List<SeekerProfile> rowsFor(
    List<SeekerProfile> accountTruth,
    SelahActivityTestState target,
  ) => [
    // A hot-reloaded session may still hold a local card in AppState from
    // the retired implementation. The scenario map is now the only test
    // destination authority, so those stale duplicates stay excluded.
    ...accountTruth.where((profile) => !_isLocalTestProfile(profile)),
    for (final fixture in fixtures)
      if (!scenario.isLocalProfileHidden(fixture.profile.id) &&
          (scenario.localProfileDestination(fixture.profile.id) ??
                  fixture.origin) ==
              target)
        fixture.profile,
  ];

  return (
    considered: rowsFor(realConsidered, SelahActivityTestState.considered),
    saved: rowsFor(realSaved, SelahActivityTestState.saved),
    passed: rowsFor(realPassed, SelahActivityTestState.passed),
  );
}

class ConnectionsScreen extends StatefulWidget {
  /// Switches the shell to the Browse tab. Used by "View profile" on a
  /// Shepherd Suggestion — this screen can't change tabs itself.
  final VoidCallback? onNavigateToBrowse;
  final VoidCallback? onNavigateToShepherd;
  final SelahConnectionsSectionController? sectionController;
  final Future<SelahSourceResult<List<ShepherdSuggestion>>> Function()?
  loadSuggestions;

  const ConnectionsScreen({
    super.key,
    this.onNavigateToBrowse,
    this.onNavigateToShepherd,
    this.sectionController,
    this.loadSuggestions,
  });

  @override
  State<ConnectionsScreen> createState() => _ConnectionsScreenState();
}

class _ConnectionsScreenState extends State<ConnectionsScreen> {
  final _accountGeneration = SelahAccountState.generation;
  final _accountOwner = SelahAccountState.userId;
  bool get _accountCurrent =>
      !SelahAccountState.isSigningOut &&
      _accountGeneration == SelahAccountState.generation &&
      _accountOwner == SelahAccountState.userId;
  final SelahConnectionsExpansionController _expansionController =
      SelahConnectionsExpansionController();

  // Suspended journeys (JOURNEY_SUSPENSION (CURRENT_VERSION)): these
  // are NOT a separate matches.status — per that spec's own §1.1
  // "Architectural Framing", suspension is a behavioural sub-state of
  // Active Journey, not a lifecycle transition. So a suspended journey
  // still has status='active'; it's identified by suspended_by being
  // non-null. Split out of `active` here for display purposes only.
  List<JourneyMatch> _suspended = [];
  // #17 — "Match remains visible in Matched list (greyed, at bottom)"
  // after End Journey (APP/Journey/JOURNEY AVAILABILITY/Summary.md).
  // Wasn't fetched/displayed at all before this pass — without this,
  // the Restart button built in journey_flow_screen.dart's _EndedView
  // would be unreachable once a user navigated away.
  List<JourneyMatch> _ended = [];

  /// Match IDs among the Active list that have a Family Review open.
  ///
  /// Drives the one override in the stage map — see
  /// SelahJourneyStages.familyReviewOverride. Fetched as a SET in one
  /// batched query in [_refresh]; a per-card fetchFamilyReview would be
  /// N+1, which is why SelahJourneyService.fetchOpenReviewMatchIds exists.
  ///
  /// Empty until that query returns, and empty forever if it fails. Both
  /// show the underlying stage, which is honest — the Journey really is
  /// in phase_2; the override only adds why it isn't moving.
  Set<String> _openReviews = const {};

  /// Ended matches on which this user may ask to begin again — inherited upstream action 159.
  ///
  /// A match's ABSENCE carries no reason. A 6-month cooldown, a permanent
  /// "don't ask again", a block, a Tier-1 exclusion, an Active Journey
  /// elsewhere and an already-pending request are all identical from here.
  /// That indistinguishability is the design, not a gap: inherited decision 121 item 8
  /// says "the requester is never told which". Do not enrich this into a
  /// map of reasons, however helpful that would feel.
  ///
  /// Empty until the query returns, and empty forever if it fails — so the
  /// button is hidden rather than offered and refused.
  Set<String> _mayRequest = const {};
  Set<String> _availableReturns = const {};

  /// Drives the Journeys/Activity pager. The toggle animates it; swiping
  /// moves it directly.
  ///
  /// REPLACED `bool _showActivity` on 2026-08-03. That flag recorded which
  /// panel had SETTLED, which was enough while the toggle only had two
  /// states — but the pill now follows the swipe continuously, so the
  /// question stopped being "which page" and became "how far between
  /// them". `_pagerPos` answers both: 0, 1, or anything in between.
  ///
  /// Leaving the bool in place would have been a second, coarser source of
  /// truth for the same thing. The analyzer caught it as write-only.
  late final PageController _pager;

  /// The pager's live position, 0.0 (Journeys) to 1.0 (Activity), updated
  /// on every frame of a drag so the toggle pill can track it.
  ///
  /// Read from the controller rather than kept in sync by hand — a second
  /// source of truth for "where is the pager" is exactly how the pill and
  /// the page would end up disagreeing.
  double _pagerPos = 0;
  late int _settledPage;
  late int _collapseRevisionSeen;

  /// Introductions. Named rather than a bare `2` because the arrival hook
  /// below depends on it and a fourth segment would silently break it.
  static const int _kIntroductionsIndex = 2;

  /// Guards the mark-seen write so it fires once per arrival, not once per
  /// frame — `_onPagerScroll` runs on every tick of the animation.
  bool _markingSeen = false;

  /// True only while THIS screen is pushing the settled segment into the
  /// scenario. That push notifies, the notify lands back here in
  /// [_onScenarioChange], and without the flag every swipe between segments
  /// would re-fetch the very list being swiped — a reload flicker caused by
  /// the panel merely following you.
  bool _pushingSection = false;

  late int _devJourneySignatureSeen;

  int _devJourneySignature(SelahDevScenario scenario) => Object.hash(
    scenario.connectionsPreviewIsolated,
    scenario.queuedJourneys,
    scenario.activeJourneys,
    scenario.pausedJourneys,
    scenario.endedJourneys,
    scenario.busyPotential,
    scenario.busyPaused,
    scenario.busyEnded,
    scenario.pauseScenario,
  );

  /// A dev toggle moved. Re-fetch, because the fakes are substituted at the
  /// fetch and a rebuild alone would show the same stale list.
  void _onScenarioChange() {
    if (_pushingSection) return; // our own section push looping back
    if (!mounted) return;
    final signature = _devJourneySignature(SelahDevScenario.instance);
    if (signature != _devJourneySignatureSeen) {
      _devJourneySignatureSeen = signature;
      _refresh();
      return;
    }
    // Design and heading comparisons are presentation-only. Rebuild in place
    // instead of re-fetching Supabase and flashing a loading state whenever
    // the Founder tries another option.
    setState(() {});
  }

  void _onPagerScroll() {
    if (!_pager.hasClients || _pager.page == null) return;
    // Upper bound was 1.0 — three segments now.
    final p = _pager.page!.clamp(0.0, (_kSegmentLabels.length - 1).toDouble());
    if ((p - _pagerPos).abs() < 0.001) return;
    setState(() => _pagerPos = p);
    // Settled on a segment — tell the dev panel where we are, so it can
    // narrow its Connections card to the section on screen (2026-08-12,
    // Founder: "i gotta be on indroduction to see the introduction optins
    // in toggle"). notifyListeners is synchronous, so the flag brackets
    // the loopback completely.
    if (SelahDeveloperAccess.canUseDeveloperTools && p == p.roundToDouble()) {
      _pushingSection = true;
      SelahDevScenario.instance.setConnectionsSection(p.round());
      _pushingSection = false;
    }
    if (p == p.roundToDouble()) {
      final settled = p.round();
      if (settled != _settledPage) {
        _settledPage = settled;
        _expansionController.collapseAll();
      }
      widget.sectionController?.synchroniseFromPage(
        SelahConnectionsSection.fromPage(settled),
      );
    }
    // Settled on Introductions — the arrival that discharges the alert.
    if (p == _kIntroductionsIndex.toDouble()) _markIntroductionsSeen();
  }

  /// Stamps the unseen introductions as seen, then rebuilds so the dot goes.
  ///
  /// Deliberately does NOT re-fetch. The list must not reorder or reload
  /// under someone who has just arrived to read it; only the badge changes.
  Future<void> _markIntroductionsSeen() async {
    if (_markingSeen) return;
    if (!_undecidedSuggestions.any((s) => s.unseen)) return;
    _markingSeen = true;
    final changed = await SelahShepherdSuggestionService.markSeen();
    if (!mounted) {
      _markingSeen = false;
      return;
    }
    if (changed) {
      setState(() {
        _suggestions = [
          for (final s in _suggestions)
            ShepherdSuggestion(
              profile: s.profile,
              suggestedBy: s.suggestedBy,
              unseen: false,
            ),
        ];
      });
    }
    _markingSeen = false;
  }

  @override
  void initState() {
    super.initState();
    final initialSection =
        widget.sectionController?.section ?? SelahConnectionsSection.journeys;
    _pager = PageController(initialPage: initialSection.page);
    _pagerPos = initialSection.page.toDouble();
    _settledPage = initialSection.page;
    _collapseRevisionSeen = widget.sectionController?.collapseRevision ?? 0;
    widget.sectionController?.addListener(_onExternalSectionRequest);
    _devJourneySignatureSeen = _devJourneySignature(SelahDevScenario.instance);
    AppState.instance.addListener(_onChange);
    // ADDED 2026-08-06. The Journey toggles wrote to SelahDevScenario and
    // nothing on this screen was listening, so `_refresh()` never re-ran and
    // no fake Journeys ever appeared — the toggles moved and did nothing,
    // which is the exact failure the panel's own header warns about.
    //
    // A full `_refresh()` rather than a `setState`, because the fakes are
    // substituted where the fetch happens; rebuilding alone would redraw the
    // same stale list.
    SelahDevScenario.instance.addListener(_onScenarioChange);
    _pager.addListener(_onPagerScroll);
    // A fresh build starts on the shell-requested section. Keep the developer
    // panel aligned with that real page rather than forcing Journeys and
    // silently undoing a Dashboard deep-link.
    // Post-frame because notifying listeners mid-build is not allowed.
    if (SelahDeveloperAccess.canUseDeveloperTools) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _pushingSection = true;
        SelahDevScenario.instance.setConnectionsSection(initialSection.page);
        _pushingSection = false;
      });
    }
    _refresh();
    _loadSuggestions();
  }

  @override
  void didUpdateWidget(covariant ConnectionsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sectionController == widget.sectionController) return;
    oldWidget.sectionController?.removeListener(_onExternalSectionRequest);
    widget.sectionController?.addListener(_onExternalSectionRequest);
    _collapseRevisionSeen = widget.sectionController?.collapseRevision ?? 0;
    _onExternalSectionRequest();
  }

  void _onExternalSectionRequest() {
    if (!mounted || widget.sectionController == null) return;
    final collapseRevision = widget.sectionController!.collapseRevision;
    if (collapseRevision != _collapseRevisionSeen) {
      _collapseRevisionSeen = collapseRevision;
      _expansionController.collapseAll();
    }
    final target = widget.sectionController!.section.page;
    void move() {
      if (!mounted || !_pager.hasClients) return;
      final current = _pager.page?.round() ?? _pager.initialPage;
      if (current == target) return;
      SelahSegmentedMotion.animateToPage(_pager, target);
    }

    if (_pager.hasClients) {
      move();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => move());
    }
  }

  @override
  void dispose() {
    AppState.instance.removeListener(_onChange);
    SelahDevScenario.instance.removeListener(_onScenarioChange);
    widget.sectionController?.removeListener(_onExternalSectionRequest);
    _pager.removeListener(_onPagerScroll);
    _pager.dispose();
    _expansionController.dispose();
    super.dispose();
  }

  /// Shepherd Suggestions for this Seeker. Loaded alongside the Journeys
  /// refresh and re-loaded whenever AppState.suggestionsVersion moves.
  List<ShepherdSuggestion> _suggestions = const [];
  bool _suggestionsUnavailable = false;
  int _suggestionsLoadGeneration = 0;
  int _suggestionsVersion = AppState.instance.suggestionsVersion;
  SelahPlan _planSeen = AppState.instance.plan;

  void _onChange() {
    if (!_accountCurrent) {
      setState(() {
        _suggestions = const [];
        _suggestionsLoaded = true;
        _suggestionsUnavailable = true;
      });
      return;
    }
    final v = AppState.instance.suggestionsVersion;
    if (v != _suggestionsVersion) {
      _suggestionsVersion = v;
      _loadSuggestions();
    }
    // ADDED 2026-08-12. A plan switch re-runs the full refresh, because the
    // dev fakes are CLAMPED to the plan's Journey limits where the fetch
    // happens (fakeJourneys' devClamp) — a bare setState would redraw the
    // same over-cap list. Without this, SELAH One with Paused at 8 switched
    // to Basic showed 5 in the panel and 8 on screen until some other
    // refresh happened to run: the panel and the page disagreeing about the
    // state the panel claims to own.
    if (AppState.instance.plan != _planSeen) {
      _planSeen = AppState.instance.plan;
      _refresh();
    }
    setState(() {});
  }

  /// False until the first fetch resolves — see [_suggestionsLoaded].
  Future<void> _loadSuggestions() async {
    if (!_accountCurrent) return;
    final generation = ++_suggestionsLoadGeneration;
    SelahSourceResult<List<ShepherdSuggestion>> result;
    try {
      result =
          await (widget.loadSuggestions ??
              SelahShepherdSuggestionService.fetchPendingResult)();
    } catch (error) {
      debugPrint('SELAH: introduction read failed (${error.runtimeType}).');
      result = const SelahSourceResult.unavailable(
        SelahSourceFailure.requestFailed,
      );
    }
    if (!mounted ||
        !_accountCurrent ||
        generation != _suggestionsLoadGeneration) {
      return;
    }
    if (result.isUnavailable) {
      setState(() {
        _suggestionsUnavailable = true;
        _suggestionsLoaded = true;
      });
      return;
    }
    final s = result.valueOr(const []);
    setState(() {
      _suggestions = s;
      _suggestionsLoaded = true;
      _suggestionsUnavailable = false;
    });
    // Publish app-wide so Browse can mark a suggested profile in the deck,
    // and so the mark survives into Considered/Saved/Passed after a
    // decision (Founder, 2026-08-05).
    AppState.instance.setShepherdSuggestedBy({
      for (final x in s) x.profile.id: x.suggestedBy,
    });
    // A suggestion can arrive while the Seeker is already sitting on
    // Introductions. They have arrived; the alert has nothing left to tell
    // them, so it is discharged here too rather than waiting for them to
    // navigate away and back to earn it.
    if (_pagerPos == _kIntroductionsIndex.toDouble()) _markIntroductionsSeen();
  }

  /// Suggestions still awaiting a look. Once you Consider, Save or Pass
  /// someone they leave this section and appear in that list instead —
  /// still marked as suggested, so the Shepherd's involvement isn't lost,
  /// but not listed twice as though nothing had happened.
  /// Outstanding user action per segment, in page order.
  ///
  /// `APP/Standards/BADGE_STANDARD_CURRENT_VERSION_V1.md`, Founder 2026-08-06:
  ///
  ///   "A badge represents outstanding user action. It does not simply
  ///    indicate that something happened."
  ///
  /// Every entry below answers one question: **is the user expected to do
  /// something?**
  ///
  /// THE REASON THIS IS A GETTER AND NOT A STORED COUNT. Outstanding action
  /// is STATE, not history. The earlier framing — "what changed since you
  /// last looked" — would have needed a `last_seen_at` per user per
  /// surface, because history needs a bookmark. Derived from current state
  /// it needs no schema at all, and it cannot drift out of sync with the
  /// thing it counts, because it IS the thing it counts.
  List<int> get _segmentBadges => [
    // JOURNEYS — only where the Journey is waiting on the user.
    //
    // A Potential Journey is a mutual like nobody has opened yet: it
    // sits there until this user promotes or declines it. That is
    // outstanding action by definition.
    //
    // NOT badged, per the standard: automatic stage progression (the
    // platform moved it, not you), the user's own actions (they were
    // there), informational milestones.
    //
    // NOT YET COUNTED, and each needs work rather than a decision:
    //   Family Review awaiting YOUR decision — needs the review's
    //     pending state surfaced on this screen; it currently lives in
    //     journey_flow_screen.
    //   The other party ended the Journey — needs an `acknowledged`
    //     boolean on the attempt. NOT an exception to "outstanding
    //     action is state": the badge represents "you have an unread
    //     Journey outcome", which is a standing condition, structurally
    //     the same as an unresolved introduction. A per-item flag, not
    //     a last_seen_at bookmark.
    //   The other party requested a new Journey — inherited upstream action 159, unbuilt.
    AppState.instance.potentialJourneys.length +
        AppState.instance.activeJourneys.where((journey) {
          final perspective = journey.pause.perspectiveFor(
            SelahAuth.currentUser?.id,
          );
          return perspective == SelahPausePerspective.pauseResponderDecision ||
              perspective == SelahPausePerspective.continuationResponderDecision;
        }).length +
        _suspended.where((journey) {
          return journey.pause.perspectiveFor(SelahAuth.currentUser?.id) ==
              SelahPausePerspective.resumeResponderDecision;
        }).length,

    // ACTIVITY — permanently zero, and correct.
    //
    // Considered, Saved and Passed are records of the user's OWN
    // decisions. Not an inbox; nothing arrives unbidden. Founder
    // 2026-08-06: "If Activity never has a badge, that's perfectly
    // fine. Not every surface needs one."
    //
    // The one candidate — a saved profile becoming unavailable — is a
    // loss the user can do nothing about, so it fails the rule.
    0,

    // INTRODUCTIONS — a Shepherd has put someone forward and the
    // Seeker has a decision to make.
    //
    // FIXED 2026-08-06 (Founder: "when I went off the page it was still
    // there. It only left after I made a choice with each user on the
    // page, but it should go once the user lands on the page").
    //
    // This counted `_undecidedSuggestions.length` — the UNRESOLVED
    // count — and the comment here confidently explained why that was
    // right. It was right against the ORIGINAL rule. The Founder amended
    // the Badge Standard the same day and this code was never brought
    // along, so the dot nagged for days about a list already read.
    //
    //   badge      = UNSEEN     clears on arrival   <- this
    //   list count = UNRESOLVED clears on resolution <- the heading
    //
    // The badge is the alert; the list is the work. Arriving discharges
    // the alert, and the heading goes on saying the work is there.
    _undecidedSuggestions.where((s) => s.unseen).length,
  ];

  // NAV BAR AGGREGATION IS NOT WIRED HERE, deliberately.
  //
  // The standard requires the Connections tab to show the SUM of these and
  // to land on the highest-priority segment with unresolved work. Both
  // numbers would have to travel UP to HomeShell, which owns the nav bar —
  // and reaching into this State from there (a GlobalKey, or lifting the
  // whole screen's state) would couple the nav bar to whether this screen
  // happens to be built.
  //
  // The right home is AppState, which already holds potentialJourneys and
  // drives suggestionsVersion. Both counts derive from it, so HomeShell can
  // read them whether or not Connections has ever been opened — which it
  // must, since the badge's whole job is to make you open it.
  //
  // Left as a stated next step rather than a stub: an unused getter here
  // would be dead code pointing at the wrong architecture.

  /// Whether the Introductions fetch has come back yet.
  ///
  /// ADDED 2026-08-13 (inherited decision 165). This screen had no loading state at
  /// all — the busiest tab in the app, and its lists start empty — so
  /// during the first fetch Introductions rendered its EMPTY STATE:
  /// "No introductions yet. People your Shepherd puts forward will appear
  /// here." Told to someone who may well have one waiting.
  ///
  /// Every comparable list screen guards this (Notifications, the
  /// Shepherd tab, Hidden Profiles, the Timeline). Scoped here to
  /// Introductions rather than the whole screen, because the other two
  /// segments read AppState, which is hydrated before this tab can be
  /// reached — Introductions is the only section that waits on a query.
  bool _suggestionsLoaded = false;

  Widget _introductionsPage() {
    final unavailable =
        _suggestionsUnavailable && !SelahDeveloperAccess.canUseDeveloperTools;
    if (shouldSelahIntroductionShowLoading(
      suggestionsLoaded: _suggestionsLoaded,
      localPreviewCount: SelahDevScenario.instance.introductionPreviewCount,
      releaseBuild: !SelahDeveloperAccess.canUseDeveloperTools,
    )) {
      return const SelahLoading();
    }
    if (_undecidedSuggestions.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
        child: unavailable
            ? SelahEmptyState(
                icon: Icons.groups_outlined,
                title: 'Couldn’t load introductions',
                message:
                    'Your introductions are unavailable right now. Please try again.',
                ctaLabel: 'Try again',
                onCta: _loadSuggestions,
              )
            : const SelahEmptyState(
                icon: Icons.groups_outlined,
                title: 'No introductions yet',
                message: 'People your Shepherd puts forward will appear here.',
              ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      children: [
        if (unavailable) ...[
          SelahErrorBanner(
            message:
                'Introductions could not refresh. Showing last confirmed information.',
            onRetry: _loadSuggestions,
          ),
          const SizedBox(height: 12),
        ],
        ..._introductionsChildren(),
      ],
    );
  }

  List<ShepherdSuggestion> get _displaySuggestions {
    // The release branch returns before the developer getter is read. Local
    // test cards can never become a fallback for production/account truth.
    if (!SelahDeveloperAccess.canUseDeveloperTools) return _suggestions;
    final dev = SelahDevScenario.instance;
    return composeSelahIntroductionPreviewSuggestions(
      _suggestions,
      previewCount: dev.introductionPreviewCount,
    ).where((suggestion) {
      final id = suggestion.profile.id;
      if (!id.startsWith(kSelahIntroductionTestProfilePrefix)) return true;
      return !dev.isLocalProfileHidden(id) &&
          dev.localProfileDestination(id) == null;
    }).toList();
  }

  List<ShepherdSuggestion> get _undecidedSuggestions {
    final app = AppState.instance;
    final decided = <String>{
      ...app.declined.map((p) => p.id),
      ...app.saved.map((p) => p.id),
      ...app.outgoingLikes.map((p) => p.id),
    };
    return _displaySuggestions
        .where((s) => !decided.contains(s.profile.id))
        .toList();
  }

  Future<void> _refresh() async {
    // Release always uses live account truth. Developer mode starts that way,
    // but Reset or any Connections count control enters an isolated preview:
    // zero then means zero visible cards and the operator adds only the states
    // they want to inspect. No server row is deleted or mutated by that view.
    final dev = SelahDevScenario.instance;
    final realOrNull = await SelahJourneyService.fetchJourneyMatches(
      statuses: const ['potential', 'active', 'ended'],
    );
    // inherited decision 179. Null means the fetch FAILED — not "no Journeys".
    // The old [] return here let a 403 (a missing column grant) read
    // as an empty list for three days, and in dev builds the panel's
    // stand-ins then topped up over the hole, so a real, live Journey
    // was invisible everywhere while every card LOOKED fine. Hold what
    // is already on screen and let the next pull retry. The former persistent
    // snackbar was removed by Founder review; a background refresh failure
    // must not obscure the app with a message that never clears.
    if (realOrNull == null) {
      return;
    }
    final real = realOrNull;
    bool isRunning(JourneyMatch j) => j.status == 'active' && !j.isSuspended;

    final all = !SelahDeveloperAccess.canUseDeveloperTools
        ? real
        : SelahDevScenario.composeJourneys(
            viewerGender: AppState.instance.gender,
            // The candidate pool exists only to give FAKES real photos —
            // skip the fetch when every row is 0 and no fake will be drawn.
            pool: dev.anyJourneysStaged
                ? await SelahDiscoveryService.fetchCandidates()
                : const [],
            // 2026-08-09: the generator clamps its counts to the plan's
            // Journey limits, so it has to be told which plan.
            viewerPlan: AppState.instance.plan,
            realActive: dev.connectionsRealRows(real.where(isRunning).toList()),
            realPotential: dev.connectionsRealRows(
              real.where((j) => j.status == 'potential').toList(),
            ),
            realPaused: dev.connectionsRealRows(
              real.where((j) => j.status == 'active' && j.isSuspended).toList(),
            ),
            realEnded: dev.connectionsRealRows(
              real.where((j) => j.status == 'ended').toList(),
            ),
          );
    if (!mounted) return;
    final potential = all.where((j) => j.status == 'potential').toList();
    final activeAll = all.where((j) => j.status == 'active').toList();
    final active = activeAll.where((j) => !j.isSuspended).toList();
    final suspended = activeAll.where((j) => j.isSuspended).toList();
    final ended = all.where((j) => j.status == 'ended').toList()
      ..sort(
        (a, b) =>
            (b.endedAt ?? DateTime(0)).compareTo(a.endedAt ?? DateTime(0)),
      );
    AppState.instance.setJourneyMatches(potential: potential, active: active);

    // ONE query for the whole Active list, and only the Active list:
    // a Potential Journey has no stage to override, and an Ended one has
    // no live review by definition.
    //
    // Placed AFTER setJourneyMatches so the extra round-trip delays only
    // this screen's own setState, not the app-wide Journey state that the
    // rest of the shell reads.
    //
    // Dev fakes are skipped rather than queried: their match IDs are not
    // real rows, and Postgres would reject them against a uuid column
    // (22P02) to tell us something we already know.
    //
    // FILTERED BY ROW, NOT BY FLAG, 2026-08-11. This used to skip the query
    // whenever ANY Journey toggle was on, which was a proxy for "everything
    // here is fake" — true until the Active toggle began surfacing the real
    // Journey. isMock is the property the comment above was always really
    // describing, so it is now the property being tested.
    final realActiveIds = active
        .where((j) => !j.isMock)
        .map((j) => j.matchId)
        .toList();
    final openReviews = realActiveIds.isEmpty
        ? const <String>{}
        : await SelahJourneyService.fetchOpenReviewMatchIds(realActiveIds);

    // inherited upstream action 159 stage 5. Expire lapsed requests BEFORE asking which
    // Journeys may be asked on, or a request that ran out its thirty days
    // yesterday would still read as pending and suppress the button.
    //
    // Lazy rather than scheduled — there is no cron in this database, and
    // this is the same shape as resolveFamilyReviewIfDue.
    // Same rule as openReviews above: asked when there is a real ended row to
    // ask about, not when a flag says the panel is involved.
    Set<String> mayRequest = const {};
    Set<String> availableReturns = const {};
    if (SelahReleaseGates.requestNewJourneyEnabled &&
        (ended.any((j) => !j.isMock) || suspended.any((j) => !j.isMock))) {
      await SelahJourneyService.expireDueJourneyRequests();
      // BATCHED — one call for every ended Journey. A per-row lookup here is
      // the N+1 this file already has a rule against.
      final result = await Future.wait([
        SelahJourneyService.fetchMayRequestNewJourneyIds(),
        SelahJourneyService.fetchAvailableJourneyReturnIds(),
      ]);
      mayRequest = result[0];
      availableReturns = result[1];
    }
    if (!mounted) return;

    setState(() {
      _suspended = suspended;
      _ended = ended;
      _openReviews = openReviews;
      _mayRequest = mayRequest;
      _availableReturns = availableReturns;
    });
  }

  /// inherited upstream action 159. Asks the other Seeker to begin again.
  ///
  /// CONFIRMED FIRST, because the tap is easy to misread. "Request New
  /// Journey" is honest about being a request, but someone who ended a
  /// Journey months ago and taps it on a quiet evening should be told plainly
  /// that the other person will be notified and may say no — before it
  /// happens, not after.
  /// The restart ask — INLINE since 2026-08-13 (Founder: "when i press
  /// restart the pop up shows but we changed the ui to give notification
  /// like we did for potential"). Was a glass dialog (restyled 2026-08-11,
  /// Frost UI pass); now the tap sets [_restartMatchId] and the ended
  /// card itself extends with the SAME words the dialog carried — see
  /// _InlineRestartAsk at the bottom of this file. _sendRestartRequest
  /// finishes the job.
  Future<void> _requestNewJourney(JourneyMatch j) async {
    if (!SelahReleaseGates.requestNewJourneyEnabled) return;
    setState(() => _restartMatchId = j.matchId);
  }

  /// The ended row whose card is currently extended with the restart ask.
  /// Null when nobody is mid-ask; a stale id matches nothing, exactly
  /// like [_takeoverMatchId].
  String? _restartMatchId;

  /// Builds the inline restart ask for [j], or null when its card isn't
  /// the one asking.
  Widget? _inlineRestartFor(JourneyMatch j) {
    if (!SelahReleaseGates.requestNewJourneyEnabled ||
        _restartMatchId != j.matchId) {
      return null;
    }
    return _InlineRestartAsk(
      next: j,
      onDismiss: () => setState(() => _restartMatchId = null),
      onSend: () => _sendRestartRequest(j),
    );
  }

  Future<void> _sendRestartRequest(JourneyMatch j) async {
    if (!SelahReleaseGates.requestNewJourneyEnabled) {
      setState(() => _restartMatchId = null);
      return;
    }
    setState(() => _restartMatchId = null);

    // A stand-in's request succeeds in words alone — there is no server
    // row to ask through, and no request state the list would show anyway.
    if (j.isMock) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Asked ${j.profile.firstName}. You\'ll hear when they answer.',
          ),
        ),
      );
      return;
    }

    final error = await SelahJourneyService.requestNewJourney(j.matchId);
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Asked ${j.profile.firstName}. You\'ll hear when they answer.',
          ),
        ),
      );
    }
    // Re-read either way: on success the button must disappear (one pending
    // request per pair), and on failure the server may have refused for a
    // reason that also changes what this list should show.
    await _refresh();
  }

  // THE START MOMENT, REWRITTEN 2026-08-11 (Founder: the start flow
  // "gotta show it will end current journey if thats the case"). Until
  // now the one-Active-Journey rule surfaced AFTER the confirm — the
  // server refused promoteToActive and a snackbar told the person to go
  // end something, so they learned the cost of the choice only once it
  // had already bounced. Now the moment itself carries the cost BEFORE
  // the tap — and since 2026-08-12 it carries the choice too: pause the
  // current Journey (its place kept) or end it, either followed by the
  // start. Since the same evening the choice is no longer a popup at
  // all — the person's own card extends with it (B3; see the banner
  // over _InlineTakeover at the bottom of this file).
  //
  // Settle-then-start, not start-then-settle: promoteToActive refuses
  // while any unsuspended Active Journey exists, so the order is forced.
  // If the promote then fails anyway, nothing is silently lost — a
  // paused Journey sits in Paused with its place kept, an ended one in
  // Ended with its Timeline kept, and _promote's own error handling says
  // the start itself failed.
  //
  // DISCLOSURE PRESERVED from 2026-08-01 (Founder decision, via ChatGPT:
  // Shepherd conversation visibility is deliberate and must be stated
  // consistently everywhere). THIS IS THE MOMENT IT MATTERS —
  // messages_select's RLS grants a linked Mentor read access from the
  // instant matches.status leaves 'potential', which is exactly what
  // this button does. It names BOTH Shepherds because the policy grants
  // access to a Mentor linked to EITHER Seeker; saying only "your
  // Shepherd" would be a second, subtler untruth.
  void _startJourney(JourneyMatch j) async {
    // MOCKS COUNT since 2026-08-12, evening (Founder: "the pop up we just
    // made isnt showing on app" — his Active Journey was a staged
    // stand-in, and `!a.isMock` here quietly excused it, so the takeover
    // never fired in exactly the solo-testing state it was built to be
    // rehearsed in). AppState holds the COMPOSED list, so in a dev build
    // staged rows block like real ones; in release no mock exists to
    // count. What differs is the ACTION: a stand-in pauses and ends in
    // the scenario's numbers (see the switch below), never the database.
    final blocking = AppState.instance.activeJourneys
        .where((a) => a.matchId != j.matchId && !a.isSuspended)
        .toList();
    // The plan's cap, mirroring the server's selah_active_journey_cap()
    // (Basic 1 / SELAH One 3 — plan_aware_active_journey_limit,
    // 2026-08-12). Below the cap a start needs no takeover at all: One
    // with a single Active Journey simply begins its second.
    final cap = SelahEntitlements.of(AppState.instance.plan).active;

    if (blocking.length < cap) {
      // THE LAST POPUP IN THE BEGIN FLOW, GONE — 2026-08-13 (Founder:
      // "I still get a popup. We agreed we were moving away from
      // popups"). What he was hitting was exactly this branch: on SELAH
      // One a single Active Journey sits UNDER the cap of 3, so the
      // takeover rightly never fired — and this confirm, a glass dialog
      // since its 2026-08-12 restyle, did. Now the confirm extends the
      // person's card inline like everything else in this flow: same
      // person-as-photo, same one-line body ("one person at a time" —
      // the seriousness principle, never a quota), same Shepherd
      // disclosure at the exact moment RLS opens to both Shepherds.
      // See _InlineBeginConfirm at the bottom of this file.
      setState(() => _beginMatchId = j.matchId);
      return;
    }

    // The cap is full — the tap is really a choice BETWEEN people, and
    // the moment must show them.
    //
    // NO LONGER A POPUP. Founder, 2026-08-12, evening (interactive
    // round, section 4): shown three presentations side by side — B1
    // the transparent glass dialog he'd picked that morning, B2 the
    // same dialog solid pink/purple, B3 the person's card extending
    // with the choice inline — he chose B3: "point 4 do b3". So the
    // tap sets [_takeoverMatchId] and the card itself grows the choice:
    // same parts, same words, same hierarchy as the dialogs it
    // replaces, just rendered where the person already is. Everything
    // else about the moment (which shape shows, what the choices do)
    // lives in _inlineTakeoverFor and _settleTakeover below.
    setState(() => _takeoverMatchId = j.matchId);
  }

  /// The potential row whose card is currently extended with the inline
  /// takeover choice (B3). Null when nobody is mid-decision. Cleared by
  /// Continue / Not now, by settling, and implicitly whenever the row
  /// itself leaves the list — a stale id simply matches nothing.
  String? _takeoverMatchId;

  /// The potential row whose card is currently extended with the inline
  /// BEGIN confirm (below the cap — 2026-08-13, the flow's last popup
  /// retired). Same lifecycle as [_takeoverMatchId]; the two are never
  /// set together, because one tap picks exactly one branch.
  String? _beginMatchId;

  /// The one extension a potential card can carry: the begin confirm if
  /// this row is mid-confirm, else the takeover if it is mid-takeover,
  /// else nothing.
  Widget? _inlinePotentialFor(JourneyMatch j) {
    if (_beginMatchId == j.matchId) {
      return _InlineBeginConfirm(
        next: j,
        onDismiss: () => setState(() => _beginMatchId = null),
        onBegin: () => _confirmBegin(j),
      );
    }
    return _inlineTakeoverFor(j);
  }

  /// The begin, confirmed inline. Mirrors what the dialog's "Begin with
  /// X" did — a staged potential "begins" in the scenario's numbers (no
  /// row exists for the real promote to act on); a real one promotes.
  Future<void> _confirmBegin(JourneyMatch j) async {
    setState(() => _beginMatchId = null);
    if (j.isMock) {
      final dev = SelahDevScenario.instance;
      dev.setQueuedJourneys((dev.queuedJourneys - 1).clamp(0, 99));
      dev.setActiveJourneys(dev.activeJourneys + 1);
      return;
    }
    await _promote(j);
  }

  /// Builds the inline takeover for [j], or null when its card isn't the
  /// one deciding. Blocking is re-read at build time so the extension
  /// always reflects the CURRENT actives — if they resolved meanwhile
  /// (ended elsewhere, scenario recomposed), the extension disappears
  /// and the next Begin tap walks the plain path.
  ///
  /// ONE blocking Journey gets B1's shape exactly; SEVERAL (a full SELAH
  /// One) get the C1 chooser's, resolving to the same decision plus the
  /// person it applies to — both inline since "point 4 do b3".
  Widget? _inlineTakeoverFor(JourneyMatch j) {
    if (_takeoverMatchId != j.matchId) return null;
    final blocking = AppState.instance.activeJourneys
        .where((a) => a.matchId != j.matchId && !a.isSuspended)
        .toList();
    if (blocking.isEmpty) return null;
    void dismiss() => setState(() => _takeoverMatchId = null);
    if (blocking.length == 1) {
      final other = blocking.first;
      return _InlineTakeover(
        active: other,
        next: j,
        onDismiss: dismiss,
        onChoice: (choice) => _settleTakeover(j, choice, other),
      );
    }
    return _InlineTakeoverChooser(
      actives: blocking,
      next: j,
      onDismiss: dismiss,
      onChoice: (choice, other) => _settleTakeover(j, choice, other),
    );
  }

  /// Resolve an Active-slot conflict. End is immediate after confirmation and
  /// can therefore be followed by Begin. Pause is now a shared request: it
  /// keeps the Active slot until the other Seeker agrees, so it opens the
  /// decision flow and deliberately does not begin the waiting Journey.
  ///
  /// A STAND-IN settles in the scenario's numbers, not the database: the
  /// staged Active count drops by one and the Paused/Ended count rises,
  /// so the list re-composes showing exactly what the choice meant. One
  /// honest limitation, accepted 2026-08-12: fakes are positional (the
  /// generator re-deals names by index), so with SEVERAL staged actives
  /// the row that disappears may not carry the name that was tapped —
  /// with one staged active, the common solo case, it is exact.
  Future<void> _settleTakeover(
    JourneyMatch j,
    _TakeoverChoice choice,
    JourneyMatch other,
  ) async {
    setState(() => _takeoverMatchId = null);
    final dev = SelahDevScenario.instance;
    switch (choice) {
      case _TakeoverChoice.continueCurrent:
        return; // the inline widgets never emit this; enum exhaustiveness
      case _TakeoverChoice.requestPause:
        if (other.isMock) {
          dev.setPauseScenario(SelahPauseDevScenario.pauseRequesterWaiting);
        } else {
          try {
            await SelahJourneyService.transitionPause(
              matchId: other.matchId,
              action: SelahPauseAction.requestPause,
              expectedVersion: other.pause.version,
            );
          } on PauseTransitionStaleException {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('This Journey changed. Review it again.'),
              ),
            );
            return;
          } catch (_) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  "Pause request didn't go through — check your connection and try again.",
                ),
              ),
            );
            return;
          }
        }
        await _refresh();
        if (!mounted) return;
        await _openPauseFlow(other);
        return;
      case _TakeoverChoice.endAndBegin:
        if (other.isMock) {
          dev.setActiveJourneys((dev.activeJourneys - 1).clamp(0, 99));
          dev.setEndedJourneys(dev.endedJourneys + 1);
        } else {
          // Truthful-end rule (2026-08-15, inherited upstream action 225): a failed end
          // stops the takeover here rather than letting _promote be
          // refused for a slot that was never freed.
          final ok = await SelahJourneyService.endJourney(other.matchId);
          if (!ok) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  "End didn't go through — check your connection and try again.",
                ),
              ),
            );
            return;
          }
        }
    }
    if (!mounted) return;
    if (j.isMock) {
      // The new Journey is itself a stand-in: "promote" it in the staged
      // numbers and stop — there is no row for JourneyFlowScreen to read.
      dev.setQueuedJourneys((dev.queuedJourneys - 1).clamp(0, 99));
      dev.setActiveJourneys(dev.activeJourneys + 1);
      return;
    }
    await _refresh();
    if (!mounted) return;
    await _promote(j);
  }

  Future<void> _promote(JourneyMatch j) async {
    try {
      final ok = await SelahJourneyService.promoteToActive(j.matchId);
      await _refresh();
      if (!mounted) return;
      if (ok) {
        // Successful value event only — never a screen-open heuristic. The
        // engine records eligibility now; the explainer/invitation may render
        // only on the next calm shell landing after this Journey route.
        await SelahPromotionEngine.instance.markNotificationValueMoment(
          role: SelahPromotionRole.seeker,
          trigger: SelahPromotionTrigger.firstActiveJourney,
        );
        await SelahPromotionEngine.instance.markUpgradeValueMoment(
          role: SelahPromotionRole.seeker,
          product: SelahPromotionProduct.selahOne,
          placement: SelahPromotionPlacement.home,
          feature: SelahPromotionFeature.generalMembership,
          trigger: SelahPromotionTrigger.firstActiveJourney,
        );
        if (!mounted) return;
        // E2 — Journey Begins (inherited decision 147): the threshold from choice
        // to commitment, and the honest moment to restate that both
        // Shepherds can now read the conversation. Plays before the
        // flow opens; tapping through lands in Compatibility Reveal.
        await showSelahMoment(
          context,
          pairWith: j.profile,
          lines: [
            SelahMomentLine.heading(
              'Your Journey with ${j.profile.firstName} begins.',
            ),
            const SelahMomentLine.body(
              'One person. Both families present. Step by step.',
            ),
            SelahMomentLine.quiet(
              'From the first message, each person’s Main Shepherd and any '
              'Additional Shepherds included in this Journey can read the '
              'conversation.',
            ),
            const SelahMomentLine.body('It opens with Compatibility Reveal.'),
          ],
          ctaLabel: 'Begin',
        );
        if (!mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => JourneyFlowScreen(
              matchId: j.matchId,
              profile: j.profile,
              onOpenShepherd: widget.onNavigateToShepherd,
            ),
          ),
        );
      }
    } on OneActiveJourneyLimitException {
      if (!mounted) return;
      // Plan-aware since 2026-08-12: "already have AN Active Journey"
      // stopped being the whole truth the day SELAH One's cap became 3.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "You're at your plan's Active Journey limit. End or pause one before starting another.",
          ),
        ),
      );
    } finally {
      // The 'Starting…' in-flight label died with the trailing pills
      // (2026-08-12, Activity-model rewire): the verb now lives inside
      // the expansion and the card collapses on tap, so there is no
      // button left to disable. promote itself refuses a double-fire —
      // the second call finds the match no longer 'potential'.
    }
  }

  /// Opens the single Pause decision surface. Pending requests are not
  /// answered from a Connections card: both Seekers see the same calm,
  /// explicit decision page and the database remains the only state owner.
  Future<void> _openPauseFlow(JourneyMatch j) => _enterJourney(j);

  Future<void> _requestResume(JourneyMatch j) async {
    if (j.isMock) {
      SelahDevScenario.instance.setPauseScenario(
        SelahPauseDevScenario.resumeRequesterWaiting,
      );
      await _openPauseFlow(j);
      return;
    }
    try {
      await SelahJourneyService.transitionPause(
        matchId: j.matchId,
        action: SelahPauseAction.requestResume,
        expectedVersion: j.pause.version,
      );
    } on PauseTransitionStaleException {
      await _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This decision changed. Review it again.'),
        ),
      );
      return;
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Resume request didn't go through — check your connection and try again.",
          ),
        ),
      );
      return;
    }
    await _refresh();
    if (!mounted) return;
    await _openPauseFlow(j);
  }

  /// Ends a paused Journey — CONFIRMED FIRST since 2026-08-12, because
  /// its only entry point is now the "End Journey" pill on the person's
  /// card (the old three-button paused dialog, which WAS the
  /// confirmation, died with the Option A row-tap model). Short and
  /// in the takeover popups' language: what it costs, what is kept.
  /// INLINE since 2026-08-13, round four (Founder: "we are agreeing
  /// popups now in connections page no longer exist and is all
  /// expanded") — the tap swaps the paused card's rows for the confirm,
  /// under the ✕ header. _doEndSuspended finishes the job.
  Future<void> _endSuspended(JourneyMatch j) async {
    setState(() => _endConfirmMatchId = j.matchId);
  }

  /// The paused row whose card currently shows the inline End confirm.
  String? _endConfirmMatchId;

  Widget? _inlineEndConfirmFor(JourneyMatch j) {
    if (_endConfirmMatchId != j.matchId) return null;
    return _InlineConfirmBlock(
      title: 'End with ${j.profile.firstName}?',
      body: 'Permanent. Your Timeline together is kept.',
      actionLabel: 'End Journey',
      danger: true,
      onConfirm: () => _doEndSuspended(j),
      dismissLabel: 'Keep it',
      onDismiss: _clearInlineDecisions,
    );
  }

  Future<void> _doEndSuspended(JourneyMatch j) async {
    _clearInlineDecisions();
    if (j.isMock) {
      // A stand-in ends in the scenario's numbers, like every other
      // stand-in action on this screen — AND plays the closure moment,
      // because solo testing must rehearse the real experience.
      final dev = SelahDevScenario.instance;
      dev.setPausedJourneys((dev.pausedJourneys - 1).clamp(0, 99));
      dev.setEndedJourneys(dev.endedJourneys + 1);
      await _endedMoment(j);
      return;
    }
    // Same truthful-end rule as _doEndActive: no closure moment for an
    // end that didn't happen (2026-08-15, inherited upstream action 225).
    final ok = await SelahJourneyService.endJourney(j.matchId);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "End didn't go through — check your connection and try again.",
          ),
        ),
      );
      return;
    }
    await _endedMoment(j);
    await _refresh();
  }

  /// E4 — the closure moment (inherited decision 147), shared by every End on this
  /// page. The keepsake promise said at the exact second loss is felt.
  /// NOT shown on the takeover's End-and-begin path: there the new
  /// beginning is the story, and stacking closure onto it would break
  /// the no-stacked-moments rule.
  Future<void> _endedMoment(JourneyMatch j) async {
    if (!mounted) return;
    await showSelahMoment(
      context,
      closure: true,
      lines: [
        const SelahMomentLine.heading('This chapter closes.'),
        const SelahMomentLine.body(
          'Ended by choice, with dignity — the way these things '
          'should end.',
        ),
        SelahMomentLine.body(
          'Everything you and ${j.profile.firstName} built is kept. '
          'Your Timeline, your words, your story.',
        ),
        const SelahMomentLine.quiet('Take your time.'),
      ],
      ctaLabel: 'Return to Journeys',
    );
  }

  /// Every inline decision, cleared at once. Only one is ever open —
  /// one tap opens one moment — so this is exact, and it lets a single
  /// ✕ handler serve every card.
  void _clearInlineDecisions() => setState(() {
    _beginMatchId = null;
    _takeoverMatchId = null;
    _restartMatchId = null;
    _endConfirmMatchId = null;
    _activeConfirm = null;
  });

  /// Which Active Journey card is mid-confirm, and which confirm.
  /// The record beats two string fields: one card, one open moment.
  ({String matchId, bool end})? _activeConfirm;

  /// Founder-selected Connections Option 4 — 2026-08-20.
  ///
  /// The Active card keeps one clear primary action and one compact rail:
  /// View Profile · Timeline · Options. Options groups the two management
  /// actions without weakening their safeguards: choosing Pause or End here
  /// only closes the sheet and opens the existing inline confirmation. No
  /// service write happens from this sheet.
  Future<void> _showActiveJourneyOptions(JourneyMatch j) async {
    final choice = await showModalBottomSheet<_ActiveJourneyOption>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black38,
      builder: (sheetContext) =>
          _ActiveJourneyOptionsSheet(firstName: j.profile.firstName),
    );
    if (!mounted || choice == null) return;

    switch (choice) {
      case _ActiveJourneyOption.pause:
        await _pauseActive(j);
        break;
      case _ActiveJourneyOption.end:
        await _endActive(j);
        break;
    }
  }

  /// Pause the ACTIVE Journey — the Journey screen's ⋮ verb, relocated
  /// 2026-08-13, and INLINE the same day, round four (Founder: "now
  /// pause journey for active journey is a popup… popups now in
  /// connections page no longer exist"): the tap extends the card with
  /// the confirm; _doPauseActive finishes.
  Future<void> _pauseActive(JourneyMatch j) async {
    setState(() => _activeConfirm = (matchId: j.matchId, end: false));
  }

  /// End the ACTIVE Journey — same relocation, same inline round.
  Future<void> _endActive(JourneyMatch j) async {
    setState(() => _activeConfirm = (matchId: j.matchId, end: true));
  }

  /// The Active card's inline confirm, or null when this card isn't
  /// mid-confirm. Same words the glass dialogs carried.
  Widget? _activeInlineConfirmFor(JourneyMatch j) {
    final c = _activeConfirm;
    if (c == null || c.matchId != j.matchId) return null;
    if (c.end) {
      return _InlineConfirmBlock(
        title: 'End with ${j.profile.firstName}?',
        body: 'Permanent. Your Timeline together is kept.',
        actionLabel: 'End Journey',
        danger: true,
        onConfirm: () => _doEndActive(j),
        dismissLabel: 'Keep it',
        onDismiss: _clearInlineDecisions,
      );
    }
    return _InlineConfirmBlock(
      title: 'Request a pause with ${j.profile.firstName}?',
      body:
          '${_keepsPlaceLine(j.profile)} '
          '${j.profile.firstName} will choose whether to pause or continue.',
      actionLabel: 'Request Pause',
      danger: false,
      onConfirm: () => _doPauseActive(j),
      dismissLabel: 'Not now',
      onDismiss: _clearInlineDecisions,
    );
  }

  Future<void> _doPauseActive(JourneyMatch j) async {
    if (j.isMock) {
      _clearInlineDecisions();
      // A pending pause still occupies the Active slot. Only a jointly
      // confirmed pause moves the card to Paused.
      SelahDevScenario.instance.setPauseScenario(
        SelahPauseDevScenario.pauseRequesterWaiting,
      );
      await _openPauseFlow(j);
      return;
    }
    // BUG-04 (2026-08-14 audit, inherited upstream action 225 — fixed 2026-08-15): the
    // confirm is no longer cleared BEFORE the outcome is known. The two
    // recognised refusals below still clear it — the server answered,
    // just with no. An UNEXPECTED failure keeps the confirm open and
    // says so: the tap didn't happen, so the card shouldn't pretend the
    // question was answered.
    try {
      await SelahJourneyService.transitionPause(
        matchId: j.matchId,
        action: SelahPauseAction.requestPause,
        expectedVersion: j.pause.version,
      );
    } on PauseTransitionStaleException {
      if (!mounted) return;
      _clearInlineDecisions();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This Journey changed. Review it again.')),
      );
      return;
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Pause request didn't go through — check your connection and try again.",
          ),
        ),
      );
      return;
    }
    if (!mounted) return;
    _clearInlineDecisions();
    await _refresh();
    if (!mounted) return;
    await _openPauseFlow(j);
  }

  Future<void> _doEndActive(JourneyMatch j) async {
    _clearInlineDecisions();
    if (j.isMock) {
      final dev = SelahDevScenario.instance;
      dev.setActiveJourneys((dev.activeJourneys - 1).clamp(0, 99));
      dev.setEndedJourneys(dev.endedJourneys + 1);
      await _endedMoment(j);
      return;
    }
    // BUG-04 companion (2026-08-15): endJourney reports failure now.
    // The E4 closure moment only plays for an end that actually
    // happened — "This chapter closes" over a still-running Journey
    // was the worst sentence this bug could produce.
    final ok = await SelahJourneyService.endJourney(j.matchId);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "End didn't go through — check your connection and try again.",
          ),
        ),
      );
      return;
    }
    await _endedMoment(j);
    await _refresh();
  }

  // ── THE PERSON ROWS — the Activity model, everywhere ────────────────
  //
  // Founder, 2026-08-12 (third round of the person-surface work): "i
  // admit for activity i like the rows design but in the journey section
  // its not quite there yet so remove the sheet option and do rows where
  // it expands… take the activity section how it expands and copy that
  // model." So: ONE pattern for every person on this page. The sheet
  // (concept 1) and the chips panel are gone; _JourneyExpandingCard below
  // is _ActivityCard's ratified expansion — collapsed thumbnail row with
  // a chevron, tap → the mini profile (photo pager, dots, scrim, name)
  // with the state's verbs beneath — carrying Journey actions instead of
  // moves. No trailing pills on headers anymore; the arrow is the whole
  // invitation, exactly like Activity.

  void _pushTimeline(JourneyMatch j) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => JourneyTimelineScreen(
          withProfile: j.profile,
          isMock: j.isMock,
          // The road needs a position (2026-08-13 — the Map lives
          // in the Timeline's rail now). Null for potential rows,
          // which is right: no Journey, no road position yet.
          journeyStage: j.journeyStage,
        ),
      ),
    );
  }

  Future<void> _reportPerson(JourneyMatch j) async {
    await showReportProfileSheet(
      context,
      profileId: j.profile.id,
      firstName: j.profile.firstName,
      source: SelahReportSource.connections,
      profileSnapshot: j.profile,
    );
    if (mounted) await _refresh();
  }

  // _barPill REMOVED 2026-08-13 (inherited decision 160). Its only caller was the
  // introduction profile's action bar, which left the same day — the
  // three decisions now sit on the card, drawn by _CardAction like every
  // other action in this file. A second pill style for the same three
  // choices was part of why they read as two features.

  /// The primary verb for a Journey person, or null when the state offers
  /// none (busy elsewhere, or the one nudge already spent).
  ({String label, String? caption, Future<void> Function() run})? _personHero(
    JourneyMatch j,
  ) {
    if (j.status == 'potential') {
      if (j.inAnotherJourney) return null;
      // NO CAPTION — 2026-08-13 (ChatGPT card review, Founder
      // approved): "one person at a time, with both families present"
      // explained the system rather than the person. A Potential card
      // is already a choice about whether to begin; the verb says the
      // rest. The seriousness of beginning is still stated, once, at
      // the moment it matters — the begin confirm.
      // 'Begin Journey', not 'Begin with Amina' — 2026-08-15 (Founder,
      // inherited decision 172: "WHEN THEY FIRST MATCH MAKE SURE ITS BEGIN JOURNEY
      // AND ONCE BEGUN THE PILL SHOWS CONTINUE JOURNEY"). This
      // supersedes the 2026-08-13 named-verb wording and completes the
      // pair: Begin Journey → Continue Journey, the same noun both
      // times. The person's name still leads the card and the begin
      // confirm ("Begin with Yusuf?") keeps naming them at the moment
      // of commitment.
      return (
        label: 'Begin Journey',
        caption: null,
        run: () async => _startJourney(j),
      );
    }
    if (j.status == 'ended') {
      if (!SelahReleaseGates.requestNewJourneyEnabled) return null;
      final mayAsk =
          _withinPaidReturnWindow(j) &&
          !j.inAnotherJourney &&
          j.isWithinNewJourneyRequestWindow &&
          (j.isMock ? j.canRestart : _mayRequest.contains(j.matchId));
      if (!mayAsk) return null;
      // 2026-08-13 (Founder): the verb names what the tap actually
      // does — it ASKS. "Restart" promised a restart the presser cannot
      // give. The caption that carried that meaning is gone with it;
      // the ask itself still says both must agree, in the extension
      // this opens.
      return (
        label: 'Request New Journey',
        caption: null,
        run: () => _requestNewJourney(j),
      );
    }
    // A mutual Pause is symmetrical. Either Seeker may ask to resume; once
    // a request exists both sides open the same decision surface.
    if (j.pause.phase == SelahPausePhase.paused && _withinPaidReturnWindow(j)) {
      return (
        label: 'Request Resume',
        caption: null,
        run: () => _requestResume(j),
      );
    }
    if (j.pause.phase == SelahPausePhase.resumeDecisionPending) {
      final mine = j.pause.requestedBy == SelahAuth.currentUser?.id;
      return (
        label: mine ? 'Resume requested' : 'Review resume request',
        caption: null,
        run: () => _openPauseFlow(j),
      );
    }
    if (j.pause.phase == SelahPausePhase.paused) return null;
    return (
      label: 'Open decision',
      caption: null,
      run: () => _openPauseFlow(j),
    );
  }

  /// The state's standing fact when there is no hero: busy elsewhere, the
  /// spent nudge, or the cooling period.
  String? _personHeroFact(JourneyMatch j) {
    // Paused rows keep status 'active' (suspended_by is what parks
    // them), so `status != 'active'` alone silently excluded exactly
    // the paused-but-busy case the Founder asked to see (2026-08-13).
    if (j.inAnotherJourney && (j.status != 'active' || j.isSuspended)) {
      return '${j.profile.firstName} is in a Journey with someone else '
          'right now.';
    }
    if (j.status == 'ended' && !SelahReleaseGates.requestNewJourneyEnabled) {
      return null;
    }
    if (SelahReleaseGates.requestNewJourneyEnabled &&
        (j.status == 'ended' || j.isSuspended)) {
      return _availableReturns.contains(j.matchId)
          ? 'Available to reconnect'
          : 'Not currently available';
    }
    if (j.status == 'ended' && j.isInCoolingPeriod) {
      return j.restartAvailableIn;
    }
    if (j.isSuspended && !j.inAnotherJourney) {
      if (j.pause.phase == SelahPausePhase.resumeDecisionPending) {
        return j.pause.requestedBy == SelahAuth.currentUser?.id
            ? 'Waiting for ${j.profile.firstName} to decide.'
            : '${j.profile.firstName} has asked to resume.';
      }
      if (!_withinPaidReturnWindow(j)) {
        return AppState.instance.plan == SelahPlan.one
            ? 'Only your five most recent Paused Journeys can be requested.'
            : '${SelahMembershipCatalog.seekerOneTitle} is needed to request a return.';
      }
      // The persistent card subtitle already says the Journey is Paused and
      // the primary action says "Request Resume". Repeating both facts as a
      // sentence made the expanded card denser without adding information.
      return null;
    }
    return null;
  }

  /// A Shepherd Suggestion's profile: the read-only screen with the three
  /// decisions as its bar (ascending commitment, Consider furthest right —
  /// the same order the Activity cards ratified on 2026-08-03).
  /// Opens the introduced person's profile, read-only.
  ///
  /// NO CHIP, NO ACTION BAR — 2026-08-13 (inherited decision 160, Founder). Both
  /// left in the same change and for one reason: the decisions moved to
  /// the CARD, where Pass, Save and Consider now sit under View Profile.
  /// Having them in both places meant the same three choices rendered
  /// two different ways, one screen apart.
  ///
  /// The "Introduced by X" chip in the top right became a "Suggested by
  /// X" line under the name — same fact, said where the person is
  /// rather than in the corner of their photo, and with the same shield
  /// glyph the Connections card uses for it.
  void _openSuggestionProfile(ShepherdSuggestion s) {
    pushSelahConnectionsProfile(
      context,
      profile: s.profile,
      suggestedBy: s.suggestedBy,
    );
  }

  void _moveLocalProfile(SeekerProfile profile, _Move move) {
    final destination = switch (move) {
      _Move.consider => SelahActivityTestState.considered,
      _Move.save => SelahActivityTestState.saved,
      _Move.pass => SelahActivityTestState.passed,
      _Move.unsave => null,
    };
    if (destination == null) return;
    SelahDevScenario.instance.moveLocalProfile(profile.id, destination);
    if (mounted) setState(() {});
  }

  void _hideLocalProfile(SeekerProfile profile) {
    SelahDevScenario.instance.hideLocalProfile(profile.id);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final potential = AppState.instance.potentialJourneys;
    final active = AppState.instance.activeJourneys;
    final dev = SelahDevScenario.instance;
    late final List<SeekerProfile> passed;
    late final List<SeekerProfile> saved;
    late final List<SeekerProfile> considered;
    if (!SelahDeveloperAccess.canUseDeveloperTools) {
      passed = AppState.instance.declined;
      saved = AppState.instance.saved;
      considered = AppState.instance.outgoingLikes;
    } else {
      final buckets = composeSelahActivityTestBuckets(
        scenario: dev,
        realConsidered: AppState.instance.outgoingLikes,
        realSaved: AppState.instance.saved,
        realPassed: AppState.instance.declined,
        viewerGender: AppState.instance.gender,
      );
      passed = buckets.passed;
      saved = buckets.saved;
      considered = buckets.considered;
    }

    return Container(
      // 2026-07-25: gender-matched gradient (inherited decision 094), widened from
      // Profile-only to all in-app post-onboarding screens per Founder
      // instruction — see SelahColors.genderGradient() doc comment.
      decoration: SelahAppGoldDecoration(
        gradient: SelahColors.genderGradient(AppState.instance.gender),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text('Connections', style: SelahText.heading(size: 26)),
            ),
            // 2026-07-29 (Founder review — Connections-page redesign,
            // Option 1 of 5 presented): Journeys/Activity segmented
            // toggle replaces the old flat MATCHES-then-everything
            // layout, and the old "Incoming Potentials — SELAH One" tease
            // that used to sit here stays removed (inherited decision 119).
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
              // 2026-08-03 (Founder: "as I swipe left to right you can
              // see the app moving in motion — can you make the top tab
              // move in motion with it also").
              //
              // `_pagerPos` is the pager's live fractional offset, not the
              // settled page. At 0.4 through a swipe the pill sits 40% of
              // the way across, so the control follows the finger instead
              // of snapping once the gesture ends.
              // Shared with the Shepherd's Network tab since 2026-08-13
              // — same widget, same behaviour, different labels.
              child: SelahSegmentedToggle(
                labels: _kSegmentLabels,
                position: _pagerPos,
                badges: _segmentBadges,
                onChanged: (i) => SelahSegmentedMotion.animateToPage(_pager, i),
              ),
            ),
            // SWIPEABLE 2026-08-01 (Founder: "allow the UI when I swipe
            // left and right to move between Journeys and Activity").
            //
            // Was a plain ListView swapping its children when the toggle
            // changed — the toggle was the only way across. A two-page
            // PageView keeps the toggle working AND makes the horizontal
            // swipe do the obvious thing, with the pill tracking whichever
            // one you used.
            //
            // Both pages stay built, so scroll position in each survives
            // switching between them. That matters here: Activity can be
            // long, and losing your place every time you glanced at
            // Journeys would be worse than the missing gesture.
            Expanded(
              child: PageView(
                controller: _pager,
                physics: SelahSegmentedMotion.pagePhysics,
                // No onPageChanged — _onPagerScroll already tracks
                // position on every frame, including the settle at the
                // end of a swipe. A second callback writing a second
                // field is what created the unused one.
                children: [
                  ListView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                    children: _journeysChildren(
                      active: active,
                      potential: potential,
                    ),
                  ),
                  ListView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                    children: _activityChildren(
                      considered: considered,
                      saved: saved,
                      passed: passed,
                    ),
                  ),
                  // CENTRED WHEN EMPTY — 2026-08-13 (Founder: "the
                  // Introductions empty state icon and text placement do
                  // not match other empty states... the Notifications
                  // empty state is centred").
                  //
                  // SelahEmptyState was always centred; it had nothing to
                  // centre IN. Inside a ListView it takes only the height
                  // of its own content and sits wherever the previous
                  // child left off, so it read as pinned under the
                  // header. Notifications puts it in an Expanded, which
                  // is what makes Center mean anything — same here now.
                  _introductionsPage(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// History is visible to every plan. Entitlement controls only whether the
  /// signed-in person may initiate a return from one of their five most
  /// recent rows in that state; incoming decisions remain actionable.
  bool _withinPaidReturnWindow(JourneyMatch journey) {
    if (AppState.instance.plan != SelahPlan.one) return false;
    final limits = SelahEntitlements.one;
    final rows = journey.status == 'ended' ? _ended : _suspended;
    final window = journey.status == 'ended'
        ? limits.endedReturnWindow
        : limits.pausedReturnWindow;
    return rows.take(window).any((row) => row.matchId == journey.matchId);
  }

  /// Developer Active previews used to look fully interactive and then stop
  /// at the door with a bottom snackbar because their fake match id had no
  /// server row. A developer tool must never create that trap. If an old
  /// preview card survives a hot reload, entering it now finds or seeds a
  /// real walkable Journey and opens that instead.
  Future<void> _enterJourney(JourneyMatch selected) async {
    var target = selected;
    String? seedResult;
    if (selected.isMock) {
      try {
        var rows = await SelahJourneyService.fetchJourneyMatches(
          statuses: const ['active'],
        );
        var live = rows
            ?.where((journey) => !journey.isMock && !journey.isSuspended)
            .toList();
        if (live == null || live.isEmpty) {
          seedResult = await SelahJourneyService.devSeedJourney();
          rows = await SelahJourneyService.fetchJourneyMatches(
            statuses: const ['active'],
          );
          live = rows
              ?.where((journey) => !journey.isMock && !journey.isSuspended)
              .toList();
        }
        if (live == null || live.isEmpty) {
          if (!mounted) return;
          await showSelahMoment(
            context,
            mark: Icons.cloud_off_outlined,
            lines: [
              const SelahMomentLine.heading('Journey unavailable'),
              SelahMomentLine.body(
                seedResult ??
                    'A live test Journey could not be created for this account.',
              ),
              const SelahMomentLine.quiet(
                'Open the developer panel and choose Open live Journey to try again.',
              ),
            ],
            ctaLabel: 'Back to Connections',
          );
          return;
        }
        target = live.first;
        SelahDevScenario.instance.refreshJourneys();
      } catch (error) {
        debugPrint('SELAH dev Journey entry failed — $error');
        if (!mounted) return;
        await showSelahMoment(
          context,
          mark: Icons.cloud_off_outlined,
          lines: const [
            SelahMomentLine.heading('Journey unavailable'),
            SelahMomentLine.body(
              'The live test Journey could not be opened. Check the connection and try again.',
            ),
          ],
          ctaLabel: 'Back to Connections',
        );
        return;
      }
    }
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => JourneyFlowScreen(
          matchId: target.matchId,
          profile: target.profile,
          onOpenShepherd: widget.onNavigateToShepherd,
        ),
      ),
    );
  }

  List<Widget> _journeysChildren({
    required List<JourneyMatch> active,
    required List<JourneyMatch> potential,
  }) {
    final currentUserId = SelahAuth.currentUser?.id;
    final incomingPaused = _suspended
        .where(
          (journey) =>
              journey.pause.phase == SelahPausePhase.resumeDecisionPending &&
              journey.pause.requestedBy != null &&
              journey.pause.requestedBy != currentUserId,
        )
        .toList(growable: false);
    final ordinaryPaused = _suspended
        .where((journey) => !incomingPaused.contains(journey))
        .toList(growable: false);

    Widget pausedCard(JourneyMatch journey) {
      final pausedFor = journey.pausedFor;
      return _JourneyExpandingCard(
        j: journey,
        expansionController: _expansionController,
        subtitle:
            (journey.pause.phase == SelahPausePhase.resumeDecisionPending
                ? 'Resume decision pending'
                : 'Paused') +
            (pausedFor.isEmpty ? '' : ' · $pausedFor'),
        hero: _personHero(journey),
        heroFact: _personHeroFact(journey),
        showStateLine: _personHeroFact(journey) != null,
        showTimeline: true,
        onTimeline: () => _pushTimeline(journey),
        canEnd: true,
        onEnd: () => _endSuspended(journey),
        onReport: () => _reportPerson(journey),
        compatibilityRevealed: true,
        inlineExtension: _inlineEndConfirmFor(journey),
        onDismissExtension: _clearInlineDecisions,
      );
    }

    Widget endedCard(JourneyMatch journey) => _JourneyExpandingCard(
      j: journey,
      expansionController: _expansionController,
      subtitle: journey.inAnotherJourney
          ? 'Ended · in another Journey now'
          : !SelahReleaseGates.requestNewJourneyEnabled || journey.canRestart
          ? 'Ended'
          : 'Ended — ${journey.restartAvailableIn.toLowerCase()}',
      hero: _personHero(journey),
      heroFact: _personHeroFact(journey),
      showStateLine: _personHeroFact(journey) != null,
      showTimeline: true,
      onTimeline: () => _pushTimeline(journey),
      canEnd: false,
      onEnd: null,
      onReport: () => _reportPerson(journey),
      dimmed: true,
      compatibilityRevealed: true,
      inlineExtension: _inlineRestartFor(journey),
      onDismissExtension: _clearInlineDecisions,
    );

    return [
      // ACTIVE JOURNEY — 2026-08-01 (Founder: "active journey should be
      // more stand out then the rest").
      //
      // Every section header on this page was identical white54 chapter
      // label, so the one Journey a Seeker is actually IN looked exactly
      // like the list of people who haven't replied. SELAH allows one
      // Active Journey at a time — it is the single most important thing
      // on the screen and should not have to be searched for.
      //
      // Emphasis is carried by the label (full white, not white54) and by
      // the card itself (_ActiveJourneyCard — brighter fill, real
      // border, larger photo), NOT by a new accent colour. Introducing
      // one here would collide with the gender gradient behind it.
      _ConnectionsSectionHeading(title: 'Active Journey', emphasised: true),
      SizedBox(height: 8),
      if (active.isEmpty)
        Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: SelahEmptyState(
            icon: Icons.forum_outlined,
            message: 'Start a Journey to see it here.',
          ),
        )
      else
        ...active.map((j) {
          // TRAILING ACTION — Founder, 2026-08-10: "active journey should be
          // enter", styled like POTENTIAL's "Start Journey", so every Journey
          // row states its action on the right instead of leaving three of the
          // four sections with a bare chevron.
          //
          // THE WHOLE-CARD TAP WAS REMOVED LATER THE SAME DAY, at Founder
          // instruction: "wherever I click goes into enter journey but that
          // ruins the enter journey button anyway, so make sure the profile
          // card clicked does nothing so only the 2 buttons are action
          // buttons."
          //
          // The comment that stood here argued the opposite — that a card
          // tappable everywhere is better than one with a button that is the
          // only route. It was wrong for this card. Two labelled pills sit on
          // it; a card-wide tap makes the primary one decorative, and makes
          // the secondary one a trap, because everything around "Timeline"
          // silently does something else.
          return _ActiveJourneyCard(
            profile: j.profile,
            onEnter: () {
              _expansionController.collapseAll();
              unawaited(_enterJourney(j));
            },
            onTimeline: () {
              _expansionController.collapseAll();
              Navigator.of(context).push(
                MaterialPageRoute(
                  // isMock: a dev stand-in has no match row; the screen
                  // says so instead of showing an empty story that reads
                  // as a bug (Founder, 2026-08-12). journeyStage feeds
                  // the Timeline's road (2026-08-13).
                  builder: (_) => JourneyTimelineScreen(
                    withProfile: j.profile,
                    isMock: j.isMock,
                    journeyStage: j.journeyStage,
                  ),
                ),
              );
            },
            // Same sheet and same source as every other card on this page,
            // so a report raised from an Active Journey is indistinguishable
            // from one raised anywhere else — which is what the person
            // reporting should be able to assume.
            onReport: () async {
              _expansionController.collapseAll();
              await showReportProfileSheet(
                context,
                profileId: j.profile.id,
                firstName: j.profile.firstName,
                source: SelahReportSource.connections,
                profileSnapshot: j.profile,
              );
              if (mounted) await _refresh();
            },
            // THE ⋮'S VERBS, RELOCATED HERE — 2026-08-13 (Founder:
            // "remove it.. put it in main page section"). View Profile
            // was the Timeline bubble's job until today; the bubble
            // stays, but the person is one tap from the card now too.
            onViewProfile: () {
              _expansionController.collapseAll();
              pushSelahConnectionsProfile(context, profile: j.profile);
            },
            onOptions: () {
              _expansionController.collapseAll();
              if (j.pause.isPending) {
                unawaited(_openPauseFlow(j));
              } else {
                _showActiveJourneyOptions(j);
              }
            },
            // Round four: the confirms extend this card in place —
            // no popups on this page.
            inlineConfirm: _activeInlineConfirmFor(j),
            onDismissConfirm: _clearInlineDecisions,
            // NOT the stage label — that came out on Founder instruction,
            // 2026-08-10. This is the one Journey state that is waiting on
            // the member's FAMILY rather than on them, and it holds the
            // Journey for 48 hours.
            //
            // Removing the stage line took it with it, and left
            // _openReviews written by a batched query and read by nothing —
            // the shape of the `profile_complete` defect in the 2026-07-26
            // audit, inverted. Restored as a chip that appears only while a
            // review is open, so the ordinary card stays as asked.
            reviewOpen: _openReviews.contains(j.matchId),
            decisionPending: j.pause.isPending,
            // BEGIN vs CONTINUE, Founder 2026-08-10: "either begin journey
            // if user started or continue journey if user is continuing".
            //
            // No new state was added for this. A Journey that is still on
            // its opening stage has not moved yet, whatever the member has
            // hasBegun REINSTATED 2026-08-15 (inherited decision 174, superseding
            // 173 same day). The Founder's screenshot settled the rule:
            // an Active Journey STILL AT ITS FIRST STAGE reads "Begin
            // Journey" — Begin holds right up until the Journey itself
            // moves, and "Continue Journey" from then on. Read off the
            // stage: one source of truth, no opened-flag to maintain.
            hasBegun: j.journeyStage != SelahJourneyStages.all.first.value,
          );
        }),

      SizedBox(height: 20),
      // RENAMED 2026-08-03, Founder approved: "Potential Journeys"
      // suggested uncertainty, when these are confirmed mutual likes
      // waiting for the user to begin. "Queue" also carries the
      // one-Active-Journey-at-a-time rule without stating it — things in
      // a queue are waiting their turn by definition.
      _ConnectionsSectionHeading(title: 'Potential Journeys'),
      SizedBox(height: 8),
      if (potential.isEmpty)
        Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          // 2026-07-26: check_circle_outline replaced favorite_border
          // (Founder: app-wide heart-icon removal).
          //
          // CHANGED AGAIN 2026-08-01 (Founder: "the Considered icon
          // should be a tick, which means the Potential Journey icon
          // needs to change"). Correct — Considered has the stronger
          // claim on a tick, and two ticks on one screen meaning
          // different things is worse than either choice alone.
          //
          // compare_arrows reads as two people having moved toward each
          // other, which is precisely what a mutual Consider is. Not a
          // heart, per the app-wide rule.
          child: SelahEmptyState(
            icon: Icons.compare_arrows,
            message:
                "Your matches will appear here when you're ready to begin.",
          ),
        )
      else
        ...potential.map(
          (j) => _JourneyExpandingCard(
            j: j,
            expansionController: _expansionController,
            // "In another Journey": beginning would be refused (the
            // server's other-party cap guard), so the card states it and
            // offers no verb — a fact, never a disabled button.
            subtitle: j.inAnotherJourney
                ? 'In another Journey right now'
                : 'Ready to start',
            hero: _personHero(j),
            heroFact: _personHeroFact(j),
            // The person and the actions, nothing else. When there IS
            // no verb (busy elsewhere) _personHeroFact still speaks —
            // that line is the reason, not an explanation.
            showStateLine: _personHeroFact(j) != null,
            showTimeline: false,
            onTimeline: null,
            canEnd: false,
            onEnd: null,
            onReport: () => _reportPerson(j),
            // B3: when this row is the one mid-decision — begin
            // confirm below the cap, takeover at it — its card
            // extends with that moment (null for everyone else).
            inlineExtension: _inlinePotentialFor(j),
            onDismissExtension: _clearInlineDecisions,
          ),
        ),

      // The live Journey page keeps its original four-section hierarchy:
      // Active, Potential, Paused, Ended. Complete historical browsing now
      // has a separate Profile route instead of replacing these sections
      // with a nested History toggle (Founder correction, 2026-09-21).
      SizedBox(height: 20),
      _ConnectionsSectionHeading(title: 'Paused Journeys'),
      SizedBox(height: 8),
      if (_suspended.isEmpty)
        Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: SelahEmptyState(
            icon: Icons.pause_circle_outlined,
            message: 'Paused Journeys will appear here.',
          ),
        )
      else ...[
        if (incomingPaused.isNotEmpty) ...[
          _ConnectionsSubsectionLabel('REQUESTS FOR YOU'),
          SizedBox(height: 8),
          ...incomingPaused.map(pausedCard),
          if (ordinaryPaused.isNotEmpty) SizedBox(height: 8),
        ],
        if (ordinaryPaused.isNotEmpty) ...[
          if (incomingPaused.isNotEmpty)
            _ConnectionsSubsectionLabel('YOUR PAUSED JOURNEYS'),
          if (incomingPaused.isNotEmpty) SizedBox(height: 8),
          ...ordinaryPaused.map(pausedCard),
        ],
      ],

      SizedBox(height: 20),
      _ConnectionsSectionHeading(title: 'Ended Journeys'),
      SizedBox(height: 8),
      if (_ended.isEmpty)
        Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: SelahEmptyState(
            icon: Icons.history,
            message: 'Ended Journeys will appear here.',
          ),
        )
      else
        ..._ended.map(endedCard),
    ];
  }

  /// INTRODUCTIONS — its own page, 2026-08-06.
  ///
  /// Founder chose this over moving it to the Shepherd tab. The deciding
  /// question was whose task it is: an introduction is an INBOUND item
  /// waiting on the Seeker. Filing it under Shepherd would sort it by who
  /// sent it rather than by what you need to do — and the Shepherd tab is
  /// somewhere you visit a handful of times ever, where Connections is
  /// daily.
  ///
  /// ============ A NAMING COLLISION, REINSTATED DELIBERATELY ============
  ///
  /// "Introductions" was REJECTED for this feature on 2026-08-05, because
  /// "Family Introductions" already names the Family Stage of an ACTIVE
  /// Journey — two families being introduced to each other. Sitting above
  /// Considered and Saved, it read as though a match had already happened
  /// and progressed that far.
  ///
  /// The Founder has now chosen it anyway (2026-08-06), and the collision
  /// is real but smaller than it was: this is no longer inside Activity
  /// pretending to be a decision you made, it is its own segment. The word
  /// is also the right one culturally — a Shepherd putting someone forward
  /// IS an introduction in the sense this community means it.
  ///
  /// RAISED, NOT WORKED AROUND. If the two ever need separating, rename
  /// the Family Stage rather than this — it has the qualifier available
  /// ("Family Introductions") and this does not.
  /// THE SUBTITLE IS GONE — 2026-08-13 (inherited decision 157, Founder: "remove
  /// this subtitle completely. The section should not explain what
  /// introductions are"). No other section on this page explains itself;
  /// CONSIDERED, SAVED and PASSED carry a header and nothing else, and a
  /// line of instruction under one of four headers is the thing that
  /// looked out of place.
  ///
  /// The empty case is NOT here — see the Introductions page below. It
  /// needs the full height to centre in, which a list of children cannot
  /// give it.
  List<Widget> _introductionsChildren() {
    final pending = _undecidedSuggestions;
    return [
      // ONE CARD, ALL FOUR SECTIONS — 2026-08-13 (Founder: "a user cannot
      // tell that Introductions cards were built separately from the
      // newer profile cards"). _SuggestionCard is gone; this is the same
      // _ActivityCard that Considered, Saved and Passed use, with the
      // introduction kind.
      //
      // View Profile remains the primary action. Pass, Save, Consider and
      // Compatibility use the same compact secondary deck as every other
      // Activity state, so an Introduction does not become a one-action
      // dead end after its developer fixture is staged.
      ...pending.map((s) {
        final local = _isIntroductionPreview(s);
        return _ActivityCard(
          expansionController: _expansionController,
          key: ValueKey<String>('connections-activity-widget-${s.profile.id}'),
          profile: s.profile,
          kind: _ActivityKind.introduction,
          suggestedByOverride: s.suggestedBy,
          isLocalTestProfile: local,
          onLocalMove: local
              ? (move) => _moveLocalProfile(s.profile, move)
              : null,
          onLocalHidden: local ? () => _hideLocalProfile(s.profile) : null,
          onViewProfile: () => _openSuggestionProfile(s),
        );
      }),
    ];
  }

  List<Widget> _activityChildren({
    required List<SeekerProfile> considered,
    required List<SeekerProfile> saved,
    required List<SeekerProfile> passed,
  }) {
    return [
      // CONSIDERED — outgoing Likes (renamed per inherited decision 099 /
      // inherited upstream action 138; underlying AppState field name unchanged).
      SizedBox(height: 28),
      _ConnectionsSectionHeading(title: 'Considered'),
      SizedBox(height: 10),
      if (considered.isEmpty)
        Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          // CHANGED 2026-08-01 (Founder: "the Considered icon should be a
          // tick"). Was pending_outlined (a "…" circle). The tick had to
          // be freed up first — Potential Journeys was using it, and now
          // uses converging arrows instead.
          child: SelahEmptyState(
            icon: Icons.check_circle_outline,
            message: "Profiles you've considered will appear here.",
          ),
        )
      else
        ...considered.map((p) {
          final local = _isLocalTestProfile(p);
          final suggestedBy = _localIntroductionAttribution(p);
          return _ActivityCard(
            expansionController: _expansionController,
            key: ValueKey<String>('connections-activity-widget-${p.id}'),
            profile: p,
            kind: _ActivityKind.considered,
            suggestedByOverride: suggestedBy,
            isLocalTestProfile: local,
            onLocalMove: local ? (move) => _moveLocalProfile(p, move) : null,
            onLocalHidden: local ? () => _hideLocalProfile(p) : null,
            onViewProfile: suggestedBy == null
                ? null
                : () => pushSelahConnectionsProfile(
                    context,
                    profile: p,
                    suggestedBy: suggestedBy,
                  ),
          );
        }),

      // SAVED.
      SizedBox(height: 28),
      _ConnectionsSectionHeading(title: 'Saved'),
      SizedBox(height: 10),
      if (saved.isEmpty)
        Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: SelahEmptyState(
            icon: Icons.bookmark_border,
            message: "Profiles you've saved will appear here.",
          ),
        )
      else
        ...saved.map((p) {
          final local = _isLocalTestProfile(p);
          final suggestedBy = _localIntroductionAttribution(p);
          return _ActivityCard(
            expansionController: _expansionController,
            key: ValueKey<String>('connections-activity-widget-${p.id}'),
            profile: p,
            kind: _ActivityKind.saved,
            suggestedByOverride: suggestedBy,
            isLocalTestProfile: local,
            onLocalMove: local ? (move) => _moveLocalProfile(p, move) : null,
            onLocalHidden: local ? () => _hideLocalProfile(p) : null,
            onViewProfile: suggestedBy == null
                ? null
                : () => pushSelahConnectionsProfile(
                    context,
                    profile: p,
                    suggestedBy: suggestedBy,
                  ),
          );
        }),

      // PASSED means profile decisions, never declined Journey requests.
      // Membership changes only this display window; the underlying list
      // and decision persistence are preserved without deleting anything.
      SizedBox(height: 28),
      Builder(
        builder: (context) {
          final limits = SelahSeekerPlanLimits.of(AppState.instance.plan);
          final recentPassed = limits.recentDeclined(passed);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ConnectionsSectionHeading(title: 'Passed'),
              SizedBox(height: 10),
              if (limits.recentDeclinedProfiles == 0)
                SelahMembershipHistoryLock(
                  key: const ValueKey('connections-passed-membership-lock'),
                  description:
                      'Revisit your last '
                      '${SelahSeekerPlanLimits.one.recentDeclinedProfiles} '
                      'declined profiles with ${SelahMembershipCatalog.seekerOneTitle}. Your existing '
                      'profile decisions are kept.',
                )
              else if (recentPassed.isEmpty)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: SelahEmptyState(
                    icon: Icons.close,
                    message: "Profiles you've passed will appear here.",
                  ),
                )
              else
                // Passed cards use the same expanded compatibility action as
                // Considered and Saved. See APP/Premium/Profile Unlocks/
                // Summary.md; the older prohibition was reversed.
                ...recentPassed.map((p) {
                  final local = _isLocalTestProfile(p);
                  final suggestedBy = _localIntroductionAttribution(p);
                  return _ActivityCard(
                    expansionController: _expansionController,
                    key: ValueKey<String>(
                      'connections-activity-widget-${p.id}',
                    ),
                    profile: p,
                    kind: _ActivityKind.passed,
                    suggestedByOverride: suggestedBy,
                    isLocalTestProfile: local,
                    onLocalMove: local
                        ? (move) => _moveLocalProfile(p, move)
                        : null,
                    onLocalHidden: local ? () => _hideLocalProfile(p) : null,
                    onViewProfile: suggestedBy == null
                        ? null
                        : () => pushSelahConnectionsProfile(
                            context,
                            profile: p,
                            suggestedBy: suggestedBy,
                          ),
                  );
                }),
            ],
          );
        },
      ),
    ];
  }
}

// 2026-07-29 (Founder review — Connections-page redesign, Option 1 of 5
// presented in chat): two-segment "Journeys / Activity" pill toggle.
//
// CHANGED 2026-08-01 (Founder: "when we choose Journey or Activity it's
// white but make it be the same as navigation bar please, transparent").
//
// Was a solid white fill with dark text — the only opaque surface on the
// screen, so it read as a different app's control sitting on SELAH's
// gradient, and it fought the floating nav bar directly below it for
// attention.
//
// The values below are lifted from floating_nav_bar.dart rather than
// invented, so the two controls are literally the same material:
//
//   track     white 0.10, border white 0.18, blur 22   (the bar)
//   selected  white 0.28, border white 0.12            (the blob)
//
// If the nav bar's glass is ever retuned, retune this with it.
/// The three labels, in page order. Founder 2026-08-06.
///
/// "Introductions", NOT "Suggestions" — Founder's word. See the naming
/// conflict recorded at _IntroductionsPage: this label was previously
/// rejected for colliding with the Family Stage, and has been reinstated
/// deliberately.
const List<String> _kSegmentLabels = ['Journeys', 'Activity', 'Introductions'];

/// One section-heading component for every repeatable Connections list.
/// Introductions does not use it: the selected segment already says
/// Introductions, so repeating the word immediately below was removed by the
/// Founder on 2026-08-25.
class _ConnectionsSectionHeading extends StatelessWidget {
  final String title;
  final bool emphasised;

  const _ConnectionsSectionHeading({
    required this.title,
    this.emphasised = false,
  });

  @override
  Widget build(BuildContext context) {
    const style = SelahConnectionsHeadingStyle.accentMarker;
    final quiet = emphasised ? SelahColors.foreground : SelahColors.ink(0.54);
    final accent = SelahColors.accentOnCanvas;

    switch (style) {
      case SelahConnectionsHeadingStyle.chapterLeft:
        return Text(
          title.toUpperCase(),
          style: SelahText.chapterLabel(color: quiet),
        );
      case SelahConnectionsHeadingStyle.titleLeft:
        return Text(
          title,
          style: SelahText.heading(
            size: emphasised ? 18 : 16,
            color: emphasised ? SelahColors.foreground : SelahColors.ink(0.82),
          ),
        );
      case SelahConnectionsHeadingStyle.centredRule:
        return Row(
          children: [
            Expanded(
              child: Container(height: 0.6, color: SelahColors.ink(0.16)),
            ),
            const SizedBox(width: 10),
            Text(
              title.toUpperCase(),
              style: SelahText.chapterLabel(color: quiet),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(height: 0.6, color: SelahColors.ink(0.16)),
            ),
          ],
        );
      case SelahConnectionsHeadingStyle.accentMarker:
        return Row(
          children: [
            Container(
              width: 3,
              height: 28,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                title,
                style: SelahText.body(
                  size: emphasised ? 16 : 14.5,
                  color: emphasised
                      ? SelahColors.foreground
                      : SelahColors.ink(0.82),
                ),
              ),
            ),
          ],
        );
      case SelahConnectionsHeadingStyle.countSplit:
        return Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: SelahText.heading(
                  size: emphasised ? 17 : 15.5,
                  color: emphasised
                      ? SelahColors.foreground
                      : SelahColors.ink(0.82),
                ),
              ),
            ),
            Container(
              width: 34,
              height: 1,
              color: accent.withValues(alpha: 0.48),
            ),
          ],
        );
    }
  }
}

// _SegmentedToggle and _UnseenDot MOVED 2026-08-13 to
// widgets/selah_segmented_toggle.dart as SelahSegmentedToggle. The Shepherd's
// Network tab needed the same control and could not reach a private class,
// so it had grown its own pair of plain rounded buttons — one job, two
// looks. Every design note that used to sit here moved with the code.

//  added 2026-08-05 with Shepherd Suggestions. It behaves like
//  for actions (you can still Unlock or Report), but is its own
// kind so the card can never be mistaken for something you decided on
// yourself — you didn't; your Shepherd did.
/// ONE CARD METRIC FOR THE WHOLE APP — 2026-08-05 (Founder: "look at how
/// the cards are different sizes. I kinda want all cards to be the same for
/// a cleaner UI, this includes the Mentor cards on the Mentor tab").
///
/// Every list row that shows a person — Shepherd Suggestions, Considered,
/// Saved, Passed, and the Shepherd cards on the Mentor tab — now uses these
/// three numbers. They were previously chosen per-widget: 52pt thumbnails
/// here, 56×64 on suggestions, 44 and 36 on the Mentor tab, with padding of
/// 12, 13 and 16. Nothing was wrong individually; together they read as
/// four different design systems on four screens.
// SelahCardMetrics MOVED to theme/selah_card_metrics.dart — 2026-08-15
// (inherited decision 171, audit UI-03). Four screens were importing THIS 4,000-line
// file to reach three constants; a design token lives in the theme. The
// doc comment travelled with it, values unchanged, and every former
// `show SelahCardMetrics` importer now imports the theme file directly.

/// A profile thumbnail that survives a profile with no photos.
///
/// ADDED 2026-08-13 (inherited decision 157) and it is the precondition for
/// everything else in that decision. `SeekerProfile.photoUrl` is
/// `photos.first` and THROWS on an empty list, and _ActivityCard called
/// it unguarded — collapsed thumb and expanded hero both. That is the
/// reason the Introductions card was built as its own widget on
/// 2026-08-05 rather than reusing this one: "_ActivityCard's photo fills
/// the row, so a profile without photos became a full-height grey
/// rectangle (the Founder's screenshot)".
///
/// Fixing the cause is what lets the two cards become one. It also
/// closes a latent crash that was only ever hidden by real profiles
/// happening to carry photos — the dev panel's no-pool stand-ins are
/// built with `photos: const []`, and so is every counterpart card.
Widget _cardThumb(SeekerProfile p, {required double size, double radius = 0}) {
  final child = p.photos.isEmpty
      ? ColoredBox(
          color: SelahColors.surfaceFill,
          child: Icon(
            Icons.person_outline,
            color: SelahColors.foregroundMuted,
            size: size * 0.4,
          ),
        )
      : SelahProfileImage(p.photoUrl, width: size, height: size);
  return ClipRRect(
    borderRadius: BorderRadius.circular(radius),
    child: SizedBox(width: size, height: size, child: child),
  );
}

/// INTRODUCTION JOINED 2026-08-13 (inherited decision 157, Founder: "a user cannot
/// tell that Introductions cards were built separately from the newer
/// profile cards"). It is a full member — same card, same expansion and
/// same photo handling. Toggle-created rows take the same production form;
/// their non-UUID ids and explicit callbacks keep every mutation local.
enum _ActivityKind { considered, saved, passed, introduction }

// _SuggestionCard REMOVED 2026-08-13 (inherited decision 157, Founder: "a user
// cannot tell that Introductions cards were built separately from the
// newer profile cards"). Introductions now use _ActivityCard with the
// introduction kind.
//
// ITS TWO REASONS FOR EXISTING, AND WHAT HAPPENED TO THEM. The class
// header argued both, on 2026-08-05:
//
//   VISUAL — "_ActivityCard's photo fills the row, so a profile without
//   photos became a full-height grey rectangle (the Founder's
//   screenshot)". TRUE AT THE TIME AND STILL TRUE THIS MORNING:
//   _ActivityCard called photoUrl (= photos.first) unguarded on the
//   thumb, and indexed photos[clamp(0, -1)] on the hero — the first
//   throws on an empty list, the second fails on the clamp. Both are
//   fixed now (_cardThumb, and the hero's own guard), which is what made
//   the merge safe rather than a re-run of that screenshot. The fix also
//   closes a latent crash that only ever stayed hidden because real
//   profiles happen to carry photos.
//
//   BEHAVIOURAL — the retired class once kept Introduction decisions off
//   the row. That is historical, not current product truth: every row now
//   uses the shared Activity decisions. Local test rows route those same
//   controls through SelahDevScenario rather than production writes.
//
// Deleted rather than left unused — an unreferenced widget is one
// somebody re-adds a call to six weeks later without reading why it
// stopped being used.

/// The one-state transitions available from an Activity card. Consider,
/// Save and Pass are mutually exclusive; choosing one replaces the current
/// state. `unsave` returns a saved real profile to no decision state.
enum _Move { consider, pass, save, unsave }

class _ActivityCard extends StatefulWidget {
  final SeekerProfile profile;
  final _ActivityKind kind;
  final SelahConnectionsExpansionController expansionController;

  /// Introduction cards receive the source directly. Other Activity states
  /// keep reading AppState so the real Shepherd attribution follows a person
  /// after the Seeker makes a decision.
  final String? suggestedByOverride;

  /// Internal truth boundary for a card created through developer controls.
  /// It never changes the card's product presentation; it only chooses the
  /// local-only action/report paths.
  final bool isLocalTestProfile;

  final ValueChanged<_Move>? onLocalMove;
  final VoidCallback? onLocalHidden;

  // Real introductions receive their source directly from the suggestion
  // row. Considered/Saved/Passed cards still read AppState.suggestedBy(),
  // populated by _loadSuggestions(), so a Shepherd's involvement survives
  // whichever list the person enters. Local preview rows never enter that
  // app-wide map; their explicit source is part of keeping mock and account
  // truth separate.

  /// Opens the read-only profile — introductions only.
  final VoidCallback? onViewProfile;

  /// `subtitle` was removed 2026-08-01 (Founder: "I feel we should remove
  /// the words 'waiting to hear back' completely").
  ///
  /// Taken further than asked, deliberately. The other two values it ever
  /// held were "Saved" and "Passed" — sitting directly under headers
  /// reading SAVED and PASSED. Removing one redundant label and keeping
  /// two identical ones would have been arbitrary. Say if the other two
  /// should come back.
  const _ActivityCard({
    super.key,
    required this.profile,
    required this.kind,
    required this.expansionController,
    this.onViewProfile,
    this.suggestedByOverride,
    this.isLocalTestProfile = false,
    this.onLocalMove,
    this.onLocalHidden,
  });

  @override
  State<_ActivityCard> createState() => _ActivityCardState();
}

class _ActivityCardState extends State<_ActivityCard> {
  String get _cardId => 'activity:${widget.profile.id}';
  bool get _open => widget.expansionController.value == _cardId;

  /// Anchor for Scrollable.ensureVisible when the card expands.
  final GlobalKey _cardKey = GlobalKey();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    widget.expansionController.addListener(_onExpansionChanged);
  }

  @override
  void didUpdateWidget(covariant _ActivityCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.expansionController == widget.expansionController) return;
    oldWidget.expansionController.removeListener(_onExpansionChanged);
    widget.expansionController.addListener(_onExpansionChanged);
  }

  @override
  void dispose() {
    widget.expansionController.removeListener(_onExpansionChanged);
    super.dispose();
  }

  void _onExpansionChanged() {
    if (mounted) setState(() {});
  }

  void _collapse() => widget.expansionController.close(_cardId);

  void _leavePage(VoidCallback action) {
    widget.expansionController.collapseAll();
    action();
  }

  String? get _suggestedBy =>
      widget.suggestedByOverride ??
      AppState.instance.suggestedBy(widget.profile.id);

  /// Move this profile to a different state.
  ///
  /// ADDED 2026-08-01 (Founder: "there's no way to open the profile card
  /// and move a user to save or decline... if I considered a profile but
  /// changed my mind then I need a button").
  ///
  /// The current one-state model is enforced in AppState and by database
  /// triggers: Consider, Save and Pass each replace the previous state.
  /// Toggle-created people follow the same visible rule through the scenario
  /// callback, without entering AppState or reaching a service.
  Future<void> _move(_Move move) async {
    if (_busy) return;
    _collapse();
    setState(() => _busy = true);

    final localMove = widget.onLocalMove;
    if (localMove != null) {
      localMove(move);
      if (mounted) setState(() => _busy = false);
      return;
    }

    final app = AppState.instance;
    final p = widget.profile;
    final limits = SelahSeekerPlanLimits.of(app.plan);
    final alreadyConsidered = app.outgoingLikes.any((item) => item.id == p.id);
    final maySave = limits.canSave(
      currentCount: app.saved.length,
      alreadySaved: app.saved.any((item) => item.id == p.id),
    );
    final mayConsider = limits.canConsider(
      currentCount: app.outgoingLikes.length,
      alreadyConsidered: alreadyConsidered,
    );
    if ((move == _Move.save && !maySave) ||
        (move == _Move.consider && !mayConsider)) {
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            move == _Move.save
                ? 'Your ${limits.savedProfiles}-profile Save list is full. '
                      'Remove a Save before adding another; existing profiles are kept.'
                : 'Your ${limits.activeConsiders}-profile Consider list is full. '
                      'Pass an existing Consider before adding another.',
          ),
        ),
      );
      return;
    }
    // BUG-02 (2026-08-14 audit, inherited upstream action 225 — fixed 2026-08-15): the
    // record calls report failure now instead of swallowing it. The
    // AppState change stays — same optimistic-with-honesty ruling as
    // Browse — and a retry is just the same move again (all three
    // writes are idempotent upserts). Stand-ins have no row to write;
    // the guard keeps them off the persistence path, so a staged move
    // keeps behaving exactly as before.
    final persistable = SelahReportService.isPersistableId(p.id);
    if (move == _Move.consider &&
        !alreadyConsidered &&
        persistable &&
        limits.dailyConsiders != null) {
      try {
        final usage = await SelahSeekerBasicUsageStore.tryRecordConsider();
        if (!mounted) return;
        if (usage == null) {
          setState(() => _busy = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Your current access allows ${limits.dailyConsiders} '
                'Considers each day. Passing or removing profiles is still available.',
              ),
            ),
          );
          return;
        }
      } catch (_) {
        if (!mounted) return;
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Couldn’t record your daily allowance. '
              'Your profile decision is unchanged; please try again.',
            ),
          ),
        );
        return;
      }
      if (!mounted) return;
    }
    var ok = true;
    switch (move) {
      case _Move.consider:
        app.like(p);
        if (persistable) ok = await SelahDiscoveryService.recordLike(p.id);
      case _Move.pass:
        app.decline(p);
        if (persistable) ok = await SelahDiscoveryService.recordPass(p.id);
      case _Move.save:
        app.save(p);
        if (persistable) ok = await SelahDiscoveryService.recordSave(p.id);
      case _Move.unsave:
        app.unsave(p);
        if (persistable) await SelahDiscoveryService.removeSave(p.id);
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "That move didn't save — check your connection and try it again.",
          ),
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  // `_canUnlock` removed 2026-08-03. It gated Compatibility Unlock off
  // Passed cards, per the 2026-07-12 rule "cannot be used on passed
  // profiles" — a rule the Founder has now reversed. Deleted rather than
  // left as a constant returning true.

  /// True once this profile has been unlocked at EITHER tier — the button
  /// then reads "View Compatibility" for good.
  bool get _viewable =>
      SelahUnlockService.isUnlocked(widget.profile.id, UnlockTier.standard) ||
      SelahUnlockService.isUnlocked(widget.profile.id, UnlockTier.plus);

  /// Opens the card AND scrolls it fully into view.
  ///
  /// ADDED 2026-08-03 (Founder: "right now I gotta swipe down to see the
  /// full thing — once they press expand, the page shows the full expand
  /// so the user doesn't have to swipe").
  ///
  /// The card grows below the tap as its compact action deck appears. Even
  /// without the retired full-photo body, a card low in the Activity list can
  /// otherwise leave its lower actions outside the viewport.
  ///
  /// FIXED 2026-08-04 (Founder: "that's no longer working"). It was a race
  /// all along and had simply been getting away with it.
  ///
  /// The body is an AnimatedCrossFade over [_kExpandAnim]. A single
  /// `addPostFrameCallback` fires after the FIRST frame of that animation —
  /// when the card has barely started growing — so `ensureVisible`
  /// measured a nearly-collapsed card and scrolled to where it used to be,
  /// not where it was heading. Whether it looked right depended on how far
  /// down the list the card already was.
  ///
  /// Now it scrolls TWICE, deliberately:
  ///   • post-frame, so the movement starts immediately and feels attached
  ///     to the tap rather than lagging behind it
  ///   • again once the crossfade has finished and the real height exists
  ///
  /// The second call is the correct one; the first is there so the scroll
  /// does not visibly wait 200ms before starting. Both are cheap no-ops if
  /// the card is already in view.
  static const Duration _kExpandAnim = Duration(milliseconds: 200);

  void _scrollIntoView() {
    final ctx = _cardKey.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      // 0.0 puts the card's top at the viewport's top, which is what
      // "show the whole thing" means for something taller than a
      // thumbnail. Centring would leave the head cropped.
      alignment: 0.0,
    );
  }

  void _expand() {
    widget.expansionController.open(_cardId);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollIntoView());
    // +40ms past the crossfade so the final layout has certainly been
    // laid out, not merely scheduled.
    Future.delayed(_kExpandAnim + const Duration(milliseconds: 40), () {
      if (mounted) _scrollIntoView();
    });
  }

  void _toggleOpen() {
    if (_open) {
      _collapse();
      return;
    }
    _expand();
  }

  Future<void> _report() async {
    widget.expansionController.collapseAll();
    final localOnly =
        widget.isLocalTestProfile ||
        !SelahReportService.isPersistableId(widget.profile.id);
    final handled = await showReportProfileSheet(
      context,
      profileId: widget.profile.id,
      firstName: widget.profile.firstName,
      source: SelahReportSource.connections,
      profileSnapshot: widget.profile,
      simulateOnly: localOnly,
      // Toggle-created people must disappear from this test surface only.
      // Do not let a fake id enter AppState or the member's persisted Hidden
      // Profiles list; [onLocalHidden] owns that scenario-only transition.
      applySimulatedHideLocally: !widget.isLocalTestProfile,
    );
    if (handled != true || !mounted) return;
    widget.onLocalHidden?.call();
    _collapse();
  }

  /// The two state-change pills, in the Founder-approved reading order.
  ///
  ///   Considered   Save · Pass
  ///   Saved        Consider · Pass
  ///   Passed       Consider · Save
  ///
  /// Introduction retains its existing Pass · Save · Consider decision row.
  /// Compatibility is appended after these by build(), so each settled
  /// Activity state has exactly three secondary pills under View Profile.
  List<_ConnectionsActionItem> _moveActions() {
    _ConnectionsActionItem item(_Move move) => switch (move) {
      _Move.pass => _ConnectionsActionItem(
        icon: Icons.close,
        label: 'Pass',
        onTap: _busy ? null : () => _move(_Move.pass),
      ),
      _Move.save => _ConnectionsActionItem(
        icon: Icons.bookmark_border,
        label: 'Save',
        onTap: _busy ? null : () => _move(_Move.save),
      ),
      _Move.consider => _ConnectionsActionItem(
        icon: Icons.check_circle_outline,
        label: 'Consider',
        onTap: _busy ? null : () => _move(_Move.consider),
      ),
      _Move.unsave => _ConnectionsActionItem(
        icon: Icons.bookmark_remove_outlined,
        label: 'Remove Save',
        onTap: _busy ? null : () => _move(_Move.unsave),
      ),
    };

    final moves = switch (widget.kind) {
      _ActivityKind.considered => const [_Move.save, _Move.pass],
      _ActivityKind.saved => const [_Move.consider, _Move.pass],
      _ActivityKind.passed => const [_Move.consider, _Move.save],
      _ActivityKind.introduction => const [
        _Move.pass,
        _Move.save,
        _Move.consider,
      ],
    };
    return moves.map(item).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final city = widget.profile.city.trim();
    return Padding(
      key: _cardKey,
      padding: const EdgeInsets.only(bottom: 10),
      child: DecoratedBox(
        key: ValueKey<String>('connections-activity-card-${widget.profile.id}'),
        decoration: BoxDecoration(
          color: _open
              ? SelahColors.surfaceEmphasisFill
              : SelahColors.surfaceFill,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _open
                ? SelahColors.surfaceEmphasisBorder
                : SelahColors.surfaceBorder,
            width: _open ? 1 : 0.5,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: Column(
            children: [
              // Activity now follows Potential Journey's compact model:
              // the one identity row remains visible in both states and
              // expansion reveals controls, never a second enlarged photo.
              InkWell(
                key: ValueKey<String>(
                  'connections-activity-card-header-${widget.profile.id}',
                ),
                borderRadius: BorderRadius.circular(14),
                onTap: _toggleOpen,
                child: Padding(
                  padding: const EdgeInsets.all(SelahCardMetrics.padding),
                  child: Row(
                    children: [
                      _cardThumb(
                        widget.profile,
                        size: SelahCardMetrics.thumb,
                        radius: SelahCardMetrics.thumbRadius,
                      ),
                      SizedBox(width: SelahCardMetrics.gap),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    // An introduction may arrive without
                                    // an age; ", 0" is worse than the
                                    // name alone.
                                    widget.profile.age > 0
                                        ? '${widget.profile.firstName}, ${widget.profile.age}'
                                        : widget.profile.firstName,
                                    style: SelahText.body(
                                      size: 14,
                                      color: SelahColors.foreground,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (city.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(
                                city,
                                key: ValueKey<String>(
                                  'connections-activity-location-${widget.profile.id}',
                                ),
                                style: SelahText.subtext(size: 11.5),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            // ADDED 2026-08-05 (Founder: "if they decline,
                            // consider etc it moves to decline/consider/save
                            // but still with the word shepherd suggested
                            // somewhere").
                            //
                            // The Shepherd's involvement is the most
                            // meaningful thing about how this person got
                            // here, and it shouldn't evaporate the moment a
                            // decision is made — a month later, "Ibrahim
                            // suggested her" is exactly the context you want
                            // when scanning a list of people you passed on.
                            if (_suggestedBy != null) ...[
                              SizedBox(height: 3),
                              Row(
                                children: [
                                  Icon(
                                    Icons.shield_outlined,
                                    size: 11,
                                    color: SelahColors.foreground.withValues(
                                      alpha: 0.45,
                                    ),
                                  ),
                                  SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      'Suggested by $_suggestedBy',
                                      style: SelahText.subtext(size: 11),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (!_open)
                        _ConnectionsCollapsedExpandArrow(
                          key: ValueKey<String>(
                            'connections-activity-expand-${widget.profile.id}',
                          ),
                        ),
                      if (_open)
                        _ConnectionsReportFlag(
                          profileId: widget.profile.id,
                          firstName: widget.profile.firstName,
                          onTap: _report,
                        ),
                    ],
                  ),
                ),
              ),

              // The retired full-photo mini-profile is gone. Potential,
              // Considered, Saved and Passed now all expand in place into a
              // compact action surface. The full-photo experience remains
              // available through View Profile.
              AnimatedCrossFade(
                // Shared with _expand()'s second scroll pass — if these two
                // durations drift apart, the auto-scroll silently starts
                // measuring mid-animation again.
                duration: _kExpandAnim,
                crossFadeState: _open
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                firstChild: SizedBox(width: double.infinity),
                secondChild: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // The full-photo mini-profile was retired. View Profile
                      // owns photo inspection; this expansion is the same
                      // compact action surface used by Potential Journey.
                      // Each settled Activity state exposes the other two
                      // one-state destinations, followed by Compatibility.
                      // The exact Founder-approved order lives in
                      // _moveActions(); local test people use the same deck.
                      SizedBox(height: 10),
                      // SHOWN ON EVERY CARD, INCLUDING PASSED — Founder,
                      // 2026-08-03: "we said on decline there isn't an
                      // option for Profile Unlock, but I feel we should
                      // change that so the option is there."
                      //
                      // Reverses the 2026-07-12 rule "cannot be used on
                      // passed profiles". That rule read as tidiness —
                      // why check compatibility with someone you rejected.
                      // But the person having second thoughts about a Pass
                      // is exactly who a compatibility score helps, and
                      // this card already offers Consider and Save from
                      // that state. Offering the reconsideration while
                      // withholding the one thing that would INFORM it was
                      // backwards.
                      //
                      // APP/Premium/Profile Unlocks/Summary.md updated to
                      // match rather than left contradicting the app.
                      _ConnectionsActionDeck(
                        primary: _ConnectionsActionItem(
                          icon: Icons.person_outline,
                          label: 'View Profile',
                          onTap: () => _leavePage(
                            widget.onViewProfile ??
                                () => pushSelahConnectionsProfile(
                                  context,
                                  profile: widget.profile,
                                ),
                          ),
                        ),
                        actions: [
                          ..._moveActions(),
                          // The label becomes View Compatibility permanently
                          // after an unlock at either tier.
                          _ConnectionsActionItem(
                            icon: _viewable
                                ? Icons.visibility_outlined
                                : Icons.insights_outlined,
                            label: _viewable
                                ? 'View Compatibility'
                                : 'Compatibility Unlock',
                            onTap: () async {
                              widget.expansionController.collapseAll();
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => ProfileUnlockScreen(
                                    profile: widget.profile,
                                  ),
                                ),
                              );
                              if (mounted) setState(() {});
                            },
                          ),
                        ],
                        // The two short decisions share one row; the longer
                        // Compatibility label gets a full-width pill below.
                        // This preserves the three-action reading order
                        // without truncating the feature name on an iPhone.
                        fullWidthLastAction:
                            widget.kind != _ActivityKind.introduction,
                      ),
                      // COLLAPSE — same single affordance as Potential.
                      SizedBox(height: 4),
                      Center(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: _collapse,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 26,
                              vertical: 6,
                            ),
                            child: Icon(
                              Icons.keyboard_arrow_up,
                              key: ValueKey<String>(
                                'connections-activity-collapse-${widget.profile.id}',
                              ),
                              size: 22,
                              color: SelahColors.ink(0.45),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConnectionsSubsectionLabel extends StatelessWidget {
  final String label;

  const _ConnectionsSubsectionLabel(this.label);

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: SelahText.chapterLabel(color: SelahColors.foregroundMuted),
  );
}

/// THE JOURNEY PERSON CARD — _ActivityCard's expansion model carrying
/// Journey verbs (Founder, 2026-08-12, third person-surface round: "take
/// the activity section how it expands and copy that model").
///
/// The thumbnail, name and state remain the card's single identity header
/// while closed and open. The down chevron belongs only to the collapsed
/// state; once expanded, the small person-level Report flag takes its place
/// and the one collapse chevron lives at the bottom. Expansion then adds the
/// state's verb, followed by the
/// full-width Profile, Compatibility and optional Timeline/End rows. States
/// with no verb (busy elsewhere, the spent nudge, the cooling period) show the
/// honest fact in the verb's place instead of a disabled button.
///
/// The scroll-into-view mechanics, durations and layout constants are
/// _ActivityCard's, copied to the value — two expanding cards on one page
/// must move identically or the copy reads as a knock-off.
class _JourneyExpandingCard extends StatefulWidget {
  final JourneyMatch j;
  final SelahConnectionsExpansionController expansionController;
  final String subtitle;
  final ({String label, String? caption, Future<void> Function() run})? hero;
  final String? heroFact;
  final bool showTimeline;
  final VoidCallback? onTimeline;
  final bool canEnd;
  final VoidCallback? onEnd;
  final VoidCallback onReport;
  final bool dimmed;

  /// When non-null this card is mid-decision and extends inline (B3,
  /// Founder pick 2026-08-12: "point 4 do b3"; widened 2026-08-13 to the
  /// restart ask — "we changed the ui to give notification like we did
  /// for potential"): the action rows step aside and this widget renders
  /// beneath the persistent identity header. Potential rows receive the
  /// takeover (_inlineTakeoverFor); Ended rows receive the restart ask
  /// (_inlineRestartFor). Never both, never elsewhere.
  final Widget? inlineExtension;

  /// True for Paused and Ended rows — pairs whose Journey BEGAN, which
  /// opens with Compatibility Reveal. Their button always reads "View
  /// Compatibility" (Founder, 2026-08-13: "its not compatibility unlock.
  /// because they already unlocked") and the report opens without a
  /// purchase, via ProfileUnlockScreen's journeyRevealed door.
  final bool compatibilityRevealed;

  /// The ✕ in the extension header (2026-08-13 round four). Every site
  /// passes the parent's clear-everything dismiss — only one decision is
  /// ever open, so clearing all of them is exact, not sloppy.
  final VoidCallback? onDismissExtension;

  /// False on Potential rows only (2026-08-13): the expanded card drops
  /// the small state line above the verb. Everywhere else it carries a
  /// fact the verb cannot say by itself — why Restart is offered, what
  /// Resume will do, why there is no verb at all — so it stays. Nothing
  /// replaces it here; the freed height goes to the photo/verb gap.
  final bool showStateLine;

  const _JourneyExpandingCard({
    required this.j,
    required this.expansionController,
    required this.subtitle,
    required this.hero,
    required this.heroFact,
    required this.showTimeline,
    required this.onTimeline,
    required this.canEnd,
    required this.onEnd,
    required this.onReport,
    this.dimmed = false,
    this.inlineExtension,
    this.compatibilityRevealed = false,
    this.onDismissExtension,
    this.showStateLine = true,
  });

  @override
  State<_JourneyExpandingCard> createState() => _JourneyExpandingCardState();
}

class _JourneyExpandingCardState extends State<_JourneyExpandingCard> {
  String get _cardId => 'journey:${widget.j.matchId}';
  bool get _open => widget.expansionController.value == _cardId;
  final GlobalKey _cardKey = GlobalKey();

  static const Duration _kExpandAnim = Duration(milliseconds: 200);

  SeekerProfile get _p => widget.j.profile;

  /// Activity's rule, verbatim: unlocked at EITHER tier and the button
  /// reads "View Compatibility" for good (2026-08-03 Founder ruling —
  /// returning never consumes another unlock).
  bool get _viewable =>
      SelahUnlockService.isUnlocked(_p.id, UnlockTier.standard) ||
      SelahUnlockService.isUnlocked(_p.id, UnlockTier.plus);

  bool get _hasJourneyReference =>
      widget.compatibilityRevealed &&
      widget.showTimeline &&
      widget.onTimeline != null;

  @override
  void initState() {
    super.initState();
    widget.expansionController.addListener(_onExpansionChanged);
  }

  void _onExpansionChanged() {
    if (mounted) setState(() {});
  }

  void _collapse() => widget.expansionController.close(_cardId);

  void _leavePage(VoidCallback action) {
    widget.expansionController.collapseAll();
    action();
  }

  Future<void> _openCompatibility() async {
    widget.expansionController.collapseAll();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProfileUnlockScreen(
          profile: _p,
          journeyRevealed: widget.compatibilityRevealed,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant _JourneyExpandingCard old) {
    super.didUpdateWidget(old);
    if (old.expansionController != widget.expansionController) {
      old.expansionController.removeListener(_onExpansionChanged);
      widget.expansionController.addListener(_onExpansionChanged);
    }
    // The extension lands right after the hero tap collapsed the card
    // (the hero's onTap closes before running the verb) — reopen so the
    // choice is actually visible, and bring it into view. Both setStates
    // happen in the same frame, so no collapse is ever painted.
    if (widget.inlineExtension != null && old.inlineExtension == null) {
      widget.expansionController.open(_cardId);
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollIntoView());
      Future.delayed(_kExpandAnim + const Duration(milliseconds: 40), () {
        if (mounted) _scrollIntoView();
      });
    }
  }

  @override
  void dispose() {
    widget.expansionController.removeListener(_onExpansionChanged);
    super.dispose();
  }

  void _scrollIntoView() {
    final ctx = _cardKey.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      alignment: 0.0,
    );
  }

  void _expand() {
    widget.expansionController.open(_cardId);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollIntoView());
    Future.delayed(_kExpandAnim + const Duration(milliseconds: 40), () {
      if (mounted) _scrollIntoView();
    });
  }

  void _toggleOpen() {
    if (_open) {
      _collapse();
      return;
    }
    _expand();
  }

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: widget.dimmed && !_open ? 0.65 : 1,
      child: Padding(
        key: _cardKey,
        padding: const EdgeInsets.only(bottom: 10),
        child: DecoratedBox(
          key: ValueKey<String>('connections-journey-card-${widget.j.matchId}'),
          decoration: BoxDecoration(
            color: _open
                ? SelahColors.surfaceEmphasisFill
                : SelahColors.surfaceFill,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _open
                  ? SelahColors.surfaceEmphasisBorder
                  : SelahColors.surfaceBorder,
              width: _open ? 1 : 0.5,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: Column(
              children: [
                // The identity row remains the single person header in both
                // states. Expanding reveals only Journey controls below it,
                // so the photo, name and state are never repeated.
                InkWell(
                  key: ValueKey<String>(
                    'connections-card-header-${widget.j.matchId}',
                  ),
                  borderRadius: BorderRadius.circular(14),
                  onTap: _toggleOpen,
                  child: Padding(
                    padding: const EdgeInsets.all(SelahCardMetrics.padding),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(
                            SelahCardMetrics.thumbRadius,
                          ),
                          child: _p.photos.isEmpty
                              ? Container(
                                  width: SelahCardMetrics.thumb,
                                  height: SelahCardMetrics.thumb,
                                  color: SelahColors.ink(0.22),
                                  alignment: Alignment.center,
                                  child: Text(
                                    _p.firstName.isEmpty
                                        ? '?'
                                        : _p.firstName[0],
                                    style: SelahText.heading(size: 16),
                                  ),
                                )
                              : SelahProfileImage(
                                  _p.photoUrl,
                                  width: SelahCardMetrics.thumb,
                                  height: SelahCardMetrics.thumb,
                                ),
                        ),
                        SizedBox(width: SelahCardMetrics.gap),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${_p.firstName}, ${_p.age}',
                                style: SelahText.body(
                                  size: 14,
                                  color: SelahColors.foreground,
                                ),
                              ),
                              SizedBox(height: 3),
                              Text(
                                widget.subtitle,
                                style: SelahText.subtext(size: 11),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        if (!_open)
                          _ConnectionsCollapsedExpandArrow(
                            key: ValueKey<String>(
                              'connections-card-expand-${widget.j.matchId}',
                            ),
                          ),
                        if (_open)
                          _ConnectionsReportFlag(
                            profileId: _p.id,
                            firstName: _p.firstName,
                            onTap: () => _leavePage(widget.onReport),
                          ),
                      ],
                    ),
                  ),
                ),
                AnimatedCrossFade(
                  duration: _kExpandAnim,
                  crossFadeState: _open
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  firstChild: SizedBox(width: double.infinity),
                  secondChild: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Mid-decision keeps one reflex exit before the inline
                        // confirmation. Identity remains in the persistent
                        // card header above, so it is not repeated here.
                        if (widget.inlineExtension != null) ...[
                          InkWell(
                            borderRadius: BorderRadius.circular(999),
                            onTap: widget.onDismissExtension,
                            child: Container(
                              width: 26,
                              height: 26,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: SelahColors.ink(0.10),
                                border: Border.all(color: SelahColors.ink(0.25)),
                              ),
                              child: Icon(
                                Icons.close,
                                size: 14,
                                color: SelahColors.ink(0.70),
                              ),
                            ),
                          ),
                          SizedBox(height: 12),
                          Container(height: 1, color: SelahColors.ink(0.14)),
                          SizedBox(height: 12),
                          widget.inlineExtension!,
                        ],
                        // MID-DECISION the card IS the dialog: the rows
                        // step aside while the extension (rendered with
                        // the ✕ header above) holds the moment.
                        if (widget.inlineExtension == null) ...[
                          // Extra state context appears only when the verb
                          // cannot say the full truth by itself. Potential
                          // rows suppress it; their persistent header already
                          // says they are ready to start.
                          if (widget.showStateLine) ...[
                            SizedBox(height: 10),
                            Text(
                              widget.heroFact ??
                                  widget.hero?.caption ??
                                  widget.subtitle,
                              style: SelahText.subtext(
                                size: 10.5,
                                color: SelahColors.ink(0.55),
                              ),
                            ),
                          ],
                          // THE VERB ROW — Activity's 85/15 split, with
                          // the Journey verb in the big seat. Its full width
                          // preserves hierarchy; Founder direction on
                          // 2026-08-29 removed the former accent-colour fill
                          // so it now uses the same neutral glass as the
                          // look-at rows. Coral remains reserved for End.
                          SizedBox(height: widget.showStateLine ? 8 : 14),
                          _ConnectionsActionDeck(
                            primary: _ConnectionsActionItem(
                              icon: Icons.route_outlined,
                              label:
                                  widget.hero?.label ??
                                  widget.heroFact ??
                                  'Nothing to do right now',
                              onTap: widget.hero == null
                                  ? null
                                  : () {
                                      _collapse();
                                      widget.hero!.run();
                                    },
                            ),
                            journeyReference: _hasJourneyReference
                                ? _ConnectionsJourneyReference(
                                    matchId: widget.j.matchId,
                                    onTimeline: () =>
                                        _leavePage(widget.onTimeline!),
                                    onCompatibility: _openCompatibility,
                                  )
                                : null,
                            actions: [
                              _ConnectionsActionItem(
                                icon: Icons.person_outline,
                                label: 'View Profile',
                                onTap: () => _leavePage(
                                  () => pushSelahConnectionsProfile(
                                    context,
                                    profile: _p,
                                  ),
                                ),
                              ),
                              if (!_hasJourneyReference)
                                _ConnectionsActionItem(
                                  icon: Icons.insights_outlined,
                                  label:
                                      widget.compatibilityRevealed || _viewable
                                      ? 'View Compatibility'
                                      : 'Compatibility Unlock',
                                  onTap: _openCompatibility,
                                ),
                              if (widget.canEnd && widget.onEnd != null)
                                _ConnectionsActionItem(
                                  icon: Icons.stop_circle_outlined,
                                  label: 'End Journey',
                                  onTap: () {
                                    _collapse();
                                    widget.onEnd!();
                                  },
                                ),
                            ],
                          ),
                          SizedBox(height: 4),
                          Center(
                            child: InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: _collapse,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 26,
                                  vertical: 6,
                                ),
                                child: Icon(
                                  Icons.keyboard_arrow_up,
                                  key: ValueKey<String>(
                                    'connections-card-collapse-${widget.j.matchId}',
                                  ),
                                  size: 22,
                                  color: SelahColors.ink(0.45),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// The former expanded portrait/photo pager was retired on 2026-08-20. The
// compact identity header now remains visible while open, and the expansion is
// reserved for Journey controls only.

/// The one collapsed-card invitation used by Journey and Activity rows.
/// Sharing the width, alignment and glyph keeps Potential and
/// Considered/Saved/Passed in the exact same centre-right position.
class _ConnectionsCollapsedExpandArrow extends StatelessWidget {
  const _ConnectionsCollapsedExpandArrow({super.key});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 32,
    child: Center(
      child: Icon(
        Icons.keyboard_arrow_down,
        color: SelahColors.ink(0.38),
        size: 20,
      ),
    ),
  );
}

class _ConnectionsActionItem {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _ConnectionsActionItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });
}

/// A person-level safety action, deliberately outside Journey navigation.
/// Active keeps this visible because its card is already the live expanded
/// Journey surface. Potential, Paused and Ended build it only after their
/// shared card opens, keeping collapsed identity rows free of safety chrome.
class _ConnectionsReportFlag extends StatelessWidget {
  final String profileId;
  final String firstName;
  final VoidCallback onTap;

  const _ConnectionsReportFlag({
    required this.profileId,
    required this.firstName,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Tooltip(
    message: 'Report $firstName',
    child: Semantics(
      button: true,
      label: 'Report $firstName',
      child: GestureDetector(
        key: ValueKey<String>('connections-report-$profileId'),
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.only(left: 10, bottom: 10),
          child: Icon(
            Icons.flag_outlined,
            size: 15,
            color: SelahColors.ink(0.75),
          ),
        ),
      ),
    ),
  );
}

/// One action hierarchy shared by Active, Potential, Paused and Ended
/// Journeys plus Considered, Saved, Passed and Introductions. The selected
/// developer style changes only presentation; labels, callbacks and data stay
/// attached to the same action objects.
class _ConnectionsActionDeck extends StatelessWidget {
  final _ConnectionsActionItem primary;
  final List<_ConnectionsActionItem> actions;
  final Widget? journeyReference;
  final bool fullWidthLastAction;

  const _ConnectionsActionDeck({
    required this.primary,
    required this.actions,
    this.journeyReference,
    this.fullWidthLastAction = false,
  });

  SelahConnectionsCardStyle get _style => SelahConnectionsCardStyle.compactChips;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ConnectionsActionButton(item: primary, primary: true, style: _style),
        if (journeyReference != null) ...[
          const SizedBox(height: 10),
          journeyReference!,
        ],
        if (actions.isNotEmpty) ...[
          const SizedBox(height: 9),
          KeyedSubtree(
            key: const ValueKey('connections-card-action-strip'),
            child: _ConnectionsSecondaryActions(
              actions: actions,
              style: _style,
              fullWidthLastAction: fullWidthLastAction,
            ),
          ),
        ],
      ],
    );
  }
}

/// Paused and Ended cards already have a Journey history. Their Timeline and
/// revealed Compatibility belong together as references to that Journey,
/// rather than being mixed with profile/safety/state-changing controls. The
/// label groups them without a second enclosing glass box; each action keeps
/// the same simple Compact Chips pill used by View Profile.
class _ConnectionsJourneyReference extends StatelessWidget {
  final String matchId;
  final VoidCallback onTimeline;
  final VoidCallback onCompatibility;

  const _ConnectionsJourneyReference({
    required this.matchId,
    required this.onTimeline,
    required this.onCompatibility,
  });

  SelahConnectionsCardStyle get _style => SelahConnectionsCardStyle.compactChips;

  @override
  Widget build(BuildContext context) => Container(
    key: ValueKey<String>('connections-journey-reference-$matchId'),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'JOURNEY',
          style: SelahText.chapterLabel(color: SelahColors.ink(0.54)),
        ),
        const SizedBox(height: 7),
        KeyedSubtree(
          key: const ValueKey('connections-journey-reference-actions'),
          child: _ConnectionsSecondaryActions(
            style: _style,
            actions: [
              _ConnectionsActionItem(
                icon: Icons.timeline_outlined,
                label: 'Timeline',
                onTap: onTimeline,
              ),
              _ConnectionsActionItem(
                icon: Icons.insights_outlined,
                label: 'View Compatibility',
                onTap: onCompatibility,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ConnectionsSecondaryActions extends StatelessWidget {
  final List<_ConnectionsActionItem> actions;
  final SelahConnectionsCardStyle style;
  final bool fullWidthLastAction;

  const _ConnectionsSecondaryActions({
    required this.actions,
    required this.style,
    this.fullWidthLastAction = false,
  });

  @override
  Widget build(BuildContext context) {
    switch (style) {
      case SelahConnectionsCardStyle.unifiedRail:
        return LayoutBuilder(
          builder: (context, constraints) => Wrap(
            spacing: 0,
            runSpacing: 7,
            children: [
              for (final action in actions)
                SizedBox(
                  width: constraints.maxWidth / actions.length.clamp(1, 3),
                  child: _ConnectionsActionButton(item: action, style: style),
                ),
            ],
          ),
        );
      case SelahConnectionsCardStyle.splitPills:
        return _ConnectionsActionWrap(
          actions: actions,
          columns: 2,
          style: style,
          gap: 8,
        );
      case SelahConnectionsCardStyle.iconDock:
        return _ConnectionsActionWrap(
          actions: actions,
          columns: 3,
          style: style,
          gap: 5,
        );
      case SelahConnectionsCardStyle.stackedRows:
        return Column(
          children: [
            for (var i = 0; i < actions.length; i++) ...[
              if (i > 0) const SizedBox(height: 6),
              _ConnectionsActionButton(item: actions[i], style: style),
            ],
          ],
        );
      case SelahConnectionsCardStyle.compactChips:
        if (fullWidthLastAction && actions.length == 3) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ConnectionsActionWrap(
                actions: actions.take(2).toList(growable: false),
                columns: 2,
                style: style,
                gap: 7,
              ),
              const SizedBox(height: 7),
              _ConnectionsActionButton(item: actions.last, style: style),
            ],
          );
        }
        return _ConnectionsActionWrap(
          actions: actions,
          columns: actions.length.clamp(1, 3),
          style: style,
          gap: 7,
        );
      case SelahConnectionsCardStyle.framedGrid:
        return Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: SelahColors.surfaceFill,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: SelahColors.surfaceBorder, width: 0.6),
          ),
          child: _ConnectionsActionWrap(
            actions: actions,
            columns: 2,
            style: style,
            gap: 5,
          ),
        );
    }
  }
}

/// Narrow public seam for layout regression tests. It uses the same private
/// heading and action widgets as the live Connections card, so the test proves
/// the Compact Chips row fills its real width rather than testing a replica.
@visibleForTesting
Widget buildSelahConnectionsDesignTestSurface() {
  return SizedBox(
    width: 330,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _ConnectionsSectionHeading(
          title: 'Active Journey',
          emphasised: true,
        ),
        const SizedBox(height: 12),
        _ConnectionsSecondaryActions(
          style: SelahConnectionsCardStyle.compactChips,
          actions: [
            _ConnectionsActionItem(
              icon: Icons.person_outline,
              label: 'View Profile',
              onTap: _ignoreConnectionsDesignTestTap,
            ),
            _ConnectionsActionItem(
              icon: Icons.timeline_outlined,
              label: 'Timeline',
              onTap: _ignoreConnectionsDesignTestTap,
            ),
            _ConnectionsActionItem(
              icon: Icons.more_horiz,
              label: 'Options',
              onTap: _ignoreConnectionsDesignTestTap,
            ),
          ],
        ),
      ],
    ),
  );
}

void _ignoreConnectionsDesignTestTap() {}

/// Live-card test states for the Potential / Paused / Ended hierarchy. The
/// surface instantiates [_JourneyExpandingCard] itself, rather than a visual
/// replica, so route, width and overflow tests exercise production widgets.
@visibleForTesting
enum SelahConnectionsJourneyCardTestState { potential, paused, ended }

@visibleForTesting
Widget buildSelahConnectionsJourneyCardTestSurface(
  SelahConnectionsJourneyCardTestState state,
) {
  const profile = SeekerProfile(
    id: 'connections-card-test-profile',
    firstName: 'Maryam',
    surnameLine: 'Hussain',
    age: 27,
    city: 'London',
    photos: [],
    gender: 'female',
  );
  final paused = state == SelahConnectionsJourneyCardTestState.paused;
  final ended = state == SelahConnectionsJourneyCardTestState.ended;
  final match = JourneyMatch(
    matchId: 'connections-card-test-${state.name}',
    profile: profile,
    status: ended
        ? 'ended'
        : paused
        ? 'active'
        : 'potential',
    pause: paused
        ? const SelahJourneyPauseState(phase: SelahPausePhase.paused)
        : SelahJourneyPauseState.active,
    endedAt: ended ? DateTime.now().subtract(const Duration(days: 2)) : null,
    isMock: true,
  );
  return _JourneyExpandingCard(
    j: match,
    expansionController: SelahConnectionsExpansionController(),
    subtitle: ended
        ? 'Ended'
        : paused
        ? 'Paused'
        : 'Ready to start',
    hero: ended && !SelahReleaseGates.requestNewJourneyEnabled
        ? null
        : (
            label: ended
                ? 'Request New Journey'
                : paused
                ? 'Request Resume'
                : 'Begin Journey',
            caption: null,
            run: _ignoreConnectionsDesignTestTapAsync,
          ),
    heroFact: null,
    showTimeline: paused || ended,
    onTimeline: paused || ended ? _ignoreConnectionsDesignTestTap : null,
    canEnd: paused,
    onEnd: paused ? _ignoreConnectionsDesignTestTap : null,
    onReport: _ignoreConnectionsDesignTestTap,
    compatibilityRevealed: paused || ended,
    showStateLine: false,
  );
}

Future<void> _ignoreConnectionsDesignTestTapAsync() async {}

/// Journey and Activity production cards sharing the live one-open contract.
@visibleForTesting
Widget buildSelahConnectionsExclusiveExpansionTestSurface() {
  final expansionController = SelahConnectionsExpansionController();
  const journeyProfile = SeekerProfile(
    id: 'exclusive-journey-profile',
    firstName: 'Maryam',
    age: 27,
    city: 'London',
    photos: [],
    gender: 'female',
  );
  const activityProfile = SeekerProfile(
    id: 'exclusive-activity-profile',
    firstName: 'Amina',
    age: 29,
    city: 'Leeds',
    photos: [],
    gender: 'female',
  );
  return Column(
    children: [
      _JourneyExpandingCard(
        j: const JourneyMatch(
          matchId: 'exclusive-journey',
          profile: journeyProfile,
          status: 'potential',
          isMock: true,
        ),
        expansionController: expansionController,
        subtitle: 'Ready to start',
        hero: (
          label: 'Begin Journey',
          caption: null,
          run: _ignoreConnectionsDesignTestTapAsync,
        ),
        heroFact: null,
        showTimeline: false,
        onTimeline: null,
        canEnd: false,
        onEnd: null,
        onReport: _ignoreConnectionsDesignTestTap,
        showStateLine: false,
      ),
      _ActivityCard(
        expansionController: expansionController,
        profile: activityProfile,
        kind: _ActivityKind.considered,
      ),
    ],
  );
}

/// Live collapsed Activity cards for alignment and overflow regression tests.
@visibleForTesting
enum SelahConnectionsActivityCardTestState { considered, saved, passed }

@visibleForTesting
Widget buildSelahConnectionsActivityCardTestSurface(
  SelahConnectionsActivityCardTestState state, {
  bool localTestProfile = false,
  bool movedIntroduction = false,
  String? profileId,
}) {
  assert(!movedIntroduction || localTestProfile);
  final kind = switch (state) {
    SelahConnectionsActivityCardTestState.considered => _ActivityKind.considered,
    SelahConnectionsActivityCardTestState.saved => _ActivityKind.saved,
    SelahConnectionsActivityCardTestState.passed => _ActivityKind.passed,
  };
  final localState = switch (state) {
    SelahConnectionsActivityCardTestState.considered =>
      SelahActivityTestState.considered,
    SelahConnectionsActivityCardTestState.saved => SelahActivityTestState.saved,
    SelahConnectionsActivityCardTestState.passed => SelahActivityTestState.passed,
  };
  final profile = SeekerProfile(
    id:
        profileId ??
        (movedIntroduction
            ? selahIntroductionTestProfileId(0)
            : localTestProfile
            ? selahActivityTestProfileId(localState, 0)
            : 'connections-activity-test-${state.name}'),
    firstName: 'Maryam',
    surnameLine: 'Hussain',
    age: 27,
    city: 'London',
    photos: const [],
    gender: 'female',
  );
  return _ActivityCard(
    expansionController: SelahConnectionsExpansionController(),
    profile: profile,
    kind: kind,
    suggestedByOverride: movedIntroduction
        ? _kLocalIntroductionSuggestedBy
        : null,
    isLocalTestProfile: localTestProfile,
    onViewProfile: movedIntroduction ? _ignoreConnectionsDesignTestTap : null,
    onLocalMove: localTestProfile
        ? (move) {
            final destination = switch (move) {
              _Move.consider => SelahActivityTestState.considered,
              _Move.save => SelahActivityTestState.saved,
              _Move.pass => SelahActivityTestState.passed,
              _Move.unsave => null,
            };
            if (destination != null) {
              SelahDevScenario.instance.moveLocalProfile(
                profile.id,
                destination,
              );
            }
          }
        : null,
    onLocalHidden: localTestProfile
        ? () => SelahDevScenario.instance.hideLocalProfile(profile.id)
        : null,
  );
}

/// Renders the same Introduction cards used by the live segment so focused
/// tests can verify the local 0/1/multiple states without invoking Supabase.
@visibleForTesting
Widget buildSelahIntroductionPreviewTestSurface({required int previewCount}) {
  final expansionController = SelahConnectionsExpansionController();
  final suggestions = composeSelahIntroductionPreviewSuggestions(
    const [],
    previewCount: previewCount,
  );
  return Column(
    children: [
      for (final suggestion in suggestions)
        _ActivityCard(
          expansionController: expansionController,
          profile: suggestion.profile,
          kind: _ActivityKind.introduction,
          suggestedByOverride: suggestion.suggestedBy,
          isLocalTestProfile: true,
          onLocalMove: (_) {},
          onViewProfile: _ignoreConnectionsDesignTestTap,
        ),
    ],
  );
}

class _ConnectionsActionWrap extends StatelessWidget {
  final List<_ConnectionsActionItem> actions;
  final int columns;
  final SelahConnectionsCardStyle style;
  final double gap;

  const _ConnectionsActionWrap({
    required this.actions,
    required this.columns,
    required this.style,
    required this.gap,
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final action in actions)
            SizedBox(
              width: width,
              child: _ConnectionsActionButton(item: action, style: style),
            ),
        ],
      );
    },
  );
}

class _ConnectionsActionButton extends StatelessWidget {
  final _ConnectionsActionItem item;
  final bool primary;
  final SelahConnectionsCardStyle style;

  const _ConnectionsActionButton({
    required this.item,
    required this.style,
    this.primary = false,
  });

  Color get _tint {
    if (item.onTap == null) return SelahColors.ink(0.34);
    return primary ? SelahColors.foreground : SelahColors.ink(0.80);
  }

  @override
  Widget build(BuildContext context) {
    final tint = _tint;
    final content = switch (style) {
      SelahConnectionsCardStyle.iconDock => SizedBox(
        // Leave enough vertical room for the app's supported large-text
        // scaling. The former 58pt secondary dock clipped its one-line label
        // by 3px at 145% text on a compact phone width.
        height: primary ? 48 : 64,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(item.icon, size: primary ? 17 : 16, color: tint),
            const SizedBox(height: 4),
            Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: SelahText.button(size: primary ? 12.5 : 9.5, color: tint),
            ),
          ],
        ),
      ),
      SelahConnectionsCardStyle.stackedRows => SizedBox(
        height: primary ? 44 : 40,
        child: Row(
          children: [
            const SizedBox(width: 12),
            Icon(item.icon, size: 16, color: tint),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: SelahText.body(size: primary ? 12.5 : 11.5, color: tint),
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 17,
              color: tint.withValues(alpha: 0.55),
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
      SelahConnectionsCardStyle.compactChips => Padding(
        padding: EdgeInsets.symmetric(
          horizontal: primary ? 14 : 10,
          vertical: primary ? 11 : 8,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(item.icon, size: 14, color: tint),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: SelahText.button(
                  size: primary ? 12.5 : 10.5,
                  color: tint,
                ),
              ),
            ),
          ],
        ),
      ),
      _ => SizedBox(
        height: primary ? 44 : 40,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (style != SelahConnectionsCardStyle.unifiedRail || primary) ...[
              Icon(item.icon, size: 15, color: tint),
              const SizedBox(width: 7),
            ],
            Flexible(
              child: Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: SelahText.button(
                  size: primary ? 12.5 : 10.5,
                  color: tint,
                ),
              ),
            ),
          ],
        ),
      ),
    };

    final radius = switch (style) {
      SelahConnectionsCardStyle.unifiedRail => primary ? 999.0 : 0.0,
      SelahConnectionsCardStyle.splitPills => 999.0,
      SelahConnectionsCardStyle.iconDock => 12.0,
      SelahConnectionsCardStyle.stackedRows => 10.0,
      SelahConnectionsCardStyle.compactChips => 999.0,
      SelahConnectionsCardStyle.framedGrid => 8.0,
    };
    final border = SelahColors.surfaceBorder;
    final fill = style == SelahConnectionsCardStyle.unifiedRail && !primary
        ? Colors.transparent
        : SelahColors.surfaceFill;

    return Material(
      key: ValueKey<String>('connections-action-${item.label}'),
      color: fill,
      borderRadius: BorderRadius.circular(radius),
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: border, width: primary ? 1 : 0.6),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(radius),
          onTap: item.onTap,
          child: content,
        ),
      ),
    );
  }
}

/// THE ACTIVE JOURNEY CARD. Founder, 2026-08-10: "make that profile card much
/// larger with the bottom have 2 text, enter and view timeline in bubbles."
///
/// Replaces `_JourneyTile(emphasised: true)` for this one section. The
/// emphasised tile was carrying two jobs badly — it existed to answer the
/// 2026-08-01 note that "active journey should be more stand out then the
/// rest" by being a slightly brighter version of a list row, and a slightly
/// brighter list row is still a list row.
///
/// SELAH allows ONE Active Journey at a time. It is not the first item in a
/// list; it is the thing the app is for, and the other three sections are
/// where the rest waits. So it gets its own shape: a 96px portrait, the name
/// at heading size, the stage underneath, and the two things you actually do
/// from here as pills across the bottom.
///
/// NO NEW ACCENT COLOUR, for the same reason the emphasised tile avoided one:
/// the gender gradient is already behind this card, and a third colour would
/// fight it. Emphasis is size, weight and white alpha only.
///
/// The pills use circular(20) and SelahColors.iconButtonBg/Border — the app's
/// existing pill, unchanged, so this reads as the same product rather than a
/// new screen. The whole card stays tappable and goes where Enter goes; the
/// pill names the action rather than owning it.
class _ActiveJourneyCard extends StatelessWidget {
  final SeekerProfile profile;
  final VoidCallback onEnter;
  final VoidCallback onTimeline;
  final VoidCallback onReport;

  /// ACTIVE CARD ACTIONS — revised by the Founder on 2026-08-20 with
  /// Connections Option 4. Continue remains the primary action; View Profile,
  /// Timeline and Options form one compact open rail. Options groups Pause and
  /// End, while the existing inline confirmations still own the consequential
  /// decision. Report remains the always-visible flag on the person.
  final VoidCallback onViewProfile;
  final VoidCallback onOptions;
  final bool reviewOpen;
  final bool decisionPending;

  /// INLINE CONFIRMS — 2026-08-13, round four ("popups now in
  /// connections page no longer exist and is all expanded"). When
  /// non-null the pill bands step aside and this confirm takes their
  /// place; a ✕ appears by the photo (which shrinks to 56pt — this
  /// card's portrait is small and part of who the card is, so it stays,
  /// unlike the expanding cards').
  final Widget? inlineConfirm;
  final VoidCallback? onDismissConfirm;

  /// The current Journey stage, from the canonical map. Rendered on the Enter
  /// pill, not as a status line — Timeline spec §12 option C, Founder
  /// 2026-08-10.
  /// True once the Journey has moved past its opening stage. Drives the
  /// primary pill's wording — Begin vs Continue — and nothing else
  /// (inherited decision 174).
  final bool hasBegun;

  const _ActiveJourneyCard({
    required this.profile,
    required this.onEnter,
    required this.onTimeline,
    required this.onReport,
    required this.onViewProfile,
    required this.onOptions,
    required this.reviewOpen,
    required this.decisionPending,
    required this.hasBegun,
    this.inlineConfirm,
    this.onDismissConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: SelahColors.surfaceFill,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: SelahColors.surfaceEmphasisBorder),
        ),
        // NOT tappable as a card — see the note at the call site. The two
        // pills below are the only actions, so there is no invisible third
        // one behind them.
        // The Material is kept though its InkWell has gone: descendants may
        // still want a Material ancestor, and a transparent one costs nothing
        // where guessing wrong costs a runtime "No Material widget found".
        child: Material(
          color: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Mid-confirm: the ✕ leads, the photo makes room.
                    if (inlineConfirm != null) ...[
                      InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: onDismissConfirm,
                        child: Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: SelahColors.iconButtonBg,
                            border: Border.all(
                              color: SelahColors.iconButtonBorder,
                            ),
                          ),
                          child: Icon(
                            Icons.close,
                            size: 14,
                            color: SelahColors.ink(0.70),
                          ),
                        ),
                      ),
                      SizedBox(width: 10),
                    ],
                    // PLAIN PHOTO. The expand glyph that briefly sat in this
                    // corner was rejected by the Founder on 2026-08-10 — a
                    // small icon on someone's face, doing something the icon
                    // does not name.
                    //
                    // The photo is NOT tappable either. An invisible tap
                    // target is worse than the glyph was: it is a feature
                    // only the person who built it knows about. Full profile
                    // entry is labelled: the View Profile pill below (the
                    // Timeline bubble it replaced retired 2026-08-13).
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: SelahProfileImage(
                        profile.photoUrl,
                        width: inlineConfirm != null ? 56 : 96,
                        height: inlineConfirm != null ? 56 : 96,
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // NAME, SURNAME, AGE, LOCATION — Founder,
                          // 2026-08-10. This replaced the Journey stage
                          // label ("Open Conversation" and the seven others
                          // from the canonical map).
                          //
                          // WHAT THAT COSTS, recorded so it is a decision and
                          // not an accident: the Connections page no longer
                          // tells you WHERE your Journey is without entering
                          // it. The stage is still on the Journey itself and
                          // still comes from the one map (inherited decision 129) — no
                          // second label was written here to replace it.
                          Text(
                            profile.firstName,
                            style: SelahText.heading(size: 19),
                          ),
                          // surnameLine is a display string, not a lastName —
                          // it may already carry "middle name + surname"
                          // together (models/seeker_profile.dart). Rendered
                          // whole, never split.
                          if ((profile.surnameLine ?? '').trim().isNotEmpty)
                            Text(
                              profile.surnameLine!.trim(),
                              style: SelahText.heading(
                                size: 15,
                                color: SelahColors.ink(0.86),
                              ),
                            ),
                          SizedBox(height: 6),
                          Text(
                            '${profile.age} · ${profile.city}',
                            style: SelahText.subtext(
                              size: 12.5,
                              color: SelahColors.ink(0.78),
                            ),
                          ),
                          if (reviewOpen) ...[
                            SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: SelahColors.surfaceEmphasisFill,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: SelahColors.surfaceEmphasisBorder,
                                  width: 0.6,
                                ),
                              ),
                              // THE ONE MAP, still. familyReviewOverride is
                              // the same string the Journey itself shows —
                              // no second wording was invented here
                              // (inherited decision 129).
                              child: Text(
                                SelahJourneyStages.familyReviewOverride,
                                style: SelahText.subtext(
                                  size: 11,
                                  color: SelahColors.foreground,
                                ),
                              ),
                            ),
                          ],
                          if (decisionPending) ...[
                            SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: SelahColors.surfaceEmphasisFill,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: SelahColors.surfaceEmphasisBorder,
                                  width: 0.6,
                                ),
                              ),
                              child: Text(
                                'Pause decision pending',
                                style: SelahText.subtext(
                                  size: 11,
                                  color: SelahColors.foreground,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    // REPORT, TOP RIGHT. Founder, 2026-08-10: the flag must
                    // exist at every stage, and on this card it belongs here.
                    //
                    // NOT repeated inside Enter or View timeline — the
                    // Founder's call, and the right one: the flag is about
                    // the PERSON, and this card is where the person is. A
                    // flag on every screen of a Journey would read as the app
                    // expecting something to go wrong.
                    //
                    // Same icon, size and alpha as the flag on every other
                    // card in this file. It opens the same sheet, with
                    // SelahReportSource.connections, so reports from here land
                    // where reports from the other cards land.
                    _ConnectionsReportFlag(
                      profileId: profile.id,
                      firstName: profile.firstName,
                      onTap: onReport,
                    ),
                  ],
                ),
                SizedBox(height: 16),
                // MID-CONFIRM the bands step aside and the confirm
                // holds the card (round four — no popups on this page).
                if (inlineConfirm != null) ...[
                  Container(height: 1, color: SelahColors.ink(0.14)),
                  SizedBox(height: 12),
                  inlineConfirm!,
                ] else ...[
                  // CONNECTIONS OPTION 4 — Founder, 2026-08-20. One primary
                  // Journey action, then a compact open rail for the three
                  // secondary destinations. Report remains the flag above;
                  // Pause and End sit behind Options and still open their
                  // existing inline confirmation before any write.
                  _ConnectionsActionDeck(
                    primary: _ConnectionsActionItem(
                      icon: Icons.route_outlined,
                      label: decisionPending
                          ? 'Open decision'
                          : hasBegun
                          ? 'Continue Journey'
                          : 'Begin Journey',
                      onTap: onEnter,
                    ),
                    actions: [
                      _ConnectionsActionItem(
                        icon: Icons.person_outline,
                        label: 'View Profile',
                        onTap: onViewProfile,
                      ),
                      _ConnectionsActionItem(
                        icon: Icons.timeline_outlined,
                        label: 'Timeline',
                        onTap: onTimeline,
                      ),
                      _ConnectionsActionItem(
                        icon: Icons.more_horiz,
                        label: decisionPending ? 'Decision' : 'Options',
                        onTap: onOptions,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _ActiveJourneyOption { pause, end }

class _ActiveJourneyOptionsSheet extends StatelessWidget {
  final String firstName;

  const _ActiveJourneyOptionsSheet({required this.firstName});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: SelahColors.modalSheetSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 11, 20, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: SelahColors.ink(0.24),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              SizedBox(height: 18),
              Text('Journey options', style: SelahText.heading(size: 22)),
              SizedBox(height: 5),
              Text(
                'Manage your Journey with $firstName.',
                style: SelahText.subtext(size: 12),
              ),
              SizedBox(height: 14),
              _ActiveJourneyOptionRow(
                icon: Icons.pause_rounded,
                label: 'Request Pause',
                detail: '$firstName chooses whether to pause or continue.',
                onTap: () =>
                    Navigator.of(context).pop(_ActiveJourneyOption.pause),
              ),
              _ActiveJourneyOptionRow(
                icon: Icons.close_rounded,
                label: 'End Journey',
                detail: 'Close this Journey permanently. Your Timeline stays.',
                danger: true,
                onTap: () =>
                    Navigator.of(context).pop(_ActiveJourneyOption.end),
              ),
              SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Cancel',
                    style: SelahText.button(
                      size: 12,
                    ).copyWith(color: SelahColors.ink(0.70)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActiveJourneyOptionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String detail;
  final VoidCallback onTap;
  final bool danger;

  const _ActiveJourneyOptionRow({
    required this.icon,
    required this.label,
    required this.detail,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = danger ? _takeoverCoral : SelahColors.foreground;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 62),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: SelahColors.ink(0.12), width: 0.6),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: foreground.withValues(alpha: 0.09),
                ),
                child: Icon(icon, size: 18, color: foreground),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: SelahText.body(
                        size: 13,
                      ).copyWith(color: foreground),
                    ),
                    SizedBox(height: 3),
                    Text(
                      detail,
                      style: SelahText.subtext(
                        size: 10.5,
                        color: danger
                            ? _takeoverCoral.withValues(alpha: 0.70)
                            : SelahColors.ink(0.38),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: foreground.withValues(alpha: 0.72),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The app's existing pill — circular(20), iconButtonBg/iconButtonBorder —
/// with one variant. `primary` fills it so the Journey action reads as the
/// main one without introducing a colour.
///
/// The pills are NO LONGER the same width. Founder, 2026-08-10: the Timeline
/// pill is smaller than the Journey pill, 1 : 2 — the Journey is the action
/// and the Timeline is a reference, and equal widths claimed they were equal
/// choices. Heights stay equal so they still sit level.
class _CardPill extends StatelessWidget {
  final String label;

  // SUBLABEL RETIRED 2026-08-10. It carried the Journey stage under the
  // label — "Enter · Compatibility Reveal" — from an earlier Founder ruling
  // (Timeline spec §12, option C) that put the stage on the control leading
  // to it. Reversed the same day: "I don't want enter open conversation in
  // smaller text." The pill now says one thing.
  //
  // Removed rather than left unused, and `stageLabel` came off
  // _ActiveJourneyCard with it. A parameter written by a caller and read by
  // nothing is the shape of the `profile_complete` defect in the 2026-07-26
  // audit — the stage is still shown where it belongs, inside the Journey.

  final VoidCallback onTap;
  final bool primary;

  const _CardPill({
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: SelahColors.iconButtonBg,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          // 44, down from 46. The taller box existed to fit a second line —
          // the stage sublabel — which came off on 2026-08-10. Kept fixed and
          // equal on both pills so the narrow Timeline one still sits level
          // with the wide Journey one.
          height: 44,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: SelahColors.iconButtonBorder,
              width: primary ? 1 : 0.5,
            ),
          ),
          // A Column with one child, left over from the two-line version.
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: SelahText.button(size: 13.5),
          ),
        ),
      ),
    );
  }
}

// _JourneyTile DELETED 2026-08-12 — every Journey row now uses
// _JourneyExpandingCard (the Activity model, Founder: "copy that model").
// The header comment at the top of this file still names the old tile in
// its history; the widget itself is in git.
// ═══════════════════════════════════════════════════════════════════════
// The takeover, INLINE — what a tap on "Begin" becomes when the plan's
// Active Journey cap is already full.
//
// A POPUP UNTIL 2026-08-12, EVENING. Founder picked B1 (one blocks) and
// C1 (several block) as glass dialogs earlier that same day, then — shown
// three presentations side by side in the interactive round (B1 the
// glass dialog, B2 the same dialog solid pink/purple, B3 the card itself
// extending) — chose the card: "point 4 do b3". Same parts, same words,
// same hierarchy as the dialogs; only the surface changed. Two knock-ons,
// both deliberate: the dialogs' tap-outside dismissal became a written
// "Not now" (a card extension has no outside), and the person's portrait
// shortens to a strip while the choice is open — the accepted cost of
// fitting the choice where the person already is.
//
// TWO shapes, one set of parts:
//
//   _InlineTakeover (B1's shape, of eleven mockups across three rounds)
//   — ONE Journey blocks. Both people at the top as circular photos
//   ("you're deciding about a person, not a slot"), a one-line body,
//   Continue as the hero out of respect to the active Journey — his
//   word: 'continue', never 'stay' — then Pause and End as square cards.
//
//   _InlineTakeoverChooser (C1's shape, over the two-step C2) — SEVERAL
//   block, which exists since plan_aware_active_journey_limit made SELAH
//   One's cap of 3 real. The new person waits at the top; the active
//   people are tappable chips; the same square cards re-aim at whoever
//   is chosen and stay dim and inert until someone is.
//
// The avatar and the cards are top-level functions shared by both, so the
// two shapes cannot drift apart. The below-cap Begin confirm is STILL a
// dialog — it was never part of the B1/B2/B3 round.
//
// Three ways out, every one of them honest:
//   Continue / Not now  dismiss — nothing changes, and the caption says so
//   Request Pause  asks the current person; the waiting Journey cannot begin
//                  unless both agree and the Active slot is released
//   End       endJourney, then the promote; permanent, Timeline kept
// ═══════════════════════════════════════════════════════════════════════

enum _TakeoverChoice { continueCurrent, requestPause, endAndBegin }

const Color _takeoverCoral = SelahColors.destructive;

/// One person: circular photo over a "Name · State" caption. photoUrl is
/// photos.first and throws on an empty list — real profiles always carry
/// one, but the dev panel's no-pool stand-ins are built with
/// photos: const [], so an initial in a circle keeps the dialog whole.
Widget _takeoverPerson(SeekerProfile p, String label, {required bool waiting}) {
  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Opacity(opacity: waiting ? 0.65 : 1, child: _takeoverAvatar(p, 46)),
      SizedBox(height: 4),
      Text(
        '${p.firstName} · $label',
        style: SelahText.subtext(size: 10, color: SelahColors.ink(0.55)),
      ),
    ],
  );
}

Widget _takeoverAvatar(SeekerProfile p, double size) {
  return Container(
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: SelahColors.ink(0.35), width: 2),
    ),
    child: ClipOval(
      child: p.photos.isEmpty
          ? Container(
              width: size,
              height: size,
              color: SelahColors.ink(0.22),
              alignment: Alignment.center,
              child: Text(
                p.firstName.isEmpty ? '?' : p.firstName[0],
                style: SelahText.heading(size: 16),
              ),
            )
          : SelahProfileImage(p.photoUrl, width: size, height: size),
    ),
  );
}

/// A square Pause/End choice card (B1's body). A null [onTap] renders it
/// dim and inert — the C1 chooser shows the cards before a person is
/// picked, and a card with nobody's name on it must not be pressable.
Widget _takeoverChoiceCard({
  required String title,
  required String sub,
  required bool danger,
  required VoidCallback? onTap,
}) {
  return Opacity(
    opacity: onTap == null ? 0.45 : 1,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        decoration: BoxDecoration(
          color: danger
              ? SelahColors.destructive.withValues(alpha: 0.08)
              : SelahColors.surfaceFill,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: danger
                ? _takeoverCoral.withValues(alpha: 0.55)
                : SelahColors.surfaceBorder,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: SelahText.button(size: 12.5).copyWith(
                color: danger ? _takeoverCoral : SelahColors.foreground,
              ),
            ),
            SizedBox(height: 4),
            Text(
              sub,
              textAlign: TextAlign.center,
              style: SelahText.subtext(size: 10, color: SelahColors.ink(0.50)),
            ),
          ],
        ),
      ),
    ),
  );
}

/// "He keeps his place" / "She keeps her place" — gender is
/// server-segregated (H1), so the counterpart's is always set; the pronoun
/// keeps the card personal the way the approved mock was.
String _keepsPlaceLine(SeekerProfile p) => SelahGender.keepsPlaceLine(p.gender);

/// COMPRESSED, NOT DROPPED. The Shepherd-visibility disclosure is a
/// 2026-08-01 Founder decision ("stated consistently everywhere"), and
/// every start-shaped popup leads straight to the promote that opens RLS
/// to both Shepherds — there is no second confirm behind any of them.
/// One quiet line, identical in the plain start, B1 and C1 dialogs,
/// keeps the disclosure at the moment it matters (the long paragraph
/// retired with the dialog restyle, Founder-directed, 2026-08-12).
Widget _takeoverDisclosure() {
  return Text(
    'From the first message, each person’s Main Shepherd and any Additional '
    'Shepherds included in this Journey can read the conversation.',
    textAlign: TextAlign.center,
    style: SelahText.subtext(size: 10, color: SelahColors.ink(0.42)),
  );
}

class _InlineTakeover extends StatelessWidget {
  final JourneyMatch active;
  final JourneyMatch next;
  final VoidCallback onDismiss;
  final void Function(_TakeoverChoice choice) onChoice;
  const _InlineTakeover({
    required this.active,
    required this.next,
    required this.onDismiss,
    required this.onChoice,
  });

  @override
  Widget build(BuildContext context) {
    final activeName = active.profile.firstName;
    final nextName = next.profile.firstName;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // The leading divider left 2026-08-13 (round four): the card's
        // ✕ header carries the one divider now — extensions start with
        // their content.
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _takeoverPerson(active.profile, 'Active', waiting: false),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 18),
              child: Icon(
                Icons.swap_horiz,
                size: 18,
                color: Colors.white.withValues(alpha: 0.55),
              ),
            ),
            _takeoverPerson(next.profile, 'Waiting', waiting: true),
          ],
        ),
        SizedBox(height: 12),
        Text(
          'Begin with $nextName?',
          style: SelahText.heading(size: 18),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 8),
        Text(
          'One Journey at a time — choose what happens with $activeName.',
          style: SelahText.subtext(),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          // Frost primary since 2026-08-13 (the consistency ruling) —
          // Continue = dismiss, exactly as the dialog treated it: the
          // caption below says nothing changes, and nothing does.
          child: _CardPill(
            label: 'Continue with $activeName',
            onTap: onDismiss,
            primary: true,
          ),
        ),
        SizedBox(height: 6),
        Text(
          'Nothing changes — carry on where you left off.',
          style: SelahText.subtext(size: 10, color: SelahColors.ink(0.42)),
        ),
        SizedBox(height: 12),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _takeoverChoiceCard(
                  title: 'Request Pause',
                  sub: '$activeName must agree before this slot is free.',
                  danger: false,
                  onTap: () => onChoice(_TakeoverChoice.requestPause),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _takeoverChoiceCard(
                  title: 'End with $activeName',
                  sub: 'Permanent. Your Timeline is kept.',
                  danger: true,
                  onTap: () => onChoice(_TakeoverChoice.endAndBegin),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 12),
        _takeoverDisclosure(),
        // The dialogs could be dismissed by tapping outside; a card
        // extension has no outside, so the way out is written down.
        TextButton(
          onPressed: onDismiss,
          child: Text('Not now', style: SelahText.subtext()),
        ),
      ],
    );
  }
}

class _InlineTakeoverChooser extends StatefulWidget {
  final List<JourneyMatch> actives;
  final JourneyMatch next;
  final VoidCallback onDismiss;
  final void Function(_TakeoverChoice choice, JourneyMatch other) onChoice;
  const _InlineTakeoverChooser({
    required this.actives,
    required this.next,
    required this.onDismiss,
    required this.onChoice,
  });

  @override
  State<_InlineTakeoverChooser> createState() => _InlineTakeoverChooserState();
}

class _InlineTakeoverChooserState extends State<_InlineTakeoverChooser> {
  /// Nobody is pre-selected, deliberately: pre-picking a person would
  /// nudge toward pausing or ending THEM, and the whole hierarchy of this
  /// dialog is respect for the Journeys already under way. The cards wake
  /// up only once a choice is made.
  JourneyMatch? _selected;

  String get _countWord => switch (widget.actives.length) {
    2 => 'two',
    3 => 'three',
    final n => '$n',
  };

  @override
  Widget build(BuildContext context) {
    final nextName = widget.next.profile.firstName;
    final sel = _selected;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // The leading divider left 2026-08-13 (round four): the card's
        // ✕ header carries the one divider now — extensions start with
        // their content.
        _takeoverPerson(widget.next.profile, 'Waiting', waiting: true),
        SizedBox(height: 10),
        Text(
          'Begin with $nextName?',
          style: SelahText.heading(size: 18),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 8),
        Text(
          'Your $_countWord Journeys are all active — choose who makes '
          'room.',
          style: SelahText.subtext(),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            for (final a in widget.actives)
              InkWell(
                onTap: () => setState(() => _selected = a),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: 72,
                  padding: const EdgeInsets.fromLTRB(4, 8, 4, 7),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: identical(a, sel)
                        ? SelahColors.surfaceEmphasisFill
                        : SelahColors.surfaceFill,
                    border: Border.all(
                      color: identical(a, sel)
                          ? SelahColors.surfaceEmphasisBorder
                          : SelahColors.surfaceBorder,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _takeoverAvatar(a.profile, 40),
                      SizedBox(height: 5),
                      Text(
                        a.profile.firstName,
                        overflow: TextOverflow.ellipsis,
                        style: SelahText.subtext(
                          size: 10,
                          color: SelahColors.ink(0.55),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          // Frost primary since 2026-08-13 (the consistency ruling) —
          // Continue = dismiss: nothing changes, and the caption below
          // says so — exactly how the dialog treated its null.
          child: _CardPill(
            label: 'Continue as things are',
            onTap: widget.onDismiss,
            primary: true,
          ),
        ),
        SizedBox(height: 6),
        Text(
          widget.actives.length == 2
              ? 'Both Journeys stay exactly as they are.'
              : 'All $_countWord Journeys stay exactly as they are.',
          style: SelahText.subtext(size: 10, color: SelahColors.ink(0.42)),
        ),
        SizedBox(height: 12),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _takeoverChoiceCard(
                  title: sel == null ? 'Request Pause' : 'Request Pause',
                  sub: sel == null
                      ? 'Choose someone above first.'
                      : '${sel.profile.firstName} must agree before this slot is free.',
                  danger: false,
                  onTap: sel == null
                      ? null
                      : () =>
                            widget.onChoice(_TakeoverChoice.requestPause, sel),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _takeoverChoiceCard(
                  title: sel == null
                      ? 'End'
                      : 'End with ${sel.profile.firstName}',
                  sub: sel == null
                      ? 'Choose someone above first.'
                      : 'Permanent. Your Timeline is kept.',
                  danger: true,
                  onTap: sel == null
                      ? null
                      : () => widget.onChoice(_TakeoverChoice.endAndBegin, sel),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 12),
        _takeoverDisclosure(),
        // Same written way out as _InlineTakeover — no outside to tap.
        TextButton(
          onPressed: widget.onDismiss,
          child: Text('Not now', style: SelahText.subtext()),
        ),
      ],
    );
  }
}

/// The restart ask, inline — the ended card's extension (2026-08-13,
/// Founder: "we changed the ui to give notification like we did for
/// potential"). The COPY IS THE DIALOG'S, unchanged since 2026-08-11:
/// same title, same both-must-agree body, same Send request / Not now
/// pair. Only the surface moved — the ask now happens where the person
/// is, exactly like the takeover, with the same divider-topped extension
/// language. No Shepherd disclosure here on purpose: sending a request
/// opens nothing — RLS widens only if they accept and a Journey actually
/// begins, and THAT moment carries the disclosure.
class _InlineRestartAsk extends StatelessWidget {
  final JourneyMatch next;
  final VoidCallback onDismiss;
  final Future<void> Function() onSend;
  const _InlineRestartAsk({
    required this.next,
    required this.onDismiss,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final name = next.profile.firstName;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // The leading divider left 2026-08-13 (round four): the card's
        // ✕ header carries the one divider now — extensions start with
        // their content.
        Icon(Icons.restart_alt_outlined, size: 26, color: Colors.white70),
        SizedBox(height: 10),
        Text(
          'Ask $name to begin a new Journey?',
          style: SelahText.heading(size: 17),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 8),
        Text(
          "They'll be told you asked, and can accept or decline. Nothing "
          'starts unless they agree.\n\nIf they accept, this is a fresh '
          'Journey — a new conversation, from the beginning. Everything '
          'from before is kept, and stays where it is.',
          style: SelahText.subtext(),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          // Frost primary since 2026-08-13 (the consistency ruling).
          child: _CardPill(
            label: 'Send request',
            onTap: () => onSend(),
            primary: true,
          ),
        ),
        // The dialog's dismissal, written down — no outside to tap.
        TextButton(
          onPressed: onDismiss,
          child: Text('Not now', style: SelahText.subtext()),
        ),
      ],
    );
  }
}

/// The begin confirm, inline — the flow's LAST popup, retired 2026-08-13
/// (Founder: "we agreed we were moving away from popups"). The dialog's
/// exact parts in the card's extension language: the person as a circular
/// photo over 'Ready', the one-line seriousness body, Begin as the frost
/// primary, 'Not yet', and the Shepherd disclosure — stated, as always,
/// at the exact moment a Begin would open RLS to both Shepherds.
class _InlineBeginConfirm extends StatelessWidget {
  final JourneyMatch next;
  final VoidCallback onDismiss;
  final Future<void> Function() onBegin;
  const _InlineBeginConfirm({
    required this.next,
    required this.onDismiss,
    required this.onBegin,
  });

  @override
  Widget build(BuildContext context) {
    final name = next.profile.firstName;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _takeoverPerson(next.profile, 'Ready', waiting: false),
        SizedBox(height: 12),
        Text(
          'Begin with $name?',
          style: SelahText.heading(size: 18),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 8),
        Text(
          'One person at a time, with both families present — it '
          'begins with Compatibility Reveal.',
          style: SelahText.subtext(),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: _CardPill(
            label: 'Begin with $name',
            onTap: () => onBegin(),
            primary: true,
          ),
        ),
        TextButton(
          onPressed: onDismiss,
          child: Text('Not yet', style: SelahText.subtext()),
        ),
        SizedBox(height: 2),
        _takeoverDisclosure(),
      ],
    );
  }
}

/// One confirm, inline — the shape every stay-or-go confirm on this page
/// now takes (round four, 2026-08-13: Pause and End on the Active card,
/// End on a paused card). Title, one honest body line, the action as the
/// app's pill (frost for reversible, the dark-coral End pill for
/// permanent), and the written dismissal underneath. The ✕ in the card's
/// header is the other way out; both do the same nothing.
class _InlineConfirmBlock extends StatelessWidget {
  final String title;
  final String body;
  final String actionLabel;
  final bool danger;
  final Future<void> Function() onConfirm;
  final String dismissLabel;
  final VoidCallback onDismiss;
  const _InlineConfirmBlock({
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.danger,
    required this.onConfirm,
    required this.dismissLabel,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: SelahText.heading(size: 16),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 8),
        Text(body, style: SelahText.subtext(), textAlign: TextAlign.center),
        SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: danger
              ? Material(
                  color: const Color(0x48140C1A),
                  shape: StadiumBorder(
                    side: BorderSide(
                      color: _takeoverCoral.withValues(alpha: 0.75),
                    ),
                  ),
                  child: InkWell(
                    customBorder: const StadiumBorder(),
                    onTap: () => onConfirm(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Center(
                        child: Text(
                          actionLabel,
                          style: SelahText.button(
                            size: 13,
                          ).copyWith(color: const Color(0xFFF0A2A0)),
                        ),
                      ),
                    ),
                  ),
                )
              : _CardPill(
                  label: actionLabel,
                  onTap: () => onConfirm(),
                  primary: true,
                ),
        ),
        TextButton(
          onPressed: onDismiss,
          child: Text(dismissLabel, style: SelahText.subtext()),
        ),
      ],
    );
  }
}
