// Static first-draft checks only. This script never launches Flutter, Dart,
// Xcode, Git, a provider, an HTTP request or an installed application.
// Findings print paths/line numbers only, never source values or credentials.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const source = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const findings = [];
let checks = 0;
function check(ok, category, file, line = 0) {
  checks++;
  if (!ok) findings.push({ category, file, ...(line ? { line } : {}) });
}
function text(relative) {
  const absolute = path.join(source, relative);
  check(fs.existsSync(absolute), 'required-file', relative);
  return fs.existsSync(absolute) ? fs.readFileSync(absolute, 'utf8') : '';
}
function walk(relative) {
  const absolute = path.join(source, relative);
  if (!fs.existsSync(absolute)) return [];
  const files = [];
  for (const entry of fs.readdirSync(absolute, { withFileTypes: true })) {
    const child = path.join(relative, entry.name);
    // Flutter/Xcode regenerate these dependency views during a native build.
    // They are build outputs, not governed Selah source, and legitimately use
    // symlinks to cached packages.
    if (child === 'ios/Flutter/ephemeral' ||
        child.startsWith('ios/Flutter/ephemeral/') ||
        child === 'ios/.symlinks' || child.startsWith('ios/.symlinks/') ||
        child === 'ios/Pods' || child.startsWith('ios/Pods/')) {
      continue;
    }
    check(!entry.isSymbolicLink(), 'no-active-source-symlink', child);
    if (entry.isSymbolicLink()) continue;
    if (entry.isDirectory()) files.push(...walk(child));
    else if (entry.isFile()) files.push(child);
  }
  return files;
}
function lineAt(value, index) {
  return value.slice(0, index).split('\n').length;
}

