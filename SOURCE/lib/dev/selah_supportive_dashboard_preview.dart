import 'package:flutter/foundation.dart';

import '../data/selah_journey_stages.dart';
import '../models/selah_dashboard_resolution.dart';
import '../models/selah_supportive_dashboard.dart';
import '../models/selah_journey_presentation.dart';
import '../services/selah_developer_access.dart';
import '../state/app_state.dart';

/// A stricter boundary than the pre-existing internal TestFlight tools.
/// Dashboard scenario samples are non-release only.
bool supportivePreviewAllowed({
  required bool isRelease,
  required bool developerAuthorized,
}) => !isRelease && developerAuthorized;

enum SupportivePreviewScenario {
  allClear('All clear'),
  oneAction('One leading action'),
  severalActions('Several actions'),
  noShepherd('No Shepherd connected'),
  paused('Journey paused'),
  changed('What Changed populated'),
  recentChanges('Recent changes together'),
  editorial('From SELAH populated'),
  allNow('All Now sections'),
  insightsEmpty('Insights honest-empty'),
  insightsPopulated('Insights samples'),
  failed('One source failed'),
  lastKnown('Last-known information'),
  loading('Loading'),
  insightsFailed('Insights unavailable'),
  statusExample('Selected status');

  final String label;
  const SupportivePreviewScenario(this.label);
}

enum SupportiveActionExample {
  shepherdRequest('Shepherd request'),
  journeyRequest('Journey request'),
  continuation('Continuation decision'),
  resumeRequest('Resume Journey request'),
  ending('Pause / ending decision'),
  familyReview('Assigned Family Review'),
  shepherdGate('Assigned Shepherd Gate'),
  payment('Payer membership problem');

  final String label;
  const SupportiveActionExample(this.label);
}

enum SupportiveStatusExample {
  noShepherd('No Shepherd'),
  paused('Paused Journey'),
  trialEnding('Trial ending soon'),
  grace('Membership in grace'),
  membershipEnding('Confirmed membership end'),
  invitationExpiry('Invitation expiry');

  final String label;
  const SupportiveStatusExample(this.label);
}

enum SupportiveChangeExample {
  started('Journey started'),
  paused('Journey paused'),
  resumed('Journey resumed'),
  ended('Journey ended'),
  stage('New Journey stage'),
  shepherdConnected('Shepherd connected'),
  mainChanged('Main Shepherd changed'),
  reviewCompleted('Family Review completed'),
  introduction('Introduction received');

  final String label;
  const SupportiveChangeExample(this.label);
}

enum SupportiveEditorialExample {
  productUpdate('Product update'),
  feature('Feature announcement'),
  newsletter('SELAH newsletter'),
  journeyGuide('Journey / Shepherd guide'),
  preparation('Marriage-preparation guide'),
  community('Community announcement'),
  maintenance('Planned maintenance'),
  supportedVersion('Supported-version notice');

  final String label;
  const SupportiveEditorialExample(this.label);
}

enum SupportiveInsightExample {
  all('All four supportive categories'),
  familyValues('Working · family values'),
  faith('Working · Faith — sensitive preview'),
  helpfulReflections('Working · helpful reflections'),
  familyInvolvement('Working · earlier family involvement'),
  completedJourneys('Pattern · completed Journeys'),
  pausedJourneys('Pattern · paused Journeys'),
  repeatedStage('Pattern · repeated ending stage'),
  reflectionTheme('Learned · communication pace'),
  personalisedGuide('Help · personalised guidance'),
  generalGuide('Help · general guidance');

  final String label;
  const SupportiveInsightExample(this.label);
}

enum SupportiveReflectionTopic {
  communication('Positive · Communication'),
  sharedValues('Positive · Shared values'),
  family('Positive · Family involvement'),
  pace('Positive · Pace'),
  clarity('Positive · Clarity'),
  locationEarlier('Different approach · Discuss location earlier'),
  familyEarlier('Different approach · Involve family earlier'),
  expectations('Different approach · Clarify expectations'),
  moreTime('Different approach · Take more time'),
  directCommunication('Different approach · Communicate more directly');

  final String label;
  const SupportiveReflectionTopic(this.label);
}

/// Session-only visual choices. This never changes AppState, an entitlement,
/// account data, notification read state, or the existing Shepherd scenarios.
class SupportiveDashboardPreview extends ChangeNotifier {
  SupportiveDashboardPreview._();
  static final instance = SupportiveDashboardPreview._();

