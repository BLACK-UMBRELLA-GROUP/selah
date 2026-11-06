import 'package:flutter/material.dart';

import '../../models/onboarding_question.dart';
import '../../models/selah_your_values_controller.dart';
import '../../models/selah_your_values.dart';
import '../../theme/selah_colors.dart';
import '../../theme/selah_text.dart';
import '../../widgets/selah_profile_questions.dart';
import '../../widgets/selah_shepherd_invite_views.dart';
import '../../widgets/selah_state_widgets.dart';

/// LOCK 17/18 presentation over the caller's existing compatibility owner.
class SelahYourValuesFlow extends StatefulWidget {
  const SelahYourValuesFlow({
    super.key,
    required this.controller,
    required this.onBack,
    required this.onFinished,
    this.onPageChanged,
  });

  final SelahYourValuesController controller;
  final VoidCallback onBack;
  final VoidCallback onFinished;
  final ValueChanged<String?>? onPageChanged;

  @override
  State<SelahYourValuesFlow> createState() => _SelahYourValuesFlowState();
}

class _SelahYourValuesFlowState extends State<SelahYourValuesFlow> {
  final _scroll = ScrollController();
  String? _partId;
  int _question = 0;
  int _viewRevision = 0;
  bool _finished = false;
  late SelahYourValuesSaveState _lastSaveState;

  SelahYourValuesController get _values => widget.controller;
  bool get _saving => _values.saveState == SelahYourValuesSaveState.saving;

  @override
  void initState() {
    super.initState();
    _lastSaveState = _values.saveState;
    _values.addListener(_changed);
  }

