// Developer scenario state — 2026-08-01.
//
// Founder: "make a toggle side button where I can select the options to
// see how it works."
//
// Why this is not a second copy of DeveloperAccess:
//
//   DeveloperAccessScreen switches ACCOUNT. It signs in as a real test
//   user. Heavy, correct, and the only way to exercise RLS or anything
//   server-side.
//
//   This switches STATE ON THE CURRENT ACCOUNT, live, without signing
//   out — for the axes that are orthogonal to which account you are.
//
// THE RULE FOR THIS FILE: a toggle must change something real. A switch
// that flips a bool nothing reads is worse than no switch, because it
// looks like the feature was checked. Every flag below names its reader.
//
// CONTEXT AWARENESS — 2026-08-03 (Founder: "let it only work on the
// correct page and correct user... if I try click it on a wrong area or
// wrong profile I need a red animation to show it can't. Maybe even start
// grouping the toggle section so it's easier for me to see").
//
// Every control now declares which plans it applies to and which page it
// affects. Out of context it is greyed and refuses, with a red shake,
// rather than appearing to work.
//
// That is not decoration. "Consider limit reached" is meaningless on SELAH
// One — Considers are unlimited there, so the cap it simulates does not
// exist and the modal it would trigger can never fire. Before this, that
// switch would happily flip and then nothing would happen, which reads
// exactly like a bug in the feature rather than a category error in the
// test.
//
// REBUILT 2026-08-12 (Founder-directed dev-panel redesign). Every simulated
// value is now a PRIVATE field behind a guarded setter: same-value writes do
// not notify, so re-tapping a segment no longer makes every listening screen
// re-fetch, and there is exactly one door into each piece of state. The
// generic set_() escape hatch is gone — it let callers mutate fields this
// class did not know were changing. Reset now covers EVERY axis,
// enumerated in one place, with one notify.

import 'package:flutter/foundation.dart';
import '../data/selah_entitlements.dart';
import '../data/selah_journey_pause_state.dart';
import '../data/selah_journey_stages.dart';
import '../models/journey_match.dart';
import '../models/seeker_profile.dart';
import '../models/selah_dashboard_lab.dart';
import '../models/selah_gender.dart';
import '../services/selah_auth.dart';
import '../services/selah_developer_access.dart';
import '../services/selah_mentor_journey_service.dart';
import '../services/selah_mentor_link_service.dart';
import '../state/app_state.dart' show SelahPlan;
import '../theme/selah_colors.dart';

/// Which Seeker plan a control makes sense for.
enum DevPlan { basic, one }

/// Which page a control affects. A control is only usable while that page
/// is the one on screen.
enum DevPage {
  browse,
  connections,
  dashboard,
  shepherd,
  profile,

  /// Pushed route context, not a root destination. This lets the app-wide
  /// developer control follow the live Journey instead of continuing to show
  /// the Connections controls underneath it.
  activeJourney,
}

/// Founder-facing Connections card presentation lab.
///
/// [compactChips] is the current testing default. The other five values are
/// live comparisons of the same actions and information; they never alter
/// Journey or profile state. Release builds continue to use [unifiedRail]
/// until the Founder selects a production direction.
enum SelahConnectionsCardStyle {
  unifiedRail,
  splitPills,
  iconDock,
  stackedRows,
  compactChips,
  framedGrid,
}

extension SelahConnectionsCardStyleX on SelahConnectionsCardStyle {
  String get label => switch (this) {
    SelahConnectionsCardStyle.unifiedRail => 'Unified rail',
    SelahConnectionsCardStyle.splitPills => 'Split pills',
    SelahConnectionsCardStyle.iconDock => 'Icon dock',
    SelahConnectionsCardStyle.stackedRows => 'Stacked rows',
    SelahConnectionsCardStyle.compactChips => 'Compact chips',
    SelahConnectionsCardStyle.framedGrid => 'Framed grid',
  };

  String get description => switch (this) {
    SelahConnectionsCardStyle.unifiedRail =>
      'Active Journey style: one primary action and a quiet action rail.',
    SelahConnectionsCardStyle.splitPills =>
      'Rounded two-column actions with a stronger button rhythm.',
    SelahConnectionsCardStyle.iconDock =>
      'Compact icon-and-label dock beneath the main action.',
    SelahConnectionsCardStyle.stackedRows =>
      'Calm full-width rows with clear direction cues.',
    SelahConnectionsCardStyle.compactChips =>
      'Three equal controls spanning the full card width.',
    SelahConnectionsCardStyle.framedGrid =>
      'Structured two-column cells inside one subtle frame.',
  };
}

/// Independent section-title comparisons for Active, Potential, Paused,
/// Ended, Considered, Saved and Passed. Introductions deliberately has no
/// repeated in-page title because the segment itself already names the page.
enum SelahConnectionsHeadingStyle {
  chapterLeft,
  titleLeft,
  centredRule,
  accentMarker,
  countSplit,
}

extension SelahConnectionsHeadingStyleX on SelahConnectionsHeadingStyle {
  String get label => switch (this) {
    SelahConnectionsHeadingStyle.chapterLeft => 'Chapter left',
    SelahConnectionsHeadingStyle.titleLeft => 'Title left',
    SelahConnectionsHeadingStyle.centredRule => 'Centred rule',
    SelahConnectionsHeadingStyle.accentMarker => 'Accent marker',
    SelahConnectionsHeadingStyle.countSplit => 'Right rule',
  };

  String get description => switch (this) {
    SelahConnectionsHeadingStyle.chapterLeft =>
      'Current compact uppercase chapter label.',
    SelahConnectionsHeadingStyle.titleLeft =>
      'Larger title-case heading aligned with the cards.',
    SelahConnectionsHeadingStyle.centredRule =>
      'Centred heading held between two quiet divider lines.',
    SelahConnectionsHeadingStyle.accentMarker =>
      'Left marker with a medium title and no numeric badge.',
    SelahConnectionsHeadingStyle.countSplit =>
      'Title on the left and a short quiet rule on the right.',
  };
}

/// Session-only visual comparisons for Browse's live swipe response.
///
/// [fullAura] is the current shipped/default response. The other ten are the
/// Founder-approved 3D photo-motion comparisons. They change presentation
/// only: the shared Browse policy still owns left=Consider, down=Save and
/// right=Pass, and no option adds action buttons or changes a decision write.
enum SelahBrowseSwipeFeedbackStyle {
  fullAura,
  layeredParallax,
  edgePeek,
  floatingDeck,
  carousel3d,
  doorHinge,
  pageCurl,
  depthTunnel,
  subjectSplit,
  magneticTilt,
  horizonLift,
}

extension SelahBrowseSwipeFeedbackStyleX on SelahBrowseSwipeFeedbackStyle {
  String get label => switch (this) {
    SelahBrowseSwipeFeedbackStyle.fullAura => 'Full aura',
    SelahBrowseSwipeFeedbackStyle.layeredParallax => '1 · Layered parallax',
    SelahBrowseSwipeFeedbackStyle.edgePeek => '2 · Edge peek',
    SelahBrowseSwipeFeedbackStyle.floatingDeck => '3 · Floating deck',
    SelahBrowseSwipeFeedbackStyle.carousel3d => '4 · 3D carousel',
    SelahBrowseSwipeFeedbackStyle.doorHinge => '5 · Door hinge',
    SelahBrowseSwipeFeedbackStyle.pageCurl => '6 · Page curl',
    SelahBrowseSwipeFeedbackStyle.depthTunnel => '7 · Depth tunnel',
    SelahBrowseSwipeFeedbackStyle.subjectSplit => '8 · Subject split',
    SelahBrowseSwipeFeedbackStyle.magneticTilt => '9 · Magnetic tilt',
    SelahBrowseSwipeFeedbackStyle.horizonLift => '10 · Horizon lift',
  };

  String get description => switch (this) {
    SelahBrowseSwipeFeedbackStyle.fullAura =>
      'Current default: traffic-light colour surrounds the full screen.',
    SelahBrowseSwipeFeedbackStyle.layeredParallax =>
      'Photo, identity and the next profile move at different depths.',
    SelahBrowseSwipeFeedbackStyle.edgePeek =>
      'The current profile clears quickly to expose the next profile edge.',
    SelahBrowseSwipeFeedbackStyle.floatingDeck =>
      'The active profile lifts above a stacked next-profile layer.',
    SelahBrowseSwipeFeedbackStyle.carousel3d =>
      'Profiles rotate through depth like a restrained 3D carousel.',
    SelahBrowseSwipeFeedbackStyle.doorHinge =>
      'The profile pivots from the opposite edge as the next one appears.',
    SelahBrowseSwipeFeedbackStyle.pageCurl =>
      'A softer perspective fold suggests turning to the next profile.',
    SelahBrowseSwipeFeedbackStyle.depthTunnel =>
      'The current profile recedes while the next profile comes forward.',
    SelahBrowseSwipeFeedbackStyle.subjectSplit =>
      'The profile and its identity details separate into layered motion.',
    SelahBrowseSwipeFeedbackStyle.magneticTilt =>
      'The profile is pulled towards the gesture with stronger 3D tilt.',
    SelahBrowseSwipeFeedbackStyle.horizonLift =>
      'The profile lifts forward while the next profile rises beneath it.',
  };

  String get groupLabel => switch (this) {
    SelahBrowseSwipeFeedbackStyle.fullAura => 'Current default',
    _ => '3D photo movement',
  };

  bool get movesPhoto => this != SelahBrowseSwipeFeedbackStyle.fullAura;

  bool get previewsNextProfile => movesPhoto;
}

/// The popups the panel can ask Browse to show. Each maps to a modal that
/// ALREADY EXISTS in browse_screen.dart — nothing here writes its own copy,
/// which was the complaint that produced this enum (Founder, 2026-08-05:
/// "please include the pop-ups that are on file, not create random ones").
///
///   saveLimit      -> _showCapReachedModal(action: 'Save', …)
///   considerLimit  -> _showCapReachedModal(action: 'Consider', …)
///   dailyLimit     -> _showLimitReachedModal()
enum DevPopup { saveLimit, considerLimit, dailyLimit }

extension DevPageX on DevPage {
  String get label => switch (this) {
    DevPage.browse => 'Browse',
    DevPage.connections => 'Connections',
    DevPage.dashboard => 'Dashboard',
    DevPage.shepherd => 'Shepherd',
    DevPage.profile => 'Profile',
    DevPage.activeJourney => 'Active Journey',
  };
}

// ═════════════════════════════════════════════════════════════════════
// THE SHEPHERD SIDE — added 2026-08-13 (inherited decision 152).
// ═════════════════════════════════════════════════════════════════════
//
// ONE STORE, NOT TWO. These enums and the "— Mentor side —" fields further
// down live in this class alongside the Seeker ones deliberately: one
// singleton, one reset(), one place a new field can be forgotten from.
// A second scenario store would have its own reset that drifts, which is
// the precise failure the 2026-08-12 rebuild was written to end.
//
// The panel that drives them is a separate WIDGET
// (dev/mentor_dev_scenario_panel.dart) because the two shells mount
// different trees — but it reads and writes this object.

/// Which Shepherd tab a control affects. The Shepherd shell's five tabs,
/// in nav-bar order (Network sits left of Seekers since 2026-08-13).
///
/// Pushed in by MentorHomeShell on every tab change, exactly as HomeShell
/// pushes [DevPage] — the panel is a sibling of the IndexedStack, not a
/// child, so it has no other way to know which tab is showing.
enum MentorPage { dashboard, network, seekers, notifications, profile }

extension MentorPageX on MentorPage {
  String get label => switch (this) {
    MentorPage.dashboard => 'Dashboard',
    MentorPage.network => 'Network',
    MentorPage.seekers => 'Seekers',
    MentorPage.notifications => 'Notifications',
    MentorPage.profile => 'Profile',
  };
}

/// Main Shepherd or Additional Shepherd.
///
/// NOT cosmetic, and this is why the Shepherd panel needed a refusal
/// path the Seeker panel had deleted. `mentor_links.is_main` is a real
/// privilege boundary (closed 2026-08-08, SHEPHERD & ROMANTIC RULES
/// §7d): selah_counterpart_card() returns nothing to an Additional
/// Shepherd, so SelahMentorJourneyService.fetchLinkedJourneys() skips the
/// row entirely, and mentor_review_decision() refuses their vote.
///
/// An Additional Shepherd therefore sees a SMALLER app, not a different
/// one — and the only way to learn that from a control panel is for the
/// controls they do not get to be VISIBLE and REFUSED. Hiding them, the
/// Seeker panel's rule, would make the whole distinction invisible.
enum MentorRole { main, additional }

extension MentorRoleX on MentorRole {
  String get label =>
      this == MentorRole.main ? 'Main Shepherd' : 'Additional Shepherd';
}

// The UnlockBalance enum and the `unlocks` / `unlockPlus` fields were
// REMOVED 2026-08-04. They held an in-memory credit count that the unlock
// screen read and the server knew nothing about, so once C-1 moved
// entitlement into the `unlock_credits` ledger the panel was setting a
// number with no bearing on whether an unlock would actually succeed — the
// screen said "5 left" and the RPC refused.
//
// Exactly the failure this file's own rule warns about: "a toggle must
// change something real. A switch that flips a bool nothing reads is worse
// than no switch, because it looks like the feature was checked."
//
// The panel now calls selah_debug_grant_credits() and grants real credits.

