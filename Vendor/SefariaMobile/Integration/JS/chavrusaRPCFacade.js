/**
 * chavrusaRPCFacade.js
 * Downstream-owned RPC dispatcher connecting ChavrusaText native Swift host
 * directly to original Sefaria-Mobile upstream engines, without duplicating any Sefaria algorithms.
 */

'use strict';

import * as OfflineOnline from '../../Upstream/offlineOnline';
import * as DownloadControl from '../../Upstream/DownloadControl';

export class ChavrusaRPCFacade {
  static dispatch = null;

  static setDispatch(d) {
    ChavrusaRPCFacade.dispatch = d;
  }

  static async handleNativeEnvelope(envelope) {
    const { protocolVersion, requestID, method, paramsData, backendID, sessionGeneration } = envelope;
    let params = {};
    if (paramsData) {
      try {
        params = typeof paramsData === 'string' ? JSON.parse(paramsData) : paramsData;
      } catch (e) {
        return {
          protocolVersion: '1.0',
          requestID,
          status: 'error',
          error: { code: 'INVALID_JSON_PARAMS', message: e.message, retryable: false },
          sessionGeneration,
        };
      }
    }

    try {
      let result = null;
      switch (method) {
        // --- RUNTIME ---
        case 'runtime.initialize':
          if (!global.Sefaria) {
            throw new Error('global.Sefaria is not defined');
          }
          await global.Sefaria.init(ChavrusaRPCFacade.dispatch || (() => {}));
          result = { status: 'initialized' };
          break;

        case 'runtime.postInitSearch':
          if (global.Sefaria?.postInitSearch) {
            await global.Sefaria.postInitSearch();
          }
          result = { status: 'postInitSearch_complete' };
          break;

        case 'runtime.postInit':
          if (global.Sefaria?.postInit) {
            await global.Sefaria.postInit(params.networkSetting || 'wifiOnly');
          }
          result = { status: 'postInit_complete' };
          break;

        // --- CATALOG ---
        case 'catalog.root':
          result = global.Sefaria?.getRootTocItems ? global.Sefaria.getRootTocItems() : [];
          break;

        case 'catalog.bookMetadata':
          result = global.Sefaria?.index ? global.Sefaria.index(params.title) : null;
          break;

        case 'catalog.toc':
          result = global.Sefaria?.toc || [];
          break;

        // --- TEXT & VERSIONS ---
        case 'text.load':
          result = await OfflineOnline.loadText(
            params.ref,
            params.context !== false,
            params.versions,
            params.fallbackOnDefaultVersions !== false,
            params.failSilently || false
          );
          break;

        case 'text.versions':
          result = await OfflineOnline.loadVersions(params.ref);
          break;

        case 'text.translations':
          result = await OfflineOnline.loadTranslations(params.ref, params.online !== false);
          break;

        // --- NAVIGATION ---
        case 'navigation.textToc':
          result = await OfflineOnline.textToc(params.title);
          break;

        case 'navigation.refUpOne':
          result = global.Sefaria?.refUpOne ? global.Sefaria.refUpOne(params.ref) : params.ref;
          break;

        // --- RELATIONSHIPS ---
        case 'relationships.links':
          result = await OfflineOnline.loadRelated(params.ref, params.online !== false);
          break;

        // --- SEARCH ---
        case 'search.query':
          if (!global.Sefaria?.search?.execute_query) {
            throw new Error('Sefaria search engine not initialized');
          }
          result = await global.Sefaria.search.execute_query(params.queryProps);
          break;

        case 'search.processHits':
          if (!global.Sefaria?.search?.process_text_hits) {
            throw new Error('Sefaria process_text_hits not initialized');
          }
          result = global.Sefaria.search.process_text_hits(params.hits);
          break;

        // --- DOWNLOADS & UPDATES ---
        case 'downloads.selected':
          result = DownloadControl.selectedPackages ? DownloadControl.selectedPackages() : {};
          break;

        case 'downloads.install':
          result = await DownloadControl.downloadPackage(
            params.packageTitle,
            params.networkSetting || 'wifiOnly',
            (progress) => {
              ChavrusaRPCFacade.sendEventToNative('downloadProgress', {
                packageTitle: params.packageTitle,
                progress,
              });
            }
          );
          break;

        case 'downloads.cancel':
          if (DownloadControl.runCancelMethods) {
            DownloadControl.runCancelMethods();
          }
          result = { cancelled: true };
          break;

        case 'updates.check':
          result = await DownloadControl.checkUpdatesFromServer();
          break;

        case 'updates.download':
          result = await DownloadControl.downloadUpdate(
            params.networkSetting || 'wifiOnly',
            false
          );
          break;

        default:
          throw new Error(`Unsupported RPC method: ${method}`);
      }

      return {
        protocolVersion: '1.0',
        requestID,
        status: 'success',
        resultData: result ? JSON.stringify(result) : null,
        error: null,
        sessionGeneration,
      };
    } catch (err) {
      return {
        protocolVersion: '1.0',
        requestID,
        status: 'error',
        resultData: null,
        error: {
          code: 'EXECUTION_ERROR',
          message: err?.message || String(err),
          retryable: false,
        },
        sessionGeneration,
      };
    }
  }

  static sendEventToNative(eventName, payload) {
    if (global.__chavrusaNativeBridge?.emitEvent) {
      global.__chavrusaNativeBridge.emitEvent(
        JSON.stringify({
          event: eventName,
          sequence: Date.now(),
          backendID: 'sefariaEmbedded',
          payloadData: JSON.stringify(payload),
        })
      );
    }
  }
}
