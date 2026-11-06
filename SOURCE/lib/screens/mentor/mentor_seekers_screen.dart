// Shepherd-side Seeker Workspace roster — inherited decision 224 F4 / 051 Phase 2.
//
// Server truth is split by role before rich Journey context is assembled.
// Main Shepherdships are always represented by caller-scoped participation;
// Additional Shepherdships gain that row only while the Seeker includes them
// in the active Journey. Main-only attention and decision states stay out of
// the neutral Additional section.

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import '../../dev/selah_app_gold_preview.dart';

import '../../dev/selah_dev_scenario.dart';
import '../../data/selah_release_gates.dart';
import '../../models/seeker_profile.dart';
import '../../services/selah_discovery_service.dart';
import '../../services/selah_developer_access.dart';
import '../../services/selah_shepherd_seeker_roster_resolver.dart';
import '../../services/selah_mentor_journey_service.dart';
import '../../services/selah_mentor_link_service.dart';
import '../../state/app_state.dart';
import '../../theme/selah_colors.dart';
import '../../theme/selah_text.dart';
import '../../widgets/selah_loading.dart';
import '../../widgets/selah_profile_image.dart';
import '../../widgets/selah_state_widgets.dart';
import 'mentor_gn_shared.dart';
import 'mentor_invite_seeker_screen.dart';
import 'family_messaging_screens.dart';
import 'mentor_seeker_workspace_screen.dart';

typedef ShepherdLinksLoader =
    Future<SelahSourceResult<List<MentorLinkedPerson>>> Function();
typedef ShepherdRosterContextLoader =
    Future<SelahSourceResult<ShepherdSeekerRosterContext>> Function(
      List<MentorLinkedPerson> people,
    );
typedef ShepherdRosterProfilesLoader =
    Future<List<SeekerProfile>> Function(List<String> ids);

class MentorSeekersScreen extends StatefulWidget {
  final bool hasShepherdOne;
  final ShepherdLinksLoader? loadLinks;
  final ShepherdRosterContextLoader? loadContext;
  final ShepherdRosterProfilesLoader? loadProfiles;
  final VoidCallback? onOpenNetwork;
  final String? requestedSeekerId;
  final int selectionRequest;

  const MentorSeekersScreen({
    super.key,
    this.hasShepherdOne = false,
    this.loadLinks,
    this.loadContext,
    this.loadProfiles,
    this.onOpenNetwork,
    this.requestedSeekerId,
    this.selectionRequest = 0,
  });

  @override
  State<MentorSeekersScreen> createState() => _MentorSeekersScreenState();
}

class _MentorSeekersScreenState extends State<MentorSeekersScreen> {
  static const _resolver = SelahShepherdSeekerRosterResolver();

  bool _loading = true;
  bool _hasLinks = false;
  bool _hasContext = false;
  bool _linksUnavailable = false;
  bool _contextUnavailable = false;
  int _loadGeneration = 0;
  List<MentorLinkedPerson> _people = const [];
  ShepherdSeekerRosterContext _context = const ShepherdSeekerRosterContext();
  Set<String> _contextRoleKeys = const {};
  Map<String, String> _photos = const {};

  bool get _usesInjectedData =>
      widget.loadLinks != null ||
      widget.loadContext != null ||
      widget.loadProfiles != null;

  @override
  void initState() {
    super.initState();
    AppState.instance.addListener(_onPresentationChange);
    SelahMentorLinkService.linkRevision.addListener(_onLinksChanged);
    if (SelahDeveloperAccess.canUseDeveloperTools) {
      SelahDevScenario.instance.addListener(_onPresentationChange);
    }
    _load();
  }

  @override
  void dispose() {
    AppState.instance.removeListener(_onPresentationChange);
    SelahMentorLinkService.linkRevision.removeListener(_onLinksChanged);
    SelahDevScenario.instance.removeListener(_onPresentationChange);
    super.dispose();
  }

  void _onPresentationChange() {
    if (mounted) setState(() {});
  }

