'use strict';

// 1. Load ChavrusaText RPC facade and Root component FIRST to guarantee
// that ChavrusaSefariaRoot is registered with AppRegistry before any
// downstream or upstream module evaluation.
import './JS/chavrusaRPCFacade';
import './JS/ChavrusaRoot';

// 2. Initialize original Sefaria-Mobile global context, state providers, and components
try {
  require('../Upstream/index');
} catch (e) {
  console.warn('[ChavrusaText] Upstream Sefaria initialization warning:', e);
}

console.log('[ChavrusaText] Sefaria-Mobile embedded JS runtime initialized successfully');

