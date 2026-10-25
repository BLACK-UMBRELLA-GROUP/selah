import 'selah_app_variant.dart';

// Retained interface only. There is no Founder server grant in this draft.
abstract final class SelahInternalFounderPolicy {
  static const bool enabled = false;
  static const String approvedSupabaseUrl = '';
  static const String approvedFounderUserId = '';
  static const String compiledFounderUserId = '';
  static bool allows({
    required SelahAppVariant variant,
    required bool internalBuildEnabled,
    required String suppliedFounderUserId,
    required String supabaseUrl,
    required String userId,
    required Map<String, dynamic> appMetadata,
    required bool claimsAreFresh,
  }) => false;
}
