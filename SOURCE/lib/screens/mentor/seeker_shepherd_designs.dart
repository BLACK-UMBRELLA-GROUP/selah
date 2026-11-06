import 'package:flutter/material.dart';
import '../../widgets/selah_switch.dart';
import 'dart:math' as math;

import '../../services/selah_mentor_link_service.dart';
import '../../theme/selah_colors.dart';
import '../../theme/selah_text.dart';
import '../../widgets/selah_state_widgets.dart';
import '../../widgets/selah_shepherd_invitation_dashboard.dart';
import '../../widgets/selah_shepherd_preview_lifetime.dart';
import '../../widgets/floating_nav_bar.dart';

// The roster may rebuild one frame after revocation. Its retained child
// callbacks must independently deny stale preview and asynchronous results.
mixin _ShepherdControlLifetime<T extends StatefulWidget> on State<T> {
  bool get shepherdPreviewRequested;
  void withdrawShepherdControl();

  late SelahShepherdPreviewLifetime shepherdLifetime;
  int shepherdRequest = 0;

  @override
  void initState() {
    super.initState();
    shepherdLifetime = SelahShepherdPreviewLifetime(
      preview: shepherdPreviewRequested,
    )..addListener(_withdrawShepherdControl);
  }

  void _withdrawShepherdControl() {
    if (!mounted) return;
    shepherdRequest++;
    setState(withdrawShepherdControl);
  }

  void replaceShepherdLifetime() {
    shepherdLifetime.removeListener(_withdrawShepherdControl);
    shepherdLifetime.revoke();
    shepherdLifetime.dispose();
    shepherdRequest++;
    shepherdLifetime = SelahShepherdPreviewLifetime(
      preview: shepherdPreviewRequested,
    )..addListener(_withdrawShepherdControl);
  }

  bool shepherdResultCurrent(
    int request,
    SelahShepherdPreviewLifetime lifetime,
  ) =>
      mounted &&
      identical(lifetime, shepherdLifetime) &&
      request == shepherdRequest &&
      lifetime.isCurrent;

  VoidCallback boundShepherdCallback(VoidCallback callback) {
    final lifetime = shepherdLifetime;
    return () {
      if (mounted &&
          identical(lifetime, shepherdLifetime) &&
          lifetime.isCurrent) {
        callback();
      }
    };
  }

  @override
  void dispose() {
    shepherdLifetime
      ..removeListener(_withdrawShepherdControl)
      ..dispose();
    super.dispose();
  }
}

const double _managerPageTopInset = 16;
const double _shepherdPageDotTail = 4;
const double _shepherdPageNavigationGap = 20;

String _recordedShepherdRole(MentorLinkedPerson person) => [
  if (person.relationshipLabel != null) person.relationshipLabel!,
  person.isMain ? 'Main Shepherd' : 'Additional Shepherd',
].join(' · ');

/// Founder-approved Seeker-side owner for Shepherd relationship management.
///
/// This deliberately does not resolve or render activity on roster cards.
/// Relationship movement belongs to Dashboard Updates; the detail route owns
/// the narrow per-Shepherd history allowed by the contract.
class ShepherdshipManagerView extends StatelessWidget {
  final List<MentorLinkedPerson> people;
  final bool linksAvailable;
  final VoidCallback onRetryLinks;
  final ValueChanged<MentorLinkedPerson> onOpenShepherd;
  final VoidCallback onAdd;
  final VoidCallback? onOpenMessages;
  final ShepherdPendingInvitesLoader? pendingInvitesLoader;
  final DateTime? comparisonNow;
  final Alignment titleAlignment;

  /// A presentation-only size override; null retains the ordinary optical size.
  final double? titleSize;

  const ShepherdshipManagerView({
    super.key,
    required this.people,
    required this.linksAvailable,
    required this.onRetryLinks,
    required this.onOpenShepherd,
    required this.onAdd,
    this.onOpenMessages,
    this.pendingInvitesLoader,
    this.comparisonNow,
    this.titleAlignment = Alignment.centerLeft,
    this.titleSize,
  });

  @override
  Widget build(BuildContext context) {
    final ordered = _ordered(people);
    final mainPeople = ordered.where((person) => person.isMain).toList();
    final main = mainPeople.isEmpty ? null : mainPeople.first;
    final additional = ordered.where((person) => !person.isMain).toList();

    Widget invitationLifecycle() => SelahShepherdInvitationDashboard(
      audience: SelahShepherdInvitationAudience.seeker,
      includeHeading: false,
      surface: SelahShepherdInvitationSurface.manager,
      pendingInvitesLoader: pendingInvitesLoader,
      comparisonNow: comparisonNow,
    );

    if (linksAvailable && ordered.isEmpty) {
      return CustomScrollView(
        key: const PageStorageKey('shepherdship-manager'),
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, _managerPageTopInset, 20, 0),
            sliver: SliverToBoxAdapter(
              child: _ManagerHeader(
                onAdd: onAdd,
                onOpenMessages: onOpenMessages,
                titleAlignment: titleAlignment,
                titleSize: titleSize,
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            sliver: SliverToBoxAdapter(child: invitationLifecycle()),
          ),
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 72),
              child: Center(child: const _ManagerEmpty()),
            ),
          ),
        ],
      );
    }

    return ListView(
      key: const PageStorageKey('shepherdship-manager'),
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(20, _managerPageTopInset, 20, 118),
      children: [
        _ManagerHeader(
          onAdd: onAdd,
          onOpenMessages: onOpenMessages,
          titleAlignment: titleAlignment,
          titleSize: titleSize,
        ),
        const SizedBox(height: 22),
        if (!linksAvailable)
          SelahEmptyState(
            key: const ValueKey('shepherd-links-unavailable'),
            icon: Icons.refresh_rounded,
            title: 'Shepherds could not be refreshed',
            message: 'Check your connection and try again.',
            ctaLabel: 'Try again',
            onCta: onRetryLinks,
          )
        else ...[
          if (main != null) ...[
            const _ManagerSectionLabel('MAIN SHEPHERD'),
            const SizedBox(height: 10),
            _ManagerShepherdCard(
              person: main,
              onOpen: () => onOpenShepherd(main),
            ),
          ],
          if (additional.isNotEmpty) ...[
            if (main != null) const SizedBox(height: 26),
            const _ManagerSectionLabel('ADDITIONAL SHEPHERDS'),
            const SizedBox(height: 10),
            for (var index = 0; index < additional.length; index++) ...[
              _ManagerShepherdCard(
                person: additional[index],
                onOpen: () => onOpenShepherd(additional[index]),
              ),
              if (index < additional.length - 1) const SizedBox(height: 10),
            ],
          ],
        ],
        const SizedBox(height: 28),
        invitationLifecycle(),
      ],
    );
  }
}

class _ManagerHeader extends StatelessWidget {
  final VoidCallback onAdd;
  final VoidCallback? onOpenMessages;
  final Alignment titleAlignment;
  final double? titleSize;

  const _ManagerHeader({
    required this.onAdd,
    this.onOpenMessages,
    this.titleAlignment = Alignment.centerLeft,
    this.titleSize,
  });

