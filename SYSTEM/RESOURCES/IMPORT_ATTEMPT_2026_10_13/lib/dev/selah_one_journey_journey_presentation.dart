// Current Journey presentation with caller-owned, disposable local actions.
// No JourneyFlowScreen, transport, member singleton or preference mutation.
import 'dart:async';

import 'package:flutter/material.dart';

import '../data/journey_questions.dart';
import '../data/selah_journey_scroll.dart';
import '../data/selah_journey_stages.dart';
import '../theme/selah_colors.dart';
import '../theme/selah_text.dart';
import '../widgets/selah_profile_image.dart';

/// Current compact mutual-action layout with exclusively caller-owned facts.
/// Photos must be offline data URLs; a missing photo keeps the current neutral
/// initial, never a remote member image.
class SelahConceptJourneyThresholdBody extends StatelessWidget {
  const SelahConceptJourneyThresholdBody({
    super.key,
    required this.firstName,
    required this.mine,
    required this.theirs,
    required this.headline,
    required this.body,
    this.selfPhoto,
    this.otherPhoto,
    this.greeting = false,
    this.actionKey,
    this.actionLabel,
    this.onAction,
    this.actionIcon = Icons.waving_hand_outlined,
  });
  final String firstName;
  final bool mine;
  final bool theirs;
  final String headline;
  final String body;
  final String? selfPhoto;
  final String? otherPhoto;
  final bool greeting;
  final Key? actionKey;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData actionIcon;

