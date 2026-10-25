import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/selah_colors.dart';
import '../theme/selah_text.dart';
import '../widgets/selah_segmented_toggle.dart';

/// Session-only comparison placement, never a messaging or access preference.
enum SelahCircleTopicLayout {
  current('Current'),
  inChat('In chat'),
  beforeChat('Before chat'),
  both('Both');

  const SelahCircleTopicLayout(this.label);
  final String label;

  bool get hasEntry => this == beforeChat || this == both;
  bool get hasInChat => this == inChat || this == both;
}

enum SelahCircleTopicKind { general, current, past }

/// Detached visual metadata. An ID here is not a member, Journey, server
/// reference, history-consent record or permission to open another screen.
@immutable
class SelahCircleDiscussionTopic {
  const SelahCircleDiscussionTopic({
    required this.id,
    required this.firstName,
    required this.kind,
    this.endedOn,
  });

  static const general = SelahCircleDiscussionTopic(
    id: 'preview-circle-general',
    firstName: 'General conversation',
    kind: SelahCircleTopicKind.general,
  );

  final String id;
  final String firstName;
  final SelahCircleTopicKind kind;
  final DateTime? endedOn;

  bool get isGeneral => kind == SelahCircleTopicKind.general;
  bool get isPast => kind == SelahCircleTopicKind.past;
}

String _topicLabel(SelahCircleDiscussionTopic topic) => topic.isGeneral
    ? 'General conversation'
    : '${topic.isPast ? 'Past Journey' : 'Journey'} · ${topic.firstName}';

