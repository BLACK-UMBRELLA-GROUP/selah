import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../services/selah_local_prefs.dart';

/// Session-only navigation comparisons available through Developer Style.
/// The existing floating glass treatment remains the production default.
enum SelahNavStyle {
  floatingGlass(
    'Floating Glass · Current',
    'Breathing glass with a moving circular highlight',
  ),
  labelledDock('Labelled Dock', 'Dark dock with a white active label pill'),
  accentRing('Accent Ring', 'A clean ring follows the selected icon'),
  softTiles('Soft Tiles', 'Rounded translucent tiles with an accent selection'),
  goldUnderline('Gold Underline', 'Minimal icons with a fine moving underline'),
  raisedCapsule('Raised Capsule', 'A softly raised accent capsule'),
  quietDot('Quiet Dot', 'Low-chrome icons with one small position marker');

  final String label;
  final String detail;
  const SelahNavStyle(this.label, this.detail);
}

/// Native feedback strengths exposed only for Founder device comparison.
/// Flutter does not provide an arbitrary motor-amplitude API, so each step
/// deliberately maps to an operating-system semantic haptic.
enum SelahHapticLevel {
  off('Off'),
  subtle('Subtle'),
  light('Light'),
  medium('Medium'),
  strong('Strong');

  final String label;
  const SelahHapticLevel(this.label);
}

class SelahInteractionStyle {
  SelahInteractionStyle._();

  static const SelahNavStyle currentDefaultNavStyle =
      SelahNavStyle.labelledDock;
  static const SelahHapticLevel currentDefaultHapticLevel =
      SelahHapticLevel.subtle;

  static final ValueNotifier<SelahNavStyle> navStyleSelection =
      ValueNotifier<SelahNavStyle>(currentDefaultNavStyle);
  static final ValueNotifier<SelahHapticLevel> hapticLevelSelection =
      ValueNotifier<SelahHapticLevel>(currentDefaultHapticLevel);

  static SelahNavStyle get navStyle => navStyleSelection.value;
  static SelahHapticLevel get hapticLevel => hapticLevelSelection.value;

  static void selectNavStyle(SelahNavStyle style) {
    navStyleSelection.value = currentDefaultNavStyle;
  }

  static bool selectHapticLevel(SelahHapticLevel level) {
    if (hapticLevelSelection.value == level) return false;
    hapticLevelSelection.value = level;
    return true;
  }

  /// Member-facing haptic choice. Selection remains a native semantic rather
  /// than a fabricated amplitude; persistence only remembers which semantic
  /// the member chose.
  static bool selectPersonalisationHapticLevel(SelahHapticLevel level) {
    final changed = selectHapticLevel(level);
    SelahLocalPrefs.setCachedHapticLevelName(level.name);
    return changed;
  }

  /// Hydrates before the first frame. Unknown values resolve to Subtle.
  static void restoreHapticLevel(String? storedName) {
    final restored = SelahHapticLevel.values.where(
      (level) => level.name == storedName,
    );
    hapticLevelSelection.value = restored.isEmpty
        ? currentDefaultHapticLevel
        : restored.first;
  }

  static Future<void> emitSelectionHaptic({SelahHapticLevel? level}) async {
    switch (level ?? hapticLevel) {
      case SelahHapticLevel.off:
        return;
      case SelahHapticLevel.subtle:
        await HapticFeedback.selectionClick();
      case SelahHapticLevel.light:
        await HapticFeedback.lightImpact();
      case SelahHapticLevel.medium:
        await HapticFeedback.mediumImpact();
      case SelahHapticLevel.strong:
        await HapticFeedback.heavyImpact();
    }
  }

  static void restoreDefaults() {
    selectNavStyle(currentDefaultNavStyle);
    selectHapticLevel(currentDefaultHapticLevel);
  }
}
