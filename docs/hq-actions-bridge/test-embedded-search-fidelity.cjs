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
  const source = fs.readFileSync(path.join(root, file), 'utf8');
  const contractStart = source.indexOf("case 'runtime.actionContract': {");
  const contractEnd = source.indexOf("case 'diagnostic.echo':", contractStart);
  assert(contractStart >= 0 && contractEnd > contractStart);
  const contract = new Function('params', 'global', 'ChavrusaRPCFacade', `let result; switch ('runtime.actionContract') { ${source.slice(contractStart,contractEnd)} } return result;`);
  const contractCall = (params, global, activeResourceOperations = 0) => contract(params, global, {activeResourceOperations});
  const nonce = 'actual-handler-fixture-nonce';
  const loaded = contractCall({nonce}, {Sefaria:{toc:[{title:'Genesis'}],search:{execute_query:()=>{throw Error('probe executed query');}}}});
  assert.deepEqual(loaded, {contract:'chavrusa.actions.search-fidelity.v1', searchFidelitySchema:1, nonce, catalogReady:true, searchReady:true, resourcesStable:true});
  assert.equal(contractCall({nonce}, {}).searchReady, false);
  assert.equal(contractCall({nonce}, {Sefaria:{toc:[],search:{execute_query:true}}}).searchReady, false);
  assert.equal(contractCall({nonce}, {Sefaria:{toc:[],search:{execute_query:()=>{}}}}).catalogReady, false);
  assert.equal(contractCall({nonce}, {}, 1).resourcesStable, false);
  console.log('PASS: actual runtime action-contract handler; read-only current catalog/search proof, absent/non-callable engine rejected');
  // Execute the complete real dispatcher, including its finally cleanup. A
  // remote operation can outlive a native timeout; discovery must still report
  // busy until the JS operation actually settles.
  const classSource = source.slice(source.indexOf('export class ChavrusaRPCFacade')).replace('export class ', 'class ');
  let finishResource;
  const downloadControl = {downloadUpdate:()=>new Promise((resolve,reject)=>{finishResource={resolve,reject};})};
  const facade = new Function('global', 'DownloadControl', 'NativeModules', `${classSource}; return ChavrusaRPCFacade;`)(
    {Sefaria:{toc:[{title:'Genesis'}],search:{execute_query:()=>{}}}}, downloadControl, {});
  const envelope = method => ({protocolVersion:'1.0', requestID:method, method, paramsJson:JSON.stringify({nonce}), sessionGeneration:7});
  const running = facade.handleNativeEnvelope(envelope('updates.download'));
  assert.equal(facade.activeResourceOperations,1);
  const busy = await facade.handleNativeEnvelope(envelope('runtime.actionContract'));
  assert.equal(JSON.parse(busy.resultJson).resourcesStable,false);
  finishResource.resolve({updated:true});
  assert.equal((await running).status,'success');
  assert.equal(facade.activeResourceOperations,0);
  const failed = facade.handleNativeEnvelope(envelope('updates.download'));
  finishResource.reject(new Error('fixture update failure'));
  assert.equal((await failed).status,'error');
  assert.equal(facade.activeResourceOperations,0);
  console.log('PASS: complete actual JS dispatcher keeps resources busy until promise settles; success/error finally cleanup verified');
  const link = {sourceRef:'Rashi on Genesis 1:1',he:'fixture',anchorRef:'Genesis 1:1'};
  const actualRelated = {links:[link],topics:[]};
  const relatedFacade = new Function('global','DownloadControl','NativeModules','OfflineOnline',`${classSource}; return ChavrusaRPCFacade;`)(
    {Sefaria:{textTitleForRef:ref=>ref === link.sourceRef ? 'Rashi on Genesis' : null}}, {}, {}, {loadRelated:async()=>actualRelated});
  const relatedResponse = await relatedFacade.handleNativeEnvelope(envelope('relationships.links'));
  const related = JSON.parse(relatedResponse.resultJson);
  assert.equal(related.links[0].sourceWorkKey,'Rashi on Genesis');
  for (const key of Object.keys(link)) { assert.deepEqual(related.links[0][key],link[key]); }
  assert.deepEqual(related.topics,[]);
  assert.equal(actualRelated.links[0].sourceWorkKey,undefined,'original upstream payload must not be mutated');
  console.log('PASS: actual related dispatcher preserves source fields and uses original engine work resolver without splitting refs');
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
