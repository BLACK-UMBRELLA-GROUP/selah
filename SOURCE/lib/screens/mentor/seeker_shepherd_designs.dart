import 'package:flutter/material.dart';
import '../../widgets/selah_switch.dart';
import '../../models/selah_shepherd_recent.dart';
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
/// LOCK 12: one vertical Main-first page using the existing control owners.
class SeekerShepherdPage extends StatelessWidget {
  final List<MentorLinkedPerson> people;
  final Map<String, String> displayNames;
  final List<SelahShepherdRecentItem> recent;
  final Widget? mainPhoto;
  final Map<String, List<ShepherdActivity>> activity;
  final bool linksAvailable;
  final bool activityAvailable;
  final VoidCallback onRetry;
  final VoidCallback onAdd;
  final VoidCallback? onOpenMessages;
  final VoidCallback? onAskForPrayer;
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
    this.displayNames = const {},
    this.recent = const [],
    this.mainPhoto,
    required this.activity,
    required this.linksAvailable,
    required this.activityAvailable,
    required this.onRetry,
    required this.onAdd,
    this.onOpenMessages,
    this.onAskForPrayer,
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
    final main = ordered.where((person) => person.isMain).firstOrNull;
    final additional = ordered.where((person) => !person.isMain).toList();
    final now = comparisonNow ?? DateTime.now();
    final shortName = main == null
        ? ''
        : '${main.relationship == 'pastor' ? 'Pastor ' : ''}${main.firstName}';
    final reserve =
        math.max(
          MediaQuery.paddingOf(context).bottom,
          SelahNavBarMetrics.bottomInset,
        ) +
        SelahNavBarMetrics.height;
    return ListView(
      key: const ValueKey('seeker_shepherd_scroll'),
      padding: EdgeInsets.fromLTRB(22, 6, 22, reserve + 16),
      children: [
        Text(
          'My Shepherd',
          style: SelahText.pageTitle().copyWith(fontSize: titleSize),
        ),
        const SizedBox(height: 10),
        if (main != null) ...[
          _LockedMainShepherd(
            person: main,
            name: displayNames[main.id] ?? main.firstName,
            photo: mainPhoto,
            onAsk: onAskForPrayer,
            onMessage: onOpenMessages,
            manage: _LockedShepherdManage(person: main, page: this),
          ),
          const SizedBox(height: 14),
          _lockedShepherdLabel('Recently from $shortName'),
          const SizedBox(height: 14),
          _lockedShepherdCard(
            key: const ValueKey('seeker_shepherd_recent'),
            child: recent.isEmpty
                ? Text(
                    'Nothing yet. When $shortName prays for you or sends a message, it shows here.',
                    style: SelahText.subtext(size: 13).copyWith(height: 1.4),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < recent.length; i++) ...[
                        if (i > 0) Divider(height: 1, color: SelahColors.line),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            recent[i].lineAt(now),
                            key: ValueKey(
                              'seeker_shepherd_recent_${recent[i].key}',
                            ),
                            style: SelahText.body(
                              size: 14.5,
                            ).copyWith(height: 1.4),
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
          const SizedBox(height: 14),
        ],
        _lockedShepherdLabel('Additional Shepherds'),
        const SizedBox(height: 14),
        _lockedShepherdCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final person in additional)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: _LockedShepherdManage(
                    person: person,
                    page: this,
                    identity: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayNames[person.id] ?? person.firstName,
                          style: SelahText.body(
                            size: 15,
                          ).copyWith(fontWeight: FontWeight.w600, height: 1.4),
                        ),
                        Text(
                          [
                            ?person.relationshipLabel,
                            'Supports you with your Journey.',
                          ].join(' · '),
                          style: SelahText.subtext(
                            size: 13,
                          ).copyWith(height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 10),
              _lockedShepherdButton(
                'Add a Shepherd',
                onAdd,
                key: const ValueKey('seeker_shepherd_add'),
              ),
            ],
          ),
        ),
        if (main != null) ...[
          const SizedBox(height: 14),
          _MainShepherdJourneyAccess(
            key: ValueKey('locked_shepherd_access_${main.id}'),
            person: main,
            loader: journeyAccessLoader,
            historyConsentLoader: historyConsentLoader,
            preview: historyConsentPreview,
            previewActiveJourneyCount: previewActiveJourneyCount,
            lockedVertical: true,
          ),
        ],
      ],
    );
  }
}

Widget _lockedShepherdCard({required Widget child, Key? key}) => Container(
  key: key,
  padding: const EdgeInsets.all(16),
  decoration: BoxDecoration(
    color: SelahColors.surface,
    border: Border.all(color: SelahColors.line),
    borderRadius: BorderRadius.circular(14),
  ),
  child: child,
);

Widget _lockedShepherdLabel(String text) => Text(
  text.toUpperCase(),
  style: SelahText.body(
    size: 11,
    color: SelahColors.muted,
  ).copyWith(fontWeight: FontWeight.w600, letterSpacing: 1.32, height: 1),
);

