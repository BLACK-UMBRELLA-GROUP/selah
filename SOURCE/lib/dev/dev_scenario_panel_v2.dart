// SELAH developer panel — rebuilt 2026-08-18.
//
// Home owns restart/reset/account entry; Preview owns complete samples.
// Actions contains independent category dropdowns contextual to the open page. Developer
// results stay inside this panel instead of covering the product with bottom
// snackbars.
//
// Active Journey has both a plan-aware Connections preview count and a
// separate server-backed "Open live Journey" action. Preview cards exercise
// the Connections layout and local developer interactions only; the live
// action remains the route for a real, walkable Journey.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/selah_colors.dart';

import '../constants/selah_plan_names.dart';
import '../data/selah_entitlements.dart';
import '../data/selah_membership_catalog.dart';
import '../data/selah_journey_pause_state.dart';
import '../main.dart' show supabase;
import '../models/selah_error_state.dart';
import '../models/selah_dashboard_lab.dart';
import '../models/journey_match.dart';
import '../screens/auth_gate.dart';
import '../screens/journey/journey_flow_screen.dart';
import '../screens/dev/developer_access_screen.dart';
import '../services/selah_auth.dart';
import '../services/selah_developer_access.dart';
import '../services/selah_shepherd_suggestion_service.dart';
import '../services/selah_journey_service.dart';
import '../services/selah_promotion_engine.dart';
import '../services/selah_unlock_service.dart';
import '../state/app_state.dart';
import '../theme/selah_text.dart';
import '../widgets/selah_glass_dialog.dart';
import '../widgets/selah_full_screen_error.dart';
import 'selah_dev_signup.dart';
import 'selah_dev_home.dart';
import 'selah_dev_surface_coordinator.dart';
import 'selah_dev_personal_code_fixtures.dart';
import 'selah_dev_control_system.dart';
import 'selah_dev_page_options.dart';
import 'selah_supportive_dashboard_preview.dart';
import 'selah_dashboard_lab_controls.dart';
import 'selah_page_preview_screen.dart';
import 'selah_dev_scenario.dart';

class DevScenarioPanelV2 extends StatefulWidget {
  final ValueChanged<DevPage> onOpenPage;
  final ValueChanged<int>? onOpenConnectionsSection;
  final VoidCallback? onOpenIntroductions;

  const DevScenarioPanelV2({
    super.key,
    required this.onOpenPage,
    this.onOpenConnectionsSection,
    this.onOpenIntroductions,
  });

  @override
  State<DevScenarioPanelV2> createState() => _DevScenarioPanelV2State();
}

class _DevScenarioPanelV2State extends State<DevScenarioPanelV2> {
  static const double _panelWidth = 310;

  bool _open = false;
  SelahDevControlSection _section = SelahDevControlSection.actions;
  bool _busy = false;
  String? _notice;
  bool _noticeError = false;
  int _shepherdSuggestions = 0;
  int _shepherdsOnDecided = 0;
  late final bool _localOnly;

  SelahDevScenario get _scenario => SelahDevScenario.instance;
  SelahCompatibilityDevControls? get _compatibility =>
      SelahDevSurfaceCoordinator.instance.activeCompatibilityControls;
  SelahPromotionEngine get _promotion => SelahPromotionEngine.instance;
  SelahJourneyLimits get _limits => SelahEntitlements.of(AppState.instance.plan);
  bool get _isOne => AppState.instance.plan == SelahPlan.one;

  @override
  void initState() {
    super.initState();
    // Latch the boundary for this panel instance. If the Auth principal
    // changes while an async tap is already queued, a Founder-preview panel
    // must not turn into a server-writing panel mid-callback.
    _localOnly = SelahDeveloperAccess.isMainAppFounderPreview;
    _scenario.migrateToCleanSeekerPanel();
    if (_localOnly) _scenario.setUseLiveShepherdData(false);
    _scenario.addListener(_onStateChanged);
    SelahDevSurfaceCoordinator.instance.addListener(_onStateChanged);
    SupportiveDashboardPreview.instance.addListener(_onStateChanged);
    _promotion.addListener(_onStateChanged);
    AppState.instance.addListener(_onStateChanged);
    if (!_localOnly) unawaited(_syncServerMirrors());
  }

