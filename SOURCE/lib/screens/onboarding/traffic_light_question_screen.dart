// Generic per-option preference screen. Every possible answer receives its
// own explicit Prefer this / No preference / Not for me choice.
//
// HARD REQUIREMENTS ARE PER-OPTION IN CHAPTER 4 SINCE 2026-08-10 (Onboarding
// Direction B, Founder decision; migration onboarding_b_stage1_hard_
// requirements_become_per_option). WAS: one checkbox per QUESTION reading
// "Never show me people matching the options I marked 🔴" — which meant a
// Seeker could not say
//
//     Currently Married — never.
//     Divorced        — I'd rather not, but I'd consider the right person.
//
// on the same question. Ticking the box excluded both; leaving it off excluded
// neither. There was no third position, and nothing on screen hinted that one
// checkbox reached past the option the user was looking at.
//
// The wire shape is {question_id: [option_label, ...]} and the database CHECK
// constraint onboarding_answers_ch4_hard_shape rejects the retired
// {question_id: bool} form outright — deliberately, because a silent
// old-shape write would read as "no hard requirement at all", failing OPEN on
// a promise the Seeker made.
//
// No value is inferred or preselected. A choice here is a stated preference,
// so every saved light must come from a deliberate tap.

import 'package:flutter/material.dart';
import '../../models/onboarding_question.dart';
import '../../theme/selah_colors.dart';
import '../../theme/selah_text.dart';

// RETIRED 2026-08-10: `HardRequirementScope`. It existed for a few hours to
// let Chapter 2 keep a single question-wide checkbox while Chapter 4 moved to
// per-option exclusions, because seeker_details.preferences still stored
// {sect: {hard_requirement: bool}} across 144 live rows. Showing the
// per-option control over that storage would have let someone exclude Ibadi
// but not Shia while the engine still excluded both — a screen promising
// precision the server could not honour.
//
// Chapter 2 converged the same afternoon (inherited upstream action 185): those rows were
// converted, a CHECK now rejects the boolean form, and score_candidates()
// tests the sect exclusion per-option and independently of the light. Both
// chapters use one model, so the enum and its branch are gone rather than
// left as a dormant fork nobody would remember the reason for.

class TrafficLightQuestionScreen extends StatefulWidget {
  final String yourAnswer; // "Your answer: ..." shown at the top
  final Set<String> yourAnswers;
  final List<String> options;
  final bool hardRequirementSupported;
  final Map<String, TrafficLight> initialValues;

  /// Option labels this Seeker will never be introduced to, for THIS question.
  /// Under [HardRequirementScope.perQuestion] this is all-or-nothing: either
  /// empty, or exactly the set of 🔴 options.
  final Set<String> initialHardRequirement;

  final ValueChanged<Map<String, TrafficLight>> onChanged;
  final ValueChanged<Set<String>> onHardRequirementChanged;

  const TrafficLightQuestionScreen({
    super.key,
    required this.yourAnswer,
    this.yourAnswers = const {},
    required this.options,
    required this.onChanged,
    required this.onHardRequirementChanged,
    this.hardRequirementSupported = true,
    this.initialValues = const {},
    this.initialHardRequirement = const {},
  });

  @override
  State<TrafficLightQuestionScreen> createState() =>
      _TrafficLightQuestionScreenState();
}