/// The three production Activity destinations available to a local test
/// profile. This state lives here rather than in [AppState]: developer-toggle
/// people must be able to move between real-looking cards without ever
/// becoming account decisions or reaching Supabase.
enum SelahActivityTestState { considered, saved, passed }

const String kSelahActivityTestProfilePrefix = 'selah-local-activity-preview-';
const String kSelahIntroductionTestProfilePrefix =
    'selah-local-introduction-preview-';

String selahActivityTestProfileId(SelahActivityTestState origin, int index) =>
    '$kSelahActivityTestProfilePrefix${origin.name}-$index';

String selahIntroductionTestProfileId(int index) =>
    '$kSelahIntroductionTestProfilePrefix$index';

class SelahDevScenario extends ChangeNotifier {
  SelahDevScenario._();
  static final SelahDevScenario instance = SelahDevScenario._();

  // --- Where the user currently is --------------------------------------
  // Written by HomeShell on every tab change. Read by the panel to decide
  // which controls are live.
  //
  // Deliberately pushed in rather than read out: the panel is a sibling of
  // the IndexedStack in HomeShell's Stack, not a child, so it has no other
  // way to know which tab is showing.

  DevPage currentPage = DevPage.browse;

  // ── DASHBOARD LAB — Founder comparison build, 2026-08-24 ────────────
  // One shared store serves both account shells. The role preview is an
  // override, not an account mutation; Current account is the honest default.
  // Every field is session-only and ignored unless developer access is live.
  bool _dashboardLabEnabled = true;
  SelahDashboardConcept _dashboardConcept = SelahDashboardConcept.nowJourneyYou;
  SelahDashboardContextPreset? _dashboardContextPreset =
      SelahDashboardContextPreset.activeJourney;
  SelahDashboardAudiencePreview _dashboardAudience =
      SelahDashboardAudiencePreview.current;
  SelahDashboardActivityState _dashboardActivityState =
      SelahDashboardActivityState.normal;
  SelahDashboardJourneyPreview _dashboardJourneyPreview =
      SelahDashboardJourneyPreview.active;
  bool _dashboardNewActivity = true;
  bool _dashboardPendingApproval = false;
  SelahDashboardInsightState _dashboardInsightState =
      SelahDashboardInsightState.positive;
  SelahDashboardInsightPlan _dashboardInsightPlan =
      SelahDashboardInsightPlan.basic;
  bool _dashboardLearningOnCurrentHub = true;
  bool _dashboardOnboardingComplete = false;
  int _dashboardOnboardingAnswered = 35;
  static const int dashboardOnboardingTotal = 68;
  int _dashboardFamilyProgress = 2;
  int _dashboardSupportedSeekers = 3;
  int _dashboardPotentialJourneys = 0;
  int _dashboardSavedProfiles = 2;
  bool _dashboardHasShepherd = true;
  bool _dashboardShepherdActivity = false;
  bool _dashboardFamilyIntroductionActive = false;
  SelahDashboardTab _dashboardTab = SelahDashboardTab.now;
  SelahSeekerDashboardTodayState _dashboardSeekerTodayState =
      SelahSeekerDashboardTodayState.calm;
  SelahShepherdDashboardTodayState _dashboardShepherdTodayState =
      SelahShepherdDashboardTodayState.noSeekers;
  SelahDashboardUpdatesState _dashboardUpdatesState =
      SelahDashboardUpdatesState.none;
  SelahSeekerDashboardInsightsState _dashboardSeekerInsightsState =
      SelahSeekerDashboardInsightsState.insufficient;
  SelahShepherdDashboardInsightsState _dashboardShepherdInsightsState =
      SelahShepherdDashboardInsightsState.insufficient;
  bool _dashboardShepherdPremium = false;
  bool _dashboardShepherdNowOptionSelected = false;
  bool _dashboardShepherdInsightsOptionSelected = false;
  bool _dashboardShepherdJourneyDecisionPending = false;
  final Set<SelahDashboardModule> _dashboardModules = {
    ...selahDashboardDefaultModules,
  };
  final List<SelahDashboardModule> _dashboardOrder = [
    ...selahDashboardDefaultOrder,
  ];

  bool get dashboardLabEnabled => _dashboardLabEnabled;
  SelahDashboardConcept get dashboardConcept => _dashboardConcept;
  SelahDashboardContextPreset? get dashboardContextPreset =>
      _dashboardContextPreset;
  SelahDashboardAudiencePreview get dashboardAudience => _dashboardAudience;
  SelahDashboardActivityState get dashboardActivityState =>
      _dashboardActivityState;
  SelahDashboardJourneyPreview get dashboardJourneyPreview =>
      _dashboardJourneyPreview;
  bool get dashboardNewActivity => _dashboardNewActivity;
  bool get dashboardPendingApproval => _dashboardPendingApproval;
  SelahDashboardInsightState get dashboardInsightState =>
      _dashboardInsightState;
  SelahDashboardInsightPlan get dashboardInsightPlan => _dashboardInsightPlan;
  bool get dashboardLearningOnCurrentHub => _dashboardLearningOnCurrentHub;
  bool get dashboardOnboardingComplete => _dashboardOnboardingComplete;
  int get dashboardOnboardingAnswered => _dashboardOnboardingAnswered;
  int get dashboardFamilyProgress => _dashboardFamilyProgress;
  int get dashboardSupportedSeekers => _dashboardSupportedSeekers;
  int get dashboardPotentialJourneys => _dashboardPotentialJourneys;
  int get dashboardSavedProfiles => _dashboardSavedProfiles;
  bool get dashboardHasShepherd => _dashboardHasShepherd;
  bool get dashboardShepherdActivity => _dashboardShepherdActivity;
  bool get dashboardFamilyIntroductionActive =>
      _dashboardFamilyIntroductionActive;
  SelahDashboardTab get dashboardTab => _dashboardTab;
  SelahSeekerDashboardTodayState get dashboardSeekerTodayState =>
      _dashboardSeekerTodayState;
  SelahShepherdDashboardTodayState get dashboardShepherdTodayState =>
      _dashboardShepherdTodayState;
  SelahDashboardUpdatesState get dashboardUpdatesState =>
      _dashboardUpdatesState;
  SelahSeekerDashboardInsightsState get dashboardSeekerInsightsState =>
      _dashboardSeekerInsightsState;
  SelahShepherdDashboardInsightsState get dashboardShepherdInsightsState =>
      _dashboardShepherdInsightsState;
  bool get dashboardShepherdPremium => _dashboardShepherdPremium;
  bool dashboardShepherdOptionSelected(SelahDashboardTab tab) => switch (tab) {
    SelahDashboardTab.now => _dashboardShepherdNowOptionSelected,
    SelahDashboardTab.insights => _dashboardShepherdInsightsOptionSelected,
  };
  Set<SelahDashboardModule> get dashboardModules =>
      Set.unmodifiable(_dashboardModules);
  List<SelahDashboardModule> get dashboardOrder =>
      List.unmodifiable(_dashboardOrder);

  SelahDashboardViewConfig dashboardConfigFor(SelahDashboardRole hostRole) =>
      SelahDashboardViewConfig(
        concept: _dashboardConcept,
        role: resolveDashboardRole(
          preview: _dashboardAudience,
          hostRole: hostRole,
        ),
        surfaceStyle: SelahColors.appSurfaceStyle,
        activityState: _dashboardActivityState,
        journeyPreview: _dashboardJourneyPreview,
        newActivity: _dashboardNewActivity,
        pendingApproval: _dashboardPendingApproval,
        insightState: _dashboardInsightState,
        insightPlan: _dashboardInsightPlan,
        onboardingComplete: _dashboardOnboardingComplete,
        onboardingAnswered: _dashboardOnboardingComplete
            ? dashboardOnboardingTotal
            : _dashboardOnboardingAnswered,
        onboardingTotal: dashboardOnboardingTotal,
        familyProgress: _dashboardFamilyProgress,
        supportedSeekers: _dashboardSupportedSeekers,
        potentialJourneys: _dashboardPotentialJourneys,
        savedProfiles: _dashboardSavedProfiles,
        hasShepherd: _dashboardHasShepherd,
        shepherdActivity: _dashboardShepherdActivity,
        familyIntroductionActive: _dashboardFamilyIntroductionActive,
        contextPreset: _dashboardContextPreset,
        enabledModules: Set.unmodifiable(_dashboardModules),
        moduleOrder: List.unmodifiable(_dashboardOrder),
      );

  void setDashboardLabEnabled(bool value) {
    if (_dashboardLabEnabled == value) return;
    _dashboardLabEnabled = value;
    notifyListeners();
  }

  /// Records an explicit Founder choice in the Shepherd Dashboard dropdown.
  /// Defaults remain stored for deterministic fixtures, but they must not
  /// render as though the Founder selected them on a fresh preview.
  void markDashboardShepherdOptionSelected(SelahDashboardTab tab) {
    final alreadySelected = dashboardShepherdOptionSelected(tab);
    if (alreadySelected) return;
    switch (tab) {
      case SelahDashboardTab.now:
        _dashboardShepherdNowOptionSelected = true;
      case SelahDashboardTab.insights:
        _dashboardShepherdInsightsOptionSelected = true;
    }
    notifyListeners();
  }

  void setDashboardConcept(SelahDashboardConcept value) {
    if (_dashboardConcept == value) return;
    _dashboardConcept = value;
    notifyListeners();
  }

  /// Stages one deterministic Founder-review story across every layout.
  ///
  /// These values only feed the developer Dashboard adapter. Invitation
  /// counts deliberately reuse the existing invitation preview store so the
  /// real Review/Accept/Decline/Cancel interactions are exercised rather than
  /// copied into a decorative Dashboard card.
  void setDashboardContextPreset(SelahDashboardContextPreset value) {
    _dashboardAudience = SelahDashboardAudiencePreview.seeker;
    _dashboardContextPreset = value;
    _applyDashboardContextPreset(value);
    notifyListeners();
  }

  void _applyDashboardContextPreset(SelahDashboardContextPreset value) {
    _dashboardModules
      ..clear()
      ..addAll(selahDashboardDefaultModules);
    _receivedInviteCount = 0;
    _pendingInviteCount = 0;
    _mainShepherd = true;
    _dashboardHasShepherd = true;
    _dashboardShepherdActivity = false;
    _dashboardFamilyIntroductionActive = false;
    _dashboardPotentialJourneys = 0;
    _dashboardSavedProfiles = 2;
    _dashboardOnboardingComplete = true;
    _dashboardOnboardingAnswered = dashboardOnboardingTotal;
    _dashboardJourneyPreview = SelahDashboardJourneyPreview.none;
    _dashboardActivityState = SelahDashboardActivityState.normal;
    _dashboardNewActivity = false;
    _dashboardPendingApproval = false;
    _dashboardInsightState = SelahDashboardInsightState.positive;
    _dashboardInsightPlan = SelahDashboardInsightPlan.basic;
    _dashboardFamilyProgress = 2;

    switch (value) {
      case SelahDashboardContextPreset.newSeeker:
        _mainShepherd = false;
        _dashboardHasShepherd = false;
        _dashboardSavedProfiles = 0;
        _dashboardOnboardingComplete = false;
        _dashboardOnboardingAnswered = 14;
        _dashboardActivityState = SelahDashboardActivityState.empty;
        _dashboardInsightState = SelahDashboardInsightState.insufficientData;
        _dashboardFamilyProgress = 0;
      case SelahDashboardContextPreset.shepherdInvitation:
        _mainShepherd = false;
        _dashboardHasShepherd = false;
        _receivedInviteCount = 1;
        _dashboardNewActivity = true;
      case SelahDashboardContextPreset.potentialJourneys:
        _dashboardJourneyPreview = SelahDashboardJourneyPreview.potentials;
        _dashboardPotentialJourneys = 3;
        _dashboardSavedProfiles = 5;
      case SelahDashboardContextPreset.activeJourney:
        _dashboardJourneyPreview = SelahDashboardJourneyPreview.active;
        _dashboardNewActivity = true;
      case SelahDashboardContextPreset.activeWithShepherd:
        _dashboardJourneyPreview = SelahDashboardJourneyPreview.active;
        _dashboardShepherdActivity = true;
        _dashboardNewActivity = true;
        _dashboardFamilyProgress = 3;
      case SelahDashboardContextPreset.decisionRequired:
        _dashboardJourneyPreview = SelahDashboardJourneyPreview.active;
        _dashboardActivityState = SelahDashboardActivityState.urgent;
        _dashboardNewActivity = true;
        _dashboardPendingApproval = true;
      case SelahDashboardContextPreset.pausedJourney:
        _dashboardJourneyPreview = SelahDashboardJourneyPreview.paused;
        _dashboardInsightState = SelahDashboardInsightState.neutral;
      case SelahDashboardContextPreset.selahOneInsights:
        _dashboardJourneyPreview = SelahDashboardJourneyPreview.active;
        _dashboardActivityState = SelahDashboardActivityState.busy;
        _dashboardNewActivity = true;
        _dashboardInsightPlan = SelahDashboardInsightPlan.one;
        _dashboardInsightState = SelahDashboardInsightState.preferenceReview;
        _dashboardSavedProfiles = 7;
    }
  }

