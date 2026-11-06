// Pre-Journey Ritual host screen — APP/Journey/PRE-JOURNEY RITUAL/
// Summary.md. Routes an Active Journey through its real stages
// (matches.journey_stage): Greeting Exchange -> Compatibility Reveal ->
// Faith & Values -> Building a Life -> Navigating Life -> Family -> Conversation. Reached
// from the Connections tab (screens/connections/connections_screen.dart,
// formerly MatchesScreen — renamed 2026-07-26 nav bar fix) after
// SelahJourneyService.promoteToActive().
//
// 2026-07-26 (#31, inherited decision 110): the 4 "both Seekers complete a stage"
// transitions (phase_1->2, phase_2->3, phase_3->family_stage,
// family_stage->conversation) no longer advance journey_stage
// directly — each opens a 48-hour Family Review Period first (MENTOR_
// ARCHITECTURE_CURRENT_VERSION_V6.md §FAMILY REVIEW PERIOD), during
// which either Seeker's main Shepherd may Continue or Pause from mentor_
// journey_detail_screen.dart. See _advanceGated()/_FamilyReviewView
// below, and 20260726190000_family_review_period.sql.
//
// REDUCED V1 SCOPE (Founder decision, 2026-07-25, inherited decision 101 audit):
// - Fixed-order questions stand in for "AI-adaptive question
//   selection" — no LLM integration exists in this codebase (see
//   journey_questions.dart).
// - Part B (searchable personal question library) is not built —
//   Part A (fixed questions) only.
// - "Ask More" is not offered as a checkpoint choice this pass — only
//   Continue / End Journey. The `ask_more` decision value still exists
//   in the database for future use.
// - Family Compatibility Stage covers Seeker<->Shepherd directions only —
//   Shepherd<->Shepherd is explicitly marked TBC in the source spec. There is
//   no Shepherd-side screen to answer "seeker_to_mentor" questions yet
//   (Shepherd app has no Journey visibility built at all — see
//   MENTOR_ARCHITECTURE_CURRENT_VERSION_V5.md's "future dedicated
//   session" note), so this stage completes once the signed-in Seeker
//   has answered their own "mentor_to_seeker" questions.
// - No Realtime — simultaneous-reveal / "waiting for the other party"
//   states use bounded foreground polling rather than a Supabase Realtime
//   channel. Requests are coalesced, stop in the background and run every
//   5–8 seconds depending on the stage.
// - Compatibility category breakdown mirrors the overall score for
//   every category (score_candidates() doesn't expose per-category
//   detail yet) — a real breakdown is future work.

import 'dart:async';
import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../../widgets/selah_switch.dart';
import '../../dev/selah_app_gold_preview.dart';
import 'package:flutter/services.dart';
import '../../data/journey_questions.dart';
import '../../data/selah_journey_life_snapshot.dart';
import '../../data/selah_journey_advance_policy.dart';
import '../../data/selah_journey_intelligence.dart';
import '../../data/selah_journey_pause_state.dart';
import '../../data/selah_journey_scroll.dart';
import '../../data/selah_journey_stages.dart';
import '../../data/selah_journey_header.dart';
import '../mentor/seeker_shepherd_designs.dart'
    show selahShepherdShortDisplayName;
import '../../data/selah_release_gates.dart';
import '../../dev/selah_dev_scenario.dart';
import '../../dev/selah_dev_tool_section.dart';
import '../../models/journey_match.dart';
import '../../models/seeker_profile.dart';
import '../../models/selah_gender.dart';
import '../../models/selah_identity_verification.dart';
import '../../services/selah_auth.dart';
import '../../services/selah_account_state.dart';
import '../../services/selah_developer_access.dart';
import '../../services/selah_image_cache.dart';
import '../../services/selah_journey_service.dart';
import '../../services/selah_identity_verification_service.dart';
import '../../services/selah_mentor_link_service.dart';
import '../../state/app_state.dart';
import '../../theme/selah_colors.dart';
import '../../theme/selah_text.dart';
import '../chat/chat_screen.dart';
import '../matches/journey_timeline_screen.dart';
import '../onboarding/identity_verification_screen.dart';
// seeker_profile_screen / journey_map_screen imports left with the
// header pill row (2026-08-13) — Profile lives on the Connections card,
// the Map inside the Timeline.
// THE EXPERIENCE LAB RETIRED HERE — inherited decision 185. Three rounds of
// on-device walks and three rounds of mocks ended at QUIET, which is
// now simply how the Journey looks; journey_experience_lab.dart is
// unreferenced and awaits git deletion.
// selah_report_service / anchored_card_overlay / report_profile_sheet
// imports left with the ⋮ menu (2026-08-13) — reporting from a Journey
// now happens at the person: the Active card's flag on Connections.
import '../../widgets/selah_glass_dialog.dart';
import '../../widgets/selah_intelligence_card.dart';
import '../../widgets/selah_loading.dart';
import '../../widgets/selah_profile_image.dart';
import '../../widgets/selah_state_widgets.dart';
import '../../widgets/selah_write_feedback.dart';

/// Network polling must stop when iOS has put SELAH in the background. Timers
/// otherwise keep waking the process until the OS suspends it, wasting radio
/// and CPU for state that cannot be seen.
bool get _journeyAppIsForeground {
  final state = WidgetsBinding.instance.lifecycleState;
  return state == null || state == AppLifecycleState.resumed;
}

/// A Journey left underneath Timeline, Chat or a confirmation route is not
/// visible work. Foreground-only was not enough: iOS remains resumed while a
/// second route covers this one, so every stage timer kept waking and reading.
bool _journeyViewCanPoll(BuildContext context) =>
    _journeyAppIsForeground && (ModalRoute.of(context)?.isCurrent ?? true);

class JourneyFlowScreen extends StatefulWidget {
  final String matchId;
  final SeekerProfile profile;
  final VoidCallback? onOpenShepherd;

  /// Injectable transport for deterministic widget tests; ordinary routes
  /// always use the caller-bound Shepherd service. This is not server authority.
  final Future<SelahJourneyShepherdGate> Function(String matchId)?
  shepherdGateLoader;
  const JourneyFlowScreen({
    super.key,
    required this.matchId,
    required this.profile,
    this.onOpenShepherd,
    this.shepherdGateLoader,
  });

  @override
  State<JourneyFlowScreen> createState() => _JourneyFlowScreenState();
}

class _JourneyFlowScreenState extends State<JourneyFlowScreen> {
  late final String? _journeyOwnerUserId;
  late final int _journeyAccountGeneration;
  late final DevPage _previousDevPage;
  String _status = 'active';
  String? _stage =
      'greeting_exchange'; // first stage — Greeting first, inherited decision 183
  SelahJourneyPauseState _pauseState = SelahJourneyPauseState.active;
  bool? _pauseCapacityAvailable;
  bool _loading = true;
  bool _stageLoaded = false;
  Timer? _poll;
  bool _pollRefreshBusy = false;
  Future<void>? _refreshFlight;
  bool _identityGateLoading =
      SelahIdentityVerificationService.enforceExistingAccountGate;
  bool _journeyExperienceStarted = false;
  bool _shepherdGateLoading = true;
  SelahJourneyShepherdGate _shepherdGate = SelahJourneyShepherdGate.unavailable;
  int _shepherdGateGeneration = 0;
  String? _ownMainShepherdName;
  String? _legacyPassThroughFailureReason;
  ModalRoute<dynamic>? _ownerRoute;
  bool? _ownerRouteCurrent;
  int _journeyOwnerRevision = 0;

  bool get _journeyAccountCurrent =>
      _journeyOwnerUserId != null &&
      !SelahAccountState.isSigningOut &&
      SelahAuth.currentUser?.id == _journeyOwnerUserId &&
      SelahAccountState.isCurrent(
        _journeyOwnerUserId,
        _journeyAccountGeneration,
      );
  ({SelahCompatibilityReadScope scope, Object context, bool admitted})?
  _compatibilitySurfaceContext;
  int _compatibilitySurfaceGeneration = 0;
  SelahIdentityVerificationState? _identityVerification;
  Object? _identityGateError;

  ({
    SelahJourneyStage stage,
    String nextLabel,
    Future<void> Function() continueAction,
    bool completionConfirmed,
  })?
  _stageDecision;
  bool _stageDecisionBusy = false;
  Object _stageDecisionToken = Object();
  bool _stageContinueSelected = false;
  bool _stageActionVisible = false;
  String? _viewedRibbonStage;
  bool _pauseActionBusy = false;
  SelahJourneyPauseState? _devPausePreview;
  SelahPauseDevScenario _devPauseScenario = SelahPauseDevScenario.active;
  bool _devPauseEnded = false;
  bool _lifeSnapshotOpen = false;
  bool _lifeSnapshotOpenedFromDevJump = false;
  bool _lifeSnapshotMineRevealed = false;
  bool _lifeSnapshotTheirsRevealed = false;
  bool _devLifeSnapshotHasBio = true;
  Set<String> _devLifeSnapshotFieldIds =
      SelahJourneyLifeSnapshotMock.defaultVisibleFieldIds;
  final Map<String, GlobalKey<_JourneyStageScrollShellState>> _stageScrollKeys =
      {};

  // #31 — Family Review Period. Non-null (pending or paused) means a
  // gated stage transition (phase_1->2, phase_2->3, phase_3->family_
  // stage, family_stage->conversation) is currently held, and
  // _buildStage below shows _FamilyReviewView instead of the next
  // stage's normal UI. See openFamilyReview()'s own doc comment.
  ({String id, String status, String toStage, DateTime deadlineAt})? _review;

  // Why the last advance attempt did not move the Journey on, in the
  // server's own vocabulary (see SelahStageAdvance). Null means either
  // "nothing attempted yet" or "it advanced". Rendered by the stage
  // views so the user is told what is actually being waited on, rather
  // than pressing Continue into silence — which is exactly what the
  // 2026-08-07 release blocker looked like from the outside.
  String? _advanceReason;

  @override
  void initState() {
    super.initState();
    _journeyOwnerUserId = SelahAuth.currentUser?.id;
    _journeyAccountGeneration = SelahAccountState.generation;
    final dev = SelahDevScenario.instance;
    _previousDevPage = dev.currentPage;
    dev.setCurrentPage(DevPage.activeJourney);
    final devScenario = dev.pauseScenario;
    if (SelahDeveloperAccess.canUseDeveloperTools &&
        devScenario != SelahPauseDevScenario.active) {
      final me = SelahAuth.currentUser?.id ?? 'dev-me';
      _devPauseScenario = devScenario;
      _devPausePreview = devScenario.stateFor(
        viewerId: me,
        otherId: widget.profile.id,
      );
      _devPauseEnded = devScenario.isEnded;
    }
    dev.addListener(_onDevScenarioChanged);
    SelahDeveloperAccess.authorizationChanges.addListener(
      _onShepherdAuthorityChanged,
    );
    SelahMentorLinkService.linkRevision.addListener(_onShepherdLinksChanged);
    _resolveMainShepherdGate();
    if (SelahIdentityVerificationService.enforceExistingAccountGate) {
      _resolveIdentityGate();
    } else {
      _startJourneyExperience();
    }
  }

