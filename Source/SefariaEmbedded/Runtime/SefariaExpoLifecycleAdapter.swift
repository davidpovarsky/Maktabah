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
    private var isHostActive: Bool = false
    #if canImport(Expo)
    private var reactNativeDelegate: Any?
    private var reactNativeFactory: Any?
    #endif
    #endif

    private init() {}

    #if canImport(UIKit)
    public var isStarted: Bool {
        #if canImport(React)
        return isHostActive
        #else
        return true
        #endif
    }

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
        if isHostActive {
            return
        }

        #if canImport(Expo)
        let delegate = ChavrusaReactNativeDelegate()
        #if canImport(ReactAppDependencyProvider)
        delegate.dependencyProvider = RCTAppDependencyProvider()
        #endif
        let factory = ExpoReactNativeFactory(delegate: delegate)
        self.reactNativeDelegate = delegate
        self.reactNativeFactory = factory

        // Mount a persistent headless background root view to bootstrap the Hermes
        // engine, global context, and JS RPC module without disrupting Maktabah's
        // native SwiftUI window hierarchy.
        let rootView = factory.createRootView(withModuleName: "ChavrusaSefariaRoot", initialProperties: nil)
        rootView.isHidden = true
        rootView.alpha = 0.001
        rootView.isUserInteractionEnabled = false
        self.hostedRootView = rootView
        self.isHostActive = true
        #else
        if let bridge = ChavrusaSefariaBridgeModule.shared.bridge {
            let rootView = RCTRootView(
                bridge: bridge,
                moduleName: "ChavrusaSefariaRoot",
                initialProperties: nil
            )
            rootView.isHidden = true
            rootView.alpha = 0.001
            rootView.isUserInteractionEnabled = false
            self.hostedRootView = rootView
            self.isHostActive = true
        }
        #endif
        #endif
    }

    #if canImport(UIKit)
    public func createSurfaceView(moduleName: String, initialProperties: [String: Any]? = nil) -> UIView {
        #if canImport(React)
        #if canImport(Expo)
        if let factory = self.reactNativeFactory as? ExpoReactNativeFactory {
            let surface = factory.createRootView(withModuleName: moduleName, initialProperties: initialProperties)
            surface.backgroundColor = .clear
            return surface
        }
        #endif
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

    public var isStarted: Bool { true }

    public func ensureHostStarted() {
        // Portable host fallback
    }

    #endif
}

#if canImport(UIKit) && canImport(React) && canImport(Expo)
private final class ChavrusaReactNativeDelegate: ExpoReactNativeFactoryDelegate {
    override func sourceURL(for bridge: RCTBridge) -> URL? {
        bridge.bundleURL ?? bundleURL()
    }

    override func bundleURL() -> URL? {
        #if DEBUG
        if let metroURL = RCTBundleURLProvider.sharedSettings().jsBundleURL(forBundleRoot: ".expo/.virtual-metro-entry") {
            return metroURL
        }
        return Bundle.main.url(forResource: "main", withExtension: "jsbundle")
        #else
        return Bundle.main.url(forResource: "main", withExtension: "jsbundle")
        #endif
    }
}
#endif
