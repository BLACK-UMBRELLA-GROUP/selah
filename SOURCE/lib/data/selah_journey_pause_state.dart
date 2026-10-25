/// Authoritative client representation of the shared Pause decision flow.
///
/// The database owns transitions. The client owns only presentation and the
/// developer preview. A pending request keeps the Journey in the Active slot
/// while locking its content; mutual Pause and its pending resume decision
/// remain outside Active capacity.
enum SelahPausePhase {
  active('none'),
  pauseDecisionPending('pause_requested'),
  continuationDecisionPending('continue_requested'),
  paused('paused'),
  resumeDecisionPending('resume_requested');

  final String storageValue;
  const SelahPausePhase(this.storageValue);

  static SelahPausePhase fromStorage(String? value) => values.firstWhere(
    (phase) => phase.storageValue == value,
    orElse: () => SelahPausePhase.active,
  );
}

enum SelahPausePerspective {
  active,
  pauseRequesterWaiting,
  pauseResponderDecision,
  continuationRequesterWaiting,
  continuationResponderDecision,
  mutuallyPaused,
  resumeRequesterWaiting,
  resumeResponderDecision,
}

enum SelahPauseAction {
  requestPause('request_pause'),
  agreePause('agree_pause'),
  requestContinue('request_continue'),
  continueJourney('continue_journey'),
  confirmPause('confirm_pause'),
  requestResume('request_resume'),
  agreeResume('agree_resume'),
  keepPaused('keep_paused');

  final String storageValue;
  const SelahPauseAction(this.storageValue);
}

/// The developer control's complete Pause-flow matrix. Basic/SELAH One is an
/// independent account-plan axis in Developer Access, so every scenario can
/// be reviewed under both entitlements without duplicating fake states.
enum SelahPauseDevScenario {
  active('Active'),
  pauseRequesterWaiting('Pause · requester waiting'),
  pauseResponderDecision('Pause · decision'),
  continuationRequesterWaiting('Continue · requester waiting'),
  continuationResponderDecision('Continue · decision'),
  mutuallyPaused('Mutually paused'),
  resumeRequesterWaiting('Resume · requester waiting'),
  resumeResponderDecision('Resume · decision'),
  resumedActive('Resumed / active'),
  endedFromPause('Ended from Pause'),
  deadlineApproaching('Deadline approaching'),
  deadlineExpired('Deadline expired'),
  pausedCapacityConflict('Paused-cap conflict');

  final String label;
  const SelahPauseDevScenario(this.label);

  bool get isEnded => this == endedFromPause;

  static SelahPauseDevScenario fromState(
    SelahJourneyPauseState state,
    String viewerId,
  ) => _fromPerspective(state.perspectiveFor(viewerId));

  static SelahPauseDevScenario _fromPerspective(
    SelahPausePerspective perspective,
  ) => switch (perspective) {
    SelahPausePerspective.active => SelahPauseDevScenario.resumedActive,
    SelahPausePerspective.pauseRequesterWaiting =>
      SelahPauseDevScenario.pauseRequesterWaiting,
    SelahPausePerspective.pauseResponderDecision =>
      SelahPauseDevScenario.pauseResponderDecision,
    SelahPausePerspective.continuationRequesterWaiting =>
      SelahPauseDevScenario.continuationRequesterWaiting,
    SelahPausePerspective.continuationResponderDecision =>
      SelahPauseDevScenario.continuationResponderDecision,
    SelahPausePerspective.mutuallyPaused => SelahPauseDevScenario.mutuallyPaused,
    SelahPausePerspective.resumeRequesterWaiting =>
      SelahPauseDevScenario.resumeRequesterWaiting,
    SelahPausePerspective.resumeResponderDecision =>
      SelahPauseDevScenario.resumeResponderDecision,
  };

