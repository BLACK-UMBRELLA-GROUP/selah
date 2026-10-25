import '../data/selah_journey_stages.dart';
import '../models/journey_match.dart';
import '../models/selah_dashboard_resolution.dart';
import '../models/selah_journey_presentation.dart';
import 'selah_journey_service.dart';
import 'selah_match_service.dart';
import 'selah_notification_service.dart';
import 'selah_dashboard_updates_service.dart';
import 'selah_profile_service.dart';
import 'selah_mentor_link_service.dart';

/// Production Seeker adapter for the pure Dashboard resolver.
///
/// This is the only layer that knows about Supabase-backed services. It turns
/// every read into an explicit [DashboardSource] before the resolver sees it,
/// preserving successful empty values and refusing to paint failures as calm.
class SelahSeekerDashboardAdapter {
  const SelahSeekerDashboardAdapter();

  Future<DashboardSnapshot> load() async {
    // Start independent reads together. No surface is expected to hydrate
    // AppState first, so cold launch and returning from another tab are equal.
    final onboardingFuture = SelahProfileService.fetchOnboardingProgress();
    final journeysFuture = SelahJourneyService.fetchJourneyMatches(
      statuses: const ['potential', 'active', 'ended'],
    );
    final updatesFuture = SelahDashboardUpdatesService.fetchPage();
    final unreadCountFuture = SelahNotificationService.fetchUnreadCount();
    final invitationsFuture = SelahMentorLinkService.fetchPendingInvitesResult();
    final linksFuture = SelahMentorLinkService.fetchLinkedPeopleResult(
      asMentor: false,
    );

    // Attach one aggregate listener immediately. Awaiting these one by one can
    // leave a later synchronous SDK failure temporarily unhandled while an
    // earlier request is still in flight (notably in isolated widget tests).
    final reads = await Future.wait<Object?>([
      onboardingFuture,
      journeysFuture,
      updatesFuture,
      invitationsFuture,
      linksFuture,
      unreadCountFuture,
    ]);
    final onboarding = reads[0] as SelahOnboardingProgress?;
    final journeys = reads[1] as List<JourneyMatch>?;
    final updates = reads[2] as SelahDashboardUpdatesPage?;
    final invitations = reads[3] as SelahSourceResult<List<PendingInvite>>;
    final links = reads[4] as SelahSourceResult<List<MentorLinkedPerson>>;
    final unreadCount = reads[5] as int?;
    final journeyMilestones = await _fetchProvenMilestones(journeys);

    return buildSnapshot(
      onboarding: onboarding == null
          ? const DashboardSource.unavailable(
              DashboardFailure(code: 'onboarding_unavailable'),
            )
          : DashboardSource.available(onboarding),
      journeys: journeys == null
          ? const DashboardSource.unavailable(
              DashboardFailure(code: 'journeys_unavailable'),
            )
          : DashboardSource.available(journeys),
      updates: updates == null
          ? const DashboardSource.unavailable(
              DashboardFailure(code: 'updates_unavailable'),
            )
          : DashboardSource.available(
              updatesForJourneys(updates.rows, journeys: journeys),
            ),
      shepherdInvitations: _mentorSource(invitations),
      linkedPeople: _mentorSource(links),
      unreadCount: unreadCount == null
          ? const DashboardSource.unavailable(
              DashboardFailure(code: 'unread_count_unavailable'),
            )
          : DashboardSource.available(unreadCount),
      journeyMilestones: journeyMilestones,
    );
  }

  /// Pure client projection: identity comes only from the same load's existing
  /// authorised Journey rows. Missing, mock or ambiguous matches stay unnamed.
  /// The Updates contract contains no actor, so these titles never attribute
  /// a request or a completed action to either person.
  static List<DashboardSignal> updatesForJourneys(
    List<SelahDashboardUpdate> updates, {
    required List<JourneyMatch>? journeys,
  }) {
    final names = <String, String?>{};
    final seenMatchIds = <String>{};
    for (final journey in journeys ?? const <JourneyMatch>[]) {
      if (!seenMatchIds.add(journey.matchId)) {
        names[journey.matchId] = null;
        continue;
      }
      names[journey.matchId] = journey.isMock
          ? null
          : journeyCounterpartFirstName(journey.profile.firstName);
    }
    return [
      for (final update in updates)
        _personalisedJourneyUpdate(update, names[update.relatedMatchId]),
    ];
  }

