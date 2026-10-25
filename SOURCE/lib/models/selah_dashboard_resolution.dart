/// Pure Dashboard priority and truth-boundary model.
///
/// This library deliberately imports neither Flutter nor Supabase. Callers turn
/// server-backed reads into a [DashboardSnapshot], then render the resulting
/// [DashboardResolution] through whichever presentation has been approved.

library;

enum DashboardRole { seeker, shepherd }

enum DashboardSourceState { loading, available, unavailable }

/// A safe source failure. [message] is diagnostic context, not automatically
/// approved user-facing copy.
final class DashboardFailure {
  final String code;
  final String? message;
  final bool retryable;

  const DashboardFailure({
    required this.code,
    this.message,
    this.retryable = true,
  });
}

/// One source read, preserving the difference between waiting, a successful
/// empty value, and failure.
sealed class DashboardSource<T> {
  const DashboardSource();

  const factory DashboardSource.loading() = DashboardLoading<T>;
  const factory DashboardSource.available(T value) = DashboardAvailable<T>;
  const factory DashboardSource.unavailable(DashboardFailure failure) =
      DashboardUnavailable<T>;

  DashboardSourceState get state;
  T? get valueOrNull;
  DashboardFailure? get failureOrNull;
  bool get isAvailable => state == DashboardSourceState.available;
}

final class DashboardLoading<T> extends DashboardSource<T> {
  const DashboardLoading();

  @override
  DashboardSourceState get state => DashboardSourceState.loading;

  @override
  T? get valueOrNull => null;

  @override
  DashboardFailure? get failureOrNull => null;
}

final class DashboardAvailable<T> extends DashboardSource<T> {
  final T value;

  const DashboardAvailable(this.value);

  @override
  DashboardSourceState get state => DashboardSourceState.available;

  @override
  T get valueOrNull => value;

  @override
  DashboardFailure? get failureOrNull => null;
}

final class DashboardUnavailable<T> extends DashboardSource<T> {
  final DashboardFailure failure;

  const DashboardUnavailable(this.failure);

  @override
  DashboardSourceState get state => DashboardSourceState.unavailable;

  @override
  T? get valueOrNull => null;

  @override
  DashboardFailure get failureOrNull => failure;
}

/// Flutter-free navigation intent carried by resolved Dashboard entries.
enum SelahDashboardTarget {
  none,
  discovery,
  connectionsJourneys,
  connectionsActivity,
  shepherd,
  notifications,
  profile,
  preferences,
  onboarding,
}

/// Priority classes in their governed order.
enum DashboardSignalKind {
  deadlineDecision,
  blockingGate,
  addressedDecision,
  ownJourneyMove,
  meaningfulMovement,
  governedInsight;

  bool get isObligation => switch (this) {
    deadlineDecision ||
    blockingGate ||
    addressedDecision ||
    ownJourneyMove => true,
    meaningfulMovement || governedInsight => false,
  };
}

/// A stable object-backed Dashboard entry.
///
/// [id] must identify the underlying unresolved object, not a render or view.
/// The resolver intentionally has no impression/view-count field: passive
/// exposure cannot demote an obligation.
final class DashboardSignal {
  final String id;
  final DashboardSignalKind kind;
  final String title;
  final String? detail;
  final String? actionLabel;
  final SelahDashboardTarget target;
  final DateTime? dueAt;
  final DateTime? eventAt;

  /// TRUE is an unread notification, FALSE is a reserved explicit read
  /// notification, and NULL means the object has no read-state semantics.
  final bool? isUnread;

  const DashboardSignal({
    required this.id,
    required this.kind,
    required this.title,
    this.detail,
    this.actionLabel,
    this.target = SelahDashboardTarget.none,
    this.dueAt,
    this.eventAt,
    this.isUnread,
  }) : assert(id != ''),
       assert(title != ''),
       assert(
         kind != DashboardSignalKind.deadlineDecision || dueAt != null,
         'A deadline decision requires a real dueAt value.',
       );
}

