import 'dart:convert';
import 'dart:io';

Never _fail(String message) {
  stderr.writeln('Selah delivery preflight failed: $message');
  exit(1);
}

dynamic _readJson(File file) {
  if (!file.existsSync()) {
    _fail('missing ${file.path}');
  }
  try {
    return jsonDecode(file.readAsStringSync());
  } on FormatException catch (error) {
    _fail('invalid JSON in ${file.path}: ${error.message}');
  }
}

String _canonicalDirectory(String path) {
  final directory = Directory(path);
  if (!directory.existsSync()) {
    _fail('missing directory $path');
  }
  return directory.resolveSymbolicLinksSync();
}

String _resolvePackageRoot(Uri rootUri, Uri configDirectory) {
  final resolved = rootUri.hasScheme ? rootUri : configDirectory.resolveUri(rootUri);
  if (resolved.scheme != 'file') {
    _fail('package root is not local: $resolved');
  }
  return _canonicalDirectory(resolved.toFilePath());
}

void _checkPackageConfig(String root) {
  final config = File('$root/.dart_tool/package_config.json');
  final pubspec = File('$root/pubspec.yaml');
  final lock = File('$root/pubspec.lock');
  final parsed = _readJson(config);
  if (parsed is! Map<String, dynamic> || parsed['configVersion'] != 2) {
    _fail('package_config.json is not configVersion 2');
  }
  if (!pubspec.existsSync() || !lock.existsSync()) {
    _fail('pubspec.yaml or pubspec.lock is missing');
  }
  final newestInput = pubspec.lastModifiedSync().isAfter(lock.lastModifiedSync())
      ? pubspec.lastModifiedSync()
      : lock.lastModifiedSync();
  if (config.lastModifiedSync().isBefore(newestInput)) {
    _fail(
      'package_config.json is older than pubspec input; prepare dependencies '
      'explicitly with tooling/flutter_cached.sh pub get --offline',
    );
  }
  final packages = parsed['packages'];
  if (packages is! List || packages.isEmpty) {
    _fail('package_config.json has no packages');
  }
  final configDirectory = config.parent.uri;
  var foundSelah = false;
  for (final value in packages) {
    if (value is! Map<String, dynamic>) {
      _fail('package_config.json contains a malformed package');
    }
    final name = value['name'];
    final rootValue = value['rootUri'];
    if (name is! String || name.isEmpty || rootValue is! String) {
      _fail('package_config.json contains an unnamed package or missing root');
    }
    final packageRoot = _resolvePackageRoot(Uri.parse(rootValue), configDirectory);
    if (name == 'selah') {
      foundSelah = true;
      if (packageRoot != root) {
        _fail('the selah package points outside this source tree: $packageRoot');
      }
    }
  }
  if (!foundSelah) {
    _fail('package_config.json does not contain the selah package');
  }
  stdout.writeln('Prepared Dart packages: ${packages.length}.');
}

void _checkSwiftPackages(String root) {
  final resolvedFile = File(
    '$root/ios/Runner.xcworkspace/xcshareddata/swiftpm/Package.resolved',
  );
  final parsed = _readJson(resolvedFile);
  if (parsed is! Map<String, dynamic> || parsed['version'] != 2) {
    _fail('Swift Package.resolved is missing version 2 state');
  }
  final pins = parsed['pins'];
  if (pins is! List) {
    _fail('Swift Package.resolved has no pins list');
  }
  final checkouts = Directory('$root/build/ios/SourcePackages/checkouts');
  if (!checkouts.existsSync()) {
    _fail(
      'prepared Swift package checkouts are missing; this delivery path will '
      'not fetch them silently',
    );
  }
  final available = <String, Directory>{};
  for (final entity in checkouts.listSync(followLinks: false)) {
    if (entity is Directory) {
      available[entity.uri.pathSegments
              .where((segment) => segment.isNotEmpty)
              .last
              .toLowerCase()] =
          entity;
    }
  }
  final revisionPattern = RegExp(r'^[0-9a-f]{40}$');
  for (final value in pins) {
    if (value is! Map<String, dynamic>) {
      _fail('Swift Package.resolved contains a malformed pin');
    }
    final identity = value['identity'];
    final location = value['location'];
    final state = value['state'];
    if (identity is! String ||
        location is! String ||
        state is! Map<String, dynamic> ||
        state['revision'] is! String) {
      _fail('Swift Package.resolved contains an incomplete pin');
    }
    final revision = state['revision'] as String;
    if (!revisionPattern.hasMatch(revision)) {
      _fail('Swift package $identity has an invalid pinned revision');
    }
    final repositoryName = Uri.parse(location).pathSegments.last.replaceFirst(
          RegExp(r'\.git$'),
          '',
        );
    final checkout = available[identity.toLowerCase()] ??
        available[repositoryName.toLowerCase()];
    if (checkout == null) {
      _fail('prepared checkout for Swift package $identity is missing');
    }
    final head = File('${checkout.path}/.git/HEAD');
    if (!head.existsSync() || head.readAsStringSync().trim() != revision) {
      _fail(
        'prepared checkout for Swift package $identity is not at its locked '
        'revision; no resolution or update was attempted',
      );
    }
  }
  stdout.writeln('Prepared locked Swift packages: ${pins.length}.');
}

void main(List<String> arguments) {
  if (arguments.length != 1) {
    _fail('usage: delivery_preflight.dart PROJECT_ROOT');
  }
  final root = _canonicalDirectory(arguments.single);
  for (final relativePath in <String>[
    'lib/main.dart',
    'pubspec.yaml',
    'pubspec.lock',
    'ios/Runner.xcworkspace/contents.xcworkspacedata',
    'ios/Runner.xcodeproj/xcshareddata/xcschemes/draft.xcscheme',
    'ios/Flutter/Profile-draft.xcconfig',
  ]) {
    if (!File('$root/$relativePath').existsSync()) {
      _fail('missing $relativePath');
    }
  }
  for (final relativePath in <String>[
    '.env',
    '.env.local',
    'ios/Runner/GoogleService-Info.plist',
  ]) {
    if (File('$root/$relativePath').existsSync()) {
      _fail('unexpected provider/environment file $relativePath');
    }
  }
  _checkPackageConfig(root);
  _checkSwiftPackages(root);
}
