// Purpose-led, read-only opening rehearsal. This owns presentation only;
// the protected parent still owns provider, role and real signup navigation.
import 'dart:async';

import 'package:flutter/material.dart';

import '../services/selah_developer_access.dart';
import '../theme/selah_colors.dart';
import '../theme/selah_text.dart';
import '../widgets/selah_onboarding_continue_action.dart';
import '../widgets/selah_onboarding_edge_swipe.dart';
import '../widgets/selah_onboarding_study.dart';
import '../widgets/selah_sanctuary_mark.dart';
import 'dev_onboarding_gold_design.dart';
import 'dev_onboarding_interaction.dart';
import 'dev_onboarding_welcome_motion.dart';

// Welcome is separate; verification and the three existing themes share one
// four-slide section. Content identities/keys stay independent of progress.
enum _OpeningPage { welcome, verification, photos, compatibility, shepherds }

class DevOnboardingOpening extends StatefulWidget {
  const DevOnboardingOpening({
    super.key,
    required this.direction,
    required this.welcomeName,
    required this.onContinue,
    this.onBackToProvider,
  });

  final SelahOnboardingDirection direction;
  final String welcomeName;
  final VoidCallback onContinue;
  final VoidCallback? onBackToProvider;

  @override
  State<DevOnboardingOpening> createState() => _DevOnboardingOpeningState();
}