/// One governed suggestion that may accompany an otherwise calm Right Now.
///
/// An advisory is deliberately not a [DashboardSignal]: it is neither an
/// obligation nor movement, and it never competes in the priority ranking.
/// [why] is mandatory so the home never makes an unexplained recommendation.
final class DashboardAdvisory {
  final String id;
  final String title;
  final String? detail;
  final String why;
  final String? actionLabel;
  final SelahDashboardTarget target;

  const DashboardAdvisory({
    required this.id,
    required this.title,
    required this.why,
    this.detail,
    this.actionLabel,
    this.target = SelahDashboardTarget.none,
  }) : assert(id != ''),
       assert(title != ''),
       assert(why != '');
}

enum DashboardJourneyKind { searching, potential, active, paused, ended }

/// The stable Journey/search state. Priority changes do not replace this
/// summary; they only decide what appears in [DashboardResolution.answer].
final class DashboardJourneySummary {
  final String id;
  final DashboardJourneyKind kind;
  final String title;
  final String? detail;
  final double? progress;

  /// Draft display lines. Null means the underlying reads did not prove the
  /// fact and the renderer must suppress the line.
  final String? latestCompletedStage;
  final String? nextMilestone;
  final String? momentum;

  const DashboardJourneySummary({
    required this.id,
    required this.kind,
    required this.title,
    this.detail,
    this.progress,
    this.latestCompletedStage,
    this.nextMilestone,
    this.momentum,
  }) : assert(id != ''),
       assert(title != ''),
       assert(progress == null || (progress >= 0 && progress <= 1));
}

final class DashboardJourneyState {
  final DashboardJourneySummary summary;
  final List<DashboardSignal> signals;

  const DashboardJourneyState({required this.summary, this.signals = const []});
}

enum DashboardOrientationKind { potentials, saved, shepherd, unread }

/// The amount of visual weight an orientation item may receive.
///
/// Saved is always [quiet]: it is a useful bookmark orientation, never a
/// number to grow or a success measure.
enum DashboardOrientationEmphasis { primary, supporting, quiet }

final class DashboardOrientationItem {
  final String id;
  final DashboardOrientationKind kind;
  final String title;
  final String valueLabel;
  final String? detail;
  final SelahDashboardTarget target;
  final DashboardOrientationEmphasis emphasis;

  const DashboardOrientationItem({
    required this.id,
    required this.kind,
    required this.title,
    required this.valueLabel,
    this.detail,
    this.target = SelahDashboardTarget.none,
    this.emphasis = DashboardOrientationEmphasis.supporting,
  }) : assert(id != ''),
       assert(title != ''),
       assert(valueLabel != '');
}

enum DashboardFamilyKind { connected, invitationPending, notConnected }

/// Stable Shepherd relationship state for the Family level of Seeker Home.
///
/// It carries compact relationship and invitation-summary truth. The
/// Dashboard routes management to the dedicated Shepherdship Manager and
/// never expands invitation lifecycle controls in place.
final class DashboardFamilyStatus {
  final DashboardFamilyKind kind;
  final String title;
  final String? detail;
  final String? actionLabel;
  final SelahDashboardTarget target;
  final int linkedCount;
  final int pendingInvitationCount;
  final DateTime? expiresAt;

  const DashboardFamilyStatus({
    required this.kind,
    required this.title,
    this.detail,
    this.actionLabel,
    this.target = SelahDashboardTarget.shepherd,
    this.linkedCount = 0,
    this.pendingInvitationCount = 0,
    this.expiresAt,
  }) : assert(title != ''),
       assert(linkedCount >= 0),
       assert(pendingInvitationCount >= 0);
}

/// The stable-state content class introduced by inherited decision 217.
///
/// The two parts preserve their source health independently. A failed
/// orientation read must not hide a known Shepherd relationship, and a failed
/// Shepherd read must not erase a truthfully known Potential count.
final class DashboardStableState {
  final DashboardSource<List<DashboardOrientationItem>> orientationItems;
  final DashboardSource<DashboardFamilyStatus> family;

