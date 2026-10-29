/**
 * ChavrusaRoot.js
 * React Native Root component that preserves Sefaria-Mobile's original context providers,
 * state managers, and error boundaries, while connecting native Swift to the JS engine.
 */

'use strict';

import React, { useReducer, useEffect } from 'react';
import { AppRegistry, View, NativeModules, NativeEventEmitter } from 'react-native';
import { SafeAreaProvider } from 'react-native-safe-area-context';
import { ErrorBoundary } from 'react-error-boundary';
import { gestureHandlerRootHOC } from 'react-native-gesture-handler';
import {
  GlobalStateContext,
  DispatchContext,
  reducer,
  DEFAULT_STATE,
  getTheme,
} from '../../Upstream/StateManager';
import ReaderApp from '../../Upstream/ReaderApp';
import * as DownloadControl from '../../Upstream/DownloadControl';
import { ChavrusaRPCFacade } from './chavrusaRPCFacade';

const ReaderAppGesturified = gestureHandlerRootHOC(ReaderApp);
const FallbackView = () => <View style={{ flex: 1, backgroundColor: 'transparent' }} />;

export const ChavrusaRoot = (props) => {
  const [globalState, dispatch] = useReducer(reducer, DEFAULT_STATE);
  const theme = getTheme(globalState.themeStr);

  useEffect(() => {
    ChavrusaRPCFacade.setDispatch(dispatch);

    const handleIncomingEnvelope = async (envelopeJSON) => {
      let reqID = 'unknown';
      let sessionGen = 0;
      try {
        const envelope = typeof envelopeJSON === 'string' ? JSON.parse(envelopeJSON) : envelopeJSON;
        reqID = envelope?.requestID || 'unknown';
        sessionGen = envelope?.sessionGeneration || 0;

        const response = await ChavrusaRPCFacade.handleNativeEnvelope(envelope);
        const responseJSON = JSON.stringify(response);

        if (NativeModules?.ChavrusaSefariaBridgeModule?.deliverResponse) {
          NativeModules.ChavrusaSefariaBridgeModule.deliverResponse(responseJSON);
        }
        return responseJSON;
      } catch (err) {
        const errResponse = JSON.stringify({
          protocolVersion: '1.0',
          requestID: reqID,
          status: 'error',
          resultJson: null,
          error: { code: 'NATIVE_INVOCATION_FAILED', message: err?.message || String(err), retryable: false },
          sessionGeneration: sessionGen,
        });
        if (NativeModules?.ChavrusaSefariaBridgeModule?.deliverResponse) {
          NativeModules.ChavrusaSefariaBridgeModule.deliverResponse(errResponse);
        }
        return errResponse;
      }
    };

    // 1. Subscribe to NativeEventEmitter for incoming Swift RPC requests
    let subscription = null;
    if (NativeModules?.ChavrusaSefariaBridgeModule) {
      try {
        const eventEmitter = new NativeEventEmitter(NativeModules.ChavrusaSefariaBridgeModule);
        subscription = eventEmitter.addListener('onSefariaRPCRequest', handleIncomingEnvelope);
      } catch (e) {
        console.warn('[ChavrusaRoot] Failed to create NativeEventEmitter:', e);
      }
    }

    // 2. Wire DownloadControl Tracker progress events to Native
    try {
      if (DownloadControl?.Tracker?.attachProgressTracker) {
        DownloadControl.Tracker.attachProgressTracker((bytesWritten, totalBytes) => {
          ChavrusaRPCFacade.sendEventToNative('downloadProgress', {
            bytesWritten: Number(bytesWritten) || 0,
            totalBytes: Number(totalBytes) || 1,
            fraction: totalBytes > 0 ? (bytesWritten / totalBytes) : 0,
          });
        }, 'chavrusaTracker');
      }
    } catch (e) {
      console.warn('[ChavrusaRoot] Failed to attach progress tracker:', e);
    }

    // 3. Notify native that JS root is mounted and providers are live
    ChavrusaRPCFacade.sendEventToNative('ready', {
      timestamp: Date.now(),
      version: '1.0',
      upstreamLockedSHA: '2fd173a5a3bd32d94a9ba1222e4e32a37f6bd23c',
    });

    return () => {
      if (subscription?.remove) {
        subscription.remove();
      }
    };
  }, [dispatch]);

  const renderContent = () => {
    if (props?.renderFullUI) {
      return (
        <ReaderAppGesturified
          {...globalState}
          theme={theme}
          dispatch={dispatch}
        />
      );
    }
    return (
      <View style={{ flex: 1, backgroundColor: 'transparent' }} testID="chavrusa-root-container">
        {props.children}
      </View>
    );
  };

  return (
    <ErrorBoundary FallbackComponent={FallbackView}>
      <SafeAreaProvider>
        <DispatchContext.Provider value={dispatch}>
          <GlobalStateContext.Provider value={globalState}>
            {renderContent()}
          </GlobalStateContext.Provider>
        </DispatchContext.Provider>
      </SafeAreaProvider>
    </ErrorBoundary>
  );
};

// Register under both names so any factory instantiation activates the ChavrusaRoot RPC & context
AppRegistry.registerComponent('ChavrusaSefariaRoot', () => ChavrusaRoot);
AppRegistry.registerComponent('ReaderApp', () => ChavrusaRoot);
