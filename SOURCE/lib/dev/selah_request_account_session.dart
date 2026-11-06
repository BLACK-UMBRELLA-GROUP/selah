// Caller-owned account drafts for the protected Founder request-flow review.
// Retained editors use this adapter, never the authenticated member repository.
// This is not durable account data, admission, verification or payment proof.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Offset;

import '../data/selah_reference_data.dart';
import '../models/seeker_profile.dart';
import '../models/selah_faith_profile.dart';
import '../models/selah_faith_profile_details.dart';
import '../models/selah_marriage_values.dart';
import '../models/selah_marriage_values_details.dart';
import '../models/selah_shepherd_suggestion.dart';
import '../models/selah_sign_up_compatibility.dart';
import '../models/selah_your_values.dart';
import '../data/chapter3_categories.dart';
import '../screens/profile/compatibility_editors.dart';
import '../screens/profile/edit_profile_screen.dart';
import '../services/selah_onboarding_answers_service.dart'
    show SelahOnboardingAnswersSnapshot;
import '../services/selah_seeker_details_service.dart' show SeekerDetails;
import '../theme/selah_colors.dart';
import '../theme/selah_interaction_style.dart';

class SelahRequestAccountSession extends ChangeNotifier {
  SelahRequestAccountSession({
    required bool Function() canAct,
    required SelahDevPalette palette,
    required SelahHapticLevel hapticLevel,
    required bool goldEnabled,
    // Public constructor names intentionally do not expose private state.
    // ignore: prefer_initializing_formals
  }) : _canAct = canAct,
       _palette = palette.isLight ? SelahColors.currentDefaultPalette : palette,
       // ignore: prefer_initializing_formals
       _hapticLevel = hapticLevel,
       // ignore: prefer_initializing_formals
       _goldEnabled = goldEnabled {
    compatibility = SelahRequestCompatibilityRepository(
      canAct: () => current,
      readSignUpPreferences: () => details.preferences,
    );
  }

  final bool Function() _canAct;
  bool _revoked = false;
  bool _disposed = false;
  final _photos = <bool, List<String>>{};
  final _avatar = <bool, Offset>{};
  // One account-owned Introduction collection. A null value is an internal
  // resolved record, retained only to prevent suggesting the same pair again.
  final _localIntroductions = <String, Map<String, ShepherdSuggestion?>>{};
  late final SelahRequestCompatibilityRepository compatibility;
  SelahDevPalette _palette;
  SelahHapticLevel _hapticLevel;
  bool _goldEnabled;
  SeekerDetails _details = const SeekerDetails();
  bool _detailsSeeded = false;

  /// Denial is terminal for this review lifetime; it cannot become live or
  /// revive when an account changes A → B → A.
  bool get current {
    if (_revoked || _disposed) return false;
    try {
      if (_canAct()) return true;
    } catch (_) {
      // A failed admission check is denial, not permission to fall back.
    }
    _revoked = true;
    return false;
  }

  SelahDevPalette get palette => _palette;
  SelahHapticLevel get hapticLevel => _hapticLevel;
  bool get goldEnabled => _goldEnabled;
  List<String> photos(bool shepherd) =>
      List<String>.unmodifiable(_photos[shepherd] ?? const []);
  Offset avatar(bool shepherd) => _avatar[shepherd] ?? Offset.zero;

  SeekerDetails get details => current ? _details : const SeekerDetails();
  SelahFaithProfileAnswers get faithAnswers =>
      selahFaithProfileAnswersFromDetails(details);
  SelahMarriageValuesAnswers get marriageAnswers =>
      selahMarriageValuesAnswersFromDetails(details);

  List<ShepherdSuggestion> introductionsFor(String seekerId) => !current
      ? const []
      : List<ShepherdSuggestion>.unmodifiable(
          (_localIntroductions[seekerId]?.values ?? const [])
              .whereType<ShepherdSuggestion>()
              .toList()
              .reversed,
        );

  /// Privacy-neutral duplicate suppression, including resolved records.
  /// It never distinguishes seen, dismissed or another Seeker's response.
  bool hasIntroduction(String seekerId, String profileId) =>
      current &&
      (_localIntroductions[seekerId]?.containsKey(profileId) ?? false);

  static bool _introductionAllowed(bool Function() guard) {
    try {
      return guard();
    } catch (_) {
      return false;
    }
  }