  const DashboardStableState({
    this.orientationItems = const DashboardSource.available([]),
    this.family = const DashboardSource.unavailable(
      DashboardFailure(code: 'family_not_supplied', retryable: false),
    ),
  });
}

/// Complete resolver input. A successful empty list is materially different
/// from [DashboardSource.unavailable].
final class DashboardSnapshot {
  final DashboardRole role;
  final DashboardSource<List<DashboardSignal>> onboarding;
  final DashboardSource<DashboardJourneyState> journeys;

  /// The one server-authoritative Updates projection shared by both roles.
  final DashboardSource<List<DashboardSignal>> updates;
  final DashboardSource<List<DashboardSignal>> shepherdInvitations;
  final DashboardSource<List<DashboardSignal>> insights;
  final DashboardSource<List<DashboardAdvisory>> advisories;
  final DashboardStableState stableState;

  const DashboardSnapshot({
    required this.role,
    required this.onboarding,
    required this.journeys,
    required this.updates,
    required this.shepherdInvitations,
    required this.insights,
    this.advisories = const DashboardSource.available([]),
    this.stableState = const DashboardStableState(),
  });
}

enum DashboardSignalSource {
  onboarding,
  journeys,
  updates,
  shepherdInvitations,
  insights,
}

final class DashboardResolvedItem {
  final DashboardSignal signal;
  final DashboardSignalSource source;

  const DashboardResolvedItem({required this.signal, required this.source});
}

enum DashboardAnswerKind {
  signal,
  calm,
  calmAdvisory,
  loading,
  refreshRequired,
}

/// The single visual answer at the top of Dashboard.
///
/// [item] is present only for [DashboardAnswerKind.signal]. Loading and refresh
/// answers prevent an incomplete read from being presented as a calm day.
final class DashboardAnswer {
  final DashboardAnswerKind kind;
  final DashboardResolvedItem? item;
  final DashboardAdvisory? advisory;

  const DashboardAnswer._(this.kind, this.item, this.advisory);

  const DashboardAnswer.signal(DashboardResolvedItem item)
    : this._(DashboardAnswerKind.signal, item, null);

  const DashboardAnswer.calm() : this._(DashboardAnswerKind.calm, null, null);

  const DashboardAnswer.calmAdvisory(DashboardAdvisory advisory)
    : this._(DashboardAnswerKind.calmAdvisory, null, advisory);

  const DashboardAnswer.loading()
    : this._(DashboardAnswerKind.loading, null, null);

  const DashboardAnswer.refreshRequired()
    : this._(DashboardAnswerKind.refreshRequired, null, null);
}

enum DashboardJourneyResolutionState { available, loading, unavailable }

final class DashboardJourneyResolution {
  final DashboardJourneyResolutionState state;
  final DashboardJourneySummary? summary;

  const DashboardJourneyResolution._(this.state, this.summary);

  const DashboardJourneyResolution.available(DashboardJourneySummary summary)
    : this._(DashboardJourneyResolutionState.available, summary);

  const DashboardJourneyResolution.loading()
    : this._(DashboardJourneyResolutionState.loading, null);

  const DashboardJourneyResolution.unavailable()
    : this._(DashboardJourneyResolutionState.unavailable, null);
}

enum DashboardTone { needsYou, moving, calm }

enum DashboardSourceHealth { complete, partial, failed }

/// Health of one Dashboard destination after its contributing reads resolve.
///
/// [available] includes a successful empty result. [partial] means at least
/// one contributor did not complete, so a renderer must never describe an
/// empty list as "nothing happened". This is separate from the aggregate
/// [DashboardSourceHealth] because each tab must tell the truth independently.
enum DashboardSectionState { loading, available, partial, unavailable }

final class DashboardResolution {
  final DashboardAnswer answer;