class _TrafficLightQuestionScreenState
    extends State<TrafficLightQuestionScreen> {
  late final Map<String, TrafficLight> _values = Map<String, TrafficLight>.from(
    widget.initialValues,
  );
  late final Set<String> _hard = Set<String>.from(
    widget.initialHardRequirement,
  );

  Set<String> get _redOptions =>
      widget.options.where((o) => _values[o] == TrafficLight.red).toSet();

  bool get _allRed =>
      widget.options.isNotEmpty && _redOptions.length == widget.options.length;

  void _set(String option, TrafficLight light) {
    setState(() {
      _values[option] = light;

      if (light != TrafficLight.red) {
        // An exclusion cannot outlive the 🔴 that justified it. Without this,
        // a Seeker who marks Divorced 🔴, ticks "never", then changes back to
        // 🟢 would keep an invisible permanent exclusion — and the server now
        // enforces exclusions INDEPENDENTLY of the lights, so it would
        // genuinely bind with nothing on screen to explain it.
        _hard.remove(option);
      }
    });
    widget.onChanged(Map<String, TrafficLight>.from(_values));
    widget.onHardRequirementChanged(Set<String>.from(_hard));
  }

  void _toggleHardOption(String option) {
    setState(() {
      if (!_hard.remove(option)) _hard.add(option);
    });
    widget.onHardRequirementChanged(Set<String>.from(_hard));
  }

  @override
  Widget build(BuildContext context) {
    final showHard = widget.hardRequirementSupported;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.yourAnswer.isNotEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: SelahColors.iconButtonBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: SelahColors.iconButtonBorder,
                width: 0.5,
              ),
            ),
            child: Text(
              'Your answer: ${widget.yourAnswer}',
              style: SelahText.subtext(size: 12.5),
            ),
          ),
          SizedBox(height: 18),
        ],
        ...widget.options.map((option) {
          final current = _values[option];
          final isRed = current == TrafficLight.red;
          return Container(
            key: ValueKey('preference_option_$option'),
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 11),
            decoration: BoxDecoration(
              color: SelahColors.foreground.withValues(alpha: 0.035),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: SelahColors.foreground.withValues(alpha: 0.09),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: Text(option, style: SelahText.option())),
                    if (widget.yourAnswers.contains(option)) ...[
                      SizedBox(width: 9),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: SelahColors.accentBg,
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(
                            color: SelahColors.accentBorder,
                            width: 0.7,
                          ),
                        ),
                        child: Text(
                          'YOUR ANSWER',
                          style: SelahText.chapterLabel(
                            color: SelahColors.ink(0.70),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                SizedBox(height: 11),
                Row(
                  children: [
                    Expanded(
                      child: _LightButton(
                        key: ValueKey('preference_${option}_green'),
                        light: TrafficLight.green,
                        label: 'Prefer this',
                        semanticLabel: 'Prefer this for $option',
                        active: current == TrafficLight.green,
                        onTap: () => _set(option, TrafficLight.green),
                      ),
                    ),
                    SizedBox(width: 7),
                    Expanded(
                      child: _LightButton(
                        key: ValueKey('preference_${option}_yellow'),
                        light: TrafficLight.yellow,
                        label: 'No preference',
                        semanticLabel: 'No preference for $option',
                        active: current == TrafficLight.yellow,
                        onTap: () => _set(option, TrafficLight.yellow),
                      ),
                    ),
                    SizedBox(width: 7),
                    Expanded(
                      child: _LightButton(
                        key: ValueKey('preference_${option}_red'),
                        light: TrafficLight.red,
                        label: 'Not for me',
                        semanticLabel: 'Not for me: $option',
                        active: isRed,
                        onTap: () => _set(option, TrafficLight.red),
                      ),
                    ),
                  ],
                ),
                // The exclusion belongs to the option, not the question, so it
                // renders under the option — indented, so it reads as a
                // qualifier on the row above rather than a new question.
                if (showHard && isRed) ...[
                  SizedBox(height: 6),
                  InkWell(
                    onTap: () => _toggleHardOption(option),
                    child: Padding(
                      padding: const EdgeInsets.only(
                        left: 2,
                        top: 2,
                        bottom: 2,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _hard.contains(option)
                                ? Icons.check_box
                                : Icons.check_box_outline_blank,
                            color: SelahColors.ink(0.54),
                            size: 17,
                          ),
                          SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              'Never introduce anyone who answered "$option".',
                              style: SelahText.subtext(size: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        }),

        // ALL-RED — a WARNING, NOT A BLOCK (changed 2026-08-10, H1).
        //
        // Continue used to be disabled here, which stranded people mid-
        // question with no explanation of what they had done wrong: the FAB
        // simply stopped working. The old copy ("At least one option must
        // remain 🟢 or 🟡") was a rule the screen never showed until you had
        // already broken it.
        //
        // Marking everything 🔴 is a legitimate thing to mean. The Seeker is
        // told what it costs and allowed to proceed.
        if (_allRed) ...[
          SizedBox(height: 4),
          Text(
            _hard.length == widget.options.length
                ? 'You have ruled out every answer to this question, so nobody who '
                      'answers it can be introduced to you.'
                : "You're not open to any answer here. SELAH can still introduce "
                      'people, but this question will count against every one of them.',
            style: SelahText.subtext(size: 11.5),
          ),
          SizedBox(height: 4),
        ],

        // Chapter 4 — a plain-language confirmation of what was just promised.
        if (showHard && _hard.isNotEmpty) ...[
          SizedBox(height: 6),
          Text(
            _hard.length == 1
                ? 'SELAH will never introduce someone with that answer.'
                : 'SELAH will never introduce someone with any of those ${_hard.length} answers.',
            style: SelahText.subtext(size: 11.5),
          ),
        ],
      ],
    );
  }
}

class _LightButton extends StatelessWidget {
  final TrafficLight light;
  final String label;
  final String semanticLabel;
  final bool active;
  final VoidCallback onTap;

  const _LightButton({
    super.key,
    required this.light,
    required this.label,
    required this.semanticLabel,
    required this.active,
    required this.onTap,
  });

  Color get _color => switch (light) {
    TrafficLight.green => SelahColors.positiveGreen,
    TrafficLight.yellow => SelahColors.journeyGold,
    TrafficLight.red => SelahColors.negativeRed,
  };

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: active,
      label: semanticLabel,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(11),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            constraints: const BoxConstraints(minHeight: 57),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            decoration: BoxDecoration(
              color: active
                  ? _color.withValues(alpha: 0.14)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(
                color: active
                    ? _color.withValues(alpha: 0.82)
                    : SelahColors.foreground.withValues(alpha: 0.13),
                width: active ? 1.2 : 0.8,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _color,
                    boxShadow: active
                        ? [
                            BoxShadow(
                              color: _color.withValues(alpha: 0.32),
                              blurRadius: 7,
                            ),
                          ]
                        : null,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  label,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  style: SelahText.subtext(
                    size: 10.5,
                    color: active ? Colors.white : SelahColors.ink(0.60),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
