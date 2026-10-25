// The disk home for photo bytes — Phase 1 of the ratified On-Device
// Data & Performance Review (inherited decision 169, Founder-approved 2026-08-15).
//
// WHY IT EXISTS. Photos live in a private bucket behind signed URLs, and
// every fetch re-signs — same bytes, different URL string. Flutter's
// image cache keys on the URL, so it missed on every refresh, and it is
// RAM-only, so every cold start re-downloaded the entire Browse deck
// (~290 paths on a full deck, per selah_photo_service.dart's own
// history). This cache keys on [keyFor] — the URL with its token
// stripped — which is stable across re-signing, so the same photo is
// fetched from the network once per TTL window instead of once per
// glance.
//
// THE ONE RULE (from the review): a cached value may PAINT, never
// decide. Nothing here gates anything; it is bytes for pixels only.
//
// SELF-MANAGING, five ways — the Founder's requirement is that no user
// ever clears a cache by hand:
//   1. TTL      — stalePeriod 7 days, matching the signed-URL lifetime.
//   2. Size     — LRU cap of 500 objects, enforced by the cache manager;
//                 lives in the OS cache directory, which iOS excludes
//                 from iCloud backup and may purge under storage
//                 pressure. Both are features here, not risks.
//   3. Recovery — every operation is try/caught; any failure is a cache
//                 MISS answered by the network, never an error a person
//                 sees. Same rule SelahLocalPrefs.init() follows.
//   4. Schema   — [_schemaVersion] against SelahLocalPrefs; a mismatch
//                 after an app update wipes once at startup, so "clear
//                 data after updating" can never become user folklore.
//   5. Events   — sign-out and account deletion empty everything
//                 (selah_auth.dart calls [clearForSignOut]); blocking a
//                 user evicts their photos immediately (browse_screen's
//                 block path calls [evictUrls]); changing your own
//                 photos self-invalidates, because every upload mints a
//                 new storage path and therefore a new key.
//
// WHAT IS DELIBERATELY NOT HERE: signed URLs on disk (a signed URL is a
// bearer capability — the session memo for those is in-memory in
// selah_photo_service.dart), structured profile data of any kind, and
// any notion of "clear cache" in Settings.

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/painting.dart' show PaintingBinding;
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import 'selah_local_prefs.dart';

class SelahImageCache {
  SelahImageCache._();

  /// Bump when the cache's shape or keying changes; init() then wipes
  /// the old generation once instead of leaving it to rot.
  static const int _schemaVersion = 1;

  static CacheManager? _manager;

  /// One manager, lazily built, shared by every photo in the app —
  /// SelahProfileImage renders through it and Browse's precache warms it,
  /// so the prefetch and the render can never disagree about where bytes
  /// live.
  static CacheManager get manager => _manager ??= CacheManager(
    Config(
      'selahImages',
      stalePeriod: const Duration(days: 7),
      maxNrOfCacheObjects: 500,
    ),
  );

  /// The cache key for a display URL: everything before the query
  /// string. A re-signed URL differs only in its ?token=…, so this is
  /// stable across signing rounds — the entire point of the cache.
  /// (selah_photo_service._storagePathFromUrl does a bucket-aware version
  /// of the same idea for database rows; for cache keying, sans-query is
  /// sufficient and works for any host, including dev image URLs.)
  static String keyFor(String url) => url.split('?').first;

  /// Startup schema check — called from main() WITHOUT await, so frame
  /// one never waits on it. A wipe here is rare (app updates that change
  /// cache shape) and invisible (the next fetch simply misses).
  static Future<void> init() async {
    try {
      if (SelahLocalPrefs.cacheSchemaVersion != _schemaVersion) {
        await manager.emptyCache();
        await SelahLocalPrefs.setCacheSchemaVersion(_schemaVersion);
      }
    } catch (e) {
      debugPrint(
        'SELAH: image cache schema check failed — continuing '
        'without a wipe. $e',
      );
    }
  }

  /// Sign-out / account deletion: both stores emptied — the disk cache
  /// holds photos the OLD account was allowed to see, and the in-RAM
  /// cache holds decoded copies of the same. The next account inherits
  /// neither. Same contract as every other clearForSignOut in this
  /// codebase.
  static Future<void> clearForSignOut() async {
    try {
      PaintingBinding.instance.imageCache
        ..clear()
        ..clearLiveImages();
      await manager.emptyCache();
    } catch (e) {
      debugPrint('SELAH: image cache clear on sign-out failed — $e');
    }
  }

  /// Immediate disk eviction for a specific person's photos — called
  /// when the user blocks someone. The server stops signing their URLs
  /// from that moment; this makes the local copy die with the
  /// relationship instead of with the TTL. RAM copies are left to the
  /// process (they die on app close and nothing renders them once the
  /// person is gone from every list).
  static Future<void> evictUrls(Iterable<String> photoUrls) async {
    for (final url in photoUrls) {
      try {
        await manager.removeFile(keyFor(url));
      } catch (_) {
        // Already absent is the desired state.
      }
    }
  }
}
