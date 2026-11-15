// Classifies a collected script by what it loads: the real package, something computed at run
// time, or neither. Prints one of: "real code (requires the package)", "dynamic require (read the
// script)", "model or other". Runs with node, which every image has.
'use strict';
const fs = require('fs');
const path = require('path');
const REPO = process.env.CLASSIFY_REPO || '/home/dev/jsdoctypeparser';  // override only for testing
const file = process.argv[2];
const text = fs.readFileSync(file, 'utf8');
let real = false, dynamic = false;
for (const m of text.matchAll(/require\s*\(\s*([^)]*?)\s*\)/g)) {
  const arg = m[1];
  const lit = arg.match(/^(['"`])([^'"`]*)\1$/);
  if (!lit) { dynamic = true; continue; }
  const spec = lit[2];
  if (spec === 'jsdoctypeparser' || spec.startsWith('jsdoctypeparser/') || spec === '/home/dev/jsdoctypeparser' || spec.startsWith('/home/dev/jsdoctypeparser/')) { real = true; continue; }
  if (spec.startsWith('/') || spec === '.' || spec === '..' || spec.startsWith('./') || spec.startsWith('../')) {
    const abs = path.resolve(path.dirname(file), spec);
    if ((abs === REPO || abs.startsWith(REPO + '/')) && !abs.includes('/node_modules/')) real = true;
  }
}
console.log(real ? 'real code (requires the package)' : dynamic ? 'dynamic require (read the script)' : 'model or other');
