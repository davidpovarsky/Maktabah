import SwiftUI

struct OtzariaLoadingStateView: View {
    let title: String

    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text(title)
                .font(.headline)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct OtzariaErrorStateView: View {
    let title: String
    let message: String

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
                .multilineTextAlignment(.center)
                .textSelection(.enabled)
        }
    }
}

struct OtzariaDatabaseRequiredView: View {
    let chooseDatabase: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("בחר seforim.db", systemImage: "externaldrive")
        } description: {
            Text("בחר את קובץ מסד הנתונים של אוצריא כדי לטעון את הספרייה.")
        } actions: {
            Button("בחר DB", systemImage: "folder", action: chooseDatabase)
                .buttonStyle(.borderedProminent)
        }
    }
}
