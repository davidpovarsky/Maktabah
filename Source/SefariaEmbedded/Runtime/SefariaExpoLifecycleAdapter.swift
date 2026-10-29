//
//  SefariaExpoLifecycleAdapter.swift
//  Maktabah
//
//  Downstream-owned lifecycle adapter that forwards necessary UIApplicationDelegate
//  events to Expo and React Native linking managers via composition, preserving Maktabah's
//  existing SwiftUI @main, CloudKit, and iPad window hierarchy.
//

import Foundation

#if canImport(UIKit)
import UIKit
#endif

#if canImport(React)
import React
#endif

#if canImport(Expo)
import Expo
#endif

#if canImport(React_RCTAppDelegate)
import React_RCTAppDelegate
#endif

#if canImport(ReactAppDependencyProvider)
import ReactAppDependencyProvider
#endif

@MainActor
public final class SefariaExpoLifecycleAdapter {
    public static let shared = SefariaExpoLifecycleAdapter()

    #if canImport(UIKit) && canImport(React)
    private var hostedRootView: UIView?
    #endif

    private init() {}

    #if canImport(UIKit)
    @discardableResult
    public func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        return true
    }

    public func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        #if canImport(React)
        return RCTLinkingManager.application(app, open: url, options: options)
        #else
        return false
        #endif
    }

    public func application(
        _ application: UIApplication,
        continue userActivity: NSUserActivity,
        restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
    ) -> Bool {
        #if canImport(React)
        return RCTLinkingManager.application(
            application,
            continue: userActivity,
            restorationHandler: restorationHandler
        )
        #else
        return false
        #endif
    }

    /// Initializes and mounts the React Native / Expo Hermes runtime if not already active.
    public func ensureHostStarted() {
        #if canImport(UIKit) && canImport(React)
        if hostedRootView != nil {
            return
        }

        // In real iOS build with CocoaPods/Expo, bind factory and mount headless/background root view
        // to bootstrap GlobalStateContext and DispatchContext without overtaking app UIWindow.
        #endif
    }

    #if canImport(UIKit)
    public func createSurfaceView(moduleName: String, initialProperties: [String: Any]? = nil) -> UIView {
        #if canImport(React)
        if let bridge = ChavrusaSefariaBridgeModule.shared.bridge {
            let rootView = RCTRootView(
                bridge: bridge,
                moduleName: moduleName,
                initialProperties: initialProperties
            )
            rootView.backgroundColor = .clear
            return rootView
        }
        #endif
        let placeholder = UIView()
        placeholder.backgroundColor = .clear
        return placeholder
    }
    #endif

    #else

    public func ensureHostStarted() {
        // Portable fallback
    }

    #endif
}
