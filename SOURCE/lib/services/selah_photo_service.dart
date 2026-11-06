// Profile photo upload — OA-104. Wraps picking a photo from the device
// library and uploading it to the `profile-photos` Storage bucket
// (own-folder-only write per RLS: `{auth.uid()}/{filename}`), then
// syncing the resulting URLs into the `profile_photos` table so they
// survive beyond this session.
//
// PRIVATE BUCKET (2026-07-19, Fable review): the bucket was public,
// which contradicted IMAGE_HANDLING_CURRENT_VERSION_V1.md ("Originals
// never publicly accessible") — a public bucket serves objects by URL
// with no auth check at all. It is now private, and every display URL
// is a signed URL (7-day expiry — longer than any app session, short
// enough that a leaked URL dies). Storage read RLS mirrors the
// profile_photos table policy: own photos, or photos of an
// active+complete profile.
//
// Photo REMOVAL in the Chapter 2 picker only removes the URL from the
// in-memory list, not the underlying Storage object or table row — a
// deliberate v1 simplification (orphaned files are harmless in a
// preview build) rather than wiring delete permissions and re-ordering
// logic today. Worth cleaning up before a real launch.

import 'dart:convert';
import 'dart:io' show Platform, SocketException;
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart' show MethodChannel, PlatformException;
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show FileOptions, StorageException;
import '../main.dart';
import '../models/selah_initial_signup_draft.dart';
import 'selah_account_state.dart';
import 'selah_auth.dart';
import 'selah_internal_preview_client.dart';
import 'selah_profile_photo_processor.dart';

enum SelahPhotoOutcome { uploaded, cancelled, error }

/// Stable, privacy-safe failure categories for profile-photo support.
///
/// These values never contain filenames, Storage paths, member ids, exception
/// messages or photo metadata. They let the UI give useful recovery advice and
/// let an attached debug console distinguish an expired session from RLS,
/// network, processing and Storage failures without exposing private data.
enum SelahPhotoFailureKind {
  authentication,
  accessDenied,
  connection,
  processing,
  storage,
  unknown,
}

extension SelahPhotoFailureCopy on SelahPhotoFailureKind {
  String get referenceCode => switch (this) {
    SelahPhotoFailureKind.authentication => 'ZY-PH-01',
    SelahPhotoFailureKind.accessDenied => 'ZY-PH-02',
    SelahPhotoFailureKind.connection => 'ZY-PH-03',
    SelahPhotoFailureKind.processing => 'ZY-PH-04',
    SelahPhotoFailureKind.storage => 'ZY-PH-05',
    SelahPhotoFailureKind.unknown => 'ZY-PH-06',
  };

  String get memberMessage => switch (this) {
    SelahPhotoFailureKind.authentication =>
      'Your session has ended. Sign in again, then retry.',
    SelahPhotoFailureKind.accessDenied =>
      "Your account couldn't save photos. Please contact Selah Support.",
    SelahPhotoFailureKind.connection =>
      'Check your connection, then try adding the photos again.',
    SelahPhotoFailureKind.processing =>
      "One photo couldn't be prepared safely. Try a different photo.",
    SelahPhotoFailureKind.storage =>
      'Photo storage is temporarily unavailable. Please try again shortly.',
    SelahPhotoFailureKind.unknown =>
      "Those photos couldn't be added. Please try again.",
  };
}

class SelahPhotoResult {
  final SelahPhotoOutcome outcome;
  final String? url;
  final SelahPhotoFailureKind? failureKind;
  const SelahPhotoResult._(this.outcome, this.url, this.failureKind);

  const SelahPhotoResult.uploaded(String url)
    : this._(SelahPhotoOutcome.uploaded, url, null);
  const SelahPhotoResult.cancelled()
    : this._(SelahPhotoOutcome.cancelled, null, null);
  const SelahPhotoResult.error([
    SelahPhotoFailureKind kind = SelahPhotoFailureKind.unknown,
  ]) : this._(SelahPhotoOutcome.error, null, kind);
}

enum SelahPhotoSelectionOutcome { selected, cancelled, error }

class SelahPhotoSelectionResult {
  const SelahPhotoSelectionResult._(this.outcome, this.photos);

  const SelahPhotoSelectionResult.selected(List<Uint8List> photos)
    : this._(SelahPhotoSelectionOutcome.selected, photos);
  const SelahPhotoSelectionResult.cancelled()
    : this._(SelahPhotoSelectionOutcome.cancelled, const []);
  const SelahPhotoSelectionResult.error()
    : this._(SelahPhotoSelectionOutcome.error, const []);

