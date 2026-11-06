// LOCK 3: local Shepherd invitation presentation. No sending or account authority.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/selah_colors.dart';
import '../theme/selah_text.dart';

class SelahInviteButton extends StatelessWidget {
  const SelahInviteButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.ghost = false,
    this.small = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool ghost;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final style = ButtonStyle(
      minimumSize: WidgetStatePropertyAll(Size(0, small ? 35.5 : 47)),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: WidgetStatePropertyAll(
        EdgeInsets.symmetric(
          horizontal: small ? 14 : 18,
          vertical: small ? 10 : 15,
        ),
      ),
      backgroundColor: WidgetStatePropertyAll(
        ghost ? Colors.transparent : SelahColors.lake,
      ),
      foregroundColor: WidgetStatePropertyAll(
        ghost ? SelahColors.inkColor : SelahColors.onLake,
      ),
      side: WidgetStatePropertyAll(
        BorderSide(color: ghost ? SelahColors.line : SelahColors.lake),
      ),
      shape: const WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
      textStyle: WidgetStatePropertyAll(
        SelahText.button(size: small ? 13.5 : 15).copyWith(height: 1),
      ),
      elevation: const WidgetStatePropertyAll(0),
    );
    return ghost
        ? OutlinedButton(onPressed: onPressed, style: style, child: Text(label))
        : FilledButton(onPressed: onPressed, style: style, child: Text(label));
  }
}

class SelahInviteBackRow extends StatelessWidget {
  const SelahInviteBackRow({super.key, required this.onBack, this.stepLabel});
  final VoidCallback onBack;
  final String? stepLabel;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      TextButton(
        key: const ValueKey('invite_back'),
        onPressed: onBack,
        style: TextButton.styleFrom(
          foregroundColor: SelahColors.lake,
          padding: const EdgeInsets.symmetric(vertical: 6),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          alignment: Alignment.centerLeft,
        ),
        child: Text(
          '‹ Back',
          style: SelahText.button(size: 15, color: SelahColors.lake),
        ),
      ),
      if (stepLabel != null) ...[
        const Spacer(),
        Text(stepLabel!, style: SelahText.subtext()),
      ],
    ],
  );
}

/// Fill the available page, with scrolling only when its real content needs it.
class SelahInviteFillScroll extends StatelessWidget {
  const SelahInviteFillScroll({
    super.key,
    required this.child,
    required this.padding,
  });
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) => SingleChildScrollView(
      child: Padding(
        padding: padding,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: math.max(0, bounds.maxHeight - padding.vertical),
          ),
          child: IntrinsicHeight(child: child),
        ),
      ),
    ),
  );
}

class SelahShepherdPermissionsCard extends StatelessWidget {
  const SelahShepherdPermissionsCard({
    super.key,
    required this.title,
    this.seekerGender,
  });
  final String title;
  // Null is the Seeker-side disclosure; non-null is the Shepherd's invitation.
  final String? seekerGender;

