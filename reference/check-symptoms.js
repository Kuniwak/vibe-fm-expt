// Symptom checks for the reference variants (run inside a copy of the repository).
const {parse, publish, traverse} = require(process.argv[2] || '.');
const r = (f) => { try { return {ok: true, v: f()}; } catch (e) { return {ok: false, e: `${e.name}: ${e.message}`.slice(0, 120)}; } };
const out = {
  M1_publish_function_dots: r(() => publish(parse('function(...)'))),
  M2_traverse_function_dots: r(() => { traverse(parse('function(...)'), () => {}); return 'ok'; }),
  M3_traverse_new_arrow: r(() => { traverse(parse('new () => X'), () => {}); return 'ok'; }),
  M4_parse_typeofFoo: r(() => { const a = parse('typeofFoo'); return a.type + (a.name ? ':' + JSON.stringify(a.name) : ''); }),
  M5_parse_record_1a: r(() => parse('{1a: x}').type),
  M6_parse_tuple_trailing: r(() => parse('[a, b,]').type),
};
console.log(JSON.stringify(out, null, 1));
// side-effect probes (not symptoms): inputs the variants should leave unchanged
const side = {
  empty_tuple: r(() => parse('[]').type),
  tuple_no_trailing: r(() => parse('[a, b]').type),
  function_variadic_number: r(() => publish(parse('function(...number)'))),
  typeof_foo: r(() => { const a = parse('typeof Foo'); return a.type; }),
  record_key_number: r(() => parse('{1: x}').type),
};
console.log(JSON.stringify(side));
