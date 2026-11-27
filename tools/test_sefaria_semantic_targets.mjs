import assert from 'node:assert/strict';
import {readFile, writeFile, mkdir} from 'node:fs/promises';
import {resolve, join} from 'node:path';
import {createHash} from 'node:crypto';
import {fileURLToPath} from 'node:url';

const [sourceRootArg, upstreamArg, outputArg, variant = 'candidate'] = process.argv.slice(2);
const sourceRoot = resolve(sourceRootArg), upstream = resolve(upstreamArg), output = resolve(outputArg);
await mkdir(output, {recursive: false});
const hash = text => createHash('sha256').update(text).digest('hex');
const read = path => readFile(path, 'utf8');
const registryPath = join(sourceRoot, 'Vendor/SefariaMobile/Integration/JS/ChavrusaVisibleSurfaceRegistry.js');
const targetPath = join(sourceRoot, 'Vendor/SefariaMobile/Integration/JS/ChavrusaVisibleSemanticTargets.js');
const wrapperPath = join(sourceRoot, 'Vendor/SefariaMobile/Integration/JS/ChavrusaVisibleSurface.js');
const [registry, targetSource, wrapper, readerSource, historySource] = await Promise.all([
  read(registryPath), read(targetPath), read(wrapperPath), read(join(upstream, 'ReaderApp.js')), read(join(upstream, 'PageHistory.js'))]);
assert.equal(hash(readerSource), 'cb088826ca2c14c9e9b20728f108594e76efd3437dbf54a500902213d81d8d1a');
const importSpecifier = "'./ChavrusaVisibleSemanticTargets'";
assert.equal(registry.split(importSpecifier).length, 2);
let evaluated = registry.replace(importSpecifier, JSON.stringify('data:text/javascript;base64,' + Buffer.from(targetSource).toString('base64')));
if (variant === 'omit-native-claim') {
  const guard = "if (claimNative(claimJSON) !== true)";
  assert.equal(evaluated.split(guard).length, 2);
  evaluated = evaluated.replace(guard, 'if (false)');
} else { assert.equal(variant, 'candidate'); }
await writeFile(join(output, 'evaluated-registry.mjs'), evaluated);
const {createVisibleSurfaceRegistry} = await import('data:text/javascript;base64,' + Buffer.from(evaluated).toString('base64'));

function actualMethod(name) {
  const marker = '\n  ' + name + ' = ';
  assert.equal(readerSource.split(marker).length, 2, name);
  const start = readerSource.indexOf(marker) + 1;
  const lineEnd = readerSource.indexOf('\n', start);
  if (!readerSource.slice(start, lineEnd).includes('=> {')) { return readerSource.slice(start, lineEnd); }
  const next = readerSource.slice(lineEnd).match(/\n  };?(?=\n)/);
  assert.ok(next, name);
  return readerSource.slice(start, lineEnd + next.index + next[0].length);
}
const names = ['modifyHistory', 'openMenu', 'openNav', 'openTopicToc', 'clearAllSearchFilters',
  'reapplySearchFilters', '_getSearchStateName', '_getSearchState'];
const methods = names.map(actualMethod);
const methodSource = methods.join('\n');
await writeFile(join(output, 'verbatim-original-methods.js'), methodSource);
// Actual original PageHistory/TabHistory run. Domain clone/search-filter and
// React state scheduling below are explicit boundaries, not engine/UI claims.
const domain = {util: {clone: value => JSON.parse(JSON.stringify(value))},
  search: {getAppliedSearchFilters: filters => ({appliedFilters: filters.filter(x => !x.unselected).map(x => x.name)})}};
const historyBody = historySource.replace("import Sefaria from './sefaria';", '').replaceAll('export class ', 'class ');
const {TabHistory} = new Function('Sefaria', historyBody + '\nreturn {TabHistory};')(domain);
class SearchStateBoundary {
  constructor(value) { Object.assign(this, {availableFilters: [], appliedFilters: []}, value); }
  update(value) { return new SearchStateBoundary({...this, ...value}); }
}
const ReaderApp = new Function('SearchState', 'Sefaria', 'SKIP_MENUS', 'trackEvent',
  'return class ReaderAppBoundary {\n' + methodSource + '\n};')(
    SearchStateBoundary, domain, ['Login', 'Register', 'Forgot Password'], () => {});
