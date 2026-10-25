import 'selah_view_request_draft_model.dart';

/// Disposable, route-local presentation of fictional Compatibility Unlocks.
///
/// This is not a wallet, a compatibility algorithm or a disclosure grant.
/// It accepts only the named draft fixtures and never reads private answers,
/// calls a service, persists a result or changes a Journey. The shell owns
/// route/role/authority guards and discards this instance when its route ends.
class SelahDraftCompatibilityPreview {
  SelahDraftCompatibilityPreview(String profileId, {int balance = 1})
    : profileId = _validatedProfile(profileId),
      _balance = _validatedBalance(balance, 'balance');

  static final Set<String> _fixtureIds = Set.unmodifiable(
    draftProfiles.map((profile) => profile.id),
  );
  static const _balancePresets = {0, 1, 5};

  final String profileId;
  int _balance;
  bool _revealed = false;

  int get balance => _balance;
  bool get revealed => _revealed;

  /// An existing deterministic sample display value, never answer scoring.
  /// The caller paints this fictional value only after [revealed].
  int get overallScore =>
      68 + profileId.codeUnits.fold<int>(0, (sum, unit) => sum + unit) % 23;

  /// Assigns one exact local preset, without revealing or resetting a result.
  /// Re-selecting a valid preset is idempotent; it never adds to the balance.
  bool setBalance({required int count}) {
    if (!_balancePresets.contains(count)) return false;
    _balance = count;
    return true;
  }

  /// One local credit reveals Overall, details and the Shepherd example once.
  bool unlock() {
    if (_revealed || _balance == 0) return false;
    _balance--;
    _revealed = true;
    return true;
  }

  static String _validatedProfile(String id) {
    if (!_fixtureIds.contains(id)) {
      throw ArgumentError.value(
        id,
        'profileId',
        'Must be a named draft fixture',
      );
    }
    return id;
  }

  static int _validatedBalance(int value, String name) {
    if (!_balancePresets.contains(value)) {
      throw ArgumentError.value(value, name, 'Must be exactly 0, 1 or 5');
    }
    return value;
  }
}