  Widget _title() => Expanded(
    child: Text(
      'Shepherd',
      key: const ValueKey('shepherd-manager-title'),
      textAlign: titleAlignment.x > 0 ? TextAlign.right : TextAlign.left,
      style: titleSize == null || titleSize == SelahText.pageTitleSize
          ? SelahText.pageTitle()
          : SelahText.heading(size: titleSize!),
    ),
  );

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (titleAlignment.x <= 0) _title(),
      if (onOpenMessages != null) ...[
        _HeaderCircleAction(
          key: const ValueKey('shepherd-family-messages-top'),
          label: 'Shepherd Circle',
          icon: Icons.forum_outlined,
          onTap: onOpenMessages!,
        ),
        const SizedBox(width: 4),
      ],
      const SizedBox(width: 8),
      Tooltip(
        message: 'Add a Shepherd',
        excludeFromSemantics: true,
        child: Semantics(
          button: true,
          label: 'Add a Shepherd',
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              key: const ValueKey('shepherd-add-top'),
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

class _HeaderCircleAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _HeaderCircleAction({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Tooltip(
    message: label,
    child: IconButton(
      onPressed: onTap,
      icon: Icon(icon, color: SelahColors.foreground),
      style: IconButton.styleFrom(
        backgroundColor: SelahColors.iconButtonBg,
        side: BorderSide(color: SelahColors.iconButtonBorder),
      ),
    ),
  );
}

class _ManagerSectionLabel extends StatelessWidget {
  final String label;

  const _ManagerSectionLabel(this.label);

  @override
  Widget build(BuildContext context) =>
      Text(label, style: SelahText.chapterLabel(color: SelahColors.ink(0.56)));
}

class _ManagerEmpty extends StatelessWidget {
  const _ManagerEmpty();

  @override
  Widget build(BuildContext context) => Column(
    key: const ValueKey('shepherdship-manager-empty'),
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(
        Icons.shield_outlined,
        key: const ValueKey('shepherd-empty-shield'),
        color: SelahColors.surfaceSignal,
        size: 30,
      ),
      const SizedBox(height: 14),
      Text(
        'Add a Shepherd',
        style: SelahText.heading(size: 15),
        textAlign: TextAlign.center,
      ),
    ],
  );
}

class _ManagerShepherdCard extends StatelessWidget {
  final MentorLinkedPerson person;
  final VoidCallback onOpen;

  const _ManagerShepherdCard({required this.person, required this.onOpen});

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Open ${person.firstName} Shepherd details',
    child: Material(
      key: ValueKey('shepherd-manager-card-${person.id}'),
      color: person.isMain
          ? SelahColors.surfaceEmphasisFill
          : SelahColors.surfaceFill,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: person.isMain
                  ? SelahColors.surfaceEmphasisBorder
                  : SelahColors.surfaceBorder,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ManagerMonogram(name: person.firstName, main: person.isMain),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(person.firstName, style: SelahText.heading(size: 18)),
                    const SizedBox(height: 3),
                    Text(
                      _recordedShepherdRole(person),
                      style: SelahText.subtext(size: 12.25),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      person.isMain
                          ? 'Asked to act on your Journey.'
                          : 'Supports you with your Journey.',
                      style: SelahText.body(size: 12.25),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      person.linkedDateLabel == null
                          ? 'Linked date not recorded'
                          : 'Linked ${person.linkedDateLabel}',
                      style: SelahText.subtext(
                        size: 11.25,
                        color: SelahColors.ink(0.44),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, color: SelahColors.ink(0.52)),
            ],
          ),
        ),
      ),
    ),
  );
}

class _ManagerMonogram extends StatelessWidget {
  final String name;
  final bool main;

  const _ManagerMonogram({required this.name, required this.main});

  @override
  Widget build(BuildContext context) => Container(
    width: 48,
    height: 48,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: SelahColors.actionFill.withValues(alpha: main ? 0.20 : 0.10),
      border: Border.all(
        color: SelahColors.actionFill.withValues(alpha: main ? 0.52 : 0.22),
      ),
    ),
    child: Text(
      name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase(),
      style: SelahText.heading(size: 19),
    ),
  );
}

List<MentorLinkedPerson> _ordered(List<MentorLinkedPerson> people) {
  final ordered = <MentorLinkedPerson>[];
  for (final person in people) {
    if (person.isMain) {
      ordered.add(person);
      break;
    }
  }
  ordered.addAll(people.where((person) => !person.isMain));
  return ordered;
}

typedef ShepherdPageHistoryConsentLoader =
    Future<SelahSourceResult<ShepherdHistoryConsentState>> Function({
      required String shepherdId,
      required bool shepherdIsMain,
      bool? enabled,
    });
typedef ShepherdPageJourneyAccessLoader =
    Future<SelahSourceResult<List<ShepherdJourneyAccessState>>> Function({
      required String shepherdId,
      String? attemptId,
      bool? enabled,
      bool? chatEnabled,
    });
typedef ShepherdMakeMainAction = Future<bool> Function(String shepherdId);
typedef ShepherdClearMainAction = Future<bool> Function(String shepherdId);
typedef ShepherdRemoveAction = Future<String?> Function(String shepherdId);

/// Canonical Seeker Shepherd page selected by the Founder.
///
/// Horizontal [PageView] movement is the sole Shepherd-to-Shepherd navigation.
/// Each Shepherd page is a fixed one-screen layout: Journey access is always
/// visible and vertical scrolling is deliberately not part of this surface.
class SeekerShepherdPage extends StatelessWidget {
  final List<MentorLinkedPerson> people;
  final Map<String, List<ShepherdActivity>> activity;
  final bool linksAvailable;
  final bool activityAvailable;
  final VoidCallback onRetry;
  final VoidCallback onAdd;
  final VoidCallback? onOpenMessages;
  final ShepherdPendingInvitesLoader? pendingInvitesLoader;
  final ShepherdPageHistoryConsentLoader? historyConsentLoader;
  final ShepherdPageJourneyAccessLoader? journeyAccessLoader;
  final bool historyConsentPreview;
  final int previewActiveJourneyCount;
  final ShepherdMakeMainAction? makeMainShepherd;
  final ShepherdClearMainAction? clearMainShepherd;
  final ShepherdRemoveAction? removeShepherd;
  final VoidCallback? onChanged;
  final DateTime? comparisonNow;

  /// Presentation-only opt-in. No relationship or permission policy changes.
  final Alignment titleAlignment;
  final double? titleSize;

  const SeekerShepherdPage({
    super.key,
    required this.people,
    required this.activity,
    required this.linksAvailable,
    required this.activityAvailable,
    required this.onRetry,
    required this.onAdd,
    this.onOpenMessages,
    this.pendingInvitesLoader,
    this.historyConsentLoader,
    this.journeyAccessLoader,
    this.historyConsentPreview = false,
    this.previewActiveJourneyCount = 1,
    this.makeMainShepherd,
    this.clearMainShepherd,
    this.removeShepherd,
    this.onChanged,
    this.comparisonNow,
    this.titleAlignment = Alignment.centerLeft,
    this.titleSize,
  });

