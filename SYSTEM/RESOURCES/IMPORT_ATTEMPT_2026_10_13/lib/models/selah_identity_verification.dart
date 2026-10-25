/// Coarse, SELAH-owned identity-verification state.
///
/// These are the only provider outcomes the Flutter client may receive. Raw
/// document data, selfie data, face-match scores, duplicate-hit identities
/// and provider reason strings never belong in this model.
enum SelahIdentityVerificationResult {
  pending('pending'),
  verified('verified'),
  retryRequired('retry_required'),
  reviewRequired('review_required'),
  failed('failed'),
  expired('expired'),
  cancelled('cancelled');

  final String storageValue;
  const SelahIdentityVerificationResult(this.storageValue);

  static SelahIdentityVerificationResult fromStorage(Object? value) =>
      values.firstWhere(
        (result) => result.storageValue == value,
        orElse: () => SelahIdentityVerificationResult.retryRequired,
      );
}

/// The duplicate signal is deliberately ternary.
///
/// `notEvaluated` must never be collapsed into `clear`: DR-SELAH-221 allows a
/// verified member into the app, but an Active Journey additionally requires
/// the duplicate check to have resolved clear.
enum SelahDuplicateReviewState { notEvaluated, clear, reviewRequired }

class SelahIdentityVerificationState {
  final SelahIdentityVerificationResult result;
  final SelahDuplicateReviewState duplicateReview;
  final bool consentGranted;
  final String consentVersion;
  final DateTime consentRecordedAt;
  final DateTime updatedAt;
  final DateTime? decidedAt;

  const SelahIdentityVerificationState({
    required this.result,
    required this.duplicateReview,
    required this.consentGranted,
    required this.consentVersion,
    required this.consentRecordedAt,
    required this.updatedAt,
    this.decidedAt,
  });

  /// DR-SELAH-221: the app shell opens only on the canonical verified result.
  bool get allowsApp => result == SelahIdentityVerificationResult.verified;

  /// Active Journey is the stricter gate: verified plus duplicate-clear.
  bool get allowsActiveJourney =>
      allowsApp && duplicateReview == SelahDuplicateReviewState.clear;

  factory SelahIdentityVerificationState.fromJson(Map<String, dynamic> json) {
    final duplicate = json['duplicate_review_required'];
    return SelahIdentityVerificationState(
      result: SelahIdentityVerificationResult.fromStorage(json['result']),
      duplicateReview: duplicate == true
          ? SelahDuplicateReviewState.reviewRequired
          : duplicate == false
          ? SelahDuplicateReviewState.clear
          : SelahDuplicateReviewState.notEvaluated,
      consentGranted: json['consent_granted'] == true,
      consentVersion: json['consent_version'] as String? ?? '',
      consentRecordedAt: _date(json['consent_recorded_at']),
      updatedAt: _date(json['updated_at']),
      decidedAt: _nullableDate(json['decided_at']),
    );
  }

  /// Parses the caller-scoped RPC envelope without widening the client model.
  /// A malformed non-null response is a protocol error, never an implied
  /// verification grant.
  static SelahIdentityVerificationState? fromRpc(Object? raw) {
    if (raw == null) return null;
    if (raw is Map) {
      return SelahIdentityVerificationState.fromJson(
        Map<String, dynamic>.from(raw),
      );
    }
    if (raw is List && raw.isNotEmpty && raw.first is Map) {
      return SelahIdentityVerificationState.fromJson(
        Map<String, dynamic>.from(raw.first as Map),
      );
    }
    throw StateError('Unexpected identity-verification state shape.');
  }

  static DateTime _date(Object? value) =>
      _nullableDate(value) ??
      DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

  static DateTime? _nullableDate(Object? value) {
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  SelahIdentityVerificationState copyWith({
    SelahIdentityVerificationResult? result,
    SelahDuplicateReviewState? duplicateReview,
    bool? consentGranted,
  }) => SelahIdentityVerificationState(
    result: result ?? this.result,
    duplicateReview: duplicateReview ?? this.duplicateReview,
    consentGranted: consentGranted ?? this.consentGranted,
    consentVersion: consentVersion,
    consentRecordedAt: consentRecordedAt,
    updatedAt: DateTime.now().toUtc(),
    decidedAt: result == SelahIdentityVerificationResult.verified
        ? DateTime.now().toUtc()
        : decidedAt,
  );
}
