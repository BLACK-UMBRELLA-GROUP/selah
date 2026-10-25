import 'package:flutter/foundation.dart';

/// Local Founder comparison only. Ordinary builds always render the current
/// Settings design; changing this value never changes an account preference.
enum SelahSettingsDesign { current, smoothCards }

abstract final class SelahDevSettingsDesign {
  static final ValueNotifier<SelahSettingsDesign> selection = ValueNotifier(
    SelahSettingsDesign.current,
  );

  static SelahSettingsDesign get current => selection.value;

  static void select(SelahSettingsDesign design) => selection.value = design;
}