  void _onLinksChanged() => _load();

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    if (mounted) setState(() => _loading = true);
    final linksLoader =
        widget.loadLinks ??
        () => SelahMentorLinkService.fetchLinkedPeopleResult(asMentor: true);
    final linksResult = await linksLoader();
    if (!mounted || generation != _loadGeneration) return;

    if (linksResult.isUnavailable) {
      setState(() {
        _linksUnavailable = true;
        _loading = false;
      });
      return;
    }

    final people = linksResult.valueOr(const []);
    final roleKeys = {
      for (final person in people) '${person.id}:${person.isMain}',
    };
    if (!_usesInjectedData)
      AppState.instance.setMentorRealLinkedSeekers(people);

    SelahSourceResult<ShepherdSeekerRosterContext> contextResult;
    if (people.isEmpty) {
      contextResult = const SelahSourceResult.available(
        ShepherdSeekerRosterContext(),
      );
    } else {
      final contextLoader =
          widget.loadContext ??
          SelahMentorJourneyService.fetchRosterContextResult;
      contextResult = await contextLoader(people);
      if (!mounted || generation != _loadGeneration) return;
    }

    setState(() {
      _people = people;
      _hasLinks = true;
      _linksUnavailable = false;
      _loading = false;
      if (contextResult.isAvailable) {
        _context = contextResult.valueOr(const ShepherdSeekerRosterContext());
        _contextRoleKeys = roleKeys;
        _hasContext = true;
        _contextUnavailable = false;
      } else {
        _contextUnavailable = true;
        if (_contextRoleKeys.length != roleKeys.length ||
            !_contextRoleKeys.containsAll(roleKeys)) {
          _hasContext = false;
        }
      }
    });
    _loadPhotos(people, generation);
  }

  Future<void> _loadPhotos(
    List<MentorLinkedPerson> people,
    int generation,
  ) async {
    if (people.isEmpty) {
      if (mounted && generation == _loadGeneration) {
        setState(() => _photos = const {});
      }
      return;
    }
    final loader = widget.loadProfiles ?? SelahDiscoveryService.profilesByIds;
    final profiles = await loader(people.map((person) => person.id).toList());
    if (!mounted || generation != _loadGeneration) return;
    setState(
      () => _photos = {
        for (final profile in profiles)
          if (profile.photos.isNotEmpty) profile.id: profile.photos.first,
      },
    );
  }

  List<MentorLinkedPerson> get _visiblePeople {
    if (!SelahDeveloperAccess.canUseDeveloperTools || _usesInjectedData) {
      return _people;
    }
    return SelahDevScenario.composeMentorWards(real: _people);
  }

  ShepherdSeekerRosterContext get _visibleContext {
    if (!SelahDeveloperAccess.canUseDeveloperTools || _usesInjectedData) {
      return _context;
    }
    final journeys = SelahDevScenario.composeMentorJourneys(
      wards: _visiblePeople,
      real: _context.journeys,
    );
    final stagedReviews = SelahDevScenario.mentorOpenReviewIds(journeys);
    return ShepherdSeekerRosterContext(
      journeys: journeys,
      openReviewMatchIds: {..._context.openReviewMatchIds, ...stagedReviews},
      waitingSinceByMatchId: {
        ..._context.waitingSinceByMatchId,
        for (final matchId in stagedReviews)
          if (!_context.waitingSinceByMatchId.containsKey(matchId))
            matchId: DateTime.now(),
      },
    );
  }

  Future<void> _openInvite() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const MentorInviteSeekerScreen()));
    if (mounted) _load();
  }

  bool get _familyMessagingVisible =>
      SelahReleaseGates.familyMessagingEnabled ||
      SelahDeveloperAccess.canUseDeveloperTools;

  Widget _workspacePage(ShepherdSeekerRosterEntry entry) {
    final developerPreview =
        SelahDeveloperAccess.canUseDeveloperTools &&
        (entry.currentJourney?.isMock == true ||
            entry.person.id.startsWith('dev-ws'));
    return MentorSeekerWorkspaceScreen(
      key: ValueKey('shepherd-seeker-page-${entry.person.id}'),
      entry: entry,
      embedded: true,
      hasShepherdOne: widget.hasShepherdOne,
      photoUrl: _photos[entry.person.id] ?? '',
      loadSummaries: developerPreview
          ? (_) async => SelahSourceResult.available([
              ShepherdAttemptSummary(
                attemptId:
                    'dev-summary-${entry.currentJourney?.matchId ?? entry.person.id}',
                startedAt: DateTime.now().subtract(const Duration(days: 18)),
                endedAt: null,
                ended: false,
              ),
            ])
          : null,
      onOpenNetwork: widget.onOpenNetwork == null
          ? null
          : () {
              GNContext.instance.selectSeeker(entry.person.id);
              widget.onOpenNetwork!();
            },
      onOpenFamilyChat: _familyMessagingVisible
          ? () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => SelahShepherdCircleScreen(
                  seekerId: entry.person.id,
                  seekerFirstName: entry.person.firstName,
                  preview: !SelahReleaseGates.familyMessagingEnabled,
                ),
              ),
            )
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final people = _visiblePeople;
    final developerPreview = SelahDeveloperAccess.canUseDeveloperTools;
    final hasMain = people.any((person) => person.isMain);
    final hasAuthoritativeRows = _hasLinks && (!hasMain || _hasContext);
    final initialUnavailable =
        !hasAuthoritativeRows && (_linksUnavailable || _contextUnavailable);

    if ((_loading && !_hasLinks) || (!_hasLinks && !initialUnavailable)) {
      return _shell(const SelahLoading());
    }
    // Developer Access owns a complete local preview model. A failed live
    // roster read must not replace its deliberate zero-Seeker state with a
    // production error page (or cover local mock Seekers with the same error).
    // Public accounts retain the honest unavailable state because an unknown
    // live roster must never be represented as an authoritative empty roster.
    if (initialUnavailable && !developerPreview) {
      return _shell(
        SelahUnknownErrorState(contentName: 'Seekers', onRetry: _load),
      );
    }

    final resolution = _resolver.resolve(
      linkedPeople: people,
      context: _visibleContext,
    );
    return ShepherdSeekerRosterView(
      resolution: resolution,
      requestedSeekerId: widget.requestedSeekerId,
      selectionRequest: widget.selectionRequest,
      photos: _photos,
      lastKnown:
          !developerPreview && (_linksUnavailable || _contextUnavailable),
      onRetry: _load,
      onInvite: _openInvite,
      onOpenSeeker: (_) {},
      pageBuilder: _workspacePage,
    );
  }

  Widget _shell(Widget child) => Container(
    decoration: SelahAppGoldDecoration(
      gradient: SelahColors.genderGradient(AppState.instance.gender),
    ),
    child: SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: _SeekersHeader(onAdd: _openInvite),
          ),
          Expanded(child: child),
        ],
      ),
    ),
  );
}

