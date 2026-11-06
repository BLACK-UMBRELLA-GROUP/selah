import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/selah_developer_access.dart';
import '../../theme/selah_colors.dart';
import '../../theme/selah_text.dart';
import '../../widgets/selah_onboarding_direction_style.dart';
import '../../widgets/selah_onboarding_continue_action.dart';
import '../../widgets/selah_onboarding_edge_swipe.dart';

/// Seeker stage metadata. The handoff itself shows only the stage name and
/// heading; the supporting detail stays here for downstream content checks.
class OnboardingStageContent {
  final String id;
  final String title;
  final String heading;
  final String summary;
  final String includes;
  final String visibility;
  final String outcome;
  final String buttonLabel;

  const OnboardingStageContent({
    required this.id,
    required this.title,
    required this.heading,
    required this.summary,
    required this.includes,
    required this.visibility,
    required this.outcome,
    required this.buttonLabel,
  });
}

enum SeekerOnboardingStage { buildProfile, journeyBio, compatibility, review }

const seekerOnboardingStages = <OnboardingStageContent>[
  OnboardingStageContent(
    id: 'build_profile',
    title: 'Your Profile',
    heading: 'Let’s begin with your profile.',
    summary: 'Build the profile people can discover and choose to match with.',
    includes: 'Your photos, city, faith and background details.',
    visibility:
        'Each question tells you whether it is public, private or revealed after a mutual match.',
    outcome: 'You will have a complete profile ready for Selah introductions.',
    buttonLabel: 'Start with Your Profile',
  ),
  OnboardingStageContent(
    id: 'journey_bio',
    title: 'Your Journey Bio',
    heading: 'Let’s build your Journey Bio.',
    summary:
        'An optional space for your story and the life details you choose to share.',
    includes:
        'A personal Bio plus optional work, family and practical details.',
    visibility:
        'Shown only after a mutual match, inside your Journey. Never shown while browsing.',
    outcome:
        'A match can understand more about you when the Journey reaches Bio reveal.',
    buttonLabel: 'Build Your Journey Bio',
  ),
  OnboardingStageContent(
    id: 'compatibility',
    title: 'Compatibility',
    heading: 'Let’s explore compatibility.',
    summary:
        'First tell Selah about yourself. Then set your partner preferences section by section.',
    includes:
        'Private answers about yourself, followed by your partner preferences.',
    visibility: 'Private. Used to calculate your compatibility score.',
    outcome:
        'Selah can show where you align without revealing either person’s raw answers.',
    buttonLabel: 'Begin Compatibility',
  ),
  OnboardingStageContent(
    id: 'review',
    title: 'Review & Go Live',
    heading: 'Let’s review and go live.',
    summary: 'See your profile as others will and make any final changes.',
    includes: 'Your photos, profile, Journey Bio and compatibility settings.',
    visibility:
        'Verification details stay private. Others see only your approved profile.',
    outcome:
        'Your profile goes live only when you are ready and checks are complete.',
    buttonLabel: 'Review Everything',
  ),
];

// The first intro is reached before the four Seeker account questions, membership
// preference and identity
// check. It is not Profile Journey stage 1, which starts only after the
// post-identity choice and overview (immediately or later from My SELAH).
const _accountEssentialsIntro = OnboardingStageContent(
  id: 'account_essentials',
  title: 'Account essentials',
  heading: 'First, your account.',
  summary:
      'Add your first and last name, gender, date of birth and one photo. Choose your membership, then verify your identity. '
      'After that, you can enter My Selah or continue building your profile.',
  includes: 'First and last name, gender, date of birth and your first photo.',
  visibility: 'Your date of birth stays private.',
  outcome: 'Choose your membership, then complete your identity check.',
  buttonLabel: 'Begin account setup',
);

/// Short account setup is not one of the four optional profile sections.
/// It comes before identity verification and the explicit now/later choice.
class AccountEssentialsIntroScreen extends StatelessWidget {
  const AccountEssentialsIntroScreen({
    super.key,
    required this.onContinue,
    this.accountExit,
    this.devPreview = false,
    this.onDevSkip,
  });

