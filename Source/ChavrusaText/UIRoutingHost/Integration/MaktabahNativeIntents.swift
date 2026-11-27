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
        AppShortcut(intent: OpenReaderTabIntent(),
                    phrases: ["Open reader tab \(\.$tab) in \(.applicationName)"],
                    shortTitle: "Open reader tab", systemImageName: "rectangle.on.rectangle")
        AppShortcut(intent: ShowSearchResultsIntent(),
                    phrases: ["Show search results in \(.applicationName)"],
                    shortTitle: "Search", systemImageName: "magnifyingglass")
        AppShortcut(intent: OpenStudyProfileIntent(),
                    phrases: ["Open study profile \(\.$selection) in \(.applicationName)"],
                    shortTitle: "Open study profile", systemImageName: "person.crop.circle")
        AppShortcut(intent: OpenStudyTabGroupIntent(),
                    phrases: ["Open tab group \(\.$selection) in \(.applicationName)"],
                    shortTitle: "Open tab group", systemImageName: "rectangle.3.group")
        AppShortcut(intent: ResumeHistoryReadingIntent(),
                    phrases: ["Resume reading \(\.$entry) in \(.applicationName)"],
                    shortTitle: "Resume reading", systemImageName: "clock.arrow.circlepath")
        AppShortcut(intent: RevealLoadedSearchResultIntent(),
                    phrases: ["Show search result \(\.$result) in \(.applicationName)"],
                    shortTitle: "Show search result", systemImageName: "text.magnifyingglass")
        AppShortcut(intent: LoadNextOriginalSearchPageIntent(),
                    phrases: ["Load next search page in \(.applicationName)"],
                    shortTitle: "Next search page", systemImageName: "arrow.down.doc")
        AppShortcut(intent: RevealSavedResultIntent(),
                    phrases: ["Show saved search result in \(.applicationName)"],
                    shortTitle: "Saved search result", systemImageName: "bookmark")
    }
}
#endif
