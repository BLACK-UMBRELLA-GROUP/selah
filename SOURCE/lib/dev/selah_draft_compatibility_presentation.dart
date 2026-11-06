import 'package:flutter/material.dart';

import '../theme/selah_colors.dart';
import '../theme/selah_text.dart';
import 'selah_compatibility_demo.dart';

/// Display-only Compatibility for the protected, fictional member preview.
///
/// The caller owns balances, reveal state, navigation and callback lifetime.
/// This widget cannot read answers, grant access, spend credits or load people.
/// Finite phone viewports fit normal text; enlarged text can scroll without
/// scaling the page down. Back gestures remain owned by the shell.
class SelahDraftCompatibilityPresentation extends StatefulWidget {
  const SelahDraftCompatibilityPresentation({
    super.key,
    required this.personName,
    required this.balance,
    required this.overallScore,
    required this.revealed,
    this.onUnlock,
    this.onBuyMore,
  }) : assert(balance >= 0),
       assert(overallScore >= 0 && overallScore <= 100);

  final String personName;
  final int balance;
  final int overallScore;
  final bool revealed;
  final VoidCallback? onUnlock;
  final VoidCallback? onBuyMore;

  @override
  State<SelahDraftCompatibilityPresentation> createState() =>
      _SelahDraftCompatibilityPresentationState();
}

