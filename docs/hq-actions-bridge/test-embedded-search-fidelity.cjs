// Isolated actual handler, existing Node only; no Metro, dependencies or network.
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const {execFileSync} = require('node:child_process');
const root = path.resolve(__dirname, '../..');
const file = 'Vendor/SefariaMobile/Integration/JS/chavrusaRPCFacade.js';
const base = '3d6f90c90403a18e780ca37504da1c71285b219e';
function handler(source) {
  const start = source.indexOf("case 'search.query': {");
  const end = source.indexOf('// --- DOWNLOADS & UPDATES ---', start);
  assert(start >= 0 && end > start);
  return new Function('params', 'global', `return (async () => { let result; switch ('search.query') { ${source.slice(start,end)} } return result; })()`);
}
const current = handler(fs.readFileSync(path.join(root, file), 'utf8'));
const old = handler(execFileSync('git', ['show', `${base}:${file}`], {cwd: root, encoding:'utf8'}));
const raw = n => Array.from({length:n}, (_, i) => ({_source:{ref:`Genesis 1:${i+1}`, title:'Genesis', text:'fixture'}, _score:1}));
const inputs = [
  ['eq_more_with_grouping', {hits:{hits:raw(3), total:{value:20,relation:'eq'}}}, {offset:10,limit:3}, true],
  ['eq_in_place_processing', {hits:{hits:raw(3), total:{value:20,relation:'eq'}}}, {offset:10,limit:3}, 'mutate'],
  ['eq_empty', {hits:{hits:[],total:{value:0,relation:'eq'}}}, {offset:0,limit:3}],
  ['missing_hits', {hits:{total:{value:0,relation:'eq'}}}, {offset:0,limit:3}],
  ['missing_total', {hits:{hits:raw(1)}}, {offset:0,limit:3}],
  ['unknown_numeric_total', {hits:{hits:raw(1),total:8}}, {offset:0,limit:3}],
  ['gte_exhaustion_unknown', {hits:{hits:raw(3),total:{value:3,relation:'gte'}}}, {offset:0,limit:3}],
  ['explicit_cursor', {hits:{hits:raw(1),total:8},nextOffset:17}, {offset:0,limit:3}],
  ['invalid_ref', {hits:{hits:[{_source:{title:'Genesis',text:'fixture'}}],total:{value:1,relation:'eq'}}}, {offset:0,limit:3}],
  ['impossible_count', {hits:{hits:raw(1),total:{value:0,relation:'eq'}}}, {offset:0,limit:3}],
  ['missing_everything', {}, {offset:0,limit:3}],
];
(async () => {
  const results = [];
  for (const [name, payload, paging, group] of inputs) {
    const params = {query:'fixture',type:'text',field:'exact',sortType:'relevance',...paging};
    const engine = {Sefaria:{search:{execute_query:async()=>JSON.parse(JSON.stringify(payload)),
      process_text_hits:hits=>{
        if (group === 'mutate') { hits.splice(2); return hits; }
        return group?hits.slice(0,2):hits;
      }}}};
    const before = await old(params, engine), after = await current(params, engine);
    for (const key of ['hits','total','start','size']) assert.deepEqual(after[key],before[key], `${name}: legacy ${key}`);
    assert.equal(after.fidelity.rawHitsPresent,Array.isArray(payload.hits?.hits));
    if (group) { assert.equal(after.fidelity.rawHitCount,3); assert.equal(after.fidelity.processedHitCount,2); }
    results.push({name,offset:params.offset,limit:params.limit,result:after});
  }
  const throwing = {Sefaria:{search:{execute_query:async()=>{throw new Error('fixture RPC source failed');}}}};
  await assert.rejects(()=>current({query:'fixture'},throwing), /fixture RPC source failed/);
  const document = {kind:'ACTUAL_HANDLER_SOURCE_WITH_EXPLICIT_ENGINE_DOUBLES',base,
    oldUIFieldsPreserved:true,rawErrorsPropagate:true,cases:results};
  fs.writeFileSync(path.join(__dirname,'embedded-handler-fixtures.json'), JSON.stringify(document,null,2)+'\n');
  console.log(`PASS: ${inputs.length} actual-handler payload cases; old hits/total/start/size preserved; source failure propagated`);
})().catch(error=>{console.error(error);process.exitCode=1;});