  /// Every known obligation after [answer], ordered and never presentation-
  /// capped. A renderer may show two plus an explicit "N more" disclosure.
  final List<DashboardResolvedItem> otherActions;
  final DashboardJourneyResolution journey;

  /// Stable orientation and Family facts, source-aware independently.
  final DashboardStableState stableState;

  /// One compact stream of meaningful movement, newest first and capped.
  final List<DashboardResolvedItem> recently;

  /// Truth state for Updates, independently of Today and Insights.
  final DashboardSectionState updatesState;

  /// Rows retained after a failed refresh. The renderer must say that they are
  /// last-known and unavailable, never present them as fresh.
  final bool updatesAreLastKnown;

  /// Governed intelligence only. Production remains honestly empty until the
  /// Learning Loop gates are satisfied.
  final List<DashboardResolvedItem> intelligence;

  /// Truth state for Insights. Successful empty is an intended launch state;
  /// unavailable must render a retry state instead.
  final DashboardSectionState insightsState;

  final DashboardTone tone;
  final DashboardSourceHealth sourceHealth;

  DashboardResolution({
    required this.answer,
    required List<DashboardResolvedItem> otherActions,
    required this.journey,
    required this.stableState,
    required List<DashboardResolvedItem> recently,
    required this.updatesState,
    this.updatesAreLastKnown = false,
    required List<DashboardResolvedItem> intelligence,
    required this.insightsState,
    required this.tone,
    required this.sourceHealth,
  }) : otherActions = List.unmodifiable(otherActions),
       recently = List.unmodifiable(recently),
       intelligence = List.unmodifiable(intelligence);

  /// Compatibility bridge for the developer Lab while its renderers move to
  /// the six-level Home contract. New production code uses [recently] and
  /// [intelligence] explicitly.
  List<DashboardResolvedItem> get worthKnowing => List.unmodifiable(
    <DashboardResolvedItem>[...recently, ...intelligence].take(3),
  );

  DashboardResolution retainUpdatesFrom(DashboardResolution previous) {
    if (updatesState != DashboardSectionState.unavailable ||
        previous.recently.isEmpty) {
      return this;
    }
    return DashboardResolution(
      answer: answer,
      otherActions: otherActions,
      journey: journey,
      stableState: stableState,
      recently: previous.recently,
      updatesState: updatesState,
      updatesAreLastKnown: true,
      intelligence: intelligence,
      insightsState: insightsState,
      tone: tone,
      sourceHealth: sourceHealth,
    );
  }
}

/// Deterministic, IO-free Dashboard resolver.
final class DashboardResolver {
  static const int recentlyLimit = 3;
  static const int intelligenceLimit = 3;

  /// Kept for older Lab/tests while they move to the named Home sections.
  static const int worthKnowingLimit = recentlyLimit;

  const DashboardResolver();

