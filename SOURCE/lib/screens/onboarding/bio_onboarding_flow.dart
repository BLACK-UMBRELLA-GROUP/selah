import 'package:flutter/material.dart';
import '../../widgets/selah_switch.dart';

import '../../models/journey_bio.dart';
import '../../services/selah_onboarding_answers_service.dart';
import '../../services/selah_developer_access.dart';
import '../../services/selah_auth.dart';
import '../../services/selah_account_state.dart';
import '../../state/app_state.dart';
import '../../theme/selah_colors.dart';
import '../../theme/selah_text.dart';
import '../../widgets/onboarding_scaffold.dart';
import '../../widgets/privacy_indicator.dart';
import '../../widgets/selah_loading.dart';
import 'onboarding_stage_intro_screen.dart';
import 'values_preferences_flow.dart';
import 'seeker_setup_navigation.dart';

/// Optional, Journey-only Bio chapter.
///
/// The structured facts are intentionally entered here rather than copied
/// silently from private compatibility answers. Sharing something with a
/// future Journey is an explicit decision, not a side effect of matching.
class BioOnboardingFlow extends StatefulWidget {
  final String? gender;
  final bool devPreview;

  const BioOnboardingFlow({
    super.key,
    required this.gender,
    this.devPreview = false,
  });

  @override
  State<BioOnboardingFlow> createState() => _BioOnboardingFlowState();
}

class _BioOnboardingFlowState extends State<BioOnboardingFlow> {
  static const _sections = [
    'Work & education',
    'Family & marriage',
    'Practical life',
  ];
  static const int _totalSteps = 5;

  int _step = 0;
  bool _saving = false;
  bool _leaving = false;
  bool _restoring = false;
  String? _owner;
  late int _ownerGeneration;
  String? _restoreError;
  String? _saveError;
  final _aboutController = TextEditingController();
  final Map<String, TextEditingController> _freeTextControllers = {};
  final Map<String, String> _values = {};
  final Set<String> _visibleFieldIds = {};
  bool _showAboutMe = false;

  // Requested preview is sticky even after authorization changes. It may
  // become unavailable, but must never begin saving as a live member flow.
  bool get _devPreview => widget.devPreview;
  bool get _canProceed =>
      mounted &&
      !_leaving &&
      (!_devPreview || SelahDeveloperAccess.canUseDeveloperTools) &&
      (_devPreview ||
          (_owner != null &&
              SelahAuth.currentUser?.id == _owner &&
              SelahAccountState.isCurrent(_owner!, _ownerGeneration)));

  @override
  void initState() {
    super.initState();
    _ownerGeneration = SelahAccountState.generation;
    if (!_devPreview) {
      try {
        _owner = SelahAuth.currentUser?.id;
      } catch (_) {
        /* Restore fails closed. */
      }
    }
    final current = AppState.instance.journeyBio;
    if (!current.isEmpty || current.showAboutMe) {
      _applySavedBio(current);
    }
    if (!_devPreview) _restoreSavedBio();
  }

  void _applySavedBio(JourneyBio bio) {
    _aboutController.text = bio.aboutMe;
    _values
      ..clear()
      ..addAll(bio.fieldValues);
    _visibleFieldIds
      ..clear()
      ..addAll(bio.visibleFieldIds);
    _showAboutMe = bio.showAboutMe;
  }

