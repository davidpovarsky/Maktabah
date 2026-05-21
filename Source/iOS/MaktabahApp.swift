import SwiftUI
import CloudKit

@main
struct MaktabahApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    static var isIpad: Bool {
        if UIDevice.current.userInterfaceIdiom == .pad {
            true
        } else {
            false
        }
    }

    var isDarkMode: Bool {
        TextViewState.shared.isDarkMode
    }

    @AppStorage("lastVersionPrompted") var lastVersionPrompted = ""
    @State private var showWelcomeScreen = false

    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    init() {
        AppConfig.initializeMode()
        ArabicFont.registerCustomFonts()
        AppConfig.setupAnnotationsAndResults()
        CloudKitSyncManager.shared.initializeOnLaunch()
        // CoreDatabaseBootstrap.run()
    }

    var body: some Scene {
        WindowGroup {
            iOSBootstrapView()
                .applyIpadColorScheme(isIpad: Self.isIpad, isDarkMode: isDarkMode)
                .onAppear {
                    if lastVersionPrompted != currentVersion {
                        showWelcomeScreen = true
                    }
                }
                .sheet(isPresented: $showWelcomeScreen) {
                    WelcomeScreenView(onDismiss: {
                        lastVersionPrompted = currentVersion
                        showWelcomeScreen = false
                    })
                    .interactiveDismissDisabled()
                }
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    func applicationDidFinishLaunching(_ application: UIApplication) {
        application.registerForRemoteNotifications()
    }
    func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        CloudKitSyncManager.shared.fetchChanges()
        completionHandler(.newData)
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
