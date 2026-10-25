import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../theme/selah_interaction_style.dart';

/// Public app invitation. This deliberately does not include the member's
/// personal SELAH Code: that code links Seeker and Shepherd accounts and must
/// never be mistaken for a general referral code.
class SelahAppInvite {
  SelahAppInvite._();

  static const website = 'https://selah.invalid';

  static Future<void> share(BuildContext context) async {
    final box = context.findRenderObject() as RenderBox?;
    final origin = box == null
        ? null
        : box.localToGlobal(Offset.zero) & box.size;

    await SelahInteractionStyle.emitSelectionHaptic();
    await SharePlus.instance.share(
      ShareParams(
        subject: 'Discover SELAH',
        text:
            'Discover SELAH — a marriage Journey built for Seekers and '
            'Shepherds.\n\n$website',
        sharePositionOrigin: origin,
      ),
    );
  }
}
