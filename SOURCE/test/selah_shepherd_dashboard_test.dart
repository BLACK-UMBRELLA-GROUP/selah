import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selah/data/selah_journey_stages.dart';
import 'package:selah/models/selah_shepherd_dashboard.dart';
import 'package:selah/theme/selah_text.dart';
import 'package:selah/widgets/selah_prayer_views.dart';
import 'package:selah/widgets/selah_shepherd_dashboard_views.dart';

import '../tool/test_shepherd_check_ins.dart';

void main() {
  setUp(() => SelahText.useTestFontStubs = true);
  tearDown(() => SelahText.useTestFontStubs = false);
  test('Actual transition history and check-in window, order and limit', () {
    runShepherdCheckInChecks(
      (value, label) => expect(value, isTrue, reason: label),
    );
  });
  Widget page({
    List<SelahShepherdDashboardNeed> needs = const [],
    List<SelahShepherdCheckIn> checkIns = const [],
    ValueChanged<SelahShepherdDashboardNeed>? onNeed,
    ValueChanged<SelahShepherdCheckIn>? onMessage,
    Widget? needsStatus,
    Widget updates = const Text('Existing updates'),
  }) => MaterialApp(
    home: Scaffold(
      body: SelahShepherdDashboardView(
        prayerRequests: SelahPrayerRequestsBlock(
          requests: const [],
          shepherdId: 'main',
          linkedSeekerNames: const ['James', 'Joel'],
          onPray: (_) {},
          showFooter: false,
        ),
        needs: needs,
        checkIns: checkIns,
        updates: updates,
        needsStatus: needsStatus,
        onNeed: onNeed ?? (_) {},
        onMessage: onMessage ?? (_) {},
      ),
    ),
  );
  testWidgets('unavailable sources retain supplied source-state widgets', (
    tester,
  ) async {
    await tester.pumpWidget(
      page(
        needsStatus: const Text('PRIORITIES UNAVAILABLE'),
        updates: const Text('UPDATES UNAVAILABLE'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('NEEDS YOU'), findsOneWidget);
    expect(find.text('PRIORITIES UNAVAILABLE'), findsOneWidget);
    expect(find.text('Nothing needs you right now.'), findsNothing);
    expect(find.text('UPDATES UNAVAILABLE'), findsOneWidget);
  });
  testWidgets('standalone Prayer retains its footer by default', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SelahPrayerRequestsBlock(
            requests: const [],
            shepherdId: 'main',
            linkedSeekerNames: const ['James', 'Joel'],
            onPray: (_) {},
          ),
        ),
      ),
    );
    expect(
      find.text(
        'Seekers you walk with can ask you for prayer. They see when you have prayed.',
      ),
      findsOneWidget,
    );
  });
  testWidgets(
    'LOCK20 empty Needs you hides check-ins and retains Prayer and note',
    (tester) async {
      await tester.pumpWidget(page());
      await tester.pumpAndSettle();
      expect(find.text('Nothing needs you right now.'), findsOneWidget);
      expect(find.text('A GOOD TIME TO CHECK IN'), findsNothing);
      expect(find.text('PRAYER REQUESTS'), findsOneWidget);
      expect(
        find.text(
          'Seekers you walk with can ask you for prayer. They see when you have prayed.',
        ),
        findsOneWidget,
      );
      for (final text in [
        'RIGHT NOW',
        'FAMILY SNAPSHOT',
        'YOUR FAMILY',
        'INSIGHTS',
        'Upgrade to unlock',
      ]) {
        expect(find.textContaining(text), findsNothing);
      }
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('LOCK20 actions address their actual supplied person and event', (
    tester,
  ) async {
    const need = SelahShepherdDashboardNeed(
      id: 'request-1',
      seekerId: 'self',
      title: 'Naomi asked James to begin',
      detail: 'He hasn’t answered yet. A word from you may help.',
      actionLabel: 'Encourage',
    );
    final event = SelahShepherdCheckIn(
      key: 'journey:from:phase_1',
      journeyId: 'journey',
      identity: const SelahShepherdCheckInIdentity(
        seekerId: 'self',
        seekerFirstName: 'James',
        counterpartFirstName: 'Esther',
      ),
      stage: SelahJourneyStages.of('phase_1')!,
      occurredAt: DateTime(2026, 11, 6),
    );
    SelahShepherdDashboardNeed? addressedNeed;
    SelahShepherdCheckIn? addressedEvent;
    await tester.pumpWidget(
      page(
        needs: [need],
        checkIns: [event],
        onNeed: (value) => addressedNeed = value,
        onMessage: (value) => addressedEvent = value,
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Encourage'));
    await tester.tap(find.text('Encourage'));
    expect(addressedNeed, same(need));
    await tester.ensureVisible(find.text('Message James'));
    await tester.tap(find.text('Message James'));
    expect(addressedEvent, same(event));
    expect(
      find.text('James and Esther reached Faith & Values'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