  @override
  Widget build(BuildContext context) {
    Widget portrait(bool you, bool complete) {
      final name = you ? 'You' : firstName;
      final label = greeting
          ? you
                ? complete
                      ? 'Greeting sent'
                      : theirs
                      ? 'Return Greeting'
                      : 'Not sent'
                : complete
                ? 'Greeting received'
                : 'Awaiting Greeting'
          : complete
          ? 'Done'
          : 'Waiting';
      final photo = you ? selfPhoto : otherPhoto;
      return Semantics(
        label: '$name, $label',
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 420),
          opacity: complete ? 1 : 0.38,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 420),
                curve: Curves.easeOutCubic,
                width: 68,
                height: 68,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    width: 2,
                    color: greeting && !complete
                        ? Colors.transparent
                        : (complete ? SelahColors.journeyGold : Colors.white)
                              .withValues(alpha: complete ? 0.9 : 0.32),
                  ),
                  boxShadow: complete
                      ? [
                          BoxShadow(
                            color: const Color(
                              0xFFE8C98A,
                            ).withValues(alpha: 0.2),
                            blurRadius: 12,
                          ),
                        ]
                      : const [],
                ),
                child: ClipOval(
                  child: photo != null && photo.startsWith('data:image/')
                      ? SelahProfileImage(photo, width: 60, height: 60)
                      : ColoredBox(
                          color: SelahColors.foreground.withValues(alpha: 0.1),
                          child: Center(
                            child: Text(
                              you
                                  ? 'You'
                                  : firstName.isEmpty
                                  ? '?'
                                  : firstName[0],
                              style: SelahText.subtext(size: you ? 11 : 19),
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 7),
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 26),
                child: SizedBox(
                  width: 92,
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: SelahText.subtext(
                      size: 10.5,
                      color: SelahColors.foreground.withValues(
                        alpha: complete ? 0.8 : 0.5,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 230,
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                Positioned(
                  top: 33,
                  left: 68,
                  width: 94,
                  child: Container(
                    height: greeting ? 1 : 1.5,
                    color: mine && theirs
                        ? SelahColors.journeyGold.withValues(alpha: 0.74)
                        : SelahColors.foreground.withValues(alpha: 0.28),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [portrait(true, mine), portrait(false, theirs)],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: Center(
              child: Text(
                headline,
                style: SelahText.heading(size: greeting ? 29 : 24),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 50),
            child: Center(
              child: Text(
                body,
                style: SelahText.subtext(size: greeting ? 14.5 : 14),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          const SizedBox(height: 48),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 130),
            child: Center(
              child: actionLabel == null
                  ? null
                  : _LocalRoundAction(
                      key: actionKey,
                      label: actionLabel!,
                      onTap: onAction,
                      icon: actionIcon,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The real first question and briefing, held as display-only in this bounded
/// comparison. It never submits, seals, rates or simulates an approval.
class SelahConceptJourneyFirstQuestion extends StatelessWidget {
  const SelahConceptJourneyFirstQuestion({super.key, required this.stage});
  final SelahJourneyStage stage;

  @override
  Widget build(BuildContext context) {
    final questions = JourneyQuestions.forStageValue(stage.value);
    if (questions == null) return const SizedBox.shrink();
    final phase = int.parse(stage.value.substring('phase_'.length));
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  stage.label.toUpperCase(),
                  style: SelahText.chapterLabel(color: SelahColors.ink(0.54)),
                ),
              ),
              Text(
                'Question 1 of ${questions.length}',
                style: SelahText.subtext(size: 11, color: SelahColors.ink(0.38)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              color: SelahColors.foreground.withValues(alpha: 0.045),
              border: const Border(
                left: BorderSide(color: SelahColors.journeyGold, width: 2),
              ),
            ),
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'You are answering privately. ',
                    style: SelahText.subtext(
                      size: 11.5,
                      color: SelahColors.journeyGold,
                    ),
                  ),
                  TextSpan(
                    text:
                        'After all ${questions.length}, you can review every answer before sealing. When you both seal, the answers open to both of you and your Shepherds.',
                    style: SelahText.subtext(
                      size: 11.5,
                      color: SelahColors.foreground.withValues(alpha: 0.66),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(questions.first.text, style: SelahText.heading(size: 17)),
          const SizedBox(height: 14),
          TextField(
            key: ValueKey('concept_phase_display_${stage.value}'),
            readOnly: true,
            maxLines: 5,
            maxLength: JourneyQuestions.answerCharacterLimitForPhase(phase),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              filled: true,
              fillColor: SelahColors.foreground.withValues(alpha: 0.06),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              hintText: 'In your own words…',
              hintStyle: TextStyle(color: SelahColors.ink(0.38)),
              counterStyle: SelahText.subtext(
                size: 11,
                color: SelahColors.ink(0.38),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LocalRoundAction extends StatelessWidget {
  const _LocalRoundAction({
    super.key,
    required this.label,
    required this.onTap,
    required this.icon,
  });
  final String label;
  final VoidCallback? onTap;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: onTap != null,
    label: label,
    onTap: onTap,
    excludeSemantics: true,
    child: Opacity(
      opacity: onTap == null ? 0.45 : 1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 76,
                  height: 76,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Transform.scale(
                        scale: 0.99,
                        child: Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(
                                0xFFE8C98A,
                              ).withValues(alpha: 0.28),
                            ),
                          ),
                        ),
                      ),
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: SelahColors.foreground.withValues(alpha: 0.1),
                          border: Border.all(
                            color: SelahColors.foreground.withValues(
                              alpha: 0.28,
                            ),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFFCEA2D1,
                              ).withValues(alpha: 0.14),
                              blurRadius: 21,
                            ),
                          ],
                        ),
                        child: Icon(
                          icon,
                          color: SelahColors.journeyGold,
                          size: 25,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  label,
                  style: SelahText.button(size: 13.5),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// JourneyFlowScreen's small header, Quiet ribbon and vertically paged stage
/// arrivals/actions. The stage is display truth supplied by the caller; moving
/// among these pages never completes a stage or changes the local model.
///
/// [localActionBody] must be a bounded page body (it may own a scrollable).
/// [decisionBody] is optional and remains guarded by the caller's thresholds.
/// [options] can contain the caller's existing current-style contextual menu;
/// by default the current header's balancing 48px space is retained.
class SelahConceptJourneyPresentation extends StatefulWidget {
  const SelahConceptJourneyPresentation({
    super.key,
    required this.firstName,
    required this.stage,
    required this.localActionBody,
    required this.onBack,
    required this.onTimeline,
    this.showBackButton = true,
    this.onBio,
    this.options,
    this.decisionBody,
    this.historyBodies = const {},
    this.onActionVisibilityChanged,
    this.onViewedStageChanged,
    this.reviewOpen = false,
  });

  final String firstName;
  final SelahJourneyStage stage;
  final Widget localActionBody;
  final VoidCallback onBack;
  final bool showBackButton;
  final VoidCallback onTimeline;
  final VoidCallback? onBio;
  final Widget? options;
  final Widget? decisionBody;
  final Map<String, Widget> historyBodies;
  final ValueChanged<bool>? onActionVisibilityChanged;
  final ValueChanged<SelahJourneyStage>? onViewedStageChanged;
  final bool reviewOpen;

  @override
  State<SelahConceptJourneyPresentation> createState() =>
      _SelahConceptJourneyPresentationState();
}

class _SelahConceptJourneyPresentationState
    extends State<SelahConceptJourneyPresentation> {
  final _frameKeys = <String, GlobalKey<_StagePagesState>>{};
  GlobalKey<_StagePagesState> get _frameKey => _frameKeys.putIfAbsent(
    widget.stage.value,
    () => GlobalKey<_StagePagesState>(),
  );
  String? _viewedStage;

  @override
  void didUpdateWidget(covariant SelahConceptJourneyPresentation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stage.value != widget.stage.value) _viewedStage = null;
  }

  @override
  Widget build(BuildContext context) {
    final surface = widget.stage.value;
    return Material(
      color: Colors.transparent,
      child: DecoratedBox(
        decoration: BoxDecoration(gradient: SelahColors.brandGradient),
        child: Stack(
          children: [
            Positioned.fill(child: _JourneyAtmosphere(stage: widget.stage)),
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 12, 4),
                    child: Row(
                      children: [
                        if (widget.showBackButton)
                          IconButton(
                            key: const ValueKey('concept_journey_back'),
                            tooltip: 'Back',
                            onPressed: widget.onBack,
                            icon: Icon(
                              Icons.arrow_back_ios_new,
                              color: SelahColors.ink(0.70),
                              size: 18,
                            ),
                          ),
                        Expanded(
                          child: Text(
                            'Journey with ${widget.firstName}',
                            style: SelahText.heading(size: 16),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        widget.options ?? const SizedBox(width: 48),
                      ],
                    ),
                  ),
                  SelahConceptJourneyRibbon(
                    stage: _viewedStage ?? widget.stage.value,
                    reviewOpen: widget.reviewOpen,
                    onCompletedStageTap: (order) =>
                        _frameKey.currentState?.showCompleted(order),
                  ),
                  Expanded(
                    child: _JourneyVerticalStageSwap(
                      surfaceKey: widget.stage.value,
                      child: _StagePages(
                        key: _frameKey,
                        stage: widget.stage,
                        localActionBody: widget.localActionBody,
                        decisionBody: widget.decisionBody,
                        historyBodies: widget.historyBodies,
                        onTimeline: widget.onTimeline,
                        onActionVisibilityChanged: (visible) {
                          if (!mounted || widget.stage.value != surface) return;
                          widget.onActionVisibilityChanged?.call(visible);
                        },
                        onViewedStageChanged: (stage) {
                          if (!mounted || widget.stage.value != surface) return;
                          setState(() => _viewedStage = stage.value);
                          widget.onViewedStageChanged?.call(stage);
                        },
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
}

/// Exact current Quiet ribbon, using the unchanged eight canonical labels.
class SelahConceptJourneyRibbon extends StatelessWidget {
  const SelahConceptJourneyRibbon({
    super.key,
    required this.stage,
    required this.onCompletedStageTap,
    this.reviewOpen = false,
  });

  final String stage;
  final ValueChanged<int> onCompletedStageTap;
  final bool reviewOpen;

  @override
  Widget build(BuildContext context) {
    final current = SelahJourneyStages.of(stage);
    if (current == null) return const SizedBox.shrink();
    const gold = SelahColors.journeyGold;
    final children = <Widget>[];
    for (final candidate in SelahJourneyStages.all) {
      if (children.isNotEmpty) children.add(const SizedBox(width: 3));
      if (candidate.order == current.order) {
        children.add(
          Flexible(
            fit: FlexFit.loose,
            child: IntrinsicWidth(
              child: Container(
                constraints: const BoxConstraints(minHeight: 24),
                padding: const EdgeInsets.symmetric(horizontal: 11),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: gold.withValues(alpha: 0.10),
                  border: Border.all(color: gold, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: gold.withValues(alpha: 0.30),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Text(
                  '${current.order} · ${reviewOpen ? SelahJourneyStages.familyReviewOverride : current.label}',
                  style: SelahText.subtext(size: 11.5, color: gold),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        );
      } else {
        final walked = candidate.order < current.order;
        children.add(
          Semantics(
            button: walked,
            enabled: walked,
            label: walked
                ? 'View completed Stage ${candidate.order}: ${candidate.label}'
                : 'Stage ${candidate.order}: ${candidate.label}',
            child: InkResponse(
              key: ValueKey('concept_journey_stage_${candidate.value}'),
              onTap: walked ? () => onCompletedStageTap(candidate.order) : null,
              radius: 15,
              child: SizedBox(
                width: 20,
                height: 24,
                child: Center(
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: walked
                          ? gold.withValues(alpha: 0.68)
                          : SelahColors.luxuryDarkPurple.withValues(alpha: 0.4),
                      border: walked
                          ? null
                          : Border.all(
                              color: SelahColors.foreground.withValues(
                                alpha: 0.2,
                              ),
                              width: 1,
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }
    }
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: children,
      ),
    );
  }
}

class _StagePages extends StatefulWidget {
  const _StagePages({
    super.key,
    required this.stage,
    required this.localActionBody,
    required this.decisionBody,
    required this.historyBodies,
    required this.onTimeline,
    required this.onViewedStageChanged,
    this.onActionVisibilityChanged,
  });
  final SelahJourneyStage stage;
  final Widget localActionBody;
  final Widget? decisionBody;
  final Map<String, Widget> historyBodies;
  final VoidCallback onTimeline;
  final ValueChanged<SelahJourneyStage> onViewedStageChanged;
  final ValueChanged<bool>? onActionVisibilityChanged;
  @override
  State<_StagePages> createState() => _StagePagesState();
}

class _StagePagesState extends State<_StagePages> {
  late final PageController _pages;
  static const double _innerPullThreshold = 34;
  static const double _historyForwardThreshold = 36;
  double _innerPullDistance = 0;
  bool _innerPullCommitted = false;
  int? _innerPullTargetPage;
  int? _historyPointerStartPage;
  double _historyForwardDistance = 0;
  int get _arrival => SelahJourneyScroll.arrivalPage(widget.stage.order - 1);
  int get _action => SelahJourneyScroll.actionPage(widget.stage.order - 1);
  int get _decision => SelahJourneyScroll.decisionPage(widget.stage.order - 1);
  @override
  void initState() {
    super.initState();
    _pages = PageController(initialPage: _arrival, keepPage: false);
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _StagePages oldWidget) {
    super.didUpdateWidget(oldWidget);
    final changed = oldWidget.stage.value != widget.stage.value;
    final decisionArrived =
        oldWidget.decisionBody == null && widget.decisionBody != null;
    if (changed || decisionArrived) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) showPage(changed ? _arrival : _decision);
      });
    }
  }

  void showPage(int page, {int milliseconds = 480}) {
    if (!mounted || !_pages.hasClients) return;
    final reduce = MediaQuery.disableAnimationsOf(context);
    if (reduce) {
      _pages.jumpToPage(page);
    } else {
      _pages.animateToPage(
        page,
        duration: Duration(milliseconds: milliseconds),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void showCompleted(int order) {
    if (order > 0 && order < widget.stage.order) {
      showPage(order - 1, milliseconds: 520);
    }
  }

  Future<void> _settleInnerScrollableAt(int targetPage) async {
    if (_innerPullCommitted || !_pages.hasClients || !mounted) return;
    _innerPullCommitted = true;
    try {
      if (MediaQuery.disableAnimationsOf(context)) {
        _pages.jumpToPage(targetPage);
      } else {
        await _pages.animateToPage(
          targetPage,
          duration: const Duration(milliseconds: 480),
          curve: Curves.easeOutCubic,
        );
      }
    } finally {
      _innerPullDistance = 0;
      _innerPullCommitted = false;
      _innerPullTargetPage = null;
    }
  }

  void _accumulateInnerPull({required int targetPage, required double delta}) {
    if (_innerPullCommitted || delta <= 0) return;
    if (_innerPullTargetPage != targetPage) {
      _innerPullTargetPage = targetPage;
      _innerPullDistance = 0;
    }
    _innerPullDistance = (_innerPullDistance + delta)
        .clamp(0, _innerPullThreshold)
        .toDouble();
    if (_innerPullDistance >= _innerPullThreshold) {
      unawaited(_settleInnerScrollableAt(targetPage));
    }
  }

  void _handlePageChanged(int page) {
    _innerPullDistance = 0;
    _innerPullCommitted = false;
    _innerPullTargetPage = null;
    widget.onActionVisibilityChanged?.call(
      SelahJourneyScroll.isActionPage(
        page: page,
        completedStageCount: widget.stage.order - 1,
      ),
    );
    final viewedIndex = SelahJourneyScroll.viewedStageIndex(
      page: page,
      completedStageCount: widget.stage.order - 1,
    );
    widget.onViewedStageChanged(
      viewedIndex < _arrival
          ? SelahJourneyStages.all[viewedIndex]
          : widget.stage,
    );
  }

  void _startHistoryForwardSwipe(PointerDownEvent event) {
    _historyPointerStartPage = null;
    _historyForwardDistance = 0;
    if (!_pages.hasClients) return;
    final page = (_pages.page ?? _pages.initialPage.toDouble()).round();
    if (page >= 0 && page < _arrival) {
      // Injected history can own a scrollable. Its boundary notifications must
      // decide when the member has finished reading that content.
      if (widget.historyBodies.containsKey(SelahJourneyStages.all[page].value)) {
        return;
      }
      _historyPointerStartPage = page;
    }
  }

  void _trackHistoryForwardSwipe(PointerMoveEvent event) {
    if (_historyPointerStartPage == null) return;
    _historyForwardDistance = SelahJourneyScroll.completionDistanceAfterInput(
      currentDistance: _historyForwardDistance,
      forwardDelta: -event.delta.dy,
      threshold: _historyForwardThreshold,
    );
  }

  void _finishHistoryForwardSwipe(PointerEvent event) {
    final startPage = _historyPointerStartPage;
    final forwardDistance = _historyForwardDistance;
    _historyPointerStartPage = null;
    _historyForwardDistance = 0;
    if (startPage == null || forwardDistance < _historyForwardThreshold) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_pages.hasClients) return;
      final target = SelahJourneyScroll.missedHistoryForwardTarget(
        startPage: startPage,
        currentPage: _pages.page ?? startPage.toDouble(),
        arrivalPage: _arrival,
        forwardDistance: forwardDistance,
        activationDistance: _historyForwardThreshold,
      );
      if (target != null) showPage(target, milliseconds: 420);
    });
  }

  void _cancelHistoryForwardSwipe(PointerEvent event) {
    _historyPointerStartPage = null;
    _historyForwardDistance = 0;
  }

  bool _handleInnerActionScroll(ScrollNotification notification) {
    final delta = _pullPastStart(notification);
    if (delta != null) {
      _accumulateInnerPull(targetPage: _arrival, delta: delta);
    } else if (notification is ScrollEndNotification && !_innerPullCommitted) {
      _innerPullDistance = 0;
      _innerPullTargetPage = null;
    }
    return false;
  }

  bool _handleInnerHistoryScroll(ScrollNotification notification, int page) {
    final pastStart = _pullPastStart(notification);
    if (pastStart != null && page > 0) {
      _accumulateInnerPull(targetPage: page - 1, delta: pastStart);
      return false;
    }
    final pastEnd = _pullPastEnd(notification);
    if (pastEnd != null) {
      _accumulateInnerPull(targetPage: page + 1, delta: pastEnd);
      return false;
    }
    if (notification is ScrollEndNotification && !_innerPullCommitted) {
      _innerPullDistance = 0;
      _innerPullTargetPage = null;
    }
    return false;
  }

  double? _pullPastStart(ScrollNotification notification) {
    if (notification is OverscrollNotification && notification.overscroll < 0) {
      return -notification.overscroll;
    }
    if (notification is ScrollUpdateNotification &&
        notification.metrics.pixels <= notification.metrics.minScrollExtent &&
        (notification.scrollDelta ?? 0) < 0) {
      return -(notification.scrollDelta ?? 0);
    }
    return null;
  }

  double? _pullPastEnd(ScrollNotification notification) {
    if (notification is OverscrollNotification && notification.overscroll > 0) {
      return notification.overscroll;
    }
    if (notification is ScrollUpdateNotification &&
        notification.metrics.pixels >= notification.metrics.maxScrollExtent &&
        (notification.scrollDelta ?? 0) > 0) {
      return notification.scrollDelta;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) => Listener(
    behavior: HitTestBehavior.translucent,
    onPointerDown: _startHistoryForwardSwipe,
    onPointerMove: _trackHistoryForwardSwipe,
    onPointerUp: _finishHistoryForwardSwipe,
    onPointerCancel: _cancelHistoryForwardSwipe,
    child: PageView.builder(
      key: const ValueKey('concept_current_journey_pages'),
      controller: _pages,
      scrollDirection: Axis.vertical,
      pageSnapping: true,
      allowImplicitScrolling: true,
      physics: const PageScrollPhysics(parent: BouncingScrollPhysics()),
      itemCount: _arrival + 2 + (widget.decisionBody == null ? 0 : 1),
      onPageChanged: _handlePageChanged,
      itemBuilder: (context, index) {
        if (index < _arrival) {
          final stage = SelahJourneyStages.all[index];
          return Stack(
            fit: StackFit.expand,
            children: [
              NotificationListener<ScrollNotification>(
                onNotification: (notification) =>
                    _handleInnerHistoryScroll(notification, index),
                child:
                    widget.historyBodies[stage.value] ??
                    _CompletedStage(
                      stage: stage,
                      onTimeline: widget.onTimeline,
                    ),
              ),
              if (index > 0)
                Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: _UpCue(
                      label: 'Stage $index above',
                      onTap: () => showPage(index - 1),
                    ),
                  ),
                ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _DownCue(
                    label: 'Stage ${index + 2} below',
                    onTap: () => showPage(index + 1),
                  ),
                ),
              ),
            ],
          );
        }
        if (index == _arrival) {
          return NotificationListener<ScrollNotification>(
            onNotification: (notification) =>
                _handleInnerHistoryScroll(notification, _arrival),
            child: SelahConceptJourneyArrival(
              stage: widget.stage,
              onContinue: () => showPage(_action),
              onPrevious: _arrival == 0 ? null : () => showPage(_arrival - 1),
            ),
          );
        }
        if (index == _action) {
          return Column(
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 58),
                child: Center(
                  child: _UpCue(
                    label: 'Stage ${widget.stage.order} arrival above',
                    onTap: () => showPage(_arrival),
                  ),
                ),
              ),
              Expanded(
                child: NotificationListener<ScrollNotification>(
                  onNotification: _handleInnerActionScroll,
                  child: SizedBox.expand(child: widget.localActionBody),
                ),
              ),
            ],
          );
        }
        return NotificationListener<ScrollNotification>(
          onNotification: _handleInnerActionScroll,
          child: SizedBox.expand(child: widget.decisionBody),
        );
      },
    ),
  );
}

/// Canonical arrival wording and actual current chapter briefing geometry.
class SelahConceptJourneyArrival extends StatelessWidget {
  const SelahConceptJourneyArrival({
    super.key,
    required this.stage,
    required this.onContinue,
    this.onPrevious,
  });
  final SelahJourneyStage stage;
  final VoidCallback onContinue;
  final VoidCallback? onPrevious;

  @override
  Widget build(BuildContext context) {
    final secondary = stage.guidingQuestion ?? stage.supportingLine;
    final questionCount = JourneyQuestions.forStageValue(stage.value)?.length;
    final downLabel = questionCount == null
        ? stage.order == 1
              ? 'Scroll to begin'
              : 'Continue'
        : 'Begin Question 1 of $questionCount';
    final upLabel = 'Stage ${stage.order - 1} above';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: LayoutBuilder(
        builder: (context, constraints) {
          double textHeight(String text, TextStyle style, double width) {
            final painter = TextPainter(
              text: TextSpan(text: text, style: style),
              textDirection: Directionality.of(context),
              textScaler: MediaQuery.textScalerOf(context),
              textAlign: TextAlign.center,
            )..layout(maxWidth: width.clamp(1.0, double.infinity).toDouble());
            final height = painter.height;
            painter.dispose();
            return height;
          }

          // Preserve current optical alignment for fitting bodies. Only an
          // overflowing body scrolls between the unchanged, measured cues.
          final upReserve = onPrevious == null
              ? 0.0
              : 16 +
                    10 +
                    24 +
                    textHeight(
                      upLabel,
                      SelahText.subtext(size: 10.5),
                      constraints.maxWidth - 36,
                    ) +
                    8;
          final downReserve =
              28 +
              24 +
              30 +
              textHeight(
                downLabel,
                SelahText.subtext(size: 12),
                constraints.maxWidth - 60,
              ) +
              8;
          final upperRequirement = upReserve / 0.44;
          final lowerRequirement = downReserve / 0.56;
          final reserved = upperRequirement > lowerRequirement
              ? upperRequirement
              : lowerRequirement;
          final maxBodyHeight = (constraints.maxHeight - reserved)
              .clamp(1.0, constraints.maxHeight)
              .toDouble();

          return Stack(
            children: [
              if (onPrevious != null)
                Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: _UpCue(label: upLabel, onTap: onPrevious!),
                  ),
                ),
              Align(
                alignment: const Alignment(0, -0.12),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxBodyHeight),
                  child: SingleChildScrollView(
                    key: const ValueKey('concept_journey_arrival_body'),
                    physics: const ClampingScrollPhysics(),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'STAGE ${stage.order} OF ${SelahJourneyStages.count}',
                          style: SelahText.chapterLabel(
                            color: SelahColors.ink(0.54),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          stage.arrivalTitle ?? stage.label,
                          style: SelahText.heading(size: 25),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          stage.introduction,
                          style: SelahText.body(
                            size: 15,
                            color: SelahColors.foreground.withValues(alpha: 0.9),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (secondary != null) ...[
                          const SizedBox(height: 10),
                          Text(
                            secondary,
                            style: SelahText.subtext(size: 13),
                            textAlign: TextAlign.center,
                          ),
                        ],
                        if (questionCount != null) ...[
                          const SizedBox(height: 22),
                          _QuestionBriefing(questionCount: questionCount),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 28),
                  child: _DownCue(
                    key: const ValueKey('concept_journey_arrival_continue'),
                    label: downLabel,
                    onTap: onContinue,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Current between-stage three-beat decision page; every callback stays local.
class SelahConceptJourneyDecisionPresentation extends StatelessWidget {
  const SelahConceptJourneyDecisionPresentation({
    super.key,
    required this.stage,
    required this.nextLabel,
    required this.completionConfirmed,
    required this.continueSelected,
    required this.onBack,
    required this.onSelectContinue,
    required this.onCommitContinue,
    required this.onPause,
    required this.onEnd,
    this.busy = false,
    this.canContinue = true,
  });
  final SelahJourneyStage stage;
  final String nextLabel;
  final bool completionConfirmed;
  final bool continueSelected;
  final VoidCallback onBack;
  final VoidCallback onSelectContinue;
  final VoidCallback onCommitContinue;
  final VoidCallback onPause;
  final VoidCallback onEnd;
  final bool busy;
  final bool canContinue;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final centredHeight = constraints.hasBoundedHeight
          ? (constraints.maxHeight - 50).clamp(0.0, double.infinity).toDouble()
          : 0.0;
      return SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(28, 22, 28, 28),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: centredHeight),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 350),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Semantics(
                    button: true,
                    label: 'Return to the completed stage',
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: busy ? null : onBack,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.keyboard_arrow_up_rounded,
                              size: 24,
                              color: SelahColors.foreground.withValues(
                                alpha: 0.52,
                              ),
                            ),
                            Text(
                              'Stage ${stage.order} completion above',
                              style: SelahText.subtext(
                                size: 10.5,
                                color: SelahColors.foreground.withValues(
                                  alpha: 0.52,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  _DecisionBeat(
                    nodeColor: const Color(0xFFE0C678),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          completionConfirmed
                              ? 'STAGE ${stage.order} COMPLETE'
                              : 'STAGE ${stage.order} CHECKPOINT',
                          style: SelahText.chapterLabel(
                            color: SelahColors.ink(0.54),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          completionConfirmed
                              ? stage.completionHeading
                              : 'Ready to move forward?',
                          style: SelahText.heading(size: 23),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          completionConfirmed
                              ? stage.completionLine
                              : 'SELAH will first confirm that both Main Shepherds are present.',
                          style: SelahText.subtext(size: 13.5),
                        ),
                      ],
                    ),
                  ),
                  _DecisionBeat(
                    nodeColor: const Color(0xFF9D86AD),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'STAGE ${stage.order + 1} AHEAD',
                          style: SelahText.chapterLabel(
                            color: SelahColors.ink(0.54),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(nextLabel, style: SelahText.heading(size: 20)),
                        const SizedBox(height: 6),
                        Text(
                          'The next chapter waits below.',
                          style: SelahText.subtext(size: 13),
                        ),
                      ],
                    ),
                  ),
                  _DecisionBeat(
                    nodeColor: SelahColors.journeyDotGreen,
                    last: true,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'YOUR DECISION',
                          style: SelahText.chapterLabel(
                            color: SelahColors.ink(0.54),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'How will you continue?',
                          style: SelahText.heading(size: 20),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Continue, pause, or end your Journey.',
                          style: SelahText.subtext(size: 13),
                        ),
                        const SizedBox(height: 15),
                        _DecisionRail(
                          busy: busy,
                          continueSelected: continueSelected,
                          canContinue: canContinue,
                          onContinue: onSelectContinue,
                          onPause: onPause,
                          onEnd: onEnd,
                        ),
                        if (continueSelected) ...[
                          const SizedBox(height: 8),
                          _DownCue(
                            label: 'Continue',
                            onTap: busy || !canContinue
                                ? null
                                : onCommitContinue,
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
      );
    },
  );
}

class _QuestionBriefing extends StatelessWidget {
  const _QuestionBriefing({required this.questionCount});
  final int questionCount;
  @override
  Widget build(BuildContext context) => Semantics(
    label:
        '$questionCount questions, one at a time. Answer privately, review and seal, then open together.',
    child: ExcludeSemantics(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: _BriefingStep(number: 1, label: 'Answer\nprivately'),
              ),
              const _BriefingConnector(),
              const Expanded(
                child: _BriefingStep(number: 2, label: 'Review\n& seal'),
              ),
              const _BriefingConnector(),
              const Expanded(
                child: _BriefingStep(number: 3, label: 'Open\ntogether'),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.lock_outline_rounded,
                size: 13,
                color: SelahColors.journeyGold,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  '$questionCount questions · one at a time',
                  textAlign: TextAlign.center,
                  style: SelahText.subtext(
                    size: 10.5,
                    color: SelahColors.foreground.withValues(alpha: 0.58),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _BriefingStep extends StatelessWidget {
  const _BriefingStep({required this.number, required this.label});
  final int number;
  final String label;
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 27,
        height: 27,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: SelahColors.journeyGold.withValues(alpha: 0.76),
          ),
        ),
        child: Text(
          '$number',
          style: SelahText.subtext(size: 9.5, color: SelahColors.journeyGold),
        ),
      ),
      const SizedBox(height: 6),
      Text(
        label,
        style: SelahText.subtext(
          size: 9.5,
          color: SelahColors.foreground.withValues(alpha: 0.78),
        ),
        textAlign: TextAlign.center,
      ),
    ],
  );
}

class _BriefingConnector extends StatelessWidget {
  const _BriefingConnector();
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 28,
    child: Padding(
      padding: const EdgeInsets.only(top: 13),
      child: Container(
        height: 1,
        color: SelahColors.journeyGold.withValues(alpha: 0.34),
      ),
    ),
  );
}

class _CompletedStage extends StatelessWidget {
  const _CompletedStage({required this.stage, required this.onTimeline});
  final SelahJourneyStage stage;
  final VoidCallback onTimeline;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
    child: Column(
      children: [
        const Spacer(),
        Icon(
          Icons.check_circle_outline_rounded,
          size: 25,
          color: SelahColors.journeyGold.withValues(alpha: 0.72),
        ),
        const SizedBox(height: 11),
        Text(
          'STAGE ${stage.order} · ${stage.label.toUpperCase()}',
          style: SelahText.chapterLabel(color: SelahColors.ink(0.54)),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        Text(
          stage.completionHeading,
          style: SelahText.heading(size: 21),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 7),
        Text(
          stage.completionLine,
          style: SelahText.subtext(size: 13.5),
          textAlign: TextAlign.center,
        ),
        if (stage.guidingQuestion != null) ...[
          const SizedBox(height: 10),
          Text(
            stage.guidingQuestion!,
            style: SelahText.body(
              size: 12.5,
              color: SelahColors.foreground.withValues(alpha: 0.62),
            ),
            textAlign: TextAlign.center,
          ),
        ],
        if (stage.value == 'compatibility_reveal' ||
            stage.kind == SelahStageKind.sustained) ...[
          const SizedBox(height: 8),
          TextButton(
            onPressed: onTimeline,
            child: Text(
              'Read this stage in your Timeline',
              style: SelahText.subtext(size: 11.5, color: SelahColors.ink(0.70)),
            ),
          ),
        ],
        const Spacer(),
        Container(
          width: 54,
          height: 1,
          color: SelahColors.foreground.withValues(alpha: 0.13),
        ),
      ],
    ),
  );
}

class _UpCue extends StatelessWidget {
  const _UpCue({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    onTap: onTap,
    excludeSemantics: true,
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        excludeFromSemantics: true,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.keyboard_arrow_up_rounded,
                size: 24,
                color: SelahColors.foreground.withValues(alpha: 0.58),
              ),
              Text(
                label,
                textAlign: TextAlign.center,
                style: SelahText.subtext(
                  size: 10.5,
                  color: SelahColors.foreground.withValues(alpha: 0.58),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _DownCue extends StatelessWidget {
  const _DownCue({super.key, required this.label, required this.onTap});
  final String label;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 560),
    curve: Curves.easeOutCubic,
    builder: (context, value, child) => Opacity(
      opacity: value,
      child: Transform.translate(
        offset: Offset(0, 10 * (1 - value)),
        child: child,
      ),
    ),
    child: Semantics(
      button: true,
      enabled: onTap != null,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          excludeFromSemantics: true,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 30,
                  color: SelahColors.foreground.withValues(alpha: 0.58),
                ),
                Text(
                  label,
                  style: SelahText.subtext(
                    size: 12,
                    color: SelahColors.foreground.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _DecisionBeat extends StatelessWidget {
  const _DecisionBeat({
    required this.nodeColor,
    required this.child,
    this.last = false,
  });
  final Color nodeColor;
  final Widget child;
  final bool last;
  @override
  Widget build(BuildContext context) => IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 34,
          child: Column(
            children: [
              const SizedBox(height: 3),
              Container(
                width: 15,
                height: 15,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: nodeColor,
                  border: Border.all(
                    color: SelahColors.luxuryDarkPurple,
                    width: 3,
                  ),
                ),
              ),
              if (!last)
                Expanded(
                  child: Container(
                    width: 1,
                    color: SelahColors.foreground.withValues(alpha: 0.28),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: last ? 0 : 28),
            child: child,
          ),
        ),
      ],
    ),
  );
}

class _DecisionRail extends StatelessWidget {
  const _DecisionRail({
    required this.busy,
    required this.continueSelected,
    required this.canContinue,
    required this.onContinue,
    required this.onPause,
    required this.onEnd,
  });
  final bool busy;
  final bool continueSelected;
  final bool canContinue;
  final VoidCallback onContinue;
  final VoidCallback onPause;
  final VoidCallback onEnd;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Divider(height: 1, color: SelahColors.foreground.withValues(alpha: 0.24)),
      _DecisionAction(
        label: continueSelected ? 'Continue selected' : 'Continue',
        dotColor: SelahColors.journeyDotGreen,
        selected: continueSelected,
        onTap: busy || !canContinue ? null : onContinue,
      ),
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) => SizeTransition(
          sizeFactor: animation,
          alignment: Alignment.topCenter,
          child: FadeTransition(opacity: animation, child: child),
        ),
        child: continueSelected
            ? const SizedBox.shrink(key: ValueKey('continue-selected'))
            : Column(
                key: const ValueKey('all-decisions'),
                children: [
                  _DecisionAction(
                    label: 'Request Pause',
                    dotColor: const Color(0xFFDFBD62),
                    onTap: busy ? null : onPause,
                  ),
                  _DecisionAction(
                    label: 'End Journey',
                    dotColor: const Color(0xFFDF7D82),
                    destructive: true,
                    onTap: busy ? null : onEnd,
                  ),
                ],
              ),
      ),
    ],
  );
}

class _DecisionAction extends StatelessWidget {
  const _DecisionAction({
    required this.label,
    required this.dotColor,
    required this.onTap,
    this.destructive = false,
    this.selected = false,
  });
  final String label;
  final Color dotColor;
  final VoidCallback? onTap;
  final bool destructive;
  final bool selected;
  @override
  Widget build(BuildContext context) => Opacity(
    opacity: onTap == null ? 0.42 : 1,
    child: Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 54,
          decoration: BoxDecoration(
            color: selected
                ? SelahColors.journeyGold.withValues(alpha: 0.09)
                : Colors.transparent,
            border: Border(
              bottom: BorderSide(
                color: selected
                    ? SelahColors.journeyGold.withValues(alpha: 0.52)
                    : SelahColors.foreground.withValues(alpha: 0.24),
              ),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: dotColor,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: SelahText.body(
                    size: 13,
                    color: destructive ? SelahColors.destructive : Colors.white,
                  ),
                ),
              ),
              Icon(
                selected ? Icons.check_rounded : Icons.chevron_right_rounded,
                size: 20,
                color: selected
                    ? SelahColors.journeyGold
                    : SelahColors.foreground.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _JourneyAtmosphere extends StatelessWidget {
  const _JourneyAtmosphere({required this.stage});
  final SelahJourneyStage stage;
  @override
  Widget build(BuildContext context) {
    final shift = ((stage.order - 1) / (SelahJourneyStages.count - 1)) * 28;
    return IgnorePointer(
      child: ClipRect(
        child: Stack(
          children: [
            Positioned(
              top: -66,
              right: -95 + shift,
              child: Transform.scale(
                scale: 1,
                child: _Glow(
                  size: 300,
                  colour: SelahColors.actionFill,
                  opacity: 0.24,
                ),
              ),
            ),
            Positioned(
              bottom: -99,
              left: -105 + 28 - shift,
              child: Transform.scale(
                scale: 1.005,
                child: const _Glow(
                  size: 330,
                  colour: Color(0xFF73579A),
                  opacity: 0.26,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({
    required this.size,
    required this.colour,
    required this.opacity,
  });
  final double size;
  final Color colour;
  final double opacity;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(
        colors: [
          colour.withValues(alpha: opacity),
          colour.withValues(alpha: 0),
        ],
      ),
    ),
  );
}

class _JourneyVerticalStageSwap extends StatefulWidget {
  const _JourneyVerticalStageSwap({
    required this.surfaceKey,
    required this.child,
  });
  final String surfaceKey;
  final Widget child;
  @override
  State<_JourneyVerticalStageSwap> createState() =>
      _JourneyVerticalStageSwapState();
}

class _JourneyVerticalStageSwapState extends State<_JourneyVerticalStageSwap>
    with SingleTickerProviderStateMixin {
  late Widget _current;
  Widget? _previous;
  late final AnimationController _controller;
  late final Animation<Offset> _incoming = Tween<Offset>(
    begin: const Offset(0, 1),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
  late final Animation<Offset> _outgoing = Tween<Offset>(
    begin: Offset.zero,
    end: const Offset(0, -1),
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
      value: 1,
    );
    _current = widget.child;
  }

  @override
  void didUpdateWidget(covariant _JourneyVerticalStageSwap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.surfaceKey == widget.surfaceKey) {
      _current = widget.child;
      return;
    }
    _previous = _current;
    _current = widget.child;
    _controller.forward(from: 0).whenComplete(() {
      if (mounted) setState(() => _previous = null);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context) || _previous == null) {
      return SizedBox.expand(child: _current);
    }
    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          IgnorePointer(
            child: SlideTransition(position: _outgoing, child: _previous),
          ),
          SlideTransition(position: _incoming, child: _current),
        ],
      ),
    );
  }
}
