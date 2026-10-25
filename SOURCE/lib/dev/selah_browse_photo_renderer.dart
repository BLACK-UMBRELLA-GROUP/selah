// Stable, prepared photographs for the protected offline Browse deck only.
// Sources are explicitly admitted data:image references; no URL, Storage,
// shared disk cache, account or member-photo authority lives here.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../widgets/selah_profile_image.dart';

/// The owner prepares its whole bounded local deck before exposing it. Keeping
/// each resolved stream alive makes both a new person's first photo and the
/// last-to-first photo wrap synchronously drawable with the same provider.
/// A source replacement or disposal revokes pending work and the old allowlist.
class SelahBrowseLocalPhotoRenderer {
  static const maximumSources = 32;

  final Map<String, _PreparedLocalPhoto> _photos = {};
  int _epoch = 0;
  bool _disposed = false;

  bool isReady(String source) => !_disposed && _photos[source]?.ready == true;

  Future<bool> prepare(Iterable<String> sources) async {
    if (_disposed) return false;
    final epoch = ++_epoch;
    final allowed = sources.toSet();
    if (allowed.length > maximumSources ||
        allowed.any((source) => !source.startsWith('data:image/'))) {
      _removePhotosExcept(const {});
      return false;
    }
    _removePhotosExcept(allowed);
    try {
      for (final source in allowed) {
        if (_photos.containsKey(source)) continue;
        final comma = source.indexOf(',');
        if (comma < 0 || !source.substring(0, comma).endsWith(';base64')) {
          throw const FormatException('Expected a local base64 image.');
        }
        final bytes = base64Decode(source.substring(comma + 1));
        if (bytes.isEmpty) throw const FormatException('Empty local image.');
        final photo = _PreparedLocalPhoto(MemoryImage(bytes));
        _photos[source] = photo;
        photo.resolve();
      }
    } on FormatException {
      _removePhotosExcept(const {});
      return false;
    }
    final results = await Future.wait([
      for (final source in allowed) _photos[source]!.completion.future,
    ]);
    return !_disposed &&
        epoch == _epoch &&
        results.every((ready) => ready) &&
        allowed.every(isReady);
  }

  Widget build(
    BuildContext context,
    String source, {
    required double width,
    required double height,
    required Alignment alignment,
  }) {
    final photo = _disposed ? null : _photos[source];
    if (photo == null || !photo.ready) {
      return _empty(width, height, alignment);
    }
    // Never retain another person's old frame under a replacement identity.
    // Preparation already supplies the correct synchronous first frame.
    return Image(
      image: photo.provider,
      width: width,
      height: height,
      fit: BoxFit.cover,
      alignment: alignment,
      gaplessPlayback: false,
      errorBuilder: (_, _, _) => _empty(width, height, alignment),
    );
  }

  Widget _empty(double width, double height, Alignment alignment) =>
      SelahProfileImage('', width: width, height: height, alignment: alignment);

  void _removePhotosExcept(Set<String> allowed) {
    final removed = _photos.keys
        .where((source) => !allowed.contains(source))
        .toList(growable: false);
    for (final source in removed) {
      _photos.remove(source)!.dispose();
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    ++_epoch;
    _removePhotosExcept(const {});
  }
}

class _PreparedLocalPhoto {
  _PreparedLocalPhoto(this.provider);

  final MemoryImage provider;
  final Completer<bool> completion = Completer<bool>();
  ImageStream? _stream;
  ImageStreamListener? _listener;
  bool ready = false;
  bool _disposed = false;

  void resolve() {
    _stream = provider.resolve(const ImageConfiguration());
    _listener = ImageStreamListener(
      (image, synchronous) {
        image.dispose();
        if (_disposed) return;
        ready = true;
        if (!completion.isCompleted) completion.complete(true);
      },
      onError: (Object error, StackTrace? stack) {
        if (_disposed) return;
        ready = false;
        if (!completion.isCompleted) completion.complete(false);
      },
    );
    // Unlike a one-frame precache, this listener stays for the deck lifetime.
    // It prevents a warm portrait being evicted between Next or wrap renders.
    _stream!.addListener(_listener!);
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    ready = false;
    if (!completion.isCompleted) completion.complete(false);
    final listener = _listener;
    if (listener != null) _stream?.removeListener(listener);
    _listener = null;
    _stream = null;
    // Remove this instance's memory key only, never clear a shared cache.
    unawaited(provider.evict());
  }
}
