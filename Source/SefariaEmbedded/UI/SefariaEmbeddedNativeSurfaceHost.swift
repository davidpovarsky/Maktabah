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

struct SefariaEmbeddedNativeSurfaceHost: UIViewControllerRepresentable {
    let moduleName: String
    let initialProperties: [String: Any]?

    init(moduleName: String = "ChavrusaSefariaRoot", initialProperties: [String: Any]? = nil) {
        self.moduleName = moduleName
        self.initialProperties = initialProperties
    }

    func makeUIViewController(context: Context) -> UIViewController {
        let vc = UIViewController()
        vc.view.backgroundColor = .clear

        #if canImport(UIKit)
        let surfaceView = SefariaExpoLifecycleAdapter.shared.createSurfaceView(
            moduleName: moduleName,
            initialProperties: initialProperties
        )
        surfaceView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        surfaceView.frame = vc.view.bounds
        vc.view.addSubview(surfaceView)
        #endif

        return vc
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}
