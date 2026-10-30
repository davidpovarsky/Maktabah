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

#if canImport(ObjectiveC)
import ObjectiveC
#endif

@MainActor
final class SefariaExpoLifecycleAdapter {
    static let shared = SefariaExpoLifecycleAdapter()

    #if canImport(UIKit) && canImport(React)
    var hostedWindow: UIWindow?
    var isHostActive: Bool = false
    #if canImport(Expo)
    var reactNativeDelegate: Any?
    var reactNativeFactory: Any?
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
        Self.installKVCResilience()
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

        Self.installKVCResilience()

        #if canImport(Expo)
        let delegate = ChavrusaReactNativeDelegate()
        #if canImport(ReactAppDependencyProvider)
        delegate.dependencyProvider = RCTAppDependencyProvider()
        #endif
        let factory = ExpoReactNativeFactory(delegate: delegate)
        self.reactNativeDelegate = delegate
        self.reactNativeFactory = factory

        // Bind factory to ExpoAppDelegate if available
        #if canImport(Expo)
        let appDelegate = (UIApplication.shared.delegate as? ExpoAppDelegate) ?? (MaktabahApp.sharedAppDelegate as? ExpoAppDelegate)
        if let appDelegate {
            appDelegate.reactNativeFactory = factory
            appDelegate.reactNativeDelegate = delegate
            appDelegate.bindReactNativeFactory(factory)
        }
        #endif

        // Mount a persistent headless background UIWindow to bootstrap the Hermes
        // engine, global context, and JS RPC module without disrupting Maktabah's
        // native SwiftUI window hierarchy.
        let headlessWindow = UIWindow(frame: .zero)
        headlessWindow.isHidden = true
        headlessWindow.alpha = 0.001
        headlessWindow.isUserInteractionEnabled = false
        self.hostedWindow = headlessWindow

        factory.startReactNative(
            withModuleName: "ReaderApp",
            in: headlessWindow,
            launchOptions: nil
        )
        self.isHostActive = true
        #endif
        #endif
    }

    #if canImport(UIKit)
    func createSurfaceView(moduleName: String = "ReaderApp", initialProperties: [String: Any]? = nil) -> UIView {
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

// MARK: - KVC Resilience Implementation

#if canImport(UIKit) && canImport(ObjectiveC)
private var hasInstalledKVCResilience = false

extension SefariaExpoLifecycleAdapter {
    static func installKVCResilience() {
        guard !hasInstalledKVCResilience else { return }
        hasInstalledKVCResilience = true

        // 1. Swizzle NSObject.value(forUndefinedKey:) and setValue(_:forUndefinedKey:)
        // This globally guards all Objective-C objects (including RCTRootViewFactory,
        // EXReactRootViewFactory, and SwiftUI's internal AppDelegate) against uncaught
        // NSUndefinedKeyException crashes during dynamic inspection by Expo and React Native.
        if let origGetter = class_getInstanceMethod(NSObject.self, #selector(NSObject.value(forUndefinedKey:))),
           let safeGetter = class_getInstanceMethod(NSObject.self, #selector(NSObject.chavrusa_safeValue(forUndefinedKey:))) {
            method_exchangeImplementations(origGetter, safeGetter)
        }

        if let origSetter = class_getInstanceMethod(NSObject.self, #selector(NSObject.setValue(_:forUndefinedKey:))),
           let safeSetter = class_getInstanceMethod(NSObject.self, #selector(NSObject.chavrusa_safeSetValue(_:forUndefinedKey:))) {
            method_exchangeImplementations(origSetter, safeSetter)
        }

        // 2. Explicitly install safe handlers on known factory candidate classes
        let candidateClassNames = [
            "RCTRootViewFactory",
            "EXReactRootViewFactory",
            "ExpoReactRootViewFactory"
        ]

        let getterSelector = #selector(NSObject.value(forUndefinedKey:))
        let setterSelector = #selector(NSObject.setValue(_:forUndefinedKey:))

        if let safeGetterMethod = class_getInstanceMethod(NSObject.self, #selector(NSObject.chavrusa_safeValue(forUndefinedKey:))),
           let safeSetterMethod = class_getInstanceMethod(NSObject.self, #selector(NSObject.chavrusa_safeSetValue(_:forUndefinedKey:))) {
            let getterIMP = method_getImplementation(safeGetterMethod)
            let setterIMP = method_getImplementation(safeSetterMethod)
            let getterTypes = method_getTypeEncoding(safeGetterMethod)
            let setterTypes = method_getTypeEncoding(safeSetterMethod)

            for name in candidateClassNames {
                if let cls = NSClassFromString(name) {
                    _ = class_addMethod(cls, getterSelector, getterIMP, getterTypes)
                    _ = class_addMethod(cls, setterSelector, setterIMP, setterTypes)
                }
            }

            if let appDelegate = UIApplication.shared.delegate {
                let appDelegateCls: AnyClass = type(of: appDelegate)
                _ = class_addMethod(appDelegateCls, getterSelector, getterIMP, getterTypes)
                _ = class_addMethod(appDelegateCls, setterSelector, setterIMP, setterTypes)
            }
        }
    }
}

@objc extension NSObject {
    @objc dynamic func chavrusa_safeValue(forUndefinedKey key: String) -> Any? {
        if key == "_configuration" {
            var currentCls: AnyClass? = object_getClass(self)
            while let cls = currentCls, cls != NSObject.self {
                if let ivar = class_getInstanceVariable(cls, "_configuration") {
                    return object_getIvar(self, ivar) as AnyObject?
                }
                currentCls = class_getSuperclass(cls)
            }
            return nil
        }
        if key == "reactHost" {
            return nil
        }
        if key == "reactNativeFactory" {
            return SefariaExpoLifecycleAdapter.shared.reactNativeFactory
        }
        if key == "reactNativeDelegate" {
            return SefariaExpoLifecycleAdapter.shared.reactNativeDelegate
        }
        if key == "window" {
            return SefariaExpoLifecycleAdapter.shared.hostedWindow
        }
        return nil
    }

    @objc dynamic func chavrusa_safeSetValue(_ value: Any?, forUndefinedKey key: String) {
        if key == "_configuration", let val = value {
            var currentCls: AnyClass? = object_getClass(self)
            while let cls = currentCls, cls != NSObject.self {
                if let ivar = class_getInstanceVariable(cls, "_configuration") {
                    object_setIvar(self, ivar, val)
                    return
                }
                currentCls = class_getSuperclass(cls)
            }
        }
    }
}
#else
extension SefariaExpoLifecycleAdapter {
    static func installKVCResilience() {}
}
#endif

#if canImport(UIKit) && canImport(React) && canImport(Expo)
@MainActor
private final class ChavrusaReactNativeDelegate: ExpoReactNativeFactoryDelegate {
    @objc var window: UIWindow? {
        get { SefariaExpoLifecycleAdapter.shared.hostedWindow }
        set { SefariaExpoLifecycleAdapter.shared.hostedWindow = newValue }
    }

    override nonisolated func value(forUndefinedKey key: String) -> Any? {
        return nil
    }

    override nonisolated func setValue(_ value: Any?, forUndefinedKey key: String) {
        // Silently tolerate undefined keys from Expo/React Native subsystems
    }

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
