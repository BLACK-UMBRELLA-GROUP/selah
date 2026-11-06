// Current Shepherd presentation with caller-supplied local fixture data only.
// Pure production roster/workspace/profile widgets are reused directly. The
// private Dashboard/Network layouts below retain their current executable
// wording and geometry; no account/service singleton is invoked here.

import 'dart:async';

import 'package:flutter/material.dart';

import '../data/selah_membership_catalog.dart';
import '../models/seeker_profile.dart';
import '../screens/mentor/mentor_gn_shared.dart';
import '../screens/mentor/mentor_seeker_workspace_screen.dart';
import '../screens/mentor/mentor_seekers_screen.dart';
import '../services/selah_shepherd_dashboard_resolver.dart';
import '../services/selah_shepherd_seeker_roster_resolver.dart';
import '../services/selah_mentor_journey_service.dart'
    show MentorJourneyView, ShepherdSeekerRosterContext;
import '../services/selah_mentor_link_service.dart' show MentorLinkedPerson;
import '../theme/selah_colors.dart';
import '../theme/selah_text.dart';
import '../widgets/selah_shepherd_dashboard_profile_card.dart';
import '../widgets/selah_profile_image.dart';
import '../widgets/selah_scrollable_seeker_selector.dart';
import '../widgets/selah_segmented_toggle.dart';
import '../widgets/selah_state_widgets.dart';

class SelahOneJourneyShepherdDashboardPresentation extends StatelessWidget {
  const SelahOneJourneyShepherdDashboardPresentation({
    super.key,
    required this.profile,
    required this.person,
    required this.shepherdName,
    required this.onProfile,
    required this.onJourney,
    this.currentJourney,
    this.hasShepherdOne = true,
    this.onMembership,
    this.showHeader = true,
    this.prayerRequests,
  });

  final SeekerProfile profile;
  final MentorLinkedPerson person;
  final String shepherdName;
  final VoidCallback onProfile;
  final VoidCallback onJourney;
  final MentorJourneyView? currentJourney;
  final bool hasShepherdOne;
  final VoidCallback? onMembership;

  /// A parent may own the same main heading above a multi-Journey selector.
  final bool showHeader;
  final Widget? prayerRequests;