/// Pure roster presentation used by production, focused widget tests and the
/// frozen-clock visual matrix.
class ShepherdSeekerRosterView extends StatelessWidget {
  final ShepherdSeekerRosterResolution resolution;

  /// A caller-owned canvas for isolated presentation previews. Ordinary
  /// owners omit this and retain the current gender/gold app decoration.
  final Decoration? decoration;
  final Map<String, String> photos;
  final bool lastKnown;
  final VoidCallback onRetry;
  final VoidCallback onInvite;
  final ValueChanged<ShepherdSeekerRosterEntry> onOpenSeeker;
  final Widget Function(ShepherdSeekerRosterEntry)? pageBuilder;
  final String? requestedSeekerId;
  final int selectionRequest;

  /// Presentation-only opt-in; the ordinary roster keeps its original header.
  final Alignment titleAlignment;

  /// Optional parent-owned heading for a bounded presentation wrapper.
  /// Ordinary roster callers keep the original header.
  final bool showHeader;

  const ShepherdSeekerRosterView({
    super.key,
    required this.resolution,
    this.photos = const {},
    this.lastKnown = false,
    required this.onRetry,
    required this.onInvite,
    required this.onOpenSeeker,
    this.pageBuilder,
    this.requestedSeekerId,
    this.selectionRequest = 0,
    this.decoration,
    this.titleAlignment = Alignment.centerLeft,
    this.showHeader = true,
  });

