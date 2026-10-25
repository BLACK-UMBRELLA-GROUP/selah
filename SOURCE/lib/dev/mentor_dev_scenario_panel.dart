// Shepherd developer tools: Home and Preview retain their existing behavior.
// Actions is one page-aware catalog of existing local scenario setters.
// Role-denied and unsupported previews remain explicit, never fabricated.
// Protected Founder capability is checked by the host and shared category controls.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/selah_dashboard_lab.dart';
import '../theme/selah_colors.dart';

import '../data/selah_journey_stages.dart';
import '../screens/auth_gate.dart';
import '../screens/mentor/mentor_gn_shared.dart';
import '../screens/dev/developer_access_screen.dart';
import '../services/selah_auth.dart';
import '../services/selah_developer_access.dart';
import '../services/selah_promotion_engine.dart';
import '../theme/selah_text.dart';
import 'selah_dev_control_system.dart';
import 'selah_dev_personal_code_fixtures.dart';
import 'selah_dev_page_options.dart';
import 'selah_dashboard_lab_controls.dart';
import 'selah_dev_signup.dart';
import 'selah_dev_home.dart';
import 'selah_page_preview_screen.dart';
import 'selah_dev_scenario.dart';

class MentorDevScenarioPanel extends StatefulWidget {
  final ValueChanged<MentorPage> onOpenPage;

  const MentorDevScenarioPanel({super.key, required this.onOpenPage});

  @override
  State<MentorDevScenarioPanel> createState() => _MentorDevScenarioPanelState();
}

class _MentorDevScenarioPanelState extends State<MentorDevScenarioPanel> {
  bool _open = false;
  SelahDevControlSection _section = SelahDevControlSection.actions;

  static const double _panelWidth = 286;

  final SelahDevScenario _s = SelahDevScenario.instance;
  final SelahPromotionEngine _promotion = SelahPromotionEngine.instance;
  String? _notice;

  @override
  void initState() {
    super.initState();
    _s.addListener(_onChange);
    _promotion.addListener(_onChange);
    GNContext.instance.addListener(_onChange);
  }