  void _markDashboardContextCustom() {
    _dashboardContextPreset = null;
  }

  void setDashboardAudience(SelahDashboardAudiencePreview value) {
    if (_dashboardAudience == value &&
        (value == SelahDashboardAudiencePreview.seeker ||
            _dashboardContextPreset == null)) {
      return;
    }
    _dashboardAudience = value;
    if (value != SelahDashboardAudiencePreview.seeker) {
      _dashboardContextPreset = null;
    }
    notifyListeners();
  }

  void setDashboardTab(SelahDashboardTab value) {
    if (_dashboardTab == value) return;
    _dashboardTab = value;
    notifyListeners();
  }

  void setDashboardSeekerTodayState(SelahSeekerDashboardTodayState value) {
    _dashboardSeekerTodayState = value;
    _dashboardContextPreset = null;
    _dashboardOnboardingComplete = true;
    _dashboardOnboardingAnswered = dashboardOnboardingTotal;
    _dashboardJourneyPreview = SelahDashboardJourneyPreview.none;
    _dashboardNewActivity = false;
    _dashboardPendingApproval = false;
    _dashboardActivityState = SelahDashboardActivityState.empty;
    _dashboardHasShepherd = false;
    _dashboardShepherdActivity = false;
    _dashboardFamilyIntroductionActive = false;
    _dashboardPotentialJourneys = 0;
    _dashboardSavedProfiles = 0;
    _receivedInviteCount = 0;
    switch (value) {
      case SelahSeekerDashboardTodayState.newSeeker:
        _dashboardOnboardingComplete = false;
        _dashboardOnboardingAnswered = 14;
      case SelahSeekerDashboardTodayState.noShepherd:
      case SelahSeekerDashboardTodayState.noJourney:
      case SelahSeekerDashboardTodayState.calm:
      case SelahSeekerDashboardTodayState.loading:
      case SelahSeekerDashboardTodayState.partialFailure:
      case SelahSeekerDashboardTodayState.fullFailure:
        break;
      case SelahSeekerDashboardTodayState.shepherdConnected:
        _dashboardHasShepherd = true;
      case SelahSeekerDashboardTodayState.shepherdInvitationPending:
        _receivedInviteCount = 1;
      case SelahSeekerDashboardTodayState.potentialJourneys:
        _dashboardJourneyPreview = SelahDashboardJourneyPreview.potentials;
        _dashboardPotentialJourneys = 3;
      case SelahSeekerDashboardTodayState.activeJourney:
        _dashboardJourneyPreview = SelahDashboardJourneyPreview.active;
      case SelahSeekerDashboardTodayState.journeyPaused:
        _dashboardJourneyPreview = SelahDashboardJourneyPreview.paused;
      case SelahSeekerDashboardTodayState.journeyDecisionPending:
        _dashboardJourneyPreview = SelahDashboardJourneyPreview.active;
        _dashboardPendingApproval = true;
        _dashboardActivityState = SelahDashboardActivityState.urgent;
      case SelahSeekerDashboardTodayState.recentMovement:
        _dashboardJourneyPreview = SelahDashboardJourneyPreview.active;
        _dashboardNewActivity = true;
        _dashboardActivityState = SelahDashboardActivityState.normal;
    }
    notifyListeners();
  }

  void setDashboardShepherdTodayState(SelahShepherdDashboardTodayState value) {
    _dashboardShepherdNowOptionSelected = true;
    _dashboardShepherdTodayState = value;
    _dashboardContextPreset = null;
    _mentorRole = MentorRole.main;
    _mentorLinkedSeekers = 1;
    _mentorActiveJourneys = 0;
    _mentorPausedJourneys = 0;
    _mentorEndedJourneys = 0;
    _mentorReviewWaiting = false;
    _mentorReviewDecision = null;
    _mentorSentInvites = 0;
    _dashboardShepherdPremium = false;
    _dashboardShepherdJourneyDecisionPending = false;
    switch (value) {
      case SelahShepherdDashboardTodayState.noSeekers:
        _mentorLinkedSeekers = 0;
      case SelahShepherdDashboardTodayState.oneSeeker:
      case SelahShepherdDashboardTodayState.mainShepherd:
      case SelahShepherdDashboardTodayState.noJourney:
      case SelahShepherdDashboardTodayState.calm:
      case SelahShepherdDashboardTodayState.loading:
      case SelahShepherdDashboardTodayState.partialFailure:
      case SelahShepherdDashboardTodayState.fullFailure:
        break;
      case SelahShepherdDashboardTodayState.multipleSeekers:
        _mentorLinkedSeekers = 3;
        _mentorActiveJourneys = 1;
        _mentorPausedJourneys = 1;
      case SelahShepherdDashboardTodayState.additionalShepherd:
        _mentorRole = MentorRole.additional;
      case SelahShepherdDashboardTodayState.activeJourney:
        _mentorActiveJourneys = 1;
      case SelahShepherdDashboardTodayState.pausedJourney:
        _mentorPausedJourneys = 1;
      case SelahShepherdDashboardTodayState.journeyDecisionPending:
        _mentorActiveJourneys = 1;
        _dashboardShepherdJourneyDecisionPending = true;
      case SelahShepherdDashboardTodayState.familyReviewWaiting:
        _mentorActiveJourneys = 1;
        _mentorReviewWaiting = true;
      case SelahShepherdDashboardTodayState.pendingInvitation:
        _mentorLinkedSeekers = 0;
        _mentorSentInvites = 1;
      case SelahShepherdDashboardTodayState.networkBasicLocked:
        break;
      case SelahShepherdDashboardTodayState.networkPremiumActive:
        _dashboardShepherdPremium = true;
    }
    notifyListeners();
  }

  void setDashboardUpdatesState(SelahDashboardUpdatesState value) {
    if (_dashboardUpdatesState == value) return;
    _dashboardUpdatesState = value;
    _dashboardNewActivity = switch (value) {
      SelahDashboardUpdatesState.none ||
      SelahDashboardUpdatesState.allRead => false,
      _ => true,
    };
    notifyListeners();
  }

  void setDashboardSeekerInsightsState(
    SelahSeekerDashboardInsightsState value,
  ) {
    _dashboardSeekerInsightsState = value;
    _dashboardInsightState = switch (value) {
      SelahSeekerDashboardInsightsState.insufficient =>
        SelahDashboardInsightState.insufficientData,
      SelahSeekerDashboardInsightsState.preferenceReview =>
        SelahDashboardInsightState.preferenceReview,
      SelahSeekerDashboardInsightsState.discoveryHealth =>
        SelahDashboardInsightState.neutral,
      _ => SelahDashboardInsightState.positive,
    };
    _dashboardInsightPlan =
        value == SelahSeekerDashboardInsightsState.one ||
            value == SelahSeekerDashboardInsightsState.aiExplanation
        ? SelahDashboardInsightPlan.one
        : SelahDashboardInsightPlan.basic;
    notifyListeners();
  }

  void setDashboardShepherdInsightsState(
    SelahShepherdDashboardInsightsState value,
  ) {
    final selectionChanged = !_dashboardShepherdInsightsOptionSelected;
    _dashboardShepherdInsightsOptionSelected = true;
    if (_dashboardShepherdInsightsState == value) {
      if (selectionChanged) notifyListeners();
      return;
    }
    _dashboardShepherdInsightsState = value;
    if (value == SelahShepherdDashboardInsightsState.premium) {
      _dashboardShepherdPremium = true;
    }
    notifyListeners();
  }

  void setDashboardShepherdPremium(bool value) {
    if (_dashboardShepherdPremium == value) return;
    _dashboardShepherdPremium = value;
    notifyListeners();
  }

  void setDashboardActivityState(SelahDashboardActivityState value) {
    if (_dashboardActivityState == value && _dashboardContextPreset == null) {
      return;
    }
    _markDashboardContextCustom();
    _dashboardActivityState = value;
    if (value == SelahDashboardActivityState.empty) {
      _dashboardNewActivity = false;
      _dashboardPendingApproval = false;
    } else if (value == SelahDashboardActivityState.urgent) {
      _dashboardPendingApproval = true;
      _dashboardNewActivity = true;
    }
    notifyListeners();
  }

  void setDashboardJourneyPreview(SelahDashboardJourneyPreview value) {
    if (_dashboardJourneyPreview == value && _dashboardContextPreset == null) {
      return;
    }
    _markDashboardContextCustom();
    _dashboardJourneyPreview = value;
    notifyListeners();
  }

  void setDashboardNewActivity(bool value) {
    if (_dashboardNewActivity == value && _dashboardContextPreset == null) {
      return;
    }
    _markDashboardContextCustom();
    _dashboardNewActivity = value;
    notifyListeners();
  }

  void setDashboardPendingApproval(bool value) {
    if (_dashboardPendingApproval == value && _dashboardContextPreset == null) {
      return;
    }
    _markDashboardContextCustom();
    _dashboardPendingApproval = value;
    if (value) {
      _dashboardModules.add(SelahDashboardModule.nextStep);
    }
    notifyListeners();
  }

  void setDashboardInsightState(SelahDashboardInsightState value) {
    if (_dashboardInsightState == value && _dashboardContextPreset == null) {
      return;
    }
    _markDashboardContextCustom();
    _dashboardInsightState = value;
    _dashboardModules.add(SelahDashboardModule.learning);
    notifyListeners();
  }

  void setDashboardInsightPlan(SelahDashboardInsightPlan value) {
    if (_dashboardInsightPlan == value && _dashboardContextPreset == null) {
      return;
    }
    _markDashboardContextCustom();
    _dashboardInsightPlan = value;
    _dashboardModules.add(SelahDashboardModule.learning);
    notifyListeners();
  }

  void setDashboardLearningOnCurrentHub(bool value) {
    if (_dashboardLearningOnCurrentHub == value) return;
    _dashboardLearningOnCurrentHub = value;
    notifyListeners();
  }

  void setDashboardOnboardingComplete(bool value) {
    if (_dashboardOnboardingComplete == value &&
        _dashboardContextPreset == null) {
      return;
    }
    _markDashboardContextCustom();
    _dashboardOnboardingComplete = value;
    if (value) {
      _dashboardModules.remove(SelahDashboardModule.onboarding);
    } else {
      _dashboardModules.add(SelahDashboardModule.onboarding);
    }
    notifyListeners();
  }

  void setDashboardOnboardingAnswered(int value) {
    final resolved = value.clamp(0, dashboardOnboardingTotal - 1);
    if (_dashboardOnboardingAnswered == resolved &&
        !_dashboardOnboardingComplete &&
        _dashboardContextPreset == null) {
      return;
    }
    _markDashboardContextCustom();
    _dashboardOnboardingAnswered = resolved;
    _dashboardOnboardingComplete = false;
    _dashboardModules.add(SelahDashboardModule.onboarding);
    notifyListeners();
  }

  void setDashboardFamilyProgress(int value) {
    final resolved = value.clamp(0, 4);
    if (_dashboardFamilyProgress == resolved &&
        _dashboardContextPreset == null) {
      return;
    }
    _markDashboardContextCustom();
    _dashboardFamilyProgress = resolved;
    _dashboardFamilyIntroductionActive = true;
    notifyListeners();
  }

  void setDashboardFamilyIntroductionActive(bool value) {
    if (_dashboardFamilyIntroductionActive == value &&
        _dashboardContextPreset == null) {
      return;
    }
    _markDashboardContextCustom();
    _dashboardFamilyIntroductionActive = value;
    notifyListeners();
  }

  void setDashboardHasShepherd(bool value) {
    if (_dashboardHasShepherd == value && _dashboardContextPreset == null) {
      return;
    }
    _markDashboardContextCustom();
    _dashboardHasShepherd = value;
    if (!value) _dashboardShepherdActivity = false;
    notifyListeners();
  }

  void setDashboardShepherdActivity(bool value) {
    if (_dashboardShepherdActivity == value &&
        _dashboardContextPreset == null) {
      return;
    }
    _markDashboardContextCustom();
    _dashboardShepherdActivity = value;
    if (value) _dashboardHasShepherd = true;
    notifyListeners();
  }

  void setDashboardPotentialJourneys(int value) {
    final resolved = value.clamp(0, 5);
    if (_dashboardPotentialJourneys == resolved &&
        _dashboardContextPreset == null) {
      return;
    }
    _markDashboardContextCustom();
    _dashboardPotentialJourneys = resolved;
    notifyListeners();
  }

  void setDashboardSavedProfiles(int value) {
    final resolved = value.clamp(0, 10);
    if (_dashboardSavedProfiles == resolved &&
        _dashboardContextPreset == null) {
      return;
    }
    _markDashboardContextCustom();
    _dashboardSavedProfiles = resolved;
    notifyListeners();
  }

