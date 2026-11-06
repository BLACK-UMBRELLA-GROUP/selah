// LOCK 22 / Q15. Shared Family Compatibility presentation; answers and Send
// remain with the caller's existing Journey owner and transient controller.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/journey_questions.dart';
import '../data/selah_journey_stages.dart';
import '../models/selah_family_stage_controller.dart';
import '../theme/selah_colors.dart';
import '../theme/selah_text.dart';
import 'floating_nav_bar.dart';
import 'selah_shepherd_invite_views.dart';
import 'selah_state_widgets.dart';

class SelahFamilyCompatibilityView extends StatefulWidget {
  const SelahFamilyCompatibilityView({
    super.key,
    required this.controller,
    required this.counterpartFirstName,
    required this.canAct,
    required this.onBack,
    this.ownMainShepherdName,
    this.otherMainShepherdName,
    this.bottomInset,
  });

  final SelahFamilyStageController controller;
  final String counterpartFirstName;
  final bool Function() canAct;
  final VoidCallback onBack;
  final String? ownMainShepherdName;
  final String? otherMainShepherdName;
  // Retained hosts may already bound their content above the real dock.
  final double? bottomInset;

  @override
  State<SelahFamilyCompatibilityView> createState() =>
      _SelahFamilyCompatibilityViewState();
}

