import assert from 'node:assert/strict';
import test from 'node:test';
import { dartTokens } from './dart_tokens.mjs';

// Fixtures stay in memory: importing the pure scanner never runs the boundary
// checker, reads application configuration, or creates files.
test('ignores quoted text inside line comments, including a final comment', () => {
  const value = '// "ignored"\nfinal count = 1; // \'also ignored\'';
  const { clean, strings } = dartTokens(value);

  assert.deepEqual(strings, []);
  assert.equal(clean.length, value.length);
  assert.equal(clean.indexOf('final count'), value.indexOf('final count'));
  assert.equal(clean.indexOf('\n'), value.indexOf('\n'));
  assert.doesNotMatch(clean, /ignored|\/\//);
  assert.ok(clean.includes('final count = 1;'));
});

test('removes nested block comments while preserving source positions and lines', () => {
  const value = '/* outer "ignored"\n/* nested */ still outer */\nfinal label = "kept";';
  const { clean, strings } = dartTokens(value);

  assert.equal(clean.length, value.length);
  assert.equal(clean.indexOf('final label'), value.indexOf('final label'));
  assert.equal(clean.split('\n').length, value.split('\n').length);
  assert.doesNotMatch(clean, /outer|nested|ignored|\/\*/);
  assert.deepEqual(strings, [{ body: 'kept', at: value.indexOf('"kept"') }]);
});

test('preserves URLs, comment markers, and apostrophes inside quoted literals', () => {
  const value = `final url = 'https://example.test/a'; final label = "don't /* hide */ // this";`;
  const { clean, strings } = dartTokens(value);

  assert.equal(clean, value);
  assert.deepEqual(strings, [
    { body: 'https://example.test/a', at: value.indexOf("'https:") },
    { body: "don't /* hide */ // this", at: value.indexOf('"don') },
  ]);
});

test('retains escaped quote and backslash bodies without decoding them', () => {
  const value = String.raw`final first = 'it\'s'; final second = "a\\b\"c";`;
  const { clean, strings } = dartTokens(value);

  assert.equal(clean, value);
  assert.deepEqual(strings, [
    { body: String.raw`it\'s`, at: value.indexOf("'it") },
    { body: String.raw`a\\b\"c`, at: value.indexOf('"a') },
  ]);
});

test('recognizes raw literals without treating their backslashes as escapes', () => {
  const value = String.raw`final first = r'C:\draft\'; final second = r"// literal";`;
  const { clean, strings } = dartTokens(value);

  assert.equal(clean, value);
  assert.deepEqual(strings, [
    { body: 'C:\\draft\\', at: value.indexOf("r'") },
    { body: '// literal', at: value.indexOf('r"') },
  ]);
});

test('keeps multiline triple-quoted and raw triple-quoted literals intact', () => {
  const value = `final first = '''line one\n'quote' /* literal */''';\nfinal second = r"""raw \\ text\n// literal""";`;
  const { clean, strings } = dartTokens(value);

  assert.equal(clean, value);
  assert.deepEqual(strings, [
    { body: "line one\n'quote' /* literal */", at: value.indexOf("'''") },
    { body: 'raw \\ text\n// literal', at: value.indexOf('r"""') },
  ]);
});
