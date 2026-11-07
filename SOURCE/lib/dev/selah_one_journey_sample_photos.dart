import 'dart:convert';

import 'package:flutter/services.dart';

/// The sample profile pictures are simple placeholder images made for this project; they show no real people. Earlier versions in the Git history used photos whose source was not recorded.
/// Never reads a member photo, signed URL, image cache or remote service.
/// Shared SelahProfileImage already renders data URLs locally, so these photos
/// can be used in its original Browse, card and avatar presentation unchanged.
class SelahOneJourneySamplePhotos {
  SelahOneJourneySamplePhotos._(this.sets, this.seekerPhoto, this.shepherdPhoto);

  final List<List<String>> sets;
  final String seekerPhoto;
  final String shepherdPhoto;

  static const seeds = <List<String>>[
    ['selah1a', 'selah1b', 'selah1c'],
    ['selah2a', 'selah2b'],
    ['selah3a', 'selah3b', 'selah3c'],
    ['selah4a'],
    ['selah5a', 'selah5b'],
    ['selah6a'],
    ['selah7a'],
    ['selah8a'],
  ];

  static Future<SelahOneJourneySamplePhotos> load({AssetBundle? bundle}) async {
    final source = bundle ?? rootBundle;
    final loaded = <List<String>>[];
    for (final group in seeds) {
      final photos = <String>[];
      for (final seed in group) {
        final data = await source.load(
          'assets/dev/one_journey_photos/$seed.jpg',
        );
        final bytes = data.buffer.asUint8List(
          data.offsetInBytes,
          data.lengthInBytes,
        );
        photos.add('data:image/jpeg;base64,${base64Encode(bytes)}');
      }
      loaded.add(photos);
    }
    Future<String> avatar(String name) async {
      final data = await source.load('assets/dev/one_journey_photos/$name.jpg');
      final bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      return 'data:image/jpeg;base64,${base64Encode(bytes)}';
    }

    return SelahOneJourneySamplePhotos._(
      List<List<String>>.unmodifiable([
        for (final group in loaded) List<String>.unmodifiable(group),
      ]),
      await avatar('seeker_self'),
      await avatar('shepherd_self'),
    );
  }

  List<String> forIndex(int index) => sets[index % sets.length];
}