  List<ShepherdSeekerRosterEntry> get _entries => [
    for (final section in resolution.mainSections) ...section.entries,
    ...resolution.additionalShepherdships,
  ];

  @override
  Widget build(BuildContext context) => Container(
    decoration:
        decoration ??
        SelahAppGoldDecoration(
          gradient: SelahColors.genderGradient(AppState.instance.gender),
        ),
    child: SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showHeader)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: _SeekersHeader(
                onAdd: onInvite,
                titleAlignment: titleAlignment,
              ),
            ),
          Expanded(
            child: resolution.isEmpty
                ? Padding(
                    padding: const EdgeInsets.only(bottom: 96),
                    child: const Center(child: _SeekersEmpty()),
                  )
                : Column(
                    children: [
                      if (requestedSeekerId != null &&
                          !_entries.any(
                            (entry) => entry.person.id == requestedSeekerId,
                          ))
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 2, 20, 8),
                          child: const SelahErrorBanner(
                            message:
                                'This Seeker is not available in your linked roster.',
                          ),
                        ),
                      if (lastKnown) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 2, 20, 8),
                          child: SelahErrorBanner(
                            message:
                                'The roster could not refresh. Showing last confirmed information.',
                            onRetry: onRetry,
                          ),
                        ),
                      ],
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 88),
                          child: _SeekerPager(
                            entries: _entries,
                            photos: photos,
                            pageBuilder: pageBuilder,
                            requestedSeekerId: requestedSeekerId,
                            selectionRequest: selectionRequest,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    ),
  );
}

class _SeekerPager extends StatefulWidget {
  const _SeekerPager({
    required this.entries,
    required this.photos,
    required this.pageBuilder,
    required this.requestedSeekerId,
    required this.selectionRequest,
  });

  final List<ShepherdSeekerRosterEntry> entries;
  final Map<String, String> photos;
  final Widget Function(ShepherdSeekerRosterEntry)? pageBuilder;
  final String? requestedSeekerId;
  final int selectionRequest;

  @override
  State<_SeekerPager> createState() => _SeekerPagerState();
}

class _SeekerPagerState extends State<_SeekerPager> {
  late final PageController _controller;
  int _page = 0;
  late String _currentSeekerId;
  String? _pendingSeekerId;
  int _jumpRevision = 0;

  @override
  void initState() {
    super.initState();
    _pendingSeekerId = widget.requestedSeekerId;
    final requested = _requestedIndex();
    if (requested >= 0) {
      _page = requested;
      _pendingSeekerId = null;
    }
    _controller = PageController(initialPage: _page);
    _currentSeekerId = widget.entries[_page].person.id;
  }

  int _requestedIndex() => _pendingSeekerId == null
      ? -1
      : widget.entries.indexWhere(
          (entry) => entry.person.id == _pendingSeekerId,
        );