  final FutureOr<void> Function() onContinue;
  final Widget? accountExit;
  final bool devPreview;
  final VoidCallback? onDevSkip;

  @override
  Widget build(BuildContext context) => OnboardingStageIntroScreen(
    stage: SeekerOnboardingStage.buildProfile,
    includeOverview: false,
    contentOverride: _accountEssentialsIntro,
    onContinue: onContinue,
    accountExit: accountExit,
    devPreview: devPreview,
    onDevSkip: onDevSkip,
  );
}

class OnboardingStageIntroScreen extends StatefulWidget {
  final SeekerOnboardingStage stage;
  final FutureOr<void> Function() onContinue;
  final String? welcomeName;
  final Widget? accountExit;
  final bool devPreview;
  final VoidCallback? onDevSkip;
  final bool includeOverview;
  final OnboardingStageContent? contentOverride;

  /// Makes content scrollable for the protected comparator and the actual
  /// post-IDV overview. This is layout only; it never grants preview access.
  final bool allowPreviewScrolling;

  const OnboardingStageIntroScreen({
    super.key,
    required this.stage,
    required this.onContinue,
    this.welcomeName,
    this.accountExit,
    this.devPreview = false,
    this.onDevSkip,
    this.includeOverview = true,
    this.contentOverride,
    this.allowPreviewScrolling = false,
  });

  @override
  State<OnboardingStageIntroScreen> createState() =>
      _OnboardingStageIntroScreenState();
}