  @override
  Widget build(BuildContext context) {
    final ordered = _ordered(people);
    if (!linksAvailable || ordered.isEmpty) {
      return ShepherdshipManagerView(
        people: ordered,
        linksAvailable: linksAvailable,
        onRetryLinks: onRetry,
        onOpenShepherd: (_) {},
        onAdd: onAdd,
        onOpenMessages: onOpenMessages,
        pendingInvitesLoader: pendingInvitesLoader,
        comparisonNow: comparisonNow,
        titleAlignment: titleAlignment,
        titleSize: titleSize,
      );
    }

    // Reserve the shared bar's full touch height, not only its smaller idle
    // height. The pager may sit in SafeArea(bottom: false), so retain the
    // actual bottom inset instead of assuming it was already consumed.
    final navigationReserve =
        math.max(
          MediaQuery.paddingOf(context).bottom,
          SelahNavBarMetrics.bottomInset,
        ) +
        SelahNavBarMetrics.height +
        _shepherdPageNavigationGap -
        _shepherdPageDotTail;
    return Column(
      key: const ValueKey('shepherd-page-quiet-sections'),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, _managerPageTopInset, 20, 0),
          child: _ManagerHeader(
            onAdd: onAdd,
            onOpenMessages: onOpenMessages,
            titleAlignment: titleAlignment,
            titleSize: titleSize,
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: navigationReserve),
            child: _ShepherdPager(
              key: const ValueKey('shepherd-pager'),
              people: ordered,
              activity: activity,
              activityAvailable: activityAvailable,
              onRetry: onRetry,
              historyConsentLoader: historyConsentLoader,
              journeyAccessLoader: journeyAccessLoader,
              historyConsentPreview: historyConsentPreview,
              previewActiveJourneyCount: previewActiveJourneyCount,
              makeMainShepherd: makeMainShepherd,
              clearMainShepherd: clearMainShepherd,
              removeShepherd: removeShepherd,
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}

class _ShepherdPager extends StatefulWidget {
  final List<MentorLinkedPerson> people;
  final Map<String, List<ShepherdActivity>> activity;
  final bool activityAvailable;
  final VoidCallback onRetry;
  final ShepherdPageHistoryConsentLoader? historyConsentLoader;
  final ShepherdPageJourneyAccessLoader? journeyAccessLoader;
  final bool historyConsentPreview;
  final int previewActiveJourneyCount;
  final ShepherdMakeMainAction? makeMainShepherd;
  final ShepherdClearMainAction? clearMainShepherd;
  final ShepherdRemoveAction? removeShepherd;
  final VoidCallback? onChanged;

  const _ShepherdPager({
    super.key,
    required this.people,
    required this.activity,
    required this.activityAvailable,
    required this.onRetry,
    required this.historyConsentLoader,
    required this.journeyAccessLoader,
    required this.historyConsentPreview,
    required this.previewActiveJourneyCount,
    required this.makeMainShepherd,
    required this.clearMainShepherd,
    required this.removeShepherd,
    required this.onChanged,
  });

  @override
  State<_ShepherdPager> createState() => _ShepherdPagerState();
}

class _ShepherdPagerState extends State<_ShepherdPager> {
  late final PageController _controller = PageController();
  int _page = 0;

  @override
  void didUpdateWidget(covariant _ShepherdPager oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldPage = _page.clamp(0, oldWidget.people.length - 1);
    final currentShepherdId = oldWidget.people[oldPage].id;
    final sameShepherdPage = widget.people.indexWhere(
      (person) => person.id == currentShepherdId,
    );
    final nextPage = sameShepherdPage >= 0
        ? sameShepherdPage
        : _page.clamp(0, widget.people.length - 1);
    if (nextPage == _page) return;
    _page = nextPage;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_controller.hasClients) _controller.jumpToPage(_page);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            key: const ValueKey('shepherd-page-view'),
            controller: _controller,
            physics: const BouncingScrollPhysics(),
            itemCount: widget.people.length,
            onPageChanged: (value) => setState(() => _page = value),
            itemBuilder: (context, index) {
              final person = widget.people[index];
              final activities = widget.activity[person.id] ?? const [];
              return Semantics(
                label:
                    'Shepherd ${index + 1} of ${widget.people.length}: '
                    '${person.firstName}',
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _ShepherdPageContent(
                    person: person,
                    activities: activities,
                    activityAvailable: widget.activityAvailable,
                    onRetry: widget.onRetry,
                    historyConsentLoader: widget.historyConsentLoader,
                    journeyAccessLoader: widget.journeyAccessLoader,
                    historyConsentPreview: widget.historyConsentPreview,
                    previewActiveJourneyCount: widget.previewActiveJourneyCount,
                    otherShepherds: widget.people
                        .where((candidate) => candidate.id != person.id)
                        .toList(growable: false),
                    makeMainShepherd: widget.makeMainShepherd,
                    clearMainShepherd: widget.clearMainShepherd,
                    removeShepherd: widget.removeShepherd,
                    onChanged: widget.onChanged,
                  ),
                ),
              );
            },
          ),
        ),
        if (widget.people.length > 1) ...[
          const SizedBox(height: 12),
          _ShepherdPageDots(count: widget.people.length, selected: _page),
          const SizedBox(height: _shepherdPageDotTail),
        ],
      ],
    );
  }
}

class _ShepherdPageContent extends StatelessWidget {
  final MentorLinkedPerson person;
  final List<ShepherdActivity> activities;
  final bool activityAvailable;
  final VoidCallback onRetry;
  final ShepherdPageHistoryConsentLoader? historyConsentLoader;
  final ShepherdPageJourneyAccessLoader? journeyAccessLoader;
  final bool historyConsentPreview;
  final int previewActiveJourneyCount;
  final List<MentorLinkedPerson> otherShepherds;
  final ShepherdMakeMainAction? makeMainShepherd;
  final ShepherdClearMainAction? clearMainShepherd;
  final ShepherdRemoveAction? removeShepherd;
  final VoidCallback? onChanged;

  const _ShepherdPageContent({
    required this.person,
    required this.activities,
    required this.activityAvailable,
    required this.onRetry,
    required this.historyConsentLoader,
    required this.journeyAccessLoader,
    required this.historyConsentPreview,
    required this.previewActiveJourneyCount,
    required this.otherShepherds,
    required this.makeMainShepherd,
    required this.clearMainShepherd,
    required this.removeShepherd,
    required this.onChanged,
  });

  ShepherdActivity? get obligation {
    for (final item in activities) {
      if (item.type == 'review_waiting' && item.line != null) return item;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => FittedBox(
      key: ValueKey('shepherd-page-static-${person.id}'),
      fit: BoxFit.scaleDown,
      alignment: Alignment.bottomCenter,
      child: SizedBox(
        width: constraints.maxWidth,
        child: IntrinsicHeight(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: _QuietSections(
              person: person,
              obligation: obligation,
              activityAvailable: activityAvailable,
              onRetry: onRetry,
              access: _access(),
              otherShepherds: otherShepherds,
              preview: historyConsentPreview,
              makeMainShepherd: makeMainShepherd,
              clearMainShepherd: clearMainShepherd,
              removeShepherd: removeShepherd,
              onChanged: onChanged,
              compact: constraints.maxHeight < 650,
            ),
          ),
        ),
      ),
    ),
  );

  Widget _access() => person.isMain
      ? _MainShepherdJourneyAccess(
          person: person,
          loader: journeyAccessLoader,
          historyConsentLoader: historyConsentLoader,
          preview: historyConsentPreview,
          previewActiveJourneyCount: previewActiveJourneyCount,
        )
      : _AdditionalShepherdJourneyAccess(
          person: person,
          loader: journeyAccessLoader,
          historyConsentLoader: historyConsentLoader,
          preview: historyConsentPreview,
          previewActiveJourneyCount: previewActiveJourneyCount,
        );
}

class _QuietSections extends StatelessWidget {
  final MentorLinkedPerson person;
  final ShepherdActivity? obligation;
  final bool activityAvailable;
  final VoidCallback onRetry;
  final Widget access;
  final List<MentorLinkedPerson> otherShepherds;
  final bool preview;
  final ShepherdMakeMainAction? makeMainShepherd;
  final ShepherdClearMainAction? clearMainShepherd;
  final ShepherdRemoveAction? removeShepherd;
  final VoidCallback? onChanged;
  final bool compact;

  const _QuietSections({
    required this.person,
    required this.obligation,
    required this.activityAvailable,
    required this.onRetry,
    required this.access,
    required this.otherShepherds,
    required this.preview,
    required this.makeMainShepherd,
    required this.clearMainShepherd,
    required this.removeShepherd,
    required this.onChanged,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) => Column(
    key: ValueKey('shepherd-quiet-sections-${person.id}'),
    mainAxisSize: MainAxisSize.max,
    mainAxisAlignment: MainAxisAlignment.start,
    children: [
      SizedBox(height: compact ? 2 : 4),
      Row(
        children: [
          _ShepherdMonogram(person: person, size: compact ? 58 : 64),
          const SizedBox(width: 14),
          Expanded(child: _ShepherdIdentity(person: person)),
        ],
      ),
      SizedBox(height: compact ? 10 : 14),
      _ShepherdDetailsStrip(person: person),
      SizedBox(height: compact ? 12 : 16),
      Divider(height: 1, color: SelahColors.ink(.12)),
      const SizedBox(height: 10),
      Expanded(child: access),
      if (!person.isMain && (!activityAvailable || obligation != null))
        _QuietSection(
          label: 'CURRENT OBLIGATION',
          compact: true,
          child: _ActivityTruth(
            available: activityAvailable,
            obligation: obligation,
            onRetry: onRetry,
            compact: true,
          ),
        ),
      const SizedBox(height: 10),
      _QuietSection(
        compact: true,
        child: _ShepherdManageActions(
          person: person,
          otherShepherds: otherShepherds,
          preview: preview,
          makeMainShepherd: makeMainShepherd,
          clearMainShepherd: clearMainShepherd,
          removeShepherd: removeShepherd,
          onChanged: onChanged,
          compact: compact,
        ),
      ),
    ],
  );
}

class _ShepherdDetailsStrip extends StatelessWidget {
  final MentorLinkedPerson person;

