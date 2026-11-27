'use strict';

import React, {useCallback, useLayoutEffect, useReducer, useRef} from 'react';
import {AppRegistry, View} from 'react-native';
import {SafeAreaProvider} from 'react-native-safe-area-context';
import {GestureHandlerRootView} from 'react-native-gesture-handler';
import {ErrorBoundary, useErrorBoundary} from 'react-error-boundary';
import ReaderApp from '../../Upstream/ReaderApp';
import {ErrorBoundaryFallbackComponent} from '../../Upstream/ErrorBoundaryFallbackComponent';
import {generalAppErrorAlert} from '../../Upstream/errors';
import {GlobalStateContext, DispatchContext, reducer, DEFAULT_STATE, getTheme} from '../../Upstream/StateManager';
import {ChavrusaVisibleSurfaces} from './ChavrusaVisibleSurfaceRegistry';

// The original ReaderApp, reducer, providers and error presentation are imported
// from the pinned Sefaria module. This wrapper owns only a native mount identity.
// It never installs its dispatch into the independent headless RPC bootstrap.
const OriginalVisibleReader = ({identity, registration}) => {
  const [globalState, dispatch] = useReducer(reducer, DEFAULT_STATE);
  const reader = useRef(null);
  const layout = useRef(null);
  const {showBoundary} = useErrorBoundary();
  const onLayout = useCallback(event => {
    const actual = event.nativeEvent.layout;
    const previous = layout.current;
    if (previous?.width === actual.width && previous?.height === actual.height) { return; }
    layout.current = {width: actual.width, height: actual.height,
      revision: (previous?.revision ?? 0) + 1};
  }, []);

  useLayoutEffect(() => {
    const token = ChavrusaVisibleSurfaces.register(identity, () => {
      const original = reader.current;
      if (!(original instanceof ReaderApp)) { return null; }
      return {loaded: original.state.loaded, completedInit: original.state._completedInit};
    }, () => layout.current);
    registration.current = token;
    return () => {
      ChavrusaVisibleSurfaces.unregister(token);
      if (registration.current === token) { registration.current = null; }
    };
  }, [identity, registration]);

  return (
    <DispatchContext.Provider value={dispatch}>
      <GlobalStateContext.Provider value={globalState}>
        <GestureHandlerRootView style={{flex: 1}}>
          <View style={{flex: 1}} onLayout={onLayout} testID="chavrusa-original-sefaria-surface">
            <ReaderApp ref={reader} {...globalState} theme={getTheme(globalState.themeStr)}
              dispatch={dispatch} showErrorBoundary={showBoundary} />
          </View>
        </GestureHandlerRootView>
      </GlobalStateContext.Provider>
    </DispatchContext.Provider>
  );
};

const ChavrusaVisibleSurface = props => {
  // Root props are immutable for one original native mount. Changing them cannot
  // hand a retained React tree to a new scene, epoch or native request.
  const identity = useRef(Object.freeze({surfaceID: props.surfaceID, sceneID: props.sceneID,
    mountID: props.mountID, epoch: props.epoch}));
  const registration = useRef(null);
  const onError = useCallback((error, info) => {
    ChavrusaVisibleSurfaces.markFailed(registration.current);
    generalAppErrorAlert(error, info);
  }, []);
  return (
    <ErrorBoundary FallbackComponent={ErrorBoundaryFallbackComponent} onError={onError}>
      <SafeAreaProvider>
        <OriginalVisibleReader identity={identity.current} registration={registration} />
      </SafeAreaProvider>
    </ErrorBoundary>
  );
};

AppRegistry.registerComponent('ChavrusaSefariaVisibleSurface', () => ChavrusaVisibleSurface);
