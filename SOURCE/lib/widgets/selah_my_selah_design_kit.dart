import 'package:flutter/material.dart';

import '../models/selah_dashboard_resolution.dart';
import '../models/selah_supportive_dashboard.dart';
import '../theme/selah_colors.dart';
import '../theme/selah_text.dart';
import 'selah_loading.dart';

/// One projection for the selected dashboard and visual candidates. No service reads, invented
/// Insight families, notification writes or presentation-specific resolvers.
class MySelahReviewData {
  final DashboardResolution resolution;
  final bool isInsights;
  final bool fixtureMode;
  final DateTime clock;
  final List<SupportiveCard> actions;
  final List<SupportiveCard> statuses;
  final List<SupportiveCard> changes;
  final List<SupportiveCard> editorial;
  final List<SupportiveCard> insights;
  final int actionCount;
  final bool hasHiddenInsights;
  final bool allInsightsHidden;

  MySelahReviewData({
    required DashboardResolution resolution,
    required bool isInsights,
    required bool fixtureMode,
    required DateTime clock,
    List<SupportiveCard> fixtureCards = const [],
    Set<String> hiddenCards = const {},
    Set<SupportiveSection> mutedSections = const {},
    bool showAllActions = false,
  }) : this._fromCards(
         resolution: resolution,
         isInsights: isInsights,
         fixtureMode: fixtureMode,
         clock: clock,
         cards: mergeSupportiveCards(
           supportiveCardsFromResolution(resolution, comparisonClock: clock),
           fixtureMode ? fixtureCards : const [],
         ),
         hiddenCards: hiddenCards,
         mutedSections: mutedSections,
         showAllActions: showAllActions,
       );

  MySelahReviewData._fromCards({
    required this.resolution,
    required this.isInsights,
    required this.fixtureMode,
    required this.clock,
    required List<SupportiveCard> cards,
    required Set<String> hiddenCards,
    required Set<SupportiveSection> mutedSections,
    required bool showAllActions,
  }) : actions = List.unmodifiable(
         cards
             .where((c) => c.section == SupportiveSection.needsYou)
             .take(showAllActions ? cards.length : 3),
       ),
       actionCount = cards
           .where((c) => c.section == SupportiveSection.needsYou)
           .length,
       statuses = List.unmodifiable(
         cards.where((c) => c.section == SupportiveSection.stand),
       ),
       changes = List.unmodifiable(
         cards.where((c) => c.section == SupportiveSection.changed).take(3),
       ),
       editorial = List.unmodifiable(
         cards.where((c) => c.section == SupportiveSection.fromSelah).take(1),
       ),
       insights = List.unmodifiable(
         resolution.insightsState == DashboardSectionState.available
             ? cards.where(
                 (c) =>
                     c.section.isInsight &&
                     !hiddenCards.contains(c.id) &&
                     !mutedSections.contains(c.section),
               )
             : const <SupportiveCard>[],
       ),
       hasHiddenInsights = hiddenCards.isNotEmpty || mutedSections.isNotEmpty,
       allInsightsHidden =
           cards.any((c) => c.section.isInsight) &&
           !cards.any(
             (c) =>
                 c.section.isInsight &&
                 !hiddenCards.contains(c.id) &&
                 !mutedSections.contains(c.section),
           );

  bool get loadingNow =>
      resolution.answer.kind == DashboardAnswerKind.loading ||
      resolution.journey.state == DashboardJourneyResolutionState.loading ||
      resolution.stableState.family.state == DashboardSourceState.loading ||
      resolution.updatesState == DashboardSectionState.loading;

  bool get completeNow =>
      resolution.sourceHealth == DashboardSourceHealth.complete &&
      resolution.answer.kind != DashboardAnswerKind.refreshRequired &&
      !loadingNow &&
      resolution.journey.state == DashboardJourneyResolutionState.available &&
      resolution.stableState.family.isAvailable &&
      resolution.updatesState == DashboardSectionState.available &&
      !resolution.updatesAreLastKnown;

  bool get quietNow =>
      completeNow &&
      actions.isEmpty &&
      statuses.isEmpty &&
      changes.isEmpty &&
      editorial.isEmpty;
}

/// Shared factual rendering and callbacks. Candidate files only arrange these
/// parts; they cannot independently reclassify, deduplicate or route a card.
class MySelahDesignKit {
  static const ink = SelahColors.inkColor;
  static const secondary = SelahColors.muted;
  static const lavender = SelahColors.lake;
  final MySelahReviewData data;
  final String? firstName;
  final bool showAllActions;
  final String? expandedEvidence;
  final ValueChanged<SupportiveCard> onOpen;
  final ValueChanged<String> onEvidence;
  final ValueChanged<SupportiveCard> onHide;
  final ValueChanged<SupportiveCard> onMute;
  final VoidCallback onMoreActions;
  final VoidCallback onResetInsights;
  final VoidCallback? onRetry;

