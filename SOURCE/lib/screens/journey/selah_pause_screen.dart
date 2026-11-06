import 'package:flutter/material.dart';

import '../../models/selah_action_pause_controller.dart';
import '../../services/selah_developer_access.dart';
import '../../theme/selah_colors.dart';
import '../../theme/selah_text.dart';
import '../../widgets/selah_shepherd_invite_views.dart';
import '../../widgets/selah_state_widgets.dart';

/// One full-screen LOCK 7/13 pause for all four existing Journey actions.
class SelahPauseScreen extends StatefulWidget {
  const SelahPauseScreen({
    super.key,
    required this.controller,
    required this.onCancel,
    required this.onDone,
    this.developerControls,
  });

  final SelahActionPauseController controller;
  final VoidCallback onCancel;
  final VoidCallback onDone;
  final Widget? developerControls;

  @override
  State<SelahPauseScreen> createState() => _SelahPauseScreenState();
}

class _SelahPauseScreenState extends State<SelahPauseScreen>
    with SingleTickerProviderStateMixin {
  late final _breath = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  );
  bool? _reduceMotion;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.disableAnimationsOf(context);
    if (reduce == _reduceMotion) return;
    _reduceMotion = reduce;
    if (reduce) {
      _breath.value = 1;
    } else {
      _breath.forward(from: 0);
    }
  }

  @override
  void didUpdateWidget(covariant SelahPauseScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    oldWidget.controller.removeListener(_changed);
    widget.controller.addListener(_changed);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _confirm() async {
    final controller = widget.controller;
    final done = await controller.confirm();
    if (!mounted || !identical(controller, widget.controller) || !done) return;
    widget.onDone();
  }

  void _cancel() {
    if (widget.controller.cancel()) widget.onCancel();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    _breath.dispose();
    super.dispose();
  }

  Widget _primary(bool working) {
    final pause = widget.controller.pause;
    final label = working ? pause.workingLabel : pause.primaryLabel;
    final onPressed = working ? null : _confirm;
    return Opacity(
      opacity: working ? .75 : 1,
      child: pause.destructive
          ? OutlinedButton(
              key: const ValueKey('pause_confirm'),
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 47),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: const EdgeInsets.symmetric(
                  vertical: 15,
                  horizontal: 18,
                ),
                foregroundColor: SelahColors.dawn,
                disabledForegroundColor: SelahColors.dawn,
                backgroundColor: Colors.transparent,
                disabledBackgroundColor: Colors.transparent,
                side: const BorderSide(color: SelahColors.dawn),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: SelahText.button().copyWith(height: 1),
              ),
              child: Text(label),
            )
          : SelahInviteButton(
              key: const ValueKey('pause_confirm'),
              label: label,
              onPressed: onPressed,
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final pause = controller.pause;
    final working = controller.state == SelahActionPauseState.working;
    final failed = controller.state == SelahActionPauseState.failed;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cancel();
      },
      child: Scaffold(
        key: ValueKey('pause_${pause.kind.name}'),
        backgroundColor: SelahColors.soft,
        body: Stack(
          fit: StackFit.expand,
          children: [
            SafeArea(
              bottom: false,
              child: SelahInviteFillScroll(
                padding: const EdgeInsets.fromLTRB(26, 20, 26, 26),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        key: const ValueKey('pause_back'),
                        onPressed: _cancel,
                        style: TextButton.styleFrom(
                          foregroundColor: SelahColors.lake,
                          minimumSize: Size.zero,
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          '‹ Back',
                          style: SelahText.button(color: SelahColors.lake),
                        ),
                      ),
                    ),
                    if (failed) ...[
                      const SizedBox(height: 8),
                      SelahErrorBanner(
                        key: const ValueKey('pause_failure'),
                        message: pause.failureMessage,
                        retryKey: const ValueKey('pause_retry'),
                        onRetry: _confirm,
                      ),
                    ],
                    const SizedBox(height: 30),
                    Text(
                      '’',
                      style: SelahText.heading(
                        size: 120,
                        color: SelahColors.dawn,
                      ).copyWith(height: .6),
                    ),
                    const Spacer(),
                    Text(
                      'SELAH',
                      style: SelahText.chapterLabel().copyWith(height: 1),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      pause.heading,
                      style: SelahText.heading(size: 48).copyWith(height: 1.05),
                    ),
                    const SizedBox(height: 14),
                    Text(pause.body, style: SelahText.body()),
                    const SizedBox(height: 14),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: SizedBox(
                        height: 4,
                        child: ColoredBox(
                          color: SelahColors.line,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: AnimatedBuilder(
                              animation: _breath,
                              builder: (context, _) => FractionallySizedBox(
                                key: const ValueKey('pause_breath'),
                                widthFactor: Curves.easeInOut.transform(
                                  _breath.value,
                                ),
                                child: const SizedBox(
                                  height: 4,
                                  child: ColoredBox(color: SelahColors.lake),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Take a breath. Pray if you wish.',
                      style: SelahText.body(size: 13, color: SelahColors.muted),
                    ),
                    const Spacer(),
                    _primary(working),
                    if (working)
                      // Preserve the locked private demo-row geometry without
                      // presenting a member-facing completion control.
                      const SizedBox(height: 42),
                    const SizedBox(height: 10),
                    SelahInviteButton(
                      key: const ValueKey('pause_not_yet'),
                      label: 'Not yet',
                      ghost: true,
                      onPressed: _cancel,
                    ),
                  ],
                ),
              ),
            ),
            if (widget.developerControls != null &&
                SelahDeveloperAccess.canUseDeveloperTools)
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                width: 36,
                child: widget.developerControls!,
              ),
          ],
        ),
      ),
    );
  }
}
