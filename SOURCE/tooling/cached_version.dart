import 'dart:convert';
import 'dart:io';

String _readTrimmed(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    throw FileSystemException('Required cached file is missing.', path);
  }
  return file.readAsStringSync().trim();
}

void _requirePath(String path, {bool directory = false}) {
  final exists = directory ? Directory(path).existsSync() : File(path).existsSync();
  if (!exists) {
    throw FileSystemException('Required cached artifact is missing.', path);
  }
}

void _requireStamp(String flutterRoot, String artifact, String expected) {
  final stamp = _readTrimmed('$flutterRoot/bin/cache/$artifact.stamp');
  if (stamp != expected) {
    throw FormatException(
      'Pinned Flutter cache stamp changed for $artifact. Refusing a cache update.',
    );
  }
}

void _validateToolPackages(String flutterRoot) {
  final configFile = File(
    '$flutterRoot/packages/flutter_tools/.dart_tool/package_config.json',
  );
  final decoded = jsonDecode(_readTrimmed(configFile.path));
  if (decoded is! Map<String, dynamic> || decoded['packages'] is! List) {
    throw const FormatException('Flutter tool package cache is invalid.');
  }
  for (final entry in decoded['packages'] as List) {
    if (entry is! Map<String, dynamic> || entry['rootUri'] is! String) {
      throw const FormatException('Flutter tool package cache has an invalid entry.');
    }
    final value = Uri.parse(entry['rootUri'] as String);
    final resolved = value.hasScheme ? value : configFile.parent.uri.resolveUri(value);
    if (resolved.scheme != 'file') {
      throw const FormatException('Flutter tool package cache is not fully local.');
    }
    _requirePath('${resolved.toFilePath()}/pubspec.yaml');
  }
}

void _validateUniversalAndIosArtifacts(
  String flutterRoot,
  Map<String, dynamic> manifest,
) {
  final cache = '$flutterRoot/bin/cache';
  final artifacts = '$cache/artifacts';
  final engine = '$artifacts/engine';
  final engineRevision = manifest['engineRevision'] as String;

  for (final artifact in <String>['material_fonts', 'gradle_wrapper']) {
    final expected = _readTrimmed('$flutterRoot/bin/internal/$artifact.version');
    _requireStamp(flutterRoot, artifact, expected);
    _requirePath('$artifacts/$artifact', directory: true);
  }
  _requirePath('$artifacts/material_fonts/MaterialIcons-Regular.otf');
  for (final path in <String>[
    '$artifacts/gradle_wrapper/gradlew',
    '$artifacts/gradle_wrapper/gradlew.bat',
    '$artifacts/gradle_wrapper/gradle/wrapper/gradle-wrapper.jar',
  ]) {
    _requirePath(path);
  }

  for (final artifact in <String>['flutter_sdk', 'ios-sdk', 'font-subset']) {
    _requireStamp(flutterRoot, artifact, engineRevision);
  }
  for (final path in <String>[
    '$cache/pkg/sky_engine',
    '$cache/pkg/flutter_gpu',
    '$engine/common',
    '$engine/darwin-x64',
    '$engine/ios',
    '$engine/ios-profile',
    '$engine/ios-release',
  ]) {
    _requirePath(path, directory: true);
  }
  for (final path in <String>[
    '$engine/ios/LICENSE',
    '$engine/ios-profile/LICENSE',
    '$engine/ios-release/LICENSE',
    '$engine/ios-profile/Flutter.xcframework/Info.plist',
    '$engine/ios-profile/gen_snapshot_arm64',
    '$engine/darwin-x64/font-subset',
    '$engine/darwin-x64/frontend_server_aot.dart.snapshot',
  ]) {
    _requirePath(path);
  }

  const usbExecutables = <String, List<String>>{
    'libimobiledevice': ['idevicescreenshot', 'idevicesyslog'],
    'libusbmuxd': ['iproxy'],
    'libplist': [],
    'openssl': [],
    'libimobiledeviceglue': [],
    'ios-deploy': [],
  };
  for (final entry in usbExecutables.entries) {
    final expected = _readTrimmed(
      '$flutterRoot/bin/internal/${entry.key}.version',
    );
    _requireStamp(flutterRoot, entry.key, expected);
    final location = '$artifacts/${entry.key}';
    _requirePath(location, directory: true);
    for (final executable in entry.value) {
      _requirePath('$location/$executable');
    }
  }

  _validateToolPackages(flutterRoot);
}

/// Refuse a missing or changed cache before Flutter can fall back to Git.
/// These fields match Flutter 3.44.2's cached version manifest.
void validateCachedFlutterRoot(String flutterRoot) {
  final cache = '$flutterRoot/bin/cache';
  final manifestFile = File('$cache/flutter.version.json');
  if (!manifestFile.existsSync()) {
    throw FileSystemException(
      'Pinned Flutter version manifest is missing.',
      manifestFile.path,
    );
  }
  final manifest = jsonDecode(manifestFile.readAsStringSync());
  if (manifest is! Map<String, dynamic>) {
    throw const FormatException('Flutter version cache must be a JSON object.');
  }
  const requiredFields = <String>[
    'frameworkVersion',
    'channel',
    'repositoryUrl',
    'frameworkRevision',
    'frameworkCommitDate',
    'engineRevision',
    'dartSdkVersion',
    'devToolsVersion',
    'flutterVersion',
  ];
  for (final field in requiredFields) {
    if (manifest[field] is! String || (manifest[field] as String).isEmpty) {
      throw FormatException('Flutter version cache has an invalid $field.');
    }
  }
  for (final field in <String>[
    'engineCommitDate',
    'engineContentHash',
    'engineBuildDate',
  ]) {
    if (manifest[field] != null && manifest[field] is! String) {
      throw FormatException('Flutter version cache has an invalid $field.');
    }
  }
  if (manifest['frameworkVersion'] != '3.44.2' ||
      manifest['flutterVersion'] != '3.44.2' ||
      manifest['channel'] != 'stable' ||
      manifest['repositoryUrl'] != 'https://github.com/flutter/flutter.git' ||
      manifest['frameworkRevision'] !=
          'c9a6c484230f8b5e408ec57be1ef71dee1e77020' ||
      manifest['engineRevision'] !=
          '77e2e94772b6eb43759e34ed1ad7da4674e19cab' ||
      manifest['dartSdkVersion'] != '3.12.2') {
    throw const FormatException(
      'Selah delivery is pinned to cached Flutter 3.44.2. '
      'Review this project-local integration before changing SDK versions.',
    );
  }
  for (final relativePath in <String>[
    'dart-sdk/bin/dart',
    'flutter_tools.snapshot',
  ]) {
    if (!File('$cache/$relativePath').existsSync()) {
      throw FileSystemException(
        'Required cached tool is missing.',
        '$cache/$relativePath',
      );
    }
  }
  _validateUniversalAndIosArtifacts(flutterRoot, manifest);
}

void main(List<String> arguments) {
  if (arguments.length != 1) {
    stderr.writeln('Usage: cached_version.dart FLUTTER_ROOT');
    exit(2);
  }
  try {
    validateCachedFlutterRoot(arguments.single);
  } on FormatException catch (error) {
    stderr.writeln(error.message);
    exit(1);
  } on FileSystemException catch (error) {
    stderr.writeln(
      'Cached Flutter tooling unavailable: ${error.message} ${error.path ?? ''}',
    );
    exit(1);
  }
}