  @override
  void didUpdateWidget(covariant _SeekerPager oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(
      oldWidget.entries.map((entry) => entry.person.id).toList(),
      widget.entries.map((entry) => entry.person.id).toList(),
    )) {
      _jumpRevision++;
    }
    if (widget.selectionRequest != oldWidget.selectionRequest ||
        widget.requestedSeekerId != oldWidget.requestedSeekerId) {
      // Invalidate queued jumps before any early return, including cancel or
      // an unavailable replacement target. Keep actual selection until commit.
      _jumpRevision++;
      _pendingSeekerId = widget.requestedSeekerId;
    }
    final retained = widget.entries.indexWhere(
      (entry) => entry.person.id == _currentSeekerId,
    );
    final requested = _requestedIndex();
    final next = requested >= 0
        ? requested
        : retained >= 0
        ? retained
        : _page.clamp(0, widget.entries.length - 1);
    if (next == _page && requested < 0) {
      _currentSeekerId = widget.entries[next].person.id;
      return;
    }
    final revision = ++_jumpRevision;
    final targetId = widget.entries[next].person.id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          revision == _jumpRevision &&
          _controller.hasClients &&
          next < widget.entries.length &&
          widget.entries[next].person.id == targetId) {
        setState(() {
          _page = next;
          _currentSeekerId = targetId;
          if (_pendingSeekerId == targetId) _pendingSeekerId = null;
        });
        _controller.jumpToPage(next);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Expanded(
        child: ShaderMask(
          key: const ValueKey('shepherd-seeker-page-bottom-fade'),
          blendMode: BlendMode.dstIn,
          shaderCallback: (bounds) {
            const fadeExtent = 26.0;
            final fadeStart = bounds.height <= fadeExtent
                ? 0.0
                : 1 - (fadeExtent / bounds.height);
            return LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: const [Colors.white, Colors.white, Colors.transparent],
              stops: [0, fadeStart, 1],
            ).createShader(bounds);
          },
          child: PageView.builder(
            key: const ValueKey('shepherd-seeker-page-view'),
            controller: _controller,
            physics: const BouncingScrollPhysics(),
            itemCount: widget.entries.length,
            onPageChanged: (value) => setState(() {
              _page = value;
              _currentSeekerId = widget.entries[value].person.id;
            }),
            itemBuilder: (context, index) {
              final entry = widget.entries[index];
              return Semantics(
                label:
                    'Seeker ${index + 1} of ${widget.entries.length}: '
                    '${entry.person.firstName}',
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child:
                      widget.pageBuilder?.call(entry) ??
                      _SeekerQuietSummary(
                        entry: entry,
                        photoUrl: widget.photos[entry.person.id] ?? '',
                      ),
                ),
              );
            },
          ),
        ),
      ),
      if (widget.entries.length > 1) ...[
        const SizedBox(height: 12),
        _SeekerPageDots(count: widget.entries.length, selected: _page),
        const SizedBox(height: 4),
      ],
    ],
  );
}

class _SeekerQuietSummary extends StatelessWidget {
  const _SeekerQuietSummary({required this.entry, required this.photoUrl});