  const MySelahDesignKit({
    required this.data,
    required this.firstName,
    required this.showAllActions,
    required this.expandedEvidence,
    required this.onOpen,
    required this.onEvidence,
    required this.onHide,
    required this.onMute,
    required this.onMoreActions,
    required this.onResetInsights,
    this.onRetry,
  });

  Widget heading(String text, {double size = 26}) => Text(
    text,
    style: SelahText.heading(size: size, color: ink).copyWith(height: 1.22),
  );
  Widget label(String text) {
    final sectionLabel = text.isNotEmpty && text == text.toUpperCase();
    return Text(
      text,
      style: SelahText.body(size: sectionLabel ? 11 : 13, color: secondary)
          .copyWith(
            fontWeight: sectionLabel ? FontWeight.w600 : FontWeight.w400,
            letterSpacing: sectionLabel ? 1.32 : 0,
            height: 1.5,
          ),
    );
  }

  Widget body(String text) => Text(
    text,
    style: SelahText.body(size: 15, color: secondary).copyWith(height: 1.5),
  );

  Widget rowTitle(String text) => Text(
    text,
    style: SelahText.body(
      size: 15,
      color: ink,
    ).copyWith(fontWeight: FontWeight.w600, height: 1.5),
  );

  Widget get rule => const Divider(height: 28, color: SelahColors.line);

  Widget get notice {
    if (data.isInsights) {
      return switch (data.resolution.insightsState) {
        DashboardSectionState.loading => const Padding(
          padding: EdgeInsets.symmetric(vertical: 28),
          child: SelahLoading(label: 'Checking Insights'),
        ),
        DashboardSectionState.partial ||
        DashboardSectionState.unavailable => _notice(
          'my-selah-insights-failed',
          'Insights could not be refreshed',
          'We could not confirm whether there is something to show.',
        ),
        DashboardSectionState.available => const SizedBox.shrink(),
      };
    }
    if (data.loadingNow) {
      return const Padding(
        key: ValueKey('my-selah-loading'),
        padding: EdgeInsets.symmetric(vertical: 28),
        child: SelahLoading(label: 'Checking what needs you'),
      );
    }
    if (data.resolution.updatesAreLastKnown) {
      return _notice(
        'my-selah-last-known',
        'Last known · refresh needed',
        'Earlier changes are shown below. We could not refresh this summary.',
      );
    }
    if (!data.completeNow) {
      return _notice(
        'my-selah-source-gap',
        'Some information is unavailable',
        'There may be more to show. Check again before relying on this summary.',
      );
    }
    return const SizedBox.shrink();
  }

