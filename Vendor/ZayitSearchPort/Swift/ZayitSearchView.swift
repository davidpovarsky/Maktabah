import SwiftUI
import UniformTypeIdentifiers

struct ZayitSearchView: View {
    @EnvironmentObject private var session: ZayitSearchSessionController
    @State private var picker = false

    let existingSeforimDB: (() -> URL?)?
    let openResult: (ZayitSearchHit) -> Void

    var body: some View {
        Group {
            switch session.state {
            case .restoring:
                ProgressView("Restoring search data…")
            case .notConfigured:
                setupUI
            case .ready:
                searchUI
            case .failed(let message):
                errorUI(message)
            }
        }
        .navigationTitle("Zayit Search")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Choose Different Folder") { picker = true }
                    Button("Forget Folder", role: .destructive) {
                        Task { await session.forget() }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .fileImporter(isPresented: $picker, allowedContentTypes: [.folder]) { result in
            switch result {
            case .success(let url):
                Task {
                    await session.chooseFolder(
                        url,
                        existingSeforimDB: existingSeforimDB?()
                    )
                }
            case .failure(let error):
                session.model.errorMessage = error.localizedDescription
            }
        }
        .alert(
            "Zayit Search",
            isPresented: Binding(
                get: { session.model.errorMessage != nil },
                set: { if !$0 { session.model.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(session.model.errorMessage ?? "")
        }
        .task {
            await session.restoreIfNeeded(
                existingSeforimDB: existingSeforimDB?()
            )
        }
    }

    private var setupUI: some View {
        ContentUnavailableView {
            Label("Choose search data folder", systemImage: "externaldrive")
        } description: {
            Text("The folder must contain lexical.db and zayit-search-index. It may also contain seforim.db.")
        } actions: {
            Button("Choose Folder") { picker = true }
                .buttonStyle(.borderedProminent)
        }
    }

    private var searchUI: some View {
        VStack {
            HStack {
                TextField(
                    "Search",
                    text: Binding(
                        get: { session.model.query },
                        set: { session.model.query = $0 }
                    )
                )
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { session.model.runSearch() }
                Button("Search") { session.model.runSearch() }
            }
            .padding()

            Picker(
                "Search Mode",
                selection: Binding(
                    get: { session.model.matchMode },
                    set: { session.model.matchMode = $0 }
                )
            ) {
                Text("Exact").tag(ZayitSearchMatchMode.exact)
                Text("Flexible").tag(ZayitSearchMatchMode.flexible)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            if session.model.isLoading { ProgressView() }

            List(session.model.hits) { hit in
                Button { openResult(hit) } label: {
                    VStack(alignment: .leading) {
                        Text(hit.bookTitle).font(.headline)
                        Text(hit.snippetHtml
                            .replacingOccurrences(of: "<b>", with: "")
                            .replacingOccurrences(of: "</b>", with: ""))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private func errorUI(_ message: String) -> some View {
        ContentUnavailableView {
            Label("Search data unavailable", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            Button("Choose Folder Again") { picker = true }
                .buttonStyle(.borderedProminent)
        }
    }
}
