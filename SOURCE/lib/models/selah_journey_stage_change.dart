/// An actual successful transition in the existing disposable Journey owner.
/// It is never a server milestone, notification or inferred historical fact.
class DraftJourneyStageChange {
  const DraftJourneyStageChange({
    required this.journeyId,
    required this.fromStage,
    required this.toStage,
    required this.occurredAt,
  });

  final String journeyId;
  final String fromStage;
  final String toStage;
  final DateTime occurredAt;
}