  Future<void> _restoreSavedBio() async {
    setState(() => _restoring = true);
    try {
      final snapshot = await SelahOnboardingAnswersService.fetchOwn(
        expectedUserId: _owner,
        throwOnError: true,
      ).timeout(const Duration(seconds: 10));
      if (!_canProceed) throw StateError('Account changed.');
      if (snapshot != null) {
        _applySavedBio(snapshot.journeyBio);
        AppState.instance.saveJourneyBio(snapshot.journeyBio);
      }
      setState(() {
        _restoring = false;
        _restoreError = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _restoring = false;
          _restoreError =
              'Your saved Bio could not be loaded. Try again before continuing.';
        });
      }
    }
  }

  SelahBackgroundVariant get _background => switch (widget.gender) {
    'male' => SelahBackgroundVariant.male,
    'female' => SelahBackgroundVariant.female,
    _ => SelahBackgroundVariant.neutral,
  };

  List<JourneyBioFieldDefinition> _fieldsFor(String section) =>
      journeyBioFieldDefinitions
          .where((field) => field.section == section)
          .toList(growable: false);

  JourneyBio get _draft => JourneyBio(
    aboutMe: _aboutController.text,
    fieldValues: Map<String, String>.unmodifiable(_values),
    visibleFieldIds: Set<String>.unmodifiable(_visibleFieldIds),
    showAboutMe: _showAboutMe,
  );

  void _setValue(JourneyBioFieldDefinition field, String value) {
    setState(() {
      final trimmed = value.trim();
      if (trimmed.isEmpty) {
        _values.remove(field.id);
        _visibleFieldIds.remove(field.id);
      } else {
        _values[field.id] = value;
        // Adding a Journey Bio detail opts that detail in. The review step
        // immediately below lets the Seeker turn any item back off.
        _visibleFieldIds.add(field.id);
      }
    });
  }

  void _back() {
    if (!_canProceed || _saving || _restoring || _restoreError != null) return;
    if (_step > 0) setState(() => _step--);
  }

  Future<void> _finishLater() async {
    if (!_canProceed || _saving || _restoring || _restoreError != null) return;
    setState(() {
      _saving = true;
      _saveError = null;
    });
    final draft = _draft.copyWith(
      reviewed: AppState.instance.journeyBio.reviewed,
    );
    final saved =
        _devPreview ||
        await SelahOnboardingAnswersService.syncJourneyBio(
          draft,
          expectedUserId: _owner,
        );
    if (!mounted) return;
    if (saved && _canProceed) {
      AppState.instance.saveJourneyBio(draft);
      final opened = await returnToMySelah(
        context,
        devPreview: _devPreview,
        expectedUserId: _owner,
        expectedGeneration: _ownerGeneration,
      );
      if (opened) return;
    }
    if (mounted) {
      setState(() {
        _saving = false;
        _saveError = 'Your progress could not be confirmed. Please try again.';
      });
    }
  }

  Future<void> _next() async {
    if (!_canProceed ||
        ModalRoute.of(context)?.isCurrent != true ||
        _saving ||
        _restoring ||
        _restoreError != null) {
      return;
    }
    setState(() {
      _saving = true;
      _saveError = null;
    });
    final finalStep = _step == _totalSteps - 1;
    final draft = _draft.copyWith(
      reviewed: finalStep || AppState.instance.journeyBio.reviewed,
    );
    final saved = _devPreview
        ? true
        : await SelahOnboardingAnswersService.syncJourneyBio(
            draft,
            expectedUserId: _owner,
          );
    if (!mounted || !_canProceed) return;
    setState(() => _saving = false);
    if (ModalRoute.of(context)?.isCurrent != true) return;

    if (!saved) {
      setState(
        () => _saveError = 'Your Bio could not be saved. Please try again.',
      );
      return;
    }
    AppState.instance.saveJourneyBio(draft);
    if (!finalStep) {
      setState(() => _step++);
      return;
    }

    final gender = widget.gender;
    final devPreview = _devPreview;
    final owner = _owner;
    final ownerGeneration = _ownerGeneration;
    var stageLeaving = false;
    if (gender == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Complete Gender in Essentials before starting Compatibility.',
          ),
        ),
      );
      return;
    }
    setState(() => _leaving = true);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (stageContext) {
          void openCompatibility() {
            if (stageLeaving ||
                !stageContext.mounted ||
                ModalRoute.of(stageContext)?.isCurrent != true) {
              return;
            }
            if (devPreview
                ? !SelahDeveloperAccess.canUseDeveloperTools
                : owner == null ||
                      SelahAuth.currentUser?.id != owner ||
                      !SelahAccountState.isCurrent(owner, ownerGeneration)) {
              return;
            }
            stageLeaving = true;
            Navigator.of(stageContext).pushReplacement(
              MaterialPageRoute(
                builder: (_) => ValuesPreferencesFlow(
                  gender: gender,
                  devPreview: devPreview,
                ),
              ),
            );
          }

          return OnboardingStageIntroScreen(
            stage: SeekerOnboardingStage.compatibility,
            devPreview: devPreview,
            onDevSkip: devPreview ? openCompatibility : null,
            onContinue: openCompatibility,
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _aboutController.dispose();
    for (final controller in _freeTextControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: SelahDeveloperAccess.authorizationChanges,
    builder: (context, _) {
      if (_devPreview && !SelahDeveloperAccess.canUseDeveloperTools) {
        return Scaffold(
          key: const ValueKey('bio_preview_denied'),
          backgroundColor: SelahColors.modalSheetSurface,
          body: const SizedBox.expand(),
        );
      }
      return _buildFlow(context);
    },
  );

  Widget _buildFlow(BuildContext context) {
    if (_restoring) {
      return const SelahLoading.fullScreen(label: 'Restoring your saved Bio…');
    }
    if (_restoreError != null) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _restoreError!,
                    textAlign: TextAlign.center,
                    style: SelahText.body(),
                  ),
                  TextButton(
                    onPressed: _restoreSavedBio,
                    child: const Text('Try again'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    child: const Text('Back'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    late String question;
    late String subtext;
    late Widget content;

    if (_step == 0) {
      question = 'Tell them about you — in your own words.';
      subtext = 'Optional · Maximum ${JourneyBio.characterLimit} characters';
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _aboutController,
            minLines: 7,
            maxLines: 11,
            maxLength: JourneyBio.characterLimit,
            onChanged: (value) => setState(() {
              if (value.trim().isEmpty) {
                _showAboutMe = false;
              } else if (!_showAboutMe) {
                _showAboutMe = true;
              }
            }),
            style: SelahText.body(size: 15.5),
            cursorColor: SelahColors.unlockText,
            decoration: InputDecoration(
              hintText:
                  'Your character, the life you hope to build, and what matters to you…',
              hintStyle: SelahText.subtext(color: SelahColors.ink(0.30)),
              filled: true,
              fillColor: SelahColors.iconButtonBg,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: SelahColors.iconButtonBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: SelahColors.unlockText),
              ),
              counterStyle: SelahText.subtext(
                size: 11,
                color: SelahColors.ink(0.38),
              ),
            ),
          ),
          SizedBox(height: 10),
          _JourneyShareSwitch(
            label: 'Include this biography in my Journey profile',
            value: _showAboutMe,
            enabled: _aboutController.text.trim().isNotEmpty,
            onChanged: (value) => setState(() => _showAboutMe = value),
          ),
        ],
      );
    } else if (_step <= _sections.length) {
      final section = _sections[_step - 1];
      final fields = _fieldsFor(section);
      question = section;
      subtext = 'Optional · Choose only what you would want a Journey to see';
      content = Column(
        children: [
          for (final field in fields) ...[
            _BioFieldEditor(
              definition: field,
              value: _values[field.id] ?? '',
              controller: field.usesFreeText
                  ? _freeTextControllers.putIfAbsent(
                      field.id,
                      () =>
                          TextEditingController(text: _values[field.id] ?? ''),
                    )
                  : null,
              shared: _visibleFieldIds.contains(field.id),
              onChanged: (value) => _setValue(field, value),
              onSharedChanged: (shared) => setState(() {
                if (shared) {
                  _visibleFieldIds.add(field.id);
                } else {
                  _visibleFieldIds.remove(field.id);
                }
              }),
            ),
            if (field != fields.last) SizedBox(height: 12),
          ],
        ],
      );
    } else {
      question = 'Review what your Journey can reveal.';
      subtext = 'Optional · Nothing here affects your compatibility score';
      content = _BioVisibilityReview(
        bio: _draft,
        onShowAboutMeChanged: (value) => setState(() => _showAboutMe = value),
        onFieldChanged: (id, shared) => setState(() {
          if (shared) {
            _visibleFieldIds.add(id);
          } else {
            _visibleFieldIds.remove(id);
          }
        }),
      );
    }

    return OnboardingScaffold(
      background: _background,
      chapterName: 'Journey Bio',
      chapterProgress: (_step + 1) / _totalSteps,
      progressLabel: 'STEP ${_step + 1} OF $_totalSteps',
      question: question,
      subtext: subtext,
      privacy: PrivacyLevel.private,
      privacyOverrideText:
          'Journey only — shown after both Seekers choose to reveal.',
      fabActive: !_saving,
      onContinue: _next,
      devPreview: _devPreview,
      onDevSkip: _next,
      devSkipLabel: 'Skip page',
      onSwipeBack: _step > 0 ? _back : null,
      onFinishLater: _finishLater,
      content: IgnorePointer(
        ignoring: _saving,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_saveError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  _saveError!,
                  style: SelahText.subtext(color: SelahColors.destructive),
                ),
              ),
            content,
          ],
        ),
      ),
    );
  }
}