const getter = "() => {\n      const original = reader.current;\n      return original instanceof ReaderApp ? original : null;\n    }";
assert.equal(wrapper.split(getter).length, 2);
const createOriginalGetter = new Function('ReaderApp', 'reader', 'return ' + getter + ';');
const identity = Object.freeze({surfaceID: '10000000-0000-0000-0000-000000000001',
  mountID: '10000000-0000-0000-0000-000000000002', sceneID: 'actual-scene', epoch: 7});
const request = Object.freeze({...identity, ticketID: '10000000-0000-0000-0000-000000000003',
  requestID: '10000000-0000-0000-0000-000000000004', nonce: '10000000-0000-0000-0000-000000000005', target: 'library'});
const results = [];
const effectObservations = [];
async function test(name, body) {
  try { await body(); results.push({name, passed: true}); }
  catch (error) { results.push({name, passed: false, error: String(error)}); }
}
const flush = async () => { await Promise.resolve(); await Promise.resolve(); };
function tracked(promise) {
  const status = {state: 'pending'};
  promise.then(value => Object.assign(status, {state: 'resolved', value}), error => Object.assign(status, {state: 'rejected', error}));
  return status;
}
function fixture(language = 'english') {
  let time = 1000, nextFrame = 0, permission = true, claims = 0, consumed = false;
  const frames = new Map(), queuedState = [], original = new ReaderApp();
  const filter = {name: 'original-filter', unselected: false, calls: 0,
    setUnselected(value) { this.calls += 1; this.unselected = value; }};
  original.props = {interfaceLanguage: language};
  original.state = {loaded: true, _completedInit: true, menuOpen: 'topic', menuOpenSource: null,
    navigationCategories: ['Original category'], navigationTopic: {slug: 'original-topic'}, footerTab: 'Texts',
    searchQuery: 'synthetic retained query', textSearchState: new SearchStateBoundary({availableFilters: [filter]}),
    ReaderDisplayOptionsMenuVisible: false, textListVisible: true, connectionsMode: 'original', dictLookup: 'word'};
  original._interruptingMessageRef = {state: {modalVisible: false}};
  original.tabHistory = new TabHistory();
  original.setState = update => { queuedState.push(update); };
  const holder = {current: original};
  const layout = {revision: 1, width: 768, height: 900};
  const registry = createVisibleSurfaceRegistry({frame(callback) { const id = ++nextFrame; frames.set(id, callback); return id; },
    cancelFrame(id) { frames.delete(id); }, now: () => time, navigationNow: () => time});
  const originalGetter = createOriginalGetter(ReaderApp, holder);
  const token = registry.register(identity, () => ({loaded: holder.current?.state?.loaded,
    completedInit: holder.current?.state?._completedInit}), () => layout, originalGetter);
  const nativeClaim = json => {
    claims += 1;
    assert.deepEqual(JSON.parse(json), {...request, target: JSON.parse(json).target});
    if (!permission || consumed) { return false; }
    consumed = true; return true;
  };
  return {registry, original, holder, filter, layout, token, frames, queuedState,
    get claims() { return claims; }, get consumed() { return consumed; },
    revoke() { permission = false; },
    commit() { while (queuedState.length) { Object.assign(original.state, queuedState.shift()); } },
    tick: async (elapsed = 1, commit = true) => {
      time += elapsed;
      if (commit) { while (queuedState.length) { Object.assign(original.state, queuedState.shift()); } }
      const batch = [...frames.values()]; frames.clear(); for (const callback of batch) { callback(time); }
      await flush();
    },
    navigate: (target = 'library', changes = {}, claim = nativeClaim) =>
      registry.navigateOriginal({...request, target, ...changes}, identity.epoch, 100, claim),
  };
}
for (const language of ['english', 'hebrew']) {
  for (const [target, menu] of [['library', 'navigation'], ['topics', 'topic toc'], ['learningSchedules', 'learning schedules'], ['dedication', 'dedication']]) {
    await test('actual original ' + target + ' method/state/history in ' + language, async () => {
      const f = fixture(language), p = f.navigate(target), state = tracked(p);
      assert.equal(state.state, 'pending'); assert.equal(f.original.state.menuOpen, 'topic');
      assert.equal(f.original.tabHistory._historyByTab.Texts._backStack.length, 1);
      await f.tick(); const value = await p;
      assert.equal(value.originalMenu, menu); assert.equal(value.interfaceLanguage, language);
      assert.equal(value.claim.target, target); assert.equal(value.originalInstanceRetained, true);
      assert.equal(f.claims, 1); assert.equal(f.original.state.menuOpen, menu);
      if (target === 'library') {
        assert.equal(f.filter.calls, 1); assert.equal(f.filter.unselected, true);
        assert.equal(f.original.state.searchQuery, ''); assert.deepEqual(f.original.state.navigationCategories, []);
        assert.equal(f.original.state.textListVisible, false); assert.equal(f.original.state.connectionsMode, null);
      } else { assert.equal(f.original.state.searchQuery, 'synthetic retained query'); assert.equal(f.filter.calls, 0); }
      if (target === 'topics') { assert.equal(f.original.state.navigationTopic, null); }
    });
  }
}
await test('queued RPC revoked before delivery performs zero original methods', async () => {
  const f = fixture(), queued = () => f.navigate(); f.revoke();
  const p = queued(); tracked(p); await f.tick();
  effectObservations.push({point: 'revoked-before-delivery', menu: f.original.state.menuOpen,
    originalHistoryDepth: f.original.tabHistory._historyByTab.Texts._backStack.length});
  await assert.rejects(p, /ORIGINAL_SEMANTIC_HANDOFF_REVOKED/);
  assert.equal(f.queuedState.length, 0); assert.equal(f.original.tabHistory._historyByTab.Texts._backStack.length, 0);
});
await test('source publication before synchronous claim performs zero methods', async () => {
  const f = fixture(); f.revoke();
  const p = f.navigate('topics'); tracked(p); await f.tick();
  effectObservations.push({point: 'source-retired-before-claim', menu: f.original.state.menuOpen,
    originalHistoryDepth: f.original.tabHistory._historyByTab.Texts._backStack.length});
  await assert.rejects(p, /ORIGINAL_SEMANTIC_HANDOFF_REVOKED/);
  assert.equal(f.queuedState.length, 0);
});
await test('consumed ticket cannot replay original navigation', async () => {
  const f = fixture(), first = f.navigate(); await f.tick(); await first;
  const replay = f.navigate('topics'); tracked(replay); await f.tick();
  effectObservations.push({point: 'replayed-consumed-ticket', menu: f.original.state.menuOpen,
    originalHistoryDepth: f.original.tabHistory._historyByTab.Texts._backStack.length});
  await assert.rejects(replay, /ORIGINAL_SEMANTIC_HANDOFF_REVOKED/);
  assert.equal(f.original.tabHistory._historyByTab.Texts._backStack.length, 1);
});
for (const [name, change] of [
  ['not loaded', f => { f.original.state.loaded = false; }],
  ['not initialized', f => { f.original.state._completedInit = false; }],
  ['display options', f => { f.original.state.ReaderDisplayOptionsMenuVisible = true; }],
  ['interrupting modal', f => { f.original._interruptingMessageRef.state.modalVisible = true; }],
  ['missing modal owner', f => { f.original._interruptingMessageRef = null; }],
  ['account menu', f => { f.original.state.menuOpen = 'account-menu'; }],
  ['settings', f => { f.original.state.menuOpen = 'settings'; }],
  ['auth form', f => { f.original.state.menuOpen = 'Login'; }],
  ['unknown original flow', f => { f.original.state.menuOpen = 'future-private-flow'; }],
  ['unknown interface language', f => { f.original.props.interfaceLanguage = 'unknown'; }],
  ['non-original instance', f => { f.holder.current = {...f.original}; }],
]) {
  await test(name + ' refuses before the native claim', async () => {
    const f = fixture(); change(f); await assert.rejects(f.navigate());
    assert.equal(f.claims, 0); assert.equal(f.queuedState.length, 0);
  });
}
for (const change of [{target: 'arbitrary.selector'}, {ticketID: 'bad'}, {nonce: 'bad'},
  {epoch: 8}, {mountID: '10000000-0000-0000-0000-000000000099'}, {sceneID: 'foreign'}, {script: 'ignored?'}]) {
  await test('strict private handoff rejects ' + JSON.stringify(change), async () => {
    const f = fixture(); await assert.rejects(f.navigate('library', change));
    assert.equal(f.claims, 0); assert.equal(f.queuedState.length, 0);
  });
}
await test('a route echo cannot replace selected original state on a frame', async () => {
  const f = fixture(), p = f.navigate('topics'), state = tracked(p);
  await f.tick(1, false); assert.equal(state.state, 'pending');
  f.commit(); f.original.state.navigationTopic = {slug: 'foreign'};
  await f.tick(1, false); assert.equal(state.state, 'pending');
  f.original.state.navigationTopic = null; await f.tick(); assert.equal((await p).originalMenu, 'topic toc');
});
await test('actual original instance replacement refuses late frame', async () => {
  const f = fixture(), p = f.navigate(); tracked(p); f.holder.current = new ReaderApp();
  await f.tick(); await assert.rejects(p, /ORIGINAL_SURFACE_SOURCE_CHANGED/);
});
await test('detach refuses late proof and cancels pending frame', async () => {
  const f = fixture(), p = f.navigate(); tracked(p); f.registry.unregister(f.token);
  await assert.rejects(p, /ORIGINAL_SURFACE_DETACHED/); assert.equal(f.frames.size, 0);
});
await test('original error boundary refuses the target', async () => {
  const f = fixture(), p = f.navigate(); tracked(p); f.registry.markFailed(f.token);
  await assert.rejects(p, /ORIGINAL_SURFACE_FAILED/);
});
await test('missing actual layout never becomes completion', async () => {
  const f = fixture(); f.layout.width = 0; const p = f.navigate(), state = tracked(p);
  await f.tick(); assert.equal(state.state, 'pending'); await f.tick(101);
  await assert.rejects(p, /ORIGINAL_SURFACE_DEADLINE_EXCEEDED/);
});
await test('one in-flight navigation blocks a second request', async () => {
  const f = fixture(), p = f.navigate(); tracked(p);
  await assert.rejects(f.navigate('topics'), /ORIGINAL_SEMANTIC_HANDOFF_BUSY/);
  assert.equal(f.claims, 1); await f.tick(); await p;
});
await test('after-claim cancellation may leave the original committed effect', async () => {
  const f = fixture(), p = f.navigate('topics'); tracked(p); f.revoke();
  await f.tick(); const proof = await p;
  assert.equal(f.original.state.menuOpen, 'topic toc'); assert.equal(proof.claim.target, 'topics');
  // This is a JS proof, NOT a native receipt. The separate actual Swift ticket
  // controls require revoked canSupportEvidence == false at final native ACK.
});