  @override
  void dispose() {
    _s.removeListener(_onChange);
    _promotion.removeListener(_onChange);
    GNContext.instance.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  Future<void> _goHome() async {
    setState(() {
      _open = false;
      _notice = null;
    });
    try {
      await SelahAuth.signOut();
    } catch (error) {
      debugPrint('SELAH Shepherd developer Home sign-out failed: $error');
    }
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthGate(playSplash: true)),
      (route) => false,
    );
  }

  /// NO CONFIRM DIALOG, and that is a difference from the Seeker panel
  /// rather than an omission. Its Reset deletes real rows — mock plan
  /// writes, mentor_suggestions, granted credits — so it asks first.
  /// Nothing on this side writes to the server: every Shepherd control
  /// here composes stand-ins in memory. There is nothing to lose and
  /// nothing to confirm.
  void _reset() {
    _s.reset();
    unawaited(_promotion.resetDeveloperPolicy());
    setState(() => _notice = 'Shepherd and Seeker previews reset.');
  }

  void _selectSection(SelahDevControlSection section) {
    setState(() {
      if (_open && _section == section) {
        _open = false;
      } else {
        _section = section;
        _open = true;
      }
      _notice = null;
    });
  }

  void _openCompletePreview() {
    setState(() => _open = false);
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => SelahPagePreviewScreen.shepherd(_s.currentMentorPage),
      ),
    );
  }

  Future<void> _openDeveloperAccess() async {
    final navigator = Navigator.of(context);
    setState(() => _open = false);
    final authorized = await SelahDeveloperAccess.refreshCurrentAuthorization();
    if (!authorized || !SelahDeveloperAccess.isAuthorizedOperator) {
      try {
        await SelahAuth.signOut();
      } catch (error) {
        debugPrint(
          'SELAH Shepherd Developer Access recheck sign-out failed: $error',
        );
      }
      if (!navigator.mounted) return;
      navigator.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthGate(playSplash: false)),
        (route) => false,
      );
      return;
    }
    if (!navigator.mounted) return;
    navigator.push<void>(
      MaterialPageRoute(builder: (_) => const DeveloperAccessScreen()),
    );
  }

  void _returnHome() {
    if (!mounted) return;
    unawaited(SelahDevHome.open(context));
    setState(() => _open = false);
  }

  void _startSignUp() {
    setState(() => _open = false);
    SelahDevSignUp.start(context);
  }

  Future<void> _copySeekerTestCode(String code, {required bool valid}) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    setState(() {
      _notice =
          '${valid ? 'Valid Seeker' : 'Wrong'} code copied. '
          'Paste it into Enter code.';
    });
  }

  String? get _roleDenial => _s.mentorIsMain
      ? null
      : 'Additional Shepherds can open Journey context when the Seeker '
            'includes them, but Family Review, Shepherd Gate and protected '
            'decisions remain Main-led. Choose Main Shepherd to inspect '
            'those decision previews.';

  static const _countNames = [
    'No',
    'One',
    'Two',
    'Three',
    'Four',
    'Five',
    'Six',
    'Seven',
    'Eight',
    'Nine',
    'Ten',
    'Eleven',
    'Twelve',
  ];

  List<SelahDevPageOption> _counts({
    required String id,
    required String group,
    required String singular,
    required String plural,
    required int value,
    required int max,
    required ValueChanged<int> onChanged,
    String? denied,
    String? zeroLabel,
  }) => [
    for (var count = 0; count <= max; count++)
      SelahDevPageOption(
        id: '$id-$count',
        group: group,
        label: count == 0 && zeroLabel != null
            ? zeroLabel
            : '${_countNames[count]} ${count == 1 ? singular : plural}',
        selected: value == count,
        onSelected: denied == null ? () => onChanged(count) : null,
        unavailableReason: denied,
      ),
  ];

  List<SelahDevPageOption> _roles({bool network = false}) => [
    for (final role in MentorRole.values)
      SelahDevPageOption(
        id: 'shepherd-role-${role.name}',
        group: 'Shepherd role',
        label: role.label,
        selected: network
            ? GNContext.instance.isMainMentor == (role == MentorRole.main)
            : _s.mentorRole == role,
        onSelected: () {
          _s.setMentorRole(role);
          if (network) {
            GNContext.instance.setMainMentor(role == MentorRole.main);
          }
        },
      ),
  ];

  List<SelahDevPageOption> _linkedSeekers() => _counts(
    id: 'shepherd-linked-seekers',
    group: 'Linked Seekers',
    singular: 'linked Seeker',
    plural: 'linked Seekers',
    value: _s.mentorLinkedSeekers,
    max: SelahDevScenario.fakeWards.length,
    onChanged: _s.setMentorLinkedSeekers,
  );

  List<SelahDevPageOption> _unreadBadge() => _counts(
    id: 'shepherd-unread',
    group: 'Notification badge only',
    singular: 'unread badge item',
    plural: 'unread badge items',
    zeroLabel: 'Use current unread badge',
    value: _s.mentorUnread,
    max: 12,
    onChanged: _s.setMentorUnread,
  );

  List<SelahDevPageOption> _journeys() => [
    ..._counts(
      id: 'shepherd-active',
      group: 'Active Journeys',
      singular: 'active Journey',
      plural: 'active Journeys',
      value: _s.mentorActiveJourneys,
      max: _s.mentorLinkedSeekers,
      onChanged: _s.setMentorActiveJourneys,
      denied: _roleDenial,
    ),
    for (var i = 0; i < SelahJourneyStages.all.length; i++)
      SelahDevPageOption(
        id: 'shepherd-stage-$i',
        label: SelahJourneyStages.all[i].label,
        group: 'Journey stage',
        selected: _s.mentorStageIndex == i,
        onSelected: _roleDenial == null ? () => _s.setMentorStageIndex(i) : null,
        unavailableReason: _roleDenial,
      ),
    ..._counts(
      id: 'shepherd-paused',
      group: 'Paused Journeys',
      singular: 'paused Journey',
      plural: 'paused Journeys',
      value: _s.mentorPausedJourneys,
      max: (_s.mentorLinkedSeekers - _s.mentorActiveJourneys).clamp(
        0,
        _s.mentorLinkedSeekers,
      ),
      onChanged: _s.setMentorPausedJourneys,
      denied: _roleDenial,
    ),
    ..._counts(
      id: 'shepherd-ended',
      group: 'Ended Journeys',
      singular: 'ended Journey',
      plural: 'ended Journeys',
      value: _s.mentorEndedJourneys,
      max: 5,
      onChanged: _s.setMentorEndedJourneys,
      denied: _roleDenial,
    ),
    for (final waiting in [false, true])
      SelahDevPageOption(
        id: 'shepherd-review-${waiting ? 'waiting' : 'none'}',
        label: waiting ? 'Review awaiting you' : 'No review awaiting you',
        group: 'Family Review',
        selected: _s.mentorReviewWaiting == waiting,
        onSelected: _roleDenial == null && _s.mentorActiveJourneys > 0
            ? () => _s.setMentorReviewWaiting(waiting)
            : null,
        unavailableReason:
            _roleDenial ??
            (_s.mentorActiveJourneys == 0
                ? 'Choose a linked Seeker and an active Journey first.'
                : null),
      ),
  ];

  List<SelahDevPageOption> _dashboardOptions() => [
    if (!_s.dashboardLabEnabled && _s.dashboardTab == SelahDashboardTab.now) ...[
      ..._roles(),
      ..._linkedSeekers(),
      ..._journeys(),
    ],
    ..._unreadBadge(),
  ];

  List<SelahDevPageOption> _networkOptions() {
    final context = GNContext.instance;
    final preview =
        _promotion.developerShepherdNetworkState ==
        SelahDeveloperShepherdNetworkState.d14Preview;
    const previewRequired =
        'Choose D14 full preview to inspect the local Network scene.';
    return [
      ..._roles(network: true),
      ..._linkedSeekers(),
      for (final item in <(SelahDeveloperShepherdNetworkState, String)>[
        (SelahDeveloperShepherdNetworkState.d14Preview, 'D14 full preview'),
        (
          SelahDeveloperShepherdNetworkState.unlinkedBasic,
          'No access · no Seeker',
        ),
        (
          SelahDeveloperShepherdNetworkState.linkedBasic,
          'No access · linked Seeker',
        ),
        (
          SelahDeveloperShepherdNetworkState.unlinkedEntitled,
          'Shepherd access · no Seeker',
        ),
        (
          SelahDeveloperShepherdNetworkState.linkedEntitledUnavailable,
          'Shepherd access · unavailable',
        ),
      ])
        SelahDevPageOption(
          id: 'shepherd-network-access-${item.$1.name}',
          group: 'Network access',
          label: item.$2,
          selected: _promotion.developerShepherdNetworkState == item.$1,
          onSelected: () =>
              _promotion.setDeveloperShepherdNetworkState(item.$1),
        ),
      for (final scene in GNScene.values)
        SelahDevPageOption(
          id: 'shepherd-network-scene-${scene.name}',
          group: 'Network scene',
          label: switch (scene) {
            GNScene.standard => 'Standard recommendations',
            GNScene.merge => 'Incoming request and recommendation',
            GNScene.capReached => 'Request limit reached',
            GNScene.empty => 'No recommendations',
            GNScene.loading => 'Recommendations loading',
            GNScene.error => 'Recommendations unavailable',
          },
          selected: context.scene == scene,
          onSelected: preview ? () => context.setScene(scene) : null,
          unavailableReason: preview ? null : previewRequired,
        ),
      for (final design in GNNetworkCardDesign.values)
        SelahDevPageOption(
          id: 'shepherd-network-card-${design.name}',
          group: 'Network card design',
          label: design.label,
          selected: context.networkCardDesign == design,
          onSelected: preview
              ? () => context.setNetworkCardDesign(design)
              : null,
          unavailableReason: preview ? null : previewRequired,
        ),
      for (final layout in GNNetworkActionLayout.values)
        SelahDevPageOption(
          id: 'shepherd-network-actions-${layout.name}',
          group: 'Network Browser actions',
          label: layout.label,
          selected: context.networkActionLayout == layout,
          onSelected: preview
              ? () => context.setNetworkActionLayout(layout)
              : null,
          unavailableReason: preview ? null : previewRequired,
        ),
      for (final area in GNNetworkPreviewArea.values)
        for (var count = 1; count <= 3; count++)
          SelahDevPageOption(
            id: 'shepherd-network-${area.name}-$count',
            group: switch (area) {
              GNNetworkPreviewArea.browser => 'Browser profiles',
              GNNetworkPreviewArea.sent => 'Sent requests',
              GNNetworkPreviewArea.received => 'Received requests',
            },
            label: '$count ${count == 1 ? 'profile' : 'profiles'}',
            selected: context.previewCountFor(area) == count,
            onSelected: preview
                ? () => context.setPreviewCount(area, count)
                : null,
            unavailableReason: preview ? null : previewRequired,
          ),
      SelahDevPageOption(
        id: 'shepherd-network-reset',
        group: 'Network scene',
        label: 'Reset Network preview',
        onSelected: preview
            ? () {
                context.reset();
                _s.setMentorRole(MentorRole.main);
              }
            : null,
        unavailableReason: preview ? null : previewRequired,
      ),
      SelahDevPageOption(
        id: 'shepherd-notification-permission',
        group: 'Notification permission',
        label: 'Notification permission banner',
        onSelected: () {
          _promotion.showDeveloperPreview(
            product: SelahPromotionProduct.notifications,
            role: SelahPromotionRole.shepherd,
          );
          setState(() => _open = false);
        },
      ),
      const SelahDevPageOption(
        id: 'shepherd-introductions-sent-unavailable',
        group: 'Unavailable previews',
        label: 'Introductions sent',
        unavailableReason:
            'No live Shepherd list shows sent introductions. '
            'The Network preview has its own existing local request states.',
      ),
    ];
  }

  List<SelahDevPageOption> _pageOptions(MentorPage page) => switch (page) {
    MentorPage.dashboard => _dashboardOptions(),
    MentorPage.network => _networkOptions(),
    MentorPage.seekers => [
      if (SelahDeveloperAccess.isMainAppFounderPreview) ...[
        SelahDevPageOption(
          id: 'seeker-code-valid',
          label:
              'Valid Seeker · '
              '${SelahDevPersonalCodeFixtures.validSeekerEntryCode}',
          group: 'SELAH Code test',
          onSelected: () => _copySeekerTestCode(
            SelahDevPersonalCodeFixtures.validSeekerEntryCode,
            valid: true,
          ),
        ),
        SelahDevPageOption(
          id: 'seeker-code-invalid',
          label:
              'Wrong code · '
              '${SelahDevPersonalCodeFixtures.invalidEntryCode}',
          group: 'SELAH Code test',
          onSelected: () => _copySeekerTestCode(
            SelahDevPersonalCodeFixtures.invalidEntryCode,
            valid: false,
          ),
        ),
      ],
      ..._roles(),
      ..._linkedSeekers(),
      ..._counts(
        id: 'shepherd-sent-invites',
        group: 'Invitations',
        singular: 'pending invitation',
        plural: 'pending invitations',
        value: _s.mentorSentInvites,
        max: SelahDevScenario.fakeMentorInvites.length,
        onChanged: _s.setMentorSentInvites,
      ),
      const SelahDevPageOption(
        id: 'shepherd-invitations-received-unavailable',
        group: 'Unavailable previews',
        label: 'Invitations received',
        unavailableReason:
            'Invitations are bearer codes until redeemed. '
            'There is no addressed received-invitation list to preview.',
      ),
    ],
    // Retained for legacy preview callers; the shell routes Notifications
    // to My SELAH, where the same badge controls now live.
    MentorPage.notifications => _unreadBadge(),
    MentorPage.profile => const [],
  };

  @override
  Widget build(BuildContext context) {
    // Backstop — see the header. Not an else-branch of the mount point.
    if (!SelahDeveloperAccess.canUseDeveloperTools) {
      return const SizedBox.shrink();
    }

    final page = _s.currentMentorPage;

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      top: 0,
      bottom: 0,
      right: _open ? 0 : -_panelWidth,
      width: _panelWidth + SelahDevControlRail.width,
      child: Row(
        children: [
          SelahDevControlRail(
            open: _open,
            selected: _section,
            onSelected: _selectSection,
          ),
          Expanded(
            child: Material(
              color: SelahColors.modalSheetSurface.withValues(alpha: 242 / 255),
              child: SafeArea(
                left: false,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _section == SelahDevControlSection.home
                                    ? 'Developer Access'
                                    : _section ==
                                              SelahDevControlSection.actions &&
                                          page == MentorPage.dashboard
                                    ? selahDashboardOptionsTitle(
                                        _s,
                                        SelahDashboardRole.shepherd,
                                      )
                                    : page.label,
                                style: SelahText.heading(size: 18),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => setState(() => _open = false),
                          icon: const Icon(
                            Icons.close,
                            size: 18,
                            color: Colors.white54,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (_notice != null) ...[
                      const SizedBox(height: 10),
                      _MentorInlineNotice(
                        message: _notice!,
                        onDismiss: () => setState(() => _notice = null),
                      ),
                    ],
                    if (_section == SelahDevControlSection.preview) ...[
                      const SizedBox(height: 10),
                      SelahDevPreviewLauncher(
                        pageLabel: page.label,
                        onOpen: _openCompletePreview,
                      ),
                    ],
                    if (_section == SelahDevControlSection.home) ...[
                      const SizedBox(height: 10),
                      SelahDevHomeTools(
                        busy: false,
                        shepherd: true,
                        onHome: _returnHome,
                        onOpenSplashPreview: () =>
                            setState(() => _open = false),
                        onRestart: _goHome,
                        onReset: _reset,
                        onAccounts: _openDeveloperAccess,
                        onSeekerSignUp: _startSignUp,
                        onShepherdSignUp: _startSignUp,
                      ),
                    ],
                    if (_section == SelahDevControlSection.actions) ...[
                      const SizedBox(height: 10),
                      if (page == MentorPage.dashboard)
                        SelahDashboardLabControls(
                          scenario: _s,
                          hostRole: SelahDashboardRole.shepherd,
                          additionalOptions: _dashboardOptions(),
                        )
                      else
                        SelahDevPageOptions(
                          options: _pageOptions(page),
                          contextKey:
                              'shepherd:${page.name}:'
                              '${_s.mentorRole.name}:'
                              '${GNContext.instance.isMainMentor}:'
                              '${_promotion.developerShepherdNetworkState.name}',
                        ),
                    ],

                    if (_section == SelahDevControlSection.preview) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Internal preview',
                        style: SelahText.subtext(
                          size: 10,
                          color: Colors.white24,
                        ),
                      ),
                    ],
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

class _MentorInlineNotice extends StatelessWidget {
  final String message;
  final VoidCallback onDismiss;

  const _MentorInlineNotice({required this.message, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    const color = SelahColors.journeyDotGreen;
    return Container(
      padding: const EdgeInsets.fromLTRB(9, 7, 2, 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 0.5),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline, size: 14, color: color),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              message,
              style: SelahText.subtext(size: 10, color: Colors.white70),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: onDismiss,
            icon: const Icon(Icons.close, size: 14, color: Colors.white38),
          ),
        ],
      ),
    );
  }
}
