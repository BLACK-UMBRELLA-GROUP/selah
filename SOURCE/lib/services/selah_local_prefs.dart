// First-frame presentation preferences, owned by one authenticated account.
// SharedPreferences is not a secure store: no tokens, DOB or signup drafts.
// A legacy cache without an owner cannot be attributed to the next sign-in.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SelahLocalPrefs {
  SelahLocalPrefs._();

  static const _kOwner = 'selah.cached_account_owner';
  static const _kGender = 'selah.cached_gender';
  static const _kFirstName = 'selah.cached_first_name';
  static const _kRole = 'selah.cached_role';
  static const _kAppLock = 'selah.app_lock_enabled';
  static const _kPromotionPolicy = 'selah.promotion_policy_v1';
  static const _kAppSurfaceStyle = 'selah.app_surface_style';
  static const _kAppPalette = 'selah.app_palette';
  static const _kAppPaletteRevision = 'selah.app_palette_revision';
  static const _kAppFont = 'selah.app_font';
  static const _kHapticLevel = 'selah.haptic_level';
  static const _kAppGold = 'selah.app_gold_enabled';
  static const _kAvatarAlignmentX = 'selah.avatar_alignment_x';
  static const _kAvatarAlignmentY = 'selah.avatar_alignment_y';
  static const _kFounderAppStyle = 'selah.founder_app_style';
  static const _kFounderPreviewRole = 'selah.founder_preview_role';
  // Device format metadata survives all account changes.
  static const _kCacheSchema = 'selah.cache_schema_version';
  static const _accountKeys = [
    _kGender,
    _kFirstName,
    _kRole,
    _kAppLock,
    _kPromotionPolicy,
    _kAppSurfaceStyle,
    _kAppPalette,
    _kAppPaletteRevision,
    _kAppFont,
    _kHapticLevel,
    _kAppGold,
    _kAvatarAlignmentX,
    _kAvatarAlignmentY,
    _kFounderAppStyle,
    _kFounderPreviewRole,
  ];

  static SharedPreferences? _prefs;
  static String? _accountOwner;
  static String? _persistenceOwner;
  static bool _hasBoundAccount = false;
  static int _bindingGeneration = 0;
  static final Map<String, Object> _values = {};
  static Future<void> _writes = Future<void>.value();

  static String? get accountOwner => _accountOwner;
  static bool get hasBoundAccount => _hasBoundAccount;
  static int get bindingGeneration => _bindingGeneration;

  /// A matching persisted owner is the only permitted cold-start restore.
  static bool canRestoreAccount(String userId) =>
      !_hasBoundAccount && _prefs?.getString(_kOwner) == userId;

  /// Initializes storage without exposing any previous account's values.
  /// Bind the restored Auth principal before restoring presentation state.
  static Future<void> init() async {
    await _writes;
    _bindingGeneration++;
    _hasBoundAccount = false;
    _accountOwner = null;
    _persistenceOwner = null;
    _values.clear();
    try {
      _prefs = await SharedPreferences.getInstance();
    } catch (_) {
      _prefs = null;
      debugPrint('SELAH: presentation preferences unavailable.');
    }
  }

  /// Changes the visible owner synchronously. Disk removals and writes share
  /// one queue; stale operations never erase or stamp a newer owner's cache.
  /// Only a matching persisted owner on first binding may restore values.
  static Future<void> bindAccount(String? userId) {
    if (_hasBoundAccount && _accountOwner == userId) return _writes;
    final prefs = _prefs;
    final preserve =
        !_hasBoundAccount &&
        userId != null &&
        prefs?.getString(_kOwner) == userId;
    final version = ++_bindingGeneration;
    _accountOwner = userId;
    _persistenceOwner = preserve ? userId : null;
    _hasBoundAccount = true;
    _values.clear();
    if (preserve && prefs != null) {
      for (final key in _accountKeys) {
        final value = prefs.get(key);
        if (value is String || value is bool) _values[key] = value!;
      }
    }
    return _enqueue(() async {
      if (prefs == null || version != _bindingGeneration) return;
      if (!preserve) {
        // Remove attribution first. A failed cleanup must never leave a
        // previous owner's stamp on values written by the next principal.
        if (!await prefs.remove(_kOwner)) {
          throw StateError('Preference owner removal failed.');
        }
        for (final key in _accountKeys) {
          if (version != _bindingGeneration) return;
          if (!await prefs.remove(key)) {
            throw StateError('Preference cleanup failed.');
          }
        }
      }
      if (version != _bindingGeneration) return;
      if (userId == null) {
        await prefs.remove(_kOwner);
      } else {
        if (!await prefs.setString(_kOwner, userId)) {
          throw StateError('Preference owner binding failed.');
        }
        if (version == _bindingGeneration) _persistenceOwner = userId;
      }
    });
  }

  static Future<void> _enqueue(Future<void> Function() operation) {
    final result = _writes.then((_) => operation()).catchError((Object _) {
      debugPrint('SELAH: presentation preference update could not be saved.');
    });
    _writes = result;
    return result;
  }

  static Future<void> _set(String key, Object? value) {
    // Pre-auth local previews can use ephemeral preferences, but can never
    // persist them or claim a pre-existing account's cache.
    if (value == null) {
      _values.remove(key);
    } else {
      _values[key] = value;
    }
    final owner = _accountOwner;
    final version = _bindingGeneration;
    final prefs = _prefs;
    if (!_hasBoundAccount || owner == null || prefs == null) {
      return Future<void>.value();
    }
    return _enqueue(() async {
      if (version != _bindingGeneration ||
          _accountOwner != owner ||
          _persistenceOwner != owner) {
        return;
      }
      if (value == null) {
        await prefs.remove(key);
      } else if (value is bool) {
        await prefs.setBool(key, value);
      } else {
        await prefs.setString(key, value as String);
      }
    });
  }

  static String? _string(String key) {
    final value = _values[key];
    return value is String && value.isNotEmpty ? value : null;
  }

  static String? get cachedGender {
    final value = _string(_kGender);
    return value == 'male' || value == 'female' ? value : null;
  }

  static void setCachedGender(String? value) => unawaited(
    _set(_kGender, value == 'male' || value == 'female' ? value : null),
  );

  static String? get cachedFirstName => _string(_kFirstName);
  static void setCachedFirstName(String? value) => unawaited(
    _set(
      _kFirstName,
      value == null || value.trim().isEmpty ? null : value.trim(),
    ),
  );

  static String? get cachedRole => _string(_kRole);
  static void setCachedRole(String? value) =>
      unawaited(_set(_kRole, value == null || value.isEmpty ? null : value));

  static double get cachedAvatarAlignmentY {
    final parsed = double.tryParse(_string(_kAvatarAlignmentY) ?? '');
    if (parsed == null || !parsed.isFinite) return 0;
    return parsed.clamp(-1.0, 1.0).toDouble();
  }

  static Future<void> setAvatarAlignmentY(double value) =>
      _set(_kAvatarAlignmentY, value.clamp(-1.0, 1.0).toDouble().toString());

  static double get cachedAvatarAlignmentX {
    final parsed = double.tryParse(_string(_kAvatarAlignmentX) ?? '');
    if (parsed == null || !parsed.isFinite) return 0;
    return parsed.clamp(-1.0, 1.0).toDouble();
  }

  static Future<void> setAvatarAlignmentX(double value) =>
      _set(_kAvatarAlignmentX, value.clamp(-1.0, 1.0).toDouble().toString());

  static bool get appLockEnabled => _values[_kAppLock] == true;
  static Future<void> setAppLockEnabled(bool value) => _set(_kAppLock, value);

  static String? get promotionPolicy => _string(_kPromotionPolicy);
  static Future<void> setPromotionPolicy(String value) =>
      _set(_kPromotionPolicy, value);
  static Future<void> clearPromotionPolicy() => _set(_kPromotionPolicy, null);

  static String? get cachedAppSurfaceStyleName => _string(_kAppSurfaceStyle);
  static Future<void> setCachedAppSurfaceStyleName(String? value) =>
      _set(_kAppSurfaceStyle, value);
  static String? get cachedAppPaletteName => _string(_kAppPalette);
  static Future<void> setCachedAppPaletteName(String? value) =>
      _set(_kAppPalette, value);
  static String? get cachedAppPaletteRevision => _string(_kAppPaletteRevision);
  static Future<void> setCachedAppPaletteRevision(String? value) =>
      _set(_kAppPaletteRevision, value);
  static String? get cachedAppFontName => _string(_kAppFont);
  static Future<void> setCachedAppFontName(String? value) =>
      _set(_kAppFont, value);
  static String? get cachedHapticLevelName => _string(_kHapticLevel);
  static Future<void> setCachedHapticLevelName(String? value) =>
      _set(_kHapticLevel, value);

  static bool get cachedAppGoldEnabled => _values[_kAppGold] == true;
  static Future<void> setCachedAppGoldEnabled(bool value) =>
      _set(_kAppGold, value);

  // Presentation choices only: neither preference grants Founder authority,
  // an account role, admission, paid access or permission to use real data.
  // The caller owns authorization and the separate account-generation guard.
  static String get cachedFounderAppStyleName =>
      _string(_kFounderAppStyle) == 'option1' ? 'option1' : 'request';

  static Future<void> setFounderAppStyleName(
    String value, {
    required String expectedOwner,
    required int expectedBindingGeneration,
  }) {
    if (value != 'request' && value != 'option1') {
      return Future<void>.value();
    }
    return _setOwnedPresentation(
      _kFounderAppStyle,
      value,
      expectedOwner: expectedOwner,
      expectedBindingGeneration: expectedBindingGeneration,
    );
  }

  static String get cachedFounderPreviewRole =>
      _string(_kFounderPreviewRole) == 'shepherd' ? 'shepherd' : 'seeker';

  static Future<void> setFounderPreviewRole(
    String value, {
    required String expectedOwner,
    required int expectedBindingGeneration,
  }) {
    if (value != 'seeker' && value != 'shepherd') {
      return Future<void>.value();
    }
    return _setOwnedPresentation(
      _kFounderPreviewRole,
      value,
      expectedOwner: expectedOwner,
      expectedBindingGeneration: expectedBindingGeneration,
    );
  }

  static Future<void> _setOwnedPresentation(
    String key,
    String value, {
    required String expectedOwner,
    required int expectedBindingGeneration,
  }) {
    // Check before touching memory as well as the existing queued disk guard.
    // The same owner returning after A -> B -> A is a different binding.
    if (!_hasBoundAccount ||
        expectedOwner.isEmpty ||
        _accountOwner != expectedOwner ||
        _bindingGeneration != expectedBindingGeneration) {
      return Future<void>.value();
    }
    return _set(key, value);
  }

  static int get cacheSchemaVersion => _prefs?.getInt(_kCacheSchema) ?? 0;
  static Future<void> setCacheSchemaVersion(int version) => _enqueue(() async {
    await _prefs?.setInt(_kCacheSchema, version);
  });

  /// Drops account preferences and ownership, preserving device format data.
  static Future<void> clear() {
    _hasBoundAccount = false;
    return bindAccount(null);
  }
}