  void setDashboardSupportedSeekers(int value) {
    final resolved = value.clamp(0, 6);
    if (_dashboardSupportedSeekers == resolved) return;
    _markDashboardContextCustom();
    _dashboardSupportedSeekers = resolved;
    notifyListeners();
  }

  void setDashboardModuleEnabled(SelahDashboardModule module, bool enabled) {
    final changed = enabled
        ? _dashboardModules.add(module)
        : _dashboardModules.remove(module);
    if (!changed) return;
    notifyListeners();
  }

  void moveDashboardModule(SelahDashboardModule module, int delta) {
    final from = _dashboardOrder.indexOf(module);
    final to = (from + delta).clamp(0, _dashboardOrder.length - 1);
    if (from < 0 || from == to) return;
    _dashboardOrder.removeAt(from);
    _dashboardOrder.insert(to, module);
    notifyListeners();
  }

  /// Moves a module only against neighbours owned by the same Dashboard tab.
  void moveDashboardModuleWithin(
    SelahDashboardModule module,
    int delta,
    Set<SelahDashboardModule> sectionModules,
  ) {
    final sectionOrder = _dashboardOrder
        .where(sectionModules.contains)
        .toList();
    final sectionFrom = sectionOrder.indexOf(module);
    final sectionTo = (sectionFrom + delta).clamp(0, sectionOrder.length - 1);
    if (sectionFrom < 0 || sectionFrom == sectionTo) return;
    final other = sectionOrder[sectionTo];
    final from = _dashboardOrder.indexOf(module);
    final to = _dashboardOrder.indexOf(other);
    _dashboardOrder[from] = other;
    _dashboardOrder[to] = module;
    notifyListeners();
  }

  void resetDashboardLab({bool notify = true}) {
    _dashboardLabEnabled = true;
    _dashboardConcept = SelahDashboardConcept.nowJourneyYou;
    _dashboardAudience = SelahDashboardAudiencePreview.current;
    _dashboardContextPreset = null;
    _dashboardTab = SelahDashboardTab.now;
    _dashboardSeekerTodayState = SelahSeekerDashboardTodayState.calm;
    _dashboardShepherdTodayState = SelahShepherdDashboardTodayState.noSeekers;
    _dashboardUpdatesState = SelahDashboardUpdatesState.none;
    _dashboardSeekerInsightsState =
        SelahSeekerDashboardInsightsState.insufficient;
    _dashboardShepherdInsightsState =
        SelahShepherdDashboardInsightsState.insufficient;
    _dashboardShepherdPremium = false;
    _dashboardShepherdNowOptionSelected = false;
    _dashboardShepherdInsightsOptionSelected = false;
    _dashboardShepherdJourneyDecisionPending = false;
    _dashboardLearningOnCurrentHub = false;
    _dashboardSupportedSeekers = 0;
    _dashboardOrder
      ..clear()
      ..addAll(selahDashboardDefaultOrder);
    _dashboardModules
      ..clear()
      ..addAll(selahDashboardDefaultModules);
    _dashboardOnboardingComplete = true;
    _dashboardOnboardingAnswered = dashboardOnboardingTotal;
    _dashboardJourneyPreview = SelahDashboardJourneyPreview.none;
    _dashboardNewActivity = false;
    _dashboardPendingApproval = false;
    _dashboardActivityState = SelahDashboardActivityState.empty;
    _dashboardInsightState = SelahDashboardInsightState.insufficientData;
    _dashboardInsightPlan = SelahDashboardInsightPlan.basic;
    _dashboardHasShepherd = false;
    _dashboardShepherdActivity = false;
    _dashboardFamilyIntroductionActive = false;
    _dashboardPotentialJourneys = 0;
    _dashboardSavedProfiles = 0;
    _receivedInviteCount = 0;
    _pendingInviteCount = 0;
    _mentorRole = MentorRole.main;
    _mentorLinkedSeekers = 0;
    _mentorActiveJourneys = 0;
    _mentorPausedJourneys = 0;
    _mentorEndedJourneys = 0;
    _mentorReviewWaiting = false;
    _mentorReviewDecision = null;
    _mentorSentInvites = 0;
    _mentorUnread = 0;
    if (notify) notifyListeners();
  }

  void setCurrentPage(DevPage page) {
    if (currentPage == page) return;
    currentPage = page;
    notifyListeners();
  }

  // Which segment of Connections is on screen: 0 Journeys · 1 Activity ·
  // 2 Introductions. Written by ConnectionsScreen when a swipe settles
  // (same pushed-in reasoning as currentPage). The panel narrows the
  // Connections card to the section actually showing — you have to BE on
  // Introductions to see the Introductions controls.
  //
  // ADDED 2026-08-12 (Founder: "i gotta be on indroduction to see the
  // introduction optins in toggle").
  //
  // Context, not scenario: reset() leaves it alone, because where you are
  // in the app is not staged data.

  int connectionsSection = 0;

  /// Local-only rows used to exercise the three Activity groups without
  /// changing the signed-in account's real decisions. Their controls live in
  /// the developer panel; the cards themselves deliberately use production
  /// presentation so the Founder is reviewing the real interface.
  int _consideredPreviewCount = 0;
  int _savedPreviewCount = 0;
  int _passedPreviewCount = 0;

  /// A fixture begins in the group which created it. Once an action is tapped,
  /// this map becomes its one local destination. Keeping this out of AppState
  /// prevents a deterministic fixture being regenerated in its old group and
  /// duplicated in the new one.
  final Map<String, SelahActivityTestState> _localProfileDestinations = {};
  final Set<String> _hiddenLocalProfileIds = {};

  int get consideredPreviewCount => _consideredPreviewCount;
  int get savedPreviewCount => _savedPreviewCount;
  int get passedPreviewCount => _passedPreviewCount;

  SelahActivityTestState? localProfileDestination(String profileId) =>
      _localProfileDestinations[profileId];

  bool isLocalProfileHidden(String profileId) =>
      _hiddenLocalProfileIds.contains(profileId);

  void moveLocalProfile(String profileId, SelahActivityTestState destination) {
    if (_localProfileDestinations[profileId] == destination &&
        !_hiddenLocalProfileIds.contains(profileId)) {
      return;
    }
    _hiddenLocalProfileIds.remove(profileId);
    _localProfileDestinations[profileId] = destination;
    notifyListeners();
  }

  void hideLocalProfile(String profileId) {
    if (!_hiddenLocalProfileIds.add(profileId)) return;
    _localProfileDestinations.remove(profileId);
    notifyListeners();
  }

  void _pruneActivitySlots(SelahActivityTestState origin, int retained) {
    for (var index = retained; index < 5; index++) {
      final id = selahActivityTestProfileId(origin, index);
      _localProfileDestinations.remove(id);
      _hiddenLocalProfileIds.remove(id);
    }
  }

  void _pruneIntroductionSlots(int retained) {
    for (var index = retained; index < 5; index++) {
      final id = selahIntroductionTestProfileId(index);
      _localProfileDestinations.remove(id);
      _hiddenLocalProfileIds.remove(id);
    }
  }

  void setConsideredPreviewCount(int count) {
    final next = count.clamp(0, 5);
    if (_consideredPreviewCount == next) return;
    _pruneActivitySlots(SelahActivityTestState.considered, next);
    _consideredPreviewCount = next;
    notifyListeners();
  }

  void setSavedPreviewCount(int count) {
    final next = count.clamp(0, 5);
    if (_savedPreviewCount == next) return;
    _pruneActivitySlots(SelahActivityTestState.saved, next);
    _savedPreviewCount = next;
    notifyListeners();
  }

  void setPassedPreviewCount(int count) {
    final next = count.clamp(0, 5);
    if (_passedPreviewCount == next) return;
    _pruneActivitySlots(SelahActivityTestState.passed, next);
    _passedPreviewCount = next;
    notifyListeners();
  }

  /// Extra production-style Introduction cards used only when the guarded
  /// server developer RPC refuses a non-`@selah.test` developer account.
  ///
  /// Zero means no fallback rows. Real server suggestions are never removed
  /// or replaced; Connections adds these deterministic rows in non-release
  /// builds only. The developer panel, not the customer card, identifies the
  /// state as a test fixture.
  int _introductionPreviewCount = 0;
  int get introductionPreviewCount => _introductionPreviewCount;

  void setIntroductionPreviewCount(int count) {
    final next = count.clamp(0, 5);
    if (_introductionPreviewCount == next) return;
    _pruneIntroductionSlots(next);
    _introductionPreviewCount = next;
    notifyListeners();
  }

  SelahBrowseSwipeFeedbackStyle _browseSwipeFeedbackStyle =
      SelahBrowseSwipeFeedbackStyle.fullAura;

  SelahBrowseSwipeFeedbackStyle get browseSwipeFeedbackStyle =>
      _browseSwipeFeedbackStyle;

  void setBrowseSwipeFeedbackStyle(SelahBrowseSwipeFeedbackStyle value) {
    if (_browseSwipeFeedbackStyle == value) return;
    _browseSwipeFeedbackStyle = value;
    notifyListeners();
  }

  /// Adds five local Browse cards behind the account's genuine candidates so
  /// the Founder can test the 3D next-profile handoff as a sequence rather
  /// than against a one-card deck.
  ///
  /// This helper is deliberately passive: [BrowseScreen] calls it only after
  /// [SelahDeveloperAccess.canUseDeveloperTools] has authorised the session.
  /// The generated ids are non-UUIDs, so the existing Browse write guards
  /// keep Save, Consider, Pass, report, hide and unlock away from Supabase.
  /// The anchor photo is reused on purpose; these cards test motion and deck
  /// continuity, not identity or image variety.
  static List<SeekerProfile> composeBrowsePreviewProfiles({
    required List<SeekerProfile> real,
    required String? viewerGender,
    int extraCount = 5,
  }) {
    final count = extraCount.clamp(0, 5);
    if (count == 0) return List<SeekerProfile>.of(real);

    final targetGender = SelahGender.oppositeCode(viewerGender);
    var anchor = mockProfiles.firstWhere(
      (profile) => profile.gender == targetGender,
    );
    for (final profile in real) {
      if (profile.gender == targetGender && profile.photos.isNotEmpty) {
        anchor = profile;
        break;
      }
    }

    const femaleIdentities = [
      (firstName: 'Grace', surnameLine: 'Clarke', age: 28, city: 'Manchester'),
      (firstName: 'Ruth', surnameLine: 'Adeyemi', age: 31, city: 'Birmingham'),
      (firstName: 'Chloe', surnameLine: 'Bennett', age: 26, city: 'Leicester'),
      (firstName: 'Lydia', surnameLine: 'Thomas', age: 30, city: 'Glasgow'),
      (firstName: 'Miriam', surnameLine: 'Okoro', age: 29, city: 'Leeds'),
    ];
    const maleIdentities = [
      (firstName: 'James', surnameLine: 'Carter', age: 30, city: 'Manchester'),
      (firstName: 'Daniel', surnameLine: 'Owusu', age: 28, city: 'Birmingham'),
      (firstName: 'Samuel', surnameLine: 'Hughes', age: 32, city: 'Leicester'),
      (firstName: 'Joel', surnameLine: 'Martins', age: 27, city: 'Glasgow'),
      (firstName: 'Caleb', surnameLine: 'Moore', age: 31, city: 'Leeds'),
    ];
    final identities = targetGender == 'male'
        ? maleIdentities
        : femaleIdentities;
    final preview = <SeekerProfile>[];
    for (var i = 0; i < count; i++) {
      final identity = identities[i];
      preview.add(
        SeekerProfile(
          id: 'dev-browse-preview-${targetGender[0]}-$i',
          firstName: identity.firstName,
          surnameLine: identity.surnameLine,
          age: identity.age,
          city: identity.city,
          photos: anchor.photos,
          gender: targetGender,
        ),
      );
    }
    return [...real, ...preview];
  }

  void setConnectionsSection(int section) {
    final s = section.clamp(0, 2);
    if (connectionsSection == s) return;
    connectionsSection = s;
    notifyListeners();
  }

  // How many staged people are ALREADY in a Journey with someone else.
  //
  // ONE COUNT PER SECTION since 2026-08-13 (Founder: "in toggle the in
  // another journey make 3… so i can choose how many people are in a
  // journey so i can see") — the single potential-first budget of
  // 2026-08-12 couldn't stage "a busy PAUSED person" without first
  // making every potential person busy. Each count marks the FIRST N
  // fakes of its own section (deterministic across recomposes, like the
  // nudge set); composeJourneys clamps by construction, so lowering a
  // row count can never leave more busy people than people. Fakes only —
  // real rows keep whatever the fetch said.
  int _busyPotential = 0;
  int get busyPotential => _busyPotential;
  void setBusyPotential(int v) {
    final n = v.clamp(0, 30);
    if (_busyPotential == n) return;
    _busyPotential = n;
    notifyListeners();
  }

  int _busyPaused = 0;
  int get busyPaused => _busyPaused;
  void setBusyPaused(int v) {
    final n = v.clamp(0, 30);
    if (_busyPaused == n) return;
    _busyPaused = n;
    notifyListeners();
  }