Widget _lockedShepherdButton(
  String label,
  VoidCallback? action, {
  Key? key,
  bool primary = false,
}) => SizedBox(
  width: double.infinity,
  child: primary
      ? FilledButton(
          key: key,
          onPressed: action,
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 35.5),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            textStyle: SelahText.body(
              size: 13.5,
            ).copyWith(fontWeight: FontWeight.w600, height: 1),
          ),
          child: Text(label),
        )
      : OutlinedButton(
          key: key,
          onPressed: action,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 35.5),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            textStyle: SelahText.body(
              size: 13.5,
            ).copyWith(fontWeight: FontWeight.w600, height: 1),
          ),
          child: Text(label),
        ),
);

class _LockedMainShepherd extends StatelessWidget {
  const _LockedMainShepherd({
    required this.person,
    required this.name,
    required this.photo,
    required this.onAsk,
    required this.onMessage,
    required this.manage,
  });
  final MentorLinkedPerson person;
  final String name;
  final Widget? photo;
  final VoidCallback? onAsk, onMessage;
  final Widget manage;

  @override
  Widget build(BuildContext context) {
    final role = person.relationshipLabel;
    final date = person.linkedAt;
    final month = date == null
        ? null
        : const [
            'January',
            'February',
            'March',
            'April',
            'May',
            'June',
            'July',
            'August',
            'September',
            'October',
            'November',
            'December',
          ][date.month - 1];
    final relationship = role == null ? null : 'Your ${role.toLowerCase()}';
    final detail = [
      ?relationship,
      if (month != null) 'walking with you since $month',
      if (month == null) 'Linked date not recorded',
    ].join(' · ');
    return _lockedShepherdCard(
      key: const ValueKey('seeker_shepherd_main'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: SizedBox(
                  width: 78,
                  height: 78,
                  child: photo ?? _ShepherdMonogram(person: person, size: 78),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: SelahText.body(
                        size: 18,
                      ).copyWith(fontWeight: FontWeight.w600, height: 1.2),
                    ),
                    Text(
                      detail,
                      style: SelahText.subtext(size: 13).copyWith(height: 1.4),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: SelahColors.soft,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Main Shepherd',
                        style: SelahText.body(
                          size: 11,
                          color: SelahColors.lake,
                        ).copyWith(fontWeight: FontWeight.w600, height: 1),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _lockedShepherdButton(
                  'Ask for prayer',
                  onAsk,
                  key: const ValueKey('ask_for_prayer'),
                  primary: true,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _lockedShepherdButton(
                  'Message',
                  onMessage,
                  key: const ValueKey('seeker_shepherd_message'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          manage,
        ],
      ),
    );
  }
}

class _LockedShepherdManage extends StatefulWidget {
  const _LockedShepherdManage({
    required this.person,
    required this.page,
    this.identity,
  });
  final MentorLinkedPerson person;
  final SeekerShepherdPage page;
  final Widget? identity;
  @override
  State<_LockedShepherdManage> createState() => _LockedShepherdManageState();
}

class _LockedShepherdManageState extends State<_LockedShepherdManage> {
  bool _open = false;
  @override
  Widget build(BuildContext context) {
    final page = widget.page;
    final person = widget.person;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.identity case final identity?)
          Row(
            children: [
              Expanded(child: identity),
              const SizedBox(width: 12),
              SizedBox(
                width: 78,
                child: _lockedShepherdButton(
                  'Manage',
                  () => setState(() => _open = !_open),
                  key: ValueKey('seeker_shepherd_manage_${person.id}'),
                ),
              ),
            ],
          )
        else
          _lockedShepherdButton(
            'Manage',
            () => setState(() => _open = !_open),
            key: ValueKey('seeker_shepherd_manage_${person.id}'),
          ),
        if (_open) ...[
          const SizedBox(height: 10),
          _ShepherdManageActions(
            person: person,
            otherShepherds: page.people
                .where((other) => other.id != person.id)
                .toList(),
            preview: page.historyConsentPreview,
            makeMainShepherd: page.makeMainShepherd,
            clearMainShepherd: page.clearMainShepherd,
            removeShepherd: page.removeShepherd,
            onChanged: page.onChanged,
          ),
          if (!person.isMain) ...[
            const SizedBox(height: 10),
            SizedBox(
              height:
                  MediaQuery.sizeOf(context).height -
                  MediaQuery.paddingOf(context).vertical -
                  SelahNavBarMetrics.height -
                  SelahNavBarMetrics.bottomInset,
              child: _AdditionalShepherdJourneyAccess(
                person: person,
                loader: page.journeyAccessLoader,
                historyConsentLoader: page.historyConsentLoader,
                preview: page.historyConsentPreview,
                previewActiveJourneyCount: page.previewActiveJourneyCount,
              ),
            ),
          ],
        ],
      ],
    );
  }
}