  static DashboardSignal _personalisedJourneyUpdate(
    SelahDashboardUpdate update,
    String? name,
  ) {
    final signal = update.toDashboardSignal();
    // Match the complete known key tuple. A name must never bypass the closed
    // renderer or turn an unknown/contradictory event into a lifecycle claim.
    final kind = switch ((
      update.classKey,
      update.titleKey,
      update.detailKey,
      update.destinationKey,
    )) {
      (
        'notification.journey_request',
        'dashboard_updates.notification.journey_request.title',
        'dashboard_updates.notification.journey_request.detail',
        'notifications',
      ) =>
        JourneyPresentationKind.startRequest,
      (
        'notification.journey_request_declined',
        'dashboard_updates.notification.journey_request_declined.title',
        'dashboard_updates.notification.journey_request_declined.detail',
        'notifications',
      ) =>
        JourneyPresentationKind.requestDeclined,
      (
        'notification.journey_also_paused',
        'dashboard_updates.notification.journey_also_paused.title',
        'dashboard_updates.notification.journey_also_paused.detail',
        'notifications',
      ) =>
        JourneyPresentationKind.paused,
      (
        'journey.timeline_milestone',
        'dashboard_updates.journey.timeline_milestone.title',
        'dashboard_updates.journey.timeline_milestone.journey_started.detail',
        'connections.journeys',
      ) =>
        JourneyPresentationKind.started,
      (
        'journey.timeline_milestone',
        'dashboard_updates.journey.timeline_milestone.title',
        'dashboard_updates.journey.timeline_milestone.journey_continued.detail',
        'connections.journeys',
      ) =>
        JourneyPresentationKind.resumed,
      (
        'journey.timeline_milestone',
        'dashboard_updates.journey.timeline_milestone.title',
        'dashboard_updates.journey.timeline_milestone.journey_paused.detail',
        'connections.journeys',
      ) =>
        JourneyPresentationKind.paused,
      (
        'journey.timeline_milestone',
        'dashboard_updates.journey.timeline_milestone.title',
        'dashboard_updates.journey.timeline_milestone.journey_ended.detail',
        'connections.journeys',
      ) =>
        JourneyPresentationKind.ended,
      _ => null,
    };
    if (kind == null) return signal;
    final counterpart = journeyCounterpartFirstName(name);
    final journey = counterpart == null
        ? 'Your Journey'
        : 'Your Journey with $counterpart';
    final request = counterpart == null
        ? 'A Journey request'
        : 'A Journey request with $counterpart';
    // A recorded notification/milestone is history, not proof that the request
    // is still pending or the Journey still occupies its recorded state.
    final title = switch (kind) {
      JourneyPresentationKind.startRequest => '$request was received',
      JourneyPresentationKind.requestDeclined => '$request was declined',
      JourneyPresentationKind.paused => '$journey was paused',
      _ => journeyPresentationTitle(kind, counterpartFirstName: counterpart),
    };
    final detail = switch (kind) {
      JourneyPresentationKind.startRequest =>
        'This update records the request. Check Connections for its current status.',
      JourneyPresentationKind.requestDeclined =>
        'The Journey request was declined.',
      JourneyPresentationKind.paused =>
        'A pause was recorded for this Journey.',
      _ => signal.detail,
    };
    return DashboardSignal(
      id: signal.id,
      kind: signal.kind,
      title: title,
      detail: detail,
      actionLabel: signal.actionLabel,
      target: signal.target,
      dueAt: signal.dueAt,
      eventAt: signal.eventAt,
      isUnread: signal.isUnread,
    );
  }

  /// Timeline's legacy reader collapses failure and a true empty result. Only
  /// returned rows are therefore treated as proof; an empty list creates no
  /// latest-stage or momentum claim.
  static Future<List<SelahMilestone>> _fetchProvenMilestones(
    List<JourneyMatch>? rows,
  ) async {
    if (rows == null) return const [];

    JourneyMatch? chosen;
    for (final row in rows) {
      if (row.status == 'active' && !row.isSuspended) {
        chosen = row;
        break;
      }
    }
    if (chosen == null) {
      for (final row in rows) {
        if (row.status == 'active' && row.isSuspended) {
          chosen = row;
          break;
        }
      }
    }
    if (chosen == null) {
      final ended = rows.where((row) => row.status == 'ended').toList()
        ..sort((left, right) {
          final leftAt = left.endedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final rightAt =
              right.endedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return rightAt.compareTo(leftAt);
        });
      chosen = ended.isEmpty ? null : ended.first;
    }
    if (chosen == null || chosen.isMock) return const [];
    return SelahMatchService.fetchTimeline(chosen.profile.id);
  }