// Small lexical scan retains strings while removing comments, so URLs and
// apostrophes in displayed text do not become accidental comment boundaries.
function dartTokens(value) {
  let clean = '';
  const strings = [];
  let i = 0;
  while (i < value.length) {
    if (value.startsWith('//', i)) {
      const end = value.indexOf('\n', i);
      const stop = end < 0 ? value.length : end;
      clean += ' '.repeat(stop - i);
      i = stop;
      continue;
    }
    if (value.startsWith('/*', i)) {
      const start = i;
      i += 2;
      let depth = 1;
      while (i < value.length && depth) {
        if (value.startsWith('/*', i)) { depth++; i += 2; }
        else if (value.startsWith('*/', i)) { depth--; i += 2; }
        else i++;
      }
      clean += value.slice(start, i).replace(/[^\n]/g, ' ');
      continue;
    }
    const raw = value[i] === 'r' && /['"]/.test(value[i + 1] ?? '');
    const start = i;
    const quoteAt = raw ? i + 1 : i;
    const quote = value[quoteAt];
    if (quote === "'" || quote === '"') {
      const delimiter = value.startsWith(quote.repeat(3), quoteAt)
        ? quote.repeat(3) : quote;
      i = quoteAt + delimiter.length;
      const bodyStart = i;
      while (i < value.length) {
        if (!raw && value[i] === '\\') { i += 2; continue; }
        if (value.startsWith(delimiter, i)) break;
        i++;
      }
      strings.push({ body: value.slice(bodyStart, i), at: start });
      i = Math.min(value.length, i + delimiter.length);
      clean += value.slice(start, i);
      continue;
    }
    clean += value[i++];
  }
  return { clean, strings };
}

const main = text('lib/main.dart');
const manifest = text('pubspec.yaml');
const plist = text('ios/Runner/Info.plist');
const project = text('ios/Runner.xcodeproj/project.pbxproj');
const entitlements = text('ios/Runner/Runner.entitlements');
check(/^name:\s*selah\s*$/m.test(manifest), 'separate-package-name', 'pubspec.yaml');
const displayLiteral = /<key>CFBundleDisplayName<\/key>\s*<string>Selah<\/string>/.test(plist);
const displayVariable = /<key>CFBundleDisplayName<\/key>\s*<string>\$\(APP_DISPLAY_NAME\)<\/string>/.test(plist)
  && [...project.matchAll(/APP_DISPLAY_NAME\s*=\s*([^;]+);/g)].every(match => match[1].trim() === 'Selah')
  && /APP_DISPLAY_NAME\s*=\s*Selah\s*;/.test(project);
check(displayLiteral || displayVariable,
  'separate-app-display-name', 'ios/Runner/Info.plist');
const identifiers = [...project.matchAll(/PRODUCT_BUNDLE_IDENTIFIER\s*=\s*([^;]+);/g)]
  .map(match => match[1].trim().replaceAll('"', ''));
check(identifiers.length > 0, 'native-bundle-id-present', 'ios/Runner.xcodeproj/project.pbxproj');
for (const identifier of identifiers) {
  check(/^com\.blackumbrella\.selah\.draft(?:\.RunnerTests)?$/.test(identifier),
    'separate-native-bundle-id', 'ios/Runner.xcodeproj/project.pbxproj');
}
check(!/CFBundleURLTypes|com\.apple\.developer\.associated-domains/.test(plist),
  'no-inherited-auth-url-routing', 'ios/Runner/Info.plist');
check(!/keychain-access-groups|com\.apple\.security\.application-groups|com\.apple\.developer\.applesignin/.test(entitlements),
  'no-shared-keychain-groups-or-login', 'ios/Runner/Runner.entitlements');
const backendConfig = text('lib/config/supabase_config.dart');
check(/url\s*=\s*''/.test(backendConfig) && /publishableKey\s*=\s*''/.test(backendConfig)
  && /isConfigured\s*=\s*false/.test(backendConfig), 'empty-failclosed-backend-config', 'lib/config/supabase_config.dart');
const oauthConfig = text('lib/config/oauth_config.dart');
check(/googleWebClientId\s*=\s*''/.test(oauthConfig) && /googleIosClientId\s*=\s*''/.test(oauthConfig)
  && /isGoogleConfigured\s*=\s*false/.test(oauthConfig), 'empty-failclosed-oauth-config', 'lib/config/oauth_config.dart');
for (const file of ['lib/config/selah_internal_founder_policy.dart', 'lib/config/selah_external_tester_policy.dart']) {
  check(/enabled\s*=\s*false/.test(text(file)), 'no-inherited-founder-or-tester-grant', file);
}

const dart = walk('lib').filter(file => file.endsWith('.dart'));
const native = walk('ios').filter(file => /\.(swift|plist|entitlements|pbxproj|xcconfig|storyboard|xcscheme)$/.test(file));
const oldBrand = /\bzyra\b|zyraconnect|app\.zyraconnect|package:zyra\//i;
const islamicCopy = /\b(?:muslims?|islam(?:ic)?|assal[a-z]*|walaikum|salam|deen|allah|imam|hadith|qur[’']?an|quran|nikah|mosque|masjid|hijab|ramadan|sunnah|sharia|madhhab|zakat|hajj|umrah|fajr|dhuhr|asr|maghrib|isha)\b|[ﷺﷲ]/i;
const endpoint = /https?:\/\/[^\s'"<>]*\.supabase\.(?:co|in)\b|(?:AIza[\w-]{20,}|eyJ[\w-]{20,}\.)/;
for (const file of [...dart, ...native]) {
  const value = fs.readFileSync(path.join(source, file), 'utf8');
  const { clean, strings } = file.endsWith('.dart') ? dartTokens(value) : { clean: value, strings: [] };
  const brand = oldBrand.exec(clean);
  check(!brand, 'old-brand-in-active-source', file, brand ? lineAt(value, brand.index) : 0);
  const remote = endpoint.exec(clean);
  check(!remote, 'live-endpoint-or-credential-shape', file, remote ? lineAt(value, remote.index) : 0);
  if (file.endsWith('.dart')) {
    for (const literal of strings) {
      const faith = islamicCopy.exec(literal.body);
      check(!faith, 'islamic-visible-copy', file, faith ? lineAt(value, literal.at) : 0);
      if (/^assets\//.test(literal.body) && !literal.body.includes('$')) {
        check(fs.existsSync(path.join(source, literal.body)), 'referenced-asset-exists', file, lineAt(value, literal.at));
      }
    }
    for (const match of clean.matchAll(/(?:import|export|part)\s+['"]([^'"]+)['"]/g)) {
      if (match[1].startsWith('dart:') || match[1].startsWith('package:')) continue;
      check(fs.existsSync(path.resolve(source, path.dirname(file), match[1])),
        'relative-dart-dependency-exists', file, lineAt(value, match.index));
    }
  }
}

// Only the new entry/config/native initialisers are eligible to initialise an
// app. Imported service implementations can remain inert behind the offline
// draft boundary; their presence is not evidence of real Selah functionality.
for (const file of ['lib/main.dart', ...walk('lib/config').filter(file => file.endsWith('.dart')),
  ...walk('lib/draft').filter(file => file.endsWith('.dart')), ...native]) {
  if (!fs.existsSync(path.join(source, file))) continue;
  const value = fs.readFileSync(path.join(source, file), 'utf8');
  const clean = file.endsWith('.dart') ? dartTokens(value).clean : value;
  const initializer = /Supabase\s*\.\s*initialize\s*\(|Firebase\w*\s*\.\s*initializeApp\s*\(|GoogleSignIn\s*\(|signInWith(?:OAuth|IdToken|Password)\s*\(/.exec(clean);
  check(!initializer, 'no-shared-provider-initialization', file,
    initializer ? lineAt(value, initializer.index) : 0);
}

check(/SelahOneJourneyConceptShell/.test(main), 'draft-core-entry', 'lib/main.dart');
check(/SelahConceptPreviewBoundary/.test(main), 'draft-presentation-isolation', 'lib/main.dart');
check(/SelahInternalPreviewClient\s*\.\s*beginPreview\s*\(/.test(main), 'draft-network-latch-before-entry', 'lib/main.dart');
check(/HttpOverrides\s*\.\s*global\s*=/.test(main), 'draft-global-network-denial', 'lib/main.dart');
check(!/(?:AuthGate|SelahFounderLaunchScreen|HomeShell|MentorHomeShell)\s*\(/.test(dartTokens(main).clean),
  'no-old-auth-or-member-entry', 'lib/main.dart');
const policyFiles = ['lib/main.dart', ...walk('lib/config').filter(file => file.endsWith('.dart')),
  ...walk('lib/draft').filter(file => file.endsWith('.dart'))];
const policies = policyFiles.map(file => fs.existsSync(path.join(source, file)) ? fs.readFileSync(path.join(source, file), 'utf8') : '').join('\n');
const runtime = text('lib/draft/selah_draft_runtime.dart');
check(/bool\s+get\s+active\s*=>\s*_active\s*&&\s*!kReleaseMode/.test(runtime)
  && /_active\s*=\s*!kReleaseMode\s*&&\s*\n?\s*bundleId\s*==\s*SelahNativeIdentityPolicy\.productionBundleId/.test(runtime),
  'release-draft-failclosed-present', 'lib/draft/selah_draft_runtime.dart');
check(/HttpClient\s+createHttpClient\([^)]*\)\s*=>\s*throw\s+const\s+SocketException/.test(runtime),
  'offline-http-client-refusal', 'lib/draft/selah_draft_runtime.dart');
check(/const\s+bool\s+supabaseReady\s*=\s*false/.test(main)
  && /SupabaseClient\s+get\s+supabase\s*=>\s*throw\s+StateError/.test(main),
  'backend-client-getter-refuses', 'lib/main.dart');
const shell = text('lib/dev/selah_one_journey_concept_shell.dart');
for (const route of ['Browse', 'Journey', 'My SELAH', 'Shepherd', 'Profile', 'Compatibility', 'Journey requests']) {
  check(shell.includes(route), 'core-route-present', 'lib/dev/selah_one_journey_concept_shell.dart');
}
check(/Christian|Christ-centred|Christ centered|Jesus/.test(policies + shell + text('lib/data/selah_reference_data.dart')),
  'christian-identity-present', 'lib');
for (const name of ['selah1a', 'selah1b', 'selah1c', 'selah2a', 'selah2b', 'selah3a', 'selah3b', 'selah3c',
  'selah4a', 'selah5a', 'selah5b', 'selah6a', 'selah7a', 'selah8a', 'seeker_self', 'shepherd_self']) {
  check(fs.existsSync(path.join(source, `assets/dev/one_journey_photos/${name}.jpg`)),
    'stock-photo-fixture-exists', `assets/dev/one_journey_photos/${name}.jpg`);
}
for (const match of manifest.matchAll(/^\s*-\s+(assets\/[^\s#]+)\s*$/gm)) {
  check(fs.existsSync(path.join(source, match[1])), 'declared-asset-exists', 'pubspec.yaml', lineAt(manifest, match.index));
}
for (const match of manifest.matchAll(/asset:\s*(assets\/[^\s#]+)/gm)) {
  check(fs.existsSync(path.join(source, match[1])), 'declared-font-exists', 'pubspec.yaml', lineAt(manifest, match.index));
}

const result = {
  scope: 'Selah SOURCE only; static checks, not compile/runtime/install/payment/auth validation',
  checks, passed: checks - findings.length, findings,
};
console.log(JSON.stringify(result, null, 2));
process.exitCode = findings.length ? 1 : 0;