  DashboardResolution resolve(DashboardSnapshot snapshot) {
    final collected = <DashboardResolvedItem>[];
    _addSignals(
      collected,
      snapshot.onboarding,
      DashboardSignalSource.onboarding,
    );

    final journeyState = snapshot.journeys.valueOrNull;
    if (journeyState != null) {
      for (final signal in journeyState.signals) {
        collected.add(
          DashboardResolvedItem(
            signal: signal,
            source: DashboardSignalSource.journeys,
          ),
        );
      }
    }

    _addSignals(collected, snapshot.updates, DashboardSignalSource.updates);
    _addSignals(
      collected,
      snapshot.shepherdInvitations,
      DashboardSignalSource.shepherdInvitations,
    );
    _addSignals(collected, snapshot.insights, DashboardSignalSource.insights);

    final deduplicated = _deduplicate(collected);
    final obligations = [
      for (final item in deduplicated)
        if (item.signal.kind.isObligation) item,
    ]..sort(_compareItems);
    final recently = [
      for (final item in deduplicated)
        if (item.signal.kind == DashboardSignalKind.meaningfulMovement) item,
    ]..sort(_compareRecentItems);
    final intelligence = [
      for (final item in deduplicated)
        if (item.signal.kind == DashboardSignalKind.governedInsight) item,
    ]..sort(_compareRecentItems);
    final rankedNonObligations = <DashboardResolvedItem>[
      ...recently,
      ...intelligence,
    ]..sort(_compareItems);
    final calmAdvisories = [...?snapshot.advisories.valueOrNull]
      ..sort((left, right) => left.id.compareTo(right.id));

    final health = _sourceHealth(snapshot);
    final actionGap = _hasIncompleteActionSource(snapshot);
    final journey = _journeyResolution(snapshot.journeys);
    final recentOutput = recently.take(recentlyLimit).toList();
    final intelligenceOutput = intelligence.take(intelligenceLimit).toList();
    final updatesState = _sectionState([snapshot.updates.state]);
    final insightsState = _sectionState([snapshot.insights.state]);

    if (obligations.isNotEmpty) {
      return DashboardResolution(
        answer: DashboardAnswer.signal(obligations.first),
        otherActions: obligations.skip(1).toList(),
        journey: journey,
        stableState: snapshot.stableState,
        recently: recentOutput,
        updatesState: updatesState,
        intelligence: intelligenceOutput,
        insightsState: insightsState,
        tone: DashboardTone.needsYou,
        sourceHealth: health,
      );
    }

    if (actionGap) {
      final hasUnavailableActionSource = _actionSourceStates(
        snapshot,
      ).contains(DashboardSourceState.unavailable);
      return DashboardResolution(
        answer: hasUnavailableActionSource
            ? const DashboardAnswer.refreshRequired()
            : const DashboardAnswer.loading(),
        otherActions: const [],
        journey: journey,
        stableState: snapshot.stableState,
        recently: recentOutput,
        updatesState: updatesState,
        intelligence: intelligenceOutput,
        insightsState: insightsState,
        tone: DashboardTone.needsYou,
        sourceHealth: health,
      );
    }

    if (rankedNonObligations.isNotEmpty) {
      final selected = rankedNonObligations.first;
      return DashboardResolution(
        answer: DashboardAnswer.signal(selected),
        otherActions: const [],
        journey: journey,
        stableState: snapshot.stableState,
        // Today may summarize the leading item, but Updates and Insights are
        // complete destinations in their own right. Keep the item in its
        // canonical tab instead of making a one-item tab look empty.
        recently: recentOutput,
        updatesState: updatesState,
        intelligence: intelligenceOutput,
        insightsState: insightsState,
        tone: DashboardTone.moving,
        sourceHealth: health,
      );
    }

    return DashboardResolution(
      answer: calmAdvisories.isEmpty
          ? const DashboardAnswer.calm()
          : DashboardAnswer.calmAdvisory(calmAdvisories.first),
      otherActions: const [],
      journey: journey,
      stableState: snapshot.stableState,
      recently: recentOutput,
      updatesState: updatesState,
      intelligence: intelligenceOutput,
      insightsState: insightsState,
      tone: DashboardTone.calm,
      sourceHealth: health,
    );
  }

  static void _addSignals(
    List<DashboardResolvedItem> output,
    DashboardSource<List<DashboardSignal>> source,
    DashboardSignalSource origin,
  ) {
    final signals = source.valueOrNull;
    if (signals == null) return;
    for (final signal in signals) {
      output.add(DashboardResolvedItem(signal: signal, source: origin));
    }
  }

  /// One object may be visible through both its domain source and an unread
  /// notification. [DashboardSignal.id] is therefore globally stable and the
  /// highest-ranked representation wins.
  static List<DashboardResolvedItem> _deduplicate(
    List<DashboardResolvedItem> input,
  ) {
    final byId = <String, DashboardResolvedItem>{};
    for (final item in input) {
      final existing = byId[item.signal.id];
      if (existing == null || _compareItems(item, existing) < 0) {
        byId[item.signal.id] = item;
      }
    }
    return byId.values.toList();
  }