  @override
  void dispose() {
    _scenario.removeListener(_onStateChanged);
    SelahDevSurfaceCoordinator.instance.removeListener(_onStateChanged);
    SupportiveDashboardPreview.instance.removeListener(_onStateChanged);
    _promotion.removeListener(_onStateChanged);
    AppState.instance.removeListener(_onStateChanged);
    super.dispose();
  }

  void _onStateChanged() {
    if (mounted) setState(() {});
  }

  void _showNotice(String message, {bool error = false}) {
    if (!mounted) return;
    setState(() {
      _notice = message;
      _noticeError = error;
    });
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
    final compatibility = _compatibility != null;
    setState(() => _open = false);
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => compatibility
            ? SelahPagePreviewScreen.compatibility()
            : SelahPagePreviewScreen.seeker(_scenario.currentPage),
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
        debugPrint('SELAH Developer Access recheck sign-out failed: $error');
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

  Future<void> _goHome() async {
    setState(() {
      _open = false;
      _notice = null;
    });
    // Home means the public start of the app: sign out, replay the splash,
    // then show Welcome with Apple/Google sign-up and sign-in. Previously this
    // replayed the splash while keeping the session, so AuthGate routed the
    // operator straight back into the signed-in shell.
    try {
      await SelahAuth.signOut();
    } catch (error) {
      debugPrint('SELAH developer Home sign-out failed: $error');
    }
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthGate(playSplash: true)),
      (route) => false,
    );
  }

  void _startSignUp() {
    setState(() {
      _open = false;
      _notice = null;
    });
    SelahDevSignUp.start(context);
  }

  void _previewError(SelahErrorKind kind) {
    setState(() {
      _open = false;
      _notice = null;
    });
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (previewContext) => SelahFullScreenError(
          kind: kind,
          referenceCode: 'ZY-DEMO',
          // Preview actions return to the live account so testing an error
          // never signs the Founder out or discards the screen underneath.
          onPrimary: () => Navigator.of(previewContext).pop(),
          onSecondary: () => Navigator.of(previewContext).pop(),
        ),
      ),
    );
  }

  Future<void> _syncServerMirrors() async {
    if (_localOnly) return;
    try {
      final pending = await SelahShepherdSuggestionService.fetchPending();
      if (mounted) {
        setState(() => _shepherdSuggestions = pending.length.clamp(0, 5));
      }
    } catch (error) {
      debugPrint('SELAH dev Introduction mirror failed — $error');
    }
    try {
      final res = await supabase.rpc('selah_dev_shepherds_on_decided');
      if (mounted) {
        setState(
          () => _shepherdsOnDecided = ((res as num?)?.toInt() ?? 0).clamp(0, 3),
        );
      }
    } catch (error) {
      debugPrint('SELAH dev Shepherd mirror failed — $error');
    }
  }

  Future<void> _setMembership(bool one) async {
    final target = one ? SelahPlan.one : SelahPlan.basic;
    if (AppState.instance.plan == target || _busy) return;
    if (_localOnly) {
      AppState.instance.setPlan(target);
      _showNotice(
        'Membership preview: ${one ? SelahMembershipCatalog.seekerOneTitle : 'Membership inactive'}. '
        'Account membership was unchanged.',
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await supabase.rpc(
        'selah_dev_set_seeker_plan',
        params: {
          'p_plan': one
              ? SelahSubscriptionPlanType.seekerPremium.dbValue
              : SelahSubscriptionPlanType.seekerBasic.dbValue,
        },
      );
      AppState.instance.setPlan(target);
      _showNotice(
        'Test membership: ${one ? SelahMembershipCatalog.seekerOneTitle : 'Membership inactive'}.',
      );
    } catch (error) {
      debugPrint('SELAH dev membership failed — $error');
      _showNotice(
        '$error'.contains('dev_accounts_only')
            ? 'Membership switching is available only on seeded test accounts.'
            : 'Membership did not change. Check the console and try again.',
        error: true,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _setIntroductionPreviews(int count) {
    _scenario.setIntroductionPreviewCount(count);
    final staged = _scenario.introductionPreviewCount;
    _showNotice(
      staged == 0
          ? 'Local test Introductions cleared. Server rows were unchanged.'
          : '$staged local test Introduction${staged == 1 ? '' : 's'} ready. '
                'Server rows were unchanged.',
    );
    if (!_localOnly) {
      _showNotice(
        '$staged local test Introductions ready. '
        '$_shepherdSuggestions server rows unchanged.',
      );
    }
    _revealIntroductions();
  }

  Future<void> _copyShepherdTestCode(String code, {required bool valid}) async {
    await Clipboard.setData(ClipboardData(text: code));
    _showNotice(
      '${valid ? 'Valid Shepherd' : 'Wrong'} code copied. '
      'Paste it into Enter code.',
    );
  }

  void _revealIntroductions() {
    if (!mounted || widget.onOpenIntroductions == null) return;
    setState(() => _open = false);
    widget.onOpenIntroductions!();
  }

  Future<void> _setShepherdsOnDecided(int count) async {
    if (_localOnly) {
      _showNotice(
        'Server-backed Shepherd staging is unavailable in local preview.',
        error: true,
      );
      return;
    }
    if (_busy) return;
    setState(() {
      _busy = true;
      _shepherdsOnDecided = count;
    });
    try {
      final res = await supabase.rpc(
        'selah_dev_set_shepherds_on_decided',
        params: {'p_count': count},
      );
      final map = (res as Map?)?.cast<String, dynamic>();
      final targets = (map?['targets'] as num?)?.toInt() ?? 0;
      _showNotice(
        targets == 0
            ? 'Decide on a profile first, then return to this control.'
            : count == 0
            ? 'Test Shepherds cleared from $targets profile${targets == 1 ? '' : 's'}.'
            : '$count Shepherd${count == 1 ? '' : 's'} added to $targets decided profile${targets == 1 ? '' : 's'}.',
        error: targets == 0,
      );
    } catch (error) {
      debugPrint('SELAH dev profile Shepherds failed — $error');
      await _syncServerMirrors();
      _showNotice(
        'Shepherd staging did not change. Check the console and retry.',
        error: true,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _grantCredits(UnlockTier tier, int count) async {
    if (_localOnly) {
      _showNotice(
        'Server-backed credit grants are unavailable in local preview.',
        error: true,
      );
      return;
    }
    if (_busy) return;
    setState(() => _busy = true);
    final ok = await SelahUnlockService.debugGrant(tier, count);
    if (!mounted) return;
    setState(() => _busy = false);
    _showNotice(
      ok
          ? '$count Compatibility Unlock credit${count == 1 ? '' : 's'} added.'
          : 'Credits were not added. Use a seeded test account.',
      error: !ok,
    );
  }

  void _showBrowsePopup(DevPopup popup) {
    setState(() {
      _open = false;
      _notice = null;
    });
    _scenario.requestPopup(popup);
  }

  Future<List<JourneyMatch>?> _liveJourneys() async {
    if (_localOnly) return null;
    final rows = await SelahJourneyService.fetchJourneyMatches(
      statuses: const ['active'],
    );
    return rows?.where((journey) => !journey.isMock).toList();
  }

  Future<void> _openLiveJourney() async {
    if (_localOnly) {
      _showNotice(
        'Live Journey creation is unavailable in local preview.',
        error: true,
      );
      return;
    }
    if (_busy) return;
    setState(() {
      _busy = true;
      _notice = 'Finding a live Journey…';
      _noticeError = false;
    });

    String? seedResult;
    try {
      var journeys = await _liveJourneys();
      if (journeys == null) {
        _showNotice(
          'Journeys could not be read. Check the connection.',
          error: true,
        );
        return;
      }
      var running = journeys.where((journey) => !journey.isSuspended).toList();
      if (running.isEmpty) {
        seedResult = await SelahJourneyService.devSeedJourney();
        journeys = await _liveJourneys();
        if (journeys == null) {
          _showNotice(
            'The seeded Journey could not be read back.',
            error: true,
          );
          return;
        }
        running = journeys.where((journey) => !journey.isSuspended).toList();
      }

      final journey = running.isNotEmpty
          ? running.first
          : journeys.isNotEmpty
          ? journeys.first
          : null;
      if (journey == null) {
        _showNotice(
          seedResult ?? 'No live Journey is available for this test account.',
          error: true,
        );
        return;
      }

      _scenario.refreshJourneys();
      if (!mounted) return;
      setState(() {
        _open = false;
        _notice = null;
      });
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => JourneyFlowScreen(
            matchId: journey.matchId,
            profile: journey.profile,
          ),
        ),
      );
    } catch (error) {
      debugPrint('SELAH dev open Journey failed — $error');
      _showNotice(
        'A live Journey could not be opened. Check the console.',
        error: true,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resetEverything() async {
    if (_busy) return;
    final confirmed = await showSelahGlassChoice(
      context: context,
      icon: Icons.restart_alt,
      title: 'Reset developer state?',
      body: _localOnly
          ? 'Clears only this device\'s preview state and returns the local '
                'membership preview to inactive. Account and server rows '
                'are unchanged.'
          : 'Clears staged previews and supported test rows, returns '
                'membership to inactive, and rewinds test Journeys to their '
                'first stage.\n\nYour profile, photos, consent, Chapter 2 '
                'answers, real Shepherd links and Journey history are kept.',
      primaryLabel: 'Reset',
      secondaryLabel: 'Cancel',
    );
    if (confirmed != true || !mounted) return;

    ScaffoldMessenger.of(context).clearSnackBars();
    setState(() {
      _busy = true;
      _notice = 'Resetting developer state…';
      _noticeError = false;
    });
    _scenario.reset();
    // Local Connections lists clear even when there is no signed-in server
    // account. Previously this sat after the early return below, so Reset
    // could truthfully zero the toggles while stale profile cards remained.
    AppState.instance.clearDecisionsForReset();
    SelahUnlockService.clearForSignOut();
    await _promotion.resetDeveloperPolicy();

    if (_localOnly) {
      AppState.instance.setPlan(SelahPlan.basic);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _shepherdSuggestions = 0;
        _shepherdsOnDecided = 0;
      });
      _showNotice(
        'Local preview state reset. Account and server rows unchanged.',
      );
      return;
    }

    if (SelahAuth.currentUser == null) {
      setState(() {
        _busy = false;
        _shepherdSuggestions = 0;
        _shepherdsOnDecided = 0;
      });
      _showNotice('Preview state cleared. No signed-in server state existed.');
      return;
    }

    final failures = <String>[];
    try {
      await supabase.rpc('selah_dev_reset_account');
    } catch (error) {
      debugPrint('SELAH dev reset account rows failed — $error');
      failures.add('account data');
    }
    try {
      await SelahJourneyService.devRewindJourney();
    } catch (error) {
      debugPrint('SELAH dev reset Journey failed — $error');
      failures.add('Journey rewind');
    }
    try {
      await supabase.rpc(
        'selah_dev_set_shepherd_suggestions',
        params: {'p_count': 0},
      );
      AppState.instance.bumpSuggestions();
    } catch (error) {
      debugPrint('SELAH dev reset Introductions failed — $error');
      failures.add('Introductions');
    }
    try {
      await supabase.rpc(
        'selah_dev_set_shepherds_on_decided',
        params: {'p_count': 0},
      );
    } catch (error) {
      debugPrint('SELAH dev reset Shepherds failed — $error');
      failures.add('test Shepherds');
    }
    try {
      await supabase.rpc(
        'selah_dev_set_seeker_plan',
        params: {'p_plan': SelahSubscriptionPlanType.seekerBasic.dbValue},
      );
      AppState.instance.setPlan(SelahPlan.basic);
    } catch (error) {
      debugPrint('SELAH dev reset membership failed — $error');
      failures.add('membership');
    }

    if (!mounted) return;
    setState(() {
      _busy = false;
      _shepherdSuggestions = 0;
      _shepherdsOnDecided = 0;
    });
    _showNotice(
      failures.isEmpty
          ? 'Developer state reset.'
          : 'Reset finished, but ${failures.join(', ')} did not clear.',
      error: failures.isNotEmpty,
    );
  }

  String get _pageContext => _compatibility != null
      ? 'compatibility-${identityHashCode(_compatibility!)}'
      : switch (_scenario.currentPage) {
          DevPage.connections => 'connections-${_scenario.connectionsSection}',
          _ => _scenario.currentPage.name,
        };

  String get _pageTitle => _compatibility != null
      ? 'Compatibility'
      : switch (_scenario.currentPage) {
          DevPage.connections =>
            'Connections · ${switch (_scenario.connectionsSection) {
              1 => 'Activity',
              2 => 'Introductions',
              _ => 'Journeys',
            }}',
          DevPage.dashboard =>
            'My SELAH · ${selahDashboardOptionsTitle(_scenario, SelahDashboardRole.seeker)}',
          _ => _scenario.currentPage.label,
        };

  SelahDevPageOption _option({
    required String id,
    required String label,
    required String group,
    required FutureOr<void> Function() onSelected,
    bool selected = false,
  }) {
    final contextKey = _pageContext;
    return SelahDevPageOption(
      id: id,
      label: label,
      group: group,
      selected: selected,
      onSelected: () async {
        // A retained row cannot act on a different page or after authority loss.
        if (!mounted ||
            _busy ||
            !SelahDeveloperAccess.canUseDeveloperTools ||
            _pageContext != contextKey) {
          return;
        }
        setState(() {
          _notice = null;
          _noticeError = false;
        });
        await onSelected();
        if (mounted && _noticeError) {
          throw StateError('The selected page option was not applied.');
        }
      },
    );
  }

  List<SelahDevPageOption> _counts({
    required String id,
    required String group,
    required int value,
    required int max,
    required FutureOr<void> Function(int) onSelected,
  }) => [
    for (var count = 0; count <= max; count++)
      _option(
        id: '$id-$count',
        label: '$group · $count',
        group: group,
        selected: value == count,
        onSelected: () => onSelected(count),
      ),
  ];

  List<SelahDevPageOption> _browseOptions() => [
    for (final style in SelahBrowseSwipeFeedbackStyle.values)
      _option(
        id: 'browse-motion-${style.name}',
        label: style.label,
        group: 'Swipe feedback',
        selected: _scenario.browseSwipeFeedbackStyle == style,
        onSelected: () => _scenario.setBrowseSwipeFeedbackStyle(style),
      ),
    _option(
      id: 'browse-save-limit',
      label: 'Save limit',
      group: 'Limit previews',
      onSelected: () => _showBrowsePopup(DevPopup.saveLimit),
    ),
    if (!_isOne) ...[
      _option(
        id: 'browse-consider-limit',
        label: 'Consider limit',
        group: 'Limit previews',
        onSelected: () => _showBrowsePopup(DevPopup.considerLimit),
      ),
      _option(
        id: 'browse-daily-limit',
        label: 'Browsing limit',
        group: 'Limit previews',
        onSelected: () => _showBrowsePopup(DevPopup.dailyLimit),
      ),
    ],
  ];

  List<SelahDevPageOption> _connectionsJourneyOptions() => [
    if (!_localOnly)
      _option(
        id: 'connections-live-journey',
        label: 'Open live Journey',
        group: 'Journey lab',
        onSelected: _openLiveJourney,
      ),
    ..._counts(
      id: 'active-journeys',
      group: 'Active Journeys',
      value: SelahEntitlements.devClamp(
        _scenario.activeJourneys,
        _limits.active,
      ),
      max: SelahEntitlements.devMaxFor(_limits.active),
      onSelected: _scenario.setActiveJourneys,
    ),
    ..._counts(
      id: 'potential-journeys',
      group: 'Potential',
      value: _scenario.queuedJourneys,
      max: SelahEntitlements.devMaxFor(_limits.potential),
      onSelected: _scenario.setQueuedJourneys,
    ),
    ..._counts(
      id: 'paused-journeys',
      group: 'Paused',
      value: _scenario.pausedJourneys.clamp(0, _limits.paused),
      max: SelahEntitlements.devMaxFor(_limits.paused),
      onSelected: _scenario.setPausedJourneys,
    ),
    ..._counts(
      id: 'ended-journeys',
      group: 'Ended',
      value: _scenario.endedJourneys.clamp(0, _limits.ended),
      max: SelahEntitlements.devMaxFor(_limits.ended),
      onSelected: _scenario.setEndedJourneys,
    ),
  ];

  List<SelahDevPageOption> _connectionsActivityOptions() => [
    ..._counts(
      id: 'considered-profiles',
      group: 'Considered',
      value: _scenario.consideredPreviewCount,
      max: 5,
      onSelected: _scenario.setConsideredPreviewCount,
    ),
    ..._counts(
      id: 'saved-profiles',
      group: 'Saved',
      value: _scenario.savedPreviewCount,
      max: 5,
      onSelected: _scenario.setSavedPreviewCount,
    ),
    ..._counts(
      id: 'passed-profiles',
      group: 'Passed',
      value: _scenario.passedPreviewCount,
      max: 5,
      onSelected: _scenario.setPassedPreviewCount,
    ),
    if (!_localOnly) ...[
      for (final count in const [1, 5])
        _option(
          id: 'credits-plus-$count',
          label: 'Compatibility Unlock credits · +$count',
          group: 'Compatibility data',
          onSelected: () => _grantCredits(SelahUnlockService.currentTier, count),
        ),
      ..._counts(
        id: 'shepherds-on-decided',
        group: 'Shepherds on decided profiles',
        value: _shepherdsOnDecided,
        max: 3,
        onSelected: _setShepherdsOnDecided,
      ),
    ],
  ];

  List<SelahDevPageOption> _shepherdOptions() => [
    if (_localOnly) ...[
      _option(
        id: 'shepherd-code-valid',
        label:
            'Valid Shepherd · '
            '${SelahDevPersonalCodeFixtures.validShepherdEntryCode}',
        group: 'SELAH Code test',
        onSelected: () => _copyShepherdTestCode(
          SelahDevPersonalCodeFixtures.validShepherdEntryCode,
          valid: true,
        ),
      ),
      _option(
        id: 'shepherd-code-invalid',
        label: 'Wrong code · ${SelahDevPersonalCodeFixtures.invalidEntryCode}',
        group: 'SELAH Code test',
        onSelected: () => _copyShepherdTestCode(
          SelahDevPersonalCodeFixtures.invalidEntryCode,
          valid: false,
        ),
      ),
    ],
    if (!_localOnly)
      for (final live in const [false, true])
        _option(
          id: 'shepherd-source-${live ? 'live' : 'preview'}',
          label: live ? 'Live' : 'Preview',
          group: 'Data source',
          selected: _scenario.useLiveShepherdData == live,
          onSelected: () => _scenario.setUseLiveShepherdData(live),
        ),
    if (!_scenario.useLiveShepherdData) ...[
      for (final count in const [0, 1, 2, 3])
        _option(
          id: 'shepherd-active-journeys-$count',
          label: 'Active Journeys · $count',
          group: 'Active Journeys',
          selected: _scenario.shepherdPreviewActiveJourneyCount == count,
          onSelected: () =>
              _scenario.setShepherdPreviewActiveJourneyCount(count),
        ),
      for (final linked in const [false, true])
        _option(
          id: 'main-shepherd-${linked ? 'linked' : 'none'}',
          label: linked ? 'Main Shepherd · Linked' : 'Main Shepherd · None',
          group: 'Main Shepherd',
          selected: _scenario.mainShepherd == linked,
          onSelected: () => _scenario.setMainShepherd(linked),
        ),
      ..._counts(
        id: 'additional-shepherds',
        group: 'Additional Shepherds',
        value: _scenario.additionalShepherdCount,
        max: 5,
        onSelected: _scenario.setAdditionalShepherds,
      ),
    ],
  ];

  List<SelahDevPageOption> _profileOptions() => [
    for (final one in const [false, true])
      _option(
        id: 'profile-membership-${one ? 'one' : 'inactive'}',
        label: one ? SelahMembershipCatalog.seekerOneTitle : 'No access',
        group: 'Membership',
        selected: _isOne == one,
        onSelected: () => _setMembership(one),
      ),
    _option(
      id: 'profile-notification-banner',
      label: 'Notification permission banner',
      group: 'Notifications',
      onSelected: () {
        _promotion.showDeveloperPreview(
          product: SelahPromotionProduct.notifications,
          role: SelahPromotionRole.seeker,
        );
        setState(() => _open = false);
      },
    ),
    _option(
      id: 'profile-notification-reset',
      label: 'Reset notification prompt policy',
      group: 'Notifications',
      onSelected: _promotion.resetDeveloperPolicy,
    ),
  ];

  List<SelahDevPageOption> _compatibilityOptions(
    SelahCompatibilityDevControls controls,
  ) => [
    for (final count in const [0, 1, 5])
      _option(
        id: 'compatibility-plus-$count',
        label: '$count Compatibility Unlock${count == 1 ? '' : 's'}',
        group: 'Compatibility Unlock',
        selected: controls.balance(true) == count,
        onSelected: () => controls.setBalance(true, count),
      ),
  ];

  List<SelahDevPageOption> _pageOptions() => _compatibility != null
      ? _compatibilityOptions(_compatibility!)
      : switch (_scenario.currentPage) {
          DevPage.browse => _browseOptions(),
          DevPage.connections => switch (_scenario.connectionsSection) {
            1 => _connectionsActivityOptions(),
            2 => _counts(
              id: 'test-introductions',
              group: 'Test Introductions',
              value: _scenario.introductionPreviewCount,
              max: 5,
              onSelected: _setIntroductionPreviews,
            ),
            _ => _connectionsJourneyOptions(),
          },
          DevPage.shepherd => _shepherdOptions(),
          DevPage.activeJourney => [
            for (final scenario in SelahPauseDevScenario.values)
              _option(
                id: 'pause-${scenario.name}',
                label: scenario.label,
                group: 'Pause decision state',
                selected: _scenario.pauseScenario == scenario,
                onSelected: () => _scenario.setPauseScenario(scenario),
              ),
          ],
          DevPage.profile => _profileOptions(),
          DevPage.dashboard => const [],
        };

  Widget _pageTools() =>
      _compatibility == null && _scenario.currentPage == DevPage.dashboard
      ? SelahDashboardLabControls(
          scenario: _scenario,
          hostRole: SelahDashboardRole.seeker,
        )
      : SelahDevPageOptions(
          key: const ValueKey('seeker_page_options'),
          options: _pageOptions(),
          contextKey: 'seeker-$_pageContext',
          busy: _busy,
        );

  @override
  Widget build(BuildContext context) {
    if (!SelahDeveloperAccess.canUseDeveloperTools) {
      return const SizedBox.shrink();
    }

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
              color: SelahColors.modalSheetSurface,
              child: SafeArea(
                left: false,
                child: Column(
                  children: [
                    _PanelHeader(
                      page: _scenario.currentPage,
                      actionsTitle: _pageTitle,
                      previewTitle: _compatibility != null
                          ? 'Compatibility'
                          : null,
                      section: _section,
                      onClose: () => setState(() => _open = false),
                    ),
                    const Divider(height: 1, color: Colors.white12),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(14, 14, 14, 30),
                        children: [
                          if (_localOnly &&
                              _section == SelahDevControlSection.preview) ...[
                            const _LocalOnlyBanner(),
                            const SizedBox(height: 14),
                          ],
                          if (_notice != null) ...[
                            _InlineNotice(
                              message: _notice!,
                              error: _noticeError,
                              onDismiss: () => setState(() => _notice = null),
                            ),
                            const SizedBox(height: 14),
                          ],
                          ...switch (_section) {
                            SelahDevControlSection.preview => [
                              SelahDevPreviewLauncher(
                                pageLabel: _compatibility != null
                                    ? 'Compatibility'
                                    : _scenario.currentPage.label,
                                onOpen: _openCompletePreview,
                              ),
                              const SizedBox(height: 20),
                              const _PanelHeading('Recovery pages'),
                              _ToolCard(
                                children: [
                                  _ToolAction(
                                    icon: Icons.broken_image_outlined,
                                    title: 'Page error',
                                    onTap: () =>
                                        _previewError(SelahErrorKind.page),
                                  ),
                                  _ToolAction(
                                    icon: Icons.wifi_off_rounded,
                                    title: 'Offline',
                                    onTap: () =>
                                        _previewError(SelahErrorKind.offline),
                                  ),
                                  _ToolAction(
                                    icon: Icons.cloud_off_outlined,
                                    title: 'SELAH unavailable',
                                    onTap: () => _previewError(
                                      SelahErrorKind.serviceUnavailable,
                                    ),
                                  ),
                                  _ToolAction(
                                    icon: Icons.lock_clock_outlined,
                                    title: 'Session expired',
                                    onTap: () => _previewError(
                                      SelahErrorKind.sessionExpired,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            SelahDevControlSection.actions => [_pageTools()],
                            SelahDevControlSection.home => [
                              SelahDevHomeTools(
                                busy: _busy,
                                onHome: _returnHome,
                                onOpenSplashPreview: () =>
                                    setState(() => _open = false),
                                onRestart: _goHome,
                                onReset: () => unawaited(_resetEverything()),
                                onAccounts: _openDeveloperAccess,
                                onSeekerSignUp: _startSignUp,
                                onShepherdSignUp: _startSignUp,
                              ),
                            ],
                          },
                          if (_section == SelahDevControlSection.preview) ...[
                            const SizedBox(height: 18),
                            Text(
                              'Internal preview',
                              textAlign: TextAlign.center,
                              style: SelahText.subtext(
                                size: 10,
                                color: Colors.white24,
                              ),
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
        ],
      ),
    );
  }
}

// --- Panel presentation -------------------------------------------------

class _LocalOnlyBanner extends StatelessWidget {
  const _LocalOnlyBanner();

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('main_app_founder_preview_panel_banner'),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: SelahColors.journeyGold.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(
        color: SelahColors.journeyGold.withValues(alpha: 0.35),
        width: 0.5,
      ),
    ),
    child: Text(
      'Local preview · server controls unavailable',
      style: SelahText.subtext(size: 10.5, color: Colors.white70),
    ),
  );
}

class _PanelHeader extends StatelessWidget {
  final DevPage page;
  final String actionsTitle;
  final String? previewTitle;
  final SelahDevControlSection section;
  final VoidCallback onClose;

  const _PanelHeader({
    required this.page,
    required this.actionsTitle,
    this.previewTitle,
    required this.section,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  section == SelahDevControlSection.home
                      ? 'Developer Access'
                      : section == SelahDevControlSection.actions
                      ? actionsTitle
                      : previewTitle ?? page.label,
                  style: SelahText.heading(size: 18),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Close developer tools',
            onPressed: onClose,
            icon: const Icon(Icons.close, size: 18, color: Colors.white54),
          ),
        ],
      ),
    );
  }
}

class _PanelHeading extends StatelessWidget {
  final String label;
  const _PanelHeading(this.label);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 2, bottom: 8),
    child: Text(
      label.toUpperCase(),
      style: SelahText.chapterLabel(color: Colors.white38),
    ),
  );
}

class _ToolCard extends StatelessWidget {
  final List<Widget> children;
  const _ToolCard({required this.children});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
    decoration: BoxDecoration(
      color: SelahColors.surfaceFill,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Colors.white10, width: 0.5),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    ),
  );
}

class _ToolAction extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  const _ToolAction({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(9),
    onTap: onTap,
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            Icon(icon, size: 17, color: Colors.white54),
            const SizedBox(width: 9),
            Expanded(child: Text(title, style: SelahText.body(size: 12.5))),
            const Icon(Icons.chevron_right, size: 17, color: Colors.white24),
          ],
        ),
      ),
    ),
  );
}

class _InlineNotice extends StatelessWidget {
  final String message;
  final bool error;
  final VoidCallback onDismiss;
  const _InlineNotice({
    required this.message,
    required this.error,
    required this.onDismiss,
  });
  @override
  Widget build(BuildContext context) {
    final color = error ? const Color(0xFFDF7D82) : SelahColors.journeyDotGreen;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 9, 4, 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: SelahText.subtext(size: 10.5, color: Colors.white70),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: onDismiss,
            icon: const Icon(Icons.close, size: 15, color: Colors.white38),
          ),
        ],
      ),
    );
  }
}