  @override
  void didUpdateWidget(covariant SelahYourValuesFlow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.controller, widget.controller)) return;
    oldWidget.controller.removeListener(_changed);
    _values.addListener(_changed);
    _partId = null;
    _question = 0;
    _viewRevision++;
    _finished = false;
    _lastSaveState = _values.saveState;
  }

  void _changed() {
    if (!mounted) return;
    final state = _values.saveState;
    final target = _values.savingPartId;
    setState(() {
      if (state != _lastSaveState &&
          (state == SelahYourValuesSaveState.saving ||
              state == SelahYourValuesSaveState.failed) &&
          target != null) {
        final nextQuestion = target == 'dealbreakers'
            ? 0
            : _values.questionsFor(target).length - 1;
        if (_partId != target || _question != nextQuestion) _viewRevision++;
        _partId = target;
        _question = nextQuestion;
      }
      _lastSaveState = state;
    });
  }

  @override
  void dispose() {
    _values.removeListener(_changed);
    _scroll.dispose();
    super.dispose();
  }

  bool _current(int revision) =>
      mounted && revision == _viewRevision && _values.current && !_finished;

  void _show(String? partId, [int question = 0]) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _partId = partId;
      _question = question;
      _viewRevision++;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
    widget.onPageChanged?.call(partId);
  }

  void _back(int revision) {
    if (!_current(revision) || _saving) return;
    if (_partId == null) {
      widget.onBack();
    } else if (_partId == 'dealbreakers' || _question == 0) {
      _show(null);
    } else {
      _show(_partId, _question - 1);
    }
  }

  void _begin(int revision) {
    if (!_current(revision) || _saving) return;
    for (final part in _values.parts) {
      if (!_values.isPartDone(part.id)) {
        _show(part.id);
        return;
      }
    }
    if (!_values.dealbreakersDone) {
      _show('dealbreakers');
      return;
    }
    _finished = true;
    widget.onFinished();
  }

  Future<void> _next(
    int revision,
    String partId,
    OnboardingQuestion question, {
    bool skip = false,
  }) async {
    if (!_current(revision) || _saving) return;
    final controller = _values;
    if (skip) {
      if (!question.selfAnswerOptional) return;
      controller.skip(question);
    } else if (!controller.validate(question)) {
      return;
    }
    final questions = controller.questionsFor(partId);
    if (_question < questions.length - 1) {
      _show(partId, _question + 1);
      return;
    }
    final saved = await controller.savePart(partId);
    if (!mounted ||
        !_current(revision) ||
        !identical(controller, _values) ||
        !saved) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Saved. ${controller.questionsRemaining} questions to go.',
        ),
      ),
    );
    _show(null);
  }

  Future<void> _saveDealbreakers(int revision) async {
    if (!_current(revision) || _saving || !_values.allPartsDone) return;
    final controller = _values;
    final saved = await controller.saveDealbreakers();
    if (!mounted ||
        !_current(revision) ||
        !identical(controller, _values) ||
        !saved) {
      return;
    }
    _show(null);
  }

  @override
  Widget build(BuildContext context) {
    final revision = _viewRevision;
    final partId = _partId;
    if (partId == null) return _overview(revision);
    if (partId == 'dealbreakers') return _dealbreakers(revision);
    final part = _values.parts.where((part) => part.id == partId).firstOrNull;
    final questions = _values.questionsFor(partId);
    if (part == null || questions.isEmpty) return _overview(revision);
    final index = _question.clamp(0, questions.length - 1);
    final question = questions[index];
    return SelahProfileQuestionPage(
      keyPrefix: 'values',
      sectionLabel: part.name,
      questions: [
        for (final q in questions)
          SelahProfileQuestion(title: q.prompt, options: q.options),
      ],
      questionNumber: index + 1,
      scrollController: _scroll,
      onBack: () => _back(revision),
      isSelected: (option) => _values.isSelected(question, option),
      onChoose: (choice) {
        if (_current(revision)) _values.choose(question, choice);
      },
      onContinue: () => _next(revision, partId, question),
      onSkip: question.selfAnswerOptional
          ? () => _next(revision, partId, question, skip: true)
          : null,
      showRequiredError: _values.showRequiredError,
      saving: _saving,
      failureMessage: _values.saveState == SelahYourValuesSaveState.failed
          ? 'Your answers didn’t save. Try again.'
          : null,
      onRetry: () => _next(revision, partId, question),
    );
  }

  Widget _header(int revision) => Padding(
    padding: const EdgeInsets.fromLTRB(22, 6, 22, 12),
    child: Row(
      children: [
        TextButton(
          key: const ValueKey('values_back'),
          onPressed: () => _back(revision),
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
        const Spacer(),
        Text('Your values', style: SelahText.subtext()),
      ],
    ),
  );

  Widget _overview(int revision) => Scaffold(
    key: const ValueKey('values_overview'),
    backgroundColor: SelahColors.mist,
    body: SafeArea(
      bottom: false,
      child: Column(
        children: [
          _header(revision),
          Expanded(
            child: SingleChildScrollView(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'What matters to you in marriage',
                    style: SelahText.pageTitle(),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    '27 questions in 7 short parts. About 8 minutes. Your answers stay private: they only shape who you’re introduced to.',
                    style: SelahText.body(color: SelahColors.muted),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    key: const ValueKey('values_parts'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: SelahColors.surface,
                      border: Border.all(color: SelahColors.line),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: [
                        for (final part in _values.parts) ...[
                          _partRow(
                            part.name,
                            '${_values.questionsFor(part.id).length} questions',
                            _values.isPartDone(part.id),
                            'values_part_${part.id}',
                          ),
                          const Divider(height: 1, color: SelahColors.line),
                        ],
                        _partRow(
                          'Deal-breakers',
                          'Optional · one screen at the end',
                          _values.dealbreakersDone,
                          'values_part_dealbreakers',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  SelahInviteButton(
                    key: const ValueKey('values_begin'),
                    label:
                        _values.parts.any((part) => _values.isPartDone(part.id))
                        ? 'Continue'
                        : 'Begin',
                    onPressed: () => _begin(revision),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _partRow(String title, String subtitle, bool done, String key) =>
      Padding(
        key: ValueKey(key),
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: SelahText.rowTitle()),
                  const SizedBox(height: 3),
                  Text(subtitle, style: SelahText.subtext()),
                ],
              ),
            ),
            if (done)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: SelahColors.soft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Done',
                  style: SelahText.subtext().copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      );

  Widget _dealbreakers(int revision) {
    const labels = selahDealbreakerLabels;
    return Scaffold(
      key: const ValueKey('values_dealbreakers'),
      backgroundColor: SelahColors.mist,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _header(revision),
            Expanded(
              child: LayoutBuilder(
                builder: (context, bounds) => SingleChildScrollView(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(22, 0, 22, 16),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: (bounds.maxHeight - 16).clamp(
                        0,
                        double.infinity,
                      ),
                    ),
                    child: IntrinsicHeight(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_values.saveState ==
                              SelahYourValuesSaveState.failed) ...[
                            SelahErrorBanner(
                              key: const ValueKey(
                                'values_dealbreakers_failure',
                              ),
                              message: 'Your choices didn’t save. Try again.',
                              retryKey: const ValueKey(
                                'values_dealbreakers_retry',
                              ),
                              onRetry: () => _saveDealbreakers(revision),
                            ),
                            const SizedBox(height: 14),
                          ],
                          Text(
                            'Is anything a deal-breaker?',
                            style: SelahText.pageTitle(),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'Only what would truly rule someone out. Selah won’t introduce you to anyone who matches what you choose. Most people choose one or none.',
                            style: SelahText.body(color: SelahColors.muted),
                          ),
                          const SizedBox(height: 14),
                          for (var i = 0; i < labels.length; i++) ...[
                            if (i > 0) const SizedBox(height: 14),
                            SelahProfileQuestionChoice(
                              key: ValueKey('values_dealbreaker_$i'),
                              label: labels[i],
                              selected: _values.selectedDealbreakers.contains(
                                i,
                              ),
                              onTap: () {
                                if (_current(revision) && !_saving) {
                                  _values.toggleDealbreaker(i);
                                }
                              },
                            ),
                          ],
                          const SizedBox(height: 14),
                          Text(
                            'Church tradition and divorce are already covered by your faith and marriage answers. Everything else counts toward how well you match, never as a rule.',
                            style: SelahText.subtext().copyWith(height: 1.5),
                          ),
                          const SizedBox(height: 14),
                          const Spacer(),
                          Opacity(
                            opacity: _saving ? .75 : 1,
                            child: SelahInviteButton(
                              key: const ValueKey('values_dealbreakers_save'),
                              label: _saving ? 'Saving…' : 'Save',
                              onPressed: _saving
                                  ? null
                                  : () => _saveDealbreakers(revision),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