  static int _compareItems(
    DashboardResolvedItem left,
    DashboardResolvedItem right,
  ) {
    final classOrder = left.signal.kind.index.compareTo(
      right.signal.kind.index,
    );
    if (classOrder != 0) return classOrder;

    final dueOrder = _compareDates(left.signal.dueAt, right.signal.dueAt);
    if (dueOrder != 0) return dueOrder;

    // Oldest unresolved object wins an otherwise-equal tie. This prevents a
    // stream of newer same-class events from starving or churning the hero.
    final eventOrder = _compareDates(left.signal.eventAt, right.signal.eventAt);
    if (eventOrder != 0) return eventOrder;

    final idOrder = left.signal.id.compareTo(right.signal.id);
    if (idOrder != 0) return idOrder;
    return left.source.index.compareTo(right.source.index);
  }

  /// Movement reads newest first. Obligation ranking intentionally does the
  /// opposite within a class so an older unresolved action cannot starve;
  /// Recently is not an action queue and therefore uses recency semantics.
  static int _compareRecentItems(
    DashboardResolvedItem left,
    DashboardResolvedItem right,
  ) {
    final leftAt = left.signal.eventAt;
    final rightAt = right.signal.eventAt;
    if (leftAt != null && rightAt != null) {
      final order = rightAt.compareTo(leftAt);
      if (order != 0) return order;
    } else if (leftAt == null && rightAt != null) {
      return 1;
    } else if (leftAt != null && rightAt == null) {
      return -1;
    }
    final idOrder = left.signal.id.compareTo(right.signal.id);
    if (idOrder != 0) return idOrder;
    return left.source.index.compareTo(right.source.index);
  }

  static int _compareDates(DateTime? left, DateTime? right) {
    if (left == null && right == null) return 0;
    if (left == null) return 1;
    if (right == null) return -1;
    return left.compareTo(right);
  }

  static DashboardJourneyResolution _journeyResolution(
    DashboardSource<DashboardJourneyState> source,
  ) => switch (source.state) {
    DashboardSourceState.loading => const DashboardJourneyResolution.loading(),
    DashboardSourceState.unavailable =>
      const DashboardJourneyResolution.unavailable(),
    DashboardSourceState.available => DashboardJourneyResolution.available(
      source.valueOrNull!.summary,
    ),
  };

  static DashboardSourceHealth _sourceHealth(DashboardSnapshot snapshot) {
    final states = _allSourceStates(snapshot);
    if (states.every((state) => state == DashboardSourceState.available)) {
      return DashboardSourceHealth.complete;
    }
    if (states.every((state) => state == DashboardSourceState.unavailable)) {
      return DashboardSourceHealth.failed;
    }
    return DashboardSourceHealth.partial;
  }

  static DashboardSectionState _sectionState(
    List<DashboardSourceState> states,
  ) {
    if (states.every((state) => state == DashboardSourceState.available)) {
      return DashboardSectionState.available;
    }
    if (states.every((state) => state == DashboardSourceState.loading)) {
      return DashboardSectionState.loading;
    }
    if (states.every((state) => state == DashboardSourceState.unavailable)) {
      return DashboardSectionState.unavailable;
    }
    return DashboardSectionState.partial;
  }

  static bool _hasIncompleteActionSource(DashboardSnapshot snapshot) =>
      _actionSourceStates(
        snapshot,
      ).any((state) => state != DashboardSourceState.available);

  static List<DashboardSourceState> _actionSourceStates(
    DashboardSnapshot snapshot,
  ) => [
    snapshot.onboarding.state,
    snapshot.journeys.state,
    snapshot.updates.state,
    snapshot.shepherdInvitations.state,
  ];

  static List<DashboardSourceState> _allSourceStates(
    DashboardSnapshot snapshot,
  ) => [
    ..._actionSourceStates(snapshot),
    snapshot.insights.state,
    snapshot.advisories.state,
    snapshot.stableState.orientationItems.state,
    snapshot.stableState.family.state,
  ];
}
