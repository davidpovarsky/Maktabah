import Foundation

// Standalone policy tests compile ITorahSharedContainer without the application target.
enum AppConfig {
    static var appSupportDir: URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
    }
}