  bool enabled = false;
  bool useCurrentSources = false;
  int tabIndex = 0;
  SupportivePreviewScenario scenario = SupportivePreviewScenario.allNow;
  SupportiveActionExample action = SupportiveActionExample.journeyRequest;
  SupportiveStatusExample status = SupportiveStatusExample.noShepherd;
  SupportiveChangeExample change = SupportiveChangeExample.resumed;
  SupportiveEditorialExample editorial =
      SupportiveEditorialExample.productUpdate;
  SupportiveInsightExample insight = SupportiveInsightExample.all;
  SupportiveReflectionTopic reflection = SupportiveReflectionTopic.pace;

  static bool get allowed => supportivePreviewAllowed(
    isRelease: kReleaseMode,
    developerAuthorized: SelahDeveloperAccess.canUseDeveloperTools,
  );

  void selectView(bool supportive) {
    if (!allowed) return;
    enabled = supportive;
    notifyListeners();
  }

  void selectSources(bool current) {
    if (!allowed) return;
    useCurrentSources = current;
    notifyListeners();
  }

  void selectTab(int value) {
    if (!allowed || value < 0 || value > 1) return;
    tabIndex = value;
    notifyListeners();
  }

  void selectScenario(SupportivePreviewScenario value) {
    if (!allowed) return;
    enabled = true;
    useCurrentSources = false;
    scenario = value;
    tabIndex = switch (value) {
      SupportivePreviewScenario.insightsEmpty ||
      SupportivePreviewScenario.insightsPopulated ||
      SupportivePreviewScenario.insightsFailed => 1,
      _ => 0,
    };
    notifyListeners();
  }

  void selectAction(SupportiveActionExample value) {
    if (!allowed) return;
    action = value;
    selectScenario(SupportivePreviewScenario.oneAction);
  }

  void selectStatus(SupportiveStatusExample value) {
    if (!allowed) return;
    status = value;
    selectScenario(SupportivePreviewScenario.statusExample);
  }

  void selectChange(SupportiveChangeExample value) {
    if (!allowed) return;
    change = value;
    selectScenario(SupportivePreviewScenario.changed);
  }

  void selectEditorial(SupportiveEditorialExample value) {
    if (!allowed) return;
    editorial = value;
    selectScenario(SupportivePreviewScenario.editorial);
  }

  void selectInsight(SupportiveInsightExample value) {
    if (!allowed) return;
    insight = value;
    selectScenario(SupportivePreviewScenario.insightsPopulated);
  }

  void selectReflection(SupportiveReflectionTopic value) {
    if (!allowed) return;
    reflection = value;
    insight = SupportiveInsightExample.reflectionTheme;
    selectScenario(SupportivePreviewScenario.insightsPopulated);
  }

  void reset() {
    enabled = false;
    useCurrentSources = false;
    tabIndex = 0;
    scenario = SupportivePreviewScenario.allNow;
    action = SupportiveActionExample.journeyRequest;
    status = SupportiveStatusExample.noShepherd;
    change = SupportiveChangeExample.resumed;
    editorial = SupportiveEditorialExample.productUpdate;
    insight = SupportiveInsightExample.all;
    reflection = SupportiveReflectionTopic.pace;
    notifyListeners();
  }

  SupportiveFixture get fixture => SupportiveDashboardFixtures.build(
    scenario,
    action: action,
    status: status,
    change: change,
    editorial: editorial,
    insight: insight,
    reflection: reflection,
    personalized: true,
    counterpartName: AppState.instance.gender == 'female' ? 'James' : 'Abigail',
  );
}

class SupportiveFixture {
  final DashboardResolution resolution;
  final List<SupportiveCard> cards;
  final int tabIndex;
  const SupportiveFixture(this.resolution, this.cards, this.tabIndex);
}

/// Named fictional objects, never real account IDs. No IO, writes or AI calls.
/// Existing resolver handles obligation priority, event ordering and health.
class SupportiveDashboardFixtures {
  static final clock = DateTime.utc(2026, 8, 30, 18);