  /// IO-free mapping kept public for focused adapter and widget tests.
  static DashboardSnapshot buildSnapshot({
    required DashboardSource<SelahOnboardingProgress> onboarding,
    required DashboardSource<List<JourneyMatch>> journeys,
    required DashboardSource<List<DashboardSignal>> updates,
    required DashboardSource<List<PendingInvite>> shepherdInvitations,
    required DashboardSource<List<MentorLinkedPerson>> linkedPeople,
    DashboardSource<int> unreadCount = const DashboardSource.available(0),
    List<SelahMilestone> journeyMilestones = const [],
    int? savedProfiles,
    DateTime? now,
  }) {
    final resolvedNow = now ?? DateTime.now();
    final family = _familyStatus(
      linkedPeople,
      shepherdInvitations,
      resolvedNow,
    );
    return DashboardSnapshot(
      role: DashboardRole.seeker,
      onboarding: _onboardingSignals(onboarding),
      journeys: _journeyState(
        journeys,
        onboarding,
        journeyMilestones,
        resolvedNow,
      ),
      updates: updates,
      shepherdInvitations: _invitationSignals(shepherdInvitations),
      // inherited upstream action 259 P1: production learning remains inactive. An honest
      // successful empty source keeps the resolver stable without claiming an
      // insight or introducing plan gating.
      insights: const DashboardSource.available(<DashboardSignal>[]),
      // inherited decision 223: a calm deterministic state is not evidence for a
      // behavioural suggestion. Production therefore supplies no advisory.
      advisories: const DashboardSource.available(<DashboardAdvisory>[]),
      stableState: DashboardStableState(
        orientationItems: _orientationItems(
          journeys: journeys,
          unreadCount: unreadCount,
          family: family,
          savedProfiles: savedProfiles,
        ),
        family: family,
      ),
    );
  }

  static DashboardSource<T> _mentorSource<T>(SelahSourceResult<T> result) {
    final value = result.valueOrNull;
    if (result.isAvailable && value != null) {
      return DashboardSource.available(value);
    }
    return DashboardSource.unavailable(
      DashboardFailure(code: result.failure?.name ?? 'shepherd_unavailable'),
    );
  }

  static DashboardSource<List<DashboardSignal>> _onboardingSignals(
    DashboardSource<SelahOnboardingProgress> source,
  ) => switch (source.state) {
    DashboardSourceState.loading => const DashboardSource.loading(),
    DashboardSourceState.unavailable => DashboardSource.unavailable(
      source.failureOrNull!,
    ),
    DashboardSourceState.available => DashboardSource.available(
      _onboardingList(source.valueOrNull!),
    ),
  };

  static List<DashboardSignal> _onboardingList(
    SelahOnboardingProgress progress,
  ) {
    if (progress.complete) return const [];
    final title = !progress.hasChapter2
        ? 'Continue your profile'
        : progress.missing > 0
        ? '${progress.answered} of ${progress.due} answers saved'
        : 'Review your profile';
    return [
      DashboardSignal(
        id: 'onboarding-profile-gate',
        kind: DashboardSignalKind.blockingGate,
        title: title,
        detail:
            'Your profile stays hidden and Journeys remain locked until setup is complete.',
        actionLabel: 'Continue setup',
        target: SelahDashboardTarget.onboarding,
      ),
    ];
  }

