// Shepherd paid-feature access is resolved by the server. It can come from
// the Shepherd's own subscription or a linked Seeker allocation; this boolean
// is not proof of a separately billed Additional Shepherd membership.

import 'package:flutter/foundation.dart' show debugPrint;

import '../main.dart';
import '../state/app_state.dart';
import 'selah_account_state.dart';
import 'selah_auth.dart';
import 'selah_mentor_link_service.dart' show SelahSourceFailure, SelahSourceResult;

class SelahEntitlementService {
  SelahEntitlementService._();
  static int _accessRequest = 0;

  /// Denies paid features on missing session or failed verification. Only a
  /// confirmed response for the same account may update the shared membership
  /// presentation; an earlier account's response cannot leak into a new one.
  static Future<bool> hasMentorOne() async =>
      (await resolveShepherdPaidAccess()).valueOr(false);

  /// Preserves unavailable separately from confirmed false. This resolves
  /// server-defined paid-feature access, not context ownership or proof of an
  /// independently purchased Shepherd membership. Legacy callers still deny
  /// access through [hasMentorOne] when this result is unavailable.
  static Future<SelahSourceResult<bool>> resolveShepherdPaidAccess() async {
    final request = ++_accessRequest;
    final userId = SelahAuth.currentUser?.id;
    if (userId == null) {
      return const SelahSourceResult.unavailable(SelahSourceFailure.signedOut);
    }
    final generation = SelahAccountState.generation;
    bool stillOwner() =>
        SelahAuth.currentUser?.id == userId &&
        SelahAccountState.isCurrent(userId, generation);
    if (!stillOwner()) {
      return const SelahSourceResult.unavailable(SelahSourceFailure.signedOut);
    }
    try {
      final result = await supabase.rpc('mentor_has_mentor_one');
      if (!stillOwner()) {
        return const SelahSourceResult.unavailable(SelahSourceFailure.signedOut);
      }
      if (request != _accessRequest) {
        return const SelahSourceResult.unavailable(
          SelahSourceFailure.requestFailed,
        );
      }
      if (result is! bool) {
        return const SelahSourceResult.unavailable(
          SelahSourceFailure.invalidResponse,
        );
      }
      AppState.instance.setMentorOne(result);
      if (!stillOwner() || request != _accessRequest) {
        return const SelahSourceResult.unavailable(
          SelahSourceFailure.requestFailed,
        );
      }
      return SelahSourceResult.available(result);
    } catch (error) {
      debugPrint(
        'SELAH Shepherd entitlement check failed (${error.runtimeType}).',
      );
      return const SelahSourceResult.unavailable(
        SelahSourceFailure.requestFailed,
      );
    }
  }
}