  final SelahPhotoSelectionOutcome outcome;
  final List<Uint8List> photos;
}

class SelahPhotoService {
  SelahPhotoService._();

  static const String _bucket = 'profile-photos';
  static const MethodChannel _iosPhotoChannel = MethodChannel(
    'selah/profile_photo',
  );

  /// Signed-URL lifetime. 7 days: outlives any realistic app session
  /// (URLs are regenerated on every fetch anyway), short enough that a
  /// leaked URL expires.
  static const int _signedUrlExpirySeconds = 60 * 60 * 24 * 7;

  static Future<XFile?> _pickProfilePhoto() => ImagePicker().pickImage(
    source: ImageSource.gallery,
    maxWidth: SelahProfilePhotoProcessor.maxDimension.toDouble(),
    maxHeight: SelahProfilePhotoProcessor.maxDimension.toDouble(),
    imageQuality: SelahProfilePhotoProcessor.jpegQuality,
    // Profile photos do not need original EXIF metadata. On iOS this also
    // lets PHPicker provide the chosen image without broad library access.
    requestFullMetadata: false,
  );

  static Future<Uint8List> _readAndProcess(XFile picked) async {
    Uint8List? sourceBytes;
    try {
      sourceBytes = await picked.readAsBytes();
      // The picker normally returns a bounded JPEG/PNG. Process that directly
      // so supported iPhone photos do not depend on a second platform hop.
      // This is still fail-closed: only the newly encoded, verified JPEG can
      // leave this method; the picked bytes are never uploadable as-is.
      return await SelahProfilePhotoProcessor.process(sourceBytes);
    } on SelahProfilePhotoProcessingException {
      if (!Platform.isIOS) rethrow;
      // HEIC/HEIF is expected on iPhone and is deliberately handled below by
      // UIKit, which can decode it while Dart's image package cannot.
    } catch (_) {
      if (!Platform.isIOS) rethrow;
    }

    // Pass the bytes rather than asking native code to reopen PHPicker's
    // temporary path. iOS may retire that sandboxed file after picker return,
    // which made valid photos fail with ZY-PH-04 on a real device. UIKit
    // applies orientation, redraws into a fresh bitmap and emits a clean JPEG;
    // the Dart privacy processor then verifies the result once more.
    final arguments = <String, Object>{
      'path': picked.path,
      'maxDimension': SelahProfilePhotoProcessor.maxDimension,
      'quality': SelahProfilePhotoProcessor.jpegQuality,
      'data': ?sourceBytes,
    };
    final normalised = await _iosPhotoChannel.invokeMethod<Uint8List>(
      'normaliseProfilePhoto',
      arguments,
    );
    if (normalised == null || normalised.isEmpty) {
      throw const SelahProfilePhotoProcessingException(
        'native iOS normalisation failed',
      );
    }
    return SelahProfilePhotoProcessor.process(normalised);
  }

  /// Selects up to [limit] photos in one native picker pass and normalises
  /// them before the crop UI receives them. Nothing is uploaded here: the
  /// member can cancel anywhere in the review queue without changing their
  /// profile or leaving partial Storage objects behind.
  static Future<SelahPhotoSelectionResult> pickManyForReview({
    required int limit,
    void Function(int prepared, int total)? onProgress,
  }) async {
    if (limit < 1) return const SelahPhotoSelectionResult.cancelled();
    try {
      final picked = await ImagePicker().pickMultiImage(
        maxWidth: SelahProfilePhotoProcessor.maxDimension.toDouble(),
        maxHeight: SelahProfilePhotoProcessor.maxDimension.toDouble(),
        imageQuality: SelahProfilePhotoProcessor.jpegQuality,
        limit: limit,
        requestFullMetadata: false,
      );
      if (picked.isEmpty) return const SelahPhotoSelectionResult.cancelled();

      final bounded = picked.take(limit).toList(growable: false);
      final prepared = <Uint8List>[];
      for (var i = 0; i < bounded.length; i++) {
        prepared.add(await _readAndProcess(bounded[i]));
        onProgress?.call(i + 1, bounded.length);
      }
      return SelahPhotoSelectionResult.selected(prepared);
    } catch (error) {
      const kind = SelahPhotoFailureKind.processing;
      debugPrint(
        'SELAH: profile photo selection/preparation failed '
        '[${kind.referenceCode}; ${error.runtimeType}]. Nothing was retained.',
      );
      return const SelahPhotoSelectionResult.error();
    }
  }

