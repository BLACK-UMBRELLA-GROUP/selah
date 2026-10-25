// One-shot, allowlisted source reuse. No config, account, build, repository,
// environment, signing material, provider records or live data is imported.
// Run only on a new Selah source tree; refuses to overwrite imported files.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { fileURLToPath, pathToFileURL } from 'node:url';

const target = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const source = path.resolve(target, '../../ZYRA/SOURCE');
const digest = data => crypto.createHash('sha256').update(data).digest('hex');
const manifest = [];
function walk(dir) {
  const results = [];
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    if (entry.isSymbolicLink()) throw new Error(`Refusing symlink: ${entry.name}`);
    const candidate = path.join(dir, entry.name);
    if (entry.isDirectory()) results.push(...walk(candidate));
    else if (entry.isFile()) results.push(candidate);
  }
  return results;
}
export function adapt(value) {
  return value
    .replaceAll('app.zyraconnect.zyra/profile_photo', 'selah/profile_photo')
    .replaceAll('app.zyraconnect.zyra/app_icon', 'selah/app_icon')
    .replaceAll('app.zyraconnect.zyra', 'com.blackumbrella.selah.draft')
    .replaceAll('zyraconnect.app', 'selah.invalid')
    .replaceAll('ZYRA', 'SELAH').replaceAll('Zyra', 'Selah').replaceAll('zyra', 'selah')
    // The upstream code has distinct Wali and Guardian types/files. Keep
    // those namespaces distinct; the displayed trusted-person role is Shepherd.
    .replaceAll('My Wali', 'My Shepherd')
    .replaceAll('WALI', 'MENTOR').replaceAll('Wali', 'Mentor').replaceAll('wali', 'mentor')
    .replaceAll('GUARDIAN', 'SHEPHERD').replaceAll('Guardian', 'Shepherd').replaceAll('guardian', 'shepherd')
    .replaceAll('Assalaamu alaikum', 'Hello')
    .replaceAll('Assalamu alaikum', 'Hello')
    .replaceAll('Assalamu Alaikum', 'Hello')
    .replaceAll('Assalaamu alaikum', 'Hello')
    .replaceAll('Wa alaikum assalam', 'Hello to you too')
    .replaceAll('Wa alaikum as-salaam', 'Hello to you too')
    .replaceAll('Wa alaikum assalaam', 'Hello to you too')
    .replaceAll('SALAM', 'GREETING').replaceAll('Salam', 'Greeting').replaceAll('salam', 'greeting')
    .replaceAll('DEEN', 'FAITH').replaceAll('Deen', 'Faith').replaceAll('deen', 'faith')
    .replaceAll('ISLAMIC', 'CHRISTIAN').replaceAll('Islamic', 'Christian').replaceAll('islamic', 'christian')
    .replaceAll('MUSLIMS', 'CHRISTIANS').replaceAll('Muslims', 'Christians').replaceAll('muslims', 'christians')
    .replaceAll('MUSLIM', 'CHRISTIAN').replaceAll('Muslim', 'Christian').replaceAll('muslim', 'christian')
    .replaceAll('Islam', 'Christianity').replaceAll('islam', 'christianity')
    .replaceAll('Allah', 'God').replaceAll('allah', 'god')
    .replaceAll('Nikah', 'Marriage').replaceAll('nikah', 'marriage')
    .replace(/DR-SELAH-(\d+)/g, 'inherited decision $1')
    .replace(/OA-SELAH-(\d+)/g, 'inherited upstream action $1');
}
function copy(relative, renamed, transform = false) {
  const from = path.join(source, relative);
  const to = path.join(target, renamed);
  if (fs.existsSync(to)) throw new Error(`Refusing overwrite: ${renamed}`);
  const data = fs.readFileSync(from);
  const output = transform ? Buffer.from(adapt(data.toString('utf8'))) : data;
  if (transform && /(?:AIza[\w-]{20,}|eyJ[\w-]{20,}\.)/.test(output.toString('utf8'))) {
    throw new Error(`Credential-shaped content refused: ${relative}`);
  }
  fs.mkdirSync(path.dirname(to), { recursive: true });
  fs.writeFileSync(to, output, { flag: 'wx' });
  manifest.push({ source: relative, target: renamed, sourceSha256: digest(data), importedSha256: digest(output) });
}

for (const file of walk(path.join(source, 'lib'))) {
  const relative = path.relative(source, file);
  if (!relative.endsWith('.dart') || relative === 'lib/main.dart' || relative.startsWith('lib/config/')) continue;
  copy(relative, adapt(relative), true);
}
for (const dir of ['assets/fonts', 'assets/dev/one_journey_photos', 'assets/auth']) {
  for (const file of walk(path.join(source, dir))) {
    const relative = path.relative(source, file);
    if (/\.(ttf|txt|jpg|png)$/.test(relative)) copy(relative, adapt(relative));
  }
}
copy('pubspec.lock', 'pubspec.lock');
copy('analysis_options.yaml', 'analysis_options.yaml', true);
// Reuse only local/pure UI model tests; never backend/credential suites.
const tests = [
  'browse_photo_tap_navigation_test.dart', 'one_journey_theme_actions_test.dart',
  'guardian_circle_discussion_bubble_test.dart', 'guardian_circle_topic_options_test.dart',
  'zyra_journey_navigation_icon_test.dart', 'zyra_browse_history_test.dart',
  'zyra_view_request_draft_model_test.dart',
];
for (const name of tests) {
  if (fs.existsSync(path.join(source, 'test', name))) copy(`test/${name}`, `test/${adapt(name)}`, true);
}
// Machine-local analyzer resolution only, using already-resolved packages.
// A normal Founder-owned pub get replaces this when preparing the app.
const configFile = path.join(source, '.dart_tool/package_config.json');
if (fs.existsSync(configFile)) {
  const config = JSON.parse(fs.readFileSync(configFile, 'utf8'));
  for (const pkg of config.packages) {
    pkg.rootUri = pkg.name === 'zyra'
      ? pathToFileURL(`${target}/`).href
      : new URL(pkg.rootUri, pathToFileURL(configFile)).href;
    if (pkg.name === 'zyra') pkg.name = 'selah';
  }
  fs.mkdirSync(path.join(target, '.dart_tool'), { recursive: true });
  fs.writeFileSync(path.join(target, '.dart_tool/package_config.json'), JSON.stringify(config, null, 2), { flag: 'wx' });
}
fs.mkdirSync(path.join(target, '../SYSTEM/RESOURCES'), { recursive: true });
fs.writeFileSync(path.join(target, '../SYSTEM/RESOURCES/CORE_IMPORT_2026_10_13.json'), JSON.stringify({
  source, target, importedAt: new Date().toISOString(),
  excluded: ['main.dart', 'all config', 'all providers', 'all native/signing records', 'all caches/builds', 'all live data'],
  files: manifest,
}, null, 2), { flag: 'wx' });
console.log(`Imported ${manifest.length} allowlisted code/asset/test files into separate Selah SOURCE.`);