  const _ShepherdDetailsStrip({required this.person});

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('shepherd-details-strip'),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
    decoration: BoxDecoration(
      color: SelahColors.surfaceFill,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: SelahColors.surfaceBorder),
    ),
    child: Row(
      children: [
        const Icon(
          Icons.check_circle_outline_rounded,
          size: 17,
          color: SelahColors.journeyGold,
        ),
        const SizedBox(width: 7),
        Flexible(
          child: Text(
            'Active',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: SelahText.body(size: 12.25),
          ),
        ),
        Expanded(
          flex: 3,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text('Linked', style: SelahText.subtext(size: 10.75)),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  person.linkedDateLabel ?? 'Not recorded',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: SelahText.body(size: 12.25),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ShepherdManageActions extends StatefulWidget {
  final MentorLinkedPerson person;
  final List<MentorLinkedPerson> otherShepherds;
  final bool preview;
  final ShepherdMakeMainAction? makeMainShepherd;
  final ShepherdClearMainAction? clearMainShepherd;
  final ShepherdRemoveAction? removeShepherd;
  final VoidCallback? onChanged;
  final bool compact;

  const _ShepherdManageActions({
    required this.person,
    required this.otherShepherds,
    required this.preview,
    required this.makeMainShepherd,
    required this.clearMainShepherd,
    required this.removeShepherd,
    required this.onChanged,
    this.compact = false,
  });

  @override
  State<_ShepherdManageActions> createState() => _ShepherdManageActionsState();
}

enum _ShepherdManageIntent { makeMain, clearMain, removeShepherd }

class _ShepherdManageActionsState extends State<_ShepherdManageActions> {
  bool _busy = false;
  _ShepherdManageIntent? _confirming;

  void _failure(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  void _ask(_ShepherdManageIntent intent) {
    if (_busy) return;
    setState(() => _confirming = intent);
  }

  void _cancel() {
    if (_busy) return;
    setState(() => _confirming = null);
  }

  Future<void> _makeMain() async {
    if (_busy) return;
    final action = widget.makeMainShepherd;
    if (action == null) {
      return _failure('Main Shepherd could not be changed right now.');
    }
    setState(() => _busy = true);
    final changed = await action(widget.person.id);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _confirming = changed ? null : _ShepherdManageIntent.makeMain;
    });
    if (!changed) return _failure("That didn't go through. Please try again.");
    widget.onChanged?.call();
  }

  Future<void> _clearMain() async {
    if (_busy) return;
    final action = widget.clearMainShepherd;
    if (action == null) {
      return _failure('Main Shepherd status could not be removed right now.');
    }
    setState(() => _busy = true);
    final changed = await action(widget.person.id);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _confirming = changed ? null : _ShepherdManageIntent.clearMain;
    });
    if (!changed) return _failure("That didn't go through. Please try again.");
    widget.onChanged?.call();
  }

  Future<void> _remove() async {
    if (_busy) return;
    final action = widget.removeShepherd;
    if (action == null) {
      return _failure('This Shepherd could not be removed right now.');
    }
    setState(() => _busy = true);
    final error = await action(widget.person.id);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _confirming = error == null ? null : _ShepherdManageIntent.removeShepherd;
    });
    if (error != null) return _failure(error);
    widget.onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (widget.person.isMain) ...[
          _actionOrConfirmation(
            intent: _ShepherdManageIntent.clearMain,
            actionKey: const ValueKey('shepherd-clear-main'),
            confirmationKey: const ValueKey('shepherd-clear-main-confirmation'),
            icon: Icons.shield_outlined,
            label: 'Remove as Main Shepherd',
            onConfirm: _clearMain,
          ),
          SizedBox(height: widget.compact ? 6 : 9),
        ],
        if (!widget.person.isMain) ...[
          _actionOrConfirmation(
            intent: _ShepherdManageIntent.makeMain,
            actionKey: const ValueKey('shepherd-make-main'),
            confirmationKey: const ValueKey('shepherd-make-main-confirmation'),
            icon: Icons.shield_outlined,
            label: 'Make Main Shepherd',
            onConfirm: _makeMain,
          ),
          SizedBox(height: widget.compact ? 6 : 9),
        ],
        _actionOrConfirmation(
          intent: _ShepherdManageIntent.removeShepherd,
          actionKey: const ValueKey('shepherd-remove'),
          confirmationKey: const ValueKey('shepherd-remove-confirmation'),
          icon: Icons.person_remove_outlined,
          label: 'Remove Shepherd',
          destructive: true,
          onConfirm: _remove,
        ),
      ],
    );
  }

  Widget _actionOrConfirmation({
    required _ShepherdManageIntent intent,
    required Key actionKey,
    required Key confirmationKey,
    required IconData icon,
    required String label,
    required Future<void> Function() onConfirm,
    bool destructive = false,
  }) {
    final confirming = _confirming == intent;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 140),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) =>
          FadeTransition(opacity: animation, child: child),
      child: confirming
          ? Row(
              key: confirmationKey,
              children: [
                Expanded(
                  child: _ManageActionButton(
                    label: 'Cancel',
                    compact: widget.compact,
                    onTap: _busy ? null : _cancel,
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: _ManageActionButton(
                    label: 'Confirm',
                    destructive: destructive,
                    compact: widget.compact,
                    onTap: _busy ? null : onConfirm,
                  ),
                ),
              ],
            )
          : _ManageActionButton(
              key: actionKey,
              icon: icon,
              label: label,
              destructive: destructive,
              compact: widget.compact,
              onTap: _busy ? null : () => _ask(intent),
            ),
    );
  }
}

class _ManageActionButton extends StatelessWidget {
  final IconData? icon;
  final String label;
  final bool destructive;
  final VoidCallback? onTap;
  final bool compact;

