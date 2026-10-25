import '../data/selah_journey_stages.dart';
import 'selah_mentor_journey_service.dart';
import 'selah_mentor_link_service.dart';

/// The four ruled Main-Shepherd roster groups, in product order.
enum ShepherdSeekerRosterGroup {
  needsYou('NEEDS YOU'),
  inAJourney('IN A JOURNEY'),
  pausedOrWaiting('PAUSED OR WAITING'),
  otherSeekers('OTHER SEEKERS');

  final String label;
  const ShepherdSeekerRosterGroup(this.label);
}

final class ShepherdSeekerRosterEntry {
  final MentorLinkedPerson person;
  final MentorJourneyView? currentJourney;
  final ShepherdSeekerRosterGroup? group;
  final bool needsAttention;
  final DateTime? waitingSince;
  final String contextLine;

  const ShepherdSeekerRosterEntry({
    required this.person,
    required this.currentJourney,
    required this.group,
    required this.needsAttention,
    required this.waitingSince,
    required this.contextLine,
  });
}

final class ShepherdSeekerRosterSection {
  final ShepherdSeekerRosterGroup group;
  final List<ShepherdSeekerRosterEntry> entries;

  const ShepherdSeekerRosterSection({
    required this.group,
    required this.entries,
  });
}

final class ShepherdSeekerRosterResolution {
  final List<ShepherdSeekerRosterSection> mainSections;
  final List<ShepherdSeekerRosterEntry> additionalShepherdships;

  const ShepherdSeekerRosterResolution({
    required this.mainSections,
    required this.additionalShepherdships,
  });

  bool get isEmpty =>
      mainSections.every((section) => section.entries.isEmpty) &&
      additionalShepherdships.isEmpty;
}

/// Pure, authority-first resolver for the Shepherd-side Seeker roster.
///
/// Additional Shepherdships remain in one neutral alphabetical section. They
/// receive current Journey context only when the server participation view
/// contains their Seeker-authorised assignment; Main-only attention states
/// never change their heading, order, badge or priority.
final class SelahShepherdSeekerRosterResolver {
  const SelahShepherdSeekerRosterResolver();

  ShepherdSeekerRosterResolution resolve({
    required List<MentorLinkedPerson> linkedPeople,
    required ShepherdSeekerRosterContext context,
  }) {
    final mainPeople = linkedPeople.where((person) => person.isMain).toList();
    final currentBySeeker = <String, MentorJourneyView>{};
    for (final journey in context.journeys) {
      if (journey.status == 'ended') continue;
      currentBySeeker.putIfAbsent(journey.linkedSeekerId, () => journey);
    }
    final additional = linkedPeople.where((person) => !person.isMain).map((
      person,
    ) {
      final journey = currentBySeeker[person.id];
      return ShepherdSeekerRosterEntry(
        person: person,
        currentJourney: journey,
        group: null,
        needsAttention: false,
        waitingSince: null,
        contextLine: _additionalContextLine(journey),
      );
    }).toList()..sort(_compareEntriesByName);

    final grouped =
        <ShepherdSeekerRosterGroup, List<ShepherdSeekerRosterEntry>>{
          for (final group in ShepherdSeekerRosterGroup.values) group: [],
        };
    for (final person in mainPeople) {
      final journey = currentBySeeker[person.id];
      final reviewOpen =
          journey != null &&
          context.openReviewMatchIds.contains(journey.matchId);
      final shepherdGate =
          journey != null &&
          !journey.isJourneyLocked &&
          journey.journeyStage == 'mentor_gate';
      final needsAttention = reviewOpen || shepherdGate;
      final group = needsAttention
          ? ShepherdSeekerRosterGroup.needsYou
          : journey == null
          ? ShepherdSeekerRosterGroup.otherSeekers
          : journey.isJourneyLocked ||
                journey.isSuspended ||
                journey.isPauseDecisionPending
          ? ShepherdSeekerRosterGroup.pausedOrWaiting
          : ShepherdSeekerRosterGroup.inAJourney;
      final entry = ShepherdSeekerRosterEntry(
        person: person,
        currentJourney: journey,
        group: group,
        needsAttention: needsAttention,
        waitingSince: journey == null
            ? null
            : context.waitingSinceByMatchId[journey.matchId],
        contextLine: _contextLine(journey, reviewOpen: reviewOpen),
      );
      grouped[group]!.add(entry);
    }

    for (final group in ShepherdSeekerRosterGroup.values) {
      final entries = grouped[group]!;
      if (group == ShepherdSeekerRosterGroup.needsYou) {
        entries.sort(_compareNeedsYou);
      } else {
        entries.sort(_compareEntriesByName);
      }
    }

    return ShepherdSeekerRosterResolution(
      mainSections: [
        for (final group in ShepherdSeekerRosterGroup.values)
          ShepherdSeekerRosterSection(group: group, entries: grouped[group]!),
      ],
      additionalShepherdships: additional,
    );
  }

  static String _contextLine(
    MentorJourneyView? journey, {
    required bool reviewOpen,
  }) {
    if (journey == null) return 'No current Journey';
    if (reviewOpen) return 'Family Review needs you';
    if (journey.isPauseDecisionPending) {
      return 'Journey awaiting a decision';
    }
    if (journey.isSuspended) return 'Journey paused';
    return 'Journey with ${journey.partner.firstName} · '
        '${SelahJourneyStages.labelFor(journey.journeyStage)}';
  }

  static String _additionalContextLine(MentorJourneyView? journey) {
    if (journey == null) return 'Not included in an active Journey';
    if (journey.isPauseDecisionPending) return 'Journey awaiting a decision';
    if (journey.isSuspended) return 'Journey paused';
    return 'Journey with ${journey.partner.firstName} · '
        '${SelahJourneyStages.labelFor(journey.journeyStage)}';
  }

  static int _compareNeedsYou(
    ShepherdSeekerRosterEntry left,
    ShepherdSeekerRosterEntry right,
  ) {
    final leftAt = left.waitingSince;
    final rightAt = right.waitingSince;
    if (leftAt != null && rightAt != null) {
      final byTime = leftAt.compareTo(rightAt);
      if (byTime != 0) return byTime;
    } else if (leftAt != null) {
      return -1;
    } else if (rightAt != null) {
      return 1;
    }
    return _compareEntriesByName(left, right);
  }

  static int _compareEntriesByName(
    ShepherdSeekerRosterEntry left,
    ShepherdSeekerRosterEntry right,
  ) {
    final byName = left.person.firstName.toLowerCase().compareTo(
      right.person.firstName.toLowerCase(),
    );
    if (byName != 0) return byName;
    return left.person.id.compareTo(right.person.id);
  }
}