  Future<void> _resolveIdentityGate() async {
    if (mounted) {
      setState(() {
        _identityGateLoading = true;
        _identityGateError = null;
      });
    }
    try {
      final state = await SelahIdentityVerificationService.fetchMyState();
      if (!mounted) return;
      setState(() {
        _identityVerification = state;
        _identityGateLoading = false;
      });
      if (state?.allowsActiveJourney == true) _startJourneyExperience();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _identityGateLoading = false;
        _identityGateError = error;
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    final current = route?.isCurrent;
    if (_ownerRoute != null &&
        (!identical(route, _ownerRoute) || current != _ownerRouteCurrent)) {
      _journeyOwnerRevision++;
    }
    _ownerRoute = route;
    _ownerRouteCurrent = current;
  }

  bool Function() _captureJourneyOwner({bool requireMain = false}) {
    final userId = _journeyOwnerUserId;
    final accountGeneration = _journeyAccountGeneration;
    final matchId = widget.matchId;
    final profileId = widget.profile.id;
    final revision = _journeyOwnerRevision;
    final linksRevision = SelahMentorLinkService.linkRevision.value;
    var retired = false;
    return () {
      if (retired) return false;
      final current =
          mounted &&
          userId != null &&
          SelahAuth.currentUser?.id == userId &&
          !SelahAccountState.isSigningOut &&
          SelahAccountState.isCurrent(userId, accountGeneration) &&
          widget.matchId == matchId &&
          widget.profile.id == profileId &&
          revision == _journeyOwnerRevision &&
          linksRevision == SelahMentorLinkService.linkRevision.value &&
          _ownerRoute?.isCurrent == true &&
          (!requireMain ||
              (_status == 'active' &&
                  !_devPauseEnded &&
                  !(_devPausePreview ?? _pauseState).isLocked &&
                  _review == null &&
                  !_shepherdGateLoading &&
                  _shepherdGate == SelahJourneyShepherdGate.ready));
      if (!current) retired = true;
      return current;
    };
  }

  void _startJourneyExperience() {
    if (_journeyExperienceStarted) return;
    _journeyExperienceStarted = true;
    _refresh();
    _loadPlusUnlock();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _warmJourneyPortraits();
    });
    _poll = Timer.periodic(const Duration(seconds: 8), (_) => _pollRefresh());
  }

  Future<void> _pollRefresh() async {
    if (_pollRefreshBusy || !_journeyViewCanPoll(context)) return;
    _pollRefreshBusy = true;
    try {
      await _refresh(showSpinner: false);
    } finally {
      _pollRefreshBusy = false;
    }
  }

  /// Warm only the two portraits this Journey actually needs. The shared
  /// cache writes the bytes to the OS cache directory with the same stable,
  /// tokenless key used everywhere else, so returning to the stage is instant
  /// without persisting Journey state or another person's profile record.
  void _warmJourneyPortraits() {
    final urls = <String>{};
    final ownPhotos = AppState.instance.photos;
    if (ownPhotos.isNotEmpty && ownPhotos.first.isNotEmpty) {
      urls.add(ownPhotos.first);
    }
    if (widget.profile.photos.isNotEmpty &&
        widget.profile.photos.first.isNotEmpty) {
      urls.add(widget.profile.photos.first);
    }
    for (final url in urls) {
      unawaited(_precacheJourneyPortrait(url));
    }
  }

  Future<void> _precacheJourneyPortrait(String url) async {
    try {
      await precacheImage(
        CachedNetworkImageProvider(
          url,
          cacheKey: SelahImageCache.keyFor(url),
          cacheManager: SelahImageCache.manager,
        ),
        context,
      );
    } catch (_) {
      // A cache miss is answered by SelahProfileImage when the portrait is
      // actually needed. Prefetch is polish and must never block the Journey.
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    final dev = SelahDevScenario.instance;
    dev.removeListener(_onDevScenarioChanged);
    SelahDeveloperAccess.authorizationChanges.removeListener(
      _onShepherdAuthorityChanged,
    );
    SelahMentorLinkService.linkRevision.removeListener(_onShepherdLinksChanged);
    // A developer destination may have changed while this route was open.
    // Only restore the underlying page if this Journey still owns context.
    if (dev.currentPage == DevPage.activeJourney) {
      dev.setCurrentPage(_previousDevPage);
    }
    super.dispose();
  }

  /// Keeps the visible Journey in sync with the app-wide page-aware control.
  /// The previous local-only jumper updated these fields directly; the shared
  /// control writes the same scenario store, so this listener is now the one
  /// rendering boundary for either developer action or an in-preview choice.
  void _onDevScenarioChanged() {
    if (!mounted) return;
    unawaited(_resolveMainShepherdGate());
    final scenario = SelahDeveloperAccess.canUseDeveloperTools
        ? SelahDevScenario.instance.pauseScenario
        : SelahPauseDevScenario.active;
    if (scenario == _devPauseScenario) return;
    final me = SelahAuth.currentUser?.id ?? 'dev-me';
    setState(() {
      _devPauseScenario = scenario;
      _devPausePreview = scenario == SelahPauseDevScenario.active
          ? null
          : scenario.stateFor(viewerId: me, otherId: widget.profile.id);
      _devPauseEnded = scenario.isEnded;
      _stageActionVisible = false;
    });
  }

  void _onShepherdLinksChanged() {
    _journeyOwnerRevision++;
    unawaited(_resolveMainShepherdGate());
  }

  void _onShepherdAuthorityChanged() {
    _journeyOwnerRevision++;
    if (!mounted) return;
    setState(() {
      _shepherdGateLoading = true;
      _shepherdGate = SelahJourneyShepherdGate.unavailable;
      if (!SelahDeveloperAccess.canUseDeveloperTools) {
        _devPauseScenario = SelahPauseDevScenario.active;
        _devPausePreview = null;
        _devPauseEnded = false;
      }
    });
    unawaited(_resolveMainShepherdGate());
  }

  Future<void> _resolveMainShepherdGate() async {
    final request = ++_shepherdGateGeneration;
    final accountGeneration = SelahAccountState.generation;
    final accountId = SelahAccountState.userId;
    bool isCurrent() =>
        mounted &&
        _journeyAccountCurrent &&
        request == _shepherdGateGeneration &&
        !SelahAccountState.isSigningOut &&
        accountGeneration == SelahAccountState.generation &&
        accountId == SelahAccountState.userId;
    final dev = SelahDevScenario.instance;
    if (dev.shepherdOverride) {
      if (!isCurrent()) return;
      setState(() {
        _ownMainShepherdName = null;
        _shepherdGateLoading = false;
        _shepherdGate = dev.mainShepherd && dev.shepherdCount > 0
            ? SelahJourneyShepherdGate.ready
            : SelahJourneyShepherdGate.selfMissing;
      });
      return;
    }
    if (!isCurrent()) return;
    setState(() {
      _ownMainShepherdName = null;
      _shepherdGateLoading = true;
      _shepherdGate = SelahJourneyShepherdGate.unavailable;
    });
    final result =
        await (widget.shepherdGateLoader?.call(widget.matchId) ??
            SelahMentorLinkService.fetchJourneyShepherdGate(widget.matchId));
    if (!isCurrent() || SelahDevScenario.instance.shepherdOverride) return;
    String? ownMainName;
    if (result == SelahJourneyShepherdGate.ready) {
      final links = await SelahMentorLinkService.fetchLinkedPeopleResult(
        asMentor: false,
      );
      if (!isCurrent() || SelahDevScenario.instance.shepherdOverride) return;
      final main = links
          .valueOr(const <MentorLinkedPerson>[])
          .where((person) => person.isMain)
          .firstOrNull;
      if (main != null) ownMainName = selahShepherdShortDisplayName(main);
    }
    setState(() {
      _ownMainShepherdName = ownMainName;
      _shepherdGateLoading = false;
      _shepherdGate = result;
    });
  }

  Future<void> _refresh({
    bool showSpinner = true,
    bool allowLegacyPassThrough = true,
  }) async {
    final active = _refreshFlight;
    if (active != null) return active;
    final next = _refreshOnce(
      showSpinner: showSpinner,
      allowLegacyPassThrough: allowLegacyPassThrough,
    );
    _refreshFlight = next;
    try {
      await next;
    } finally {
      if (identical(_refreshFlight, next)) _refreshFlight = null;
    }
  }

  Future<void> _refreshOnce({
    required bool showSpinner,
    required bool allowLegacyPassThrough,
  }) async {
    if (!_journeyAccountCurrent ||
        (_ownerRoute != null && _ownerRoute?.isCurrent != true)) {
      return;
    }
    final current = _captureJourneyOwner();
    if (showSpinner && mounted) setState(() => _loading = true);
    // #31 — lazy-resolve a due review (48h elapsed, no Pause) before
    // reading the match's current stage, so a Journey whose review
    // timed out while nobody had this screen open still advances the
    // moment either party next opens it, exactly like every other
    // poll-driven state in this screen.
    await SelahJourneyService.resolveFamilyReviewIfDue(widget.matchId);
    if (!current()) return;
    var fresh = await SelahJourneyService.refetchOne(
      widget.matchId,
      widget.profile.id,
    );
    if (!current()) return;

    // LOCK 21: inspect the raw stored key before its display alias. A legacy
    // Shepherd stage is passed through only while the real access gate allows
    // it; existing deliberate-choice retries remain for the other thresholds.
    final review = await SelahJourneyService.fetchFamilyReview(widget.matchId);
    if (!current()) return;
    // An explicit Continue already attempted the existing RPC for this cycle.
    // A conflicting/missing read is held for Retry, never another auto-write.
    if (!allowLegacyPassThrough &&
        review == null &&
        (fresh == null ||
            (fresh.status == 'active' &&
                !fresh.isJourneyLocked &&
                (fresh.journeyStage == 'mentor_gate' ||
                    SelahJourneyStages.of(fresh.journeyStage) == null)))) {
      setState(() {
        _legacyPassThroughFailureReason = 'stage_not_confirmed';
        _loading = false;
      });
      return;
    }
    if (review == null) {
      fresh = await _retryStalledAdvance(fresh, refreshCurrent: current);
    }
    if (!current()) return;
    if (fresh != null) {
      final m = fresh;
      setState(() {
        final stageChanged = _stageLoaded && _stage != m.journeyStage;
        final journeySurfaceChanged =
            stageChanged ||
            _status != m.status ||
            _pauseState.phase != m.pause.phase ||
            _pauseState.version != m.pause.version ||
            (_review == null) != (review == null);
        _stageLoaded = true;
        _status = m.status;
        _stage = m.journeyStage;
        _pauseState = m.pause;
        _review = review;
        if (journeySurfaceChanged) {
          _journeyOwnerRevision++;
          _stageActionVisible = false;
          _viewedRibbonStage = null;
        }
        if (stageChanged) {
          _advanceReason = null;
          _lifeSnapshotOpen = false;
          _lifeSnapshotOpenedFromDevJump = false;
          _lifeSnapshotMineRevealed = false;
          _lifeSnapshotTheirsRevealed = false;
          _stageDecision = null;
          _stageDecisionBusy = false;
          _stageContinueSelected = false;
        }
        if (m.journeyStage != 'mentor_gate' &&
            m.journeyStage != 'compatibility_reveal') {
          _legacyPassThroughFailureReason = null;
        }
        _observeCompatibilitySurface();
        _loading = false;
      });
      if (m.pause.isLocked) {
        final capacityCurrent = _captureJourneyOwner();
        final capacity = await SelahJourneyService.fetchPauseCapacity(
          widget.matchId,
        );
        if (capacityCurrent()) {
          setState(() => _pauseCapacityAvailable = capacity);
        }
      } else if (_pauseCapacityAvailable != null && mounted) {
        setState(() => _pauseCapacityAvailable = null);
      }
    } else if (showSpinner) {
      setState(() => _loading = false);
    }
  }

  /// Re-asks the server to move a two-sided transition that is waiting on the
  /// other party. Returns the match, re-fetched if it moved.
  ///
  /// Threshold stages only. The four gated ones go through a Family Review
  /// and resolveFamilyReviewIfDue() above already retries those.
  Future<JourneyMatch?> _retryStalledAdvance(
    JourneyMatch? fresh, {
    required bool Function() refreshCurrent,
  }) async {
    if (fresh == null || fresh.status != 'active' || fresh.isJourneyLocked) {
      return fresh;
    }
    final stage = fresh.journeyStage;
    if (stage == null) return fresh;
    final legacy = stage == 'mentor_gate';
    if (legacy && _legacyPassThroughFailureReason != null) return fresh;
    if (!legacy &&
        !SelahJourneyAdvancePolicy.shouldRetryStalled(
          stage: stage,
          reason: _advanceReason,
        )) {
      return fresh;
    }
    if (!refreshCurrent()) return fresh;
    if (_shepherdGateLoading) await _resolveMainShepherdGate();
    if (!refreshCurrent()) return fresh;
    final stageCurrent = _captureJourneyOwner(requireMain: true);
    bool current() => refreshCurrent() && stageCurrent();
    if (!current()) return fresh;
    final result = await SelahJourneyService.advanceVisibleThreshold(
      widget.matchId,
      stage,
      canAct: current,
    );
    if (result == null || !current()) return fresh;
    final hiddenRefusal =
        !result.accepted &&
        (legacy ||
            (stage == 'compatibility_reveal' &&
                result.stage != 'compatibility_reveal'));
    if (hiddenRefusal) {
      _legacyPassThroughFailureReason = result.reason;
      _advanceReason = null;
      debugPrint(
        'SELAH: legacy Journey pass-through refused: ${result.reason}',
      );
      return fresh;
    }
    _advanceReason = result.accepted ? null : result.reason;
    if (!result.accepted) return fresh;
    final confirmation = await confirmSelahVisibleThreshold<JourneyMatch>(
      result: result,
      fromStage: stage,
      refetch: () =>
          SelahJourneyService.refetchOne(widget.matchId, widget.profile.id),
      stageOf: (match) => match.journeyStage,
      canAct: current,
    );
    if (confirmation == null || !current()) return fresh;
    _legacyPassThroughFailureReason = confirmation.failureReason;
    return confirmation.failureReason == null
        ? confirmation.value ?? fresh
        : fresh;
  }

  /// Continue still names the completed threshold; only the server moves it.
  Future<void> _advance(String fromStage) async {
    if (_stage != fromStage) return;
    final current = _captureJourneyOwner(requireMain: true);
    if (!current()) return;
    final result = await SelahJourneyService.advanceVisibleThreshold(
      widget.matchId,
      fromStage,
      canAct: current,
    );
    if (result == null || !current()) return;
    final legacyRefusal =
        fromStage == 'compatibility_reveal' &&
        !result.accepted &&
        result.stage != 'compatibility_reveal';
    final confirmation = result.accepted && fromStage == 'compatibility_reveal'
        ? await confirmSelahVisibleThreshold<JourneyMatch>(
            result: result,
            fromStage: fromStage,
            refetch: () => SelahJourneyService.refetchOne(
              widget.matchId,
              widget.profile.id,
            ),
            stageOf: (match) => match.journeyStage,
            canAct: current,
          )
        : null;
    if (!current()) return;
    setState(() {
      _legacyPassThroughFailureReason = legacyRefusal
          ? result.reason
          : confirmation?.failureReason;
      _advanceReason = result.accepted || legacyRefusal ? null : result.reason;
    });
    if (legacyRefusal) {
      debugPrint(
        'SELAH: legacy Journey pass-through refused: ${result.reason}',
      );
    }
    if (legacyRefusal || confirmation?.failureReason != null) return;
    await _refresh(showSpinner: false, allowLegacyPassThrough: false);
  }

  void _retryLegacyPassThrough() {
    final current = _captureJourneyOwner(requireMain: true);
    if (!current()) return;
    setState(() => _legacyPassThroughFailureReason = null);
    if (_stage == 'compatibility_reveal') {
      unawaited(_advance('compatibility_reveal'));
    } else {
      unawaited(_refresh(showSpinner: false));
    }
  }

  VoidCallback _captureLegacyPassThroughRetry() {
    final current = _captureJourneyOwner(requireMain: true);
    return () {
      if (current()) _retryLegacyPassThrough();
    };
  }

  /// #31 — the 4 "both Seekers complete a stage" transitions open a
  /// Family Review Period instead of advancing journey_stage directly.
  /// Safe to call from whichever Seeker's client reaches this point
  /// first (openFamilyReview is idempotent).
  Future<void> _advanceGated(String fromStage, String toStage) async {
    final r = await SelahJourneyService.openFamilyReview(
      widget.matchId,
      fromStage,
      toStage,
    );
    if (!mounted) return;
    // SURFACE IT. Since 2026-08-09 the server validates this call (audit
    // 2.2), so it can refuse — and the return value used to be discarded
    // entirely, which meant a refusal looked exactly like a success: a
    // tap, a refresh, and nothing moving. That is the 2026-08-07 release
    // blocker's signature, and it would have been reintroduced by the
    // very fix that hardened the server.
    if (!r.ok) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_reviewRefusedMessage(r.reason))));
    }
    await _refresh(showSpinner: false);
  }

  GlobalKey<_JourneyStageScrollShellState> _scrollKeyFor(String? stage) {
    final value = stage ?? SelahJourneyStages.all.first.value;
    return _stageScrollKeys.putIfAbsent(
      value,
      () => GlobalKey<_JourneyStageScrollShellState>(),
    );
  }

  void _setStageActionVisible(bool visible) {
    if (!mounted || _stageActionVisible == visible) return;
    setState(() => _stageActionVisible = visible);
  }

  void _setViewedRibbonStage(SelahJourneyStage stage) {
    if (!mounted || _viewedRibbonStage == stage.value) return;
    setState(() => _viewedRibbonStage = stage.value);
  }

  void _navigateToCompletedStage(int order) {
    void scroll() {
      _scrollKeyFor(
        _displayStage.value,
      ).currentState?.scrollToCompletedStage(order);
    }

    if (_stageDecision != null) {
      setState(() {
        _stageDecision = null;
        _stageDecisionBusy = false;
        _stageContinueSelected = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => scroll());
      return;
    }
    scroll();
  }

  Future<void> _openStageDecision({
    required String fromStage,
    required Future<void> Function() continueAction,
    bool completionConfirmed = true,
    SelahJourneyStage? stageOverride,
    String? nextLabelOverride,
  }) async {
    final stage = stageOverride ?? SelahJourneyStages.of(fromStage);
    if (!mounted || stage == null) {
      return;
    }
    final nextLabel =
        nextLabelOverride ??
        (stage.order < SelahJourneyStages.count
            ? SelahJourneyStages.all[stage.order].label
            : null);
    if (nextLabel == null) return;
    setState(() {
      _stageDecisionToken = Object();
      _stageDecision = (
        stage: stage,
        nextLabel: nextLabel,
        continueAction: continueAction,
        completionConfirmed: completionConfirmed,
      );
      _stageDecisionBusy = false;
      _stageContinueSelected = false;
    });
  }

  void _selectStageContinue() {
    if (_stageDecision == null || _stageDecisionBusy) return;
    HapticFeedback.selectionClick();
    setState(() => _stageContinueSelected = !_stageContinueSelected);
  }

  Future<void> Function() _captureStageDecisionCommit() {
    final decision = _stageDecision;
    final token = _stageDecisionToken;
    final ownerCurrent = _captureJourneyOwner(requireMain: true);
    bool current() =>
        ownerCurrent() &&
        identical(token, _stageDecisionToken) &&
        decision == _stageDecision;
    return () async {
      if (!current() ||
          decision == null ||
          _stageDecisionBusy ||
          !_stageContinueSelected) {
        return;
      }
      setState(() => _stageDecisionBusy = true);
      await decision.continueAction();
      if (!current()) return;
      setState(() {
        _stageDecision = null;
        _stageDecisionBusy = false;
        _stageContinueSelected = false;
      });
    };
  }

  Future<void> _pauseStageDecision() async {
    if (_stageDecision == null || _stageDecisionBusy) return;
    setState(() => _stageDecisionBusy = true);
    final requested = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _JourneyLifecycleConfirmScreen(
          action: _JourneyLifecycleAction.pause,
          profile: widget.profile,
          onConfirm: () async {
            try {
              await SelahJourneyService.transitionPause(
                matchId: widget.matchId,
                action: SelahPauseAction.requestPause,
                expectedVersion: _pauseState.version,
              );
              return null;
            } catch (_) {
              return _JourneyLifecycleFailure.failed;
            }
          },
        ),
      ),
    );
    if (!mounted) return;
    if (requested != true) {
      setState(() => _stageDecisionBusy = false);
      return;
    }

    setState(() {
      _stageDecision = null;
      _stageDecisionBusy = false;
      _stageContinueSelected = false;
    });
    await _refresh(showSpinner: false);
  }

  Future<void> _pauseForMissingMainShepherd() async {
    if (_pauseActionBusy || _pauseState.isLocked) return;
    setState(() => _pauseActionBusy = true);
    final requested = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _JourneyLifecycleConfirmScreen(
          action: _JourneyLifecycleAction.pause,
          profile: widget.profile,
          onConfirm: () async {
            try {
              await SelahJourneyService.transitionPause(
                matchId: widget.matchId,
                action: SelahPauseAction.requestPause,
                expectedVersion: _pauseState.version,
              );
              return null;
            } catch (_) {
              return _JourneyLifecycleFailure.failed;
            }
          },
        ),
      ),
    );
    if (!mounted) return;
    setState(() => _pauseActionBusy = false);
    if (requested == true) await _refresh(showSpinner: false);
  }

  void _openShepherdFromJourneyHold() {
    Navigator.of(context).pop();
    widget.onOpenShepherd?.call();
  }

  Future<void> _applyPauseAction(SelahPauseAction action) async {
    if (_pauseActionBusy) return;
    final preview = _devPausePreview;
    if (preview != null) {
      final me = SelahAuth.currentUser?.id ?? 'dev-me';
      try {
        final next = SelahJourneyPausePolicy.apply(
          state: preview,
          action: action,
          actorId: me,
          otherId: widget.profile.id,
        );
        if (mounted) {
          final scenario = SelahPauseDevScenario.fromState(next, me);
          SelahDevScenario.instance.setPauseScenario(scenario);
          setState(() {
            _devPauseScenario = scenario;
            _devPausePreview = next.phase == SelahPausePhase.active
                ? null
                : next;
            _stageActionVisible = false;
          });
        }
      } on StateError {
        // A preview action can only be reached from a compatible decision
        // surface. If a hot-reload leaves a stale callback, ignore it.
      }
      return;
    }
    setState(() => _pauseActionBusy = true);
    try {
      final next = await SelahJourneyService.transitionPause(
        matchId: widget.matchId,
        action: action,
        expectedVersion: _pauseState.version,
      );
      if (mounted) {
        setState(() {
          _pauseState = next;
          _pauseCapacityAvailable = null;
        });
      }
      await _refresh(showSpinner: false);
    } on PauseCapacityConflictException {
      if (!mounted) return;
      setState(() => _pauseCapacityAvailable = false);
    } on PauseTransitionStaleException {
      await _refresh(showSpinner: false);
    } on PauseTransitionNotAllowedException {
      await _refresh(showSpinner: false);
    } on SelfInActiveJourneyException {
      await _refresh(showSpinner: false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "You're at your plan's Active Journey limit, so this one stays "
            'paused. Pause or end an Active Journey first — nothing here is lost.',
          ),
        ),
      );
    } on OtherPartyInActiveJourneyException {
      await _refresh(showSpinner: false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "They're in another Journey right now, so this one stays paused. "
            'Nothing has been lost. You can request again when there is capacity.',
          ),
        ),
      );
    } on NotEligibleToContinueException {
      await _refresh(showSpinner: false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("This Journey can't continue right now.")),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "That didn't go through — check your connection and try again.",
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _pauseActionBusy = false);
    }
  }

  void _endPauseFlow() {
    if (_devPausePreview != null) {
      SelahDevScenario.instance.setPauseScenario(
        SelahPauseDevScenario.endedFromPause,
      );
      setState(() {
        _devPauseScenario = SelahPauseDevScenario.endedFromPause;
        _devPausePreview = null;
        _devPauseEnded = true;
      });
      return;
    }
    unawaited(_endJourney());
  }

  /// The server's vocabulary turned into something a person can act on.
  /// 'stage_moved' is the one a real user will actually hit — the other
  /// Seeker's client opened the same review a moment earlier — and it is
  /// not an error from their point of view, so it does not read like one.
  static String _reviewRefusedMessage(String reason) => switch (reason) {
    'stage_moved' =>
      'This Journey has already moved on — bringing you up to date.',
    'journey_paused' => 'This Journey is paused. Resume it to continue.',
    'journey_not_active' => 'This Journey is no longer active.',
    'not_a_gated_transition' ||
    'invalid_transition' => "That step isn't available from here.",
    _ => "That didn't go through. Please try again.",
  };

  /// End is confirmed on its own full screen. The write happens while that
  /// confirmation remains visible, so a failure leaves the member on the
  /// decision they were making instead of dismissing it into a snackbar.
  Future<void> _endJourney() async {
    final ended = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _JourneyLifecycleConfirmScreen(
          action: _JourneyLifecycleAction.end,
          profile: widget.profile,
          onConfirm: () async {
            final ok = await SelahJourneyService.endJourney(widget.matchId);
            return ok ? null : _JourneyLifecycleFailure.failed;
          },
        ),
      ),
    );
    if (ended != true || !mounted) return;

    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) =>
            _JourneyLifecycleCompleteScreen(profile: widget.profile),
      ),
    );
    if (mounted) Navigator.of(context).pop();
  }

  /// Legacy live-account Journey controls stay disabled in the one-app model.
  // Legacy server-backed Journey jump controls are not part of local previews.
  // Keep disabled; the shared local scenario panel owns preview controls.
  bool get _isDevAccount => false;

  bool _jumping = false;

  /// inherited decision 135. Whether this account holds a simulated Compatibility
  /// Unlock+ on the other Seeker. Read from the server, not held
  /// locally — a switch that shows its own last write is a switch that
  /// lies.
  bool _hasPlus = false;

  Future<void> _loadPlusUnlock() async {
    if (!_isDevAccount) return;
    final v = await SelahJourneyService.fetchHasPlusUnlock(widget.profile.id);
    if (mounted) setState(() => _hasPlus = v);
  }

  Future<void> _setPlusUnlock(bool value) async {
    if (_jumping) return;
    setState(() => _jumping = true);
    try {
      await SelahJourneyService.devSetPlusUnlock(widget.profile.id, value);
      await _loadPlusUnlock();
      await _refresh(showSpinner: false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _jumping = false);
    }
  }

  /// DEV ONLY. Does the OTHER party's half of the stage the Journey is
  /// standing on — their Greeting, their answers, their Continue, their
  /// Shepherd's answers — and nothing else.
  ///
  /// Founder, 2026-08-11: "make the whole journey process until the message
  /// stage." It could not be walked at all before this. Every stage from the
  /// Greeting onwards is mutual BY DESIGN, so one person testing alone reaches
  /// "Waiting for their answers" at stage two and stops; six of the eight
  /// stages had therefore never been seen running.
  ///
  /// This is not a skip. It does not move the Journey on — the tester still
  /// presses their own buttons, still sees their own waiting states, and the
  /// real gates still decide. What ends is the wait for a person who is never
  /// going to open the app.
  ///
  /// The question ids travel from here because the bank lives in
  /// data/journey_questions.dart and the database has never been told about
  /// it. Sending the wrong set would write answers to questions that are not
  /// on screen, so it is read from the same [JourneyQuestions] the stage view
  /// itself renders rather than a second list.
  Future<void> _counterpartComplete() async {
    if (_jumping) return;
    if (_lifeSnapshotOpen && _stage == 'compatibility_reveal') {
      if (_lifeSnapshotTheirsRevealed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${widget.profile.firstName} already revealed their profile (dev)',
            ),
          ),
        );
        return;
      }
      setState(() => _lifeSnapshotTheirsRevealed = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${widget.profile.firstName} revealed their profile (dev)',
          ),
        ),
      );
      return;
    }
    setState(() => _jumping = true);
    try {
      final ids = switch (_stage) {
        'phase_1' => JourneyQuestions.phase1.map((q) => q.id).toList(),
        'phase_2' => JourneyQuestions.phase2.map((q) => q.id).toList(),
        'phase_3' => JourneyQuestions.phase3.map((q) => q.id).toList(),
        'family_stage' =>
          JourneyQuestions.seekerToMentor.map((q) => q.id).toList(),
        _ => const <String>[],
      };
      final said = await SelahJourneyService.devCounterpartComplete(
        widget.matchId,
        questionIds: ids,
      );
      await _refresh(showSpinner: false);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$said (dev)')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _jumping = false);
    }
  }

  void _setDevLifeSnapshotBio(bool value) {
    if (_jumping || _pauseActionBusy) return;
    setState(() => _devLifeSnapshotHasBio = value);
  }

  void _toggleDevLifeSnapshotField(String id) {
    if (_jumping || _pauseActionBusy) return;
    setState(() {
      _devLifeSnapshotFieldIds = SelahJourneyLifeSnapshotMock.toggle(
        _devLifeSnapshotFieldIds,
        id,
      );
    });
  }

  void _setAllDevLifeSnapshotFields(bool visible) {
    if (_jumping || _pauseActionBusy) return;
    setState(() {
      _devLifeSnapshotFieldIds = visible
          ? SelahJourneyLifeSnapshotMock.defaultVisibleFieldIds
          : const <String>{};
    });
  }

  Future<void> _openLifeSnapshot({bool fromDevJump = false}) async {
    if (!mounted) return;
    setState(() {
      _lifeSnapshotOpen = true;
      _lifeSnapshotOpenedFromDevJump = fromDevJump;
      _lifeSnapshotMineRevealed = false;
      _lifeSnapshotTheirsRevealed = false;
      _viewedRibbonStage = null;
      _advanceReason = null;
      _stageActionVisible = false;
    });
  }

  void _revealLifeSnapshot() {
    if (!mounted || _lifeSnapshotMineRevealed) return;
    HapticFeedback.selectionClick();
    setState(() => _lifeSnapshotMineRevealed = true);
  }

  Future<void> _continueLifeSnapshot() async {
    if (_isDevAccount && _lifeSnapshotOpenedFromDevJump) {
      await _jumpToStage('phase_1');
      return;
    }
    await _advance('compatibility_reveal');
  }

  /// DEV ONLY, DESTRUCTIVE. Puts this Journey back to its first stage and
  /// throws away everything done inside it, so it can be walked again.
  ///
  /// CONFIRMED FIRST. It is the only control in this panel that destroys
  /// anything — the rest move a stage or fill in the other person's half, and
  /// both are recoverable by carrying on. This is not, and after a long
  /// walk-through there is real work behind that tap.
  Future<void> _rewindJourney() async {
    if (_jumping) return;
    final ok = await showSelahGlassChoice(
      context: context,
      icon: Icons.restart_alt,
      title: 'Start this Journey again?',
      body:
          'Puts you back at Compatibility Reveal and clears everything you '
          'both did — answers, ratings, Greetings, the reveal, family answers, '
          'messages and Timeline milestones.\n\nThe match itself stays, and so '
          'does your Shepherd link.',
      primaryLabel: 'Start again',
      secondaryLabel: 'Cancel',
    );
    if (ok != true || !mounted) return;

    setState(() => _jumping = true);
    try {
      final said = await SelahJourneyService.devRewindJourney(
        matchId: widget.matchId,
      );
      await _refresh(showSpinner: false);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$said (dev)')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _jumping = false);
    }
  }

  /// DEV ONLY. Skips the Pre-Journey Ritual and the
  /// 48-hour Family Review Period in one tap.
  Future<void> _jumpToStage(String stage) async {
    if (_jumping) return;
    setState(() => _jumping = true);
    try {
      final serverStage = stage == SelahJourneyStages.lifeSnapshotPreview.value
          ? 'compatibility_reveal'
          : stage;
      await SelahJourneyService.devSetStage(widget.matchId, serverStage);
      // The server is the source of truth for where the Journey now is, so
      // re-read rather than assuming the jump landed where it was asked to.
      // A local setState here would show the requested stage even if the
      // server had quietly done something else — the exact shape of the
      // 2026-08-07 release blocker, where a no-op looked like a success.
      await _refresh(showSpinner: false);
      if (stage == SelahJourneyStages.lifeSnapshotPreview.value && mounted) {
        await _openLifeSnapshot(fromDevJump: true);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _jumping = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    _observeCompatibilitySurface();
    if (SelahIdentityVerificationService.enforceExistingAccountGate) {
      if (_identityGateLoading) {
        return const Scaffold(body: SafeArea(child: SelahLoading.fullScreen()));
      }
      if (_identityGateError != null) {
        return Scaffold(
          body: Container(
            constraints: const BoxConstraints.expand(),
            decoration: SelahAppGoldDecoration(
              gradient: SelahColors.brandGradient,
            ),
            child: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "We couldn't check Journey access.",
                        style: SelahText.heading(size: 22),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Nothing has changed. Check your connection and try again.',
                        style: SelahText.subtext(size: 13),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: _resolveIdentityGate,
                        child: const Text('Try again'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }
      if (_identityVerification?.allowsActiveJourney != true) {
        return InitialIdentityCheckScreen(
          initialState: _identityVerification,
          requireDuplicateResolution: true,
          onContinue: (_) => _resolveIdentityGate(),
        );
      }
    }
    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
        // JOURNEY MODE IS NEUTRAL GROUND — Founder, 2026-08-15
        // (inherited decision 177): "regardless of male or female the colour for
        // both is the default purple." Inside a Journey two accounts
        // share one place, so neither side's tint paints it; the
        // neutral brand gradient does. Gender tints stay everywhere
        // else (inherited decision 094 unchanged outside Journey mode).
        decoration: SelahAppGoldDecoration(gradient: SelahColors.brandGradient),
        child: Stack(
          children: [
            // One shared living background for the whole Journey. The
            // motion belongs to the relationship, not to any individual
            // chapter, so every stage inherits it from here instead of
            // maintaining eight decorative implementations that can drift.
            Positioned.fill(child: _JourneyAtmosphere(stage: _stage)),
            SafeArea(
              child: _loading ? const SelahLoading() : _buildBody(context),
            ),
            // DEV ONLY — the right-edge pull-out, matching dev_scenario_panel.
            //
            // In the Stack rather than the Column so it floats over the stage
            // content the way the app's other developer panel floats over
            // HomeShell. It remains reachable on a paused Journey because its
            // display-only pause selector is how every ownership state is
            // reviewed; stage-changing controls disable while the live row is
            // paused.
            //
            // Client capability decides whether this is drawn; the staging
            // RPC boundary independently repeats the exact protected-persona
            // check before changing server state.
            if (_isDevAccount && _stageLoaded && _status == 'active')
              _DevStageJumper(
                current: _displayStage.value,
                busy: _jumping || _pauseActionBusy,
                onJump: _jumpToStage,
                lifeSnapshotHasBio: _devLifeSnapshotHasBio,
                lifeSnapshotFieldIds: _devLifeSnapshotFieldIds,
                onLifeSnapshotBioChanged: _setDevLifeSnapshotBio,
                onLifeSnapshotFieldToggle: _toggleDevLifeSnapshotField,
                onLifeSnapshotShowAll: _setAllDevLifeSnapshotFields,
                hasPlus: _hasPlus,
                onHasPlusChanged: _setPlusUnlock,
                onRewind: _rewindJourney,
                livePaused: _pauseState.isLocked,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    // inherited decision 178. Until the first fetch has ANSWERED, there is nothing
    // to render as a Journey — and this screen used to render its field
    // defaults ('active', first stage) instead, which is how a dev
    // stand-in with no server row behind it walked into a Compatibility
    // Reveal that could never advance (the 2026-08-15 "toggle isn't
    // working" report). Truthful-failure rule, extended: a cached value
    // may paint, never decide — and an INVENTED value may not even
    // paint.
    if (!_stageLoaded) {
      return SelahEmptyState(
        icon: Icons.cloud_off_outlined,
        title: "Couldn't load this Journey",
        message: _isDevAccount
            ? 'Nothing arrived from the server for it. A dev stand-in '
                  'has no real Journey behind it and never loads here; a '
                  'real one appears when the connection returns. (dev)'
            : 'Nothing arrived from the server. Check your connection, '
                  'then try again.',
        ctaLabel: 'Try again',
        onCta: () => _refresh(),
      );
    }

    if (_status == 'ended' || _devPauseEnded) {
      return _EndedView(profile: widget.profile);
    }

    if (_shepherdGateLoading) {
      return const SelahLoading();
    }
    if (_shepherdGate == SelahJourneyShepherdGate.unavailable) {
      return SelahEmptyState(
        icon: Icons.cloud_off_outlined,
        title: "Couldn't check your Main Shepherd",
        message:
            'Journey access stays protected until this check succeeds. '
            'Nothing has changed.',
        ctaLabel: 'Try again',
        onCta: _resolveMainShepherdGate,
      );
    }
    if (_shepherdGate != SelahJourneyShepherdGate.ready) {
      final selfMissing =
          _shepherdGate == SelahJourneyShepherdGate.selfMissing ||
          _shepherdGate == SelahJourneyShepherdGate.bothMissing;
      return _MainShepherdRequiredJourneyView(
        profile: widget.profile,
        stage: _displayStage,
        paused: _pauseState.isLocked,
        busy: _pauseActionBusy,
        waitingOnOther: !selfMissing,
        onChooseShepherd: selfMissing ? _openShepherdFromJourneyHold : null,
        onPause: _pauseState.isLocked ? null : _pauseForMissingMainShepherd,
        onEnd: _endJourney,
      );
    }

    final pauseState = _devPausePreview ?? _pauseState;
    if (pauseState.isLocked) {
      final preview = _devPausePreview != null;
      return _PauseDecisionView(
        profile: widget.profile,
        state: pauseState,
        busy: preview ? false : _pauseActionBusy,
        preview: preview,
        capacityAvailable: preview
            ? !pauseState.capacityBlocked
            : _pauseCapacityAvailable,
        onAction: _applyPauseAction,
        onEnd: _endPauseFlow,
        onReturn: () => Navigator.of(context).maybePop(),
      );
    }

    final displayStage = _displayStage;
    if (_stage == 'mentor_gate') {
      // The stored legacy key never exposes a retired screen or Phase 1
      // actions before the unchanged server RPC confirms the pass-through.
      return Column(
        children: [
          _JourneyAppBar(
            profile: widget.profile,
            stage: displayStage,
            ownMainShepherdName: _ownMainShepherdName,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Center(
                child: _legacyPassThroughFailureReason == null
                    ? const SelahLoading()
                    : SelahErrorBanner(
                        key: const ValueKey('journey_legacy_pass_failure'),
                        message: 'That didn’t save. Try again.',
                        retryKey: const ValueKey('journey_legacy_pass_retry'),
                        onRetry: _captureLegacyPassThroughRetry(),
                      ),
              ),
            ),
          ),
        ],
      );
    }
    final surfaceKey = _review != null ? 'family_review' : displayStage.value;

    return Column(
      children: [
        // Persistent Journey management lives on the Connections Active
        // Journey card. Live chapter content contains only its own action;
        // Pause/End appear once, on the dedicated between-stage choice page.
        _JourneyAppBar(
          profile: widget.profile,
          stage: displayStage,
          ownMainShepherdName: _ownMainShepherdName,
        ),
        if (_legacyPassThroughFailureReason != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
            child: SelahErrorBanner(
              key: const ValueKey('journey_legacy_pass_failure'),
              message: 'That didn’t save. Try again.',
              retryKey: const ValueKey('journey_legacy_pass_retry'),
              onRetry: _captureLegacyPassThroughRetry(),
            ),
          ),
        // THE RIBBON — inherited decision 185 (chosen as "Quiet" after three
        // mock rounds): eight quiet marks, one named pill. Walked
        // chapters fill soft gold, the road ahead sits faint, and the
        // chapter you are standing in says its own name. During a
        // Family Review the pill says that instead — the one moment
        // the Journey is held for a reason the Seeker cannot act on.
        //
        _JourneyRibbon(
          stage: _viewedRibbonStage ?? displayStage.value,
          stages: SelahJourneyStages.previewAll,
          reviewOpen: _review != null,
          onCompletedStageTap: _navigateToCompletedStage,
        ),
        Expanded(
          // A confirmed stage change continues the exact movement used by
          // the vertical PageView: the completed surface rises out while the
          // next arrival rises from below. There is no fade, scale, loader or
          // route transition, so one gesture reads as one continuous scroll.
          // Family Review remains an override rather than a ninth stage.
          child: _JourneyVerticalStageSwap(
            surfaceKey: surfaceKey,
            child: KeyedSubtree(
              key: ValueKey(surfaceKey),
              child: _review != null
                  ? _FamilyReviewView(review: _review!, profile: widget.profile)
                  : _JourneyStageScrollShell(
                      key: _scrollKeyFor(displayStage.value),
                      stage: displayStage,
                      stages: SelahJourneyStages.previewAll,
                      compatibilityHistoryChild: _CompatibilityRevealView(
                        matchId: widget.matchId,
                        profile: widget.profile,
                        isActionVisible: false,
                        readOnly: true,
                        isCurrentSurface: _captureCompatibilitySurfaceOwner(
                          readOnly: true,
                        ),
                        onContinue: () async {},
                        waitingReason: null,
                      ),
                      greetingHistoryChild: _GreetingExchangeHistoryView(
                        profile: widget.profile,
                      ),
                      lifeSnapshotHistoryChild: _LifeSnapshotView(
                        profile: widget.profile,
                        showBio: _devLifeSnapshotHasBio,
                        visibleFieldIds: _devLifeSnapshotFieldIds,
                        mineRevealed: true,
                        theirsRevealed: true,
                        onReveal: () {},
                        waitingForOther: false,
                        onContinue: () async {},
                        readOnly: true,
                      ),
                      decisionChild: _stageDecision == null
                          ? null
                          : _JourneyStageDecisionPage(
                              stage: _stageDecision!.stage,
                              nextLabel: _stageDecision!.nextLabel,
                              completionConfirmed:
                                  _stageDecision!.completionConfirmed,
                              busy: _stageDecisionBusy,
                              continueSelected: _stageContinueSelected,
                              onBack: () => _scrollKeyFor(
                                displayStage.value,
                              ).currentState?.showActionPage(),
                              onSelectContinue: _selectStageContinue,
                              onCommitContinue: _captureStageDecisionCommit(),
                              onPause: _pauseStageDecision,
                              onEnd: _endJourney,
                            ),
                      onOpenTimeline: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => JourneyTimelineScreen(
                            withProfile: widget.profile,
                          ),
                        ),
                      ),
                      onActionVisibilityChanged: _setStageActionVisible,
                      onViewedStageChanged: _setViewedRibbonStage,
                      child: _buildStage(context),
                    ),
            ),
          ),
        ),
        // THE WAITING LINES — inherited decision 185. When the server has said the
        // Journey is waiting on the other side, the app's own comet
        // rule says so in the app's own voice, with the reason in
        // words. Absent otherwise: a page that is yours to act on
        // never shows a spinner. NOT ON STAGE 1 (inherited decision 192): nothing
        // is loading while another human decides when to open SELAH, so
        // nothing animates — the Greeting page says the wait in words.
        if (_advanceReason != null &&
            _review == null &&
            !_lifeSnapshotOpen &&
            _stage != 'greeting_exchange')
          Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 6),
            child: SelahLoading(label: _waitingLine),
          ),
        // DEV ONLY — the on-page "User" action (inherited decision 181). Does the
        // OTHER person's half of the current step, on press — it
        // REPLACED the auto toggle so the waiting states are seen
        // first: complete your side, see the wait, press User, watch
        // the Journey move. It stays during a Family Review (its RPC's
        // closing block is the only fast exit from one). Subtle and
        // apart from the Journey's own controls; never in release.
        if (SelahDeveloperAccess.canUseDeveloperTools &&
            _isDevAccount &&
            _status == 'active' &&
            !_pauseState.isLocked)
          Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 10),
            child: Center(
              child: InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: _jumping ? null : _counterpartComplete,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: SelahColors.foreground.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: SelahColors.foreground.withValues(alpha: 0.14),
                      width: 0.5,
                    ),
                  ),
                  child: Text(
                    'User',
                    style: SelahText.subtext(
                      size: 11.5,
                      color: SelahColors.foreground.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// The server's waiting reason, in the Journey's own words —
  /// rendered under the stage by the standard loading lines
  /// (inherited decision 185).
  String get _waitingLine {
    final name = widget.profile.firstName;
    return switch (_advanceReason) {
      'waiting_for_greeting' => "Waiting for $name's Greeting",
      'waiting_for_reveal' => 'Waiting for $name to reveal',
      'waiting_for_continue' => 'Waiting for $name to continue',
      _ => 'Waiting for $name',
    };
  }

  SelahJourneyStage get _displayStage {
    if (_lifeSnapshotOpen && _stage == 'compatibility_reveal') {
      return SelahJourneyStages.lifeSnapshotPreview;
    }
    return SelahJourneyStages.previewOf(_stage) ??
        SelahJourneyStages.previewAll.first;
  }

  String get _currentJourneySurfaceKey =>
      _review != null ? 'family_review' : _displayStage.value;

  bool get _compatibilityParentAdmitted =>
      _stageLoaded &&
      _status == 'active' &&
      !_devPauseEnded &&
      _review == null &&
      !_shepherdGateLoading &&
      _shepherdGate == SelahJourneyShepherdGate.ready &&
      !(_devPausePreview ?? _pauseState).isLocked &&
      !_identityGateLoading &&
      (!SelahIdentityVerificationService.enforceExistingAccountGate ||
          (_identityGateError == null &&
              _identityVerification?.allowsActiveJourney == true));

  int _observeCompatibilitySurface() {
    final pause = _devPausePreview ?? _pauseState;
    final next = (
      scope: SelahCompatibilityReadScope(
        actorId: SelahAuth.currentUser?.id,
        accountGeneration: SelahAccountState.generation,
        matchId: widget.matchId,
      ),
      context: (
        widget.profile.id,
        _currentJourneySurfaceKey,
        _stageLoaded,
        _status,
        _devPauseEnded,
        _review?.id,
        _review?.status,
        _shepherdGateLoading,
        _shepherdGate,
        pause.phase,
        pause.version,
        pause.isLocked,
        _identityGateLoading,
        _identityGateError != null,
        SelahIdentityVerificationService.enforceExistingAccountGate,
        _identityVerification?.allowsActiveJourney,
        _lifeSnapshotOpen,
      ),
      admitted: _compatibilityParentAdmitted,
    );
    final previous = _compatibilitySurfaceContext;
    if (previous != next) {
      // Initial loading is not a retirement of a usable parent context.
      // Preserve an unchanged-context revisit's last confirmed cache.
      if (previous?.admitted == true) {
        _CompatibilityRevealViewState.invalidateParentContext(previous!.scope);
      }
      _compatibilitySurfaceContext = next;
      _compatibilitySurfaceGeneration++;
    }
    return _compatibilitySurfaceGeneration;
  }

  bool Function() _captureCompatibilitySurfaceOwner({required bool readOnly}) {
    final matchId = widget.matchId;
    final profileId = widget.profile.id;
    final surfaceKey = _currentJourneySurfaceKey;
    final generation = _observeCompatibilitySurface();
    var retired = false;
    return () {
      if (retired) return false;
      final current =
          mounted &&
          _observeCompatibilitySurface() == generation &&
          widget.matchId == matchId &&
          widget.profile.id == profileId &&
          _currentJourneySurfaceKey == surfaceKey &&
          _compatibilityParentAdmitted &&
          (readOnly ||
              (_stage == 'compatibility_reveal' && !_lifeSnapshotOpen));
      // Once this captured surface loses admission it cannot revive an old
      // awaited read merely because the same surface key comes back later.
      if (!current) retired = true;
      return current;
    };
  }

  Widget _buildStage(BuildContext context) {
    if (_lifeSnapshotOpen && _stage == 'compatibility_reveal') {
      return _LifeSnapshotView(
        profile: widget.profile,
        showBio: _devLifeSnapshotHasBio,
        visibleFieldIds: _devLifeSnapshotFieldIds,
        mineRevealed: _lifeSnapshotMineRevealed,
        theirsRevealed: _lifeSnapshotTheirsRevealed,
        onReveal: _revealLifeSnapshot,
        waitingForOther:
            _advanceReason == 'waiting_for_continue' ||
            _advanceReason == 'waiting_for_reveal',
        onContinue: () => _openStageDecision(
          fromStage: 'compatibility_reveal',
          stageOverride: SelahJourneyStages.lifeSnapshotPreview,
          nextLabelOverride: SelahJourneyStages.labelFor('phase_1'),
          continueAction: _continueLifeSnapshot,
        ),
      );
    }
    switch (_stage) {
      case 'compatibility_reveal':
        return _CompatibilityRevealView(
          matchId: widget.matchId,
          profile: widget.profile,
          isActionVisible: _stageActionVisible,
          isCurrentSurface: _captureCompatibilitySurfaceOwner(readOnly: false),
          onContinue: () => _openStageDecision(
            fromStage: 'compatibility_reveal',
            nextLabelOverride: SelahJourneyStages.labelFor('phase_1'),
            continueAction: () => _advance('compatibility_reveal'),
          ),
          waitingReason: _advanceReason,
        );
      case 'greeting_exchange':
        return _GreetingExchangeView(
          matchId: widget.matchId,
          profile: widget.profile,
          isActionVisible: _stageActionVisible,
          onContinue: () => _openStageDecision(
            fromStage: 'greeting_exchange',
            continueAction: () => _advance('greeting_exchange'),
          ),
        );
      case 'phase_1':
        return _PhaseView(
          matchId: widget.matchId,
          profile: widget.profile,
          phase: 1,
          isActionVisible: _stageActionVisible,
          onAdvance: () => _advanceGated('phase_1', 'phase_2'),
          onRequestDecision: (continueAction) => _openStageDecision(
            fromStage: 'phase_1',
            continueAction: continueAction,
          ),
        );
      case 'phase_2':
        return _PhaseView(
          matchId: widget.matchId,
          profile: widget.profile,
          phase: 2,
          isActionVisible: _stageActionVisible,
          onAdvance: () => _advanceGated('phase_2', 'phase_3'),
          onRequestDecision: (continueAction) => _openStageDecision(
            fromStage: 'phase_2',
            continueAction: continueAction,
          ),
        );
      case 'phase_3':
        return _PhaseView(
          matchId: widget.matchId,
          profile: widget.profile,
          phase: 3,
          isActionVisible: _stageActionVisible,
          onAdvance: () => _advanceGated('phase_3', 'family_stage'),
          onRequestDecision: (continueAction) => _openStageDecision(
            fromStage: 'phase_3',
            continueAction: continueAction,
          ),
        );
      case 'family_stage':
        return _FamilyStageView(
          matchId: widget.matchId,
          profile: widget.profile,
          isActionVisible: _stageActionVisible,
          onAdvance: () => _advanceGated('family_stage', 'conversation'),
          onRequestDecision: (continueAction) => _openStageDecision(
            fromStage: 'family_stage',
            continueAction: continueAction,
          ),
        );
      case 'conversation':
        // WAS an immediate pushReplacement into ChatScreen. The eighth stage
        // therefore had no screen at all: you arrived at the end of a Journey
        // and were dropped into a message list with no acknowledgement that
        // anything had been reached.
        //
        // It also made the stage impossible to look at — every visit bounced
        // straight past it — which is how it went this long without anyone
        // noticing the conversation row it needs was never created for a
        // seeded match.
        //
        // JOURNEY PHILOSOPHY §2: "structure does not disappear... the
        // experience does not suddenly become a standard chat app." A door,
        // then, rather than a trapdoor.
        return _OpenConversationView(
          matchId: widget.matchId,
          profile: widget.profile,
        );
      default:
        return const SelahLoading();
    }
  }
}

class _MainShepherdRequiredJourneyView extends StatelessWidget {
  final SeekerProfile profile;
  final SelahJourneyStage stage;
  final bool paused;
  final bool busy;
  final bool waitingOnOther;
  final VoidCallback? onChooseShepherd;
  final Future<void> Function()? onPause;
  final Future<void> Function() onEnd;

  const _MainShepherdRequiredJourneyView({
    required this.profile,
    required this.stage,
    required this.paused,
    required this.busy,
    required this.waitingOnOther,
    required this.onChooseShepherd,
    required this.onPause,
    required this.onEnd,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
    child: Column(
      children: [
        _JourneyAppBar(profile: profile, stage: stage),
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.shield_outlined,
                    size: 34,
                    color: SelahColors.journeyGold,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    waitingOnOther
                        ? 'This Journey is waiting'
                        : 'Choose a Main Shepherd',
                    style: SelahText.heading(size: 24),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    waitingOnOther
                        ? '${profile.firstName} needs to choose a Main Shepherd before this Journey can continue.'
                        : paused
                        ? 'This Journey stays paused until you choose the Shepherd who leads.'
                        : 'This Journey is held until you choose the Shepherd who leads.',
                    style: SelahText.subtext(size: 13),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  if (onChooseShepherd != null)
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: busy ? null : onChooseShepherd,
                        child: const Text('Go to Shepherd'),
                      ),
                    ),
                  if (onPause != null) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: busy ? null : onPause,
                        child: const Text('Pause Journey'),
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: busy ? null : onEnd,
                    child: const Text('End Journey'),
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

/// The Journey's shared visual atmosphere.
///
/// Founder direction, 2026-08-17: the neutral purple was correct but felt
/// flat. This adds restrained layered light behind every stage. The first
/// implementation moved those full-screen layers continuously; they are now
/// deliberately static because repainting them at display refresh rate was a
/// measurable thermal cost with no functional value. People are
/// always rendered as real profile photos in the foreground; decoration must
/// never sit behind and collide with readable content. Reduced-motion users
/// get the same layered colour without animation.
class _JourneyAtmosphere extends StatefulWidget {
  final String? stage;

  const _JourneyAtmosphere({required this.stage});

  @override
  State<_JourneyAtmosphere> createState() => _JourneyAtmosphereState();
}

class _JourneyAtmosphereState extends State<_JourneyAtmosphere>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
      value: 0.5,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final stage = SelahJourneyStages.of(widget.stage);
    final step = stage?.order ?? 1;
    final stageShift = ((step - 1) / (SelahJourneyStages.all.length - 1)) * 28;

    Widget scene(double t) {
      final eased = Curves.easeInOut.transform(t);
      return IgnorePointer(
        child: ClipRect(
          child: Stack(
            children: [
              Positioned(
                top: -80 + (28 * eased),
                right: -95 + stageShift,
                child: Transform.scale(
                  scale: 0.96 + (0.08 * eased),
                  child: _JourneyGlow(
                    size: 300,
                    colour: SelahColors.actionFill,
                    opacity: 0.24,
                  ),
                ),
              ),
              Positioned(
                bottom: -110 + (22 * (1 - eased)),
                left: -105 + (28 - stageShift),
                child: Transform.scale(
                  scale: 1.04 - (0.07 * eased),
                  child: const _JourneyGlow(
                    size: 330,
                    colour: Color(0xFF73579A),
                    opacity: 0.26,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (reduceMotion) return scene(0.5);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => scene(_controller.value),
    );
  }
}

class _JourneyGlow extends StatelessWidget {
  final double size;
  final Color colour;
  final double opacity;

  const _JourneyGlow({
    required this.size,
    required this.colour,
    required this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            colour.withValues(alpha: opacity),
            colour.withValues(alpha: 0),
          ],
        ),
      ),
    );
  }
}

/// A human version of the Journey's connection mark. The completed person is
/// bright; the person whose action is still needed is deliberately softened.
/// The quiet orbit is a waiting signal, not a loading spinner.
class _JourneyPairStatus extends StatefulWidget {
  final SeekerProfile profile;
  final bool youComplete;
  final bool otherComplete;
  final bool emphasizeWaiting;
  final bool greetingGoldWake;
  final bool motionEnabled;
  final String youCompleteLabel;
  final String youWaitingLabel;
  final String otherCompleteLabel;
  final String otherWaitingLabel;

  const _JourneyPairStatus({
    required this.profile,
    required this.youComplete,
    required this.otherComplete,
    this.emphasizeWaiting = false,
    this.greetingGoldWake = false,
    this.motionEnabled = true,
    this.youCompleteLabel = 'Done',
    this.youWaitingLabel = 'Waiting',
    this.otherCompleteLabel = 'Done',
    this.otherWaitingLabel = 'Waiting',
  });

  @override
  State<_JourneyPairStatus> createState() => _JourneyPairStatusState();
}

class _JourneyPairStatusState extends State<_JourneyPairStatus>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3100),
    value: 0.5,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncMotion();
  }

  @override
  void didUpdateWidget(covariant _JourneyPairStatus oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.greetingGoldWake != widget.greetingGoldWake ||
        oldWidget.motionEnabled != widget.motionEnabled ||
        oldWidget.youComplete != widget.youComplete ||
        oldWidget.otherComplete != widget.otherComplete) {
      _syncMotion();
    }
  }

  void _syncMotion() {
    final connection = SelahGreetingConnectionPolicy.resolve(
      mine: widget.youComplete,
      theirs: widget.otherComplete,
    );
    final travelling =
        connection == SelahGreetingConnectionMotion.outbound ||
        connection == SelahGreetingConnectionMotion.inbound;
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final shouldAnimate =
        widget.greetingGoldWake &&
        widget.motionEnabled &&
        travelling &&
        !reduceMotion &&
        TickerMode.valuesOf(context).enabled;
    if (shouldAnimate) {
      if (!_pulse.isAnimating) _pulse.repeat();
      return;
    }
    _pulse.stop();
    if (_pulse.value != 0.5) _pulse.value = 0.5;
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    Widget portrait({
      required bool you,
      required bool complete,
      required double t,
    }) {
      final photos = you ? AppState.instance.photos : widget.profile.photos;
      final name = you
          ? (AppState.instance.name ?? 'You')
          : widget.profile.firstName;
      final waiting = !complete;
      final highlightedWaiting =
          !widget.greetingGoldWake &&
          widget.emphasizeWaiting &&
          !you &&
          !complete;
      final statusLabel = complete
          ? (you ? widget.youCompleteLabel : widget.otherCompleteLabel)
          : (you ? widget.youWaitingLabel : widget.otherWaitingLabel);
      return Semantics(
        label: '$name, $statusLabel',
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 420),
          opacity: complete || highlightedWaiting ? 1 : 0.38,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 68,
                height: 68,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    if (highlightedWaiting) ...[
                      Transform.scale(
                        scale: 1.05 + (0.18 * t),
                        child: Container(
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(
                                0xFFCEA2D1,
                              ).withValues(alpha: 0.12 + (0.24 * (1 - t))),
                            ),
                          ),
                        ),
                      ),
                      Transform.scale(
                        scale: 1 + (0.09 * t),
                        child: Container(
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              width: 1.2,
                              color: const Color(
                                0xFFE8C98A,
                              ).withValues(alpha: 0.2 + (0.26 * t)),
                            ),
                          ),
                        ),
                      ),
                    ],
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 420),
                      curve: Curves.easeOutCubic,
                      width: 68,
                      height: 68,
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          width: widget.greetingGoldWake
                              ? 2
                              : waiting
                              ? 1.5 + t
                              : 2,
                          color: widget.greetingGoldWake
                              ? (complete
                                    ? const Color(
                                        0xFFE8C98A,
                                      ).withValues(alpha: 0.9)
                                    : Colors.transparent)
                              : (complete
                                        ? SelahColors.journeyGold
                                        : Colors.white)
                                    .withValues(
                                      alpha: complete
                                          ? 0.8
                                          : highlightedWaiting
                                          ? 0.68
                                          : 0.32,
                                    ),
                        ),
                        boxShadow: widget.greetingGoldWake
                            ? complete
                                  ? [
                                      BoxShadow(
                                        color: const Color(
                                          0xFFE8C98A,
                                        ).withValues(alpha: 0.2),
                                        blurRadius: 12,
                                      ),
                                    ]
                                  : const []
                            : [
                                BoxShadow(
                                  color: SelahColors.actionFill.withValues(
                                    alpha: complete
                                        ? 0.24
                                        : highlightedWaiting
                                        ? 0.18 + (0.16 * t)
                                        : 0.08 + (0.08 * t),
                                  ),
                                  blurRadius: complete
                                      ? 24
                                      : highlightedWaiting
                                      ? 20 + (12 * t)
                                      : 14 + (8 * t),
                                  spreadRadius: complete
                                      ? 1
                                      : highlightedWaiting
                                      ? 1 + (2 * t)
                                      : t,
                                ),
                              ],
                      ),
                      child: ClipOval(
                        child: photos.isEmpty
                            ? ColoredBox(
                                color: SelahColors.foreground.withValues(
                                  alpha: 0.1,
                                ),
                                child: Center(
                                  child: Text(
                                    you
                                        ? 'You'
                                        : (name.isEmpty ? '?' : name[0]),
                                    style: SelahText.subtext(
                                      size: you ? 11 : 19,
                                    ),
                                  ),
                                ),
                              )
                            : SelahProfileImage(
                                photos.first,
                                width: 60,
                                height: 60,
                              ),
                      ),
                    ),
                    if (!widget.greetingGoldWake)
                      AnimatedScale(
                        scale: complete ? 1 : 0,
                        duration: const Duration(milliseconds: 320),
                        curve: Curves.easeOutBack,
                        child: Align(
                          alignment: Alignment.bottomRight,
                          child: Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: SelahColors.journeyGold,
                              border: Border.all(
                                color: SelahColors.luxuryDarkPurple,
                                width: 2.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFFE8C98A,
                                  ).withValues(alpha: 0.3),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.check_rounded,
                              size: 13,
                              color: SelahColors.luxuryDarkPurple,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(height: 7),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: SizedBox(
                  key: ValueKey(statusLabel),
                  width: 92,
                  height: 26,
                  child: Text(
                    statusLabel,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: SelahText.subtext(
                      size: 10.5,
                      color: SelahColors.foreground.withValues(
                        alpha: complete ? 0.8 : 0.5,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    Widget scene(double t) {
      final connection = SelahGreetingConnectionPolicy.resolve(
        mine: widget.youComplete,
        theirs: widget.otherComplete,
      );
      final travelling =
          connection == SelahGreetingConnectionMotion.outbound ||
          connection == SelahGreetingConnectionMotion.inbound;
      const lineLeft = 68.0;
      const lineWidth = 94.0;
      final travel = ((t - 0.12) / 0.76).clamp(0.0, 1.0).toDouble();
      final travelOpacity = t < 0.12
          ? (t / 0.12).clamp(0.0, 1.0).toDouble()
          : t > 0.88
          ? ((1 - t) / 0.12).clamp(0.0, 1.0).toDouble()
          : 1.0;
      final outbound = connection == SelahGreetingConnectionMotion.outbound;
      final dotProgress = outbound ? travel : 1 - travel;
      final wakeWidth = lineWidth * travel;
      final wakeLeft = outbound ? lineLeft : lineLeft + lineWidth - wakeWidth;

      return SizedBox(
        width: 230,
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            Positioned(
              top: 33,
              left: lineLeft,
              width: lineWidth,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 520),
                curve: Curves.easeOutCubic,
                height: widget.greetingGoldWake ? 1 : 1.5,
                decoration: widget.greetingGoldWake
                    ? BoxDecoration(
                        color:
                            connection == SelahGreetingConnectionMotion.settled
                            ? SelahColors.journeyGold.withValues(alpha: 0.74)
                            : SelahColors.foreground.withValues(alpha: 0.28),
                      )
                    : BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            SelahColors.journeyGold.withValues(
                              alpha: widget.youComplete ? 0.7 : 0.16,
                            ),
                            SelahColors.foreground.withValues(
                              alpha: 0.2 + (0.18 * t),
                            ),
                            SelahColors.journeyGold.withValues(
                              alpha: widget.otherComplete ? 0.7 : 0.16,
                            ),
                          ],
                        ),
                      ),
              ),
            ),
            if (widget.greetingGoldWake && travelling) ...[
              Positioned(
                top: 32,
                left: wakeLeft,
                width: wakeWidth,
                child: Opacity(
                  opacity: 0.72 * travelOpacity,
                  child: Container(
                    height: 3,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: outbound
                            ? Alignment.centerLeft
                            : Alignment.centerRight,
                        end: outbound
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        colors: [
                          SelahColors.journeyGold,
                          SelahColors.journeyGold.withValues(alpha: 0.12),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 30,
                left: lineLeft - 3 + (lineWidth * dotProgress),
                child: Opacity(
                  opacity: travelOpacity,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: SelahColors.journeyGold,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(
                            0xFFE8C98A,
                          ).withValues(alpha: 0.88),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                portrait(you: true, complete: widget.youComplete, t: t),
                portrait(you: false, complete: widget.otherComplete, t: t),
              ],
            ),
          ],
        ),
      );
    }

    if (reduceMotion) return scene(0.5);
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) => scene(Curves.easeInOut.transform(_pulse.value)),
    );
  }
}