class _OnboardingStageIntroScreenState
    extends State<OnboardingStageIntroScreen> {
  late final PageController _pageController = PageController();
  final ScrollController _welcomeScrollController = ScrollController();
  final ScrollController _stageScrollController = ScrollController();
  int _page = 0;
  bool _pageTransitioning = false;
  bool _stageAdvanceSent = false;
  bool _backAdvanceSent = false;
  bool _finalAdvanceSent = false;
  bool _welcomeRoadmapComplete = false;

  bool get _includesWelcome =>
      widget.includeOverview &&
      widget.stage == SeekerOnboardingStage.buildProfile;

  bool get _arrowMode => SelahOnboardingArrowScope.enabledOf(context);

  bool get _isCurrentRoute => ModalRoute.of(context)?.isCurrent ?? true;

  String? get _welcomeName {
    final value = widget.welcomeName?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  Duration get _pageDuration => MediaQuery.disableAnimationsOf(context)
      ? Duration.zero
      : const Duration(milliseconds: 1000);

  Future<void> _showPage(int page) async {
    if (!mounted || _pageTransitioning || !_pageController.hasClients) return;
    // onPageChanged fires at the halfway point, not at settlement. Keep all
    // page actions locked until the controller finishes the complete journey.
    setState(() => _pageTransitioning = true);
    try {
      if (_pageDuration == Duration.zero ||
          MediaQuery.accessibleNavigationOf(context)) {
        _pageController.jumpToPage(page);
      } else {
        await _pageController.animateToPage(
          page,
          duration: _pageDuration,
          curve: Curves.easeInOutCubic,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _pageTransitioning = false;
          _backAdvanceSent = false;
          if (_page == 0) _stageAdvanceSent = false;
        });
      }
    }
  }

  Future<void> _showStage() => _showPage(1);
  Future<void> _showWelcome() => _showPage(0);

  void _advanceToStageOnce() {
    if (!mounted ||
        _pageTransitioning ||
        _finalAdvanceSent ||
        _stageAdvanceSent ||
        !_isCurrentRoute ||
        (widget.devPreview && !SelahDeveloperAccess.canUseDeveloperTools) ||
        _page != 0 ||
        !_welcomeRoadmapComplete) {
      return;
    }
    _stageAdvanceSent = true;
    unawaited(_showStage());
  }

  void _completeOnce() {
    if (!mounted ||
        _pageTransitioning ||
        _finalAdvanceSent ||
        !_isCurrentRoute ||
        (widget.devPreview && !SelahDeveloperAccess.canUseDeveloperTools) ||
        (_includesWelcome && _page != 1)) {
      return;
    }
    setState(() => _finalAdvanceSent = true);
    unawaited(_runCompletion());
  }

  Future<void> _runCompletion() async {
    try {
      await widget.onContinue();
    } finally {
      // A failed async save keeps this intro mounted. Rearm it after the
      // caller's rebuild, so a successful parent transition can dispose this
      // intro before it could be retriggered on its outgoing frame.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _isCurrentRoute) {
          setState(() => _finalAdvanceSent = false);
        }
      });
      WidgetsBinding.instance.scheduleFrame();
    }
  }

  void _onPageChanged(int page) {
    setState(() {
      _page = page;
      if (!_pageTransitioning) {
        _backAdvanceSent = false;
        if (page == 0) _stageAdvanceSent = false;
      }
    });
  }

  void _onWelcomeRoadmapComplete() {
    if (!mounted || _welcomeRoadmapComplete) return;
    setState(() => _welcomeRoadmapComplete = true);
  }

  void _returnToWelcomeOnce() {
    if (!mounted ||
        _pageTransitioning ||
        _finalAdvanceSent ||
        _backAdvanceSent ||
        !_isCurrentRoute ||
        (widget.devPreview && !SelahDeveloperAccess.canUseDeveloperTools) ||
        !_includesWelcome ||
        _page != 1) {
      return;
    }
    _backAdvanceSent = true;
    unawaited(_showWelcome());
  }

  @override
  void dispose() {
    _pageController.dispose();
    _welcomeScrollController.dispose();
    _stageScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.devPreview && !SelahDeveloperAccess.canUseDeveloperTools) {
      return Scaffold(
        key: const ValueKey('onboarding_stage_preview_denied'),
        backgroundColor: SelahColors.modalSheetSurface,
        body: const SizedBox.expand(),
      );
    }
    final stageIndex = widget.stage.index;
    final stage = widget.contentOverride ?? seekerOnboardingStages[stageIndex];
    final previewStyle = OnboardingPreviewStyle.effectiveStyleOf(context);
    final arrowMode = _arrowMode;
    final skipButton = widget.devPreview && widget.onDevSkip != null
        ? TextButton(
            key: const ValueKey('onboarding_stage_dev_skip'),
            onPressed: () {
              if (SelahDeveloperAccess.canUseDeveloperTools) {
                widget.onDevSkip?.call();
              }
            },
            child: Text(
              'Skip · DEV',
              style: SelahText.button(
                size: 11,
                color: arrowMode
                    ? SelahColors.journeyGold.withValues(alpha: 0.58)
                    : SelahColors.journeyGold,
              ),
            ),
          )
        : null;

    final pages = _includesWelcome
        ? PageView(
            key: const ValueKey('onboarding_intro_page_view'),
            controller: _pageController,
            onPageChanged: _onPageChanged,
            scrollDirection: Axis.vertical,
            // In arrow mode, each page's own scroll view reads long content.
            // A light raw finger swipe from its edge changes the page.
            physics: arrowMode || _pageTransitioning || !_welcomeRoadmapComplete
                ? const NeverScrollableScrollPhysics()
                : const BouncingScrollPhysics(),
            children: [
              if (arrowMode)
                SelahOnboardingEdgeSwipe(
                  enabled: !_pageTransitioning && !_finalAdvanceSent,
                  controller: _welcomeScrollController,
                  onForward: _advanceToStageOnce,
                  child: _WelcomePage(
                    firstName: _welcomeName,
                    onContinue: _advanceToStageOnce,
                    devPreview: widget.devPreview,
                    accountExit: widget.accountExit,
                    allowPreviewScrolling: widget.allowPreviewScrolling,
                    animateEntrance: true,
                    arrowMode: true,
                    scrollController: _welcomeScrollController,
                    onRoadmapComplete: _onWelcomeRoadmapComplete,
                  ),
                )
              else
                _WelcomePage(
                  firstName: _welcomeName,
                  onContinue: _advanceToStageOnce,
                  devPreview: widget.devPreview,
                  accountExit: widget.accountExit,
                  allowPreviewScrolling: widget.allowPreviewScrolling,
                  animateEntrance: true,
                  onRoadmapComplete: _onWelcomeRoadmapComplete,
                ),
              if (arrowMode)
                SelahOnboardingEdgeSwipe(
                  enabled: !_pageTransitioning && !_finalAdvanceSent,
                  controller: _stageScrollController,
                  onForward: _completeOnce,
                  onBackward: _returnToWelcomeOnce,
                  child: _StagePage(
                    stage: stage,
                    stageIndex: stageIndex,
                    onScrollUp: _returnToWelcomeOnce,
                    onContinue: _completeOnce,
                    accountExit: widget.accountExit,
                    arrowMode: true,
                    scrollController: _stageScrollController,
                  ),
                )
              else
                _StagePage(
                  stage: stage,
                  stageIndex: stageIndex,
                  onScrollUp: _returnToWelcomeOnce,
                  onContinue: _completeOnce,
                  accountExit: widget.accountExit,
                ),
            ],
          )
        : _StagePage(
            stage: stage,
            stageIndex: stageIndex,
            onContinue: _completeOnce,
            accountExit: widget.accountExit,
            arrowMode: arrowMode,
            scrollController: _stageScrollController,
          );
    final stageOnlyPages = !_includesWelcome && arrowMode
        ? SelahOnboardingEdgeSwipe(
            enabled: !_pageTransitioning && !_finalAdvanceSent,
            controller: _stageScrollController,
            onForward: _completeOnce,
            child: pages,
          )
        : pages;
    final pageArea = Stack(
      children: [
        stageOnlyPages,
        if (!arrowMode && skipButton != null)
          Positioned(top: 2, right: 16, child: skipButton),
      ],
    );

    return Scaffold(
      body: Container(
        constraints: const BoxConstraints.expand(),
        decoration: BoxDecoration(
          gradient:
              previewStyle?.backgroundGradient ?? SelahColors.brandGradient,
        ),
        child: SafeArea(
          child: arrowMode && skipButton != null
              ? Column(
                  children: [
                    Expanded(child: pageArea),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 16),
                          child: skipButton,
                        ),
                      ),
                    ),
                  ],
                )
              : pageArea,
        ),
      ),
    );
  }
}

