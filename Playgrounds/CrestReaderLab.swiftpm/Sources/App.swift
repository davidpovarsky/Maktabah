import SwiftUI
import CoreText

@main
struct CrestReaderLabApp: App {
    init() {
        registerOriginalFonts()
        // This Hebrew-only sample must not inherit an Arabic-specific font.
        TextViewState.shared.setFont("Arial Hebrew")
        TextViewState.shared.setLineHeight(1.24)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }

    private func registerOriginalFonts() {
        let files = [
            "Lateef-Regular.ttf",
            "Lateef-Bold.ttf",
            "ScheherazadeNew-Regular.ttf",
            "UthmanTN1-Ver10.otf"
        ]
        // Swift Playgrounds on iPad does not always generate Bundle.module.
        // Discover resource bundles dynamically, without relying on that symbol.
        let embeddedBundles = (try? FileManager.default.contentsOfDirectory(
            at: Bundle.main.bundleURL,
            includingPropertiesForKeys: nil
        ))?.compactMap { url -> Bundle? in
            guard url.pathExtension == "bundle" else { return nil }
            return Bundle(url: url)
        } ?? []
        let bundles = [Bundle.main] + embeddedBundles + Bundle.allBundles + Bundle.allFrameworks

        for name in files {
            let parts = name.split(separator: ".", maxSplits: 1)
            guard parts.count == 2 else { continue }
            let file = String(parts[0]), ext = String(parts[1])
            guard let url = bundles.lazy.compactMap({ bundle -> URL? in
                bundle.url(forResource: file, withExtension: ext, subdirectory: "Fonts")
                    ?? bundle.url(forResource: file, withExtension: ext)
            }).first else { continue }
            var error: Unmanaged<CFError>?
            _ = CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
            if let error { _ = error.takeRetainedValue() }
        }
    }
}
