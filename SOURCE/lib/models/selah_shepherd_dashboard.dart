import '../data/selah_journey_stages.dart';
import 'selah_journey_stage_change.dart';

/// Caller-admitted identity, read from the existing linked Journey owner.
/// This binding conveys no link, role or permission by itself.
class SelahShepherdCheckInIdentity {
  const SelahShepherdCheckInIdentity({
    required this.seekerId,
    required this.seekerFirstName,
    required this.counterpartFirstName,
  });
  final String seekerId;
  final String seekerFirstName;
  final String counterpartFirstName;
}

class SelahShepherdCheckIn {
  const SelahShepherdCheckIn({
    required this.key,
    required this.journeyId,
    required this.identity,
    required this.stage,
    required this.occurredAt,
  });
  final String key;
  final String journeyId;
  final SelahShepherdCheckInIdentity identity;
  final SelahJourneyStage stage;
  final DateTime occurredAt;
  String get title =>
      '${identity.seekerFirstName} and '
      '${identity.counterpartFirstName} reached ${stage.label}';
}

/// LOCK20's read-only seven-day projection. The supplied binding must already
/// be admitted by the caller's existing current-link and Journey-access gates.
List<SelahShepherdCheckIn> selahShepherdCheckIns({
  required Iterable<DraftJourneyStageChange> events,
  required Map<String, SelahShepherdCheckInIdentity> admittedJourneys,
  required DateTime now,
}) {
  final cutoff = now.subtract(const Duration(days: 7));
  final rows = <String, SelahShepherdCheckIn>{};
  for (final event in events) {
    final identity = admittedJourneys[event.journeyId];
    final stage = SelahJourneyStages.of(event.toStage);
    if (identity == null ||
        stage == null ||
        identity.seekerId.isEmpty ||
        identity.seekerFirstName.trim().isEmpty ||
        identity.counterpartFirstName.trim().isEmpty ||
        event.occurredAt.isBefore(cutoff) ||
        event.occurredAt.isAfter(now)) {
      continue;
    }
    final key =
        '${identity.seekerId}:${event.journeyId}:${event.fromStage}:${event.toStage}';
    final previous = rows[key];
    if (previous != null && !event.occurredAt.isAfter(previous.occurredAt)) {
      continue;
    }
    rows[key] = SelahShepherdCheckIn(
      key: key,
      journeyId: event.journeyId,
      identity: identity,
      stage: stage,
      occurredAt: event.occurredAt,
    );
  }
  return selahMergeShepherdCheckIns(rows.values);
}

/// Bind each model's events to its admitted Seeker identity before merging.
/// Peer IDs are local to each model and cannot identify the Seeker on their own.
List<SelahShepherdCheckIn> selahMergeShepherdCheckIns(
  Iterable<SelahShepherdCheckIn> checkIns,
) {
  final rows = <String, SelahShepherdCheckIn>{};
  for (final row in checkIns) {
    final previous = rows[row.key];
    if (previous == null || row.occurredAt.isAfter(previous.occurredAt)) {
      rows[row.key] = row;
    }
  }
  final indexed = rows.values.indexed.toList()
    ..sort((a, b) {
      final time = b.$2.occurredAt.compareTo(a.$2.occurredAt);
      return time == 0 ? b.$1.compareTo(a.$1) : time;
    });
  return List.unmodifiable(indexed.take(3).map((entry) => entry.$2));
}

/// Presentation of an existing actionable priority, with its source key.
class SelahShepherdDashboardNeed {
  const SelahShepherdDashboardNeed({
    required this.id,
    required this.seekerId,
    required this.title,
    required this.detail,
    required this.actionLabel,
  });
  final String id;
  final String seekerId;
  final String title;
  final String detail;
  final String actionLabel;
}
