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

@MainActor
public final class SefariaExpoLifecycleAdapter {
    public static let shared = SefariaExpoLifecycleAdapter()

    private init() {}

    #if canImport(UIKit)
    @discardableResult
    public func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        #if canImport(React)
        // Lazy startup: React Native Hermes runtime starts on first Sefaria usage or background warm-up
        #endif
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
    #endif
}