class _BioFieldEditor extends StatelessWidget {
  final JourneyBioFieldDefinition definition;
  final String value;
  final TextEditingController? controller;
  final bool shared;
  final ValueChanged<String> onChanged;
  final ValueChanged<bool> onSharedChanged;

  const _BioFieldEditor({
    required this.definition,
    required this.value,
    required this.controller,
    required this.shared,
    required this.onChanged,
    required this.onSharedChanged,
  });

  @override
  Widget build(BuildContext context) {
    final hasValue = value.trim().isNotEmpty;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      decoration: BoxDecoration(
        color: SelahColors.iconButtonBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SelahColors.iconButtonBorder, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(definition.prompt, style: SelahText.body(size: 13.5)),
          SizedBox(height: 10),
          if (definition.usesFreeText)
            TextField(
              controller: controller,
              onChanged: onChanged,
              style: SelahText.body(size: 14.5),
              decoration: InputDecoration(
                hintText: 'Optional answer',
                hintStyle: SelahText.subtext(color: SelahColors.ink(0.30)),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: SelahColors.ink(0.24)),
                ),
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: SelahColors.unlockDot),
                ),
              ),
            )
          else
            DropdownButtonFormField<String>(
              initialValue: hasValue ? value : null,
              isExpanded: true,
              dropdownColor: SelahColors.luxuryDarkPurple,
              style: SelahText.body(size: 14),
              decoration: InputDecoration(
                hintText: 'Choose an optional answer',
                hintStyle: SelahText.subtext(color: SelahColors.ink(0.30)),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: SelahColors.ink(0.24)),
                ),
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: SelahColors.unlockDot),
                ),
              ),
              items: [
                for (final option in definition.options)
                  DropdownMenuItem(value: option, child: Text(option)),
              ],
              onChanged: (next) => onChanged(next ?? ''),
            ),
          SizedBox(height: 4),
          _JourneyShareSwitch(
            label: 'Show ${definition.label.toLowerCase()} in my Journey',
            value: shared && hasValue,
            enabled: hasValue,
            onChanged: onSharedChanged,
          ),
        ],
      ),
    );
  }
}

