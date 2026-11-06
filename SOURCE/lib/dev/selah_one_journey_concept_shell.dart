// Disposable methodology comparison using the current app's presentation.
// No production routes/services are called, no member records are loaded,
// and no production preferences or records are written by this shell.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle;

import '../data/selah_journey_stages.dart';
import '../data/journey_questions.dart';
import '../data/selah_reference_data.dart';
import '../data/selah_journey_pause_state.dart';
import '../models/seeker_profile.dart';
import '../models/selah_shepherd_invite.dart';
import '../models/selah_action_pause.dart';
import '../models/selah_action_pause_controller.dart';
import '../models/selah_prayer.dart';
import '../models/selah_prayer_controller.dart';
import '../models/selah_shepherd_recent.dart';
import '../widgets/selah_prayer_views.dart';
import '../services/selah_developer_access.dart';
import '../widgets/selah_shepherd_invite_scope.dart';
import '../widgets/selah_shepherd_invite_views.dart';
import '../widgets/selah_marriage_prep_card.dart';
import '../widgets/selah_faith_profile_card.dart';
import '../models/selah_faith_profile.dart';
import '../models/selah_marriage_values.dart';
import '../widgets/selah_marriage_values_views.dart';
import '../widgets/selah_journey_marriage_profile.dart';
import '../widgets/selah_profile_image.dart';
import '../screens/onboarding/selah_shepherd_invite_flow.dart';
import '../screens/onboarding/selah_languages_flow.dart';
import '../screens/journey/selah_pause_screen.dart';
import '../models/selah_dashboard_resolution.dart';
import '../models/selah_supportive_dashboard.dart';
import '../services/selah_mentor_link_service.dart'
    show
        MentorLinkedPerson,
        SelahSourceResult,
        SelahSourceFailure,
        ShepherdHistoryConsentState,
        ShepherdJourneyAccessState,
        PendingInvite;
import '../services/selah_mentor_journey_service.dart' show MentorJourneyView;
import '../services/selah_family_messaging_service.dart';
import '../screens/mentor/family_messaging_screens.dart';
import '../screens/mentor/seeker_shepherd_designs.dart';
import '../screens/mentor/mentor_seekers_screen.dart'
    show ShepherdSeekerRosterView;
import '../screens/settings/help_support_screen.dart';
import '../screens/settings/personalisation_screen.dart';
import '../screens/profile/edit_profile_screen.dart';
import '../screens/profile/edit_photos_screen.dart';
import '../screens/profile/my_profile_preview_screen.dart';
import '../services/selah_shepherd_seeker_roster_resolver.dart'
    show ShepherdSeekerRosterResolution;
import '../theme/selah_card_metrics.dart';
import '../theme/selah_colors.dart';
import '../theme/selah_text.dart';
import '../widgets/floating_nav_bar.dart';
import '../widgets/selah_browse_options_button.dart';
import '../widgets/selah_browse_next_photo_motion.dart';
import '../widgets/selah_shepherd_dashboard_profile_card.dart';
import '../widgets/selah_loading.dart';
import '../widgets/selah_segmented_toggle.dart';
import '../widgets/selah_shell_navigation.dart';
import '../widgets/selah_quiet_dashboard.dart';
import '../widgets/selah_pull_down_back_scope.dart';
import '../widgets/selah_state_widgets.dart';
import '../widgets/searchable_list_picker.dart';
import 'selah_view_request_draft_model.dart';
import 'selah_browse_filter.dart';
import 'selah_browse_history.dart';
import 'selah_browse_photo_renderer.dart';
import 'selah_draft_compatibility_preview.dart';
import 'selah_draft_compatibility_presentation.dart';
import 'selah_draft_compatibility_store_presentation.dart';
import 'selah_draft_browse_utility_presentation.dart';
import 'selah_draft_code_entry.dart';
import 'selah_request_help_content.dart';
import 'selah_request_account_session.dart';
import 'selah_request_capacity_choice.dart';
import 'selah_shepherd_circle_preview.dart';
import 'selah_shepherd_circle_topic_options.dart';
import 'selah_one_journey_sample_photos.dart';
import 'selah_one_journey_discovery_presentation.dart';
import 'selah_one_journey_browse_designs.dart';
import 'selah_one_journey_card_content.dart';
import 'selah_one_journey_options.dart';
import 'selah_one_journey_shepherd_presentation.dart';
import 'selah_one_journey_account_presentation.dart';
import 'dev_settings_design_state.dart';
import 'selah_one_journey_journey_presentation.dart';
import '../screens/connections/connections_section_controller.dart';
import 'selah_dev_control_system.dart';
import 'selah_dev_tool_section.dart';
import '../theme/selah_interaction_style.dart';
import '../data/selah_membership_catalog.dart';

class SelahOneJourneyConceptShell extends StatefulWidget {
  const SelahOneJourneyConceptShell({
    super.key,
    required this.canAct,
    this.canActOnOwnedPause,
    this.appearanceCanAct,
    required this.onExit,
    this.onOption1,
    this.onDeveloperHome,
    this.onRoleChanged,
    this.accountSession,
    this.initialShepherdRole = false,
    this.initialShepherdInviteReview = false,
    this.initialSeekerBasic = false,
    this.initialShepherdBasic = false,
    this.faithConsentSkipped = false,
  });
  final bool Function() canAct;
  // Only the exact foreground Pause owned by this shell may use this scope.
  // Ordinary covered-screen callbacks still require canAct.
  final bool Function(Route<dynamic> pauseRoute)? canActOnOwnedPause;
  // Appearance survives an owned modal covering the route. Interaction still
  // requires canAct; actual owner/proof loss terminally invalidates the study.
  final bool Function()? appearanceCanAct;
  final VoidCallback onExit;
  final VoidCallback? onOption1;
  final VoidCallback? onDeveloperHome;
  final ValueChanged<bool>? onRoleChanged;
  final SelahRequestAccountSession? accountSession;
  final bool initialShepherdRole;
  final bool initialShepherdInviteReview;
  final bool initialSeekerBasic;
  final bool initialShepherdBasic;
  final bool faithConsentSkipped;
  @override
  State<SelahOneJourneyConceptShell> createState() =>
      _SelahOneJourneyConceptShellState();
}

