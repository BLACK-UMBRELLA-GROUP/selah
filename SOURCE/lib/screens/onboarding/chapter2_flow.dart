// Profile setup: existing photos/location, LOCKed faith and marriage, then languages.

import 'package:flutter/material.dart';
import '../../widgets/selah_profile_image.dart';
import '../../data/selah_christian_traditions.dart';
import '../../data/selah_reference_data.dart';
import '../../models/onboarding_question.dart';
import '../../models/selah_faith_profile_controller.dart';
import '../../models/selah_faith_profile_details.dart';
import 'selah_faith_profile_flow.dart';
import 'selah_marriage_values_flow.dart';
import 'selah_languages_flow.dart';
import '../../models/selah_marriage_values_controller.dart';
import '../../models/selah_marriage_values_details.dart';
import '../../models/selah_non_faith_profile_save.dart';
import '../../models/selah_languages_controller.dart';
import '../../services/selah_auth.dart';
import '../../services/selah_account_state.dart';
import '../../services/selah_consent_service.dart';
import '../../services/selah_developer_access.dart';
import '../../services/selah_internal_preview_client.dart';
import '../../services/selah_photo_service.dart';
import '../../services/selah_profile_service.dart';
import '../../services/selah_seeker_details_service.dart';
import 'article9_consent_screen.dart';
import '../profile/selah_photo_batch_flow.dart';
import '../../state/app_state.dart';
import '../../theme/selah_colors.dart';
import '../../theme/selah_text.dart';
import '../../widgets/flexibility_choice.dart';
import '../../widgets/onboarding_scaffold.dart';
import '../../widgets/selah_onboarding_choice_card.dart';
import '../../widgets/privacy_indicator.dart';
import '../../widgets/selah_state_widgets.dart';
import '../../widgets/selah_loading.dart';
import 'bio_onboarding_flow.dart';
import 'onboarding_stage_intro_screen.dart';
import 'seeker_setup_navigation.dart';

class Chapter2Flow extends StatefulWidget {
  final String? gender;
  final bool devPreview;

  const Chapter2Flow({
    super.key,
    required this.gender,
    this.devPreview = false,
  });

  @override
  State<Chapter2Flow> createState() => _Chapter2FlowState();
}

class _Chapter2FlowState extends State<Chapter2Flow> {
  int _step = 0;
  bool _restoring = false;
  bool _saving = false;
  bool _leaving = false;
  String? _owner;
  late int _ownerGeneration;
  String? _restoreError;
  String? _saveError;
  // LOCK 4 replaces the former five faith prompts with one seven-screen flow.
  // Saved background fields remain untouched; LOCK 14 retires their prompts.
  static const int _faithStep = 21;
  static const int _marriageStep = 22;
  int _marriageInitialQuestion = 1;
  SelahMarriageValuesController? _marriageController;
  SelahLanguagesController? _languagesController;
  Map<String, dynamic> _faithProfileData = {};
  Map<String, dynamic> _savedPreferences = {};
  int _faithInitialQuestion = 1;
  SelahFaithProfileController? _faithController;

  SelahFaithProfileController get _faithFlowController =>
      _faithController ??= SelahFaithProfileController(
        canAct: () => _canProceed,
        read: () => selahFaithProfileAnswersFromDetails(_currentDetails),
        save: (answers) async {
          if (!_canProceed ||
              _step != _faithStep ||
              ModalRoute.of(context)?.isCurrent != true) {
            return false;
          }
          final details = selahApplyFaithProfileAnswers(
            _currentDetails,
            answers,
          );
          _applySavedDetails(details);
          return _persistCheckpoint(_faithStep);
        },
      );

