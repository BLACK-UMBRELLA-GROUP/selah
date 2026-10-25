import 'selah_app_variant.dart';

abstract final class OAuthConfig {
  static const String googleWebClientId = '';
  static const String googleIosClientId = '';
  static const bool isGoogleConfigured = false;
  static bool isGoogleConfigurationAllowed({
    required SelahAppVariant variant,
    required String webClientId,
    required String iosClientId,
  }) => false;
}