  static SupportiveFixture build(
    SupportivePreviewScenario scenario, {
    SupportiveActionExample action = SupportiveActionExample.journeyRequest,
    SupportiveStatusExample status = SupportiveStatusExample.noShepherd,
    SupportiveChangeExample change = SupportiveChangeExample.resumed,
    SupportiveEditorialExample editorial =
        SupportiveEditorialExample.productUpdate,
    SupportiveInsightExample insight = SupportiveInsightExample.all,
    SupportiveReflectionTopic reflection = SupportiveReflectionTopic.pace,
    bool personalized = false,
    String counterpartName = 'James',
  }) {
    // Both entry and leaf fail closed; direct fixture callers get no samples.
    if (!SupportiveDashboardPreview.allowed) {
      const denied = DashboardFailure(
        code: 'preview_not_authorized',
        retryable: false,
      );
      return SupportiveFixture(
        const DashboardResolver().resolve(
          const DashboardSnapshot(
            role: DashboardRole.seeker,
            onboarding: DashboardSource.unavailable(denied),
            journeys: DashboardSource.unavailable(denied),
            updates: DashboardSource.unavailable(denied),
            shepherdInvitations: DashboardSource.unavailable(denied),
            insights: DashboardSource.unavailable(denied),
            advisories: DashboardSource.unavailable(denied),
            stableState: DashboardStableState(
              orientationItems: DashboardSource.unavailable(denied),
              family: DashboardSource.unavailable(denied),
            ),
          ),
        ),
        const [],
        0,
      );
    }
    final cards = <SupportiveCard>[];
    final person = personalized
        ? journeyCounterpartFirstName(counterpartName)
        : null;
    final actions = <DashboardSignal>[];
    final updates = <DashboardSignal>[];
    var journeyKind = DashboardJourneyKind.searching;
    var familyKind = DashboardFamilyKind.connected;
    var updateState = DashboardSourceState.available;
    var insightState = DashboardSourceState.available;
    if (scenario == SupportivePreviewScenario.oneAction ||
        scenario == SupportivePreviewScenario.allNow) {
      actions.add(_action(action, counterpartName: person));
    }
    if (scenario == SupportivePreviewScenario.severalActions) {
      actions.addAll(
        SupportiveActionExample.values.map(
          (value) => _action(value, counterpartName: person),
        ),
      );
    }
    if (scenario == SupportivePreviewScenario.noShepherd ||
        scenario == SupportivePreviewScenario.allNow) {
      familyKind = DashboardFamilyKind.notConnected;
    }
    if (scenario == SupportivePreviewScenario.paused) {
      journeyKind = DashboardJourneyKind.paused;
    }
    if (scenario == SupportivePreviewScenario.statusExample) {
      if (status == SupportiveStatusExample.noShepherd) {
        familyKind = DashboardFamilyKind.notConnected;
      } else if (status == SupportiveStatusExample.paused) {
        journeyKind = DashboardJourneyKind.paused;
      } else {
        cards.add(_status(status));
      }
    }
    if (scenario == SupportivePreviewScenario.changed ||
        scenario == SupportivePreviewScenario.recentChanges ||
        scenario == SupportivePreviewScenario.allNow ||
        scenario == SupportivePreviewScenario.lastKnown) {
      updates.add(
        _change(
          scenario == SupportivePreviewScenario.recentChanges
              ? SupportiveChangeExample.resumed
              : change,
          clock.subtract(const Duration(hours: 2)),
          counterpartName: person,
        ),
      );
      if (scenario != SupportivePreviewScenario.changed) {
        updates.add(
          _change(
            SupportiveChangeExample.mainChanged,
            clock.subtract(const Duration(days: 1)),
            counterpartName: person,
          ),
        );
        updates.add(
          _change(
            SupportiveChangeExample.reviewCompleted,
            clock.subtract(const Duration(days: 2)),
            counterpartName: person,
          ),
        );
      }
    }
    if (scenario == SupportivePreviewScenario.editorial ||
        scenario == SupportivePreviewScenario.allNow) {
      cards.add(_editorial(editorial));
    }
    if (scenario == SupportivePreviewScenario.insightsPopulated) {
      cards.addAll(_insights(insight, reflection));
    }
    if (scenario == SupportivePreviewScenario.failed ||
        scenario == SupportivePreviewScenario.lastKnown) {
      updateState = DashboardSourceState.unavailable;
    }
    if (scenario == SupportivePreviewScenario.loading) {
      updateState = DashboardSourceState.loading;
    }
    if (scenario == SupportivePreviewScenario.insightsFailed) {
      insightState = DashboardSourceState.unavailable;
    }
    final snapshot = _snapshot(
      actions: actions,
      updates: updates,
      journeyKind: journeyKind,
      familyKind: familyKind,
      updateState: updateState,
      insightState: insightState,
      counterpartName: person,
    );
    var resolution = const DashboardResolver().resolve(snapshot);
    if (scenario == SupportivePreviewScenario.lastKnown) {
      resolution = resolution.retainUpdatesFrom(
        const DashboardResolver().resolve(
          _snapshot(updates: updates, counterpartName: person),
        ),
      );
    }
    return SupportiveFixture(
      resolution,
      List.unmodifiable(cards),
      switch (scenario) {
        SupportivePreviewScenario.insightsEmpty ||
        SupportivePreviewScenario.insightsPopulated ||
        SupportivePreviewScenario.insightsFailed => 1,
        _ => 0,
      },
    );
  }