class _WelcomePage extends StatefulWidget {
  final String? firstName;
  final VoidCallback onContinue;
  final bool devPreview;
  final Widget? accountExit;
  final bool allowPreviewScrolling;
  final bool animateEntrance;
  final bool arrowMode;
  final ScrollController? scrollController;
  final VoidCallback onRoadmapComplete;

  const _WelcomePage({
    required this.firstName,
    required this.onContinue,
    required this.devPreview,
    this.accountExit,
    this.allowPreviewScrolling = false,
    this.animateEntrance = false,
    this.arrowMode = false,
    this.scrollController,
    required this.onRoadmapComplete,
  });

  @override
  State<_WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<_WelcomePage>
    with
        SingleTickerProviderStateMixin,
        AutomaticKeepAliveClientMixin<_WelcomePage> {
  static const _entranceDuration = Duration(milliseconds: 2900);
  late final AnimationController _entrance;
  int _revealedRoadmapItems = 0;

  @override
  bool get wantKeepAlive => true;

  void _revealNextRoadmapItem() {
    if (_revealedRoadmapItems >= _SignupRoadmap.itemCount) return;
    setState(() => _revealedRoadmapItems++);
    if (_revealedRoadmapItems == _SignupRoadmap.itemCount) {
      widget.onRoadmapComplete();
    }
  }

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: _entranceDuration,
      value: widget.animateEntrance ? 0 : 1,
    );
  }

  bool get _canAnimate =>
      widget.animateEntrance &&
      !MediaQuery.disableAnimationsOf(context) &&
      !MediaQuery.accessibleNavigationOf(context);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_canAnimate) {
      _entrance.value = 1;
    } else if (_entrance.value == 0 && !_entrance.isAnimating) {
      _entrance.forward();
    }
  }

  @override
  void didUpdateWidget(covariant _WelcomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animateEntrance == widget.animateEntrance) return;
    if (_canAnimate) {
      _entrance.forward(from: 0);
    } else {
      _entrance.value = 1;
    }
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final title = widget.firstName == null
        ? 'Your next steps.'
        : 'Your next steps, ${widget.firstName}.';
    final previewStyle = OnboardingPreviewStyle.effectiveStyleOf(context);
    // VoiceOver and reduced-motion users receive the entire page immediately.
    // Ordinary signup also keeps its existing static presentation.
    final entrance = _canAnimate ? _entrance : null;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Poppins has taller metrics than the former Jost default. Preserve
        // the vertical journey/PageView gesture and compact only the quiet
        // spacing on short phones rather than nesting another vertical
        // scroller inside it.
        final compact = constraints.maxHeight < 620;
        final emblemSize = compact ? 52.0 : 58.0;
        final content = Padding(
          padding: EdgeInsets.fromLTRB(
            27,
            compact ? 12 : 20,
            27,
            compact ? 12 : 22,
          ),
          child: Column(
            crossAxisAlignment: previewStyle?.centered == false
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.center,
            children: [
              Text(
                'Selah',
                style: SelahText.wordmark(
                  size: 17,
                  color: SelahColors.splashWordmark,
                ),
              ),
              SizedBox(height: compact ? 6 : 8),
              Text(
                'PROFILE SETUP · OVERVIEW',
                textAlign: previewStyle?.centered == false
                    ? TextAlign.left
                    : TextAlign.center,
                style: SelahText.chapterLabel(color: SelahColors.ink(0.54)),
              ),
              const Spacer(flex: 2),
              if (previewStyle != null)
                _WelcomeEntrance(
                  progress: entrance,
                  step: 0,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      OnboardingPreviewAccent(
                        style: previewStyle,
                        size: emblemSize,
                        progress: 0,
                      ),
                      // Atoms' welcome artwork otherwise has only a muted
                      // centre. One quiet dot ties it to the gold progress
                      // marks used by the following onboarding stages.
                      if (widget.animateEntrance &&
                          previewStyle.directionName == 'atoms')
                        ExcludeSemantics(
                          child: Container(
                            key: const ValueKey(
                              'onboarding_welcome_progress_cue',
                            ),
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: SelahColors.journeyGold,
                              boxShadow: [
                                BoxShadow(
                                  color: SelahColors.journeyGold.withValues(
                                    alpha: 0.28,
                                  ),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                )
              else
                _WelcomeEntrance(
                  progress: entrance,
                  step: 0,
                  child: Container(
                    width: emblemSize,
                    height: emblemSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: SelahColors.frostFill,
                      border: Border.all(
                        color: SelahColors.unlockDot.withValues(alpha: 0.62),
                        width: 0.8,
                      ),
                    ),
                    child: Icon(
                      Icons.auto_awesome_rounded,
                      color: SelahColors.unlockText,
                      size: compact ? 20 : 22,
                    ),
                  ),
                ),
              SizedBox(height: compact ? 17 : 25),
              _WelcomeEntrance(
                progress: entrance,
                step: 1,
                child: Text(
                  title,
                  key: const ValueKey('onboarding_welcome_title'),
                  textAlign: previewStyle?.centered == false
                      ? TextAlign.left
                      : TextAlign.center,
                  style: SelahText.heading(
                    size: previewStyle == null
                        ? (compact ? 27 : 29)
                        : (compact
                              ? previewStyle.titleSize - 2
                              : previewStyle.titleSize),
                  ),
                ),
              ),
              SizedBox(height: compact ? 8 : 12),
              _WelcomeEntrance(
                progress: entrance,
                step: 2,
                child: Text(
                  'Together, we’ll build four things.',
                  textAlign: previewStyle?.centered == false
                      ? TextAlign.left
                      : TextAlign.center,
                  style: SelahText.body(size: compact ? 16 : 17),
                ),
              ),
              SizedBox(height: compact ? 17 : 24),
              _SignupRoadmap(
                allowPreviewScrolling: widget.allowPreviewScrolling,
                revealedCount: _revealedRoadmapItems,
              ),
              const Spacer(flex: 3),
              if (_revealedRoadmapItems == _SignupRoadmap.itemCount)
                _JourneyContinueButton(
                  key: const ValueKey('onboarding_welcome_continue'),
                  label: 'Continue to Your Profile',
                  onTap: widget.onContinue,
                )
              else
                const SizedBox(height: 52),
            ],
          ),
        );
        final canReveal = _revealedRoadmapItems < _SignupRoadmap.itemCount;
        return Semantics(
          container: true,
          explicitChildNodes: true,
          button: canReveal,
          enabled: canReveal ? true : null,
          label: canReveal ? 'Reveal next setup step' : null,
          value: canReveal ? '$_revealedRoadmapItems of 4 revealed' : null,
          onTap: canReveal ? _revealNextRoadmapItem : null,
          child: GestureDetector(
            key: const ValueKey('onboarding_welcome_reveal_tap_area'),
            behavior: HitTestBehavior.opaque,
            excludeFromSemantics: true,
            onTap: _revealNextRoadmapItem,
            child: Stack(
              children: [
                if (widget.allowPreviewScrolling ||
                    constraints.maxHeight < 700 ||
                    MediaQuery.textScalerOf(context).scale(1) > 1.2)
                  SingleChildScrollView(
                    key: const ValueKey(
                      'onboarding_preview_welcome_scrollable',
                    ),
                    controller: widget.scrollController,
                    physics: widget.arrowMode
                        ? const ClampingScrollPhysics(
                            parent: AlwaysScrollableScrollPhysics(),
                          )
                        : null,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: IntrinsicHeight(child: content),
                    ),
                  )
                else
                  content,
                if (widget.accountExit != null)
                  Positioned(top: 0, right: 8, child: widget.accountExit!),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// A deliberately sequential, low-distance reveal. Children keep their
/// layout and semantics throughout, so the visual entrance never shifts the
/// roadmap or withholds content from assistive technology.
class _WelcomeEntrance extends StatelessWidget {
  const _WelcomeEntrance({
    required this.progress,
    required this.step,
    required this.child,
  });

  final Animation<double>? progress;
  final int step;
  final Widget child;

  static const _windows = <(int, int)>[
    (0, 500), // motif
    (350, 900), // greeting
    (900, 1430), // four-things introduction
    (1430, 1810), // profile
    (1790, 2170), // Journey Bio
    (2150, 2530), // compatibility
    (2510, 2890), // review
  ];

  @override
  Widget build(BuildContext context) {
    final animation = progress;
    if (animation == null) return child;
    final window = _windows[step];
    return AnimatedBuilder(
      key: ValueKey('onboarding_welcome_reveal_$step'),
      animation: animation,
      child: child,
      builder: (context, child) {
        final elapsed = animation.value * 2900;
        final fraction = ((elapsed - window.$1) / (window.$2 - window.$1))
            .clamp(0.0, 1.0);
        final visible = Curves.easeOutCubic.transform(fraction);
        return Opacity(
          opacity: visible,
          alwaysIncludeSemantics: true,
          child: Transform.translate(
            offset: Offset(0, 8 * (1 - visible)),
            child: child,
          ),
        );
      },
    );
  }
}

class _SignupRoadmap extends StatelessWidget {
  const _SignupRoadmap({
    this.allowPreviewScrolling = false,
    required this.revealedCount,
  });
  final bool allowPreviewScrolling;
  final int revealedCount;

  static const _items = <(String, String)>[
    ('Your profile', 'Your photos and background details.'),
    ('Your Journey Bio', 'Optional · shared in a Journey.'),
    ('Compatibility', 'Private answers and partner preferences.'),
    ('Review & go live', 'Check everything before you are seen.'),
  ];
  static const itemCount = 4;

  @override
  Widget build(BuildContext context) {
    final reducedMotion =
        MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context);
    return Column(
      children: [
        for (var index = 0; index < _items.length; index++)
          IgnorePointer(
            ignoring: index >= revealedCount,
            child: AnimatedSlide(
              duration: reducedMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 420),
              curve: Curves.easeOutCubic,
              offset: reducedMotion || index < revealedCount
                  ? Offset.zero
                  : const Offset(0, 0.08),
              child: AnimatedOpacity(
                key: ValueKey('onboarding_roadmap_item_${index + 1}'),
                duration: reducedMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 420),
                curve: Curves.easeOutCubic,
                opacity: index < revealedCount ? 1 : 0,
                child: _RoadmapRow(
                  number: index + 1,
                  title: _items[index].$1,
                  note: _items[index].$2,
                  showLine: index < _items.length - 1,
                  allowPreviewScrolling: allowPreviewScrolling,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _RoadmapRow extends StatelessWidget {
  final int number;
  final String title;
  final String note;
  final bool showLine;
  final bool allowPreviewScrolling;

  const _RoadmapRow({
    required this.number,
    required this.title,
    required this.note,
    required this.showLine,
    this.allowPreviewScrolling = false,
  });

  @override
  Widget build(BuildContext context) {
    final previewStyle = OnboardingPreviewStyle.effectiveStyleOf(context);
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 34,
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              if (showLine)
                Positioned(
                  top: 25,
                  bottom: 0,
                  child: Container(width: 0.7, color: SelahColors.ink(0.24)),
                ),
              Container(
                width: 27,
                height: 27,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: SelahColors.unlockDot.withValues(alpha: 0.72),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  '$number',
                  style: SelahText.subtext(
                    size: 10.5,
                    color: SelahColors.unlockText,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: SelahText.body(size: 13.5)),
                SizedBox(height: 1),
                Text(
                  note,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: SelahText.subtext(
                    size: 10.5,
                    color: SelahColors.ink(0.54),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
    if (previewStyle != null && previewStyle.directionName != 'structured') {
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
        decoration: previewStyle.cardDecoration(selected: number == 1),
        child: row,
      );
    }
    if (allowPreviewScrolling) {
      return ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 49),
        child: IntrinsicHeight(child: row),
      );
    }
    return SizedBox(height: 49, child: row);
  }
}

class _StagePage extends StatelessWidget {
  final OnboardingStageContent stage;
  final int stageIndex;
  final VoidCallback onContinue;
  final VoidCallback? onScrollUp;
  final Widget? accountExit;
  final bool arrowMode;
  final ScrollController? scrollController;

  const _StagePage({
    required this.stage,
    required this.stageIndex,
    required this.onContinue,
    this.onScrollUp,
    this.accountExit,
    this.arrowMode = false,
    this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    final previewStyle = OnboardingPreviewStyle.effectiveStyleOf(context);
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        key: const ValueKey('onboarding_stage_scrollable'),
        controller: scrollController,
        physics: arrowMode
            ? const ClampingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              )
            : const ClampingScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: IntrinsicHeight(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(27, 16, 27, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'Selah',
                    style: SelahText.wordmark(
                      size: 17,
                      color: SelahColors.splashWordmark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (onScrollUp != null)
                    Align(
                      alignment: Alignment.center,
                      child: _ScrollUpCue(onTap: onScrollUp!),
                    )
                  else
                    const SizedBox(height: 25),
                  const Spacer(flex: 2),
                  if (stage.id == 'account_essentials')
                    const _AccountEssentialsArtwork()
                  else if (previewStyle != null)
                    OnboardingPreviewAccent(
                      style: previewStyle,
                      size: 70,
                      progress:
                          (stageIndex + 1) / seekerOnboardingStages.length,
                    )
                  else
                    Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: SelahColors.frostFill,
                        border: Border.all(
                          color: SelahColors.unlockDot.withValues(alpha: 0.62),
                          width: 0.8,
                        ),
                      ),
                      child: Icon(
                        Icons.auto_awesome_rounded,
                        color: SelahColors.unlockText,
                        size: 26,
                      ),
                    ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: Text(
                      stage.title.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: SelahText.chapterLabel(
                        color: SelahColors.unlockText,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: Text(
                      stage.heading,
                      key: ValueKey('onboarding_stage_${stage.id}'),
                      textAlign: TextAlign.center,
                      style: SelahText.heading(
                        size: previewStyle?.titleSize ?? 30,
                      ),
                    ),
                  ),
                  if (stage.id == 'account_essentials') ...[
                    const SizedBox(height: 18),
                    Text(
                      stage.summary,
                      textAlign: TextAlign.center,
                      style: SelahText.body(size: 16).copyWith(height: 1.6),
                    ),
                  ],
                  const Spacer(flex: 3),
                  _JourneyContinueButton(
                    key: const ValueKey('onboarding_stage_continue'),
                    label: stage.buttonLabel,
                    onTap: onContinue,
                  ),
                  if (accountExit != null) ...[
                    const SizedBox(height: 4),
                    Align(alignment: Alignment.center, child: accountExit!),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Account details, not a completed identity check. Decorative and deliberately
/// local to this handoff so the other stages keep their existing artwork.
class _AccountEssentialsArtwork extends StatelessWidget {
  const _AccountEssentialsArtwork();

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        key: const ValueKey('onboarding_account_essentials_artwork'),
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: SelahColors.journeyGold.withValues(alpha: 0.38),
            width: 0.8,
          ),
          gradient: RadialGradient(
            colors: [
              SelahColors.journeyGold.withValues(alpha: 0.16),
              SelahColors.journeyGold.withValues(alpha: 0.04),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: SelahColors.journeyGold.withValues(alpha: 0.08),
              blurRadius: 18,
            ),
          ],
        ),
        child: const Icon(
          Icons.person_outline_rounded,
          key: ValueKey('onboarding_account_essentials_icon'),
          color: SelahColors.journeyGold,
          size: 32,
        ),
      ),
    );
  }
}

class _ScrollUpCue extends StatelessWidget {
  final VoidCallback onTap;

  const _ScrollUpCue({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Back to overview',
      child: InkWell(
        key: const ValueKey('onboarding_stage_scroll_up'),
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          child: Icon(
            Icons.keyboard_arrow_up_rounded,
            color: SelahColors.ink(0.70),
            size: 20,
          ),
        ),
      ),
    );
  }
}

class _JourneyContinueButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _JourneyContinueButton({
    super.key,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final previewStyle = OnboardingPreviewStyle.effectiveStyleOf(context);
    if (SelahOnboardingArrowScope.enabledOf(context)) {
      return SizedBox(
        width: double.infinity,
        height: 52,
        child: Center(
          child: SelahOnboardingArrowAction(
            active: true,
            onPressed: onTap,
            semanticLabel: label,
          ),
        ),
      );
    }
    if (previewStyle != null) {
      return SizedBox(
        width: double.infinity,
        height: 51,
        child: FilledButton(
          onPressed: onTap,
          style: previewStyle.primaryButtonStyle,
          child: Text(label, style: SelahText.button()),
        ),
      );
    }
    return SizedBox(
      width: double.infinity,
      height: 51,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: SelahColors.frostFill,
          border: Border.all(color: SelahColors.glassBorder, width: 0.7),
          borderRadius: BorderRadius.circular(50),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(50),
            onTap: onTap,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.fade,
                    style: SelahText.button(color: Colors.white),
                  ),
                ),
                SizedBox(width: 9),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: SelahColors.ink(0.70),
                  size: 19,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
