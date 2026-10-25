import '../state/app_state.dart' show SelahPlan;
import 'selah_seeker_basic_policy.dart';

/// Founder-approved client membership policy. These are capacity/display
/// rules, not backend authorisation, purchase proof or data-retention rules.
/// Downgrading never deletes profiles, Journeys or accepted Shepherd links.
class SelahSeekerPlanLimits {
  final int savedProfiles;
  final int? activeConsiders;
  final int? dailyConsiders;
  final int recentDeclinedProfiles;
  final int linkedShepherds;

  const SelahSeekerPlanLimits({
    required this.savedProfiles,
    required this.activeConsiders,
    required this.dailyConsiders,
    required this.recentDeclinedProfiles,
    required this.linkedShepherds,
  });

  static const oneSavedProfiles = 50;
  static const basic = SelahSeekerPlanLimits(
    savedProfiles: SelahSeekerBasicPolicy.totalSaveLimit,
    activeConsiders: SelahSeekerBasicPolicy.totalConsiderLimit,
    dailyConsiders: SelahSeekerBasicPolicy.dailyConsiderLimit,
    recentDeclinedProfiles: 0,
    linkedShepherds: 1,
  );
  static const one = SelahSeekerPlanLimits(
    savedProfiles: oneSavedProfiles,
    activeConsiders: null,
    dailyConsiders: null,
    recentDeclinedProfiles: 10,
    linkedShepherds: 10,
  );

  static SelahSeekerPlanLimits of(SelahPlan plan) =>
      plan == SelahPlan.one ? one : basic;

  bool canSave({required int currentCount, bool alreadySaved = false}) =>
      alreadySaved || (currentCount >= 0 && currentCount < savedProfiles);

  bool canConsider({
    required int currentCount,
    bool alreadyConsidered = false,
  }) =>
      alreadyConsidered ||
      (currentCount >= 0 &&
          (activeConsiders == null || currentCount < activeConsiders!));

  /// Main counts as one of the accepted links. Pending requests are not links.
  static bool canAddShepherd({
    required SelahPlan plan,
    required int linkedShepherdCount,
  }) =>
      linkedShepherdCount >= 0 &&
      linkedShepherdCount < of(plan).linkedShepherds;

  /// AppState.declined is the profile decision/Passed list, not declined
  /// Journey requests. Hydration and local Pass both keep newest first.
  /// Return a display copy without mutating the source.
  List<T> recentDeclined<T>(List<T> profiles) =>
      List<T>.unmodifiable(profiles.take(recentDeclinedProfiles));
}