class _ShepherdManageActions extends StatefulWidget {
  final MentorLinkedPerson person;
  final List<MentorLinkedPerson> otherShepherds;
  final bool preview;
  final ShepherdMakeMainAction? makeMainShepherd;
  final ShepherdClearMainAction? clearMainShepherd;
  final ShepherdRemoveAction? removeShepherd;
  final VoidCallback? onChanged;
  final bool compact = false;

  const _ShepherdManageActions({
    required this.person,
    required this.otherShepherds,
    required this.preview,
    required this.makeMainShepherd,
    required this.clearMainShepherd,
    required this.removeShepherd,
    required this.onChanged,
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
  final bool lockedVertical;
  final ShepherdPageJourneyAccessLoader? loader;
  final ShepherdPageHistoryConsentLoader? historyConsentLoader;
  final bool preview;
  final int previewActiveJourneyCount;

  const _MainShepherdJourneyAccess({
    super.key,
    this.lockedVertical = false,
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
  Widget build(BuildContext context) => widget.lockedVertical
      ? Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _lockedShepherdLabel('Journey access'),
            const SizedBox(height: 14),
            _lockedShepherdCard(
              key: const ValueKey('seeker_shepherd_journey_access'),
              child: _buildLockedJourneyAccess(),
            ),
            const SizedBox(height: 14),
            _lockedShepherdLabel('Past Journey summaries'),
            const SizedBox(height: 14),
            _lockedShepherdCard(
              child: _ShepherdHistoryConsentControl(
                key: ValueKey('shepherd-history-consent-${widget.person.id}'),
                person: widget.person,
                loader: widget.historyConsentLoader,
                preview: widget.preview,
                lockedVertical: true,
              ),
            ),
          ],
        )
      : Column(
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

  Widget _buildLockedJourneyAccess() {
    if (_loading && _confirmed == null) {
      return Text(
        'Loading Journey access…',
        style: SelahText.subtext(size: 13),
      );
    }
    if (!_available || _confirmed == null) {
      return SelahErrorBanner(
        message: 'Journey access didn’t load.',
        onRetry: _loading ? null : boundShepherdCallback(_load),
      );
    }
    final states = _confirmed!;
    if (states.isEmpty) {
      return Text(
        'No active Journeys. Access is set when one begins.',
        style: SelahText.subtext(size: 13).copyWith(height: 1.4),
      );
    }
    final name =
        '${widget.person.relationship == 'pastor' ? 'Pastor ' : ''}${widget.person.firstName}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < states.length; index++) ...[
          if (index > 0) Divider(height: 1, color: SelahColors.line),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Journey with ${states[index].counterpartFirstName}',
                        style: SelahText.body(
                          size: 15,
                        ).copyWith(fontWeight: FontWeight.w600, height: 1.4),
                      ),
                      Text(
                        'View is required for each active Journey.',
                        style: SelahText.subtext(
                          size: 13,
                        ).copyWith(height: 1.4),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: SelahColors.soft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('View', style: SelahText.subtext(size: 13)),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: SelahColors.line),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Chat',
                        style: SelahText.body(
                          size: 15,
                        ).copyWith(fontWeight: FontWeight.w600, height: 1.4),
                      ),
                      Text(
                        '$name can join the chat for this Journey.',
                        style: SelahText.subtext(
                          size: 13,
                        ).copyWith(height: 1.4),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                SelahSwitch(
                  key: ValueKey(
                    'shepherd-journey-chat-toggle-${states[index].attemptId}',
                  ),
                  value:
                      states[index].included &&
                      states[index].chatAvailable &&
                      states[index].chatEnabled,
                  onChanged: null,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

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
  final bool lockedVertical;
  final ShepherdPageHistoryConsentLoader? loader;
  final bool preview;

  const _ShepherdHistoryConsentControl({
    this.lockedVertical = false,
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
    if (widget.lockedVertical) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Share past Journey summaries',
                    style: SelahText.body(
                      size: 15,
                    ).copyWith(fontWeight: FontWeight.w600, height: 1.4),
                  ),
                  Text(
                    'Names, messages, answers and notes are never included.',
                    style: SelahText.subtext(size: 13).copyWith(height: 1.4),
                  ),
                  if (!_available)
                    SelahErrorBanner(
                      message:
                          'Past-summary permission could not be refreshed.',
                      onRetry: _loading || _busy
                          ? null
                          : boundShepherdCallback(_load),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            if (confirmed != null)
              SelahSwitch(
                key: const ValueKey('shepherd-history-consent-toggle'),
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
              )
            else
              Text(
                _loading ? 'Loading…' : 'Unavailable',
                style: SelahText.subtext(size: 11),
              ),
          ],
        ),
      );
    }
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
          Text('Confirming with Selah…', style: SelahText.subtext(size: 11)),
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
