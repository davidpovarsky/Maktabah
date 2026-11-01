'use strict';

// 1. Load ChavrusaText RPC facade and Root component FIRST to guarantee
// that ChavrusaSefariaRoot is registered with AppRegistry before any
// downstream or upstream module evaluation.
import './JS/chavrusaRPCFacade';
import { setupChavrusaRPCBridge } from './JS/ChavrusaRoot';

// 2. Initialize original Sefaria-Mobile global context, state providers, and components
let upstreamBootstrapError = null;
try {
  require('../Upstream/index');
} catch (e) {
  upstreamBootstrapError = e;
  console.error('[ChavrusaText] Fatal error during upstream Sefaria initialization:', e);
}

if (upstreamBootstrapError) {
  console.error('[ChavrusaText] Sefaria-Mobile embedded JS runtime failed to bootstrap cleanly');
  try {
    const { ChavrusaRPCFacade } = require('./JS/chavrusaRPCFacade');
    ChavrusaRPCFacade.sendEventToNative('bootstrapError', {
      error: upstreamBootstrapError.message || String(upstreamBootstrapError),
      fatal: true,
    });
  } catch (_) {}
} else {
  console.log('[ChavrusaText] Sefaria-Mobile embedded JS runtime initialized successfully');
  // 3. Setup RPC bridge listener and emit ready handshake to native Swift
  try {
    setupChavrusaRPCBridge(1);
  } catch (e) {
    console.error('[ChavrusaText] Failed to initialize RPC bridge after upstream load:', e);
  }
}