  SelahMarriageValuesController get _marriageFlowController =>
      _marriageController ??= SelahMarriageValuesController(
        canAct: () => _canProceed,
        read: () => selahMarriageValuesAnswersFromDetails(_currentDetails),
        save: (answers) async {
          if (!_canProceed ||
              _step != _marriageStep ||
              ModalRoute.of(context)?.isCurrent != true) {
            return false;
          }
          _applySavedDetails(
            selahApplyMarriageValuesAnswers(_currentDetails, answers),
          );
          return _persistCheckpoint(_marriageStep);
        },
      );
  SelahLanguagesController get _languagesFlowController =>
      _languagesController ??= SelahLanguagesController(
        canAct: () => _canProceed,
        read: () => _currentDetails.languages,
        save: (values) async {
          if (!_canProceed ||
              _step != 18 ||
              ModalRoute.of(context)?.isCurrent != true) {
            return false;
          }
          _languages = List.of(values);
          return _persistCheckpoint(18, finalCheckpoint: true);
        },
      );

  @override
  void dispose() {
    _faithController?.dispose();
    _marriageController?.dispose();
    _languagesController?.dispose();
    super.dispose();
  }

  // Latch the requested mode. Revocation must never turn this route into a
  // live persistence path while an old preview callback is still mounted.
  bool get _devPreview => widget.devPreview;
  bool get _canProceed =>
      mounted &&
      !_leaving &&
      (!_devPreview || SelahDeveloperAccess.canUseDeveloperTools) &&
      (_devPreview ||
          (_owner != null &&
              SelahAuth.currentUser?.id == _owner &&
              SelahAccountState.isCurrent(_owner!, _ownerGeneration)));

  final List<String> _photos = [];
  String? _location;
  String? _distancePref;
  TrafficLight? _distanceFlex;

  String? _christianFamily;
  String? _christianDenomination;
  String _christianDenominationOther = '';
  bool _showChristianTraditionOnProfile = false;
  String? _churchPreferenceScope;
  List<String> _selectedChristianFamilies = [];
  bool _churchHardRequirement = false;
  TrafficLight? _traditionOutsideFlex;

  String? _faithJourney;
  TrafficLight? _faithJourneyFlex;

  String? _countryOfBirth;
  List<String> _countryPrefs = [];
  bool _countrySkipped = false;
  TrafficLight? _countryFlex;

  String? _nationality;
  List<String> _nationalityPrefs = [];
  bool _nationalitySkipped = false;
  TrafficLight? _nationalityFlex;

  String? _ethnicity;
  List<String> _ethnicityPrefs = [];
  bool _ethnicitySkipped = false;
  TrafficLight? _ethnicityFlex;

