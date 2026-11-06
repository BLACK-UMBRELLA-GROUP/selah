import 'dart:convert';
import 'dart:io';

Never _fail(String message) {
  stderr.writeln('Selah delivery receipt failed: $message');
  exit(1);
}

Map<String, dynamic> _map(dynamic value, String label) {
  if (value is! Map<String, dynamic>) {
    _fail('$label is missing or malformed');
  }
  return value;
}

List<dynamic> _list(dynamic value, String label) {
  if (value is! List) {
    _fail('$label is missing or malformed');
  }
  return value;
}

Map<String, dynamic> _receipt(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    _fail('missing receipt $path');
  }
  dynamic decoded;
  try {
    decoded = jsonDecode(file.readAsStringSync());
  } on FormatException catch (error) {
    _fail('invalid receipt JSON: ${error.message}');
  }
  final root = _map(decoded, 'receipt');
  final info = _map(root['info'], 'receipt info');
  if (info['outcome'] != 'success') {
    _fail('device command outcome was ${info['outcome']}');
  }
  return root;
}

String _containerFromUrl(String value) {
  final match = RegExp(
    r'/Bundle/Application/([^/]+)/[^/]+\.app/',
  ).firstMatch(value);
  if (match == null) {
    _fail('installed application URL is malformed');
  }
  return match.group(1)!;
}

bool _isInstalledRunner(dynamic executable, String container) {
  if (executable is! String ||
      !RegExp(r'^[A-Za-z0-9-]+$').hasMatch(container)) {
    return false;
  }
  final path =
      '/var/containers/Bundle/Application/$container/Runner.app/Runner';
  return <String>{
    path,
    '/private$path',
    'file://$path',
    'file:///private$path',
  }.contains(executable);
}

void main(List<String> arguments) {
  if (arguments.length < 2) {
    _fail(
      'usage: verify_devicectl_receipt.dart '
      '{device|lock|install|launch|apps|processes} RECEIPT [expected values]',
    );
  }
  final mode = arguments[0];
  final root = _receipt(arguments[1]);
  final result = _map(root['result'], 'receipt result');

  switch (mode) {
    case 'device':
      if (arguments.length != 3 || arguments[2].trim().isEmpty) {
        _fail('device requires the exact intended device UDID');
      }
      final devices = _list(result['devices'], 'device query');
      final matches = devices.whereType<Map<String, dynamic>>().where((device) {
        final properties = device['properties'];
        if (properties is! Map<String, dynamic>) return false;
        final hardware = properties['hardware'];
        return hardware is Map<String, dynamic> &&
            hardware['udid'] == arguments[2];
      }).toList();
      if (matches.length != 1) {
        _fail('device query does not identify exactly one intended iPhone');
      }
      final properties = _map(
        matches.single['properties'],
        'device properties',
      );
      final hardware = _map(properties['hardware'], 'device hardware');
      final connection = _map(properties['connection'], 'device connection');
      if (hardware['deviceType'] != 'iPhone' ||
          hardware['reality'] != 'physical' ||
          connection['pairingState'] != 'paired' ||
          connection['state'] != 'connected') {
        _fail('the intended physical iPhone is not paired and connected');
      }
      return;
    case 'lock':
      if (result['passcodeRequired'] != false) {
        _fail('the intended iPhone is locked');
      }
      return;
    case 'install':
      if (arguments.length != 3) _fail('install requires expected bundle ID');
      final applications = _list(
        result['installedApplications'],
        'installed applications',
      );
      final application = applications
          .whereType<Map<String, dynamic>>()
          .firstWhere(
            (value) => value['bundleID'] == arguments[2],
            orElse: () => _fail('install receipt has the wrong bundle ID'),
          );
      final url = application['installationURL'];
      if (url is! String) _fail('install receipt has no application URL');
      stdout.writeln(_containerFromUrl(url));
      return;
    case 'launch':
      if (arguments.length != 3) _fail('launch requires expected container');
      final process = _map(result['process'], 'launched process');
      final executable = process['executable'];
      final pid = process['processIdentifier'];
      if (pid is! int ||
          pid <= 0 ||
          !_isInstalledRunner(executable, arguments[2])) {
        _fail('launch receipt does not identify the installed Selah process');
      }
      stdout.writeln(pid);
      return;
    case 'apps':
      if (arguments.length != 6) {
        _fail('apps requires bundle ID, name, version and build');
      }
      final apps = _list(result['apps'], 'installed app query');
      final app = apps.whereType<Map<String, dynamic>>().firstWhere(
        (value) => value['bundleIdentifier'] == arguments[2],
        orElse: () => _fail('installed app query has the wrong bundle ID'),
      );
      if (app['name'] != arguments[3] ||
          app['version'] != arguments[4] ||
          app['bundleVersion'].toString() != arguments[5]) {
        _fail('installed Selah metadata does not match the signed artifact');
      }
      final url = app['url'];
      if (url is! String) _fail('installed app query has no URL');
      stdout.writeln(_containerFromUrl(url));
      return;
    case 'processes':
      if (arguments.length != 4) {
        _fail('processes requires expected container and PID');
      }
      final expectedPid = int.tryParse(arguments[3]);
      if (expectedPid == null) _fail('expected process ID is invalid');
      final processes = _list(result['runningProcesses'], 'process query');
      final matched = processes.whereType<Map<String, dynamic>>().any((
        process,
      ) {
        final executable = process['executable'];
        return process['processIdentifier'] == expectedPid &&
            _isInstalledRunner(executable, arguments[2]);
      });
      if (!matched) _fail('Selah process is not present in the post-query');
      return;
    default:
      _fail('unknown receipt mode $mode');
  }
}