class _DevOnboardingOpeningState extends State<DevOnboardingOpening>
    with SingleTickerProviderStateMixin {
  static const _readingDelay = Duration(seconds: 3);
  static const _storyCount = 4;
  static const _quote =
      'A first impression can open a conversation. Shared faith, character '
      'and intentions help you understand whether to walk towards marriage together.';
  // Original Selah draft prose, not a scripture quotation.
  late final AnimationController _motion;
  final ScrollController _scroll = ScrollController();
  Animation<double>? _routeAnimation;
  Timer? _arrowTimer;
  _OpeningPage _currentPage = _OpeningPage.welcome;
  bool _moving = true;
  bool _entering = true;
  bool _forward = true;
  bool _sectionChange = true;
  bool _entryQueued = false;
  bool _arrowReady = false;
  bool _quoteExpanded = false;
  bool _finishing = false;
  bool _revoked = false;

  bool get _isTrust => _currentPage == _OpeningPage.verification;
  bool get _isStory => _currentPage != _OpeningPage.welcome;
  int get _storyPosition => _currentPage.index;
  int get _page => switch (_currentPage) {
    _OpeningPage.welcome => 0,
    _OpeningPage.verification => 4,
    _OpeningPage.photos => 1,
    _OpeningPage.compatibility => 2,
    _OpeningPage.shepherds => 3,
  };
  Key get _contentKey => _isTrust
      ? const ValueKey('dev_onboarding_verification_intro')
      : ValueKey(
          _page == 0
              ? 'dev_onboarding_welcome_prelude'
              : 'dev_opening_page_$_page',
        );

  bool get _allowed =>
      mounted && !_revoked && SelahDeveloperAccess.canUseDeveloperTools;
  bool get _reduceMotion =>
      MediaQuery.disableAnimationsOf(context) ||
      MediaQuery.accessibleNavigationOf(context);
  bool get _scrollAll =>
      SelahDevOnboardingStoryNavigation.current ==
      SelahOnboardingStoryNavigation.scrollDown;
  bool get _checkpoint => !_isStory || _page == 3;
  bool get _canAdvance =>
      _allowed && !_moving && !_finishing && (_isStory || _arrowReady);
  SelahWelcomeTextMotion get _selectedMotion {
    final selected = SelahDevWelcomeTextMotion.current;
    // A previous comparison selection must not bring character typing back
    // into a reader that now presents complete thoughts on every page.
    return selected.typesText
        ? SelahDevWelcomeTextMotion.defaultMotion
        : selected;
  }

  @override
  void initState() {
    super.initState();
    _motion = AnimationController(vsync: this, value: 1);
    _revoked = !SelahDeveloperAccess.canUseDeveloperTools;
    SelahDeveloperAccess.authorizationChanges.addListener(_onAuthorityChanged);
  }

  void _onAuthorityChanged() {
    if (!SelahDeveloperAccess.canUseDeveloperTools) {
      _revoked = true;
      _arrowTimer?.cancel();
      _motion.stop();
    }
    if (mounted) setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final animation = ModalRoute.of(context)?.animation;
    if (!identical(animation, _routeAnimation)) {
      _routeAnimation?.removeStatusListener(_onRouteStatus);
      _routeAnimation = animation;
      animation?.addStatusListener(_onRouteStatus);
    }
    if (animation == null || animation.status == AnimationStatus.completed) {
      _queueEntry();
    }
  }

  void _onRouteStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) _queueEntry();
  }

  Future<void> _animateTo(double value, Duration duration) async {
    try {
      await _motion
          .animateTo(
            value,
            duration: duration,
            curve: _entering && _selectedMotion.easeOut
                ? Curves.easeOutCubic
                : Curves.easeInOutSine,
          )
          .orCancel;
    } on TickerCanceled {
      // A disposed/revoked rehearsal may cancel its foreground animation.
      // Unexpected animation failures are deliberately not swallowed.
    }
  }

  void _queueEntry() {
    if (_entryQueued || !_allowed) return;
    _entryQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || !_allowed) return;
      if (_reduceMotion) {
        _motion.value = 0;
      } else {
        await _animateTo(
          0,
          Duration(milliseconds: (_selectedMotion.milliseconds * .65).round()),
        );
      }
      if (!mounted || !_allowed) return;
      setState(() => _moving = false);
      _scheduleArrow();
    });
  }

  void _scheduleArrow() {
    _arrowTimer?.cancel();
    if (_isStory) return;
    if (_reduceMotion) {
      setState(() => _arrowReady = true);
      return;
    }
    final scheduledPage = _currentPage;
    _arrowTimer = Timer(_readingDelay, () {
      if (mounted && _allowed && _currentPage == scheduledPage && !_moving) {
        setState(() => _arrowReady = true);
      }
    });
  }

  Future<void> _move(_OpeningPage target, {bool skip = false}) async {
    if (!_allowed ||
        _moving ||
        _finishing ||
        (target.index - _currentPage.index).abs() != 1 ||
        (target.index > _currentPage.index && !skip && !_canAdvance)) {
      return;
    }
    _arrowTimer?.cancel();
    final reduced = _reduceMotion;
    final duration = _selectedMotion.milliseconds;
    setState(() {
      _moving = true;
      _forward = target.index > _currentPage.index;
      _sectionChange = !_isStory || target == _OpeningPage.welcome;
      _entering = false;
    });
    if (!reduced) {
      await _animateTo(1, Duration(milliseconds: (duration * .35).round()));
    }
    if (!mounted || !_allowed) return;
    // Only one foreground page exists. Replace it when fully transparent;
    // an outgoing/incoming AnimatedSwitcher can briefly mix two sentences.
    setState(() {
      _currentPage = target;
      _entering = true;
      _arrowReady = _isStory;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
    SelahDevOnboardingGoldMotion.pageEntered();
    if (!reduced) {
      await _animateTo(0, Duration(milliseconds: (duration * .65).round()));
    } else {
      _motion.value = 0;
    }
    if (!mounted || !_allowed) return;
    setState(() => _moving = false);
    _scheduleArrow();
  }

  Future<void> _finish() async {
    if (!_canAdvance || _page != 3) return;
    setState(() {
      _moving = true;
      _finishing = true;
      _entering = false;
      _forward = true;
      _sectionChange = true;
    });
    if (!_reduceMotion) {
      await _animateTo(1, const Duration(milliseconds: 500));
    }
    if (mounted && _allowed) widget.onContinue();
  }

  void _next({bool skip = false}) {
    if (_page == 3) {
      _finish();
    } else {
      _move(_OpeningPage.values[_currentPage.index + 1], skip: skip);
    }
  }

  void _back() {
    if (!_allowed || _moving || _finishing) return;
    if (_page == 0) {
      widget.onBackToProvider?.call();
    } else {
      _move(_OpeningPage.values[_currentPage.index - 1]);
    }
  }

  @override
  void dispose() {
    SelahDeveloperAccess.authorizationChanges.removeListener(
      _onAuthorityChanged,
    );
    _routeAnimation?.removeStatusListener(_onRouteStatus);
    _arrowTimer?.cancel();
    _motion.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Widget _paragraph(String text, {double size = 16, Key? key}) => Text(
    text,
    key: key,
    textAlign: TextAlign.center,
    style: SelahText.body(
      size: size,
      color: SelahColors.foregroundSecondary,
    ).copyWith(height: 1.55),
  );

  Widget _quoteCard() => Material(
    color: SelahColors.journeyGold.withValues(alpha: .045),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: BorderSide(color: SelahColors.journeyGold.withValues(alpha: .24)),
    ),
    child: Column(
      children: [
        InkWell(
          key: const ValueKey('dev_opening_quote_toggle'),
          borderRadius: BorderRadius.circular(20),
          onTap: _moving
              ? null
              : () => setState(() => _quoteExpanded = !_quoteExpanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(
                  Icons.format_quote_rounded,
                  color: SelahColors.journeyGold,
                  size: 24,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Why photos first?',
                        style: SelahText.body(size: 15),
                      ),
                      Text(
                        'The Selah approach',
                        style: SelahText.subtext(size: 12),
                      ),
                    ],
                  ),
                ),
                Icon(
                  _quoteExpanded ? Icons.expand_less : Icons.expand_more,
                  color: SelahColors.journeyGold,
                ),
              ],
            ),
          ),
        ),
        if (_quoteExpanded)
          Padding(
            key: const ValueKey('dev_opening_quote'),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
            child: _paragraph('“$_quote”', size: 15),
          ),
      ],
    ),
  );

  Widget _content(bool compact) {
    final suppliedName = widget.welcomeName.trim();
    final name = suppliedName.isEmpty
        ? ''
        : suppliedName.split(RegExp(r'\s+')).first;
    final heading = switch (_page) {
      0 => name.isEmpty ? 'Welcome to SELAH.' : 'Welcome to SELAH, $name.',
      4 => 'Verified people.\nSerious intentions.',
      1 => 'Match on attraction.\nConnect on faith.',
      2 => 'Discover where you align.',
      _ => 'A Journey you share\nwith your Shepherds.',
    };
    final body = switch (_page) {
      0 =>
        'A thoughtful space to seek marriage—or support someone on their Journey.',
      4 =>
        'Every Seeker and Shepherd must complete identity verification before joining SELAH.',
      1 =>
        'SELAH introduces you through photos first, so you can see who you’re drawn to. When you both choose to connect, you can get to know the person beyond the first impression.',
      2 =>
        'Explore your compatibility in faith, values and marriage expectations. See what you share—and what may need a conversation.',
      _ =>
        'You can invite more than one Shepherd to support you. Once your Journey begins, they can share each stage, offer guidance and help you decide what comes next.',
    };
    return Padding(
      padding: EdgeInsets.fromLTRB(24, compact ? 6 : 12, 24, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_page == 0 && !_isTrust)
            SizedBox(
              key: const ValueKey('dev_opening_art_0'),
              height: compact ? 120 : 140,
              child: Center(
                child: SelahSanctuaryMark(size: compact ? 104 : 118),
              ),
            )
          else
            SelahOnboardingStoryArtwork(
              key: _isTrust
                  ? const ValueKey('dev_onboarding_verification_art')
                  : ValueKey('dev_opening_art_$_page'),
              direction: widget.direction,
              topic: _isTrust || _page <= 1 ? 0 : _page - 1,
              symbol: _isTrust ? Icons.verified_user_outlined : null,
              height: compact ? 120 : 140,
            ),
          SizedBox(height: compact ? 22 : 24),
          Semantics(
            header: true,
            child: Text(
              heading,
              key: _isTrust
                  ? const ValueKey('dev_onboarding_verification_heading')
                  : ValueKey('dev_opening_heading_$_page'),
              textAlign: TextAlign.center,
              style: SelahText.heading(
                size: compact ? 26 : 29,
              ).copyWith(height: 1.4),
            ),
          ),
          const SizedBox(height: 18),
          _paragraph(
            body,
            key: _isTrust
                ? const ValueKey('dev_onboarding_verification_body')
                : ValueKey('dev_opening_body_$_page'),
          ),
          if (_page == 0) ...[
            const SizedBox(height: 18),
            Divider(color: SelahColors.journeyGold.withValues(alpha: .25)),
            const SizedBox(height: 10),
            _paragraph(
              'A Christ-centred space for faith, connection and marriage.',
              size: 14,
            ),
            const SizedBox(height: 12),
            _paragraph(
              'May your search be shaped by prayer, wisdom and the love of Christ.',
              size: 17,
            ),
          ] else if (_isTrust) ...[
            const SizedBox(height: 26),
            Divider(color: SelahColors.journeyGold.withValues(alpha: .25)),
            const SizedBox(height: 10),
            _paragraph(
              'A shared standard for a community focused on marriage.',
              size: 14,
              key: const ValueKey('dev_onboarding_verification_closing'),
            ),
          ] else if (_page == 1) ...[
            const SizedBox(height: 24),
            _quoteCard(),
            const SizedBox(height: 18),
            _paragraph(
              'Built for Christians serious about marriage.',
              size: 13,
            ),
          ] else ...[
            const SizedBox(height: 26),
            Icon(
              _page == 2 ? Icons.lock_outline_rounded : Icons.groups_outlined,
              size: 22,
              color: SelahColors.journeyGold,
            ),
            const SizedBox(height: 10),
            _paragraph(
              _page == 2
                  ? 'You see the compatibility result—not each other’s private answers.'
                  : 'Support beside you, every step of the way.',
              size: 14,
            ),
          ],
        ],
      ),
    );
  }

  Widget _footer() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            SizedBox(
              width: 68,
              child: TextButton(
                key: ValueKey(
                  _isTrust
                      ? 'dev_onboarding_verification_back'
                      : _page == 0
                      ? 'dev_onboarding_welcome_back'
                      : 'dev_onboarding_story_back',
                ),
                onPressed:
                    _moving || (_page == 0 && widget.onBackToProvider == null)
                    ? null
                    : _back,
                child: Text('Back · DEV', style: SelahText.subtext(size: 11)),
              ),
            ),
            Expanded(
              child: !_isStory
                  ? const SizedBox(height: 44)
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        _storyCount,
                        (index) => Semantics(
                          key: ValueKey('dev_onboarding_story_dot_$index'),
                          label:
                              'How SELAH works, page ${index + 1} of $_storyCount',
                          selected: index == _storyPosition - 1,
                          value: index < _storyPosition - 1
                              ? 'Completed'
                              : index == _storyPosition - 1
                              ? 'Current'
                              : 'Upcoming',
                          child: SizedBox(
                            width: 24,
                            height: 44,
                            child: Center(
                              child: Container(
                                width: index == _storyPosition - 1 ? 20 : 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: index <= _storyPosition - 1
                                      ? SelahColors.journeyGold
                                      : SelahColors.foreground.withValues(
                                          alpha: .25,
                                        ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
            SizedBox(
              width: 68,
              child: Text(
                !_isStory ? '' : '$_storyPosition / $_storyCount',
                key: const ValueKey('dev_onboarding_page_count'),
                textAlign: TextAlign.right,
                style: SelahText.subtext(size: 11),
              ),
            ),
          ],
        ),
        SizedBox(
          height: 52,
          child: Row(
            children: [
              const Expanded(child: SizedBox.shrink()),
              if (_checkpoint || _scrollAll)
                !_isStory && !_arrowReady && !_reduceMotion
                    ? SizedBox.square(
                        key: ValueKey(
                          _isTrust
                              ? 'dev_onboarding_verification_arrow_wait'
                              : 'dev_onboarding_welcome_arrow_wait',
                        ),
                        dimension: 52,
                      )
                    : SelahOnboardingArrowAction(
                        key: ValueKey(
                          _isTrust
                              ? 'dev_onboarding_verification_continue'
                              : _page == 0
                              ? 'dev_onboarding_welcome_continue'
                              : 'dev_onboarding_story_continue',
                        ),
                        active: _canAdvance,
                        onPressed: _canAdvance ? _next : null,
                        repeatCue: true,
                        semanticLabel: _isTrust
                            ? 'See how SELAH works'
                            : _page == 0
                            ? 'See SELAH’s verification standard'
                            : _page == 3
                            ? 'Choose your account role'
                            : 'Next introduction page',
                      )
              else
                IconButton(
                  key: ValueKey(
                    _isTrust
                        ? 'dev_onboarding_verification_continue'
                        : 'dev_opening_next',
                  ),
                  onPressed: _canAdvance ? _next : null,
                  tooltip: 'Next introduction page',
                  icon: const Icon(Icons.chevron_right_rounded),
                  color: SelahColors.journeyGold,
                ),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    key: const ValueKey('dev_onboarding_skip'),
                    onPressed: _moving ? null : () => _next(skip: true),
                    child: Text(
                      'Skip · DEV',
                      style: SelahText.subtext(size: 11),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([
      SelahDevWelcomeTextMotion.changes,
      SelahDevOnboardingStoryNavigation.changes,
    ]),
    builder: (context, _) => Scaffold(
      key: ValueKey('dev_onboarding_introduction_${widget.direction.name}'),
      body: DecoratedBox(
        key: const ValueKey('dev_onboarding_static_canvas'),
        decoration: BoxDecoration(gradient: SelahColors.brandGradient),
        child: Stack(
          fit: StackFit.expand,
          children: [
            const SelahSanctuaryBackdrop(),
            if (_allowed)
              SafeArea(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 12, bottom: 12),
                      child: Text(
                        'SELAH',
                        style: SelahText.wordmark(
                          size: 18,
                          color: SelahColors.splashWordmark,
                        ),
                      ),
                    ),
                    Text(
                      _isTrust
                          ? 'OUR COMMUNITY'
                          : _page == 0
                          ? 'WELCOME'
                          : 'HOW SELAH WORKS',
                      key: const ValueKey('dev_opening_section'),
                      style: SelahText.subtext(
                        size: 11,
                      ).copyWith(letterSpacing: 1.2),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: AnimatedBuilder(
                        animation: _motion,
                        child: SelahOnboardingHorizontalSwipe(
                          onNext: !_scrollAll && !_checkpoint && _canAdvance
                              ? _next
                              : null,
                          onPrevious: !_scrollAll && _page > 0 && !_moving
                              ? _back
                              : null,
                          onTap: !_scrollAll && !_checkpoint && _canAdvance
                              ? _next
                              : null,
                          onTapHint: 'Next introduction page',
                          child: SelahOnboardingEdgeSwipe(
                            key: ValueKey(_currentPage),
                            controller: _scroll,
                            enabled: _allowed && !_moving && !_finishing,
                            onForward: () {
                              if ((_checkpoint || _scrollAll) && _canAdvance) {
                                _next();
                              }
                            },
                            onBackward: _page > 0 ? _back : null,
                            child: LayoutBuilder(
                              builder: (context, constraints) =>
                                  SingleChildScrollView(
                                    key: _contentKey,
                                    controller: _scroll,
                                    physics: const ClampingScrollPhysics(
                                      parent: AlwaysScrollableScrollPhysics(),
                                    ),
                                    child: _content(
                                      MediaQuery.sizeOf(context).height < 700,
                                    ),
                                  ),
                            ),
                          ),
                        ),
                        builder: (context, child) {
                          final hidden = _reduceMotion ? 0.0 : _motion.value;
                          final travel = _sectionChange
                              ? 74.0
                              : 18 + _selectedMotion.travel;
                          final direction = _forward ? 1.0 : -1.0;
                          final matrix = Matrix4.identity()
                            ..setEntry(3, 2, .0005);
                          if (!_sectionChange) {
                            matrix.rotateX(
                              (_entering ? 1 : -1) * direction * .025 * hidden,
                            );
                          }
                          return IgnorePointer(
                            ignoring: _moving,
                            child: Opacity(
                              key: const ValueKey(
                                'dev_opening_foreground_opacity',
                              ),
                              opacity: 1 - hidden,
                              child: Transform.translate(
                                key: const ValueKey(
                                  'dev_onboarding_downward_exit',
                                ),
                                offset: Offset(
                                  0,
                                  (_entering ? direction : -direction) *
                                      travel *
                                      hidden,
                                ),
                                child: Transform(
                                  alignment: Alignment.center,
                                  transform: matrix,
                                  child: child,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    _footer(),
                  ],
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
