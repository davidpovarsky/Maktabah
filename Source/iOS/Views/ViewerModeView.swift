import SwiftUI

struct ViewerModeView: View {
    @Environment(iOSNavigationManager.self) var navigationManager: iOSNavigationManager

    var body: some View {
        NavigationView {
            VStack {
                Text("Viewer Mode")
                    .font(.largeTitle)

                // Example of embedding the UIKit wrapper for the book list
                BookListWrapper()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationTitle("Viewer")
            .navigationBarItems(trailing: Button(action: {
                navigationManager.showViewOptions = true
            }) {
                Image(systemName: "slider.horizontal.3")
            })
        }
    }
}
