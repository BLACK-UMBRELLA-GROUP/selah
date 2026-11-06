import 'package:flutter/widgets.dart';

import '../models/selah_shepherd_invite.dart';

/// Optional session owner for new invite surfaces. Older isolated fixtures may
/// omit it; the scope never creates an owner or grants local preview authority.
class SelahShepherdInviteScope
    extends InheritedNotifier<SelahShepherdInviteController> {
  const SelahShepherdInviteScope({
    super.key,
    required SelahShepherdInviteController controller,
    required super.child,
  }) : super(notifier: controller);

  static SelahShepherdInviteController? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<SelahShepherdInviteScope>()
      ?.notifier;
}
