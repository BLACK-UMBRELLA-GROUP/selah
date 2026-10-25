import 'dart:io';
import 'package:flutter/foundation.dart';
import '../config/selah_native_identity_policy.dart';

// Local fixtures are never real account authority. Release artifacts cannot
// activate this draft runtime, even with the same installed bundle identity.
abstract final class SelahDraftRuntime {
  static const bool _localDraftDeliveryEnabled = bool.fromEnvironment(
    'SELAH_DRAFT_LOCAL_ONLY',
    defaultValue: false,
  );
  static bool _active = false;
  static bool get active => _active && !kReleaseMode;
  static bool activate({required String bundleId}) {
    _active = !kReleaseMode &&
        bundleId == SelahNativeIdentityPolicy.productionBundleId &&
        _localDraftDeliveryEnabled;
    return active;
  }
  static void stop() => _active = false;
}

// Defence in depth for all retained Dart IO clients. There is no endpoint,
// authenticated account or Supabase initialization in the draft entrypoint.
class SelahOfflineHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      throw const SocketException('Selah first draft is local-only.');
}
