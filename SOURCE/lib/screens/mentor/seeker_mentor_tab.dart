// Seeker-side canonical owner for Shepherd relationship management.
//
// The Founder-approved production experience is the vertical, Main-first
// Shepherd page. Retired comparison designs were removed only after device
// acceptance under the governed promotion gate.

import 'package:flutter/material.dart';
import '../../dev/selah_app_gold_preview.dart';

import '../../dev/selah_dev_scenario.dart';
import '../../data/selah_release_gates.dart';
import '../../services/selah_auth.dart';
import '../../services/selah_account_state.dart';
import '../../services/selah_developer_access.dart';
import '../../services/selah_mentor_link_service.dart';
import '../../state/app_state.dart';
import '../../theme/selah_colors.dart';
import '../../widgets/selah_loading.dart';
import 'link_shepherd_panel.dart';
import 'family_messaging_screens.dart';
import 'seeker_shepherd_designs.dart';

typedef ShepherdLinksLoader =
    Future<SelahSourceResult<List<MentorLinkedPerson>>> Function();
typedef ShepherdActivityLoader =
    Future<SelahSourceResult<Map<String, List<ShepherdActivity>>>> Function();
typedef ShepherdHistoryConsentLoader =
    Future<SelahSourceResult<ShepherdHistoryConsentState>> Function({
      required String shepherdId,
      required bool shepherdIsMain,
      bool? enabled,
    });
typedef ShepherdJourneyAccessLoader =
    Future<SelahSourceResult<List<ShepherdJourneyAccessState>>> Function({
      required String shepherdId,
      String? attemptId,
      bool? enabled,
      bool? chatEnabled,
    });

class SeekerMentorTab extends StatefulWidget {
  final ShepherdLinksLoader? linksLoader;
  final ShepherdActivityLoader? activityLoader;
  final ShepherdHistoryConsentLoader? historyConsentLoader;
  final ShepherdJourneyAccessLoader? journeyAccessLoader;
  final Future<SelahSourceResult<List<PendingInvite>>> Function()?
  pendingInvitesLoader;

  /// Frozen only by governed visual fixtures. Production uses wall time.
  final DateTime? comparisonNow;

  const SeekerMentorTab({
    super.key,
    this.linksLoader,
    this.activityLoader,
    this.historyConsentLoader,
    this.journeyAccessLoader,
    this.pendingInvitesLoader,
    this.comparisonNow,
  });

  @override
  State<SeekerMentorTab> createState() => _SeekerMentorTabState();
}

