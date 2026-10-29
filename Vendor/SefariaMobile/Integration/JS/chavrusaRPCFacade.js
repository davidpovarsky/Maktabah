/**
 * chavrusaRPCFacade.js
 * Downstream-owned RPC dispatcher connecting ChavrusaText native Swift host
 * directly to original Sefaria-Mobile upstream engines, without duplicating any Sefaria algorithms.
 */

'use strict';

import { NativeModules } from 'react-native';
import AsyncStorage from '@react-native-async-storage/async-storage';
import * as OfflineOnline from '../../Upstream/offlineOnline';
import * as DownloadControl from '../../Upstream/DownloadControl';

export class ChavrusaRPCFacade {
  static dispatch = null;

  static setDispatch(d) {
    ChavrusaRPCFacade.dispatch = d;
  }

  static async handleNativeEnvelope(envelope) {
    const { protocolVersion, requestID, method, paramsJson, backendID, sessionGeneration } = envelope;
    let params = {};
    if (paramsJson) {
      try {
        params = typeof paramsJson === 'string' ? JSON.parse(paramsJson) : paramsJson;
      } catch (e) {
        return {
          protocolVersion: '1.0',
          requestID,
          status: 'error',
          resultJson: null,
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
            throw new Error('global.Sefaria is not defined in runtime environment');
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
          result = global.Sefaria?.getRootTocItems ? global.Sefaria.getRootTocItems() : (global.Sefaria?.toc || []);
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
        case 'search.query': {
          if (!global.Sefaria?.search?.execute_query) {
            throw new Error('Sefaria search engine not initialized');
          }
          const queryProps = {
            query: params.query,
            start: params.offset || 0,
            size: params.limit || 20,
            type: params.type || 'text',
            field: params.field || 'exact',
            exact: params.exact || false,
            applied_filters: params.appliedFilters || [],
            appliedFilterAggTypes: params.appliedFilterAggTypes || [],
            sort_type: params.sortType || 'relevance',
          };
          const rawSearchData = await global.Sefaria.search.execute_query(queryProps);
          const rawHits = rawSearchData?.hits?.hits || [];
          const processedHits = global.Sefaria.search.process_text_hits
            ? global.Sefaria.search.process_text_hits(rawHits)
            : rawHits;

          result = {
            hits: processedHits.map(hit => {
              const source = hit._source || {};
              const highlight = hit.highlight || {};
              const snippetArr = highlight.exact || highlight.naive_lemmatizer || highlight.text || [];
              return {
                ref: source.ref,
                heRef: source.heRef,
                snippet: Array.isArray(snippetArr) ? snippetArr.join(' ... ') : String(snippetArr),
                score: hit._score,
                version: source.version,
                language: hit._id?.includes('[he]') ? 'hebrew' : 'english',
              };
            }),
            total: rawSearchData?.hits?.total || 0,
            start: queryProps.start,
            size: queryProps.size,
          };
          break;
        }

        // --- DOWNLOADS & UPDATES ---
        case 'downloads.packages': {
          if (!DownloadControl.PackagesState || Object.keys(DownloadControl.PackagesState).length === 0) {
            await DownloadControl.packageSetupProtocol();
          }
          const pkgs = Object.values(DownloadControl.PackagesState || {}).map(pkg => ({
            id: pkg.name,
            title: pkg.jsonData?.en || pkg.name,
            heTitle: pkg.jsonData?.he || null,
            parentID: pkg.parent || null,
            compressedSize: pkg.jsonData?.size || 0,
            indexTitles: pkg.jsonData?.indexes || [],
            isCompleteLibrary: pkg.name === 'COMPLETE LIBRARY',
          }));
          result = pkgs;
          break;
        }

        case 'downloads.installed': {
          const stored = await AsyncStorage.getItem('packagesSelected');
          const packagesSelected = stored ? JSON.parse(stored) : {};
          result = Object.keys(packagesSelected);
          break;
        }

        case 'downloads.install': {
          result = await DownloadControl.downloadPackage(
            params.packageName,
            params.networkSetting || 'wifiOnly'
          );
          break;
        }

        case 'downloads.remove': {
          if (params.bookTitles && params.bookTitles.length > 0) {
            await DownloadControl.deleteBooks(params.bookTitles);
          } else {
            const toDelete = DownloadControl.calculateBooksToDelete();
            if (toDelete && toDelete.length > 0) {
              await DownloadControl.deleteBooks(toDelete);
            }
          }
          result = { removed: true };
          break;
        }

        case 'downloads.cancel': {
          if (DownloadControl.Tracker?.cancelDownload) {
            DownloadControl.Tracker.cancelDownload(false);
          }
          result = { cancelled: true };
          break;
        }

        case 'updates.check': {
          result = await DownloadControl.checkUpdatesFromServer();
          break;
        }

        case 'updates.download': {
          result = await DownloadControl.downloadUpdate(
            params.networkSetting || 'wifiOnly',
            false
          );
          break;
        }

        default:
          throw new Error(`Unsupported RPC method: ${method}`);
      }

      return {
        protocolVersion: '1.0',
        requestID,
        status: 'success',
        resultJson: result !== undefined && result !== null ? JSON.stringify(result) : null,
        error: null,
        sessionGeneration,
      };
    } catch (err) {
      return {
        protocolVersion: '1.0',
        requestID,
        status: 'error',
        resultJson: null,
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
    if (NativeModules?.ChavrusaSefariaBridgeModule?.deliverEvent) {
      NativeModules.ChavrusaSefariaBridgeModule.deliverEvent(
        JSON.stringify({
          event: eventName,
          sequence: Date.now(),
          backendID: 'sefariaEmbedded',
          payloadJson: payload ? JSON.stringify(payload) : null,
        })
      );
    }
  }
}