  static DashboardSource<List<DashboardOrientationItem>> _orientationItems({
    required DashboardSource<List<JourneyMatch>> journeys,
    required DashboardSource<int> unreadCount,
    required DashboardSource<DashboardFamilyStatus> family,
    required int? savedProfiles,
  }) {
    if (journeys.state == DashboardSourceState.loading) {
      return const DashboardSource.loading();
    }
    if (journeys.state == DashboardSourceState.unavailable) {
      return DashboardSource.unavailable(journeys.failureOrNull!);
    }
    final items = <DashboardOrientationItem>[];
    final potentialCount = journeys.valueOrNull!
        .where((row) => row.status == 'potential')
        .length;
    if (potentialCount > 0) {
      items.add(
        DashboardOrientationItem(
          id: 'orientation-potentials',
          kind: DashboardOrientationKind.potentials,
          title: 'Potential Journeys',
          valueLabel: '$potentialCount',
          target: SelahDashboardTarget.connectionsJourneys,
          emphasis: DashboardOrientationEmphasis.primary,
        ),
      );
    }

    final familyValue = family.valueOrNull;
    if (familyValue != null) {
      final valueLabel = switch (familyValue.kind) {
        DashboardFamilyKind.connected => 'Connected',
        DashboardFamilyKind.invitationPending => 'Invitation pending',
        DashboardFamilyKind.notConnected => 'Not connected',
      };
      items.add(
        DashboardOrientationItem(
          id: 'orientation-shepherd',
          kind: DashboardOrientationKind.shepherd,
          title: 'Shepherd',
          valueLabel: valueLabel,
          detail: familyValue.kind == DashboardFamilyKind.connected
              ? familyValue.title
              : null,
          target: SelahDashboardTarget.shepherd,
          emphasis: DashboardOrientationEmphasis.primary,
        ),
      );
    }

    // Unread awareness belongs to the My SELAH nav badge and Now tab badge.
    // The update rows themselves are already below on this same surface, so a
    // second "Notifications" orientation item would be a circular route.

    // The production Saved read currently collapses failure and empty, so the
    // live adapter supplies null and makes no claim. Tests and a future
    // truth-preserving owner read may supply a proven positive count.
    if (savedProfiles != null && savedProfiles > 0) {
      items.add(
        DashboardOrientationItem(
          id: 'orientation-saved',
          kind: DashboardOrientationKind.saved,
          title: 'Saved',
          valueLabel: '$savedProfiles kept for later',
          target: SelahDashboardTarget.connectionsActivity,
          emphasis: DashboardOrientationEmphasis.quiet,
        ),
      );
    }

    return DashboardSource.available(items);
  }

