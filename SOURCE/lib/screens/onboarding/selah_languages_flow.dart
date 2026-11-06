import 'package:flutter/material.dart';
import '../../data/selah_reference_data.dart';
import '../../models/selah_languages_controller.dart';
import '../../theme/selah_colors.dart';
import '../../theme/selah_text.dart';
import '../../widgets/selah_profile_questions.dart';
import '../../widgets/selah_shepherd_invite_views.dart';
import '../../widgets/selah_state_widgets.dart';
import '../../widgets/searchable_list_picker.dart';

class SelahLanguagesFlow extends StatefulWidget {
  const SelahLanguagesFlow({
    super.key,
    required this.controller,
    required this.onBack,
    required this.onSaved,
  });
  final SelahLanguagesController controller;
  final VoidCallback onBack;
  final VoidCallback onSaved;
  @override
  State<SelahLanguagesFlow> createState() => _SelahLanguagesFlowState();
}

class _SelahLanguagesFlowState extends State<SelahLanguagesFlow> {
  bool _openingSearch = false;

  Future<void> _anotherLanguage() async {
    final owner = widget.controller;
    if (_openingSearch ||
        !owner.current ||
        owner.saveState == SelahLanguagesSaveState.saving) {
      return;
    }
    _openingSearch = true;
    try {
      final language = await showSingleSearchPicker(
        context,
        selahLanguageNames,
        searchHint: 'Search languages',
      );
      if (!mounted ||
          !identical(owner, widget.controller) ||
          !owner.current ||
          language == null) {
        return;
      }
      if (!owner.languages.contains(language)) owner.toggle(language);
    } finally {
      _openingSearch = false;
    }
  }

  Future<void> _save() async {
    final owner = widget.controller;
    final saved = await owner.save();
    if (!mounted || !identical(owner, widget.controller) || !saved) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Profile saved.')));
    widget.onSaved();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final controller = widget.controller;
      final saving = controller.saveState == SelahLanguagesSaveState.saving;
      final choices = controller.displayChoices;
      return Scaffold(
        key: const ValueKey('languages_screen'),
        backgroundColor: SelahColors.mist,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 6, 22, 12),
                child: Row(
                  children: [
                    TextButton(
                      key: const ValueKey('languages_back'),
                      onPressed: saving ? null : widget.onBack,
                      style: TextButton.styleFrom(
                        foregroundColor: SelahColors.lake,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        '‹ Back',
                        style: SelahText.button(
                          size: 15,
                          color: SelahColors.lake,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text('About you', style: SelahText.subtext()),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (controller.saveState ==
                            SelahLanguagesSaveState.failed) ...[
                          SelahErrorBanner(
                            key: const ValueKey('languages_failure'),
                            message: 'Your answers didn’t save. Try again.',
                            retryKey: const ValueKey('languages_retry'),
                            onRetry: _save,
                          ),
                          const SizedBox(height: 14),
                        ],
                        Text(
                          'Which languages do you speak?',
                          style: SelahText.pageTitle(),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Choose any you speak well.',
                          style: SelahText.body(color: SelahColors.muted),
                        ),
                        const SizedBox(height: 14),
                        for (var i = 0; i < choices.length; i++) ...[
                          if (i > 0) const SizedBox(height: 8),
                          SelahProfileQuestionChoice(
                            key: ValueKey(
                              i < SelahLanguagesController.primaryChoices.length
                                  ? 'language_choice_$i'
                                  : 'language_extra_${choices[i]}',
                            ),
                            label: choices[i],
                            selected: controller.languages.contains(choices[i]),
                            onTap: () => controller.toggle(choices[i]),
                          ),
                        ],
                        const SizedBox(height: 8),
                        SelahProfileQuestionChoice(
                          key: const ValueKey('languages_another'),
                          label: 'Another language',
                          selected: false,
                          onTap: _anotherLanguage,
                        ),
                        const SizedBox(height: 14),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 14, 22, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (controller.showRequiredError) ...[
                      Text(
                        'Choose at least one language to continue.',
                        key: const ValueKey('languages_required_error'),
                        style: SelahText.subtext(color: SelahColors.dawn),
                      ),
                      const SizedBox(height: 14),
                    ],
                    Opacity(
                      opacity: saving ? .75 : 1,
                      child: SelahInviteButton(
                        key: const ValueKey('languages_save'),
                        label: saving ? 'Saving…' : 'Save and continue',
                        onPressed: saving ? null : _save,
                      ),
                    ),
                    if (saving) const SizedBox(height: 42),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class SelahAboutYouCard extends StatelessWidget {
  const SelahAboutYouCard({super.key, required this.languages});
  final List<String> languages;
  @override
  Widget build(BuildContext context) => Column(
    key: const ValueKey('about_you_card'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        'ABOUT YOU',
        style: SelahText.chapterLabel(color: SelahColors.muted),
      ),
      const SizedBox(height: 10),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: SelahColors.surface,
          border: Border.all(color: SelahColors.line),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 4,
              child: Text(
                'Languages',
                style: SelahText.body(size: 14.5, color: SelahColors.muted),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 6,
              child: Text(
                languages.isEmpty ? 'Not answered' : languages.join(', '),
                textAlign: TextAlign.right,
                style: SelahText.body(
                  size: 14.5,
                  color: languages.isEmpty
                      ? SelahColors.muted
                      : SelahColors.inkColor,
                ),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}
