/// Selection rules for the six Stage 3 developer Shepherds.
///
/// Index 0 is the one Main Shepherd. The other five are Additional
/// Shepherds. Selecting an Additional Shepherd also selects the Main because
/// the app cannot truthfully preview an Additional-only Shepherd network;
/// clearing the Main clears the whole mock network for the same reason.
abstract final class SelahJourneyShepherdSelection {
  static const int shepherdCount = 6;
  static const int mainIndex = 0;

  /// The other Seeker's display-only Shepherd family used by the Active
  /// Journey developer preview. This is deliberately separate from
  /// [toggle]: that set represents *your* Shepherd network and is only used
  /// to prove that the Stage 4 gate can be satisfied. Showing those people
  /// as the introductions awaiting you would reverse whose family the page
  /// is about.
  ///
  /// Main is always first so the portrait pager opens on the person who
  /// carries that responsibility. Production data keeps the same ordering.
  static const List<({String firstName, String relationship, bool isMain})>
  otherShepherdPreview = [
    (firstName: 'Peter', relationship: 'uncle', isMain: true),
    (firstName: 'Ruth', relationship: 'sister', isMain: false),
    (firstName: 'Mark', relationship: 'grandfather', isMain: false),
  ];

  static Set<int> toggle(Set<int> current, int index) {
    if (index < 0 || index >= shepherdCount) {
      return Set<int>.unmodifiable(current);
    }

    final next = <int>{...current};
    if (index == mainIndex) {
      if (next.contains(mainIndex)) {
        next.clear();
      } else {
        next.add(mainIndex);
      }
      return Set<int>.unmodifiable(next);
    }

    if (!next.remove(index)) {
      next
        ..add(mainIndex)
        ..add(index);
    }
    return Set<int>.unmodifiable(next);
  }
}

enum SelahJourneyShepherdRevealState {
  neither,
  mineWaiting,
  theirsWaiting,
  revealed,
}

/// Stage 4 is a mutual identity threshold. A Seeker can offer their reveal,
/// but neither family opens for only one person's decision.
abstract final class SelahJourneyShepherdRevealPolicy {
  static SelahJourneyShepherdRevealState resolve({
    required bool mine,
    required bool theirs,
  }) {
    if (mine && theirs) return SelahJourneyShepherdRevealState.revealed;
    if (mine) return SelahJourneyShepherdRevealState.mineWaiting;
    if (theirs) return SelahJourneyShepherdRevealState.theirsWaiting;
    return SelahJourneyShepherdRevealState.neither;
  }

  static bool canRevealMine({required bool mine}) => !mine;

  static bool canViewShepherds({required bool mine, required bool theirs}) =>
      mine && theirs;
}

/// Greetings after the reveal are optional and belong to one Shepherd portrait,
/// not to the Stage 4 gate. After a greeting, move to the next person who has
/// not received one so offering several Greetings stays quick without forcing
/// the member to greet everybody.
abstract final class SelahJourneyShepherdGreetingPolicy {
  static int? nextUngreeted({
    required int currentIndex,
    required Set<int> greetedIndices,
    required int shepherdCount,
  }) {
    if (shepherdCount <= 0) return null;
    for (var offset = 1; offset <= shepherdCount; offset++) {
      final candidate = (currentIndex + offset) % shepherdCount;
      if (!greetedIndices.contains(candidate)) return candidate;
    }
    return null;
  }
}