  static DashboardSource<DashboardFamilyStatus> _familyStatus(
    DashboardSource<List<MentorLinkedPerson>> linkedPeople,
    DashboardSource<List<PendingInvite>> invitations,
    DateTime now,
  ) {
    if (linkedPeople.state == DashboardSourceState.loading) {
      return const DashboardSource.loading();
    }
    if (linkedPeople.state == DashboardSourceState.unavailable) {
      return DashboardSource.unavailable(linkedPeople.failureOrNull!);
    }

    final links = linkedPeople.valueOrNull!;
    final pending =
        invitations.valueOrNull == null
              ? <PendingInvite>[]
              : [...invitations.valueOrNull!]
          ..sort((left, right) {
            final leftExpiry = left.expiresAt ?? DateTime(9999);
            final rightExpiry = right.expiresAt ?? DateTime(9999);
            final byExpiry = leftExpiry.compareTo(rightExpiry);
            return byExpiry != 0
                ? byExpiry
                : left.createdAt.compareTo(right.createdAt);
          });

    if (links.isNotEmpty) {
      MentorLinkedPerson? main;
      for (final person in links) {
        if (person.isMain) {
          main = person;
          break;
        }
      }
      final named = main ?? links.first;
      // Family Home communicates the Shepherd's relationship, not identity.
      // If the relationship has not been recorded, remain neutral rather than
      // leaking or substituting the person's first name.
      final identity = named.relationshipLabel ?? 'Shepherd';
      final extra = pending.isEmpty
          ? null
          : '${pending.length} additional Shepherd ${pending.length == 1 ? 'invitation is' : 'invitations are'} pending.';
      if (main == null) {
        return DashboardSource.available(
          DashboardFamilyStatus(
            kind: DashboardFamilyKind.connected,
            title: 'Choose a Main Shepherd',
            detail:
                'Your Shepherds stay linked, but your Journey waits until '
                'you choose who leads.',
            actionLabel: 'Choose Main Shepherd',
            linkedCount: links.length,
            pendingInvitationCount: pending.length,
            expiresAt: pending.isEmpty ? null : pending.first.expiresAt,
          ),
        );
      }
      return DashboardSource.available(
        DashboardFamilyStatus(
          kind: DashboardFamilyKind.connected,
          title: '$identity · Shepherd connected',
          detail: extra,
          actionLabel: 'Manage Shepherds',
          linkedCount: links.length,
          pendingInvitationCount: pending.length,
          expiresAt: pending.isEmpty ? null : pending.first.expiresAt,
        ),
      );
    }

    if (invitations.state == DashboardSourceState.loading) {
      return const DashboardSource.loading();
    }
    if (invitations.state == DashboardSourceState.unavailable) {
      return DashboardSource.unavailable(invitations.failureOrNull!);
    }

    if (pending.isNotEmpty) {
      final first = pending.first;
      final days = first.expiresAt?.difference(now).inDays.clamp(0, 9999);
      final count = pending.length;
      final timing = count == 1
          ? days == null
                ? 'Awaiting a response.'
                : days == 0
                ? 'Awaiting a response · Expires today.'
                : 'Awaiting a response · $days ${days == 1 ? 'day' : 'days'} left.'
          : days == null
          ? 'Awaiting responses.'
          : days == 0
          ? 'Earliest invitation expires today.'
          : 'Earliest invitation expires in $days ${days == 1 ? 'day' : 'days'}.';
      return DashboardSource.available(
        DashboardFamilyStatus(
          kind: DashboardFamilyKind.invitationPending,
          title:
              '$count Shepherd ${count == 1 ? 'invitation' : 'invitations'} pending',
          detail: timing,
          actionLabel: 'Manage Shepherds',
          pendingInvitationCount: count,
          expiresAt: first.expiresAt,
        ),
      );
    }

    return const DashboardSource.available(
      DashboardFamilyStatus(
        kind: DashboardFamilyKind.notConnected,
        title: 'No Shepherd connected',
        detail: 'Add a Shepherd when you are ready.',
        actionLabel: 'Manage Shepherds',
      ),
    );
  }

  static DashboardSource<DashboardJourneyState> _journeyState(
    DashboardSource<List<JourneyMatch>> source,
    DashboardSource<SelahOnboardingProgress> onboarding,
    List<SelahMilestone> milestones,
    DateTime now,
  ) => switch (source.state) {
    DashboardSourceState.loading => const DashboardSource.loading(),
    DashboardSourceState.unavailable => DashboardSource.unavailable(
      source.failureOrNull!,
    ),
    DashboardSourceState.available => DashboardSource.available(
      _journeyStateFromRows(
        source.valueOrNull!,
        onboarding.valueOrNull,
        milestones,
        now,
      ),
    ),
  };

