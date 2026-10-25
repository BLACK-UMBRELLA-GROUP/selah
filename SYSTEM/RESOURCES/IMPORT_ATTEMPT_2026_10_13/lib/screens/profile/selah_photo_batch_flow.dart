import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../services/selah_photo_service.dart';
import 'photo_crop_review_screen.dart';

enum SelahPhotoBatchOutcome { added, cancelled, error }

class SelahPhotoBatchResult {
  const SelahPhotoBatchResult._(this.outcome, this.urls, this.failureKind);

  const SelahPhotoBatchResult.added(List<String> urls)
    : this._(SelahPhotoBatchOutcome.added, urls, null);
  const SelahPhotoBatchResult.cancelled()
    : this._(SelahPhotoBatchOutcome.cancelled, const [], null);
  const SelahPhotoBatchResult.error([
    SelahPhotoFailureKind kind = SelahPhotoFailureKind.unknown,
  ]) : this._(SelahPhotoBatchOutcome.error, const [], kind);

  final SelahPhotoBatchOutcome outcome;
  final List<String> urls;
  final SelahPhotoFailureKind? failureKind;

  String get memberErrorMessage {
    final kind = failureKind ?? SelahPhotoFailureKind.unknown;
    return '${kind.memberMessage} Reference: ${kind.referenceCode}.';
  }
}

typedef SelahPhotoBatchRunner =
    Future<SelahPhotoBatchResult> Function(
      BuildContext context,
      int remaining,
      ValueChanged<String?> onProgress,
    );

/// Runs the whole choose-many → crop individually → preview → save sequence.
/// Uploading starts only after the member has approved every crop.
Future<SelahPhotoBatchResult> runSelahPhotoBatchFlow(
  BuildContext context, {
  required int remaining,
  required bool localPreview,
  required ValueChanged<String?> onProgress,
  bool Function()? canProceed,
  bool preview = false,
  String? previewGender,
}) async {
  bool current() {
    if (!context.mounted) return false;
    try {
      return canProceed?.call() ?? !preview;
    } catch (_) {
      return false;
    }
  }

  bool parentCurrent() =>
      current() && (!preview || (ModalRoute.of(context)?.isCurrent ?? true));
  if ((preview && !localPreview) || !parentCurrent()) {
    return const SelahPhotoBatchResult.cancelled();
  }
  final selection = await SelahPhotoService.pickManyForReview(
    limit: remaining,
    onProgress: (prepared, total) {
      if (current()) onProgress('Preparing $prepared of $total');
    },
  );
  switch (selection.outcome) {
    case SelahPhotoSelectionOutcome.cancelled:
      if (current()) onProgress(null);
      return const SelahPhotoBatchResult.cancelled();
    case SelahPhotoSelectionOutcome.error:
      if (current()) onProgress(null);
      return const SelahPhotoBatchResult.error(SelahPhotoFailureKind.processing);
    case SelahPhotoSelectionOutcome.selected:
      break;
  }

  if (!parentCurrent()) {
    return const SelahPhotoBatchResult.cancelled();
  }
  onProgress(null);
  // The caller's progress callback can also remove the owning route.
  if (!context.mounted || !parentCurrent()) {
    return const SelahPhotoBatchResult.cancelled();
  }
  final reviewed = await Navigator.of(context).push<List<Uint8List>>(
    MaterialPageRoute(
      builder: (_) => PhotoCropReviewScreen(
        photos: selection.photos,
        preview: preview,
        gender: previewGender,
        canAct: preview ? current : null,
      ),
    ),
  );
  if (reviewed == null || reviewed.isEmpty || !parentCurrent()) {
    return const SelahPhotoBatchResult.cancelled();
  }

  final saved = <String>[];
  for (var i = 0; i < reviewed.length; i++) {
    if (!current()) return const SelahPhotoBatchResult.cancelled();
    onProgress(
      localPreview
          ? 'Adding ${i + 1} of ${reviewed.length}'
          : 'Uploading ${i + 1} of ${reviewed.length}',
    );
    final result = await SelahPhotoService.saveReviewedPhoto(
      reviewed[i],
      localPreview: localPreview,
      canProceed: canProceed,
    );
    if (!current()) return const SelahPhotoBatchResult.cancelled();
    if (result.outcome != SelahPhotoOutcome.uploaded || result.url == null) {
      if (!localPreview) await SelahPhotoService.discardNewUploads(saved);
      onProgress(null);
      return SelahPhotoBatchResult.error(
        result.failureKind ?? SelahPhotoFailureKind.unknown,
      );
    }
    saved.add(result.url!);
  }
  onProgress(null);
  return SelahPhotoBatchResult.added(saved);
}
