import CloudKit
import SwiftUI

#if canImport(Expo)
import Expo
typealias MaktabahAppDelegateBase = ExpoAppDelegate
#else
typealias MaktabahAppDelegateBase = NSObject
#endif

@main
struct MaktabahApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    static weak var sharedAppDelegate: AppDelegate?

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

    @AppStorage("useDefaultTheme") private var useDefaultTheme: Bool = false
    @StateObject private var otzariaApp = OtzariaAppContainer()
    @StateObject private var otzariaNavigation = OtzariaIntegratedNavigationState()
    @StateObject private var zayitSearchSession = ZayitSearchSessionController()

    init() {
        BackendComposition.registerAll()
        // Native acceptance launches exercise isolated Otzaria bootstrap/search
        // paths and must not be blocked by unrelated first-launch setup.
        if OtzariaNativeBootstrapAcceptanceRunner.isRequested
            || OtzariaCorpusAcceptanceRunner.isRequested
            || SharedTorahDataDiagnosticRunner.isRequested {
            return
        }

        AppConfig.initializeMode()
        ArabicFont.registerCustomFonts()
        UserFontManager.shared.registerUserFonts()
        let cloudKitRestorationKey = "cloudKitCapabilityRestored.v1"
        UserDefaults.standard.register(defaults: [AppConfig.useICloudKey: true])
        if !UserDefaults.standard.bool(forKey: cloudKitRestorationKey) {
            // Previous sideload builds force-wrote this preference to false on every launch,
            // so there is no intentional user choice to preserve from those builds.
            UserDefaults.standard.set(true, forKey: AppConfig.useICloudKey)
            UserDefaults.standard.set(true, forKey: cloudKitRestorationKey)
        }
        AppConfig.setupAnnotationsAndResults()
        CloudKitSyncManager.shared.initializeOnLaunch()
        _ = WidgetUpdateCoordinator.shared
        // CoreDatabaseBootstrap.run()
        setupGlobalAppearances()
    }

    private func setupGlobalAppearances() {
        // -- Navigation Bar --
        if #unavailable(iOS 26) {
            let appearance = UINavigationBarAppearance()
            appearance.configureWithDefaultBackground()
            if !useDefaultTheme {
                appearance.backgroundColor = .appSecondaryBackground
            }

            UINavigationBar.appearance().standardAppearance = appearance
            UINavigationBar.appearance().compactAppearance = appearance
        }
        UINavigationBar.appearance().tintColor = useDefaultTheme ? nil : UIColor.iosTint

        // -- Tab Bar --
        let barAppearance = UITabBarAppearance()
        barAppearance.configureWithDefaultBackground()
        if !useDefaultTheme {
            barAppearance.backgroundColor = .appSecondaryBackground
        }
        UITabBar.appearance().standardAppearance = barAppearance
    }

    var body: some Scene {
        WindowGroup {
            if SharedTorahDataDiagnosticRunner.isRequested {
                Color.clear
                    .task {
                        await SharedTorahDataDiagnosticRunner.runIfRequested()
                    }
            } else if OtzariaNativeBootstrapAcceptanceRunner.isRequested {
                Color.clear
                    .task {
                        await OtzariaNativeBootstrapAcceptanceRunner.runIfRequested()
                    }
            } else if OtzariaCorpusAcceptanceRunner.isRequested {
                Color.clear
                    .task {
                        await OtzariaCorpusAcceptanceRunner.runIfRequested()
                    }
            } else {
                iOSBootstrapView()
                    .environmentObject(otzariaApp)
                    .environmentObject(otzariaNavigation)
                    .environmentObject(zayitSearchSession)
                    .applyIpadColorScheme(isIpad: Self.isIpad, isDarkMode: isDarkMode)
                    .id(useDefaultTheme)
                    .toggleStyle(SwitchToggleStyle(tint: .green))
                    .onChange(of: scenePhase) { _, newPhase in
                        switch newPhase {
                        case .active:
                            HistoryViewModel.shared.reloadFromDatabase()
                            CloudKitSyncManager.shared.fetchChanges()
                        case .background, .inactive:
                            WidgetUpdateCoordinator.shared.flushPendingUpdatesTask(
                                forceCloudKit: true
                            )
                            if newPhase == .background {
                                OtzariaTantivySearchRepository.shared.closeAllEngines()
                            }
                        @unknown default:
                            break
                        }
                    }
                    .onChange(of: useDefaultTheme) { _, _ in
                        setupGlobalAppearances()
                        // Force navigation bars and tab bars in all windows to redraw their appearances
                        for scene in UIApplication.shared.connectedScenes {
                            if let windowScene = scene as? UIWindowScene {
                                for window in windowScene.windows {
                                    for view in window.subviews {
                                        view.removeFromSuperview()
                                        window.addSubview(view)
                                    }
                                }
                            }
                        }
                    }
            }
        }
    }
}

#if canImport(Expo)
@MainActor
class AppDelegate: MaktabahAppDelegateBase {
    override init() {
        super.init()
        MaktabahApp.sharedAppDelegate = self
    }

    // MARK: - Expo & React Native Host Delegation & Clean Integration

    @objc var window: UIWindow? {
        get {
            #if canImport(UIKit)
            return SefariaExpoLifecycleAdapter.shared.hostedWindow
            #else
            nil
            #endif
        }
        set {
            #if canImport(UIKit)
            SefariaExpoLifecycleAdapter.shared.hostedWindow = newValue
            #endif
        }
    }

    /// Explicitly exposed property to satisfy Expo's `value(forKey: "_expoAppDelegate")`
    /// fallback without triggering unhandled KVC undefined key exceptions.
    @objc var _expoAppDelegate: Any? {
        return self
    }

