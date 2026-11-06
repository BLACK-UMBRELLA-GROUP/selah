import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/seeker_profile.dart';
import '../theme/selah_colors.dart';
import '../theme/selah_text.dart';
import 'floating_nav_bar.dart';
import 'selah_profile_image.dart';
import 'selah_shepherd_invite_views.dart';
import 'selah_state_widgets.dart';

/// LOCK 19 presentation. The existing owner supplies identities and actions.
class SelahShepherdIntroduceView extends StatelessWidget {
  const SelahShepherdIntroduceView({
    super.key,
    required this.seekers,
    required this.selectedSeekerId,
    required this.candidate,
    required this.onSeekerChanged,
    required this.onNext,
    required this.onSuggest,
    this.suggesting = false,
    this.failed = false,
  });

  final List<({String id, String name})> seekers;
  final String selectedSeekerId;
  final SeekerProfile? candidate;
  final ValueChanged<String> onSeekerChanged;
  final VoidCallback? onNext;
  final VoidCallback? onSuggest;
  final bool suggesting;
  final bool failed;

  Widget _seekerChoices() => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final person in seekers)
        Semantics(
          selected: person.id == selectedSeekerId,
          button: true,
          child: OutlinedButton(
            key: ValueKey('introduce_for_${person.id}'),
            onPressed: () => onSeekerChanged(person.id),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              backgroundColor: person.id == selectedSeekerId
                  ? SelahColors.inkColor
                  : Colors.transparent,
              foregroundColor: person.id == selectedSeekerId
                  ? Colors.white
                  : SelahColors.inkColor,
              side: BorderSide(
                color: person.id == selectedSeekerId
                    ? SelahColors.inkColor
                    : SelahColors.line,
              ),
              shape: const StadiumBorder(),
            ),
            child: Text(
              'For ${person.name}',
              style: SelahText.body(size: 13).copyWith(
                height: 1,
                fontWeight: FontWeight.w500,
                color: person.id == selectedSeekerId
                    ? Colors.white
                    : SelahColors.inkColor,
              ),
            ),
          ),
        ),
    ],
  );

  Widget _actions(String name) => LayoutBuilder(
    builder: (context, bounds) {
      // CSS flex:1 / flex:1.5 shares content width after the common 18px
      // horizontal padding and 1px borders. At 430px this is 158 / 218px.
      const buttonInsets = 18.0 * 2 + 2;
      final content = math.max(0.0, bounds.maxWidth - 10 - buttonInsets * 2);
      final ghostWidth = buttonInsets + content / 2.5;
      return Row(
        key: const ValueKey('introduce_actions'),
        children: [
          SizedBox(
            width: ghostWidth,
            child: SelahInviteButton(
              key: const ValueKey('introduce_next'),
              label: 'Not for $name',
              ghost: true,
              onPressed: onNext,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Opacity(
              opacity: suggesting ? .75 : 1,
              child: SelahInviteButton(
                key: const ValueKey('introduce_suggest'),
                label: suggesting ? 'Suggesting…' : 'Suggest to $name',
                onPressed: suggesting ? null : onSuggest,
              ),
            ),
          ),
        ],
      );
    },
  );

  Widget _empty(String name) => LayoutBuilder(
    builder: (context, bounds) => SingleChildScrollView(
      key: const ValueKey('introduce_scroll'),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: bounds.maxHeight),
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '’',
                  textAlign: TextAlign.center,
                  style: SelahText.heading(
                    size: 70,
                    color: SelahColors.dawn,
                  ).copyWith(height: .6),
                ),
                const SizedBox(height: 10),
                Text(
                  'No one new to suggest for $name',
                  key: const ValueKey('introduce_no_one_new'),
                  textAlign: TextAlign.center,
                  style: SelahText.rowTitle(),
                ),
                const SizedBox(height: 10),
                Text(
                  'New people join every week. Come back soon.',
                  textAlign: TextAlign.center,
                  style: SelahText.body(size: 13, color: SelahColors.muted),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final name = seekers
        .where((person) => person.id == selectedSeekerId)
        .firstOrNull
        ?.name;
    final profile = candidate;
    final reserve =
        math.max(
          MediaQuery.paddingOf(context).bottom,
          SelahNavBarMetrics.bottomInset,
        ) +
        SelahNavBarMetrics.height +
        16;
    return SafeArea(
      key: const ValueKey('introduce_page'),
      bottom: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(22, 6, 22, reserve),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: profile == null
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Introduce', style: SelahText.pageTitle()),
                        const SizedBox(height: 10),
                        _seekerChoices(),
                        Expanded(child: _empty(name ?? '')),
                      ],
                    )
                  : SingleChildScrollView(
                      key: const ValueKey('introduce_scroll'),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('Introduce', style: SelahText.pageTitle()),
                          const SizedBox(height: 10),
                          if (failed) ...[
                            SelahErrorBanner(
                              key: const ValueKey('introduce_failure'),
                              message:
                                  'Your suggestion didn’t send. Try again.',
                              retryKey: const ValueKey('introduce_retry'),
                              onRetry: onSuggest,
                            ),
                            const SizedBox(height: 14),
                          ],
                          Text(
                            'Know someone who might be right for one of your Seekers? Suggest them. Your Seeker decides - nothing is sent to the other person or their Shepherd.',
                            style: SelahText.body(color: SelahColors.muted),
                          ),
                          const SizedBox(height: 14),
                          _seekerChoices(),
                          const SizedBox(height: 14),
                          SelahIntroducePersonCard(profile: profile),
                        ],
                      ),
                    ),
            ),
            if (profile != null) ...[
              const SizedBox(height: 14),
              _actions(name ?? ''),
            ],
          ],
        ),
      ),
    );
  }
}