  bool recordIntroduction({
    required String seekerId,
    required ShepherdSuggestion suggestion,
    required bool Function() canSuggest,
    required Iterable<String> Function() eligibleProfileIds,
  }) {
    final profileId = suggestion.profile.id;
    bool eligible() {
      try {
        return eligibleProfileIds().contains(profileId);
      } catch (_) {
        return false;
      }
    }

    if (!current ||
        !_introductionAllowed(canSuggest) ||
        seekerId.trim().isEmpty ||
        profileId.trim().isEmpty ||
        seekerId == profileId ||
        suggestion.suggestedBy.trim().isEmpty ||
        hasIntroduction(seekerId, profileId) ||
        !eligible()) {
      return false;
    }
    final next = suggestion.snapshot(unseen: true);
    if (!eligible() ||
        !current ||
        !_introductionAllowed(canSuggest) ||
        hasIntroduction(seekerId, profileId) ||
        !current) {
      return false;
    }
    (_localIntroductions[seekerId] ??= {})[profileId] = next;
    notifyListeners();
    return true;
  }

  bool markIntroductionsSeen(
    String seekerId, {
    required bool Function() canRead,
  }) {
    if (!current || !_introductionAllowed(canRead)) return false;
    final records = _localIntroductions[seekerId];
    if (records == null) return false;
    final next = <String, ShepherdSuggestion>{
      for (final entry in records.entries)
        if (entry.value case final suggestion? when suggestion.unseen)
          entry.key: suggestion.snapshot(unseen: false),
    };
    if (next.isEmpty ||
        !current ||
        !_introductionAllowed(canRead) ||
        !current) {
      return false;
    }
    records.addAll(next);
    notifyListeners();
    return true;
  }

  bool dismissIntroduction(
    String seekerId,
    String profileId, {
    required bool Function() canDismiss,
  }) {
    if (!current || !_introductionAllowed(canDismiss)) return false;
    final records = _localIntroductions[seekerId];
    final previous = records?[profileId];
    if (previous == null ||
        !current ||
        !_introductionAllowed(canDismiss) ||
        !identical(records?[profileId], previous) ||
        !current) {
      return false;
    }
    records![profileId] = null;
    notifyListeners();
    return true;
  }

  /// Seeds the existing details owner once for an isolated local review.
  /// This never infers new answers from old Chapter 2 values.
  bool seedDetails(SeekerDetails value) {
    if (!current || _detailsSeeded) return false;
    final detached = _copyDetails(value);
    if (!current) return false;
    _details = detached;
    _detailsSeeded = true;
    return true;
  }

  bool saveFaithProfile(SelahFaithProfileAnswers answers) {
    if (!current || !answers.canSave) return false;
    final next = _copyDetails(selahApplyFaithProfileAnswers(_details, answers));
    if (!current) return false;
    _details = next;
    _detailsSeeded = true;
    notifyListeners();
    return true;
  }

  /// Consent Skip clears only this local faith collection. It is not a
  /// backend withdrawal and does not discard unrelated profile/bank answers.
  bool clearFaithProfile() {
    if (!current) return false;
    final previous = _details;
    if (previous.christianFamily == null &&
        previous.christianDenomination == null &&
        previous.christianDenominationOther == null &&
        previous.faithJourney == null &&
        !previous.showChristianTraditionOnProfile &&
        !previous.preferences.containsKey('faith_profile') &&
        !previous.preferences.containsKey('church_background')) {
      return true;
    }
    final preferences = Map<String, dynamic>.from(previous.preferences)
      ..remove('faith_profile')
      ..remove('church_background');
    final next = _copyDetails(
      SeekerDetails(
        countryOfBirth: previous.countryOfBirth,
        nationality: previous.nationality,
        ethnicity: previous.ethnicity,
        languages: previous.languages,
        preferences: preferences,
      ),
    );
    if (!current) return false;
    _details = next;
    _detailsSeeded = true;
    notifyListeners();
    return true;
  }

  bool saveMarriageValues(SelahMarriageValuesAnswers answers) {
    if (!current || !answers.canSave) return false;
    final next = _copyDetails(
      selahApplyMarriageValuesAnswers(_details, answers),
    );
    if (!current) return false;
    _details = next;
    _detailsSeeded = true;
    notifyListeners();
    return true;
  }

