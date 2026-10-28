//
//  SefariaEmbeddedNativeSurfaceHost.swift
//  Maktabah
//
//  Downstream-owned UIViewControllerRepresentable / UIKit host allowing SwiftUI
//  to present genuine React Native components from Sefaria-Mobile within native containers.
//

import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

#if canImport(React)
import React
#endif

public struct SefariaEmbeddedNativeSurfaceHost: UIViewControllerRepresentable {
    public let moduleName: String
    public let initialProperties: [String: Any]?

    public init(moduleName: String = "ChavrusaSefariaRoot", initialProperties: [String: Any]? = nil) {
        self.moduleName = moduleName
        self.initialProperties = initialProperties
    }

    public func makeUIViewController(context: Context) -> UIViewController {
        let vc = UIViewController()
        vc.view.backgroundColor = .clear

        #if canImport(React)
        if let bridge = ChavrusaSefariaBridgeModule.shared.bridge {
            let rootView = RCTRootView(
                bridge: bridge,
                moduleName: moduleName,
                initialProperties: initialProperties
            )
            rootView.backgroundColor = .clear
            rootView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            rootView.frame = vc.view.bounds
            vc.view.addSubview(rootView)
        }
        #endif

        return vc
    }

    public func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        #if canImport(React)
        if let rootView = uiViewController.view.subviews.first(where: { $0 is RCTRootView }) as? RCTRootView,
           let props = initialProperties {
            rootView.appProperties = props
        }
        #endif
    }
}
