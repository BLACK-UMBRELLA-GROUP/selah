import 'package:flutter_test/flutter_test.dart';
import 'package:selah/data/selah_journey_shepherd_selection.dart';
import 'package:selah/dev/selah_dev_scenario.dart';
import 'package:selah/dev/selah_view_request_draft_model.dart';

void main() {
  test('local cast uses matching names for gendered family relations', () {
    // Explicit LOCK 8 cast membership, rather than guessed gender from a name.
    const women = {
      'Grace',
      'Esther',
      'Naomi',
      'Abigail',
      'Ruth',
      'Lydia',
      'Phoebe',
      'Chloe',
      'Miriam',
      'Rebecca',
      'Joanna',
      'Priscilla',
      'Ama',
      'Sarah',
      'Teresa',
    };
    const men = {
      'James',
      'Daniel',
      'Samuel',
      'Joel',
      'Caleb',
      'Nathan',
      'Elijah',
      'Matthew',
      'Isaac',
      'Jonah',
      'Simon',
      'Andrew',
      'David',
      'Joseph',
      'Peter',
      'Mark',
    };
    const maleRelations = {
      'father',
      'brother',
      'uncle',
      'grandfather',
      'son',
      'nephew',
      'paternal_uncle',
      'maternal_uncle',
      'father_in_law',
      'brother_in_law',
    };
    const femaleRelations = {
      'mother',
      'sister',
      'aunt',
      'grandmother',
      'daughter',
      'niece',
      'paternal_aunt',
      'maternal_aunt',
      'mother_in_law',
      'sister_in_law',
    };
    final people = <(String, String)>[
      for (final p in SelahDevScenario.fakeShepherds) (p.name, p.relationship),
      for (final p in SelahDevScenario.fakeWards) (p.name, p.relationship),
      for (final p in SelahDevScenario.fakeReceived(5))
        (p.from, p.relationship),
      for (final p in SelahJourneyShepherdSelection.otherShepherdPreview)
        (p.firstName, p.relationship),
      for (final p in draftShepherds) (p.firstName, p.relationshipCode),
    ];
    for (final (name, relation) in people) {
      expect(
        {...women, ...men},
        contains(name),
        reason: '$name must belong to the approved local cast.',
      );
      if (maleRelations.contains(relation)) {
        expect(
          men,
          contains(name),
          reason: '$name cannot be shown as $relation.',
        );
      }
      if (femaleRelations.contains(relation)) {
        expect(
          women,
          contains(name),
          reason: '$name cannot be shown as $relation.',
        );
      }
    }
  });
}
