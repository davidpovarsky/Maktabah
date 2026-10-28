/**
 * ChavrusaRoot.js
 * React Native Root component that preserves Sefaria-Mobile's original context providers,
 * state managers, and error boundaries, while allowing native Swift to invoke RPC methods.
 */

'use strict';

import React, { useReducer, useEffect } from 'react';
import { AppRegistry, View } from 'react-native';
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

    // Register global bridge handler for native invocation
    global.__chavrusaHandleEnvelope = async (envelopeJSON) => {
      try {
        const envelope = typeof envelopeJSON === 'string' ? JSON.parse(envelopeJSON) : envelopeJSON;
        const response = await ChavrusaRPCFacade.handleNativeEnvelope(envelope);
        return JSON.stringify(response);
      } catch (err) {
        return JSON.stringify({
          protocolVersion: '1.0',
          status: 'error',
          error: { code: 'NATIVE_INVOCATION_FAILED', message: err?.message || String(err) },
        });
      }
    };

    // Notify native that JS bridge is mounted and ready
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
