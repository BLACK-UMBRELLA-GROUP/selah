import 'package:flutter/material.dart';

import '../../models/selah_faith_profile.dart';
import '../../models/selah_faith_profile_controller.dart';
import '../../theme/selah_colors.dart';
import '../../theme/selah_text.dart';
import '../../widgets/selah_shepherd_invite_views.dart';
import '../../widgets/selah_state_widgets.dart';

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

  Widget _header() => Padding(
    padding: const EdgeInsets.fromLTRB(22, 6, 22, 12),
    child: Row(
      children: [
        TextButton(
          key: const ValueKey('faith_back'),
          onPressed: _back,
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
        const Spacer(),
        Text('Your faith · $_question of 7', style: SelahText.subtext()),
      ],
    ),
  );

  Widget _choice(String option, int index) {
    final selected = _selected(option);
    return Semantics(
      selected: selected,
      button: true,
      child: Container(
        decoration: BoxDecoration(
          color: SelahColors.surface,
          border: Border.all(
            color: selected ? SelahColors.lake : SelahColors.line,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        foregroundDecoration: selected
            ? BoxDecoration(
                border: Border.all(color: SelahColors.lake, width: 2),
                borderRadius: BorderRadius.circular(14),
              )
            : null,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: ValueKey('faith_choice_q${_question}_$index'),
            borderRadius: BorderRadius.circular(14),
            onTap: () => _faith.choose(_question, index),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
              child: Text(
                option,
                style: SelahText.body(size: 14.5).copyWith(height: 1.2),
              ),
            ),
          ),
        ),
      ),
    );
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
  Widget build(BuildContext context) {
    final saving = _faith.saveState == SelahFaithProfileSaveState.saving;
    final failed = _faith.saveState == SelahFaithProfileSaveState.failed;
    final options = SelahFaithProfileAnswers.optionsFor(_question);
    final help = _help[_question];
    return Scaffold(
      key: ValueKey('faith_question_$_question'),
      backgroundColor: SelahColors.mist,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _header(),
            Expanded(
              child: LayoutBuilder(
                builder: (context, bounds) => SingleChildScrollView(
                  controller: _scroll,
                  child: Padding(
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
                            if (failed) ...[
                              SelahErrorBanner(
                                key: const ValueKey('faith_failure'),
                                message:
                                    'Your faith profile didn’t save. Try again.',
                                retryKey: const ValueKey('faith_retry'),
                                onRetry: _save,
                              ),
                              const SizedBox(height: 14),
                            ],
                            ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                value: _question / 7,
                                minHeight: 5,
                                color: SelahColors.lake,
                                backgroundColor: SelahColors.line,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              _titles[_question - 1],
                              style: SelahText.pageTitle(),
                            ),
                            if (help != null) ...[
                              const SizedBox(height: 14),
                              Text(
                                help,
                                style: SelahText.body(color: SelahColors.muted),
                              ),
                            ],
                            const SizedBox(height: 14),
                            if (options.isNotEmpty)
                              for (var i = 0; i < options.length; i++) ...[
                                if (i > 0) const SizedBox(height: 8),
                                _choice(options[i], i),
                              ]
                            else
                              _wordsField(),
                            if (_faith.showRequiredErrorFor(_question)) ...[
                              const SizedBox(height: 14),
                              Text(
                                'Choose one answer to continue.',
                                key: const ValueKey('faith_required_error'),
                                style: SelahText.subtext(
                                  color: SelahColors.dawn,
                                ),
                              ),
                            ],
                            const SizedBox(height: 14),
                            const Spacer(),
                            if (_question == 7 && _faith.showLengthError) ...[
                              Text(
                                'Keep it under 150 characters.',
                                key: const ValueKey('faith_length_error'),
                                style: SelahText.subtext(
                                  color: SelahColors.dawn,
                                ),
                              ),
                              const SizedBox(height: 14),
                            ],
                            Opacity(
                              opacity: saving ? .75 : 1,
                              child: SelahInviteButton(
                                key: ValueKey(
                                  _question == 7
                                      ? 'faith_save'
                                      : 'faith_continue',
                                ),
                                label: saving
                                    ? 'Saving…'
                                    : _question == 7
                                    ? 'Save and continue'
                                    : 'Continue',
                                onPressed: saving ? null : _next,
                              ),
                            ),
                            if (saving)
                              // The locked master reserves the existing private
                              // demo-row space; no member-facing preset appears.
                              const SizedBox(height: 42)
                            else if (_question == 5 || _question == 7) ...[
                              const SizedBox(height: 10),
                              SelahInviteButton(
                                key: const ValueKey('faith_skip'),
                                label: 'Skip',
                                ghost: true,
                                onPressed: _skip,
                              ),
                            ],
                          ],
                        ),
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