  SelahJourneyPauseState stateFor({
    required String viewerId,
    required String otherId,
    DateTime? now,
  }) {
    final at = now ?? DateTime.now();
    return switch (this) {
      active || resumedActive || endedFromPause => SelahJourneyPauseState.active,
      pauseRequesterWaiting => SelahJourneyPauseState(
        phase: SelahPausePhase.pauseDecisionPending,
        initiatedBy: viewerId,
        requestedBy: viewerId,
        requestedAt: at,
        version: 1,
      ),
      pauseResponderDecision => SelahJourneyPauseState(
        phase: SelahPausePhase.pauseDecisionPending,
        initiatedBy: otherId,
        requestedBy: otherId,
        requestedAt: at,
        version: 1,
      ),
      continuationRequesterWaiting => SelahJourneyPauseState(
        phase: SelahPausePhase.continuationDecisionPending,
        initiatedBy: otherId,
        requestedBy: viewerId,
        requestedAt: at,
        version: 2,
      ),
      continuationResponderDecision => SelahJourneyPauseState(
        phase: SelahPausePhase.continuationDecisionPending,
        initiatedBy: viewerId,
        requestedBy: otherId,
        requestedAt: at,
        version: 2,
      ),
      mutuallyPaused => SelahJourneyPauseState(
        phase: SelahPausePhase.paused,
        initiatedBy: viewerId,
        version: 2,
      ),
      resumeRequesterWaiting => SelahJourneyPauseState(
        phase: SelahPausePhase.resumeDecisionPending,
        initiatedBy: viewerId,
        requestedBy: viewerId,
        requestedAt: at,
        version: 3,
      ),
      resumeResponderDecision => SelahJourneyPauseState(
        phase: SelahPausePhase.resumeDecisionPending,
        initiatedBy: otherId,
        requestedBy: otherId,
        requestedAt: at,
        version: 3,
      ),
      deadlineApproaching => SelahJourneyPauseState(
        phase: SelahPausePhase.pauseDecisionPending,
        initiatedBy: otherId,
        requestedBy: otherId,
        requestedAt: at.subtract(const Duration(hours: 12)),
        deadlineAt: at.add(const Duration(minutes: 45)),
        version: 1,
      ),
      deadlineExpired => SelahJourneyPauseState(
        phase: SelahPausePhase.pauseDecisionPending,
        initiatedBy: otherId,
        requestedBy: otherId,
        requestedAt: at.subtract(const Duration(days: 2)),
        deadlineAt: at.subtract(const Duration(minutes: 5)),
        version: 1,
      ),
      pausedCapacityConflict => SelahJourneyPauseState(
        phase: SelahPausePhase.pauseDecisionPending,
        initiatedBy: otherId,
        requestedBy: otherId,
        requestedAt: at,
        version: 1,
        capacityBlocked: true,
      ),
    };
  }
}

class SelahJourneyPauseState {
  final SelahPausePhase phase;

  /// The person who opened the current pause episode.
  final String? initiatedBy;

  /// The person who made the request currently awaiting an answer.
  final String? requestedBy;
  final DateTime? requestedAt;
  final DateTime? deadlineAt;
  final int version;

  /// Preview/transient refusal only. Capacity failures do not mutate the
  /// database state, so this flag is never persisted as a second truth.
  final bool capacityBlocked;

  const SelahJourneyPauseState({
    this.phase = SelahPausePhase.active,
    this.initiatedBy,
    this.requestedBy,
    this.requestedAt,
    this.deadlineAt,
    this.version = 0,
    this.capacityBlocked = false,
  });

  static const active = SelahJourneyPauseState();

  factory SelahJourneyPauseState.fromStorage({
    required String? phase,
    required String? initiatedBy,
    required String? requestedBy,
    required Object? requestedAt,
    required Object? deadlineAt,
    required Object? version,
  }) => SelahJourneyPauseState(
    phase: SelahPausePhase.fromStorage(phase),
    initiatedBy: initiatedBy,
    requestedBy: requestedBy,
    requestedAt: _date(requestedAt),
    deadlineAt: _date(deadlineAt),
    version: (version as num?)?.toInt() ?? 0,
  );

