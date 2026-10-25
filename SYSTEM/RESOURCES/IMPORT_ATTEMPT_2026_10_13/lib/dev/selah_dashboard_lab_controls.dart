import 'package:flutter/material.dart';

import '../models/selah_dashboard_lab.dart';
import '../services/selah_developer_access.dart';
import 'selah_dev_page_options.dart';
import 'selah_dev_scenario.dart';
import 'selah_supportive_dashboard_preview.dart';

/// Follows the tab on the mounted renderer, not an independent panel switch.
String selahDashboardOptionsTitle(
  SelahDevScenario scenario,
  SelahDashboardRole hostRole,
) {
  final preview = SupportiveDashboardPreview.instance;
  final tab =
      hostRole == SelahDashboardRole.seeker &&
          SupportiveDashboardPreview.allowed &&
          preview.enabled
      ? SelahDashboardTab.values[preview.tabIndex]
      : scenario.dashboardTab;
  return tab.label;
}

/// The third developer door contains separate category dropdowns. The page owners
/// still own rendering, navigation, data sources and authorization.
class SelahDashboardLabControls extends StatelessWidget {
  final SelahDevScenario scenario;
  final SelahDashboardRole hostRole;
  final List<SelahDevPageOption> additionalOptions;

  const SelahDashboardLabControls({
    super.key,
    required this.scenario,
    this.hostRole = SelahDashboardRole.seeker,
    this.additionalOptions = const [],
  });

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([
      scenario,
      SupportiveDashboardPreview.instance,
      SelahDeveloperAccess.authorizationChanges,
    ]),
    builder: (context, _) => SelahDevPageOptions(
      contextKey:
          'dashboard-${hostRole.name}-'
          '${selahDashboardOptionsTitle(scenario, hostRole)}-'
          '${hostRole == SelahDashboardRole.shepherd ? scenario.shepherdRole.name : 'seeker'}',
      options: [
        ...selahDashboardPageOptions(scenario, hostRole),
        ...additionalOptions,
      ],
    ),
  );
}

/// Public composition seam for the existing role-specific panel hosts.
List<SelahDevPageOption> selahDashboardPageOptions(
  SelahDevScenario scenario,
  SelahDashboardRole hostRole,
) => hostRole == SelahDashboardRole.seeker
    ? _seekerOptions(scenario)
    : _shepherdOptions(scenario);