  bool saveLanguages(List<String> value) {
    if (!current ||
        value.isEmpty ||
        value.any((item) => !selahLanguageNames.contains(item))) {
      return false;
    }
    final previous = _details;
    final next = _copyDetails(
      SeekerDetails(
        christianFamily: previous.christianFamily,
        christianDenomination: previous.christianDenomination,
        christianDenominationOther: previous.christianDenominationOther,
        faithJourney: previous.faithJourney,
        showChristianTraditionOnProfile:
            previous.showChristianTraditionOnProfile,
        countryOfBirth: previous.countryOfBirth,
        nationality: previous.nationality,
        ethnicity: previous.ethnicity,
        languages: value.toSet().toList(growable: false),
        preferences: previous.preferences,
      ),
    );
    if (!current) return false;
    _details = next;
    _detailsSeeded = true;
    notifyListeners();
    return true;
  }

  static SeekerDetails _copyDetails(SeekerDetails value) {
    dynamic freeze(dynamic item) {
      if (item is Map) {
        return Map<String, dynamic>.unmodifiable(
          item.map((key, nested) => MapEntry(key as String, freeze(nested))),
        );
      }
      if (item is List) return List<dynamic>.unmodifiable(item.map(freeze));
      return item;
    }

    return SeekerDetails(
      christianFamily: value.christianFamily,
      christianDenomination: value.christianDenomination,
      christianDenominationOther: value.christianDenominationOther,
      faithJourney: value.faithJourney,
      showChristianTraditionOnProfile: value.showChristianTraditionOnProfile,
      countryOfBirth: value.countryOfBirth,
      nationality: value.nationality,
      ethnicity: value.ethnicity,
      languages: List.unmodifiable(value.languages),
      preferences: freeze(value.preferences) as Map<String, dynamic>,
    );
  }

  bool seedPhotos(bool shepherd, List<String> value) {
    if (!current || _photos.containsKey(shepherd) || !_localPhotos(value)) {
      return false;
    }
    _photos[shepherd] = List.of(value);
    return true;
  }

  bool setPhotos(bool shepherd, List<String> value) {
    if (!current || !_localPhotos(value) || value.isEmpty) return false;
    _photos[shepherd] = List.of(value);
    notifyListeners();
    return true;
  }

  bool setAvatar(bool shepherd, Offset value) {
    if (!current || !value.dx.isFinite || !value.dy.isFinite) return false;
    _avatar[shepherd] = Offset(
      value.dx.clamp(-1.0, 1.0).toDouble(),
      value.dy.clamp(-1.0, 1.0).toDouble(),
    );
    notifyListeners();
    return true;
  }

  bool setPalette(SelahDevPalette value) {
    if (!current || value.isLight) return false;
    if (value == _palette) return true;
    _palette = value;
    notifyListeners();
    return true;
  }

  bool setHapticLevel(SelahHapticLevel value) {
    if (!current) return false;
    if (value == _hapticLevel) return true;
    _hapticLevel = value;
    notifyListeners();
    return true;
  }

  bool setGoldEnabled(bool value) {
    if (!current) return false;
    if (value == _goldEnabled) return true;
    _goldEnabled = value;
    notifyListeners();
    return true;
  }

  SeekerProfile ownProfile(bool shepherd) => SeekerProfile(
    id: shepherd ? 'draft-own-shepherd' : 'draft-self',
    firstName: shepherd ? 'David' : 'James',
    surnameLine: shepherd ? 'Okafor' : 'Carter',
    age: shepherd ? 54 : 30,
    city: 'London',
    gender: 'male',
    photos: photos(shepherd),
    faithProfile: shepherd ? null : faithAnswers,
    marriageValues: shepherd ? null : marriageAnswers,
    faithDenominationText: shepherd ? null : details.christianDenomination,
  );

  static bool _localPhotos(List<String> value) =>
      value.length <= 6 &&
      value.every((photo) => photo.startsWith('data:image/jpeg;base64,'));

  @override
  void dispose() {
    _disposed = true;
    _revoked = true;
    _photos.clear();
    _avatar.clear();
    _localIntroductions.clear();
    _details = const SeekerDetails();
    compatibility.close();
    super.dispose();
  }
}

