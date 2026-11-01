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
import { loadTextOffline, textFromRefData } from '../../Upstream/offline';
import { ERRORS } from '../../Upstream/errors';
import api from '../../Upstream/api';

/**
 * Loads text while rigorously tracking provenance (offline vs remote).
 * Does not invent an origin from response shape.
 */
export async function loadTextWithProvenance(ref, context = true, versions, fallbackOnDefaultVersions = true, failSilently = false) {
  if (typeof context === 'undefined') { context = true; }

  // 1. If debugNoLibrary is active, skip offline loading entirely
  if (!global.Sefaria?.debugNoLibrary) {
    try {
      const offlineResult = await loadTextOffline(ref, versions, fallbackOnDefaultVersions);
      const { textContent, links } = offlineResult || {};
      if (textContent?.missingLangs?.length) {
        throw ERRORS.MISSING_OFFLINE_DATA;
      }
      if (!context) {
        const result = textFromRefData(textContent);
        return {
          result,
          textContent: null,
          links: [],
          isOffline: true,
          origin: 'offline',
        };
      }
      return {
        textContent,
        links: links || [],
        result: null,
        isOffline: true,
        origin: 'offline',
      };
    } catch (error) {
      if (error !== ERRORS.MISSING_OFFLINE_DATA) {
        // Corrupt file or parsing error — do NOT fall back to remote API!
        console.error('[ChavrusaText] Unexpected offline load error (corrupt file or parse error):', error);
        throw error;
      }
      // Missing offline data: fall back to remote API below
    }
  }

  // 2. Remote API fallback
  const rawApiData = await api.textApi(ref, context, versions, failSilently);
  api.processTextApiData(ref, context, versions, rawApiData);

  let textContent = null;
  let links = [];
  let result = null;

  if (context) {
    textContent = rawApiData?.textContent || rawApiData;
    links = rawApiData?.links || [];
  } else {
    result = rawApiData?.result || rawApiData;
  }

  return {
    textContent,
    links,
    result,
    isOffline: false,
    origin: 'remote',
  };
}

export class ChavrusaRPCFacade {
  static dispatch = null;
  static activeDownloadingPackage = null;

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
          backendID: 'sefariaEmbedded',
        };
      }
    }

    try {
      let result = null;
      switch (method) {
        // --- DIAGNOSTICS & RUNTIME ---
        case 'diagnostic.echo': {
          if (params?.injectError) {
            return {
              protocolVersion: '1.0',
              requestID,
              status: 'error',
              resultJson: null,
              error: {
                code: 'ECHO_INJECTED_ERROR',
                message: params?.errorMessage || 'Injected diagnostic error',
                retryable: false,
              },
              sessionGeneration,
              backendID: 'sefariaEmbedded',
            };
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
          const loaded = await loadTextWithProvenance(
            params.ref,
            params.context !== false,
            params.versions,
            params.fallbackOnDefaultVersions !== false,
            params.failSilently || false
          );
          result = {
            textContent: loaded.textContent,
            links: loaded.links || [],
            result: loaded.result,
            isOffline: loaded.isOffline,
            origin: loaded.origin,
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
              let snippet = Array.isArray(snippetArr) && snippetArr.length > 0
                ? snippetArr.join(' ... ')
                : (typeof snippetArr === 'string' && snippetArr.length > 0 ? snippetArr : '');
              if (!snippet) {
                snippet = source.text || source.he || '';
              }
              const bookTitle = source.title || (global.Sefaria?.textTitleForRef ? global.Sefaria.textTitleForRef(source.ref) : null) || source.ref;
              return {
                ref: source.ref,
                heRef: source.heRef,
                title: bookTitle,
                workKey: bookTitle,
                snippet: snippet,
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
          if (!DownloadControl.PackagesState || Object.keys(DownloadControl.PackagesState).length === 0) {
            await DownloadControl.packageSetupProtocol();
          }
          const pkg = DownloadControl.PackagesState?.[params.packageName];
          if (!pkg) {
            throw new Error(`Package '${params.packageName}' not found in package manifest`);
          }

          DownloadControl.Tracker.downloadTitle = params.packageName;
          ChavrusaRPCFacade.activeDownloadingPackage = params.packageName;

          try {
            await DownloadControl.downloadPackage(
              params.packageName,
              params.networkSetting || 'wifiOnly'
            );
          } finally {
            ChavrusaRPCFacade.activeDownloadingPackage = null;
          }

          // Verify whether the package was physically installed
          await DownloadControl.repopulateBooksState();
          const installedBooks = Object.keys(DownloadControl.BooksState || {}).filter(
            b => !!DownloadControl.BooksState[b]?.localLastUpdated
          );
          const pkgIndexes = pkg.jsonData?.indexes || [];
          const isInstalled = pkgIndexes.length > 0 && pkgIndexes.every(b => installedBooks.includes(b));

          if (!isInstalled) {
            throw new Error(`Installation of package '${params.packageName}' failed or was blocked by network policy`);
          }

          result = {
            installed: true,
            packageName: params.packageName,
            booksCount: pkgIndexes.length,
          };
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
        backendID: 'sefariaEmbedded',
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
        backendID: 'sefariaEmbedded',
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
    } else {
      console.warn('[ChavrusaText] sendEventToNative failed: NativeModules.ChavrusaSefariaBridgeModule.deliverEvent is unavailable');
    }
  }
}
