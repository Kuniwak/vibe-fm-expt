'use strict';
// Parse the wiki's operator-precedence relation table (Home.md).
const fs = require('fs');
function decode(s) { return s.replace(/&vert;/g, '|').replace(/&lt;/g, '<').replace(/&gt;/g, '>').trim(); }
function loadTable(file) {
  const lines = fs.readFileSync(file, 'utf8').split('\n').filter(l => l.startsWith('|'));
  const cells = l => l.split('|').slice(1, -1).map(decode);
  const symRow = cells(lines[2]);           // header symbols (first body row)
  const colSyms = symRow.slice(2);
  const cats = [].concat(Array(7).fill('Operand'), Array(5).fill('Infix'), Array(4).fill('Open'), Array(3).fill('Close'), Array(7).fill('Prefix'), Array(7).fill('Suffix'), ['End']);
  if (colSyms.length !== cats.length) throw new Error('unexpected column count ' + colSyms.length);
  const colKeys = colSyms.map((s, i) => cats[i] + ':' + s);
  const rel = {}; const rowKeys = [];
  for (const l of lines.slice(3)) {
    const c = cells(l); const rk = c[0] + ':' + c[1]; rowKeys.push(rk); rel[rk] = {};
    c.slice(2).forEach((v, i) => { rel[rk][colKeys[i]] = v; });
  }
  return {rel, rowKeys, colKeys};
}
// Operator-precedence parse of a token list using the table. Rows = left (stack) symbol, columns = right (incoming) symbol.
const INFIX = new Set(['.', '~', '#', '|', '/']);
const PREFIX = new Set(['?', '!', '=', '...']);
const SUFFIX = new Set(['?', '!', '=', '...', '[]']);
function opParse(tokens, table) {
  const {rel} = table;
  const stack = [{t: 'Operand:^'}];
  const topTermIdx = () => { for (let i = stack.length - 1; i >= 0; i--) if (stack[i].t) return i; };
  const R = (a, b) => (rel[a] && rel[a][b] !== undefined) ? rel[a][b] : undefined;
  const reduce = () => {
    const i = topTermIdx(); const [cat, sym] = [stack[i].t.split(':')[0], stack[i].t.slice(stack[i].t.indexOf(':') + 1)];
    if (cat === 'Prefix') { if (i !== stack.length - 2 || !stack[i + 1].e) return 'bad prefix handle'; const e = stack.pop().e; stack.pop(); stack.push({e: `(${sym} ${e})`}); return null; }
    if (cat === 'Suffix') { if (i !== stack.length - 1 || i < 1 || !stack[i - 1].e) return 'bad suffix handle'; stack.pop(); const e = stack.pop().e; stack.push({e: `(${e} ${sym})`}); return null; }
    if (cat === 'Infix') { if (i !== stack.length - 2 || !stack[i + 1].e || i < 1 || !stack[i - 1].e) return 'bad infix handle'; const r = stack.pop().e; stack.pop(); const l = stack.pop().e; stack.push({e: `(${l} ${sym} ${r})`}); return null; }
    return 'cannot reduce ' + stack[i].t;
  };
  const feed = (b) => {
    for (;;) {
      const a = stack[topTermIdx()].t; const r = R(a, b);
      if (r === '<' || r === '=') { return null; }
      if (r === '>') { const err = reduce(); if (err) return err; continue; }
      if (r === 'x') return `x: ${a} then ${b}`;
      return `undefined relation: ${a} then ${b}` + (r === '' ? ' (blank cell)' : '');
    }
  };
  for (const tok of tokens) {
    const top = stack[stack.length - 1];
    const ended = !!top.e || (top.t && top.t.startsWith('Suffix:'));
    if (tok.name) { if (ended) return {error: 'operand after complete expression'}; stack.push({e: tok.name}); continue; }
    let key;
    if (ended) { if (INFIX.has(tok.op)) key = 'Infix:' + tok.op; else if (SUFFIX.has(tok.op)) key = 'Suffix:' + tok.op; else return {error: 'no such operator here ' + tok.op}; }
    else { if (PREFIX.has(tok.op)) key = 'Prefix:' + tok.op; else return {error: 'operator needs left operand: ' + tok.op}; }
    const err = feed(key); if (err) return {error: err};
    stack.push({t: key});
  }
  for (;;) {
    if (stack.length === 2 && stack[1].e) { return R('Operand:^', 'End:$') === '=' ? {tree: stack[1].e} : {error: 'no accept relation'}; }
    const a = stack[topTermIdx()].t; if (a === 'Operand:^') return {error: 'incomplete expression'};
    const r = R(a, 'End:$');
    if (r === '>') { const err = reduce(); if (err) return {error: err}; continue; }
    return {error: `at end: ${a} has relation ${JSON.stringify(r)} to $`};
  }
}
module.exports = {loadTable, opParse};
