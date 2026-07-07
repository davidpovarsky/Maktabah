import SwiftUI

struct OtzariaReaderView: View {
    let book: OtzariaBook
    let onSelectLine: (OtzariaBookLine) -> Void

    @Binding var selectedLineID: Int?
    @StateObject private var viewModel: OtzariaReaderViewModel

    init(
        book: OtzariaBook,
        repository: any OtzariaBookTextRepository,
        selectedLineID: Binding<Int?>,
        onSelectLine: @escaping (OtzariaBookLine) -> Void
    ) {
        self.book = book
        self.onSelectLine = onSelectLine
        _selectedLineID = selectedLineID
        _viewModel = StateObject(wrappedValue: OtzariaReaderViewModel(book: book, repository: repository))
    }

    var body: some View {
        Group {
            if let error = viewModel.errorMessage, viewModel.lines.isEmpty {
                OtzariaErrorStateView(title: "טעינת הספר נכשלה", message: error)
            } else if viewModel.lines.isEmpty && viewModel.isLoading {
                OtzariaLoadingStateView(title: "טוען את \(book.title)")
            } else if viewModel.lines.isEmpty {
                ContentUnavailableView("אין שורות להצגה", systemImage: "text.book.closed")
            } else {
                readerList
            }
        }
        .navigationTitle(book.title)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            if !viewModel.tocEntries.isEmpty {
                ToolbarItem(placement: .primaryAction) {
                    Menu("תוכן", systemImage: "list.bullet") {
                        ForEach(viewModel.tocEntries.prefix(160)) { entry in
                            Button(entry.menuTitle) {
                                Task { await viewModel.jump(to: entry) }
                            }
                            .disabled(entry.lineIndex == nil)
                        }
                    }
                }
            }
        }
        .task {
            await viewModel.loadInitial()
        }
    }

    private var readerList: some View {
        List {
            Section {
                ForEach(viewModel.lines) { line in
                    OtzariaReaderLineRow(line: line, isSelected: selectedLineID == line.id)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedLineID = line.id
                            onSelectLine(line)
                        }
                        .task {
                            if line.id == viewModel.lines.last?.id {
                                await viewModel.loadNextPage()
                            }
                        }
                }

                if viewModel.isLoading {
                    ProgressView("טוען עוד")
                }
            } footer: {
                Text(book.subtitle)
            }
        }
        .listStyle(.plain)
    }
}

struct OtzariaReaderLineRow: View {
    let line: OtzariaBookLine
    let isSelected: Bool

    @AppStorage("otsaria.reader.fontSize") private var fontSize = 20.0
    @AppStorage("otsaria.reader.lineSpacing") private var lineSpacing = 6.0
    @AppStorage("otsaria.reader.showHebrewReference") private var showHebrewReference = true

    var body: some View {
        VStack(alignment: .trailing, spacing: 6) {
            if showHebrewReference, let heRef = line.heRef, !heRef.isEmpty {
                Text(heRef)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(line.text)
                .font(line.isHeading ? .headline : .system(size: fontSize))
                .lineSpacing(lineSpacing)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .textSelection(.enabled)
        }
        .padding(.vertical, 4)
        .listRowBackground(isSelected ? Color.accentColor.opacity(0.14) : Color.clear)
    }
}

struct OtzariaReaderPlaceholderView: View {
    var body: some View {
        ContentUnavailableView("בחר ספר", systemImage: "book", description: Text("בחר ספר מהספרייה כדי להתחיל לקרוא."))
    }
}
