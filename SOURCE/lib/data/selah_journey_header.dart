import 'selah_journey_stages.dart';

/// LOCK 21 / Q15 presentation only. The caller supplies its admitted own Main
/// Shepherd's display name; this formatter performs no identity or paid lookup.
String selahJourneyStageHeader({
  required int stageOrder,
  required String counterpartFirstName,
  String? ownMainShepherdName,
  String? otherMainShepherdName,
}) {
  final stage = 'Stage $stageOrder of ${SelahJourneyStages.count}';
  final own = ownMainShepherdName?.trim() ?? '';
  if (own.isEmpty) {
    return stage;
  }
  final other = otherMainShepherdName?.trim() ?? '';
  final counterpart = counterpartFirstName.trim();
  if (other.isEmpty && counterpart.isEmpty) {
    return stage;
  }
  final peer = other.isNotEmpty ? other : '$counterpart’s Shepherd';
  return '$stage · Shepherds: $own and $peer';
}