  List<String> _languages = [];
  List<String> _languagePrefs = [];
  bool _languageSkipped = false;
  TrafficLight? _languageFlex;

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
    _location = AppState.instance.location;
    if (_devPreview) _photos.addAll(AppState.instance.photos);
    if (!_devPreview) _restoreSavedProgress();
  }

  Future<void> _restoreSavedProgress() async {
    setState(() => _restoring = true);
    try {
      final results = await Future.wait<dynamic>([
        SelahSeekerDetailsService.fetchOwn(
          expectedUserId: _owner,
          throwOnError: true,
        ),
        SelahPhotoService.fetchOwnPhotos(
          expectedUserId: _owner,
          throwOnError: true,
        ),
        SelahConsentService.currentArticle9Decision(
          expectedUserId: _owner,
          throwOnError: true,
        ),
      ]).timeout(const Duration(seconds: 10));
      if (!_canProceed) throw StateError('Account changed.');

      final details = results[0] as SeekerDetails?;
      final photos = results[1] as List<String>;
      final consentDecision = results[2] as bool?;
      _photos
        ..clear()
        ..addAll(photos);
      _article9Consent = consentDecision;
      if (details != null) _applySavedDetails(details);
      _step = _firstIncompleteStep();
      setState(() {
        _restoring = false;
        _restoreError = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _restoring = false;
          _restoreError =
              'Your saved profile could not be loaded. Try again before continuing.';
        });
      }
    }
  }

  TrafficLight? _light(Object? value) => switch (value) {
    'green' => TrafficLight.green,
    'yellow' => TrafficLight.yellow,
    'red' => TrafficLight.red,
    _ => null,
  };

  void _applySavedDetails(SeekerDetails details) {
    _christianFamily = details.christianFamily;
    _christianDenomination = details.christianDenomination;
    _christianDenominationOther = details.christianDenominationOther ?? '';
    _showChristianTraditionOnProfile = details.showChristianTraditionOnProfile;
    _faithJourney = details.faithJourney;
    _countryOfBirth = details.countryOfBirth;
    _nationality = details.nationality;
    _ethnicity = details.ethnicity;
    _languages = List<String>.from(details.languages);

    final p = details.preferences;
    _savedPreferences = Map<String, dynamic>.from(p);
    final faithProfile = p['faith_profile'];
    _faithProfileData = faithProfile is Map
        ? Map<String, dynamic>.from(faithProfile)
        : {};
    final location = p['location'] as Map?;
    _distancePref = selahNameFor(
      selahLocationPreferences,
      location?['preference'] as String?,
    );
    _distanceFlex = _light(location?['flexibility']);

    final church = p['church_background'] as Map?;
    final scope = church?['scope'] as String?;
    _churchPreferenceScope = scope == null
        ? null
        : selahChurchPreferenceScopeLabels[scope];
    final familyCodes = church?['family_codes'];
    if (familyCodes is List) {
      _selectedChristianFamilies = [
        for (final code in familyCodes.whereType<String>())
          ?selahChristianFamilyForCode(code)?.label,
      ];
    }
    _churchHardRequirement = church?['hard_requirement'] == true;
    _traditionOutsideFlex = _light(church?['outside_flexibility']);
    _faithJourneyFlex = _light((p['faith_journey'] as Map?)?['flexibility']);

    _restoreReferencePreference(
      p['country_of_birth'],
      labelFor: (code) => selahNameFor([
        for (final country in selahCountries)
          SelahRefItem(country.code, country.name),
      ], code),
      assignValues: (values) => _countryPrefs = values,
      assignSkipped: (value) => _countrySkipped = value,
      assignLight: (value) => _countryFlex = value,
    );
    _restoreReferencePreference(
      p['nationality'],
      labelFor: (code) {
        for (final country in selahCountries) {
          if (country.code == code) return country.nationality;
        }
        return null;
      },
      assignValues: (values) => _nationalityPrefs = values,
      assignSkipped: (value) => _nationalitySkipped = value,
      assignLight: (value) => _nationalityFlex = value,
    );
    _restoreReferencePreference(
      p['ethnicity'],
      labelFor: (code) => selahNameFor(selahEthnicities, code),
      assignValues: (values) => _ethnicityPrefs = values,
      assignSkipped: (value) => _ethnicitySkipped = value,
      assignLight: (value) => _ethnicityFlex = value,
    );
    _restoreReferencePreference(
      p['languages'],
      labelFor: (code) => selahNameFor(selahLanguages, code),
      assignValues: (values) => _languagePrefs = values,
      assignSkipped: (value) => _languageSkipped = value,
      assignLight: (value) => _languageFlex = value,
    );
  }

  void _restoreReferencePreference(
    Object? raw, {
    required String? Function(String code) labelFor,
    required ValueChanged<List<String>> assignValues,
    required ValueChanged<bool> assignSkipped,
    required ValueChanged<TrafficLight?> assignLight,
  }) {
    final map = raw as Map?;
    final values = <String>[];
    final preferred = map?['preferred'];
    if (preferred is List) {
      for (final code in preferred.whereType<String>()) {
        final label = labelFor(code);
        if (label != null) values.add(label);
      }
    }
    assignValues(values);
    assignSkipped(map?['skipped'] == true);
    assignLight(_light(map?['flexibility']));
  }

  SelahBackgroundVariant get _background {
    if (widget.gender == 'male') return SelahBackgroundVariant.male;
    if (widget.gender == 'female') return SelahBackgroundVariant.female;
    return SelahBackgroundVariant.neutral;
  }

  void _goto(int step) {
    if (!_canProceed || _saving) return;
    setState(() => _step = step);
  }

  SeekerDetails get _currentDetails => SeekerDetails(
    christianFamily: _christianFamily,
    christianDenomination: _christianDenomination,
    christianDenominationOther: _christianDenominationOther.trim().isEmpty
        ? null
        : _christianDenominationOther.trim(),
    faithJourney: _faithJourney,
    showChristianTraditionOnProfile: _showChristianTraditionOnProfile,
    countryOfBirth: _countryOfBirth,
    nationality: _nationality,
    ethnicity: _ethnicity,
    languages: _languages,
    preferences: _currentPreferences,
  );

  Map<String, dynamic> get _currentPreferences {
    final updated = SelahSeekerDetailsService.buildPreferences(
      distancePref: _distancePref,
      distanceFlex: _distanceFlex,
      traditionPreferenceScope: _churchPreferenceScope,
      selectedChristianFamilies: _selectedChristianFamilies,
      traditionHardRequirement: _churchHardRequirement,
      traditionOutsideFlex: _traditionOutsideFlex,
      faithJourneyFlex: _faithJourneyFlex,
      countryPrefs: _countryPrefs,
      countrySkipped: _countrySkipped,
      countryFlex: _countryFlex,
      nationalityPrefs: _nationalityPrefs,
      nationalitySkipped: _nationalitySkipped,
      nationalityFlex: _nationalityFlex,
      ethnicityPrefs: _ethnicityPrefs,
      ethnicitySkipped: _ethnicitySkipped,
      ethnicityFlex: _ethnicityFlex,
      languagePrefs: _languagePrefs,
      languageSkipped: _languageSkipped,
      languageFlex: _languageFlex,
    );
    return {
      ...selahMergeAskedProfilePreferences(_savedPreferences, updated),
      if (_faithProfileData.isNotEmpty) 'faith_profile': _faithProfileData,
    };
  }

  Future<void> _finishLater() async {
    if (!_canProceed || _saving || _restoring || _restoreError != null) return;
    setState(() {
      _saving = true;
      _saveError = null;
    });
    // Save the valid draft fields, without inventing answers to unfinished questions.
    final step = _step;
    bool saved = true;
    if (_photos.isNotEmpty) saved = await _persistCheckpoint(0);
    if (saved && (_location ?? '').trim().isNotEmpty) {
      saved = await _persistCheckpoint(1);
    }
    if (saved &&
        (_article9Consent == true || step == _marriageStep || step == 18)) {
      saved = await _persistCheckpoint(step < 4 ? 4 : step);
    }
    if (!mounted) return;
    if (saved && _canProceed) {
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

  Future<bool> _persistCheckpoint(
    int step, {
    bool finalCheckpoint = false,
  }) async {
    if (_devPreview) return true;
    if (!_canProceed) return false;
    if ((step == 0 || finalCheckpoint) &&
        !await SelahPhotoService.syncPhotosConfirmed(
          List.of(_photos),
          expectedUserId: _owner,
        )) {
      return false;
    }
    if (!_canProceed) return false;
    if ((step == 1 || finalCheckpoint) &&
        !await SelahProfileService.saveLocation(
          _location,
          expectedUserId: _owner,
        )) {
      return false;
    }
    if (!_canProceed) return false;
    // Respect refusal. The existing service cannot store special-category
    // details without consent, and the server still owns readiness.
    if (_article9Consent == true && (step >= 4 || finalCheckpoint)) {
      if (!await SelahSeekerDetailsService.saveDetails(
        _currentDetails,
        expectedUserId: _owner,
      )) {
        return false;
      }
    } else if (_article9Consent == false &&
        (step == _marriageStep || step == 18 || finalCheckpoint)) {
      final marriage = selahMarriageValuesAnswersFromDetails(_currentDetails);
      final location = _currentPreferences['location'];
      if (!await SelahSeekerDetailsService.saveNonFaithDetails(
        languages: step == 18 || finalCheckpoint ? List.of(_languages) : null,
        marriageValues: marriage.canSave ? marriage : null,
        locationPreference: location is Map
            ? Map<String, dynamic>.from(location)
            : null,
        expectedUserId: _owner,
      )) {
        return false;
      }
    }
    return _canProceed;
  }

  Future<void> _goToBioTransition({bool checkpointSaved = false}) async {
    if (!_canProceed || _saving || ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    setState(() => _saving = true);
    final saved =
        checkpointSaved ||
        await _persistCheckpoint(_step, finalCheckpoint: true);
    if (!mounted) return;
    if (!saved || !_canProceed || ModalRoute.of(context)?.isCurrent != true) {
      setState(() {
        _saving = false;
        _saveError = 'Your profile could not be saved. Please try again.';
      });
      return;
    }
    final gender = widget.gender;
    final devPreview = _devPreview;
    final owner = _owner;
    final ownerGeneration = _ownerGeneration;
    final signUpPreferences = Map<String, dynamic>.unmodifiable(
      _currentDetails.preferences,
    );
    var stageLeaving = false;
    AppState.instance.saveChapter2(
      photos: _photos,
      location: _location,
      christianTradition: _christianDenomination ?? _christianFamily,
    );
    setState(() => _leaving = true);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (stageContext) {
          void openBio() {
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
                builder: (_) => BioOnboardingFlow(
                  gender: gender,
                  devPreview: devPreview,
                  readSignUpPreferences: () =>
                      (devPreview
                          ? SelahDeveloperAccess.canUseDeveloperTools
                          : owner != null &&
                                SelahAuth.currentUser?.id == owner &&
                                SelahAccountState.isCurrent(
                                  owner,
                                  ownerGeneration,
                                ))
                      ? signUpPreferences
                      : const <String, dynamic>{},
                ),
              ),
            );
          }

          return OnboardingStageIntroScreen(
            stage: SeekerOnboardingStage.journeyBio,
            devPreview: devPreview,
            onDevSkip: devPreview ? openBio : null,
            onContinue: openBio,
          );
        },
      ),
    );
  }

  /// True once the user has been asked for Article 9 consent this session.
  /// Null means not yet asked.
  bool? _article9Consent;

  /// Only the LOCKed faith flow is skipped when consent is declined.
  /// Marriage values and the existing languages field remain on both paths.
  static const int _firstArticle9Step = 4;
  static const int _firstNonArticle9Step = _marriageStep;

  /// Shown once, immediately before the first special-category question.
  ///
  /// Consent has to precede collection, so this sits between the location
  /// block and the faith/background block rather than at the end of the
  /// chapter. Declining is a real path: it skips faith, then marriage and the
  /// languages screen complete the chapter. A decline that dead-ended would make the
  /// consent not freely given, and therefore not valid consent at all.
  Future<void> _askArticle9Consent() async {
    if (!_canProceed) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Article9ConsentScreen(
          background: _background,
          devPreview: _devPreview,
          onDecision: (granted) {
            if (!_canProceed) return;
            Navigator.of(context).pop();
            setState(() {
              _article9Consent = granted;
              _faithInitialQuestion = 1;
              _marriageInitialQuestion = 1;
              _step = granted ? _faithStep : _firstNonArticle9Step;
            });
          },
        ),
      ),
    );
  }

  Future<void> _next() async {
    if (!_canProceed ||
        ModalRoute.of(context)?.isCurrent != true ||
        _saving ||
        _restoring ||
        _restoreError != null ||
        (!_devPreview && !_canContinue)) {
      return;
    }
    setState(() {
      _saving = true;
      _saveError = null;
    });
    final saved = await _persistCheckpoint(_step);
    if (!mounted) return;
    setState(() => _saving = false);
    if (!saved || !_canProceed || ModalRoute.of(context)?.isCurrent != true) {
      setState(
        () => _saveError = 'Your profile could not be saved. Please try again.',
      );
      return;
    }
    // Gate on the way IN to the special-category block. Placed here rather
    // than on a step boundary so any future reordering that lands on step 4
    // still passes through it.
    if (_step == _firstArticle9Step - 1 && _article9Consent == null) {
      _askArticle9Consent();
      return;
    }
    if (_step == _firstArticle9Step - 1 && _article9Consent == false) {
      _goto(_firstNonArticle9Step);
      return;
    }

    if (_step == 3) {
      _faithInitialQuestion = 1;
      _goto(_faithStep);
      return;
    }
    if (_step == 18) {
      _goToBioTransition();
      return;
    }
    final index = _activeStepIds.indexOf(_step);
    if (index >= 0 && index + 1 < _activeStepIds.length) {
      _goto(_activeStepIds[index + 1]);
    }
  }

  void _devSkipCurrentQuestion() {
    if (!_devPreview || !_canProceed) return;
    if (_step == _firstArticle9Step - 1 && _article9Consent == null) {
      setState(() {
        // Developer preview never persists these answers, so it may bypass
        // the consent ceremony while still visiting each question in order.
        _article9Consent = true;
        _step = _faithStep;
      });
      return;
    }
    _next();
  }

  void _back() {
    if (!_canProceed || _saving) return;
    if (_step == 18) {
      _marriageInitialQuestion = 7;
      _goto(_marriageStep);
      return;
    }
    final index = _activeStepIds.indexOf(_step);
    if (index > 0) _goto(_activeStepIds[index - 1]);
  }

  int _firstIncompleteStep() {
    for (final step in _activeStepIds) {
      if (step == _faithStep && _article9Consent != true) return 3;
      if (!_isStepComplete(step)) return step;
    }
    return _activeStepIds.last;
  }

  bool get _canContinue =>
      !_saving &&
      !_restoring &&
      _restoreError == null &&
      _isStepComplete(_step);

  bool _isStepComplete(int step) {
    switch (step) {
      case 0:
        return _photos.length >= 3;
      case 1:
        return (_location ?? '').trim().isNotEmpty;
      case 2:
        return _distancePref != null;
      case 3:
        return _distanceFlex != null;
      case _faithStep:
        final faith = selahFaithProfileAnswersFromDetails(_currentDetails);
        return faith.requiredComplete && faith.characterCount <= 150;
      case _marriageStep:
        return selahMarriageValuesAnswersFromDetails(_currentDetails).canSave;
      case 18:
        return _languages.isNotEmpty;
      default:
        return false;
    }
  }

  // Article 9 refusal and explicit no-preference answers remove questions
  // from this person's path. The displayed position must describe that path,
  // rather than count skipped questions as completed work. Before the consent
  // decision, the possible full path remains the provisional denominator.
  List<int> get _activeStepIds => [
    0,
    1,
    2,
    3,
    if (_article9Consent != false) _faithStep,
    _marriageStep,
    18,
  ];

  int get _activeStepPosition {
    final index = _activeStepIds.indexOf(_step);
    return index < 0 ? _step + 1 : index + 1;
  }

  double get _progress => _activeStepPosition / _activeStepIds.length;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: SelahDeveloperAccess.authorizationChanges,
    builder: (context, _) {
      if (_devPreview && !SelahDeveloperAccess.canUseDeveloperTools) {
        return Scaffold(
          key: const ValueKey('chapter2_preview_denied'),
          backgroundColor: SelahColors.modalSheetSurface,
          body: const SizedBox.expand(),
        );
      }
      return _buildFlow(context);
    },
  );

  Widget _buildFlow(BuildContext context) {
    if (_restoring) {
      return const SelahLoading.fullScreen(
        label: 'Restoring your saved profile…',
      );
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
                    onPressed: _restoreSavedProgress,
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
    if (_step == _faithStep) {
      return SelahFaithProfileFlow(
        controller: _faithFlowController,
        initialQuestion: _faithInitialQuestion,
        onBack: _askArticle9Consent,
        onSaved: () {
          if (_canProceed && _step == _faithStep) {
            _marriageInitialQuestion = 1;
            _goto(_marriageStep);
          }
        },
      );
    }
    if (_step == _marriageStep) {
      return SelahMarriageValuesFlow(
        controller: _marriageFlowController,
        initialQuestion: _marriageInitialQuestion,
        onBack: () {
          if (!_canProceed) return;
          if (_article9Consent == false) {
            _askArticle9Consent();
          } else {
            _faithInitialQuestion = 7;
            _goto(_faithStep);
          }
        },
        onSaved: () {
          if (_canProceed) _goto(18);
        },
      );
    }
    if (_step == 18) {
      return SelahLanguagesFlow(
        controller: _languagesFlowController,
        onBack: _back,
        onSaved: () => _goToBioTransition(checkpointSaved: true),
      );
    }
    late String question;
    String? subtext;
    Widget content;
    PrivacyLevel privacy = PrivacyLevel.unlock;

    switch (_step) {
      case 0:
        question = _photos.isEmpty ? 'Add your photos' : 'Add more photos';
        subtext = _photos.isEmpty
            ? 'At least 3 required, up to 6. First photo becomes your main profile photo.'
            : 'Your first photo is already here. Complete your profile with at least 3 photos, up to 6.';
        privacy = PrivacyLevel.public;
        content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PhotoGrid(
              photos: _photos,
              devPreview: _devPreview,
              onChanged: (p) => setState(
                () => _photos
                  ..clear()
                  ..addAll(p),
              ),
            ),
            if (_photos.length < 3)
              const SelahDisabledHint(
                'Choose at least 3 photos so others can get to know you.',
              ),
          ],
        );
        break;
      case 1:
        question = 'Where do you currently live?';
        privacy = PrivacyLevel.public;
        content = _TextField(
          hint: 'Search for your city…',
          value: _location,
          onChanged: (v) => setState(() => _location = v),
        );
        break;
      // CHANGED 2026-08-01 (Founder decision): mileage bands replaced by
      // coarse location preferences.
      //
      // The old options — Within 10 / 25 / 50 / 100 miles — could never be
      // honoured. `_location` above is a free-text field; there is no
      // geocoding, no latitude, no longitude and no plan for any. A Seeker
      // answering "Within 10 miles" was giving SELAH something it had no
      // way to act on, and free text meant "London", "london" and "Greater
      // London" were three different places even for exact matching.
      //
      // Same city / region / country / anywhere needs no coordinates and
      // is closer to how families actually think about this.
      case 2:
        question = 'Where would you ideally like your future spouse to live?';
        content = _LargeSelect(
          options: selahLocationPreferenceNames,
          value: _distancePref,
          onChanged: (v) => setState(() => _distancePref = v),
        );
        break;
      // COPY FIXED 2026-08-01 alongside the change above. "Outside your
      // preferred distance" described mileage bands that no longer exist —
      // the question now sets a location scope, not a radius.
      case 3:
        question =
            'Would you be happy for Selah to introduce people outside your preferred area if they appear to be a strong match?';
        content = FlexibilityChoice(
          greenText: "Yes, I'd be happy to consider them.",
          yellowText: 'Maybe, depending on the person.',
          redText: "No, I'd prefer to stay within my preferred area.",
          value: _distanceFlex,
          onChanged: (v) => setState(() => _distanceFlex = v),
        );
        break;
      default:
        return const SizedBox.shrink();
    }

    final standaloneChoices = const {2, 3}.contains(_step);
    return OnboardingScaffold(
      background: _background,
      chapterName: 'Your Profile',
      frameContent: !standaloneChoices,
      chapterProgress: _progress,
      progressLabel: 'STEP $_activeStepPosition OF ${_activeStepIds.length}',
      question: question,
      subtext: subtext,
      privacy: privacy,
      fabActive: _canContinue,
      onContinue: _next,
      devPreview: _devPreview,
      onDevSkip: _devSkipCurrentQuestion,
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
            if (standaloneChoices)
              SelahOnboardingChoiceEntrance(
                key: ValueKey('profile_choice_entrance_$_step'),
                child: content,
              )
            else
              content,
          ],
        ),
      ),
    );
  }
}

