import 'selah_journey_stages.dart';

/// Result returned by the existing stage RPC. No destination is client-chosen.
class SelahStageAdvance {
  final bool advanced;
  final String? stage;
  final String reason;

  const SelahStageAdvance(this.advanced, this.stage, this.reason);

  static const failed = SelahStageAdvance(false, null, 'call_failed');

  bool get accepted => advanced || reason == 'stage_moved';
}

/// LOCK 21: pass through the retained server's hidden Shepherd stage.
///
/// The server map and its refusal reasons remain authoritative. Sustained
/// stages are deliberately excluded: they still require Family Review.
/// A null result means the captured owner expired; it must not update UI.
Future<SelahStageAdvance?> advanceSelahVisibleThreshold({
  required String fromStage,
  required Future<SelahStageAdvance> Function(String) advance,
  required bool Function() canAct,
}) async {
  if (!canAct()) return null;
  if (!const {
    'greeting_exchange',
    'compatibility_reveal',
    'mentor_gate',
  }.contains(fromStage)) {
    return SelahStageAdvance.failed;
  }
  var result = await advance(fromStage);
  if (!canAct()) return null;
  if (fromStage == 'compatibility_reveal' &&
      result.accepted &&
      result.stage == 'mentor_gate') {
    result = await advance('mentor_gate');
    if (!canAct()) return null;
  }
  return result;
}

/// Confirm an accepted transition from a fresh read, never a guessed stage.
/// An unchanged hidden stage is a held error, not permission to loop the RPC.
Future<({T? value, String? failureReason})?> confirmSelahVisibleThreshold<T>({
  required SelahStageAdvance result,
  String? fromStage,
  required Future<T?> Function() refetch,
  required String? Function(T) stageOf,
  required bool Function() canAct,
}) async {
  if (!canAct()) return null;
  if (!result.accepted) return (value: null, failureReason: result.reason);
  final fresh = await refetch();
  if (!canAct()) return null;
  final rawStage = fresh == null ? null : stageOf(fresh);
  if (fresh == null ||
      rawStage == 'mentor_gate' ||
      (fromStage != null && rawStage == fromStage) ||
      SelahJourneyStages.of(rawStage) == null) {
    return (value: fresh, failureReason: 'stage_not_confirmed');
  }
  return (value: fresh, failureReason: null);
}
