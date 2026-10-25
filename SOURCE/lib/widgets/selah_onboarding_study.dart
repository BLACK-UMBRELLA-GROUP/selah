// Founder-requested Mobbin onboarding comparisons, 2026-09-28.
// Pure local artwork/copy, not a registration flow or a permission request.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../dev/dev_onboarding_welcome_motion.dart';
import '../theme/selah_colors.dart';
import '../theme/selah_text.dart';

enum SelahOnboardingDirection {
  current('Current Seeker onboarding'),
  structured('1 · Structured'),
  luma('2 · Luma'),
  revolut('3 · Revolut'),
  headspace('4 · Headspace'),
  mozi('5 · Mozi'),
  wise('6 · Wise'),
  uber('7 · Uber'),
  ahead('8 · Ahead'),
  howWeFeel('9 · How We Feel'),
  atoms('10 · Atoms');

  const SelahOnboardingDirection(this.label);
  final String label;

  /// These are visual welcome stories, not canonical signup chapters.
  static const storyPageCount = 4;
}

/// Initial style for the protected developer rehearsal only. An explicit
/// toggle selection still takes precedence; ordinary member onboarding is
/// not changed by this preview default.
const selahDefaultDevOnboardingDirection = SelahOnboardingDirection.luma;

const _storyBodies = [
  'SELAH introduces you through photos first, so you can see who you’re drawn to. When you both choose to connect, you can get to know the person beyond the first impression.',
  'SELAH shows where your values and expectations align, where they differ and what may need a conversation.',
  'You can invite more than one Shepherd to support you. Once your Journey begins, they can share each stage, offer guidance and help you decide what comes next.',
];

const _storyEyebrows = ['MARRIAGE-FIRST', 'COMPATIBILITY', 'SHEPHERD SUPPORT'];
const _storyHeadings = [
  'Match on attraction.\nConnect on faith.',
  'See where you align\nbefore moving forward.',
  'A Journey you share\nwith your Shepherds.',
];
const _storyNotes = [
  'Built for Christians serious about marriage.',
  'You see the compatibility result—not each other’s private answers.',
  'Support beside you, every step of the way.',
];

// Original first-draft Selah guidance, not a scripture quotation or a
// claimed teaching attributed to a religious authority.
const _selahIntentExcerpt =
    'A first impression can open a conversation. Shared faith, character '
    'and intentions help you understand whether to walk towards marriage together.';
const _selahIntentAttribution =
    'The Selah approach: attraction, shared faith and intentional conversation.';
const _selahIntentExplanation = 'A principle that helped shape SELAH.';

/// Ten different compositions using the existing SELAH palette and type APIs.
/// No photographed members, borrowed logos, inputs, timers, storage or APIs.
class SelahOnboardingStudy extends StatelessWidget {
  const SelahOnboardingStudy({
    super.key,
    required this.direction,
    required this.page,
    this.scrollController,
    this.swipeNavigation = false,
    this.revealStep = 2,
    this.animateReveal = false,
    this.entered = true,
    this.sectionLead = false,
    this.alignArtwork = false,
    this.welcomeMotion,
  }) : assert(page >= 0 && page < SelahOnboardingDirection.storyPageCount);

  final SelahOnboardingDirection direction;
  final int page;
  final ScrollController? scrollController;
  final bool swipeNavigation;

  /// 0 = artwork and label; 1 = heading; 2 = quote/explanation. The
  /// continuous photo-first card uses 3 for its photo explanation after the
  /// Selah guidance, without adding a numbered page.
  /// Direct artwork previews remain fully visible by default.
  final int revealStep;
  final bool animateReveal;
  final bool entered;

  /// Labels the first explanatory card in the seven-step continuous preview
  /// and shows the excerpt without visible reference text. The separate
  /// four-card design comparison keeps its sourced quote page.
  final bool sectionLead;

  /// Keeps the four continuous-story illustrations in one top-aligned slot.
  final bool alignArtwork;
  final SelahWelcomeTextMotion? welcomeMotion;

  Widget _reveal(int step, Widget child) => _StoryReveal(
    visible: entered && revealStep >= step,
    animate: animateReveal,
    motion: welcomeMotion,
    child: child,
  );