  const _ManageActionButton({
    super.key,
    this.icon,
    required this.label,
    this.destructive = false,
    this.compact = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final signal = destructive
        ? SelahColors.destructive
        : SelahColors.ink(0.68);
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          constraints: BoxConstraints(minHeight: compact ? 42 : 49),
          padding: EdgeInsets.symmetric(
            horizontal: 15,
            vertical: compact ? 8 : 11,
          ),
          decoration: BoxDecoration(
            color: destructive
                ? signal.withValues(alpha: 0.06)
                : Colors.white.withValues(alpha: 0.025),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: destructive
                  ? signal.withValues(alpha: 0.30)
                  : SelahColors.ink(0.16),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: signal),
                const SizedBox(width: 9),
              ],
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: SelahText.body(
                    size: 13,
                    color: destructive
                        ? SelahColors.destructive
                        : SelahColors.foreground,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MainShepherdJourneyAccess extends StatefulWidget {
  final MentorLinkedPerson person;
  final ShepherdPageJourneyAccessLoader? loader;
  final ShepherdPageHistoryConsentLoader? historyConsentLoader;
  final bool preview;
  final int previewActiveJourneyCount;

  const _MainShepherdJourneyAccess({
    required this.person,
    required this.loader,
    required this.historyConsentLoader,
    required this.preview,
    required this.previewActiveJourneyCount,
  });

  @override
  State<_MainShepherdJourneyAccess> createState() =>
      _MainShepherdJourneyAccessState();
}

class _MainShepherdJourneyAccessState extends State<_MainShepherdJourneyAccess>
    with _ShepherdControlLifetime<_MainShepherdJourneyAccess> {
  List<ShepherdJourneyAccessState>? _confirmed;
  bool _loading = false;
  bool _available = true;

  @override
  bool get shepherdPreviewRequested => widget.preview;

  @override
  void withdrawShepherdControl() {
    _confirmed = null;
    _loading = false;
    _available = false;
  }

  @override
  void initState() {
    super.initState();
    _resetAndLoad();
  }

  @override
  void didUpdateWidget(covariant _MainShepherdJourneyAccess oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.person.id != widget.person.id ||
        oldWidget.person.isMain != widget.person.isMain ||
        oldWidget.preview != widget.preview ||
        oldWidget.previewActiveJourneyCount !=
            widget.previewActiveJourneyCount ||
        oldWidget.loader != widget.loader ||
        oldWidget.historyConsentLoader != widget.historyConsentLoader) {
      replaceShepherdLifetime();
      _resetAndLoad();
    }
  }

  void _resetAndLoad() {
    shepherdRequest++;
    _confirmed = null;
    _loading = false;
    _available = true;
    if (widget.preview) {
      if (!shepherdLifetime.canPreview) {
        _available = false;
        return;
      }
      _confirmed = _previewJourneyAccessStates(
        widget.previewActiveJourneyCount,
        mainShepherd: true,
      );
      return;
    }
    if (!shepherdLifetime.isCurrent) {
      _available = false;
      return;
    }
    _loading = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!mounted || !shepherdLifetime.isCurrent) return;
    final request = ++shepherdRequest;
    final lifetime = shepherdLifetime;
    final loader = widget.loader;
    if (loader == null) {
      if (!shepherdResultCurrent(request, lifetime)) return;
      setState(() {
        _loading = false;
        _available = false;
      });
      return;
    }
    if (!_loading) setState(() => _loading = true);
    SelahSourceResult<List<ShepherdJourneyAccessState>> result;
    try {
      result = await loader(shepherdId: widget.person.id);
    } catch (error) {
      debugPrint('SELAH Main Shepherd Journey access read failed — $error');
      if (!shepherdResultCurrent(request, lifetime)) return;
      setState(() {
        _loading = false;
        _available = false;
      });
      return;
    }
    if (!shepherdResultCurrent(request, lifetime)) return;
    final states = result.valueOrNull;
    final valid =
        result.isAvailable &&
        states != null &&
        states.every(
          (state) => state.shepherdIsMain && state.included && !state.canChange,
        );
    setState(() {
      _loading = false;
      _available = valid;
      if (valid) _confirmed = states;
    });
  }

  @override
  Widget build(BuildContext context) => Column(
    key: const ValueKey('main-shepherd-protected-access'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const _ShepherdJourneyAccessHeading(),
      const SizedBox(height: 6),
      Expanded(child: _buildJourneyAccess()),
      const SizedBox(height: 12),
      _ShepherdHistoryConsentControl(
        key: ValueKey('shepherd-history-consent-${widget.person.id}'),
        person: widget.person,
        loader: widget.historyConsentLoader,
        preview: widget.preview,
      ),
    ],
  );

  Widget _buildJourneyAccess() {
    final states = _confirmed;
    if (_loading && states == null) {
      return const _JourneyAccessSummary(
        states: [],
        requiredAccess: true,
        placeholderLabel: 'Loading Journey…',
        statusLabel: 'LOADING JOURNEY ACCESS',
      );
    }
    if (!_available || states == null) {
      return _JourneyAccessSummary(
        states: states ?? const [],
        requiredAccess: true,
        placeholderLabel: 'Journey unavailable',
        statusLabel: 'JOURNEY ACCESS UNAVAILABLE',
        onRetry: _loading ? null : boundShepherdCallback(_load),
      );
    }
    return _JourneyAccessSummary(states: states, requiredAccess: true);
  }
}

class _ShepherdJourneyAccessHeading extends StatelessWidget {
  const _ShepherdJourneyAccessHeading();

  @override
  Widget build(BuildContext context) => Row(
    key: const ValueKey('shepherd-journey-access-heading'),
    children: [
      const Icon(
        Icons.route_outlined,
        size: 17,
        color: SelahColors.journeyGold,
      ),
      const SizedBox(width: 9),
      Expanded(
        child: Text(
          'Active Journey access',
          style: SelahText.body(size: 13.25),
        ),
      ),
    ],
  );
}

List<ShepherdJourneyAccessState> _previewJourneyAccessStates(
  int requestedCount, {
  required bool mainShepherd,
}) {
  const names = ['Abigail', 'Rebecca', 'Esther'];
  final count = requestedCount.clamp(0, 3).toInt();
  return [
    for (var index = 0; index < count; index++)
      ShepherdJourneyAccessState(
        attemptId: index == 0
            ? 'dev-active-journey'
            : 'dev-active-journey-${index + 1}',
        matchId: 'dev-match-${index + 1}',
        counterpartFirstName: names[index],
        included: true,
        canChange: !mainShepherd,
        shepherdIsMain: mainShepherd,
        chatAvailable: true,
        chatEnabled: true,
      ),
  ];
}

class _AdditionalShepherdJourneyAccess extends StatefulWidget {
  final MentorLinkedPerson person;
  final ShepherdPageJourneyAccessLoader? loader;
  final ShepherdPageHistoryConsentLoader? historyConsentLoader;
  final bool preview;
  final int previewActiveJourneyCount;

  const _AdditionalShepherdJourneyAccess({
    required this.person,
    required this.loader,
    required this.historyConsentLoader,
    required this.preview,
    required this.previewActiveJourneyCount,
  });

  @override
  State<_AdditionalShepherdJourneyAccess> createState() =>
      _AdditionalShepherdJourneyAccessState();
}

class _AdditionalShepherdJourneyAccessState
    extends State<_AdditionalShepherdJourneyAccess>
    with _ShepherdControlLifetime<_AdditionalShepherdJourneyAccess> {
  List<ShepherdJourneyAccessState>? _confirmed;
  bool _loading = false;
  bool _available = true;
  bool _writeFailed = false;
  String? _busyAttempt;

  @override
  bool get shepherdPreviewRequested => widget.preview;

  @override
  void withdrawShepherdControl() {
    _confirmed = null;
    _loading = false;
    _available = false;
    _writeFailed = false;
    _busyAttempt = null;
  }

  @override
  void initState() {
    super.initState();
    _resetAndLoad();
  }

  @override
  void didUpdateWidget(covariant _AdditionalShepherdJourneyAccess oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.person.id != widget.person.id ||
        oldWidget.person.isMain != widget.person.isMain ||
        oldWidget.preview != widget.preview ||
        oldWidget.previewActiveJourneyCount !=
            widget.previewActiveJourneyCount ||
        oldWidget.loader != widget.loader ||
        oldWidget.historyConsentLoader != widget.historyConsentLoader) {
      replaceShepherdLifetime();
      _resetAndLoad();
    }
  }

