import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

/// A small visual acknowledgement only. The original child's gestures,
/// semantics, permissions and callbacks retain their authority.
class SelahPressFeedback extends StatefulWidget {
  const SelahPressFeedback({
    super.key,
    required this.child,
    this.enabled = true,
  });

  final Widget child;
  final bool enabled;

  @override
  State<SelahPressFeedback> createState() => _SelahPressFeedbackState();
}

class _SelahPressFeedbackState extends State<SelahPressFeedback> {
  final _pointers = <int>{};
  final _childKey = GlobalKey();
  bool _quiet = false;

  bool get _canAnimate => widget.enabled && !_quiet;
  bool get _pressed => _canAnimate && _pointers.isNotEmpty;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _quiet =
        MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context);
    if (_quiet) _pointers.clear();
  }

  @override
  void didUpdateWidget(covariant SelahPressFeedback oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled) _pointers.clear();
  }

  void _down(PointerDownEvent event) {
    if (!mounted || !_canAnimate || event.buttons != kPrimaryButton) return;
    if (_pointers.add(event.pointer)) setState(() {});
  }

  void _release(int pointer) {
    if (!mounted || !_pointers.remove(pointer)) return;
    setState(() {});
  }

  @override
  void dispose() {
    _pointers.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Listener(
    // Listening never adds a competing gesture recognizer or a tap action.
    behavior: HitTestBehavior.deferToChild,
    onPointerDown: _down,
    onPointerUp: (event) => _release(event.pointer),
    onPointerCancel: (event) => _release(event.pointer),
    child: AnimatedScale(
      // Duration.zero alone does not stop an unchanged release tween. Reset
      // only the visual controller when quiet mode changes; the keyed child
      // retains its own gesture/state/semantics through that replacement.
      key: ValueKey(_canAnimate),
      scale: _pressed ? .985 : 1,
      duration: !_canAnimate
          ? Duration.zero
          : _pressed
          ? const Duration(milliseconds: 90)
          : const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      child: KeyedSubtree(key: _childKey, child: widget.child),
    ),
  );
}