List<SelahDevPageOption> _seekerOptions(SelahDevScenario scenario) {
  final preview = SupportiveDashboardPreview.instance;
  final insights =
      selahDashboardOptionsTitle(scenario, SelahDashboardRole.seeker) ==
      'Insights';
  final prefix = insights ? 'seeker-insights' : 'seeker-now';
  final sample = preview.enabled && !preview.useCurrentSources;
  final options = <SelahDevPageOption>[];

  void add(
    String id,
    String label,
    String group,
    VoidCallback apply, {
    bool selected = false,
  }) {
    options.add(
      SelahDevPageOption(
        id: '$prefix-$id',
        label: label,
        group: group,
        selected: selected,
        unavailableReason: SupportiveDashboardPreview.allowed
            ? null
            : 'Local examples require an authorized non-release build.',
        onSelected: SupportiveDashboardPreview.allowed
            ? () {
                // Recheck at dispatch: a menu may outlive its authorization.
                if (SupportiveDashboardPreview.allowed) apply();
              }
            : null,
      ),
    );
  }

  void state(
    String id,
    String label,
    SupportivePreviewScenario value, {
    String group = 'Page view',
  }) {
    add(
      id,
      label,
      group,
      () => preview.selectScenario(value),
      selected: sample && preview.scenario == value,
    );
  }

  add(
    'current',
    'Current page data',
    'Page view',
    () {
      // Capture before activating the new renderer; its previous session tab
      // must not pull an Insights page back to Now.
      final tab = insights ? 1 : 0;
      preview.selectTab(tab);
      preview.selectSources(true);
      preview.selectView(true);
    },
    selected: preview.enabled && preview.useCurrentSources,
  );

  if (!insights) {
    state('all', 'All Now sections', SupportivePreviewScenario.allNow);
    state('clear', 'All clear', SupportivePreviewScenario.allClear);
    state(
      'several',
      'Several actions',
      SupportivePreviewScenario.severalActions,
    );
    state(
      'changes',
      'Recent changes together',
      SupportivePreviewScenario.recentChanges,
    );
    add(
      'editorial',
      'From SELAH example',
      'Page view',
      () => preview.selectEditorial(SupportiveEditorialExample.productUpdate),
      selected:
          sample &&
          preview.scenario == SupportivePreviewScenario.editorial &&
          preview.editorial == SupportiveEditorialExample.productUpdate,
    );

    for (final value in SupportiveActionExample.values) {
      add(
        'action-${value.name}',
        value.label,
        'What Needs You',
        () => preview.selectAction(value),
        selected:
            sample &&
            preview.scenario == SupportivePreviewScenario.oneAction &&
            preview.action == value,
      );
    }
    for (final value in SupportiveStatusExample.values) {
      final label = switch (value) {
        SupportiveStatusExample.noShepherd => 'No Shepherd connected',
        SupportiveStatusExample.paused => 'Journey paused',
        _ => value.label,
      };
      add(
        'status-${value.name}',
        label,
        'Current status',
        () => preview.selectStatus(value),
        selected:
            sample &&
            preview.scenario == SupportivePreviewScenario.statusExample &&
            preview.status == value,
      );
    }
    for (final value in SupportiveChangeExample.values) {
      add(
        'change-${value.name}',
        value.label,
        'What Changed',
        () => preview.selectChange(value),
        selected:
            sample &&
            preview.scenario == SupportivePreviewScenario.changed &&
            preview.change == value,
      );
    }
    for (final value in SupportiveEditorialExample.values) {
      add(
        'editorial-${value.name}',
        value.label,
        'From SELAH',
        () => preview.selectEditorial(value),
        selected:
            sample &&
            preview.scenario == SupportivePreviewScenario.editorial &&
            preview.editorial == value,
      );
    }
    state(
      'loading',
      'Updates loading',
      SupportivePreviewScenario.loading,
      group: 'Updates availability',
    );
    state(
      'failed',
      'Updates unavailable',
      SupportivePreviewScenario.failed,
      group: 'Updates availability',
    );
    state(
      'last-known',
      'Last-known updates',
      SupportivePreviewScenario.lastKnown,
      group: 'Updates availability',
    );
    return options;
  }

  add(
    'all',
    'All four categories',
    'Page view',
    () => preview.selectInsight(SupportiveInsightExample.all),
    selected:
        sample &&
        preview.scenario == SupportivePreviewScenario.insightsPopulated &&
        preview.insight == SupportiveInsightExample.all,
  );
  state('empty', 'No insights yet', SupportivePreviewScenario.insightsEmpty);
  state(
    'failed',
    'Insights unavailable',
    SupportivePreviewScenario.insightsFailed,
  );

  const insightChoices = [
    (SupportiveInsightExample.familyValues, 'Family values', 'What’s Working'),
    (
      SupportiveInsightExample.faith,
      'Faith — sensitive example',
      'What’s Working',
    ),
    (
      SupportiveInsightExample.helpfulReflections,
      'Helpful reflections',
      'What’s Working',
    ),
    (
      SupportiveInsightExample.familyInvolvement,
      'Earlier family involvement',
      'What’s Working',
    ),
    (
      SupportiveInsightExample.completedJourneys,
      'Completed Journeys',
      'What Keeps Happening',
    ),
    (
      SupportiveInsightExample.pausedJourneys,
      'Paused Journeys',
      'What Keeps Happening',
    ),
    (
      SupportiveInsightExample.repeatedStage,
      'Repeated ending stage',
      'What Keeps Happening',
    ),
    (
      SupportiveInsightExample.reflectionTheme,
      'Communication pace',
      'What You’ve Learned',
    ),
    (
      SupportiveInsightExample.personalisedGuide,
      'Personalised guidance',
      'What May Help',
    ),
    (
      SupportiveInsightExample.generalGuide,
      'General guidance',
      'What May Help',
    ),
  ];
  for (final (value, label, group) in insightChoices) {
    add(
      'insight-${value.name}',
      label,
      group,
      () {
        if (value == SupportiveInsightExample.reflectionTheme) {
          preview.selectReflection(SupportiveReflectionTopic.pace);
        } else {
          preview.selectInsight(value);
        }
      },
      selected:
          sample &&
          preview.scenario == SupportivePreviewScenario.insightsPopulated &&
          preview.insight == value &&
          (value != SupportiveInsightExample.reflectionTheme ||
              preview.reflection == SupportiveReflectionTopic.pace),
    );
  }
  for (final value in SupportiveReflectionTopic.values) {
    final parts = value.label.split(' · ');
    add(
      'reflection-${value.name}',
      parts.last,
      value.index < 5
          ? 'Reflection topics · positive'
          : 'Reflection topics · different approach',
      () => preview.selectReflection(value),
      selected:
          sample &&
          preview.scenario == SupportivePreviewScenario.insightsPopulated &&
          preview.insight == SupportiveInsightExample.reflectionTheme &&
          preview.reflection == value,
    );
  }
  return options;
}

