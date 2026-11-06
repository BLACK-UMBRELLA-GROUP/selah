import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:selah/models/selah_marriage_values.dart';
import 'package:selah/models/selah_non_faith_profile_save.dart';

void main() {
  SelahMarriageValuesAnswers marriage() => SelahMarriageValuesAnswers(
    marriedBefore: 'No',
    children: 'No',
    wouldLikeChildren: 'Open to it',
    rolesInMarriage: 'Equal partners who decide together',
    openToDivorced: 'No',
    whereToLive: 'Open to moving abroad',
    hopingToMarry: 'In 1–2 years',
  );
  Map<String, dynamic> stored() => {
    'faith_profile': {'tradition': 'Baptist', 'words': 'stored faith'},
    'church_background': {
      'scope': 'same_family',
      'outside_flexibility': 'yellow',
    },
    'faith_journey': {'flexibility': 'unasked old value'},
    'country_of_birth': {
      'preferred': ['old-code'],
      'skipped': false,
      'unknown': 'retain',
    },
    'nationality': {
      'preferred': ['GB'],
      'flexibility': 'red',
    },
    'ethnicity': {
      'preferred': ['old-background'],
    },
    'languages': {
      'preferred': ['de'],
      'flexibility': 'green',
    },
    'marriage_values': {'unknown': 'retain'},
    'location': {
      'preference': 'anywhere',
      'flexibility': 'red',
      'unknown': 'retain',
    },
    'unknown': {'keep': true},
  };

  test(
    'Skip payload writes only asked nonfaith columns and preserves stored sections',
    () async {
      final original = stored();
      final originalJson = jsonEncode(original);
      Map<String, dynamic>? payload;
      expect(
        await selahSaveNonFaithProfile(
          userId: 'existing-owner',
          languages: ['English', 'French', 'English'],
          marriageValues: marriage(),
          locationPreference: {
            'preference': 'same_country',
            'flexibility': 'yellow',
            'unasked': 'ignore',
          },
          canAct: () => true,
          readStoredPreferences: () async => original,
          write: (value) async {
            payload = value;
            return true;
          },
        ),
        isTrue,
      );
      expect(payload!.keys.toSet(), {'user_id', 'languages', 'preferences'});
      expect(payload!['user_id'], 'existing-owner');
      expect(payload!['languages'], ['en', 'fr']);
      final saved = payload!['preferences'] as Map;
      for (final entry in original.entries.where(
        (entry) => !{'location', 'marriage_values'}.contains(entry.key),
      )) {
        expect(saved[entry.key], entry.value, reason: 'unchanged ${entry.key}');
      }
      expect(saved['location'], {
        'preference': 'same_country',
        'flexibility': 'yellow',
        'unknown': 'retain',
      });
      expect(saved['marriage_values'], {
        'unknown': 'retain',
        ...marriage().toMap(),
      });
      expect(jsonEncode(original), originalJson);
    },
  );

  test(
    'languages only never writes preferences; marriage only never writes unasked languages',
    () async {
      var reads = 0;
      Map<String, dynamic>? payload;
      expect(
        await selahSaveNonFaithProfile(
          userId: 'existing-owner',
          languages: ['English'],
          canAct: () => true,
          readStoredPreferences: () async {
            reads++;
            return stored();
          },
          write: (value) async {
            payload = value;
            return true;
          },
        ),
        isTrue,
      );
      expect(reads, 0);
      expect(payload!.keys.toSet(), {'user_id', 'languages'});
      expect(
        await selahSaveNonFaithProfile(
          userId: 'existing-owner',
          marriageValues: marriage(),
          canAct: () => true,
          readStoredPreferences: () async {
            reads++;
            return stored();
          },
          write: (value) async {
            payload = value;
            return true;
          },
        ),
        isTrue,
      );
      expect(reads, 1);
      expect(payload!.keys.toSet(), {'user_id', 'preferences'});
    },
  );

  test('invalid or unasked input never reaches storage', () async {
    var reads = 0;
    var writes = 0;
    Future<bool> attempt({
      String userId = 'existing-owner',
      List<String>? languages,
      SelahMarriageValuesAnswers? values,
      Map<String, dynamic>? location,
    }) => selahSaveNonFaithProfile(
      userId: userId,
      languages: languages,
      marriageValues: values,
      locationPreference: location,
      canAct: () => true,
      readStoredPreferences: () async {
        reads++;
        return {};
      },
      write: (_) async {
        writes++;
        return true;
      },
    );
    expect(await attempt(), isFalse);
    expect(await attempt(userId: '', languages: ['English']), isFalse);
    expect(await attempt(languages: []), isFalse);
    expect(await attempt(languages: ['invented']), isFalse);
    expect(
      await attempt(values: SelahMarriageValuesAnswers(marriedBefore: 'No')),
      isFalse,
    );
    expect(
      await attempt(
        location: {'preference': 'invented', 'flexibility': 'green'},
      ),
      isFalse,
    );
    expect(
      await attempt(
        location: {'preference': 'same_country', 'flexibility': 'blue'},
      ),
      isFalse,
    );
    expect(reads, 0);
    expect(writes, 0);
  });

  test('denied or throwing owner is never read or written', () async {
    var calls = 0;
    for (final throws in [false, true]) {
      expect(
        await selahSaveNonFaithProfile(
          userId: 'existing-owner',
          marriageValues: marriage(),
          canAct: () => throws ? throw StateError('owner unavailable') : false,
          readStoredPreferences: () async {
            calls++;
            return {};
          },
          write: (_) async {
            calls++;
            return true;
          },
        ),
        isFalse,
      );
    }
    expect(calls, 0);
  });

  test('owner change during preference read prevents the write', () async {
    var current = true;
    var writes = 0;
    final read = Completer<Map<String, dynamic>>();
    final pending = selahSaveNonFaithProfile(
      userId: 'existing-owner',
      marriageValues: marriage(),
      canAct: () => current,
      readStoredPreferences: () => read.future,
      write: (_) async {
        writes++;
        return true;
      },
    );
    current = false;
    read.complete(stored());
    expect(await pending, isFalse);
    expect(writes, 0);
  });

  test(
    'submitted languages/location are captured before the preference read yields',
    () async {
      final input = ['English'];
      final location = <String, dynamic>{
        'preference': 'same_country',
        'flexibility': 'yellow',
      };
      final read = Completer<Map<String, dynamic>>();
      Map<String, dynamic>? payload;
      final pending = selahSaveNonFaithProfile(
        userId: 'existing-owner',
        languages: input,
        marriageValues: marriage(),
        locationPreference: location,
        canAct: () => true,
        readStoredPreferences: () => read.future,
        write: (value) async {
          payload = value;
          return true;
        },
      );
      input
        ..clear()
        ..add('French');
      location['flexibility'] = 'red';
      read.complete(stored());
      expect(await pending, isTrue);
      expect(payload!['languages'], ['en']);
      expect(
        (payload!['preferences'] as Map)['location']['flexibility'],
        'yellow',
      );
    },
  );

  test(
    'write failure, read failure and revoked completion never report success',
    () async {
      var writes = 0;
      expect(
        await selahSaveNonFaithProfile(
          userId: 'existing-owner',
          marriageValues: marriage(),
          canAct: () => true,
          readStoredPreferences: () async => throw StateError('read failed'),
          write: (_) async {
            writes++;
            return true;
          },
        ),
        isFalse,
      );
      expect(writes, 0);
      for (final throws in [false, true]) {
        expect(
          await selahSaveNonFaithProfile(
            userId: 'existing-owner',
            languages: ['English'],
            canAct: () => true,
            readStoredPreferences: () async => {},
            write: (_) async =>
                throws ? throw StateError('write failed') : false,
          ),
          isFalse,
        );
      }
      var current = true;
      final result = Completer<bool>();
      final pending = selahSaveNonFaithProfile(
        userId: 'existing-owner',
        languages: ['English'],
        canAct: () => current,
        readStoredPreferences: () async => {},
        write: (_) => result.future,
      );
      current = false;
      result.complete(true);
      expect(await pending, isFalse);
    },
  );

  test('Chapter2 rebuild changes only asked preference sections', () {
    final original = stored();
    final snapshot = jsonEncode(original);
    final updated = {
      for (final key in [
        'country_of_birth',
        'nationality',
        'ethnicity',
        'languages',
        'faith_journey',
      ])
        key: {'preferred': [], 'skipped': false, 'flexibility': null},
      'location': {'preference': 'same_country', 'flexibility': 'green'},
      'church_background': {
        'scope': 'no_preference',
        'outside_flexibility': 'green',
      },
    };
    final merged = selahMergeAskedProfilePreferences(original, updated);
    for (final key in [
      'country_of_birth',
      'nationality',
      'ethnicity',
      'languages',
      'faith_journey',
    ]) {
      expect(
        merged[key],
        original[key],
        reason: 'unasked $key retained exactly',
      );
    }
    expect(merged['unknown'], original['unknown']);
    expect(merged['faith_profile'], original['faith_profile']);
    expect(merged['location'], {
      'preference': 'same_country',
      'flexibility': 'green',
      'unknown': 'retain',
    });
    expect(merged['church_background'], {
      'scope': 'no_preference',
      'outside_flexibility': 'green',
    });
    expect(jsonEncode(original), snapshot);
  });
}
