import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import '../data/selah_membership_catalog.dart';

import '../models/selah_dashboard_resolution.dart';
import '../models/selah_supportive_dashboard.dart';
import '../services/selah_developer_access.dart';
import '../services/selah_promotion_engine.dart';
import '../theme/selah_colors.dart';
import '../theme/selah_text.dart';
import 'selah_my_selah_design_kit.dart';
import 'floating_nav_bar.dart';
import 'selah_fade_edges.dart';
import 'selah_gold_action_pill.dart';
import 'selah_locked_feature_upgrade.dart';
import 'selah_segmented_toggle.dart';

/// Founder-selected Quiet Index: no section subtitles, one fine divider
/// between nonempty groups. Domain state and owner actions remain elsewhere.
/// Ordinary data is renderable in every build; fictional supplements require
/// both the existing developer authority and a non-release build.
class SelahQuietDashboard extends StatefulWidget {
  final DashboardResolution resolution;
  final List<SupportiveCard> fixtureCards;
  final bool fixtureMode;
  final DateTime? comparisonClock;
  final String? firstName;
  final int? selectedTabIndex;
  final ValueChanged<int>? onTabChanged;
  final ValueChanged<SupportiveCard>? onNavigate;
  final VoidCallback? onRetry;
  final VoidCallback? onMarkAllNotificationsRead;
  final int unreadCount;
  final Future<void> Function()? onRefresh;
  final bool insightsEntitled;
  final bool blankUntilDeveloperSelection;

  /// Optional presentation-only rehearsal: one information page, no Insights
  /// pager. Ordinary callers keep the existing two-section dashboard.
  final bool singlePage;

  /// Presentation-only heading placement. Ordinary callers keep the original.
  final Alignment titleAlignment;

  /// Optional caller-owned presentation/upgrade seams for isolated rehearsals.
  /// Ordinary callers retain the current canvas and upgrade destination.
  final Decoration? decoration;
  final VoidCallback? onInsightsUpgrade;

  const SelahQuietDashboard({
    super.key,
    required this.resolution,
    this.fixtureCards = const [],
    this.fixtureMode = false,
    this.comparisonClock,
    this.firstName,
    this.selectedTabIndex,
    this.onTabChanged,
    this.onNavigate,
    this.onRetry,
    this.onMarkAllNotificationsRead,
    this.unreadCount = 0,
    this.onRefresh,
    this.insightsEntitled = true,
    this.blankUntilDeveloperSelection = false,
    this.singlePage = false,
    this.titleAlignment = Alignment.centerLeft,
    this.decoration,
    this.onInsightsUpgrade,
  });

  @override
  State<SelahQuietDashboard> createState() => _SelahQuietDashboardState();
}

class _SelahQuietDashboardState extends State<SelahQuietDashboard> {
  late int _tab;
  String? _expanded;
  bool _showAllActions = false;
  final _hidden = <String>{};
  final _muted = <SupportiveSection>{};
  late final PageController _pager;
  final _nowScroll = ScrollController();
  final _insightsScroll = ScrollController();
  int _generation = 0;
  double _pagerPosition = 0;
  late int _settledPage;

  bool get _allowed =>
      !widget.fixtureMode ||
      (!kReleaseMode && SelahDeveloperAccess.canUseDeveloperTools);

  @override
  void initState() {
    super.initState();
    _tab = widget.singlePage ? 0 : (widget.selectedTabIndex ?? 0).clamp(0, 1);
    _pagerPosition = _tab.toDouble();
    _settledPage = _tab;
    _pager = PageController(initialPage: _tab)..addListener(_trackPager);
    SelahDeveloperAccess.authorizationChanges.addListener(_clearAuthorityState);
  }

  void _clearAuthorityState() {
    if (!mounted) return;
    setState(() {
      _generation++;
      _resetPrivateState();
    });
  }

  void _resetPrivateState() {
    _expanded = null;
    _hidden.clear();
    _muted.clear();
    _showAllActions = false;
  }