  Widget _storyText(
    int step,
    String text,
    TextStyle style, {
    TextAlign textAlign = TextAlign.left,
    Key? textKey,
  }) {
    final motion = welcomeMotion;
    if (motion == null || !motion.typesText) {
      return Text(text, key: textKey, textAlign: textAlign, style: style);
    }
    return _StoryTypedText(
      text: text,
      style: style,
      textAlign: textAlign,
      textKey: textKey,
      motion: motion,
      visible: entered && revealStep >= step,
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxHeight < 510;
      final centered = switch (direction) {
        SelahOnboardingDirection.structured ||
        SelahOnboardingDirection.revolut ||
        SelahOnboardingDirection.wise ||
        SelahOnboardingDirection.uber ||
        SelahOnboardingDirection.howWeFeel => false,
        _ => true,
      };
      if (page == 0) {
        return _QuotePage(
          direction: direction,
          centered: centered,
          compact: compact,
          minHeight: constraints.maxHeight,
          scrollController: scrollController,
          swipeNavigation: swipeNavigation,
          revealStep: revealStep,
          animateReveal: animateReveal,
          entered: entered,
        );
      }
      // The reported principle opens the story; the three themed explanation
      // cards retain their existing artwork and copy associations afterward.
      final contentPage = page - 1;
      final roomy = constraints.maxWidth >= 430;
      final heroFirst =
          alignArtwork ||
          switch (direction) {
            SelahOnboardingDirection.luma ||
            SelahOnboardingDirection.headspace ||
            SelahOnboardingDirection.mozi ||
            SelahOnboardingDirection.ahead ||
            SelahOnboardingDirection.atoms => true,
            _ => false,
          };
      final headingSize = sectionLead && contentPage == 0
          ? (compact ? 22.0 : 25.0)
          : switch (direction) {
              SelahOnboardingDirection.revolut ||
              SelahOnboardingDirection.wise ||
              SelahOnboardingDirection.howWeFeel => compact ? 28.0 : 34.0,
              _ => compact ? 25.0 : 29.0,
            };
      // The continuous story uses one artwork slot even when copy lengths
      // differ. Standalone design comparisons retain their own compositions.
      final artworkHeight = alignArtwork
          ? (compact ? 120.0 : 140.0)
          : (constraints.maxHeight * (heroFirst ? .43 : .38) -
                    (contentPage == 1 ? 32 : 0))
                .clamp(140.0, 290.0);
      final explanationStep = 2;
      final explanation = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: centered
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        children: [
          _storyText(
            explanationStep,
            _storyBodies[contentPage],
            SelahText.body(
              size: sectionLead
                  ? (compact ? 14.0 : (roomy ? 17 : 16))
                  : (compact ? 12.5 : 14),
              color: SelahColors.foregroundSecondary,
            ).copyWith(height: sectionLead ? 1.38 : 1.6),
            textAlign: centered ? TextAlign.center : TextAlign.left,
          ),
          SizedBox(height: sectionLead ? 7 : (compact ? 12 : 18)),
          Row(
            mainAxisAlignment: centered
                ? MainAxisAlignment.center
                : MainAxisAlignment.start,
            children: [
              Icon(
                contentPage == 1
                    ? Icons.lock_outline_rounded
                    : Icons.check_circle_outline_rounded,
                size: 16,
                color: SelahColors.journeyGold,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: _storyText(
                  explanationStep,
                  _storyNotes[contentPage],
                  SelahText.subtext(
                    size: sectionLead ? (roomy ? 13.5 : 13) : 11.5,
                  ),
                ),
              ),
            ],
          ),
        ],
      );
      final text = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: centered
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        children: [
          _reveal(
            0,
            _storyText(
              0,
              sectionLead && contentPage == 0
                  ? 'HOW SELAH WORKS'
                  : _storyEyebrows[contentPage],
              SelahText.chapterLabel(color: SelahColors.journeyGold),
            ),
          ),
          SizedBox(height: sectionLead ? 6 : 10),
          _reveal(
            1,
            _storyText(
              1,
              _storyHeadings[contentPage],
              SelahText.heading(size: headingSize),
              textKey: ValueKey(
                'onboarding-study-heading-${direction.name}-$page',
              ),
              textAlign: centered ? TextAlign.center : TextAlign.left,
            ),
          ),
          SizedBox(height: sectionLead ? 7 : 13),
          if (sectionLead && contentPage == 0)
            AnimatedSwitcher(
              duration:
                  !animateReveal || MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : (welcomeMotion?.duration ??
                        const Duration(milliseconds: 620)),
              transitionBuilder: (child, animation) =>
                  SelahWelcomeTextMotionFrame(
                    motion: welcomeMotion ?? SelahWelcomeTextMotion.slowDescent,
                    animation: animation,
                    child: child,
                  ),
              child: !entered || revealStep < 2
                  ? const SizedBox.shrink(
                      key: ValueKey('onboarding-study-photo-stage-heading'),
                    )
                  : KeyedSubtree(
                      key: const ValueKey(
                        'onboarding-study-photo-stage-complete',
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Semantics(
                            container: true,
                            label:
                                'The Selah approach. '
                                '$_selahIntentExcerpt',
                            child: ExcludeSemantics(
                              child: Container(
                                key: ValueKey(
                                  'onboarding-study-quote-panel-${direction.name}-$page',
                                ),
                                width: double.infinity,
                                padding: EdgeInsets.symmetric(
                                  horizontal: compact ? 8 : 10,
                                  vertical: compact ? 6 : 8,
                                ),
                                decoration: BoxDecoration(
                                  color: SelahColors.journeyGold.withValues(
                                    alpha: .07,
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: SelahColors.journeyGold.withValues(
                                      alpha: .18,
                                    ),
                                  ),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: centered
                                      ? CrossAxisAlignment.center
                                      : CrossAxisAlignment.start,
                                  children: [
                                    _storyText(
                                      2,
                                      'The Selah approach',
                                      SelahText.subtext(
                                        size: compact ? 12 : 13,
                                        color: SelahColors.journeyGold,
                                      ),
                                      textKey: ValueKey(
                                        'onboarding-study-quote-attribution-${direction.name}-$page',
                                      ),
                                      textAlign: centered
                                          ? TextAlign.center
                                          : TextAlign.left,
                                    ),
                                    const SizedBox(height: 5),
                                    _storyText(
                                      2,
                                      '“$_selahIntentExcerpt”',
                                      SelahText.body(
                                        size: compact ? 14 : (roomy ? 17 : 16),
                                        color: SelahColors.foregroundSecondary,
                                      ).copyWith(
                                        height: 1.3,
                                        fontStyle: FontStyle.italic,
                                      ),
                                      textKey: ValueKey(
                                        'onboarding-study-quote-${direction.name}-$page',
                                      ),
                                      textAlign: centered
                                          ? TextAlign.center
                                          : TextAlign.left,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 7),
                          explanation,
                        ],
                      ),
                    ),
            )
          else
            _reveal(2, explanation),
        ],
      );
      final artwork = _reveal(
        0,
        ExcludeSemantics(
          child: SizedBox(
            height: artworkHeight,
            width: double.infinity,
            child: CustomPaint(
              key: ValueKey('onboarding-study-art-${direction.name}-$page'),
              painter: _OnboardingStudyPainter(
                direction,
                contentPage,
                storyPage: page,
              ),
            ),
          ),
        ),
      );
      return SingleChildScrollView(
        key: ValueKey('onboarding-study-scroll-${direction.name}-$page'),
        controller: scrollController,
        physics: swipeNavigation
            ? alignArtwork && contentPage == 2
                  ? const ClampingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    )
                  : const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    )
            : null,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              24,
              alignArtwork ? (compact ? 12 : 46) : (compact ? 12 : 22),
              24,
              16,
            ),
            child: Column(
              mainAxisAlignment: alignArtwork
                  ? MainAxisAlignment.start
                  : MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (direction == SelahOnboardingDirection.structured) ...[
                  _QuietProgress(page: page),
                  const SizedBox(height: 18),
                ],
                if (heroFirst) ...[
                  artwork,
                  SizedBox(height: alignArtwork ? 8 : (compact ? 10 : 14)),
                ],
                if (direction == SelahOnboardingDirection.mozi)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: SelahColors.surfaceFill,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: text,
                  )
                else
                  text,
                if (!heroFirst) ...[
                  SizedBox(height: compact ? 12 : 18),
                  artwork,
                ],
                if (direction == SelahOnboardingDirection.wise) ...[
                  SizedBox(height: compact ? 14 : 22),
                  _RoleTiles(page: page),
                  SizedBox(height: compact ? 12 : 18),
                ] else if (direction == SelahOnboardingDirection.howWeFeel) ...[
                  SizedBox(height: compact ? 14 : 22),
                  _MeaningTiles(page: contentPage),
                  SizedBox(height: compact ? 12 : 18),
                ],
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// Reuses each selected direction's large story artwork for the three
/// role-neutral welcome messages and the final handoff card.
class SelahOnboardingStoryArtwork extends StatelessWidget {
  const SelahOnboardingStoryArtwork({
    super.key,
    required this.direction,
    required this.topic,
    this.height = 260,
    this.symbol,
  }) : assert(topic >= 0 && topic < 3);

  final SelahOnboardingDirection direction;
  final int topic;
  final double height;
  // An additional intro checkpoint reuses the same gold halo and anchor,
  // without adding an artificial fourth photos/compatibility/Shepherd topic.
  final IconData? symbol;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        key: ValueKey('onboarding-welcome-art-${direction.name}-$topic'),
        painter: _OnboardingStudyPainter(
          direction,
          topic,
          storyPage: topic + 1,
          introSymbol: symbol,
        ),
      ),
    ),
  );
}

