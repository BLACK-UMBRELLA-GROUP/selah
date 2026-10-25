// A local comparison setting for the onboarding next-step control. It is
// independent of the eleven visual directions and never changes live signup.
import 'package:flutter/foundation.dart';

import '../services/selah_account_state.dart';
import '../services/selah_developer_access.dart';

enum SelahOnboardingAdvanceMode { continueButton, animatedDownArrow }

/// How the protected four-card opening story is read. Independent of later
/// form controls so comparison never changes the real member signup flow.
enum SelahOnboardingStoryNavigation { tapThrough, scrollDown }

abstract final class SelahDevOnboardingStoryNavigation {
  static const _defaultMode = SelahOnboardingStoryNavigation.tapThrough;
  static final ValueNotifier<SelahOnboardingStoryNavigation> _selection =
      ValueNotifier(_defaultMode);
  static int _accountGeneration = SelahAccountState.generation;

  static Listenable get changes => _selection;
  static SelahOnboardingStoryNavigation get current =>
      _accountGeneration == SelahAccountState.generation
      ? _selection.value
      : _defaultMode;

  static bool select(SelahOnboardingStoryNavigation mode) {
    if (!SelahDeveloperAccess.canUseDeveloperTools) return false;
    final generation = SelahAccountState.generation;
    if (_accountGeneration != generation) {
      _accountGeneration = generation;
      _selection.value = _defaultMode;
    }
    _selection.value = mode;
    return true;
  }

  @visibleForTesting
  static void resetForTesting() {
    assert(() {
      _accountGeneration = SelahAccountState.generation;
      _selection.value = _defaultMode;
      return true;
    }());
  }
}

abstract final class SelahDevOnboardingInteraction {
  // Founder-selected default for protected onboarding comparisons. Continue
  // remains an explicit session-local alternative; ordinary signup is not
  // driven by this developer control.
  static const _defaultMode = SelahOnboardingAdvanceMode.animatedDownArrow;
  static final ValueNotifier<SelahOnboardingAdvanceMode> _selection =
      ValueNotifier(_defaultMode);
  static int _accountGeneration = SelahAccountState.generation;

  /// The selector and the local rehearsal may listen without gaining a
  /// writable ValueNotifier or a route into production onboarding.
  static Listenable get changes => _selection;

  /// An account transition immediately restores the default, even before
  /// another developer control has been built for the new account.
  static SelahOnboardingAdvanceMode get current =>
      _accountGeneration == SelahAccountState.generation
      ? _selection.value
      : _defaultMode;

  static bool select(SelahOnboardingAdvanceMode mode) {
    if (!SelahDeveloperAccess.canUseDeveloperTools) return false;
    final generation = SelahAccountState.generation;
    if (_accountGeneration != generation) {
      _accountGeneration = generation;
      _selection.value = _defaultMode;
    }
    _selection.value = mode;
    return true;
  }

  @visibleForTesting
  static void resetForTesting() {
    assert(() {
      _accountGeneration = SelahAccountState.generation;
      _selection.value = _defaultMode;
      return true;
    }());
  }
}
