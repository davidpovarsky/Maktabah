/**
 * ChavrusaRoot.js
 * React Native Root component that preserves Sefaria-Mobile's original context providers,
 * state managers, and error boundaries, while connecting native Swift to the JS engine.
 */

'use strict';

import React, { useReducer, useEffect } from 'react';
import { AppRegistry, View, NativeModules } from 'react-native';
import BatchedBridge from 'react-native/Libraries/BatchedBridge/BatchedBridge';
import { SafeAreaProvider } from 'react-native-safe-area-context';
import { ErrorBoundary } from 'react-error-boundary';
import {
  GlobalStateContext,
  DispatchContext,
  reducer,
  DEFAULT_STATE,
  getTheme,
} from '../../Upstream/StateManager';
import { ChavrusaRPCFacade } from './chavrusaRPCFacade';

const FallbackView = () => <View style={{ flex: 1, backgroundColor: 'transparent' }} />;

export const ChavrusaRoot = (props) => {
  const [globalState, dispatch] = useReducer(reducer, DEFAULT_STATE);
  const theme = getTheme(globalState.themeStr);

  useEffect(() => {
    ChavrusaRPCFacade.setDispatch(dispatch);

    const handleIncomingEnvelope = async (envelopeJSON) => {
      try {
        const envelope = typeof envelopeJSON === 'string' ? JSON.parse(envelopeJSON) : envelopeJSON;
        const response = await ChavrusaRPCFacade.handleNativeEnvelope(envelope);
        const responseJSON = JSON.stringify(response);

        if (NativeModules?.ChavrusaSefariaBridgeModule?.deliverResponse) {
          NativeModules.ChavrusaSefariaBridgeModule.deliverResponse(responseJSON);
        }
        return responseJSON;
      } catch (err) {
        const errResponse = JSON.stringify({
          protocolVersion: '1.0',
          requestID: envelopeJSON?.requestID || 'unknown',
          status: 'error',
          resultJson: null,
          error: { code: 'NATIVE_INVOCATION_FAILED', message: err?.message || String(err), retryable: false },
          sessionGeneration: envelopeJSON?.sessionGeneration || 0,
        });
        if (NativeModules?.ChavrusaSefariaBridgeModule?.deliverResponse) {
          NativeModules.ChavrusaSefariaBridgeModule.deliverResponse(errResponse);
        }
        return errResponse;
      }
    };

    // 1. Register with NativeModule direct callback if available
    if (NativeModules?.ChavrusaSefariaBridgeModule?.registerJSDispatcher) {
      NativeModules.ChavrusaSefariaBridgeModule.registerJSDispatcher(handleIncomingEnvelope);
    }

    // 2. Also register callable module for bridge.enqueueJSCall compatibility
    try {
      BatchedBridge.registerCallableModule('ChavrusaRPCModule', {
        handleEnvelope: handleIncomingEnvelope,
      });
    } catch (e) {
      // Ignore if already registered
    }

    // 3. Notify native that JS root is mounted and providers are live
    ChavrusaRPCFacade.sendEventToNative('ready', { timestamp: Date.now() });
  }, [dispatch]);

  return (
    <ErrorBoundary FallbackComponent={FallbackView}>
      <SafeAreaProvider>
        <DispatchContext.Provider value={dispatch}>
          <GlobalStateContext.Provider value={globalState}>
            <View style={{ flex: 1, backgroundColor: 'transparent' }} testID="chavrusa-root-container">
              {props.children}
            </View>
          </GlobalStateContext.Provider>
        </DispatchContext.Provider>
      </SafeAreaProvider>
    </ErrorBoundary>
  );
};

AppRegistry.registerComponent('ChavrusaSefariaRoot', () => ChavrusaRoot);
