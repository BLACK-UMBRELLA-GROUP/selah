// Shared local persona entry for Developer Access and its gender toggle.
// No account switching, provider changes or live mutations. Only the guarded
// Founder presentation direction and preview role are remembered locally.

import 'package:flutter/material.dart';

import '../data/selah_membership_catalog.dart';
import '../screens/home/home_shell.dart';
import '../screens/shepherd/shepherd_home_shell.dart';
import '../services/selah_developer_access.dart';
import '../services/selah_account_state.dart';
import '../services/selah_internal_preview_client.dart';
import '../services/selah_local_prefs.dart';
import '../services/selah_profile_service.dart';
import '../services/selah_promotion_engine.dart';
import '../models/selah_signup_membership_choice.dart';
import '../state/app_state.dart';
import 'selah_dev_scenario.dart';
import 'selah_dev_surface_coordinator.dart';
import 'selah_founder_launch_screen.dart';

class SelahDevLocalPreview {
  SelahDevLocalPreview._();

  static final ValueNotifier<String> genderSelection = ValueNotifier('male');
  static bool _opening = false;
  static bool _seekerPremium = true;
  static bool _shepherdPremium = true;

  static String get seekerMembershipLabel =>
      _seekerPremium ? SelahMembershipCatalog.seekerOneTitle : 'Seeker Basic';
  static String get shepherdMembershipLabel => _shepherdPremium
      ? SelahMembershipCatalog.shepherdOneTitle
      : 'Shepherd Basic';

  /// A labelled local sample, never a claim that a default Basic account paid.
  static String? basicMembershipPreviewLabel({required bool shepherd}) =>
      SelahInternalPreviewClient.isActive &&
          SelahDeveloperAccess.canUseDeveloperTools &&
          !(shepherd ? _shepherdPremium : _seekerPremium)
      ? '${shepherd ? 'Shepherd' : 'Seeker'} Basic · Preview'
      : null;

  /// Apply a deliberately selected sample only after the protected signup
  /// rehearsal reaches its completion action. Never callable by live signup;
  /// this is not a payment, receipt, identity or Family allocation operation.
  static bool applySignupMembershipPreview({
    required SelahSignupRole role,
    required SelahSignupMembershipChoice choice,
  }) {
    if (!SelahInternalPreviewClient.isActive ||
        !SelahDeveloperAccess.isMainAppPreview ||
        !SelahDeveloperAccess.canUseDeveloperTools ||
        !choice.isValidFor(role)) {
      return false;
    }
    final premium = choice.kind != SelahSignupMembershipKind.basic;
    if (role == SelahSignupRole.shepherd) {
      _shepherdPremium = premium;
      AppState.instance.setShepherdOne(premium);
    } else {
      _seekerPremium = premium;
      AppState.instance.setPlan(premium ? SelahPlan.one : SelahPlan.basic);
    }
    return true;
  }

  static Future<void> selectGender(BuildContext context, String gender) async {
    if ((gender != 'male' && gender != 'female') ||
        !SelahDeveloperAccess.isMainAppPreview) {
      return;
    }
    final surface = SelahDevSurfaceCoordinator.instance.surface;
    if (surface == SelahDevSurface.entry ||
        SelahDevSurfaceCoordinator.instance.developerLandingVisible) {
      // Selecting the next sample is not editing the signed-in account.
      genderSelection.value = gender;
      return;
    }
    await open(
      context,
      isShepherd: surface == SelahDevSurface.shepherd,
      premium: surface == SelahDevSurface.shepherd
          ? _shepherdPremium
          : _seekerPremium,
      gender: gender,
    );
  }