  int _busyEnded = 0;
  int get busyEnded => _busyEnded;
  void setBusyEnded(int v) {
    final n = v.clamp(0, 30);
    if (_busyEnded == n) return;
    _busyEnded = n;
    notifyListeners();
  }

  // The shared decision flow's complete preview axis. Plan is deliberately
  // separate, allowing every state to be reviewed as Basic and SELAH One.
  SelahPauseDevScenario _pauseScenario = SelahPauseDevScenario.active;
  SelahPauseDevScenario get pauseScenario => _pauseScenario;

  void setPauseScenario(SelahPauseDevScenario scenario) {
    final nextCount = _pausedJourneys == 0 ? 1 : _pausedJourneys;
    if (_pauseScenario == scenario && _pausedJourneys == nextCount) return;
    _connectionsPreviewIsolated = true;
    _pauseScenario = scenario;
    _pausedJourneys = nextCount;
    notifyListeners();
  }

  // The three-way Connections page-design switcher lived here for a few
  // hours on 2026-08-12 (A sections · B hero+shelves · C one list) and
  // was REMOVED the same day: the Founder committed to A — "stop
  // exploring alternative layouts and instead focus on making Option A
  // feel polished." Both alternative builders deleted with it; git
  // history keeps them if a future redesign wants the reference.

  // The Sheet/Rows person-surface switcher (concepts 1 and 4) also lived
  // and died on 2026-08-12: after testing both live, the Founder kept the
  // ROWS pattern — the Activity card's expansion model — for every person
  // on Connections, and the toggle went with the choice. One pattern,
  // no switch, nothing to configure.

  // --- Forced limit states ----------------------------------------------
  // Read by: browse_screen.dart `_onSave` and `_onConsider`.
  //
  // RESTORED 2026-08-03 after being removed on 2026-08-01. The removal was
  // right at the time and the restoration is right now, for the same
  // reason in both directions: reaching a cap honestly means 5, 15 or 25
  // deliberate taps, so the modals behind them go unreviewed. The SELAH One
  // save message said the same thing twice for weeks before anyone got
  // there.
  //
  // Save applies on BOTH plans — Basic caps at 5, SELAH One at 15, and the
  // two show visibly different copy.
  // Consider applies on Basic ONLY — SELAH One is unlimited, so there is no
  // cap to reach and no modal to see.

  // REPLACED the `forceSaveLimit` / `forceConsiderLimit` booleans
  // 2026-08-05 (Founder: "after pressing the save limit button, every time
  // I try Browse the save limit message pops up — when I press the button
  // in toggle it should show it just one time").
  //
  // Those were STICKY: once set, every Save for the rest of the session hit
  // the cap branch, so the panel effectively broke Browse until reset. They
  // also only ARMED a state — the modal still needed the right tap
  // afterwards, so the button looked like it had done nothing.
  //
  // A popup is an event. This is a one-shot request: the panel names the
  // popup, Browse shows THE APP'S OWN modal once, and clears it. No
  // invented copy, no lingering state, one showing per press.
  DevPopup? pendingPopup;

  void requestPopup(DevPopup p) {
    pendingPopup = p;
    notifyListeners();
  }

  /// Read-and-clear. Browse calls this; whoever asks first gets it.
  DevPopup? takePendingPopup() {
    final p = pendingPopup;
    pendingPopup = null;
    return p;
  }

  // --- Test deck ---------------------------------------------------------
  // REMOVED 2026-08-04, Founder: "remove the 200 colour profile block
  // profiles, I don't want that no more."
  //
  // The deck existed because the seeded profiles had no Chapter 2 data and
  // real photos were slow to sign. Both are now false: the 24 seeded
  // profiles carry church tradition, ethnicity, languages and preferences, so the real
  // deck exercises more of the product than a synthetic one ever did.

  // --- Shepherds --------------------------------------------------------
  // Read by: seeker_mentor_tab.dart.
  //
  // Founder: "whatever number I select, it then shows on the Shepherd page
  // a profile card of a mock-up Shepherd. For example if I click 1 it
  // makes Abdul father; if two, it's Abdul father and Hassan brother."
  //
  // Linking a Shepherd for real needs a second account, an invite code and
  // a 7-day token — which is why that page's layout had never been seen
  // with anyone in it, and why `mentor_links.is_main` sat unread since the
  // table was built.
  //
  // Index 0 is always Main. Not a display choice: `mentor_links.is_main`
  // auto-designates the first active link, so if the fakes disagreed the
  // panel would show a layout the database cannot produce.
  /// SPLIT 2026-08-06 (Founder: "for mentor section can you give option for 1
  /// main mentor, 0–5 additional mentor and 0–5 pending mentor").
  ///
  /// Was a single 0–3 count, which could not produce the states the
  /// rebuilt Shepherd page actually has: a Main with no Additional, a
  /// pending-only network, or an empty page while invites are outstanding.
  ///
  /// NO PRODUCT LIMIT EXISTS. Checked before adding these:
  /// `mentor_links` has no count constraint, the INSERT policy caps nothing,
  /// `accept_mentor_invite` counts nothing, and MENTOR_ARCHITECTURE V6 states
  /// plainly — "No artificial cap is currently imposed. A formal linking
  /// policy must be specified before production." So 5 is a testing
  /// convenience, NOT an implied maximum, and the page must not be built as
  /// though 6 were the ceiling.
  bool _mainShepherd = false;
  int _additionalShepherdCount = 0;
  int _pendingInviteCount = 0;
  int _shepherdPreviewActiveJourneyCount = 1;

  bool get mainShepherd => _mainShepherd;
  int get additionalShepherdCount => _additionalShepherdCount;
  int get pendingInviteCount => _pendingInviteCount;
  int get shepherdPreviewActiveJourneyCount =>
      _shepherdPreviewActiveJourneyCount;

  void setMainShepherd(bool v) {
    if (_mainShepherd == v) return;
    _mainShepherd = v;
    notifyListeners();
  }

  void setAdditionalShepherds(int v) {
    if (_additionalShepherdCount == v) return;
    _additionalShepherdCount = v;
    notifyListeners();
  }

  void setPendingInvites(int v) {
    if (_pendingInviteCount == v) return;
    _pendingInviteCount = v;
    notifyListeners();
  }

  /// Founder-only layout preview for the Seeker's Shepherd page. It changes
  /// only the local Main/Additional Shepherd access rows, never Journey truth.
  void setShepherdPreviewActiveJourneyCount(int value) {
    final next = value.clamp(0, 3).toInt();
    if (_shepherdPreviewActiveJourneyCount == next) return;
    _shepherdPreviewActiveJourneyCount = next;
    notifyListeners();
  }

  /// One dev invite was cancelled on the Shepherd page. The page calls this
  /// rather than reaching into the field (the old `set_()` route), so the
  /// panel's segment and the page always agree on the count.
  void consumePendingInvite() {
    if (_pendingInviteCount <= 0) return;
    _pendingInviteCount -= 1;
    notifyListeners();
  }

  /// Invitations sent TO this user by a Shepherd, awaiting their answer.
  ///
  /// ADDED 2026-08-07 as a PREVIEW. This section cannot exist for real yet —
  /// see SelahDevScenario.fakeReceived below.
  int _receivedInviteCount = 0;
  int get receivedInviteCount => _receivedInviteCount;

  void setReceivedInvites(int v) {
    if (_receivedInviteCount == v) return;
    _receivedInviteCount = v;
    notifyListeners();
  }

  void consumeReceivedInvite() {
    if (_receivedInviteCount <= 0) return;
    _receivedInviteCount -= 1;
    notifyListeners();
  }

  /// When true the Shepherd page reads the DATABASE and ignores the panel.
  ///
  /// INVERTED 2026-08-07 (Founder: "if the Dev Panel says 0 Shepherds, the
  /// Shepherd page should also show 0 Shepherds… When I'm using the Dev
  /// Panel I expect the panel to be the source of truth").
  ///
  /// The panel now wins by default and 0 means zero. Live data is a
  /// deliberate opt-in, named on screen, rather than something 0 quietly
  /// meant.
  ///
  /// THE HISTORY, because it took three attempts and the lesson is worth
  /// keeping: the first two versions tried to INFER whether the panel was
  /// driving the page, from the values — `pendingInviteCount > 0`, then
  /// `|| shepherdCount > 0`. Both failed the same way, because 0 is
  /// simultaneously a legitimate choice and the resting state, so the two
  /// cannot be told apart. The third made it an explicit flag but still
  /// defaulted to live data, which left the panel and the page disagreeing
  /// on screen.
  ///
  /// A control panel that is only SOMETIMES in charge is a control panel you
  /// cannot trust. It is in charge unless told otherwise.
  bool _useLiveShepherdData = false;
  bool get useLiveShepherdData => _useLiveShepherdData;

  void setUseLiveShepherdData(bool v) {
    if (_useLiveShepherdData == v) return;
    _useLiveShepherdData = v;
    notifyListeners();
  }

  /// Fixture data is never an ordinary member's fallback. The stored panel
  /// preference applies only while the protected developer authority is live.
  bool get shepherdOverride =>
      SelahDeveloperAccess.canUseDeveloperTools && !_useLiveShepherdData;

  // ── Journeys ─────────────────────────────────────────────────────────
  //
  // ADDED 2026-08-06 (Founder: "add a section for 0–5 journey queued,
  // paused journeys, ended journey, and I'm assuming we only have option
  // for 1 active journey so make that 0/1").
  //
  // Active and Paused are capacity categories over status='active' match
  // rows. A pending Pause/Continue decision stays in Active; only mutual
  // Pause and its pending resume live in Paused. The scenario below mirrors
  // that model instead of simulating ownership by one Seeker.
  // False on a fresh app launch so developer access never hides live rows
  // merely by existing. Reset and the Connections controls turn this on:
  // from that point the page is an isolated preview and zero genuinely means
  // no cards, while the server rows remain untouched.
  bool _connectionsPreviewIsolated = false;
  bool get connectionsPreviewIsolated => _connectionsPreviewIsolated;

  List<T> connectionsRealRows<T>(List<T> rows) =>
      _connectionsPreviewIsolated ? <T>[] : rows;

  int _queuedJourneys = 0; // status 'potential'
  int _endedJourneys = 0; // status 'ended'

  int get queuedJourneys => _queuedJourneys;
  int get endedJourneys => _endedJourneys;

  void setQueuedJourneys(int v) {
    if (_queuedJourneys == v && _connectionsPreviewIsolated) return;
    _connectionsPreviewIsolated = true;
    _queuedJourneys = v;
    notifyListeners();
  }

  void setEndedJourneys(int v) {
    if (_endedJourneys == v && _connectionsPreviewIsolated) return;
    _connectionsPreviewIsolated = true;
    _endedJourneys = v;
    notifyListeners();
  }

  /// Extra Running and mutually Paused preview rows. Counts are clamped by
  /// the current plan. [pauseScenario] controls the first row's precise
  /// decision state, including pending states that remain in Active.
  int _activeJourneys = 0;
  int _pausedJourneys = 0;

  int get activeJourneys => _activeJourneys;
  int get pausedJourneys => _pausedJourneys;

  void setActiveJourneys(int v) {
    if (_activeJourneys == v && _connectionsPreviewIsolated) return;
    _connectionsPreviewIsolated = true;
    _activeJourneys = v;
    notifyListeners();
  }

  /// inherited decision 180. A public nudge for dev controls that change SERVER
  /// rows rather than staged counts — seeding a real Journey changes
  /// what the real fetch returns, and ConnectionsScreen's scenario
  /// listener answers a notify with a full re-fetch. Nothing staged
  /// changes here.
  void refreshJourneys() => notifyListeners();

  void setPausedJourneys(int v) {
    final nextScenario = v > 0 && _pauseScenario == SelahPauseDevScenario.active
        ? SelahPauseDevScenario.mutuallyPaused
        : _pauseScenario;
    if (_pausedJourneys == v &&
        _pauseScenario == nextScenario &&
        _connectionsPreviewIsolated) {
      return;
    }
    _connectionsPreviewIsolated = true;
    _pausedJourneys = v;
    _pauseScenario = nextScenario;
    notifyListeners();
  }

  /// One-time bridge from the 2026-08-12 control collection to the clean
  /// 2026-08-18 panel. The busy counters were removed because
  /// they staged impossible or retired states. Active Journey is intentionally
  /// retained: the Connections panel exposes it again as a plan-aware preview
  /// count (legacy inactive fixture 0-1 / SELAH One 0-3).
  void migrateToCleanSeekerPanel() {
    final changed = _busyPotential != 0 || _busyPaused != 0 || _busyEnded != 0;
    if (!changed) return;
    _busyPotential = 0;
    _busyPaused = 0;
    _busyEnded = 0;
    notifyListeners();
  }

  /// Total linked Shepherds. Kept as a getter so every existing
  /// `shepherdCount > 0` check still means "the dev panel is driving this
  /// page" without each caller having to reassemble it.
  int get shepherdCount => (mainShepherd ? 1 : 0) + additionalShepherdCount;

