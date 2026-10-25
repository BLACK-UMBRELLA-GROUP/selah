// Privacy boundary for every member profile photo before it reaches Storage.
//
// The native picker is deliberately asked to resize first so a very large
// camera source is not decoded at full resolution inside Dart. Native picker
// implementations can preserve EXIF (including GPS), however, so their output
// is never uploadable as-is. This second pass:
//   1. decodes the bounded picker output;
//   2. applies the EXIF orientation to the pixels;
//   3. enforces the 1440px longest-edge cap again;
//   4. removes EXIF and textual metadata; and
//   5. emits a fresh JPEG at quality 85.
//
// Processing is fail-closed. Callers receive an exception for an empty,
// corrupt, unsupported or unverifiable result and must not upload the source
// bytes as a fallback.

import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute, visibleForTesting;
import 'package:image/image.dart' as img;

class SelahProfilePhotoProcessingException implements Exception {
  const SelahProfilePhotoProcessingException(this.reason);

  final String reason;

  @override
  String toString() => 'SelahProfilePhotoProcessingException: $reason';
}

class SelahProfilePhotoProcessor {
  SelahProfilePhotoProcessor._();

  static const int maxDimension = 1440;
  static const int jpegQuality = 85;

  /// Processes away from the UI isolate. The native picker has already made
  /// the source reasonably small, but JPEG encoding is still CPU work and
  /// should not freeze the photo screen.
  static Future<Uint8List> process(Uint8List sourceBytes) =>
      compute(_processProfilePhotoBytes, sourceBytes);

  /// Quarter-turn used by the review screen. It returns another clean JPEG
  /// and runs off the UI isolate so rotating a large portrait stays smooth.
  static Future<Uint8List> rotateClockwise(Uint8List sourceBytes) =>
      compute(_rotateProfilePhotoBytes, sourceBytes);

  @visibleForTesting
  static Uint8List processSynchronously(Uint8List sourceBytes) =>
      _processProfilePhotoBytes(sourceBytes);
}

Uint8List _rotateProfilePhotoBytes(Uint8List sourceBytes) {
  final decoded = img.decodeImage(sourceBytes);
  if (decoded == null) {
    throw const SelahProfilePhotoProcessingException(
      'unsupported or unreadable source',
    );
  }
  final rotated = img.copyRotate(decoded, angle: 90)
    ..exif = img.ExifData()
    ..textData = null
    ..extraChannels = null;
  return Uint8List.fromList(
    img.JpegEncoder(
      quality: SelahProfilePhotoProcessor.jpegQuality,
    ).encode(rotated, singleFrame: true),
  );
}

Uint8List _processProfilePhotoBytes(Uint8List sourceBytes) {
  try {
    if (sourceBytes.isEmpty) {
      throw const SelahProfilePhotoProcessingException('empty source');
    }

    final decoded = img.decodeImage(sourceBytes);
    if (decoded == null || decoded.width < 1 || decoded.height < 1) {
      throw const SelahProfilePhotoProcessingException(
        'unsupported or unreadable source',
      );
    }

    // Apply orientation before removing the tag that described it.
    var processed = img.bakeOrientation(decoded);

    if (processed.width > SelahProfilePhotoProcessor.maxDimension ||
        processed.height > SelahProfilePhotoProcessor.maxDimension) {
      processed = processed.width >= processed.height
          ? img.copyResize(
              processed,
              width: SelahProfilePhotoProcessor.maxDimension,
              interpolation: img.Interpolation.average,
            )
          : img.copyResize(
              processed,
              height: SelahProfilePhotoProcessor.maxDimension,
              interpolation: img.Interpolation.average,
            );
    }

    // Keep the colour profile: it is required to render colour faithfully and
    // carries no capture location, date or device identity. Everything else
    // the JPEG encoder could emit from the source is removed explicitly.
    processed = img.Image.from(processed, noAnimation: true)
      ..exif = img.ExifData()
      ..textData = null
      ..extraChannels = null;

    final output = img.JpegEncoder(
      quality: SelahProfilePhotoProcessor.jpegQuality,
    ).encode(processed, singleFrame: true);

    // Verify our own boundary rather than assuming the encoder honoured it.
    final verified = img.decodeJpg(output);
    if (verified == null ||
        verified.width > SelahProfilePhotoProcessor.maxDimension ||
        verified.height > SelahProfilePhotoProcessor.maxDimension ||
        !verified.exif.isEmpty) {
      throw const SelahProfilePhotoProcessingException(
        'sanitised output verification failed',
      );
    }

    return output;
  } on SelahProfilePhotoProcessingException {
    rethrow;
  } catch (_) {
    throw const SelahProfilePhotoProcessingException(
      'unsupported or unreadable source',
    );
  }
}