const report = {schema: 'otzaria.original-rn-semantic-source-controls.v1', variant,
  scope: 'Node actual original navigation/history methods and downstream JS registry; native claim/React scheduling/search state are explicit boundaries; Apple/native NOT_RUN',
  inputs: [{path: registryPath, sha256: hash(registry)}, {path: targetPath, sha256: hash(targetSource)},
    {path: wrapperPath, sha256: hash(wrapper)}, {path: join(upstream, 'ReaderApp.js'), sha256: hash(readerSource)},
    {path: join(upstream, 'PageHistory.js'), sha256: hash(historySource)},
    {path: fileURLToPath(import.meta.url), sha256: hash(await read(fileURLToPath(import.meta.url)))}],
  originalMethods: names.map((name, i) => ({name, bytes: Buffer.byteLength(methods[i]), sha256: hash(methods[i])})),
  originalGetterSHA256: hash(getter), evaluatedRegistrySHA256: hash(evaluated),
  passed: results.filter(x => x.passed).length, failed: results.filter(x => !x.passed).length, effectObservations, results};
await writeFile(join(output, 'RESULT.json'), JSON.stringify(report, null, 2) + '\n');
console.log(JSON.stringify({variant, passed: report.passed, failed: report.failed,
  resultSHA256: hash(JSON.stringify(report, null, 2) + '\n'), failures: results.filter(x => !x.passed)}));
if (report.failed) { process.exitCode = 1; }