  static DashboardSnapshot _snapshot({
    List<DashboardSignal> actions = const [],
    List<DashboardSignal> updates = const [],
    DashboardJourneyKind journeyKind = DashboardJourneyKind.searching,
    DashboardFamilyKind familyKind = DashboardFamilyKind.connected,
    DashboardSourceState updateState = DashboardSourceState.available,
    DashboardSourceState insightState = DashboardSourceState.available,
    String? counterpartName,
  }) => DashboardSnapshot(
    role: DashboardRole.seeker,
    onboarding: const DashboardSource.available([]),
    journeys: DashboardSource.available(
      DashboardJourneyState(
        summary: DashboardJourneySummary(
          id: 'preview:journey',
          kind: journeyKind,
          title: journeyKind == DashboardJourneyKind.paused
              ? journeyPresentationTitle(
                  JourneyPresentationKind.paused,
                  counterpartFirstName: counterpartName,
                )
              : 'Your Journey',
        ),
        signals: actions,
      ),
    ),
    updates: switch (updateState) {
      DashboardSourceState.available => DashboardSource.available(updates),
      DashboardSourceState.loading => const DashboardSource.loading(),
      DashboardSourceState.unavailable => const DashboardSource.unavailable(
        DashboardFailure(code: 'preview_updates_unavailable'),
      ),
    },
    shepherdInvitations: const DashboardSource.available([]),
    insights: insightState == DashboardSourceState.unavailable
        ? const DashboardSource.unavailable(
            DashboardFailure(code: 'preview_insights_unavailable'),
          )
        : const DashboardSource.available([]),
    stableState: DashboardStableState(
      family: DashboardSource.available(
        DashboardFamilyStatus(kind: familyKind, title: 'Shepherd connection'),
      ),
    ),
  );

  static DashboardSignal _action(
    SupportiveActionExample value, {
    String? counterpartName,
  }) => DashboardSignal(
    id: value == SupportiveActionExample.payment
        ? 'preview:membership'
        : 'preview:action:${value.name}',
    kind: value == SupportiveActionExample.shepherdGate
        ? DashboardSignalKind.blockingGate
        : DashboardSignalKind.addressedDecision,
    title: switch (value) {
      SupportiveActionExample.shepherdRequest =>
        'A Shepherd request is waiting',
      SupportiveActionExample.journeyRequest =>
        counterpartName == null
            ? 'A Journey decision is waiting'
            : journeyPresentationTitle(
                JourneyPresentationKind.startRequest,
                counterpartFirstName: counterpartName,
                actor: JourneyRequestActor.counterpart,
              ),
      SupportiveActionExample.continuation =>
        counterpartName == null
            ? 'Your Journey is ready for you'
            : journeyPresentationTitle(
                JourneyPresentationKind.continueRequest,
                counterpartFirstName: counterpartName,
                actor: JourneyRequestActor.counterpart,
              ),
      SupportiveActionExample.resumeRequest => journeyPresentationTitle(
        JourneyPresentationKind.resumeRequest,
        counterpartFirstName: counterpartName,
        actor: JourneyRequestActor.counterpart,
      ),
      SupportiveActionExample.ending =>
        counterpartName == null
            ? 'A Journey decision needs your review'
            : journeyPresentationTitle(
                JourneyPresentationKind.endRequest,
                counterpartFirstName: counterpartName,
                actor: JourneyRequestActor.counterpart,
              ),
      SupportiveActionExample.familyReview => 'Your Family Review needs you',
      SupportiveActionExample.shepherdGate =>
        'A Shepherd Gate needs your attention',
      SupportiveActionExample.payment => 'Your membership needs attention',
    },
    detail: switch (value) {
      SupportiveActionExample.shepherdRequest =>
        'Review the request on your Shepherd page.',
      SupportiveActionExample.payment =>
        'Review the payment issue in Membership. This example is for the authorised payer.',
      SupportiveActionExample.familyReview ||
      SupportiveActionExample.shepherdGate =>
        'An assignment example only. The live service must confirm that this action belongs to you.',
      _ => 'Review the request in Connections.',
    },
    target: value == SupportiveActionExample.shepherdRequest
        ? SelahDashboardTarget.shepherd
        : value == SupportiveActionExample.payment
        ? SelahDashboardTarget.none
        : SelahDashboardTarget.connectionsJourneys,
    actionLabel: value == SupportiveActionExample.payment
        ? 'View membership'
        : value == SupportiveActionExample.shepherdRequest
        ? 'View request'
        : 'View Journey',
    eventAt: clock.subtract(Duration(hours: value.index + 1)),
  );