List<SelahDevPageOption> _shepherdOptions(SelahDevScenario scenario) {
  final insights = scenario.dashboardTab == SelahDashboardTab.insights;
  final prefix = insights ? 'shepherd-insights' : 'shepherd-now';
  final options = <SelahDevPageOption>[];

  void add(
    String id,
    String label,
    String group,
    VoidCallback apply, {
    bool selected = false,
  }) {
    options.add(
      SelahDevPageOption(
        id: '$prefix-$id',
        label: label,
        group: group,
        selected: selected,
        onSelected: () {
          if (SelahDeveloperAccess.canUseDeveloperTools) {
            scenario.markDashboardShepherdOptionSelected(
              insights ? SelahDashboardTab.insights : SelahDashboardTab.now,
            );
            apply();
          }
        },
      ),
    );
  }

  add(
    'current',
    'Current page data',
    'Page view',
    () => scenario.setDashboardLabEnabled(false),
    selected:
        scenario.dashboardShepherdOptionSelected(
          insights ? SelahDashboardTab.insights : SelahDashboardTab.now,
        ) &&
        !scenario.dashboardLabEnabled,
  );
  if (!insights) {
    for (final value in SelahShepherdDashboardTodayState.values) {
      add(
        'state-${value.name}',
        value.label,
        'Shepherd Now',
        () {
          final role = scenario.shepherdRole;
          scenario.setDashboardShepherdTodayState(value);
          if (value != SelahShepherdDashboardTodayState.mainShepherd &&
              value != SelahShepherdDashboardTodayState.additionalShepherd) {
            scenario.setShepherdRole(role);
          }
          scenario.setDashboardLabEnabled(true);
        },
        selected:
            scenario.dashboardShepherdOptionSelected(SelahDashboardTab.now) &&
            scenario.dashboardLabEnabled &&
            scenario.dashboardShepherdTodayState == value,
      );
    }
    for (final value in SelahDashboardUpdatesState.values) {
      add(
        'updates-${value.name}',
        value.label,
        'Updates',
        () {
          scenario.setDashboardUpdatesState(value);
          scenario.setDashboardLabEnabled(true);
        },
        selected:
            scenario.dashboardShepherdOptionSelected(SelahDashboardTab.now) &&
            scenario.dashboardLabEnabled &&
            scenario.dashboardUpdatesState == value,
      );
    }
  } else {
    for (final value in SelahShepherdDashboardInsightsState.values) {
      add(
        'state-${value.name}',
        value.label,
        'Shepherd Insights',
        () {
          scenario.setDashboardShepherdInsightsState(value);
          // These are already-rendered local examples, not a grant of real
          // Shepherd access or a new source of family intelligence.
          scenario.setDashboardShepherdPremium(true);
          scenario.setDashboardLabEnabled(true);
        },
        selected:
            scenario.dashboardShepherdOptionSelected(
              SelahDashboardTab.insights,
            ) &&
            scenario.dashboardLabEnabled &&
            scenario.dashboardShepherdPremium &&
            scenario.dashboardShepherdInsightsState == value,
      );
    }
  }
  for (final access in [false, true]) {
    add(
      access ? 'access' : 'no-access',
      access ? 'Shepherd access' : 'No access',
      'Shepherd access',
      () {
        scenario.setDashboardShepherdPremium(access);
        scenario.setDashboardLabEnabled(true);
      },
      selected:
          scenario.dashboardShepherdOptionSelected(
            insights ? SelahDashboardTab.insights : SelahDashboardTab.now,
          ) &&
          scenario.dashboardLabEnabled &&
          scenario.dashboardShepherdPremium == access,
    );
  }
  return options;
}
