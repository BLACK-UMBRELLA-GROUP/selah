import 'selah_app_variant.dart';

class SelahSupabaseEndpoint {
  const SelahSupabaseEndpoint({required this.url, required this.publishableKey});
  final String url;
  final String publishableKey;
  bool get isConfigured => false;
}
abstract final class SelahSupabaseConfigPolicy {
  static SelahSupabaseEndpoint select({
    required SelahAppVariant variant,
    required SelahSupabaseEndpoint production,
  }) => const SelahSupabaseEndpoint(url: '', publishableKey: '');
}
