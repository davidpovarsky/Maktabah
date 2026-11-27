import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';

const path = process.argv[2];
const source = await readFile(path, 'utf8');
const variant = process.argv[3] ?? 'original';
let evaluated = source;
if (variant === 'omit-completed-init') {
  assert.equal(source.split('reader?.completedInit === true').length, 2);
  evaluated = source.replace('reader?.completedInit === true', 'true');
} else if (variant === 'omit-mount-identity') {
  assert.equal(source.split('params.mountID === record.identity.mountID').length, 2);
  evaluated = source.replace('params.mountID === record.identity.mountID', 'true');
} else if (variant === 'allow-first-mount-aba') {
  assert.equal(source.split("if (pendingObservation) { end(pendingObservation, failure('ORIGINAL_SURFACE_DETACHED')); }").length, 2);
  evaluated = source.replace("if (pendingObservation) { end(pendingObservation, failure('ORIGINAL_SURFACE_DETACHED')); }", '');
  evaluated = evaluated.replace('active.revision !== pending.initialRevision + 1', 'false');
} else { assert.equal(variant, 'original'); }

const {createVisibleSurfaceRegistry, ORIGINAL_READER_SHA, VISIBLE_SURFACE_CONTRACT} =
  await import('data:text/javascript;base64,' + Buffer.from(evaluated).toString('base64'));
const identity = Object.freeze({surfaceID: '00000000-0000-0000-0000-000000000001',
  mountID: '00000000-0000-0000-0000-000000000002', sceneID: 'original-scene-A', epoch: 7});
const otherID = '00000000-0000-0000-0000-000000000099';
const request = {...identity, nonce: '00000000-0000-0000-0000-000000000003'};
const results = [];
const flush = async () => { await Promise.resolve(); await Promise.resolve(); };
function fixture() {
  let time = 1000, next = 1;
  const frames = new Map();
  const state = {loaded: true, completedInit: true};
  const layout = {revision: 1, width: 640, height: 800};
  const registry = createVisibleSurfaceRegistry({
    frame(callback) { const id = next++; frames.set(id, callback); return id; },
    cancelFrame(id) { frames.delete(id); }, now: () => time,
  });
  return {registry, state, layout, frames,
    register: (id = identity) => registry.register(id, () => state, () => layout),
    tick: async (elapsed = 1) => {
      time += elapsed;
      const callbacks = [...frames.values()]; frames.clear();
      for (const callback of callbacks) { callback(time); }
      await flush();
    },
    observe: (params = request, generation = identity.epoch, timeout = 100) =>
      registry.awaitVisible(params, generation, timeout),
  };
}
async function test(name, operation) {
  try { await operation(); results.push({name, passed: true}); }
  catch (error) { results.push({name, passed: false, error: String(error)}); }
}
async function rejects(promise, code) {
  await assert.rejects(promise, error => error?.code === code, code);
}
function track(promise) {
  const box = {state: 'pending'};
  promise.then(value => { box.state = 'fulfilled'; box.value = value; },
    error => { box.state = 'rejected'; box.error = error; });
  return box;
}

