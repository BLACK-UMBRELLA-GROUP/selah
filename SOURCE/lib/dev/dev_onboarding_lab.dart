// Visual-only welcome walkthroughs. Never re-enter signup, mutate completion,
// refresh Auth, store a selection, or request device permissions.
import 'package:flutter/material.dart';

import '../screens/onboarding/onboarding_stage_intro_screen.dart';
import '../services/selah_developer_access.dart';
import '../theme/selah_colors.dart';
import '../theme/selah_text.dart';
import '../widgets/selah_onboarding_continue_action.dart';
import '../widgets/selah_onboarding_edge_swipe.dart';
import '../widgets/selah_onboarding_study.dart';
import 'dev_onboarding_gold_design.dart';
import 'dev_onboarding_interaction.dart';
import 'dev_onboarding_opening.dart';
import 'dev_onboarding_transition.dart';

class DevOnboardingDirectionsScreen extends StatefulWidget {
  const DevOnboardingDirectionsScreen({
    super.key,
    this.initialDirection = selahDefaultDevOnboardingDirection,
  });
  final SelahOnboardingDirection initialDirection;

  @override
  State<DevOnboardingDirectionsScreen> createState() =>
      _DevOnboardingDirectionsScreenState();
}

class _DevOnboardingDirectionsScreenState
    extends State<DevOnboardingDirectionsScreen> {
  late SelahOnboardingDirection _direction = widget.initialDirection;

  void _cycle(int delta) {
    if (!SelahDeveloperAccess.canUseDeveloperTools) return;
    setState(() {
      _direction =
          SelahOnboardingDirection.values[(_direction.index + delta) %
              SelahOnboardingDirection.values.length];
    });
    SelahDevOnboardingGoldMotion.pageEntered();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([
      SelahDeveloperAccess.authorizationChanges,
      SelahDevOnboardingInteraction.changes,
    ]),
    builder: (context, _) {
      final authorized = SelahDeveloperAccess.canUseDeveloperTools;
      return SelahOnboardingArrowScope(
        enabled:
            SelahDevOnboardingInteraction.current ==
            SelahOnboardingAdvanceMode.animatedDownArrow,
        child: Scaffold(
          key: ValueKey(
            authorized
                ? 'dev_onboarding_directions_preview'
                : 'dev_onboarding_directions_denied',
          ),
          body: DecoratedBox(
            key: const ValueKey('dev_onboarding_static_canvas'),
            decoration: BoxDecoration(gradient: SelahColors.brandGradient),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (authorized && _direction != SelahOnboardingDirection.current)
                  const SelahOnboardingGoldBackdrop(),
                SafeArea(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          IconButton(
                            key: const ValueKey('dev_onboarding_close'),
                            tooltip: 'Close onboarding preview',
                            onPressed: () => Navigator.of(context).maybePop(),
                            icon: const Icon(Icons.close_rounded),
                            color: SelahColors.foregroundSecondary,
                          ),
                          if (authorized) ...[
                            Expanded(
                              child: Text(
                                'Preview · ${_direction.label}',
                                key: const ValueKey(
                                  'dev_onboarding_direction_label',
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: SelahText.subtext(size: 11),
                              ),
                            ),
                            IconButton(
                              key: const ValueKey(
                                'dev_onboarding_previous_direction',
                              ),
                              tooltip: 'Previous onboarding design',
                              onPressed: () => _cycle(-1),
                              icon: const Icon(Icons.chevron_left_rounded),
                              color: SelahColors.journeyGold,
                            ),
                            IconButton(
                              key: const ValueKey(
                                'dev_onboarding_next_direction',
                              ),
                              tooltip: 'Next onboarding design',
                              onPressed: () => _cycle(1),
                              icon: const Icon(Icons.chevron_right_rounded),
                              color: SelahColors.journeyGold,
                            ),
                          ],
                        ],
                      ),
                      if (authorized)
                        Expanded(
                          child: KeyedSubtree(
                            key: ValueKey(
                              'onboarding-direction-${_direction.name}',
                            ),
                            child: _direction == SelahOnboardingDirection.current
                                ? OnboardingStageIntroScreen(
                                    stage: SeekerOnboardingStage.buildProfile,
                                    welcomeName: 'Shakeel',
                                    devPreview: true,
                                    allowPreviewScrolling: true,
                                    onContinue: () async {
                                      await Navigator.of(context).maybePop();
                                    },
                                  )
                                : _OnboardingWalkthrough(direction: _direction),
                          ),
                        )
                      else
                        const Expanded(child: SizedBox.shrink()),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _OnboardingWalkthrough extends StatefulWidget {
  const _OnboardingWalkthrough({required this.direction});

  final SelahOnboardingDirection direction;

  @override
  State<_OnboardingWalkthrough> createState() => _OnboardingWalkthroughState();
}

class _OnboardingWalkthroughState extends State<_OnboardingWalkthrough> {
  static const _lastRevealStep = 2;
  final PageController _pager = PageController();
  final List<ScrollController> _storyScrolls = List.generate(
    SelahOnboardingDirection.storyPageCount,
    (_) => ScrollController(),
  );
  final List<int> _revealSteps = List.filled(
    SelahOnboardingDirection.storyPageCount,
    1,
  );
  final List<bool> _entered = List.generate(
    SelahOnboardingDirection.storyPageCount,
    (page) => page == 0,
  );
  int _page = 0;
  bool _finishing = false;
  bool _pagerMoving = false;

  @override
  void initState() {
    super.initState();
    SelahDevOnboardingTransition.changes.addListener(_onTransitionChanged);
  }

  void _onTransitionChanged() {
    if (mounted) setState(() {});
  }

  bool get _accessibleReadingMode => MediaQuery.accessibleNavigationOf(context);
  bool get _canNavigate =>
      mounted &&
      !_finishing &&
      !_pagerMoving &&
      SelahDeveloperAccess.canUseDeveloperTools;

  bool _fullyRevealed(int page) =>
      _accessibleReadingMode || _revealSteps[page] >= _lastRevealStep;

  Widget _card(int page, {required bool swipeNavigation}) =>
      SelahOnboardingStudy(
        direction: widget.direction,
        page: page,
        scrollController: _storyScrolls[page],
        swipeNavigation: swipeNavigation,
        revealStep: _accessibleReadingMode
            ? _lastRevealStep
            : _revealSteps[page],
        animateReveal: !_accessibleReadingMode,
        entered: _entered[page],
      );

  void _revealNext(int page) {
    if (!_canNavigate || _page != page || _fullyRevealed(page)) {
      return;
    }
    setState(() => _revealSteps[page]++);
  }

  Future<void> _goTo(int page, {bool bypassReveal = false}) async {
    if (!_canNavigate ||
        page < 0 ||
        page >= SelahOnboardingDirection.storyPageCount ||
        page == _page) {
      return;
    }
    // Only the developer Skip control may bypass unread story copy.
    if (page > _page && !bypassReveal) {
      if (!_fullyRevealed(_page)) {
        _revealNext(_page);
        return;
      }
      page = _page + 1;
    }
    setState(() {
      _entered[page] = true;
      _pagerMoving = true;
    });
    try {
      if (MediaQuery.disableAnimationsOf(context)) {
        _pager.jumpToPage(page);
      } else {
        final transition = SelahDevOnboardingTransition.current;
        await _pager.animateToPage(
          page,
          duration: transition.duration,
          curve: transition.curve,
        );
      }
    } finally {
      // onPageChanged can fire halfway through the page travel. Keep every
      // button, reveal and gesture locked until the driven scroll settles.
      if (mounted) setState(() => _pagerMoving = false);
    }
  }

  void _finish() {
    if (!_canNavigate) return;
    _finishing = true;
    Navigator.of(context).maybePop();
  }

  void _continue() {
    if (!_canNavigate) return;
    if (!_fullyRevealed(_page)) {
      _revealNext(_page);
    } else if (_page == SelahOnboardingDirection.storyPageCount - 1) {
      _finish();
    } else {
      _goTo(_page + 1);
    }
  }

  void _skip() {
    if (!_canNavigate) return;
    if (_page == SelahOnboardingDirection.storyPageCount - 1) {
      _finish();
    } else {
      _goTo(_page + 1, bypassReveal: true);
    }
  }

  void _swipeTo(int fromPage, int page) {
    if (!_canNavigate || _page != fromPage || !_fullyRevealed(fromPage)) {
      return;
    }
    if (page == SelahOnboardingDirection.storyPageCount) {
      _finish();
    } else {
      _goTo(page);
    }
  }

  void _swipeRight(int fromPage) {
    if (!_canNavigate ||
        fromPage >= SelahOnboardingDirection.storyPageCount - 1) {
      return;
    }
    if (!_fullyRevealed(fromPage)) {
      _revealNext(fromPage);
      return;
    }
    _swipeTo(fromPage, fromPage + 1);
  }

  void _swipeLeft(int fromPage) {
    if (fromPage == 0 || !_canNavigate || _page != fromPage) {
      return;
    }
    _goTo(fromPage - 1);
  }

  void _tapForward(int page) {
    if (!_canNavigate || _page != page) {
      return;
    }
    if (!_fullyRevealed(page)) {
      _revealNext(page);
    } else if (page < SelahOnboardingDirection.storyPageCount - 1) {
      _swipeTo(page, page + 1);
    }
    // The last standalone comparison card finishes through its explicit
    // Continue control, or the guarded down arrow in arrow mode.
  }

  @override
  void dispose() {
    SelahDevOnboardingTransition.changes.removeListener(_onTransitionChanged);
    _pager.dispose();
    for (final controller in _storyScrolls) {
      controller.dispose();
    }
    super.dispose();
  }

  Widget _storyPage(int page) => SelahOnboardingHorizontalSwipe(
    onNext: page < SelahOnboardingDirection.storyPageCount - 1
        ? () => _swipeRight(page)
        : null,
    onPrevious: page == 0 ? null : () => _swipeLeft(page),
    onTap:
        page < SelahOnboardingDirection.storyPageCount - 1 ||
            (!_accessibleReadingMode && _revealSteps[page] < _lastRevealStep)
        ? () => _tapForward(page)
        : null,
    onTapHint: _fullyRevealed(page)
        ? 'Continue to the next introduction card'
        : 'Reveal more introduction text',
    child: page == SelahOnboardingDirection.storyPageCount - 1
        ? SelahOnboardingEdgeSwipe(
            controller: _storyScrolls[page],
            enabled: _canNavigate && _page == page,
            onForward: () =>
                _swipeTo(page, SelahOnboardingDirection.storyPageCount),
            child: _card(page, swipeNavigation: true),
          )
        : _card(page, swipeNavigation: false),
  );

  @override
  Widget build(BuildContext context) {
    final arrowMode = SelahOnboardingArrowScope.enabledOf(context);
    final transition = SelahDevOnboardingTransition.current;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      excludeFromSemantics: true,
      onTap: _canNavigate ? () => _tapForward(_page) : null,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 9),
            child: Text(
              'Selah',
              style: SelahText.wordmark(
                size: 18,
                color: SelahColors.splashWordmark,
              ),
            ),
          ),
          Expanded(
            child: PageView(
              key: const ValueKey('dev_onboarding_page_view'),
              controller: _pager,
              scrollDirection: Axis.horizontal,
              reverse: true,
              allowImplicitScrolling:
                  transition != SelahOnboardingPageTransition.current,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (page) {
                if (!_finishing) setState(() => _page = page);
                SelahDevOnboardingGoldMotion.pageEntered();
              },
              children: [
                for (
                  var page = 0;
                  page < SelahOnboardingDirection.storyPageCount;
                  page++
                )
                  SelahOnboardingTransitionFrame(
                    controller: _pager,
                    pageIndex: page,
                    axis: Axis.horizontal,
                    reverse: true,
                    transition: transition,
                    child: _storyPage(page),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 3, 24, 16),
            child: Column(
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: 44,
                      height: 44,
                      child: _page == 0
                          ? const SizedBox.shrink()
                          : TextButton(
                              key: const ValueKey('dev_onboarding_back'),
                              onPressed: _canNavigate
                                  ? () => _goTo(_page - 1)
                                  : null,
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                alignment: Alignment.centerLeft,
                                minimumSize: const Size(44, 44),
                              ),
                              child: Text(
                                'Back · DEV',
                                maxLines: 2,
                                textAlign: TextAlign.left,
                                style: SelahText.subtext(size: 10),
                              ),
                            ),
                    ),
                    const Expanded(
                      child: Row(
                        key: ValueKey('dev_onboarding_page_dots'),
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [],
                      ),
                    ),
                    SizedBox(
                      width: 52,
                      child: Text(
                        '${_page + 1} / ${SelahOnboardingDirection.storyPageCount}',
                        key: const ValueKey('dev_onboarding_page_count'),
                        textAlign: TextAlign.right,
                        style: SelahText.subtext(size: 11),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (!arrowMode)
                  SizedBox(
                    height: 36,
                    child: TextButton(
                      key: const ValueKey('dev_onboarding_skip'),
                      onPressed: _canNavigate ? _skip : null,
                      child: Text(
                        'Skip · DEV',
                        style: SelahText.button(
                          size: 11,
                          color: SelahColors.journeyGold,
                        ),
                      ),
                    ),
                  ),
                if (arrowMode)
                  SizedBox(
                    height: 56,
                    child: Row(
                      children: [
                        const Expanded(child: SizedBox.shrink()),
                        if (_page ==
                                SelahOnboardingDirection.storyPageCount - 1 &&
                            _fullyRevealed(_page))
                          SelahOnboardingArrowAction(
                            key: const ValueKey('dev_onboarding_continue'),
                            active: _canNavigate,
                            onPressed: _canNavigate ? _continue : null,
                            semanticLabel: 'Finish preview',
                          ),
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              key: const ValueKey('dev_onboarding_skip'),
                              onPressed: _canNavigate ? _skip : null,
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                              ),
                              child: Text(
                                'Skip · DEV',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.right,
                                style: SelahText.subtext(
                                  size: 11,
                                  color: SelahColors.foregroundSecondary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      key: const ValueKey('dev_onboarding_continue'),
                      onPressed: _canNavigate ? _continue : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: SelahColors.journeyGold,
                        foregroundColor: SelahColors.luxuryDarkPurple,
                        shape: const StadiumBorder(),
                      ),
                      child: Text(
                        _page == SelahOnboardingDirection.storyPageCount - 1
                            ? 'Finish preview'
                            : 'Continue',
                        style: SelahText.button(size: 13),
                      ),
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

/// The selected welcome story inside the continuous local onboarding flow.
/// No lab header, design arrows or finish/pop shortcut. The outer process owns
/// Close and the nested Navigator; capability loss remains deny-first.
class DevOnboardingIntroduction extends StatefulWidget {
  const DevOnboardingIntroduction({
    super.key,
    required this.direction,
    required this.onContinue,
    this.onBackToProvider,
    this.welcomeName = 'Shakeel',
  }) : assert(direction != SelahOnboardingDirection.current);

  final SelahOnboardingDirection direction;
  final VoidCallback onContinue;
  final VoidCallback? onBackToProvider;

  /// A synthetic preview name; never read a signed-in member's identity here.
  final String welcomeName;

  @override
  State<DevOnboardingIntroduction> createState() =>
      _DevOnboardingIntroductionState();
}

class _DevOnboardingIntroductionState extends State<DevOnboardingIntroduction> {
  @override
  Widget build(BuildContext context) => DevOnboardingOpening(
    direction: widget.direction,
    welcomeName: widget.welcomeName,
    onContinue: widget.onContinue,
    onBackToProvider: widget.onBackToProvider,
  );
}
