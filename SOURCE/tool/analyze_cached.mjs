// Static analysis only: direct native analysis server, no Flutter tool,
// shell-Dart wrapper, package fetch, SDK edit, build or native build phase.
import fs from 'node:fs';
import path from 'node:path';
import { spawn } from 'node:child_process';
import readline from 'node:readline';
import { fileURLToPath } from 'node:url';
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const sdk = '/opt/homebrew/share/flutter/bin/cache/dart-sdk';
const executable = path.join(sdk, 'bin/dartaotruntime');
const snapshot = path.join(sdk, 'bin/snapshots/analysis_server_aot.dart.snapshot');
const proc = spawn(executable, [snapshot, `--dart-sdk=${sdk}`,
  '--client-id=selah-private-static-audit', '--protocol=analyzer'], {
  cwd: root, stdio: ['pipe', 'pipe', 'pipe'],
});
let nextId = 0;
const pending = new Map();
let connected;
const ready = new Promise(resolve => connected = resolve);
const failures = [];
proc.stderr.on('data', data => failures.push(data.toString()));
const lines = readline.createInterface({ input: proc.stdout });
lines.on('line', line => {
  let value;
  try { value = JSON.parse(line); } catch { return; }
  if (value.event === 'server.connected') connected();
  if (value.id && pending.has(value.id)) {
    const { resolve, reject } = pending.get(value.id);
    pending.delete(value.id);
    if (value.error) reject(new Error(JSON.stringify(value.error)));
    else resolve(value.result);
  }
});
function request(method, params) {
  const id = `${++nextId}`;
  return new Promise((resolve, reject) => {
    pending.set(id, { resolve, reject });
    proc.stdin.write(`${JSON.stringify({ id, method, ...(params ? { params } : {}) })}\n`);
  });
}
function dartFiles(dir) {
  return fs.readdirSync(dir, { withFileTypes: true }).flatMap(e => {
    const f = path.join(dir, e.name);
    if (e.isSymbolicLink()) throw new Error('Analysis refuses symlinks.');
    return e.isDirectory() ? dartFiles(f) : f.endsWith('.dart') ? [f] : [];
  });
}
const timer = setTimeout(() => { proc.kill('SIGTERM'); process.exitCode = 1; }, 120000);
try {
  await ready;
  await request('analysis.setAnalysisRoots', {
    included: [path.join(root, 'lib'), path.join(root, 'test')], excluded: [],
  });
  const files = [...dartFiles(path.join(root, 'lib')), ...dartFiles(path.join(root, 'test'))];
  const diagnostics = [];
  let cursor = 0;
  await Promise.all(Array.from({ length: 6 }, async () => {
    while (cursor < files.length) {
      const file = files[cursor++];
      const response = await request('analysis.getErrors', { file });
      for (const e of response.errors ?? []) diagnostics.push({ file: path.relative(root, file), ...e });
    }
  }));
  const result = {
    timestamp: new Date().toISOString(), scope: 'direct native static analyzer, no Flutter build',
    executable, snapshot, analyzedFiles: files.length,
    errors: diagnostics.filter(x => x.severity === 'ERROR').length,
    warnings: diagnostics.filter(x => x.severity === 'WARNING').length,
    infos: diagnostics.filter(x => x.severity === 'INFO').length,
    diagnostics, stderr: failures.join(''),
  };
  fs.writeFileSync(path.join(root, '../SYSTEM/RESOURCES/STATIC_ANALYSIS_2026_10_13.json'), JSON.stringify(result, null, 2));
  console.log(JSON.stringify({ analyzedFiles: result.analyzedFiles, errors: result.errors, warnings: result.warnings, infos: result.infos }));
  for (const e of diagnostics.filter(x => x.severity !== 'INFO')) {
    console.log(`${e.severity} ${e.file}:${e.location.startLine}: ${e.message}`);
  }
  await request('server.shutdown');
  proc.stdin.end();
  process.exitCode = result.errors > 0 ? 1 : 0;
} finally {
  clearTimeout(timer);
  if (proc.exitCode === null) proc.kill('SIGTERM');
}