class _TextField extends StatelessWidget {
  final String hint;
  final String? value;
  final ValueChanged<String> onChanged;
  const _TextField({
    required this.hint,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: TextEditingController(text: value)
        ..selection = TextSelection.collapsed(offset: (value ?? '').length),
      onChanged: onChanged,
      style: SelahText.body(size: 16, color: SelahColors.foreground),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: SelahText.body(size: 16, color: SelahColors.ink(0.24)),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: SelahColors.ink(0.24)),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: SelahColors.royalPurple),
        ),
      ),
    );
  }
}

class _LargeSelect extends StatelessWidget {
  final List<String> options;
  final String? value;
  final ValueChanged<String> onChanged;
  const _LargeSelect({
    required this.options,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: options.map((o) {
        final selected = value == o;
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: SelahOnboardingChoiceCard(
            key: ValueKey('profile_choice_$o'),
            label: o,
            selected: selected,
            onTap: () => onChanged(o),
          ),
        );
      }).toList(),
    );
  }
}

class _PhotoGrid extends StatefulWidget {
  final List<String> photos;
  final bool devPreview;
  final ValueChanged<List<String>> onChanged;
  const _PhotoGrid({
    required this.photos,
    required this.devPreview,
    required this.onChanged,
  });

  @override
  State<_PhotoGrid> createState() => _PhotoGridState();
}