class _SelahDraftCompatibilityPresentationState
    extends State<SelahDraftCompatibilityPresentation>
    with TickerProviderStateMixin {
  late final AnimationController _overallMotion;
  late final AnimationController _plusMotion;
  late final Listenable _motion;

  bool get _overallOpen => widget.revealed;
  bool get _quiet =>
      MediaQuery.of(context).disableAnimations ||
      MediaQuery.of(context).accessibleNavigation;

  @override
  void initState() {
    super.initState();
    _overallMotion = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
      value: _overallOpen ? 1 : 0,
    );
    _plusMotion = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1850),
      value: widget.revealed ? 1 : 0,
    );
    _motion = Listenable.merge([_overallMotion, _plusMotion]);
  }

  @override
  void didUpdateWidget(SelahDraftCompatibilityPresentation oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncMotion(_overallMotion, oldWidget.revealed, _overallOpen);
    _syncMotion(_plusMotion, oldWidget.revealed, widget.revealed);
  }

  void _syncMotion(AnimationController motion, bool before, bool after) {
    if (!after) {
      motion.value = 0;
    } else if (!before) {
      if (_quiet) {
        motion.value = 1;
      } else {
        motion.forward(from: 0);
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_quiet) {
      _overallMotion.value = _overallOpen ? 1 : 0;
      _plusMotion.value = widget.revealed ? 1 : 0;
    }
  }

  @override
  void dispose() {
    _overallMotion.dispose();
    _plusMotion.dispose();
    super.dispose();
  }

  Widget _overallResult(Widget locked) => AnimatedBuilder(
    animation: _overallMotion,
    builder: (context, _) {
      if (!_overallOpen) return locked;
      final progress = Curves.easeOutCubic.transform(_overallMotion.value);
      return _DraftReveal(
        progress: progress,
        id: 'draft_compatibility_overall_result',
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 4,
          children: [
            Text(
              '${(widget.overallScore * progress).round()}%',
              key: const ValueKey('draft_compatibility_overall_score'),
              semanticsLabel:
                  'Overall compatibility: '
                  '${widget.overallScore} percent aligned.',
              style: SelahText.heading(size: 44).copyWith(height: 1.15),
            ),
            Text('aligned', style: SelahText.subtext(size: 13)),
          ],
        ),
      );
    },
  );

  Widget _footer(_DraftFooterMetrics metrics) => AnimatedBuilder(
    animation: _motion,
    builder: (context, _) {
      final busy = _overallMotion.isAnimating || _plusMotion.isAnimating;
      final enabled =
          !widget.revealed &&
          widget.balance > 0 &&
          widget.onUnlock != null &&
          !busy;
      final label = busy
          ? 'Revealing'
          : widget.revealed
          ? 'Revealed'
          : 'Reveal';
      final gold = SelahColors.journeyGold;
      final foreground = gold.withValues(alpha: enabled || busy ? 1 : .55);
      final balance = Text(
        _balanceLabel(widget.balance),
        key: const ValueKey('draft_compatibility_balances'),
        textAlign: metrics.stacked ? TextAlign.center : TextAlign.right,
        style: metrics.balanceStyle.copyWith(
          color: foreground.withValues(alpha: enabled || busy ? .8 : .55),
        ),
      );
      final action = Text(
        label,
        textAlign: TextAlign.center,
        style: metrics.actionStyle.copyWith(color: foreground),
      );
      final icon = Icon(
        widget.revealed && !busy
            ? Icons.check_rounded
            : Icons.lock_open_rounded,
        size: 18,
        color: foreground,
      );
      return Column(
        key: const ValueKey('draft_compatibility_actions'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OutlinedButton(
            key: const ValueKey('draft_compatibility_reveal'),
            onPressed: enabled ? widget.onUnlock : null,
            style: OutlinedButton.styleFrom(
              minimumSize: Size(44, metrics.controlHeight),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.standard,
              shape: const StadiumBorder(),
              foregroundColor: foreground,
              backgroundColor: gold.withValues(alpha: .10),
              side: BorderSide(
                color: gold.withValues(alpha: enabled || busy ? .6 : .25),
              ),
            ),
            child: Semantics(
              label:
                  '$label Compatibility Unlock. ${_balanceLabel(widget.balance)}',
              child: ExcludeSemantics(
                child: SizedBox(
                  width: double.infinity,
                  height: metrics.contentHeight,
                  child: metrics.stacked
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                icon,
                                const SizedBox(width: 8),
                                Flexible(child: action),
                              ],
                            ),
                            const SizedBox(height: 4),
                            balance,
                          ],
                        )
                      : Stack(
                          alignment: Alignment.center,
                          children: [
                            Align(alignment: Alignment.centerLeft, child: icon),
                            Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: metrics.sideExtent + 12,
                              ),
                              child: action,
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: SizedBox(
                                width: metrics.sideExtent,
                                child: balance,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.center,
            child: TextButton(
              key: const ValueKey('draft_compatibility_buy_more'),
              onPressed: widget.onBuyMore,
              style: TextButton.styleFrom(
                minimumSize: Size(44, metrics.moreHeight),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.standard,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                foregroundColor: SelahColors.foreground.withValues(alpha: .7),
              ),
              child: Text(
                'Get more unlocks',
                textAlign: TextAlign.center,
                style: metrics.moreStyle,
              ),
            ),
          ),
        ],
      );
    },
  );

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final height = constraints.hasBoundedHeight
          ? constraints.maxHeight
          : double.infinity;
      final largeText = MediaQuery.textScalerOf(context).scale(14) > 16.8;
      final compact = height < 620 && !largeText;
      final gap = compact ? 4.0 : 10.0;
      final sectionPadding = compact ? 6.0 : 14.0;
      final textScaler = MediaQuery.textScalerOf(context);
      final nameHeight = _textSize(
        context,
        'You and ${widget.personName}',
        SelahText.heading(size: 22).copyWith(height: 1.15),
        constraints.maxWidth,
      ).height;
      final overallBodyHeight = _textSize(
        context,
        'Your overall compatibility with ${widget.personName}.',
        SelahText.body(size: 14).copyWith(height: 1.2),
        (constraints.maxWidth -
                26 -
                20 -
                10 -
                8 -
                _textSize(
                  context,
                  '__%',
                  SelahText.heading(size: 26).copyWith(height: 1.15),
                  double.infinity,
                ).width)
            .clamp(1, double.infinity)
            .toDouble(),
      ).height;
      final overallSlotHeight = overallBodyHeight
          .clamp(
            _textSize(
              context,
              '100%',
              SelahText.heading(size: 44).copyWith(height: 1.15),
              double.infinity,
            ).height,
            double.infinity,
          )
          .toDouble();
      final sectionWidth = (constraints.maxWidth - 26)
          .clamp(1, double.infinity)
          .toDouble();
      final chapterHeight = _textSize(
        context,
        'DETAILS',
        SelahText.chapterLabel().copyWith(height: 1.2),
        sectionWidth,
      ).height;
      final tableHeaderHeight = _textSize(
        context,
        'Opposed',
        SelahText.subtext(size: 9.5).copyWith(height: 1.2),
        textScaler.scale(51),
      ).height;
      final minimumCardHeight =
          2 +
          sectionPadding * 4 +
          chapterHeight * 2 +
          gap * 4 +
          overallSlotHeight +
          2 +
          tableHeaderHeight +
          36 * 6;
      final footer = _DraftFooterMetrics.measure(
        context,
        width: constraints.maxWidth,
        balance: widget.balance,
      );
      final minimumPageHeight =
          _textSize(
            context,
            'Compatibility',
            SelahText.heading(size: 26).copyWith(height: 1.15),
            constraints.maxWidth,
          ).height +
          nameHeight +
          gap +
          32 +
          minimumCardHeight +
          footer.height;
      // Controls are reserved once, outside the result card. Revealing never
      // removes a button or redistributes row height. Accessible/short layouts
      // retain the readable scroll fallback rather than shrinking the font.
      final fillViewport =
          constraints.hasBoundedHeight &&
          !largeText &&
          !compact &&
          constraints.maxWidth >= textScaler.scale(315) &&
          nameHeight <= textScaler.scale(26) &&
          overallBodyHeight <= textScaler.scale(34) &&
          height >= minimumPageHeight;
      final content = Column(
        key: const ValueKey('draft_compatibility_presentation'),
        mainAxisSize: fillViewport ? MainAxisSize.max : MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Compatibility',
            style: SelahText.heading(size: 26).copyWith(height: 1.15),
          ),
          SizedBox(height: gap),
          Text(
            'You and ${widget.personName}',
            style: SelahText.heading(size: 22).copyWith(height: 1.15),
          ),
          SizedBox(height: compact ? 6 : 16),
          _expand(
            fillViewport,
            Container(
              key: const ValueKey('draft_compatibility_card'),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _DraftSection(
                    label: 'OVERALL',
                    gap: gap,
                    verticalPadding: sectionPadding,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: overallSlotHeight),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: _overallResult(
                          Row(
                            children: [
                              Icon(
                                Icons.lock_outline,
                                size: 20,
                                color: Colors.white.withValues(alpha: .45),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Your overall compatibility with ${widget.personName}.',
                                  semanticsLabel:
                                      'Your overall compatibility with ${widget.personName}.',
                                  style: SelahText.body(
                                    size: 14,
                                  ).copyWith(height: 1.2),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '__%',
                                style: SelahText.heading(
                                  size: 26,
                                  color: Colors.white24,
                                ).copyWith(height: 1.15),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Divider(
                    color: Colors.white.withValues(alpha: .14),
                    height: 1,
                    thickness: 1,
                  ),
                  _expand(
                    fillViewport,
                    _DraftSection(
                      label: 'DETAILS',
                      gap: gap,
                      verticalPadding: sectionPadding,
                      fillChild: fillViewport,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _expand(
                            fillViewport,
                            _DraftBreakdown(
                              revealed: widget.revealed,
                              animation: _plusMotion,
                              rowHeight: compact ? 32 : 36,
                              fontSize: fillViewport ? 12.5 : 11.5,
                              fillRows: fillViewport,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: compact ? 6 : 16),
          _footer(footer),
        ],
      );
      return SingleChildScrollView(
        key: const ValueKey('draft_compatibility_viewport'),
        child: fillViewport
            ? SizedBox(height: height, child: content)
            : content,
      );
    },
  );
}

String _balanceLabel(int balance) =>
    '$balance ${balance == 1 ? 'unlock' : 'unlocks'} left';

/// Measure all action states once so a reveal/debit cannot move the card.
/// The same explicit styles are used by the painter and the visible controls.
class _DraftFooterMetrics {
  const _DraftFooterMetrics({
    required this.stacked,
    required this.sideExtent,
    required this.contentHeight,
    required this.controlHeight,
    required this.moreHeight,
    required this.actionStyle,
    required this.balanceStyle,
    required this.moreStyle,
  });

  final bool stacked;
  final double sideExtent;
  final double contentHeight;
  final double controlHeight;
  final double moreHeight;
  final TextStyle actionStyle;
  final TextStyle balanceStyle;
  final TextStyle moreStyle;
  double get height => controlHeight + 4 + moreHeight;

  static _DraftFooterMetrics measure(
    BuildContext context, {
    required double width,
    required int balance,
  }) {
    TextStyle resolved(TextStyle style) {
      var result = (Theme.of(context).textTheme.bodyMedium ?? const TextStyle())
          .merge(style)
          .copyWith(height: 1.2, inherit: false);
      if (MediaQuery.boldTextOf(context)) {
        result = result.merge(const TextStyle(fontWeight: FontWeight.bold));
      }
      return result;
    }

    final actionStyle = resolved(SelahText.button(size: 14));
    final balanceStyle = resolved(SelahText.subtext(size: 11.5));
    final moreStyle = resolved(
      SelahText.button(
        size: 12.5,
        color: SelahColors.foreground.withValues(alpha: .7),
      ),
    );
    final innerWidth = (width - 34).clamp(1, double.infinity).toDouble();
    final actions = [
      for (final label in ['Reveal', 'Revealing', 'Revealed'])
        _textSize(context, label, actionStyle, double.infinity),
    ];
    final counts = {
      _balanceLabel(balance),
      _balanceLabel(balance > 0 ? balance - 1 : 0),
      _balanceLabel(0),
      _balanceLabel(1),
    };
    final sideExtent = [
      18.0,
      for (final count in counts)
        _textSize(context, count, balanceStyle, double.infinity).width,
    ].reduce((a, b) => a > b ? a : b);
    final actionWidth = actions
        .map((s) => s.width)
        .reduce((a, b) => a > b ? a : b);
    final stacked = actionWidth + 2 * (sideExtent + 12) > innerWidth;
    final actionHeight = [
      18.0,
      for (final label in ['Reveal', 'Revealing', 'Revealed'])
        _textSize(
          context,
          label,
          actionStyle,
          stacked
              ? (innerWidth - 26).clamp(1, double.infinity).toDouble()
              : innerWidth,
        ).height,
    ].reduce((a, b) => a > b ? a : b);
    final balanceHeight = [
      for (final count in counts)
        _textSize(context, count, balanceStyle, innerWidth).height,
    ].reduce((a, b) => a > b ? a : b);
    final contentHeight = stacked
        ? actionHeight + 4 + balanceHeight
        : (actionHeight > balanceHeight ? actionHeight : balanceHeight);
    return _DraftFooterMetrics(
      stacked: stacked,
      sideExtent: sideExtent,
      contentHeight: contentHeight,
      controlHeight: (contentHeight + 20).clamp(52, double.infinity).toDouble(),
      moreHeight:
          (_textSize(
                    context,
                    'Get more unlocks',
                    moreStyle,
                    width - 24,
                  ).height +
                  16)
              .clamp(44, double.infinity)
              .toDouble(),
      actionStyle: actionStyle,
      balanceStyle: balanceStyle,
      moreStyle: moreStyle,
    );
  }
}

Widget _expand(bool expanded, Widget child) =>
    expanded ? Expanded(child: child) : child;

Size _textSize(
  BuildContext context,
  String text,
  TextStyle style,
  double width,
) {
  var measuredStyle = DefaultTextStyle.of(context).style.merge(style);
  if (MediaQuery.boldTextOf(context)) {
    measuredStyle = measuredStyle.merge(
      const TextStyle(fontWeight: FontWeight.bold),
    );
  }
  final measured = TextPainter(
    text: TextSpan(text: text, style: measuredStyle),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
  )..layout(maxWidth: width);
  final size = measured.size;
  measured.dispose();
  return size;
}

class _DraftSection extends StatelessWidget {
  const _DraftSection({
    required this.label,
    required this.gap,
    required this.verticalPadding,
    required this.child,
    this.fillChild = false,
  });
  final String label;
  final double gap;
  final double verticalPadding;
  final Widget child;
  final bool fillChild;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.symmetric(horizontal: 12, vertical: verticalPadding),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: SelahText.chapterLabel().copyWith(height: 1.2)),
        SizedBox(height: gap),
        _expand(fillChild, child),
      ],
    ),
  );
}

/// Caller-owned disclosure is already complete; this is one-shot paint only.
/// Fixed slots and opacity0 do not introduce new grants or execute callbacks.
class _DraftReveal extends StatelessWidget {
  const _DraftReveal({
    required this.progress,
    required this.id,
    required this.child,
  });
  final double progress;
  final String id;
  final Widget child;

  @override
  Widget build(BuildContext context) => Opacity(
    key: ValueKey('$id-opacity'),
    opacity: progress,
    child: Transform.translate(
      offset: Offset(0, (1 - progress) * 6),
      child: ClipRect(
        child: Align(
          alignment: Alignment.centerLeft,
          widthFactor: 1,
          child: child,
        ),
      ),
    ),
  );
}

double _lineProgress(double elapsed, int index) {
  final fraction = ((elapsed * 1850 - index * 200) / 650).clamp(0.0, 1.0);
  return Curves.easeOutCubic.transform(fraction);
}

class _DraftBreakdown extends StatelessWidget {
  const _DraftBreakdown({
    required this.revealed,
    required this.animation,
    required this.rowHeight,
    required this.fontSize,
    required this.fillRows,
  });
  final bool revealed;
  final Animation<double> animation;
  final double rowHeight;
  final double fontSize;
  final bool fillRows;
  static const _labels = ['Aligned', 'Discuss', 'Opposed'];
  static const _colors = [
    Color(0xFF6FBF8A),
    Color(0xFFE0C070),
    SelahColors.destructive,
  ];

  Widget _value(int value, int index, bool started) => Text(
    started ? '$value%' : '—',
    textAlign: TextAlign.center,
    style: SelahText.body(
      size: fontSize,
      color: _colors[index].withValues(alpha: started ? 1 : .55),
    ).copyWith(height: 1.2),
  );

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: animation,
    builder: (context, _) => LayoutBuilder(
      builder: (context, constraints) {
        final cellWidth = MediaQuery.textScalerOf(context).scale(51);
        final roomy =
            constraints.maxWidth >= MediaQuery.textScalerOf(context).scale(280);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (roomy)
              Row(
                children: [
                  const Expanded(child: SizedBox.shrink()),
                  for (final label in _labels)
                    SizedBox(
                      width: cellWidth,
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        style: SelahText.subtext(
                          size: 9.5,
                        ).copyWith(height: 1.2),
                      ),
                    ),
                ],
              ),
            for (final (rowIndex, category)
                in SelahCompatibilityDemo.categories.indexed)
              _expand(
                fillRows,
                Builder(
                  builder: (context) {
                    final progress = revealed
                        ? _lineProgress(animation.value, rowIndex)
                        : 0.0;
                    final started =
                        revealed && animation.value * 1850 > rowIndex * 200;
                    final values = [
                      category.aligned,
                      category.discuss,
                      category.opposed,
                    ];
                    final motion = _DraftReveal(
                      id: 'draft_compatibility_category_${category.name}_result',
                      progress: revealed ? progress : 1,
                      child: roomy
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                for (var index = 0; index < 3; index++)
                                  SizedBox(
                                    width: cellWidth,
                                    child: _value(
                                      values[index],
                                      index,
                                      started,
                                    ),
                                  ),
                              ],
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                for (var index = 0; index < 3; index++)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 2,
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            _labels[index],
                                            style: SelahText.subtext(
                                              size: 11.5,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        _value(values[index], index, started),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                    );
                    return Semantics(
                      label: started
                          ? '${category.name}: ${category.aligned}% aligned, ${category.discuss}% discuss, ${category.opposed}% opposed'
                          : '${category.name}, breakdown locked',
                      excludeSemantics: true,
                      child: Container(
                        key: ValueKey(
                          'draft_compatibility_category_${category.name}',
                        ),
                        constraints: BoxConstraints(minHeight: rowHeight),
                        alignment: Alignment.center,
                        padding: EdgeInsets.symmetric(vertical: roomy ? 2 : 10),
                        decoration:
                            category != SelahCompatibilityDemo.categories.last
                            ? BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: Colors.white.withValues(alpha: .10),
                                  ),
                                ),
                              )
                            : null,
                        child: CustomPaint(
                          foregroundPainter: _DraftGoldSweep(
                            progress: revealed ? progress : 1,
                          ),
                          child: roomy
                              ? Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        category.name,
                                        style: SelahText.body(
                                          size: fontSize,
                                        ).copyWith(height: 1.2),
                                      ),
                                    ),
                                    motion,
                                  ],
                                )
                              : Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Text(
                                      category.name,
                                      style: SelahText.body(size: fontSize),
                                    ),
                                    const SizedBox(height: 8),
                                    motion,
                                  ],
                                ),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      },
    ),
  );
}

class _DraftGoldSweep extends CustomPainter {
  const _DraftGoldSweep({required this.progress});
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;
    final paint = Paint()
      ..color = SelahColors.journeyGold.withValues(alpha: .6 * (1 - progress))
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(0, size.height),
      Offset(size.width * progress, size.height),
      paint,
    );
  }

  @override
  bool shouldRepaint(_DraftGoldSweep oldDelegate) =>
      progress != oldDelegate.progress;
}