  void _resetAndLoad() {
    shepherdRequest++;
    _confirmed = null;
    _loading = false;
    _available = true;
    _writeFailed = false;
    _busyAttempt = null;
    if (widget.preview) {
      if (!shepherdLifetime.canPreview) {
        _available = false;
        return;
      }
      _confirmed = _previewJourneyAccessStates(
        widget.previewActiveJourneyCount,
        mainShepherd: false,
      );
      return;
    }
    if (!shepherdLifetime.isCurrent) {
      _available = false;
      return;
    }
    _loading = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!mounted || !shepherdLifetime.isCurrent) return;
    final request = ++shepherdRequest;
    final lifetime = shepherdLifetime;
    final loader = widget.loader;
    if (loader == null) {
      if (!shepherdResultCurrent(request, lifetime)) return;
      setState(() {
        _loading = false;
        _available = false;
      });
      return;
    }
    if (!_loading) setState(() => _loading = true);
    SelahSourceResult<List<ShepherdJourneyAccessState>> result;
    try {
      result = await loader(shepherdId: widget.person.id);
    } catch (error) {
      debugPrint('SELAH Shepherd Journey access read failed — $error');
      if (!shepherdResultCurrent(request, lifetime)) return;
      setState(() {
        _loading = false;
        _available = false;
      });
      return;
    }
    if (!shepherdResultCurrent(request, lifetime)) return;
    final states = result.valueOrNull;
    final valid =
        result.isAvailable &&
        states != null &&
        states.every((state) => !state.shepherdIsMain && state.canChange);
    setState(() {
      _loading = false;
      _available = valid;
      _writeFailed = false;
      if (valid) _confirmed = states;
    });
  }

  Future<void> _setEnabled(
    ShepherdJourneyAccessState state,
    bool enabled,
  ) async {
    if (!mounted ||
        !shepherdLifetime.isCurrent ||
        !(_confirmed?.any((item) => identical(item, state)) ?? false) ||
        _busyAttempt != null ||
        !_available) {
      return;
    }
    if (widget.preview) {
      if (!shepherdLifetime.canPreview) return;
      setState(() {
        _confirmed = [
          for (final item in _confirmed ?? const [])
            if (item.attemptId == state.attemptId)
              ShepherdJourneyAccessState(
                attemptId: item.attemptId,
                matchId: item.matchId,
                counterpartFirstName: item.counterpartFirstName,
                included: enabled,
                canChange: item.canChange,
                shepherdIsMain: item.shepherdIsMain,
                chatAvailable: item.chatAvailable,
                chatEnabled: enabled ? item.chatEnabled : false,
              )
            else
              item,
        ];
      });
      return;
    }
    final loader = widget.loader;
    if (loader == null) return;
    final request = ++shepherdRequest;
    final lifetime = shepherdLifetime;
    setState(() {
      _busyAttempt = state.attemptId;
      _writeFailed = false;
    });
    SelahSourceResult<List<ShepherdJourneyAccessState>> result;
    try {
      result = await loader(
        shepherdId: widget.person.id,
        attemptId: state.attemptId,
        enabled: enabled,
      );
    } catch (error) {
      debugPrint('SELAH Shepherd Journey access write failed — $error');
      result = const SelahSourceResult.unavailable(
        SelahSourceFailure.requestFailed,
      );
    }
    final returned = result.valueOrNull;
    final accepted =
        result.isAvailable &&
        returned != null &&
        returned.any(
          (item) =>
              item.attemptId == state.attemptId && item.included == enabled,
        );
    if (!shepherdResultCurrent(request, lifetime)) return;
    setState(() {
      _busyAttempt = null;
      _writeFailed = !accepted;
      _available = true;
      if (accepted) _confirmed = returned;
    });
  }

  Future<void> _setChatEnabled(
    ShepherdJourneyAccessState state,
    bool enabled,
  ) async {
    if (!mounted ||
        !shepherdLifetime.isCurrent ||
        !(_confirmed?.any((item) => identical(item, state)) ?? false) ||
        _busyAttempt != null ||
        !_available ||
        !state.chatAvailable ||
        !state.included) {
      return;
    }
    if (widget.preview) {
      if (!shepherdLifetime.canPreview) return;
      setState(() {
        _confirmed = [
          for (final item in _confirmed ?? const [])
            if (item.attemptId == state.attemptId)
              ShepherdJourneyAccessState(
                attemptId: item.attemptId,
                matchId: item.matchId,
                counterpartFirstName: item.counterpartFirstName,
                included: item.included,
                canChange: item.canChange,
                shepherdIsMain: item.shepherdIsMain,
                chatAvailable: item.chatAvailable,
                chatEnabled: enabled,
              )
            else
              item,
        ];
      });
      return;
    }
    final loader = widget.loader;
    if (loader == null) return;
    final request = ++shepherdRequest;
    final lifetime = shepherdLifetime;
    setState(() {
      _busyAttempt = state.attemptId;
      _writeFailed = false;
    });
    SelahSourceResult<List<ShepherdJourneyAccessState>> result;
    try {
      result = await loader(
        shepherdId: widget.person.id,
        attemptId: state.attemptId,
        chatEnabled: enabled,
      );
    } catch (error) {
      debugPrint('SELAH Shepherd Journey chat access write failed — $error');
      result = const SelahSourceResult.unavailable(
        SelahSourceFailure.requestFailed,
      );
    }
    final returned = result.valueOrNull;
    final accepted =
        result.isAvailable &&
        returned != null &&
        returned.any(
          (item) =>
              item.attemptId == state.attemptId && item.chatEnabled == enabled,
        );
    if (!shepherdResultCurrent(request, lifetime)) return;
    setState(() {
      _busyAttempt = null;
      _writeFailed = !accepted;
      _available = true;
      if (accepted) _confirmed = returned;
    });
  }

  @override
  Widget build(BuildContext context) {
    final states = _confirmed;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _ShepherdJourneyAccessHeading(),
        const SizedBox(height: 6),
        Expanded(child: _buildJourneyAccess(states)),
        const SizedBox(height: 12),
        _ShepherdHistoryConsentControl(
          key: ValueKey('shepherd-history-consent-${widget.person.id}'),
          person: widget.person,
          loader: widget.historyConsentLoader,
          preview: widget.preview,
        ),
      ],
    );
  }

  Widget _buildJourneyAccess(List<ShepherdJourneyAccessState>? states) {
    final lifetime = shepherdLifetime;
    if (_loading && states == null) {
      return const _JourneyAccessSummary(
        states: [],
        placeholderLabel: 'Loading Journey…',
        statusLabel: 'LOADING JOURNEY ACCESS',
      );
    }
    if (!_available || states == null) {
      return _JourneyAccessSummary(
        states: states ?? const [],
        busyAttempt: 'unavailable',
        placeholderLabel: 'Journey unavailable',
        statusLabel: 'JOURNEY ACCESS UNAVAILABLE',
        onRetry: _loading ? null : boundShepherdCallback(_load),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: _JourneyAccessSummary(
            states: states,
            busyAttempt: _busyAttempt,
            onViewChanged: (state, enabled) {
              if (identical(lifetime, shepherdLifetime) && lifetime.isCurrent) {
                _setEnabled(state, enabled);
              }
            },
            onChatChanged: (state, enabled) {
              if (identical(lifetime, shepherdLifetime) && lifetime.isCurrent) {
                _setChatEnabled(state, enabled);
              }
            },
          ),
        ),
        if (_writeFailed) ...[
          const SizedBox(height: 10),
          SelahErrorBanner(
            message:
                'That change was not confirmed. Showing the last confirmed '
                'Journey access.',
            onRetry: boundShepherdCallback(_load),
          ),
        ],
      ],
    );
  }
}

class _JourneyAccessSummary extends StatelessWidget {
  final List<ShepherdJourneyAccessState> states;
  final String? busyAttempt;
  final void Function(ShepherdJourneyAccessState state, bool enabled)?
  onViewChanged;
  final void Function(ShepherdJourneyAccessState state, bool enabled)?
  onChatChanged;
  final bool requiredAccess;
  final String placeholderLabel;
  final String? statusLabel;
  final VoidCallback? onRetry;

  const _JourneyAccessSummary({
    required this.states,
    this.busyAttempt,
    this.onViewChanged,
    this.onChatChanged,
    this.requiredAccess = false,
    this.placeholderLabel = 'Awaiting a Journey',
    this.statusLabel,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final countLabel =
        statusLabel ??
        (states.isEmpty
            ? 'NO ACTIVE JOURNEYS'
            : states.length == 1
            ? '1 ACTIVE JOURNEY'
            : '${states.length} ACTIVE JOURNEYS');
    return Semantics(
      label:
          '$countLabel. ${states.map((state) => state.counterpartFirstName).join(', ')}. '
          '${requiredAccess ? 'View is required for each active Journey. Chat depends on Journey availability.' : 'View and Chat permissions are set separately for each active Journey.'}',
      child: Container(
        key: const ValueKey('shepherd-journey-access-summary'),
        padding: const EdgeInsets.fromLTRB(14, 11, 10, 8),
        decoration: BoxDecoration(
          color: SelahColors.surfaceFill,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: SelahColors.surfaceBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    countLabel,
                    style: SelahText.subtext(
                      size: 9.5,
                      color: SelahColors.ink(0.54),
                    ).copyWith(letterSpacing: 0.9),
                  ),
                ),
                if (onRetry != null)
                  Flexible(
                    flex: 2,
                    child: TextButton(
                      onPressed: onRetry,
                      child: const Text('Try again'),
                    ),
                  ),
              ],
            ),
            if (statusLabel != null) ...[
              const SizedBox(height: 4),
              Text(
                statusLabel == 'LOADING JOURNEY ACCESS'
                    ? 'Checking your current Journey access…'
                    : 'Journey access could not be refreshed.',
                style: SelahText.subtext(size: 10.75),
              ),
            ],
            const SizedBox(height: 8),
            const _JourneyPermissionHeader(),
            const SizedBox(height: 6),
            Divider(height: 1, color: SelahColors.ink(0.10)),
            Expanded(
              child: Column(
                children: [
                  for (
                    var index = 0;
                    index < math.max(3, states.length);
                    index++
                  ) ...[
                    Expanded(
                      child: index >= states.length
                          ? _PendingJourneyPermissionRow(
                              slot: index,
                              label: placeholderLabel,
                            )
                          : _JourneyPermissionTableRow(
                              state: states[index],
                              busy: busyAttempt != null,
                              requiredAccess: requiredAccess,
                              onViewChanged: onViewChanged == null
                                  ? null
                                  : (enabled) =>
                                        onViewChanged!(states[index], enabled),
                              onChatChanged: onChatChanged == null
                                  ? null
                                  : (enabled) =>
                                        onChatChanged!(states[index], enabled),
                            ),
                    ),
                    if (index < math.max(3, states.length) - 1)
                      Divider(height: 1, color: SelahColors.ink(0.08)),
                  ],
                ],
              ),
            ),
            if (states.any((state) => !state.chatAvailable)) ...[
              const SizedBox(height: 8),
              Text(
                'Chat is unavailable for this Journey.',
                key: const ValueKey('shepherd-journey-chat-unavailable'),
                style: SelahText.subtext(size: 10.75),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _JourneyPermissionHeader extends StatelessWidget {
  const _JourneyPermissionHeader();

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: Text('Journey', style: SelahText.subtext(size: 10.5))),
      SizedBox(
        width: 48,
        child: Text(
          'View',
          textAlign: TextAlign.center,
          style: SelahText.subtext(size: 10.5),
        ),
      ),
      SizedBox(
        width: 48,
        child: Text(
          'Chat',
          textAlign: TextAlign.center,
          style: SelahText.subtext(size: 10.5),
        ),
      ),
    ],
  );
}

/// A visual capacity slot only: never a Journey record or writable attempt.
class _PendingJourneyPermissionRow extends StatelessWidget {
  const _PendingJourneyPermissionRow({required this.slot, required this.label});
  final int slot;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    key: ValueKey('shepherd-journey-pending-row-$slot'),
    children: [
      Expanded(child: Text(label, style: SelahText.subtext(size: 12.25))),
      for (final permission in ['view', 'chat'])
        SizedBox(
          width: 48,
          child: Center(
            child: _CompactSelahSwitch(
              switchKey: ValueKey('shepherd-journey-pending-$permission-$slot'),
              value: false,
              onChanged: null,
              semanticLabel:
                  '$label, ${permission == 'view' ? 'View' : 'Chat'} unavailable',
            ),
          ),
        ),
    ],
  );
}