  static SupportiveCard _status(
    SupportiveStatusExample value,
  ) => SupportiveCard(
    id: value == SupportiveStatusExample.invitationExpiry
        ? 'preview:invitation'
        : 'preview:membership',
    section: SupportiveSection.stand,
    title: switch (value) {
      SupportiveStatusExample.trialEnding => 'Your trial ends soon',
      SupportiveStatusExample.grace => 'Your membership is in its grace period',
      SupportiveStatusExample.membershipEnding =>
        'Your membership has an end date',
      _ => 'Your invitation expires soon',
    },
    detail: value == SupportiveStatusExample.invitationExpiry
        ? 'This example invitation expires on 1 September 2026.'
        : 'Example only · confirmed date: 1 September 2026. No trial or payment is activated.',
    date: DateTime.utc(2026, 9, 1, 18),
    actionLabel: value == SupportiveStatusExample.invitationExpiry
        ? 'Go to Shepherd'
        : 'View membership',
    target: value == SupportiveStatusExample.invitationExpiry
        ? SelahDashboardTarget.shepherd
        : SelahDashboardTarget.none,
    ownerLabel: value == SupportiveStatusExample.invitationExpiry
        ? 'Shepherd'
        : 'Membership',
  );

  static DashboardSignal _change(
    SupportiveChangeExample value,
    DateTime date, {
    String? counterpartName,
  }) => DashboardSignal(
    id: 'preview:change:${value.name}',
    kind: DashboardSignalKind.meaningfulMovement,
    title: counterpartName == null
        ? (value == SupportiveChangeExample.stage
              ? 'Reached ${SelahJourneyStages.labelFor('phase_1')}'
              : value.label)
        : switch (value) {
            SupportiveChangeExample.started => journeyPresentationTitle(
              JourneyPresentationKind.started,
              counterpartFirstName: counterpartName,
            ),
            SupportiveChangeExample.paused => journeyPresentationTitle(
              JourneyPresentationKind.paused,
              counterpartFirstName: counterpartName,
            ),
            SupportiveChangeExample.resumed => journeyPresentationTitle(
              JourneyPresentationKind.resumed,
              counterpartFirstName: counterpartName,
            ),
            SupportiveChangeExample.ended => journeyPresentationTitle(
              JourneyPresentationKind.ended,
              counterpartFirstName: counterpartName,
            ),
            SupportiveChangeExample.stage =>
              'Your Journey with $counterpartName reached ${SelahJourneyStages.labelFor('phase_1')}',
            SupportiveChangeExample.reviewCompleted =>
              'Family Review for your Journey with $counterpartName is complete',
            _ => value.label,
          },
    target: switch (value) {
      SupportiveChangeExample.shepherdConnected ||
      SupportiveChangeExample.mainChanged => SelahDashboardTarget.shepherd,
      SupportiveChangeExample.introduction =>
        SelahDashboardTarget.connectionsActivity,
      _ => SelahDashboardTarget.connectionsJourneys,
    },
    eventAt: date,
    isUnread: value == SupportiveChangeExample.introduction ? true : null,
  );

  static SupportiveCard _editorial(
    SupportiveEditorialExample value,
  ) => SupportiveCard(
    id: 'preview:editorial:${value.name}',
    section: SupportiveSection.fromSelah,
    title: switch (value) {
      SupportiveEditorialExample.productUpdate =>
        'A calmer home for your Journey',
      SupportiveEditorialExample.feature =>
        'A little more support, in one place',
      SupportiveEditorialExample.newsletter => 'A letter from Selah',
      SupportiveEditorialExample.journeyGuide =>
        'Starting the family conversation',
      SupportiveEditorialExample.preparation =>
        'Preparing for a thoughtful conversation',
      SupportiveEditorialExample.community => 'From our community',
      SupportiveEditorialExample.maintenance =>
        'A planned moment of maintenance',
      SupportiveEditorialExample.supportedVersion =>
        'Keeping your app up to date',
    },
    detail:
        '${value.label} · A short editorial preview would live here. This is a design example, not a published announcement.',
    date: clock.subtract(const Duration(days: 1)),
    actionLabel: 'Read more',
    ownerLabel: 'Published article',
  );

