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
final class SefariaExpoLifecycleAdapter {
    static let shared = SefariaExpoLifecycleAdapter()

    #if canImport(UIKit) && canImport(React)
    private var hostedWindow: UIWindow?
    private var isHostActive: Bool = false
    #if canImport(Expo)
    private var reactNativeDelegate: Any?
    private var reactNativeFactory: Any?
    #endif
    #endif

    private init() {}

    #if canImport(UIKit)
    var isStarted: Bool {
        #if canImport(React)
        return isHostActive
        #else
        return true
        #endif
    }

    @discardableResult
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        return true
    }

    func application(
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

    func application(
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
    func ensureHostStarted() {
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

        // Mount a persistent headless background UIWindow to bootstrap the Hermes
        // engine, global context, and JS RPC module without disrupting Maktabah's
        // native SwiftUI window hierarchy.
        let headlessWindow = UIWindow(frame: .zero)
        headlessWindow.isHidden = true
        headlessWindow.alpha = 0.001
        headlessWindow.isUserInteractionEnabled = false

        factory.startReactNative(
            withModuleName: "ChavrusaSefariaRoot",
            in: headlessWindow,
            launchOptions: nil
        )
        self.hostedWindow = headlessWindow
        self.isHostActive = true
        #endif
        #endif
    }

    #if canImport(UIKit)
    func createSurfaceView(moduleName: String, initialProperties: [String: Any]? = nil) -> UIView {
        #if canImport(React)
        ensureHostStarted()
        #if canImport(Expo)
        if let factory = reactNativeFactory as? ExpoReactNativeFactory {
            return factory.rootViewFactory.view(withModuleName: moduleName, initialProperties: initialProperties)
        }
        #endif
        #endif
        let container = UIView()
        container.backgroundColor = .systemBackground
        return container
    }
    #endif

    #else

    var isStarted: Bool { true }

    func ensureHostStarted() {
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
        if let bundledURL = Bundle.main.url(forResource: "main", withExtension: "jsbundle") {
            #if DEBUG
            if ProcessInfo.processInfo.environment["ENABLE_METRO"] == "1",
               let metroURL = RCTBundleURLProvider.sharedSettings().jsBundleURL(forBundleRoot: ".expo/.virtual-metro-entry") {
                return metroURL
            }
            #endif
            return bundledURL
        }
        #if DEBUG
        return RCTBundleURLProvider.sharedSettings().jsBundleURL(forBundleRoot: ".expo/.virtual-metro-entry")
        #else
        return nil
        #endif
    }
}
#endif