  final ShepherdSeekerRosterEntry entry;
  final String photoUrl;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      key: ValueKey('shepherd-seeker-page-scroll-${entry.person.id}'),
      physics: const BouncingScrollPhysics(),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: constraints.maxHeight),
        child: Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _SeekerPageIdentity(entry: entry, photoUrl: photoUrl),
              _SeekerQuietSection(
                label: 'DETAILS',
                child: Column(
                  children: [
                    _SeekerQuietPair(
                      label: 'Status',
                      value: entry.needsAttention ? 'Needs you' : 'Active',
                      signal: entry.needsAttention,
                    ),
                    _SeekerQuietPair(
                      label: 'Linked',
                      value: entry.person.linkedDateLabel ?? 'Not recorded',
                    ),
                  ],
                ),
              ),
              _SeekerQuietSection(
                label: 'JOURNEY ACCESS',
                child: Column(
                  children: [
                    _SeekerQuietPair(
                      label: 'Role',
                      value: entry.person.isMain
                          ? 'Main Shepherd'
                          : 'Additional Shepherd',
                    ),
                    _SeekerQuietPair(
                      label: 'Current',
                      value: entry.contextLine,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _SeekerPageIdentity extends StatelessWidget {
  const _SeekerPageIdentity({required this.entry, required this.photoUrl});

  final ShepherdSeekerRosterEntry entry;
  final String photoUrl;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      children: [
        ClipOval(
          child: SizedBox.square(
            dimension: 72,
            child: SelahProfileImage(photoUrl, width: 72, height: 72),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(entry.person.firstName, style: SelahText.heading(size: 27)),
              const SizedBox(height: 3),
              Text(
                [
                  entry.person.relationshipLabel ?? 'Relationship not recorded',
                  entry.person.isMain ? 'Main Shepherd' : 'Additional Shepherd',
                ].join(' · '),
                style: SelahText.subtext(
                  size: 12.5,
                  color: SelahColors.ink(0.58),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _SeekerPageDots extends StatelessWidget {
  const _SeekerPageDots({required this.count, required this.selected});

  final int count;
  final int selected;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Seeker ${selected + 1} of $count',
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var index = 0; index < count; index++)
          AnimatedContainer(
            key: ValueKey('shepherd-seeker-page-dot-$index'),
            duration: const Duration(milliseconds: 180),
            width: index == selected ? 20 : 5,
            height: 5,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color: index == selected
                  ? SelahColors.journeyGold
                  : SelahColors.ink(0.25),
              borderRadius: BorderRadius.circular(20),
            ),
          ),
      ],
    ),
  );
}

class _SeekerQuietSection extends StatelessWidget {
  const _SeekerQuietSection({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 17, horizontal: 2),
    decoration: BoxDecoration(
      border: Border(top: BorderSide(color: SelahColors.ink(0.13))),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: SelahText.chapterLabel(color: SelahColors.ink(0.47)),
        ),
        const SizedBox(height: 10),
        child,
      ],
    ),
  );
}

class _SeekerQuietPair extends StatelessWidget {
  const _SeekerQuietPair({
    required this.label,
    required this.value,
    this.signal = false,
  });

  final String label;
  final String value;
  final bool signal;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: SelahText.subtext(size: 12.5, color: SelahColors.ink(0.46)),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: SelahText.body(
              size: 13,
              color: signal ? SelahColors.journeyGold : SelahColors.foreground,
            ),
          ),
        ),
      ],
    ),
  );
}

/// Mirrors the Seeker-side Shepherd header: the relationship owner page
/// keeps its add action beside the title instead of burying it in Profile or
/// repeating it at the bottom of the roster.
class _SeekersHeader extends StatelessWidget {
  final VoidCallback onAdd;
  final Alignment titleAlignment;

  const _SeekersHeader({
    required this.onAdd,
    this.titleAlignment = Alignment.centerLeft,
  });

  Widget _title() => Expanded(
    child: Text(
      'Seekers',
      key: const ValueKey('shepherd-seekers-title'),
      textAlign: titleAlignment.x > 0 ? TextAlign.right : TextAlign.left,
      style: SelahText.heading(size: 26),
    ),
  );

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (titleAlignment.x <= 0) ...[_title(), const SizedBox(width: 8)],
      Tooltip(
        message: 'Add a Seeker',
        excludeFromSemantics: true,
        child: Semantics(
          button: true,
          label: 'Add a Seeker',
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              key: const ValueKey('shepherd-seeker-add-top'),
              customBorder: const CircleBorder(),
              onTap: onAdd,
              child: SizedBox.square(
                dimension: 48,
                child: Center(
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: SelahColors.iconButtonBg,
                      border: Border.all(color: SelahColors.iconButtonBorder),
                    ),
                    child: Icon(
                      Icons.add_rounded,
                      size: 23,
                      color: SelahColors.foreground,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      if (titleAlignment.x > 0) ...[const SizedBox(width: 8), _title()],
    ],
  );
}

class _SeekersEmpty extends StatelessWidget {
  const _SeekersEmpty();

  @override
  Widget build(BuildContext context) => Column(
    key: const ValueKey('shepherd-seekers-empty'),
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(
        Icons.people_outline_rounded,
        color: SelahColors.surfaceSignal,
        size: 30,
      ),
      const SizedBox(height: 14),
      Text(
        'Add a Seeker',
        style: SelahText.heading(size: 15),
        textAlign: TextAlign.center,
      ),
    ],
  );
}