class _JourneyShareSwitch extends StatelessWidget {
  final String label;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const _JourneyShareSwitch({
    required this.label,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SelahSwitchListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(
        label,
        style: SelahText.subtext(
          size: 11.5,
          color: enabled ? SelahColors.ink(0.70) : SelahColors.ink(0.30),
        ),
      ),
      value: enabled && value,
      onChanged: enabled ? onChanged : null,
    );
  }
}

class _BioVisibilityReview extends StatelessWidget {
  final JourneyBio bio;
  final ValueChanged<bool> onShowAboutMeChanged;
  final void Function(String id, bool shared) onFieldChanged;

  const _BioVisibilityReview({
    required this.bio,
    required this.onShowAboutMeChanged,
    required this.onFieldChanged,
  });

  @override
  Widget build(BuildContext context) {
    final filledFields = journeyBioFieldDefinitions
        .where((field) => (bio.fieldValues[field.id] ?? '').trim().isNotEmpty)
        .toList(growable: false);
    if (bio.aboutMe.trim().isEmpty && filledFields.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
        decoration: BoxDecoration(
          color: SelahColors.iconButtonBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: SelahColors.iconButtonBorder, width: 0.5),
        ),
        child: Column(
          children: [
            Icon(Icons.notes_rounded, color: SelahColors.ink(0.54), size: 30),
            SizedBox(height: 10),
            Text('No Bio added', style: SelahText.heading(size: 18)),
            SizedBox(height: 6),
            Text(
              'That is completely fine. Your Journey will simply explain that you chose not to add one.',
              textAlign: TextAlign.center,
              style: SelahText.subtext(size: 12.5),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        if (bio.aboutMe.trim().isNotEmpty)
          _ReviewToggle(
            title: 'Biography',
            value:
                '${bio.aboutMe.trim().length} / ${JourneyBio.characterLimit} characters',
            shared: bio.showAboutMe,
            onChanged: onShowAboutMeChanged,
          ),
        for (final field in filledFields)
          _ReviewToggle(
            title: field.label,
            value: bio.fieldValues[field.id]!,
            shared: bio.visibleFieldIds.contains(field.id),
            onChanged: (shared) => onFieldChanged(field.id, shared),
          ),
        SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            '${bio.sharedItemCount} item${bio.sharedItemCount == 1 ? '' : 's'} selected for Journey reveal',
            style: SelahText.subtext(size: 11.5, color: SelahColors.unlockText),
          ),
        ),
      ],
    );
  }
}

class _ReviewToggle extends StatelessWidget {
  final String title;
  final String value;
  final bool shared;
  final ValueChanged<bool> onChanged;

  const _ReviewToggle({
    required this.title,
    required this.value,
    required this.shared,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
      decoration: BoxDecoration(
        color: SelahColors.iconButtonBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: SelahColors.iconButtonBorder, width: 0.5),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: SelahText.body(size: 13.5)),
                SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: SelahText.subtext(size: 11.5),
                ),
              ],
            ),
          ),
          SelahSwitch(value: shared, onChanged: onChanged),
        ],
      ),
    );
  }
}