await test('warm original surface requires a real subsequent frame', async () => {
  const f = fixture(); f.register(); const p = f.observe(); const box = track(p);
  await flush(); assert.equal(box.state, 'pending'); await f.tick();
  const proof = await p; assert.equal(proof.contract, VISIBLE_SURFACE_CONTRACT);
  assert.equal(proof.upstreamSHA, ORIGINAL_READER_SHA); assert.equal(proof.component, 'ReaderApp');
  assert.equal(proof.nonce, request.nonce); assert.equal(proof.sceneID, identity.sceneID);
});
await test('cold observation admits only its exact first real mount', async () => {
  const f = fixture(); const p = f.observe(); const box = track(p);
  await f.tick(); assert.equal(box.state, 'pending'); f.register(); await f.tick();
  assert.equal((await p).surfaceID, identity.surfaceID);
});
await test('original loaded flag cannot be manufactured by native layout', async () => {
  const f = fixture(); f.state.loaded = false; f.register(); const p = f.observe(); const box = track(p);
  await f.tick(); assert.equal(box.state, 'pending'); f.state.loaded = true; await f.tick(); await p;
});
await test('original completed-init flag is mandatory', async () => {
  const f = fixture(); f.state.completedInit = false; f.register(); const p = f.observe(); const box = track(p);
  await f.tick(); assert.equal(box.state, 'pending'); f.state.completedInit = true; await f.tick(); await p;
});
await test('actual layout event is mandatory', async () => {
  const f = fixture(); f.layout.revision = 0; f.register(); const p = f.observe(); const box = track(p);
  await f.tick(); assert.equal(box.state, 'pending'); f.layout.revision = 1; await f.tick(); await p;
});
for (const [field, value] of [['width', 0], ['height', 0], ['width', NaN], ['height', Infinity]]) {
  await test('reject unrendered layout ' + field + '=' + value, async () => {
    const f = fixture(); f.layout[field] = value; f.register(); const p = f.observe(); const box = track(p);
    await f.tick(); assert.equal(box.state, 'pending'); f.layout[field] = 400; await f.tick(); await p;
  });
}
for (const [field, value] of [['surfaceID', otherID], ['mountID', otherID], ['sceneID', 'other-scene']]) {
  await test('reject wrong original ' + field, async () => {
    const f = fixture(); f.register(); const p = f.observe({...request, [field]: value});
    const box = track(p); await f.tick(); await flush();
    assert.equal(box.state, 'rejected'); assert.equal(box.error.code, 'ORIGINAL_SURFACE_SOURCE_CHANGED');
  });
}
await test('reject wrong bridge epoch', async () => {
  const f = fixture(); f.register(); await rejects(f.observe(request, 8), 'ORIGINAL_SURFACE_SOURCE_CHANGED');
});
await test('reject invalid nonce and unsafe epoch', async () => {
  const f = fixture(); f.register(); await rejects(f.observe({...request, nonce: 'bad'}), 'ORIGINAL_SURFACE_OBSERVATION_INVALID');
  await rejects(f.observe(request, Number.MAX_SAFE_INTEGER + 1), 'ORIGINAL_SURFACE_OBSERVATION_INVALID');
});
await test('detach revokes pending read and cancels its frame', async () => {
  const f = fixture(); f.state.loaded = false; const token = f.register(); const p = f.observe(); track(p);
  f.registry.unregister(token); await f.tick(); await rejects(p, 'ORIGINAL_SURFACE_DETACHED'); assert.equal(f.frames.size, 0);
});
await test('first-mount foreign to null ABA cannot join an old wait', async () => {
  const f = fixture(); const p = f.observe(); const box = track(p);
  const foreign = f.register({...identity, mountID: otherID}); f.registry.unregister(foreign);
  f.register(); await f.tick(); assert.equal(box.state, 'rejected');
});
await test('equal-identity unmount and remount does not revive a prior request', async () => {
  const f = fixture(); f.state.loaded = false; const old = f.register(); const p = f.observe(); const box = track(p);
  f.registry.unregister(old); f.register(); f.state.loaded = true; await f.tick();
  assert.equal(box.state, 'rejected'); assert.equal(box.error.code, 'ORIGINAL_SURFACE_DETACHED');
});
await test('duplicate visible root cannot replace the owner', async () => {
  const f = fixture(); const owner = f.register();
  assert.throws(() => f.register({...identity, sceneID: 'other-scene'}), /ORIGINAL_SURFACE_ALREADY_MOUNTED/);
  assert.equal(f.registry.unregister({}), false); assert.equal(f.registry.unregister(null), false);
  f.registry.markFailed(null); const p = f.observe(); await f.tick(); await p;
  assert.equal(f.registry.unregister(owner), true);
});
await test('original error boundary revokes actual surface observation', async () => {
  const f = fixture(); f.state.loaded = false; const token = f.register(); const p = f.observe(); track(p);
  f.registry.markFailed(token); await rejects(p, 'ORIGINAL_SURFACE_FAILED'); assert.equal(f.frames.size, 0);
  await rejects(f.observe(), 'ORIGINAL_SURFACE_FAILED');
});
await test('retained deadline is exclusive even when UI becomes ready then', async () => {
  const f = fixture(); f.register(); const p = f.observe(request, 7, 10); track(p);
  await f.tick(10); await rejects(p, 'ORIGINAL_SURFACE_DEADLINE_EXCEEDED');
});
await test('an absent cold surface has a bounded lifetime', async () => {
  const f = fixture(); const p = f.observe(request, 7, 10); track(p);
  await f.tick(10); await rejects(p, 'ORIGINAL_SURFACE_DEADLINE_EXCEEDED'); assert.equal(f.frames.size, 0);
});
await test('only one original observation may be pending', async () => {
  const f = fixture(); f.state.loaded = false; f.register(); const first = f.observe();
  await rejects(f.observe({...request, nonce: otherID}), 'ORIGINAL_SURFACE_OBSERVATION_BUSY');
  f.state.loaded = true; await f.tick(); await first;
});
await test('response reads actual latest geometry without mutating feature state', async () => {
  const f = fixture(); const before = {...f.state}; f.register(); const p = f.observe();
  f.layout.width = 900; f.layout.revision = 2; await f.tick(); const result = await p;
  assert.equal(result.layout.width, 900); assert.equal(result.layout.revision, 2);
  assert.deepEqual(f.state, before); assert.equal(Object.isFrozen(result), true);
});
await test('failed prior request does not strand observation capacity', async () => {
  const f = fixture(); f.register(); const first = f.observe(request, 7, 10); track(first);
  await f.tick(10); await rejects(first, 'ORIGINAL_SURFACE_DEADLINE_EXCEEDED');
  const next = f.observe({...request, nonce: otherID}); await f.tick(); assert.equal((await next).nonce, otherID);
});

const failed = results.filter(row => !row.passed);
console.log(JSON.stringify({variant, sourceSHA256: createHash('sha256').update(source).digest('hex'),
  evaluatedSHA256: createHash('sha256').update(evaluated).digest('hex'),
  passed: results.length - failed.length, failed: failed.length, results}, null, 2));
process.exitCode = failed.length ? 1 : 0;
