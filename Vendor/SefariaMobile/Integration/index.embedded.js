'use strict';

// 1. Load ChavrusaText RPC facade and Root component FIRST to guarantee
// that ChavrusaSefariaRoot is registered with AppRegistry before any
// downstream or upstream module evaluation.
import './JS/chavrusaRPCFacade';
import { setupChavrusaRPCBridge } from './JS/ChavrusaRoot';

// 2. Initialize original Sefaria-Mobile global context, state providers, and components
try {
  require('../Upstream/index');
} catch (e) {
  console.warn('[ChavrusaText] Upstream Sefaria initialization warning:', e);
}

console.log('[ChavrusaText] Sefaria-Mobile embedded JS runtime initialized successfully');

// 3. Setup RPC bridge listener and emit ready handshake to native Swift
try {
  setupChavrusaRPCBridge();
  let readyAttempts = 0;
  const readyInterval = setInterval(() => {
    readyAttempts += 1;
    if (readyAttempts >= 10) {
      clearInterval(readyInterval);
      return;
    }
    setupChavrusaRPCBridge();
  }, 500);
} catch (e) {
  console.warn('[ChavrusaText] Failed to initialize RPC bridge after upstream load:', e);
}

