import 'package:flutter/material.dart';

import '../theme/selah_colors.dart';

/// Five Founder-facing hierarchy experiments over one shared Dashboard state.
///
/// Option 1 is only the Lab reset state, not a selected production design. The
/// real Seeker and Shepherd Dashboards remain unchanged until the Founder
/// chooses a candidate and separately authorises promotion.
enum SelahDashboardConcept {
  nowJourneyYou(
    '1 · Now / Journey / You',
    'Three layers: what needs you, where your Journey stands, then useful personal context.',
  ),
  selahCompass(
    '2 · SELAH Compass',
    'One calm daily heading, a compact status board and supporting insight below.',
  ),
  journeyLens(
    '3 · Journey Lens',
    'Centres the active, potential, paused or searching state and arranges everything around it.',
  ),
  livingPriorities(
    '4 · Living Priorities',
    'Ranks one primary and two secondary priorities while folding quieter information away.',
  ),
  progressStory(
    '5 · Progress Story',
    'Explains where you are, what moved and what comes next as one concise narrative.',
  );

  final String label;
  final String rationale;
  const SelahDashboardConcept(this.label, this.rationale);
}

enum SelahDashboardAudiencePreview {
  current('Current account'),
  seeker('Seeker'),
  shepherd('Shepherd');

  final String label;
  const SelahDashboardAudiencePreview(this.label);
}

enum SelahDashboardRole { seeker, shepherd }

/// Semantic Dashboard sections shared by the preview and its developer tools.
///
/// Seeker and Shepherd have different four-tab structures. Keeping the names
/// and module ownership here means a developer control can never silently
/// drift away from the tab it is reviewing.
enum SelahDashboardSection { today, updates, insights }

List<SelahDashboardSection> selahDashboardSectionsFor(SelahDashboardRole role) =>
    switch (role) {
      SelahDashboardRole.seeker => const [
        SelahDashboardSection.today,
        SelahDashboardSection.updates,
        SelahDashboardSection.insights,
      ],
      SelahDashboardRole.shepherd => const [
        SelahDashboardSection.today,
        SelahDashboardSection.updates,
        SelahDashboardSection.insights,
      ],
    };

String selahDashboardSectionLabel(SelahDashboardSection section) =>
    switch (section) {
      SelahDashboardSection.today => 'Today',
      SelahDashboardSection.updates => 'Updates',
      SelahDashboardSection.insights => 'Insights',
    };

Set<SelahDashboardModule> selahDashboardModulesForSection({
  required SelahDashboardRole role,
  required SelahDashboardSection section,
}) => switch ((role, section)) {
  (SelahDashboardRole.seeker, SelahDashboardSection.today) => const {
    SelahDashboardModule.onboarding,
    SelahDashboardModule.nextStep,
    SelahDashboardModule.journey,
    SelahDashboardModule.discovery,
    SelahDashboardModule.family,
    SelahDashboardModule.saved,
    SelahDashboardModule.profile,
  },
  (SelahDashboardRole.seeker, SelahDashboardSection.updates) => const {
    SelahDashboardModule.activity,
    SelahDashboardModule.milestone,
  },
  (SelahDashboardRole.seeker, SelahDashboardSection.insights) => const {
    SelahDashboardModule.learning,
    SelahDashboardModule.compatibility,
  },
  (SelahDashboardRole.shepherd, SelahDashboardSection.today) => const {
    SelahDashboardModule.nextStep,
    SelahDashboardModule.family,
    SelahDashboardModule.network,
    SelahDashboardModule.seekers,
    SelahDashboardModule.journey,
    SelahDashboardModule.profile,
  },
  (SelahDashboardRole.shepherd, SelahDashboardSection.updates) => const {
    SelahDashboardModule.activity,
    SelahDashboardModule.milestone,
  },
  (SelahDashboardRole.shepherd, SelahDashboardSection.insights) => const {
    SelahDashboardModule.learning,
  },
};

enum SelahDashboardTab {
  now('Now'),
  insights('Insights');

  final String label;
  const SelahDashboardTab(this.label);
}

