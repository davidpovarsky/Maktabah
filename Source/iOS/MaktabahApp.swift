import SwiftUI

@main
struct MaktabahApp: App {
    static var isIpad: Bool {
        if UIDevice.current.userInterfaceIdiom == .pad {
            true
        } else {
            false
        }
    }

    var isDarkMode: Bool {
        TextViewState.shared
            .backgroundColorIndex > 1
    }

    init() {
        AppConfig.initializeMode()
        ArabicFont.registerCustomFonts()
        AppConfig.setupAnnotationsAndResults()
        // CoreDatabaseBootstrap.run()
    }

    var body: some Scene {
        WindowGroup {
            iOSBootstrapView()
                .preferredColorScheme(
                    Self.isIpad
                        ? isDarkMode
                            ? .dark
                            : .light
                    : nil
                )
        }
    }
}