class _SeekerMentorTabState extends State<SeekerMentorTab> {
  bool _loading = true;
  bool _linksAvailable = true;
  bool _activityAvailable = true;
  List<MentorLinkedPerson> _linked = const [];
  Map<String, List<ShepherdActivity>> _activity = const {};
  List<MentorLinkedPerson>? _previewPeople;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    SelahDevScenario.instance.addListener(_onScenarioChange);
    SelahDeveloperAccess.authorizationChanges.addListener(_onAuthorityChange);
    SelahMentorLinkService.linkRevision.addListener(_onLinkRevision);
    _load();
  }

  @override
  void dispose() {
    SelahDevScenario.instance.removeListener(_onScenarioChange);
    SelahDeveloperAccess.authorizationChanges.removeListener(
      _onAuthorityChange,
    );
    SelahMentorLinkService.linkRevision.removeListener(_onLinkRevision);
    super.dispose();
  }

  void _onScenarioChange() {
    _onAuthorityChange();
  }

  void _onAuthorityChange() {
    if (!mounted) return;
    // Withdraw fixture display and outstanding results before refreshing.
    setState(() {
      _previewPeople = null;
      _linked = const [];
      _activity = const {};
    });
    _load();
  }

  void _onLinkRevision() {
    if (mounted) _load();
  }

  List<MentorLinkedPerson> get _people {
    final dev = SelahDevScenario.instance;
    if (!dev.shepherdOverride) return _linked;
    final locallyManaged = _previewPeople;
    if (locallyManaged != null) return locallyManaged;
    final count = dev.shepherdCount;
    if (count == 0) return const [];
    final start = dev.mainShepherd ? 0 : 1;
    return [
      for (
        var index = start;
        index < start + count && index < SelahDevScenario.fakeShepherds.length;
        index++
      )
        MentorLinkedPerson(
          id: 'dev-shepherd-$index',
          firstName: SelahDevScenario.fakeShepherds[index].name,
          relationship: SelahDevScenario.fakeShepherds[index].relationship,
          isMain: dev.mainShepherd && index == 0,
          linkedAt: DateTime(2026, 7, 12 + index),
        ),
    ];
  }

  MentorLinkedPerson _withMainStatus(
    MentorLinkedPerson person, {
    required bool isMain,
  }) => MentorLinkedPerson(
    id: person.id,
    firstName: person.firstName,
    isMain: isMain,
    relationship: person.relationship,
    linkedAt: person.linkedAt,
  );

  Future<bool> _previewMakeMain(String shepherdId) async {
    if (!mounted || !SelahDevScenario.instance.shepherdOverride) return false;
    final people = List<MentorLinkedPerson>.of(_people);
    if (!people.any((person) => person.id == shepherdId)) return false;
    setState(() {
      _previewPeople = [
        for (final person in people)
          _withMainStatus(person, isMain: person.id == shepherdId),
      ];
    });
    return true;
  }

  Future<bool> _previewClearMain(String shepherdId) async {
    if (!mounted || !SelahDevScenario.instance.shepherdOverride) return false;
    final people = List<MentorLinkedPerson>.of(_people);
    final target = people.where((person) => person.id == shepherdId);
    if (target.isEmpty || !target.first.isMain) return false;
    setState(() {
      _previewPeople = [
        for (final person in people)
          _withMainStatus(
            person,
            isMain: person.id == shepherdId ? false : person.isMain,
          ),
      ];
    });
    return true;
  }

  Future<String?> _previewRemove(String shepherdId) async {
    if (!mounted || !SelahDevScenario.instance.shepherdOverride) {
      return 'This Shepherd preview is no longer available.';
    }
    final people = List<MentorLinkedPerson>.of(_people);
    if (!people.any((person) => person.id == shepherdId)) {
      return 'This Shepherd could not be removed right now.';
    }
    setState(() {
      _previewPeople = people
          .where((person) => person.id != shepherdId)
          .toList(growable: false);
    });
    return null;
  }

  List<ShepherdActivity> _activityFor(MentorLinkedPerson person) {
    if (SelahDevScenario.instance.shepherdOverride) {
      return SelahDevScenario.fakeActivityFor(person.id);
    }
    return _activity[person.id] ?? const [];
  }

  ShepherdHistoryConsentLoader get _consentLoader =>
      widget.historyConsentLoader ??
      SelahMentorLinkService.shepherdHistoryConsent;

  ShepherdJourneyAccessLoader get _journeyAccessLoader =>
      widget.journeyAccessLoader ??
      SelahMentorLinkService.shepherdJourneyAccess;

  Future<void> _load() async {
    final request = ++_loadGeneration;
    final accountGeneration = SelahAccountState.generation;
    final accountId = SelahAccountState.userId;
    bool canPublish() =>
        mounted &&
        request == _loadGeneration &&
        !SelahAccountState.isSigningOut &&
        accountGeneration == SelahAccountState.generation &&
        accountId == SelahAccountState.userId &&
        !SelahDevScenario.instance.shepherdOverride;
    if (SelahDevScenario.instance.shepherdOverride) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    if (mounted) setState(() => _loading = true);
    final linksResult =
        await (widget.linksLoader?.call() ??
            SelahMentorLinkService.fetchLinkedPeopleResult(asMentor: false));
    if (!canPublish()) return;

    if (linksResult.isUnavailable) {
      setState(() {
        _linksAvailable = false;
        _activityAvailable = true;
        _linked = const [];
        _activity = const {};
        _loading = false;
      });
      return;
    }

    final linked = linksResult.valueOr(const []);
    if (linked.isEmpty) {
      setState(() {
        _linksAvailable = true;
        _activityAvailable = true;
        _linked = const [];
        _activity = const {};
        _loading = false;
      });
      return;
    }

    final activityResult =
        await (widget.activityLoader?.call() ??
            SelahMentorLinkService.fetchActivityResult());
    if (!canPublish()) return;
    setState(() {
      _linksAvailable = true;
      _activityAvailable = activityResult.isAvailable;
      _linked = linked;
      _activity = activityResult.valueOr(const {});
      _loading = false;
    });
  }

  void _openAdd() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LinkShepherdScreen(
          onLinked: _load,
          gender: AppState.instance.gender,
        ),
      ),
    );
  }

  bool get _familyMessagingVisible =>
      SelahReleaseGates.familyMessagingEnabled ||
      SelahDevScenario.instance.shepherdOverride;

  void _openFamilyMessages() {
    if (!_familyMessagingVisible) return;
    final preview = !SelahReleaseGates.familyMessagingEnabled;
    final seekerId = SelahAuth.currentUser?.id ?? 'dev-seeker-adam';
    final seekerName = AppState.instance.name?.trim().isNotEmpty == true
        ? AppState.instance.name!.trim()
        : 'James';
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SelahShepherdCircleScreen(
          seekerId: seekerId,
          seekerFirstName: seekerName,
          viewerIsSeeker: true,
          preview: preview,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final preview = SelahDevScenario.instance.shepherdOverride;
    final showSpinner = _loading && !preview;
    return Container(
      decoration: SelahAppGoldDecoration(
        gradient: SelahColors.genderGradient(AppState.instance.gender),
      ),
      child: SafeArea(
        child: showSpinner
            ? const SelahLoading()
            : SeekerShepherdPage(
                people: _people,
                activity: {
                  for (final person in _people) person.id: _activityFor(person),
                },
                linksAvailable: preview || _linksAvailable,
                activityAvailable: preview || _activityAvailable,
                onRetry: _load,
                onAdd: _openAdd,
                onOpenMessages: _familyMessagingVisible && _people.isNotEmpty
                    ? _openFamilyMessages
                    : null,
                pendingInvitesLoader: widget.pendingInvitesLoader,
                historyConsentLoader: preview ? null : _consentLoader,
                journeyAccessLoader: preview ? null : _journeyAccessLoader,
                historyConsentPreview: preview,
                previewActiveJourneyCount: preview
                    ? SelahDevScenario
                          .instance
                          .shepherdPreviewActiveJourneyCount
                    : 1,
                makeMainShepherd: preview
                    ? _previewMakeMain
                    : SelahMentorLinkService.setMainShepherd,
                clearMainShepherd: preview
                    ? _previewClearMain
                    : SelahMentorLinkService.clearMainShepherd,
                removeShepherd: preview
                    ? _previewRemove
                    : SelahMentorLinkService.removeShepherd,
                onChanged: preview ? null : _load,
                comparisonNow: widget.comparisonNow,
              ),
      ),
    );
  }
}