    @objc var reactNativeFactory: Any? {
        get {
            #if canImport(UIKit)
            return self.factory ?? SefariaExpoLifecycleAdapter.shared.reactNativeFactory
            #else
            nil
            #endif
        }
        set {
            #if canImport(UIKit)
            if let f = newValue as? RCTReactNativeFactory {
                self.factory = f
            }
            #endif
        }
    }

    @objc var reactNativeDelegate: Any? {
        get {
            #if canImport(UIKit)
            return SefariaExpoLifecycleAdapter.shared.reactNativeDelegate
            #else
            nil
            #endif
        }
        set {}
    }

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        _ = super.application(application, didFinishLaunchingWithOptions: launchOptions)
        SefariaExpoLifecycleAdapter.shared.application(application, didFinishLaunchingWithOptions: launchOptions)
        if AppConfig.useICloud, CloudKitCoreManager.shared.isAvailable {
            application.registerForRemoteNotifications()
        }
        return true
    }

    override func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        let superHandled = super.application(app, open: url, options: options)
        let adapterHandled = SefariaExpoLifecycleAdapter.shared.application(app, open: url, options: options)
        return superHandled || adapterHandled
    }

    override func application(
        _ application: UIApplication,
        continue userActivity: NSUserActivity,
        restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
    ) -> Bool {
        let superHandled = super.application(application, continue: userActivity, restorationHandler: restorationHandler)
        let adapterHandled = SefariaExpoLifecycleAdapter.shared.application(application, continue: userActivity, restorationHandler: restorationHandler)
        return superHandled || adapterHandled
    }

    override func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        guard AppConfig.useICloud, CloudKitCoreManager.shared.isAvailable else {
            super.application(application, didReceiveRemoteNotification: userInfo, fetchCompletionHandler: completionHandler)
            return
        }
        CloudKitSyncManager.shared.fetchChanges()
        Task {
            let updated = await WidgetUpdateCoordinator.shared.handleSilentPush()
            completionHandler(updated ? .newData : .noData)
        }
    }

    override func applicationDidEnterBackground(_ application: UIApplication) {
        super.applicationDidEnterBackground(application)
        OtzariaTantivySearchRepository.shared.closeAllEngines()
    }

    override func applicationWillTerminate(_ application: UIApplication) {
        super.applicationWillTerminate(application)
        OtzariaTantivySearchRepository.shared.closeAllEngines()
        WidgetUpdateCoordinator.shared.flushPendingUpdatesTask(forceCloudKit: true)
        CloudKitCoreManager.shared.syncWorker()
    }
}
#else
@MainActor
class AppDelegate: NSObject, UIApplicationDelegate {
    override init() {
        super.init()
        MaktabahApp.sharedAppDelegate = self
    }

    @objc var window: UIWindow? {
        get { nil }
        set {}
    }

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        return true
    }
}
#endif

extension View {
    @ViewBuilder
    func applyIpadColorScheme(isIpad: Bool, isDarkMode: Bool) -> some View {
        if isIpad {
            preferredColorScheme(isDarkMode ? .dark : .light)
        } else {
            self // Tidak menerapkan modifier apa-apa jika bukan iPad
        }
    }

    /// Menerapkan warna latar belakang tema utama aplikasi
    func themeBackground() -> some View {
        background(Color.appBackground)
    }

    /// Menerapkan warna latar belakang tema untuk baris di List
    func themeListRowBackground() -> some View {
        listRowBackground(Color.appCellBackground)
    }

    /// Helper untuk List: menyembunyikan background bawaan List dan menerapkan tema
    func themeListBackground() -> some View {
        listRowBackground(Color.appBackground)
    }
}

// MARK: - Color Theme Extensions

extension UIColor {
    static let appBackground = UIColor { traitCollection in
        if UserDefaults.standard.bool(forKey: "useDefaultTheme") {
            return .systemGroupedBackground
        }
        switch traitCollection.userInterfaceStyle {
        case .dark:
            return UIColor.bgSepiaDark.adjustBrightness(to: 0.60)
        default:
            return UIColor(red: 237 / 255, green: 217 / 255, blue: 184 / 255, alpha: 1.0)
        }
    }

    static let appCellBackground = UIColor { traitCollection in
        if UserDefaults.standard.bool(forKey: "useDefaultTheme") {
            return .secondarySystemGroupedBackground
        }
        switch traitCollection.userInterfaceStyle {
        case .dark:
            return UIColor.bgSepiaDark.adjustBrightness(to: 0.80)
        default:
            return UIColor.bgSepia
        }
    }

    static let appSecondaryBackground = UIColor { traitCollection in
        if UserDefaults.standard.bool(forKey: "useDefaultTheme") {
            return .secondarySystemBackground
        }
        switch traitCollection.userInterfaceStyle {
        case .dark:
            return UIColor.bgSepiaDark.adjustBrightness(to: 0.85)
        default:
            // Mid-tone light sepia for toolbars / headers
            return UIColor(red: 229 / 255, green: 217 / 255, blue: 194 / 255, alpha: 1.0)
        }
    }

    /// Menyesuaikan brightness warna dengan rasio (0.0 - 1.0)
    func adjustBrightness(to ratio: CGFloat) -> UIColor {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        if getHue(&h, saturation: &s, brightness: &b, alpha: &a) {
            return UIColor(hue: h, saturation: s, brightness: b * ratio, alpha: a)
        }
        var white: CGFloat = 0
        if getWhite(&white, alpha: &a) {
            return UIColor(white: white * ratio, alpha: a)
        }
        return self
    }
}

extension Color {
    static let appBackground = Color(uiColor: .appBackground)
    static let appCellBackground = Color(uiColor: .appCellBackground)
    static let appSecondaryBackground = Color(uiColor: .appSecondaryBackground)
}
