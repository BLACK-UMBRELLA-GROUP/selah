// Phase A moderation queue fixture.
//
// This store is deliberately memory-only and developer-only. A local queue is
// not an operational safety system; Phase C binds the same UI contract to
// server-owned report/photo-moderation rows after Vision enablement.

import 'package:flutter/foundation.dart';

import '../models/seeker_profile.dart';
import '../models/selah_moderation_review.dart';

class SelahModerationPreviewStore extends ChangeNotifier {
  SelahModerationPreviewStore._();

  static final instance = SelahModerationPreviewStore._();

  final List<SelahModerationReviewItem> _items = [];

  List<SelahModerationReviewItem> get items => List.unmodifiable(_items);

  void ensureDemoItems() {
    if (_items.isNotEmpty) return;
    final now = DateTime.now();
    for (var i = 0; i < 3; i++) {
      final profile = mockProfiles[i];
      _items.add(
        SelahModerationReviewItem(
          id: 'moderation-demo-$i',
          profileId: profile.id,
          firstName: profile.firstName,
          photoUrl: profile.photos.first,
          contentType: SelahReportedContentType.photo,
          reason: i == 0
              ? 'Member report · inappropriate content'
              : 'Vision preview · hold for review',
          status: SelahModerationReviewStatus.values[i],
          createdAt: now.subtract(Duration(minutes: i * 18)),
        ),
      );
    }
    notifyListeners();
  }

  void flag({
    required String profileId,
    required String firstName,
    required String photoUrl,
    required SelahReportedContentType contentType,
    required String reason,
  }) {
    _items.insert(
      0,
      SelahModerationReviewItem(
        id: 'moderation-local-${DateTime.now().microsecondsSinceEpoch}',
        profileId: profileId,
        firstName: firstName,
        photoUrl: photoUrl,
        contentType: contentType,
        reason: reason,
        status: SelahModerationReviewStatus.pending,
        createdAt: DateTime.now(),
      ),
    );
    notifyListeners();
  }

  void decide(String id, SelahModerationReviewStatus status) {
    final index = _items.indexWhere((item) => item.id == id);
    if (index < 0) return;
    _items[index] = _items[index].copyWith(status: status);
    notifyListeners();
  }

  @visibleForTesting
  void clear() {
    _items.clear();
    notifyListeners();
  }
}
