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
        // --- DIAGNOSTICS & RUNTIME ---
        case 'diagnostic.echo': {
          if (params?.injectError) {
            throw new Error(params?.errorMessage || 'Injected diagnostic error');
          }
          result = {
            echoedMessage: params?.message || '',
            timestamp: Date.now(),
            generation: sessionGeneration,
          };
          break;
        }

        case 'runtime.initialize':
          if (!global.Sefaria) {
            throw new Error('global.Sefaria is not defined in runtime environment');
          }
          await global.Sefaria.init(ChavrusaRPCFacade.dispatch || (() => {}));
          result = { status: 'initialized' };
          break;

        case 'runtime.postInitSearch':
          if (!global.Sefaria?.postInitSearch) {
            throw new Error('global.Sefaria.postInitSearch is not available in runtime');
          }
          await global.Sefaria.postInitSearch();
          result = { status: 'postInitSearch_complete', searchReady: !!global.Sefaria?.search?.execute_query };
          break;

        case 'runtime.postInit':
          if (!global.Sefaria?.postInit) {
            throw new Error('global.Sefaria.postInit is not available in runtime');
          }
          await global.Sefaria.postInit(params.networkSetting || 'wifiOnly');
          result = { status: 'postInit_complete', packagesReady: !!DownloadControl?.PackagesState };
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
        case 'text.load': {
          const raw = await OfflineOnline.loadText(
            params.ref,
            params.context !== false,
            params.versions,
            params.fallbackOnDefaultVersions !== false,
            params.failSilently || false
          );
          let isOffline = false;
          let textContent = null;
          let links = [];
          if (raw?.textContent) {
            textContent = raw.textContent;
            links = raw.links || [];
            isOffline = true;
          } else {
            textContent = raw;
            links = raw?.links || [];
            isOffline = false;
          }
          result = {
            textContent,
            links,
            isOffline,
          };
          break;
        }

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
              const bookTitle = source.title || (global.Sefaria?.textTitleForRef ? global.Sefaria.textTitleForRef(source.ref) : null) || source.ref;
              return {
                ref: source.ref,
                heRef: source.heRef,
                title: bookTitle,
                workKey: bookTitle,
                snippet: Array.isArray(snippetArr) ? snippetArr.join(' ... ') : String(snippetArr),
                score: hit._score,
                version: source.version,
                language: hit._id?.includes('[he]') ? 'hebrew' : 'english',
              };
            }),
            total: (typeof rawSearchData?.hits?.total === 'number')
              ? rawSearchData.hits.total
              : (rawSearchData?.hits?.total?.value || rawHits.length),
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
          if (!DownloadControl.BooksState || Object.keys(DownloadControl.BooksState).length === 0) {
            await DownloadControl.repopulateBooksState();
          }
          if (!DownloadControl.PackagesState || Object.keys(DownloadControl.PackagesState).length === 0) {
            await DownloadControl.packageSetupProtocol();
          }

          // A book is truly installed when localLastUpdated is non-null
          const installedBooks = Object.keys(DownloadControl.BooksState || {}).filter(
            b => !!DownloadControl.BooksState[b]?.localLastUpdated
          );

          // A package is installed if all its indexed books are installed
          const installedPackages = [];
          for (const pkg of Object.values(DownloadControl.PackagesState || {})) {
            const indexes = pkg.jsonData?.indexes || [];
            if (indexes.length > 0 && indexes.every(b => installedBooks.includes(b))) {
              installedPackages.push(pkg.name);
            }
          }

          // Return array of installed package names, plus an object map for works
          result = {
            packages: installedPackages,
            books: installedBooks,
            allKeys: Array.from(new Set([...installedPackages, ...installedBooks])),
          };
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
          let booksToDelete = [];
          if (params.packageTitles && Array.isArray(params.packageTitles)) {
            for (const pkgTitle of params.packageTitles) {
              const pkg = DownloadControl.PackagesState?.[pkgTitle];
              if (pkg && typeof pkg.unclick === 'function') {
                try {
                  const toDel = await pkg.unclick();
                  if (Array.isArray(toDel)) {
                    booksToDelete.push(...toDel);
                  }
                } catch (e) {
                  // Ignore if disabled/superseded
                }
              }
            }
          }
          if (params.bookTitles && Array.isArray(params.bookTitles)) {
            booksToDelete.push(...params.bookTitles);
          }
          const uniqueBooks = Array.from(new Set(booksToDelete));
          if (uniqueBooks.length > 0) {
            await DownloadControl.deleteBooks(uniqueBooks);
            result = { removed: true, booksDeleted: uniqueBooks };
          } else {
            result = { removed: false, booksDeleted: [] };
          }
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
          const updateData = await DownloadControl.checkUpdatesFromServer();
          const allBooksToDownload = Array.isArray(updateData) ? (updateData[0] || []) : [];
          const notDownloaded = Array.isArray(updateData) ? (updateData[1] || []) : [];

          if (!DownloadControl.PackagesState || Object.keys(DownloadControl.PackagesState).length === 0) {
            await DownloadControl.packageSetupProtocol();
          }

          const affectedPackageIDs = [];
          for (const pkg of Object.values(DownloadControl.PackagesState || {})) {
            const indexes = pkg.jsonData?.indexes || [];
            if (indexes.some(b => allBooksToDownload.includes(b))) {
              affectedPackageIDs.push(pkg.name);
            }
          }

          result = {
            allBooksToDownload,
            booksNotDownloaded: notDownloaded,
            hasUpdates: allBooksToDownload.length > 0,
            count: allBooksToDownload.length,
            packageIDs: affectedPackageIDs,
          };
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