/// THE RIBBON — inherited decision 185, the Journey's header. One mark per displayed
/// chapter: walked ones filled in quiet gold, the road ahead
/// faint, and the chapter underfoot opened into a pill that says its
/// number and name. Labels come from the canonical map (inherited decision 129);
/// during a Family Review the pill carries the override label instead.
/// Gold completed dots navigate; faint future dots and the current pill do not.
class _JourneyRibbon extends StatelessWidget {
  final String? stage;
  final List<SelahJourneyStage> stages;
  final bool reviewOpen;
  final ValueChanged<int> onCompletedStageTap;
  const _JourneyRibbon({
    required this.stage,
    required this.stages,
    required this.reviewOpen,
    required this.onCompletedStageTap,
  });

  static const _gold = SelahColors.journeyGold;

  @override
  Widget build(BuildContext context) {
    SelahJourneyStage? selected;
    for (final candidate in stages) {
      if (candidate.value == stage) {
        selected = candidate;
        break;
      }
    }
    if (selected == null) return SizedBox.shrink();
    final current = selected;
    final children = <Widget>[];
    for (final st in stages) {
      if (children.isNotEmpty) children.add(SizedBox(width: 3));
      if (st.order == current.order) {
        children.add(
          Flexible(
            fit: FlexFit.loose,
            child: IntrinsicWidth(
              child: Container(
                constraints: const BoxConstraints(minHeight: 24),
                padding: const EdgeInsets.symmetric(horizontal: 11),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: _gold.withValues(alpha: 0.10),
                  border: Border.all(color: _gold, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: _gold.withValues(alpha: 0.30),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Text(
                  '${current.order} · ${reviewOpen ? SelahJourneyStages.familyReviewOverride : current.label}',
                  style: SelahText.subtext(size: 11.5, color: _gold),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        );
      } else {
        final walked = st.order < current.order;
        children.add(
          Semantics(
            button: walked,
            enabled: walked,
            label: walked
                ? 'View completed Stage ${st.order}: ${st.label}'
                : 'Stage ${st.order}: ${st.label}',
            child: InkResponse(
              onTap: walked ? () => onCompletedStageTap(st.order) : null,
              radius: 15,
              child: SizedBox(
                width: 20,
                height: 24,
                child: Center(
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: walked
                          ? _gold.withValues(alpha: 0.68)
                          : SelahColors.luxuryDarkPurple.withValues(alpha: 0.4),
                      border: walked
                          ? null
                          : Border.all(
                              color: SelahColors.foreground.withValues(
                                alpha: 0.2,
                              ),
                              width: 1,
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }
    }
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: children,
      ),
    );
  }
}

/// A calm boundary between chapters. Reaching this page has not silently
/// advanced anything: the member chooses whether to keep moving, rest the
/// Journey, or close it. End retains its separate final confirmation.
class _JourneyStageDecisionPage extends StatelessWidget {
  final SelahJourneyStage stage;
  final String nextLabel;
  final bool completionConfirmed;
  final bool busy;
  final bool continueSelected;
  final VoidCallback onBack;
  final VoidCallback onSelectContinue;
  final Future<void> Function() onCommitContinue;
  final VoidCallback onPause;
  final VoidCallback onEnd;

  const _JourneyStageDecisionPage({
    required this.stage,
    required this.nextLabel,
    required this.completionConfirmed,
    required this.busy,
    required this.continueSelected,
    required this.onBack,
    required this.onSelectContinue,
    required this.onCommitContinue,
    required this.onPause,
    required this.onEnd,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const verticalPadding = 50.0;
        final centredHeight = constraints.hasBoundedHeight
            ? (constraints.maxHeight - verticalPadding)
                  .clamp(0.0, double.infinity)
                  .toDouble()
            : 0.0;
        return SingleChildScrollView(
          // This page fits in the Journey viewport. Disabling its own vertical
          // drag recogniser lets the surrounding PageView receive the gesture,
          // so dragging back up reliably returns to the exact completed stage.
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(28, 22, 28, 28),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: centredHeight),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 350),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Semantics(
                      button: true,
                      label: 'Return to the completed stage',
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: busy ? null : onBack,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.keyboard_arrow_up_rounded,
                                size: 24,
                                color: SelahColors.foreground.withValues(
                                  alpha: 0.52,
                                ),
                              ),
                              Text(
                                'Stage ${stage.order} completion above',
                                style: SelahText.subtext(
                                  size: 10.5,
                                  color: SelahColors.foreground.withValues(
                                    alpha: 0.52,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    _JourneyDecisionBeat(
                      nodeColor: const Color(0xFFE0C678),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            completionConfirmed
                                ? 'STAGE ${stage.order} COMPLETE'
                                : 'STAGE ${stage.order} CHECKPOINT',
                            style: SelahText.chapterLabel(
                              color: SelahColors.ink(0.54),
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            completionConfirmed
                                ? stage.completionHeading
                                : 'Ready to move forward?',
                            style: SelahText.heading(size: 23),
                          ),
                          SizedBox(height: 7),
                          if (completionConfirmed)
                            Text(
                              stage.completionLine,
                              style: SelahText.subtext(size: 13.5),
                            ),
                        ],
                      ),
                    ),
                    _JourneyDecisionBeat(
                      nodeColor: const Color(0xFF9D86AD),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'STAGE ${stage.order + 1} AHEAD',
                            style: SelahText.chapterLabel(
                              color: SelahColors.ink(0.54),
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(nextLabel, style: SelahText.heading(size: 20)),
                          SizedBox(height: 6),
                          Text(
                            'The next chapter waits below.',
                            style: SelahText.subtext(size: 13),
                          ),
                        ],
                      ),
                    ),
                    _JourneyDecisionBeat(
                      nodeColor: SelahColors.journeyDotGreen,
                      last: true,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'YOUR DECISION',
                            style: SelahText.chapterLabel(
                              color: SelahColors.ink(0.54),
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'How will you continue?',
                            style: SelahText.heading(size: 20),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Continue, pause, or end your Journey.',
                            style: SelahText.subtext(size: 13),
                          ),
                          SizedBox(height: 15),
                          _JourneyOpenDecisionRail(
                            busy: busy,
                            continueSelected: continueSelected,
                            onContinue: onSelectContinue,
                            onPause: onPause,
                            onEnd: onEnd,
                          ),
                          if (continueSelected) ...[
                            SizedBox(height: 8),
                            _JourneyScrollToContinue(
                              onContinue: onCommitContinue,
                              idleLabel: 'Continue',
                              openingLabel: 'Continuing…',
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
        );
      },
    );
  }
}

class _JourneyDecisionBeat extends StatelessWidget {
  final Color nodeColor;
  final bool last;
  final Widget child;

  const _JourneyDecisionBeat({
    required this.nodeColor,
    required this.child,
    this.last = false,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 34,
            child: Column(
              children: [
                SizedBox(height: 3),
                Container(
                  width: 15,
                  height: 15,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: nodeColor,
                    border: Border.all(
                      color: SelahColors.luxuryDarkPurple,
                      width: 3,
                    ),
                  ),
                ),
                if (!last)
                  Expanded(
                    child: Container(
                      width: 1,
                      color: SelahColors.foreground.withValues(alpha: 0.28),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? 0 : 28),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

class _JourneyOpenDecisionRail extends StatelessWidget {
  final bool busy;
  final bool continueSelected;
  final VoidCallback onContinue;
  final VoidCallback onPause;
  final VoidCallback onEnd;

  const _JourneyOpenDecisionRail({
    required this.busy,
    required this.continueSelected,
    required this.onContinue,
    required this.onPause,
    required this.onEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Divider(
          height: 1,
          color: SelahColors.foreground.withValues(alpha: 0.24),
        ),
        _JourneyOpenDecisionAction(
          label: continueSelected ? 'Continue selected' : 'Continue',
          dotColor: SelahColors.journeyDotGreen,
          selected: continueSelected,
          onTap: busy ? null : onContinue,
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) => SizeTransition(
            sizeFactor: animation,
            alignment: Alignment.topCenter,
            child: FadeTransition(opacity: animation, child: child),
          ),
          child: continueSelected
              ? SizedBox.shrink(key: ValueKey('continue-selected'))
              : Column(
                  key: const ValueKey('all-decisions'),
                  children: [
                    _JourneyOpenDecisionAction(
                      label: 'Request Pause',
                      dotColor: const Color(0xFFDFBD62),
                      onTap: busy ? null : onPause,
                    ),
                    _JourneyOpenDecisionAction(
                      label: 'End Journey',
                      dotColor: const Color(0xFFDF7D82),
                      destructive: true,
                      onTap: busy ? null : onEnd,
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _JourneyOpenDecisionAction extends StatelessWidget {
  final String label;
  final Color dotColor;
  final bool destructive;
  final bool selected;
  final VoidCallback? onTap;

  const _JourneyOpenDecisionAction({
    required this.label,
    required this.dotColor,
    required this.onTap,
    this.destructive = false,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? 0.42 : 1,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          child: Container(
            height: 54,
            decoration: BoxDecoration(
              color: selected
                  ? SelahColors.journeyGold.withValues(alpha: 0.09)
                  : Colors.transparent,
              border: Border(
                bottom: BorderSide(
                  color: selected
                      ? SelahColors.journeyGold.withValues(alpha: 0.52)
                      : SelahColors.foreground.withValues(alpha: 0.24),
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: dotColor,
                  ),
                ),
                SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: SelahText.body(
                      size: 13,
                      color: destructive
                          ? SelahColors.destructive
                          : Colors.white,
                    ),
                  ),
                ),
                Icon(
                  selected ? Icons.check_rounded : Icons.chevron_right_rounded,
                  size: 20,
                  color: selected
                      ? SelahColors.journeyGold
                      : SelahColors.foreground.withValues(alpha: 0.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _JourneyLifecycleAction { pause, end }

enum _JourneyLifecycleFailure { failed }

/// Exact production Pause-confirm surface with an injectable write, used to
/// force the unknown-failure branch without a live backend outage.
@visibleForTesting
Widget buildSelahPauseFailureTestSurface({
  required Future<void> Function() write,
}) {
  return _JourneyLifecycleConfirmScreen(
    action: _JourneyLifecycleAction.pause,
    profile: const SeekerProfile(
      id: 'truthful-failure-test-profile',
      firstName: 'James',
      age: 30,
      city: 'London',
      photos: <String>[],
      gender: 'male',
    ),
    onConfirm: () async {
      await write();
      return null;
    },
  );
}

const _requestNewJourneyHoldTestProfile = SeekerProfile(
  id: 'request-new-journey-hold-test-profile',
  firstName: 'Abigail',
  age: 30,
  city: 'London',
  photos: <String>[],
  gender: 'female',
);

@visibleForTesting
Widget buildSelahEndConfirmationTestSurface() => _JourneyLifecycleConfirmScreen(
  action: _JourneyLifecycleAction.end,
  profile: _requestNewJourneyHoldTestProfile,
  onConfirm: () async => null,
);

@visibleForTesting
Widget buildSelahJourneyEndedCompleteTestSurface() =>
    const _JourneyLifecycleCompleteScreen(
      profile: _requestNewJourneyHoldTestProfile,
    );

@visibleForTesting
Widget buildSelahEndedJourneyTestSurface() =>
    const _EndedView(profile: _requestNewJourneyHoldTestProfile);

class _JourneyLifecycleConfirmScreen extends StatefulWidget {
  final _JourneyLifecycleAction action;
  final SeekerProfile profile;
  final Future<_JourneyLifecycleFailure?> Function() onConfirm;

  const _JourneyLifecycleConfirmScreen({
    required this.action,
    required this.profile,
    required this.onConfirm,
  });

  @override
  State<_JourneyLifecycleConfirmScreen> createState() =>
      _JourneyLifecycleConfirmScreenState();
}

class _JourneyLifecycleConfirmScreenState
    extends State<_JourneyLifecycleConfirmScreen> {
  bool _busy = false;
  String? _error;

  bool get _pausing => widget.action == _JourneyLifecycleAction.pause;

  Future<void> _confirm() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    _JourneyLifecycleFailure? failure;
    try {
      failure = await widget.onConfirm();
    } catch (_) {
      failure = _JourneyLifecycleFailure.failed;
    }
    if (!mounted) return;
    if (failure == null) {
      Navigator.of(context).pop(true);
      return;
    }

    setState(() {
      _busy = false;
      _error = switch (failure) {
        _JourneyLifecycleFailure.failed =>
          _pausing
              ? "Pause request didn't go through. Check your connection and try again."
              : "End didn't go through. Check your connection and try again.",
        null => null,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final accent = _pausing ? const Color(0xFFDFBD62) : const Color(0xFFDF7D82);
    final actionTitle = _pausing ? 'Request Pause' : 'End Journey';
    final body = _pausing
        ? 'This asks for space without deciding the Journey for either of '
              'you. Nothing in your Journey is lost.'
        : 'Ending closes this Journey for both of you. It cannot resume from '
              'this point.';
    final detail = _pausing
        ? '${widget.profile.firstName} can agree to pause, request to '
              'continue, or end the Journey. Until then, it stays Active but '
              'locked for both of you.'
        : SelahReleaseGates.requestNewJourneyEnabled
        ? 'For 60 days after ending, one of you may request a new Journey '
              'and the other must accept. After that, you would need to find '
              'each other again in Browser. Your Timeline is kept.'
        : '${SelahReleaseGates.requestNewJourneyUnavailable} '
              'Your Timeline is kept.';

    return Scaffold(
      body: Container(
        decoration: SelahAppGoldDecoration(gradient: SelahColors.brandGradient),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 4),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: _busy
                          ? null
                          : () => Navigator.of(context).pop(false),
                      icon: Icon(
                        Icons.arrow_back_ios_new,
                        color: SelahColors.ink(0.70),
                        size: 18,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        actionTitle,
                        style: SelahText.subtext(
                          size: 13,
                          color: SelahColors.ink(0.70),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    SizedBox(width: 48),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(32, 44, 32, 32),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 350),
                      child: Column(
                        children: [
                          Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: accent,
                            ),
                          ),
                          SizedBox(height: 22),
                          Text(
                            _pausing ? 'Request a pause?' : 'End this Journey?',
                            style: SelahText.heading(size: 25),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 12),
                          Text(
                            body,
                            style: SelahText.body(size: 14),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 20),
                          Container(width: 54, height: 1, color: accent),
                          SizedBox(height: 20),
                          Text(
                            detail,
                            style: SelahText.subtext(size: 13),
                            textAlign: TextAlign.center,
                          ),
                          if (_error != null) ...[
                            SizedBox(height: 18),
                            Text(
                              _error!,
                              style: SelahText.subtext(
                                size: 12.5,
                                color: SelahColors.destructive,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                          SizedBox(height: 30),
                          _JourneySolidAction(
                            label: _busy
                                ? (_pausing ? 'Requesting…' : 'Ending…')
                                : (_pausing ? 'Request Pause' : 'End Journey'),
                            accent: accent,
                            destructive: !_pausing,
                            onTap: _busy ? null : _confirm,
                          ),
                          SizedBox(height: 10),
                          TextButton(
                            onPressed: _busy
                                ? null
                                : () => Navigator.of(context).pop(false),
                            child: Text(
                              _pausing ? 'Keep Journey active' : 'Keep Journey',
                              style: SelahText.subtext(
                                size: 12.5,
                                color: SelahColors.ink(0.70),
                              ),
                            ),
                          ),
                        ],
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
}

class _JourneyLifecycleCompleteScreen extends StatelessWidget {
  final SeekerProfile profile;

  const _JourneyLifecycleCompleteScreen({required this.profile});

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFDF7D82);

    return Scaffold(
      body: Container(
        decoration: SelahAppGoldDecoration(gradient: SelahColors.brandGradient),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 36),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 350),
                child: Column(
                  children: [
                    Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: accent,
                      ),
                    ),
                    SizedBox(height: 22),
                    Text(
                      'JOURNEY ENDED',
                      style: SelahText.chapterLabel(
                        color: SelahColors.ink(0.54),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'This chapter has closed.',
                      style: SelahText.heading(size: 25),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 12),
                    Text(
                      '${profile.firstName} has been notified. Your Timeline '
                      'is kept, but continuing together would mean '
                      'beginning a new Journey.',
                      style: SelahText.body(size: 14),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 20),
                    Container(width: 54, height: 1, color: accent),
                    SizedBox(height: 20),
                    Text(
                      SelahReleaseGates.requestNewJourneyEnabled
                          ? 'Starting again requires a new request and agreement '
                                'from both of you. The direct request is available '
                                'for 60 days; after that, you would need to meet '
                                'again in Browser.'
                          : SelahReleaseGates.requestNewJourneyUnavailable,
                      style: SelahText.subtext(size: 13),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 34),
                    _JourneySolidAction(
                      label: 'Return to Connections',
                      accent: accent,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _JourneySolidAction extends StatelessWidget {
  final String label;
  final Color accent;
  final bool destructive;
  final VoidCallback? onTap;

  const _JourneySolidAction({
    required this.label,
    required this.accent,
    required this.onTap,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: Opacity(
        opacity: onTap == null ? 0.5 : 1,
        child: Material(
          color: destructive
              ? const Color(0xFF56313B)
              : SelahColors.sheetSurface,
          shape: StadiumBorder(side: BorderSide(color: accent, width: 1)),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: onTap,
            child: Center(
              child: Text(
                label,
                style: SelahText.button(
                  size: 13.5,
                  color: destructive ? accent : Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// THE JOURNEY'S ONE BUTTON LANGUAGE — inherited decision 186 (Founder: "i want
/// the ui to be same and i want it to copy the part-the-veil design").
/// The frosted stadium the veil introduced, now shared by every
/// threshold the Journey itself presents — the opening beats and each
/// chapter's entry — so the same gesture always looks the same.
class _FrostPill extends StatelessWidget {
  final String label;

  /// Null renders the pill dimmed and inert — the frost language's own
  /// disabled state (inherited decision 189 made it the Journey's ONLY button, so
  /// it had to learn the states FilledButton carried).
  final VoidCallback? onTap;
  const _FrostPill({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (onTap == null) {
      return Opacity(opacity: 0.45, child: _pill(context));
    }
    return _pill(context);
  }

  Widget _pill(BuildContext context) {
    return Material(
      color: SelahColors.foreground.withValues(alpha: 0.22),
      shape: StadiumBorder(
        side: BorderSide(color: SelahColors.foreground.withValues(alpha: 0.42)),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
          child: Text(label, style: SelahText.button(size: 13.5)),
        ),
      ),
    );
  }
}

/// The Journey's primary human action. A calm icon and soft halo separate
/// a meaningful threshold action from compact navigation/checkpoint pills,
/// while preserving ordinary button semantics and a generous tap target.
class _JourneyRoundAction extends StatefulWidget {
  final String label;
  final VoidCallback? onTap;
  final IconData icon;

  const _JourneyRoundAction({
    required this.label,
    required this.onTap,
    this.icon = Icons.waving_hand_outlined,
  });

  @override
  State<_JourneyRoundAction> createState() => _JourneyRoundActionState();
}

class _JourneyRoundActionState extends State<_JourneyRoundAction>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breath;

  @override
  void initState() {
    super.initState();
    _breath = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
      value: 0.5,
    );
  }

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    Widget action(double t) => Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 76,
                height: 76,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Transform.scale(
                      scale: 0.94 + (0.1 * t),
                      child: Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(
                              0xFFE8C98A,
                            ).withValues(alpha: 0.18 + (0.2 * t)),
                          ),
                        ),
                      ),
                    ),
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: SelahColors.foreground.withValues(alpha: 0.1),
                        border: Border.all(
                          color: SelahColors.foreground.withValues(alpha: 0.28),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFFCEA2D1,
                            ).withValues(alpha: 0.1 + (0.08 * t)),
                            blurRadius: 18 + (6 * t),
                          ),
                        ],
                      ),
                      child: Icon(
                        widget.icon,
                        color: SelahColors.journeyGold,
                        size: 25,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 7),
              Text(widget.label, style: SelahText.button(size: 13.5)),
            ],
          ),
        ),
      ),
    );

    final content = reduceMotion
        ? action(0.5)
        : AnimatedBuilder(
            animation: _breath,
            builder: (context, _) =>
                action(Curves.easeInOut.transform(_breath.value)),
          );
    return Semantics(
      button: true,
      enabled: widget.onTap != null,
      label: widget.label,
      onTap: widget.onTap,
      child: Opacity(opacity: widget.onTap == null ? 0.45 : 1, child: content),
    );
  }
}

/// The shared visual invitation at the end of every completed Journey stage.
/// Actions remain explicit buttons; leaving a completed chapter is always a
/// deliberate upward scroll through this invitation.
class _JourneyScrollInvitation extends StatefulWidget {
  final VoidCallback onContinue;
  final double progress;
  final bool continuing;
  final String idleLabel;
  final String openingLabel;

  const _JourneyScrollInvitation({
    required this.onContinue,
    required this.progress,
    required this.continuing,
    this.idleLabel = 'Scroll to continue',
    required this.openingLabel,
  });

  @override
  State<_JourneyScrollInvitation> createState() =>
      _JourneyScrollInvitationState();
}

class _JourneyScrollInvitationState extends State<_JourneyScrollInvitation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _invitation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1450),
    value: 0.5,
  );

  @override
  void dispose() {
    _invitation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.progress.clamp(0.0, 1.0).toDouble();
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return Semantics(
      button: true,
      label: 'Scroll to continue the Journey',
      onTap: widget.continuing ? null : widget.onContinue,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.continuing ? null : widget.onContinue,
          excludeFromSemantics: true,
          borderRadius: BorderRadius.circular(18),
          child: SizedBox(
            width: double.infinity,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedBuilder(
                    animation: _invitation,
                    builder: (context, child) {
                      final idleDrop = reduceMotion || progress > 0
                          ? 0.0
                          : 4 * Curves.easeInOut.transform(_invitation.value);
                      return Transform.translate(
                        offset: Offset(0, idleDrop + (8 * progress)),
                        child: child,
                      );
                    },
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 30,
                      color: const Color(
                        0xFFE8C98A,
                      ).withValues(alpha: 0.58 + (0.36 * progress)),
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    widget.continuing ? widget.openingLabel : widget.idleLabel,
                    style: SelahText.subtext(
                      size: 13,
                      color: SelahColors.foreground.withValues(
                        alpha: 0.58 + (0.3 * progress),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Self-contained completion gesture used by Stages 2–7. The gesture begins
/// on the invitation at the end of the completed content, so reading or
/// scrolling through a long result cannot accidentally advance the Journey.
class _JourneyScrollToContinue extends StatefulWidget {
  final Future<void> Function() onContinue;
  final String idleLabel;
  final String openingLabel;
  final Widget? child;
  final bool expand;

  const _JourneyScrollToContinue({
    required this.onContinue,
    this.idleLabel = 'Scroll to continue',
    this.openingLabel = 'Opening your choices…',
    this.child,
    this.expand = false,
  });

  @override
  State<_JourneyScrollToContinue> createState() =>
      _JourneyScrollToContinueState();
}

class _JourneyScrollToContinueState extends State<_JourneyScrollToContinue> {
  static const _threshold = 22.0;
  double _distance = 0;
  bool _committed = false;
  Timer? _signalReset;

  @override
  void dispose() {
    _signalReset?.cancel();
    super.dispose();
  }

  void _start(PointerDownEvent event) {
    if (_committed) return;
    _signalReset?.cancel();
    setState(() => _distance = 0);
  }

  void _track(PointerMoveEvent event) {
    _applyDelta(-event.delta.dy);
  }

  void _trackSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    _applyDelta(event.scrollDelta.dy);
    _signalReset?.cancel();
    _signalReset = Timer(const Duration(milliseconds: 450), () {
      if (mounted && !_committed && _distance != 0) {
        setState(() => _distance = 0);
      }
    });
  }

  void _applyDelta(double delta) {
    if (_committed) return;
    final distance = SelahJourneyScroll.completionDistanceAfterInput(
      currentDistance: _distance,
      forwardDelta: delta,
      threshold: _threshold,
    );
    if (distance >= _threshold) {
      _signalReset?.cancel();
      setState(() => _distance = _threshold);
      unawaited(_continue());
      return;
    }
    setState(() => _distance = distance);
  }

  void _finish(PointerEvent event) {
    if (_committed || _distance == 0) return;
    setState(() => _distance = 0);
  }

  Future<void> _continue() async {
    if (_committed) return;
    setState(() => _committed = true);
    await widget.onContinue();
    // A successful transition disposes this invitation. If the server holds
    // the stage, reset it so the member can try again honestly.
    if (!mounted) return;
    setState(() {
      _committed = false;
      _distance = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final invitation = _JourneyScrollInvitation(
      onContinue: () => unawaited(_continue()),
      progress: _distance / _threshold,
      continuing: _committed,
      idleLabel: widget.idleLabel,
      openingLabel: widget.openingLabel,
    );
    final contents = widget.child == null
        ? invitation
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: [widget.child!, invitation],
          );
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: _start,
      onPointerMove: _track,
      onPointerSignal: _trackSignal,
      onPointerUp: _finish,
      onPointerCancel: _finish,
      child: widget.expand
          ? SizedBox.expand(child: Center(child: contents))
          : contents,
    );
  }
}

/// Carries a confirmed stage boundary through the same vertical movement as
/// the Journey's section PageView. Holding the outgoing child explicitly is
/// intentional: AnimatedSwitcher reverses a single slide tween, which would
/// send the old page back down. A Journey moves forward with the old page
/// leaving above and the new one arriving from below.
class _JourneyVerticalStageSwap extends StatefulWidget {
  final String surfaceKey;
  final Widget child;

  const _JourneyVerticalStageSwap({
    required this.surfaceKey,
    required this.child,
  });

  @override
  State<_JourneyVerticalStageSwap> createState() =>
      _JourneyVerticalStageSwapState();
}

class _JourneyVerticalStageSwapState extends State<_JourneyVerticalStageSwap>
    with SingleTickerProviderStateMixin {
  late Widget _current;
  Widget? _previous;
  late final AnimationController _controller;

  late final Animation<Offset> _incoming = Tween<Offset>(
    begin: const Offset(0, 1),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

  late final Animation<Offset> _outgoing = Tween<Offset>(
    begin: Offset.zero,
    end: const Offset(0, -1),
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
      value: 1,
    );
    _current = widget.child;
  }

  @override
  void didUpdateWidget(covariant _JourneyVerticalStageSwap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.surfaceKey == widget.surfaceKey) {
      _current = widget.child;
      return;
    }

    _previous = _current;
    _current = widget.child;
    _controller.forward(from: 0).whenComplete(() {
      if (mounted) setState(() => _previous = null);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion || _previous == null) {
      return SizedBox.expand(child: _current);
    }

    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          IgnorePointer(
            child: SlideTransition(position: _outgoing, child: _previous),
          ),
          SlideTransition(position: _incoming, child: _current),
        ],
      ),
    );
  }
}

/// One continuous arrival-to-action surface for every real Journey stage.
/// Completed chapters remain physically above the current arrival as compact,
/// read-only endings. The screen opens at the current stage; scrolling up
/// revisits what was completed, while scrolling down reaches the live action.
class _JourneyStageScrollShell extends StatefulWidget {
  final SelahJourneyStage stage;
  final List<SelahJourneyStage> stages;
  final Widget child;
  final Widget compatibilityHistoryChild;
  final Widget greetingHistoryChild;
  final Widget lifeSnapshotHistoryChild;
  final Widget? decisionChild;
  final VoidCallback onOpenTimeline;
  final ValueChanged<bool> onActionVisibilityChanged;
  final ValueChanged<SelahJourneyStage> onViewedStageChanged;

  const _JourneyStageScrollShell({
    super.key,
    required this.stage,
    required this.stages,
    required this.child,
    required this.compatibilityHistoryChild,
    required this.greetingHistoryChild,
    required this.lifeSnapshotHistoryChild,
    this.decisionChild,
    required this.onOpenTimeline,
    required this.onActionVisibilityChanged,
    required this.onViewedStageChanged,
  });

  @override
  State<_JourneyStageScrollShell> createState() =>
      _JourneyStageScrollShellState();
}

class _JourneyStageScrollShellState extends State<_JourneyStageScrollShell> {
  late final PageController _pageController;
  static const double _innerPullThreshold = 34;
  static const double _historyForwardThreshold = 36;
  double _innerPullDistance = 0;
  bool _innerPullCommitted = false;
  int? _innerPullTargetPage;
  int? _historyPointerStartPage;
  double _historyForwardDistance = 0;

  List<SelahJourneyStage> get _history =>
      List.unmodifiable(widget.stages.take(widget.stage.order - 1));

  @override
  void initState() {
    super.initState();
    // Completed endings sit above the current arrival. Open on that arrival,
    // never at the start of the whole history.
    _pageController = PageController(
      initialPage: SelahJourneyScroll.arrivalPage(_history.length),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _JourneyStageScrollShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.decisionChild == null && widget.decisionChild != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_pageController.hasClients) return;
        final reduceMotion =
            MediaQuery.maybeOf(context)?.disableAnimations ?? false;
        final page = SelahJourneyScroll.decisionPage(_history.length);
        if (reduceMotion) {
          _pageController.jumpToPage(page);
        } else {
          _pageController.animateToPage(
            page,
            duration: const Duration(milliseconds: 480),
            curve: Curves.easeOutCubic,
          );
        }
      });
    }
  }

  void scrollToCompletedStage(int order) {
    if (order < 1 ||
        order >= widget.stage.order ||
        !_pageController.hasClients) {
      return;
    }
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) {
      _pageController.jumpToPage(order - 1);
      return;
    }
    _pageController.animateToPage(
      order - 1,
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutCubic,
    );
  }

  void showActionPage() {
    if (!_pageController.hasClients) return;
    final page = SelahJourneyScroll.actionPage(_history.length);
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) {
      _pageController.jumpToPage(page);
      return;
    }
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 480),
      curve: Curves.easeOutCubic,
    );
  }

  void _showPage(int page) {
    if (!_pageController.hasClients) return;
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) {
      _pageController.jumpToPage(page);
      return;
    }
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 480),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _settleInnerScrollableAt(int targetPage) async {
    if (_innerPullCommitted || !_pageController.hasClients) return;
    _innerPullCommitted = true;
    try {
      final reduceMotion =
          MediaQuery.maybeOf(context)?.disableAnimations ?? false;
      if (reduceMotion) {
        _pageController.jumpToPage(targetPage);
      } else {
        await _pageController.animateToPage(
          targetPage,
          duration: const Duration(milliseconds: 480),
          curve: Curves.easeOutCubic,
        );
      }
    } finally {
      _innerPullDistance = 0;
      _innerPullCommitted = false;
      _innerPullTargetPage = null;
    }
  }

  void _accumulateInnerPull({required int targetPage, required double delta}) {
    if (_innerPullCommitted || delta <= 0) return;
    if (_innerPullTargetPage != targetPage) {
      _innerPullTargetPage = targetPage;
      _innerPullDistance = 0;
    }
    _innerPullDistance = (_innerPullDistance + delta)
        .clamp(0, _innerPullThreshold)
        .toDouble();
    if (_innerPullDistance >= _innerPullThreshold) {
      unawaited(_settleInnerScrollableAt(targetPage));
    }
  }

  void _handlePageChanged(int page) {
    // A completed programmatic move or a fresh user drag always starts with a
    // clean inner-pull accumulator. This is what makes Action -> Arrival ->
    // Action repeatable instead of leaving a stale committed latch behind.
    _innerPullDistance = 0;
    _innerPullCommitted = false;
    _innerPullTargetPage = null;
    widget.onActionVisibilityChanged(
      SelahJourneyScroll.isActionPage(
        page: page,
        completedStageCount: _history.length,
      ),
    );
    final viewedIndex = SelahJourneyScroll.viewedStageIndex(
      page: page,
      completedStageCount: _history.length,
    );
    widget.onViewedStageChanged(
      viewedIndex < _history.length ? _history[viewedIndex] : widget.stage,
    );
  }

  void _startHistoryForwardSwipe(PointerDownEvent event) {
    _historyPointerStartPage = null;
    _historyForwardDistance = 0;
    if (!_pageController.hasClients) return;
    final page =
        (_pageController.page ?? _pageController.initialPage.toDouble())
            .round();
    final arrivalPage = SelahJourneyScroll.arrivalPage(_history.length);
    if (page >= 0 && page < arrivalPage) {
      // Compatibility history owns a real inner scroll view so its result can
      // be read again. Its boundary handler decides when a pull has gone past
      // the content; the raw fallback is only for non-scrollable history.
      if (_history[page].value == 'compatibility_reveal' ||
          _history[page].value ==
              SelahJourneyStages.lifeSnapshotPreview.value) {
        return;
      }
      _historyPointerStartPage = page;
    }
  }

  void _trackHistoryForwardSwipe(PointerMoveEvent event) {
    if (_historyPointerStartPage == null) return;
    _historyForwardDistance = SelahJourneyScroll.completionDistanceAfterInput(
      currentDistance: _historyForwardDistance,
      forwardDelta: -event.delta.dy,
      threshold: _historyForwardThreshold,
    );
  }

  void _finishHistoryForwardSwipe(PointerEvent event) {
    final startPage = _historyPointerStartPage;
    final forwardDistance = _historyForwardDistance;
    _historyPointerStartPage = null;
    _historyForwardDistance = 0;
    if (startPage == null || forwardDistance < _historyForwardThreshold) {
      return;
    }

    // Let PageView process the same pointer-up first. If it already settles
    // forward this becomes a no-op; otherwise finish the missed chapter move.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_pageController.hasClients) return;
      final target = SelahJourneyScroll.missedHistoryForwardTarget(
        startPage: startPage,
        currentPage: _pageController.page ?? startPage.toDouble(),
        arrivalPage: SelahJourneyScroll.arrivalPage(_history.length),
        forwardDistance: forwardDistance,
        activationDistance: _historyForwardThreshold,
      );
      if (target == null) return;
      final reduceMotion =
          MediaQuery.maybeOf(context)?.disableAnimations ?? false;
      if (reduceMotion) {
        _pageController.jumpToPage(target);
      } else {
        _pageController.animateToPage(
          target,
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  void _cancelHistoryForwardSwipe(PointerEvent event) {
    _historyPointerStartPage = null;
    _historyForwardDistance = 0;
  }

  /// A tall action (notably the revealed Compatibility result) owns a small
  /// inner scroll view. Once that content is already at its top, one further
  /// downward pull must return to the arrival above instead of being trapped
  /// by the inner scrollable.
  bool _handleInnerActionScroll(ScrollNotification notification) {
    final delta = _pullPastStart(notification);
    if (delta != null) {
      _accumulateInnerPull(
        targetPage: SelahJourneyScroll.arrivalPage(_history.length),
        delta: delta,
      );
    } else if (notification is ScrollEndNotification && !_innerPullCommitted) {
      _innerPullDistance = 0;
      _innerPullTargetPage = null;
    }
    return false;
  }

  bool _handleInnerHistoryScroll(
    ScrollNotification notification,
    int historyPage,
  ) {
    final pastStart = _pullPastStart(notification);
    if (pastStart != null && historyPage > 0) {
      _accumulateInnerPull(targetPage: historyPage - 1, delta: pastStart);
      return false;
    }
    final pastEnd = _pullPastEnd(notification);
    if (pastEnd != null) {
      _accumulateInnerPull(targetPage: historyPage + 1, delta: pastEnd);
      return false;
    }
    if (notification is ScrollEndNotification && !_innerPullCommitted) {
      _innerPullDistance = 0;
      _innerPullTargetPage = null;
    }
    return false;
  }

  double? _pullPastStart(ScrollNotification notification) {
    if (notification is OverscrollNotification && notification.overscroll < 0) {
      return -notification.overscroll;
    }
    if (notification is ScrollUpdateNotification &&
        notification.metrics.pixels <= notification.metrics.minScrollExtent &&
        (notification.scrollDelta ?? 0) < 0) {
      return -(notification.scrollDelta ?? 0);
    }
    return null;
  }

  double? _pullPastEnd(ScrollNotification notification) {
    if (notification is OverscrollNotification && notification.overscroll > 0) {
      return notification.overscroll;
    }
    if (notification is ScrollUpdateNotification &&
        notification.metrics.pixels >= notification.metrics.maxScrollExtent &&
        (notification.scrollDelta ?? 0) > 0) {
      return notification.scrollDelta;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final stage = widget.stage;
    final secondary = stage.guidingQuestion ?? stage.supportingLine;
    final questionCount = JourneyQuestions.forStageValue(stage.value)?.length;
    final history = _history;
    return LayoutBuilder(
      builder: (context, constraints) {
        final pageHeight = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : MediaQuery.sizeOf(context).height;
        final arrivalPage = SelahJourneyScroll.arrivalPage(history.length);
        final actionPage = SelahJourneyScroll.actionPage(history.length);
        final decisionPage = SelahJourneyScroll.decisionPage(history.length);
        return Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: _startHistoryForwardSwipe,
          onPointerMove: _trackHistoryForwardSwipe,
          onPointerUp: _finishHistoryForwardSwipe,
          onPointerCancel: _cancelHistoryForwardSwipe,
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: _handlePageChanged,
            scrollDirection: Axis.vertical,
            pageSnapping: true,
            // Cache the action page one viewport below the arrival. With the
            // default zero cache, Flutter did not mount a stage's StatefulWidget
            // until the drag had already begun; its first network read and
            // loader therefore appeared during the movement and made each
            // section feel like a newly opened route. One viewport is enough to
            // start that read while the arrival is being read, without mounting
            // future stages or changing the page-by-page gesture.
            allowImplicitScrolling: true,
            physics: const PageScrollPhysics(parent: BouncingScrollPhysics()),
            itemCount:
                history.length + 2 + (widget.decisionChild == null ? 0 : 1),
            itemBuilder: (context, index) {
              if (index < history.length) {
                final completedStage = history[index];
                final completedChild = switch (completedStage.value) {
                  'compatibility_reveal' => widget.compatibilityHistoryChild,
                  'greeting_exchange' => widget.greetingHistoryChild,
                  'life_snapshot_preview' => widget.lifeSnapshotHistoryChild,
                  _ => _JourneyCompletedStage(
                    stage: completedStage,
                    height: pageHeight,
                    onOpenTimeline: widget.onOpenTimeline,
                  ),
                };
                final nextOrder = index + 1 < history.length
                    ? history[index + 1].order
                    : stage.order;
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    NotificationListener<ScrollNotification>(
                      onNotification: (notification) =>
                          _handleInnerHistoryScroll(notification, index),
                      child: completedChild,
                    ),
                    if (index > 0)
                      Align(
                        alignment: Alignment.topCenter,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: _JourneyUpCue(
                            label: 'Stage ${history[index - 1].order} above',
                            onTap: () => _showPage(index - 1),
                          ),
                        ),
                      ),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _JourneyDownCue(
                          label: 'Stage $nextOrder below',
                          onTap: () => _showPage(index + 1),
                        ),
                      ),
                    ),
                  ],
                );
              }
              if (index == arrivalPage) {
                return SizedBox(
                  height: pageHeight,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Stack(
                      children: [
                        if (history.isNotEmpty)
                          Align(
                            alignment: Alignment.topCenter,
                            child: Padding(
                              padding: const EdgeInsets.only(top: 16),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _JourneyUpCue(
                                    label: 'Stage ${history.last.order} above',
                                    onTap: () => _showPage(arrivalPage - 1),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        Align(
                          // The stage body starts below the app bar and ribbon.
                          // A small upward optical correction places the words
                          // at the centre of the physical display, consistently
                          // for all eight arrivals.
                          alignment: const Alignment(0, -0.12),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'STAGE ${stage.order} OF ${widget.stages.length}',
                                style: SelahText.chapterLabel(
                                  color: SelahColors.ink(0.54),
                                ),
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(height: 10),
                              Text(
                                stage.arrivalTitle ?? stage.label,
                                style: SelahText.heading(size: 25),
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(height: 16),
                              Text(
                                stage.introduction,
                                style: SelahText.body(
                                  size: 15,
                                  color: SelahColors.foreground.withValues(
                                    alpha: 0.9,
                                  ),
                                ),
                                textAlign: TextAlign.center,
                              ),
                              if (secondary != null) ...[
                                SizedBox(height: 10),
                                Text(
                                  secondary,
                                  style: SelahText.subtext(size: 13),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                              if (questionCount != null) ...[
                                SizedBox(height: 22),
                                _JourneyQuestionChapterBriefing(
                                  questionCount: questionCount,
                                ),
                              ],
                            ],
                          ),
                        ),
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 28),
                            child: _JourneyDownCue(
                              label: questionCount == null
                                  ? history.isEmpty
                                        ? 'Scroll to begin'
                                        : 'Continue'
                                  : 'Begin Question 1 of $questionCount',
                              onTap: showActionPage,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
              if (index == actionPage) {
                return Column(
                  children: [
                    SizedBox(
                      height: 58,
                      child: Center(
                        child: _JourneyUpCue(
                          label: 'Stage ${stage.order} arrival above',
                          onTap: () => _showPage(arrivalPage),
                        ),
                      ),
                    ),
                    Expanded(
                      child: NotificationListener<ScrollNotification>(
                        onNotification: _handleInnerActionScroll,
                        child: SizedBox.expand(child: widget.child),
                      ),
                    ),
                  ],
                );
              }
              assert(index == decisionPage && widget.decisionChild != null);
              return NotificationListener<ScrollNotification>(
                onNotification: _handleInnerActionScroll,
                child: SizedBox.expand(child: widget.decisionChild),
              );
            },
          ),
        );
      },
    );
  }
}

/// The three sustained question chapters begin differently from action-only
/// stages: members need to understand the private envelope before Question 1
/// appears. Counts come from the real question bank, never presentation copy.
class _JourneyQuestionChapterBriefing extends StatelessWidget {
  final int questionCount;

  const _JourneyQuestionChapterBriefing({required this.questionCount});

  @override
  Widget build(BuildContext context) {
    const gold = SelahColors.journeyGold;
    return Semantics(
      label:
          '$questionCount questions, one at a time. Answer privately, review and seal, then open together.',
      child: ExcludeSemantics(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Expanded(
                  child: _JourneyQuestionBriefingStep(
                    number: 1,
                    label: 'Answer\nprivately',
                  ),
                ),
                _JourneyQuestionBriefingConnector(color: gold),
                const Expanded(
                  child: _JourneyQuestionBriefingStep(
                    number: 2,
                    label: 'Review\n& seal',
                  ),
                ),
                _JourneyQuestionBriefingConnector(color: gold),
                const Expanded(
                  child: _JourneyQuestionBriefingStep(
                    number: 3,
                    label: 'Open\ntogether',
                  ),
                ),
              ],
            ),
            SizedBox(height: 13),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline_rounded, size: 13, color: gold),
                SizedBox(width: 6),
                Text(
                  '$questionCount questions · one at a time',
                  style: SelahText.subtext(
                    size: 10.5,
                    color: SelahColors.foreground.withValues(alpha: 0.58),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _JourneyQuestionBriefingStep extends StatelessWidget {
  final int number;
  final String label;

  const _JourneyQuestionBriefingStep({
    required this.number,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 27,
          height: 27,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: SelahColors.journeyGold.withValues(alpha: 0.76),
            ),
          ),
          child: Text(
            '$number',
            style: SelahText.subtext(size: 9.5, color: SelahColors.journeyGold),
          ),
        ),
        SizedBox(height: 6),
        Text(
          label,
          style: SelahText.subtext(
            size: 9.5,
            color: SelahColors.foreground.withValues(alpha: 0.78),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _JourneyQuestionBriefingConnector extends StatelessWidget {
  final Color color;

  const _JourneyQuestionBriefingConnector({required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 28,
      child: Padding(
        padding: const EdgeInsets.only(top: 13),
        child: Container(height: 1, color: color.withValues(alpha: 0.34)),
      ),
    );
  }
}

/// Every live or revisited Journey section exposes the same upward return.
/// The gesture remains available; the cue makes the route explicit and gives
/// nested scrollables such as Compatibility a reliable tap target as well.
class _JourneyUpCue extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _JourneyUpCue({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          excludeFromSemantics: true,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 5),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.keyboard_arrow_up_rounded,
                  size: 24,
                  color: SelahColors.foreground.withValues(alpha: 0.58),
                ),
                Text(
                  label,
                  style: SelahText.subtext(
                    size: 10.5,
                    color: SelahColors.foreground.withValues(alpha: 0.58),
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

/// The next chapter's invitation appears with the arrival instead of asking
/// the member to guess whether the successful Continue tap did anything.
class _JourneyDownCue extends StatefulWidget {
  final String label;
  final VoidCallback onTap;

  const _JourneyDownCue({required this.label, required this.onTap});

  @override
  State<_JourneyDownCue> createState() => _JourneyDownCueState();
}

class _JourneyDownCueState extends State<_JourneyDownCue> {
  bool _reducedMotionLatched = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      _reducedMotionLatched = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 560),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        final visibleValue = _reducedMotionLatched ? 1.0 : value;
        return Opacity(
          opacity: visibleValue,
          child: Transform.translate(
            offset: Offset(0, 10 * (1 - visibleValue)),
            child: child,
          ),
        );
      },
      child: Semantics(
        button: true,
        label: widget.label,
        onTap: widget.onTap,
        excludeSemantics: true,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            excludeFromSemantics: true,
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 30,
                    color: SelahColors.foreground.withValues(alpha: 0.58),
                  ),
                  Text(
                    widget.label,
                    style: SelahText.subtext(
                      size: 12,
                      color: SelahColors.foreground.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The ending of a completed stage, not a recreation of its live screen.
/// Threshold actions cannot be repeated here. Deeper chapters offer their
/// durable Timeline record instead of rebuilding old answer/reveal controls.
class _JourneyCompletedStage extends StatelessWidget {
  final SelahJourneyStage stage;
  final double height;
  final VoidCallback onOpenTimeline;

  const _JourneyCompletedStage({
    required this.stage,
    required this.height,
    required this.onOpenTimeline,
  });

  bool get _hasTimelineRecord =>
      stage.value == 'compatibility_reveal' ||
      stage.kind == SelahStageKind.sustained;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
        child: Column(
          children: [
            const Spacer(),
            Icon(
              Icons.check_circle_outline_rounded,
              size: 25,
              color: SelahColors.journeyGold.withValues(alpha: 0.72),
            ),
            SizedBox(height: 11),
            Text(
              'STAGE ${stage.order} · ${stage.label.toUpperCase()}',
              style: SelahText.chapterLabel(color: SelahColors.ink(0.54)),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 10),
            Text(
              stage.completionHeading,
              style: SelahText.heading(size: 21),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 7),
            Text(
              stage.completionLine,
              style: SelahText.subtext(size: 13.5),
              textAlign: TextAlign.center,
            ),
            if (stage.guidingQuestion != null) ...[
              SizedBox(height: 10),
              Text(
                stage.guidingQuestion!,
                style: SelahText.body(
                  size: 12.5,
                  color: SelahColors.foreground.withValues(alpha: 0.62),
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (_hasTimelineRecord) ...[
              SizedBox(height: 8),
              TextButton(
                onPressed: onOpenTimeline,
                child: Text(
                  'Read this stage in your Timeline',
                  style: SelahText.subtext(
                    size: 11.5,
                    color: SelahColors.ink(0.70),
                  ),
                ),
              ),
            ],
            const Spacer(),
            Container(
              width: 54,
              height: 1,
              color: SelahColors.foreground.withValues(alpha: 0.13),
            ),
          ],
        ),
      ),
    );
  }
}

/// DEV ONLY — a pull-out tab on the right edge, matching the app's own
/// developer panel rather than inventing a second convention.
///
/// Founder, 2026-08-10: "the toggle in Enter should be the same as it is as
/// the rest of the app, a little black button on right middle side."
///
/// The first version was an amber strip under the app bar. It was legible and
/// it was wrong: `dev_scenario_panel.dart` already established the pattern on
/// 2026-08-01 — a 22pt tab, dark-plum glass, chevron when open and a tune glyph
/// when closed, vertically centred. Two debug conventions in one app is one
/// too many, and the newer one is always the one that looks like a bug.
///
/// This remains the Journey's specialist stage-control tab. The global
/// developer rail stays available above pushed routes and owns the page-aware
/// Pause Decision State control; keeping pause state out of this tab avoids
/// two controls for the same scenario.
///
/// ⚠️ IT SKIPS THE THREE THINGS THAT MAKE SELAH WHAT IT IS: the Pre-Journey
/// Ritual, the Shepherd Gate, and the 48-hour Family Review Period.
///
/// RELEASE SAFETY — double-guarded, copying dev_scenario_panel exactly, after
/// the 2026-07-26 audit found Developer Access shipping in a release build:
///   1. the caller only builds it for an @selah.test account
///   2. build() returns SizedBox.shrink() in a release build regardless
///
/// LABELS COME FROM THE CANONICAL MAP (inherited decision 129). No stage name is written
/// here. Three screens once each kept their own switch over the same eight
/// strings and all three drifted; a debug tool showing different names from
/// the product would be a debug tool that lies about what it is debugging.
class _DevStageJumper extends StatefulWidget {
  final String? current;
  final bool busy;
  final ValueChanged<String> onJump;
  final bool lifeSnapshotHasBio;
  final Set<String> lifeSnapshotFieldIds;
  final ValueChanged<bool> onLifeSnapshotBioChanged;
  final ValueChanged<String> onLifeSnapshotFieldToggle;
  final ValueChanged<bool> onLifeSnapshotShowAll;
  final bool hasPlus;
  final ValueChanged<bool> onHasPlusChanged;
  final VoidCallback onRewind;
  final bool livePaused;

  const _DevStageJumper({
    required this.current,
    required this.busy,
    required this.onJump,
    required this.lifeSnapshotHasBio,
    required this.lifeSnapshotFieldIds,
    required this.onLifeSnapshotBioChanged,
    required this.onLifeSnapshotFieldToggle,
    required this.onLifeSnapshotShowAll,
    required this.hasPlus,
    required this.onHasPlusChanged,
    required this.onRewind,
    required this.livePaused,
  });

  @override
  State<_DevStageJumper> createState() => _DevStageJumperState();
}

class _DevStageJumperState extends State<_DevStageJumper> {
  bool _open = false;

  static const double _tabWidth = 22;
  static const double _panelWidth = 232;

  // LOCK 21: private stage choices use the same seven visible stages.
  static final _stages = SelahJourneyStages.previewAll
      .map((stage) => stage.value)
      .toList(growable: false);

  Widget _lifeSnapshotFieldChip(SelahJourneyLifeSnapshotField field) {
    final selected = widget.lifeSnapshotFieldIds.contains(field.id);
    return GestureDetector(
      onTap: widget.busy || widget.livePaused
          ? null
          : () => widget.onLifeSnapshotFieldToggle(field.id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? SelahColors.journeyGold.withValues(alpha: 0.2)
              : SelahColors.foreground.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? SelahColors.journeyGold.withValues(alpha: 0.72)
                : SelahColors.foreground.withValues(alpha: 0.12),
            width: 0.7,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selected ? Icons.check_rounded : Icons.add_rounded,
              size: 12,
              color: selected ? SelahColors.journeyGold : SelahColors.ink(0.54),
            ),
            SizedBox(width: 4),
            Text(
              field.label,
              style: SelahText.subtext(
                size: 10,
                color: selected ? Colors.white : SelahColors.ink(0.70),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!SelahDeveloperAccess.canUseDeveloperTools) {
      return SizedBox.shrink();
    }

    return Positioned(
      top: 0,
      bottom: 0,
      right: _open ? 0 : -_panelWidth,
      width: _panelWidth + _tabWidth,
      child: Row(
        children: [
          GestureDetector(
            onTap: () => setState(() => _open = !_open),
            child: Center(
              child: Container(
                width: _tabWidth,
                height: 92,
                decoration: BoxDecoration(
                  color: SelahColors.modalSheetSurface.withValues(
                    alpha: 242 / 255,
                  ),
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(8),
                  ),
                  border: Border.all(
                    color: SelahColors.foreground.withValues(alpha: 0.16),
                    width: 0.5,
                  ),
                ),
                child: Center(
                  child: Icon(
                    _open ? Icons.chevron_right : Icons.tune,
                    size: 15,
                    color: SelahColors.foreground.withValues(alpha: 0.75),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Material(
              color: SelahColors.modalSheetSurface.withValues(alpha: 242 / 255),
              child: SafeArea(
                left: false,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
                  children: [
                    // START OVER — TOP, at the Founder's word (inherited decision 176:
                    // "PUT START OVER AT THE TOP"): every full walk of the
                    // six experiences begins here, so the reset earns the
                    // first reach, not a scroll. Still the only destructive
                    // thing in the panel, still tinted like the account
                    // reset in dev_scenario_panel, still asks first.
                    SelahDevToolSection(
                      key: const ValueKey('dev_journey_section_start'),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'START OVER',
                            style: SelahText.chapterLabel(
                              color: SelahColors.ink(0.70),
                            ),
                          ),
                          SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: widget.busy || widget.livePaused
                                  ? null
                                  : widget.onRewind,
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                  color: SelahColors.destructiveBorder,
                                  width: 0.7,
                                ),
                              ),
                              child: Text(
                                'Start this Journey again',
                                style: SelahText.subtext(
                                  size: 12,
                                  color: SelahColors.destructive,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Back to Compatibility Reveal, with everything you both '
                            'did inside it cleared. The match and your Shepherd link '
                            'stay. Asks first.',
                            style: SelahText.subtext(size: 10.5),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SelahDevToolSection(
                      key: const ValueKey('dev_journey_section_stages'),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Text(
                                'SKIP TO STAGE',
                                style: SelahText.chapterLabel(
                                  color: SelahColors.ink(0.70),
                                ),
                              ),
                              const Spacer(),
                              if (widget.busy)
                                SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: SelahLoading(),
                                ),
                            ],
                          ),
                          SizedBox(height: 10),
                          // CHIPS, not a tower — 2026-08-12 (premium-tool pass).
                          // Full-width rows pushed the panel past one screen;
                          // wrapped chips keep the whole sequence visible.
                          // Labels still come from the canonical map, never a
                          // literal here.
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final s in _stages)
                                Builder(
                                  builder: (_) {
                                    final isCurrent = s == widget.current;
                                    return GestureDetector(
                                      onTap:
                                          widget.busy ||
                                              widget.livePaused ||
                                              isCurrent
                                          ? null
                                          : () => widget.onJump(s),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 7,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isCurrent
                                              ? SelahColors.foreground
                                                    .withValues(alpha: 0.22)
                                              : SelahColors.foreground
                                                    .withValues(alpha: 0.06),
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                          border: Border.all(
                                            color: SelahColors.foreground
                                                .withValues(
                                                  alpha: isCurrent
                                                      ? 0.35
                                                      : 0.12,
                                                ),
                                            width: 0.5,
                                          ),
                                        ),
                                        child: Text(
                                          SelahJourneyStages.previewLabelFor(s),
                                          style: SelahText.subtext(
                                            size: 11,
                                            color: isCurrent
                                                ? Colors.white
                                                : SelahColors.ink(0.70),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    if (widget.current ==
                        SelahJourneyStages.lifeSnapshotPreview.value) ...[
                      const SizedBox(height: 16),
                      SelahDevToolSection(
                        key: const ValueKey('dev_journey_section_bio'),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'STAGE 3 BIO',
                              style: SelahText.chapterLabel(
                                color: SelahColors.ink(0.70),
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              'Preview only what the other person chose to share '
                              'for this Journey.',
                              style: SelahText.subtext(size: 10.5),
                            ),
                            SizedBox(height: 8),
                            SelahSwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              title: Text(
                                'Journey bio added',
                                style: SelahText.subtext(
                                  size: 11.5,
                                  color: Colors.white,
                                ),
                              ),
                              subtitle: Text(
                                widget.lifeSnapshotHasBio
                                    ? '${SelahJourneyLifeSnapshotMock.bio.length} / '
                                          '${SelahJourneyLifeSnapshotMock.bioCharacterLimit} characters'
                                    : 'No biography will appear',
                                style: SelahText.subtext(size: 9.5),
                              ),
                              value: widget.lifeSnapshotHasBio,
                              onChanged: widget.busy || widget.livePaused
                                  ? null
                                  : widget.onLifeSnapshotBioChanged,
                            ),
                            Row(
                              children: [
                                TextButton(
                                  onPressed: widget.busy || widget.livePaused
                                      ? null
                                      : () =>
                                            widget.onLifeSnapshotShowAll(true),
                                  child: const Text('Show all'),
                                ),
                                TextButton(
                                  onPressed: widget.busy || widget.livePaused
                                      ? null
                                      : () =>
                                            widget.onLifeSnapshotShowAll(false),
                                  child: const Text('Show none'),
                                ),
                              ],
                            ),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                for (final field
                                    in SelahJourneyLifeSnapshotMock.fields)
                                  _lifeSnapshotFieldChip(field),
                              ],
                            ),
                            SizedBox(height: 7),
                            Text(
                              '${widget.lifeSnapshotFieldIds.length} of '
                              '${SelahJourneyLifeSnapshotMock.fields.length} details shared',
                              style: SelahText.subtext(
                                size: 10,
                                color: SelahColors.journeyGold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),
                    SelahDevToolSection(
                      key: const ValueKey('dev_journey_section_account'),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // inherited decision 135 / inherited upstream action 152. Simulates having bought
                          // Compatibility Unlock+, which lets you see the score
                          // before the other Seeker reveals.
                          //
                          // With THE OTHER PERSON's auto half left OFF, this
                          // reaches the state that could not exist before today:
                          // you see the number, she has not revealed, and she has
                          // not been told.
                          Text(
                            'THIS ACCOUNT',
                            style: SelahText.chapterLabel(
                              color: SelahColors.ink(0.70),
                            ),
                          ),
                          SizedBox(height: 8),
                          SelahSwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            value: widget.hasPlus,
                            onChanged: widget.busy || widget.livePaused
                                ? null
                                : widget.onHasPlusChanged,
                            title: Text(
                              'Has paid for Compatibility Unlock',
                              style: SelahText.subtext(
                                size: 12,
                                color: Colors.white,
                              ),
                            ),
                            subtitle: Text(
                              widget.hasPlus
                                  ? 'You see the score early. They are told nothing.'
                                  : 'Mutual reveal applies — neither sees it first.',
                              style: SelahText.subtext(size: 10.5),
                            ),
                          ),
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

// BACK AND A NAME — that is the whole header now.
//
// THE ⋮ WENT FIRST (2026-08-13, morning — Founder: "those 3 dots of top
// right for active journey. remove it.. put it in main page section"):
// its Pause / End / Report moved to the Active Journey card on
// Connections. THE PILL ROW WENT THE SAME DAY (Founder: "Map Timeline
// Profile at the top… I don't think they're needed anymore"): Timeline
// and Profile live on that same card, and Map — the one action the card
// doesn't carry — DISSOLVED INTO the Timeline ("map is not needed cos
// it should live in timeline"): the rail now runs past a YOU ARE HERE
// into the road ahead, and JourneyMapScreen is retired outright. The
// Journey screen holds only the Journey.
//
// Stateless: the GlobalKey existed only so the menu overlay could find
// its anchor, and went with the menu. `stage` stayed a parameter for one
// build after the Map pill left and was removed with the pill row —
// nothing here reads it now.
class _JourneyAppBar extends StatelessWidget {
  final SeekerProfile profile;
  final SelahJourneyStage stage;
  final String? ownMainShepherdName;
  const _JourneyAppBar({
    required this.profile,
    required this.stage,
    this.ownMainShepherdName,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 12, 4),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: Icon(
                  Icons.arrow_back_ios_new,
                  color: SelahColors.ink(0.70),
                  size: 18,
                ),
              ),
              Expanded(
                child: Text(
                  'Journey with ${profile.firstName}',
                  style: SelahText.heading(size: 16),
                  textAlign: TextAlign.center,
                ),
              ),
              // The old trailing controls' footprint, kept as space so the
              // title stays centred — an IconButton is 48pt wide.
              SizedBox(width: 48),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
            child: Text(
              selahJourneyStageHeader(
                stageOrder: stage.order,
                counterpartFirstName: profile.firstName,
                ownMainShepherdName: ownMainShepherdName,
              ),
              style: SelahText.subtext(),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

// The Ended Journey view.
//
// REWRITTEN 2026-08-06 — inherited upstream action 154, inherited decision 121.
//
// Was stateful purely to drive a one-second countdown to a "Restart
// Journey" button. Both are gone: restart_journey() reopened an ended
// Journey on one person's tap, deleting six tables of history and clearing
// `ended_at` first, and the server now refuses it.
//
// The 24-hour cooling period it counted down to came from APP/Journey/
// JOURNEY AVAILABILITY/Summary.md "ENDED JOURNEY — RULES". That rule is
// superseded: under V3 §9 an ended Journey is permanent, and starting again
// is a new attempt requiring the other person's consent — not a timer
// expiring. Counting down to a button that no longer exists would be worse
// than saying nothing.
//
// Stateless again, and one Timer.periodic fewer running per ended Journey.
class _EndedView extends StatelessWidget {
  final SeekerProfile profile;
  const _EndedView({required this.profile});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 350),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFDF7D82),
                ),
              ),
              SizedBox(height: 20),
              Text(
                'JOURNEY ENDED',
                style: SelahText.chapterLabel(color: SelahColors.ink(0.54)),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 12),
              Text(
                'This chapter has closed.',
                style: SelahText.heading(size: 24),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 11),
              Text(
                'Your Journey with ${profile.firstName} is no longer active. '
                'Your Timeline and everything you shared are kept.',
                style: SelahText.body(size: 14),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 20),
              SizedBox(
                width: 54,
                child: Divider(height: 1, color: Color(0xFFDF7D82)),
              ),
              SizedBox(height: 20),
              Text(
                SelahReleaseGates.requestNewJourneyEnabled
                    ? 'Beginning together again means starting a new Journey. One '
                          'person requests it and the other decides. That direct option '
                          'lasts 60 days; after it closes, you would need to meet again '
                          'through Browser.'
                    : SelahReleaseGates.requestNewJourneyUnavailable,
                style: SelahText.subtext(size: 13),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 30),
              _JourneySolidAction(
                label: 'Return to Connections',
                accent: const Color(0xFFDF7D82),
                onTap: () => Navigator.of(context).maybePop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

@visibleForTesting
Widget buildSelahPauseDecisionTestSurface({
  required SelahJourneyPauseState state,
  required String viewerId,
  bool capacityAvailable = true,
  String profileName = 'James',
  String profileGender = 'male',
  ValueChanged<SelahPauseAction>? onAction,
}) => MaterialApp(
  home: Scaffold(
    body: _PauseDecisionView(
      profile: SeekerProfile(
        id: 'pause-test-other',
        firstName: profileName,
        age: 30,
        city: 'London',
        photos: const <String>[],
        gender: profileGender,
      ),
      state: state,
      busy: false,
      preview: false,
      capacityAvailable: capacityAvailable,
      viewerId: viewerId,
      onAction: onAction ?? (_) {},
      onEnd: () {},
      onReturn: () {},
    ),
  ),
);

class _PauseDecisionView extends StatelessWidget {
  final SeekerProfile profile;
  final SelahJourneyPauseState state;
  final bool busy;
  final bool preview;
  final bool? capacityAvailable;
  final ValueChanged<SelahPauseAction> onAction;
  final VoidCallback onEnd;
  final VoidCallback onReturn;
  final String? viewerId;

  const _PauseDecisionView({
    required this.profile,
    required this.state,
    required this.busy,
    required this.preview,
    required this.capacityAvailable,
    required this.onAction,
    required this.onEnd,
    required this.onReturn,
    this.viewerId,
  });

  String? _deadlineLine() {
    final deadline = state.deadlineAt;
    if (deadline == null) return null;
    final remaining = deadline.difference(DateTime.now());
    if (remaining <= Duration.zero) {
      return 'The response window has ended. No automatic outcome is '
          'configured, so this Journey remains safely locked.';
    }
    if (remaining.inHours >= 24) {
      final days = (remaining.inHours / 24).ceil();
      return 'Response due in $days day${days == 1 ? '' : 's'}.';
    }
    final hours = remaining.inHours;
    final minutes = remaining.inMinutes.remainder(60);
    return 'Response due in ${hours}h ${minutes}m.';
  }

  @override
  Widget build(BuildContext context) {
    final perspective = state.perspectiveFor(
      viewerId ?? SelahAuth.currentUser?.id,
    );
    final title = switch (perspective) {
      SelahPausePerspective.pauseRequesterWaiting => 'Pause requested',
      SelahPausePerspective.pauseResponderDecision =>
        '${profile.firstName} has asked to pause this Journey',
      SelahPausePerspective.continuationRequesterWaiting =>
        'Continuation requested',
      SelahPausePerspective.continuationResponderDecision =>
        '${profile.firstName} would like to continue',
      SelahPausePerspective.mutuallyPaused => 'Journey paused',
      SelahPausePerspective.resumeRequesterWaiting => 'Resume requested',
      SelahPausePerspective.resumeResponderDecision =>
        '${profile.firstName} would like to resume',
      SelahPausePerspective.active => 'Journey active',
    };
    final body = switch (perspective) {
      SelahPausePerspective.pauseRequesterWaiting =>
        'You asked to pause this Journey. Waiting for '
            '${profile.firstName} to decide.',
      SelahPausePerspective.pauseResponderDecision =>
        'Choose what feels right. The Journey stays active but locked until '
            'this decision is settled.',
      SelahPausePerspective.continuationRequesterWaiting =>
        'You asked to continue this Journey. Waiting for '
            '${profile.firstName} to decide.',
      SelahPausePerspective.continuationResponderDecision =>
        'You can continue from the exact place you both reached, confirm the '
            'pause, or end the Journey.',
      SelahPausePerspective.mutuallyPaused =>
        'You both agreed to take some space. Nothing has been lost. Either '
            'person can ask to resume when ready.',
      SelahPausePerspective.resumeRequesterWaiting =>
        'You asked to resume. This Journey remains paused while '
            '${profile.firstName} decides.',
      SelahPausePerspective.resumeResponderDecision =>
        'Choose whether this Journey resumes, remains paused, or ends.',
      SelahPausePerspective.active => 'Your Journey is ready to continue.',
    };
    final deadline = _deadlineLine();
    final capacityBlocked = capacityAvailable == false;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 42),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 350),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (preview) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF34283F),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: const Color(0xFF5B4867),
                      width: 0.5,
                    ),
                  ),
                  child: Text(
                    'DEVELOPMENT PREVIEW',
                    style: SelahText.chapterLabel(color: SelahColors.ink(0.54)),
                  ),
                ),
                SizedBox(height: 16),
              ],
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: SelahColors.journeyGold.withValues(alpha: 0.14),
                  border: Border.all(
                    color: SelahColors.journeyGold.withValues(alpha: 0.72),
                  ),
                ),
                child: Icon(
                  state.isPaused
                      ? Icons.pause_rounded
                      : Icons.hourglass_top_rounded,
                  color: SelahColors.journeyGold,
                  size: 18,
                ),
              ),
              SizedBox(height: 20),
              Text(
                state.isPaused ? 'SHARED PAUSE' : 'DECISION PENDING',
                style: SelahText.chapterLabel(color: SelahColors.ink(0.54)),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 12),
              Text(
                title,
                style: SelahText.heading(size: 24),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 11),
              Text(
                body,
                style: SelahText.body(size: 14),
                textAlign: TextAlign.center,
              ),
              if (deadline != null) ...[
                SizedBox(height: 12),
                Text(
                  deadline,
                  style: SelahText.subtext(
                    size: 11.5,
                    color: state.deadlineExpired
                        ? const Color(0xFFDFBD62)
                        : SelahColors.ink(0.58),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              if (capacityBlocked &&
                  (perspective ==
                          SelahPausePerspective.pauseResponderDecision ||
                      perspective ==
                          SelahPausePerspective
                              .continuationResponderDecision)) ...[
                SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: SelahColors.journeyGold.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: SelahColors.journeyGold.withValues(alpha: 0.35),
                      width: 0.7,
                    ),
                  ),
                  child: Text(
                    'Paused Journey capacity is full for one account. '
                    'Manage a Paused Journey, continue this one, or end it.',
                    style: SelahText.subtext(size: 12.5),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
              SizedBox(height: 26),
              if (perspective ==
                  SelahPausePerspective.pauseResponderDecision) ...[
                Divider(
                  height: 1,
                  color: SelahColors.foreground.withValues(alpha: 0.24),
                ),
                _JourneyOpenDecisionAction(
                  label: 'Agree to Pause',
                  dotColor: const Color(0xFFDFBD62),
                  onTap: busy || capacityBlocked
                      ? null
                      : () => onAction(SelahPauseAction.agreePause),
                ),
                _JourneyOpenDecisionAction(
                  label: 'Request to Continue',
                  dotColor: SelahColors.journeyDotGreen,
                  onTap: busy
                      ? null
                      : () => onAction(SelahPauseAction.requestContinue),
                ),
                _JourneyOpenDecisionAction(
                  label: 'End Journey',
                  dotColor: const Color(0xFFDF7D82),
                  destructive: true,
                  onTap: busy ? null : onEnd,
                ),
              ] else if (perspective ==
                  SelahPausePerspective.continuationResponderDecision) ...[
                Divider(
                  height: 1,
                  color: SelahColors.foreground.withValues(alpha: 0.24),
                ),
                _JourneyOpenDecisionAction(
                  label: 'Continue Journey',
                  dotColor: SelahColors.journeyDotGreen,
                  onTap: busy
                      ? null
                      : () => onAction(SelahPauseAction.continueJourney),
                ),
                _JourneyOpenDecisionAction(
                  label: 'Confirm Pause',
                  dotColor: const Color(0xFFDFBD62),
                  onTap: busy || capacityBlocked
                      ? null
                      : () => onAction(SelahPauseAction.confirmPause),
                ),
                _JourneyOpenDecisionAction(
                  label: 'End Journey',
                  dotColor: const Color(0xFFDF7D82),
                  destructive: true,
                  onTap: busy ? null : onEnd,
                ),
              ] else if (perspective ==
                  SelahPausePerspective.mutuallyPaused) ...[
                Divider(
                  height: 1,
                  color: SelahColors.foreground.withValues(alpha: 0.24),
                ),
                _JourneyOpenDecisionAction(
                  label: 'Request Resume',
                  dotColor: SelahColors.journeyDotGreen,
                  onTap: busy
                      ? null
                      : () => onAction(SelahPauseAction.requestResume),
                ),
                _JourneyOpenDecisionAction(
                  label: 'End Journey',
                  dotColor: const Color(0xFFDF7D82),
                  destructive: true,
                  onTap: busy ? null : onEnd,
                ),
              ] else if (perspective ==
                  SelahPausePerspective.resumeResponderDecision) ...[
                Divider(
                  height: 1,
                  color: SelahColors.foreground.withValues(alpha: 0.24),
                ),
                _JourneyOpenDecisionAction(
                  label: 'Agree to Resume',
                  dotColor: SelahColors.journeyDotGreen,
                  onTap: busy
                      ? null
                      : () => onAction(SelahPauseAction.agreeResume),
                ),
                _JourneyOpenDecisionAction(
                  label: 'Keep Paused',
                  dotColor: const Color(0xFFDFBD62),
                  onTap: busy
                      ? null
                      : () => onAction(SelahPauseAction.keepPaused),
                ),
                _JourneyOpenDecisionAction(
                  label: 'End Journey',
                  dotColor: const Color(0xFFDF7D82),
                  destructive: true,
                  onTap: busy ? null : onEnd,
                ),
              ] else ...[
                Divider(
                  height: 1,
                  color: SelahColors.foreground.withValues(alpha: 0.24),
                ),
                _JourneyOpenDecisionAction(
                  label: 'End Journey',
                  dotColor: const Color(0xFFDF7D82),
                  destructive: true,
                  onTap: busy ? null : onEnd,
                ),
              ],
              if (busy) ...[
                SizedBox(height: 12),
                const SelahLoading(label: 'Updating your Journey'),
              ],
              SizedBox(height: 24),
              _JourneySolidAction(
                label: 'Return to Connections',
                accent: const Color(0xFFDFBD62),
                onTap: busy ? null : onReturn,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- Family Review Period (#31) ---------------------------------------
//
// Seeker-facing view only — per MENTOR_ARCHITECTURE_CURRENT_VERSION_V6.md,
// Continue/Pause is a Mentor capability, not a Seeker one ("Each MENTOR
// may Continue or Pause"). This view is deliberately read-only for the
// Seeker: no button re-approves their own stage, matching the spec's
// framing that this gives "Shepherds meaningful involvement... not a
// permission gate" the Seekers themselves operate.
class _FamilyReviewView extends StatefulWidget {
  final ({String id, String status, String toStage, DateTime deadlineAt})
  review;
  final SeekerProfile profile;
  const _FamilyReviewView({required this.review, required this.profile});

  @override
  State<_FamilyReviewView> createState() => _FamilyReviewViewState();
}

class _FamilyReviewViewState extends State<_FamilyReviewView> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // Redraws the countdown every minute — cheap, no network, purely
    // cosmetic (the real resolution is server-side via the poll in
    // _refresh()'s resolveFamilyReviewIfDue call).
    _ticker = Timer.periodic(
      const Duration(minutes: 1),
      (_) => mounted ? setState(() {}) : null,
    );
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  static String _formatRemaining(Duration d) {
    if (d.isNegative || d == Duration.zero) return 'less than a minute';
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    return h > 0 ? '${h}h ${m}m' : '${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final paused = widget.review.status == 'paused';
    final remaining = widget.review.deadlineAt.difference(DateTime.now());

    // THE SEAL — 2026-08-12 (experience redesign). A review only ever opens
    // because the couple just closed a chapter together, so this screen is
    // two beats in one: what was sealed, then whose time this is. The
    // sealed chapter is the stage BEFORE the review's destination.
    final toIdx = SelahJourneyStages.all.indexWhere(
      (s) => s.value == widget.review.toStage,
    );
    final sealedStage = toIdx > 0 ? SelahJourneyStages.all[toIdx - 1] : null;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              paused ? Icons.pause_circle_outline : Icons.hourglass_top,
              color: SelahColors.ink(0.54),
              size: 32,
            ),
            SizedBox(height: 14),
            if (!paused && sealedStage != null) ...[
              Text(
                sealedStage.completionHeading,
                style: SelahText.heading(size: 18),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 6),
              Text(
                sealedStage.completionLine,
                style: SelahText.subtext(),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16),
            ] else
              Text(
                paused ? 'Paused for family review' : 'Family Review Period',
                style: SelahText.heading(size: 18),
                textAlign: TextAlign.center,
              ),
            SizedBox(height: 8),
            Text(
              paused
                  ? "A Shepherd has asked for more time before this Journey continues. This isn't a rejection — it means the family needs a little longer. Selah support is available to help if needed."
                  : 'This pause is deliberate — it is your families\' time. '
                        'Both families have this stage to review, and unless a '
                        'Shepherd raises a concern you continue together in '
                        '${_formatRemaining(remaining)}.',
              style: SelahText.subtext(),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20),
            TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      JourneyTimelineScreen(withProfile: widget.profile),
                ),
              ),
              child: Text(
                'Read your story so far',
                style: SelahText.subtext(
                  size: 12.5,
                  color: SelahColors.ink(0.70),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Compatibility Reveal ---------------------------------------------

class _CompatibilityRevealView extends StatefulWidget {
  final String matchId;
  final SeekerProfile profile;
  final bool isActionVisible;
  final Future<void> Function() onContinue;
  final bool readOnly;

  /// Parent-owned admission/lifetime, not a transport or developer bypass.
  final bool Function() isCurrentSurface;

  /// Server's reason the pair has not moved on yet. 'waiting_for_continue'
  /// means this user has pressed Continue and the other has not — the
  /// checkpoint is recorded, so it is safe to show a wait rather than the
  /// button. See PRE-JOURNEY RITUAL: "Every checkpoint is a shared decision."
  final String? waitingReason;

  const _CompatibilityRevealView({
    required this.matchId,
    required this.profile,
    required this.isActionVisible,
    required this.onContinue,
    required this.waitingReason,
    required this.isCurrentSurface,
    this.readOnly = false,
  });

  @override
  State<_CompatibilityRevealView> createState() =>
      _CompatibilityRevealViewState();
}

class _CompatibilityRevealViewState extends State<_CompatibilityRevealView> {
  bool _mine = false;
  bool _theirs = false;
  double? _score;
  bool _loading = true;
  bool _animateReveal = false;
  bool _hasConfirmedSnapshot = false;
  bool _accountRetryRequired = false;
  SelahCompatibilityReadStatus _readStatus =
      SelahCompatibilityReadStatus.unavailable;
  SelahCompatibilityReadFailure? _readFailure;
  late SelahCompatibilityReadScope _scope;
  int _readGeneration = 0;
  Timer? _poll;
  StreamSubscription<dynamic>? _authSubscription;
  bool _pollLoadBusy = false;
  Future<void>? _loadFlight;

  static final Map<
    SelahCompatibilityReadScope,
    ({bool mine, bool theirs, double? score, double? plusScore})
  >
  _settledSnapshots = {};

  /// inherited decision 135: the server alone decides whether an early Plus read exists.
  double? _plusScore;

  /// A reveal celebration belongs to this member lifetime, not just a match.
  static final Set<SelahCompatibilityReadScope> _celebratedMatches = {};

  static void invalidateParentContext(SelahCompatibilityReadScope scope) {
    _settledSnapshots.remove(scope);
    _celebratedMatches.remove(scope);
  }

  SelahCompatibilityReadScope _currentScope() => SelahCompatibilityReadScope(
    actorId: SelahAuth.currentUser?.id,
    accountGeneration: SelahAccountState.generation,
    matchId: widget.matchId,
  );

  bool _scopeIsCurrent(SelahCompatibilityReadScope scope) {
    final actor = scope.actorId;
    return actor != null &&
        scope == _currentScope() &&
        SelahAccountState.isCurrent(actor, scope.accountGeneration);
  }

  bool _canPublish(
    SelahCompatibilityReadScope scope,
    int generation, {
    bool Function()? surfaceOwner,
  }) =>
      mounted &&
      generation == _readGeneration &&
      scope == _scope &&
      widget.isCurrentSurface() &&
      (surfaceOwner?.call() ?? true) &&
      _scopeIsCurrent(scope);

  void _clearConfirmed() {
    _mine = false;
    _theirs = false;
    _score = null;
    _plusScore = null;
    _hasConfirmedSnapshot = false;
    _animateReveal = false;
  }

  void _resetReadScope({bool restoreCache = false}) {
    _readGeneration++;
    _loadFlight = null;
    _pollLoadBusy = false;
    _scope = _currentScope();
    // Eagerly discard another member's or a previous session's protected data.
    _settledSnapshots.removeWhere(
      (scope, _) =>
          scope.actorId != _scope.actorId ||
          scope.accountGeneration != _scope.accountGeneration,
    );
    _celebratedMatches.removeWhere(
      (scope) =>
          scope.actorId != _scope.actorId ||
          scope.accountGeneration != _scope.accountGeneration,
    );
    _clearConfirmed();
    _readStatus = SelahCompatibilityReadStatus.unavailable;
    _readFailure = _scope.actorId == null
        ? SelahCompatibilityReadFailure.signedOut
        : SelahCompatibilityReadFailure.staleOwner;
    _loading = restoreCache && _scopeIsCurrent(_scope);
    final cached = restoreCache && _scopeIsCurrent(_scope)
        ? _settledSnapshots[_scope]
        : null;
    if (cached != null) {
      _mine = cached.mine;
      _theirs = cached.theirs;
      _score = cached.score;
      _plusScore = cached.plusScore;
      _hasConfirmedSnapshot = true;
      _readFailure = SelahCompatibilityReadFailure.transient;
      // Cache is not a failed refresh or renewed authority. Keep the loader
      // until this visit's read confirms it or actually returns transient.
      _loading = true;
    }
  }

  @override
  void initState() {
    super.initState();
    _resetReadScope(restoreCache: true);
    AppState.instance.addListener(_onAccountChanged);
    _authSubscription = SelahAuth.authStateChanges.listen(
      (_) => _onAccountChanged(),
      onError: (Object error, StackTrace stackTrace) {
        if (!mounted) return;
        if (_scope != _currentScope() || !_scopeIsCurrent(_scope)) {
          _onAccountChanged();
          return;
        }
        // Retire the pending read and its captured actions without inventing
        // a logout. Keep same-owner confirmed data display-only after the error.
        _readGeneration++;
        _loadFlight = null;
        _pollLoadBusy = false;
        _publishReadFailure(
          SelahCompatibilityReadResult.unavailable(
            scope: _scope,
            failure: SelahCompatibilityReadFailure.transient,
          ),
        );
      },
    );
    _load();
    _configurePolling();
  }

  void _onAccountChanged() {
    if (!mounted || (_scope == _currentScope() && _scopeIsCurrent(_scope))) {
      return;
    }
    // AccountState changes its owner/generation before AppState's reset signal.
    // Do not wait for a timer or an outstanding HTTP response to hide old data.
    setState(() {
      _resetReadScope();
      _accountRetryRequired = true;
    });
  }

  void _configurePolling() {
    _poll?.cancel();
    _poll = widget.readOnly
        ? null
        : Timer.periodic(const Duration(seconds: 5), (_) => _pollLoad());
  }

  @override
  void didUpdateWidget(covariant _CompatibilityRevealView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.matchId != widget.matchId ||
        oldWidget.profile.id != widget.profile.id ||
        !oldWidget.isCurrentSurface() ||
        _scope != _currentScope()) {
      final requestedDifferentJourney =
          oldWidget.matchId != widget.matchId ||
          oldWidget.profile.id != widget.profile.id;
      if (requestedDifferentJourney) _accountRetryRequired = false;
      if (oldWidget.profile.id != widget.profile.id) {
        _settledSnapshots.remove(_scope);
        _celebratedMatches.remove(_scope);
      }
      _resetReadScope();
      _loading = !_accountRetryRequired && _scopeIsCurrent(_scope);
      if (!_accountRetryRequired) _load();
    }
    if (oldWidget.readOnly != widget.readOnly) _configurePolling();
    if (!oldWidget.isActionVisible && widget.isActionVisible) {
      _armRevealIfReady();
    }
  }

  bool get _readIsAvailable =>
      _readStatus == SelahCompatibilityReadStatus.available &&
      _hasConfirmedSnapshot &&
      widget.isCurrentSurface() &&
      _scopeIsCurrent(_scope);

  bool get _revealIsReady =>
      _readIsAvailable && _mine && _theirs && _score != null;

  void _armRevealIfReady() {
    if (!_readIsAvailable) return;
    final shouldAnimate = SelahCompatibilityRevealPolicy.shouldAnimate(
      isActionVisible: widget.isActionVisible,
      mineRevealed: _mine,
      theirsRevealed: _theirs,
      hasScore: _score != null,
      alreadyCelebrated: _animateReveal || _celebratedMatches.contains(_scope),
    );
    if (!shouldAnimate) return;
    _celebratedMatches.add(_scope);
    _animateReveal = true;
  }

  Future<void> _pollLoad() async {
    if (_pollLoadBusy ||
        !widget.isCurrentSurface() ||
        !_scopeIsCurrent(_scope) ||
        !_journeyViewCanPoll(context) ||
        !widget.isActionVisible) {
      return;
    }
    _pollLoadBusy = true;
    try {
      await _load();
    } finally {
      _pollLoadBusy = false;
    }
  }

  @override
  void dispose() {
    _readGeneration++;
    _poll?.cancel();
    _authSubscription?.cancel();
    AppState.instance.removeListener(_onAccountChanged);
    super.dispose();
  }

  Future<void> _load({bool allowScoreRecovery = true}) async {
    final active = _loadFlight;
    if (active != null) return active;
    final next = _loadOnce(allowScoreRecovery: allowScoreRecovery);
    _loadFlight = next;
    try {
      await next;
    } finally {
      if (identical(_loadFlight, next)) _loadFlight = null;
    }
  }

  void _publishReadFailure(SelahCompatibilityReadResult result) {
    final keepConfirmed =
        result.status == SelahCompatibilityReadStatus.unavailable &&
        result.failure == SelahCompatibilityReadFailure.transient &&
        _hasConfirmedSnapshot;
    setState(() {
      if (!keepConfirmed) {
        _settledSnapshots.remove(_scope);
        _celebratedMatches.remove(_scope);
        _clearConfirmed();
      }
      _readStatus = result.status;
      _readFailure = result.failure;
      _loading = false;
    });
  }

  Future<void> _loadOnce({required bool allowScoreRecovery}) async {
    final scope = _scope;
    final generation = _readGeneration;
    final otherId = widget.profile.id;
    final surfaceOwner = widget.isCurrentSurface;
    if (!surfaceOwner()) return;
    if (!_scopeIsCurrent(scope)) {
      if (mounted && generation == _readGeneration) {
        _publishReadFailure(
          SelahCompatibilityReadResult.unavailable(
            scope: scope,
            failure: scope.actorId == null
                ? SelahCompatibilityReadFailure.signedOut
                : SelahCompatibilityReadFailure.staleOwner,
          ),
        );
      }
      return;
    }
    var result = await SelahJourneyService.fetchCompatibility(scope.matchId);
    if (!_canPublish(scope, generation, surfaceOwner: surfaceOwner)) return;
    if (result.scope != scope ||
        result.status != SelahCompatibilityReadStatus.available) {
      _publishReadFailure(
        result.scope == scope
            ? result
            : SelahCompatibilityReadResult.unavailable(
                scope: scope,
                failure: SelahCompatibilityReadFailure.staleOwner,
              ),
      );
      return;
    }
    var snapshot = result.snapshot!;

    // Keep the existing valid mutual/null-score first-score recovery.
    // DR250D5's future-held change is not implemented here. An unavailable or
    // empty read never enters this mutation. Explicit Retry skips this legacy
    // recovery; validated one-sided Plus retains its existing server policy.
    if (allowScoreRecovery &&
        !widget.readOnly &&
        snapshot.mine &&
        snapshot.theirs &&
        snapshot.overallScore == null) {
      if (!_canPublish(scope, generation, surfaceOwner: surfaceOwner)) return;
      await SelahJourneyService.revealCompatibility(scope.matchId, otherId);
      if (!_canPublish(scope, generation, surfaceOwner: surfaceOwner)) return;
      result = await SelahJourneyService.fetchCompatibility(scope.matchId);
      if (!_canPublish(scope, generation, surfaceOwner: surfaceOwner)) return;
      if (result.scope != scope ||
          result.status != SelahCompatibilityReadStatus.available) {
        _publishReadFailure(
          result.scope == scope
              ? result
              : SelahCompatibilityReadResult.unavailable(
                  scope: scope,
                  failure: SelahCompatibilityReadFailure.staleOwner,
                ),
        );
        return;
      }
      snapshot = result.snapshot!;
    }

    double? plus;
    if (!widget.readOnly && snapshot.mine && !snapshot.theirs) {
      if (!_canPublish(scope, generation, surfaceOwner: surfaceOwner)) return;
      plus = await SelahJourneyService.fetchCompatibilityForPlus(scope.matchId);
      if (!_canPublish(scope, generation, surfaceOwner: surfaceOwner)) return;
    }

    if (!_canPublish(scope, generation, surfaceOwner: surfaceOwner)) return;
    if (snapshot.mine && snapshot.theirs) {
      _settledSnapshots[scope] = (
        mine: snapshot.mine,
        theirs: snapshot.theirs,
        score: snapshot.overallScore,
        plusScore: plus,
      );
    } else {
      _settledSnapshots.remove(scope);
    }
    final animateNow = SelahCompatibilityRevealPolicy.shouldAnimate(
      isActionVisible: widget.isActionVisible,
      mineRevealed: snapshot.mine,
      theirsRevealed: snapshot.theirs,
      hasScore: snapshot.overallScore != null,
      alreadyCelebrated: _animateReveal || _celebratedMatches.contains(scope),
    );
    if (animateNow) _celebratedMatches.add(scope);
    setState(() {
      _plusScore = plus;
      _mine = snapshot.mine;
      _theirs = snapshot.theirs;
      _score = snapshot.overallScore;
      _hasConfirmedSnapshot = true;
      _readStatus = SelahCompatibilityReadStatus.available;
      _readFailure = null;
      _accountRetryRequired = false;
      _loading = false;
      if (animateNow) _animateReveal = true;
    });
  }

  Future<void> _retryRead() {
    _accountRetryRequired = false;
    return _load(allowScoreRecovery: false);
  }

  Future<void> _reveal(
    SelahCompatibilityReadScope scope,
    int generation,
    bool Function() surfaceOwner,
  ) async {
    if (widget.readOnly ||
        !_readIsAvailable ||
        _loading ||
        _loadFlight != null) {
      return;
    }
    final otherId = widget.profile.id;
    if (!_canPublish(scope, generation, surfaceOwner: surfaceOwner)) return;
    setState(() => _loading = true);
    await SelahJourneyService.revealCompatibility(scope.matchId, otherId);
    if (!_canPublish(scope, generation, surfaceOwner: surfaceOwner)) return;
    await _load();
  }

  String get _readFailureMessage => switch (_readFailure) {
    SelahCompatibilityReadFailure.signedOut =>
      'Sign in again to check your compatibility.',
    SelahCompatibilityReadFailure.forbidden ||
    SelahCompatibilityReadFailure.unavailableJourney =>
      'Compatibility is not available for this Journey.',
    SelahCompatibilityReadFailure.staleOwner =>
      'Your account changed. Check this Journey again to continue.',
    _ =>
      _hasConfirmedSnapshot
          ? 'Showing your last confirmed result. Could not refresh compatibility.'
          : 'Could not load compatibility. Please try again.',
  };

  @override
  Widget build(BuildContext context) {
    // A retired outgoing surface may remain mounted for the 480 ms page
    // handover. It is no longer a place to display protected cached content.
    if (!widget.isCurrentSurface() && !_accountRetryRequired) {
      return const SizedBox.shrink();
    }
    if (_loading) return const SelahLoading();
    if (!_readIsAvailable) {
      final retryScope = _scope;
      final retryGeneration = _readGeneration;
      final retrySurfaceOwner = widget.isCurrentSurface;
      void retryIfCurrent() {
        if (!_canPublish(
          retryScope,
          retryGeneration,
          surfaceOwner: retrySurfaceOwner,
        )) {
          return;
        }
        unawaited(_retryRead());
      }

      final banner = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
        child: SelahErrorBanner(
          message: !_scopeIsCurrent(_scope)
              ? (SelahAuth.currentUser == null
                    ? 'Sign in again to check your compatibility.'
                    : 'Your account changed. Check this Journey again to continue.')
              : _readStatus == SelahCompatibilityReadStatus.empty
              ? 'Compatibility is not available yet for this Journey.'
              : _readFailureMessage,
          onRetry: retryIfCurrent,
        ),
      );
      final keepConfirmed =
          _scopeIsCurrent(_scope) &&
          _readStatus == SelahCompatibilityReadStatus.unavailable &&
          _readFailure == SelahCompatibilityReadFailure.transient &&
          _hasConfirmedSnapshot;
      if (!keepConfirmed) return Center(child: banner);
      // Only a same-owner transient refresh can retain confirmed content.
      // It is display-only until a current read confirms the protected action.
      return Column(
        children: [
          banner,
          Expanded(child: IgnorePointer(child: _buildConfirmed(context))),
        ],
      );
    }
    return _buildConfirmed(context);
  }

  Widget _buildConfirmed(BuildContext context) {
    final stage = SelahJourneyStages.of('compatibility_reveal')!;
    final scope = _scope;
    final generation = _readGeneration;
    final surfaceOwner = widget.isCurrentSurface;
    Future<void> continueIfCurrent() async {
      if (!_readIsAvailable ||
          _loading ||
          !_canPublish(scope, generation, surfaceOwner: surfaceOwner)) {
        return;
      }
      await widget.onContinue();
    }

    // REVEALED, BUT NOT SCOREABLE. Distinct from the retry above, which
    // covers a figure that failed to compute: this is a figure that cannot
    // exist yet, because there is not enough between the two of them to score.
    // Reachable until the onboarding completeness gate (inherited upstream action 193c) is
    // built, and worth keeping afterwards — the alternative is inventing a
    // number the moment the honest branch is deleted.
    if (_mine && _theirs && _score == null && !_loading) {
      final content = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _JourneyPairStatus(
              profile: widget.profile,
              youComplete: _mine,
              otherComplete: _theirs,
            ),
            SizedBox(height: 18),
            Text(
              stage.completionHeading,
              style: SelahText.heading(size: 18),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 4),
            Text(
              'You both chose to reveal.',
              style: SelahText.subtext(),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 10),
            Text(
              '—',
              style: SelahText.heading(size: 44, color: SelahColors.ink(0.38)),
            ),
            SizedBox(height: 10),
            Text(
              'There is not enough between you yet to work out a figure. '
              'It appears here once you have both covered more ground.',
              style: SelahText.subtext(),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24),
          ],
        ),
      );
      if (widget.readOnly || widget.waitingReason == 'waiting_for_continue') {
        return Center(child: content);
      }
      return _JourneyScrollToContinue(
        onContinue: continueIfCurrent,
        openingLabel: 'Opening your choices…',
        expand: true,
        child: content,
      );
    }

    if (_mine && _theirs && _score != null) {
      // SCROLLABLE AS OF 2026-08-11. It was a centred Column, which was fine
      // for a number and five rows and overflows the moment a SELAH Insight is
      // added under it on a small phone. Center + SingleChildScrollView keeps
      // the old centred look whenever it still fits.
      final intelligence = SelahJourneyIntelligence.compatibility(
        plan: AppState.instance.plan,
        score: _score!,
      );
      // THE MOMENT — the June spec's STATE 2, built 2026-08-12. First
      // sight of a mutual result: a held beat on "You both chose to
      // reveal", then the genuine caller-owned number counting up.
      // Once, ever — and only once this preloaded page is actually visible.
      // Later visits render the settled screen instantly.
      final reduceMotion =
          MediaQuery.maybeOf(context)?.disableAnimations ?? false;
      final animate = _animateReveal && !reduceMotion && _revealIsReady;
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
          child: TweenAnimationBuilder<double>(
            key: ValueKey('compatibility-${_scope.hashCode}-$animate'),
            tween: Tween(begin: animate ? 0.0 : 1.0, end: 1.0),
            duration: animate
                ? const Duration(milliseconds: 2600)
                : Duration.zero,
            curve: Curves.easeOutCubic,
            builder: (context, t, _) {
              // The overall ring is the one truthful focal point. Category
              // detail stays withheld until the server owns a real,
              // provenance-safe category contract (inherited upstream action 193d).
              final countT = ((t - 0.18) / 0.40).clamp(0.0, 1.0);
              final shown = (_score! * countT).round();
              final tailT = ((t - 0.85) * 6.7).clamp(0.0, 1.0);
              return Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _JourneyPairStatus(
                    profile: widget.profile,
                    youComplete: _mine,
                    otherComplete: _theirs,
                  ),
                  SizedBox(height: 18),
                  Text(
                    stage.completionHeading,
                    style: SelahText.heading(size: 18),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 4),
                  Text(
                    stage.completionLine,
                    style: SelahText.subtext(),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 14),
                  _CompatibilityScoreRing(
                    score: countT == 0 ? null : shown,
                    progress: (_score! / 100 * countT).clamp(0.0, 1.0),
                  ),
                  // Everything below the result fades in after it — the
                  // moment first, the machinery second.
                  Opacity(
                    opacity: tailT,
                    child: IgnorePointer(
                      ignoring: tailT < 1,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(height: 16),
                          Text(
                            'Detailed compatibility isn’t available yet.',
                            style: SelahText.subtext(),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 16),
                          // SELAH One reads the number back; SELAH Basic sees
                          // the number and an invitation, and the screen is
                          // complete either way.
                          if (intelligence != null)
                            SelahIntelligenceCard(intelligence: intelligence)
                          else
                            const SelahIntelligenceInvitation(
                              kind: SelahIntelligenceKind.insight,
                            ),
                          SizedBox(height: 20),
                          if (widget.readOnly)
                            SizedBox.shrink()
                          else if (widget.waitingReason ==
                              'waiting_for_continue') ...[
                            Text(
                              "You've chosen to continue. Waiting for ${widget.profile.firstName} — every step here is taken together.",
                              style: SelahText.subtext(),
                              textAlign: TextAlign.center,
                            ),
                          ] else
                            _JourneyScrollToContinue(
                              onContinue: continueIfCurrent,
                              openingLabel: 'Opening your choices…',
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      );
    }

    // ── THE THIRD STATE — inherited decision 135, closing inherited upstream action 152 ────────────────
    //
    // A Plus holder can see the score while the other Seeker has not revealed.
    // They are NEITHER waiting-to-see NOR mutually revealed, and the existing
    // two states are both wrong for them:
    //
    //   "Waiting for Aisha"  — they are not waiting to SEE anything.
    //   "You both chose to reveal." — untrue, and the untrue half is the
    //                                 half about the other person.
    //
    // What they are actually waiting for is her to CONTINUE. So the screen
    // says that, and nothing else.
    //
    // No Continue button here on purpose. The Journey advances when both have
    // revealed — buying the number does not buy the stage (DR-135: "the
    // result is bought, the relationship is not"). Offering Continue would
    // make the purchase look like it moved the Journey, which is the exact
    // misreading the decision was careful to avoid.
    if (_mine && !_theirs && _plusScore != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _JourneyPairStatus(
                profile: widget.profile,
                youComplete: _mine,
                otherComplete: _theirs,
                emphasizeWaiting: true,
              ),
              SizedBox(height: 18),
              Text(
                '${_plusScore!.round()}%',
                style: SelahText.heading(size: 44),
              ),
              Text('Overall Compatibility', style: SelahText.subtext()),
              SizedBox(height: 20),
              // Said plainly, because it is the thing they paid for and the
              // thing that could otherwise feel like a glitch: you can see it,
              // they cannot.
              Text(
                'You unlocked this early.',
                style: SelahText.body(size: 13),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 4),
              Text(
                "${widget.profile.firstName} hasn't revealed yet, and hasn't "
                'been told you have. The Journey moves when '
                '${SelahGender.subject(widget.profile.gender)} does.',
                style: SelahText.subtext(),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    if (_mine && !_theirs) {
      return _CompatibilityCompactState(
        profile: widget.profile,
        mine: _mine,
        theirs: _theirs,
        emphasizeWaiting: true,
        headline: 'Reveal chosen',
        body:
            'Waiting for ${widget.profile.firstName}. You open the result together.',
      );
    }

    return _CompatibilityCompactState(
      profile: widget.profile,
      mine: _mine,
      theirs: _theirs,
      headline: SelahJourneyStages.labelFor('compatibility_reveal'),
      body: 'Neither of you sees the result until you both choose to reveal.',
      action: widget.readOnly
          ? null
          : _JourneyRoundAction(
              label: 'Reveal Compatibility',
              icon: Icons.visibility_outlined,
              onTap: () => _reveal(scope, generation, surfaceOwner),
            ),
    );
  }
}

/// The first focal point of the mutual Compatibility Reveal. The label lives
/// inside a deliberately bounded column rather than being painted around the
/// circumference, so it stays centred and readable on narrow iPhones and at
/// larger accessibility text scales.
class _CompatibilityScoreRing extends StatelessWidget {
  final int? score;
  final double progress;

  const _CompatibilityScoreRing({required this.score, required this.progress});

  @override
  Widget build(BuildContext context) {
    final value = progress.clamp(0.0, 1.0).toDouble();
    return Semantics(
      label: score == null
          ? 'Compatibility score being revealed'
          : '$score percent overall compatibility',
      child: ExcludeSemantics(
        child: RepaintBoundary(
          child: SizedBox.square(
            dimension: 176,
            child: CustomPaint(
              painter: _CompatibilityScoreRingPainter(progress: value),
              child: Center(
                child: SizedBox(
                  width: 116,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: 50,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            score == null ? '—' : '$score%',
                            maxLines: 1,
                            style: SelahText.heading(
                              size: 43,
                              color: score == null
                                  ? SelahColors.ink(0.38)
                                  : Colors.white,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 3),
                      SizedBox(
                        height: 28,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Overall\nCompatibility',
                            maxLines: 2,
                            textAlign: TextAlign.center,
                            style: SelahText.subtext(
                              size: 10.5,
                              color: SelahColors.foreground.withValues(
                                alpha: 0.66,
                              ),
                            ).copyWith(height: 1.15, letterSpacing: 0.15),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CompatibilityScoreRingPainter extends CustomPainter {
  final double progress;

  const _CompatibilityScoreRingPainter({required this.progress});

  static const _gold = SelahColors.journeyGold;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(8);
    final track = Paint()
      ..color = SelahColors.foreground.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;
    canvas.drawOval(arcRect, track);

    if (progress <= 0) return;
    final sweep = math.pi * 2 * progress;
    final glow = Paint()
      ..color = _gold.withValues(alpha: 0.28)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 7
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    canvas.drawArc(arcRect, -math.pi / 2, sweep, false, glow);

    final trace = Paint()
      ..color = _gold
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3;
    canvas.drawArc(arcRect, -math.pi / 2, sweep, false, trace);
  }

  @override
  bool shouldRepaint(covariant _CompatibilityScoreRingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _CompatibilityCompactState extends StatelessWidget {
  final SeekerProfile profile;
  final bool mine;
  final bool theirs;
  final bool emphasizeWaiting;
  final String headline;
  final String body;
  final Widget? action;

  const _CompatibilityCompactState({
    required this.profile,
    required this.mine,
    required this.theirs,
    required this.headline,
    required this.body,
    this.emphasizeWaiting = false,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _JourneyPairStatus(
              profile: profile,
              youComplete: mine,
              otherComplete: theirs,
              emphasizeWaiting: emphasizeWaiting,
            ),
            SizedBox(height: 14),
            SizedBox(
              height: 64,
              child: Center(
                child: Text(
                  headline,
                  maxLines: 2,
                  style: SelahText.heading(size: 24),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            SizedBox(height: 8),
            SizedBox(
              height: 50,
              child: Center(
                child: Text(
                  body,
                  maxLines: 2,
                  style: SelahText.subtext(size: 14),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            SizedBox(height: 48),
            SizedBox(height: 130, child: Center(child: action)),
          ],
        ),
      ),
    );
  }
}

// --- Greeting Exchange ------------------------------------------------------

/// Stage 1, rebuilt to say almost nothing — inherited decision 192 (Lead Architect
/// brief, 2026-08-17, from the Founder's own finding: even he was pressing
/// the buttons without reading the page). The user already knows what
/// Greeting is; the page's whole job is to let two people begin respectfully
/// in seconds. Four states, one line each, at most one action; no opening
/// beats, no veil, no gold rule, no ceremony copy, and no loading
/// animation while the only thing happening is another human taking
/// their time.
///
/// Once both Greetings are exchanged, the completed state holds until the
/// member scrolls to continue. This is the Journey's shared transition
/// language: actions are buttons; moving on from a completed chapter is a
/// scroll gesture.
class _GreetingExchangeView extends StatefulWidget {
  final String matchId;
  final SeekerProfile profile;
  final bool isActionVisible;
  final Future<void> Function() onContinue;
  const _GreetingExchangeView({
    required this.matchId,
    required this.profile,
    required this.isActionVisible,
    required this.onContinue,
  });

  @override
  State<_GreetingExchangeView> createState() => _GreetingExchangeViewState();
}

class _GreetingExchangeViewState extends State<_GreetingExchangeView> {
  bool _mine = false;
  bool _theirs = false;

  /// True once a REAL server answer has landed. Until then the page
  /// renders nothing rather than guessing — returning to this page must
  /// show the server's state, not a default.
  bool _known = false;

  bool _sending = false;
  bool _sendFailed = false;
  static const _completionScrollThreshold = 22.0;
  double _completionScrollDistance = 0;
  bool _completionCommitted = false;
  Timer? _completionSignalReset;
  Timer? _poll;
  bool _pollLoadBusy = false;
  Future<void>? _loadFlight;

  @override
  void initState() {
    super.initState();
    _load();
    _poll = Timer.periodic(const Duration(seconds: 5), (_) => _pollLoad());
  }

  @override
  void didUpdateWidget(covariant _GreetingExchangeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isActionVisible && widget.isActionVisible) {
      unawaited(_load());
    }
  }

  Future<void> _pollLoad() async {
    if (_pollLoadBusy ||
        !_journeyViewCanPoll(context) ||
        !widget.isActionVisible) {
      return;
    }
    _pollLoadBusy = true;
    try {
      await _load();
    } finally {
      _pollLoadBusy = false;
    }
  }

  @override
  void dispose() {
    _completionSignalReset?.cancel();
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final active = _loadFlight;
    if (active != null) return active;
    final next = _loadOnce();
    _loadFlight = next;
    try {
      await next;
    } finally {
      if (identical(_loadFlight, next)) _loadFlight = null;
    }
  }

  Future<void> _loadOnce() async {
    final r = await SelahJourneyService.fetchGreetingStatus(
      widget.matchId,
      widget.profile.id,
    );
    if (!mounted || _sending) return;
    // A failed read HOLDS the last known state — flickering a waiting
    // page back to "send" on a bad connection would tell a lie twice.
    if (r == null) return;
    if (_known && r.mine == _mine && r.theirs == _theirs) return;
    setState(() {
      _mine = r.mine;
      _theirs = r.theirs;
      _known = true;
    });
  }

  Future<void> _send() async {
    if (_sending) return; // a double-tap's second tap: no second submission
    setState(() {
      _sending = true;
      _sendFailed = false;
    });
    final ok = await SelahJourneyService.sendGreeting(widget.matchId);
    if (!mounted) return;
    if (!ok) {
      // Same state, same button label, one added line of truth.
      setState(() {
        _sending = false;
        _sendFailed = true;
      });
      return;
    }
    final r = await SelahJourneyService.fetchGreetingStatus(
      widget.matchId,
      widget.profile.id,
    );
    if (!mounted) return;
    setState(() {
      _sending = false;
      if (r != null) {
        _mine = r.mine;
        _theirs = r.theirs;
      } else {
        // The send succeeded; the read after it did not. Our own half
        // is a fact we hold locally.
        _mine = true;
      }
      _known = true;
    });
  }

  void _startCompletionScroll(PointerDownEvent event) {
    if (_completionCommitted) return;
    _completionSignalReset?.cancel();
    setState(() => _completionScrollDistance = 0);
  }

  void _trackCompletionScroll(PointerMoveEvent event) {
    _applyCompletionScrollDelta(-event.delta.dy);
  }

  void _trackCompletionScrollSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    _applyCompletionScrollDelta(event.scrollDelta.dy);
    _completionSignalReset?.cancel();
    _completionSignalReset = Timer(const Duration(milliseconds: 450), () {
      if (mounted && !_completionCommitted && _completionScrollDistance != 0) {
        setState(() => _completionScrollDistance = 0);
      }
    });
  }

  void _applyCompletionScrollDelta(double delta) {
    if (_completionCommitted) return;
    final distance = SelahJourneyScroll.completionDistanceAfterInput(
      currentDistance: _completionScrollDistance,
      forwardDelta: delta,
      threshold: _completionScrollThreshold,
    );
    if (distance >= _completionScrollThreshold) {
      _completionSignalReset?.cancel();
      setState(() => _completionScrollDistance = _completionScrollThreshold);
      unawaited(_continueAfterScroll());
      return;
    }
    setState(() => _completionScrollDistance = distance);
  }

  void _finishCompletionScroll(PointerEvent event) {
    if (_completionCommitted || _completionScrollDistance == 0) return;
    setState(() => _completionScrollDistance = 0);
  }

  Future<void> _continueAfterScroll() async {
    if (_completionCommitted) return;
    setState(() => _completionCommitted = true);
    await widget.onContinue();
    // If the server moved the Journey, this widget has been disposed. If it
    // did not, allow one honest retry rather than trapping the completed page.
    if (!mounted) return;
    setState(() {
      _completionCommitted = false;
      _completionScrollDistance = 0;
    });
  }

  void _continueFromSemantics() {
    unawaited(_continueAfterScroll());
  }

  @override
  Widget build(BuildContext context) {
    if (!_known) return SizedBox.shrink();
    final name = widget.profile.firstName;
    final stage = SelahJourneyStages.of('greeting_exchange')!;

    // Founder-directed copy pass: let the greeting itself lead. The page
    // should sound like two people beginning, not software explaining a
    // ceremonial workflow. No gendered pronouns: the person's name is
    // clearer.
    final String stateKey;
    final String headline;
    final String body;
    if (_mine && _theirs) {
      stateKey = 'complete';
      headline = stage.completionHeading;
      body = stage.completionLine;
    } else if (_theirs) {
      stateKey = 'return';
      headline = '$name sent Greeting';
      body = 'Hello to you too.';
    } else if (_mine) {
      stateKey = 'waiting';
      headline = 'Greeting sent';
      body = "We'll let you know when $name returns it.";
    } else {
      stateKey = 'send';
      headline = 'Hello';
      body = 'Send Greeting to $name to begin.';
    }
    final bool actionable = stateKey == 'send' || stateKey == 'return';
    final Widget stageAction;
    if (actionable) {
      stageAction = _JourneyRoundAction(
        label: stateKey == 'return' ? 'Return Greeting' : 'Send Greeting',
        onTap: _sending ? null : _send,
      );
    } else if (stateKey == 'complete') {
      stageAction = _JourneyScrollInvitation(
        onContinue: _continueFromSemantics,
        progress: _completionScrollDistance / _completionScrollThreshold,
        continuing: _completionCommitted,
        openingLabel: 'Opening your choices…',
      );
    } else {
      stageAction = SizedBox.shrink();
    }

    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: stateKey == 'complete' ? _startCompletionScroll : null,
      onPointerMove: stateKey == 'complete' ? _trackCompletionScroll : null,
      onPointerSignal: stateKey == 'complete'
          ? _trackCompletionScrollSignal
          : null,
      onPointerUp: stateKey == 'complete' ? _finishCompletionScroll : null,
      onPointerCancel: stateKey == 'complete' ? _finishCompletionScroll : null,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 480),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.018),
                  end: Offset.zero,
                ).animate(anim),
                child: child,
              ),
            ),
            child: Column(
              key: ValueKey(stateKey),
              mainAxisSize: MainAxisSize.min,
              children: [
                _JourneyPairStatus(
                  profile: widget.profile,
                  youComplete: _mine,
                  otherComplete: _theirs,
                  greetingGoldWake: true,
                  motionEnabled: widget.isActionVisible,
                  // A waiting portrait stays dim until THAT person sends a
                  // Greeting. The old emphasizeWaiting treatment brightened the
                  // other person as soon as this user sent, making the one-
                  // sided and completed states look almost identical.
                  youCompleteLabel: 'Greeting sent',
                  youWaitingLabel: _theirs ? 'Return Greeting' : 'Not sent',
                  otherCompleteLabel: 'Greeting received',
                  otherWaitingLabel: 'Awaiting Greeting',
                ),
                SizedBox(height: 14),
                SizedBox(
                  height: 64,
                  child: Center(
                    child: Text(
                      headline,
                      maxLines: 2,
                      style: SelahText.heading(size: 29),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                SizedBox(height: 8),
                SizedBox(
                  height: 50,
                  child: Center(
                    child: Text(
                      body,
                      maxLines: 2,
                      style: SelahText.subtext(size: 14.5),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                SizedBox(
                  height: 48,
                  child: Center(
                    child: _sendFailed && actionable
                        ? Text(
                            "Greeting wasn't sent. Check your connection and try again.",
                            style: SelahText.subtext(
                              size: 12.5,
                              color: SelahColors.destructive,
                            ),
                            textAlign: TextAlign.center,
                          )
                        : SizedBox.shrink(),
                  ),
                ),
                SizedBox(height: 130, child: Center(child: stageAction)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Stage 1's durable history keeps the completed exchange visible instead of
/// reducing two people to a generic tick. It is read-only: neither Greeting can
/// be sent again from history.
class _GreetingExchangeHistoryView extends StatelessWidget {
  final SeekerProfile profile;

  const _GreetingExchangeHistoryView({required this.profile});

  @override
  Widget build(BuildContext context) {
    final stage = SelahJourneyStages.of('greeting_exchange')!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _JourneyPairStatus(
              profile: profile,
              youComplete: true,
              otherComplete: true,
              greetingGoldWake: true,
              motionEnabled: false,
              youCompleteLabel: 'Greeting sent',
              otherCompleteLabel: 'Greeting received',
            ),
            SizedBox(height: 20),
            Text(
              stage.completionHeading,
              style: SelahText.heading(size: 27),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              stage.completionLine,
              style: SelahText.subtext(size: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// --- Journey Bio / Life Snapshot mock -------------------------------

/// Display-only Stage 3 inserted after Compatibility Reveal while the
/// Journey Bio experience is tested. It never reads private matching answers:
/// every fact below is explicit mock data controlled by the developer panel.
class _LifeSnapshotView extends StatelessWidget {
  final SeekerProfile profile;
  final bool showBio;
  final Set<String> visibleFieldIds;
  final bool mineRevealed;
  final bool theirsRevealed;
  final VoidCallback onReveal;
  final bool waitingForOther;
  final Future<void> Function() onContinue;
  final bool readOnly;

  const _LifeSnapshotView({
    required this.profile,
    required this.showBio,
    required this.visibleFieldIds,
    required this.mineRevealed,
    required this.theirsRevealed,
    required this.onReveal,
    required this.waitingForOther,
    required this.onContinue,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    final revealState = SelahJourneyLifeSnapshotRevealPolicy.resolve(
      mine: mineRevealed,
      theirs: theirsRevealed,
    );
    if (revealState != SelahJourneyLifeSnapshotRevealState.revealed) {
      final copy = switch (revealState) {
        SelahJourneyLifeSnapshotRevealState.neither => (
          'Reveal your profiles together',
          'Neither Journey profile opens until you both choose to reveal.',
        ),
        SelahJourneyLifeSnapshotRevealState.mineWaiting => (
          'Your profile is ready',
          'Waiting for ${profile.firstName}. You open each other’s profiles together.',
        ),
        SelahJourneyLifeSnapshotRevealState.theirsWaiting => (
          '${profile.firstName} is ready',
          'Reveal yours to open both Journey profiles.',
        ),
        SelahJourneyLifeSnapshotRevealState.revealed => throw StateError(
          'Handled above',
        ),
      };
      final headline = copy.$1;
      final body = copy.$2;
      final canReveal = SelahJourneyLifeSnapshotRevealPolicy.canRevealMine(
        mine: mineRevealed,
      );
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _JourneyPairStatus(
                profile: profile,
                youComplete: mineRevealed,
                otherComplete: theirsRevealed,
                youCompleteLabel: 'Profile revealed',
                youWaitingLabel: 'Not revealed',
                otherCompleteLabel: 'Profile revealed',
                otherWaitingLabel: 'Awaiting reveal',
              ),
              SizedBox(height: 20),
              Icon(
                Icons.visibility_outlined,
                size: 27,
                color: SelahColors.journeyGold.withValues(alpha: 0.84),
              ),
              SizedBox(height: 12),
              Text(
                headline,
                style: SelahText.heading(size: 23),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                body,
                style: SelahText.subtext(size: 13.5),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 34),
              if (canReveal)
                _JourneyRoundAction(
                  label: 'Reveal Profile',
                  icon: Icons.visibility_outlined,
                  onTap: onReveal,
                )
              else
                Text(
                  'Profile revealed · waiting together',
                  style: SelahText.subtext(
                    size: 12,
                    color: SelahColors.journeyGold.withValues(alpha: 0.7),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    final visibleFields = SelahJourneyLifeSnapshotMock.fields
        .where((field) => visibleFieldIds.contains(field.id))
        .toList(growable: false);
    final sections = <String, List<SelahJourneyLifeSnapshotField>>{};
    for (final field in visibleFields) {
      sections.putIfAbsent(field.section, () => []).add(field);
    }
    final hasAnything = showBio || visibleFields.isNotEmpty;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 38),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            Icons.visibility_outlined,
            size: 24,
            color: SelahColors.journeyGold.withValues(alpha: 0.8),
          ),
          SizedBox(height: 7),
          Text(
            'Profiles revealed',
            style: SelahText.heading(size: 18),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 4),
          Text(
            'You both chose to open this part of the Journey.',
            style: SelahText.subtext(size: 12.5),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 22),
          Center(
            child: Container(
              width: 92,
              height: 92,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: SelahColors.journeyGold, width: 1.5),
              ),
              child: ClipOval(
                child: profile.photoUrl.isEmpty
                    ? ColoredBox(
                        color: SelahColors.luxuryDarkPurple,
                        child: Center(
                          child: Text(
                            profile.firstName.isEmpty
                                ? '·'
                                : profile.firstName[0].toUpperCase(),
                            style: SelahText.heading(size: 28),
                          ),
                        ),
                      )
                    : SelahProfileImage(
                        profile.photoUrl,
                        width: 86,
                        height: 86,
                      ),
              ),
            ),
          ),
          SizedBox(height: 14),
          Text(
            profile.firstName,
            style: SelahText.heading(size: 24),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 5),
          Text(
            'SHARED FOR THIS JOURNEY',
            style: SelahText.chapterLabel(
              color: SelahColors.journeyGold.withValues(alpha: 0.82),
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 28),
          if (showBio) ...[
            _LifeSnapshotSectionHeading(label: 'BIO'),
            SizedBox(height: 9),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: _lifeSnapshotCardDecoration(),
              child: Text(
                SelahJourneyLifeSnapshotMock.bio,
                style: SelahText.body(
                  size: 14.5,
                  color: SelahColors.foreground.withValues(alpha: 0.9),
                ),
              ),
            ),
            SizedBox(height: 24),
          ],
          for (final entry in sections.entries) ...[
            _LifeSnapshotSectionHeading(label: entry.key.toUpperCase()),
            SizedBox(height: 9),
            Container(
              decoration: _lifeSnapshotCardDecoration(),
              child: Column(
                children: [
                  for (var index = 0; index < entry.value.length; index++) ...[
                    _LifeSnapshotFactRow(field: entry.value[index]),
                    if (index < entry.value.length - 1)
                      Divider(
                        height: 1,
                        indent: 16,
                        endIndent: 16,
                        color: SelahColors.foreground.withValues(alpha: 0.1),
                      ),
                  ],
                ],
              ),
            ),
            SizedBox(height: 24),
          ],
          if (!hasAnything)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 30),
              decoration: _lifeSnapshotCardDecoration(),
              child: Column(
                children: [
                  Icon(
                    Icons.notes_rounded,
                    size: 30,
                    color: SelahColors.foreground.withValues(alpha: 0.52),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'No Journey bio added',
                    style: SelahText.heading(size: 18),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 7),
                  Text(
                    'A biography and these life details are optional. '
                    '${profile.firstName} chose not to add them.',
                    style: SelahText.subtext(size: 13),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          Container(
            margin: const EdgeInsets.only(top: 2),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  size: 15,
                  color: SelahColors.foreground.withValues(alpha: 0.48),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Only what ${profile.firstName} chose to share for this '
                    'Active Journey appears here. Private matching answers '
                    'stay private.',
                    style: SelahText.subtext(
                      size: 11.5,
                      color: SelahColors.foreground.withValues(alpha: 0.54),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 18),
          if (readOnly)
            SizedBox(height: 12)
          else if (waitingForOther)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'You chose to continue. Waiting for ${profile.firstName}.',
                style: SelahText.subtext(size: 13.5),
                textAlign: TextAlign.center,
              ),
            )
          else
            _JourneyScrollToContinue(
              onContinue: onContinue,
              idleLabel: 'Continue',
              openingLabel: 'Opening your choices…',
            ),
        ],
      ),
    );
  }
}

BoxDecoration _lifeSnapshotCardDecoration() => BoxDecoration(
  color: SelahColors.foreground.withValues(alpha: 0.065),
  borderRadius: BorderRadius.circular(16),
  border: Border.all(
    color: SelahColors.foreground.withValues(alpha: 0.13),
    width: 0.7,
  ),
);

class _LifeSnapshotSectionHeading extends StatelessWidget {
  final String label;

  const _LifeSnapshotSectionHeading({required this.label});

  @override
  Widget build(BuildContext context) =>
      Text(label, style: SelahText.chapterLabel(color: SelahColors.ink(0.54)));
}

class _LifeSnapshotFactRow extends StatelessWidget {
  final SelahJourneyLifeSnapshotField field;

  const _LifeSnapshotFactRow({required this.field});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 4,
          child: Text(
            field.label,
            style: SelahText.subtext(
              size: 12,
              color: SelahColors.foreground.withValues(alpha: 0.58),
            ),
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          flex: 5,
          child: Text(
            field.value,
            style: SelahText.body(
              size: 12.5,
              color: SelahColors.foreground.withValues(alpha: 0.9),
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    ),
  );
}

// --- Phase 1/2/3 -------------------------------------------------------

class _PhaseView extends StatefulWidget {
  final String matchId;
  final SeekerProfile profile;
  final int phase;
  final bool isActionVisible;
  final VoidCallback onAdvance;
  final Future<void> Function(Future<void> Function()) onRequestDecision;
  const _PhaseView({
    required this.matchId,
    required this.profile,
    required this.phase,
    required this.isActionVisible,
    required this.onAdvance,
    required this.onRequestDecision,
  });

  @override
  State<_PhaseView> createState() => _PhaseViewState();
}

class _PhaseViewState extends State<_PhaseView> {
  late final List<JourneyQuestion> _questions = JourneyQuestions.forPhase(
    widget.phase,
  );
  final Map<String, TextEditingController> _controllers = {};
  Map<String, Map<String, String>> _allAnswers = {};
  Map<String, String> _checkpoints = {};

  /// This Seeker's OWN private ratings, questionId -> rating. Read from the
  /// server on load and kept in step locally as they tap, because from
  /// 2026-08-11 they are no longer write-only: they select the reflection,
  /// drive the SELAH Recommendation under it, and on SELAH One they decide
  /// which follow-ups are offered. A rating that vanished on rebuild used to
  /// be invisible; now it would look broken.
  Map<String, String> _ratings = {};
  bool _submitted = false;
  bool _loading = true;
  Timer? _poll;
  bool _pollLoadBusy = false;
  Future<void>? _loadFlight;

  // ── Authoring flow state: one question per screen, then review-and-seal.
  // The shared stage scroll shell now owns the introduction, so this view
  // starts directly at the first real question. Drafts remain local until
  // 'Seal my answers'.
  int _qIndex = 0;
  bool _reviewing = false;

  @override
  void initState() {
    super.initState();
    for (final q in _questions) {
      _controllers[q.id] = TextEditingController();
    }
    _load();
    _poll = Timer.periodic(const Duration(seconds: 8), (_) => _pollLoad());
  }

  @override
  void didUpdateWidget(covariant _PhaseView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isActionVisible && widget.isActionVisible) {
      unawaited(_load(showSpinner: false));
    }
  }

  Future<void> _pollLoad() async {
    if (_pollLoadBusy ||
        !_journeyViewCanPoll(context) ||
        !widget.isActionVisible) {
      return;
    }
    _pollLoadBusy = true;
    try {
      await _load(showSpinner: false);
    } finally {
      _pollLoadBusy = false;
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load({bool showSpinner = true}) async {
    final active = _loadFlight;
    if (active != null) return active;
    final next = _loadOnce(showSpinner: showSpinner);
    _loadFlight = next;
    try {
      await next;
    } finally {
      if (identical(_loadFlight, next)) _loadFlight = null;
    }
  }

  Future<void> _loadOnce({required bool showSpinner}) async {
    if (showSpinner && mounted) setState(() => _loading = true);
    final answers = await SelahJourneyService.fetchPhaseAnswers(
      widget.matchId,
      widget.phase,
    );
    final checkpoints = await SelahJourneyService.fetchCheckpoints(
      widget.matchId,
      widget.phase,
    );
    final ratings = await SelahJourneyService.fetchMyRatings(
      widget.matchId,
      widget.phase,
    );
    if (!mounted) return;
    final myId = SelahAuth.currentUser?.id;
    setState(() {
      _allAnswers = answers;
      _checkpoints = checkpoints;
      _ratings = ratings;
      _submitted =
          myId != null && (answers[myId]?.length ?? 0) >= _questions.length;
      _loading = false;
    });

    if (_bothSubmitted &&
        myId != null &&
        checkpoints[myId] != null &&
        checkpoints.length >= 2) {
      widget.onAdvance();
    }
  }

  bool get _bothSubmitted {
    if (_questions.isEmpty) return false;
    return _allAnswers.values
            .where((a) => a.length >= _questions.length)
            .length >=
        2;
  }

  // ── THE SELAH LAYER. Null on SELAH Basic, always — see
  // data/selah_journey_intelligence.dart. Getters rather than fields so they
  // recompute the moment a reflection choice is tapped, which is the point:
  // the recommendation under the answers should change as you mark them.
  SelahIntelligence? get _followUps => SelahJourneyIntelligence.phaseFollowUps(
    plan: AppState.instance.plan,
    questions: _questions,
    ratings: _ratings,
    otherName: widget.profile.firstName,
  );

  SelahIntelligence? get _checkpointAdvice =>
      SelahJourneyIntelligence.phaseCheckpoint(
        plan: AppState.instance.plan,
        questions: _questions,
        ratings: _ratings,
      );

  SelahIntelligence? get _summary => SelahJourneyIntelligence.phaseSummary(
    plan: AppState.instance.plan,
    phaseLabel: SelahJourneyStages.phase(widget.phase)?.label ?? 'this phase',
    questions: _questions,
    ratings: _ratings,
    otherName: widget.profile.firstName,
  );

  Future<void> _submitAll() async {
    final userId = SelahAuth.currentUser?.id;
    if (userId == null) return;
    final generation = SelahAccountState.generation;
    bool isCurrentSubmission() =>
        mounted &&
        SelahAuth.currentUser?.id == userId &&
        SelahAccountState.isCurrent(userId, generation);

    var allSaved = true;
    for (var index = 0; index < _questions.length; index++) {
      if (!isCurrentSubmission()) return;
      final q = _questions[index];
      final text = _controllers[q.id]!.text.trim();
      if (!JourneyQuestions.answerFitsCharacterLimit(widget.phase, text)) {
        if (!mounted) return;
        setState(() {
          _reviewing = false;
          _qIndex = index;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Each Faith & Values answer can be up to 400 characters.',
            ),
          ),
        );
        return;
      }
      if (text.isNotEmpty) {
        final saved = await SelahJourneyService.submitPhaseAnswer(
          widget.matchId,
          widget.phase,
          q.id,
          text,
        );
        if (!isCurrentSubmission()) return;
        if (!saved) allSaved = false;
      }
    }
    if (!isCurrentSubmission()) return;
    if (!allSaved && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Some answers didn't save — check your connection and submit again.",
          ),
        ),
      );
    }
    await _load();
  }

  Future<void> _rate(String questionId, String rating) async {
    // Optimistic, then written. The signal has to select instantly — this is a
    // private note to yourself, and waiting on a round-trip to see it land
    // reads as the tap having missed.
    final previous = _ratings[questionId];
    setState(() => _ratings[questionId] = rating);
    final saved = await SelahJourneyService.submitRating(
      widget.matchId,
      widget.phase,
      questionId,
      rating,
    );
    if (!saved && mounted) {
      setState(() {
        if (previous == null) {
          _ratings.remove(questionId);
        } else {
          _ratings[questionId] = previous;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("That reflection didn't save — please try again."),
        ),
      );
    }
  }

  Future<void> _checkpoint(String decision) async {
    final saved = await SelahJourneyService.submitCheckpoint(
      widget.matchId,
      widget.phase,
      decision,
    );
    await _load();
    if (!saved && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Your choice didn't save — please try again."),
        ),
      );
    }
  }

  // _phaseGuidingQuestion REMOVED 2026-08-09 — the three questions now
  // live on SelahJourneyStage.guidingQuestion in
  // data/selah_journey_stages.dart, beside the labels that were derived
  // from them. Keeping them apart meant the heading and the question
  // under it could be edited independently and end up describing
  // different things.
  //
  // Same copy, moved — not rewritten.

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SelahLoading();

    final myId = SelahAuth.currentUser?.id;
    final otherId = widget.profile.id;
    final myAnswers = myId == null
        ? const <String, String>{}
        : (_allAnswers[myId] ?? const {});
    final theirAnswers = _allAnswers[otherId] ?? const {};

    if (_bothSubmitted) {
      final myCheckpoint = myId == null ? null : _checkpoints[myId];
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // The label still comes from the map, never a literal here.
            Text(
              (SelahJourneyStages.phase(widget.phase)?.label ??
                      'Phase ${widget.phase}')
                  .toUpperCase(),
              style: SelahText.chapterLabel(color: SelahColors.ink(0.54)),
            ),
            SizedBox(height: 4),
            Text(
              'Your answers, opened together',
              style: SelahText.heading(size: 18),
            ),
            SizedBox(height: 4),
            Text(
              'Read slowly — there is no clock on this stage.',
              style: SelahText.subtext(),
            ),
            SizedBox(height: 20),
            for (var index = 0; index < _questions.length; index++)
              _JourneyRevealedQuestion(
                question: _questions[index],
                questionNumber: index + 1,
                questionCount: _questions.length,
                myAnswer: myAnswers[_questions[index].id] ?? '—',
                theirAnswer: theirAnswers[_questions[index].id] ?? '—',
                otherName: widget.profile.firstName,
                rating: _ratings[_questions[index].id],
                onRate: (rating) => _rate(_questions[index].id, rating),
              ),
            // The privacy line the spec asks for on every phase. It sits
            // directly under the ratings it is about, not in a footer.
            SizedBox(height: 4),
            Text(
              'Your answers are shared with ${widget.profile.firstName} and '
              'your Shepherd. Your ratings are private and used only to guide '
              'your journey.',
              style: SelahText.privacyText(),
            ),
            SizedBox(height: 8),
            if (_summary != null)
              SelahIntelligenceCard(intelligence: _summary!),
            if (_followUps != null)
              SelahIntelligenceCard(intelligence: _followUps!),
            if (_checkpointAdvice != null)
              SelahIntelligenceCard(intelligence: _checkpointAdvice!)
            else if (AppState.instance.plan != SelahPlan.one)
              const SelahIntelligenceInvitation(
                kind: SelahIntelligenceKind.recommendation,
              ),
            if (myCheckpoint == null) ...[
              Text(
                'Close this chapter together?',
                style: SelahText.heading(size: 15),
              ),
              SizedBox(height: 4),
              Text(
                'What you shared here stays on your Timeline. '
                '${_nextChapterLabel != null ? '${_nextChapterLabel!} is next.' : ''}',
                style: SelahText.subtext(),
              ),
              SizedBox(height: 10),
              _JourneyScrollToContinue(
                onContinue: () =>
                    widget.onRequestDecision(() => _checkpoint('continue')),
                openingLabel: 'Opening your choices…',
              ),
            ] else
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      SelahJourneyStages.phase(widget.phase)!.completionHeading,
                      style: SelahText.heading(size: 17),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 5),
                    Text(
                      SelahJourneyStages.phase(widget.phase)!.completionLine,
                      style: SelahText.subtext(),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Waiting for ${widget.profile.firstName} to close it too.',
                      style: SelahText.subtext(
                        size: 12.5,
                        color: SelahColors.ink(0.60),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
    }

    if (_submitted) {
      // THE ENVELOPE, NAMED — 2026-08-12. The mechanic was always this
      // (neither sees anything until both have finished); the old copy
      // narrated it as a queue. No spinner: the system is not loading, a
      // person is writing. The wait offers something worthy of the time —
      // your own answers, to read once more.
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 48, 28, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${widget.profile.firstName} is still writing',
              style: SelahText.heading(size: 18),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              'Your answers are sealed until ${widget.profile.firstName} '
              'finishes — you open them together. There is no clock on this.',
              style: SelahText.subtext(),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24),
            _SealedAnswers(questions: _questions, answers: myAnswers),
          ],
        ),
      );
    }

    // One question per screen, then review-and-seal. The shared scroll shell
    // above this view has already provided the chapter's arrival and meaning.
    final chapterLabel =
        SelahJourneyStages.phase(widget.phase)?.label ??
        'Phase ${widget.phase}';

    if (_reviewing) {
      final missing = _questions
          .where((q) => _controllers[q.id]!.text.trim().isEmpty)
          .length;
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Read yours once more', style: SelahText.heading(size: 18)),
            SizedBox(height: 4),
            Text(
              'Sealed answers wait for ${widget.profile.firstName}. Tap one '
              'to change it.',
              style: SelahText.subtext(),
            ),
            SizedBox(height: 16),
            for (var i = 0; i < _questions.length; i++) ...[
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => setState(() {
                  _reviewing = false;
                  _qIndex = i;
                }),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: SelahColors.foreground.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: SelahColors.foreground.withValues(alpha: 0.10),
                      width: 0.5,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _questions[i].text,
                        style: SelahText.subtext(size: 11.5),
                      ),
                      SizedBox(height: 4),
                      Text(
                        _controllers[_questions[i].id]!.text.trim().isEmpty
                            ? 'Not answered yet'
                            : _controllers[_questions[i].id]!.text.trim(),
                        style: SelahText.body(
                          size: 13.5,
                          color:
                              _controllers[_questions[i].id]!.text
                                  .trim()
                                  .isEmpty
                              ? SelahColors.ink(0.38)
                              : Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 10),
            ],
            SizedBox(height: 8),
            Center(
              child: _JourneyRoundAction(
                label: missing == 0
                    ? 'Seal my answers'
                    : '$missing still to answer',
                icon: Icons.lock_outline,
                onTap: missing == 0 ? _submitAll : null,
              ),
            ),
          ],
        ),
      );
    }

    final q = _questions[_qIndex];
    final answerCharacterLimit = JourneyQuestions.answerCharacterLimitForPhase(
      widget.phase,
    );
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  chapterLabel.toUpperCase(),
                  style: SelahText.chapterLabel(color: SelahColors.ink(0.54)),
                ),
              ),
              Text(
                'Question ${_qIndex + 1} of ${_questions.length}',
                style: SelahText.subtext(
                  size: 11,
                  color: SelahColors.ink(0.38),
                ),
              ),
            ],
          ),
          if (_qIndex == 0) ...[
            SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                color: SelahColors.foreground.withValues(alpha: 0.045),
                border: const Border(
                  left: BorderSide(color: SelahColors.journeyGold, width: 2),
                ),
              ),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: 'You are answering privately. ',
                      style: SelahText.subtext(
                        size: 11.5,
                        color: SelahColors.journeyGold,
                      ),
                    ),
                    TextSpan(
                      text:
                          'After all ${_questions.length}, you can review every answer before sealing. When you both seal, the answers open to both of you and your Shepherds.',
                      style: SelahText.subtext(
                        size: 11.5,
                        color: SelahColors.foreground.withValues(alpha: 0.66),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          SizedBox(height: 18),
          Text(q.text, style: SelahText.heading(size: 17)),
          SizedBox(height: 14),
          TextField(
            controller: _controllers[q.id],
            maxLines: 5,
            maxLength: answerCharacterLimit,
            maxLengthEnforcement: MaxLengthEnforcement.enforced,
            buildCounter: answerCharacterLimit == null
                ? null
                : (
                    context, {
                    required currentLength,
                    required isFocused,
                    required maxLength,
                  }) => Text(
                    '$currentLength / $maxLength',
                    style: SelahText.subtext(
                      size: 11,
                      color:
                          currentLength >= (answerCharacterLimit * 0.9).round()
                          ? SelahColors.journeyGold
                          : SelahColors.ink(0.38),
                    ),
                  ),
            style: TextStyle(color: Colors.white),
            decoration: InputDecoration(
              filled: true,
              fillColor: SelahColors.foreground.withValues(alpha: 0.06),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              hintText: 'In your own words…',
              hintStyle: TextStyle(color: SelahColors.ink(0.38)),
              counterStyle: SelahText.subtext(
                size: 11,
                color: SelahColors.ink(0.38),
              ),
            ),
          ),
          SizedBox(height: 16),
          Row(
            children: [
              if (_qIndex > 0) ...[
                OutlinedButton(
                  onPressed: () => setState(() => _qIndex -= 1),
                  child: Text('Back', style: SelahText.button(size: 13)),
                ),
                SizedBox(width: 10),
              ],
              Expanded(
                child: Center(
                  child: _FrostPill(
                    label: _qIndex < _questions.length - 1
                        ? 'Next · Question ${_qIndex + 2} of ${_questions.length}'
                        : 'Review my answers',
                    onTap: () => setState(() {
                      if (_qIndex < _questions.length - 1) {
                        _qIndex += 1;
                      } else {
                        _reviewing = true;
                      }
                    }),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// The chapter after this one, for the seal copy. Null past the map's end.
  String? get _nextChapterLabel {
    final me = SelahJourneyStages.phase(widget.phase);
    if (me == null || me.order >= SelahJourneyStages.all.length) return null;
    return SelahJourneyStages.all[me.order].label;
  }
}

/// Your own sealed answers, rereadable while the other person writes.
class _SealedAnswers extends StatefulWidget {
  final List<JourneyQuestion> questions;
  final Map<String, String> answers;
  const _SealedAnswers({required this.questions, required this.answers});

  @override
  State<_SealedAnswers> createState() => _SealedAnswersState();
}

class _SealedAnswersState extends State<_SealedAnswers> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton(
          onPressed: () => setState(() => _open = !_open),
          child: Text(
            _open ? 'Hide your answers' : 'Read your answers again',
            style: SelahText.button(size: 13),
          ),
        ),
        if (_open) ...[
          SizedBox(height: 14),
          for (final q in widget.questions) ...[
            Text(q.text, style: SelahText.subtext(size: 11.5)),
            SizedBox(height: 4),
            Text(
              widget.answers[q.id] ?? '—',
              style: SelahText.body(size: 13.5),
            ),
            SizedBox(height: 14),
          ],
        ],
      ],
    );
  }
}

class _JourneyRevealedQuestion extends StatelessWidget {
  final JourneyQuestion question;
  final int questionNumber;
  final int questionCount;
  final String myAnswer;
  final String theirAnswer;
  final String otherName;
  final String? rating;
  final ValueChanged<String> onRate;

  const _JourneyRevealedQuestion({
    required this.question,
    required this.questionNumber,
    required this.questionCount,
    required this.myAnswer,
    required this.theirAnswer,
    required this.otherName,
    required this.rating,
    required this.onRate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: SelahColors.foreground.withValues(alpha: 0.12),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'QUESTION $questionNumber OF $questionCount',
            style: SelahText.chapterLabel(
              color: SelahColors.journeyGold.withValues(alpha: 0.9),
            ),
          ),
          SizedBox(height: 9),
          Text(question.text, style: SelahText.heading(size: 16)),
          SizedBox(height: 16),
          _JourneyRevealedAnswerRow(label: 'YOU', answer: myAnswer),
          SizedBox(height: 11),
          _JourneyRevealedAnswerRow(
            label: otherName.toUpperCase(),
            answer: theirAnswer,
          ),
          SizedBox(height: 19),
          Text(
            'YOUR PRIVATE REFLECTION',
            style: SelahText.chapterLabel(
              color: SelahColors.foreground.withValues(alpha: 0.44),
            ),
          ),
          SizedBox(height: 10),
          _TrafficLightRatingScale(selected: rating, onSelected: onRate),
        ],
      ),
    );
  }
}

class _JourneyRevealedAnswerRow extends StatelessWidget {
  final String label;
  final String answer;

  const _JourneyRevealedAnswerRow({required this.label, required this.answer});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 54,
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: SelahText.chapterLabel(
                color: SelahColors.foreground.withValues(alpha: 0.46),
              ),
            ),
          ),
        ),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            answer,
            style: SelahText.body(
              size: 13.5,
              color: SelahColors.foreground.withValues(alpha: 0.86),
            ),
          ),
        ),
      ],
    );
  }
}

class _TrafficLightRatingOption {
  final String value;
  final String label;
  final Color color;

  const _TrafficLightRatingOption({
    required this.value,
    required this.label,
    required this.color,
  });
}

class _TrafficLightRatingScale extends StatelessWidget {
  static const _options = [
    _TrafficLightRatingOption(
      value: 'reassured',
      label: 'Reassured me',
      color: SelahColors.positiveGreen,
    ),
    _TrafficLightRatingOption(
      value: 'discuss_further',
      label: 'Discuss further',
      color: SelahColors.journeyGold,
    ),
    _TrafficLightRatingOption(
      value: 'concerns',
      label: 'Concerns me',
      color: SelahColors.negativeRed,
    ),
  ];

  final String? selected;
  final ValueChanged<String> onSelected;

  const _TrafficLightRatingScale({
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Stack(
        children: [
          Positioned(
            top: 13.5,
            left: 0,
            right: 0,
            child: Row(
              children: [
                const Spacer(),
                Expanded(
                  flex: 4,
                  child: Container(
                    height: 1,
                    color: SelahColors.foreground.withValues(alpha: 0.2),
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final option in _options)
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: selected == option.value,
                    label: option.label,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => onSelected(option.value),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(4, 0, 4, 7),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 160),
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: option.color.withValues(
                                    alpha: selected == option.value ? 1 : 0.6,
                                  ),
                                  border: selected == option.value
                                      ? Border.all(
                                          color: SelahColors.foreground
                                              .withValues(alpha: 0.88),
                                          width: 2,
                                        )
                                      : Border.all(
                                          color: SelahColors.luxuryDarkPurple,
                                          width: 4,
                                        ),
                                  boxShadow: selected == option.value
                                      ? [
                                          BoxShadow(
                                            color: option.color.withValues(
                                              alpha: 0.3,
                                            ),
                                            blurRadius: 10,
                                            spreadRadius: 3,
                                          ),
                                        ]
                                      : null,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                option.label,
                                style: SelahText.subtext(
                                  size: 10.5,
                                  color: selected == option.value
                                      ? Colors.white
                                      : SelahColors.foreground.withValues(
                                          alpha: 0.68,
                                        ),
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// --- Family Compatibility Stage ---------------------------------------

class _FamilyStageView extends StatefulWidget {
  final String matchId;
  final SeekerProfile profile;
  final bool isActionVisible;
  final Future<void> Function() onAdvance;
  final Future<void> Function(Future<void> Function()) onRequestDecision;
  const _FamilyStageView({
    required this.matchId,
    required this.profile,
    required this.isActionVisible,
    required this.onAdvance,
    required this.onRequestDecision,
  });

  @override
  State<_FamilyStageView> createState() => _FamilyStageViewState();
}

class _FamilyStageViewState extends State<_FamilyStageView> {
  final Map<String, TextEditingController> _controllers = {};
  bool _loading = true;
  bool _submitted = false;
  bool _mentorAnswered = false;
  Timer? _poll;
  bool _pollLoadBusy = false;
  Future<void>? _loadFlight;

  /// Ratings from ALL THREE phases, because the summary the Shepherd is given
  /// is about the Journey, not about this stage.
  Map<String, String> _ratings = {};

  @override
  void initState() {
    super.initState();
    for (final q in JourneyQuestions.mentorToSeeker) {
      _controllers[q.id] = TextEditingController();
    }
    _load();
    // Polls for the Mentor's answers so this screen advances the moment
    // both sides are done, without the Seeker needing to reopen it.
    _poll = Timer.periodic(const Duration(seconds: 8), (_) => _pollLoad());
  }

  @override
  void didUpdateWidget(covariant _FamilyStageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isActionVisible && widget.isActionVisible) {
      unawaited(_load(showSpinner: false));
    }
  }

  Future<void> _pollLoad() async {
    if (_pollLoadBusy ||
        !_journeyViewCanPoll(context) ||
        !widget.isActionVisible) {
      return;
    }
    _pollLoadBusy = true;
    try {
      await _load(showSpinner: false);
    } finally {
      _pollLoadBusy = false;
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load({bool showSpinner = true}) async {
    final active = _loadFlight;
    if (active != null) return active;
    final next = _loadOnce(showSpinner: showSpinner);
    _loadFlight = next;
    try {
      await next;
    } finally {
      if (identical(_loadFlight, next)) _loadFlight = null;
    }
  }

  Future<void> _loadOnce({required bool showSpinner}) async {
    final userId = SelahAuth.currentUser?.id;
    if (userId == null) return;
    final generation = SelahAccountState.generation;
    bool isCurrentLoad() =>
        mounted &&
        SelahAuth.currentUser?.id == userId &&
        SelahAccountState.isCurrent(userId, generation);

    if (!isCurrentLoad()) return;
    if (showSpinner && mounted) setState(() => _loading = true);
    final myAnswers = await SelahJourneyService.fetchFamilyAnswers(
      widget.matchId,
      'mentor_to_seeker',
    );
    if (!isCurrentLoad()) return;
    final mentorAnswers = await SelahJourneyService.fetchFamilyAnswers(
      widget.matchId,
      'seeker_to_mentor',
    );
    if (!isCurrentLoad()) return;
    final ratings = await SelahJourneyService.fetchAllMyRatings(widget.matchId);
    if (!isCurrentLoad()) return;
    final submitted =
        myAnswers.length >= JourneyQuestions.mentorToSeeker.length;
    final mentorAnswered =
        mentorAnswers.length >= JourneyQuestions.seekerToMentor.length;
    setState(() {
      _submitted = submitted;
      _mentorAnswered = mentorAnswered;
      _ratings = ratings;
      _loading = false;
    });
    // BOTH sides must answer before Conversation (Founder, 2026-07-26) —
    // the Shepherd's participation is real, not cosmetic. The AUTO-advance
    // that used to fire here is GONE (2026-08-12, experience redesign):
    // "Both families have spoken with you both" is plausibly the most
    // reassuring sentence this app ever shows, and it replaced itself in
    // under a second. The build now HOLDS that state until the couple
    // continues by choice.
  }

  Future<void> _submit() async {
    final userId = SelahAuth.currentUser?.id;
    if (userId == null) return;
    final generation = SelahAccountState.generation;
    bool isCurrentSubmission() =>
        mounted &&
        SelahAuth.currentUser?.id == userId &&
        SelahAccountState.isCurrent(userId, generation);

    // BUG-03 (2026-08-14 audit, inherited upstream action 225 — fixed 2026-08-15):
    // submitFamilyAnswer reports failure now, and this surfaces it. The
    // text stays in the controllers either way, and _load() keeps
    // deriving _submitted from what the SERVER holds — so a failed
    // write can no longer masquerade as a submitted state, and pressing
    // Submit again re-sends safely (duplicate rows are tolerated by
    // fetchFamilyAnswers' later-insert-wins ordering).
    var allSaved = true;
    for (final q in JourneyQuestions.mentorToSeeker) {
      if (!isCurrentSubmission()) return;
      final text = _controllers[q.id]!.text.trim();
      if (text.isNotEmpty) {
        final ok = await SelahJourneyService.submitFamilyAnswer(
          widget.matchId,
          'mentor_to_seeker',
          q.id,
          text,
        );
        if (!isCurrentSubmission()) return;
        if (!ok) allSaved = false;
      }
    }
    if (!isCurrentSubmission()) return;
    if (!allSaved && mounted) {
      showSelahFamilyAnswersWriteFailure(context);
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SelahLoading();
    final stage = SelahJourneyStages.of('family_stage')!;

    if (_submitted) {
      final shepherdSummary = SelahJourneyIntelligence.shepherdSummary(
        plan: AppState.instance.plan,
        otherName: widget.profile.firstName,
        ratings: _ratings,
        questions: [
          ...JourneyQuestions.phase1,
          ...JourneyQuestions.phase2,
          ...JourneyQuestions.phase3,
        ],
      );
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _mentorAnswered
                    ? stage.completionHeading
                    : 'Your Shepherd is answering',
                style: SelahText.heading(size: 18),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                _mentorAnswered
                    ? stage.completionLine
                    : "You've answered ${widget.profile.firstName}'s family. "
                          'Your Journey continues once your own Shepherd has '
                          'answered theirs — families are not hurried here.',
                style: SelahText.subtext(),
                textAlign: TextAlign.center,
              ),
              if (shepherdSummary != null)
                SelahIntelligenceCard(intelligence: shepherdSummary)
              else
                const SelahIntelligenceInvitation(
                  kind: SelahIntelligenceKind.summary,
                ),
              if (_mentorAnswered) ...[
                SizedBox(height: 20),
                _JourneyScrollToContinue(
                  onContinue: () => widget.onRequestDecision(widget.onAdvance),
                  openingLabel: 'Opening your choices…',
                ),
              ],
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            SelahJourneyStages.labelFor('family_stage'),
            style: SelahText.heading(size: 18),
          ),
          SizedBox(height: 6),
          Text(
            'Your families meet your Journey here. '
            "${widget.profile.firstName}'s Shepherd asks you their questions; "
            'yours asks theirs. Answer as if they were sitting across from '
            'you — they are.',
            style: SelahText.subtext(),
          ),
          SizedBox(height: 18),
          Text(
            "${widget.profile.firstName}'s family asks:",
            style: SelahText.body(size: 13, color: SelahColors.ink(0.70)),
          ),
          SizedBox(height: 10),
          for (final q in JourneyQuestions.mentorToSeeker) ...[
            Text(q.text, style: SelahText.body(size: 14)),
            SizedBox(height: 6),
            TextField(
              controller: _controllers[q.id],
              maxLines: 3,
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: SelahColors.foreground.withValues(alpha: 0.06),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                hintText: 'Your answer…',
                hintStyle: TextStyle(color: SelahColors.ink(0.38)),
              ),
            ),
            SizedBox(height: 16),
          ],
          SizedBox(
            width: double.infinity,
            child: Center(
              child: _JourneyRoundAction(
                label: 'Share my answers',
                icon: Icons.send_outlined,
                onTap: _submit,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- Open Conversation ------------------------------------------------
//
// The eighth and final stage. Added 2026-08-11; before this the case simply
// pushed ChatScreen and the stage had no screen of its own.
//
// It is a threshold, not a reward. "This is NOT the reward at the end of a
// checklist. The structured journey continues — it simply becomes less rigid
// and more open" (PRE-JOURNEY RITUAL/Summary.md), and JOURNEY PHILOSOPHY §2
// says the same in stronger words. So this screen marks the change, hands
// over what was left open along the way, and then gets out of the road.
class _OpenConversationView extends StatefulWidget {
  final String matchId;
  final SeekerProfile profile;
  const _OpenConversationView({required this.matchId, required this.profile});

  @override
  State<_OpenConversationView> createState() => _OpenConversationViewState();
}

class _OpenConversationViewState extends State<_OpenConversationView> {
  SelahIntelligence? _topics;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final ratings = await SelahJourneyService.fetchAllMyRatings(widget.matchId);
    if (!mounted) return;
    setState(() {
      _topics = SelahJourneyIntelligence.conversationTopics(
        plan: AppState.instance.plan,
        ratings: ratings,
        otherName: widget.profile.firstName,
      );
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SelahLoading();
    final name = widget.profile.firstName;
    final stage = SelahJourneyStages.of('conversation')!;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 20, 28, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              stage.completionHeading,
              style: SelahText.heading(size: 22),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 10),
            Text(
              '${stage.completionLine} Your Timeline keeps going, and your '
              'Shepherds remain part of it.',
              style: SelahText.subtext(),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 14),
            // THE EARNED ARRIVAL — 2026-08-12 (experience redesign §7).
            // Not a badge and not a number: the accurate list of what they
            // actually did to be standing here.
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: SelahColors.foreground.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: SelahColors.foreground.withValues(alpha: 0.14),
                  width: 0.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final line in const [
                    'Three chapters, written and sealed together.',
                    'Both families, present and heard.',
                    'Every step, chosen twice.',
                  ])
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          Icon(
                            Icons.check,
                            size: 14,
                            color: SelahColors.foreground.withValues(
                              alpha: 0.6,
                            ),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(line, style: SelahText.body(size: 13)),
                          ),
                        ],
                      ),
                    ),
                  SizedBox(height: 4),
                  Text(
                    'You have earned this conversation.',
                    style: SelahText.subtext(size: 12),
                  ),
                ],
              ),
            ),
            SizedBox(height: 6),
            if (_topics != null)
              SelahIntelligenceCard(intelligence: _topics!)
            else if (AppState.instance.plan != SelahPlan.one)
              const SelahIntelligenceInvitation(
                kind: SelahIntelligenceKind.recommendation,
              ),
            SizedBox(height: 14),
            Center(
              child: _JourneyRoundAction(
                label: 'Open your conversation with $name',
                icon: Icons.forum_outlined,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ChatScreen(withProfile: widget.profile),
                  ),
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      JourneyTimelineScreen(withProfile: widget.profile),
                ),
              ),
              child: Text(
                'Read your story so far',
                style: SelahText.subtext(
                  size: 12.5,
                  color: SelahColors.ink(0.70),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
