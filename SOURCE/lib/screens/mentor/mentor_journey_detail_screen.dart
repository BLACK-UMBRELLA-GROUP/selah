// Shepherd-facing Journey detail. Shepherd Free can view the linked Seeker's
// Journey and Timeline only. SELAH One — Shepherd also receives the existing
// read-only Conversation and Family Stage answering surfaces. The current
// read path is backed by 20260726130000_mentor_journey_visibility.sql.
//
// Family Stage answering: journey_family_answers already had a
// working Mentor-write RLS policy before this file existed (2026-07-25,
// see that migration's own journey_family_answers_write policy —
// `WITH CHECK (answerer_id = auth.uid())`, no seeker-only restriction)
// — the only missing piece was ever the UI. Submits via the same
// SelahJourneyService.submitFamilyAnswer/fetchFamilyAnswers the Seeker
// side already uses, just with direction 'seeker_to_mentor' and the
// Shepherd as answerer_id.
//
// 2026-07-26 (#31): Family Review Period Continue/Pause banner added —
// the actual "Choose Continue or Pause during the Family Review
// Period" Standard Shepherd capability from MENTOR_ARCHITECTURE_CURRENT_
// VERSION_V6.md, previously ratified but never built (same gap
// pattern as the Family Stage answering UI above). Shown whenever
// SelahJourneyService.fetchFamilyReview() finds a live (pending or
// paused) review for this Journey.
//
// 2026-08-31 (inherited decision 224 F7): Timeline, Conversation and Family Review
// reads preserve source truth independently. Successful empty remains empty;
// unavailable gets a local Retry; retained rows are labelled last confirmed.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../../dev/selah_app_gold_preview.dart';
import '../../data/journey_questions.dart';
import '../../data/selah_journey_stages.dart';
import '../../dev/selah_dev_scenario.dart';
import '../../services/selah_account_state.dart';
import '../../services/selah_journey_service.dart';
import '../../services/selah_developer_access.dart';
// SelahMilestone/SelahChatMessage are defined in selah_match_service.dart,
// not selah_mentor_journey_service.dart (which only imports them to shape
// its own fetchTimeline()/fetchMessages() return types) — this file
// declares fields of those types directly (`List<SelahMilestone>
// _milestones`, `List<SelahChatMessage> _messages` below), so it needs
// its own import of the defining library. Missing until now (2026-07-26
// pre-existing gap, caught on a real device build during #31 testing,
// not something #31 introduced) — Dart only makes a type's NAME usable
// via re-export or a direct import, not transitively through another
// file's method signatures.
import '../../services/selah_match_service.dart';
import '../../services/selah_mentor_journey_service.dart';
import '../../services/selah_mentor_link_service.dart';
import '../../state/app_state.dart';
import '../../theme/selah_colors.dart';
import '../../theme/selah_text.dart';
import '../../widgets/selah_state_widgets.dart';
import '../../widgets/selah_loading.dart';
import '../../widgets/selah_write_feedback.dart';

typedef MentorTimelineSourceLoader =
    Future<SelahSourceResult<List<SelahMilestone>>> Function(String matchId);
typedef MentorMessagesSourceLoader =
    Future<SelahSourceResult<List<SelahChatMessage>>> Function(String matchId);
typedef MentorFamilyReviewSourceLoader =
    Future<SelahSourceResult<SelahFamilyReview?>> Function(String matchId);
typedef MentorReviewDecisionSourceLoader =
    Future<SelahSourceResult<String?>> Function(String reviewId);
typedef MentorFamilyAnswerWriter =
    Future<bool> Function(
      String matchId,
      String direction,
      String questionId,
      String answerText,
    );
typedef MentorReviewDecisionWriter =
    Future<bool> Function(String reviewId, String decision);

class MentorJourneyDetailScreen extends StatefulWidget {
  final MentorJourneyView journey;
  final bool hasShepherdOne;

  @visibleForTesting
  final MentorTimelineSourceLoader? loadTimeline;
  @visibleForTesting
  final MentorMessagesSourceLoader? loadMessages;
  @visibleForTesting
  final MentorFamilyReviewSourceLoader? loadFamilyReview;
  @visibleForTesting
  final MentorReviewDecisionSourceLoader? loadReviewDecision;
  @visibleForTesting
  final Future<Map<String, String>> Function(String matchId, String direction)?
  loadFamilyAnswers;
  @visibleForTesting
  final bool enablePolling;
  @visibleForTesting
  final MentorFamilyAnswerWriter? writeFamilyAnswer;
  @visibleForTesting
  final MentorReviewDecisionWriter? writeReviewDecision;
  @visibleForTesting
  final Future<bool> Function(String reviewId)? reopenReview;

  const MentorJourneyDetailScreen({
    super.key,
    required this.journey,
    this.hasShepherdOne = false,
    this.loadTimeline,
    this.loadMessages,
    this.loadFamilyReview,
    this.loadReviewDecision,
    this.loadFamilyAnswers,
    this.enablePolling = true,
    this.writeFamilyAnswer,
    this.writeReviewDecision,
    this.reopenReview,
  });

