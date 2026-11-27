'use strict';

// Downstream lifecycle only. The original ReaderApp owns every screen, reducer,
// content load and interaction. No selected text or navigation action is accepted.
export const ORIGINAL_READER_SHA = '2fd173a5a3bd32d94a9ba1222e4e32a37f6bd23c';
export const VISIBLE_SURFACE_CONTRACT = 'chavrusa.original-rn-surface.v1';

const isUUID = value => typeof value === 'string'
  && /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(value);
const isEpoch = value => Number.isSafeInteger(value) && value > 0;
const isScene = value => typeof value === 'string' && value.length > 0 && value.length <= 256;
const failure = code => Object.assign(new Error(code), {code});

// An injected frame clock is for the exact source controls. Production uses the
// actual React Native frame callback, not a timer that declares a view ready.
export function createVisibleSurfaceRegistry({
  frame = callback => global.requestAnimationFrame(callback),
  cancelFrame = handle => global.cancelAnimationFrame(handle),
  now = () => Date.now(),
} = {}) {
  let active = null;
  let revision = 0;
  let pendingObservation = null;

  const matches = (record, params, generation) => record !== null
    && params.surfaceID === record.identity.surfaceID
    && params.sceneID === record.identity.sceneID
    && params.mountID === record.identity.mountID
    && generation === record.identity.epoch;

  const end = (pending, error, proof) => {
    if (pendingObservation !== pending) { return; }
    pendingObservation = null;
    if (pending.frame !== null) { cancelFrame(pending.frame); pending.frame = null; }
    if (error) { pending.reject(error); } else { pending.resolve(proof); }
  };

  const register = (identity, readOriginalReader, readLayout) => {
    if (!identity || !isUUID(identity.surfaceID) || !isUUID(identity.mountID)
        || !isScene(identity.sceneID) || !isEpoch(identity.epoch)
        || typeof readOriginalReader !== 'function' || typeof readLayout !== 'function') {
      throw failure('ORIGINAL_SURFACE_IDENTITY_INVALID');
    }
    // Original ReaderApp uses process-wide DownloadTracker listener names.
    // A second scene may not replace, borrow or detach the first original root.
    if (active !== null) { throw failure('ORIGINAL_SURFACE_ALREADY_MOUNTED'); }
    if (revision >= Number.MAX_SAFE_INTEGER) { throw failure('ORIGINAL_SURFACE_LIFETIME_EXHAUSTED'); }
    revision += 1;
    const record = {
      identity: Object.freeze({...identity}), readOriginalReader, readLayout,
      failed: false, revision,
    };
    active = record;
    return record;
  };

  const unregister = token => {
    if (!token || active !== token) { return false; }
    active = null;
    if (revision < Number.MAX_SAFE_INTEGER) { revision += 1; }
    if (pendingObservation) { end(pendingObservation, failure('ORIGINAL_SURFACE_DETACHED')); }
    return true;
  };

  const markFailed = token => {
    if (!token || active !== token) { return; }
    token.failed = true;
    if (pendingObservation) { end(pendingObservation, failure('ORIGINAL_SURFACE_FAILED')); }
  };

  const awaitVisible = (params, generation, timeoutMs) => {
    if (!params || !isUUID(params.nonce) || !isUUID(params.surfaceID) || !isUUID(params.mountID)
        || !isScene(params.sceneID) || !isEpoch(generation)
        || !Number.isInteger(timeoutMs) || timeoutMs < 1 || timeoutMs > 5000) {
      return Promise.reject(failure('ORIGINAL_SURFACE_OBSERVATION_INVALID'));
    }
    if (active !== null && !matches(active, params, generation)) {
      return Promise.reject(failure('ORIGINAL_SURFACE_SOURCE_CHANGED'));
    }
    if (active?.failed) { return Promise.reject(failure('ORIGINAL_SURFACE_FAILED')); }
    if (pendingObservation && now() >= pendingObservation.deadline) {
      end(pendingObservation, failure('ORIGINAL_SURFACE_DEADLINE_EXCEEDED'));
    }
    if (pendingObservation) { return Promise.reject(failure('ORIGINAL_SURFACE_OBSERVATION_BUSY')); }

    return new Promise((resolve, reject) => {
      const pending = {resolve, reject, deadline: now() + timeoutMs, frame: null,
        record: active, initialRevision: revision};
      pendingObservation = pending;
      const schedule = callback => {
        try { pending.frame = frame(callback); }
        catch (_) { end(pending, failure('ORIGINAL_SURFACE_FRAME_UNAVAILABLE')); }
      };
      const observeOriginalFrame = () => {
        pending.frame = null;
        if (pendingObservation !== pending) { return; }
        if (now() >= pending.deadline) {
          end(pending, failure('ORIGINAL_SURFACE_DEADLINE_EXCEEDED')); return;
        }
        if (pending.record === null) {
          // A cold native apply may precede the first actual React commit. Only
          // that exact first mount may join; null -> foreign -> null is stale.
          if (active === null && revision === pending.initialRevision) {
            schedule(observeOriginalFrame); return;
          }
          if (active === null || active.revision !== pending.initialRevision + 1
              || !matches(active, params, generation)) {
            end(pending, failure('ORIGINAL_SURFACE_SOURCE_CHANGED')); return;
          }
          pending.record = active;
        }
        const record = pending.record;
        if (active !== record || !matches(record, params, generation)) {
          end(pending, failure('ORIGINAL_SURFACE_SOURCE_CHANGED')); return;
        }
        if (record.failed) { end(pending, failure('ORIGINAL_SURFACE_FAILED')); return; }
        let reader, layout;
        try { reader = record.readOriginalReader(); layout = record.readLayout(); }
        catch (_) { end(pending, failure('ORIGINAL_SURFACE_SOURCE_CHANGED')); return; }
        if (reader?.loaded === true && reader?.completedInit === true
            && Number.isSafeInteger(layout?.revision) && layout.revision > 0
            && Number.isFinite(layout?.width) && layout.width > 0
            && Number.isFinite(layout?.height) && layout.height > 0) {
          end(pending, null, Object.freeze({
            contract: VISIBLE_SURFACE_CONTRACT,
            component: 'ReaderApp', upstreamSHA: ORIGINAL_READER_SHA,
            ...record.identity, nonce: params.nonce,
            layout: Object.freeze({...layout}),
          }));
          return;
        }
        schedule(observeOriginalFrame);
      };
      schedule(observeOriginalFrame);
    });
  };

  return Object.freeze({register, unregister, markFailed, awaitVisible});
}

export const ChavrusaVisibleSurfaces = createVisibleSurfaceRegistry();