  /// Selects a real device photo for Developer Preview without crossing the
  /// preview's no-live-data boundary. The processed, metadata-free JPEG stays
  /// in memory for this preview session and never reaches Storage/Postgres.
  static Future<SelahPhotoResult> pickForLocalPreview() async {
    try {
      final picked = await _pickProfilePhoto();
      if (picked == null) return const SelahPhotoResult.cancelled();
      final bytes = await _readAndProcess(picked);
      return SelahPhotoResult.uploaded(
        'data:image/jpeg;base64,${base64Encode(bytes)}',
      );
    } catch (error) {
      const kind = SelahPhotoFailureKind.processing;
      debugPrint(
        'SELAH: local preview photo processing failed '
        '[${kind.referenceCode}; ${error.runtimeType}]. Nothing was retained.',
      );
      return const SelahPhotoResult.error(kind);
    }
  }

  /// Finalises bytes returned by the crop/review screen. Cropping is followed
  /// by the privacy processor again so the final uploaded artifact — not only
  /// the original picker output — is bounded, orientation-safe and metadata
  /// free.
  static Future<SelahPhotoResult> saveReviewedPhoto(
    Uint8List croppedBytes, {
    required bool localPreview,
    bool Function()? canProceed,
  }) async {
    if (canProceed?.call() == false) return const SelahPhotoResult.cancelled();
    try {
      final bytes = await SelahProfilePhotoProcessor.process(croppedBytes);
      if (canProceed?.call() == false) return const SelahPhotoResult.cancelled();
      if (localPreview) {
        return SelahPhotoResult.uploaded(
          'data:image/jpeg;base64,${base64Encode(bytes)}',
        );
      }
      return _uploadProcessed(bytes, canProceed: canProceed);
    } catch (error) {
      const kind = SelahPhotoFailureKind.processing;
      debugPrint(
        'SELAH: reviewed profile photo could not be finalised '
        '[${kind.referenceCode}; ${error.runtimeType}]. Nothing was retained.',
      );
      return const SelahPhotoResult.error(kind);
    }
  }

