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
        for name in files {
            let parts = name.split(separator: ".", maxSplits: 1)
            guard parts.count == 2 else { continue }
            let file = String(parts[0]), ext = String(parts[1])
            #if SWIFT_PACKAGE
            let packageURL = Bundle.module.url(forResource: file, withExtension: ext, subdirectory: "Fonts")
                ?? Bundle.module.url(forResource: file, withExtension: ext)
            #else
            let packageURL: URL? = nil
            #endif
            guard let url = packageURL
                ?? Bundle.main.url(forResource: file, withExtension: ext, subdirectory: "Fonts")
                ?? Bundle.main.url(forResource: file, withExtension: ext)
            else { continue }
            var error: Unmanaged<CFError>?
            _ = CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
            if let error { _ = error.takeRetainedValue() }
        }
    }
}