class SelahIntroducePersonCard extends StatelessWidget {
  const SelahIntroducePersonCard({super.key, required this.profile});
  final SeekerProfile profile;

  @override
  Widget build(BuildContext context) => Container(
    key: ValueKey('introduce_person_${profile.id}'),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: SelahColors.surface,
      border: Border.all(color: SelahColors.line),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: SelahProfileImage(profile.photoUrl, width: 78, height: 78),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${profile.firstName}, ${profile.age}',
                    style: SelahText.body(
                      size: 18,
                    ).copyWith(fontWeight: FontWeight.w600, height: 1.2),
                  ),
                  const SizedBox(height: 3),
                  Text(profile.city, style: SelahText.subtext()),
                ],
              ),
            ),
          ],
        ),
        if (profile.browseFaithChips.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final text in profile.browseFaithChips)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: SelahColors.soft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    text,
                    style: SelahText.body(size: 12.5).copyWith(height: 1),
                  ),
                ),
            ],
          ),
        ],
        if (profile.browseMarriageLine.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            profile.browseMarriageLine,
            style: SelahText.subtext().copyWith(height: 1.5),
          ),
        ],
        if ((profile.faithProfile?.words.trim() ?? '').isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            '“${profile.faithProfile!.words.trim()}”',
            style: SelahText.quote(),
          ),
        ],
      ],
    ),
  );
}

/// The Seeker acts on the same Introduction object supplied by its owner.
class SelahShepherdSuggestionCard extends StatelessWidget {
  const SelahShepherdSuggestionCard({
    super.key,
    required this.profile,
    required this.shepherdName,
    required this.onDismiss,
    required this.onSee,
  });
  final SeekerProfile profile;
  final String shepherdName;
  final VoidCallback onDismiss;
  final VoidCallback onSee;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text('FROM YOUR SHEPHERD', style: SelahText.chapterLabel()),
      const SizedBox(height: 14),
      Container(
        key: ValueKey('shepherd_suggestion_${profile.id}'),
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
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: SelahProfileImage(
                    profile.photoUrl,
                    width: 56,
                    height: 56,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${profile.firstName}, ${profile.age}',
                        style: SelahText.body(
                          size: 16,
                        ).copyWith(fontWeight: FontWeight.w600, height: 1.2),
                      ),
                      Text(
                        '$shepherdName thinks you might like to meet ${profile.firstName}.',
                        style: SelahText.subtext().copyWith(height: 1.2),
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
                    key: ValueKey('suggestion_dismiss_${profile.id}'),
                    label: 'Not now',
                    small: true,
                    ghost: true,
                    onPressed: onDismiss,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SelahInviteButton(
                    key: ValueKey('suggestion_see_${profile.id}'),
                    label: 'See ${profile.firstName}',
                    small: true,
                    onPressed: onSee,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ],
  );
}
