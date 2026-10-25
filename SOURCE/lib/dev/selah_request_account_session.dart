// Caller-owned account drafts for the protected Founder request-flow review.
// Retained editors use this adapter, never the authenticated member repository.
// This is not durable account data, admission, verification or payment proof.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Offset;

import '../models/seeker_profile.dart';
import '../screens/profile/compatibility_editors.dart';
import '../screens/profile/edit_profile_screen.dart';
import '../services/selah_onboarding_answers_service.dart'
    show SelahOnboardingAnswersSnapshot;
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
    compatibility = SelahRequestCompatibilityRepository(canAct: () => current);
  }

  final bool Function() _canAct;
  bool _revoked = false;
  bool _disposed = false;
  final _photos = <bool, List<String>>{};
  final _avatar = <bool, Offset>{};
  late final SelahRequestCompatibilityRepository compatibility;
  SelahDevPalette _palette;
  SelahHapticLevel _hapticLevel;
  bool _goldEnabled;

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
    firstName: shepherd ? 'Hassan' : 'Adam',
    surnameLine: shepherd ? 'Rahman' : 'Khan',
    age: shepherd ? 54 : 30,
    city: 'London',
    gender: 'male',
    photos: photos(shepherd),
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
    compatibility.close();
    super.dispose();
  }
}

/// Uses the retained editor contract with detached canonical question keys.
/// No server repository, Auth reads, preferences or AppState merging exist.
class SelahRequestCompatibilityRepository
    implements SelahCompatibilityEditorRepository {
  SelahRequestCompatibilityRepository({required bool Function() canAct})
    // Keep the caller's public guard parameter separate from private storage.
    // ignore: prefer_initializing_formals
    : _canAct = canAct;

  final bool Function() _canAct;
  bool _closed = false;
  SelahCompatibilityDraft? _draft;
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
  int get accountGeneration => 0;
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
    final detached = draft.copy();
    if (!isCurrentOwner(userId, 0)) return false;
    _draft = detached;
    return true;
  }

  void close() {
    _closed = true;
    _draft = null;
  }
}
