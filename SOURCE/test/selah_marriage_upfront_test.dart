import 'package:flutter_test/flutter_test.dart';

import '../tool/test_marriage_upfront.dart';

void main() {
  test(
    'LOCK16 exact disclosure projection and non-destructive Bio retirement',
    () {
      runMarriageUpfrontChecks((passed, message) {
        expect(passed, isTrue, reason: message);
      });
    },
  );
}
