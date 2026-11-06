import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/selah_prayer.dart';
import '../models/selah_prayer_controller.dart';
import '../theme/selah_colors.dart';
import '../theme/selah_text.dart';
import 'floating_nav_bar.dart';
import 'selah_profile_questions.dart';
import 'selah_shepherd_invite_views.dart';
import 'selah_state_widgets.dart';

/// LOCK 10 content hosted by the existing Seeker shell and its real dock.
class SelahPrayerComposer extends StatefulWidget {
  const SelahPrayerComposer({
    super.key,
    required this.controller,
    required this.onSent,
    required this.onBack,
  });

  final SelahPrayerController controller;
  final VoidCallback onSent;
  final VoidCallback onBack;

  @override
  State<SelahPrayerComposer> createState() => _SelahPrayerComposerState();
}

class _SelahPrayerComposerState extends State<SelahPrayerComposer> {
  late final TextEditingController _words;

  @override
  void initState() {
    super.initState();
    _words = TextEditingController(text: widget.controller.ownText);
    widget.controller.addListener(_changed);
  }

  @override
  void didUpdateWidget(covariant SelahPrayerComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.controller, widget.controller)) return;
    oldWidget.controller.removeListener(_changed);
    widget.controller.addListener(_changed);
    _words.text = widget.controller.ownText;
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void _send() {
    FocusManager.instance.primaryFocus?.unfocus();
    final controller = widget.controller;
    if (controller.send() &&
        mounted &&
        identical(controller, widget.controller) &&
        controller.current) {
      widget.onSent();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    _words.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final sending = controller.sendState == SelahPrayerSendState.sending;
    final failed = controller.sendState == SelahPrayerSendState.failed;
    final shepherd = controller.context?.shepherdName ?? '';
    final reserve =
        math.max(
          MediaQuery.paddingOf(context).bottom,
          SelahNavBarMetrics.bottomInset,
        ) +
        SelahNavBarMetrics.height +
        16;
    return SafeArea(
      key: const ValueKey('prayer_page'),
      bottom: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(22, 6, 22, reserve),
        child: LayoutBuilder(
          builder: (context, bounds) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: bounds.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        key: const ValueKey('prayer_back'),
                        onPressed: widget.onBack,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          '‹ Back',
                          style: SelahText.button(color: SelahColors.lake),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text('Ask for prayer', style: SelahText.pageTitle()),
                    const SizedBox(height: 14),
                    if (failed) ...[
                      SelahErrorBanner(
                        key: const ValueKey('prayer_failure'),
                        message: 'Your prayer request didn’t send. Try again.',
                        retryKey: const ValueKey('prayer_retry'),
                        onRetry: _send,
                      ),
                      const SizedBox(height: 14),
                    ],
                    Text(
                      '$shepherd will see this and pray for you.',
                      style: SelahText.body(color: SelahColors.muted),
                    ),
                    const SizedBox(height: 14),
                    for (var i = 0; i < controller.suggestions.length; i++) ...[
                      if (i > 0) const SizedBox(height: 14),
                      SelahProfileQuestionChoice(
                        key: ValueKey('prayer_choice_$i'),
                        label: controller.suggestions[i],
                        selected: controller.selectedSuggestion == i,
                        onTap: () => controller.chooseSuggestion(i),
                      ),
                    ],
                    const SizedBox(height: 14),
                    Expanded(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 120),
                        child: TextField(
                          key: const ValueKey('prayer_words'),
                          controller: _words,
                          enabled: !sending,
                          onChanged: controller.setOwnText,
                          expands: true,
                          minLines: null,
                          maxLines: null,
                          textAlignVertical: TextAlignVertical.top,
                          style: SelahText.body(),
                          decoration: InputDecoration(
                            hintText: 'Or write your own',
                            hintStyle: SelahText.body(color: SelahColors.muted),
                            filled: true,
                            fillColor: SelahColors.surface,
                            contentPadding: const EdgeInsets.all(12),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: SelahColors.line,
                              ),
                            ),
                            disabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: SelahColors.line,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: SelahColors.lake,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Opacity(
                      opacity: sending ? .75 : 1,
                      child: SelahInviteButton(
                        key: const ValueKey('prayer_send'),
                        label: sending ? 'Sending…' : 'Send to $shepherd',
                        onPressed: sending ? null : _send,
                      ),
                    ),
                    if (sending) const SizedBox(height: 42),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SelahPrayerRequestsBlock extends StatelessWidget {
  const SelahPrayerRequestsBlock({
    super.key,
    required this.requests,
    required this.shepherdId,
    required this.onPray,
    required this.linkedSeekerNames,
  });

  final List<SelahPrayerRequest> requests;
  final String shepherdId;
  final ValueChanged<String> onPray;
  final List<String> linkedSeekerNames;

  String get _names => linkedSeekerNames.join(' or ');

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text('PRAYER REQUESTS', style: SelahText.chapterLabel()),
      const SizedBox(height: 14),
      Container(
        key: const ValueKey('prayer_requests'),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: SelahColors.surface,
          border: Border.all(color: SelahColors.line),
          borderRadius: BorderRadius.circular(14),
        ),
        child: requests.isEmpty
            ? Text(
                'No prayer requests right now. When $_names ask you to pray, they’ll show here.',
                key: const ValueKey('prayer_requests_empty'),
                style: SelahText.body(size: 13.5, color: SelahColors.muted),
              )
            : Column(
                children: [
                  for (var i = 0; i < requests.length; i++) ...[
                    if (i > 0) ...[
                      const SizedBox(height: 14),
                      const Divider(height: 1, color: SelahColors.line),
                      const SizedBox(height: 14),
                    ],
                    _request(requests[i]),
                  ],
                ],
              ),
      ),
      const SizedBox(height: 14),
      Text(
        'Seekers you walk with can ask you for prayer. They see when you have prayed.',
        style: SelahText.body(size: 13.5, color: SelahColors.muted),
      ),
    ],
  );

  Widget _request(SelahPrayerRequest request) {
    final prayed = request.hasPrayed(shepherdId);
    return Row(
      key: ValueKey('prayer_request_${request.id}'),
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(request.seekerFirstName, style: SelahText.rowTitle()),
              const SizedBox(height: 4),
              Text(
                request.text,
                style: SelahText.body(size: 13.5, color: SelahColors.muted),
              ),
              const SizedBox(height: 4),
              Text('${request.prayedCount} prayed', style: SelahText.subtext()),
            ],
          ),
        ),
        const SizedBox(width: 12),
        SelahInviteButton(
          key: ValueKey('prayer_pray_${request.id}'),
          label: prayed ? 'Prayed' : 'I prayed',
          ghost: prayed,
          small: true,
          onPressed: prayed ? null : () => onPray(request.id),
        ),
      ],
    );
  }
}
