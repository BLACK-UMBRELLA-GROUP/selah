// Small lexical scan retains strings while removing comments, so URLs and
// apostrophes in displayed text do not become accidental comment boundaries.
export function dartTokens(value) {
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
