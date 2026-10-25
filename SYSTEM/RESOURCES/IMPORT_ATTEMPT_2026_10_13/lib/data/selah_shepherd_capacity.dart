import '../state/app_state.dart';
import 'selah_membership_catalog.dart';
import 'selah_seeker_plan_limits.dart';

enum SelahShepherdCapacityStatus { available, atLimit, unavailable }

/// Client presentation guard for a Seeker's active, accepted Shepherd links.
/// It never revokes a link on downgrade and is not atomic server enforcement.
class SelahShepherdCapacity {
  final SelahPlan plan;
  final int? linkedShepherdCount;
  final SelahShepherdCapacityStatus status;

  const SelahShepherdCapacity._(
    this.plan,
    this.linkedShepherdCount,
    this.status,
  );

  factory SelahShepherdCapacity.fromCount({
    required SelahPlan plan,
    required int? linkedShepherdCount,
  }) => SelahShepherdCapacity._(
    plan,
    linkedShepherdCount,
    linkedShepherdCount == null || linkedShepherdCount < 0
        ? SelahShepherdCapacityStatus.unavailable
        : SelahSeekerPlanLimits.canAddShepherd(
            plan: plan,
            linkedShepherdCount: linkedShepherdCount,
          )
        ? SelahShepherdCapacityStatus.available
        : SelahShepherdCapacityStatus.atLimit,
  );

  bool get canAdd => status == SelahShepherdCapacityStatus.available;
  bool get canUpgrade =>
      status == SelahShepherdCapacityStatus.atLimit && plan == SelahPlan.basic;

  static String get basicLimitMessage =>
      'Your current access allows ${SelahSeekerPlanLimits.basic.linkedShepherds} '
      'linked Shepherd${SelahSeekerPlanLimits.basic.linkedShepherds == 1 ? '' : 's'}. '
      'View ${SelahMembershipCatalog.seekerOneTitle} for up to ${SelahSeekerPlanLimits.one.linkedShepherds}. '
      'Your existing Shepherds stay linked.';
  static String get oneLimitMessage =>
      '${SelahMembershipCatalog.seekerOneTitle} includes up to ${SelahSeekerPlanLimits.one.linkedShepherds} '
      'linked Shepherds. Your existing Shepherds '
      'stay linked. Remove a link before adding another.';
  static const unavailableMessage =
      'Your linked Shepherds could not be checked. Please try again before '
      'adding another.';

  String? get message => switch (status) {
    SelahShepherdCapacityStatus.available => null,
    SelahShepherdCapacityStatus.unavailable => unavailableMessage,
    SelahShepherdCapacityStatus.atLimit =>
      plan == SelahPlan.basic ? basicLimitMessage : oneLimitMessage,
  };

  static bool isCapacityMessage(String? message) =>
      message == basicLimitMessage ||
      message == oneLimitMessage ||
      message == unavailableMessage;
}