class _SelahFamilyCompatibilityViewState
    extends State<SelahFamilyCompatibilityView> {
  final _words = <String, TextEditingController>{};
  int _render = 0;

  @override
  void initState() {
    super.initState();
    _syncWords();
    widget.controller.addListener(_changed);
  }

  @override
  void didUpdateWidget(SelahFamilyCompatibilityView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller.removeListener(_changed);
      widget.controller.addListener(_changed);
    }
    _syncWords();
  }

  void _syncWords() {
    final answers = widget.controller.answers;
    for (final question in JourneyQuestions.family) {
      final text = answers.answerFor(question.id);
      final editor = _words.putIfAbsent(
        question.id,
        () => TextEditingController(text: text),
      );
      if (editor.text != text) {
        editor.value = TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
        );
      }
    }
  }

  void _changed() {
    if (!mounted) return;
    _syncWords();
    setState(() {});
  }

  @override
  void dispose() {
    _render++;
    widget.controller.removeListener(_changed);
    for (final editor in _words.values) {
      editor.dispose();
    }
    super.dispose();
  }

  bool _allows(SelahFamilyCompatibilityView binding, int render) {
    if (!mounted ||
        _render != render ||
        !identical(binding, widget) ||
        !binding.controller.current) {
      return false;
    }
    try {
      return binding.canAct() && binding.controller.current;
    } catch (_) {
      return false;
    }
  }

  Widget _card({required Widget child, Key? key}) => Container(
    key: key,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: SelahColors.surface,
      border: Border.all(color: SelahColors.line),
      borderRadius: BorderRadius.circular(14),
    ),
    child: child,
  );

  @override
  Widget build(BuildContext context) {
    final binding = widget;
    final controller = binding.controller;
    final render = ++_render;
    bool current() => _allows(binding, render);
    if (!controller.current) return const SizedBox.shrink();
    final sending = controller.sendState == SelahFamilySendState.sending;
    final failed = controller.sendState == SelahFamilySendState.failed;
    final sent = controller.sent;
    final bothSent = controller.bothSent;
    final familyStage = SelahJourneyStages.of('family_stage')!;
    final enabled = !sending && !sent && current();
    final name = binding.counterpartFirstName;
    final own = binding.ownMainShepherdName?.trim() ?? '';
    final other = binding.otherMainShepherdName?.trim() ?? '';
    final otherLabel = other.isEmpty ? '$name’s Shepherd' : other;
    final ownLabel = own.isEmpty ? 'your Shepherd' : own;
    final label = other.isEmpty
        ? '$name’s Shepherd asks you'
        : '$other, $name’s Shepherd, asks you';
    final questions = JourneyQuestions.familyFor(name);
    final reserve =
        binding.bottomInset ??
        math.max(
              MediaQuery.paddingOf(context).bottom,
              SelahNavBarMetrics.bottomInset,
            ) +
            SelahNavBarMetrics.height +
            16;

    Future<void> send() async {
      if (!current() || !controller.canSend) return;
      FocusManager.instance.primaryFocus?.unfocus();
      await controller.send();
    }

    OutlineInputBorder border(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: color),
    );

    return SafeArea(
      key: const ValueKey('family_page'),
      bottom: false,
      child: ListView(
        key: const ValueKey('family_scroll'),
        padding: EdgeInsets.fromLTRB(22, 6, 22, reserve),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: const ValueKey('family_back'),
              onPressed: () {
                if (current()) binding.onBack();
              },
              style: TextButton.styleFrom(
                foregroundColor: SelahColors.lake,
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
          const SizedBox(height: 12),
          Text('Family Compatibility', style: SelahText.pageTitle()),
          const SizedBox(height: 6),
          Text(
            'Now your families enter the conversation.',
            style: SelahText.body(color: SelahColors.muted),
          ),
          const SizedBox(height: 12),
          Text(
            label.toUpperCase(),
            key: const ValueKey('family_shepherd_label'),
            style: SelahText.chapterLabel().copyWith(height: 1),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < questions.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            _card(
              key: ValueKey('family_question_${questions[i].id}'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    questions[i].text,
                    style: SelahText.option().copyWith(
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (sent)
                    Text(
                      controller.answers.answerFor(questions[i].id).trim(),
                      key: ValueKey('family_sent_answer_${questions[i].id}'),
                      style: SelahText.subtext().copyWith(height: 1.2),
                    )
                  else ...[
                    SizedBox(
                      height: 90,
                      child: TextField(
                        key: ValueKey('family_answer_${questions[i].id}'),
                        controller: _words[questions[i].id],
                        enabled: enabled,
                        expands: true,
                        minLines: null,
                        maxLines: null,
                        textAlignVertical: TextAlignVertical.top,
                        style: SelahText.body().copyWith(height: 1.45),
                        inputFormatters: [_familyLimit],
                        onChanged: (text) {
                          if (current()) {
                            controller.setAnswer(questions[i].id, text);
                          }
                        },
                        decoration: InputDecoration(
                          hintText: 'Your answer',
                          hintStyle: SelahText.body(
                            color: SelahColors.muted,
                          ).copyWith(height: 1.45),
                          filled: true,
                          fillColor: SelahColors.surface,
                          contentPadding: const EdgeInsets.all(12),
                          enabledBorder: border(SelahColors.line),
                          disabledBorder: border(SelahColors.line),
                          focusedBorder: border(SelahColors.lake),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${controller.characterCount(questions[i].id)} of ${JourneyQuestions.familyAnswerCharacterLimit}',
                      key: ValueKey('family_counter_${questions[i].id}'),
                      textAlign: TextAlign.right,
                      style: SelahText.subtext().copyWith(height: 1.2),
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 18),
          if (sent)
            _card(
              key: const ValueKey('family_sent'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    bothSent
                        ? familyStage.completionHeading
                        : 'Sent to $otherLabel and $name.',
                    style: SelahText.option().copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    bothSent
                        ? familyStage.completionLine
                        : 'Waiting for $name to answer $ownLabel’s questions. The Journey moves on when you have both answered.',
                    style: SelahText.subtext().copyWith(height: 1.2),
                  ),
                ],
              ),
            )
          else ...[
            if (failed) ...[
              SelahErrorBanner(
                key: const ValueKey('family_failure'),
                message: 'Your answers didn’t send. Try again.',
                retryKey: const ValueKey('family_retry'),
                onRetry: current() && controller.canSend ? send : null,
              ),
              const SizedBox(height: 10),
            ],
            Text(
              '$name and both Shepherds read your answers.',
              style: SelahText.subtext().copyWith(height: 1.5),
            ),
            const SizedBox(height: 10),
            Opacity(
              opacity: sending
                  ? .75
                  : controller.canSend
                  ? 1
                  : .45,
              child: SelahInviteButton(
                key: const ValueKey('family_send'),
                label: sending ? 'Sending…' : 'Send answers',
                onPressed: current() && controller.canSend ? send : null,
              ),
            ),
            if (!sending && controller.answeredCount < questions.length) ...[
              const SizedBox(height: 10),
              Text(
                '${controller.answeredCount} of ${questions.length} answered',
                key: const ValueKey('family_answered_count'),
                textAlign: TextAlign.center,
                style: SelahText.subtext().copyWith(height: 1.2),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

// A single Unicode-rune limit is shared with validation and the visible count.
// Presentation-only editors never become a second saved answer authority.
final _familyLimit = TextInputFormatter.withFunction((oldValue, newValue) {
  final runes = newValue.text.runes;
  final limit = JourneyQuestions.familyAnswerCharacterLimit;
  if (runes.length <= limit) return newValue;
  final text = String.fromCharCodes(runes.take(limit));
  return TextEditingValue(
    text: text,
    selection: TextSelection.collapsed(
      offset: newValue.selection.extentOffset.clamp(0, text.length),
    ),
  );
});
