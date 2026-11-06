import 'selah_mentor_journey_service.dart';
import 'selah_mentor_link_service.dart';

enum ShepherdDashboardAttentionKind { familyReview }

final class ShepherdDashboardAttention {
  final ShepherdDashboardAttentionKind kind;
  final MentorJourneyView journey;
  final String title;
  final String detail;
  final String actionLabel;

  const ShepherdDashboardAttention({
    required this.kind,
    required this.journey,
    required this.title,
    required this.detail,
    required this.actionLabel,
  });
}

final class ShepherdDashboardResolution {
  final List<ShepherdDashboardAttention> attention;
  final int linkedSeekerCount;
  final int needsYouCount;

  const ShepherdDashboardResolution({
    required this.attention,
    required this.linkedSeekerCount,
    required this.needsYouCount,
  });
}

/// Pure Shepherd Dashboard decision layer.
///
/// The adapter remains the existing screen-owned group of permitted reads;
/// this resolver accepts only their returned domain values. It cannot query
/// Browse decisions, infer private Seeker behaviour, or widen RLS.
final class SelahShepherdDashboardResolver {
  const SelahShepherdDashboardResolver();

  ShepherdDashboardResolution resolve({
    required List<MentorLinkedPerson> linkedPeople,
    required List<MentorJourneyView> journeys,
    required Set<String> openReviewIds,
  }) {
    // A Shepherd may be Main for one Seeker and Additional for another.
    // Partition authority before inspecting any Journey field so a stale,
    // injected or over-broad Additional-owned row cannot affect priority,
    // copy, ordering or aggregates.
    final mainSeekerIds = {
      for (final person in linkedPeople)
        if (person.isMain) person.id,
    };
    final familyReviews = <ShepherdDashboardAttention>[];

    for (final journey in journeys) {
      if (!mainSeekerIds.contains(journey.linkedSeekerId)) continue;
      if (journey.status == 'ended') continue;
      if (openReviewIds.contains(journey.matchId)) {
        familyReviews.add(
          ShepherdDashboardAttention(
            kind: ShepherdDashboardAttentionKind.familyReview,
            journey: journey,
            title: '${journey.linkedSeekerName} needs your Family Review',
            detail:
                'Both families decide whether this Journey continues. '
                'Your decision is waiting.',
            actionLabel: 'Review',
          ),
        );
      }
    }

    final attention = familyReviews;
    final seekersNeedingAttention = {
      for (final item in attention) item.journey.linkedSeekerId,
    };

    return ShepherdDashboardResolution(
      attention: attention,
      linkedSeekerCount: linkedPeople.length,
      needsYouCount: seekersNeedingAttention.length,
    );
  }
}
