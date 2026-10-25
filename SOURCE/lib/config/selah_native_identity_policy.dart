import 'selah_app_variant.dart';

abstract final class SelahNativeIdentityPolicy {
  static const productionBundleId = 'com.blackumbrella.selah.draft';
  static String expectedBundleId(SelahAppVariant _) => productionBundleId;
  static String expectedDisplayName(SelahAppVariant _) => 'Selah';
  static bool matches({
    required SelahAppVariant variant,
    required Object? bundleId,
    required Object? displayName,
  }) => variant == SelahAppVariant.production &&
      bundleId == productionBundleId && displayName == 'Selah';
}