  static Future<SelahPhotoResult> _uploadProcessed(
    Uint8List bytes, {
    bool Function()? canProceed,
  }) async {
    if (canProceed?.call() == false) return const SelahPhotoResult.cancelled();
    _synchronizeOwner();
    final user = SelahAuth.currentUser;
    if (user == null) {
      return const SelahPhotoResult.error(SelahPhotoFailureKind.authentication);
    }
    final epoch = _epoch;
    try {
      final path = '${user.id}/${DateTime.now().microsecondsSinceEpoch}.jpg';
      await supabase.storage
          .from(_bucket)
          .uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: false,
            ),
          );
      if (!_isCurrent(user.id, epoch) || canProceed?.call() == false) {
        return const SelahPhotoResult.cancelled();
      }
      final signedUrl = await supabase.storage
          .from(_bucket)
          .createSignedUrl(path, _signedUrlExpirySeconds);
      if (!_isCurrent(user.id, epoch) || canProceed?.call() == false) {
        return const SelahPhotoResult.cancelled();
      }
      _urlMemo[path] = (url: signedUrl, at: DateTime.now());
      return SelahPhotoResult.uploaded(signedUrl);
    } catch (error) {
      final kind = classifyFailure(error);
      final storageStatus = error is StorageException
          ? '; status=${error.statusCode ?? "unknown"}'
          : '';
      debugPrint(
        'SELAH: processed profile photo upload failed '
        '[${kind.referenceCode}; ${error.runtimeType}$storageStatus]. '
        'Nothing was saved.',
      );
      return SelahPhotoResult.error(kind);
    }
  }

  /// Convert only this backend's signed private JPEG URL into an owner-bound,
  /// tokenless reference suitable for protected same-device signup recovery.
  static String? signupStoragePathFor(
    String url, {
    required String expectedUserId,
  }) {
    final uri = Uri.tryParse(url);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.userInfo.isNotEmpty ||
        uri.fragment.isNotEmpty) {
      return null;
    }
    final base = Uri.parse(supabase.storage.from(_bucket).url);
    final prefix = '${base.path}/object/sign/$_bucket/';
    if (uri.origin != base.origin || !uri.path.startsWith(prefix)) return null;
    final path = uri.path.substring(prefix.length);
    return SelahInitialSignupDraft.isPrivatePhotoPath(
          path,
          expectedUserId: expectedUserId,
        )
        ? path
        : null;
  }

  static bool _signupOwnerCurrent(String userId, int generation) {
    try {
      return !SelahInternalPreviewClient.isActive &&
          SelahAuth.currentUser?.id == userId &&
          SelahAccountState.isCurrent(userId, generation);
    } catch (_) {
      return false;
    }
  }

  /// Fresh capability stays in memory only. A missing/expired object or stale
  /// account cannot be mistaken for a usable saved first photo.
  static Future<String?> signupPhotoUrl(
    String path, {
    required String expectedUserId,
    required int expectedGeneration,
  }) async {
    if (!_signupOwnerCurrent(expectedUserId, expectedGeneration) ||
        !SelahInitialSignupDraft.isPrivatePhotoPath(
          path,
          expectedUserId: expectedUserId,
        )) {
      return null;
    }
    try {
      final session = supabase.auth.currentSession;
      if (session?.user.id != expectedUserId) return null;
      final url = await supabase.storage
          .from(_bucket)
          .setHeader('Authorization', 'Bearer ${session!.accessToken}')
          .createSignedUrl(path, _signedUrlExpirySeconds);
      if (!_signupOwnerCurrent(expectedUserId, expectedGeneration) ||
          signupStoragePathFor(url, expectedUserId: expectedUserId) != path) {
        return null;
      }
      return url;
    } catch (_) {
      return null;
    }
  }

  /// Used only after verified profile creation. Unlike the legacy replacement
  /// sync, this never deletes or reorders photos: a retry reuses the same row,
  /// and any existing saved photos keep their primary/order. Readback and fresh
  /// signing must confirm the staged reference before signup can be erased.
  static Future<List<String>?> ensureSignupFirstPhotoConfirmed(
    String path, {
    required String expectedUserId,
    required int expectedGeneration,
  }) async {
    bool current() => _signupOwnerCurrent(expectedUserId, expectedGeneration);
    if (!current() ||
        !SelahInitialSignupDraft.isPrivatePhotoPath(
          path,
          expectedUserId: expectedUserId,
        )) {
      return null;
    }
    final session = supabase.auth.currentSession;
    if (session?.user.id != expectedUserId) return null;
    final authorization = 'Bearer ${session!.accessToken}';
    Future<List<Map<String, dynamic>>> readRows() => supabase
        .from('profile_photos')
        .select('user_id, storage_path, display_order, is_primary')
        .eq('user_id', expectedUserId)
        .order('display_order')
        .setHeader('Authorization', authorization);
    try {
      // Confirm Storage before inserting any reference to an unavailable file.
      if (await signupPhotoUrl(
            path,
            expectedUserId: expectedUserId,
            expectedGeneration: expectedGeneration,
          ) ==
          null) {
        return null;
      }
      if (!current()) return null;
      var rows = await readRows();
      if (!current()) return null;
      bool validRows() => rows.every(
        (row) =>
            row['user_id'] == expectedUserId &&
            row['storage_path'] is String &&
            SelahInitialSignupDraft.isPrivatePhotoPath(
              row['storage_path'] as String,
              expectedUserId: expectedUserId,
            ) &&
            row['display_order'] is int &&
            (row['display_order'] as int) >= 0 &&
            row['is_primary'] is bool,
      );
      if (!validRows()) return null;
      if (!rows.any((row) => row['storage_path'] == path)) {
        if (rows.length >= 6) return null;
        var lastOrder = -1;
        for (final row in rows) {
          final order = row['display_order'];
          if (order is! int || order < 0) return null;
          if (order > lastOrder) lastOrder = order;
        }
        await supabase
            .from('profile_photos')
            .insert({
              'user_id': expectedUserId,
              'storage_path': path,
              'is_primary': rows.isEmpty,
              'display_order': lastOrder + 1,
            })
            .setHeader('Authorization', authorization);
        if (!current()) return null;
        rows = await readRows();
        if (!current()) return null;
      }
      if (!validRows() || !rows.any((row) => row['storage_path'] == path)) {
        return null;
      }
      final urls = <String>[];
      for (final row in rows) {
        final savedPath = row['storage_path'];
        if (savedPath is! String) return null;
        final url = await signupPhotoUrl(
          savedPath,
          expectedUserId: expectedUserId,
          expectedGeneration: expectedGeneration,
        );
        if (!current() || url == null) return null;
        urls.add(url);
      }
      return urls;
    } catch (_) {
      debugPrint(
        'SELAH: signup photo confirmation failed; setup remains pending.',
      );
      return null;
    }
  }

  /// Maps raw SDK/transport failures to a stable category without retaining
  /// or displaying their potentially sensitive free-text messages.
  static SelahPhotoFailureKind classifyFailure(Object error) {
    if (error is SocketException || error is http.ClientException) {
      return SelahPhotoFailureKind.connection;
    }
    if (error is StorageException) {
      final status = int.tryParse(error.statusCode ?? '');
      if (status == 401) return SelahPhotoFailureKind.authentication;
      if (status == 403) return SelahPhotoFailureKind.accessDenied;
      if (status == 408 || status == 429 || (status != null && status >= 500)) {
        return SelahPhotoFailureKind.storage;
      }
      return SelahPhotoFailureKind.storage;
    }
    if (error is SelahProfilePhotoProcessingException) {
      return SelahPhotoFailureKind.processing;
    }
    if (error is PlatformException && error.code.startsWith('photo_')) {
      return SelahPhotoFailureKind.processing;
    }
    return SelahPhotoFailureKind.unknown;
  }

  /// Loads an existing display photo back into the same safe crop pipeline.
  ///
  /// Developer Preview supplies an in-memory data URL. Signed-in accounts
  /// supply a private, short-lived signed URL. The URL itself is never logged
  /// or included in errors, and the returned bytes have already passed the
  /// profile-photo privacy processor before the crop screen receives them.
  static Future<Uint8List> prepareDisplayPhotoForReview(String photo) async {
    Uint8List sourceBytes;
    if (photo.startsWith('data:image/')) {
      final comma = photo.indexOf(',');
      if (comma < 0) {
        throw const SelahProfilePhotoProcessingException(
          'invalid local preview photo',
        );
      }
      sourceBytes = base64Decode(photo.substring(comma + 1));
    } else {
      final uri = Uri.tryParse(photo);
      if (uri == null || !uri.hasScheme || uri.scheme != 'https') {
        throw const SelahProfilePhotoProcessingException(
          'invalid profile photo reference',
        );
      }
      final response = await http.get(uri);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw http.ClientException('profile photo download failed');
      }
      sourceBytes = response.bodyBytes;
    }
    return SelahProfilePhotoProcessor.process(sourceBytes);
  }

  /// Best-effort rollback for a reviewed batch that only partly uploaded.
  /// Existing profile rows and existing photos are never included here.
  static Future<void> discardNewUploads(List<String> displayUrls) async {
    _synchronizeOwner();
    final user = SelahAuth.currentUser;
    if (user == null || displayUrls.isEmpty) return;
    final ownPrefix = '${user.id}/';
    final paths = displayUrls
        .map(_storagePathFromUrl)
        .where((path) => path.startsWith(ownPrefix))
        .toList(growable: false);
    if (paths.isEmpty) return;
    try {
      await supabase.storage.from(_bucket).remove(paths);
      for (final path in paths) {
        _urlMemo.remove(path);
      }
    } catch (error) {
      debugPrint(
        'SELAH: incomplete photo batch cleanup failed '
        '(${error.runtimeType}).',
      );
    }
  }

  // ── SESSION URL MEMO — inherited decision 169 Phase 2, 2026-08-15 ──────────────
  //
  // Every list refresh used to re-sign every path it showed — a signing
  // round trip per fetch for URLs that live SEVEN DAYS. This memo keeps
  // the session's already-minted URLs so a refresh only signs what it
  // has never signed before.
  //
  // IN MEMORY, DELIBERATELY, and this is a privacy line, not a
  // convenience: a signed URL is a bearer capability — anyone holding
  // the string can fetch the photo for 7 days with no auth check — so
  // it must never be written to disk (the review's NEVER-STORE item N2).
  // The disk cache stores BYTES keyed by the tokenless URL instead
  // (selah_image_cache.dart), which is exactly as fast and carries no
  // capability.
  //
  // Entries older than 6 days re-sign on next use — one day of margin
  // before the 7-day URL under them dies. Cleared on sign-out
  // (selah_auth.dart) with everything else the account minted.
  static final Map<String, ({String url, DateTime at})> _urlMemo = {};
  static const Duration _memoMaxAge = Duration(days: 6);
  static String? _owner;
  static int _epoch = 0;

  static String? _currentOwner() {
    try {
      return SelahAuth.currentUser?.id;
    } catch (_) {
      return null;
    }
  }

  static void _synchronizeOwner() {
    final owner = _currentOwner();
    if (_owner == owner) return;
    clearUrlMemoForSignOut();
    _owner = owner;
  }

  static bool _isCurrent(String? owner, int epoch) =>
      epoch == _epoch && owner == _owner && owner == _currentOwner();

  /// Sign-out hook — see the memo note above.
  static void clearUrlMemoForSignOut() {
    _epoch++;
    _owner = null;
    _urlMemo.clear();
  }

  /// Batch-signs storage paths for display. Used by Browse and Matches
  /// for other users' photos as well as the user's own. Returns an
  /// empty list on any failure — callers already treat "no photos" as
  /// a skip/fallback case, never an error.
  /// FIXED 2026-08-05 (Founder: "still on Browse page I'm not getting
  /// profiles… 50 men 50 women, I'm not seeing anything").
  ///
  /// ROOT CAUSE. Browse signs every candidate's photos in ONE batched call
  /// and then slices the results back out by position, so it requires the
  /// returned list to be exactly as long as the list it sent — if it isn't,
  /// `fetchCandidates` deliberately shows nothing rather than risk pairing
  /// the wrong photo with the wrong person.
  ///
  /// The 100 seeded test profiles reuse the same ~99 real storage objects,
  /// so a full deck asks for ~290 paths of which most are DUPLICATES.
  /// Deduplicating server-side returns fewer rows than were sent, the
  /// length check fails, and every candidate is dropped — an empty Browse
  /// with a perfectly healthy database behind it.
  ///
  /// The fix belongs here, not in the seed data: a caller asking for the
  /// same path twice should get the same URL twice. Unique paths are signed
  /// once, chunked so a large deck cannot exceed a request limit, then
  /// expanded back to the caller's exact order and length. Still
  /// all-or-nothing — a missing path returns empty rather than a
  /// misaligned list.
  static Future<List<String>> signedUrlsFor(List<String> storagePaths) async {
    if (storagePaths.isEmpty) return const [];
    _synchronizeOwner();
    final owner = _owner;
    final epoch = _epoch;
    // DELEGATES to signedUrlMap since 2026-08-15 (inherited decision 169 Phase 2):
    // one signing implementation, one memo, one retry policy — this used
    // to be a second copy of the chunked signer with a harsher failure
    // mode (any chunk mismatch returned NONE, hiding a whole person over
    // one bad path — the exact 2026-08-05 failure shape, surviving here
    // after it was fixed there). Callers of THIS form sign one person's
    // own photo list per call (order preserved below), so proportional
    // results cannot misalign anyone's photos with anyone else's face.
    // This also retires the second of the two deprecated
    // createSignedUrls call sites.
    final byPath = await signedUrlMap(storagePaths);
    if (!_isCurrent(owner, epoch)) return const [];
    final out = <String>[];
    for (final p in storagePaths) {
      final url = byPath[p];
      if (url != null) out.add(url);
    }
    if (out.length != storagePaths.length) {
      debugPrint(
        'SELAH: signedUrlsFor — resolved ${out.length} of '
        '${storagePaths.length} paths; the rest are skipped.',
      );
    }
    return out;
  }

  /// Path → signed URL, for callers signing several people's photos at once.
  ///
  /// ADDED 2026-08-05 (Founder: "still no profiles showing up… please do a
  /// deep fix"). The previous design returned a positional LIST, so Browse
  /// signed every candidate's photos in one call and sliced the results back
  /// out by index. That only works if the returned list is exactly as long
  /// as the one sent — and made the whole deck hostage to a single bad path:
  /// one unresolvable photo, and 69 healthy candidates all disappeared.
  ///
  /// Returning a map removes the coupling entirely. Callers look up each
  /// path by name, a photo that fails to sign is simply not shown, and a
  /// person is only dropped if NONE of their photos resolve. Failure is now
  /// proportional to what actually failed.
  ///
  /// Never throws and never returns null — an empty map means nothing
  /// resolved, which callers already treat as "no photos".
  static Future<Map<String, String>> signedUrlMap(
    List<String> storagePaths,
  ) async {
    if (storagePaths.isEmpty) return const {};
    _synchronizeOwner();
    final owner = _owner;
    final epoch = _epoch;
    final byPath = <String, String>{};

    // Memo first (inherited decision 169 Phase 2): anything this session already
    // minted — and that is younger than 6 of its 7 days — is answered
    // without a round trip. Only genuine misses go to Storage below.
    final now = DateTime.now();
    final unique = <String>[];
    for (final p in storagePaths.toSet()) {
      final hit = _urlMemo[p];
      if (hit != null && now.difference(hit.at) < _memoMaxAge) {
        byPath[p] = hit.url;
      } else {
        unique.add(p);
      }
    }
    if (unique.isEmpty) return byPath;

    // 40, not 80, and never a per-path fallback. An earlier version fell
    // back to signing each path individually when a batch came up short —
    // which, on a full deck, meant up to 80 separate HTTP calls in a burst.
    // That is the surest way to get rate-limited, i.e. it made the failure
    // it was trying to recover from more likely. Two calm attempts per
    // chunk, with a pause between, is both gentler and more effective.
    const chunkSize = 40;

    for (var start = 0; start < unique.length; start += chunkSize) {
      final end = (start + chunkSize) > unique.length
          ? unique.length
          : start + chunkSize;
      final slice = unique.sublist(start, end);

      for (var attempt = 0; attempt < 2; attempt++) {
        if (attempt > 0) {
          await Future<void>.delayed(const Duration(milliseconds: 400));
        }
        if (!_isCurrent(owner, epoch)) return const {};
        try {
          // ignore: deprecated_member_use
          final signed = await supabase.storage
              .from(_bucket)
              // ignore: deprecated_member_use
              .createSignedUrls(slice, _signedUrlExpirySeconds);
          if (!_isCurrent(owner, epoch)) return const {};
          // Positional correlation is only safe when every path came back —
          // the slice is deduplicated, so a short result means something was
          // dropped and we can no longer say which. Retry rather than guess.
          if (signed.length == slice.length) {
            for (var i = 0; i < slice.length; i++) {
              byPath[slice[i]] = signed[i].signedUrl;
              // Remembered for the rest of the session — see _urlMemo.
              _urlMemo[slice[i]] = (url: signed[i].signedUrl, at: now);
            }
            break;
          }
          debugPrint(
            'SELAH: signedUrlMap — asked for ${slice.length}, got '
            '${signed.length}${attempt == 0 ? ", retrying" : ", giving up on this chunk"}.',
          );
        } catch (e) {
          if (!_isCurrent(owner, epoch)) return const {};
          debugPrint(
            'SELAH: signedUrlMap — chunk failed'
            '${attempt == 0 ? ", retrying" : ", giving up on this chunk"}. $e',
          );
        }
      }
    }

    // Against ALL unique paths asked for, not just this round's misses —
    // `unique` shrank to the memo-miss set above.
    final wanted = storagePaths.toSet().length;
    if (byPath.length != wanted) {
      debugPrint(
        'SELAH: signedUrlMap — resolved ${byPath.length} of '
        '$wanted unique paths.',
      );
    }
    return byPath;
  }

  /// Opens the device photo library and uploads the chosen image.
  /// Distinguishes "user cancelled picking" from "upload actually
  /// failed" (unlike a bare nullable return) so the UI can show a real
  /// error banner only when something genuinely went wrong, per
  /// ERROR_AND_EMPTY_STATE_STANDARD_CURRENT_VERSION_V1.md — a cancelled
  /// picker isn't an error and shouldn't look like one.
  ///
  /// Caller must check SelahAuth.isSignedIn before calling this — there's
  /// no signed-in-user fallback here (that's handled at the call site
  /// in chapter2_flow.dart for the mock/dev-access path).
  static Future<SelahPhotoResult> pickAndUpload() async {
    _synchronizeOwner();
    final user = SelahAuth.currentUser;
    if (user == null) {
      return const SelahPhotoResult.error(SelahPhotoFailureKind.authentication);
    }
    final epoch = _epoch;

    final picked = await _pickProfilePhoto();
    if (!_isCurrent(user.id, epoch)) return const SelahPhotoResult.cancelled();
    if (picked == null) return const SelahPhotoResult.cancelled();

    try {
      final bytes = await _readAndProcess(picked);
      if (!_isCurrent(user.id, epoch)) return const SelahPhotoResult.cancelled();
      return _uploadProcessed(bytes);
    } catch (error) {
      // Fail closed: processing errors never fall back to the picker bytes.
      // Log only the error type, never a path, filename or photo metadata.
      final kind = classifyFailure(error);
      debugPrint(
        'SELAH: profile photo processing/upload failed '
        '[${kind.referenceCode}; ${error.runtimeType}]. Nothing was uploaded.',
      );
      return SelahPhotoResult.error(kind);
    }
  }

  /// Restores the signed-in Seeker's ordered photo draft for deferred
  /// onboarding. Only storage paths are persisted; fresh signed URLs are
  /// minted on every restore so an expired URL is never treated as data.
  static Future<List<String>> fetchOwnPhotos({
    String? expectedUserId,
    bool throwOnError = false,
  }) async {
    _synchronizeOwner();
    final user = SelahAuth.currentUser;
    if (user == null || (expectedUserId != null && user.id != expectedUserId)) {
      if (throwOnError) throw StateError('Account changed.');
      return const [];
    }
    final epoch = _epoch;
    try {
      final rows = await supabase
          .from('profile_photos')
          .select('storage_path, display_order')
          .eq('user_id', user.id)
          .order('display_order');
      if (!_isCurrent(user.id, epoch)) throw StateError('Account changed.');
      final paths = <String>[
        for (final row in rows)
          if (row['storage_path'] is String) row['storage_path'] as String,
      ];
      final urls = await signedUrlsFor(paths);
      if (!_isCurrent(user.id, epoch) ||
          (throwOnError && urls.length != paths.length)) {
        throw StateError('Photos unavailable.');
      }
      return urls;
    } catch (e) {
      debugPrint('SELAH: own onboarding photos could not be restored — $e');
      if (throwOnError) rethrow;
      return const [];
    }
  }

  /// Replaces this user's `profile_photos` rows with the current
  /// ordered list of display URLs (first = primary). Derives the
  /// storage path back out of each URL rather than threading a
  /// separate path alongside every URL through the UI layer. Handles
  /// both URL shapes — signed (`.../object/sign/profile-photos/{path}
  /// ?token=...`, the current form) and public (`.../object/public/
  /// profile-photos/{path}`, in case any pre-privacy-fix URL is still
  /// held in AppState from an older session).
  static Future<void> syncPhotos(List<String> displayUrls) async {
    await syncPhotosConfirmed(displayUrls);
  }

  /// Edit Photos variant of [syncPhotos] that reports whether the ordered
  /// rows were actually saved. The onboarding flow remains best-effort, while
  /// an explicit editor must not silently claim a failed write succeeded.
  static Future<bool> syncPhotosConfirmed(
    List<String> displayUrls, {
    String? expectedUserId,
  }) async {
    _synchronizeOwner();
    final user = SelahAuth.currentUser;
    if (user == null || (expectedUserId != null && user.id != expectedUserId)) {
      return false;
    }
    final epoch = _epoch;

    try {
      await supabase.from('profile_photos').delete().eq('user_id', user.id);
      if (!_isCurrent(user.id, epoch)) return false;
      if (displayUrls.isEmpty) return true;

      final rows = <Map<String, dynamic>>[];
      for (var i = 0; i < displayUrls.length; i++) {
        rows.add({
          'user_id': user.id,
          'storage_path': _storagePathFromUrl(displayUrls[i]),
          'is_primary': i == 0,
          'display_order': i,
        });
      }
      await supabase.from('profile_photos').insert(rows);
      return _isCurrent(user.id, epoch);
    } catch (e) {
      // Best-effort — AppState's in-memory photos list (used everywhere
      // else in the app today) already has the URLs regardless of
      // whether this sync succeeds.
      debugPrint('SELAH: ordered profile photos could not be saved — $e');
      return false;
    }
  }

  /// `.../storage/v1/object/sign/{bucket}/{path}?token=...` →
  /// `{path}`; also accepts the legacy public form. Falls back to the
  /// input unchanged if neither marker is present (shouldn't happen
  /// for anything this service produced).
  static String _storagePathFromUrl(String url) {
    final withoutQuery = url.split('?').first;
    for (final marker in [
      '/object/sign/$_bucket/',
      '/object/public/$_bucket/',
    ]) {
      final idx = withoutQuery.indexOf(marker);
      if (idx != -1) {
        return Uri.decodeComponent(withoutQuery.substring(idx + marker.length));
      }
    }
    return url;
  }
}