class _SelahOneJourneyConceptShellState
    extends State<SelahOneJourneyConceptShell>
    with SingleTickerProviderStateMixin {
  final _model = ViewRequestDraftModel(capacity: 3);
  final _marriagePrepFailed = <String>{};
  bool _marriageShareLater = false;
  static const _prayerJoelFixtureId = 'prayer-seed-joel';
  final _prayerShellLifetime = Object();
  Object _prayerComposerLifetime = Object();
  late final _prayerStore = SelahPrayerStore.seeded(
    shepherdId: draftShepherds.first.id,
    jamesId: 'draft-self',
    joelId: _prayerJoelFixtureId,
    clock: DateTime.now,
  );
  SelahPrayerController? _prayerComposerController;
  bool _prayerEmptyView = false;
  bool _actionPauseOpen = false;
  Route<dynamic>? _ownedActionPauseRoute;
  final _replacementUpdates = <({String ending, String accepted})>[];
  SelahShepherdInviteController? _invite;
  bool _inviteWasPending = false;
  bool get _invitePending => _invite?.pending ?? false;

  void _inviteChanged() {
    if (!_allowed) return;
    final invite = _invite;
    if (invite == null) return;
    final newlyAccepted = _inviteWasPending && invite.accepted;
    _act(() {
      if (invite.hasInvite) {
        _model.setOwnMainShepherdPresent(invite.accepted);
      }
      _inviteWasPending = invite.pending;
      if (newlyAccepted && !_shepherdRole) {
        _notice = '${invite.firstName} said yes. You can ask and accept now.';
      }
    });
  }

  final _appearanceOwner = Object();
  final _scroll = ScrollController();
  final _message = TextEditingController();
  final _messages = <String, List<String>>{};
  final _pages = <String>[];
  final _expansion = SelahConnectionsExpansionController();
  SelahOneJourneySamplePhotos? _photos;
  final _browsePhotoRenderer = SelahBrowseLocalPhotoRenderer();
  bool _photoLoadFailed = false;
  int _tab = 0;
  int _requestsTab = 0;
  int _browseIndex = 1;
  // Session-only viewing order, never a visibility or request permission.
  final _seenBrowseProfileIds = <String>{};
  bool _browseExhausted = false;
  final _browseHistory = SelahBrowseHistory();
  // The approved portrait card is the single active Browse direction.
  static const _browseDesign = SelahOneJourneyBrowseDesign.portraitCard;
  SelahBrowseNextMotion _browseNextMotion = SelahBrowseNextMotion.current;
  int _browseNextMotionEpoch = 0;
  int _uiRevision = 0;
  bool _browseOptionsOpen = false;
  bool _browseHideConfirmation = false;
  String? _browseOptionsPersonId;
  int _shepherdPage = 0;
  int _networkTab = 0;
  String? _personId;
  String? _shepherdJourneyId;
  bool _journeyOptionsOpen = false;
  String? _expandedJourneyOptionsId;
  ({String id, bool incoming})? _capacityRequest;
  String? _capacityEndingId;
  bool _capacityConfirmOpen = false;
  String _heldTitle = '';
  String _heldDetail = '';
  String? _noticeValue;
  Timer? _noticeTimer;
  String? get _notice => _noticeValue;
  set _notice(String? value) {
    _noticeTimer?.cancel();
    _noticeValue = value;
    if (value != null) {
      _noticeTimer = Timer(const Duration(seconds: 3), () {
        if (_allowed && _noticeValue == value) {
          setState(() => _noticeValue = null);
        }
      });
    }
  }

  bool _shepherdRole = false;
  bool _shareHistory = false;
  bool get _gold => false;
  late final _goldMotion = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 12),
  );
  String _seekerMembership = 'Seeker One';
  String _shepherdMembership = 'Shepherd One';
  String get _membership =>
      _shepherdRole ? _shepherdMembership : _seekerMembership;

  SelahBrowseFilter _browseFilter = const SelahBrowseFilter();
  SelahBrowseFilter _editingBrowseFilter = const SelahBrowseFilter();
  SelahConceptAccountAction? _accountDestination;
  final _selectedProducts = <SelahMembershipProduct>{};
  // Route-local fictional credits, never an account ledger or entitlement.
  // Presets let the Founder set up a test before opening a person; a covered
  // Compatibility route keeps its own results until that route is closed.
  int _compatibilityUnlockPreset = 1;
  SelahDraftCompatibilityPreview? _compatibilityPreview;
  Widget? _scanEntryView;
  int _scanEntryRevision = -1;
  late final SelahRequestAccountSession _accountSession;
  GlobalKey<NavigatorState>? _accountNavigator;
  Widget? _accountLeafView;
  int _accountLeafRevision = -1;
  Widget? _ownProfilePreviewView;
  int _ownProfilePreviewRevision = -1;
  Widget? _circleEntryView;
  SelahShepherdCirclePreviewData? _circlePreviewData;
  int _shepherdAccessPreset = 0;
  bool _shepherdRecentEmpty = false;
  int _circleEntryRevision = -1;
  GlobalKey<NavigatorState>? _circleNavigator;
  int _circleScopeRevision = 0;
  final _circleTopicLayout = ValueNotifier(SelahCircleTopicLayout.current);
  final _circleVisibility = ValueNotifier(false);

  Future<void> _selectionHaptic() => SelahInteractionStyle.emitSelectionHaptic(
    level: _accountSession.hapticLevel,
  );

  bool get _allowed => mounted && widget.canAct();
  String? get _page => _pages.isEmpty ? null : _pages.last;
  String? get _pageOptionsSource => _page == 'controls'
      ? (_pages.length > 1 ? _pages[_pages.length - 2] : null)
      : _page;
  bool get _hasCircleDiscussionOptions =>
      _pageOptionsSource == 'shepherd_circle' ||
      (_pageOptionsSource == null && _tab == (_shepherdRole ? 2 : 3));
  bool get _supportsPageOptions =>
      _page == null ||
      _page == 'controls' ||
      _page == 'shepherd_circle' ||
      (!_shepherdRole && _page == 'prayer') ||
      (SelahDeveloperAccess.canUseDeveloperTools &&
          !_shepherdRole &&
          _page == 'journey' &&
          _personId != null &&
          _model.stateFor(_personId!) != null) ||
      (const [
        'held_action',
        'network_request',
        'account_action',
        'notifications',
        'filters',
        'bio',
        'journey_compatibility',
        'timeline',
      ].contains(_page)) ||
      (!_shepherdRole &&
          const [
            'compatibility',
            'requests',
            'ended',
            'past_journeys',
          ].contains(_page));
  String get _pageOptionsTitle => switch (_pageOptionsSource) {
    'shepherd_circle' => 'Shepherd Circle',
    'prayer' => 'Prayer',
    'journey' => 'Journey',
    'journey_compatibility' => 'Journey compatibility',
    'bio' => 'Journey Bio',
    'timeline' => 'Timeline',
    'held_action' => _heldTitle,
    'network_request' => 'Speak to Shepherd',
    'account_action' =>
      _accountDestination == null
          ? 'Account'
          : _accountActionLabel(_accountDestination!),
    'notifications' => 'Updates',
    'filters' => 'Filters',
    'compatibility' => 'Compatibility',
    'requests' =>
      'Journey requests · ${const ['Received', 'Sent', 'Introductions'][_requestsTab]}',
    'ended' || 'past_journeys' => 'Ended Journeys',
    _ =>
      _shepherdRole
          ? const ['My SELAH', 'Network', 'Seekers', 'Profile'][_tab]
          : const [
              'Browse',
              'Journey',
              'My SELAH',
              'Shepherd',
              'Profile',
            ][_tab],
  };

  void _togglePageOptions() {
    if (!_allowed) return;
    if (_page == 'shepherd_circle' &&
        (_circleNavigator?.currentState?.canPop() ?? false)) {
      return;
    }
    FocusScope.of(context).unfocus();
    if (_page == 'controls' || !_supportsPageOptions) {
      _back();
    } else {
      _open('controls');
    }
  }

  bool get _isPhotoPage => const [
    'profile',
    'own_profile_preview',
    'shepherd_linked_profile',
    'shepherd_network_profile',
  ].contains(_page);
  DraftProfile? get _person => _personId == null
      ? null
      : draftProfiles.where((p) => p.id == _personId).firstOrNull;
  List<DraftProfile> get _currentJourneys => draftProfiles.where((p) {
    final s = _model.stateFor(p.id);
    return s == DraftJourneyState.preparing ||
        s == DraftJourneyState.active ||
        s == DraftJourneyState.pauseRequested;
  }).toList();
  DraftProfile? get _focus => _currentJourneys.firstOrNull;

  // One read projection for cards, counts, badges and updates. Blocking hides
  // an invitation here without deleting its underlying fictional record.
  // Hide is deliberately different: it only removes the peer from Browse.
  List<DraftProfile> _visibleRequests(DraftJourneyState state) => draftProfiles
      .where(
        (person) =>
            !_model.isBlocked(person.id) && _model.stateFor(person.id) == state,
      )
      .toList(growable: false);

  // A request/preparation is not a current Journey disclosure to Shepherds.
  List<DraftProfile> get _shepherdJourneys => draftProfiles.where((p) {
    final s = _model.stateFor(p.id);
    return !_model.isBlocked(p.id) &&
        (s == DraftJourneyState.active ||
            s == DraftJourneyState.pauseRequested);
  }).toList();
  List<DraftProfile> get _permittedShepherdJourneys => !_conceptHassanLinked
      ? const []
      : _shepherdJourneys
            .where(
              (p) =>
                  _conceptLinkedSeeker.isMain ||
                  _conceptAccessFor('draft-shepherd-hassan', p.id).view,
            )
            .toList();
  DraftProfile? get _shepherdFocus =>
      _permittedShepherdJourneys
          .where((p) => p.id == _shepherdJourneyId)
          .firstOrNull ??
      _permittedShepherdJourneys.firstOrNull;

  @override
  void initState() {
    super.initState();
    _shepherdRole = widget.initialShepherdRole;
    if (widget.initialShepherdInviteReview && _shepherdRole) {
      _pages.add('shepherd_invite_review');
    }
    _accountSession =
        widget.accountSession ??
        SelahRequestAccountSession(
          canAct: () => _allowed,
          palette: SelahColors.devPalette,
          hapticLevel: SelahInteractionStyle.hapticLevel,
          goldEnabled: _gold,
        );
    _accountSession.addListener(_accountChanged);
    SelahVisualComparison.instance.bind(
      _appearanceOwner,
      () => mounted && (widget.appearanceCanAct ?? widget.canAct)(),
    );
    if (widget.initialSeekerBasic) {
      _model.setCapacity(1);
      _seekerMembership = 'Seeker Basic';
    }
    if (widget.initialShepherdBasic) {
      _shepherdMembership = 'Shepherd Basic';
      _model.setSampleShepherdMembership(
        'draft-shepherd-hassan',
        DraftShepherdMembership.basic,
      );
    }
    unawaited(_loadBrowsePhotos());
  }

  Future<void> _loadBrowsePhotos() async {
    try {
      final value = await SelahOneJourneySamplePhotos.load();
      if (!_allowed) return;
      // Publish this bounded offline deck only after its first image frames
      // are ready. Person and photo identity then change together, without a
      // blank decode frame or retaining another person's photograph.
      final ready = await _browsePhotoRenderer.prepare(
        value.sets.expand((group) => group),
      );
      if (!_allowed) return;
      setState(() {
        if (ready) {
          _photos = value;
          _accountSession.seedPhotos(false, [value.seekerPhoto]);
          _accountSession.seedPhotos(true, [value.shepherdPhoto]);
        } else {
          _photoLoadFailed = true;
        }
      });
    } catch (_) {
      if (_allowed) setState(() => _photoLoadFailed = true);
    }
  }

  void _act(VoidCallback change, {bool preserveCircle = false}) {
    if (!_allowed) return;
    setState(() {
      _browseOptionsOpen = false;
      _browseHideConfirmation = false;
      _browseOptionsPersonId = null;
      change();
      if (_expandedJourneyOptionsId case final id?) {
        if (_shepherdRole ||
            _tab != 1 ||
            _page != null ||
            _model.isBlocked(id) ||
            !_currentJourneys.any((person) => person.id == id)) {
          _expandedJourneyOptionsId = null;
        }
      }
      if (_capacityRequest case final request?) {
        if (_shepherdRole ||
            _tab != 2 ||
            _page != 'request_capacity' ||
            _model.isBlocked(request.id) ||
            _model.stateFor(request.id) !=
                (request.incoming
                    ? DraftJourneyState.received
                    : DraftJourneyState.sent)) {
          _capacityRequest = null;
          _capacityEndingId = null;
        }
      }
      _uiRevision++;
      if (!preserveCircle) _circleScopeRevision++;
      _circleVisibility.value = _page == 'shepherd_circle';
    });
    _syncGoldMotion();
  }

  void _move(VoidCallback change, {bool preserveCircle = false}) {
    _act(() {
      _notice = null;
      _expandedJourneyOptionsId = null;
      _capacityRequest = null;
      _capacityEndingId = null;
      change();
      if (_shepherdRole || !_pages.contains('compatibility')) {
        _compatibilityPreview = null;
      }
    }, preserveCircle: preserveCircle);
    if (_allowed && _scroll.hasClients) _scroll.jumpTo(0);
  }

  void _tabTo(int index) => _move(() {
    _tab = index;
    _expansion.collapseAll();
    if (!_shepherdRole && index == 3) _shepherdPage = 0;
    _pages.clear();
  });
  void _open(String page, {String? person}) {
    if (page == 'scan' &&
        (!_allowed || _shepherdRole || _tab != 0 || !_model.canBrowse)) {
      return;
    }
    if (page == 'compatibility' &&
        (!_allowed ||
            _shepherdRole ||
            !draftProfiles.any((p) => p.id == person) ||
            _model.isBlocked(person!))) {
      return;
    }
    final preserveCircle = page == 'controls' && _page == 'shepherd_circle';
    _move(() {
      if (person != null) _personId = person;
      if (page == 'compatibility') {
        _compatibilityPreview = SelahDraftCompatibilityPreview(
          person!,
          balance: _compatibilityUnlockPreset,
        );
      }
      if (page == 'journey_shepherds') _shepherdPage = 0;
      if (page == 'filters') _editingBrowseFilter = _browseFilter;
      _pages.add(page);
    }, preserveCircle: preserveCircle);
  }

  void _back() {
    if (_expandedJourneyOptionsId != null && _page == null) {
      _act(() => _expandedJourneyOptionsId = null);
      return;
    }
    if (_isRetainedAccountPage &&
        (_accountNavigator?.currentState?.canPop() ?? false)) {
      _accountNavigator!.currentState!.pop();
      return;
    }
    if (_page == 'shepherd_circle' &&
        (_circleNavigator?.currentState?.canPop() ?? false)) {
      _circleNavigator!.currentState!.pop();
      return;
    }
    if (_browseOptionsOpen) {
      if (_browseHideConfirmation) {
        _openBrowseOptions(_browseOptionsPersonId);
        return;
      }
      _act(() {});
      return;
    }
    final preserveCircle =
        _page == 'controls' && _pageOptionsSource == 'shepherd_circle';
    _move(() {
      if (_page == 'filters') _editingBrowseFilter = _browseFilter;
      if (_pages.isNotEmpty) _pages.removeLast();
    }, preserveCircle: preserveCircle);
  }

  bool _canOpenBrowseOptions(String? id) =>
      _allowed &&
      !_shepherdRole &&
      _tab == 0 &&
      (_page == null || _page == 'profile') &&
      _model.canBrowse &&
      (id == null ||
          (_page == 'profile'
                  ? _model.discoverableProfiles
                  : _browseFilter.apply(_model.discoverableProfiles))
              .any((person) => person.id == id));

  void _openBrowseOptions(String? id, {bool feedback = true}) {
    if (!_canOpenBrowseOptions(id)) return;
    if (feedback) unawaited(_selectionHaptic());
    _act(() {
      _browseOptionsOpen = true;
      _browseOptionsPersonId = id;
    });
  }

  Widget _browseOptionsButton(DraftProfile person) {
    final open = _bound(() => _openBrowseOptions(person.id));
    return SelahBrowseOptionsButton(
      alignToContentEdge: true,
      profile: _displayProfile(person),
      onOpen: (_) => open(),
    );
  }

  Widget _browseOptionsNavigation() {
    final revision = _uiRevision;
    final page = _page;
    final id = _browseOptionsPersonId;
    bool current() =>
        _browseOptionsOpen &&
        revision == _uiRevision &&
        page == _page &&
        id == _browseOptionsPersonId &&
        _canOpenBrowseOptions(id);
    if (_browseHideConfirmation) {
      return FloatingNavConfirmationBar(
        key: const ValueKey('concept_browse_hide_confirmation'),
        showOuterSurface: false,
        contentEdgeInset: 20,
        hapticLevel: _accountSession.hapticLevel,
        onCancel: () {
          // The confirmation pill owns this press's single feedback tick.
          if (current()) _openBrowseOptions(id, feedback: false);
        },
        onConfirm: () {
          if (!current() || id == null) return;
          _move(() {
            if (!_model.hide(id)) return;
            _pages.clear();
            _personId = null;
            _notice = 'Profile hidden.';
          });
        },
      );
    }
    final navigation = SelahShellNavigation(
      key: const ValueKey('concept_browse_options_navigation'),
      forceCurrent: true,
      commitOnRelease: true,
      contentEdgeInset: 20,
      hapticLevel: _accountSession.hapticLevel,
      currentIndex: 0,
      items: [
        for (final action in SelahBrowseAction.values)
          FloatingNavItem(
            icon: action.icon,
            label: action.label,
            dimmed:
                id == null &&
                action != SelahBrowseAction.scan &&
                action != SelahBrowseAction.filters,
          ),
      ],
      onTap: (index) {
        if (!current() ||
            index < 0 ||
            index >= SelahBrowseAction.values.length) {
          return;
        }
        final action = SelahBrowseAction.values[index];
        final person = draftProfiles.where((p) => p.id == id).firstOrNull;
        if (person == null &&
            action != SelahBrowseAction.scan &&
            action != SelahBrowseAction.filters) {
          return;
        }
        switch (action) {
          case SelahBrowseAction.compatibility:
            _open('compatibility', person: person!.id);
          case SelahBrowseAction.scan:
            _open('scan');
          case SelahBrowseAction.hide:
            _act(() {
              _browseOptionsOpen = true;
              _browseOptionsPersonId = person!.id;
              _browseHideConfirmation = true;
            });
          case SelahBrowseAction.filters:
            _open('filters');
          case SelahBrowseAction.report:
            _open('safety', person: person!.id);
        }
      },
    );
    // Navigation resolves to Positioned; keep it directly under a Stack.
    // The separate cue never owns touch, semantics or destination authority.
    return navigation;
  }

  void _result(bool success, String message) {
    _notice = success
        ? message
        : 'This is no longer available. Nothing changed.';
  }

  void _journey(String id) => _open('journey', person: id);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final invite = SelahShepherdInviteScope.maybeOf(context);
    if (_invite != invite) {
      _invite?.removeListener(_inviteChanged);
      _invite = invite;
      invite?.addListener(_inviteChanged);
      _inviteWasPending = invite?.pending ?? false;
      if (invite?.hasInvite ?? false) {
        _model.setOwnMainShepherdPresent(invite!.accepted);
      }
    }
    _syncGoldMotion();
  }

  void _syncGoldMotion() {
    final reduce =
        MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context);
    final fullPhoto = _isPhotoPage;
    if (reduce || !_gold || fullPhoto) {
      _goldMotion.stop();
      _goldMotion.value = 0;
    } else if (!_goldMotion.isAnimating) {
      _goldMotion.repeat();
    }
  }

  @override
  void dispose() {
    SelahVisualComparison.instance.release(_appearanceOwner);
    _invite?.removeListener(_inviteChanged);
    _noticeTimer?.cancel();
    _browsePhotoRenderer.dispose();
    _expansion.dispose();
    _goldMotion.dispose();
    _scroll.dispose();
    _message.dispose();
    _prayerComposerController?.dispose();
    _prayerStore.clear();
    _accountSession.removeListener(_accountChanged);
    if (widget.accountSession == null) _accountSession.dispose();
    _circleTopicLayout.dispose();
    _circleVisibility.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final railFresh = _accountFreshGuard();
    final names = _shepherdRole
        ? ['Dashboard', 'Network', 'Seekers', 'Profile']
        : ['Browse', 'Journey', 'My SELAH', 'Shepherd', 'Profile'];
    final icons = _shepherdRole
        ? [
            Icons.dashboard_outlined,
            Icons.diversity_3_outlined,
            Icons.people_outline,
            Icons.person_outline,
          ]
        : [
            Icons.search,
            Icons.route_outlined,
            Icons.dashboard_outlined,
            Icons.gpp_good_outlined,
            Icons.person_outline,
          ];
    final fullPhoto = _isPhotoPage;
    final ownsViewport =
        _page == null ||
        fullPhoto ||
        [
          'settings',
          'personalisation',
          'edit_profile',
          'manage_photos',
          'membership',
          'journey',
          'journey_marriage_profile',
          'request_capacity',
          'journey_shepherds',
          'prayer',
          'shepherd_invite_review',
          'shepherd_circle',
          'account_action',
          'shepherd_linked_profile',
          'shepherd_network_profile',
          'requests',
          'saved',
          'paused',
          'ended',
          'own_profile_preview',
          'past_journeys',
          'compatibility',
          'compatibility_store',
          'scan',
          'help_support',
          'safety',
        ].contains(_page);
    final circleViewport =
        _page == 'shepherd_circle' ||
        (_page == 'controls' && _pageOptionsSource == 'shepherd_circle');
    final content = circleViewport
        ? _circleOptionsViewport()
        : ownsViewport
        ? _content()
        : SafeArea(
            bottom: false,
            child: SingleChildScrollView(
              key: const ValueKey('draft_scroll'),
              controller: _scroll,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
              child: _content(),
            ),
          );
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: PopScope(
        canPop:
            _pages.isEmpty &&
            !_browseOptionsOpen &&
            _expandedJourneyOptionsId == null,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop && _allowed) _back();
        },
        child: Scaffold(
          backgroundColor: SelahColors.mist,
          extendBody: true,
          body: DecoratedBox(
            decoration: BoxDecoration(color: SelahColors.mist),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if ((_pages.isNotEmpty || _expandedJourneyOptionsId != null) &&
                    !_isRetainedAccountPage &&
                    _page != 'own_profile_preview')
                  SelahPullDownBackScope(
                    key: const ValueKey('concept_pull_down_back_scope'),
                    routeIdentity: (
                      List<String>.of(_pages).join('/'),
                      _tab,
                      _shepherdRole,
                      _personId,
                      _uiRevision,
                      _expandedJourneyOptionsId,
                    ),
                    enabled: _allowed && !_browseOptionsOpen,
                    onBack: _bound(() {
                      // A sheet can open before the parent rebuilds. Recheck
                      // current decision ownership at dispatch, not just build.
                      if (!_browseOptionsOpen &&
                          !_journeyOptionsOpen &&
                          !_capacityConfirmOpen) {
                        _back();
                      }
                    }),
                    child: content,
                  )
                else
                  content,
                if (_browseOptionsOpen)
                  Positioned.fill(
                    child: GestureDetector(
                      key: const ValueKey('concept_browse_options_dismiss'),
                      behavior: HitTestBehavior.opaque,
                      onTap: _bound(() => _act(() {})),
                      child: const SizedBox.expand(),
                    ),
                  ),
                if (_browseOptionsOpen)
                  _browseOptionsNavigation()
                else if (_page == null ||
                    (!_shepherdRole &&
                        (_page == 'prayer' ||
                            _page == 'journey_marriage_profile')))
                  SelahShellNavigation(
                    forceCurrent: true,
                    hapticLevel: _accountSession.hapticLevel,
                    contentEdgeInset: !_shepherdRole && _tab == 0 ? 20 : null,
                    items: [
                      for (var i = 0; i < names.length; i++)
                        FloatingNavItem(
                          icon: icons[i],
                          label: names[i],
                          useJourneyGlyph: !_shepherdRole && i == 1,
                          dot:
                              !_shepherdRole &&
                              i == 2 &&
                              _visibleRequests(
                                DraftJourneyState.received,
                              ).isNotEmpty,
                        ),
                    ],
                    currentIndex: _tab,
                    onTap: _tabTo,
                  ),
                // The same developer rail as the current app, not an extra footer
                // that moves every header/content area upward.
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  width: SelahDevControlRail.width,
                  child: SelahDevControlRail(
                    visibleSections: const [
                      SelahDevControlSection.home,
                      SelahDevControlSection.actions,
                    ],
                    open: false,
                    selected: SelahDevControlSection.preview,
                    buttonKeys: const {
                      SelahDevControlSection.home: ValueKey('draft_close'),
                      SelahDevControlSection.preview: ValueKey('draft_rules'),
                      SelahDevControlSection.actions: ValueKey('draft_back'),
                    },
                    labels: {
                      SelahDevControlSection.home:
                          widget.onDeveloperHome == null
                          ? 'Current SELAH · turn concept off'
                          : 'Developer Home',
                      SelahDevControlSection.preview: 'Sample preview controls',
                      SelahDevControlSection.actions: _page == 'controls'
                          ? 'Close page options'
                          : _supportsPageOptions
                          ? 'Page options for $_pageOptionsTitle'
                          : 'Back',
                    },
                    onSelected: (section) {
                      if (!railFresh()) return;
                      switch (section) {
                        case SelahDevControlSection.home:
                          SelahVisualComparison.instance.release(
                            _appearanceOwner,
                          );
                          (widget.onDeveloperHome ?? widget.onExit)();
                        case SelahDevControlSection.preview:
                          _togglePageOptions();
                        case SelahDevControlSection.actions:
                          _togglePageOptions();
                      }
                    },
                  ),
                ),
                if (_notice != null)
                  Positioned(
                    left: 20,
                    right: 48,
                    bottom: MediaQuery.paddingOf(context).bottom + 82,
                    child: Semantics(
                      liveRegion: true,
                      child: IgnorePointer(
                        child: Material(
                          color: SelahColors.inkColor,
                          borderRadius: BorderRadius.circular(14),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              _notice!,
                              style: SelahText.body(
                                size: 14,
                                color: SelahColors.mist,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _circleOptionsViewport() {
    final covered = _page == 'controls';
    return Stack(
      key: const ValueKey('circle_options_viewport'),
      fit: StackFit.expand,
      children: [
        Offstage(
          offstage: covered,
          child: TickerMode(enabled: !covered, child: _shepherdCircle()),
        ),
        if (covered)
          Container(
            decoration: BoxDecoration(
              gradient: SelahColors.isWafaPreview
                  ? SelahColors.wafaCanvas
                  : _accountSession.palette.gradient,
            ),
            child: SafeArea(
              bottom: false,
              child: SingleChildScrollView(
                key: const ValueKey('circle_page_options_scroll'),
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
                child: _controls(),
              ),
            ),
          ),
      ],
    );
  }

  Widget _content() => switch (_page) {
    'controls' => _controls(),
    'shepherd_invite_review' => _shepherdInviteReview(),
    'profile' => _profileView(),
    'journey' => _journeyView(),
    'journey_marriage_profile' => _journeyMarriageProfile(),
    'request_capacity' => _requestCapacityView(),
    'journey_compatibility' => _journeyCompatibility(),
    'journey_shepherds' => _journeyShepherds(),
    'shepherd_circle' => _shepherdCircle(),
    'prayer' => _prayerPage(),
    'network_request' => _networkRequestConfirmation(),
    'held_action' => _heldPreviewAction(),
    'own_profile_preview' => _ownProfilePreview(),
    'past_journeys' => _activityPage('Ended Journeys', _history(true)),
    'requests' => _requestActivity(),
    'saved' || 'paused' => _unavailable(),
    'ended' => _historyActivity(true),
    'shepherd' => _shepherdDetail(),
    'shepherd_linked_profile' => _shepherdLinkedProfile(),
    'shepherd_network_profile' => _shepherdNetworkProfile(),
    'settings' => _settings(),
    'personalisation' => _personalisation(),
    'edit_profile' || 'manage_photos' => _retainedAccountLeaf(),
    'membership' => _membershipView(),
    'bio' => _bio(),
    'compatibility' => _compatibilityInfo(),
    'compatibility_store' => _compatibilityStore(),
    'notifications' => _notificationsView(),
    'filters' => _filters(),
    'scan' => _scanEntry(),
    'help_support' => _helpSupport(),
    'safety' => _safety(),
    'timeline' => _timeline(_personId ?? ''),
    'account_action' => _accountActionView(),
    _ =>
      _shepherdRole
          ? switch (_tab) {
              0 => _shepherdDashboard(),
              1 => _network(),
              2 => _shepherdSeekers(),
              _ => _ownProfile(),
            }
          : switch (_tab) {
              0 => _discover(),
              1 => _connections(),
              2 => _dashboard(),
              3 => _shepherds(),
              _ => _ownProfile(),
            },
  };

  VoidCallback _bound(VoidCallback action) {
    final revision = _uiRevision;
    final page = _page;
    final tab = _tab;
    final shepherd = _shepherdRole;
    return () {
      if (!_allowed ||
          revision != _uiRevision ||
          page != _page ||
          tab != _tab ||
          shepherd != _shepherdRole) {
        return;
      }
      action();
    };
  }

  Widget _scanEntry() {
    // Keep the adapter callbacks stable through harmless bundled-photo/theme
    // repaints. A new page/role/revision gets an independent entry lifetime.
    if (_scanEntryView != null && _scanEntryRevision == _uiRevision) {
      return _scanEntryView!;
    }
    final revision = _uiRevision;
    _scanEntryRevision = revision;
    bool current() =>
        _allowed &&
        !_shepherdRole &&
        _tab == 0 &&
        _page == 'scan' &&
        revision == _uiRevision &&
        _model.canBrowse;
    bool eligible(DraftProfile person) =>
        draftProfiles.any((known) => identical(known, person)) &&
        _model.discoverableProfiles.any((known) => known.id == person.id);
    return _scanEntryView = SelahDraftCodeEntry(
      key: ValueKey(('draft_code_entry', revision)),
      canAct: current,
      lookupCode: (code) async {
        if (!current()) return null;
        final person = SelahDraftKnownPersonCodes.resolve(code);
        return person != null && eligible(person) ? person : null;
      },
      onViewProfile: (person) {
        if (!current() || !eligible(person)) return;
        _open('profile', person: person.id);
      },
    );
  }

  Widget _helpSupport() => HelpSupportScreen.preview(
    canAct: _accountFreshGuard(),
    categories: selahRequestHelpCategories,
  );

  SeekerProfile _displayProfile(DraftProfile p) => SeekerProfile(
    id: p.id,
    firstName: p.firstName,
    surnameLine: p.surname,
    age: p.age,
    city: p.city,
    faithProfile: SelahFaithProfileAnswers(
      tradition: p.faithTradition,
      church: p.churchAttendance,
      baptised: p.baptised,
      words: p.faithWords,
    ),
    marriageValues: _marriageShareLater && p.id == 'draft-amira'
        ? SelahMarriageValuesAnswers.fromMap({
            ...p.marriageValues,
            'marriedBefore': 'I’d rather share later',
          })
        : p.marriageAnswers,
    gender: 'female',
    photos: _photos?.forIndex(draftProfiles.indexOf(p)) ?? const [],
  );

  bool _canToggleInvitation(String id) =>
      !_shepherdRole &&
      !_model.isBlocked(id) &&
      (_model.stateFor(id) == DraftJourneyState.sent || _model.canRequest(id));

  String _invitationLabel(String id) => switch (_model.stateFor(id)) {
    null =>
      _invitePending
          ? 'Request later'
          : (_invite?.accepted ?? false)
          ? 'Request a Journey'
          : 'Request a Journey',
    DraftJourneyState.sent => 'Journey invitation sent',
    DraftJourneyState.ended => 'Journey archived',
    DraftJourneyState.preparing || DraftJourneyState.active => 'In a Journey',
    final state => _stateLabel(state),
  };

  String? get _actionShepherdName {
    final people = _conceptShepherdPeople;
    final person =
        people.where((person) => person.isMain).firstOrNull ??
        people.firstOrNull;
    final name = person?.firstName.trim();
    return name == null || name.isEmpty ? null : name;
  }

  String _actionPersonName(DraftProfile person) =>
      _model.isBlocked(person.id) ? 'User not found' : person.firstName;

  Future<void> _pauseDeveloperOptions(
    BuildContext pauseContext,
    SelahActionPauseController controller,
  ) async {
    if (!controller.active || !SelahDeveloperAccess.canUseDeveloperTools) {
      return;
    }
    final selected = await showModalBottomSheet<SelahActionPauseState>(
      context: pauseContext,
      builder: (sheetContext) {
        void choose(SelahActionPauseState state) {
          if (!sheetContext.mounted ||
              ModalRoute.of(sheetContext)?.isCurrent != true ||
              !SelahDeveloperAccess.canUseDeveloperTools) {
            return;
          }
          Navigator.of(sheetContext).pop(state);
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Page options', style: SelahText.option(size: 18)),
                TextButton(
                  key: const ValueKey('pause_state_ready'),
                  onPressed: () => choose(SelahActionPauseState.ready),
                  child: const Text('Pause · ready'),
                ),
                TextButton(
                  key: const ValueKey('pause_state_working'),
                  onPressed: () => choose(SelahActionPauseState.working),
                  child: Text('Pause · ${controller.pause.workingLabel}'),
                ),
                TextButton(
                  key: const ValueKey('pause_state_failed'),
                  onPressed: () => choose(SelahActionPauseState.failed),
                  child: const Text('Pause · didn’t go through'),
                ),
              ],
            ),
          ),
        );
      },
    );
    // Revalidate only after this owned sheet uncovers the Pause route.
    if (selected == null ||
        !mounted ||
        !controller.active ||
        !SelahDeveloperAccess.canUseDeveloperTools) {
      return;
    }
    switch (selected) {
      case SelahActionPauseState.ready:
        controller.showReady();
      case SelahActionPauseState.working:
        controller.showWorking();
      case SelahActionPauseState.failed:
        controller.showFailure();
      case SelahActionPauseState.done:
        return;
    }
  }

  bool get _canActOnOwnedPause {
    if (!mounted) return false;
    final route = _ownedActionPauseRoute;
    if (!_actionPauseOpen || route == null) return _allowed;
    if (!route.isActive || !route.isCurrent) return false;
    return widget.canActOnOwnedPause?.call(route) ?? widget.canAct();
  }

  bool Function() _actionPauseFreshGuard() {
    final revision = _uiRevision;
    final shepherd = _shepherdRole;
    final page = _page;
    final tab = _tab;
    return () =>
        _canActOnOwnedPause &&
        revision == _uiRevision &&
        shepherd == _shepherdRole &&
        page == _page &&
        tab == _tab;
  }

  Future<bool> _presentActionPause({
    required SelahActionPause pause,
    required bool Function() current,
    required bool Function() commit,
  }) async {
    if (_actionPauseOpen || !current()) return false;
    if (!pause.canOpen) {
      _act(() => _notice = SelahActionPause.noShepherdMessage);
      return false;
    }
    final ownerCurrent = _accountFreshGuard();
    final pauseCurrent = _actionPauseFreshGuard();
    _actionPauseOpen = true;
    late final MaterialPageRoute<bool> route;
    final controller = SelahActionPauseController(
      pause: pause,
      canAct: () =>
          pauseCurrent() &&
          _actionPauseOpen &&
          identical(_ownedActionPauseRoute, route),
      commit: () => route.isCurrent && current() && commit(),
    );
    route = MaterialPageRoute<bool>(
      builder: (pauseContext) {
        void close(bool done) {
          if (pauseContext.mounted && route.isActive && route.isCurrent) {
            Navigator.of(pauseContext).pop(done);
          }
        }

        return SelahPauseScreen(
          controller: controller,
          onCancel: () => close(false),
          onDone: () => close(true),
          developerControls: SelahDevControlRail(
            open: false,
            selected: SelahDevControlSection.actions,
            visibleSections: const [
              SelahDevControlSection.home,
              SelahDevControlSection.actions,
            ],
            buttonKeys: const {
              SelahDevControlSection.home: ValueKey('pause_developer_home'),
              SelahDevControlSection.actions: ValueKey(
                'pause_developer_actions',
              ),
            },
            onSelected: (section) {
              if (!controller.active ||
                  !SelahDeveloperAccess.canUseDeveloperTools) {
                return;
              }
              if (section == SelahDevControlSection.home) {
                controller.cancel();
                close(false);
                if (_allowed) (widget.onDeveloperHome ?? widget.onExit)();
              } else {
                _pauseDeveloperOptions(pauseContext, controller);
              }
            },
          ),
        );
      },
    );
    _ownedActionPauseRoute = route;
    try {
      final committed = await Navigator.of(context).push(route);
      return committed == true && ownerCurrent();
    } finally {
      controller.dispose();
      _ownedActionPauseRoute = null;
      _actionPauseOpen = false;
    }
  }

  Future<void> _toggleInvitation(String id) async {
    if (!_allowed || !_canToggleInvitation(id)) return;
    if (_model.stateFor(id) != DraftJourneyState.sent &&
        _actionShepherdName == null) {
      _act(() => _notice = SelahActionPause.noShepherdMessage);
      return;
    }
    if (_invitePending) {
      _act(
        () => _notice =
            'You can request a Journey once ${_invite!.firstName} accepts your invite.',
      );
      return;
    }
    if (_model.stateFor(id) == DraftJourneyState.sent) {
      unawaited(_selectionHaptic());
      _act(() {
        _seenBrowseProfileIds.add(id);
        _model.cancel(id);
      });
      return;
    }
    final person = draftProfiles.where((person) => person.id == id).firstOrNull;
    if (person == null) return;
    final fresh = _actionPauseFreshGuard();
    final shepherd = _actionShepherdName;
    final committed = await _presentActionPause(
      pause: SelahActionPause(
        kind: SelahActionPauseKind.ask,
        name: _actionPersonName(person),
        shepherdName: shepherd,
      ),
      current: () => fresh() && _model.canRequest(id) && !_invitePending,
      commit: () => _model.request(id),
    );
    if (!committed) return;
    unawaited(_selectionHaptic());
    _act(() {
      _seenBrowseProfileIds.add(id);
      _notice = 'Request sent to ${person.firstName}. $shepherd has been told.';
    });
  }

  Widget _photoSurface(
    DraftProfile p, {
    bool browsing = false,
    Widget? sheet,
  }) => Stack(
    fit: StackFit.expand,
    children: [
      SelahOneJourneyBrowsePresentation(
        profile: _displayProfile(p),
        onMenu: _bound(
          () => _open(browsing ? 'filters' : 'safety', person: p.id),
        ),
        menuKey: ValueKey(browsing ? 'concept_filters' : 'draft_safety'),
        menuButton: !_shepherdRole && _tab == 0 && _page == 'profile'
            ? _browseOptionsButton(p)
            : null,
        previousKey: const ValueKey('draft_browse_previous'),
        nextKey: const ValueKey('draft_browse_next'),
        onPreviousProfile: browsing && _browseHistory.canBack
            ? _bound(() => _act(_previousBrowseProfile))
            : null,
        onNextProfile: browsing ? _bound(() => _act(_nextBrowseProfile)) : null,
        requestKey: ValueKey(
          browsing ? 'draft_profile_${p.id}' : 'draft_request',
        ),
        requestLabel: _invitationLabel(p.id),
        invitationSent: _model.stateFor(p.id) == DraftJourneyState.sent,
        onRequest: _canToggleInvitation(p.id)
            ? _bound(() => _toggleInvitation(p.id))
            : null,
        showSave: false,
      ),
      if (_photoLoadFailed)
        Positioned(
          top: 100,
          left: 20,
          right: 60,
          child: _body('Photos didn’t load', small: true),
        ),
      if (sheet != null)
        Positioned.fill(
          child: ColoredBox(
            color: Colors.black.withValues(alpha: .7),
            child: SafeArea(
              child: SingleChildScrollView(
                key: const ValueKey('draft_scroll'),
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(20, 32, 20, 100),
                child: sheet,
              ),
            ),
          ),
        ),
    ],
  );

  int _browseSelectionIndex(List<DraftProfile> people) {
    if (people.isEmpty) {
      _browseHistory.reconcile(const []);
      return 0;
    }
    final fallback =
        ((_browseIndex % people.length) + people.length) % people.length;
    _browseHistory.reconcile(
      people.map((person) => person.id),
      fallbackId: people[fallback].id,
    );
    final current = people.indexWhere(
      (person) => person.id == _browseHistory.currentId,
    );
    return _browseIndex = current < 0 ? fallback : current;
  }

  void _previousBrowseProfile() {
    final people = _browseFilter.apply(_model.discoverableProfiles);
    if (!_model.canBrowse || people.isEmpty) return;
    _browseSelectionIndex(people);
    final previous = _browseHistory.back();
    if (previous == null) return;
    unawaited(_selectionHaptic());
    _browseIndex = people.indexWhere((person) => person.id == previous);
  }

  void _nextBrowseProfile() {
    final people = _browseFilter.apply(_model.discoverableProfiles);
    if (!_model.canBrowse || people.isEmpty) return;
    unawaited(_selectionHaptic());
    final current = _browseSelectionIndex(people);
    final replay = _browseHistory.forwardReplay();
    if (replay != null) {
      _browseIndex = people.indexWhere((person) => person.id == replay);
      if (_browseIndex >= 0 && replay != people[current].id) {
        ++_browseNextMotionEpoch;
      }
      return;
    }
    _seenBrowseProfileIds.add(people[current].id);
    // Neutral Next exhausts the visible frontier without making a decision.
    // Hidden, blocked and occupied peers never enter the eligible deck.
    int? next;
    for (var offset = 1; offset < people.length; offset++) {
      final candidate = (current + offset) % people.length;
      if (!_seenBrowseProfileIds.contains(people[candidate].id)) {
        next = candidate;
        break;
      }
    }
    if (next == null) {
      _browseExhausted = true;
      return;
    }
    _browseIndex = next;
    if (people[next].id != people[current].id) ++_browseNextMotionEpoch;
    _seenBrowseProfileIds.add(people[next].id);
    _browseHistory.appendFrontier(people[next].id);
  }

  Widget _discover() {
    final people = _browseFilter.apply(_model.discoverableProfiles);
    if (!_model.canBrowse) {
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _mainHeading('Browse'),
              _title(
                _model.capacity == 1
                    ? 'Your Journey has your focus.'
                    : 'Your Journey places are full.',
                size: 24,
              ),
              const SizedBox(height: 12),
              _body(
                _model.capacity == 1
                    ? 'You are out of search while your Journey place is reserved or active.'
                    : 'You are out of search while all ${_model.capacity} Journey places are reserved or active.',
              ),
              if (_focus != null) ...[
                const SizedBox(height: 24),
                _button(
                  'draft_focus_journey',
                  _model.capacity == 1
                      ? 'Continue your Journey'
                      : 'View your Journeys',
                  () => _currentJourneys.length == 1
                      ? _journey(_focus!.id)
                      : _tabTo(1),
                  primary: true,
                ),
              ],
            ],
          ),
        ),
      );
    }
    if (people.isEmpty || _browseExhausted) {
      return SelahOneJourneyBrowseDesigns(
        profiles: const [],
        selectedIndex: 0,
        design: _browseDesign,
        photoBuilder: _browsePhotoRenderer.build,
        alignHeaderActions: true,
        bottomPadding: 100,
        onFilters: _bound(() => _open('filters')),
        onBrowseMenu: (_) => _openBrowseOptions(null),
      );
    }
    final index = _browseSelectionIndex(people);
    final revision = _uiRevision;
    bool current(SeekerProfile profile) =>
        _allowed &&
        revision == _uiRevision &&
        !_shepherdRole &&
        _tab == 0 &&
        _page == null &&
        _model.canBrowse &&
        people.any((person) => person.id == profile.id);
    final displayed = _displayProfile(people[index]);
    // Record actual exposure after rendering, including filter selections.
    // This bookkeeping never triggers a rebuild or changes the selection.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (current(displayed)) _seenBrowseProfileIds.add(displayed.id);
    });
    if (_photos == null && !_photoLoadFailed) {
      return _browseLoadFrame(const SelahLoading.browse());
    }
    if (_photoLoadFailed) {
      return _browseLoadFrame(
        SelahLoadFailure(
          contentName: 'Profiles',
          onRetry: _bound(() {
            setState(() {
              _photoLoadFailed = false;
              _photos = null;
            });
            unawaited(_loadBrowsePhotos());
          }),
        ),
      );
    }
    return SelahOneJourneyBrowseDesigns(
      profiles: people.map(_displayProfile).toList(growable: false),
      waitingShepherdFirstName: _invitePending ? _invite!.firstName : null,
      selectedIndex: index,
      design: _browseDesign,
      photoBuilder: _browsePhotoRenderer.build,
      alignHeaderActions: true,
      nextProfileMotion: _browseNextMotion,
      nextProfileMotionEpoch: _browseNextMotionEpoch,
      hapticLevel: _accountSession.hapticLevel,
      bottomPadding: _browseOptionsOpen && _browseHideConfirmation
          ? (FloatingNavConfirmationBar.layoutHeight(
                      context,
                      viewportWidth: MediaQuery.sizeOf(context).width,
                      showOuterSurface: false,
                      contentEdgeInset: 20,
                    ) +
                    MediaQuery.paddingOf(context).bottom.clamp(
                      SelahNavBarMetrics.bottomInset,
                      double.infinity,
                    ) +
                    12)
                .clamp(100, double.infinity)
                .toDouble()
          : 100,
      showSave: false,
      onFilters: _bound(() {
        unawaited(_selectionHaptic());
        _open('filters');
      }),
      onBrowseMenu: (profile) {
        if (profile == null) {
          if (_allowed &&
              revision == _uiRevision &&
              !_shepherdRole &&
              _tab == 0 &&
              _page == null) {
            _openBrowseOptions(null);
          }
        } else if (current(profile)) {
          _openBrowseOptions(profile.id);
        }
      },
      onPrevious: _browseHistory.canBack
          ? _bound(() => _act(_previousBrowseProfile))
          : null,
      onNext: _bound(() => _act(_nextBrowseProfile)),
      canRequest: (profile) => _canToggleInvitation(profile.id),
      requestLabel: (profile) => _invitationLabel(profile.id),
      invitationSent: (profile) =>
          _model.stateFor(profile.id) == DraftJourneyState.sent,
      // Photo browsing stays inside the approved bounded card.
      onProfile: null,
      onRequest: (profile) {
        if (current(profile)) _toggleInvitation(profile.id);
      },
    );
  }

  Widget _browseLoadFrame(Widget state) => SafeArea(
    bottom: false,
    child: Padding(
      padding: const EdgeInsets.only(bottom: 81),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 8, 22, 0),
            child: Row(
              children: [
                const SelahWordmark(),
                const Spacer(),
                SelahBrowseOptionsButton(
                  profile: null,
                  alignToContentEdge: true,
                  onOpen: (_) => _openBrowseOptions(null),
                ),
              ],
            ),
          ),
          Expanded(child: state),
        ],
      ),
    ),
  );

  Widget _profileView() {
    final p = _person;
    if (p == null) return _unavailable();
    if (_model.isBlocked(p.id)) return _userNotFoundView();
    // Nested return is owned by the shared viewport scope, not this photo's
    // horizontal pager or a second competing vertical dismissal recognizer.
    return _photoSurface(p);
  }

  Widget _connections() {
    final journeys = _currentJourneys;
    final expanded = journeys
        .where((person) => person.id == _expandedJourneyOptionsId)
        .firstOrNull;
    return journeys.isEmpty
        ? SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                16,
                20,
                SelahNavBarMetrics.restingHeight +
                    SelahNavBarMetrics.bottomInset +
                    16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _mainHeading('Journey'),
                  Expanded(
                    child: LayoutBuilder(
                      key: const ValueKey('concept_journey_empty_viewport'),
                      builder: (context, constraints) => SingleChildScrollView(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight,
                          ),
                          child: const SelahEmptyState(
                            key: ValueKey('concept_journey_empty'),
                            icon: Icons.route_outlined,
                            title: 'Your Journeys will appear here',
                            message:
                                'When a request is accepted, you both choose to begin together. This is where your Journey continues.',
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
        : SelahOneJourneyConnectionsPresentation(
            title: 'Journey',
            labels: const ['Journey'],
            selectedIndex: 0,
            onChanged: (_) {},
            pageTopPadding: 12,
            fillSinglePage: journeys.length > 1,
            singlePageMaxHeight: journeys.length == 2 ? 532 : null,
            expandedCard: expanded == null
                ? null
                : KeyedSubtree(
                    key: ValueKey('concept_expanded_journey_${expanded.id}'),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final reading =
                            MediaQuery.textScalerOf(context).scale(1) > 1.3 ||
                            constraints.maxHeight < 420;
                        final card = _connectionCard(
                          expanded,
                          compact: true,
                          fillHeight: !reading,
                          expandedOptions: true,
                          inlineOptionsFillHeight: !reading,
                        );
                        return reading
                            ? SingleChildScrollView(
                                key: ValueKey(
                                  'concept_expanded_journey_reading_${expanded.id}',
                                ),
                                physics: const ClampingScrollPhysics(),
                                child: card,
                              )
                            : card;
                      },
                    ),
                  ),
            pages: [
              [
                for (var index = 0; index < journeys.length; index++) ...[
                  _connectionCard(
                    journeys[index],
                    compact: journeys.length > 1,
                    fillHeight: journeys.length > 1,
                  ),
                  if (index < journeys.length - 1) const SizedBox(height: 12),
                ],
              ],
            ],
          );
  }

  void _activity(String page, {int requestsTab = 0}) {
    if ((page != 'requests' && page != 'ended') ||
        requestsTab < 0 ||
        requestsTab > 2) {
      return;
    }
    _move(() {
      _tab = 2;
      _requestsTab = requestsTab;
      _expansion.collapseAll();
      _pages
        ..clear()
        ..add(page);
    });
  }

  Widget _activityPage(String title, List<Widget> content) =>
      SelahOneJourneyConnectionsPresentation(
        key: ValueKey('concept_activity_$_page'),
        title: title,
        labels: [title],
        pages: [content],
        selectedIndex: 0,
        onChanged: (_) {},
      );

  Widget _requestActivity() {
    final revision = _uiRevision;
    return SelahOneJourneyConnectionsPresentation(
      key: const ValueKey('concept_activity_requests'),
      title: 'Journey requests',
      labels: const ['Received', 'Sent', 'Introductions'],
      segmentKeys: const [
        ValueKey('draft_requests_0'),
        ValueKey('draft_requests_1'),
        ValueKey('draft_requests_2'),
      ],
      pages: [
        _requests(0),
        _requests(1),
        const [
          SizedBox(height: 80),
          SelahEmptyState(
            icon: Icons.groups_outlined,
            title: 'No introductions yet',
            message: 'People your Shepherds put forward will appear here.',
          ),
        ],
      ],
      selectedIndex: _requestsTab,
      onChanged: (i) {
        if (!_allowed ||
            revision != _uiRevision ||
            _shepherdRole ||
            _tab != 2 ||
            _page != 'requests' ||
            i < 0 ||
            i > 2 ||
            i == _requestsTab) {
          return;
        }
        _act(() {
          _requestsTab = i;
          _expansion.collapseAll();
        });
      },
    );
  }

  Widget _historyActivity(bool ended) => _activityPage(
    ended ? 'Ended Journeys' : 'Paused Journeys',
    _history(ended),
  );

  SelahOneJourneyConnectionsAction _connectionAction(
    String key,
    String label,
    IconData? icon,
    VoidCallback? action,
  ) => SelahOneJourneyConnectionsAction(
    key: ValueKey(key),
    label: label,
    icon: icon,
    onTap: action == null ? null : _bound(action),
  );

  Widget _personRow(
    DraftProfile p,
    String detail,
    String id,
    VoidCallback action,
  ) => SelahOneJourneyConnectionsPersonCard(
    profile: _displayProfile(p),
    subtitle: detail,
    cardId: id,
    controller: _expansion,
    headerKey: ValueKey('${id}_header'),
    onReport: _bound(() => _open('safety', person: p.id)),
    actions: SelahOneJourneyConnectionsActionDeck(
      primary: _connectionAction(
        id,
        'View Journey',
        Icons.route_outlined,
        action,
      ),
    ),
  );

  List<Widget> _requests(int tab) {
    VoidCallback visibleAction(VoidCallback action) => _bound(() {
      if (!_shepherdRole &&
          _tab == 2 &&
          _page == 'requests' &&
          _requestsTab == tab) {
        action();
      }
    });
    final expected = tab == 0
        ? DraftJourneyState.received
        : DraftJourneyState.sent;
    final people = _visibleRequests(expected);
    if (people.isEmpty) {
      return [
        _body(
          tab == 0 ? 'No received requests yet.' : 'No sent requests yet.',
          small: true,
        ),
      ];
    }
    return [
      for (final p in people) ...[
        SelahOneJourneyConnectionsPersonCard(
          profile: _displayProfile(p),
          subtitle: tab == 0 ? 'Journey request' : 'Waiting for a response',
          cardId: 'request_${p.id}',
          controller: _expansion,
          headerKey: ValueKey('concept_request_${p.id}_header'),
          onReport: visibleAction(() => _open('safety', person: p.id)),
          actions: SelahOneJourneyConnectionsActionDeck(
            primary: _connectionAction(
              'concept_request_profile_${p.id}',
              'View profile',
              Icons.visibility_outlined,
              visibleAction(() => _open('profile', person: p.id)),
            ),
            actions: tab == 0
                ? [
                    _connectionAction(
                      'draft_accept_${p.id}',
                      'Accept request',
                      Icons.check,
                      (_invitePending || _model.canAttemptAccept(p.id))
                          ? visibleAction(() => _accept(p, true))
                          : null,
                    ),
                    _connectionAction(
                      'draft_decline_${p.id}',
                      'Decline',
                      Icons.close,
                      visibleAction(
                        () => _act(
                          () => _result(
                            _model.declineReceived(p.id),
                            'Request declined.',
                          ),
                        ),
                      ),
                    ),
                  ]
                : [
                    _connectionAction(
                      'draft_cancel_${p.id}',
                      'Cancel request',
                      Icons.close,
                      visibleAction(
                        () => _act(
                          () => _result(
                            _model.cancel(p.id),
                            'Request cancelled.',
                          ),
                        ),
                      ),
                    ),
                  ],
          ),
        ),
        const SizedBox(height: 14),
      ],
    ];
  }

  Future<void> _accept(
    DraftProfile p,
    bool incoming, {
    bool fromPageOptions = false,
  }) async {
    final expected = incoming
        ? DraftJourneyState.received
        : DraftJourneyState.sent;
    if (!_allowed ||
        _shepherdRole ||
        _tab != 2 ||
        (fromPageOptions
            ? incoming ||
                  _page != 'controls' ||
                  _pageOptionsSource != 'requests' ||
                  !SelahDeveloperAccess.canUseDeveloperTools
            : _page != 'requests') ||
        _requestsTab != (incoming ? 0 : 1) ||
        _model.stateFor(p.id) != expected) {
      return;
    }
    if (incoming && _actionShepherdName == null) {
      _act(() => _notice = SelahActionPause.noShepherdMessage);
      return;
    }
    if (_invitePending) {
      if (incoming) {
        _act(
          () => _notice =
              'You can accept once ${_invite!.firstName} accepts your invite.',
        );
      }
      return;
    }
    if (!_model.canAttemptAccept(p.id)) return;
    if (!_model.hasCapacity) {
      _move(() {
        _personId = p.id;
        if (fromPageOptions) _pages.removeLast();
        _capacityRequest = (id: p.id, incoming: incoming);
        _capacityEndingId = null;
        _pages.add('request_capacity');
      });
      return;
    }
    bool accepted;
    if (incoming) {
      final fresh = _actionPauseFreshGuard();
      accepted = await _presentActionPause(
        pause: SelahActionPause(
          kind: SelahActionPauseKind.accept,
          name: _actionPersonName(p),
          shepherdName: _actionShepherdName,
          otherGender: _displayProfile(p).gender,
        ),
        current: () => fresh() && !_invitePending && _model.canAccept(p.id),
        commit: () => _model.acceptReceived(p.id),
      );
    } else {
      // The existing private control represents the other member's action.
      accepted = _model.simulateRecipientAccept(p.id);
    }
    if (!accepted || !_allowed) return;
    _act(() {
      _result(true, 'Accepted. Both places are reserved while you prepare.');
      if (fromPageOptions) _pages.removeLast();
      _personId = p.id;
      _pages.add('journey');
    });
  }

  bool _currentCapacityRequest(
    ({String id, bool incoming}) request,
    int revision, {
    bool ownedPause = false,
  }) =>
      (ownedPause ? _canActOnOwnedPause : _allowed) &&
      !_shepherdRole &&
      _tab == 2 &&
      _page == 'request_capacity' &&
      _personId == request.id &&
      _capacityRequest == request &&
      _uiRevision == revision &&
      !_model.isBlocked(request.id) &&
      _model.stateFor(request.id) ==
          (request.incoming
              ? DraftJourneyState.received
              : DraftJourneyState.sent);

  Widget _requestCapacityView() {
    final request = _capacityRequest;
    final person = _person;
    if (request == null || person == null || request.id != person.id) {
      return _unavailable();
    }
    final revision = _uiRevision;
    bool current() => _currentCapacityRequest(request, revision);
    final choices = _currentJourneys;
    final ending = choices
        .where((candidate) => candidate.id == _capacityEndingId)
        .firstOrNull;
    final choice = SelahRequestCapacityChoice(
      key: ValueKey('request_capacity_${request.id}'),
      firstName: person.firstName,
      capacity: _model.capacity,
      selectedId: ending?.id,
      items: [
        for (final choice in choices)
          SelahRequestCapacityItem(
            id: choice.id,
            name: _model.isBlocked(choice.id)
                ? 'User not found'
                : '${choice.firstName} ${choice.surname}'.trim(),
            subtitle: _model.isBlocked(choice.id)
                ? null
                : '${choice.age} · ${choice.city}',
            portrait: _model.isBlocked(choice.id)
                ? null
                : _browsePhotoRenderer.build(
                    context,
                    _displayProfile(choice).photoUrl,
                    width: 52,
                    height: 52,
                    alignment: Alignment.center,
                  ),
          ),
      ],
      onSelected: (id) {
        if (!current() ||
            _capacityConfirmOpen ||
            !choices.any((choice) => choice.id == id)) {
          return;
        }
        unawaited(_selectionHaptic());
        _act(() => _capacityEndingId = id);
      },
      onContinue:
          ending == null ||
              _capacityConfirmOpen ||
              !_model.canReplaceJourneyForRequest(
                request.id,
                ending.id,
                incoming: request.incoming,
              )
          ? null
          : () {
              if (current()) _confirmCapacityReplacement(request, ending);
            },
      onCancel: () {
        if (!current() || _capacityConfirmOpen) return;
        unawaited(_selectionHaptic());
        _act(() {
          final cancelled = request.incoming
              ? _model.declineReceived(request.id)
              : _model.cancel(request.id);
          if (cancelled) {
            _pages.removeLast();
            _capacityRequest = null;
            _capacityEndingId = null;
          }
        });
      },
    );
    return SafeArea(
      child: Padding(padding: const EdgeInsets.all(20), child: choice),
    );
  }

  Future<void> _confirmCapacityReplacement(
    ({String id, bool incoming}) request,
    DraftProfile ending,
  ) async {
    final revision = _uiRevision;
    final endingState = _model.stateFor(ending.id);
    bool current() =>
        _currentCapacityRequest(request, revision, ownedPause: true) &&
        _capacityEndingId == ending.id &&
        _model.stateFor(ending.id) == endingState &&
        _model.canReplaceJourneyForRequest(
          request.id,
          ending.id,
          incoming: request.incoming,
        );
    if (_capacityConfirmOpen || !current()) return;
    final target = _person!;
    _capacityConfirmOpen = true;
    unawaited(_selectionHaptic());
    try {
      final committed = await _presentActionPause(
        pause: SelahActionPause(
          kind: SelahActionPauseKind.replace,
          name: _actionPersonName(target),
          endingName: _actionPersonName(ending),
          shepherdName: _actionShepherdName,
        ),
        current: current,
        commit: () => _model.replaceJourneyForRequest(
          request.id,
          ending.id,
          incoming: request.incoming,
        ),
      );
      if (!committed) return;
      _act(() {
        _pages
          ..clear()
          ..add('journey');
        _tab = 1;
        _personId = request.id;
        _capacityRequest = null;
        _capacityEndingId = null;
        _replacementUpdates.add((
          ending: _actionPersonName(ending),
          accepted: _actionPersonName(target),
        ));
        _notice = 'Journey with ${target.firstName} has begun.';
      });
    } finally {
      _capacityConfirmOpen = false;
      if (_allowed) setState(() {});
    }
  }

  Widget _connectionCard(
    DraftProfile p, {
    bool compact = false,
    bool fillHeight = false,
    bool expandedOptions = false,
    bool inlineOptionsFillHeight = true,
  }) {
    final state = _model.stateFor(p.id)!;
    if (_model.isBlocked(p.id)) {
      return _card([
        Text(
          'User not found',
          key: ValueKey('concept_blocked_journey_${p.id}'),
          style: SelahText.heading(size: 18),
        ),
        _body(
          'This Journey place is retained. The profile and conversation are unavailable.',
          small: true,
        ),
        _button(
          'draft_end_${p.id}',
          'End Journey',
          () => _showJourneyAction(p, 'end'),
        ),
      ]);
    }
    final primary = _connectionAction(
      'draft_journey_${p.id}',
      _journeyPrimaryLabel(p.id),
      null,
      () => _journey(p.id),
    );
    final stageLabel = _model.stageFor(p.id)?.label ?? _stateLabel(state);
    final actions = SelahOneJourneyConnectionsActionDeck(
      primary: primary,
      primaryTrailing: SelahConceptJourneyOptionsButton(
        key: ValueKey('draft_journey_options_${p.id}'),
        isExpandable: true,
        expanded: expandedOptions,
        onTap: _bound(() => _toggleJourneyCardOptions(p)),
      ),
    );
    if (state == DraftJourneyState.active ||
        state == DraftJourneyState.pauseRequested ||
        state == DraftJourneyState.preparing) {
      return SelahOneJourneyConnectionsActiveCard(
        profile: _displayProfile(p),
        stateLabel: _stateLabel(state),
        actions: actions,
        compact: compact,
        fillHeight: fillHeight,
        cardDesign: SelahOneJourneyCardDesign.quietMinimal,
        stageLabel: stageLabel,
        primaryAction: actions.primaryRow,
        inlineOptions: expandedOptions ? _inlineJourneyOptions(p) : null,
        inlineOptionsFillHeight: inlineOptionsFillHeight,
      );
    }
    return _personRow(
      p,
      _stateLabel(state),
      'draft_journey_${p.id}',
      () => _journey(p.id),
    );
  }

  String _journeyPrimaryLabel(String id) {
    final state = _model.stateFor(id);
    final notBegun =
        state == DraftJourneyState.preparing ||
        (state == DraftJourneyState.active &&
            _model.stageFor(id)?.value == 'greeting_exchange' &&
            !_model.hasSentGreeting(id) &&
            !_model.peerHasSentGreeting(id));
    return notBegun ? 'Start Journey' : 'Continue Journey';
  }

  bool _canExpandJourneyCard(String id) =>
      _allowed &&
      !_shepherdRole &&
      !_journeyOptionsOpen &&
      _tab == 1 &&
      _page == null &&
      !_model.isBlocked(id) &&
      _currentJourneys.any((person) => person.id == id);

  void _toggleJourneyCardOptions(DraftProfile person) {
    if (!_canExpandJourneyCard(person.id)) return;
    unawaited(_selectionHaptic());
    _act(() {
      _expandedJourneyOptionsId = _expandedJourneyOptionsId == person.id
          ? null
          : person.id;
    });
  }

  Widget _inlineJourneyOptions(DraftProfile person) {
    final revision = _uiRevision;
    final state = _model.stateFor(person.id);
    bool current() =>
        revision == _uiRevision &&
        _expandedJourneyOptionsId == person.id &&
        _canExpandJourneyCard(person.id) &&
        _model.stateFor(person.id) == state;
    return SelahConceptJourneyOptions(
      id: person.id,
      firstName: person.firstName,
      inline: true,
      canPause: false,
      canEnd: state != null && state != DraftJourneyState.ended,
      onSelected: (choice) {
        if (!current()) return;
        unawaited(_selectionHaptic());
        _selectJourneyOption(person, choice);
      },
      onCancel: () {
        if (current()) _act(() => _expandedJourneyOptionsId = null);
      },
    );
  }

  void _selectJourneyOption(
    DraftProfile person,
    SelahConceptJourneyOption choice,
  ) {
    switch (choice) {
      case SelahConceptJourneyOption.profile:
        _open('profile', person: person.id);
      case SelahConceptJourneyOption.timeline:
        _open('timeline', person: person.id);
      case SelahConceptJourneyOption.bio:
        _open('bio', person: person.id);
      case SelahConceptJourneyOption.compatibility:
        _open('journey_compatibility', person: person.id);
      case SelahConceptJourneyOption.shepherds:
        _open('journey_shepherds', person: person.id);
      case SelahConceptJourneyOption.report:
        _open('safety', person: person.id);
      case SelahConceptJourneyOption.pause:
        // Retired: neither an inline nor retained modal callback restores it.
        return;
      case SelahConceptJourneyOption.end:
        _showJourneyAction(person, 'end');
    }
  }

  Future<void> _openJourneyOptions(DraftProfile person) async {
    if (!_allowed || _shepherdRole || _journeyOptionsOpen) return;
    final state = _model.stateFor(person.id);
    if (state == null) return;
    final fresh = _accountFreshGuard();
    _journeyOptionsOpen = true;
    try {
      final choice = await showModalBottomSheet<SelahConceptJourneyOption>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        barrierColor: Colors.black38,
        builder: (sheetContext) => ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * .85,
          ),
          child: SelahConceptJourneyOptions(
            id: person.id,
            firstName: person.firstName,
            canPause: false,
            canEnd: state != DraftJourneyState.ended,
            onSelected: (value) {
              if (!sheetContext.mounted ||
                  ModalRoute.of(sheetContext)?.isCurrent != true) {
                return;
              }
              // The owned modal temporarily makes the parent route non-current.
              // This only returns an intent; recheck owner/revision/state below,
              // after dismissal restores the parent route. Never mutate here.
              Navigator.pop(sheetContext, value);
            },
            onCancel: () {
              if (!sheetContext.mounted ||
                  ModalRoute.of(sheetContext)?.isCurrent != true) {
                return;
              }
              Navigator.pop(sheetContext);
            },
          ),
        ),
      );
      if (!fresh() || choice == null || _model.stateFor(person.id) != state) {
        return;
      }
      _selectJourneyOption(person, choice);
    } finally {
      _journeyOptionsOpen = false;
    }
  }

  Future<void> _showJourneyAction(DraftProfile person, String action) async {
    if (action != 'end') return;
    final fresh = _actionPauseFreshGuard();
    final state = _model.stateFor(person.id);
    bool current() =>
        fresh() &&
        _model.stateFor(person.id) == state &&
        state != null &&
        state != DraftJourneyState.received &&
        state != DraftJourneyState.sent &&
        state != DraftJourneyState.ended;
    final committed = await _presentActionPause(
      pause: SelahActionPause(
        kind: SelahActionPauseKind.end,
        name: _actionPersonName(person),
        shepherdName: _actionShepherdName,
      ),
      current: current,
      commit: () => _model.end(person.id),
    );
    if (!committed) return;
    _act(() {
      _message.clear();
      _notice = 'Journey ended. Your history stays.';
    });
  }

  Widget _journeyCompatibility() {
    final person = _person;
    if (person == null || _model.stateFor(person.id) == null) {
      return _unavailable();
    }
    final revealed = _model.compatibilityRevealed(person.id);
    return Column(
      key: ValueKey('draft_journey_compatibility_${person.id}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _heading('Compatibility with ${person.firstName}', ''),
        _card([
          _eyebrow('COMPATIBILITY SCORE'),
          _title(
            revealed ? 'Your shared result' : 'Your result stays private.',
            size: 25,
          ),
          _body(
            revealed
                ? 'You both chose to reveal. There is not enough between you yet to work out a figure.'
                : 'Your score opens only when you both choose to reveal at the Compatibility step of your Journey.',
          ),

          _button(
            'concept_compatibility_continue_${person.id}',
            _journeyPrimaryLabel(person.id),
            () => _journey(person.id),
            primary: true,
          ),
        ]),
      ],
    );
  }

  Widget _journeyShepherds() {
    final person = _person;
    if (person == null || _model.stateFor(person.id) == null) {
      return _unavailable();
    }
    return SafeArea(
      key: ValueKey('draft_journey_shepherds_${person.id}'),
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Text(
              'Journey with ${person.firstName}',
              style: SelahText.subtext(size: 13),
            ),
          ),
          Expanded(child: _shepherds(journeyContextId: person.id)),
        ],
      ),
    );
  }

  List<Widget> _history(bool ended) {
    final people = draftProfiles.where((p) {
      final s = _model.stateFor(p.id);
      return ended
          ? s == DraftJourneyState.ended
          : s == DraftJourneyState.paused ||
                s == DraftJourneyState.resumeRequested;
    }).toList();
    return people.isEmpty
        ? [_body(ended ? 'No ended Journeys.' : 'No paused Journeys.')]
        : [
            for (final p in people) ...[
              if (_model.isBlocked(p.id))
                _card([
                  Text(
                    'User not found',
                    key: ValueKey('concept_blocked_archive_${p.id}'),
                    style: SelahText.heading(size: 18),
                  ),
                  _body(
                    'This ended Journey remains archived. Its profile and messages are unavailable.',
                    small: true,
                  ),
                  _button(
                    'draft_journey_${p.id}',
                    'View archive',
                    () => _journey(p.id),
                  ),
                ])
              else if (ended)
                SelahOneJourneyConnectionsPersonCard(
                  profile: _displayProfile(p),
                  subtitle: 'Ended Journey · read-only archive',
                  cardId: 'draft_journey_${p.id}',
                  controller: _expansion,
                  headerKey: ValueKey('draft_journey_${p.id}_header'),
                  actions: SelahOneJourneyConnectionsActionDeck(
                    primary: _connectionAction(
                      'draft_journey_${p.id}',
                      'View archive',
                      null,
                      () => _journey(p.id),
                    ),
                  ),
                )
              else
                _connectionCard(p),
              const SizedBox(height: 10),
            ],
          ];
  }

  bool _canViewJourneyMarriage(String id) =>
      _allowed &&
      !_shepherdRole &&
      !_model.isBlocked(id) &&
      const {
        DraftJourneyState.active,
        DraftJourneyState.pauseRequested,
        DraftJourneyState.paused,
        DraftJourneyState.resumeRequested,
      }.contains(_model.stateFor(id));

  Widget _journeyMarriageProfile() {
    final person = _person;
    if (person == null ||
        _page != 'journey_marriage_profile' ||
        !_pages.contains('journey') ||
        !_canViewJourneyMarriage(person.id)) {
      return _unavailable();
    }
    return SelahJourneyMarriageProfile(
      profile: _displayProfile(person),
      onBack: _bound(_back),
    );
  }

  Widget _journeyView() {
    final p = _person;
    if (p == null || _model.stateFor(p.id) == null) return _unavailable();
    if (_model.isBlocked(p.id)) return _userNotFoundView();
    if (_model.stateFor(p.id) == DraftJourneyState.ended) {
      return _archiveView(p);
    }
    final stage = _model.stageFor(p.id);
    final state = _model.stateFor(p.id);
    final profileFresh = _accountFreshGuard();
    void openMarriageProfile() {
      if (profileFresh() &&
          _page == 'journey' &&
          _personId == p.id &&
          _canViewJourneyMarriage(p.id)) {
        _open('journey_marriage_profile');
      }
    }

    final actions = SingleChildScrollView(
      key: const ValueKey('draft_scroll'),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 80),
      child: _journeyLocalActions(),
    );
    if (stage == null ||
        (state != DraftJourneyState.active &&
            state != DraftJourneyState.pauseRequested)) {
      return SafeArea(
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    key: const ValueKey('concept_journey_profile_name'),
                    onTap: _canViewJourneyMarriage(p.id)
                        ? openMarriageProfile
                        : null,
                    child: Text(
                      'Journey with ${p.firstName}',
                      textAlign: TextAlign.center,
                      style: SelahText.heading(size: 16),
                    ),
                  ),
                ),
                IconButton(
                  key: const ValueKey('concept_journey_timeline'),
                  tooltip: 'Timeline',
                  onPressed: _bound(() => _open('timeline')),
                  icon: const Icon(Icons.history),
                ),
                IconButton(
                  tooltip: 'Journey options',
                  onPressed: _bound(() => _openJourneyOptions(p)),
                  icon: const Icon(Icons.more_horiz),
                ),
              ],
            ),
            Expanded(child: actions),
          ],
        ),
      );
    }
    return SelahConceptJourneyPresentation(
      key: ValueKey('concept_journey_${p.id}'),
      firstName: p.firstName,
      stage: stage,
      localActionBody: actions,
      onBack: _bound(_back),
      showBackButton: false,
      onTimeline: _bound(() => _open('timeline')),
      onBio: _bound(() => _open('bio')),
      onProfile: _canViewJourneyMarriage(p.id) ? openMarriageProfile : null,
      options: IconButton(
        key: const ValueKey('concept_journey_menu'),
        tooltip: 'Journey options',
        onPressed: _bound(() => _openJourneyOptions(p)),
        icon: Icon(Icons.more_horiz, color: SelahColors.foregroundMuted),
      ),
    );
  }

  Widget _archiveView(DraftProfile person) => SafeArea(
    key: ValueKey('concept_archive_${person.id}'),
    child: Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Journey with ${person.firstName}',
                textAlign: TextAlign.center,
                style: SelahText.heading(size: 16),
              ),
            ),
          ],
        ),
        Expanded(
          child: SingleChildScrollView(
            key: const ValueKey('draft_scroll'),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _title('A chapter kept, not reopened.', size: 25),
                _body(
                  'This ended Journey is read-only. No messages or new request can reopen this attempt.',
                ),
                const SizedBox(height: 16),
                _timeline(person.id),
                const SizedBox(height: 16),
                _title('Messages', size: 18),

                for (final message in _messages[person.id] ?? <String>[])
                  _body('You · $message'),
                if ((_messages[person.id] ?? <String>[]).isEmpty)
                  _body('No messages in this archive.', small: true),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  Widget _userNotFoundView() => SafeArea(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Expanded(
          child: SelahEmptyState(
            key: ValueKey('concept_user_not_found'),
            icon: Icons.person_off_outlined,
            title: 'User not found',
            message: 'This profile and conversation are unavailable.',
          ),
        ),
      ],
    ),
  );

  Widget _journeyLocalActions() {
    final p = _person;
    if (p == null || _model.stateFor(p.id) == null) return _unavailable();
    final id = p.id;
    final state = _model.stateFor(id)!;
    final stage = _model.stageFor(id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state == DraftJourneyState.preparing)
          _card([
            _title('Choose to begin, together.', size: 26),
            _body(
              'You both accepted the invitation. Each person still chooses '
              'to begin. Until then, no conversation or private compatibility result opens.',
            ),
            _body(
              'You: ${_model.isReady(id) ? 'ready' : 'not yet confirmed'}',
              gold: true,
            ),
            _body(
              '${p.firstName}: ${_model.peerIsReady(id) ? 'ready' : 'waiting'}',
            ),
            _button(
              'draft_ready_$id',
              _model.isReady(id) ? 'You are ready' : 'I’m ready to begin',
              _model.isReady(id)
                  ? null
                  : () => _act(() => _model.markReady(id)),
              primary: true,
            ),
            _button(
              'draft_begin_$id',
              'Begin your Journey',
              _model.isReady(id) && _model.peerIsReady(id)
                  ? () => _act(
                      () => _result(
                        _model.beginPreparedJourney(id),
                        'Journey begun. Start by saying hello.',
                      ),
                    )
                  : null,
              primary: true,
            ),
          ])
        else if (state == DraftJourneyState.ended)
          _card([
            _title('A chapter kept, not reopened.', size: 25),
            _body(
              'This attempt has ended. Its Timeline remains read-only. '
              'No messages or new request can reopen this attempt.',
            ),
          ])
        else if (state == DraftJourneyState.paused ||
            state == DraftJourneyState.resumeRequested)
          _card([
            _title('Space to reflect.', size: 26),
            _body(
              'Your history stays here. Both people must agree and have a free '
              'place before resuming. Chat and stage progression are paused.',
            ),
            if (state == DraftJourneyState.paused)
              _button(
                'draft_resume_$id',
                'Request Resume',
                _model.canResume(id)
                    ? () => _act(
                        () => _result(
                          _model.requestResume(id),
                          'Resume requested.',
                        ),
                      )
                    : null,
              )
            else ...[
              _button(
                'draft_keep_paused_$id',
                'Keep Paused',
                () => _act(
                  () =>
                      _result(_model.keepPaused(id), 'Journey remains Paused.'),
                ),
              ),
            ],
          ])
        else if (stage != null) ...[
          _stageContent(p, stage),
        ],
        const SizedBox(height: 24),
        if (state == DraftJourneyState.pauseRequested)
          _card([
            _title('Pause requested.', size: 23),
            _body(
              'Your place remains occupied until the shared decision settles.',
            ),
          ]),
        if (state != DraftJourneyState.ended &&
            state != DraftJourneyState.sent &&
            state != DraftJourneyState.received) ...[
          const SizedBox(height: 10),
          _button(
            'draft_end_$id',
            'End Journey',
            () => _showJourneyAction(p, 'end'),
          ),
        ],
        if (state == DraftJourneyState.active &&
            stage?.value == 'conversation') ...[
          const SizedBox(height: 24),
          SelahMarriagePrepCard(
            completedSteps: _model.marriagePrepCompletedFor(id),
            saveFailed: _marriagePrepFailed.contains(id),
            onToggle: (step) {
              if (!_allowed ||
                  _shepherdRole ||
                  _page != 'journey' ||
                  _personId != id) {
                return;
              }
              _act(() {
                if (!_model.toggleMarriagePrepStep(id, step)) return;
                _marriagePrepFailed.remove(id);
                _notice = _model.marriagePrepCompletedFor(id).contains(step)
                    ? 'Marked done.'
                    : 'Unmarked.';
              });
            },
            onRetry: _bound(() {
              if (!_model.conversationOpen(id)) return;
              _act(() => _marriagePrepFailed.remove(id));
            }),
          ),
        ],
      ],
    );
  }

  Widget _stageContent(DraftProfile p, SelahJourneyStage stage) {
    final id = p.id;
    final active = _model.canParticipateInJourney(id);
    final mine = _model.hasSentGreeting(id);
    final theirs = _model.peerHasSentGreeting(id);
    final revealMine = _model.hasChosenCompatibilityReveal(id);
    final revealTheirs = _model.peerHasChosenCompatibilityReveal(id);
    late final Widget ordinary;
    if (!active && _model.stateFor(id) == DraftJourneyState.active) {
      final waitingOnOther = _model.ownMainShepherdPresent;
      ordinary = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 42),
        child: Column(
          children: [
            const Icon(
              Icons.shield_outlined,
              size: 34,
              color: SelahColors.journeyGold,
            ),
            const SizedBox(height: 18),
            Text(
              waitingOnOther
                  ? 'This Journey is waiting'
                  : 'Choose a Main Shepherd',
              style: SelahText.heading(size: 24),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              waitingOnOther
                  ? '${p.firstName} needs to choose a Main Shepherd before this Journey can continue.'
                  : 'Choose the trusted supporter who will walk with you in this Journey.',
              style: SelahText.subtext(size: 13),
              textAlign: TextAlign.center,
            ),
            if (!waitingOnOther) ...[
              const SizedBox(height: 24),
              _button(
                'concept_missing_main',
                'Go to Shepherd',
                () => _tabTo(3),
              ),
            ],
          ],
        ),
      );
    } else if (stage.value == 'greeting_exchange') {
      ordinary = SelahConceptJourneyThresholdBody(
        firstName: p.firstName,
        mine: mine,
        theirs: theirs,
        greeting: true,
        selfPhoto: _accountData.photoAsset,
        otherPhoto: _displayProfile(p).photoUrl,
        headline: mine && theirs
            ? stage.completionHeading
            : theirs
            ? '${p.firstName} said hello'
            : mine
            ? 'Greeting sent'
            : 'Hello',
        body: mine && theirs
            ? stage.completionLine
            : theirs
            ? 'A simple hello is a thoughtful place to start.'
            : mine
            ? "We'll let you know when ${p.firstName} returns it."
            : 'Say hello to ${p.firstName} to begin.',
        actionKey: ValueKey('draft_greeting_$id'),
        actionLabel: mine
            ? null
            : theirs
            ? 'Say hello back'
            : 'Say hello',
        onAction: active && !mine
            ? _bound(() => _act(() => _model.sendGreeting(id)))
            : null,
      );
    } else if (stage.value == 'compatibility_reveal') {
      ordinary = _model.compatibilityRevealed(id)
          ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 36),
              child: Column(
                children: [
                  Text(
                    stage.completionHeading,
                    style: SelahText.heading(size: 18),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'You both chose to reveal.',
                    style: SelahText.subtext(),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '—',
                    style: SelahText.heading(
                      size: 44,
                      color: SelahColors.ink(0.38),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'There is not enough between you yet to work out a figure. '
                    'It appears here once you have both covered more ground.',
                    style: SelahText.subtext(),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            )
          : SelahConceptJourneyThresholdBody(
              firstName: p.firstName,
              mine: revealMine,
              theirs: revealTheirs,
              selfPhoto: _accountData.photoAsset,
              otherPhoto: _displayProfile(p).photoUrl,
              headline: revealMine ? 'Reveal chosen' : stage.label,
              body: revealMine
                  ? 'Waiting for ${p.firstName}. You open the result together.'
                  : 'Neither of you sees the result until you both choose to reveal.',
              actionKey: ValueKey('draft_reveal_$id'),
              actionLabel: revealMine ? null : 'Reveal Compatibility',
              actionIcon: Icons.visibility_outlined,
              onAction: active && !revealMine
                  ? _bound(
                      () => _act(() => _model.chooseCompatibilityReveal(id)),
                    )
                  : null,
            );
    } else if (stage.value == 'mentor_gate') {
      ordinary = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 42),
        child: Column(
          children: [
            Text(
              stage.completionHeading,
              style: SelahText.heading(size: 20),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              stage.completionLine,
              style: SelahText.subtext(),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            _button(
              'concept_stage_shepherds',
              'Go to Shepherd',
              () => _tabTo(3),
            ),
          ],
        ),
      );
    } else if (stage.value.startsWith('phase_')) {
      ordinary = SelahConceptJourneyFirstQuestion(
        key: ValueKey('concept_phase_first_${stage.value}'),
        stage: stage,
      );
    } else if (stage.value == 'family_stage') {
      ordinary = Padding(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(stage.label, style: SelahText.heading(size: 18)),
            const SizedBox(height: 6),
            Text(
              'Your families meet your Journey here. '
              "${p.firstName}'s Shepherd asks you their questions; "
              'yours asks theirs. Answer as if they were sitting across from you — they are.',
              style: SelahText.subtext(),
            ),
            const SizedBox(height: 18),
            Text(
              "${p.firstName}'s family asks:",
              style: SelahText.body(size: 13, color: SelahColors.ink(0.70)),
            ),
            const SizedBox(height: 10),
            for (final q in JourneyQuestions.mentorToSeeker) ...[
              Text(q.text, style: SelahText.body(size: 14)),
              const SizedBox(height: 6),
              TextField(
                key: ValueKey('concept_family_display_${q.id}'),
                readOnly: true,
                maxLines: 3,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: SelahColors.foreground.withValues(alpha: 0.06),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  hintText: 'Your answer…',
                  hintStyle: TextStyle(color: SelahColors.ink(0.38)),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ],
        ),
      );
    } else {
      ordinary = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 20),
        child: Column(
          children: [
            Text(
              stage.completionHeading,
              style: SelahText.heading(size: 22),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              '${stage.completionLine} Your Timeline keeps going, and your Shepherds remain part of it.',
              style: SelahText.subtext(),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: _bound(() => _open('timeline')),
              child: Text(
                'Read your story so far',
                style: SelahText.subtext(size: 12),
              ),
            ),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ordinary,
        if (stage.value == 'conversation') ...[
          for (final message in _messages[id] ?? <String>[])
            _body('You · $message'),
        ] else ...[
          const SizedBox(height: 28),
          _button(
            'draft_stage_ready_$id',
            _model.hasChosenStageContinue(id)
                ? 'You chose to continue'
                : 'I’m ready for the next step',
            _model.canChooseStageContinue(id)
                ? () => _act(
                    () => _result(
                      _model.chooseStageContinue(id),
                      'Your choice is recorded.',
                    ),
                  )
                : null,
          ),
          _button(
            'draft_stage_next_$id',
            'Continue together',
            _model.canAdvanceStage(id)
                ? () => _act(
                    () => _result(_model.advanceStage(id), 'Next stage.'),
                  )
                : null,
            primary: true,
          ),
        ],
      ],
    );
  }

  Widget _timeline(String id) {
    final stage = _model.stageFor(id);
    return _card([
      _title('Your shared Timeline.', size: 25),
      _body(
        'A record of this attempt. It does not include private search behaviour.',
      ),
      _body('• Journey invitation accepted', gold: true),
      if (_model.stateFor(id) != DraftJourneyState.preparing)
        _body('• You both chose to begin'),
      if (stage != null)
        for (final previous in SelahJourneyStages.all.where(
          (s) => s.order < stage.order,
        ))
          _body('• ${previous.completionHeading}'),
      if (_model.stateFor(id) == DraftJourneyState.paused)
        _body('• Journey paused'),
      if (_model.stateFor(id) == DraftJourneyState.ended)
        _body('• Journey ended · read-only history'),
    ]);
  }

  MentorLinkedPerson? get _prayerMainShepherd =>
      _conceptShepherdPeople.where((person) => person.isMain).firstOrNull;

  bool get _prayerComposerScope =>
      _allowed &&
      !_shepherdRole &&
      (_page == 'prayer' ||
          (_page == 'controls' && _pageOptionsSource == 'prayer'));
  bool get _prayerShepherdScope =>
      _allowed &&
      _shepherdRole &&
      _tab == 0 &&
      (_page == null || (_page == 'controls' && _pageOptionsSource == null)) &&
      _conceptHassanLinked;

  SelahPrayerContext _prayerContext({required bool composer}) {
    final profile = _accountSession.ownProfile(_shepherdRole);
    final main = _prayerMainShepherd;
    final journey = _currentJourneys
        .where(
          (person) =>
              _model.stateFor(person.id) == DraftJourneyState.active &&
              !_model.isBlocked(person.id),
        )
        .firstOrNull;
    return SelahPrayerContext(
      lifetime: composer ? _prayerComposerLifetime : _prayerShellLifetime,
      role: _shepherdRole ? SelahPrayerRole.shepherd : SelahPrayerRole.seeker,
      actorId: _shepherdRole ? draftShepherds.first.id : profile.id,
      actorFirstName: profile.firstName,
      shepherdId: _shepherdRole ? draftShepherds.first.id : main?.id,
      shepherdName: _shepherdRole ? profile.firstName : main?.firstName,
      journeyName: _shepherdRole ? null : journey?.firstName,
      linkedShepherdIds: _shepherdRole
          ? const []
          : _conceptShepherdPeople.map((person) => person.id),
      // The four LOCK10 demo requests explicitly belong to James and Joel.
      // This fixture scope grants no roster, chat or server relationship.
      linkedSeekerIds: _shepherdRole && _conceptHassanLinked
          ? {'draft-self', _prayerJoelFixtureId}
          : const <String>{},
    );
  }

  SelahPrayerController _newPrayerController({required bool composer}) =>
      SelahPrayerController(
        canAct: () => composer ? _prayerComposerScope : _prayerShepherdScope,
        readContext: () => _prayerContext(composer: composer),
        readRequest: _prayerStore.requestById,
        onSend: (actor, text, journeyName) {
          if (!composer ||
              !_prayerComposerScope ||
              !actor.sameBinding(_prayerContext(composer: true)) ||
              actor.shepherdId == null ||
              actor.shepherdName == null) {
            return false;
          }
          final request = _prayerStore.send(
            seekerId: actor.actorId,
            seekerFirstName: actor.actorFirstName,
            recipientShepherdIds: {actor.shepherdId!},
            shepherdName: actor.shepherdName!,
            text: text,
            journeyName: journeyName,
          );
          if (request == null) return false;
          _act(() => _prayerEmptyView = false);
          return true;
        },
        onPray: (actor, requestId) {
          if (composer ||
              !_prayerShepherdScope ||
              !actor.sameBinding(_prayerContext(composer: false))) {
            return false;
          }
          final request = _prayerStore.requestById(requestId);
          if (request == null ||
              !actor.linkedSeekerIds.contains(request.seekerId)) {
            return false;
          }
          final prayed = _prayerStore.pray(
            requestId: requestId,
            shepherdId: actor.actorId,
            shepherdName: actor.actorFirstName,
          );
          if (prayed) {
            _act(
              () => _notice =
                  '${request.seekerFirstName} will see that you prayed.',
            );
          }
          return prayed;
        },
        onPresetEmpty: (actor) {
          if (composer ||
              !_prayerShepherdScope ||
              !actor.sameBinding(_prayerContext(composer: false))) {
            return false;
          }
          _act(() => _prayerEmptyView = true);
          return true;
        },
      );

  void _openPrayer() {
    if (!_allowed ||
        _shepherdRole ||
        _invitePending ||
        _page != null ||
        _tab != 3 ||
        _prayerMainShepherd == null) {
      return;
    }
    _prayerComposerController?.dispose();
    _prayerComposerLifetime = Object();
    _open('prayer');
    _prayerComposerController = _newPrayerController(composer: true);
  }

  Widget _prayerPage() {
    final controller = _prayerComposerController;
    if (!_prayerComposerScope || controller == null || !controller.current) {
      return const SizedBox.shrink();
    }
    return SelahPrayerComposer(
      controller: controller,
      onBack: _bound(_back),
      onSent: () {
        if (!_prayerComposerScope ||
            _page != 'prayer' ||
            !identical(controller, _prayerComposerController) ||
            !controller.current) {
          return;
        }
        final name = controller.context?.shepherdName;
        if (name == null) return;
        _move(() {
          _pages.removeLast();
          _notice = 'Sent. $name will pray for you.';
        });
      },
    );
  }

  void _prayForRequest(String requestId) {
    if (!_prayerShepherdScope || _prayerEmptyView) return;
    final controller = _newPrayerController(composer: false);
    controller.pray(requestId);
    controller.dispose();
  }

  Widget _prayerRequestsBlock() {
    final current = _accountFreshGuard();
    return SelahPrayerRequestsBlock(
      requests: _prayerEmptyView
          ? const []
          : _prayerStore.requestsFor(draftShepherds.first.id),
      shepherdId: draftShepherds.first.id,
      linkedSeekerNames: const ['James', 'Joel'],
      onPray: (id) {
        if (current()) _prayForRequest(id);
      },
    );
  }

  Widget _dashboard() {
    final focus = _focus;
    final receivedRequests = _visibleRequests(DraftJourneyState.received);
    final sentRequests = _visibleRequests(DraftJourneyState.sent);
    final focusBlocked = focus != null && _model.isBlocked(focus.id);
    final mainShepherd = _conceptShepherdPeople
        .where((person) => person.isMain)
        .firstOrNull;
    final mainFixture = draftShepherds
        .where((shepherd) => shepherd.id == mainShepherd?.id)
        .firstOrNull;
    final stage = focus == null ? null : _model.stageFor(focus.id);
    final preparing =
        focus != null &&
        _model.stateFor(focus.id) == DraftJourneyState.preparing;
    final signals = <DashboardSignal>[
      // Current Journey cards/stages belong in Journey. Mere presence is not
      // an obligation; only a sourced, addressed decision belongs in My SELAH.
      for (final p in receivedRequests)
        DashboardSignal(
          id: 'concept-request-${p.id}',
          kind: DashboardSignalKind.addressedDecision,
          title: 'Journey request from ${p.firstName}',
          actionLabel: 'View requests',
          target: SelahDashboardTarget.connectionsActivity,
        ),
    ];
    final resolution = const DashboardResolver().resolve(
      DashboardSnapshot(
        role: DashboardRole.seeker,
        onboarding: const DashboardSource.available([]),
        journeys: DashboardSource.available(
          DashboardJourneyState(
            summary: DashboardJourneySummary(
              id: focus?.id ?? 'concept-search',
              kind: focus == null
                  ? DashboardJourneyKind.searching
                  : DashboardJourneyKind.active,
              title: _currentJourneys.length > 1
                  ? '${_currentJourneys.length} Journeys in progress'
                  : focus == null
                  ? 'Ready for introductions'
                  : focusBlocked
                  ? 'User not found'
                  : 'You & ${focus.firstName}',
              detail: _currentJourneys.length > 1
                  ? '${_model.occupiedCount} of ${_model.capacity} places in use'
                  : focus == null
                  ? 'New introductions will appear when they are available.'
                  : focusBlocked
                  ? 'Your Journey place is retained.'
                  : preparing
                  ? 'Preparing together'
                  : '${stage?.label} · Stage ${stage?.order} of ${SelahJourneyStages.count}',
              progress:
                  stage == null || focusBlocked || _currentJourneys.length > 1
                  ? null
                  : stage.order / SelahJourneyStages.count,
            ),
            signals: signals,
          ),
        ),
        updates: const DashboardSource.available([]),
        shepherdInvitations: const DashboardSource.available([]),
        insights: const DashboardSource.available([]),
        stableState: DashboardStableState(
          orientationItems: const DashboardSource.available([]),
          family: DashboardSource.available(
            DashboardFamilyStatus(
              kind: DashboardFamilyKind.connected,
              title: mainFixture != null
                  ? '${mainFixture.firstName} ${mainFixture.surname} · Shepherd connected'
                  : 'Choose a Main Shepherd',
              detail: mainFixture != null
                  ? null
                  : 'Your Shepherds stay linked. Choose your main supporter to continue this Journey.',
              linkedCount: _conceptShepherdPeople.length,
              actionLabel: 'Manage Shepherds',
            ),
          ),
        ),
      ),
    );
    final revision = _uiRevision;
    return SelahQuietDashboard(
      titleAlignment: Alignment.centerLeft,
      resolution: resolution,
      fixtureMode: true,
      singlePage: true,
      fixtureCards: [
        for (final event in _prayerStore.updatesFor(
          _accountSession.ownProfile(false).id,
        ))
          SupportiveCard(
            id: 'prayer-${event.kind.name}-${event.requestId}-${event.shepherdId}',
            section: SupportiveSection.changed,
            title: event.text,
          ),
        for (var index = 0; index < _replacementUpdates.length; index++)
          SupportiveCard(
            id: 'local-journey-replaced-$index',
            section: SupportiveSection.changed,
            title:
                'You ended your Journey with '
                '${_replacementUpdates[index].ending} and accepted '
                '${_replacementUpdates[index].accepted}. Both Shepherds were told.',
          ),
        if (_invite?.accepted ?? false)
          SupportiveCard(
            id: 'local-shepherd-accepted',
            section: SupportiveSection.changed,
            title:
                '${_invite!.fullName} accepted. Your Shepherd walks with you now.',
          ),
        SupportiveCard(
          id: 'concept-my-requests',
          section: SupportiveSection.stand,
          title: 'Journey requests',
          detail:
              '${receivedRequests.length} received · ${sentRequests.length} sent',
          actionLabel: 'View requests',
          target: SelahDashboardTarget.connectionsActivity,
        ),
        SupportiveCard(
          id: 'concept-my-introductions',
          section: SupportiveSection.stand,
          title: 'Introductions',
          detail: 'People put forward by your Shepherds.',
          actionLabel: 'View introductions',
          target: SelahDashboardTarget.connectionsActivity,
        ),
        SupportiveCard(
          id: 'concept-my-ended',
          section: SupportiveSection.stand,
          title: 'Ended Journeys',
          detail:
              '${_model.states.values.where((state) => state == DraftJourneyState.ended).length} ended',
          actionLabel: 'View Ended',
          target: SelahDashboardTarget.connectionsActivity,
        ),
      ],
      firstName: 'James',
      comparisonClock: DateTime.utc(2026, 10, 9),
      decoration: const BoxDecoration(),
      onRefresh: () async {},
      onNavigate: (card) {
        if (!_allowed ||
            revision != _uiRevision ||
            _shepherdRole ||
            _tab != 2 ||
            _page != null) {
          return;
        }
        switch (card.target) {
          case SelahDashboardTarget.discovery:
            _tabTo(0);
          case SelahDashboardTarget.connectionsJourneys:
            final addressed = _currentJourneys
                .where(
                  (journey) =>
                      card.id == 'concept-current-journey-${journey.id}',
                )
                .firstOrNull;
            if (addressed != null) {
              _journey(addressed.id);
            } else if (focus != null && _currentJourneys.length == 1) {
              _journey(focus.id);
            } else {
              _tabTo(1);
            }
          case SelahDashboardTarget.connectionsActivity:
            if (card.id == 'concept-my-ended') {
              _activity('ended');
            } else if (card.id == 'concept-my-introductions') {
              _activity('requests', requestsTab: 2);
            } else if (card.id == 'concept-my-requests' ||
                receivedRequests.any(
                  (person) => card.id == 'concept-request-${person.id}',
                )) {
              _activity('requests');
            }
          case SelahDashboardTarget.shepherd:
            _tabTo(3);
          case SelahDashboardTarget.profile:
            _tabTo(4);
          case SelahDashboardTarget.notifications:
            _open('notifications');
          default:
            return;
        }
      },
    );
  }

  // Relationship and permission changes below are disposable local fixtures.
  // They never establish an account role, link, consent or Journey authority.
  String _conceptMainShepherdId = 'draft-shepherd-hassan';
  final _conceptRemovedShepherds = <String>{};
  final _conceptShepherdHistory = <String, bool>{};
  final _conceptNetworkSent = <String>{};

  bool get _conceptHassanLinked =>
      !_conceptRemovedShepherds.contains('draft-shepherd-hassan');

  List<MentorLinkedPerson> get _conceptShepherdPeople => [
    for (final shepherd in draftShepherds)
      if (!_conceptRemovedShepherds.contains(shepherd.id))
        if ((_invite?.accepted ?? false) &&
            shepherd.id == _conceptMainShepherdId)
          _InvitedShepherdPerson(
            id: shepherd.id,
            fullName: _invite!.fullName,
            relation: _invite!.relation?.label,
            isMain: _model.ownMainShepherdPresent,
          )
        else
          MentorLinkedPerson(
            id: shepherd.id,
            firstName: shepherd.firstName,
            relationship: shepherd.relationshipCode,
            linkedAt: shepherd.linkedAt,
            isMain:
                _model.ownMainShepherdPresent &&
                shepherd.id == _conceptMainShepherdId,
          ),
  ];

  SeekerProfile get _conceptLinkedSeekerProfile =>
      _accountSession.ownProfile(false);

  MentorLinkedPerson get _conceptLinkedSeeker => MentorLinkedPerson(
    id: 'draft-self',
    firstName: 'James',
    relationship: draftShepherds.first.relationshipCode,
    linkedAt: draftShepherds.first.linkedAt,
    isMain:
        _model.ownMainShepherdPresent &&
        _conceptMainShepherdId == 'draft-shepherd-hassan' &&
        !_conceptRemovedShepherds.contains('draft-shepherd-hassan'),
  );

  MentorJourneyView? get _conceptShepherdJourney {
    if (!_conceptHassanLinked) return null;
    final focus = _shepherdFocus;
    if (focus == null) return null;
    final main = _conceptLinkedSeeker.isMain;
    final access = _conceptAccessFor('draft-shepherd-hassan', focus.id);
    if (!main && !access.view) return null;
    return MentorJourneyView(
      attemptId: 'draft-attempt-${focus.id}',
      matchId: 'draft-match-${focus.id}',
      linkedSeekerId: 'draft-self',
      linkedSeekerName: 'James',
      partner: SeekerProfile(
        id: focus.id,
        firstName: focus.firstName,
        age: focus.age,
        city: '—',
        gender: 'female',
        photos: const [],
      ),
      counterpartShepherdName: _model.peerMainShepherdPresentFor(focus.id)
          ? 'Main Shepherd'
          : null,
      counterpartShepherdSurname: null,
      status: 'active',
      journeyStage: _model.stageFor(focus.id)?.value,
      pause: _model.stateFor(focus.id) == DraftJourneyState.pauseRequested
          ? SelahJourneyPauseState(
              phase: SelahPausePhase.pauseDecisionPending,
              initiatedBy: 'draft-self',
              requestedBy: 'draft-self',
            )
          : SelahJourneyPauseState.active,
      isMock: true,
    );
  }

  ({bool view, bool chat}) _conceptAccessFor(
    String shepherdId,
    String focusId,
  ) => _model.sampleShepherdAccessFor(
    shepherdId,
    focusId,
    isMain:
        _model.ownMainShepherdPresent && _conceptMainShepherdId == shepherdId,
  );

  SelahShepherdCirclePreviewData _currentCirclePreviewData() {
    final people = _conceptShepherdPeople;
    final shepherd = _shepherdRole;
    final senderId = shepherd ? 'draft-shepherd-hassan' : 'draft-self';
    final contexts = [
      for (final person
          in shepherd ? _permittedShepherdJourneys : _shepherdJourneys)
        if (_model.stateFor(person.id) == DraftJourneyState.active)
          SelahFamilyMessageContext(
            referenceId: person.id,
            firstName: person.firstName,
            kind: SelahFamilyMessageContextKind.active,
          ),
    ];
    final funded =
        _seekerMembership == 'Seeker One' &&
        people.every(
          (person) =>
              _model.sampleShepherdMembershipFor(person.id) ==
              DraftShepherdMembership.one,
        );
    final previous = _circlePreviewData;
    final viewer = SelahShepherdCirclePreviewData(
      seekerId: 'draft-self',
      senderId: senderId,
      canSend: people.isNotEmpty && funded,
      participants: [
        SelahFamilyCircleParticipant(
          userId: 'draft-self',
          firstName: 'James',
          memberRole: 'seeker',
          isMainShepherd: false,
          isCurrentUser: !shepherd,
        ),
        for (final person in people)
          SelahFamilyCircleParticipant(
            userId: person.id,
            firstName: person.firstName,
            memberRole: 'shepherd',
            isMainShepherd: person.isMain,
            isCurrentUser: shepherd && person.id == senderId,
          ),
      ],
      messages: previous == null
          ? [
              SelahFamilyMessage(
                id: 'draft-circle-welcome',
                senderId: 'draft-self',
                senderFirstName: 'James',
                senderRoleLabel: 'Seeker',
                body: 'Hello. Let’s discuss the journey together.',
                createdAt: DateTime.utc(2026, 10, 12, 0, 10),
                readBy: [
                  for (final person in people)
                    SelahFamilyMessageReader(
                      userId: person.id,
                      firstName: person.firstName,
                      roleLabel: person.isMain
                          ? 'Main Shepherd'
                          : 'Additional Shepherd',
                      readAt: DateTime.utc(2026, 10, 12, 0, 11),
                    ),
                ],
              ),
              if (people.isNotEmpty)
                SelahFamilyMessage(
                  id: 'draft-circle-response',
                  senderId: people.first.id,
                  senderFirstName: people.first.firstName,
                  senderRelationship: people.first.relationship,
                  senderRoleLabel: people.first.isMain
                      ? 'Main Shepherd'
                      : 'Additional Shepherd',
                  body: 'Hello. We’re here to support and pray for you.',
                  createdAt: DateTime.utc(2026, 10, 12, 0, 12),
                  unreadForMe: !shepherd,
                  readBy: [
                    SelahFamilyMessageReader(
                      userId: 'draft-self',
                      firstName: 'James',
                      roleLabel: 'Seeker',
                      readAt: DateTime.utc(2026, 10, 12, 0, 14),
                    ),
                    for (final person in people.skip(1))
                      SelahFamilyMessageReader(
                        userId: person.id,
                        firstName: person.firstName,
                        roleLabel: person.isMain
                            ? 'Main Shepherd'
                            : 'Additional Shepherd',
                        readAt: DateTime.utc(2026, 10, 12, 0, 14),
                      ),
                  ],
                ),
            ]
          : const [],
      contexts: contexts,
    );
    return _circlePreviewData = previous == null
        ? viewer
        : previous.forViewer(
            senderId: viewer.senderId,
            participants: viewer.participants,
            contexts: viewer.contexts,
            canSend: viewer.canSend,
          );
  }

  Widget _shepherdCircle() {
    if (_shepherdRole && !_conceptHassanLinked) return _unavailable();
    if (_circleEntryView != null &&
        _circleEntryRevision == _circleScopeRevision) {
      return _circleEntryView!;
    }
    final revision = _circleScopeRevision;
    final shepherd = _shepherdRole;
    final tab = _tab;
    final senderId = shepherd ? 'draft-shepherd-hassan' : 'draft-self';
    String linkStamp() => _conceptShepherdPeople
        .map((person) => '${person.id}:${person.isMain}')
        .join('|');
    final stamp = linkStamp();
    bool current() =>
        _allowed &&
        revision == _circleScopeRevision &&
        shepherd == _shepherdRole &&
        tab == _tab &&
        (_page == 'shepherd_circle' ||
            (_page == 'controls' && _pageOptionsSource == 'shepherd_circle')) &&
        stamp == linkStamp() &&
        (!shepherd || _conceptHassanLinked);

    final contexts = [
      for (final person
          in shepherd ? _permittedShepherdJourneys : _shepherdJourneys)
        if (_model.stateFor(person.id) == DraftJourneyState.active)
          SelahFamilyMessageContext(
            referenceId: person.id,
            firstName: person.firstName,
            kind: SelahFamilyMessageContextKind.active,
          ),
    ];
    // Snapshot lazily after the existing bundled photo reader is ready. A
    // fast Circle entry must not freeze an empty photo list, and once exposed
    // each profile keeps its identity for this owned child-route lifetime.
    final discussionProfiles = <String, SeekerProfile>{};
    final data = _currentCirclePreviewData();
    final navigator = GlobalKey<NavigatorState>();
    _circleNavigator = navigator;
    _circleEntryRevision = revision;
    final ownerGuard = current;
    bool foreground() => current() && _page == 'shepherd_circle';
    final pastTopics = List<SelahCircleDiscussionTopic>.unmodifiable([
      for (var index = 0; index < 12; index++)
        SelahCircleDiscussionTopic(
          id: 'draft-circle-past-$index',
          firstName: const [
            'Elif',
            'Lydia',
            'Hafsa',
            'Phoebe',
            'Huda',
            'Chloe',
            'Abigail',
            'Joanna',
            'Priscilla',
            'Sumayya',
            'Miriam',
            'Joanna',
          ][index],
          kind: SelahCircleTopicKind.past,
          endedOn: DateTime.utc(
            2026,
            10,
            10,
          ).subtract(Duration(days: index * 15)),
        ),
    ]);
    return _circleEntryView = Navigator(
      key: navigator,
      onGenerateRoute: (_) => MaterialPageRoute<void>(
        builder: (_) => SelahShepherdCircleScreen(
          key: ValueKey(('request-shepherd-circle', revision, senderId)),
          seekerId: data.seekerId,
          seekerFirstName: 'James',
          viewerIsSeeker: !shepherd,
          preview: true,
          previewData: data,
          previewTopicLayout: _circleTopicLayout,
          previewForeground: foreground,
          previewVisibility: _circleVisibility,
          previewPastTopics: pastTopics,
          // A topic is not permission to look up a profile. Only this bound
          // Seeker caller can return an already admitted current example.
          // Shepherd/Past comparisons never gain a full-profile capability.
          previewDiscussionProfileFor: shepherd
              ? null
              : (context) {
                  if (!current() ||
                      _page != 'shepherd_circle' ||
                      !contexts.any(
                        (allowed) =>
                            allowed.referenceId == context.referenceId &&
                            allowed.firstName == context.firstName &&
                            allowed.kind == context.kind,
                      ) ||
                      context.kind != SelahFamilyMessageContextKind.active ||
                      _model.isBlocked(context.referenceId) ||
                      _model.stateFor(context.referenceId) !=
                          DraftJourneyState.active) {
                    return null;
                  }
                  final person = _shepherdJourneys
                      .where(
                        (person) =>
                            person.id == context.referenceId &&
                            person.firstName == context.firstName,
                      )
                      .firstOrNull;
                  if (person == null || _photos == null) return null;
                  return discussionProfiles.putIfAbsent(
                    person.id,
                    () => _displayProfile(person),
                  );
                },
          canAct: ownerGuard,
          onBack: () {
            if (current() && _page == 'shepherd_circle') _back();
          },
          onOpenContext: (context) {
            if (!current() ||
                _page != 'shepherd_circle' ||
                !contexts.any(
                  (allowed) =>
                      allowed.referenceId == context.referenceId &&
                      allowed.kind == context.kind,
                ) ||
                _model.isBlocked(context.referenceId) ||
                _model.stateFor(context.referenceId) !=
                    DraftJourneyState.active) {
              return;
            }
            if (shepherd) {
              _move(() {
                _shepherdJourneyId = context.referenceId;
                _pages.add('shepherd');
              });
            } else {
              _journey(context.referenceId);
            }
          },
        ),
      ),
    );
  }

  Future<void> _openInviteReminder(SelahShepherdInviteController invite) async {
    if (!_allowed || !invite.pending) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (routeContext) => SelahShepherdInviteFlow(
          controller: invite,
          initialStep: SelahShepherdInviteStep.sent,
          onContinue: () {
            if (_allowed) Navigator.of(routeContext).pop();
          },
        ),
      ),
    );
  }

  Widget _shepherdInviteReview() {
    final invite = _invite;
    if (invite == null || !invite.pending) return _shepherdDashboard();
    final profile = _conceptLinkedSeekerProfile;
    return SelahShepherdRequestReview(
      key: const ValueKey('local_shepherd_invite_review'),
      seekerName: profile.firstName,
      seekerAge: profile.age,
      seekerGender: profile.gender,
      seekerPhoto: SelahProfileImage(
        profile.photos.firstOrNull ?? '',
        width: 78,
        height: 78,
      ),
      relationship: invite.relation?.label ?? '',
      onBack: _bound(_back),
      onAccept: _bound(() {
        if (!invite.pending || !invite.accept()) return;
        _move(() {
          _pages.clear();
          _tab = 0;
          _notice = 'You are now ${profile.firstName}’s Shepherd.';
        });
      }),
      onDecline: _bound(
        () => _move(() {
          _pages.clear();
          _tab = 0;
          _notice =
              '${profile.firstName} will be told kindly. You can accept later from the message.';
        }),
      ),
    );
  }

  Widget _shepherds({String? journeyContextId}) {
    if (_invitePending && journeyContextId == null) {
      final invite = _invite!;
      return SafeArea(
        bottom: false,
        child: SelahShepherdPendingView(
          fullName: invite.fullName,
          onRemind: _bound(() => _openInviteReminder(invite)),
          onCopy: _bound(() => _act(() => _notice = 'Invite link copied.')),
        ),
      );
    }
    final revision = _uiRevision;
    final journeys = _shepherdJourneys;
    String journeyStamp() => _shepherdJourneys
        .map((p) => '${p.id}:${_model.stateFor(p.id)}')
        .join('|');
    final stamp = journeyStamp();
    final people = _conceptShepherdPeople;
    final orderedPeople = [
      ...people.where((person) => person.isMain),
      ...people.where((person) => !person.isMain),
    ];
    bool current() =>
        _allowed &&
        revision == _uiRevision &&
        !_shepherdRole &&
        ((journeyContextId == null && _tab == 3 && _page == null) ||
            (journeyContextId != null &&
                _page == 'journey_shepherds' &&
                _personId == journeyContextId &&
                _model.stateFor(journeyContextId) != null)) &&
        journeyStamp() == stamp;
    SelahSourceResult<T> unavailable<T>() =>
        const SelahSourceResult.unavailable(SelahSourceFailure.notReady);
    MentorLinkedPerson? personFor(String id) =>
        people.where((person) => person.id == id).firstOrNull;
    bool selectAddressed(String id) {
      if (!current()) return false;
      final captured = personFor(id);
      final actual = _conceptShepherdPeople
          .where((p) => p.id == id)
          .firstOrNull;
      if (captured == null ||
          actual == null ||
          captured.isMain != actual.isMain ||
          captured.firstName != actual.firstName ||
          captured.relationshipLabel != actual.relationshipLabel) {
        return false;
      }
      _shepherdPage = orderedPeople.indexWhere((person) => person.id == id);
      return _shepherdPage >= 0;
    }

    final main = people.where((person) => person.isMain).firstOrNull;
    final circle = _currentCirclePreviewData();
    final recent = main == null || _shepherdRecentEmpty
        ? const <SelahShepherdRecentItem>[]
        : selahShepherdRecent(
            seekerId: _accountSession.ownProfile(false).id,
            shepherdId: main.id,
            prayers: _prayerStore.updatesFor(
              _accountSession.ownProfile(false).id,
            ),
            messages: circle.messages
                .where((message) => message.senderId != null)
                .map(
                  (message) => SelahShepherdRecentMessage(
                    id: message.id,
                    senderId: message.senderId!,
                    body: message.body,
                    sentAt: message.createdAt,
                  ),
                ),
          );

    return SafeArea(
      bottom: false,
      child: NotificationListener<ScrollEndNotification>(
        onNotification: (notification) {
          final metrics = notification.metrics;
          if (metrics is! PageMetrics || metrics.axis != Axis.horizontal) {
            return false;
          }
          final next = metrics.page?.round();
          if (next != null && next != _shepherdPage && current()) {
            _act(() => _shepherdPage = next);
          }
          return false;
        },
        child: SeekerShepherdPage(
          titleAlignment: Alignment.centerLeft,
          titleSize: SelahText.pageTitleSize,
          people: people,
          displayNames: {
            for (final person in people)
              person.id: person is _InvitedShepherdPerson
                  ? person.firstName
                  : '${person.relationship == 'pastor' ? 'Pastor ' : ''}${person.firstName} ${draftShepherds.where((item) => item.id == person.id).firstOrNull?.surname ?? ''}'
                        .trim(),
          },
          recent: recent,
          mainPhoto:
              main != null &&
                  main is! _InvitedShepherdPerson &&
                  main.id == draftShepherds.first.id
              ? Image.asset(
                  'assets/dev/one_journey_photos/shepherd_self.jpg',
                  fit: BoxFit.cover,
                )
              : null,

          activity: const {},
          linksAvailable: true,
          activityAvailable: true,
          historyConsentPreview: false,
          previewActiveJourneyCount: journeys.length,
          onRetry: _bound(() => _act(() {})),
          onAdd: _bound(
            () => _holdPreviewAction(
              'Invite a Shepherd',
              'Choose the people who will support your journey. Invitations stay in the current app; this comparison does not send or create real links.',
            ),
          ),
          onOpenMessages: _bound(() => _open('shepherd_circle')),
          onAskForPrayer: _prayerMainShepherd == null
              ? null
              : _bound(_openPrayer),
          pendingInvitesLoader: () async => current()
              ? const SelahSourceResult.available(<PendingInvite>[])
              : unavailable<List<PendingInvite>>(),
          historyConsentLoader:
              ({required shepherdId, required shepherdIsMain, enabled}) async {
                final person = personFor(shepherdId);
                if (!current() ||
                    person == null ||
                    person.isMain != shepherdIsMain) {
                  return unavailable<ShepherdHistoryConsentState>();
                }
                if (enabled != null) {
                  if (!selectAddressed(shepherdId)) {
                    return unavailable<ShepherdHistoryConsentState>();
                  }
                  _act(() => _conceptShepherdHistory[shepherdId] = enabled);
                }
                return SelahSourceResult.available(
                  ShepherdHistoryConsentState(
                    enabled:
                        _conceptShepherdHistory[shepherdId] ?? _shareHistory,
                    activeShepherdLinkId: 'draft-link-$shepherdId',
                    shepherdId: shepherdId,
                    shepherdIsMain: shepherdIsMain,
                  ),
                );
              },
          journeyAccessLoader:
              ({required shepherdId, attemptId, enabled, chatEnabled}) async {
                final person = personFor(shepherdId);
                if (!current() || person == null) {
                  return unavailable<List<ShepherdJourneyAccessState>>();
                }
                if (_shepherdAccessPreset == 1) {
                  return Completer<
                        SelahSourceResult<List<ShepherdJourneyAccessState>>
                      >()
                      .future;
                }
                if (_shepherdAccessPreset == 2) {
                  return unavailable<List<ShepherdJourneyAccessState>>();
                }
                final target = journeys
                    .where((p) => 'draft-attempt-${p.id}' == attemptId)
                    .firstOrNull;
                if (attemptId != null && target == null) {
                  return unavailable<List<ShepherdJourneyAccessState>>();
                }
                if (enabled != null || chatEnabled != null) {
                  if (!selectAddressed(shepherdId) ||
                      person.isMain ||
                      target == null) {
                    return unavailable<List<ShepherdJourneyAccessState>>();
                  }
                  final oldAccess = _conceptAccessFor(shepherdId, target.id);
                  if (chatEnabled == true &&
                      (!_model.canUseSampleShepherdChat(shepherdId) ||
                          !(enabled ?? oldAccess.view))) {
                    return unavailable<List<ShepherdJourneyAccessState>>();
                  }
                  _act(() {
                    _model.setSampleShepherdJourneyAccess(
                      shepherdId,
                      target.id,
                      viewEnabled: enabled,
                      chatEnabled: chatEnabled,
                    );
                  });
                }
                return SelahSourceResult.available([
                  for (final counterpart in journeys)
                    ShepherdJourneyAccessState(
                      attemptId: 'draft-attempt-${counterpart.id}',
                      matchId: 'draft-match-${counterpart.id}',
                      counterpartFirstName: counterpart.firstName,
                      included:
                          person.isMain ||
                          _conceptAccessFor(shepherdId, counterpart.id).view,
                      canChange: !person.isMain,
                      shepherdIsMain: person.isMain,
                      chatAvailable: _model.canUseSampleShepherdChat(
                        shepherdId,
                      ),
                      chatEnabled: _conceptAccessFor(
                        shepherdId,
                        counterpart.id,
                      ).chat,
                    ),
                ]);
              },
          makeMainShepherd: (shepherdId) async {
            if (!current() ||
                !selectAddressed(shepherdId) ||
                personFor(shepherdId) == null) {
              return false;
            }
            _act(() {
              _conceptMainShepherdId = shepherdId;
              _model.setOwnMainShepherdPresent(true);
              _shepherdPage = 0;
            });
            return true;
          },
          clearMainShepherd: (shepherdId) async {
            if (!current() ||
                !selectAddressed(shepherdId) ||
                personFor(shepherdId)?.isMain != true) {
              return false;
            }
            _act(() => _model.setOwnMainShepherdPresent(false));
            return true;
          },
          removeShepherd: (shepherdId) async {
            if (!current() ||
                !selectAddressed(shepherdId) ||
                personFor(shepherdId) == null) {
              return 'This is no longer available. Nothing changed.';
            }
            _act(() {
              _conceptRemovedShepherds.add(shepherdId);
              if (shepherdId == _conceptMainShepherdId) {
                _model.setOwnMainShepherdPresent(false);
              }
              _shepherdPage = 0;
            });
            return null;
          },
          onChanged: () {},
        ),
      ),
    );
  }

  Widget _shepherdDetail() => _shepherdPermittedJourney();

  Widget _shepherdPermittedJourney() {
    final journey = _conceptShepherdJourney;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _mainHeading('Journey'),
        if (_permittedShepherdJourneys.length > 1) ...[
          const SizedBox(height: 14),
          _shepherdJourneySelector(),
        ],
        const SizedBox(height: 20),
        if (_conceptHassanLinked)
          ShepherdDashboardProfileCard(
            person: _conceptLinkedSeeker,
            profile: _conceptLinkedSeekerProfile,
            onViewProfile: _bound(() => _open('shepherd_linked_profile')),
          ),
        const SizedBox(height: 20),
        if (journey == null)
          _card([_body('No current Journey')])
        else
          _card([
            _title('James & ${journey.partner.firstName}', size: 25),
            _body(
              _model.stageFor(journey.partner.id)?.label ??
                  'Journey in progress',
            ),
            if (journey.isJourneyLocked)
              _body(
                'The Journey is waiting for a shared decision.',
                small: true,
              ),
            if (!_model.ownMainShepherdPresent)
              _body(
                'A Main Shepherd is needed before the Journey can continue.',
              ),
          ]),
      ],
    );
  }

  Widget _shepherdLinkedProfile() =>
      !_allowed || !_shepherdRole || !_conceptHassanLinked
      ? _conceptUnavailableShepherdProfile()
      : LayoutBuilder(
          builder: (context, bounds) => SingleChildScrollView(
            key: const ValueKey('shepherd_linked_profile_scroll'),
            child: Column(
              children: [
                SizedBox(
                  height: bounds.maxHeight,
                  child: SelahOneJourneyBrowsePresentation(
                    profile: _conceptLinkedSeekerProfile,
                    onMenu: _bound(_back),
                    menuKey: const ValueKey(
                      'concept_shepherd_linked_profile_back',
                    ),
                    menuLabel: 'Back',
                    menuIcon: Icons.arrow_back_ios_new,
                    menuOnLeft: true,
                    showMenu: false,
                    showActions: false,
                    identityBottom: 100,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 14, 22, 110),
                  child: SelahMarriageValuesCard(
                    answers: _accountSession.marriageAnswers,
                    visibilityNote: null,
                  ),
                ),
              ],
            ),
          ),
        );

  Widget _shepherdNetworkProfile() {
    if (!_conceptHassanLinked) return _conceptUnavailableShepherdProfile();
    final person = _person;
    if (person == null) return Center(child: _body('Profile unavailable'));
    if (_model.isBlocked(person.id)) return _userNotFoundView();
    // Same bounded display identity/photos as the current Network card.
    // No surname, exact place, private answer, history or Journey data.
    final profile = SeekerProfile(
      id: person.id,
      firstName: '${person.firstName[0]}., ${person.age}',
      age: 0,
      city: '',
      gender: 'female',
      photos: _photos?.forIndex(draftProfiles.indexOf(person)) ?? const [],
    );
    return SelahOneJourneyBrowsePresentation(
      profile: profile,
      onMenu: _bound(_back),
      menuKey: const ValueKey('concept_shepherd_network_profile_back'),
      menuLabel: 'Back',
      menuIcon: Icons.arrow_back_ios_new,
      menuOnLeft: true,
      showMenu: false,
      showActions: false,
      identityBottom: 100,
    );
  }

  void _switchRole(bool shepherd) {
    if (!_allowed) return;
    _move(() {
      _shepherdRole = shepherd;
      _tab = 0;
      _pages.clear();
    });
    widget.onRoleChanged?.call(shepherd);
  }

  Widget _conceptUnavailableShepherdProfile() => const SafeArea(
    child: SelahEmptyState(
      key: ValueKey('concept_shepherd_profile_unavailable'),
      icon: Icons.people_outline_rounded,
      message: 'This Seeker is not available in your linked roster.',
    ),
  );

  // Current empty Shepherd Dashboard hierarchy/copy, without a surviving
  // linked-person selector, portrait or permitted Journey after unlinking.
  Widget _conceptUnlinkedShepherdDashboard() => SafeArea(
    bottom: false,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _mainHeading('Shepherd Dashboard'),
              const SizedBox(height: 4),
              Text('Hello, David.', style: SelahText.subtext(size: 13.5)),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            key: const PageStorageKey('concept_shepherd_dashboard_empty'),
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 108),
            children: [
              _conceptEmptyShepherdStatus(
                section: 'RIGHT NOW',
                icon: Icons.check_circle_outline_rounded,
                eyebrow: 'ALL SETTLED',
                title: 'Everything is settled right now',
                detail:
                    'There are no linked Seeker responsibilities to review.',
              ),
              const SizedBox(height: 22),
              _conceptEmptyShepherdStatus(
                section: 'FAMILY SNAPSHOT',
                icon: Icons.people_outline_rounded,
                eyebrow: 'YOUR FAMILY',
                title: '0 linked Seekers · Nothing needs you',
                detail:
                    'Open Seekers for relationships, roles and authorised context.',
                actionLabel: 'View Seekers',
                onAction: _bound(() => _tabTo(2)),
              ),
              const SizedBox(height: 22),
              _conceptEmptyShepherdStatus(
                section: 'UPDATES',
                icon: Icons.notifications_none_rounded,
                eyebrow: 'ALL CAUGHT UP',
                title: 'No Shepherd updates yet',
                detail:
                    'Meaningful Journey and Family Review movement will appear here.',
              ),
              const SizedBox(height: 22),
              _conceptEmptyShepherdStatus(
                section: 'INSIGHTS',
                icon: Icons.insights_outlined,
                eyebrow: 'SHEPHERD INSIGHTS',
                title: 'No Shepherd insights available yet',
                detail:
                    'SELAH will only show a Shepherd insight when real, governed family-process evidence supports it.',
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _conceptEmptyShepherdStatus({
    required String section,
    required IconData icon,
    required String eyebrow,
    required String title,
    required String detail,
    String? actionLabel,
    VoidCallback? onAction,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(left: 2, bottom: 10),
        child: Text(
          section,
          style: SelahText.chapterLabel(color: SelahColors.ink(.54)),
        ),
      ),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: SelahColors.surfaceFill,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: SelahColors.surfaceBorder, width: .5),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 21, color: SelahColors.ink(.72)),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    eyebrow,
                    style: SelahText.chapterLabel(color: SelahColors.ink(.50)),
                  ),
                  const SizedBox(height: 4),
                  Text(title, style: SelahText.body(size: 14.2)),
                  const SizedBox(height: 4),
                  Text(detail, style: SelahText.subtext(size: 11.7)),
                  if (actionLabel != null && onAction != null) ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: onAction,
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 32),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(actionLabel),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _shepherdJourneySelector() {
    final people = _permittedShepherdJourneys;
    final selected = people.indexWhere((p) => p.id == _shepherdFocus?.id);
    final callbacks = [
      for (final p in people)
        _bound(() => _move(() => _shepherdJourneyId = p.id)),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'JOURNEY WITH',
          style: SelahText.chapterLabel(color: SelahColors.ink(.54)),
        ),
        const SizedBox(height: 5),
        TweenAnimationBuilder<double>(
          tween: Tween(end: selected < 0 ? 0.0 : selected.toDouble()),
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : SelahSegmentedMotion.selectionDuration,
          curve: SelahSegmentedMotion.selectionCurve,
          builder: (context, position, _) => SelahSegmentedToggle(
            labels: people.map((p) => p.firstName).toList(),
            position: position,
            segmentKeys: [
              for (final p in people)
                ValueKey('concept_shepherd_journey_${p.id}'),
            ],
            onChanged: (i) {
              if (i >= 0 && i < callbacks.length) callbacks[i]();
            },
          ),
        ),
      ],
    );
  }

  Widget _withShepherdJourneySelector(String title, Widget child) =>
      _permittedShepherdJourneys.length <= 1
      ? child
      : SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: _mainHeading(title),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                child: _shepherdJourneySelector(),
              ),
              Expanded(child: child),
            ],
          ),
        );

  Widget _shepherdDashboard() => !_conceptHassanLinked
      ? _conceptUnlinkedShepherdDashboard()
      : _withShepherdJourneySelector(
          'Shepherd Dashboard',
          SelahOneJourneyShepherdDashboardPresentation(
            showHeader: _permittedShepherdJourneys.length <= 1,
            profile: _conceptLinkedSeekerProfile,
            person: _conceptLinkedSeeker,
            shepherdName: 'David',
            prayerRequests: _prayerRequestsBlock(),
            hasShepherdOne: _shepherdMembership == 'Shepherd One',
            currentJourney: _conceptShepherdJourney,
            onProfile: _bound(() => _open('shepherd_linked_profile')),
            onJourney: _bound(() => _open('shepherd')),
            onMembership: _bound(() => _open('membership')),
          ),
        );

  Widget _shepherdSeekers() => !_conceptHassanLinked
      ? ShepherdSeekerRosterView(
          titleAlignment: Alignment.centerLeft,
          decoration: const BoxDecoration(),
          resolution: const ShepherdSeekerRosterResolution(
            mainSections: [],
            additionalShepherdships: [],
          ),
          onRetry: _bound(() => _act(() {})),
          onInvite: _bound(
            () => _holdPreviewAction(
              'Invite your Seeker',
              'Support someone on their journey. Invitations stay in the current app; no real invitation is sent from this comparison.',
            ),
          ),
          onOpenSeeker: (_) {},
        )
      : _withShepherdJourneySelector(
          'Seekers',
          SelahOneJourneyShepherdSeekersPresentation(
            showHeader: _permittedShepherdJourneys.length <= 1,
            profile: _conceptLinkedSeekerProfile,
            person: _conceptLinkedSeeker,
            currentJourney: _conceptShepherdJourney,
            hasShepherdOne: _shepherdMembership == 'Shepherd One',
            onJourney: _bound(() => _open('shepherd')),
            onNetwork: _bound(() => _tabTo(1)),
            onInvite: _bound(
              () => _holdPreviewAction(
                'Invite your Seeker',
                'Support someone on their journey. Invitations stay in the current app; no real invitation is sent from this comparison.',
              ),
            ),
            onFamilyChat: _bound(() => _open('shepherd_circle')),
          ),
        );

  Widget _network() {
    if (!_conceptHassanLinked) {
      return SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
              child: _mainHeading('Network'),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 96),
                child: Center(
                  child: SelahAddCircle(
                    label: 'Invite your Seeker',
                    onTap: _bound(
                      () => _holdPreviewAction(
                        'Invite your Seeker',
                        'Support someone on their journey. Invitations stay in the current app; no real invitation is sent from this comparison.',
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }
    final revision = _uiRevision;
    bool current() =>
        _allowed &&
        revision == _uiRevision &&
        _shepherdRole &&
        _conceptHassanLinked &&
        _tab == 1 &&
        _page == null;
    void localAction(VoidCallback action) {
      if (current()) _act(action);
    }

    return SelahOneJourneyShepherdNetworkPresentation(
      person: _conceptLinkedSeeker,
      profiles: _model.canBrowse
          ? _model.discoverableProfiles
                .where((p) => !_conceptNetworkSent.contains(p.id))
                .map(_displayProfile)
                .toList()
          : const [],
      selectedIndex: _networkTab,
      onChanged: (value) => localAction(() => _networkTab = value),
      onViewingProfileChanged: () => localAction(() {}),
      onSelectSeeker: _bound(() => _tabTo(2)),
      onProfile: (profile) {
        if (!current() || _model.isBlocked(profile.id)) return;
        _open('shepherd_network_profile', person: profile.id);
      },
      onIntroduction: (profile) {
        if (!current() ||
            !_conceptLinkedSeeker.isMain ||
            !_model.canBrowse ||
            _conceptNetworkSent.contains(profile.id) ||
            !_model.discoverableProfiles.any((p) => p.id == profile.id)) {
          return;
        }
        _open('network_request', person: profile.id);
      },
      sentProfiles: [
        for (final person in draftProfiles)
          if (!_model.isBlocked(person.id) &&
              _conceptNetworkSent.contains(person.id))
            _displayProfile(person),
      ],
      onWithdraw: (profile) {
        if (_model.isBlocked(profile.id)) return;
        localAction(() => _conceptNetworkSent.remove(profile.id));
      },
    );
  }

  void _holdPreviewAction(String title, String detail) => _move(() {
    _heldTitle = title;
    _heldDetail = detail;
    _pages.add('held_action');
  });

  Widget _heldPreviewAction() => Column(
    key: const ValueKey('concept_held_action'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [_heading(_heldTitle, '')],
  );

  Widget _networkRequestConfirmation() {
    final p = _person;
    if (p == null) return _unavailable();
    final canSend =
        _shepherdRole &&
        _conceptHassanLinked &&
        _conceptLinkedSeeker.isMain &&
        _model.canBrowse &&
        !_conceptNetworkSent.contains(p.id) &&
        _model.discoverableProfiles.any((person) => person.id == p.id);
    return Column(
      key: ValueKey('concept_network_request_${p.id}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _heading('Speak to Shepherd', ''),
        _card([
          _body(
            'Send a request to the Main Shepherd supporting this Seeker. They choose whether to respond.',
          ),

          _button(
            'concept_confirm_network_request_${p.id}',
            'Send request',
            canSend
                ? () => _act(() {
                    _conceptNetworkSent.add(p.id);
                    _networkTab = 1;
                    _pages.removeLast();
                    _notice = 'Request sent.';
                  })
                : null,
            primary: true,
          ),
          _button('concept_cancel_network_request_${p.id}', 'Not yet', _back),
        ]),
      ],
    );
  }

  Widget _ownProfilePreview() {
    if (_photos == null && !_photoLoadFailed) {
      return const SelahLoading.profile();
    }
    if (_ownProfilePreviewView != null &&
        _ownProfilePreviewRevision == _uiRevision) {
      return _ownProfilePreviewView!;
    }
    final fresh = _accountFreshGuard();
    _ownProfilePreviewRevision = _uiRevision;
    return _ownProfilePreviewView = MyProfilePreviewScreen.preview(
      key: ValueKey(('retained-own-profile', _uiRevision, _shepherdRole)),
      profile: _accountSession.ownProfile(_shepherdRole),
      canAct: fresh,
      onBack: () {
        if (fresh()) _back();
      },
    );
  }

  // These are explicitly synthetic presentation facts. They do not read a
  // member account, establish verification or grant any purchased access.
  SelahConceptAccountData get _accountData => SelahConceptAccountData(
    shepherd: _shepherdRole,
    name: _shepherdRole ? 'David Okafor' : 'James Carter',
    age: _shepherdRole ? '54' : '30',
    gender: 'Male',
    location: 'London',
    membership: _membership,
    isOne: !_membership.contains('Basic'),
    relationship: 'Pastor',
    linkedSeekers: _conceptHassanLinked ? '1' : '0',
    shepherdCount: '${_conceptShepherdPeople.length}',
    signedInWith: 'Apple',
    backgroundLabel: _accountSession.palette.label.replaceAll(' · Current', ''),
    hapticLabel: _accountSession.hapticLevel.label,
    gold: _gold,
    plusUnlocks: _compatibilityUnlockPreset,
    photoAsset: _accountSession.photos(_shepherdRole).firstOrNull,
    smoothSettings:
        SelahDevSettingsDesign.current == SelahSettingsDesign.smoothCards,
    basketCount: _selectedProducts.length,
    selectedProducts: Set.unmodifiable(_selectedProducts),
  );

  bool Function() _accountFreshGuard() {
    final revision = _uiRevision;
    final shepherd = _shepherdRole;
    final page = _page;
    final tab = _tab;
    return () =>
        _allowed &&
        revision == _uiRevision &&
        shepherd == _shepherdRole &&
        page == _page &&
        tab == _tab;
  }

  void _accountDispatch(SelahConceptAccountAction action) {
    switch (action) {
      case SelahConceptAccountAction.previewProfile:
        _open('own_profile_preview');
      case SelahConceptAccountAction.pastJourneys:
        // Ended Journeys live only in My SELAH in the new methodology.
        return;
      case SelahConceptAccountAction.personalisation:
        _open('personalisation');
      case SelahConceptAccountAction.settings:
        _open('settings');
      case SelahConceptAccountAction.membership:
        _open('membership');
      case SelahConceptAccountAction.compatibilityStore:
        _open('compatibility_store');
      case SelahConceptAccountAction.safetyAdvice:
        _move(() {
          _personId = null;
          _pages.add('safety');
        });
      case SelahConceptAccountAction.signOut:
        // Leaving the disposable preview never signs out the live account.
        if (_allowed) widget.onExit();
      case SelahConceptAccountAction.helpSupport:
        _open('help_support');
      case SelahConceptAccountAction.editProfile:
        if (!_shepherdRole) _open('edit_profile');
      case SelahConceptAccountAction.managePhotos:
        _open('manage_photos');
      default:
        _move(() {
          _accountDestination = action;
          _pages.add('account_action');
        });
    }
  }

  Widget _ownProfile() {
    final fresh = _accountFreshGuard();
    final shepherd = _shepherdRole;
    return SelahConceptProfilePresentation(
      data: _accountData,
      faithProfile: shepherd
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.faithConsentSkipped) ...[
                  Text(
                    'You chose not to share these. You can change this in Settings.',
                    key: const ValueKey('faith_consent_skipped_note'),
                    style: SelahText.body(size: 13, color: SelahColors.muted),
                  ),
                  const SizedBox(height: 14),
                ],
                SelahFaithProfileCard(answers: _accountSession.faithAnswers),
              ],
            ),
      marriageProfile: shepherd
          ? null
          : SelahMarriageValuesCard(answers: _accountSession.marriageAnswers),
      aboutYouProfile: shepherd
          ? null
          : SelahAboutYouCard(languages: _accountSession.details.languages),
      simplifiedMethodology: true,
      onAction: (action) {
        if (fresh()) _accountDispatch(action);
      },
      onSwitchRole: () {
        if (fresh()) _switchRole(!shepherd);
      },
    );
  }

  Widget _membershipView() {
    final fresh = _accountFreshGuard();
    return SelahConceptMembershipPresentation(
      data: _accountData,
      showBackButton: false,
      simplifiedMethodology: true,
      onAction: (action) {
        if (fresh()) _accountDispatch(action);
      },
      onProductSelected: (product) {
        if (!fresh()) return;
        _act(() {
          // Local basket only. Selection does not change membership, receipts,
          // eligibility or paid access in either the preview or the live app.
          if (!_selectedProducts.add(product)) {
            _selectedProducts.remove(product);
          }
        });
      },
      onBack: () {
        if (fresh()) _back();
      },
    );
  }

  Widget _settings() {
    final fresh = _accountFreshGuard();
    return SelahConceptSettingsPresentation(
      data: _accountData,
      showBackButton: false,
      onAction: (action) {
        if (fresh()) _accountDispatch(action);
      },
      onBack: () {
        if (fresh()) _back();
      },
    );
  }

  Widget _personalisation() => _retainedAccountLeaf();

  bool get _isRetainedAccountPage => const [
    'edit_profile',
    'manage_photos',
    'personalisation',
  ].contains(_page);

  void _accountChanged() {
    if (!_allowed) return;
    // Local presentation updates are not navigation epochs. Keeping this
    // lifetime stable lets the retained choice sheet return to its own page.
    setState(() {});
    _syncGoldMotion();
  }

  Widget _retainedAccountLeaf() {
    if (_page == 'manage_photos' && _photos == null && !_photoLoadFailed) {
      return const SelahLoading.profile();
    }
    if (_accountLeafView != null && _accountLeafRevision == _uiRevision) {
      return _accountLeafView!;
    }
    final revision = _uiRevision;
    final shepherd = _shepherdRole;
    final page = _page;
    final tab = _tab;
    final navigator = GlobalKey<NavigatorState>();
    _accountNavigator = navigator;
    _accountLeafRevision = revision;
    bool current() =>
        _allowed &&
        revision == _uiRevision &&
        shepherd == _shepherdRole &&
        page == _page &&
        tab == _tab &&
        _accountSession.current;
    void back() {
      if (current()) _back();
    }

    // Publication rebuilds the leaf. Keep its admitted callbacks stable for
    // this route epoch rather than accidentally revoking its own editor.
    void photosChanged(List<String> photos) {
      if (current()) _accountSession.setPhotos(shepherd, photos);
    }

    void avatarChanged(Offset alignment) {
      if (current()) _accountSession.setAvatar(shepherd, alignment);
    }

    void paletteChanged(SelahDevPalette palette) {
      if (current()) _accountSession.setPalette(palette);
    }

    void hapticChanged(SelahHapticLevel level) {
      if (!current() || !_accountSession.setHapticLevel(level)) return;
      unawaited(SelahInteractionStyle.emitSelectionHaptic(level: level));
    }

    void goldChanged(bool enabled) {
      if (current()) _accountSession.setGoldEnabled(enabled);
    }

    // The retained hub owns its ordinary child routes in this Navigator.
    // Covering the hub with its own editor or picker does not cover the
    // admitted Founder route or grant a stale page permission to save.
    return _accountLeafView = Navigator(
      key: navigator,
      onGenerateRoute: (_) => MaterialPageRoute<void>(
        builder: (_) => SelahPullDownBackScope(
          key: const ValueKey('concept_pull_down_back_scope'),
          routeIdentity: ('retained-account', revision, shepherd, page, tab),
          onBack: back,
          child: ListenableBuilder(
            listenable: _accountSession,
            builder: (_, _) => switch (page) {
              'edit_profile' => EditProfileScreen.preview(
                repository: _accountSession.compatibility,
                canAct: current,
                gender: 'male',
                age: 30,
              ),
              'manage_photos' => EditPhotosScreen.preview(
                canAct: current,
                initialPhotos: _accountSession.photos(shepherd),
                gender: 'male',
                hapticLevel: _accountSession.hapticLevel,
                initialAlignmentX: _accountSession.avatar(shepherd).dx,
                initialAlignmentY: _accountSession.avatar(shepherd).dy,
                onPhotosChanged: photosChanged,
                onAvatarChanged: avatarChanged,
              ),
              _ => PersonalisationScreen.preview(
                canAct: current,
                palette: _accountSession.palette,
                hapticLevel: _accountSession.hapticLevel,
                goldEnabled: _accountSession.goldEnabled,
                onPaletteChanged: paletteChanged,
                onHapticChanged: hapticChanged,
                onGoldChanged: goldChanged,
              ),
            },
          ),
        ),
      ),
    );
  }

  String _accountActionLabel(SelahConceptAccountAction action) =>
      switch (action) {
        SelahConceptAccountAction.previewProfile => 'Preview my profile',
        SelahConceptAccountAction.editProfile => 'Edit profile',
        SelahConceptAccountAction.managePhotos => 'Manage photos',
        SelahConceptAccountAction.compatibilityStore => 'Compatibility Unlocks',
        SelahConceptAccountAction.pastJourneys => 'Past Journeys',
        SelahConceptAccountAction.safetyAdvice => 'Safety & advice',
        SelahConceptAccountAction.invite => 'Invite someone to SELAH',
        SelahConceptAccountAction.personalisation => 'Personalisation',
        SelahConceptAccountAction.settings => 'Settings',
        SelahConceptAccountAction.signOut => 'Sign out',
        SelahConceptAccountAction.signInSecurity => 'Sign-in & security',
        SelahConceptAccountAction.appLock => 'App lock',
        SelahConceptAccountAction.advanced => 'Advanced',
        SelahConceptAccountAction.shepherdPrivacy => 'Shepherd privacy',
        SelahConceptAccountAction.visibility => 'Discovery & visibility',
        SelahConceptAccountAction.hiddenProfiles => 'Hidden profiles',
        SelahConceptAccountAction.notificationSettings =>
          'Notifications & emails',
        SelahConceptAccountAction.membership => 'Membership',
        SelahConceptAccountAction.helpSupport => 'Help & support',
        SelahConceptAccountAction.feedback => 'Send feedback',
        SelahConceptAccountAction.privacyData => 'Privacy & data',
        SelahConceptAccountAction.background => 'Background',
        SelahConceptAccountAction.haptics => 'Haptic feel',
        SelahConceptAccountAction.cancelMembership => 'Cancel membership',
        SelahConceptAccountAction.basket => 'Basket',
      };

  Widget _accountActionView() {
    final action = _accountDestination;
    final basket = action == SelahConceptAccountAction.basket;
    return Material(
      color: Colors.transparent,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      action == null ? 'Account' : _accountActionLabel(action),
                      style: SelahText.heading(size: 18),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                key: const ValueKey('concept_account_action_scroll'),
                padding: const EdgeInsets.fromLTRB(24, 26, 24, 100),
                children: [
                  if (basket) ...[
                    const SizedBox(height: 24),
                    if (_selectedProducts.isEmpty)
                      Text(
                        'Your basket is empty.',
                        style: SelahText.body(size: 14),
                      )
                    else
                      for (final product in _selectedProducts)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            SelahMembershipCatalog.title(product),
                            style: SelahText.body(size: 14),
                          ),
                        ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bio() => _card([
    _eyebrow('JOURNEY BIO'),
    _title('Beyond a first impression.', size: 27),
    _body(
      'A story, not a public browsing card. Only biography and life details '
      'a person chose to share belong in the Journey view.',
    ),
  ]);
  Widget _compatibilityInfo() {
    final preview = _compatibilityPreview;
    final person = _person;
    if (!_allowed ||
        _shepherdRole ||
        preview == null ||
        person == null ||
        preview.profileId != person.id ||
        _model.isBlocked(person.id)) {
      return _unavailable();
    }
    bool current() =>
        _allowed &&
        !_shepherdRole &&
        _page == 'compatibility' &&
        identical(preview, _compatibilityPreview) &&
        _personId == preview.profileId &&
        !_model.isBlocked(preview.profileId);
    VoidCallback? unlock() {
      if (preview.revealed || preview.balance == 0) return null;
      return _bound(() {
        if (current()) {
          _act(() {
            if (preview.unlock()) {
              unawaited(_selectionHaptic());
            }
          });
        }
      });
    }

    return SafeArea(
      child: Padding(
        // No bottom navigation is shown on this temporary result page.
        // Give its original-theme card the actual available phone viewport.
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: SelahDraftCompatibilityPresentation(
          key: ValueKey(('draft_compatibility', preview)),
          personName: person.firstName,
          balance: preview.balance,
          overallScore: preview.overallScore,
          revealed: preview.revealed,
          onUnlock: unlock(),
          onBuyMore: _bound(() {
            if (current()) _open('compatibility_store');
          }),
        ),
      ),
    );
  }

  Widget _compatibilityStore() => const SafeArea(
    child: Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: SelahDraftCompatibilityStorePresentation(),
    ),
  );

  Widget _compatibilityCreditChoices() {
    final preview = _compatibilityPreview;
    final balance = preview?.balance ?? _compatibilityUnlockPreset;
    return Row(
      children: [
        for (final count in const [0, 1, 5]) ...[
          if (count != 0) const SizedBox(width: 8),
          Expanded(
            child: _previewAction(
              'draft_compatibility_unlock_$count',
              '$count',
              () => _act(() {
                if (_shepherdRole) return;
                _compatibilityUnlockPreset = count;
                // Only the same covered local route may receive this count.
                if (identical(preview, _compatibilityPreview) &&
                    preview != null &&
                    _pages.contains('compatibility') &&
                    preview.profileId == _personId &&
                    !_model.isBlocked(preview.profileId)) {
                  preview.setBalance(count: count);
                }
              }),
              selected: balance == count,
              centered: true,
              showChevron: false,
              semanticLabel:
                  'Set Compatibility Unlock sample credits to $count',
            ),
          ),
        ],
      ],
    );
  }

  Widget _notificationsView() => _card([
    _eyebrow('UPDATES'),
    _title('Only what matters to you.', size: 26),
    _body(
      _currentJourneys.length > 1
          ? '${_currentJourneys.length} Journeys are in progress. Open Journey to choose one.'
          : _focus == null
          ? _visibleRequests(DraftJourneyState.received).isNotEmpty
                ? 'A Journey invitation is waiting in My SELAH.'
                : 'No Journey requests need your attention right now.'
          : _model.isBlocked(_focus!.id)
          ? 'This Journey is unavailable. Its place is retained until you end it.'
          : 'Your Journey with ${_focus!.firstName} is ${_stateLabel(_model.stateFor(_focus!.id)!)}.',
    ),
    _button(
      'concept_updates_connections',
      _focus == null
          ? 'View requests'
          : _currentJourneys.length > 1
          ? 'View your Journeys'
          : 'Open your Journey',
      () => _focus == null
          ? _activity('requests')
          : _currentJourneys.length > 1
          ? _tabTo(1)
          : _journey(_focus!.id),
    ),
  ]);
  Future<void> _pickBrowseFilter(String field) async {
    if (!_allowed || _page != 'filters') return;
    final revision = _uiRevision;
    final shepherd = _shepherdRole;
    final choices = switch (field) {
      'country' => {for (final item in selahCountries) item.code: item.name},
      'nationality' => {
        for (final item in selahCountries)
          item.code: '${item.nationality} (${item.code})',
      },
      'ethnicity' => {
        for (final item in selahEthnicities) item.code: item.name,
      },
      _ => <String, String>{},
    };
    if (choices.isEmpty) return;
    final selected = switch (field) {
      'country' => _editingBrowseFilter.countryCode,
      'nationality' => _editingBrowseFilter.nationalityCode,
      _ => _editingBrowseFilter.ethnicityCode,
    };
    final result = await showSingleSearchPicker(context, [
      'Any',
      ...choices.values,
    ], current: selected == null ? 'Any' : choices[selected]);
    // A picker result belongs only to the still-current editing session.
    // Account/proof, local navigation and another changed criterion all
    // revoke the retained completion; no preference/member write is made.
    if (!_allowed ||
        revision != _uiRevision ||
        shepherd != _shepherdRole ||
        _page != 'filters' ||
        result == null) {
      return;
    }
    final code = result == 'Any'
        ? null
        : choices.entries
              .where((entry) => entry.value == result)
              .firstOrNull
              ?.key;
    if (result != 'Any' && code == null) return;
    _act(() {
      _editingBrowseFilter = switch (field) {
        'country' => _editingBrowseFilter.withCountry(code),
        'nationality' => _editingBrowseFilter.withNationality(code),
        _ => _editingBrowseFilter.withEthnicity(code),
      };
    });
  }

  Widget _browseFilterPicker(String field, String title, String? selected) =>
      _previewAction(
        'concept_$field',
        '$title · ${selected ?? 'Any'}',
        () => _pickBrowseFilter(field),
        icon: Icons.search,
      );

  void _applyBrowseFilter() {
    if (!_allowed || _page != 'filters') return;
    _move(() {
      _browseFilter = _editingBrowseFilter;
      _browseExhausted = false;
      _seenBrowseProfileIds.clear();
      _browseIndex = 0;
      _browseHistory.reset();
      _pages.removeLast();
    });
  }

  Widget _filters() {
    final revision = _uiRevision;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _heading('Filters', ''),
        _title('Age', size: 15),
        const SizedBox(height: 8),
        _choices(
          const ['Any age (18+)', 'Set range'],
          _editingBrowseFilter.minAge == null &&
                  _editingBrowseFilter.maxAge == null
              ? 0
              : 1,
          (index) => _editingBrowseFilter = _editingBrowseFilter.withAge(
            index == 0 ? null : 18,
            index == 0 ? null : 70,
          ),
          'concept_age',
        ),
        if (_editingBrowseFilter.minAge != null ||
            _editingBrowseFilter.maxAge != null) ...[
          const SizedBox(height: 8),
          Text(
            '${_editingBrowseFilter.minAge ?? 18}–${_editingBrowseFilter.maxAge ?? 70}',
            key: const ValueKey('concept_age_value'),
            style: SelahText.body(size: 13, color: SelahColors.journeyGold),
          ),
          RangeSlider(
            key: const ValueKey('concept_age_range'),
            min: 18,
            max: 70,
            divisions: 52,
            activeColor: SelahColors.journeyGold,
            inactiveColor: SelahColors.surfaceBorder,
            values: RangeValues(
              (_editingBrowseFilter.minAge ?? 18).toDouble(),
              (_editingBrowseFilter.maxAge ?? 70).toDouble(),
            ),
            labels: RangeLabels(
              '${_editingBrowseFilter.minAge ?? 18}',
              '${_editingBrowseFilter.maxAge ?? 70}',
            ),
            onChanged: (values) {
              if (!_allowed || _page != 'filters' || revision != _uiRevision) {
                return;
              }
              _act(
                () => _editingBrowseFilter = _editingBrowseFilter.withAge(
                  values.start.round(),
                  values.end.round(),
                ),
              );
            },
          ),
        ],
        const SizedBox(height: 20),
        _browseFilterPicker(
          'country',
          'Country of residence',
          selahBrowseCountryLabel(_editingBrowseFilter.countryCode),
        ),
        const SizedBox(height: 8),
        const SizedBox(height: 20),
        _title('Distance', size: 15),
        const SizedBox(height: 6),
        _body(selahBrowseSampleOriginLabel, small: true),
        const SizedBox(height: 4),
        _body('Your current location is not available.', small: true),
        const SizedBox(height: 8),
        _choices(
          const ['Any distance', '50 km', '150 km', '300 km'],
          const <double?>[
            null,
            50,
            150,
            300,
          ].indexOf(_editingBrowseFilter.radiusKm),
          (index) => _editingBrowseFilter = _editingBrowseFilter.withRadius(
            const <double?>[null, 50, 150, 300][index],
            from: selahBrowseSampleOrigin,
          ),
          'concept_radius',
        ),
        const SizedBox(height: 20),
        _title('City', size: 15),
        const SizedBox(height: 8),
        _choices(
          ['All places', 'Manchester', 'Birmingham', 'London', 'Leeds'],
          [
            null,
            'Manchester',
            'Birmingham',
            'London',
            'Leeds',
          ].indexOf(_editingBrowseFilter.city),
          (i) => _editingBrowseFilter = _editingBrowseFilter.withCity(
            [null, 'Manchester', 'Birmingham', 'London', 'Leeds'][i],
          ),
          'concept_city',
        ),
        const SizedBox(height: 18),
        _button(
          'concept_apply_filter',
          'Apply filters',
          _applyBrowseFilter,
          primary: true,
        ),
        const SizedBox(height: 8),
        _previewAction(
          'concept_reset_filter_draft',
          'Clear filters',
          () => _act(() => _editingBrowseFilter = const SelahBrowseFilter()),
          icon: Icons.filter_alt_off_outlined,
        ),
        const SizedBox(height: 14),
      ],
    );
  }

  Widget _safety() {
    final person = _person;
    final canSelect = _accountFreshGuard();
    VoidCallback? localAction(bool hide) => person == null
        ? null
        : _bound(() {
            if (!canSelect() || _personId != person.id) return;
            _move(() {
              final changed = hide
                  ? _model.hide(person.id)
                  : _model.block(person.id);
              if (!changed) return;
              _pages.clear();
              _tab = 0;
              _personId = null;
              _browseIndex = 0;
              _notice = hide ? 'Profile hidden.' : 'Profile blocked.';
            });
          });
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: SelahDraftReportPresentation(
          key: ValueKey(('draft_report', person?.id, _shepherdRole)),
          profile: person == null ? null : _displayProfile(person),
          canSelect: canSelect,
          onHide: localAction(true),
          onBlock: localAction(false),
        ),
      ),
    );
  }

  void _showJourneyCount(int count, {int tab = 1}) => _move(() {
    if (!_model.seedJourneys(count)) return;
    _messages.clear();
    _message.clear();
    _conceptShepherdHistory.clear();
    _conceptRemovedShepherds.clear();
    _conceptMainShepherdId = 'draft-shepherd-hassan';
    _shareHistory = false;
    _shepherdJourneyId = null;
    _personId = null;
    _expansion.collapseAll();
    _shepherdPage = 0;
    _shepherdRole = false;
    _tab = tab;
    _pages.clear();
    widget.onRoleChanged?.call(false);
  });

  void _sampleSeekerMembership(bool basic) => _act(() {
    if (!_model.setCapacity(basic ? 1 : 3)) {
      _notice =
          'Choose the 1 Journey option first. Existing Journeys have not been removed.';
      return;
    }
    _seekerMembership = basic ? 'Seeker Basic' : 'Seeker One';
  });

  /// The existing private Page options owns these offline simulation controls.
  /// Each callback keeps the menu's original source, identity and revision.
  List<Widget> _movedSimulationOptions() {
    if (!_allowed ||
        _page != 'controls' ||
        _shepherdRole ||
        !SelahDeveloperAccess.canUseDeveloperTools) {
      return const [];
    }
    final fresh = _accountFreshGuard();
    final source = _pageOptionsSource;
    if (source == 'requests' && _tab == 2 && _requestsTab == 1) {
      return [
        for (final person in _visibleRequests(DraftJourneyState.sent))
          _previewAction(
            'draft_recipient_${person.id}',
            'Demo: recipient accepts · ${person.firstName}',
            _model.canAttemptAccept(person.id)
                ? () {
                    if (!fresh() ||
                        _page != 'controls' ||
                        _pageOptionsSource != source ||
                        _shepherdRole ||
                        _tab != 2 ||
                        _requestsTab != 1 ||
                        !SelahDeveloperAccess.canUseDeveloperTools ||
                        _model.stateFor(person.id) != DraftJourneyState.sent) {
                      return;
                    }
                    unawaited(_accept(person, false, fromPageOptions: true));
                  }
                : null,
          ),
      ];
    }
    final person = _person;
    if (source != 'journey' || person == null) return const [];
    final id = person.id;
    final state = _model.stateFor(id);
    final stage = _model.stageFor(id)?.value;
    bool current() =>
        fresh() &&
        !_shepherdRole &&
        _page == 'controls' &&
        _pageOptionsSource == source &&
        _personId == id &&
        _model.stateFor(id) == state &&
        _model.stageFor(id)?.value == stage &&
        !_model.isBlocked(id) &&
        SelahDeveloperAccess.canUseDeveloperTools;
    void apply(VoidCallback action) {
      if (!current()) return;
      _act(action);
      _back();
    }

    Widget option(
      String key,
      String label,
      bool enabled,
      VoidCallback action,
    ) => _previewAction(key, label, enabled ? () => apply(action) : null);
    return [
      if (state == DraftJourneyState.preparing)
        option(
          'draft_peer_ready_$id',
          'Demo: ${person.firstName} confirms readiness',
          !_model.peerIsReady(id),
          () => _model.simulatePeerReady(id),
        ),
      if (state == DraftJourneyState.resumeRequested)
        option(
          'draft_agree_resume_$id',
          'Demo: other person agrees to resume',
          _model.hasCapacity &&
              !_model.peerOccupied(id) &&
              _model.ownMainShepherdPresent &&
              _model.peerMainShepherdPresentFor(id),
          () => _result(_model.agreeResume(id), 'Journey resumed.'),
        ),
      if (state == DraftJourneyState.pauseRequested) ...[
        option(
          'draft_agree_pause_$id',
          'Demo: both agree to Pause',
          true,
          () => _result(_model.agreePause(id), 'Mutual Pause settled.'),
        ),
        option(
          'draft_continue_$id',
          'Demo: both agree to continue',
          true,
          () => _result(_model.continueJourney(id), 'Journey continues.'),
        ),
      ],
      if (stage == 'greeting_exchange')
        option(
          'draft_peer_greeting_$id',
          'Demo: ${person.firstName} says hello',
          _model.canParticipateInJourney(id) && !_model.peerHasSentGreeting(id),
          () => _model.simulatePeerGreeting(id),
        ),
      if (stage == 'compatibility_reveal')
        option(
          'draft_peer_reveal_$id',
          'Demo: ${person.firstName} also chooses reveal',
          _model.canParticipateInJourney(id) &&
              !_model.peerHasChosenCompatibilityReveal(id),
          () => _model.simulatePeerCompatibilityReveal(id),
        ),
      if (stage == 'conversation') ...[
        TextField(
          key: const ValueKey('concept_message'),
          controller: _message,
          style: SelahText.body(),
          maxLength: 280,
          enabled: _model.conversationOpen(id),
          decoration: const InputDecoration(labelText: 'Sample message'),
        ),
        option(
          'concept_send_message',
          'Add sample message',
          _model.conversationOpen(id),
          () {
            if (!_model.conversationOpen(id)) return;
            final text = _message.text.trim();
            if (text.isEmpty || text.length > 280) return;
            (_messages[id] ??= []).add(text);
            _message.clear();
          },
        ),
      ] else if (stage != null)
        option(
          'draft_stage_peer_ready_$id',
          'Demo: ${person.firstName} is also ready',
          _model.canPeerChooseStageContinue(id),
          () => _model.simulatePeerStageContinue(id),
        ),
    ];
  }

  /// Draft-only explanations live behind the same private door as presets.
  List<Widget> _privateDraftHelp() {
    if (_page != 'controls' || !SelahDeveloperAccess.canUseDeveloperTools) {
      return const [];
    }
    final source = _pageOptionsSource;
    final help = <String>[
      if (source == 'journey' ||
          source == 'timeline' ||
          source == 'ended' ||
          source == 'past_journeys') ...[
        'These controls simulate the other person and chapter checkpoints. Question fields are display-only here. No messages, private answers, credits or Family Review decisions are sent or approved.',
        'The demo still requires both choices and the current threshold. Phase review is simulated, not a server approval.',
        'Invented local messages only. No real conversation is loaded.',
      ],
      if (source == 'journey' || source == 'journey_compatibility')
        'This sample does not calculate a score, load private answers or spend Compatibility Unlocks.',
      if (source == 'compatibility') ...[
        'This local preview has no score or private result. Your real answers, credit balance and results are untouched.',
        'SHEPHERD EXAMPLE · Demo Shepherd · Father · Main Shepherd · Fictional example.',
        'Compatibility figures are fictional developer results, not calculated from private answers. No real credits are used.',
      ],
      if (source == 'held_action') _heldDetail,
      if (source == null && !_shepherdRole && _tab == 2)
        'This action is held in the local preview. Your account is unchanged.',
      if (source == 'network_request')
        'This sample stays in the comparison. No real request or conversation opens.',
      if (source == 'account_action') ...[
        'This action is held in the comparison. It does not open your live account, edit member records, change security or device preferences, send invitations or feedback, or manage billing.',
        'This basket is local to the comparison. Checkout is not available here; no payment or entitlement is created.',
      ],
      if (source == null && _tab == (_shepherdRole ? 3 : 4))
        'Preview features only; no payment or entitlement change.',
      if (source == 'bio')
        'No real or sample private biography is auto-revealed in this comparison.',
      if (source == 'notifications')
        'No real notifications are fetched, marked read or sent.',
      if (source == 'filters')
        'Sample people only. These public heritage labels and locations are invented samples. Private compatibility answers are not accessed. Occupied profiles stay excluded; real preferences and eligibility are unchanged.',
    ];
    return [
      if (help.isNotEmpty)
        _controlSection([for (final text in help) _body(text, small: true)]),
    ];
  }

  Widget _controls() {
    final sourcePage = _pageOptionsSource;
    final mainPage = sourcePage == null;
    final browse = mainPage && !_shepherdRole && _tab == 0;
    final journey = mainPage && !_shepherdRole && _tab == 1;
    final mySelah =
        !_shepherdRole &&
        ((mainPage && _tab == 2) ||
            sourcePage == 'ended' ||
            sourcePage == 'past_journeys');
    final shepherd = mainPage && !_shepherdRole && _tab == 3;
    final prayer = !_shepherdRole && sourcePage == 'prayer';
    final prayerDashboard = mainPage && _shepherdRole && _tab == 0;
    final profile = mainPage && _tab == (_shepherdRole ? 3 : 4);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _title('Page options', size: 18),
        ..._movedSimulationOptions(),
        ..._privateDraftHelp(),
        if (browse)
          _controlSection([
            _previewAction(
              'marriage_share_later',
              'Marriage · share later',
              () {
                if (!_allowed ||
                    !SelahDeveloperAccess.canUseDeveloperTools ||
                    _shepherdRole ||
                    _page != 'controls' ||
                    _pageOptionsSource != null ||
                    _tab != 0) {
                  return;
                }
                final people = _browseFilter.apply(_model.discoverableProfiles);
                if (people.isEmpty ||
                    people[_browseSelectionIndex(people)].id != 'draft-amira') {
                  return;
                }
                _move(() {
                  _marriageShareLater = true;
                  _pages.removeLast();
                });
              },
            ),
          ]),
        if (prayer)
          _controlSection([
            _previewAction('prayer_sending', 'Prayer · sending', () {
              if (!_prayerComposerScope ||
                  !SelahDeveloperAccess.canUseDeveloperTools) {
                return;
              }
              _prayerComposerController?.showSending();
              _back();
            }),
            _previewAction('prayer_failed', "Prayer · didn't send", () {
              if (!_prayerComposerScope ||
                  !SelahDeveloperAccess.canUseDeveloperTools) {
                return;
              }
              _prayerComposerController?.showFailure();
              _back();
            }),
          ]),
        if (prayerDashboard)
          _controlSection([
            _previewAction('prayer_empty', 'Prayer · no requests', () {
              final controller = _newPrayerController(composer: false);
              final changed = controller.presetEmpty();
              controller.dispose();
              if (changed) _back();
            }),
            _previewAction('prayer_requests', 'Prayer · requests', () {
              if (!_prayerShepherdScope ||
                  !SelahDeveloperAccess.canUseDeveloperTools) {
                return;
              }
              _act(() => _prayerEmptyView = false);
              _back();
            }),
          ]),
        if (_invite != null && SelahDeveloperAccess.canUseDeveloperTools) ...[
          _controlSection([
            _previewAction('invite_sending', 'Invite · sending', () {
              if (_allowed && SelahDeveloperAccess.canUseDeveloperTools) {
                _invite!.showSending();
              }
            }),
            _previewAction('invite_failed', "Invite · didn't send", () {
              if (_allowed && SelahDeveloperAccess.canUseDeveloperTools) {
                _invite!.showFailure();
              }
            }),
            _previewAction('invite_shepherd_accepts', 'Shepherd accepts', () {
              if (!_allowed || !SelahDeveloperAccess.canUseDeveloperTools) {
                return;
              }
              if (_invite!.accept()) {
                _move(() {
                  _pages.clear();
                  _notice =
                      '${_invite!.firstName} said yes. You can ask and accept now.';
                });
              }
            }),
          ]),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 8),
        Text(
          _pageOptionsTitle,
          key: const ValueKey('concept_page_options_context'),
          style: SelahText.heading(size: 15),
        ),
        const SizedBox(height: 14),
        if (SelahDeveloperAccess.canUseDeveloperTools &&
            !_shepherdRole &&
            sourcePage == 'journey' &&
            _personId != null &&
            _model.conversationOpen(_personId!)) ...[
          _controlSection([
            _previewAction(
              'marriage_prep_didnt_save',
              "Marriage preparation · didn't save",
              () {
                if (!_allowed ||
                    !SelahDeveloperAccess.canUseDeveloperTools ||
                    _page != 'controls' ||
                    _pageOptionsSource != 'journey' ||
                    _personId == null ||
                    !_model.conversationOpen(_personId!)) {
                  return;
                }
                _move(() {
                  _marriagePrepFailed.add(_personId!);
                  _pages.removeLast();
                });
              },
            ),
          ]),
          const SizedBox(height: 12),
        ],
        if (_hasCircleDiscussionOptions) ...[
          _controlSection([
            _title('Journey discussion', size: 13),
            _circleTopicLayoutPicker(),
          ]),
          const SizedBox(height: 12),
        ],
        if (!_shepherdRole && (browse || sourcePage == 'compatibility')) ...[
          _controlSection([
            _title('Compatibility Unlock', size: 13),
            _compatibilityCreditChoices(),
          ]),
          const SizedBox(height: 12),
        ],
        if (browse) ...[
          const SizedBox(height: 12),
          _controlSection([
            _title('Next animation', size: 13),
            _nextMotionPicker(),
          ]),
        ],
        if (journey) ...[
          const SizedBox(height: 12),
          _controlSection([
            _title('Journey preview', size: 13),
            Row(
              children: [
                for (final count in [1, 2, 3]) ...[
                  if (count > 1) const SizedBox(width: 8),
                  Expanded(
                    child: _previewAction(
                      'concept_journey_preview_$count',
                      '$count',
                      count <= _model.capacity
                          ? () => _showJourneyCount(count)
                          : null,
                      showChevron: false,
                      centered: true,
                      semanticLabel:
                          'Show $count sample ${count == 1 ? 'Journey' : 'Journeys'}',
                    ),
                  ),
                ],
              ],
            ),
          ]),
        ],
        if (profile && !_shepherdRole) ...[
          const SizedBox(height: 12),
          _controlSection([
            _title('Sample membership', size: 13),
            _previewAction(
              'draft_membership_seeker_basic',
              'Basic · 1 place',
              () => _sampleSeekerMembership(true),
              selected: _model.capacity == 1,
              icon: Icons.person_outline,
            ),
            _previewAction(
              'draft_membership_seeker_one',
              'Monthly · 3 places',
              () => _sampleSeekerMembership(false),
              selected: _model.capacity == 3,
              icon: Icons.workspace_premium_outlined,
            ),
          ]),
        ],
        if (shepherd) ...[
          const SizedBox(height: 12),
          _controlSection([
            for (final entry in const [
              (0, 'shepherd_access_available', 'Journey access · available'),
              (1, 'shepherd_access_loading', 'Journey access · loading'),
              (2, 'shepherd_access_failed', 'Journey access · didn’t load'),
              (3, 'shepherd_recent_empty', 'Recently · nothing yet'),
            ])
              _previewAction(entry.$2, entry.$3, () {
                if (!_allowed ||
                    !SelahDeveloperAccess.canUseDeveloperTools ||
                    _shepherdRole ||
                    _tab != 3 ||
                    _page != 'controls' ||
                    _pageOptionsSource != null) {
                  return;
                }
                _move(() {
                  if (entry.$1 == 3) {
                    _shepherdRecentEmpty = true;
                  } else {
                    _shepherdAccessPreset = entry.$1;
                    _shepherdRecentEmpty = false;
                  }
                  _pages.removeLast();
                });
              }),
          ]),
        ],
        if (shepherd) ...[
          const SizedBox(height: 12),
          _controlSection([
            for (final shepherd in draftShepherds) ...[
              if (shepherd != draftShepherds.first) const SizedBox(height: 8),
              _choices(
                ['${shepherd.firstName}: Basic', '${shepherd.firstName}: One'],
                _model.sampleShepherdMembershipFor(shepherd.id) ==
                        DraftShepherdMembership.basic
                    ? 0
                    : 1,
                (index) {
                  _model.setSampleShepherdMembership(
                    shepherd.id,
                    index == 0
                        ? DraftShepherdMembership.basic
                        : DraftShepherdMembership.one,
                  );
                  if (shepherd.id == 'draft-shepherd-hassan') {
                    _shepherdMembership = index == 0
                        ? 'Shepherd Basic'
                        : 'Shepherd One';
                  }
                },
                'concept_shepherd_plan_${shepherd.id}',
              ),
            ],
          ]),
        ],
        if (!_shepherdRole && sourcePage == 'requests') ...[
          const SizedBox(height: 12),
          _controlSection([
            _choices(
              const ['Received', 'Sent', 'Introductions'],
              _requestsTab,
              (index) => _requestsTab = index,
              'concept_requests_controls',
            ),
          ]),
        ],
        if (mySelah) ...[
          const SizedBox(height: 12),
          _controlSection([
            _previewAction(
              'draft_history',
              'Add Ended history',
              () => _act(() {
                _model.seedHistory(includePaused: false);
                _notice = 'History added. Current Journey is unchanged.';
              }),
              icon: Icons.history,
            ),
          ]),
        ],
        const SizedBox(height: 12),
        _controlSection([
          _previewAction(
            'draft_reset',
            'Reset preview',
            () => _move(() {
              SelahVisualComparison.instance.select(
                _appearanceOwner,
                option2: false,
              );
              _model.setCapacity(3);
              _model.reset();
              _replacementUpdates.clear();
              _marriagePrepFailed.clear();
              _marriageShareLater = false;
              _invite?.reset();
              _seenBrowseProfileIds.clear();
              _browseExhausted = false;
              _browseHistory.reset();
              _messages.clear();
              _message.clear();
              _conceptNetworkSent.clear();
              _conceptShepherdHistory.clear();
              _conceptRemovedShepherds.clear();
              _conceptMainShepherdId = 'draft-shepherd-hassan';
              _shareHistory = false;

              _browseFilter = const SelahBrowseFilter();
              _editingBrowseFilter = _browseFilter;
              _seekerMembership = 'Seeker One';
              _shepherdMembership = 'Shepherd One';
              _requestsTab = 0;
              _selectedProducts.clear();
              _compatibilityUnlockPreset = 1;
              _compatibilityPreview = null;
              _circleTopicLayout.value = SelahCircleTopicLayout.current;
              _accountDestination = null;
              _expansion.collapseAll();
              _shepherdPage = _networkTab = 0;
              _browseIndex = 1;
              _personId = null;
              _shepherdJourneyId = null;
              _shepherdRole = false;
              _tab = 0;
              _pages.clear();
              widget.onRoleChanged?.call(false);
            }),
            icon: Icons.restart_alt,
          ),
        ]),
        const SizedBox(height: 12),
        _controlSection([
          _title('Account preview', size: 13),
          _previewAction(
            'draft_role_shepherd',
            'Shepherd',
            () => _switchRole(true),
            selected: _shepherdRole,
            icon: Icons.gpp_good_outlined,
          ),
          _previewAction(
            'draft_role_seeker',
            'Seeker',
            () => _switchRole(false),
            selected: !_shepherdRole,
            icon: Icons.person_outline,
          ),
        ]),
      ],
    );
  }

  Widget _circleTopicLayoutPicker() {
    final fresh = _accountFreshGuard();
    final sourcePage = _pageOptionsSource;
    final shepherdRole = _shepherdRole;
    final sourceTab = _tab;
    return DropdownButtonFormField<SelahCircleTopicLayout>(
      key: ValueKey((
        'concept_circle_topic_layout_dropdown',
        _circleTopicLayout.value,
      )),
      initialValue: _circleTopicLayout.value,
      isExpanded: true,
      menuMaxHeight: 320,
      dropdownColor: SelahColors.modalSheetSurface,
      icon: Icon(Icons.expand_more, color: SelahColors.unlockText, size: 20),
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        filled: true,
        fillColor: SelahColors.surfaceFill,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: SelahColors.surfaceBorder, width: .6),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: SelahColors.unlockText, width: .8),
        ),
      ),
      items: [
        for (final layout in SelahCircleTopicLayout.values)
          DropdownMenuItem(
            key: ValueKey('concept_circle_topic_layout_${layout.name}'),
            value: layout,
            child: Text(layout.label, style: SelahText.body(size: 13)),
          ),
      ],
      onChanged: (layout) {
        if (layout == null ||
            !fresh() ||
            !_hasCircleDiscussionOptions ||
            _pageOptionsSource != sourcePage ||
            _shepherdRole != shepherdRole ||
            _tab != sourceTab) {
          return;
        }
        unawaited(_selectionHaptic());
        _act(
          () => _circleTopicLayout.value = layout,
          preserveCircle: sourcePage == 'shepherd_circle',
        );
      },
    );
  }

  Widget _nextMotionPicker() {
    final fresh = _accountFreshGuard();
    return DropdownButtonFormField<SelahBrowseNextMotion>(
      key: ValueKey(('concept_next_motion_dropdown', _browseNextMotion)),
      initialValue: _browseNextMotion,
      isExpanded: true,
      menuMaxHeight: 320,
      dropdownColor: SelahColors.modalSheetSurface,
      icon: Icon(Icons.expand_more, color: SelahColors.unlockText, size: 20),
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        filled: true,
        fillColor: SelahColors.surfaceFill,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: SelahColors.surfaceBorder, width: .6),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: SelahColors.unlockText, width: .8),
        ),
      ),
      items: [
        for (final motion in SelahBrowseNextMotion.values)
          DropdownMenuItem(
            key: ValueKey('concept_browse_next_motion_${motion.name}'),
            value: motion,
            child: Text(motion.label, style: SelahText.body(size: 13)),
          ),
      ],
      onChanged: (motion) {
        if (motion != null && fresh()) {
          _act(() => _browseNextMotion = motion);
        }
      },
    );
  }

  Widget _unavailable() => _card([
    _title('Nothing to open here.', size: 23),
    _button('concept_return_connections', 'Go to Journey', () => _tabTo(1)),
  ]);
  Widget _mainHeading(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Align(
      alignment: Alignment.topLeft,
      child: Text(
        title,
        key: ValueKey('concept_main_title_$title'),
        style: SelahText.pageTitle(),
        textAlign: TextAlign.left,
      ),
    ),
  );
  Widget _heading(String title, String description) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _title(title, size: 26),
        if (description.isNotEmpty) ...[
          const SizedBox(height: 8),
          _body(description, small: true),
        ],
      ],
    ),
  );
  Widget _eyebrow(String label) => Text(
    label,
    style: SelahText.chapterLabel(
      color: SelahColors.foregroundMuted.withValues(alpha: .7),
    ),
  );
  Widget _title(String text, {double size = 24}) =>
      Text(text, style: SelahText.heading(size: size));
  Widget _body(String text, {bool small = false, bool gold = false}) => Text(
    text,
    style: SelahText.body(
      size: small ? 12 : 15,
      color: gold ? SelahColors.journeyGold : SelahColors.foregroundMuted,
    ),
  );
  Widget _controlSection(List<Widget> children) => SelahDevToolSection(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          children[i],
        ],
      ],
    ),
  );
  // Developer controls use compact current-theme rows. Member-facing actions
  // continue to use _button below; this never changes their size or behavior.
  Widget _previewAction(
    String id,
    String label,
    VoidCallback? action, {
    bool? selected,
    IconData? icon,
    bool showChevron = true,
    bool centered = false,
    String? semanticLabel,
  }) {
    final enabled = action != null;
    final color = enabled
        ? SelahColors.foreground
        : SelahColors.foregroundMuted.withValues(alpha: .5);
    return Semantics(
      selected: selected,
      child: OutlinedButton(
        key: ValueKey(id),
        onPressed: enabled ? _bound(action) : null,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(44, 44),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          foregroundColor: color,
          backgroundColor: selected == true
              ? SelahColors.surfaceEmphasisFill
              : Colors.transparent,
          side: BorderSide(
            color: selected == true
                ? SelahColors.surfaceEmphasisBorder
                : SelahColors.surfaceBorder,
            width: selected == true ? 1 : .6,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 17, color: color.withValues(alpha: .65)),
              const SizedBox(width: 9),
            ],
            Expanded(
              child: Text(
                label,
                semanticsLabel: semanticLabel,
                textAlign: centered ? TextAlign.center : TextAlign.start,
                style: SelahText.body(size: 12.5, color: color),
              ),
            ),
            if (showChevron) ...[
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                size: 17,
                color: color.withValues(alpha: .4),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _card(List<Widget> children) => Container(
    padding: EdgeInsets.all(SelahCardMetrics.comparisonPadding),
    decoration: BoxDecoration(
      color: SelahColors.surfaceFill,
      borderRadius: BorderRadius.circular(SelahCardMetrics.comparisonRadius),
      border: Border.all(color: SelahColors.surfaceBorder),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(height: 13),
          children[i],
        ],
      ],
    ),
  );
  Widget _button(
    String id,
    String label,
    VoidCallback? action, {
    bool primary = false,
    IconData? icon,
    bool alignStart = false,
  }) => OutlinedButton(
    key: ValueKey(id),
    onPressed: action == null ? null : _bound(action),
    style: OutlinedButton.styleFrom(
      minimumSize: const Size(48, 48),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
      foregroundColor: primary ? SelahColors.onLake : SelahColors.inkColor,
      disabledForegroundColor: SelahColors.foregroundMuted.withValues(
        alpha: .5,
      ),
      backgroundColor: primary ? SelahColors.lake : Colors.transparent,
      side: BorderSide(
        color: primary
            ? SelahColors.surfaceEmphasisBorder
            : SelahColors.surfaceBorder,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    child: Row(
      mainAxisSize: alignStart ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: alignStart
          ? MainAxisAlignment.start
          : MainAxisAlignment.center,
      children: [
        if (icon != null) ...[Icon(icon, size: 22), const SizedBox(width: 12)],
        Flexible(
          child: label.contains('\n')
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label.split('\n').first,
                      style: SelahText.button(
                        size: 14,
                        color: SelahColors.foreground,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      label.substring(label.indexOf('\n') + 1),
                      style: SelahText.subtext(size: 12),
                    ),
                  ],
                )
              : Text(
                  label,
                  textAlign: alignStart ? TextAlign.start : TextAlign.center,
                  style: SelahText.button(
                    size: 14,
                    color: action == null
                        ? SelahColors.foregroundMuted.withValues(alpha: .5)
                        : primary
                        ? SelahColors.onLake
                        : SelahColors.foreground,
                  ),
                ),
        ),
        if (alignStart) ...[
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right, size: 18),
        ],
      ],
    ),
  );
  Widget _choices(
    List<String> labels,
    int selected,
    ValueChanged<int> change,
    String id,
  ) {
    final callbacks = [
      for (var i = 0; i < labels.length; i++)
        _bound(() => _act(() => change(i))),
    ];
    return labels.length <= 4
        ? TweenAnimationBuilder<double>(
            tween: Tween<double>(end: selected.toDouble()),
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : SelahSegmentedMotion.selectionDuration,
            curve: SelahSegmentedMotion.selectionCurve,
            builder: (context, position, _) => SelahSegmentedToggle(
              labels: labels,
              position: position,
              labelSize: labels.length == 2 ? 13 : 11.5,
              segmentKeys: [
                for (var i = 0; i < labels.length; i++) ValueKey('${id}_$i'),
              ],
              onChanged: (i) {
                if (i >= 0 && i < callbacks.length) callbacks[i]();
              },
            ),
          )
        : Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < labels.length; i++)
                Semantics(
                  selected: selected == i,
                  child: _button(
                    '${id}_$i',
                    labels[i],
                    () => _act(() => change(i)),
                    primary: selected == i,
                  ),
                ),
            ],
          );
  }

  String _stateLabel(DraftJourneyState state) => switch (state) {
    DraftJourneyState.received => 'Received request',
    DraftJourneyState.sent => 'Request sent',
    DraftJourneyState.preparing => 'Preparing together · place reserved',
    DraftJourneyState.active => 'Active Journey',
    DraftJourneyState.pauseRequested => 'Pause requested · place occupied',
    DraftJourneyState.paused => 'Paused Journey',
    DraftJourneyState.resumeRequested => 'Resume requested · still Paused',
    DraftJourneyState.ended => 'Ended Journey · history retained',
  };
}

/// Touch ends the opening cue before the bar begins its existing breathing
/// interaction. The Listener observes only child hits and owns no gesture.

// Ephemeral display adapter: the pending invite supplies its own name/label.
// No relationship code, server link timestamp or saved record is fabricated.
class _InvitedShepherdPerson extends MentorLinkedPerson {
  _InvitedShepherdPerson({
    required super.id,
    required String fullName,
    required this.relation,
    required super.isMain,
  }) : super(firstName: fullName);
  final String? relation;
  @override
  String? get relationshipLabel => relation;
}