  @override
  Widget build(BuildContext context) {
    final resolution = const SelahShepherdDashboardResolver().resolve(
      linkedPeople: [person],
      journeys: [?currentJourney],
      openReviewIds: const {},
    );
    final attention = resolution.attention.firstOrNull;
    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showHeader)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Shepherd Dashboard',
                    key: const ValueKey('concept_shepherd_dashboard_title'),
                    textAlign: TextAlign.left,
                    style: SelahText.pageTitle(),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    shepherdName.trim().isEmpty
                        ? 'Your SELAH, in one place.'
                        : 'Hello, $shepherdName.',
                    style: SelahText.subtext(size: 13.5),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
            child: SelahScrollableSeekerSelector(
              labels: [person.firstName],
              segmentKeys: [ValueKey('concept_shepherd_selected_${person.id}')],
              position: 0,
              onChanged: (_) {},
            ),
          ),
          Expanded(
            child: ListView(
              key: PageStorageKey('concept_shepherd_dashboard_${person.id}'),
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 108),
              children: [
                if (prayerRequests != null) ...[
                  prayerRequests!,
                  const SizedBox(height: 20),
                ],
                ShepherdDashboardProfileCard(
                  person: person,
                  profile: profile,
                  onViewProfile: onProfile,
                ),
                const SizedBox(height: 20),
                _DashboardSection(
                  label: 'RIGHT NOW',
                  child: attention == null
                      ? const _DashboardStatusCard(
                          icon: Icons.check_circle_outline_rounded,
                          eyebrow: 'ALL SETTLED',
                          title: 'Nothing needs you right now',
                          detail:
                              'Your current Shepherd responsibilities are clear.',
                        )
                      : _DashboardAttentionCard(
                          title: attention.title,
                          body: attention.detail,
                          cta: attention.actionLabel,
                          onTap: onJourney,
                        ),
                ),
                const SizedBox(height: 22),
                const _DashboardSection(
                  label: 'UPDATES',
                  child: _DashboardStatusCard(
                    icon: Icons.notifications_none_rounded,
                    eyebrow: 'ALL CAUGHT UP',
                    title: 'No Shepherd updates yet',
                    detail:
                        'Meaningful Journey and Family Review movement will appear here.',
                  ),
                ),
                const SizedBox(height: 22),
                _DashboardSection(
                  label: 'INSIGHTS',
                  child: hasShepherdOne
                      ? _DashboardStatusCard(
                          icon: Icons.insights_outlined,
                          eyebrow:
                              '${person.firstName.toUpperCase()} · INSIGHTS',
                          title: 'No Shepherd insights available yet',
                          detail:
                              'SELAH will only show a Shepherd insight when real, governed family-process evidence supports it.',
                        )
                      : _DashboardStatusCard(
                          icon: Icons.lock_rounded,
                          eyebrow:
                              '${person.firstName.toUpperCase()} · INSIGHTS',
                          title:
                              'Shepherd Insights are part of ${SelahMembershipCatalog.shepherdOneTitle}',
                          detail:
                              'Upgrade to unlock deeper family-process and Shepherd-responsibility insights. Your existing responsibilities remain available.',
                          actionLabel:
                              'View ${SelahMembershipCatalog.shepherdOneTitle}',
                          onTap: onMembership,
                          premiumBoundary: true,
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The actual current production roster and embedded Seeker workspace, not
/// the older standalone quiet summary. All routes are injected local actions.
class SelahOneJourneyShepherdSeekersPresentation extends StatelessWidget {
  const SelahOneJourneyShepherdSeekersPresentation({
    super.key,
    required this.profile,
    required this.person,
    required this.onJourney,
    required this.onNetwork,
    required this.onInvite,
    this.currentJourney,
    this.hasShepherdOne = true,
    this.onFamilyChat,
    this.showHeader = true,
  });

  final SeekerProfile profile;
  final MentorLinkedPerson person;
  final MentorJourneyView? currentJourney;
  final bool hasShepherdOne;
  final VoidCallback onJourney;
  final VoidCallback onNetwork;
  final VoidCallback onInvite;
  final VoidCallback? onFamilyChat;
  final bool showHeader;

  @override
  Widget build(BuildContext context) {
    final resolution = const SelahShepherdSeekerRosterResolver().resolve(
      linkedPeople: [person],
      context: ShepherdSeekerRosterContext(journeys: [?currentJourney]),
    );
    return ShepherdSeekerRosterView(
      decoration: const BoxDecoration(),
      titleAlignment: Alignment.centerLeft,
      showHeader: showHeader,
      resolution: resolution,
      photos: {person.id: profile.photoUrl},
      onRetry: () {},
      onInvite: onInvite,
      onOpenSeeker: (_) {},
      pageBuilder: (entry) => ShepherdSeekerWorkspaceView(
        entry: entry,
        embedded: true,
        hasShepherdOne: hasShepherdOne,
        photoUrl: profile.photoUrl,
        onRetrySummary: () {},
        onOpenJourney: (_) => onJourney(),
        onOpenNetwork: onNetwork,
        onOpenFamilyChat: onFamilyChat,
      ),
    );
  }
}

/// Current Network header/selector/motion and portrait-focus cards. Local
/// comparison owners supply the introduced-profile and request lists; no
/// Shepherd context singleton or real invitation route is reached.
class SelahOneJourneyShepherdNetworkPresentation extends StatefulWidget {
  const SelahOneJourneyShepherdNetworkPresentation({
    super.key,
    required this.person,
    required this.profiles,
    required this.selectedIndex,
    required this.onChanged,
    required this.onProfile,
    required this.onIntroduction,
    this.onSelectSeeker,
    this.sentProfiles = const [],
    this.receivedProfiles = const [],
    this.onWithdraw,
    this.onAccept,
    this.onDecline,
    this.onShepherd,
    this.onViewingProfileChanged,
    this.showHeader = true,
  }) : assert(selectedIndex >= 0 && selectedIndex <= 2);

  final MentorLinkedPerson person;
  final List<SeekerProfile> profiles;
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final ValueChanged<SeekerProfile> onProfile;
  final ValueChanged<SeekerProfile> onIntroduction;
  final VoidCallback? onSelectSeeker;
  final List<SeekerProfile> sentProfiles;
  final List<SeekerProfile> receivedProfiles;
  final ValueChanged<SeekerProfile>? onWithdraw;
  final ValueChanged<SeekerProfile>? onAccept;
  final ValueChanged<SeekerProfile>? onDecline;
  final ValueChanged<SeekerProfile>? onShepherd;
  final VoidCallback? onViewingProfileChanged;
  final bool showHeader;

  @override
  State<SelahOneJourneyShepherdNetworkPresentation> createState() =>
      _SelahOneJourneyShepherdNetworkPresentationState();
}

class _SelahOneJourneyShepherdNetworkPresentationState
    extends State<SelahOneJourneyShepherdNetworkPresentation> {
  late final PageController _pager;
  late double _position;
  int _profileIndex = 0;
  int _viewGeneration = 0;

  @override
  void initState() {
    super.initState();
    _position = widget.selectedIndex.toDouble();
    _pager = PageController(initialPage: widget.selectedIndex, keepPage: false)
      ..addListener(_onScroll);
  }

  void _onScroll() {
    final page = _pager.page;
    if (mounted && page != null && page != _position) {
      setState(() => _position = page);
    }
  }

  void _select(int index) {
    if (!_pager.hasClients) return;
    if (MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context)) {
      _pager.jumpToPage(index);
    } else {
      unawaited(SelahSegmentedMotion.animateToPage(_pager, index));
    }
  }

  void _nextProfile(int generation) {
    if (!mounted || generation != _viewGeneration) return;
    _viewGeneration++;
    setState(() => _profileIndex++);
    widget.onViewingProfileChanged?.call();
  }

  @override
  void didUpdateWidget(
    covariant SelahOneJourneyShepherdNetworkPresentation old,
  ) {
    super.didUpdateWidget(old);
    _viewGeneration++;
    if (old.person.id != widget.person.id) _profileIndex = 0;
    if (old.selectedIndex != widget.selectedIndex &&
        _position.round() != widget.selectedIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _select(widget.selectedIndex);
      });
    }
  }

  @override
  void dispose() {
    _pager.removeListener(_onScroll);
    _pager.dispose();
    super.dispose();
  }

  // Preserve the current centred empty state when it fits; only an oversized
  // large-text body scrolls inside the existing page viewport.
  Widget _boundedEmpty({required Widget child}) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: constraints.maxHeight),
        child: Center(child: child),
      ),
    ),
  );

  Widget _body(List<SeekerProfile> profiles, int mode) {
    if (mode != 0 && !widget.person.isMain) {
      return _boundedEmpty(
        child: GNQuietNotice(
          icon: Icons.shield_outlined,
          title: 'Handled by the Main Shepherd',
          message:
              'Only the Main Shepherd manages requests for ${widget.person.firstName}.',
        ),
      );
    }
    if (profiles.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 84),
        child: _boundedEmpty(
          child: SelahEmptyState(
            icon: mode == 1
                ? Icons.outbox_outlined
                : Icons.mark_email_unread_outlined,
            title: mode == 1
                ? 'No sent requests'
                : mode == 2
                ? 'No received requests'
                : 'No families available',
            message: mode == 1
                ? 'Requests you send for ${widget.person.firstName} will appear here.'
                : mode == 2
                ? 'Requests another family sends for ${widget.person.firstName} will appear here.'
                : 'Check back soon.',
          ),
        ),
      );
    }
    final shown = mode == 0
        ? [profiles[_profileIndex % profiles.length]]
        : profiles;
    // A retained portrait action belongs to this exact owner binding. Do not
    // read the newer widget's callbacks when an old profile card is invoked.
    final onProfile = widget.onProfile;
    final onIntroduction = widget.onIntroduction;
    final onWithdraw = widget.onWithdraw;
    final onAccept = widget.onAccept;
    final onDecline = widget.onDecline;
    final onShepherd = widget.onShepherd;
    final viewGeneration = _viewGeneration;
    return LayoutBuilder(
      builder: (context, constraints) {
        // The same card needs additional scrolling space at large text sizes.
        // Previously the one-slot sample hid this populated Network path once
        // a Journey began; monthly spare capacity now keeps it reachable.
        final textGrowth = (MediaQuery.textScalerOf(context).scale(14) / 14 - 1)
            .clamp(0.0, double.infinity);
        final height =
            (constraints.maxHeight - 88).clamp(510.0, 720.0) + textGrowth * 400;
        return SingleChildScrollView(
          key: PageStorageKey('concept_shepherd_network_$mode'),
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 84),
          child: Column(
            children: [
              for (final profile in shown) ...[
                SizedBox(
                  height: height,
                  child: _NetworkPortraitCard(
                    profile: profile,
                    mode: mode,
                    isMain: widget.person.isMain,
                    onProfile: () => onProfile(profile),
                    onRequest: () => onIntroduction(profile),
                    onNext: () => _nextProfile(viewGeneration),
                    onWithdraw: onWithdraw == null
                        ? null
                        : () => onWithdraw(profile),
                    onAccept: onAccept == null ? null : () => onAccept(profile),
                    onDecline: onDecline == null
                        ? null
                        : () => onDecline(profile),
                    onShepherd: onShepherd == null
                        ? null
                        : () => onShepherd(profile),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    bottom: false,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.showHeader)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    'Network',
                    key: const ValueKey('concept_shepherd_network_title'),
                    textAlign: TextAlign.left,
                    style: SelahText.pageTitle(),
                  ),
                ),
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 120),
                  child: GestureDetector(
                    key: const ValueKey('concept_network_seeker'),
                    behavior: HitTestBehavior.opaque,
                    onTap: widget.onSelectSeeker,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(10, 7, 4, 7),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              widget.person.firstName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: SelahText.body(
                                size: 14.5,
                                color: SelahColors.foreground,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 17,
                            color: SelahColors.foregroundSecondary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
          child: SelahSegmentedToggle(
            labels: const ['Browser', 'Sent requests', 'Received'],
            position: _position.clamp(0, 2),
            badges: [
              0,
              widget.sentProfiles.length,
              widget.receivedProfiles.length,
            ],
            labelSize: 10.5,
            segmentKeys: const [
              ValueKey('concept_network_browser'),
              ValueKey('concept_network_sent'),
              ValueKey('concept_network_received'),
            ],
            onChanged: _select,
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: PageView(
            controller: _pager,
            physics: SelahSegmentedMotion.pagePhysics,
            onPageChanged: widget.onChanged,
            children: [
              _body(widget.profiles, 0),
              _body(widget.sentProfiles, 1),
              _body(widget.receivedProfiles, 2),
            ],
          ),
        ),
      ],
    ),
  );
}

class _NetworkPortraitCard extends StatelessWidget {
  const _NetworkPortraitCard({
    required this.profile,
    required this.mode,
    required this.isMain,
    required this.onProfile,
    required this.onRequest,
    required this.onNext,
    this.onWithdraw,
    this.onAccept,
    this.onDecline,
    this.onShepherd,
  });

  final SeekerProfile profile;
  final int mode;
  final bool isMain;
  final VoidCallback onProfile;
  final VoidCallback onRequest;
  final VoidCallback onNext;
  final VoidCallback? onWithdraw;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;
  final VoidCallback? onShepherd;

  Widget _pill(String label, VoidCallback? callback, {bool gold = false}) =>
      GNActionPill(
        label: label,
        onTap: callback ?? () {},
        enabled: callback != null,
        goldAccent: gold,
      );

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onProfile,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Stack(
                fit: StackFit.expand,
                children: [SelahProfileImage(profile.photoUrl)],
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 14),
      Text(
        '${profile.firstName.characters.first}., ${profile.age}',
        textAlign: TextAlign.center,
        style: SelahText.heading(size: 25),
      ),
      const SizedBox(height: 2),
      Text(
        profile.city,
        textAlign: TextAlign.center,
        style: SelahText.subtext(size: 11.75),
      ),
      const SizedBox(height: 11),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shield_outlined,
            size: 19,
            color: gnGold.withValues(alpha: .88),
          ),
          const SizedBox(width: 9),
          Flexible(
            child: Text(
              'Main Shepherd · Father',
              style: SelahText.body(size: 13.25),
            ),
          ),
          const SizedBox(width: 8),
          const GNVerifiedBadge(),
        ],
      ),
      if (mode != 0) ...[
        const SizedBox(height: 8),
        Text(
          mode == 1
              ? 'Request sent · Awaiting their Main Shepherd'
              : 'Request received · Their Main Shepherd is waiting',
          textAlign: TextAlign.center,
          style: SelahText.subtext(size: 10.5),
        ),
      ],
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(child: _pill('View profile', onProfile)),
          const SizedBox(width: 10),
          Expanded(
            child: mode == 0
                ? KeyedSubtree(
                    key: const ValueKey('concept_network_suggestion'),
                    child: _pill(
                      isMain ? 'Speak to Shepherd' : 'Ask Main Shepherd',
                      isMain ? onRequest : null,
                      gold: true,
                    ),
                  )
                : mode == 1
                ? _pill('Withdraw request', onWithdraw)
                : _pill('View Shepherd', onShepherd, gold: true),
          ),
        ],
      ),
      const SizedBox(height: 7),
      SizedBox(
        height: 44,
        child: mode == 0
            ? GNActionPill(label: 'Next', onTap: onNext, borderless: true)
            : mode == 1
            ? Center(
                child: Text(
                  'Waiting for their family to respond',
                  style: SelahText.subtext(size: 11),
                ),
              )
            : Row(
                children: [
                  Expanded(child: _pill('Not for us', onDecline)),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: _pill('Connect', onAccept, gold: true),
                  ),
                ],
              ),
      ),
    ],
  );
}

