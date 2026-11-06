import 'package:flutter/material.dart';

import '../../models/selah_faith_profile.dart';
import '../../models/selah_faith_profile_controller.dart';
import '../../theme/selah_colors.dart';
import '../../theme/selah_text.dart';
import '../../widgets/selah_profile_questions.dart';

/// The seven LOCK 4 screens; the owner supplies the interim destinations.
class SelahFaithProfileFlow extends StatefulWidget {
  const SelahFaithProfileFlow({
    super.key,
    required this.controller,
    required this.onSaved,
    required this.onBack,
    this.initialQuestion = 1,
  }) : assert(initialQuestion >= 1 && initialQuestion <= 7);

  final SelahFaithProfileController controller;
  final VoidCallback onSaved;
  final VoidCallback onBack;
  final int initialQuestion;

  @override
  State<SelahFaithProfileFlow> createState() => _SelahFaithProfileFlowState();
}

class _SelahFaithProfileFlowState extends State<SelahFaithProfileFlow> {
  late int _question;
  late SelahFaithProfileSaveState _lastSaveState;
  late final TextEditingController _words;
  final _scroll = ScrollController();
  bool _writingWords = false;

  SelahFaithProfileController get _faith => widget.controller;

  static const _titles = [
    'Which church tradition are you part of?',
    'How often are you at church?',
    'Have you been baptised?',
    'How long have you been a Christian?',
    'Where do you serve?',
    'Are you open to someone from another tradition?',
    'Your faith, in your own words',
  ];
  static const _help = <int, String>{
    1: 'Choose the closest one.',
    5: 'Choose any, or skip.',
    7: 'Shown on your profile. Up to 150 characters. You can skip this.',
  };

  int _initial() => switch (_faith.saveState) {
    SelahFaithProfileSaveState.saving || SelahFaithProfileSaveState.failed => 7,
    _ => widget.initialQuestion,
  };

  @override
  void initState() {
    super.initState();
    _question = _initial();
    _lastSaveState = _faith.saveState;
    _words = TextEditingController(text: _faith.answers.words);
    _faith.addListener(_changed);
  }

  @override
  void didUpdateWidget(covariant SelahFaithProfileFlow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    oldWidget.controller.removeListener(_changed);
    _faith.addListener(_changed);
    _question = _initial();
    _lastSaveState = _faith.saveState;
    _words.text = _faith.answers.words;
  }

  void _changed() {
    if (!mounted) return;
    if (!_writingWords && _words.text != _faith.answers.words) {
      _words.value = TextEditingValue(
        text: _faith.answers.words,
        selection: TextSelection.collapsed(offset: _faith.answers.words.length),
      );
    }
    final state = _faith.saveState;
    setState(() {
      if (state != _lastSaveState &&
          (state == SelahFaithProfileSaveState.saving ||
              state == SelahFaithProfileSaveState.failed)) {
        _question = 7;
      }
      _lastSaveState = state;
    });
  }

  @override
  void dispose() {
    _faith.removeListener(_changed);
    _words.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _showQuestion(int question) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _question = question);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _back() {
    if (_question == 1) {
      FocusManager.instance.primaryFocus?.unfocus();
      widget.onBack();
    } else {
      _showQuestion(_question - 1);
    }
  }

  Future<void> _next() async {
    if (_question == 7) {
      await _save();
    } else if (_faith.validateQuestion(_question)) {
      _showQuestion(_question + 1);
    }
  }

  Future<void> _skip() async {
    if (_question == 5) {
      _faith.clearServing();
      _showQuestion(6);
    } else if (_question == 7) {
      await _save(skipWords: true);
    }
  }

  Future<void> _save({bool skipWords = false}) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final controller = _faith;
    final saved = await controller.save(skipWords: skipWords);
    if (!mounted || !identical(controller, _faith) || !saved) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Faith profile saved.')));
    widget.onSaved();
  }

  bool _selected(String option) {
    final answers = _faith.answers;
    return switch (_question) {
      1 => answers.tradition == option,
      2 => answers.church == option,
      3 => answers.baptised == option,
      4 => answers.christianFor == option,
      5 => answers.serving.contains(option),
      6 => answers.openness == option,
      _ => false,
    };
  }

  Widget _wordsField() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SizedBox(
        height: 146,
        child: TextField(
          key: const ValueKey('faith_words'),
          controller: _words,
          keyboardType: TextInputType.multiline,
          textCapitalization: TextCapitalization.sentences,
          maxLines: null,
          expands: true,
          textAlignVertical: TextAlignVertical.top,
          style: SelahText.body().copyWith(height: 1.45),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: SelahColors.surface,
            contentPadding: const EdgeInsets.all(12),
            hintText: 'What does your faith mean to you day to day?',
            hintStyle: SelahText.body(
              color: SelahColors.muted,
            ).copyWith(height: 1.45),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: SelahColors.line),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: SelahColors.line),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: SelahColors.lake),
            ),
          ),
          onChanged: (value) {
            _writingWords = true;
            try {
              _faith.setWords(value);
            } finally {
              _writingWords = false;
            }
          },
        ),
      ),
      const SizedBox(height: 8),
      Text(
        '${_faith.characterCount} of 150',
        key: const ValueKey('faith_count'),
        style: SelahText.subtext(
          color: _faith.characterCount > 150
              ? SelahColors.dawn
              : SelahColors.muted,
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => SelahProfileQuestionPage(
    keyPrefix: 'faith',
    sectionLabel: 'Your faith',
    questions: [
      for (var q = 1; q <= 7; q++)
        SelahProfileQuestion(
          title: _titles[q - 1],
          help: _help[q],
          options: SelahFaithProfileAnswers.optionsFor(q),
        ),
    ],
    questionNumber: _question,
    scrollController: _scroll,
    onBack: _back,
    isSelected: _selected,
    onChoose: (index) => _faith.choose(_question, index),
    onContinue: _next,
    customAnswer: _question == 7 ? _wordsField() : null,
    showRequiredError: _faith.showRequiredErrorFor(_question),
    saving: _faith.saveState == SelahFaithProfileSaveState.saving,
    failureMessage: _faith.saveState == SelahFaithProfileSaveState.failed
        ? 'Your faith profile didn’t save. Try again.'
        : null,
    onRetry: _save,
    beforeButtons: _question == 7 && _faith.showLengthError
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Keep it under 150 characters.',
                key: const ValueKey('faith_length_error'),
                style: SelahText.subtext(color: SelahColors.dawn),
              ),
              const SizedBox(height: 14),
            ],
          )
        : null,
    onSkip: _question == 5 || _question == 7 ? _skip : null,
  );
}