/// Uses the retained editor contract with detached canonical question keys.
/// No server repository, Auth reads, preferences or AppState merging exist.
class SelahRequestCompatibilityRepository
    implements SelahCompatibilityEditorRepository {
  SelahRequestCompatibilityRepository({
    required bool Function() canAct,
    SelahSignUpPreferencesReader? readSignUpPreferences,
  })
    // Keep the caller's public guard parameter separate from private storage.
    // ignore: prefer_initializing_formals
    : _canAct = canAct,
       // ignore: prefer_initializing_formals
       _readSignUpPreferences = readSignUpPreferences;

  final bool Function() _canAct;
  final SelahSignUpPreferencesReader? _readSignUpPreferences;
  bool _closed = false;
  SelahCompatibilityDraft? _draft;
  bool _dealbreakersSaved = false;
  static const _owner = 'draft-self';

  bool get _current {
    if (_closed) return false;
    try {
      if (_canAct()) return true;
    } catch (_) {}
    _closed = true;
    return false;
  }

  @override
  String? get currentUserId => _current ? _owner : null;
  @override
  Map<String, dynamic> get signUpPreferences {
    if (!_current) return const {};
    try {
      return _readSignUpPreferences?.call() ?? const {};
    } catch (_) {
      _closed = true;
      return const {};
    }
  }

  @override
  int get accountGeneration => 0;

  /// Detached reads of this same local compatibility owner, never a second
  /// persisted Values store. Retired keys remain present in these raw reads.
  Map<String, dynamic> get rawAnswers => _current
      ? Map.unmodifiable(_draft?.copy().answers ?? const <String, dynamic>{})
      : const {};
  Map<String, Set<String>> get rawHardRequirements => _current
      ? Map.unmodifiable({
          for (final entry
              in _draft?.hardRequirements.entries ??
                  <MapEntry<String, Set<String>>>[])
            entry.key: Set<String>.unmodifiable(entry.value),
        })
      : const {};

  /// Completion of an actual successful save, including None. This belongs
  /// to the same local owner lifetime; raw legacy rules never imply it.
  bool get dealbreakersSaved => _current && _dealbreakersSaved;

  Future<bool> saveYourValuesPart(
    String partId,
    Map<String, dynamic> answers,
  ) async {
    if (!_current) return false;
    final previous =
        _draft?.copy() ??
        SelahCompatibilityDraft.fromSnapshot(
          gender: 'male',
          readSignUpPreferences: () => signUpPreferences,
        );
    final merged = selahMergeYourValuesPart(
      existing: previous.answers,
      gender: 'male',
      partId: partId,
      answers: answers,
      signUpPreferences: signUpPreferences,
    );
    if (merged == null || !_current) return false;
    previous.answers
      ..clear()
      ..addAll(merged);
    return save(_owner, previous);
  }

  Future<bool> saveDealbreakers(Map<String, Set<String>> requirements) async {
    if (!_current) return false;
    final previous = _draft?.copy();
    if (previous == null ||
        !chapter3Categories.every(
          (part) => selahYourValuesPartComplete(
            part,
            'male',
            previous.answers,
            signUpPreferences,
          ),
        )) {
      return false;
    }
    final merged = selahMergeDealbreakers(
      existing: previous.hardRequirements,
      requirements: requirements,
    );
    if (merged == null || !_current) return false;
    previous.hardRequirements
      ..clear()
      ..addAll(merged);
    final saved = await save(_owner, previous);
    if (!saved || !_current) return false;
    _dealbreakersSaved = true;
    return true;
  }

  @override
  bool isCurrentOwner(String userId, int generation) =>
      userId == _owner && generation == 0 && _current;

  @override
  Future<SelahOnboardingAnswersSnapshot?> load(String userId) async {
    if (!isCurrentOwner(userId, 0)) return null;
    return _draft?.toSnapshot();
  }

  @override
  Future<bool> save(String userId, SelahCompatibilityDraft draft) async {
    if (!isCurrentOwner(userId, 0) || draft.gender != 'male') return false;
    final detached = draft.copy(readSignUpPreferences: () => signUpPreferences);
    if (!isCurrentOwner(userId, 0)) return false;
    _draft = detached;
    return true;
  }

  void close() {
    _closed = true;
    _draft = null;
    _dealbreakersSaved = false;
  }
}
