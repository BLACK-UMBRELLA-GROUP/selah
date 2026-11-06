import 'dart:convert';
import 'dart:io';

// Exercises the actual receipt CLI with synthetic data only. Fixtures stay in
// build/test_logs for inspection; this runner never contacts or installs a device.
Future<void> main() async {
  final source = File.fromUri(Platform.script).parent.parent;
  final checker = '${source.path}/tooling/verify_devicectl_receipt.dart';
  final logs = Directory('${source.path}/build/test_logs')
    ..createSync(recursive: true);
  final fixtures = logs.createTempSync('delivery_receipts_');
  const bundle = 'com.blackumbrella.selah.draft';
  const container = 'AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE';
  const otherContainer = 'FFFFFFFF-BBBB-CCCC-DDDD-EEEEEEEEEEEE';
  const device = 'synthetic-device-a';
  const pid = 321;
  const path =
      '/private/var/containers/Bundle/Application/$container/Runner.app/Runner';
  const appUrl =
      'file:///private/var/containers/Bundle/Application/$container/Runner.app/';
  var cases = 0;
  final failures = <String>[];

  Map<String, dynamic> receipt(Object? result, {String outcome = 'success'}) =>
      {
        'info': {'outcome': outcome},
        'result': result,
      };

  Map<String, dynamic> phone({
    String udid = device,
    String pairing = 'paired',
    String state = 'connected',
    String type = 'iPhone',
    String reality = 'physical',
  }) => {
    'properties': {
      'hardware': {'udid': udid, 'deviceType': type, 'reality': reality},
      'connection': {'pairingState': pairing, 'state': state},
    },
  };

  Map<String, dynamic> launch(Object? executable, {Object? processId = pid}) =>
      {
        'process': {'executable': executable, 'processIdentifier': processId},
      };

  Map<String, dynamic> processes(
    Object? executable, {
    Object? processId = pid,
  }) => {
    'runningProcesses': [
      {'executable': executable, 'processIdentifier': processId},
    ],
  };

  Future<void> expectReceipt(
    String label,
    String mode,
    Object? body,
    List<String> expectedValues, {
    bool succeeds = false,
    String output = '',
    String? error,
    String? raw,
    bool missing = false,
  }) async {
    cases++;
    final fixture = File('${fixtures.path}/case_$cases.json');
    if (!missing) fixture.writeAsStringSync(raw ?? jsonEncode(body));
    final result = await Process.run(Platform.resolvedExecutable, [
      checker,
      mode,
      fixture.path,
      ...expectedValues,
    ]);
    final stdout = (result.stdout as String).trim();
    final stderr = result.stderr as String;
    final correctExit = succeeds ? result.exitCode == 0 : result.exitCode != 0;
    final correctOutput = stdout == output;
    final correctError = succeeds
        ? stderr.isEmpty
        : stderr.contains('Selah delivery receipt failed:') &&
              (error == null || stderr.contains(error));
    if (!correctExit || !correctOutput || !correctError) failures.add(label);
  }

  await expectReceipt(
    'missing file refuses',
    'lock',
    null,
    [],
    missing: true,
    error: 'missing receipt',
  );
  await expectReceipt(
    'malformed JSON refuses',
    'lock',
    null,
    [],
    raw: '{',
    error: 'invalid receipt JSON',
  );
  await expectReceipt(
    'non-object root refuses',
    'lock',
    [],
    [],
    error: 'receipt is missing or malformed',
  );
  await expectReceipt(
    'missing info refuses',
    'lock',
    {'result': {}},
    [],
    error: 'receipt info',
  );
  await expectReceipt(
    'failed outcome refuses otherwise valid result',
    'lock',
    receipt({'passcodeRequired': false}, outcome: 'failure'),
    [],
    error: 'device command outcome',
  );
  await expectReceipt(
    'missing result refuses',
    'lock',
    {
      'info': {'outcome': 'success'},
    },
    [],
    error: 'receipt result',
  );
  await expectReceipt(
    'unknown mode refuses',
    'unknown',
    receipt({}),
    [],
    error: 'unknown receipt mode',
  );

  await expectReceipt(
    'exact physical paired connected device succeeds',
    'device',
    receipt({
      'devices': [phone(udid: 'unrelated'), phone()],
    }),
    [device],
    succeeds: true,
  );
  for (final value in <(String, Map<String, dynamic>)>[
    ('wrong UDID', phone(udid: 'another-device')),
    ('UDID substring', phone(udid: '$device-extra')),
    ('unpaired', phone(pairing: 'unpaired')),
    ('disconnected', phone(state: 'disconnected')),
    ('unknown connection', phone(state: 'unknown')),
    ('simulator', phone(reality: 'simulated')),
    ('other device type', phone(type: 'iPad')),
  ]) {
    await expectReceipt(
      '${value.$1} refuses',
      'device',
      receipt({
        'devices': [value.$2],
      }),
      [device],
      error: value.$1.startsWith('UDID') || value.$1 == 'wrong UDID'
          ? 'exactly one intended iPhone'
          : 'not paired and connected',
    );
  }
  await expectReceipt(
    'duplicate matching devices refuse ambiguity',
    'device',
    receipt({
      'devices': [phone(), phone()],
    }),
    [device],
    error: 'exactly one intended iPhone',
  );
  await expectReceipt('absent devices refuse', 'device', receipt({}), [
    device,
  ], error: 'device query');
  await expectReceipt(
    'deprecated device fields cannot substitute for real query',
    'device',
    receipt({
      'devices': [
        {
          'hardwareProperties': {'udid': device},
          'connectionProperties': {
            'pairingState': 'paired',
            'tunnelState': 'connected',
          },
        },
      ],
    }),
    [device],
    error: 'exactly one intended iPhone',
  );
  await expectReceipt(
    'empty expected device refuses',
    'device',
    receipt({
      'devices': [phone()],
    }),
    [''],
    error: 'requires the exact intended device UDID',
  );
  await expectReceipt(
    'missing modern connection refuses',
    'device',
    receipt({
      'devices': [
        {
          'properties': {
            'hardware': {
              'udid': device,
              'deviceType': 'iPhone',
              'reality': 'physical',
            },
          },
        },
      ],
    }),
    [device],
    error: 'device connection',
  );

  await expectReceipt(
    'explicit unlocked receipt succeeds',
    'lock',
    receipt({'passcodeRequired': false}),
    [],
    succeeds: true,
  );
  for (final value in [true, null, 'false', 0]) {
    await expectReceipt(
      'non-false lock value $value refuses',
      'lock',
      receipt({'passcodeRequired': value}),
      [],
      error: 'intended iPhone is locked',
    );
  }

  Map<String, dynamic> install(String id, Object? url) => {
    'installedApplications': [
      {'bundleID': id, 'installationURL': url},
    ],
  };
  await expectReceipt(
    'install exact bundle returns installed container',
    'install',
    receipt(install(bundle, appUrl)),
    [bundle],
    succeeds: true,
    output: container,
  );
  await expectReceipt(
    'install wrong bundle refuses',
    'install',
    receipt(install('$bundle.other', appUrl)),
    [bundle],
    error: 'wrong bundle ID',
  );
  await expectReceipt(
    'install malformed URL refuses',
    'install',
    receipt(install(bundle, 'file:///unrelated/Runner.app/')),
    [bundle],
    error: 'application URL is malformed',
  );
  await expectReceipt(
    'install absent URL refuses',
    'install',
    receipt(install(bundle, null)),
    [bundle],
    error: 'no application URL',
  );

  for (final executable in [
    path,
    'file://$path',
    path.replaceFirst('/private', ''),
    'file://${path.replaceFirst('/private', '')}',
  ]) {
    await expectReceipt(
      'launch exact supported path form succeeds',
      'launch',
      receipt(launch(executable)),
      [container],
      succeeds: true,
      output: '$pid',
    );
    await expectReceipt(
      'same exact process path and PID remains present',
      'processes',
      receipt(processes(executable)),
      [container, '$pid'],
      succeeds: true,
    );
  }
  for (final executable in [
    '$path-extra',
    '$path/helper',
    '$path?query=1',
    '$path#fragment',
    '/unexpected$path',
    path.replaceFirst(container, otherContainer),
    path.replaceFirst('/Runner.app/', '/Other.app/'),
    'file://remote-host$path',
    'https://example.invalid$path',
    path.replaceFirst('/Runner.app/', '/../$container/Runner.app/'),
    null,
  ]) {
    await expectReceipt(
      'launch rejects a non-exact executable',
      'launch',
      receipt(launch(executable)),
      [container],
      error: 'does not identify the installed Selah process',
    );
    await expectReceipt(
      'post-query rejects a non-exact executable even with correct PID',
      'processes',
      receipt(processes(executable)),
      [container, '$pid'],
      error: 'not present in the post-query',
    );
  }
  for (final invalidPid in [0, -1, '$pid', null]) {
    await expectReceipt(
      'launch rejects invalid PID $invalidPid',
      'launch',
      receipt(launch(path, processId: invalidPid)),
      [container],
      error: 'does not identify the installed Selah process',
    );
  }
  await expectReceipt(
    'post-query rejects restarted process with different PID',
    'processes',
    receipt(processes(path, processId: pid + 1)),
    [container, '$pid'],
    error: 'not present in the post-query',
  );
  await expectReceipt(
    'post-query rejects missing process after stability window',
    'processes',
    receipt({'runningProcesses': []}),
    [container, '$pid'],
    error: 'not present in the post-query',
  );

  Map<String, dynamic> installedApp({
    String id = bundle,
    String name = 'Selah',
    String version = '1.2.3',
    Object build = '45',
  }) => {
    'apps': [
      {
        'bundleIdentifier': id,
        'name': name,
        'version': version,
        'bundleVersion': build,
        'url': appUrl,
      },
    ],
  };
  const metadata = [bundle, 'Selah', '1.2.3', '45'];
  await expectReceipt(
    'queried installed metadata returns exact container',
    'apps',
    receipt(installedApp()),
    metadata,
    succeeds: true,
    output: container,
  );
  await expectReceipt(
    'integer bundle version is accepted exactly',
    'apps',
    receipt(installedApp(build: 45)),
    metadata,
    succeeds: true,
    output: container,
  );
  for (final app in [
    installedApp(id: '$bundle.other'),
    installedApp(name: 'Other'),
    installedApp(version: '1.2.4'),
    installedApp(build: '46'),
  ]) {
    await expectReceipt(
      'queried app metadata mismatch refuses',
      'apps',
      receipt(app),
      metadata,
      error: app['apps'][0]['bundleIdentifier'] == bundle
          ? 'metadata does not match'
          : 'wrong bundle ID',
    );
  }

  if (failures.isNotEmpty) {
    stderr.writeln(
      '${failures.length} of $cases delivery receipt cases failed:',
    );
    for (final failure in failures) {
      stderr.writeln('- $failure');
    }
    stderr.writeln('Synthetic fixtures retained: ${fixtures.path}');
    exitCode = 1;
    return;
  }
  stdout.writeln('$cases delivery receipt cases passed (synthetic data only).');
  stdout.writeln('Synthetic fixtures retained: ${fixtures.path}');
}
