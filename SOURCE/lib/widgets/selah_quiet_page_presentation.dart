import 'package:flutter/material.dart';

import '../theme/selah_colors.dart';
import '../theme/selah_text.dart';
import 'selah_shepherd_invite_views.dart';

/// The one three-block presentation shared by LOCK7/13 and LOCK15.
/// Actions, progress and authority remain with each actual screen owner.
class SelahQuietPagePresentation extends StatelessWidget {
  const SelahQuietPagePresentation({
    super.key,
    required this.header,
    required this.label,
    required this.heading,
    required this.body,
    required this.afterBody,
    required this.actions,
    this.failure,
    this.headingKey,
    this.bodyKey,
  });

  final Widget header;
  final String label;
  final String heading;
  final String body;
  final List<Widget> afterBody;
  final List<Widget> actions;
  final Widget? failure;
  final Key? headingKey;
  final Key? bodyKey;

  @override
  Widget build(BuildContext context) => SafeArea(
    bottom: false,
    child: ColoredBox(
      color: SelahColors.soft,
      child: SelahInviteFillScroll(
        padding: const EdgeInsets.fromLTRB(26, 20, 26, 26),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header,
            if (failure != null) ...[const SizedBox(height: 8), failure!],
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
              label.toUpperCase(),
              style: SelahText.chapterLabel().copyWith(height: 1),
            ),
            const SizedBox(height: 14),
            Text(
              heading,
              key: headingKey,
              style: SelahText.heading(size: 48).copyWith(height: 1.05),
            ),
            const SizedBox(height: 14),
            Text(body, key: bodyKey, style: SelahText.body()),
            const SizedBox(height: 14),
            ...afterBody,
            const Spacer(),
            ...actions,
          ],
        ),
      ),
    ),
  );
}
