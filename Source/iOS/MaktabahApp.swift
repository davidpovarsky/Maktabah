import SwiftUI

@main
struct MaktabahApp: App {
    @Environment(\.scenePhase) private var scenePhase

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
                .applyIpadColorScheme(isIpad: Self.isIpad, isDarkMode: isDarkMode)
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active {
                iOSHistoryViewModel.shared.refreshFromCloud()
            }
            if newPhase == .background {
                iOSHistoryViewModel.shared.saveToUserDefaults()
            }
        }
    }
}

extension View {
    @ViewBuilder
    func applyIpadColorScheme(isIpad: Bool, isDarkMode: Bool) -> some View {
        if isIpad {
            self.preferredColorScheme(isDarkMode ? .dark : .light)
        } else {
            self // Tidak menerapkan modifier apa-apa jika bukan iPad
        }
    }
}