  Widget _notice(String key, String title, String detail) => Container(
    key: ValueKey(key),
    margin: const EdgeInsets.only(bottom: 24),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: SelahColors.surface,
      border: Border.all(color: SelahColors.line),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: SelahText.body(size: 14, color: ink)),
        const SizedBox(height: 7),
        body(detail),
        if (onRetry != null)
          _button('Check again', onRetry!, key: 'my-selah-retry'),
      ],
    ),
  );

  Widget get empty {
    if (data.isInsights &&
        data.resolution.insightsState == DashboardSectionState.available &&
        data.insights.isEmpty) {
      return Padding(
        key: ValueKey(
          data.allInsightsHidden
              ? 'my-selah-insights-hidden'
              : 'my-selah-insights-empty',
        ),
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            label(
              data.allInsightsHidden
                  ? 'YOUR PREVIEW CHOICES'
                  : 'ROOM TO UNDERSTAND',
            ),
            const SizedBox(height: 20),
            heading(
              data.allInsightsHidden
                  ? 'These Insights are hidden in this preview'
                  : 'Insights will grow with your SELAH experience',
              size: 28,
            ),
            const SizedBox(height: 18),
            body(
              data.allInsightsHidden
                  ? 'Your preview choices are not saved to your account.'
                  : 'SELAH will only show an Insight when reliable information genuinely supports it. We will not guess or fill this page with generic statistics.',
            ),
          ],
        ),
      );
    }
    if (!data.isInsights && data.quietNow) {
      return Padding(
        key: const ValueKey('my-selah-quiet'),
        padding: const EdgeInsets.symmetric(vertical: 56, horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(width: 32, height: 2, color: lavender),
            const SizedBox(height: 28),
            heading('You’re all caught up', size: 32),
            const SizedBox(height: 16),
            body('Nothing needs your attention right now.'),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }

  /// Index/disclosure summary retains provenance even before details open.
  Widget summary(SupportiveCard card, {bool showCategory = false}) => Column(
    key: ValueKey('my-selah-item-${card.id}'),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (showCategory) ...[
        label(card.section.label),
        const SizedBox(height: 10),
      ],
      if (card.isGeneralGuide) ...[
        label('General guidance'),
        const SizedBox(height: 6),
      ],
      if (card.section == SupportiveSection.changed &&
          data.resolution.updatesAreLastKnown)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: label('Last known · not current'),
        ),
      rowTitle(card.title),
      if (card.date != null) ...[
        const SizedBox(height: 8),
        label(_date(card.date!)),
      ],
      if (card.isUnread == true) ...[
        const SizedBox(height: 6),
        label('Unread'),
      ],
    ],
  );

  Widget item(
    SupportiveCard card, {
    bool prominent = false,
    bool compact = false,
    bool showCategory = false,
  }) {
    final evidence = card.evidence;
    final open = expandedEvidence == card.id;
    final routeAllowed =
        card.actionLabel != null &&
        (data.fixtureMode ||
            (card.target != SelahDashboardTarget.none &&
                card.target != SelahDashboardTarget.notifications));
    return Column(
      key: ValueKey('my-selah-item-${card.id}'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showCategory) ...[
          label(card.section.label),
          const SizedBox(height: 12),
        ],
        if (card.isGeneralGuide) ...[
          label('General guidance'),
          const SizedBox(height: 6),
        ],
        if (card.section == SupportiveSection.changed &&
            data.resolution.updatesAreLastKnown)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: label('Last known · not current'),
          ),
        rowTitle(card.title),
        if (card.detail?.trim().isNotEmpty == true) ...[
          const SizedBox(height: 8),
          body(card.detail!),
        ],
        if (card.date != null) ...[
          const SizedBox(height: 10),
          label(_date(card.date!)),
        ],
        // Only true carries an unread indication; null is not described as read.
        if (card.isUnread == true) ...[
          const SizedBox(height: 6),
          label('Unread'),
        ],
        if (routeAllowed)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _button(
              card.actionLabel!,
              () => onOpen(card),
              key: 'my-selah-route-${card.id}',
              route: true,
            ),
          ),
        if (card.section.isInsight &&
            evidence != null &&
            !card.isGeneralGuide) ...[
          const SizedBox(height: 8),
          _button(
            'Why am I seeing this?',
            () => onEvidence(card.id),
            key: 'my-selah-evidence-${card.id}',
            expanded: open,
          ),
          if (open)
            Container(
              key: ValueKey('my-selah-evidence-body-${card.id}'),
              padding: const EdgeInsets.only(left: 14, top: 12, bottom: 12),
              decoration: BoxDecoration(
                border: Border(left: BorderSide(color: SelahColors.line)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  label('EVIDENCE'),
                  const SizedBox(height: 5),
                  body(evidence.summary),
                  const SizedBox(height: 14),
                  label('PERIOD'),
                  const SizedBox(height: 5),
                  body(evidence.period),
                  const SizedBox(height: 14),
                  label('WHY THIS IS SHOWN'),
                  const SizedBox(height: 5),
                  body(evidence.reason),
                  const SizedBox(height: 14),
                  label('LIMITATION'),
                  const SizedBox(height: 5),
                  body(evidence.limitation),
                  if (data.fixtureMode) ...[
                    const SizedBox(height: 14),
                    body('Preview only — no account preference is saved.'),
                    _button(
                      'Hide this Insight',
                      () => onHide(card),
                      key: 'my-selah-hide-${card.id}',
                    ),
                    _button(
                      'Mute this type',
                      () => onMute(card),
                      key: 'my-selah-mute-${card.id}',
                    ),
                  ],
                ],
              ),
            ),
        ],
      ],
    );
  }

  Widget _button(
    String text,
    VoidCallback callback, {
    String? key,
    bool route = false,
    bool? expanded,
  }) => Semantics(
    expanded: expanded,
    child: TextButton(
      key: key == null ? null : ValueKey(key),
      onPressed: callback,
      style: TextButton.styleFrom(
        foregroundColor: ink,
        minimumSize: const Size(48, 40),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
        side: const BorderSide(color: SelahColors.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        alignment: Alignment.centerLeft,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(text, style: SelahText.button(size: 13.5, color: ink)),
          ),
          if (route) ...[
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_rounded, size: 16),
          ],
          if (expanded != null) ...[
            const SizedBox(width: 8),
            Icon(expanded ? Icons.expand_less : Icons.expand_more, size: 18),
          ],
        ],
      ),
    ),
  );

  Widget get moreActions => data.actionCount <= 3
      ? const SizedBox.shrink()
      : _button(
          showAllActions
              ? 'Show fewer obligations'
              : '${data.actionCount - 3} more to review',
          onMoreActions,
          key: 'my-selah-more-actions',
          expanded: showAllActions,
        );

  Widget get resetInsights => !data.hasHiddenInsights
      ? const SizedBox.shrink()
      : _button(
          'Reset hidden preview Insights',
          onResetInsights,
          key: 'my-selah-reset-insights',
        );

  String _date(DateTime date) {
    // Stable, explicit calendar text, never inferred elapsed/ended dates.
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final utc = date.toUtc();
    return '${utc.day} ${months[utc.month - 1]} ${utc.year}';
  }
}