class _PhotoGridState extends State<_PhotoGrid> {
  bool _uploading = false;
  String? _uploadError;

  Future<void> _addPhoto() async {
    if (widget.photos.length >= 6 ||
        _uploading ||
        (widget.devPreview && !SelahDeveloperAccess.canUseDeveloperTools)) {
      return;
    }
    setState(() {
      _uploading = true;
      _uploadError = null;
    });

    final result = await runSelahPhotoBatchFlow(
      context,
      remaining: 6 - widget.photos.length,
      localPreview:
          widget.devPreview ||
          (!SelahAuth.isSignedIn && SelahInternalPreviewClient.isActive),
      onProgress: (_) {},
    );
    if (!mounted) return;
    if (widget.devPreview && !SelahDeveloperAccess.canUseDeveloperTools) return;
    setState(() => _uploading = false);
    switch (result.outcome) {
      case SelahPhotoBatchOutcome.added:
        widget.onChanged([...widget.photos, ...result.urls]);
        return;
      case SelahPhotoBatchOutcome.cancelled:
        return; // not an error — nothing to show
      case SelahPhotoBatchOutcome.error:
        setState(() => _uploadError = result.memberErrorMessage);
        return;
    }
  }

  void _removePhoto(String url) {
    widget.onChanged(widget.photos.where((p) => p != url).toList());
  }

