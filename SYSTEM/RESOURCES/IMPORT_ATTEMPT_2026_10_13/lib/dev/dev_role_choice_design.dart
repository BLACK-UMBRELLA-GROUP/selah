// Local visual comparison for the protected first-use role-choice page only.
// This never changes account role, signup drafts, or ordinary onboarding.
import 'package:flutter/foundation.dart';

import '../services/selah_account_state.dart';
import '../services/selah_developer_access.dart';

enum SelahRoleChoiceDesign {
  current('Current'),
  editorial('1 · Editorial'),
  guidedPaths('2 · Guided paths'),
  quietRails('3 · Quiet rails'),
  spotlight('4 · Spotlight'),
  framedChoice('5 · Framed choice');

  const SelahRoleChoiceDesign(this.label);

  final String label;
}

abstract final class SelahDevRoleChoiceDesign {
  static final ValueNotifier<SelahRoleChoiceDesign> _selection = ValueNotifier(
    SelahRoleChoiceDesign.guidedPaths,
  );
  static int _accountGeneration = SelahAccountState.generation;

  static Listenable get changes => _selection;

  /// A change of authenticated account cannot inherit the previous account's
  /// design choice, even before the protected control is mounted again.
  static SelahRoleChoiceDesign get current =>
      _accountGeneration == SelahAccountState.generation
      ? _selection.value
      : SelahRoleChoiceDesign.guidedPaths;

  static bool select(SelahRoleChoiceDesign design) {
    if (!SelahDeveloperAccess.canUseDeveloperTools) return false;
    final generation = SelahAccountState.generation;
    if (_accountGeneration != generation) {
      _accountGeneration = generation;
      _selection.value = SelahRoleChoiceDesign.guidedPaths;
    }
    _selection.value = design;
    return true;
  }

  @visibleForTesting
  static void resetForTesting() {
    assert(() {
      _accountGeneration = SelahAccountState.generation;
      _selection.value = SelahRoleChoiceDesign.guidedPaths;
      return true;
    }());
  }
}