  static Future<bool> open(
    BuildContext context, {
    required bool isShepherd,
    bool premium = true,
    String? gender,
    String? identityName,
    DateTime? identityDob,
    String? identityLocation,
    String? appStyle,
  }) async {
    if (_opening ||
        !context.mounted ||
        !SelahDeveloperAccess.isMainAppPreview ||
        SelahAccountState.isSigningOut ||
        (appStyle != null && appStyle != 'request' && appStyle != 'option1')) {
      return false;
    }
    final selectedGender = gender ?? genderSelection.value;
    if (selectedGender != 'male' && selectedGender != 'female') return false;
    // Refresh retracts the developer overlay while proof is re-established.
    // Its button context may be disposed; the app Navigator remains the owner.
    final navigator = Navigator.of(context);
    final route = ModalRoute.of(context);
    final ownerId = SelahAccountState.userId;
    final generation = SelahAccountState.generation;
    final preferenceGeneration = SelahLocalPrefs.bindingGeneration;
    bool sameLifetime() =>
        navigator.mounted &&
        !SelahAccountState.isSigningOut &&
        ownerId == SelahAccountState.userId &&
        generation == SelahAccountState.generation &&
        preferenceGeneration == SelahLocalPrefs.bindingGeneration &&
        (route == null || route.isCurrent);
    _opening = true;
    try {
      final tester = SelahDeveloperAccess.isAuthorizedTester;
      final authorization = tester
          ? null
          : await SelahDeveloperAccess.refreshCurrentAuthorizationSnapshot();
      if (!sameLifetime() ||
          !SelahDeveloperAccess.canUseDeveloperTools ||
          !SelahDeveloperAccess.isMainAppPreview) {
        return false;
      }
      final founder =
          authorization?.founderAuthorized == true &&
          authorization?.user?.id == ownerId &&
          ownerId != null;
      // Other test personas retain their previous protected entry. A cached
      // direction is not a Founder grant, paid entitlement or member route.
      final style = founder
          ? appStyle ?? SelahLocalPrefs.cachedFounderAppStyleName
          : 'option1';
      if (founder) {
        if (appStyle != null) {
          await SelahLocalPrefs.setFounderAppStyleName(
            appStyle,
            expectedOwner: ownerId,
            expectedBindingGeneration: preferenceGeneration,
          );
        }
        await SelahLocalPrefs.setFounderPreviewRole(
          isShepherd ? 'shepherd' : 'seeker',
          expectedOwner: ownerId,
          expectedBindingGeneration: preferenceGeneration,
        );
        if (!sameLifetime() || !SelahDeveloperAccess.canUseDeveloperTools) {
          return false;
        }
      }
      final female = selectedGender == 'female';
      final name =
          identityName ??
          (isShepherd
              ? (female ? 'Khadija' : 'Ibrahim')
              : (female ? 'Maryam' : 'Adam'));
      if (isShepherd) {
        _shepherdPremium = premium;
      } else {
        _seekerPremium = premium;
      }
      SelahInternalPreviewClient.beginPreview();
      genderSelection.value = selectedGender;
      AppState.instance.applyDevPreset(
        name: name,
        gender: selectedGender,
        dob:
            identityDob ??
            (isShepherd
                ? (female ? DateTime(1970, 4, 2) : DateTime(1968, 1, 15))
                : (female ? DateTime(1998, 7, 22) : DateTime(1997, 3, 14))),
        location:
            identityLocation ??
            (isShepherd
                ? (female ? 'Manchester' : 'Birmingham')
                : (female ? 'Birmingham' : 'London')),
        shepherdName: isShepherd ? name : null,
        shepherdRelationship: isShepherd ? (female ? 'Mother' : 'Father') : null,
        plan: !isShepherd && premium ? SelahPlan.one : SelahPlan.basic,
        shepherdHasShepherdOne: isShepherd && premium,
      );
      if (isShepherd) {
        SelahPromotionEngine.instance.setDeveloperShepherdNetworkState(
          premium
              ? SelahDeveloperShepherdNetworkState.d14Preview
              : SelahDeveloperShepherdNetworkState.linkedBasic,
        );
      }
      final scenario = SelahDevScenario.instance;
      scenario.reset();
      scenario.setDashboardLabEnabled(true);
      scenario.setDashboardOnboardingComplete(true);
      scenario.setUseLiveShepherdData(false);
      scenario.setMainShepherd(true);
      scenario.setShepherdLinkedSeekers(2);
      SelahDevSurfaceCoordinator.instance.endEntryFlow();
      navigator.pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => founder && style == 'request'
              ? SelahFounderReviewSurface(
                  ownerId: ownerId,
                  ownerGeneration: generation,
                  initialShepherdRole: isShepherd,
                  initialSeekerBasic: !isShepherd && !premium,
                  initialShepherdBasic: isShepherd && !premium,
                )
              : isShepherd
              ? const ShepherdHomeShell()
              : const HomeShell(
                  initialTab: 2,
                  deferredOnboardingDevPreview: true,
                  initialOnboardingProgress: SelahOnboardingProgress(
                    complete: true,
                    due: 0,
                    missing: 0,
                    hasChapter2: true,
                    basicProfile: true,
                  ),
                ),
        ),
        (_) => false,
      );
      return true;
    } catch (error) {
      debugPrint('SELAH local preview entry failed (${error.runtimeType}).');
      return false;
    } finally {
      _opening = false;
    }
  }

  /// Switches application context without ending the authenticated session.
  ///
  /// The current preview identity is carried into the target context while
  /// each context keeps its own remembered membership. This mirrors the
  /// production contract without pretending the migration already exists.
  static Future<void> switchAccountContext(
    BuildContext context, {
    required bool toShepherd,
  }) async {
    if (!SelahDeveloperAccess.isMainAppPreview) return;
    final state = AppState.instance;
    final identityName = state.name ?? state.shepherdName;
    await open(
      context,
      isShepherd: toShepherd,
      premium: toShepherd ? _shepherdPremium : _seekerPremium,
      gender: state.gender ?? genderSelection.value,
      identityName: identityName,
      identityDob: state.dob,
      identityLocation: state.location,
    );
  }
}