  /// Names are the Founder's own. Fixed, so screenshots are reproducible.
  /// CHANGED 2026-08-06: these were display labels ('Father', 'Paternal
  /// uncle'). They are now the stored CODES, so dev data and production
  /// data are the same shape and go through the same label lookup. The old
  /// values had a lowercase 'u' in "Paternal uncle" and would never have
  /// matched anything — which nobody noticed, because until today these
  /// fakes were the ONLY source of a relationship anywhere in the app.
  /// Six, so 1 Main + 5 Additional is reachable. Relationships deliberately
  /// span the whole enum — a list of three fathers would never have shown
  /// that "Family Representative" is the longest label on the card and the
  /// first to wrap.
  static const List<({String name, String relationship})> fakeShepherds = [
    (name: 'David', relationship: 'pastor'),
    (name: 'Ama', relationship: 'pastor'),
    (name: 'Joseph', relationship: 'church_elder'),
    (name: 'Sarah', relationship: 'mentor'),
    (name: 'Peter', relationship: 'father'),
    (name: 'Mark', relationship: 'brother'),
  ];

  /// Labels are the Founder's own examples. One is deliberately null: an
  /// invite with no label is the common case, and it renders as the raw
  /// token, which is the outcome the label exists to avoid — worth being
  /// able to see rather than only ever testing the happy path.
  static const List<({String? label, int daysLeft})> fakePendingInvites = [
    (label: 'Dad', daysLeft: 5),
    (label: 'Uncle Matthew', daysLeft: 3),
    (label: null, daysLeft: 6),
    (label: 'Pastor', daysLeft: 1),
    (label: 'Family Friend', daysLeft: 0),
  ];

  /// Activity for the fake Shepherds, so the dev panel exercises the
  /// Shepherd page's whole point rather than showing empty cards.
  ///
  /// ADDED 2026-08-06 with the Family Management rebuild. Without it the
  /// panel would display a working feature looking broken — the exact trap
  /// the relationship fixtures set earlier the same day, where the fakes
  /// were the only source of a value the real fetch never selected.
  ///
  /// Shapes deliberately chosen to cover all four states the card can
  /// render: something owed (Abdul), a plain event (Hassan), several
  /// events (Ibrahim), and nothing at all — index 3+ returns empty, which
  /// is the case the honest empty copy exists for.
  static List<ShepherdActivity> fakeActivityFor(String devId) {
    final now = DateTime.now();
    return switch (devId) {
      'dev-shepherd-0' => [
        ShepherdActivity(
          mentorId: devId,
          type: 'review_waiting',
          occurredAt: now.subtract(const Duration(days: 2)),
        ),
        ShepherdActivity(
          mentorId: devId,
          type: 'suggested',
          occurredAt: now.subtract(const Duration(days: 9)),
          detail: 'Elijah',
        ),
        ShepherdActivity(
          mentorId: devId,
          type: 'linked',
          occurredAt: now.subtract(const Duration(days: 61)),
        ),
      ],
      'dev-shepherd-1' => [
        ShepherdActivity(
          mentorId: devId,
          type: 'review_answered',
          occurredAt: now.subtract(const Duration(days: 5)),
          detail: 'approve',
        ),
        ShepherdActivity(
          mentorId: devId,
          type: 'linked',
          occurredAt: now.subtract(const Duration(days: 40)),
        ),
      ],
      'dev-shepherd-2' => [
        ShepherdActivity(
          mentorId: devId,
          type: 'suggested',
          occurredAt: now.subtract(const Duration(hours: 5)),
          detail: 'David',
        ),
        ShepherdActivity(
          mentorId: devId,
          type: 'suggested',
          occurredAt: now.subtract(const Duration(days: 3)),
          detail: 'Jonah',
        ),
        ShepherdActivity(
          mentorId: devId,
          type: 'linked',
          occurredAt: now.subtract(const Duration(days: 18)),
        ),
      ],
      // Shepherds 3–5 have no activity, on purpose. Someone who has just
      // linked has genuinely done nothing, and the honest empty copy on the
      // detail page needs a case that reaches it.
      _ => const [],
    };
  }

  /// Fake Journeys for the Connections page.
  ///
  /// `isMock: true` on every one — the model already carries that flag for
  /// exactly this, and it is what stops a screen trying to call
  /// `end_journey` on a match id the server has never heard of.
  ///
  /// Ended ones get an `endedAt` well past the 24-hour cooling period, so
  /// Restart is reachable rather than permanently greyed out.
  /// [viewerGender] is passed in rather than read from AppState, so this
  /// file keeps depending on nothing but the models. The fakes are shown the
  /// opposite gender, matching the gender segregation Browse enforces.
  /// [pool] is REAL profiles — with real photos — that the fake Journeys are
  /// wrapped around.
  ///
  /// CHANGED 2026-08-07 (Founder: "I get this white box, so make them profile
  /// cards… if needed make profiles with photos we already have").
  ///
  /// The first version invented people with `photos: const []`, and an empty
  /// photo list renders as a blank white tile — which is what the white box
  /// was. Inventing a profile means inventing everything a card draws, and
  /// the one thing that cannot be invented client-side is a signed photo URL.
  ///
  /// So the fakes now borrow real seeded profiles and only fabricate the
  /// JOURNEY STATE around them. Everything a card renders is genuine; only
  /// the status is staged.
  ///
  /// Real Journeys are account truth and are always returned. Scenario
  /// counts add preview cards around them; zero means zero PREVIEWS, not
  /// zero real people. This supersedes the 2026-08-12 absolute-count model,
  /// which could hide a working Journey and replace it with a fake Active
  /// card that could not enter the flow.
  static List<JourneyMatch> composeJourneys({
    String? viewerGender,
    String? currentUserId,
    List<SeekerProfile> pool = const [],
    SelahPlan viewerPlan = SelahPlan.basic,
    List<JourneyMatch> realActive = const [],
    List<JourneyMatch> realPotential = const [],
    List<JourneyMatch> realPaused = const [],
    List<JourneyMatch> realEnded = const [],
  }) {
    final s = SelahDevScenario.instance;
    final now = DateTime.now();
    // Real account truth is always present. Scenario counts now mean EXTRA
    // preview cards; zero removes previews, never real people. The old
    // absolute-count model could hide a working server Journey and replace it
    // with a dead-end Active stand-in that looked identical.
    final out = <JourneyMatch>[
      ...realPotential,
      ...realActive,
      ...realPaused,
      ...realEnded,
    ];
    final otherGender = SelahGender.oppositeCode(viewerGender);

    var next = 0;
    // Falls back to a synthesised profile only when no real pool arrived —
    // better a blank card than a crash, but the pool is the intended path.
    SeekerProfile take(String name, int age) {
      if (pool.isEmpty) {
        return SeekerProfile(
          id: 'dev-$name',
          firstName: name,
          age: age,
          city: 'Birmingham',
          photos: const [],
          gender: otherGender,
        );
      }
      return pool[next++ % pool.length];
    }

    JourneyMatch make(
      String id,
      String name,
      int age,
      String status, {
      String? stage,
      SelahJourneyPauseState pause = SelahJourneyPauseState.active,
      DateTime? suspendedAt,
      DateTime? endedAt,
      bool inAnotherJourney = false,
    }) => JourneyMatch(
      matchId: id,
      profile: take(name, age),
      status: status,
      journeyStage: stage,
      pause: pause,
      suspendedAt: suspendedAt,
      endedAt: endedAt,
      inAnotherJourney: inAnotherJourney,
      isMock: true,
    );

    // "In another Journey" — PER SECTION since 2026-08-13: the first N
    // fakes of each section are busy, N being that section's own panel
    // count. FAKES ONLY (an Active Journey with the tester cannot also
    // be with someone else, so the active loop has no count). Clamped by
    // construction: a fake index only exists for a built fake.
    //
    final me = currentUserId ?? SelahAuth.currentUser?.id ?? 'dev-me';

    // ── TEN NAMES PER LIST, 2026-08-09, up from five.
    //
    // The dev panel now offers up to 10 for Potential, Paused and Ended
    // (SELAH One's caps — see data/selah_entitlements.dart). With five names
    // the generator silently produced five rows for a toggle that said ten,
    // which is a control panel lying about the state it just created — the
    // exact failure this panel exists to avoid.
    // One lookup for all four loops below.
    final limits = SelahEntitlements.of(viewerPlan);

    const queuedNames = [
      'Elijah',
      'Nathan',
      'Joel',
      'Musa',
      'Zaid',
      'Harun',
      'Peter',
      'Andrew',
      'Kamal',
      'Mark',
    ];
    final nQueued = SelahEntitlements.devClamp(
      s.queuedJourneys,
      limits.potential,
    );
    for (var i = 0; i < nQueued; i++) {
      if (i >= queuedNames.length) break;
      out.add(
        make(
          'dev-q$i',
          queuedNames[i],
          26 + i,
          'potential',
          inAnotherJourney: i < s._busyPotential,
        ),
      );
    }

    // SIMULATION ONLY — the two counts are now INDEPENDENT.
    //
    // Both categories are stored as status='active' match rows, while the
    // shared pause_state determines which capacity and section they occupy.
    //
    // Here `activeJourneys` means extra RUNNING previews and
    // `pausedJourneys` means extra PAUSED previews. Every preview is isMock
    // and never reaches the database; real rows above remain untouched.
    //
    // 2026-08-09: the counts are CLAMPED TO THE CURRENT PLAN by the same
    // helper the panel's segments use, so switching SELAH One -> Basic with
    // Paused at 8 shows Basic's 5 in both places. Without a shared clamp
    // the row and the list drift apart on a plan switch, and the panel
    // stops being the source of truth it claims to be.
    const activeNames = ['Joanna', 'Esther', 'Phoebe', 'Abigail', 'Priscilla'];
    const pausedNames = [
      'Priscilla',
      'Naomi',
      'Chloe',
      'Halima',
      'Lydia',
      'Rabia',
      'Sumaya',
      'Zahra',
      'Iman',
      'Lydia',
    ];
    // Active previews exist only as a defensive bridge for an old hot-reload
    // session or a preview Potential card promoted locally. The clean panel
    // never exposes an Active count: its Journey action finds/seeds a real
    // match. Connections also converts any surviving Active preview into a
    // real walkable Journey when entered.
    final nActive = SelahEntitlements.devClamp(s.activeJourneys, limits.active);
    for (var i = 0; i < nActive; i++) {
      if (i >= activeNames.length) break;
      out.add(
        make(
          'dev-a$i',
          activeNames[i],
          27 + i,
          'active',
          stage: 'conversation',
        ),
      );
    }
    final nPaused = SelahEntitlements.devClamp(s.pausedJourneys, limits.paused);
    for (var i = 0; i < nPaused; i++) {
      if (i < pausedNames.length) {
        final fakeId = 'dev-p$i';
        final f = i;
        final scenario = i == 0
            ? s._pauseScenario
            : SelahPauseDevScenario.mutuallyPaused;
        final pause = scenario.stateFor(
          viewerId: me,
          otherId: 'dev-other-$i',
          now: now,
        );
        out.add(
          make(
            fakeId,
            pausedNames[f],
            26 + i,
            scenario.isEnded ? 'ended' : 'active',
            stage: 'conversation',
            pause: pause,
            inAnotherJourney: f < s._busyPaused,
            suspendedAt: i == 0
                ? now.subtract(const Duration(days: 95))
                : now.subtract(const Duration(days: 3)),
            endedAt: scenario.isEnded ? now : null,
          ),
        );
      }
    }

    const endedNames = [
      'Miriam',
      'Hafsa',
      'Ruqayya',
      'Asma',
      'Juwayriya',
      'Umm Kulthum',
      'Phoebe bint Ali',
      'Ramla',
      'Barira',
      'Nusayba',
    ];
    final nEnded = SelahEntitlements.devClamp(s.endedJourneys, limits.ended);
    for (var i = 0; i < nEnded; i++) {
      if (i < endedNames.length) {
        final f = i;
        out.add(
          make(
            'dev-e$i',
            endedNames[f],
            25 + i,
            'ended',
            endedAt: now.subtract(Duration(days: 2 + i)),
            inAnotherJourney: f < s._busyEnded,
          ),
        );
      }
    }

    return out;
  }

  /// True when any Journey row is above zero — used to skip the candidate
  /// pool fetch when nothing would be drawn from it.
  bool get anyJourneysStaged =>
      _queuedJourneys > 0 ||
      _activeJourneys > 0 ||
      _pausedJourneys > 0 ||
      _endedJourneys > 0;

  // journeysOverridden and holdsRealActiveJourneys REMOVED 2026-08-12: in
  // dev builds composeJourneys() is now the only source of the Connections
  // list, so there is no longer an "overridden vs real" fork for either
  // getter to arbitrate. The rows are always in charge; release builds
  // never call any of this.

