import SwiftUI

@main
struct MaktabahUIWorkbenchApp: App {
    var body: some Scene {
        WindowGroup {
            iOSMainView()
                .environment(\.layoutDirection, .rightToLeft)
        }
    }
}