enum SelahSeekerDashboardTodayState {
  newSeeker('New Seeker'),
  noShepherd('No Shepherd'),
  shepherdConnected('Shepherd connected'),
  shepherdInvitationPending('Shepherd invitation pending'),
  noJourney('No Journey'),
  potentialJourneys('Potential Journeys'),
  activeJourney('Active Journey'),
  journeyPaused('Journey paused'),
  journeyDecisionPending('Journey decision pending'),
  recentMovement('Recent meaningful movement'),
  calm('Calm · nothing needs attention'),
  loading('Loading'),
  partialFailure('Partial failure'),
  fullFailure('Full failure');

  final String label;
  const SelahSeekerDashboardTodayState(this.label);
}

enum SelahShepherdDashboardTodayState {
  noSeekers('No linked Seekers'),
  oneSeeker('One linked Seeker'),
  multipleSeekers('Multiple linked Seekers'),
  mainShepherd('Main Shepherd'),
  additionalShepherd('Additional Shepherd'),
  noJourney('No Journey'),
  activeJourney('Active Journey'),
  pausedJourney('Paused Journey'),
  journeyDecisionPending('Journey awaiting decision'),
  familyReviewWaiting('Family Review waiting'),
  pendingInvitation('Pending invitation'),
  networkBasicLocked('Shepherd Network · No access'),
  networkPremiumActive('Shepherd Network · Shepherd access'),
  calm('Calm · nothing needs attention'),
  loading('Loading'),
  partialFailure('Partial failure'),
  fullFailure('Full failure');

  final String label;
  const SelahShepherdDashboardTodayState(this.label);
}

enum SelahDashboardUpdatesState {
  none('No updates'),
  oneInformational('One informational update'),
  oneActionable('One actionable update'),
  several('Several updates'),
  unread('Unread updates'),
  allRead('All read'),
  mixed('Mixed account / Journey / Shepherd');

  final String label;
  const SelahDashboardUpdatesState(this.label);
}

enum SelahSeekerDashboardInsightsState {
  insufficient('Insufficient data'),
  basic('Membership inactive insight preview'),
  one('SELAH One insight'),
  compatibility('Compatibility pattern'),
  discoveryHealth('Discovery Health'),
  preferenceReview('Preference review suggestion'),
  aiExplanation('DEV-only AI explanation');

  final String label;
  const SelahSeekerDashboardInsightsState(this.label);
}

enum SelahShepherdDashboardInsightsState {
  insufficient('Insufficient data'),
  familyProcess('Family-process insight'),
  multiSeeker('Multi-Seeker overview'),
  journeyPreparation('Journey preparation'),
  shepherdNetwork('Shepherd Network insight'),
  premium('Shepherd insight');

  final String label;
  const SelahShepherdDashboardInsightsState(this.label);
}

/// Explicit destinations owned by Dashboard content.
///
/// A module name is not a route: the same Journey module can mean Discovery
/// when no Journey exists, or the Journeys section of Connections once a
/// Potential/Active/Paused Journey exists. Keeping the destination beside the
/// rendered state prevents copy and navigation from drifting apart.
enum SelahDashboardDestination {
  discovery,
  connectionsJourneys,
  connectionsActivity,
  shepherd,
  notifications,
  profile,
  preferences,
  onboarding,
}

enum SelahDashboardActivityState {
  empty('Empty'),
  normal('Normal'),
  busy('Busy'),
  urgent('Urgent');

  final String label;
  const SelahDashboardActivityState(this.label);
}

enum SelahDashboardJourneyPreview {
  none('No active Journey'),
  potentials('Potential Journeys'),
  active('Active Journey'),
  paused('Paused Journey'),
  ended('Recently ended');

  final String label;
  const SelahDashboardJourneyPreview(this.label);
}

/// Eight stable developer presets from the Founder brief.
///
/// A preset stages only the mock adapter. It never changes a real profile,
/// Shepherd link, Journey, entitlement or invitation.
enum SelahDashboardContextPreset {
  newSeeker('A · New Seeker'),
  shepherdInvitation('B · Shepherd invitation'),
  potentialJourneys('C · Potential Journeys'),
  activeJourney('D · Active Journey'),
  activeWithShepherd('E · Journey + Shepherd'),
  decisionRequired('F · Decision required'),
  pausedJourney('G · Paused Journey'),
  selahOneInsights('H · SELAH One insights');

  final String label;
  const SelahDashboardContextPreset(this.label);
}