  /// Invitations this Seeker has RECEIVED from a Shepherd.
  ///
  /// PREVIEW ONLY, and it cannot be otherwise today: `mentor_invites` has no
  /// recipient. The flow is "generate a code, share it however you like", so
  /// nobody — including SELAH — knows who an invite is for until they type
  /// the code in. There is nothing to list.
  ///
  /// Making this real needs invites to become ADDRESSED (sent to an account,
  /// a phone number or an email) rather than bearer tokens. That is a
  /// product decision, not a screen. This exists so the layout can be judged
  /// before that decision is taken.
  static List<({String from, String relationship, int daysAgo})> fakeReceived(
    int count,
  ) {
    const all = [
      (from: 'Peter', relationship: 'father', daysAgo: 0),
      (from: 'Mark', relationship: 'brother', daysAgo: 2),
      (from: 'Matthew', relationship: 'uncle', daysAgo: 5),
      (from: 'Elijah', relationship: 'grandfather', daysAgo: 9),
      (from: 'Nathan', relationship: 'legal_shepherd', daysAgo: 14),
    ];
    return [for (var i = 0; i < count && i < all.length; i++) all[i]];
  }

  /// Fake pending invites, shaped so the section renders every variant:
  /// labelled, unlabelled, and expiring today.
  static List<PendingInvite> fakePending(int count) {
    final now = DateTime.now();
    return [
      for (var i = 0; i < count && i < fakePendingInvites.length; i++)
        PendingInvite(
          // A plausible token, so an unlabelled invite shows what a real
          // one would rather than something obviously fake.
          token: 'DEV${(i + 1) * 11117 % 100000}'
              .padRight(8, 'X')
              .substring(0, 8),
          label: fakePendingInvites[i].label,
          createdAt: now.subtract(
            Duration(days: 7 - fakePendingInvites[i].daysLeft),
          ),
          expiresAt: now.add(Duration(days: fakePendingInvites[i].daysLeft)),
        ),
    ];
  }

  // ═══════════════════════════════════════════════════════════════════
  // — Mentor side — inherited decision 152, 2026-08-13
  // ═══════════════════════════════════════════════════════════════════
  //
  // Same rule as everything above: A TOGGLE MUST CHANGE SOMETHING REAL,
  // and every field here names its reader.
  //
  // TWO CONTROLS THE BRIEF ASKED FOR ARE DELIBERATELY ABSENT, because a
  // field nothing renders is the exact failure this file's header rule
  // exists to prevent. Both appear in the panel as REFUSED rows pointing
  // at Developer Access, rather than as steppers writing into nothing:
  //
  //   Invitations received  `mentor_invites` has no recipient column. An
  //                         invite is a bearer code typed into
  //                         accept_mentor_invite_screen — there is no list
  //                         to stage, and no screen that renders one.
  //                         (Same limit the Seeker panel records against
  //                         its own receivedInviteCount, which survives
  //                         only because seeker_mentor_tab draws a PREVIEW
  //                         section for it. No Shepherd equivalent exists.)
  //   Introductions sent    SelahShepherdSuggestionService.fetchPending()
  //                         reads suggestions FOR a Seeker; both of its
  //                         callers are Seeker screens. Nothing on the
  //                         Shepherd side shows what this Shepherd put
  //                         forward, so there is nothing to top up.
  //
  // Readers for what IS here:
  //   mentorLinkedSeekers  → composeMentorWards() → MentorSeekersScreen,
  //                        MentorDashboardScreen
  //   active/stage/      → composeMentorJourneys() → MentorDashboardScreen,
  //   paused/ended         MentorJourneyDetailScreen
  //   reviewWaiting      → mentorOpenReviewIds() → Dashboard badge;
  //                        mentorStagedReview() → detail screen
  //   mentorRole           → gates BOTH of the above, and is the reason the
  //                        refusal path came back (see [MentorRole])
  //   sentInvites        → composeMentorSentInvites() →
  //                        MentorInviteSeekerScreen
  //   mentorUnread         → MentorHomeShell's My SELAH tab badge

  /// Where the Shepherd currently is. Context, not scenario — reset()
  /// leaves it alone, exactly as it leaves [currentPage] alone.
  MentorPage currentMentorPage = MentorPage.dashboard;

  void setCurrentMentorPage(MentorPage page) {
    if (currentMentorPage == page) return;
    currentMentorPage = page;
    notifyListeners();
  }

  /// Main or Additional. Defaults to Main because that is the role the
  /// Shepherd flows were built for and the one a fresh link receives —
  /// `mentor_links.is_main` auto-designates the first active link.
  MentorRole _mentorRole = MentorRole.main;
  MentorRole get mentorRole => _mentorRole;
  bool get mentorIsMain => _mentorRole == MentorRole.main;

  void setMentorRole(MentorRole r) {
    if (_mentorRole == r) return;
    _mentorRole = r;
    notifyListeners();
  }

  /// Seekers under this Shepherd. Real links first, stand-ins topping up.
  // Staged Browse-activity counts for the Dashboard's ward chips —
  // inherited decision 171. STAGED ONLY, by design: a ward's Saved/Considered/
  // Declined lists have no Shepherd read path in RLS today, so these
  // numbers exist purely so the Founder can review the design. The real
  // read is its own privacy decision, raised in the register.
  // ── THE JOURNEY EXPERIENCE LAB — inherited decision 172 ─────────────────────
  // Which of the five candidate first-page experiences the Journey's
  // Compatibility Reveal wears. 0 = today's build; 1-5 per
  // JourneyExperienceLab.labels (Path · Chamber · Ascent · Ritual ·
  // Table). Chrome around the REAL view — never a mock of it.
  int _journeyExperience = 0;
  int get journeyExperience => _journeyExperience;

  void setJourneyExperience(int v) {
    final n = v.clamp(0, 5);
    if (_journeyExperience == n) return;
    _journeyExperience = n;
    notifyListeners();
  }

  int _wardSaved = 0;
  int get wardSaved => _wardSaved;
  void setWardSaved(int v) {
    final n = v.clamp(0, 99);
    if (_wardSaved == n) return;
    _wardSaved = n;
    notifyListeners();
  }

  int _wardConsidered = 0;
  int get wardConsidered => _wardConsidered;
  void setWardConsidered(int v) {
    final n = v.clamp(0, 99);
    if (_wardConsidered == n) return;
    _wardConsidered = n;
    notifyListeners();
  }

  int _wardDeclined = 0;
  int get wardDeclined => _wardDeclined;
  void setWardDeclined(int v) {
    final n = v.clamp(0, 99);
    if (_wardDeclined == n) return;
    _wardDeclined = n;
    notifyListeners();
  }

  int _mentorLinkedSeekers = 0;
  int get mentorLinkedSeekers => _mentorLinkedSeekers;
  void setMentorLinkedSeekers(int v) {
    final n = v.clamp(0, fakeWards.length);
    if (_mentorLinkedSeekers == n) return;
    _mentorLinkedSeekers = n;
    notifyListeners();
  }

  /// Journeys belonging to those Seekers.
  ///
  /// ACTIVE + PAUSED IS CAPPED BY THE WARD COUNT, not by a number chosen
  /// here: one Active Journey per Seeker is the platform invariant
  /// (UNIQUE partial indexes on matches.seeker_a_id / seeker_b_id WHERE
  /// status = 'active'), and pausing sets suspended_by while leaving the
  /// status 'active' — the same slot. Two Journeys for one ward is a
  /// picture of something the database refuses. Ended rows are history,
  /// not slots, so they are not capped against it.
  int _mentorActiveJourneys = 0;
  int _mentorPausedJourneys = 0;
  int _mentorEndedJourneys = 0;

  int get mentorActiveJourneys => _mentorActiveJourneys;
  int get mentorPausedJourneys => _mentorPausedJourneys;
  int get mentorEndedJourneys => _mentorEndedJourneys;

  void setMentorActiveJourneys(int v) {
    final n = v.clamp(0, _mentorLinkedSeekers);
    if (_mentorActiveJourneys == n) return;
    _mentorActiveJourneys = n;
    notifyListeners();
  }

  void setMentorPausedJourneys(int v) {
    final n = v.clamp(0, _mentorLinkedSeekers);
    if (_mentorPausedJourneys == n) return;
    _mentorPausedJourneys = n;
    notifyListeners();
  }

  void setMentorEndedJourneys(int v) {
    final n = v.clamp(0, _mentorPartners.length);
    if (_mentorEndedJourneys == n) return;
    _mentorEndedJourneys = n;
    notifyListeners();
  }

  /// Which stage the staged Active Journeys sit at — an INDEX into
  /// [SelahJourneyStages.all], never a stage name written here. That map
  /// is the only one (inherited decision 129); this stores a position in it so a
  /// renamed label reaches the panel without a second edit.
  int _mentorStageIndex = 0;
  int get mentorStageIndex => _mentorStageIndex;
  SelahJourneyStage get mentorStage =>
      SelahJourneyStages.all[_mentorStageIndex.clamp(
        0,
        SelahJourneyStages.all.length - 1,
      )];

  void setMentorStageIndex(int v) {
    final n = v.clamp(0, SelahJourneyStages.all.length - 1);
    if (_mentorStageIndex == n) return;
    _mentorStageIndex = n;
    notifyListeners();
  }

  /// A Family Review waiting on THIS Shepherd — the one thing on the
  /// Shepherd's dashboard that is genuinely blocked on them.
  ///
  /// Main Shepherds only, and that is not a panel rule: mentor_review_
  /// decision() checks the caller is an active MAIN Mentor for one of the
  /// two Seekers, so an Additional Shepherd has no vote to cast.
  bool _mentorReviewWaiting = false;
  bool get mentorReviewWaiting => _mentorReviewWaiting && mentorIsMain;

  void setMentorReviewWaiting(bool v) {
    if (_mentorReviewWaiting == v) return;
    _mentorReviewWaiting = v;
    // A fresh review has not been answered. Without this, turning the
    // toggle off and on again would restore a review that still
    // remembered last round's decision.
    _mentorReviewDecision = null;
    notifyListeners();
  }

  /// What this Shepherd chose on the staged review — 'continue' or
  /// 'pause', null until they act.
  ///
  /// THIS IS THE POINT OF THE SECTION. The panel's rule is that a dev
  /// snackbar where the product would act is the panel lying about the
  /// experience, so the stand-in Continue / Pause buttons write here and
  /// the screen re-reads it, greying the buttons and showing "You chose
  /// Continue — waiting on the other family" exactly as a real vote does.
  String? _mentorReviewDecision;
  String? get mentorReviewDecision => _mentorReviewDecision;

  void setMentorReviewDecision(String? d) {
    if (_mentorReviewDecision == d) return;
    _mentorReviewDecision = d;
    notifyListeners();
  }

  /// Invite codes this Shepherd has sent and nobody has redeemed.
  int _mentorSentInvites = 0;
  int get mentorSentInvites => _mentorSentInvites;
  void setMentorSentInvites(int v) {
    final n = v.clamp(0, fakeMentorInvites.length);
    if (_mentorSentInvites == n) return;
    _mentorSentInvites = n;
    notifyListeners();
  }

  /// Unread notifications on the Shepherd's My SELAH tab badge.
  ///
  /// THE BELL IS A TAB, not the top-right overlay it was: MentorHomeShell
  /// dropped the floating Bell on 2026-08-13 and the unread count now
  /// feeds FloatingNavItem.badge. This overrides that count when above
  /// zero, so the badge's own layout (1, 9, 10+) is reachable without
  /// generating ten real notifications.
  int _mentorUnread = 0;
  int get mentorUnread => _mentorUnread;
  void setMentorUnread(int v) {
    final n = v.clamp(0, 12);
    if (_mentorUnread == n) return;
    _mentorUnread = n;
    notifyListeners();
  }

  // SHEPHERD NETWORK PREVIEW CONTROLS RETIRED — 2026-08-23 (inherited upstream action 251).
  // The first-draft plan/scene state that lived here drove the retired
  // 2026-08-22 preview model (dev/shepherd_network_preview.dart, archived
  // in SYSTEM/RESOURCES/OVERNIGHT_GN_2026-08-23/ARCHIVE_RETIRED_PREVIEW/
  // with its test). The current Shepherd Network (D14, GN Draft 3.x)
  // keeps ALL of its staging in GNContext — lib/screens/mentor/
  // mentor_gn_shared.dart — behind the DEV chip on the Network and
  // Dashboard pages. This store still composes the WARDS the Network
  // works on behalf of (mentorLinkedSeekers above); that control remains
  // real and current.

  /// True when any Shepherd-side row is above zero — lets a screen skip
  /// composition entirely when the panel is at rest.
  bool get anyMentorStaged =>
      _mentorLinkedSeekers > 0 ||
      _mentorActiveJourneys > 0 ||
      _mentorPausedJourneys > 0 ||
      _mentorEndedJourneys > 0 ||
      _mentorSentInvites > 0 ||
      _mentorUnread > 0 ||
      _mentorReviewWaiting;

