import 'package:flutter/services.dart' show appFlavor;

enum SelahAppVariant { production, unsupported }
abstract final class SelahAppVariantPolicy {
  static SelahAppVariant fromFlavor(String? value) =>
      value == null || value.isEmpty || value == 'production' || value == 'draft'
          ? SelahAppVariant.production
          : SelahAppVariant.unsupported;
  static SelahAppVariant get current => fromFlavor(appFlavor);
}