  @override
  State<MentorJourneyDetailScreen> createState() =>
      _MentorJourneyDetailScreenState();
}

class _MentorJourneyDetailScreenState extends State<MentorJourneyDetailScreen> {
  bool _loading = true;
  List<SelahMilestone> _milestones = [];
  List<SelahChatMessage> _messages = [];
  bool _timelineLoading = true;
  bool _timelineUnavailable = false;
  bool _timelineLastKnown = false;
  bool _messagesLoading = true;
  bool _messagesUnavailable = false;
  bool _messagesLastKnown = false;
  Map<String, String> _myAnswers =
      {}; // seeker_to_mentor, answered by this Shepherd
  final Map<String, TextEditingController> _controllers = {};
  Timer? _poll;

  // #31 — Family Review Period.
  SelahFamilyReview? _review;
  String? _myDecision; // this Shepherd's own Continue/Pause on _review, if any
  bool _reviewLoading = true;
  bool _reviewUnavailable = false;
  bool _reviewLastKnown = false;
  bool _decisionLoading = true;
  bool _decisionUnavailable = false;
  bool _reviewActionBusy = false;
  bool _familyActionBusy = false;
  bool _revoked = false;
  late final String? _owner;
  late final int _generation;
  int _sourceEpoch = 0;
  int _loadRequest = 0;
  int _timelineRequest = 0;
  int _messagesRequest = 0;
  int _reviewRequest = 0;
  int _decisionRequest = 0;
  int _reviewWindowEpoch = 0;
  int _reviewActionToken = 0;

  bool _readCurrent(int epoch) =>
      mounted &&
      !_revoked &&
      (!widget.journey.isMock || SelahDeveloperAccess.canUseDeveloperTools) &&
      epoch == _sourceEpoch &&
      !SelahAccountState.isSigningOut &&
      SelahAccountState.userId == _owner &&
      SelahAccountState.generation == _generation;

  bool _actionSourceCurrent(int epoch, String matchId) =>
      _readCurrent(epoch) &&
      (_owner != null || _isMock) &&
      widget.journey.matchId == matchId;

  bool _actionCurrent(int epoch, String matchId) =>
      _actionSourceCurrent(epoch, matchId) &&
      _journeyWritable &&
      ModalRoute.of(context)?.isCurrent != false;

  bool get _journeyWritable =>
      widget.journey.status == 'active' && !widget.journey.isJourneyLocked;

  void _replaceReview(SelahFamilyReview? review) {
    if (_review != review) {
      _reviewWindowEpoch++;
      _reviewActionToken++;
      _reviewActionBusy = false;
      _decisionRequest++;
      _myDecision = null;
    }
    _review = review;
  }

  void _withdrawSupersededAccount() {
    if (!mounted || _revoked || _readCurrent(_sourceEpoch)) return;
    _revoked = true;
    _sourceEpoch++;
    _poll?.cancel();
    _milestones = const [];
    _messages = const [];
    _myAnswers = const {};
    _review = null;
    _myDecision = null;
    _reviewActionBusy = false;
    _familyActionBusy = false;
    for (final controller in _controllers.values) {
      controller.clear();
    }
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    } else {
      setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();
    _owner = SelahAccountState.userId;
    _generation = SelahAccountState.generation;
    AppState.instance.addListener(_withdrawSupersededAccount);
    SelahDeveloperAccess.authorizationChanges.addListener(
      _withdrawSupersededAccount,
    );
    for (final q in JourneyQuestions.seekerToMentor) {
      _controllers[q.id] = TextEditingController();
    }
    _load();
    _configurePolling();
  }

  void _configurePolling() {
    _poll?.cancel();
    if (widget.enablePolling && !_revoked) {
      _poll = Timer.periodic(
        const Duration(seconds: 5),
        (_) => _load(showSpinner: false),
      );
    }
  }