class _DashboardSection extends StatelessWidget {
  const _DashboardSection({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(left: 2, bottom: 10),
        child: Text(
          label,
          style: SelahText.chapterLabel(color: SelahColors.ink(.54)),
        ),
      ),
      child,
    ],
  );
}

class _DashboardStatusCard extends StatelessWidget {
  const _DashboardStatusCard({
    required this.icon,
    required this.eyebrow,
    required this.title,
    required this.detail,
    this.actionLabel,
    this.onTap,
    this.premiumBoundary = false,
  });

  final IconData icon;
  final String eyebrow;
  final String title;
  final String detail;
  final String? actionLabel;
  final VoidCallback? onTap;
  final bool premiumBoundary;

  @override
  Widget build(BuildContext context) => Container(
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
        Icon(
          icon,
          size: 21,
          color: premiumBoundary
              ? SelahColors.journeyGold
              : SelahColors.ink(.72),
        ),
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
              if (actionLabel != null && onTap != null) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: onTap,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    actionLabel!,
                    style: SelahText.button(
                      size: 13,
                      color: premiumBoundary
                          ? SelahColors.journeyGold
                          : SelahColors.foreground,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

class _DashboardAttentionCard extends StatelessWidget {
  const _DashboardAttentionCard({
    required this.title,
    required this.body,
    required this.cta,
    required this.onTap,
  });
  final String title;
  final String body;
  final String cta;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: SelahColors.surfaceEmphasisFill,
    borderRadius: BorderRadius.circular(14),
    child: InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: SelahColors.surfaceEmphasisBorder),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: SelahText.body(size: 13.5, color: Colors.white),
                  ),
                  const SizedBox(height: 3),
                  Text(body, style: SelahText.subtext(size: 11.5)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(cta, style: SelahText.body(size: 12.5, color: Colors.white)),
            Icon(Icons.chevron_right, color: SelahColors.ink(.54), size: 16),
          ],
        ),
      ),
    ),
  );
}
