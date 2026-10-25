import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show PaintingBinding;

import '../dev/selah_dev_scenario.dart';
import '../state/app_state.dart';
import '../theme/selah_app_gold_style.dart';
import '../theme/selah_colors.dart';
import '../theme/selah_interaction_style.dart';
import '../theme/selah_text.dart';
import 'selah_app_lock.dart';
import 'selah_consent_service.dart';
import 'selah_image_cache.dart';
import 'selah_hidden_profile_store.dart';
import 'selah_internal_preview_client.dart';
import 'selah_local_prefs.dart';
import 'selah_photo_service.dart';
import 'selah_promotion_engine.dart';
import 'selah_unlock_service.dart';

/// Owns the lifetime of member display state independently of developer access.
/// Callers await synchronization before starting account work, then capture the
/// generation and check [isCurrent] before publishing an asynchronous result.
abstract final class SelahAccountState {
  static String? _userId;
  static int _generation = 0;
  static bool _initialized = false;
  static bool _signingOut = false;
  static Future<void> _cleanup = Future<void>.value();

  static String? get userId => _userId;
  static int get generation => _generation;
  static bool get isSigningOut => _signingOut;

  @visibleForTesting
  static Future<void> Function()? clearImagesForTesting;

  /// Each widget test owns a FakeAsync zone. Do not retain one test's queued
  /// cleanup Future in the next zone. Compiled production calls are no-ops.
  @visibleForTesting
  static void resetForTesting() {
    assert(() {
      _generation++;
      _userId = null;
      _initialized = false;
      _signingOut = false;
      _cleanup = Future<void>.value();
      SelahInternalPreviewClient.bindAccount(null);
      return true;
    }());
  }

  static bool isCurrent(String expectedUserId, int expectedGeneration) =>
      !_signingOut &&
      _userId == expectedUserId &&
      _generation == expectedGeneration;

  static Future<void> synchronize(String? userId) {
    // A token refresh delivered while logout is pending cannot rehydrate the
    // principal whose display state has already been removed.
    if (_signingOut && userId != null) return _cleanup;
    if (_initialized && _userId == userId) {
      final preferences = SelahLocalPrefs.bindAccount(userId);
      return Future.wait([_cleanup, preferences]).then((_) {});
    }
    return _changeAccount(userId);
  }

  static Future<void> beginSignOut() {
    _signingOut = true;
    return _changeAccount(null);
  }

  static void endSignOutAttempt() => _signingOut = false;

  static Future<void> _changeAccount(String? userId) {
    final preserveDiskImages =
        !_initialized &&
        userId != null &&
        SelahLocalPrefs.canRestoreAccount(userId);
    _initialized = true;
    _userId = userId;
    final version = ++_generation;
    SelahInternalPreviewClient.bindAccount(userId);
    // Binding first makes all following callbacks observe the new owner.
    final preferences = SelahLocalPrefs.bindAccount(userId);
    AppState.instance.resetForAccountChange();
    SelahUnlockService.clearForSignOut();
    SelahConsentService.clearForSignOut();
    SelahPhotoService.clearUrlMemoForSignOut();
    SelahHiddenProfileStore.clearForAccountChange();
    SelahPromotionEngine.instance.resetForAccountChange();
    SelahAppLock.instance.clearForSignOut();
    SelahDevScenario.instance.reset();
    SelahColors.restoreAppSurfaceStyle(null);
    SelahColors.restoreAppPalette(null);
    SelahText.restoreAppFont(null);
    SelahInteractionStyle.restoreHapticLevel(null);
    SelahAppGoldStyle.instance.restore(false);
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();

    // An already-running image eviction must finish before the next account
    // can start fetching. Queued stale evictions are skipped altogether.
    final result = _cleanup.then((_) async {
      await preferences;
      if (version != _generation || preserveDiskImages) return;
      await (clearImagesForTesting ?? SelahImageCache.clearForSignOut)();
    });
    _cleanup = result.catchError((Object _) {
      debugPrint('SELAH: account cache cleanup could not be completed.');
    });
    return _cleanup;
  }
}