  static DashboardJourneyState _journeyStateFromRows(
    List<JourneyMatch> rows,
    SelahOnboardingProgress? onboarding,
    List<SelahMilestone> milestones,
    DateTime now,
  ) {
    JourneyMatch? firstWhere(bool Function(JourneyMatch value) test) {
      for (final value in rows) {
        if (test(value)) return value;
      }
      return null;
    }

    final active = firstWhere(
      (row) => row.status == 'active' && !row.isSuspended,
    );
    if (active != null) {
      final stage = SelahJourneyStages.of(active.journeyStage);
      final lines = _journeyLines(stage, milestones, now);
      final detail = stage == null
          ? 'This Journey is in progress.'
          : '${stage.label} · Stage ${stage.order} of ${SelahJourneyStages.count}';
      return DashboardJourneyState(
        summary: DashboardJourneySummary(
          id: 'journey-${active.matchId}',
          kind: DashboardJourneyKind.active,
          title: 'You & ${active.profile.firstName}',
          detail: detail,
          progress: stage == null
              ? null
              : stage.order / SelahJourneyStages.count,
          latestCompletedStage: lines.latestCompletedStage,
          nextMilestone: lines.nextMilestone,
          momentum: lines.momentum,
        ),
      );
    }

    final paused = firstWhere(
      (row) => row.status == 'active' && row.isSuspended,
    );
    if (paused != null) {
      final stage = SelahJourneyStages.of(paused.journeyStage);
      final lines = _journeyLines(stage, milestones, now);
      return DashboardJourneyState(
        summary: DashboardJourneySummary(
          id: 'journey-${paused.matchId}',
          kind: DashboardJourneyKind.paused,
          title: journeyPresentationTitle(
            JourneyPresentationKind.paused,
            counterpartFirstName: paused.isMock
                ? null
                : paused.profile.firstName,
          ),
          detail: stage == null ? 'Journey paused' : 'Paused · ${stage.label}',
          progress: stage == null
              ? null
              : stage.order / SelahJourneyStages.count,
          latestCompletedStage: lines.latestCompletedStage,
          nextMilestone: lines.nextMilestone,
          momentum: lines.momentum,
        ),
      );
    }

    final potentials = rows.where((row) => row.status == 'potential').toList();
    if (potentials.isNotEmpty) {
      return DashboardJourneyState(
        summary: DashboardJourneySummary(
          id: 'potential-journeys',
          kind: DashboardJourneyKind.potential,
          title:
              '${potentials.length} Potential ${potentials.length == 1 ? 'Journey' : 'Journeys'}',
          detail: 'Review each possibility at your own pace.',
        ),
      );
    }

    final ended = rows.where((row) => row.status == 'ended').toList()
      ..sort((left, right) {
        final leftDate = left.endedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final rightDate =
            right.endedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return rightDate.compareTo(leftDate);
      });
    if (ended.isNotEmpty) {
      final latest = ended.first;
      final stage = SelahJourneyStages.of(latest.journeyStage);
      final lines = _journeyLines(stage, milestones, now);
      return DashboardJourneyState(
        summary: DashboardJourneySummary(
          id: 'journey-${latest.matchId}',
          kind: DashboardJourneyKind.ended,
          title: 'Your Journey with ${latest.profile.firstName}',
          detail: 'This Journey has ended.',
          progress: 1,
          latestCompletedStage: lines.latestCompletedStage,
          nextMilestone: null,
          momentum: lines.momentum,
        ),
      );
    }

    final ready = onboarding?.complete == true;
    return DashboardJourneyState(
      summary: DashboardJourneySummary(
        id: 'journey-searching',
        kind: DashboardJourneyKind.searching,
        title: ready ? 'Ready for introductions' : 'Preparing your profile',
        detail: ready
            ? 'New introductions will appear when they are available.'
            : 'Complete setup before a Journey can begin.',
      ),
    );
  }

  static ({
    String? latestCompletedStage,
    String? nextMilestone,
    String? momentum,
  })
  _journeyLines(
    SelahJourneyStage? current,
    List<SelahMilestone> milestones,
    DateTime now,
  ) {
    final canonical = [
      for (final milestone in milestones)
        if (SelahJourneyStages.ofTimelineMilestone(milestone.type) case final s?)
          (stage: s, occurredAt: milestone.occurredAt),
    ]..sort((left, right) => right.occurredAt.compareTo(left.occurredAt));
    final latest = canonical.isEmpty ? null : canonical.first.stage;

    SelahJourneyStage? next;
    if (current != null) {
      final index = SelahJourneyStages.all.indexWhere(
        (stage) => stage.value == current.value,
      );
      if (index >= 0 && index + 1 < SelahJourneyStages.all.length) {
        next = SelahJourneyStages.all[index + 1];
      }
    }

    final movedThisWeek = milestones.any((milestone) {
      if (milestone.occurredAt.isAfter(now)) return false;
      return now.difference(milestone.occurredAt) <= const Duration(days: 7);
    });
    return (
      latestCompletedStage: latest == null
          ? null
          : 'Latest completed · ${latest.label}',
      nextMilestone: next == null ? null : 'Next · ${next.label}',
      momentum: movedThisWeek ? 'Your Journey moved forward this week.' : null,
    );
  }

  static DashboardSource<List<DashboardSignal>> _invitationSignals(
    DashboardSource<List<PendingInvite>> source,
  ) => switch (source.state) {
    DashboardSourceState.loading => const DashboardSource.loading(),
    DashboardSourceState.unavailable => DashboardSource.unavailable(
      source.failureOrNull!,
    ),
    // A sent/pending invitation is stable Family state, not fresh movement on
    // every reload. Keep this source for truthful calm gating while Family
    // carries its count and real expiry.
    DashboardSourceState.available => const DashboardSource.available([]),
  };
}
