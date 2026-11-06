import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:selah/config/selah_native_identity_policy.dart';
import 'package:selah/draft/selah_draft_runtime.dart';
import 'package:selah/data/selah_reference_data.dart';
import 'package:selah/models/selah_languages_controller.dart';
import 'package:selah/dev/selah_request_account_session.dart';
import 'package:selah/services/selah_seeker_details_service.dart';
import 'package:selah/theme/selah_colors.dart';
import 'package:selah/theme/selah_interaction_style.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(SelahDraftRuntime.stop);

  test(
    'denied owners are never read and a throwing read fails closed',
    () async {
      var reads = 0;
      var writes = 0;
      final denied = SelahLanguagesController(
        canAct: () => false,
        read: () {
          reads++;
          return [selahLanguageNames.first];
        },
        save: (_) {
          writes++;
          return true;
        },
      );
      expect(reads, 0);
      expect(denied.languages, isEmpty);
      expect(await denied.save(), isFalse);
      expect(reads, 0);
      denied.dispose();
      final throwing = SelahLanguagesController(
        canAct: () => true,
        read: () {
          reads++;
          throw StateError('unavailable');
        },
        save: (_) {
          writes++;
          return true;
        },
      );
      expect(reads, 0);
      expect(throwing.languages, isEmpty);
      expect(throwing.current, isFalse);
      expect(await throwing.save(), isFalse);
      expect(writes, 0);
      throwing.dispose();
    },
  );

  test(
    'only existing-list language choices can reach a save callback',
    () async {
      List<String>? saved;
      final c = SelahLanguagesController(
        canAct: () => true,
        read: () => [
          'invalid',
          selahLanguageNames.first,
          selahLanguageNames.first,
        ],
        save: (value) {
          saved = value;
          return true;
        },
      );
      expect(await c.save(), isTrue);
      expect(saved, [selahLanguageNames.first]);
      c.dispose();
    },
  );

  test(
    'private presets cannot interrupt a real pending write and unlock a duplicate',
    () async {
      expect(
        SelahDraftRuntime.activate(
          bundleId: SelahNativeIdentityPolicy.productionBundleId,
        ),
        isTrue,
        reason: 'Use actual SELAH_DRAFT_LOCAL_ONLY=true, no bypass.',
      );
      var calls = 0;
      final result = Completer<bool>();
      final c = SelahLanguagesController(
        canAct: () => SelahDraftRuntime.active,
        read: () => [selahLanguageNames.first],
        save: (_) {
          calls++;
          return result.future;
        },
      );
      final pending = c.save();
      c.showFailure();
      c.showSaving();
      expect(c.saveState, SelahLanguagesSaveState.saving);
      expect(await c.save(), isFalse);
      expect(calls, 1);
      result.complete(true);
      expect(await pending, isTrue);
      expect(c.saveState, SelahLanguagesSaveState.saved);
      c.dispose();
    },
  );

  test('revocation during saving notification prevents dispatch', () async {
    var current = true;
    var calls = 0;
    final c = SelahLanguagesController(
      canAct: () => current,
      read: () => [selahLanguageNames.first],
      save: (_) {
        calls++;
        return true;
      },
    );
    c.addListener(() {
      current = false;
    });
    expect(await c.save(), isFalse);
    expect(calls, 0);
    c.dispose();
  });
  test('required valid choices toggle and save an immutable list', () async {
    var calls = 0;
    List<String>? saved;
    final c = SelahLanguagesController(
      canAct: () => true,
      read: () => [],
      save: (v) {
        calls++;
        saved = v;
        return true;
      },
    );
    expect(await c.save(), isFalse);
    expect(c.showRequiredError, isTrue);
    c.toggle('invalid');
    expect(c.languages, isEmpty);
    c.toggle(selahLanguageNames.first);
    c.toggle(selahLanguageNames[1]);
    c.toggle(selahLanguageNames[1]);
    expect(c.languages, [selahLanguageNames.first]);
    expect(await c.save(), isTrue);
    expect(calls, 1);
    expect(saved, c.languages);
    expect(() => saved!.add('invalid'), throwsUnsupportedError);
    c.dispose();
  });
  test(
    'pending save denies repeat and edits; disposed result is ignored',
    () async {
      final result = Completer<bool>();
      var calls = 0;
      final c = SelahLanguagesController(
        canAct: () => true,
        read: () => [selahLanguageNames.first],
        save: (_) {
          calls++;
          return result.future;
        },
      );
      final pending = c.save();
      c.toggle(selahLanguageNames[1]);
      expect(c.languages.length, 1);
      expect(await c.save(), isFalse);
      expect(calls, 1);
      c.dispose();
      result.complete(true);
      expect(await pending, isFalse);
    },
  );
  test('denial and throwing owner checks fail closed permanently', () async {
    var allowed = true;
    var calls = 0;
    final c = SelahLanguagesController(
      canAct: () => allowed,
      read: () => [],
      save: (_) {
        calls++;
        return true;
      },
    );
    allowed = false;
    c.toggle(selahLanguageNames.first);
    allowed = true;
    expect(await c.save(), isFalse);
    expect(c.languages, isEmpty);
    expect(calls, 0);
    c.dispose();
    final throwing = SelahLanguagesController(
      canAct: () => throw StateError('gone'),
      read: () => [],
      save: (_) => true,
    );
    expect(await throwing.save(), isFalse);
    throwing.dispose();
  });
  test('failed save retries the same choices', () async {
    var calls = 0;
    final c = SelahLanguagesController(
      canAct: () => true,
      read: () => [selahLanguageNames.first],
      save: (_) => ++calls > 1,
    );
    expect(await c.save(), isFalse);
    expect(c.saveState, SelahLanguagesSaveState.failed);
    expect(await c.save(), isTrue);
    expect(calls, 2);
    c.dispose();
  });
  test(
    'session stores existing languages while preserving old background fields',
    () {
      var current = true;
      final owner = SelahRequestAccountSession(
        canAct: () => current,
        palette: SelahColors.devPalette,
        hapticLevel: SelahInteractionStyle.hapticLevel,
        goldEnabled: false,
      );
      owner.seedDetails(
        const SeekerDetails(
          countryOfBirth: 'United Kingdom',
          nationality: 'British',
          ethnicity: 'Other',
          preferences: {'untouched': true},
        ),
      );
      final input = [selahLanguageNames.first, selahLanguageNames.first];
      expect(owner.saveLanguages(input), isTrue);
      input.clear();
      expect(owner.details.languages, [selahLanguageNames.first]);
      expect(owner.details.countryOfBirth, 'United Kingdom');
      expect(owner.details.nationality, 'British');
      expect(owner.details.ethnicity, 'Other');
      expect(owner.details.preferences['untouched'], isTrue);
      expect(owner.saveLanguages([]), isFalse);
      expect(owner.saveLanguages(['invalid']), isFalse);
      current = false;
      expect(owner.saveLanguages([selahLanguageNames[1]]), isFalse);
      current = true;
      expect(owner.saveLanguages([selahLanguageNames[1]]), isFalse);
      owner.dispose();
    },
  );
}