String _topicDate(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

bool _sameTopic(
  SelahCircleDiscussionTopic left,
  SelahCircleDiscussionTopic right,
) =>
    left.id == right.id &&
    left.firstName == right.firstName &&
    left.kind == right.kind &&
    left.endedOn == right.endedOn;

class SelahCircleTopicBar extends StatelessWidget {
  const SelahCircleTopicBar({super.key, required this.topic, this.onChoose});

  final SelahCircleDiscussionTopic topic;
  final VoidCallback? onChoose;

  @override
  Widget build(BuildContext context) => Semantics(
    button: onChoose != null,
    enabled: onChoose != null,
    child: Material(
      key: const ValueKey('circle_topic_bar'),
      color: SelahColors.journeyGold.withValues(alpha: .055),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onChoose,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: SelahColors.journeyGold.withValues(alpha: .23),
              width: .7,
            ),
          ),
          child: Row(
            children: [
              Icon(
                topic.isGeneral
                    ? Icons.forum_outlined
                    : topic.isPast
                    ? Icons.history_rounded
                    : Icons.route_outlined,
                color: SelahColors.journeyGold.withValues(alpha: .8),
                size: 18,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  topic.isGeneral ? 'Discuss a Journey' : _topicLabel(topic),
                  style: SelahText.body(size: 12.5),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.expand_more_rounded,
                color: SelahColors.foregroundMuted.withValues(
                  alpha: onChoose == null ? .5 : 1,
                ),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// A label only. Selecting a discussion topic never creates a Journey link.
class SelahCircleTopicTag extends StatelessWidget {
  const SelahCircleTopicTag({super.key, required this.topic});

  final SelahCircleDiscussionTopic topic;

  @override
  Widget build(BuildContext context) => Container(
    key: ValueKey('circle_topic_tag_${topic.id}'),
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: SelahColors.journeyGold.withValues(alpha: .065),
      borderRadius: BorderRadius.circular(11),
      border: Border.all(
        color: SelahColors.journeyGold.withValues(alpha: .20),
        width: .6,
      ),
    ),
    child: Text(
      _topicLabel(topic),
      style: SelahText.subtext(size: 11, color: SelahColors.journeyGold),
    ),
  );
}

/// A local discussion change in the same Circle transcript, not a service
/// message, Journey lifecycle event, read receipt or history permission.
class SelahCircleDiscussionBubble extends StatelessWidget {
  const SelahCircleDiscussionBubble({
    super.key,
    required this.topic,
    this.onViewProfile,
  });

  final SelahCircleDiscussionTopic topic;
  final VoidCallback? onViewProfile;

  @override
  Widget build(BuildContext context) => Container(
    key: ValueKey('circle_discussion_bubble_${topic.id}'),
    width: double.infinity,
    margin: const EdgeInsets.symmetric(vertical: 9),
    padding: const EdgeInsets.fromLTRB(12, 11, 12, 10),
    decoration: BoxDecoration(
      color: SelahColors.journeyGold.withValues(alpha: .055),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: SelahColors.journeyGold.withValues(alpha: .26),
        width: .7,
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          topic.isGeneral
              ? 'Back to general conversation'
              : topic.isPast
              ? 'Discussing a past Journey with ${topic.firstName}'
              : 'Discussing a Journey with ${topic.firstName}',
          style: SelahText.body(size: 12.5, color: SelahColors.journeyGold),
        ),
        if (onViewProfile != null)
          TextButton(
            key: ValueKey('circle_discussion_profile_${topic.id}'),
            onPressed: onViewProfile,
            style: TextButton.styleFrom(
              foregroundColor: SelahColors.journeyGold,
              minimumSize: const Size(0, 44),
              padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 6),
              alignment: Alignment.centerLeft,
            ),
            child: Text('View profile', style: SelahText.body(size: 12)),
          ),
      ],
    ),
  );
}

/// A bounded, caller-owned selector. It performs no navigation, API request,
/// persistence, membership change or lookup beyond the supplied local rows.
class SelahCircleTopicPicker extends StatefulWidget {
  const SelahCircleTopicPicker({
    super.key,
    required this.currentTopics,
    required this.pastTopics,
    required this.selected,
    required this.onSelected,
    required this.canSelect,
    this.embedded = false,
  });

  final List<SelahCircleDiscussionTopic> currentTopics;
  final List<SelahCircleDiscussionTopic> pastTopics;
  final SelahCircleDiscussionTopic selected;
  final ValueChanged<SelahCircleDiscussionTopic> onSelected;
  final bool Function() canSelect;
  final bool embedded;

  @override
  State<SelahCircleTopicPicker> createState() => _SelahCircleTopicPickerState();
}

class _SelahCircleTopicPickerState extends State<SelahCircleTopicPicker> {
  final _search = TextEditingController();
  late SelahCircleDiscussionTopic _selected;
  late int _tab;

  @override
  void initState() {
    super.initState();
    _selected = widget.selected;
    _tab = _selected.isPast ? 1 : 0;
  }

  @override
  void didUpdateWidget(covariant SelahCircleTopicPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameTopic(oldWidget.selected, widget.selected)) {
      _selected = widget.selected;
      _tab = _selected.isPast ? 1 : 0;
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _allowed() {
    if (!mounted) return false;
    try {
      return widget.canSelect();
    } catch (_) {
      return false;
    }
  }

  bool _includes(SelahCircleDiscussionTopic topic) => topic.isGeneral
      ? _sameTopic(topic, SelahCircleDiscussionTopic.general)
      : (topic.isPast ? widget.pastTopics : widget.currentTopics).any(
          (known) => _sameTopic(known, topic),
        );

  void _choose(SelahCircleDiscussionTopic topic) {
    if (!_allowed() || !_includes(topic)) return;
    setState(() => _selected = topic);
    widget.onSelected(topic);
  }

  bool _matches(SelahCircleDiscussionTopic topic, String query) {
    if (query.isEmpty || topic.firstName.toLowerCase().contains(query)) {
      return true;
    }
    final date = topic.endedOn;
    if (date == null) return false;
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return _topicDate(date).toLowerCase().contains(query) ||
        '${date.year}-$month-$day'.contains(query) ||
        '$day/$month/${date.year}'.contains(query);
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final topics = (_tab == 0 ? widget.currentTopics : widget.pastTopics)
        .where(
          (topic) =>
              topic.kind ==
                  (_tab == 0
                      ? SelahCircleTopicKind.current
                      : SelahCircleTopicKind.past) &&
              (_tab == 0 || _matches(topic, query)),
        )
        .toList(growable: false);
    final enabled = _allowed();
    final keyboard = widget.embedded
        ? 0.0
        : MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: keyboard),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final available = constraints.hasBoundedHeight
                ? constraints.maxHeight
                : MediaQuery.sizeOf(context).height -
                      MediaQuery.paddingOf(context).vertical -
                      keyboard;
            final height = math.max(
              0.0,
              widget.embedded
                  ? available
                  : math.min(
                      available,
                      MediaQuery.sizeOf(context).height * .78,
                    ),
            );
            return SizedBox(
              key: const ValueKey('circle_topic_picker'),
              height: height,
              child: Material(
                color: SelahColors.modalSheetSurface,
                borderRadius: widget.embedded
                    ? BorderRadius.zero
                    : const BorderRadius.vertical(top: Radius.circular(24)),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
                  child: CustomScrollView(
                    primary: false,
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    slivers: [
                      SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Discuss a Journey',
                              style: SelahText.heading(size: 21),
                            ),
                            const SizedBox(height: 14),
                            TweenAnimationBuilder<double>(
                              tween: Tween(end: _tab.toDouble()),
                              duration: MediaQuery.disableAnimationsOf(context)
                                  ? Duration.zero
                                  : SelahSegmentedMotion.selectionDuration,
                              curve: SelahSegmentedMotion.selectionCurve,
                              builder: (context, position, _) =>
                                  SelahSegmentedToggle(
                                    labels: const ['Current', 'Past'],
                                    labelSize: 13,
                                    position: position,
                                    segmentKeys: const [
                                      ValueKey('circle_topic_tab_0'),
                                      ValueKey('circle_topic_tab_1'),
                                    ],
                                    onChanged: (index) {
                                      if (!_allowed() ||
                                          index < 0 ||
                                          index > 1) {
                                        return;
                                      }
                                      setState(() => _tab = index);
                                    },
                                  ),
                            ),
                            const SizedBox(height: 12),
                            _row(SelahCircleDiscussionTopic.general, enabled),
                            if (_tab == 1) ...[
                              const SizedBox(height: 12),
                              TextField(
                                key: const ValueKey('circle_topic_search'),
                                controller: _search,
                                enabled: enabled,
                                textInputAction: TextInputAction.search,
                                onChanged: (_) {
                                  if (_allowed()) setState(() {});
                                },
                                style: SelahText.body(size: 13),
                                decoration: InputDecoration(
                                  hintText: 'Search past Journeys',
                                  hintStyle: SelahText.subtext(size: 13),
                                  prefixIcon: Icon(
                                    Icons.search_rounded,
                                    size: 20,
                                    color: SelahColors.foregroundMuted,
                                  ),
                                  filled: true,
                                  fillColor: SelahColors.surfaceFill,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 12,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(13),
                                    borderSide: BorderSide(
                                      color: SelahColors.surfaceBorder,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(13),
                                    borderSide: BorderSide(
                                      color: SelahColors.surfaceBorder,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(13),
                                    borderSide: BorderSide(
                                      color: SelahColors.journeyGold.withValues(
                                        alpha: .55,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                          ],
                        ),
                      ),
                      if (topics.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(
                            child: Text(
                              query.isNotEmpty && _tab == 1
                                  ? 'No matching Journeys'
                                  : _tab == 1
                                  ? 'No past Journeys'
                                  : 'No current Journeys',
                              style: SelahText.subtext(size: 13),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      else
                        SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (_, index) => index.isOdd
                                ? const SizedBox(height: 8)
                                : _row(topics[index ~/ 2], enabled),
                            childCount: topics.length * 2 - 1,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _row(SelahCircleDiscussionTopic topic, bool enabled) {
    final selected = _sameTopic(_selected, topic);
    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      child: Material(
        key: ValueKey(
          topic.isGeneral ? 'circle_topic_general' : 'circle_topic_${topic.id}',
        ),
        color: selected
            ? SelahColors.journeyGold.withValues(alpha: .075)
            : SelahColors.surfaceFill,
        borderRadius: BorderRadius.circular(13),
        child: InkWell(
          onTap: enabled ? () => _choose(topic) : null,
          borderRadius: BorderRadius.circular(13),
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: selected
                    ? SelahColors.journeyGold.withValues(alpha: .44)
                    : SelahColors.surfaceBorder,
                width: .7,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(topic.firstName, style: SelahText.body(size: 13)),
                      if (topic.isPast && topic.endedOn != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          _topicDate(topic.endedOn!),
                          style: SelahText.subtext(size: 11),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Icon(
                  selected
                      ? Icons.check_circle_outline_rounded
                      : Icons.circle_outlined,
                  color: selected
                      ? SelahColors.journeyGold
                      : SelahColors.foregroundMuted.withValues(alpha: .4),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