  /// The Shepherd's stand-in wards. Deterministic, so a Journey staged
  /// against `dev-ws1` is still against `dev-ws1` after a recompose.
  ///
  /// Relationships are the STORED CODES, matching fakeShepherds above —
  /// dev data and production data go through the same label lookup, which
  /// is how the 'Paternal uncle' casing bug hid for a week.
  static const List<({String name, String relationship})> fakeWards = [
    (name: 'James', relationship: 'father'),
    (name: 'Isaac', relationship: 'uncle'),
    (name: 'Daniel', relationship: 'brother'),
    (name: 'Peter', relationship: 'grandfather'),
    (name: 'Elijah', relationship: 'legal_shepherd'),
    (name: 'Phoebe', relationship: 'family_representative'),
    (name: 'Daniel', relationship: 'uncle'),
    (name: 'Chloe', relationship: 'other'),
    (name: 'Joel', relationship: 'brother'),
    (name: 'Joel', relationship: 'father'),
  ];

  /// Counterparts, in the shape selah_counterpart_card() actually returns:
  /// first name and age, nothing else.
  ///
  /// `city` '—', `photos` empty and `gender` '' are NOT laziness here, and
  /// this is the one place a stand-in is more honest with an empty photo
  /// list than with a borrowed real profile: a Shepherd is not shown the
  /// other family's photos, city or gender at all (clause 3, closed
  /// 2026-08-08). Borrowing a real profile the way composeJourneys does
  /// for the Seeker would preview a disclosure that does not happen.
  static const List<({String name, int age, String? shepherd, String? surname})>
  _mentorPartners = [
    (name: 'Nathan', age: 29, shepherd: 'Joseph', surname: 'family of Brooks'),
    (name: 'Priscilla', age: 26, shepherd: 'David', surname: 'family of Evans'),
    (name: 'Elijah', age: 31, shepherd: null, surname: null),
    (name: 'Chloe', age: 27, shepherd: 'Mark', surname: 'family of Bennett'),
    (name: 'Joel', age: 33, shepherd: 'Peter', surname: 'family of Martins'),
  ];

  /// Labels for staged sent invites. One is null on purpose — an invite
  /// with no label is the common case and renders as the raw token, which
  /// is the outcome the label exists to avoid.
  static const List<({String? label, int daysLeft})> fakeMentorInvites = [
    (label: 'Rebecca', daysLeft: 6),
    (label: null, daysLeft: 4),
    (label: 'My nephew', daysLeft: 2),
    (label: 'Cousin Joel', daysLeft: 0),
  ];

  /// Seekers under this Shepherd — REAL LINKS FIRST, stand-ins topping up.
  ///
  /// Real-first for the same reason composeJourneys is: a fabricated ward
  /// cannot be tested with. Its id is not a uuid, so every Shepherd action
  /// that reaches the server against it is handed something that is not a
  /// row. Slot 0 is the genuine link when one exists.
  ///
  /// 0 MEANS ZERO, real links included — the panel is the source of truth
  /// while it is driving, which is what makes Reset mean reset.
  static List<MentorLinkedPerson> composeMentorWards({
    List<MentorLinkedPerson> real = const [],
  }) {
    final s = SelahDevScenario.instance;
    final out = <MentorLinkedPerson>[];
    for (var i = 0; i < s._mentorLinkedSeekers; i++) {
      if (i < real.length) {
        out.add(real[i]);
      } else {
        final f = i - real.length;
        if (f >= fakeWards.length) break;
        out.add(
          MentorLinkedPerson(
            id: 'dev-ws$i',
            firstName: fakeWards[f].name,
            // A Seeker has exactly one Main Shepherd, and this Shepherd is
            // either it or not — the role is a property of the LINK, so
            // every staged ward agrees with the role segment.
            isMain: s.mentorIsMain,
            relationship: fakeWards[f].relationship,
          ),
        );
      }
    }
    return out;
  }

  /// Journeys for the staged wards, in the shape the Shepherd screens read.
  ///
  /// This composes the richer Journey view used by Main-only surfaces.
  /// Additional Shepherds receive their separate four-field summary inside
  /// the Seeker workspace, so they still do not enter this counterpart/stage
  /// path.
  static List<MentorJourneyView> composeMentorJourneys({
    required List<MentorLinkedPerson> wards,
    List<MentorJourneyView> real = const [],
  }) {
    final s = SelahDevScenario.instance;
    final now = DateTime.now();
    if (!s.mentorIsMain) return const [];

    final realActive = [
      for (final j in real)
        if (j.status != 'ended' && !j.isSuspended) j,
    ];
    final realPaused = [
      for (final j in real)
        if (j.status != 'ended' && j.isSuspended) j,
    ];
    final realEnded = [
      for (final j in real)
        if (j.status == 'ended') j,
    ];

    // One Active Journey per Seeker — see the field comment. Paused takes
    // what Active left, so the two can never claim the same ward.
    final slots = wards.length;
    final nActive = s._mentorActiveJourneys.clamp(0, slots);
    final nPaused = s._mentorPausedJourneys.clamp(0, slots - nActive);
    final nEnded = s._mentorEndedJourneys.clamp(0, _mentorPartners.length);

    final out = <MentorJourneyView>[];
    var partner = 0;

    MentorJourneyView make(
      String id,
      MentorLinkedPerson ward,
      String status, {
      String? stage,
      SelahJourneyPauseState pause = SelahJourneyPauseState.active,
    }) {
      final p = _mentorPartners[partner++ % _mentorPartners.length];
      return MentorJourneyView(
        matchId: id,
        linkedSeekerId: ward.id,
        linkedSeekerName: ward.firstName,
        partner: SeekerProfile(
          id: 'dev-wp$id',
          firstName: p.name,
          age: p.age,
          city: '—', // withheld by the card, not missing
          photos: const [], // withheld by the card, not missing
          gender: '', // not disclosed to Shepherds
        ),
        counterpartShepherdName: p.shepherd,
        counterpartShepherdSurname: p.surname,
        status: status,
        journeyStage: stage,
        pause: pause,
        isMock: true,
      );
    }

    final stageValue = s.mentorStage.value;

    for (var i = 0; i < nActive; i++) {
      if (i < realActive.length) {
        out.add(realActive[i]);
      } else if (i < wards.length) {
        out.add(
          make(
            'dev-wj$i',
            wards[i],
            'active',
            stage: stageValue,
            pause: i == 0 && s._dashboardShepherdJourneyDecisionPending
                ? SelahJourneyPauseState(
                    phase: SelahPausePhase.pauseDecisionPending,
                    initiatedBy: wards[i].id,
                    requestedBy: wards[i].id,
                    requestedAt: now,
                    version: 1,
                  )
                : SelahJourneyPauseState.active,
          ),
        );
      }
    }
    for (var i = 0; i < nPaused; i++) {
      final wardIndex = nActive + i;
      if (i < realPaused.length) {
        out.add(realPaused[i]);
      } else if (wardIndex < wards.length) {
        out.add(
          make(
            'dev-wp$i',
            wards[wardIndex],
            'active',
            stage: stageValue,
            // Shepherd wording is neutral: it sees the Journey state,
            // never which Seeker opened the decision.
            pause: const SelahJourneyPauseState(
              phase: SelahPausePhase.paused,
              initiatedBy: 'dev-seeker',
              version: 2,
            ),
          ),
        );
      }
    }
    for (var i = 0; i < nEnded; i++) {
      if (i < realEnded.length) {
        out.add(realEnded[i]);
      } else if (wards.isNotEmpty) {
        // Ended Journeys are history, so they reuse wards freely — the
        // same Seeker having ended one Journey and started another is
        // the ordinary case, not an edge one.
        out.add(make('dev-we$i', wards[i % wards.length], 'ended'));
      }
    }
    // No endedAt is stamped: MentorJourneyView carries no timestamp, and a
    // Shepherd's Journey list shows "Journey ended" with no cooling
    // period behind it. Nothing to fabricate here.
    return out;
  }

  /// Journeys the Dashboard should badge as having a Family Review open.
  ///
  /// STAND-INS ONLY. Staging a review against a REAL matchId would put a
  /// Continue button on screen that then calls mentor_review_decision()
  /// with an id the server has no review row for — the panel showing a
  /// decision that cannot be taken.
  static Set<String> mentorOpenReviewIds(List<MentorJourneyView> journeys) {
    final s = SelahDevScenario.instance;
    if (!s.mentorReviewWaiting) return const {};
    return {
      for (final j in journeys)
        if (j.isMock && j.status != 'ended' && !j.isSuspended) j.matchId,
    };
  }

  /// The staged Family Review, in the record shape
  /// mentor_journey_detail_screen already renders. Null is the same "no
  /// review" the real fetch returns, so the screen needs no new branch.
  ///
  /// `toStage` is the NEXT stage in the canonical sequence, derived from
  /// the one map rather than named here — a review is the gate BETWEEN
  /// two stages, so the stage it leads to cannot be invented separately.
  static ({String id, String status, String toStage, DateTime deadlineAt})?
  mentorStagedReview() {
    final s = SelahDevScenario.instance;
    if (!s.mentorReviewWaiting) return null;
    final i = s._mentorStageIndex;
    final next = i + 1 < SelahJourneyStages.all.length
        ? SelahJourneyStages.all[i + 1].value
        // Open Conversation is terminal — there is no stage after it and
        // therefore no review that could gate one. Falling back to the
        // current stage keeps the record well-formed; the panel refuses
        // the toggle there instead of relying on this.
        : SelahJourneyStages.all[i].value;
    return (
      id: 'dev-review-0',
      status: 'pending',
      toStage: next,
      // Inside the 48h window and not a round number, so the countdown
      // renders as "41h 12m" rather than something that reads as a
      // placeholder.
      deadlineAt: DateTime.now().add(const Duration(hours: 41, minutes: 12)),
    );
  }

  /// Invite codes this Shepherd has sent — real rows first, stand-ins
  /// topping up, same rule as everywhere else.
  static List<PendingInvite> composeMentorSentInvites({
    List<PendingInvite> real = const [],
  }) {
    final s = SelahDevScenario.instance;
    final now = DateTime.now();
    final out = <PendingInvite>[];
    for (var i = 0; i < s._mentorSentInvites; i++) {
      if (i < real.length) {
        out.add(real[i]);
      } else {
        final f = i - real.length;
        if (f >= fakeMentorInvites.length) break;
        out.add(
          PendingInvite(
            token: 'DEVW${(f + 1) * 7919 % 10000}'
                .padRight(8, 'X')
                .substring(0, 8),
            label: fakeMentorInvites[f].label,
            createdAt: now.subtract(
              Duration(days: 7 - fakeMentorInvites[f].daysLeft),
            ),
            expiresAt: now.add(Duration(days: fakeMentorInvites[f].daysLeft)),
          ),
        );
      }
    }
    return out;
  }

  // ---------------------------------------------------------------------

  // set_() REMOVED 2026-08-12. It ran an arbitrary closure and notified,
  // which meant state could change without this class knowing WHICH state —
  // the reason reset() drifted out of step with the fields. Every mutation
  // now goes through a named,
  // guarded setter above.

  /// Everything simulated, back to zero, in one notify. "Zero means zero.
  /// Every time." (Founder, 2026-08-12.)
  ///
  /// Enumerates EVERY simulated axis — when a field is added to this class,
  /// it is added here in the same change or the panel's Reset silently lies,
  /// which is the failure this file's header rule exists to prevent.
  /// `currentPage` is deliberately untouched: it records where the user IS,
  /// not a simulation. Server-backed dev state (credits, Introductions,
  /// Shepherds-on-decided, the plan row) is the panel's reset flow to clear —
  /// it lives in the database, not here.
  void reset() {
    pendingPopup = null;
    _useLiveShepherdData = false;
    _mainShepherd = false;
    _additionalShepherdCount = 0;
    _pendingInviteCount = 0;
    _receivedInviteCount = 0;
    _shepherdPreviewActiveJourneyCount = 1;
    _connectionsPreviewIsolated = true;
    _queuedJourneys = 0;
    _activeJourneys = 0;
    _pausedJourneys = 0;
    _endedJourneys = 0;
    _busyPotential = 0;
    _busyPaused = 0;
    _busyEnded = 0;
    _pauseScenario = SelahPauseDevScenario.active;
    _browseSwipeFeedbackStyle = SelahBrowseSwipeFeedbackStyle.fullAura;
    _introductionPreviewCount = 0;
    _consideredPreviewCount = 0;
    _savedPreviewCount = 0;
    _passedPreviewCount = 0;
    _localProfileDestinations.clear();
    _hiddenLocalProfileIds.clear();
    resetDashboardLab(notify: false);
    SelahColors.selectAppSurfaceStyle(SelahColors.currentDefaultSurfaceStyle);
    // — Mentor side — inherited decision 152. Enumerated here in the same change that
    // added them, per this method's own rule. `currentMentorPage` is
    // deliberately absent for the same reason `currentPage` is: it
    // records where the Shepherd IS, not a simulation.
    _journeyExperience = 0;
    _wardSaved = 0;
    _wardConsidered = 0;
    _wardDeclined = 0;
    _mentorRole = MentorRole.main;
    _mentorLinkedSeekers = 0;
    _mentorActiveJourneys = 0;
    _mentorPausedJourneys = 0;
    _mentorEndedJourneys = 0;
    _mentorStageIndex = 0;
    _mentorReviewWaiting = false;
    _mentorReviewDecision = null;
    _mentorSentInvites = 0;
    _mentorUnread = 0;
    notifyListeners();
  }
}
