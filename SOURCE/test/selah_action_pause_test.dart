import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selah/models/selah_action_pause.dart';
import 'package:selah/models/selah_action_pause_controller.dart';
import 'package:selah/screens/journey/selah_pause_screen.dart';
import 'package:selah/theme/selah_colors.dart';

const _ask = SelahActionPause(
  kind: SelahActionPauseKind.ask,
  name: 'Grace',
  shepherdName: 'Pastor David',
);

void main() {
  test('locked words, profile pronouns and no-Shepherd rule agree', () {
    expect(
      _ask.body,
      'Asking Grace to begin a Journey is a serious step toward marriage. '
      'Pastor David will see this request, and so will Grace’s Shepherd.',
    );
    const end = SelahActionPause(
      kind: SelahActionPauseKind.end,
      name: 'Esther',
    );
    expect(end.canOpen, isTrue);
    expect(
      end.body,
      'Ending your Journey with Esther closes it for both of you.',
    );
    for (final kind in [
      SelahActionPauseKind.ask,
      SelahActionPauseKind.accept,
      SelahActionPauseKind.replace,
    ]) {
      final pause = SelahActionPause(
        kind: kind,
        name: 'Naomi',
        endingName: 'Esther',
        otherGender: 'female',
      );
      expect(pause.canOpen, isFalse);
    }
    for (final gender in ['female', 'male']) {
      final pause = SelahActionPause(
        kind: SelahActionPauseKind.accept,
        name: 'Naomi',
        shepherdName: 'Pastor David',
        otherGender: gender,
      );
      expect(pause.body, contains(gender == 'female' ? 'hers' : 'his'));
    }
    const replace = SelahActionPause(
      kind: SelahActionPauseKind.replace,
      name: 'Naomi',
      endingName: 'Esther',
      shepherdName: 'Pastor David',
    );
    expect(
      replace.body,
      'You already have three Journeys. Accepting Naomi means ending your '
      'Journey with Esther. Your history stays. Pastor David will be told, '
      'and so will Esther’s and Naomi’s Shepherds.',
    );
    expect(replace.primaryLabel, 'End and accept');
  });

  test(
    'opening and cancelling never commit; confirmation commits once',
    () async {
      var commits = 0;
      final cancel = SelahActionPauseController(
        pause: _ask,
        canAct: () => true,
        commit: () {
          commits++;
          return true;
        },
      );
      expect(commits, 0);
      expect(cancel.cancel(), isTrue);
      expect(await cancel.confirm(), isFalse);
      expect(commits, 0);
      cancel.dispose();

      final confirm = SelahActionPauseController(
        pause: _ask,
        canAct: () => true,
        commit: () {
          commits++;
          return true;
        },
      );
      expect(await confirm.confirm(), isTrue);
      expect(await confirm.confirm(), isFalse);
      expect(commits, 1);
      expect(confirm.state, SelahActionPauseState.done);
      confirm.dispose();
    },
  );

  test(
    'missing Shepherd refuses without invoking the supplied action',
    () async {
      var commits = 0;
      final controller = SelahActionPauseController(
        pause: const SelahActionPause(
          kind: SelahActionPauseKind.ask,
          name: 'Grace',
        ),
        canAct: () => true,
        commit: () {
          commits++;
          return true;
        },
      );
      expect(await controller.confirm(), isFalse);
      expect(commits, 0);
      controller.dispose();
    },
  );

  test(
    'failed action retains the pause and retries the same callback',
    () async {
      var attempts = 0;
      final controller = SelahActionPauseController(
        pause: _ask,
        canAct: () => true,
        commit: () => ++attempts > 1,
      );
      expect(await controller.confirm(), isFalse);
      expect(controller.state, SelahActionPauseState.failed);
      expect(await controller.confirm(), isTrue);
      expect(attempts, 2);
      controller.dispose();
    },
  );

  test(
    'in-flight duplicate and late completion after cancel are inert',
    () async {
      final result = Completer<bool>();
      var commits = 0;
      final controller = SelahActionPauseController(
        pause: _ask,
        canAct: () => true,
        commit: () {
          commits++;
          return result.future;
        },
      );
      final first = controller.confirm();
      expect(controller.state, SelahActionPauseState.working);
      expect(await controller.confirm(), isFalse);
      expect(commits, 1);
      expect(controller.cancel(), isTrue);
      result.complete(true);
      expect(await first, isFalse);
      expect(controller.state, isNot(SelahActionPauseState.done));
      controller.dispose();
    },
  );

  test('owner denial is terminal, including A to B to A', () async {
    var allowed = true;
    var commits = 0;
    final controller = SelahActionPauseController(
      pause: _ask,
      canAct: () => allowed,
      commit: () {
        commits++;
        return true;
      },
    );
    allowed = false;
    expect(controller.active, isFalse);
    allowed = true;
    expect(await controller.confirm(), isFalse);
    expect(commits, 0);
    expect(
      controller.cancel(),
      isTrue,
      reason: 'The owned route can still close.',
    );
    controller.dispose();
  });

  Future<void> mountPause(
    WidgetTester tester,
    SelahActionPauseController controller,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              key: const ValueKey('open_pause'),
              onPressed: () => Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (pauseContext) => SelahPauseScreen(
                    controller: controller,
                    onCancel: () => Navigator.of(pauseContext).pop(false),
                    onDone: () => Navigator.of(pauseContext).pop(true),
                  ),
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('open_pause')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  testWidgets('Reduce Motion fills the bar and Not yet immediately cancels', (
    tester,
  ) async {
    var commits = 0;
    final controller = SelahActionPauseController(
      pause: _ask,
      canAct: () => true,
      commit: () {
        commits++;
        return true;
      },
    );
    addTearDown(controller.dispose);
    await mountPause(tester, controller);
    final bar = tester.widget<FractionallySizedBox>(
      find.byKey(const ValueKey('pause_breath')),
    );
    expect(bar.widthFactor, 1);
    final barSize = tester.getSize(find.byKey(const ValueKey('pause_breath')));
    expect(barSize.height, 4);
    expect(barSize.width, greaterThan(0));
    await tester.tap(find.byKey(const ValueKey('pause_not_yet')));
    await tester.pumpAndSettle();
    expect(find.byType(SelahPauseScreen), findsNothing);
    expect(commits, 0);
  });

  testWidgets('confirmation has no timer gate; failure Retry uses the action', (
    tester,
  ) async {
    var commits = 0;
    final controller = SelahActionPauseController(
      pause: _ask,
      canAct: () => true,
      commit: () => ++commits > 1,
    );
    addTearDown(controller.dispose);
    await mountPause(tester, controller);
    await tester.tap(find.byKey(const ValueKey('pause_confirm')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('pause_failure')), findsOneWidget);
    expect(commits, 1);
    await tester.tap(find.byKey(const ValueKey('pause_retry')));
    await tester.pumpAndSettle();
    expect(find.byType(SelahPauseScreen), findsNothing);
    expect(commits, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('working End keeps dawn text and a usable Not yet', (
    tester,
  ) async {
    final result = Completer<bool>();
    final controller = SelahActionPauseController(
      pause: const SelahActionPause(
        kind: SelahActionPauseKind.end,
        name: 'Esther',
      ),
      canAct: () => true,
      commit: () => result.future,
    );
    addTearDown(controller.dispose);
    await mountPause(tester, controller);
    await tester.tap(find.byKey(const ValueKey('pause_confirm')));
    await tester.pump();
    final button = tester.widget<OutlinedButton>(
      find.byKey(const ValueKey('pause_confirm')),
    );
    expect(button.onPressed, isNull);
    expect(
      button.style!.foregroundColor!.resolve({WidgetState.disabled}),
      SelahColors.dawn,
    );
    await tester.tap(find.byKey(const ValueKey('pause_not_yet')));
    await tester.pumpAndSettle();
    result.complete(false);
    await tester.pump();
    expect(find.byType(SelahPauseScreen), findsNothing);
  });
}
