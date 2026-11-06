import 'package:flutter/material.dart';

import '../theme/selah_colors.dart';
import '../theme/selah_text.dart';

enum SelahLoadingContent { list, browse, photo, profile }

/// LOCK 2: placeholders at an existing wait point. This widget never starts
/// a load or introduces a new wait into a screen.
class SelahLoading extends StatefulWidget {
  const SelahLoading({super.key, this.label})
    : content = SelahLoadingContent.list,
      fullScreen = false;

  const SelahLoading.fullScreen({super.key, this.label})
    : content = SelahLoadingContent.list,
      fullScreen = true;

  const SelahLoading.list({super.key})
    : content = SelahLoadingContent.list,
      fullScreen = false,
      label = null;

  const SelahLoading.browse({super.key})
    : content = SelahLoadingContent.browse,
      fullScreen = false,
      label = 'Finding people for you…';

  const SelahLoading.photo({super.key})
    : content = SelahLoadingContent.photo,
      fullScreen = false,
      label = null;

  const SelahLoading.profile({super.key})
    : content = SelahLoadingContent.profile,
      fullScreen = false,
      label = null;

  final String? label;
  final SelahLoadingContent content;
  final bool fullScreen;

  @override
  State<SelahLoading> createState() => _SelahLoadingState();
}

class _SelahLoadingState extends State<SelahLoading>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );
  late final Animation<double> _opacity = Tween<double>(
    begin: 1,
    end: .5,
  ).animate(_fade);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final media = MediaQuery.maybeOf(context);
    final reduced =
        (media?.disableAnimations ?? false) ||
        (media?.accessibleNavigation ?? false);
    if (reduced) {
      _fade.stop();
      _fade.value = 0;
    } else if (!_fade.isAnimating) {
      _fade.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shapes = LayoutBuilder(
      builder: (context, constraints) {
        if (widget.content == SelahLoadingContent.photo) {
          return const _Block(radius: 18);
        }
        if (constraints.maxWidth < 180 ||
            (constraints.hasBoundedHeight && constraints.maxHeight < 260)) {
          return Center(
            child: SizedBox(
              width: constraints.maxWidth.isFinite
                  ? constraints.maxWidth.clamp(0, 118).toDouble()
                  : 118,
              height: 14,
              child: const _Block(radius: 7),
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.all(22),
          child: widget.content == SelahLoadingContent.browse
              ? _browse(constraints.hasBoundedHeight)
              : widget.content == SelahLoadingContent.profile
              ? _profile(constraints.hasBoundedHeight)
              : _list(constraints.hasBoundedHeight),
        );
      },
    );
    final content = Semantics(
      label: 'Loading',
      child: FadeTransition(
        key: ValueKey('selah_loading_${widget.content.name}'),
        opacity: _opacity,
        child: shapes,
      ),
    );
    return widget.fullScreen
        ? ColoredBox(color: SelahColors.mist, child: content)
        : content;
  }

  Widget _browse(bool bounded) => Column(
    mainAxisSize: bounded ? MainAxisSize.max : MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (bounded)
        const Expanded(child: _Block(radius: 18))
      else
        const SizedBox(height: 360, child: _Block(radius: 18)),
      const SizedBox(height: 14),
      const FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: .55,
        child: SizedBox(height: 30, child: _Block(radius: 7)),
      ),
      const SizedBox(height: 14),
      Row(
        children: [
          for (final width in [80.0, 110.0, 80.0]) ...[
            SizedBox(width: width, height: 26, child: const _Block(radius: 12)),
            const SizedBox(width: 10),
          ],
        ],
      ),
      const SizedBox(height: 14),
      for (final fraction in [1.0, .85, .6]) ...[
        FractionallySizedBox(
          widthFactor: fraction,
          alignment: Alignment.centerLeft,
          child: const SizedBox(height: 14, child: _Block(radius: 7)),
        ),
        const SizedBox(height: 14),
      ],
      Text(
        widget.label!,
        textAlign: TextAlign.center,
        style: SelahText.subtext(size: 13, color: SelahColors.muted),
      ),
    ],
  );

  Widget _list(bool bounded) => Column(
    mainAxisSize: bounded ? MainAxisSize.max : MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const _LoadingRow(),
      const SizedBox(height: 14),
      const _LoadingRow(),
      const SizedBox(height: 14),
      if (bounded)
        const Expanded(child: _Block(radius: 14))
      else
        const SizedBox(height: 100, child: _Block(radius: 14)),
    ],
  );

  Widget _profile(bool bounded) => Column(
    mainAxisSize: bounded ? MainAxisSize.max : MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const _LoadingRow(),
      const SizedBox(height: 14),
      if (bounded)
        const Expanded(child: _Block(radius: 14))
      else
        const SizedBox(height: 220, child: _Block(radius: 14)),
    ],
  );
}

class _LoadingRow extends StatelessWidget {
  const _LoadingRow();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: SelahColors.surface,
      border: Border.all(color: SelahColors.line),
      borderRadius: BorderRadius.circular(14),
    ),
    child: const Row(
      children: [
        SizedBox(width: 56, height: 56, child: _Block(radius: 18)),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FractionallySizedBox(
                widthFactor: .55,
                alignment: Alignment.centerLeft,
                child: SizedBox(height: 14, child: _Block(radius: 7)),
              ),
              SizedBox(height: 10),
              FractionallySizedBox(
                widthFactor: .9,
                alignment: Alignment.centerLeft,
                child: SizedBox(height: 14, child: _Block(radius: 7)),
              ),
              SizedBox(height: 10),
              SizedBox(height: 5, child: _Block(radius: 3)),
            ],
          ),
        ),
      ],
    ),
  );
}

class _Block extends StatelessWidget {
  const _Block({required this.radius});
  final double radius;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: SelahColors.soft,
      borderRadius: BorderRadius.circular(radius),
    ),
    child: const SizedBox.expand(),
  );
}
