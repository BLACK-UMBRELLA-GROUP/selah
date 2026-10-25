enum SelahReportedContentType { profile, photo }

enum SelahModerationReviewStatus { pending, approved, rejected }

class SelahModerationReviewItem {
  final String id;
  final String profileId;
  final String firstName;
  final String photoUrl;
  final SelahReportedContentType contentType;
  final String reason;
  final SelahModerationReviewStatus status;
  final DateTime createdAt;

  const SelahModerationReviewItem({
    required this.id,
    required this.profileId,
    required this.firstName,
    required this.photoUrl,
    required this.contentType,
    required this.reason,
    required this.status,
    required this.createdAt,
  });

  SelahModerationReviewItem copyWith({SelahModerationReviewStatus? status}) =>
      SelahModerationReviewItem(
        id: id,
        profileId: profileId,
        firstName: firstName,
        photoUrl: photoUrl,
        contentType: contentType,
        reason: reason,
        status: status ?? this.status,
        createdAt: createdAt,
      );
}