/// Founder-requested learning states for the developer Dashboard preview.
///
/// These describe UI examples only. They are not evidence thresholds and do
/// not activate any inference or preference mutation.
enum SelahDashboardInsightState {
  insufficientData('Not enough information'),
  positive('Positive pattern'),
  neutral('Neutral pattern'),
  preferenceReview('Preference review');

  final String label;
  const SelahDashboardInsightState(this.label);
}

enum SelahDashboardInsightPlan {
  basic('Membership inactive'),
  one('SELAH One');

  final String label;
  const SelahDashboardInsightPlan(this.label);
}

const String selahDashboardInsightsLabel = 'Insights for you';
const String selahDashboardInsightsHeading = 'INSIGHTS FOR YOU';

enum SelahDashboardModule {
  journey('Journey', Icons.route_outlined),
  onboarding('Profile setup', Icons.checklist_rounded),
  nextStep('Next step', Icons.arrow_forward_rounded),
  learning(selahDashboardInsightsLabel, Icons.auto_awesome_outlined),
  activity('New activity', Icons.auto_awesome_outlined),
  family('Family', Icons.diversity_3_outlined),
  discovery('Discovery', Icons.search_rounded),
  saved('Saved', Icons.bookmark_outline_rounded),
  compatibility('Compatibility', Icons.insights_outlined),
  profile('Profile readiness', Icons.person_outline_rounded),
  milestone('Milestone', Icons.verified_outlined),
  seekers('Seekers', Icons.people_outline_rounded),
  network('Shepherd Network', Icons.hub_outlined);

  final String label;
  final IconData icon;
  const SelahDashboardModule(this.label, this.icon);
}

const List<SelahDashboardModule> selahDashboardDefaultOrder = [
  SelahDashboardModule.journey,
  SelahDashboardModule.onboarding,
  SelahDashboardModule.nextStep,
  SelahDashboardModule.learning,
  SelahDashboardModule.activity,
  SelahDashboardModule.family,
  SelahDashboardModule.discovery,
  SelahDashboardModule.saved,
  SelahDashboardModule.compatibility,
  SelahDashboardModule.profile,
  SelahDashboardModule.milestone,
  SelahDashboardModule.seekers,
  SelahDashboardModule.network,
];

const Set<SelahDashboardModule> selahDashboardDefaultModules = {
  ...selahDashboardDefaultOrder,
};

SelahDashboardRole resolveDashboardRole({
  required SelahDashboardAudiencePreview preview,
  required SelahDashboardRole hostRole,
}) => switch (preview) {
  SelahDashboardAudiencePreview.current => hostRole,
  SelahDashboardAudiencePreview.seeker => SelahDashboardRole.seeker,
  SelahDashboardAudiencePreview.shepherd => SelahDashboardRole.shepherd,
};

class SelahDashboardViewConfig {
  final SelahDashboardConcept concept;
  final SelahDashboardRole role;
  final SelahAppSurfaceStyle surfaceStyle;
  final SelahDashboardActivityState activityState;
  final SelahDashboardJourneyPreview journeyPreview;
  final bool newActivity;
  final bool pendingApproval;
  final SelahDashboardInsightState insightState;
  final SelahDashboardInsightPlan insightPlan;
  final bool onboardingComplete;
  final int onboardingAnswered;
  final int onboardingTotal;
  final int familyProgress;
  final int supportedSeekers;
  final int potentialJourneys;
  final int savedProfiles;
  final bool hasShepherd;
  final bool shepherdActivity;
  final bool familyIntroductionActive;
  final SelahDashboardContextPreset? contextPreset;
  final Set<SelahDashboardModule> enabledModules;
  final List<SelahDashboardModule> moduleOrder;

  const SelahDashboardViewConfig({
    required this.concept,
    required this.role,
    required this.surfaceStyle,
    required this.activityState,
    required this.journeyPreview,
    required this.newActivity,
    required this.pendingApproval,
    required this.insightState,
    required this.insightPlan,
    required this.onboardingComplete,
    required this.onboardingAnswered,
    required this.onboardingTotal,
    required this.familyProgress,
    required this.supportedSeekers,
    this.potentialJourneys = 3,
    this.savedProfiles = 7,
    this.hasShepherd = true,
    this.shepherdActivity = false,
    this.familyIntroductionActive = false,
    this.contextPreset,
    required this.enabledModules,
    required this.moduleOrder,
  });
}
