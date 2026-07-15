import SwiftUI
import UniformTypeIdentifiers

struct ZayitSearchView: View {
    @StateObject private var access = ZayitSearchFolderAccess()
    @StateObject private var model = ZayitSearchViewModel(repository: ZayitSearchRepository())
    @State private var picker = false

    let existingSeforimDB: (() -> URL?)?
    let openResult: (ZayitSearchHit) -> Void

    var body: some View {
        NavigationStack {
            Group {
                if model.configured { searchUI } else { setupUI }
            }
            .navigationTitle("Zayit Search")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Choose Different Folder") { picker = true }
                        Button("Forget Folder", role: .destructive) {
                            access.clear()
                            model.reset()
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .fileImporter(isPresented: $picker, allowedContentTypes: [.folder]) { result in
                do {
                    let url = try result.get()
                    try access.save(url)
                    try configure()
                } catch {
                    model.errorMessage = error.localizedDescription
                }
            }
            .alert(
                "Zayit Search",
                isPresented: Binding(
                    get: { model.errorMessage != nil },
                    set: { if !$0 { model.errorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(model.errorMessage ?? "")
            }
        }
        .task {
            do {
                try access.restore()
                if access.folderURL != nil { try configure() }
            } catch {
                model.errorMessage = error.localizedDescription
            }
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
                TextField("Search", text: $model.query)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { model.runSearch() }
                Button("Search") { model.runSearch() }
            }
            .padding()

            HStack {
                Text("Near: \(model.near)")
                Slider(
                    value: Binding(
                        get: { Double(model.near) },
                        set: { model.near = UInt32($0) }
                    ),
                    in: 0...12,
                    step: 1
                )
            }
            .padding(.horizontal)

            if model.isLoading { ProgressView() }

            List(model.hits) { hit in
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

    private func configure() throws {
        let folder = try access.activate()
        let paths = try ZayitSearchDataValidator.paths(
            in: folder,
            existingSeforimDB: existingSeforimDB?()
        )
        model.configure(paths: paths)
    }
}