class _JourneyPermissionTableRow extends StatelessWidget {
  final ShepherdJourneyAccessState state;
  final bool busy;
  final bool requiredAccess;
  final ValueChanged<bool>? onViewChanged;
  final ValueChanged<bool>? onChatChanged;

  const _JourneyPermissionTableRow({
    required this.state,
    required this.busy,
    required this.requiredAccess,
    required this.onViewChanged,
    required this.onChatChanged,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      children: [
        Expanded(
          child: Text(
            'Journey with ${state.counterpartFirstName}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: SelahText.body(size: 12.25),
          ),
        ),
        SizedBox(
          width: 48,
          child: Center(
            child: requiredAccess
                ? _RequiredAccessMark(
                    markKey: ValueKey(
                      'shepherd-journey-view-required-${state.attemptId}',
                    ),
                    semanticLabel:
                        'View required for Journey with ${state.counterpartFirstName}',
                  )
                : _CompactSelahSwitch(
                    switchKey: ValueKey(
                      'shepherd-journey-access-toggle-${state.attemptId}',
                    ),
                    value: state.included,
                    onChanged: busy ? null : onViewChanged,
                    semanticLabel:
                        'View Journey with ${state.counterpartFirstName}',
                  ),
          ),
        ),
        SizedBox(
          width: 48,
          child: Center(
            child: requiredAccess && state.chatAvailable
                ? _RequiredAccessMark(
                    markKey: ValueKey(
                      'shepherd-journey-chat-required-${state.attemptId}',
                    ),
                    semanticLabel:
                        'Chat required for Journey with ${state.counterpartFirstName}',
                  )
                : _CompactSelahSwitch(
                    switchKey: ValueKey(
                      'shepherd-journey-chat-toggle-${state.attemptId}',
                    ),
                    value:
                        state.included &&
                        state.chatAvailable &&
                        state.chatEnabled,
                    onChanged:
                        !requiredAccess &&
                            state.included &&
                            state.chatAvailable &&
                            !busy
                        ? onChatChanged
                        : null,
                    semanticLabel: state.chatAvailable
                        ? 'Chat in Journey with ${state.counterpartFirstName}'
                        : 'Chat unavailable in Journey with ${state.counterpartFirstName}',
                  ),
          ),
        ),
      ],
    ),
  );
}

class _RequiredAccessMark extends StatelessWidget {
  final Key markKey;
  final String semanticLabel;

  const _RequiredAccessMark({
    required this.markKey,
    required this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    label: semanticLabel,
    child: Container(
      key: markKey,
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: SelahColors.actionFill.withValues(alpha: 0.15),
        shape: BoxShape.circle,
        border: Border.all(
          color: SelahColors.journeyGold.withValues(alpha: 0.52),
        ),
      ),
      child: const Icon(
        Icons.check_rounded,
        size: 16,
        color: SelahColors.journeyGold,
      ),
    ),
  );
}

class _CompactSelahSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  final String semanticLabel;
  final Key? switchKey;

  const _CompactSelahSwitch({
    required this.value,
    required this.onChanged,
    required this.semanticLabel,
    this.switchKey,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    label: semanticLabel,
    toggled: value,
    enabled: onChanged != null,
    excludeSemantics: true,
    child: SelahSwitch(key: switchKey, value: value, onChanged: onChanged),
  );
}

class _ShepherdHistoryConsentControl extends StatefulWidget {
  final MentorLinkedPerson person;
  final ShepherdPageHistoryConsentLoader? loader;
  final bool preview;

  const _ShepherdHistoryConsentControl({
    super.key,
    required this.person,
    required this.loader,
    required this.preview,
  });

  @override
  State<_ShepherdHistoryConsentControl> createState() =>
      _ShepherdHistoryConsentControlState();
}

