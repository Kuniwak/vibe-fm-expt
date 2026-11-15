'use strict';
// Usage: node classify.js <path to jsdoctypeparser checkout> <input> [<input> ...]
// For each input, says whether the wiki's precedence table and the parser disagree, and which known family the disagreement belongs to.
// Scope: one-letter names and the operators ? ! = ... [] . ~ # | only. Anything else is reported as "out of scope".
const path = require('path');
const {loadTable, opParse} = require('./optable.js');
const families = require('./families.json');
const api = require(path.resolve(process.argv[2], 'index.js'));
const table = loadTable(path.join(__dirname, 'precedence-table.md'));
const show = (n) => {
  switch (n.type) {
    case 'NAME': return n.name;
    case 'UNION': return `(${show(n.left)} | ${show(n.right)})`;
    case 'MEMBER': return `(${show(n.owner)} . ${n.name})`;
    case 'INNER_MEMBER': return `(${show(n.owner)} ~ ${n.name})`;
    case 'INSTANCE_MEMBER': return `(${show(n.owner)} # ${n.name})`;
    case 'NULLABLE': return n.meta.syntax === 'PREFIX_QUESTION_MARK' ? `(? ${show(n.value)})` : `(${show(n.value)} ?)`;
    case 'NOT_NULLABLE': return n.meta.syntax === 'PREFIX_BANG' ? `(! ${show(n.value)})` : `(${show(n.value)} !)`;
    case 'OPTIONAL': return n.meta.syntax === 'SUFFIX_EQUALS_SIGN' ? `(${show(n.value)} =)` : `<OPTIONAL>`;
    case 'VARIADIC': return n.meta.syntax === 'PREFIX_DOTS' ? `(... ${show(n.value)})` : n.meta.syntax === 'SUFFIX_DOTS' ? `(${show(n.value)} ...)` : '<ONLY_DOTS>';
    case 'GENERIC': return n.meta.syntax === 'SQUARE_BRACKET' ? `(${show(n.objects[0])} [])` : '<GENERIC>';
    default: return `<${n.type}>`;
  }
};
function tokenize(s) {
  const out = []; let i = 0;
  while (i < s.length) {
    if (/\s/.test(s[i])) { i++; continue; }
    if (s.startsWith('...', i)) { out.push({op: '...'}); i += 3; continue; }
    if (s.startsWith('[]', i)) { out.push({op: '[]'}); i += 2; continue; }
    if ('?!=.~#|'.includes(s[i])) { out.push({op: s[i]}); i++; continue; }
    if (/[A-Za-z]/.test(s[i]) && !/[A-Za-z0-9_]/.test(s[i + 1] || '')) { out.push({name: s[i]}); i++; continue; }
    return null;
  }
  return out;
}
const shape = (toks) => toks.map(t => t.name ? 'N' : t.op).join(' ');
function classify(input) {
  const toks = tokenize(input); if (!toks || !toks.length) return {input, verdict: 'out of scope'};
  const tb = opParse(toks, table);
  let impl; try { impl = show(api.parse(input)); } catch (e) { impl = e.name === 'SyntaxError' ? 'SyntaxError' : 'throws ' + e.name; }
  if (impl.includes('<')) return {input, verdict: 'out of scope', impl};
  const tableResult = tb.tree || 'rejected: ' + tb.error;
  const agree = tb.tree ? tb.tree === impl : impl === 'SyntaxError';
  if (agree) return {input, verdict: 'agree', table: tableResult, impl};
  const sh = shape(toks).split(' '); const hit = new Set();
  for (const f of families) for (const pat of f.patterns) { const p = pat.split(' '); for (let i = 0; i + p.length <= sh.length; i++) if (p.every((x, j) => x === sh[i + j])) hit.add(f.id); }
  return {input, verdict: 'disagree', families: [...hit], table: tableResult, impl};
}
module.exports = {classify};
if (require.main === module) for (const s of process.argv.slice(3)) console.log(JSON.stringify(classify(s)));
