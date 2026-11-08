import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';

// Execute the production dispatcher with explicit unit-test transports.
// This verifies mapping/contracts only, and is not a Hermes or live-network acceptance test.
let source = fs.readFileSync('Vendor/SefariaMobile/Integration/JS/chavrusaRPCFacade.js', 'utf8');
source = source.replace(/^import .*;\r?\n/gm, '').replace(/^export /gm, '');
let related = { links: [{ ref: 'Rashi on Genesis 1:1:1' }], topics: [] };
let relatedError = null;
const sandbox = {
  console, NativeModules: {}, AsyncStorage: {}, DownloadControl: {},
  loadTextOffline: () => {}, textFromRefData: () => {}, ERRORS: {}, api: {},
  OfflineOnline: { loadRelated: async () => { if (relatedError) throw relatedError; return related; } },
  global: { Sefaria: {
    textTitleForRef: ref => ref?.startsWith('Rashi on Genesis') ? 'Rashi on Genesis' : ref?.startsWith('Genesis') ? 'Genesis' : null,
    index: title => ({ title, heTitle: title === 'Genesis' ? 'בראשית' : 'רש״י על בראשית' }),
    search: { execute_query: async () => ({ hits: { hits: [
      { _id: 'hit[he]', _source: { ref: 'Rashi on Genesis 1:1:1', title: 'WRONG TITLE 1:1:1', lang: 'hebrew', text: 'טקסט בדיקה' } },
      { _id: 'hit[en]', _source: { ref: 'Genesis 1:1', language: 'english' } },
    ], total: { value: 2 } } }) },
  } },
};
vm.runInNewContext(source + '\nglobalThis.Facade = ChavrusaRPCFacade;', sandbox);
let count = 0;
function check(value, expected) { assert.deepEqual(value, expected); count++; }
async function call(method, params = {}) {
  return sandbox.Facade.handleNativeEnvelope({ requestID: 'unit', method, paramsJson: JSON.stringify(params), sessionGeneration: 3 });
}
const search = JSON.parse((await call('search.query', { query: 'בדיקה' })).resultJson);
check(search.hits[0].workKey, 'Rashi on Genesis');
check(search.hits[0].language, 'he');
check(search.hits[1].language, 'en');
check(search.hits[0].heTitle, 'רש״י על בראשית');
check(search.total, 2);
const links = JSON.parse((await call('relationships.links', { ref: 'Genesis 1:1' })).resultJson);
check(links.links[0].workKey, 'Rashi on Genesis');
related = [];
check(JSON.parse((await call('relationships.links')).resultJson).length, 0);
related = { unexpected: true };
check((await call('relationships.links')).status, 'error');
relatedError = new Error('Network unavailable');
const failure = await call('relationships.links');
check(failure.status, 'error');
check(failure.error.retryable, true);
check(failure.resultJson, null);
console.log(`PASS: ${count} production JavaScript dispatcher contract assertions (unit fixtures; no Hermes claim)`);
