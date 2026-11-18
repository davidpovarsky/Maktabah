#if os(iOS)
import AppIntents
import ChavrusaUIRoutingHost

/// App-bundle metadata association. Existing WidgetKit intents are untouched.
struct MaktabahNativeIntents: AppIntentsPackage {
    static var includedPackages: [any AppIntentsPackage.Type] { [ChavrusaRoutingIntents.self] }
}

struct MaktabahNativeShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: OpenNativeDestinationIntent(),
                    phrases: ["Open \(\.$destination) in \(.applicationName)"],
                    shortTitle: "Open destination", systemImageName: "books.vertical")
        AppShortcut(intent: OpenBookAtLocationIntent(),
                    phrases: ["Open \(\.$book) in \(.applicationName)"],
                    shortTitle: "Open book", systemImageName: "book")
    }
}
#endif