  @override
  Widget build(BuildContext context) {
    final her = seekerGender?.toLowerCase() == 'female';
    final possessive = her ? 'her' : 'his';
    final object = her ? 'her' : 'him';
    final subject = her ? 'she' : 'he';
    final rows = seekerGender == null
        ? const [
            'Every request you send or receive',
            'Which stage each Journey is at',
            'Prayer requests you share',
            'Your private messages',
          ]
        : [
            'Walk with $object toward marriage',
            'See every request $subject sends or receives',
            'See which stage each Journey is at',
            'Receive the prayer requests $subject shares',
            'You won’t see $possessive private messages',
          ];
    return Container(
      key: const ValueKey('invite_permissions'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SelahColors.surface,
        border: Border.all(color: SelahColors.line),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: SelahText.chapterLabel().copyWith(height: 1),
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ExcludeSemantics(
                    child: SizedBox(
                      width: 20,
                      child: Icon(
                        i == rows.length - 1 ? Icons.close : Icons.check,
                        size: 16,
                        color: i == rows.length - 1
                            ? SelahColors.dawn
                            : SelahColors.lake,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      rows[i],
                      style: SelahText.body(size: 14.5).copyWith(height: 1.2),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

String _firstName(String fullName) =>
    fullName.trim().split(RegExp(r'\s+')).first;
String _initial(String fullName) =>
    fullName.trim().isEmpty ? '' : fullName.trim().characters.first;

class SelahShepherdWaitingBanner extends StatelessWidget {
  const SelahShepherdWaitingBanner({super.key, required this.firstName});
  final String firstName;

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('invite_waiting_banner'),
    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
    decoration: BoxDecoration(
      color: SelahColors.soft,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        SizedBox(
          width: 30,
          height: 30,
          child: Center(
            child: Text(
              _initial(firstName),
              style: SelahText.button(size: 12, color: SelahColors.lake),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Waiting for $firstName to accept. You can request a Journey once they say yes.',
            style: SelahText.body(size: 13.5).copyWith(height: 1.2),
          ),
        ),
      ],
    ),
  );
}

class SelahShepherdPendingView extends StatelessWidget {
  const SelahShepherdPendingView({
    super.key,
    required this.fullName,
    required this.onRemind,
    required this.onCopy,
    this.bottomPadding = 95,
  });
  final String fullName;
  final VoidCallback onRemind;
  final VoidCallback onCopy;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    final first = _firstName(fullName);
    return SafeArea(
      bottom: false,
      child: SelahInviteFillScroll(
        padding: EdgeInsets.fromLTRB(22, 8, 22, bottomPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('My Shepherd', style: SelahText.pageTitle()),
            const SizedBox(height: 14),
            Container(
              key: const ValueKey('invite_pending_card'),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: SelahColors.surface,
                border: Border.all(color: SelahColors.line),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: SelahColors.soft,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          _initial(fullName),
                          style: SelahText.button(
                            size: 24,
                            color: SelahColors.lake,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(fullName, style: SelahText.option(size: 18)),
                            Text(
                              'Invite sent · waiting for a yes',
                              style: SelahText.subtext(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: SelahInviteButton(
                          key: const ValueKey('invite_remind'),
                          label: 'Remind $first',
                          onPressed: onRemind,
                          ghost: true,
                          small: true,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SelahInviteButton(
                          key: const ValueKey('invite_copy_again'),
                          label: 'Copy link again',
                          onPressed: onCopy,
                          ghost: true,
                          small: true,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Preserve the master spacing around its hidden private demo row.
            const SizedBox(height: 60),
            Expanded(
              child: SelahShepherdPermissionsCard(
                title: 'Once $first says yes, they will see',
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'A Shepherd is needed in Selah. Until $first accepts, you can’t send or accept a request.',
              style: SelahText.subtext().copyWith(height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

/// The body for a Shepherd reviewing a Seeker's request. Its owner keeps the
/// existing shell navigation and chooses the destination of accept/decline.
class SelahShepherdRequestReview extends StatelessWidget {
  const SelahShepherdRequestReview({
    super.key,
    required this.seekerName,
    required this.seekerAge,
    required this.seekerGender,
    required this.seekerPhoto,
    required this.relationship,
    required this.onAccept,
    required this.onDecline,
    this.onBack,
    this.bottomPadding = 95,
  });
  final String seekerName;
  final int seekerAge;
  final String seekerGender;
  final Widget seekerPhoto;
  final String relationship;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final VoidCallback? onBack;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    final possessive = seekerGender.toLowerCase() == 'female' ? 'her' : 'his';
    return SafeArea(
      bottom: false,
      child: SelahInviteFillScroll(
        padding: EdgeInsets.fromLTRB(22, 6, 22, bottomPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SelahInviteBackRow(
              onBack:
                  onBack ??
                  () {
                    Navigator.of(context).maybePop();
                  },
            ),
            const SizedBox(height: 12),
            Text('Be $seekerName’s Shepherd?', style: SelahText.pageTitle()),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: SelahColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: SelahColors.line),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: SizedBox(width: 78, height: 78, child: seekerPhoto),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$seekerName, $seekerAge',
                          style: SelahText.option(size: 18),
                        ),
                        Text(
                          'Asked you as $possessive ${relationship.toLowerCase()}',
                          style: SelahText.subtext(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SelahShepherdPermissionsCard(
              title: 'As $possessive Shepherd you will',
              seekerGender: seekerGender,
            ),
            const SizedBox(height: 14),
            Text(
              'You don’t need a profile of your own or be looking for marriage. You can step back at any time.',
              style: SelahText.subtext().copyWith(height: 1.5),
            ),
            const SizedBox(height: 14),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: SelahInviteButton(
                    key: const ValueKey('invite_review_decline'),
                    label: 'Not now',
                    onPressed: onDecline,
                    ghost: true,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: SelahInviteButton(
                    key: const ValueKey('invite_review_accept'),
                    label: 'Accept',
                    onPressed: onAccept,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