class _ShepherdHistoryConsentControlState
    extends State<_ShepherdHistoryConsentControl>
    with _ShepherdControlLifetime<_ShepherdHistoryConsentControl> {
  ShepherdHistoryConsentState? _confirmed;
  bool _loading = false;
  bool _busy = false;
  bool _available = true;

  @override
  bool get shepherdPreviewRequested => widget.preview;

  @override
  void withdrawShepherdControl() {
    _confirmed = null;
    _loading = false;
    _busy = false;
    _available = false;
  }

  @override
  void initState() {
    super.initState();
    _resetAndLoad();
  }

  @override
  void didUpdateWidget(covariant _ShepherdHistoryConsentControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.person.id != widget.person.id ||
        oldWidget.person.isMain != widget.person.isMain ||
        oldWidget.preview != widget.preview ||
        oldWidget.loader != widget.loader) {
      replaceShepherdLifetime();
      _resetAndLoad();
    }
  }

  bool _matches(ShepherdHistoryConsentState state) =>
      state.activeShepherdLinkId != null &&
      state.shepherdId == widget.person.id &&
      state.shepherdIsMain == widget.person.isMain;

  void _resetAndLoad() {
    shepherdRequest++;
    _confirmed = null;
    _loading = false;
    _busy = false;
    _available = true;
    if (widget.preview) {
      if (!shepherdLifetime.canPreview) {
        _available = false;
        return;
      }
      _confirmed = ShepherdHistoryConsentState(
        enabled: false,
        activeShepherdLinkId: 'dev-shepherd-link-${widget.person.id}',
        shepherdId: widget.person.id,
        shepherdIsMain: widget.person.isMain,
      );
      return;
    }
    if (!shepherdLifetime.isCurrent) {
      _available = false;
      return;
    }
    _loading = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!mounted || !shepherdLifetime.isCurrent || _busy) return;
    final request = ++shepherdRequest;
    final lifetime = shepherdLifetime;
    final loader = widget.loader;
    if (loader == null) {
      if (!shepherdResultCurrent(request, lifetime)) return;
      setState(() {
        _loading = false;
        _available = false;
      });
      return;
    }
    if (!_loading) setState(() => _loading = true);
    SelahSourceResult<ShepherdHistoryConsentState> result;
    try {
      result = await loader(
        shepherdId: widget.person.id,
        shepherdIsMain: widget.person.isMain,
        enabled: null,
      );
    } catch (error) {
      debugPrint('SELAH Shepherd design consent read failed — $error');
      if (!shepherdResultCurrent(request, lifetime)) return;
      setState(() {
        _loading = false;
        _available = false;
      });
      return;
    }
    if (!shepherdResultCurrent(request, lifetime)) return;
    final next = result.valueOrNull;
    final confirmed = result.isAvailable && next != null && _matches(next);
    setState(() {
      _loading = false;
      _available = confirmed;
      _confirmed = confirmed ? next : null;
    });
  }

  Future<void> _setEnabled(bool enabled) async {
    if (!mounted || !shepherdLifetime.isCurrent) return;
    final confirmed = _confirmed;
    if (confirmed == null || _busy || _loading) {
      return;
    }
    if (widget.preview) {
      if (!shepherdLifetime.canPreview) return;
      setState(() {
        _confirmed = ShepherdHistoryConsentState(
          enabled: enabled,
          activeShepherdLinkId: confirmed.activeShepherdLinkId,
          shepherdId: confirmed.shepherdId,
          shepherdIsMain: confirmed.shepherdIsMain,
        );
      });
      return;
    }
    final loader = widget.loader;
    if (loader == null || !_available) return;
    final request = ++shepherdRequest;
    final lifetime = shepherdLifetime;
    setState(() => _busy = true);
    SelahSourceResult<ShepherdHistoryConsentState> result;
    try {
      result = await loader(
        shepherdId: widget.person.id,
        shepherdIsMain: widget.person.isMain,
        enabled: enabled,
      );
    } catch (error) {
      debugPrint('SELAH Shepherd design consent write failed — $error');
      if (!shepherdResultCurrent(request, lifetime)) return;
      setState(() {
        _busy = false;
        _available = false;
      });
      return;
    }
    if (!shepherdResultCurrent(request, lifetime)) return;
    final next = result.valueOrNull;
    final accepted =
        result.isAvailable &&
        next != null &&
        _matches(next) &&
        next.enabled == enabled;
    setState(() {
      _busy = false;
      _available = accepted;
      if (accepted) _confirmed = next;
    });
  }

  Future<void> _showExplanation() async {
    if (!mounted || !shepherdLifetime.isCurrent) return;
    final lifetime = shepherdLifetime;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SelahShepherdPreviewRouteBoundary(
        authority: lifetime,
        child: SafeArea(
          top: false,
          child: Container(
            key: const ValueKey('shepherd-history-consent-explanation'),
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
            decoration: BoxDecoration(
              color: SelahColors.mentorSheetBg,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: SelahColors.surfaceBorder),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: SelahColors.ink(0.22),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Past Journey summaries',
                  style: SelahText.heading(size: 20),
                ),
                const SizedBox(height: 10),
                Text(
                  '${widget.person.firstName} already sees your current '
                  'Journey and summaries from this link period. Turn sharing '
                  'on to include older Journey start dates, end dates and '
                  'status.',
                  style: SelahText.subtext(size: 12.5),
                ),
                const SizedBox(height: 10),
                Text(
                  'Names, messages, answers, reasons, notes and safety '
                  'information are never included.',
                  style: SelahText.subtext(
                    size: 12.5,
                    color: SelahColors.ink(0.56),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final confirmed = _confirmed;
    final lifetime = shepherdLifetime;
    return Column(
      key: const ValueKey('shepherd-history-consent'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Text(
                  'Share past Journey summaries',
                  style: SelahText.body(size: 13.25),
                ),
              ),
              IconButton(
                key: const ValueKey('shepherd-history-consent-details-toggle'),
                tooltip: 'About sharing past Journey summaries',
                visualDensity: VisualDensity.compact,
                iconSize: 19,
                color: SelahColors.ink(0.58),
                onPressed: boundShepherdCallback(_showExplanation),
                icon: const Icon(Icons.info_outline_rounded),
              ),
              const SizedBox(width: 4),
              if (confirmed != null)
                Semantics(
                  label:
                      'Share past Journey summaries with '
                      '${widget.person.firstName}',
                  child: _CompactSelahSwitch(
                    switchKey: const ValueKey(
                      'shepherd-history-consent-toggle',
                    ),
                    value: confirmed.enabled,
                    onChanged: _available && !_loading && !_busy
                        ? (enabled) {
                            if (identical(lifetime, shepherdLifetime) &&
                                identical(confirmed, _confirmed) &&
                                lifetime.isCurrent) {
                              _setEnabled(enabled);
                            }
                          }
                        : null,
                    semanticLabel:
                        'Share past Journey summaries with '
                        '${widget.person.firstName}',
                  ),
                )
              else
                Flexible(
                  flex: 2,
                  child: Text(
                    _loading ? 'Loading…' : 'Unavailable',
                    style: SelahText.subtext(
                      size: 11,
                      color: SelahColors.ink(0.44),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (_busy)
          Text('Confirming with SELAH…', style: SelahText.subtext(size: 11)),
        if (!_available) ...[
          const SizedBox(height: 8),
          SelahErrorBanner(
            message: confirmed == null
                ? 'Past-summary permission could not be refreshed.'
                : 'The last change was not confirmed. Showing the last '
                      'server-confirmed state.',
            onRetry: _loading || _busy ? null : boundShepherdCallback(_load),
          ),
        ],
      ],
    );
  }
}

class _ActivityTruth extends StatelessWidget {
  final bool available;
  final ShepherdActivity? obligation;
  final VoidCallback onRetry;
  final bool compact;

  const _ActivityTruth({
    required this.available,
    required this.obligation,
    required this.onRetry,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (!available) {
      return Padding(
        padding: EdgeInsets.only(top: compact ? 0 : 14),
        child: SelahErrorBanner(
          message: 'Current Shepherd activity could not be refreshed.',
          onRetry: onRetry,
        ),
      );
    }
    final current = obligation;
    if (current == null) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(top: compact ? 0 : 17),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 5),
                decoration: const BoxDecoration(
                  color: SelahColors.journeyGold,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(current.line!, style: SelahText.body(size: 13.25)),
                    const SizedBox(height: 3),
                    Text(
                      current.timingLabel ?? '',
                      style: SelahText.subtext(
                        size: 10.75,
                        color: SelahColors.ink(0.42),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ShepherdIdentity extends StatelessWidget {
  final MentorLinkedPerson person;

  const _ShepherdIdentity({required this.person});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(person.firstName, style: SelahText.heading(size: 27)),
      const SizedBox(height: 3),
      Text(
        _recordedShepherdRole(person),
        style: SelahText.subtext(size: 12.5, color: SelahColors.ink(0.58)),
      ),
    ],
  );
}

class _ShepherdMonogram extends StatelessWidget {
  final MentorLinkedPerson person;
  final double size;

  const _ShepherdMonogram({required this.person, required this.size});

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: SelahColors.actionFill.withValues(alpha: 0.13),
      border: Border.all(color: SelahColors.actionFill.withValues(alpha: 0.35)),
    ),
    child: Text(
      person.firstName.trim().isEmpty
          ? '?'
          : person.firstName.trim()[0].toUpperCase(),
      style: SelahText.heading(size: size * 0.38),
    ),
  );
}

class _ShepherdPageDots extends StatelessWidget {
  final int count;
  final int selected;

  const _ShepherdPageDots({required this.count, required this.selected});

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Shepherd ${selected + 1} of $count',
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var index = 0; index < count; index++)
          AnimatedContainer(
            key: ValueKey('shepherd-page-dot-$index'),
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

class _QuietSection extends StatelessWidget {
  final String? label;
  final Widget child;
  final bool compact;

  const _QuietSection({this.label, required this.child, this.compact = false});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: EdgeInsets.symmetric(vertical: compact ? 7 : 10, horizontal: 2),
    decoration: BoxDecoration(
      border: Border(top: BorderSide(color: SelahColors.ink(0.13))),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          _DesignSectionLabel(label!),
          SizedBox(height: compact ? 4 : 6),
        ],
        child,
      ],
    ),
  );
}

class _DesignSectionLabel extends StatelessWidget {
  final String text;

  const _DesignSectionLabel(this.text);

  @override
  Widget build(BuildContext context) =>
      Text(text, style: SelahText.chapterLabel(color: SelahColors.ink(0.47)));
}
