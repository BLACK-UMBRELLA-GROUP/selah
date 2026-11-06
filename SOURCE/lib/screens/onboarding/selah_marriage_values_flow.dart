import 'package:flutter/material.dart';

import '../../models/selah_marriage_values.dart';
import '../../models/selah_marriage_values_controller.dart';
import '../../widgets/selah_profile_questions.dart';

/// LOCK 5's seven questions, rendered by the shared faith/marriage layout.
class SelahMarriageValuesFlow extends StatefulWidget {
  const SelahMarriageValuesFlow({
    super.key,
    required this.controller,
    required this.onSaved,
    required this.onBack,
    this.initialQuestion = 1,
  }) : assert(initialQuestion >= 1 && initialQuestion <= 7);
  final SelahMarriageValuesController controller;
  final VoidCallback onSaved;
  final VoidCallback onBack;
  final int initialQuestion;

  @override
  State<SelahMarriageValuesFlow> createState() =>
      _SelahMarriageValuesFlowState();
}

class _SelahMarriageValuesFlowState extends State<SelahMarriageValuesFlow> {
  late int _question;
  late SelahMarriageValuesSaveState _lastSaveState;
  final _scroll = ScrollController();
  SelahMarriageValuesController get _marriage => widget.controller;
  static const _titles = [
    'Have you been married before?',
    'Do you have children?',
    'Would you like children?',
    'How do you see roles in marriage?',
    'Would you marry someone who has been divorced?',
    'Where would you like to live after marriage?',
    'When are you hoping to marry?',
  ];

  int _initial() => switch (_marriage.saveState) {
    SelahMarriageValuesSaveState.saving ||
    SelahMarriageValuesSaveState.failed => 7,
    _ => widget.initialQuestion,
  };

  @override
  void initState() {
    super.initState();
    _question = _initial();
    _lastSaveState = _marriage.saveState;
    _marriage.addListener(_changed);
  }

  @override
  void didUpdateWidget(covariant SelahMarriageValuesFlow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    oldWidget.controller.removeListener(_changed);
    _marriage.addListener(_changed);
    _question = _initial();
    _lastSaveState = _marriage.saveState;
  }

  void _changed() {
    if (!mounted) return;
    final state = _marriage.saveState;
    setState(() {
      if (state != _lastSaveState &&
          (state == SelahMarriageValuesSaveState.saving ||
              state == SelahMarriageValuesSaveState.failed)) {
        _question = 7;
      }
      _lastSaveState = state;
    });
  }

  @override
  void dispose() {
    _marriage.removeListener(_changed);
    _scroll.dispose();
    super.dispose();
  }

  void _showQuestion(int question) {
    setState(() => _question = question);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _back() {
    if (_question == 1) {
      widget.onBack();
    } else {
      _showQuestion(_question - 1);
    }
  }

  Future<void> _next() async {
    if (_question == 7) {
      await _save();
    } else if (_marriage.validateQuestion(_question)) {
      _showQuestion(_question + 1);
    }
  }

  Future<void> _save() async {
    final controller = _marriage;
    final saved = await controller.save();
    if (!mounted || !identical(controller, _marriage) || !saved) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Marriage values saved.')));
    widget.onSaved();
  }

  @override
  Widget build(BuildContext context) => SelahProfileQuestionPage(
    keyPrefix: 'marriage',
    sectionLabel: 'Marriage',
    questions: [
      for (var q = 1; q <= 7; q++)
        SelahProfileQuestion(
          title: _titles[q - 1],
          help: q == 4
              ? 'There’s no wrong answer. This helps you meet someone who sees it the way you do.'
              : null,
          options: SelahMarriageValuesAnswers.optionsFor(q),
        ),
    ],
    questionNumber: _question,
    scrollController: _scroll,
    onBack: _back,
    isSelected: (option) => _marriage.answers.answerFor(_question) == option,
    onChoose: (index) => _marriage.choose(_question, index),
    onContinue: _next,
    showRequiredError: _marriage.showRequiredErrorFor(_question),
    saving: _marriage.saveState == SelahMarriageValuesSaveState.saving,
    failureMessage: _marriage.saveState == SelahMarriageValuesSaveState.failed
        ? 'Your marriage values didn’t save. Try again.'
        : null,
    onRetry: _save,
  );
}