  @override
  Widget build(BuildContext context) {
    final tileCount = widget.photos.length + (widget.photos.length < 6 ? 1 : 0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
          ),
          itemCount: tileCount,
          itemBuilder: (context, index) {
            if (index < widget.photos.length) {
              final url = widget.photos[index];
              return GestureDetector(
                onTap: () => _removePhoto(url),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      // Uses SelahProfileImage for the shared error fallback, not for
                      // colour support — these are the user's OWN uploads and are
                      // always real Storage URLs. Swapped so "one place renders a
                      // profile photo" is literally true rather than nearly true.
                      child: SelahProfileImage(url),
                    ),
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.close, size: 14, color: Colors.white),
                      ),
                    ),
                    if (index == 0)
                      Positioned(
                        bottom: 6,
                        left: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Main',
                            style: TextStyle(fontSize: 10, color: Colors.white),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }
            // "Add photo" tile.
            return GestureDetector(
              onTap: _addPhoto,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: SelahColors.iconButtonBg,
                  border: Border.all(
                    color: SelahColors.iconButtonBorder,
                    width: 0.5,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: _uploading
                      ? SizedBox(width: 20, height: 20, child: SelahLoading())
                      : Icon(
                          Icons.add_photo_alternate_outlined,
                          color: SelahColors.ink(0.54),
                          size: 26,
                        ),
                ),
              ),
            );
          },
        ),
        if (_uploadError != null) ...[
          SizedBox(height: 10),
          SelahErrorBanner(
            message: _uploadError!,
            onRetry: () {
              setState(() => _uploadError = null);
              _addPhoto();
            },
            onDismiss: () => setState(() => _uploadError = null),
          ),
        ],
      ],
    );
  }
}
