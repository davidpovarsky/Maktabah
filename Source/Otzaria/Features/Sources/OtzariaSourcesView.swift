import SwiftUI

struct OtzariaSourcesView: View {
    @ObservedObject var viewModel: OtzariaSourcesViewModel

    var body: some View {
        Group {
            if viewModel.isLoading {
                OtzariaLoadingStateView(title: "טוען מקורות")
            } else if let error = viewModel.errorMessage {
                OtzariaErrorStateView(title: "טעינת המקורות נכשלה", message: error)
            } else if viewModel.selectedLine == nil {
                ContentUnavailableView("בחר שורה", systemImage: "link", description: Text("לחיצה על שורה בטקסט תציג כאן מפרשים, מקורות ותרגומים."))
            } else if viewModel.sections.isEmpty {
                ContentUnavailableView("לא נמצאו קישורים", systemImage: "link.badge.plus")
            } else {
                sourcesList
            }
        }
        .navigationTitle("מקורות")
    }

    private var sourcesList: some View {
        List {
            if let line = viewModel.selectedLine {
                Section("השורה שנבחרה") {
                    Text(line.text)
                        .font(.callout)
                        .lineLimit(4)
                        .multilineTextAlignment(.trailing)
                        .textSelection(.enabled)
                }
            }

            ForEach(viewModel.sections) { section in
                Section(section.title) {
                    ForEach(section.items) { item in
                        OtzariaLinkedSourceRow(item: item)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

struct OtzariaLinkedSourceRow: View {
    let item: OtzariaLinkedSource

    var body: some View {
        VStack(alignment: .trailing, spacing: 6) {
            HStack {
                Image(systemName: item.systemImage)
                Text(item.bookTitle)
                    .font(.headline)
                Spacer()
                if let heRef = item.heRef, !heRef.isEmpty {
                    Text(heRef)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text(item.text)
                .font(.body)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .lineLimit(8)
                .textSelection(.enabled)
        }
        .padding(.vertical, 4)
    }
}