  static List<SupportiveCard> _insights(
    SupportiveInsightExample value,
    SupportiveReflectionTopic reflection,
  ) {
    if (value == SupportiveInsightExample.all) {
      return [
        ..._insights(SupportiveInsightExample.familyValues, reflection),
        ..._insights(SupportiveInsightExample.completedJourneys, reflection),
        ..._insights(SupportiveInsightExample.reflectionTheme, reflection),
        ..._insights(SupportiveInsightExample.personalisedGuide, reflection),
        ..._insights(SupportiveInsightExample.generalGuide, reflection),
      ];
    }
    final section = switch (value) {
      SupportiveInsightExample.familyValues ||
      SupportiveInsightExample.faith ||
      SupportiveInsightExample.helpfulReflections ||
      SupportiveInsightExample.familyInvolvement => SupportiveSection.working,
      SupportiveInsightExample.completedJourneys ||
      SupportiveInsightExample.pausedJourneys ||
      SupportiveInsightExample.repeatedStage => SupportiveSection.repeating,
      SupportiveInsightExample.reflectionTheme => SupportiveSection.learned,
      _ => SupportiveSection.help,
    };
    final title = switch (value) {
      SupportiveInsightExample.familyValues =>
        'Family values have been a consistent area of alignment across your recent Journeys.',
      SupportiveInsightExample.faith =>
        'Faith has been a recurring area of alignment.',
      SupportiveInsightExample.helpfulReflections =>
        'Clear communication appears in reflections about what helped you.',
      SupportiveInsightExample.familyInvolvement =>
        'You recorded that involving family earlier was helpful.',
      SupportiveInsightExample.completedJourneys =>
        'Of your five completed Journeys in the last 12 months, three ended at ${SelahJourneyStages.labelFor('compatibility_reveal')}.',
      SupportiveInsightExample.pausedJourneys =>
        'Two of five completed Journeys were paused during ${SelahJourneyStages.labelFor('family_stage')}.',
      SupportiveInsightExample.repeatedStage =>
        'Three of five completed Journeys ended at ${SelahJourneyStages.labelFor('phase_1')}.',
      SupportiveInsightExample.reflectionTheme =>
        reflection == SupportiveReflectionTopic.pace
            ? 'Communication pace has appeared in several reflections you chose to record.'
            : '“${reflection.label.split(' · ').last}” appeared in reflections you chose to record.',
      SupportiveInsightExample.personalisedGuide =>
        'You may find it useful to discuss communication expectations earlier.',
      SupportiveInsightExample.generalGuide =>
        'Questions worth discussing before Family Review',
      SupportiveInsightExample.all => '',
    };
    return [
      SupportiveCard(
        id: 'preview:insight:${value.name}:${reflection.name}',
        section: section,
        title: title,
        detail: value == SupportiveInsightExample.generalGuide
            ? 'Marriage preparation · general guidance, not a personal finding.'
            : value == SupportiveInsightExample.personalisedGuide
            ? 'Communication expectations appeared in three example reflections.'
            : null,
        isGeneralGuide: value == SupportiveInsightExample.generalGuide,
        actionLabel: value == SupportiveInsightExample.generalGuide
            ? 'Read guide'
            : null,
        ownerLabel: value == SupportiveInsightExample.generalGuide
            ? 'Guide'
            : 'Private reflection',
        evidence: SupportiveEvidence(
          summary: section == SupportiveSection.repeating
              ? 'Five fictional completed Journeys; active Journeys excluded.'
              : 'Fictional examples only; no account history was read or analysed.',
          period: '31 August 2025 – 30 August 2026 · frozen preview period',
          reason: 'Shown only to review the ${section.label} card design.',
          limitation:
              value == SupportiveInsightExample.faith ||
                  value == SupportiveInsightExample.familyValues
              ? 'Category history is unavailable. Sensitive processing is not authorised. This is not a real Insight.'
              : 'Not a personal finding. Ending earlier is not failure, and a pattern does not explain its cause.',
        ),
      ),
    ];
  }
}
