        AppShortcut(intent: RevealLoadedSearchResultIntent(),
                    phrases: ["Show \(\.$result) in \(.applicationName)"],
                    shortTitle: "Show search result", systemImageName: "text.magnifyingglass")
        AppShortcut(intent: LoadNextOriginalSearchPageIntent(),
                    phrases: ["Load the next search page in \(.applicationName)"],
                    shortTitle: "Next search page", systemImageName: "arrow.down.document")
