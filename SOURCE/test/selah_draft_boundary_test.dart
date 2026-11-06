// Source-level draft boundary assertions. These are not claims of real-member,
// provider, purchase, camera or installed-device verification.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  test('Selah is a separate Dart package and native draft app', () {
    expect(source('pubspec.yaml'), matches(RegExp(r'^name:\s*selah\s*$', multiLine: true)));
    final project = source('ios/Runner.xcodeproj/project.pbxproj');
    final plist = source('ios/Runner/Info.plist');
    final literal = RegExp(r'<key>CFBundleDisplayName</key>\s*<string>Selah</string>')
        .hasMatch(plist);
    final variable = RegExp(r'<key>CFBundleDisplayName</key>\s*<string>\$\(APP_DISPLAY_NAME\)</string>')
        .hasMatch(plist);
    expect(literal || variable, isTrue);
    if (variable) {
      final names = RegExp(r'APP_DISPLAY_NAME\s*=\s*([^;]+);')
          .allMatches(project)
          .map((match) => match[1]!.trim());
      expect(names, isNotEmpty);
      expect(names.every((name) => name == 'Selah'), isTrue);
    }
    final ids = RegExp(r'PRODUCT_BUNDLE_IDENTIFIER\s*=\s*([^;]+);')
        .allMatches(project)
        .map((match) => match[1]!.trim().replaceAll('"', ''));
    expect(ids, isNotEmpty);
    for (final id in ids) {
      expect(id, matches(RegExp(r'^com\.blackumbrella\.selah\.draft(?:\.RunnerTests)?$')));
    }
  });

  test('fresh main opens only the offline Selah draft core', () {
    final main = source('lib/main.dart');
    expect(main, contains('SelahOneJourneyConceptShell'));
    expect(main, contains('SelahConceptPreviewBoundary'));
    expect(main, matches(RegExp(r'SelahInternalPreviewClient\s*\.\s*beginPreview\s*\(')));
    expect(main, matches(RegExp(r'HttpOverrides\s*\.\s*global\s*=')));
    expect(main, isNot(matches(RegExp(r'Supabase\s*\.\s*initialize\s*\('))));
    expect(main, isNot(matches(RegExp(r'package:zyra/|zyraconnect|\.supabase\.co'))));
    expect(main, isNot(matches(RegExp(r'(?:AuthGate|HomeShell|MentorHomeShell)\s*\('))));
  });

  test('no inherited backend, login or native account-sharing configuration', () {
    final backend = source('lib/config/supabase_config.dart');
    expect(backend, matches(RegExp(r"url\s*=\s*''")));
    expect(backend, matches(RegExp(r"publishableKey\s*=\s*''")));
    expect(backend, matches(RegExp(r'isConfigured\s*=\s*false')));
    final oauth = source('lib/config/oauth_config.dart');
    expect(oauth, matches(RegExp(r"googleWebClientId\s*=\s*''")));
    expect(oauth, matches(RegExp(r"googleIosClientId\s*=\s*''")));
    expect(oauth, matches(RegExp(r'isGoogleConfigured\s*=\s*false')));
    for (final path in ['lib/config/selah_internal_founder_policy.dart', 'lib/config/selah_external_tester_policy.dart']) {
      expect(source(path), matches(RegExp(r'enabled\s*=\s*false')));
    }
    expect(source('ios/Runner/Info.plist'), isNot(matches(RegExp(r'CFBundleURLTypes|com\.apple\.developer\.associated-domains'))));
    expect(source('ios/Runner/Runner.entitlements'), isNot(matches(RegExp(r'keychain-access-groups|com\.apple\.security\.application-groups|com\.apple\.developer\.applesignin'))));
  });

  test('new entry and config retain an explicit release refusal', () {
    final runtime = source('lib/draft/selah_draft_runtime.dart');
    expect(runtime, matches(RegExp(r'bool\s+get\s+active\s*=>\s*_active\s*&&\s*!kReleaseMode')));
    expect(runtime, matches(RegExp(r'_active\s*=\s*!kReleaseMode\s*&&\s*\n?\s*bundleId\s*==\s*SelahNativeIdentityPolicy\.productionBundleId')));
    expect(runtime, matches(RegExp(r'HttpClient\s+createHttpClient\([^)]*\)\s*=>\s*throw\s+const\s+SocketException')));
    final main = source('lib/main.dart');
    expect(main, matches(RegExp(r'const\s+bool\s+supabaseReady\s*=\s*false')));
    expect(main, matches(RegExp(r'SupabaseClient\s+get\s+supabase\s*=>\s*throw\s+StateError')));
  });

  test('core routes and Christian identity remain available', () {
    final shell = source('lib/dev/selah_one_journey_concept_shell.dart');
    for (final route in ['Browse', 'Journey', 'My Selah', 'Shepherd', 'Profile', 'Compatibility', 'Journey requests']) {
      expect(shell, contains(route));
    }
    expect(
      source('lib/data/selah_reference_data.dart') + shell + source('lib/main.dart'),
      matches(RegExp(r'Christian|Christ-centred|Christ centered|Jesus')),
    );
  });

  test('every first-draft local portrait asset is present', () {
    for (final name in ['selah1a', 'selah1b', 'selah1c', 'selah2a', 'selah2b', 'selah3a', 'selah3b',
      'selah3c', 'selah4a', 'selah5a', 'selah5b', 'selah6a', 'selah7a', 'selah8a', 'seeker_self', 'shepherd_self']) {
      expect(File('assets/dev/one_journey_photos/$name.jpg').existsSync(), isTrue);
    }
  });
}
