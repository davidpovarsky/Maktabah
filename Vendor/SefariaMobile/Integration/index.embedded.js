'use strict';

// 1. Initialize original Sefaria-Mobile global context, state providers, and components
import '../Upstream/index';

// 2. Load ChavrusaText RPC facade and Root component
import './JS/chavrusaRPCFacade';
import './JS/ChavrusaRoot';

console.log('[ChavrusaText] Sefaria-Mobile embedded JS runtime initialized successfully');