  @override
  void didUpdateWidget(covariant SelahQuietDashboard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fixtureMode != widget.fixtureMode ||
        oldWidget.singlePage != widget.singlePage) {
      _generation++;
      _resetPrivateState();
      if (widget.singlePage) {
        _tab = _settledPage = 0;
        _pagerPosition = 0;
      }
    }
    if (!widget.singlePage &&
        widget.selectedTabIndex != null &&
        oldWidget.selectedTabIndex != widget.selectedTabIndex) {
      final target = widget.selectedTabIndex!.clamp(0, 1);
      void move() {
        if (!mounted || !_pager.hasClients || target == _settledPage) return;
        SelahSegmentedMotion.animateToPage(_pager, target);
      }

      if (_pager.hasClients) {
        move();
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) => move());
      }
    }
  }

  void _trackPager() {
    if (!mounted || !_pager.hasClients || _pager.page == null) return;
    final position = _pager.page!.clamp(0.0, 1.0);
    final settled = position == position.roundToDouble()
        ? position.round()
        : null;
    final pageChanged = settled != null && settled != _settledPage;
    final positionChanged = (position - _pagerPosition).abs() >= 0.001;
    if (!positionChanged && !pageChanged) return;
    setState(() {
      if (pageChanged) {
        _pagerPosition = settled.toDouble();
      } else if (positionChanged) {
        _pagerPosition = position;
      }
      if (!pageChanged) return;
      _settledPage = settled;
      _tab = settled;
      _expanded = null;
      _generation++;
    });
    if (pageChanged) widget.onTabChanged?.call(settled);
  }

  void _selectTab(int tab) {
    if (!_allowed || widget.singlePage) return;
    SelahSegmentedMotion.animateToPage(_pager, tab);
  }

  @override
  void dispose() {
    SelahDeveloperAccess.authorizationChanges.removeListener(
      _clearAuthorityState,
    );
    _pager.dispose();
    _nowScroll.dispose();
    _insightsScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Never re-interpret a denied sample snapshot as ordinary account data.
    if (!_allowed) {
      return const SizedBox.shrink(key: ValueKey('quiet-index-fixture-denied'));
    }
    return Container(
      key: const ValueKey('my-selah-quiet-dashboard'),
      decoration:
          widget.decoration ?? const BoxDecoration(color: SelahColors.mist),
      child: Material(
        color: Colors.transparent,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 16, 22, 8),
                child: Align(
                  alignment: widget.titleAlignment,
                  child: Text(
                    'My Selah',
                    key: const ValueKey('my-selah-main-title'),
                    textAlign: widget.titleAlignment.x > 0
                        ? TextAlign.right
                        : TextAlign.left,
                    style: SelahText.pageTitle(),
                  ),
                ),
              ),
              if (!widget.singlePage)
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 0, 22, 4),
                  child: _navigation(),
                ),
              Expanded(
                child: widget.singlePage
                    ? _content(context, 0, _nowScroll)
                    : PageView(
                        key: const ValueKey('my-selah-pages'),
                        controller: _pager,
                        physics: SelahSegmentedMotion.pagePhysics,
                        children: [
                          _content(context, 0, _nowScroll),
                          _content(context, 1, _insightsScroll),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _content(BuildContext context, int tab, ScrollController scroll) {
    final generation = _generation;
    final fixtureMode = widget.fixtureMode;
    final singlePage = widget.singlePage;
    bool current() =>
        mounted &&
        _allowed &&
        generation == _generation &&
        fixtureMode == widget.fixtureMode &&
        singlePage == widget.singlePage;
    if (widget.blankUntilDeveloperSelection) {
      return _scrollSurface(
        ListView(
          key: ValueKey('my-selah-quiet-scroll-$tab'),
          controller: scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 130),
        ),
        current,
        tab,
      );
    }
    final data = MySelahReviewData(
      resolution: widget.resolution,
      isInsights: tab == 1,
      fixtureMode: fixtureMode,
      fixtureCards: widget.fixtureCards,
      clock: widget.comparisonClock ?? DateTime.now(),
      hiddenCards: _hidden,
      mutedSections: _muted,
      showAllActions: _showAllActions,
    );
    final kit = MySelahDesignKit(
      data: data,
      firstName: widget.firstName,
      showAllActions: _showAllActions,
      expandedEvidence: _expanded,
      onOpen: (card) {
        if (!current()) return;
        setState(() => _expanded = null);
        widget.onNavigate?.call(card);
      },
      onEvidence: (id) {
        if (current()) setState(() => _expanded = _expanded == id ? null : id);
      },
      onHide: (card) {
        if (!current() || !fixtureMode) return;
        setState(() {
          _hidden.add(card.id);
          _expanded = null;
        });
      },
      onMute: (card) {
        if (!current() || !fixtureMode) return;
        setState(() {
          _muted.add(card.section);
          _expanded = null;
        });
      },
      onMoreActions: () {
        if (current()) setState(() => _showAllActions = !_showAllActions);
      },
      onResetInsights: () {
        if (current()) setState(_resetPrivateState);
      },
      onRetry: widget.onRetry == null
          ? null
          : () {
              if (current()) widget.onRetry!();
            },
    );
    final groups = <Widget>[];
    final insightsBlocked = data.isInsights && !widget.insightsEntitled;
    if (data.isInsights && !insightsBlocked) {
      for (final section in SupportiveSection.values.where(
        (v) => v.isInsight,
      )) {
        final cards = data.insights.where((c) => c.section == section).toList();
        if (cards.isNotEmpty) groups.add(_items(cards.map((c) => kit.item(c))));
      }
    } else if (!data.isInsights) {
      if (data.actions.isNotEmpty) {
        groups.add(
          _items([
            kit.item(data.actions.first, prominent: true),
            for (final card in data.actions.skip(1))
              kit.item(card, compact: true),
            if (data.actionCount > 3) kit.moreActions,
          ]),
        );
      }
      if (data.statuses.isNotEmpty) {
        groups.add(_items(data.statuses.map((c) => kit.item(c))));
      }
      final canMarkRead =
          !fixtureMode &&
          widget.onMarkAllNotificationsRead != null &&
          (widget.unreadCount > 0 ||
              data.changes.any((c) => c.isUnread == true));
      if (data.changes.isNotEmpty || canMarkRead) {
        groups.add(
          _items([
            ...data.changes.map((c) => _disclosure(kit, c)),
            if (canMarkRead)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  key: const ValueKey('quiet-index-mark-read'),
                  onPressed: () {
                    if (current() && !fixtureMode) {
                      widget.onMarkAllNotificationsRead!();
                    }
                  },
                  child: Text(
                    'Mark all read',
                    style: SelahText.body(
                      size: 12.5,
                      color: MySelahDesignKit.secondary,
                    ),
                  ),
                ),
              ),
          ]),
        );
      }
      if (data.editorial.isNotEmpty) {
        groups.add(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Source attribution, not a category heading.
              kit.label('Selah'),
              const SizedBox(height: 10),
              _items(data.editorial.map((c) => _disclosure(kit, c))),
            ],
          ),
        );
      }
    }
    return _scrollSurface(
      ListView(
        key: ValueKey('my-selah-quiet-scroll-$tab'),
        controller: scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(22, 14, 22, 130),
        children: [
          if (insightsBlocked)
            Padding(
              key: const ValueKey('quiet-index-insights-locked'),
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.lock_rounded,
                    key: const ValueKey('seeker-insights-content-lock'),
                    color: SelahColors.lake,
                    size: 28,
                  ),
                  const SizedBox(height: 16),
                  kit.heading(
                    'Insights are part of ${SelahMembershipCatalog.seekerOneTitle}',
                  ),
                  const SizedBox(height: 18),
                  kit.body(
                    'Upgrade to unlock deeper activity and Journey insights. '
                    'Your current Journey and account controls remain available.',
                  ),
                  const SizedBox(height: 24),
                  SelahGoldActionPill(
                    key: const ValueKey('seeker-insights-upgrade'),
                    label: 'View ${SelahMembershipCatalog.seekerOneTitle}',
                    icon: Icons.workspace_premium_outlined,
                    onPressed:
                        widget.onInsightsUpgrade ??
                        () => openSeekerLockedFeaturePlan(
                          context,
                          feature: SelahPromotionFeature.selahIntelligence,
                        ),
                  ),
                ],
              ),
            )
          else
            kit.notice,
          if (data.quietNow && !data.isInsights)
            Padding(
              key: const ValueKey('my-selah-quiet'),
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  kit.heading('You’re all caught up', size: 30),
                  const SizedBox(height: 16),
                  kit.body('Nothing needs your attention right now.'),
                ],
              ),
            ),
          if (data.isInsights &&
              !insightsBlocked &&
              data.insights.isEmpty &&
              data.resolution.insightsState == DashboardSectionState.available)
            _emptyInsights(kit),
          for (var i = 0; i < groups.length; i++) ...[
            if (i > 0)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Divider(
                  key: ValueKey('quiet-index-group-rule-$i'),
                  height: 1,
                  thickness: 1,
                  color: SelahColors.line,
                ),
              ),
            groups[i],
          ],
          if (data.isInsights && !insightsBlocked) kit.resetInsights,
        ],
      ),
      current,
      tab,
    );
  }

  Widget _scrollSurface(Widget child, bool Function() current, int tab) {
    if (widget.onRefresh != null && !widget.fixtureMode) {
      child = RefreshIndicator(
        color: SelahColors.accentOnCanvas,
        backgroundColor: SelahColors.surfaceFill,
        onRefresh: () async {
          if (current()) await widget.onRefresh!();
        },
        child: child,
      );
    }
    return SelahFadeEdges.bottomOnly(
      key: ValueKey(
        'dashboard-nav-scroll-fade-${tab == 0 ? 'now' : 'insights'}',
      ),
      bottom:
          SelahNavBarMetrics.restingHeight +
          SelahNavBarMetrics.bottomInset +
          10,
      child: child,
    );
  }

  Widget _items(Iterable<Widget> values) {
    final items = values.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: SelahColors.surface,
              border: Border.all(color: SelahColors.line),
              borderRadius: BorderRadius.circular(14),
            ),
            child: items[i],
          ),
        ],
      ],
    );
  }

  Widget _disclosure(MySelahDesignKit kit, SupportiveCard card) {
    final expanded = _expanded == card.id;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (expanded)
          KeyedSubtree(
            key: ValueKey('quiet-index-details-${card.id}'),
            child: kit.item(card),
          )
        else
          kit.summary(card),
        Semantics(
          expanded: expanded,
          child: TextButton(
            key: ValueKey('quiet-index-disclosure-${card.id}'),
            onPressed: () => kit.onEvidence(card.id),
            style: TextButton.styleFrom(
              foregroundColor: SelahColors.lake,
              minimumSize: const Size(48, 40),
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
              side: const BorderSide(color: SelahColors.line),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.centerLeft,
            ),
            child: Semantics(
              label: '${expanded ? 'Close' : 'Read'} details: ${card.title}',
              excludeSemantics: true,
              child: Row(
                children: [
                  Expanded(
                    child: kit.label(
                      expanded ? 'Close details' : 'Read details',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(
                    expanded ? Icons.remove_rounded : Icons.add_rounded,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _emptyInsights(MySelahDesignKit kit) => Padding(
    key: ValueKey(
      kit.data.allInsightsHidden
          ? 'my-selah-insights-hidden'
          : 'my-selah-insights-empty',
    ),
    padding: const EdgeInsets.symmetric(vertical: 32),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        kit.heading(
          kit.data.allInsightsHidden
              ? 'These Insights are hidden in this preview'
              : 'Insights will grow with your Selah experience',
          size: 27,
        ),
        const SizedBox(height: 18),
        kit.body(
          kit.data.allInsightsHidden
              ? 'Your preview choices are not saved to your account.'
              : 'Selah will only show an Insight when reliable information genuinely supports it. We will not guess or fill this page with generic statistics.',
        ),
      ],
    ),
  );

  Widget _navigation() => Semantics(
    label: 'My Selah section selector',
    child: SelahSegmentedToggle(
      key: const ValueKey('my-selah-tab-slider'),
      labels: const ['Now', 'Insights'],
      position: _pagerPosition,
      segmentKeys: const [
        ValueKey('my-selah-now-tab'),
        ValueKey('my-selah-insights-tab'),
      ],
      lockedIndexes: widget.insightsEntitled ? const {} : const {1},
      onChanged: _selectTab,
    ),
  );
}