  static DateTime? _date(Object? value) {
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  bool get isLocked => phase != SelahPausePhase.active;
  bool get isPaused =>
      phase == SelahPausePhase.paused ||
      phase == SelahPausePhase.resumeDecisionPending;
  bool get isPending => switch (phase) {
    SelahPausePhase.pauseDecisionPending ||
    SelahPausePhase.continuationDecisionPending ||
    SelahPausePhase.resumeDecisionPending => true,
    _ => false,
  };

  /// Pending decisions still occupy Active capacity. Mutual Pause does not.
  bool get countsAsActiveSlot => !isPaused;

  bool get deadlineExpired =>
      deadlineAt != null && !DateTime.now().isBefore(deadlineAt!);

  bool deadlineApproaching({Duration threshold = const Duration(hours: 6)}) {
    if (deadlineAt == null || deadlineExpired) return false;
    return deadlineAt!.difference(DateTime.now()) <= threshold;
  }

  SelahPausePerspective perspectiveFor(String? currentUserId) {
    final mine = currentUserId != null && requestedBy == currentUserId;
    return switch (phase) {
      SelahPausePhase.active => SelahPausePerspective.active,
      SelahPausePhase.pauseDecisionPending =>
        mine
            ? SelahPausePerspective.pauseRequesterWaiting
            : SelahPausePerspective.pauseResponderDecision,
      SelahPausePhase.continuationDecisionPending =>
        mine
            ? SelahPausePerspective.continuationRequesterWaiting
            : SelahPausePerspective.continuationResponderDecision,
      SelahPausePhase.paused => SelahPausePerspective.mutuallyPaused,
      SelahPausePhase.resumeDecisionPending =>
        mine
            ? SelahPausePerspective.resumeRequesterWaiting
            : SelahPausePerspective.resumeResponderDecision,
    };
  }

  SelahJourneyPauseState copyWith({
    SelahPausePhase? phase,
    String? initiatedBy,
    String? requestedBy,
    DateTime? requestedAt,
    DateTime? deadlineAt,
    int? version,
    bool? capacityBlocked,
    bool clearRequestedBy = false,
    bool clearTiming = false,
  }) => SelahJourneyPauseState(
    phase: phase ?? this.phase,
    initiatedBy: initiatedBy ?? this.initiatedBy,
    requestedBy: clearRequestedBy ? null : requestedBy ?? this.requestedBy,
    requestedAt: clearTiming ? null : requestedAt ?? this.requestedAt,
    deadlineAt: clearTiming ? null : deadlineAt ?? this.deadlineAt,
    version: version ?? this.version,
    capacityBlocked: capacityBlocked ?? this.capacityBlocked,
  );
}

/// Pure transition rules used by tests and the developer scenario.
/// Production writes always go through the atomic database RPC.
abstract final class SelahJourneyPausePolicy {
  static bool canApply({
    required SelahJourneyPauseState state,
    required SelahPauseAction action,
    required String actorId,
    required String otherId,
  }) => switch ((state.phase, action)) {
    (SelahPausePhase.active, SelahPauseAction.requestPause) => true,
    (SelahPausePhase.pauseDecisionPending, SelahPauseAction.agreePause) ||
    (
      SelahPausePhase.pauseDecisionPending,
      SelahPauseAction.requestContinue,
    ) => state.requestedBy == otherId,
    (
      SelahPausePhase.continuationDecisionPending,
      SelahPauseAction.continueJourney,
    ) ||
    (
      SelahPausePhase.continuationDecisionPending,
      SelahPauseAction.confirmPause,
    ) => state.requestedBy == otherId,
    (SelahPausePhase.paused, SelahPauseAction.requestResume) => true,
    (SelahPausePhase.resumeDecisionPending, SelahPauseAction.agreeResume) ||
    (
      SelahPausePhase.resumeDecisionPending,
      SelahPauseAction.keepPaused,
    ) => state.requestedBy == otherId,
    _ => false,
  };

  static SelahJourneyPauseState apply({
    required SelahJourneyPauseState state,
    required SelahPauseAction action,
    required String actorId,
    required String otherId,
    DateTime? now,
    DateTime? deadlineAt,
  }) {
    if (!canApply(
      state: state,
      action: action,
      actorId: actorId,
      otherId: otherId,
    )) {
      throw StateError('pause_transition_not_allowed');
    }
    final at = now ?? DateTime.now();
    final nextVersion = state.version + 1;
    return switch (action) {
      SelahPauseAction.requestPause => SelahJourneyPauseState(
        phase: SelahPausePhase.pauseDecisionPending,
        initiatedBy: actorId,
        requestedBy: actorId,
        requestedAt: at,
        deadlineAt: deadlineAt,
        version: nextVersion,
      ),
      SelahPauseAction.agreePause ||
      SelahPauseAction.confirmPause => SelahJourneyPauseState(
        phase: SelahPausePhase.paused,
        initiatedBy: state.initiatedBy,
        version: nextVersion,
      ),
      SelahPauseAction.requestContinue => SelahJourneyPauseState(
        phase: SelahPausePhase.continuationDecisionPending,
        initiatedBy: state.initiatedBy,
        requestedBy: actorId,
        requestedAt: at,
        deadlineAt: deadlineAt,
        version: nextVersion,
      ),
      SelahPauseAction.continueJourney || SelahPauseAction.agreeResume =>
        SelahJourneyPauseState(version: nextVersion),
      SelahPauseAction.requestResume => SelahJourneyPauseState(
        phase: SelahPausePhase.resumeDecisionPending,
        initiatedBy: state.initiatedBy,
        requestedBy: actorId,
        requestedAt: at,
        deadlineAt: deadlineAt,
        version: nextVersion,
      ),
      SelahPauseAction.keepPaused => SelahJourneyPauseState(
        phase: SelahPausePhase.paused,
        initiatedBy: state.initiatedBy,
        version: nextVersion,
      ),
    };
  }
}