  @override
  void didUpdateWidget(covariant MentorJourneyDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enablePolling != widget.enablePolling) _configurePolling();
    if (oldWidget.journey.matchId != widget.journey.matchId ||
        oldWidget.journey.attemptId != widget.journey.attemptId ||
        oldWidget.journey.linkedSeekerId != widget.journey.linkedSeekerId ||
        oldWidget.journey.journeyStage != widget.journey.journeyStage ||
        oldWidget.journey.status != widget.journey.status ||
        oldWidget.journey.pause != widget.journey.pause ||
        oldWidget.journey.isMock != widget.journey.isMock ||
        oldWidget.hasShepherdOne != widget.hasShepherdOne ||
        oldWidget.loadTimeline != widget.loadTimeline ||
        oldWidget.loadMessages != widget.loadMessages ||
        oldWidget.loadFamilyReview != widget.loadFamilyReview ||
        oldWidget.loadReviewDecision != widget.loadReviewDecision ||
        oldWidget.loadFamilyAnswers != widget.loadFamilyAnswers ||
        oldWidget.writeFamilyAnswer != widget.writeFamilyAnswer ||
        oldWidget.writeReviewDecision != widget.writeReviewDecision ||
        oldWidget.reopenReview != widget.reopenReview) {
      _sourceEpoch++;
      _milestones = const [];
      _messages = const [];
      _myAnswers = const {};
      for (final controller in _controllers.values) {
        controller.clear();
      }
      _review = null;
      _myDecision = null;
      _timelineLoading = true;
      _timelineUnavailable = false;
      _timelineLastKnown = false;
      _messagesLoading = widget.hasShepherdOne;
      _messagesUnavailable = false;
      _messagesLastKnown = false;
      _reviewLoading = true;
      _reviewUnavailable = false;
      _reviewLastKnown = false;
      _decisionLoading = true;
      _decisionUnavailable = false;
      _reviewActionBusy = false;
      _familyActionBusy = false;
      _load();
    }
  }

  @override
  void dispose() {
    _sourceEpoch++;
    AppState.instance.removeListener(_withdrawSupersededAccount);
    SelahDeveloperAccess.authorizationChanges.removeListener(
      _withdrawSupersededAccount,
    );
    _poll?.cancel();
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _atFamilyStage => widget.journey.journeyStage == 'family_stage';

  /// A dev-panel stand-in. BRANCHED ON BEFORE ANY SERVER CALL, not after:
  /// its matchId is `dev-wj0`, not a uuid, so fetchTimeline,
  /// fetchMessages, fetchFamilyReview and mentor_review_decision would each
  /// be handed something that is not an id. The branch prevents false error
  /// states and any accidental server call for a developer-only fixture.
  bool get _isMock =>
      SelahDeveloperAccess.canUseDeveloperTools && widget.journey.isMock;

  /// The staged Timeline for a stand-in Journey.
  ///
  /// Derived from the staged STAGE rather than listed as its own toggle:
  /// a Journey at Open Conversation has necessarily started a
  /// conversation, and one that has not reached Family Compatibility
  /// cannot have a family_stage milestone. Two controls that could
  /// disagree with each other would let the panel draw a Journey that
  /// cannot exist.
  ///
  /// Milestone types are the ones _milestoneLabel already knows — this
  /// invents no new vocabulary.
  List<SelahMilestone> get _stagedMilestones {
    final order = SelahJourneyStages.of(widget.journey.journeyStage)?.order ?? 1;
    final now = DateTime.now();
    return [
      SelahMilestone(
        type: 'match_created',
        occurredAt: now.subtract(const Duration(days: 34)),
      ),
      if (order >= 7)
        SelahMilestone(
          type: 'family_stage',
          occurredAt: now.subtract(const Duration(days: 6)),
        ),
      if (order >= 8)
        SelahMilestone(
          type: 'conversation_started',
          occurredAt: now.subtract(const Duration(days: 2)),
        ),
    ];
  }

  Future<void> _load({bool showSpinner = true}) async {
    final epoch = _sourceEpoch;
    if (!_readCurrent(epoch)) return;
    final request = ++_loadRequest;
    // STAND-IN: no server call is made at all, and the staged review is
    // read straight back so a Continue tapped a moment ago is still
    // recorded when the 5s poll comes round.
    if (_isMock) {
      if (!mounted) return;
      setState(() {
        _milestones = _stagedMilestones;
        // Messages stay EMPTY on a stand-in, deliberately. A Shepherd's
        // message view is a real privacy surface (per-attempt since
        // 2026-08-10, so a new Journey inherits nothing), and inventing a
        // conversation would preview a disclosure rather than a layout.
        _messages = const [];
        _timelineLoading = false;
        _timelineUnavailable = false;
        _timelineLastKnown = false;
        _messagesLoading = false;
        _messagesUnavailable = false;
        _messagesLastKnown = false;
        _myAnswers = const {};
        _replaceReview(SelahDevScenario.mentorStagedReview());
        _myDecision = SelahDevScenario.instance.mentorReviewDecision;
        _reviewLoading = false;
        _reviewUnavailable = false;
        _reviewLastKnown = false;
        _decisionLoading = false;
        _decisionUnavailable = false;
        _loading = false;
      });
      return;
    }
    if (showSpinner && mounted) setState(() => _loading = true);
    final myAnswersFuture = _atFamilyStage && widget.hasShepherdOne
        ? (widget.loadFamilyAnswers ?? SelahJourneyService.fetchFamilyAnswers)(
            widget.journey.matchId,
            'seeker_to_mentor',
          )
        : Future.value(<String, String>{});
    await Future.wait<void>([
      _loadTimeline(),
      if (widget.hasShepherdOne) _loadMessages() else _clearMessages(),
      _loadReview(),
    ]);
    final myAnswers = await myAnswersFuture;
    if (!_readCurrent(epoch) || request != _loadRequest) return;
    setState(() {
      _myAnswers = myAnswers;
      _loading = false;
    });
  }

  Future<void> _clearMessages() async {
    _messagesRequest++;
    if (!mounted) return;
    setState(() {
      _messages = const [];
      _messagesLoading = false;
      _messagesUnavailable = false;
      _messagesLastKnown = false;
    });
  }

  Future<void> _loadTimeline({bool localSpinner = false}) async {
    final epoch = _sourceEpoch;
    if (!_readCurrent(epoch)) return;
    final request = ++_timelineRequest;
    if (localSpinner && mounted) setState(() => _timelineLoading = true);
    SelahSourceResult<List<SelahMilestone>> result;
    try {
      result =
          await (widget.loadTimeline ??
              SelahMentorJourneyService.fetchTimelineSource)(
            widget.journey.matchId,
          );
    } catch (_) {
      result = const SelahSourceResult.unavailable(
        SelahSourceFailure.requestFailed,
      );
    }
    if (!_readCurrent(epoch) || request != _timelineRequest) return;
    setState(() {
      _timelineLoading = false;
      _timelineUnavailable = result.isUnavailable;
      if (result.isAvailable) {
        _milestones = result.valueOr(const []);
        _timelineLastKnown = false;
      } else {
        _timelineLastKnown = _milestones.isNotEmpty;
      }
    });
  }

  Future<void> _loadMessages({bool localSpinner = false}) async {
    final epoch = _sourceEpoch;
    if (!_readCurrent(epoch) || !widget.hasShepherdOne) return;
    final request = ++_messagesRequest;
    if (localSpinner && mounted) setState(() => _messagesLoading = true);
    SelahSourceResult<List<SelahChatMessage>> result;
    try {
      result =
          await (widget.loadMessages ??
              SelahMentorJourneyService.fetchMessagesResult)(
            widget.journey.matchId,
          );
    } catch (_) {
      result = const SelahSourceResult.unavailable(
        SelahSourceFailure.requestFailed,
      );
    }
    if (!_readCurrent(epoch) ||
        request != _messagesRequest ||
        !widget.hasShepherdOne) {
      return;
    }
    setState(() {
      _messagesLoading = false;
      _messagesUnavailable = result.isUnavailable;
      if (result.isAvailable) {
        _messages = result.valueOr(const []);
        _messagesLastKnown = false;
      } else {
        _messagesLastKnown = _messages.isNotEmpty;
      }
    });
  }

  Future<void> _loadReview({bool localSpinner = false}) async {
    final epoch = _sourceEpoch;
    if (!_readCurrent(epoch)) return;
    final request = ++_reviewRequest;
    final matchId = widget.journey.matchId;
    final loader = widget.loadFamilyReview;
    if (localSpinner && mounted) setState(() => _reviewLoading = true);
    if (loader == null) {
      await SelahJourneyService.resolveFamilyReviewIfDue(matchId);
      if (!_readCurrent(epoch) || request != _reviewRequest) return;
    }
    SelahSourceResult<SelahFamilyReview?> result;
    try {
      result = await (loader ?? SelahJourneyService.fetchFamilyReviewResult)(
        matchId,
      );
    } catch (_) {
      result = const SelahSourceResult.unavailable(
        SelahSourceFailure.requestFailed,
      );
    }
    if (!_readCurrent(epoch) || request != _reviewRequest) return;
    if (result.isUnavailable) {
      setState(() {
        _reviewLoading = false;
        _reviewUnavailable = true;
        _reviewLastKnown = _review != null;
      });
      return;
    }
    final review = result.valueOrNull;
    setState(() {
      _replaceReview(review);
      _reviewLoading = false;
      _reviewUnavailable = false;
      _reviewLastKnown = false;
      if (review == null) {
        _reviewActionBusy = false;
        _myDecision = null;
        _decisionLoading = false;
        _decisionUnavailable = false;
      } else {
        _decisionLoading = true;
        _decisionUnavailable = false;
      }
    });
    if (review != null) await _loadDecision(review.id);
  }

  Future<void> _loadDecision(
    String reviewId, {
    bool localSpinner = false,
  }) async {
    final epoch = _sourceEpoch;
    if (!_readCurrent(epoch) || _review?.id != reviewId) return;
    final request = ++_decisionRequest;
    if (localSpinner && mounted) setState(() => _decisionLoading = true);
    SelahSourceResult<String?> result;
    try {
      result =
          await (widget.loadReviewDecision ??
              SelahMentorJourneyService.myReviewDecisionResult)(reviewId);
    } catch (_) {
      result = const SelahSourceResult.unavailable(
        SelahSourceFailure.requestFailed,
      );
    }
    if (!_readCurrent(epoch) ||
        request != _decisionRequest ||
        _review?.id != reviewId) {
      return;
    }
    setState(() {
      _decisionLoading = false;
      _decisionUnavailable = result.isUnavailable;
      if (result.isAvailable) {
        if (_myDecision != result.valueOrNull) _reviewWindowEpoch++;
        _myDecision = result.valueOrNull;
      }
    });
  }

  Future<void> _submitFamilyAnswers(int epoch) async {
    final matchId = widget.journey.matchId;
    if (!_actionCurrent(epoch, matchId) ||
        _familyActionBusy ||
        !_atFamilyStage ||
        !widget.hasShepherdOne ||
        widget.journey.isJourneyLocked) {
      return;
    }
    // A stand-in has no journey_family_answers row to write to. Answers
    // are kept in the controllers and simply not submitted — the panel
    // does not claim to stage this half.
    if (_isMock) {
      await _load();
      return;
    }
    // BUG-03 (2026-08-14 audit, inherited upstream action 225 — fixed 2026-08-15): same
    // truthful-submit rule as the Seeker side. A Shepherd's family
    // answers are a Journey safeguard; a failed write now says so, the
    // text stays in the controllers, and pressing Submit again re-sends
    // safely (dup rows are tolerated by later-insert-wins ordering).
    final answers = [
      for (final q in JourneyQuestions.seekerToMentor)
        if (_controllers[q.id]!.text.trim().isNotEmpty)
          (q.id, _controllers[q.id]!.text.trim()),
    ];
    final writer =
        widget.writeFamilyAnswer ?? SelahJourneyService.submitFamilyAnswer;
    setState(() => _familyActionBusy = true);
    var allSaved = true;
    try {
      for (final answer in answers) {
        if (!_actionCurrent(epoch, matchId)) return;
        final ok = await writer(
          matchId,
          'seeker_to_mentor',
          answer.$1,
          answer.$2,
        );
        if (!_actionCurrent(epoch, matchId)) return;
        if (!ok) allSaved = false;
      }
    } catch (_) {
      allSaved = false;
    } finally {
      if (_actionSourceCurrent(epoch, matchId)) {
        setState(() => _familyActionBusy = false);
      }
    }
    if (!mounted || !_actionCurrent(epoch, matchId)) return;
    if (!allSaved) {
      showSelahFamilyAnswersWriteFailure(context);
    }
    await _load();
  }

  Future<void> _reviewDecision(
    String decision,
    int epoch,
    String? expectedReviewId,
    int expectedWindowEpoch,
  ) async {
    final matchId = widget.journey.matchId;
    final review = _review;
    if (!_actionCurrent(epoch, matchId) ||
        review == null ||
        review.id != expectedReviewId ||
        expectedWindowEpoch != _reviewWindowEpoch ||
        review.status != 'pending' ||
        _myDecision != null ||
        (decision != 'continue' && decision != 'pause') ||
        _reviewActionBusy ||
        _reviewLoading ||
        _reviewUnavailable ||
        _decisionLoading ||
        _decisionUnavailable) {
      return;
    }
    // THE STAND-IN ACTUALLY DECIDES. Writing the choice into the scenario
    // and re-reading it is what makes this rehearsable: the buttons grey,
    // the card switches to "You chose … — waiting on the other family",
    // and it survives the 5s poll. A snackbar here would be the panel
    // announcing an outcome instead of producing one.
    if (_isMock) {
      SelahDevScenario.instance.setMentorReviewDecision(decision);
      await _load(showSpinner: false);
      return;
    }
    final token = ++_reviewActionToken;
    setState(() => _reviewActionBusy = true);
    var ok = false;
    try {
      ok =
          await (widget.writeReviewDecision ??
              SelahMentorJourneyService.mentorReviewDecision)(review.id, decision);
    } catch (_) {
      // Failed writes retain the prior confirmed review and can be retried.
    }
    if (_actionSourceCurrent(epoch, matchId) && token == _reviewActionToken) {
      setState(() => _reviewActionBusy = false);
    }
    if (!_actionCurrent(epoch, matchId) ||
        _review?.id != review.id ||
        expectedWindowEpoch != _reviewWindowEpoch ||
        token != _reviewActionToken) {
      return;
    }
    if (!ok) {
      _showReviewWriteFailure();
      return;
    }
    await _load(showSpinner: false);
  }

  Future<void> _reopenReview(
    int epoch,
    String? expectedReviewId,
    int expectedWindowEpoch,
  ) async {
    final matchId = widget.journey.matchId;
    final review = _review;
    if (!_actionCurrent(epoch, matchId) ||
        review == null ||
        review.id != expectedReviewId ||
        expectedWindowEpoch != _reviewWindowEpoch ||
        review.status != 'paused' ||
        _reviewActionBusy ||
        _reviewLoading ||
        _reviewUnavailable ||
        _decisionLoading ||
        _decisionUnavailable) {
      return;
    }
    if (_isMock) {
      // Reopening clears the decision and starts the window again —
      // the same shape reopen_family_review() produces.
      SelahDevScenario.instance.setMentorReviewDecision(null);
      await _load(showSpinner: false);
      return;
    }
    final token = ++_reviewActionToken;
    setState(() => _reviewActionBusy = true);
    var ok = false;
    try {
      ok =
          await (widget.reopenReview ??
              SelahMentorJourneyService.reopenFamilyReview)(review.id);
    } catch (_) {
      // A transport failure is not a confirmed reopened review.
    }
    if (_actionSourceCurrent(epoch, matchId) && token == _reviewActionToken) {
      setState(() => _reviewActionBusy = false);
    }
    if (!_actionCurrent(epoch, matchId) ||
        _review?.id != review.id ||
        expectedWindowEpoch != _reviewWindowEpoch ||
        token != _reviewActionToken) {
      return;
    }
    if (!ok) {
      _showReviewWriteFailure();
      return;
    }
    await _load(showSpinner: false);
  }

  void _showReviewWriteFailure() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Your review didn't save — please try again."),
      ),
    );
  }

  static String _formatReviewRemaining(DateTime deadlineAt) {
    final d = deadlineAt.difference(DateTime.now());
    if (d.isNegative || d == Duration.zero) return 'less than a minute';
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    return h > 0 ? '${h}h ${m}m' : '${m}m';
  }

  // _stageLabel REMOVED 2026-08-09 — see data/selah_journey_stages.dart.
  //
  // It was one of three copies of the same switch over the same eight
  // strings, and the three had drifted: this one said 'Phase 1 —
  // Foundations', the Shepherd Dashboard said 'Phase 1', and Connections
  // said 'In the Pre-Journey Ritual' for seven of the eight. A Shepherd
  // could read two different names for one Journey by tapping into it.
  //
  // The labels also changed with the move: 'Phase 1/2/3' were internal
  // engineering names that had leaked to the surface (Founder,
  // 2026-08-09). They are now Faith & Values, Building a Life and
  // Navigating Life.

  /// Milestone types from `journey_milestones` — NOT Journey stages, and
  /// deliberately not folded into SelahJourneyStages even though
  /// 'family_stage' appears in both. One is a stage of the Journey; the
  /// other is a real-world event a Shepherd records after it happened.
  /// Merging them on a matching string would be a false economy.
  static String _milestoneLabel(String type) => switch (type) {
    'match_created' => 'Match',
    'conversation_started' => 'Conversation Started',
    'family_stage' => 'Family Stage',
    'meeting' => 'Meeting',
    'marriage' => 'Marriage',
    _ => type,
  };

  @override
  Widget build(BuildContext context) {
    if (!_readCurrent(_sourceEpoch)) {
      return Scaffold(
        body: Container(
          decoration: SelahAppGoldDecoration(gradient: SelahColors.brandGradient),
          child: const SafeArea(
            child: SelahEmptyState(
              icon: Icons.lock_outline,
              message: 'This Journey is no longer available.',
            ),
          ),
        ),
      );
    }
    final j = widget.journey;
    final actionEpoch = _sourceEpoch;
    final reviewId = _review?.id;
    final reviewWindowEpoch = _reviewWindowEpoch;
    final answered = _myAnswers.length >= JourneyQuestions.seekerToMentor.length;

    return Scaffold(
      // FIXED 2026-08-01 (Founder: "there should be no purple at top, it
      // should blend the pink/purple colour... that should be across all
      // things"). Same fix notifications_screen.dart got on 2026-07-27:
      // without this the transparent AppBar shows the Scaffold's own flat
      // background through, cutting the gender gradient off with a hard
      // purple strip. Body content compensates with SafeArea, which still
      // clears the status bar.
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          '${j.linkedSeekerName} & ${j.partner.firstName}',
          style: SelahText.heading(size: 16),
        ),
        iconTheme: IconThemeData(color: SelahColors.ink(0.70)),
      ),
      body: Container(
        decoration: SelahAppGoldDecoration(
          gradient: SelahColors.genderGradient(AppState.instance.gender),
        ),
        child: SafeArea(
          child: _loading
              ? const SelahLoading()
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: SelahColors.iconButtonBg,
                        border: Border.all(
                          color: SelahColors.iconButtonBorder,
                          width: 0.5,
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          // 2026-07-26: check_circle_outline replaces
                          // favorite_border (Founder: app-wide heart-icon
                          // removal) — pairs cleanly with its sibling
                          // pause_circle_outline, same icon family.
                          Icon(
                            j.isPauseDecisionPending
                                ? Icons.hourglass_top_rounded
                                : j.isSuspended
                                ? Icons.pause_circle_outline
                                : Icons.check_circle_outline,
                            color: SelahColors.ink(0.70),
                            size: 20,
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  j.isPauseDecisionPending
                                      ? 'Journey awaiting a decision'
                                      : j.isSuspended
                                      ? 'Paused'
                                      : (j.status == 'ended'
                                            ? 'Ended'
                                            // The override is real here, not
                                            // a hardcoded false: this screen
                                            // already loads the review in
                                            // _load(). When one is open the
                                            // chip says Family Review and the
                                            // card below it carries the
                                            // countdown and this Shepherd's
                                            // own Continue/Pause.
                                            : SelahJourneyStages.labelFor(
                                                j.journeyStage,
                                                reviewOpen:
                                                    _review != null &&
                                                    !_reviewUnavailable,
                                              )),
                                  style: SelahText.body(
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  '${j.linkedSeekerName}\'s Journey with ${j.partner.firstName}',
                                  style: SelahText.subtext(size: 11.5),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ── The other family ──────────────────────────
                    // 2026-08-08. Everything a Shepherd may learn about
                    // the counterpart family now arrives here and nowhere
                    // else. Until today this screen read the counterpart's
                    // full profile — photos, city, and by extension their
                    // Shepherds and this Shepherd's own co-Shepherds —
                    // because clause 3 of selah_can_view_profile treated
                    // every attempt participant as visible to every other.
                    //
                    // The disclosure line is required, not decorative:
                    // people are entitled to know what the other family
                    // can see of them. Same fields for everyone — a card
                    // a user could trim would make a sparse card a signal.
                    SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: SelahColors.foreground.withValues(alpha: 0.04),
                        border: Border.all(
                          color: SelahColors.ink(0.24),
                          width: 0.5,
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'The other family',
                            style: SelahText.heading(size: 14),
                          ),
                          SizedBox(height: 10),
                          _CardRow(
                            label: 'Seeker',
                            value:
                                '${j.partner.firstName}${j.partner.age > 0 ? ', ${j.partner.age}' : ''}',
                          ),
                          SizedBox(height: 6),
                          _CardRow(
                            label: 'Main Shepherd',
                            value: j.counterpartShepherdName == null
                                ? 'No Main Shepherd linked'
                                : [
                                        j.counterpartShepherdName,
                                        j.counterpartShepherdSurname,
                                      ]
                                      .where((x) => x != null && x.isNotEmpty)
                                      .join(' '),
                            muted: j.counterpartShepherdName == null,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'This is everything you can see of the other family — '
                            'and they see the same of yours.',
                            style: SelahText.subtext(size: 11),
                          ),
                        ],
                      ),
                    ),

                    if (_reviewUnavailable) ...[
                      SizedBox(height: 20),
                      SelahErrorBanner(
                        key: const ValueKey('mentor-review-unavailable'),
                        message: _reviewLastKnown
                            ? 'Family Review could not refresh. Showing last confirmed review.'
                            : 'Family Review could not refresh.',
                        onRetry: _reviewLoading
                            ? null
                            : () => _loadReview(localSpinner: true),
                      ),
                    ],
                    if (_decisionUnavailable &&
                        !_reviewUnavailable &&
                        _review != null) ...[
                      SizedBox(height: 20),
                      SelahErrorBanner(
                        key: const ValueKey('mentor-review-decision-unavailable'),
                        message: 'Review decision could not refresh.',
                        onRetry: _decisionLoading
                            ? null
                            : () => _loadDecision(
                                _review!.id,
                                localSpinner: true,
                              ),
                      ),
                    ],

                    // #31 — Family Review Period banner. Shown whenever
                    // a review is live for this Journey, regardless of
                    // which stage it's holding at.
                    if (_review != null && _journeyWritable) ...[
                      SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: SelahColors.accentBg,
                          border: Border.all(
                            color: SelahColors.accentBorder,
                            width: 0.5,
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  _review!.status == 'paused'
                                      ? Icons.pause_circle_outline
                                      : Icons.hourglass_top,
                                  color: Colors.white,
                                  size: 18,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  _review!.status == 'paused'
                                      ? 'Family Review — Paused'
                                      : 'Family Review Period',
                                  style: SelahText.body(
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            Text(
                              _review!.status == 'paused'
                                  ? "You paused this stage. ${j.linkedSeekerName}'s Journey holds here until you (or ${j.linkedSeekerName}'s other Shepherd) reopen the review."
                                  : "Review this stage. Unless you or ${j.linkedSeekerName}'s other Shepherd raises a concern, the Journey continues automatically in ${_formatReviewRemaining(_review!.deadlineAt)}.",
                              style: SelahText.subtext(size: 12.5),
                            ),
                            SizedBox(height: 12),
                            if (_reviewLoading ||
                                _reviewUnavailable ||
                                _decisionLoading ||
                                _decisionUnavailable)
                              const SizedBox.shrink()
                            else if (_review!.status == 'paused')
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton(
                                  onPressed: _reviewActionBusy
                                      ? null
                                      : () => _reopenReview(
                                          actionEpoch,
                                          reviewId,
                                          reviewWindowEpoch,
                                        ),
                                  child: _reviewActionBusy
                                      ? SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : Text(
                                          'Reopen Review',
                                          style: SelahText.button(size: 13),
                                        ),
                                ),
                              )
                            else if (_myDecision != null)
                              Text(
                                _myDecision == 'pause'
                                    ? "You chose Pause."
                                    : "You chose Continue — waiting on the review window.",
                                style: SelahText.subtext(
                                  size: 12,
                                  color: SelahColors.ink(0.70),
                                ),
                              )
                            else
                              Row(
                                children: [
                                  Expanded(
                                    child: FilledButton(
                                      onPressed: _reviewActionBusy
                                          ? null
                                          : () => _reviewDecision(
                                              'continue',
                                              actionEpoch,
                                              reviewId,
                                              reviewWindowEpoch,
                                            ),
                                      child: Text(
                                        'Continue',
                                        style: SelahText.button(size: 13),
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: _reviewActionBusy
                                          ? null
                                          : () => _reviewDecision(
                                              'pause',
                                              actionEpoch,
                                              reviewId,
                                              reviewWindowEpoch,
                                            ),
                                      child: Text(
                                        'Pause',
                                        style: SelahText.button(size: 13),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ],

                    if (_atFamilyStage &&
                        widget.hasShepherdOne &&
                        _journeyWritable) ...[
                      SizedBox(height: 24),
                      Text(
                        'FAMILY COMPATIBILITY STAGE',
                        style: SelahText.chapterLabel(
                          color: SelahColors.ink(0.54),
                        ),
                      ),
                      SizedBox(height: 10),
                      if (answered)
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: SelahColors.iconButtonBg,
                            border: Border.all(
                              color: SelahColors.iconButtonBorder,
                              width: 0.5,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            "You've answered ${j.partner.firstName}'s questions. "
                            "${j.linkedSeekerName}'s Journey continues once both sides have answered.",
                            style: SelahText.subtext(size: 12.5),
                          ),
                        )
                      else ...[
                        Text(
                          "${j.partner.firstName}'s side has questions for you, as ${j.linkedSeekerName}'s Shepherd:",
                          style: SelahText.body(
                            size: 13,
                            color: SelahColors.ink(0.70),
                          ),
                        ),
                        SizedBox(height: 12),
                        for (final q in JourneyQuestions.seekerToMentor) ...[
                          Text(q.text, style: SelahText.body(size: 14)),
                          SizedBox(height: 6),
                          TextField(
                            controller: _controllers[q.id],
                            maxLines: 3,
                            style: TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: SelahColors.foreground.withValues(
                                alpha: 0.06,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none,
                              ),
                              hintText: 'Your answer…',
                              hintStyle: TextStyle(color: SelahColors.ink(0.38)),
                            ),
                          ),
                          SizedBox(height: 14),
                        ],
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: _familyActionBusy
                                ? null
                                : () => _submitFamilyAnswers(actionEpoch),
                            child: Text(
                              'Submit',
                              style: SelahText.button(size: 14),
                            ),
                          ),
                        ),
                      ],
                    ],

                    SizedBox(height: 28),
                    Text(
                      'TIMELINE',
                      style: SelahText.chapterLabel(color: SelahColors.ink(0.54)),
                    ),
                    SizedBox(height: 10),
                    if (_timelineUnavailable) ...[
                      SelahErrorBanner(
                        key: const ValueKey('mentor-timeline-unavailable'),
                        message: _timelineLastKnown
                            ? 'Timeline could not refresh. Showing last confirmed Timeline.'
                            : 'Timeline could not refresh.',
                        onRetry: _timelineLoading
                            ? null
                            : () => _loadTimeline(localSpinner: true),
                      ),
                      if (_timelineLastKnown) SizedBox(height: 10),
                    ],
                    if (!_timelineUnavailable && _milestones.isEmpty)
                      const SelahEmptyState(
                        icon: Icons.timeline_outlined,
                        message: 'Nothing recorded here yet.',
                      )
                    else if (_milestones.isNotEmpty)
                      ..._milestones.map(
                        (m) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              Icon(
                                Icons.circle,
                                color: SelahColors.ink(0.38),
                                size: 8,
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _milestoneLabel(m.type),
                                  style: SelahText.body(
                                    size: 13,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              Text(
                                '${m.occurredAt.day}/${m.occurredAt.month}/${m.occurredAt.year}',
                                style: SelahText.subtext(size: 11),
                              ),
                            ],
                          ),
                        ),
                      ),

                    if (widget.hasShepherdOne) ...[
                      SizedBox(height: 28),
                      Text(
                        'CONVERSATION',
                        style: SelahText.chapterLabel(
                          color: SelahColors.ink(0.54),
                        ),
                      ),
                      SizedBox(height: 10),
                      if (_messagesUnavailable) ...[
                        SelahErrorBanner(
                          key: const ValueKey('mentor-conversation-unavailable'),
                          message: _messagesLastKnown
                              ? 'Conversation could not refresh. Showing last confirmed messages.'
                              : 'Conversation could not refresh.',
                          onRetry: _messagesLoading
                              ? null
                              : () => _loadMessages(localSpinner: true),
                        ),
                        if (_messagesLastKnown) SizedBox(height: 10),
                      ],
                      if (!_messagesUnavailable && _messages.isEmpty)
                        const SelahEmptyState(
                          icon: Icons.forum_outlined,
                          message: 'No messages yet.',
                        )
                      else if (_messages.isNotEmpty)
                        ..._messages.map(
                          (m) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                constraints: const BoxConstraints(
                                  maxWidth: 280,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: SelahColors.iconButtonBg,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  m.text,
                                  style: SelahText.body(
                                    size: 13,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}

/// One label/value line of the counterpart card. Kept private to this
/// screen — the card is the only place it renders.
class _CardRow extends StatelessWidget {
  final String label;
  final String value;
  final bool muted;
  const _CardRow({
    required this.label,
    required this.value,
    this.muted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 108,
          child: Text(label, style: SelahText.subtext(size: 12)),
        ),
        Expanded(
          child: Text(
            value,
            style: muted
                ? SelahText.subtext(size: 12.5)
                : SelahText.body(size: 12.5, color: Colors.white),
          ),
        ),
      ],
    );
  }
}