class _QuotePage extends StatelessWidget {
  const _QuotePage({
    required this.direction,
    required this.centered,
    required this.compact,
    required this.minHeight,
    required this.scrollController,
    required this.swipeNavigation,
    required this.revealStep,
    required this.animateReveal,
    required this.entered,
  });

  final SelahOnboardingDirection direction;
  final bool centered;
  final bool compact;
  final double minHeight;
  final ScrollController? scrollController;
  final bool swipeNavigation;
  final int revealStep;
  final bool animateReveal;
  final bool entered;

  Widget _reveal(int step, Widget child) => _StoryReveal(
    visible: entered && revealStep >= step,
    animate: animateReveal,
    child: child,
  );

  @override
  Widget build(BuildContext context) {
    const page = 0;
    final alignment = centered ? TextAlign.center : TextAlign.left;
    return SingleChildScrollView(
      key: ValueKey('onboarding-study-scroll-${direction.name}-$page'),
      controller: scrollController,
      physics: swipeNavigation
          ? const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics())
          : null,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: minHeight),
        child: Padding(
          padding: EdgeInsets.fromLTRB(24, compact ? 12 : 22, 24, 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (direction == SelahOnboardingDirection.structured) ...[
                const _QuietProgress(page: page),
                SizedBox(height: compact ? 10 : 16),
              ],
              _reveal(
                0,
                Align(
                  alignment: Alignment.center,
                  child: ExcludeSemantics(
                    child: Container(
                      key: ValueKey(
                        'onboarding-study-art-${direction.name}-$page',
                      ),
                      width: compact ? 72 : 92,
                      height: compact ? 72 : 92,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: SelahColors.journeyGold.withValues(alpha: .08),
                        border: Border.all(
                          color: SelahColors.journeyGold.withValues(alpha: .5),
                        ),
                      ),
                      child: Icon(
                        Icons.format_quote_rounded,
                        size: compact ? 33 : 42,
                        color: SelahColors.journeyGold,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: compact ? 12 : 20),
              _reveal(
                0,
                Text(
                  'A PRINCIPLE BEHIND SELAH',
                  textAlign: alignment,
                  style: SelahText.chapterLabel(color: SelahColors.journeyGold),
                ),
              ),
              const SizedBox(height: 10),
              _reveal(
                1,
                Text(
                  'A thoughtful beginning:',
                  key: ValueKey(
                    'onboarding-study-heading-${direction.name}-$page',
                  ),
                  textAlign: alignment,
                  style: SelahText.heading(size: compact ? 25 : 29),
                ),
              ),
              SizedBox(height: compact ? 12 : 18),
              _reveal(
                2,
                Column(
                  crossAxisAlignment: centered
                      ? CrossAxisAlignment.center
                      : CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      container: true,
                      label:
                          'The Selah approach. '
                          '$_selahIntentExcerpt',
                      child: ExcludeSemantics(
                        child: Container(
                          padding: EdgeInsets.all(compact ? 15 : 18),
                          decoration: BoxDecoration(
                            color: SelahColors.surfaceFill,
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: SelahColors.journeyGold.withValues(
                                alpha: .22,
                              ),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: centered
                                ? CrossAxisAlignment.center
                                : CrossAxisAlignment.start,
                            children: [
                              Text(
                                '“$_selahIntentExcerpt”',
                                key: ValueKey(
                                  'onboarding-study-quote-${direction.name}-$page',
                                ),
                                textAlign: alignment,
                                style: SelahText.body(
                                  size: compact ? 13.5 : 15,
                                  color: SelahColors.foreground,
                                ).copyWith(height: 1.5),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _selahIntentAttribution,
                                key: ValueKey(
                                  'onboarding-study-attribution-${direction.name}-$page',
                                ),
                                textAlign: alignment,
                                style: SelahText.subtext(
                                  size: compact ? 11 : 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: compact ? 12 : 18),
                    Text(
                      _selahIntentExplanation,
                      textAlign: alignment,
                      style: SelahText.body(
                        size: compact ? 12.5 : 14,
                        color: SelahColors.foregroundSecondary,
                      ).copyWith(height: 1.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Retains each line's place in the composition so reading reveals never
/// shove the next line or change the scroll position. Reduced-motion users
/// receive the same stages without opacity or movement animation.
class _StoryTypedText extends StatelessWidget {
  const _StoryTypedText({
    required this.text,
    required this.style,
    required this.textAlign,
    required this.textKey,
    required this.motion,
    required this.visible,
  });

  final String text;
  final TextStyle style;
  final TextAlign textAlign;
  final Key? textKey;
  final SelahWelcomeTextMotion motion;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return SelahWelcomeLine(
        text: text,
        style: style,
        textAlign: textAlign,
        textKey: textKey,
        visibleFraction: visible ? 1 : 0,
      );
    }
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: visible ? 1 : 0),
      duration: motion.duration,
      curve: motion.easedTyping ? Curves.easeInOutSine : Curves.linear,
      builder: (context, fraction, _) => SelahWelcomeLine(
        text: text,
        style: style,
        textAlign: textAlign,
        textKey: textKey,
        visibleFraction: fraction,
      ),
    );
  }
}

class _StoryReveal extends StatelessWidget {
  const _StoryReveal({
    required this.visible,
    required this.animate,
    required this.child,
    this.motion,
  });

  final bool visible;
  final bool animate;
  final Widget child;
  final SelahWelcomeTextMotion? motion;

  @override
  Widget build(BuildContext context) {
    final hidden = ExcludeSemantics(excluding: !visible, child: child);
    if (!animate || MediaQuery.disableAnimationsOf(context)) {
      return Opacity(opacity: visible ? 1 : 0, child: hidden);
    }
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: visible ? 1 : 0),
      duration: motion?.duration ?? const Duration(milliseconds: 620),
      curve: motion?.easeOut == true
          ? Curves.easeOutCubic
          : Curves.easeInOutSine,
      child: hidden,
      builder: (context, amount, child) => Opacity(
        opacity: amount,
        child: Transform.translate(
          offset: Offset(0, (1 - amount) * (motion?.travel ?? 12)),
          child: child,
        ),
      ),
    );
  }
}

class _QuietProgress extends StatelessWidget {
  const _QuietProgress({required this.page});
  final int page;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (var i = 0; i < SelahOnboardingDirection.storyPageCount; i++) ...[
        if (i != 0) const SizedBox(width: 6),
        Expanded(
          child: Container(
            height: 4,
            decoration: BoxDecoration(
              color: i <= page
                  ? SelahColors.journeyGold
                  : SelahColors.surfaceFill,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      ],
    ],
  );
}

class _RoleTiles extends StatelessWidget {
  const _RoleTiles({required this.page});
  final int page;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final item in [
        (Icons.person_outline_rounded, 'Seeker'),
        (Icons.shield_outlined, 'Shepherd'),
      ])
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: SelahColors.surfaceFill,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(item.$1, color: SelahColors.journeyGold, size: 19),
              const SizedBox(width: 8),
              Text(item.$2, style: SelahText.body(size: 12)),
            ],
          ),
        ),
    ],
  );
}

class _MeaningTiles extends StatelessWidget {
  const _MeaningTiles({required this.page});
  final int page;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 7,
    runSpacing: 7,
    children: [
      for (final label in switch (page) {
        0 => ['Intention', 'Understanding', 'Support'],
        1 => ['Values', 'Preferences', 'Privacy'],
        _ => ['Consent', 'Guidance', 'Your pace'],
      })
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: SelahColors.journeyGold.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Text(
            label,
            style: SelahText.body(size: 11, color: SelahColors.journeyGold),
          ),
        ),
    ],
  );
}

/// Original code-native illustrations. References influence composition only;
/// no source-brand assets, logos, photos, or slogans are reproduced.
class _OnboardingStudyPainter extends CustomPainter {
  _OnboardingStudyPainter(
    this.direction,
    this.page, {
    required this.storyPage,
    this.introSymbol,
  });
  final SelahOnboardingDirection direction;
  final IconData? introSymbol;

  /// Original artwork topic: attraction, compatibility or Shepherd support.
  final int page;

  /// Position in the four-card opening story, including the quote card.
  final int storyPage;
  Color get gold => SelahColors.journeyGold;
  Color get ink => SelahColors.foreground;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(size.width / 320, size.height / 280);
    canvas.save();
    canvas.translate(
      (size.width - 320 * scale) / 2,
      (size.height - 280 * scale) / 2,
    );
    canvas.scale(scale);
    if (introSymbol != null) {
      _glow(canvas);
    } else {
      switch (direction) {
        case SelahOnboardingDirection.structured:
          _timeline(canvas);
        case SelahOnboardingDirection.luma:
          _glow(canvas);
        case SelahOnboardingDirection.revolut:
          _cards(canvas);
        case SelahOnboardingDirection.headspace:
          _landscape(canvas);
        case SelahOnboardingDirection.mozi:
          _people(canvas);
        case SelahOnboardingDirection.wise:
          _path(canvas);
        case SelahOnboardingDirection.uber:
          _shield(canvas);
        case SelahOnboardingDirection.ahead:
          _orbit(canvas);
        case SelahOnboardingDirection.howWeFeel:
          _mosaic(canvas);
        case SelahOnboardingDirection.atoms:
          _ring(canvas);
        case SelahOnboardingDirection.current:
          _glow(canvas);
      }
    }
    canvas.restore();
  }

  void _card(Canvas c, Rect r, {double radius = 22, double alpha = .09}) {
    c.drawRRect(
      RRect.fromRectAndRadius(r, Radius.circular(radius)),
      Paint()..color = ink.withValues(alpha: alpha),
    );
  }

  void _icon(
    Canvas c,
    IconData icon,
    Offset center,
    double size, {
    Color? color,
  }) {
    final p = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          fontSize: size,
          color: color ?? gold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    p.paint(c, center - Offset(p.width / 2, p.height / 2));
  }

  void _label(
    Canvas c,
    String value,
    Offset at, {
    double size = 13,
    Color? color,
  }) {
    final p = TextPainter(
      text: TextSpan(
        text: value,
        style: value == 'SELAH'
            ? SelahText.wordmark(size: size).copyWith(color: color ?? ink)
            : SelahText.body(size: size, color: color ?? ink),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 250);
    p.paint(c, at);
  }

  void _line(
    Canvas c,
    Offset a,
    Offset b, {
    double alpha = .4,
    double width = 1.5,
  }) {
    c.drawLine(
      a,
      b,
      Paint()
        ..color = gold.withValues(alpha: alpha)
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round,
    );
  }

  void _halo(Canvas c, Offset at, double radius) {
    c.drawCircle(
      at,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [gold.withValues(alpha: .28), gold.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: at, radius: radius)),
    );
  }

  void _avatar(Canvas c, Offset at, double radius, {bool accented = false}) {
    c.drawCircle(
      at,
      radius,
      Paint()
        ..color = accented
            ? gold.withValues(alpha: .18)
            : ink.withValues(alpha: .08),
    );
    c.drawCircle(
      at,
      radius,
      Paint()
        ..color = gold.withValues(alpha: accented ? .8 : .25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    _icon(
      c,
      Icons.person_outline_rounded,
      at,
      radius * 1.15,
      color: accented ? gold : ink.withValues(alpha: .7),
    );
  }

  void _timeline(Canvas c) {
    _line(c, const Offset(31, 47), const Offset(31, 231), alpha: .28, width: 2);
    for (var i = 0; i < 3; i++) {
      final y = 24.0 + i * 78;
      c.drawCircle(
        Offset(31, y + 29),
        11,
        Paint()..color = gold.withValues(alpha: i == page ? 1 : .16),
      );
      if (i <= page) {
        _icon(
          c,
          Icons.check_rounded,
          Offset(31, y + 29),
          14,
          color: SelahColors.luxuryDarkPurple,
        );
      }
      _card(
        c,
        Rect.fromLTWH(57, y, 240, 62),
        alpha: i == page ? .13 : .05,
        radius: 18,
      );
      _icon(
        c,
        [
          Icons.person_outline_rounded,
          Icons.auto_awesome_outlined,
          Icons.people_outline_rounded,
        ][i],
        Offset(85, y + 30),
        23,
      );
      _label(
        c,
        ['Your profile', 'Private values', 'Trusted support'][i],
        Offset(108, y + 18),
      );
      _line(
        c,
        Offset(108, y + 43),
        Offset(245 - i * 18, y + 43),
        alpha: .19,
        width: 3,
      );
    }
  }

  void _glow(Canvas c) {
    _halo(c, const Offset(160, 130), 123);
    c.drawCircle(
      const Offset(160, 130),
      61,
      Paint()..color = gold.withValues(alpha: .10),
    );
    c.drawCircle(
      const Offset(160, 130),
      88,
      Paint()
        ..color = gold.withValues(alpha: .22)
        ..style = PaintingStyle.stroke,
    );
    _icon(
      c,
      introSymbol ??
          [
            Icons.auto_awesome_rounded,
            Icons.tune_rounded,
            Icons.people_outline_rounded,
          ][page],
      const Offset(160, 130),
      69,
    );
    for (var i = 0; i < 4; i++) {
      final a = i * math.pi / 2 + .45;
      final at = Offset(160 + 112 * math.cos(a), 130 + 112 * math.sin(a));
      c.drawCircle(
        at,
        i == page ? 8 : 4,
        Paint()..color = gold.withValues(alpha: i == page ? .8 : .3),
      );
    }
    _card(c, const Rect.fromLTWH(100, 238, 120, 24), radius: 12, alpha: .06);
  }

  void _cards(Canvas c) {
    for (var i = 0; i < 3; i++) {
      c.save();
      c.translate(160.0, 138.0);
      c.rotate((i - 1) * .15);
      c.translate(-160.0 + (i - 1) * 18, -138.0 - i * 12);
      final r = Rect.fromLTWH(55, 65 + i * 28, 210, 142);
      c.drawRRect(
        RRect.fromRectAndRadius(r, const Radius.circular(24)),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [SelahColors.royalPurple, SelahColors.luxuryDarkPurple],
          ).createShader(r),
      );
      c.drawRRect(
        RRect.fromRectAndRadius(r, const Radius.circular(24)),
        Paint()
          ..color = gold.withValues(alpha: .20 + i * .09)
          ..style = PaintingStyle.stroke,
      );
      _label(c, 'SELAH', Offset(76, r.top + 19), size: 17, color: gold);
      _icon(
        c,
        [
          Icons.person_outline_rounded,
          Icons.lock_outline_rounded,
          Icons.shield_outlined,
        ][i],
        Offset(234, r.top + 34),
        24,
      );
      _line(
        c,
        Offset(77, r.bottom - 39),
        Offset(188, r.bottom - 39),
        alpha: .35,
        width: 4,
      );
      _line(
        c,
        Offset(77, r.bottom - 23),
        Offset(143, r.bottom - 23),
        alpha: .2,
        width: 3,
      );
      c.restore();
    }
  }

  void _landscape(Canvas c) {
    _halo(c, const Offset(160, 128), 123);
    c.drawCircle(
      const Offset(160, 101),
      61,
      Paint()..color = gold.withValues(alpha: .83),
    );
    final hills = Path()
      ..moveTo(0, 250)
      ..cubicTo(50, 123, 165, 126, 245, 210)
      ..cubicTo(270, 239, 308, 221, 320, 215)
      ..lineTo(320, 280)
      ..lineTo(0, 280)
      ..close();
    c.drawPath(hills, Paint()..color = SelahColors.royalPurple);
    final front = Path()
      ..moveTo(0, 263)
      ..cubicTo(113, 285, 167, 161, 320, 206)
      ..lineTo(320, 280)
      ..lineTo(0, 280)
      ..close();
    c.drawPath(front, Paint()..color = gold.withValues(alpha: .11));
    _icon(
      c,
      [
        Icons.spa_outlined,
        Icons.self_improvement_rounded,
        Icons.people_outline_rounded,
      ][page],
      const Offset(160, 102),
      38,
      color: SelahColors.luxuryDarkPurple,
    );
  }

  void _people(Canvas c) {
    for (var i = 0; i < 3; i++) {
      final x = 5.0 + i * 101;
      final y = i == 1 ? 24.0 : 56.0;
      _card(
        c,
        Rect.fromLTWH(x, y, 108, 171),
        radius: 28,
        alpha: i == 1 ? .12 : .055,
      );
      _avatar(c, Offset(x + 54, y + 55), 32, accented: i == page);
      _label(
        c,
        ['You', 'Your values', 'Your circle'][i],
        Offset(x + 15, y + 105),
        size: 11.5,
      );
      _card(c, Rect.fromLTWH(x + 16, y + 132, 76, 20), radius: 10, alpha: .09);
    }
    _line(c, const Offset(61, 244), const Offset(257, 244), alpha: .17);
    _icon(c, Icons.handshake_outlined, const Offset(160, 244), 22);
  }

  void _path(Canvas c) {
    final path = Path()
      ..moveTo(25, 217)
      ..cubicTo(67, 215, 66, 75, 144, 75)
      ..cubicTo(224, 75, 193, 216, 285, 128);
    c.drawPath(
      path,
      Paint()
        ..color = gold.withValues(alpha: .75)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round,
    );
    for (final entry in [
      (const Offset(25, 217), Icons.person_outline_rounded),
      (const Offset(145, 75), Icons.auto_awesome_outlined),
      (const Offset(285, 128), Icons.shield_outlined),
    ]) {
      c.drawCircle(entry.$1, 24, Paint()..color = SelahColors.royalPurple);
      c.drawCircle(
        entry.$1,
        24,
        Paint()
          ..color = gold.withValues(alpha: .8)
          ..style = PaintingStyle.stroke,
      );
      _icon(c, entry.$2, entry.$1, 24);
    }
    _label(c, 'A clear path. Your own pace.', const Offset(65, 252), size: 12);
  }

  void _shield(Canvas c) {
    final shield = Path()
      ..moveTo(160, 15)
      ..lineTo(259, 53)
      ..lineTo(250, 154)
      ..quadraticBezierTo(234, 216, 160, 257)
      ..quadraticBezierTo(86, 216, 70, 154)
      ..lineTo(61, 53)
      ..close();
    c.drawPath(
      shield,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [gold.withValues(alpha: .24), gold.withValues(alpha: .045)],
        ).createShader(const Rect.fromLTWH(61, 15, 198, 242)),
    );
    c.drawPath(
      shield,
      Paint()
        ..color = gold.withValues(alpha: .48)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    _avatar(c, const Offset(129, 133), 38, accented: true);
    _avatar(c, const Offset(194, 141), 32);
    _line(
      c,
      const Offset(131, 207),
      const Offset(183, 207),
      alpha: .66,
      width: 3,
    );
    _icon(c, Icons.arrow_forward_rounded, const Offset(204, 207), 24);
  }

  void _orbit(Canvas c) {
    _halo(c, const Offset(160, 137), 114);
    c.drawOval(
      const Rect.fromLTWH(31, 80, 259, 105),
      Paint()
        ..color = gold.withValues(alpha: .3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    c.save();
    c.translate(160.0, 132.0);
    c.rotate(-.58);
    c.translate(-160.0, -132.0);
    c.drawOval(
      const Rect.fromLTWH(31, 80, 259, 105),
      Paint()
        ..color = gold.withValues(alpha: .24)
        ..style = PaintingStyle.stroke,
    );
    c.restore();
    c.drawCircle(
      const Offset(160, 132),
      54,
      Paint()..color = gold.withValues(alpha: .17),
    );
    _icon(
      c,
      [
        Icons.auto_awesome_rounded,
        Icons.tune_rounded,
        Icons.shield_outlined,
      ][page],
      const Offset(160, 132),
      44,
    );
    for (final at in [
      const Offset(43, 135),
      const Offset(245, 76),
      const Offset(250, 164),
    ]) {
      _icon(c, Icons.auto_awesome_rounded, at, 20);
    }
    _card(c, const Rect.fromLTWH(63, 226, 194, 34), radius: 17, alpha: .08);
    _label(
      c,
      ['Start thoughtfully', 'Know what matters', 'Keep support close'][page],
      const Offset(88, 235),
      size: 11,
    );
  }

  void _mosaic(Canvas c) {
    final icons = [
      Icons.person_outline_rounded,
      Icons.auto_awesome_outlined,
      Icons.shield_outlined,
      Icons.people_outline_rounded,
    ];
    for (var i = 0; i < 4; i++) {
      final x = 45.0 + (i % 2) * 119;
      final y = 19.0 + (i ~/ 2) * 119;
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, 105, 105),
          Radius.circular(i.isEven ? 48 : 22),
        ),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              gold.withValues(alpha: .24 + i * .08),
              gold.withValues(alpha: .10),
            ],
          ).createShader(Rect.fromLTWH(x, y, 105, 105)),
      );
      _icon(
        c,
        icons[(i + page) % 4],
        Offset(x + 52.5, y + 52.5),
        39,
        color: gold.withValues(alpha: .8 + i * .05),
      );
    }
  }

  void _ring(Canvas c) {
    for (var x = 38; x < 300; x += 18) {
      for (var y = 17; y < 265; y += 18) {
        c.drawCircle(
          Offset(x.toDouble(), y.toDouble()),
          1.2,
          Paint()..color = gold.withValues(alpha: .09),
        );
      }
    }
    final r = const Rect.fromLTWH(65, 39, 190, 190);
    c.drawCircle(
      const Offset(160, 134),
      95,
      Paint()
        ..color = gold.withValues(alpha: .12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 22,
    );
    c.drawArc(
      r,
      -math.pi / 2,
      math.pi * 2 * ((storyPage + 1) / SelahOnboardingDirection.storyPageCount),
      false,
      Paint()
        ..color = gold
        ..style = PaintingStyle.stroke
        ..strokeWidth = 22
        ..strokeCap = StrokeCap.round,
    );
    _icon(
      c,
      [
        Icons.auto_awesome_outlined,
        Icons.lock_outline_rounded,
        Icons.people_outline_rounded,
      ][page],
      const Offset(160, 134),
      44,
    );
    c.drawCircle(const Offset(160, 256), 4, Paint()..color = gold);
  }

  @override
  bool shouldRepaint(_OnboardingStudyPainter oldDelegate) =>
      oldDelegate.direction != direction ||
      oldDelegate.page != page ||
      oldDelegate.storyPage != storyPage ||
      oldDelegate.introSymbol != introSymbol;
}
