import SwiftUI

// MARK: - MoveTarget

/// Target item yang akan dipindahkan (folder atau result).
enum MoveTarget: Identifiable {
    case folder(FolderNode)
    case result(ResultNode)

    var id: ObjectIdentifier {
        switch self {
        case let .folder(node): ObjectIdentifier(node)
        case let .result(node): ObjectIdentifier(node)
        }
    }
}

// MARK: - Main View

struct iOSSavedResultsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(iOSNavigationManager.self) var navigationManager
    @Environment(\.maktabahNativeRoutingSession) private var nativeRoutingSession

    let viewModel: ResultsViewModel = .shared

    @State private var isLoading = true
    @State private var searchText = ""
    @State private var nativeNavigationPath: [FolderNode] = []
    @State private var nativeSheetOwner = UUID()

    // Aksi item (shared across navigation stack)
    @State private var itemToMove: MoveTarget?
    @State private var folderToDelete: FolderNode?
    @State private var itemToRename: RenameTarget?

    var body: some View {
        NavigationStack(path: nativeStateBinding($nativeNavigationPath, field: .path)) {
            Group {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .themeBackground()
                } else if viewModel.folderRoots.isEmpty,
                          (viewModel.folderResults[nil] ?? []).isEmpty
                {
                    ContentUnavailableView(
                        "No Saved Results",
                        systemImage: "bookmark.slash",
                        description: Text("Save search results to access them later.")
                    )
                    .background {
                        if let binding = nativeRoutingSession?.savedResultsBinding {
                            MaktabahNativeSavedResultsPageWitness(binding: binding, owner: nativeSheetOwner,
                                folder: nil, reveal: { _ in })
                                .allowsHitTesting(false).accessibilityHidden(true)
                        }
                    }
                } else if !searchText.isEmpty {
                    // Global Flattened Search
                    flattenedSearchList
                } else {
                    makeFolderContentList(folder: nil)
                }
            }
            .navigationTitle("Saved Results".localized)
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: nativeStateBinding($searchText, field: .filter), prompt: "Search globally")
            .navigationDestination(for: FolderNode.self) { folder in
                makeFolderContentList(folder: folder)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .background {
            if let binding = nativeRoutingSession?.savedResultsBinding {
                MaktabahNativeSavedResultsSheetWitness(binding: binding, access: nativeSheetAccess)
                    .allowsHitTesting(false).accessibilityHidden(true)
            }
        }
        .modifier(MaktabahNativeRoutingSurface(kind: .savedResults))
        // Sheet & Alerts
        .sheet(item: nativeStateBinding($itemToMove, field: .operation)) { target in
            iOSMoveItemView(target: target)
        }
        .alert(
            "Delete Folder",
            isPresented: Binding(
                get: { folderToDelete != nil },
                set: { if !$0 { nativeStateBinding($folderToDelete, field: .operation).wrappedValue = nil } }
            ),
            presenting: folderToDelete
        ) { folder in
            Button("Delete", role: .destructive) {
                viewModel.deleteFolder(node: folder)
            }
            Button("Cancel", role: .cancel) {}
        } message: { folder in
            Text("\"\(folder.name)\" and all its contents will be permanently deleted.")
        }
        .alert(
            itemToRename?.alertTitle ?? "",
            isPresented: Binding(
                get: { itemToRename != nil },
                set: { if !$0 { nativeStateBinding($itemToRename, field: .operation).wrappedValue = nil } }
            )
        ) {
            TextField("Name", text: Binding(
                get: { itemToRename?.draftName ?? "" },
                set: { nativeStateBinding($itemToRename, field: .operation).wrappedValue?.draftName = $0 }
            ))
            Button("Save") {
                if let target = itemToRename {
                    commitRename(target)
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .task {
            await viewModel.getFolders()
            await viewModel.dbLoadAllResults()
            nativeStateBinding($isLoading, field: .loading).wrappedValue = false
        }
    }

    /// Capture the actual original State storage, never a copied View value.
    /// These hooks observe changes; ordinary UI setters always execute once.
    @MainActor private func nativeStateBinding<Value>(_ original: Binding<Value>,
        field: MaktabahNativeSavedResultsBinding.StateField) -> Binding<Value> {
        let binding = nativeRoutingSession?.savedResultsBinding, owner = nativeSheetOwner
        return Binding(get: { original.wrappedValue }, set: { [weak binding] value in
            binding?.sheetStateWillPublish(owner: owner, field: field,
                nextPath: value as? [FolderNode], nextLoading: value as? Bool)
            original.wrappedValue = value
            binding?.sheetStateDidPublish(owner: owner, field: field)
        })
    }
    @MainActor private var nativeSheetAccess: MaktabahNativeSavedResultsBinding.SheetAccess {
        let path = $nativeNavigationPath, query = $searchText, loading = $isLoading
        let move = $itemToMove, deleting = $folderToDelete, rename = $itemToRename
        let originalPath = nativeStateBinding(path, field: .path)
        return .init(token: nativeSheetOwner, model: viewModel,
            path: { path.wrappedValue }, setPath: { originalPath.wrappedValue = $0 },
            filter: { query.wrappedValue }, loading: { loading.wrappedValue },
            blocked: { move.wrappedValue != nil || deleting.wrappedValue != nil || rename.wrappedValue != nil })
    }

    // MARK: - Global Flattened Search

    private var flattenedSearchList: some View {
        ScrollViewReader { proxy in
        ThemeList {
            let matchingFolders = viewModel.allFolders.filter { $0.name.localizedStandardContains(searchText) }
            if !matchingFolders.isEmpty {
                Section("Folders") {
                    ForEach(matchingFolders) { folder in
                        NavigationLink(value: folder) {
                            HStack {
                                Image(systemName: "folder")
                                    .accessibilityHidden(true)
                                Text(folder.name)
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) { nativeStateBinding($folderToDelete, field: .operation).wrappedValue = folder } label: { Label("Delete", systemImage: "trash") }
                        }
                        .swipeActions(edge: .leading) {
                            Button { nativeStateBinding($itemToMove, field: .operation).wrappedValue = .folder(folder) } label: { Label("Move", systemImage: "folder") }.tint(.blue)
                            Button { nativeStateBinding($itemToRename, field: .operation).wrappedValue = .folder(folder) } label: { Label("Rename", systemImage: "pencil") }.tint(.orange)
                        }
                    }
                }
            }

            let matchingResults = viewModel.allResults.filter {
                $0.name.localizedStandardContains(searchText) ||
                    ($0.items.first?.query ?? "").localizedStandardContains(searchText)
            }

            if !matchingResults.isEmpty {
                Section("Results") {
                    ForEach(matchingResults) { result in
                        ResultRow(result: result, action: { loadResult(result) })
                            .id(MaktabahNativeSavedResultsBinding.ScrollKey.result(result))
                            .background {
                                if let binding = nativeRoutingSession?.savedResultsBinding {
                                    MaktabahNativeSavedResultsRowWitness(binding: binding, owner: nativeSheetOwner,
                                        folder: nil, node: .result(result))
                                        .allowsHitTesting(false).accessibilityHidden(true)
                                }
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) { viewModel.deleteResult(result.parentId, name: result.name) } label: { Label("Delete", systemImage: "trash") }
                            }
                            .swipeActions(edge: .leading) {
                                Button { nativeStateBinding($itemToMove, field: .operation).wrappedValue = .result(result) } label: { Label("Move", systemImage: "folder") }.tint(.blue)
                                Button { nativeStateBinding($itemToRename, field: .operation).wrappedValue = .result(result) } label: { Label("Rename", systemImage: "pencil") }.tint(.orange)
                            }
                    }
                }
            }

            if matchingFolders.isEmpty, matchingResults.isEmpty {
                ContentUnavailableView.search(text: searchText)
            }
        }
        .background {
            if let binding = nativeRoutingSession?.savedResultsBinding {
                MaktabahNativeSavedResultsPageWitness(binding: binding, owner: nativeSheetOwner, folder: nil,
                    reveal: { proxy.scrollTo($0, anchor: .center) })
                    .allowsHitTesting(false).accessibilityHidden(true)
            }
        }
        }
    }

    private func makeFolderContentList(folder: FolderNode?) -> some View {
        iOSFolderContentList(
            folder: folder,
            onSelectResult: loadResult,
            onDeleteFolder: { nativeStateBinding($folderToDelete, field: .operation).wrappedValue = $0 },
            onMoveFolder: { nativeStateBinding($itemToMove, field: .operation).wrappedValue = .folder($0) },
            onRenameFolder: { nativeStateBinding($itemToRename, field: .operation).wrappedValue = .folder($0) },
            onDeleteResult: { viewModel.deleteResult($0.parentId, name: $0.name) },
            onMoveResult: { nativeStateBinding($itemToMove, field: .operation).wrappedValue = .result($0) },
            onRenameResult: { nativeStateBinding($itemToRename, field: .operation).wrappedValue = .result($0) },
            onNewFolder: { parent in nativeStateBinding($itemToRename, field: .operation).wrappedValue = .newFolder(parent: parent) },
            nativeBinding: nativeRoutingSession?.savedResultsBinding, nativeOwner: nativeSheetOwner
        )
    }

    // MARK: - Rename

    private func commitRename(_ target: RenameTarget) {
        let newName = target.draftName.trimmingCharacters(in: .whitespaces)
        guard !newName.isEmpty else { return }

        do {
            switch target.kind {
            case let .folder(node):
                guard node.name != newName else { return }
                try viewModel.updateFolderName(id: node.id, newName: newName)
            case let .result(node):
                guard node.name != newName else { return }
                try viewModel.updateResultQueryName(id: node.id, newName: newName)
            case let .newFolder(parent):
                if let parent {
                    try viewModel.addSubFolder(parentNode: parent, name: newName)
                } else {
                    try viewModel.addRootFolder(name: newName)
                }
            }
        } catch {
            // Errors are silent in SwiftUI; could show another alert if needed
        }
    }

    // MARK: - Load result

    private func loadResult(_ resultNode: ResultNode) {
        dismiss()
        navigationManager.searchViewModel.loadSavedResults(resultNode.items)
    }
}

// MARK: - iOSFolderContentList

struct iOSFolderContentList: View {
    let folder: FolderNode? // nil = root
    let onSelectResult: (ResultNode) -> Void
    let onDeleteFolder: (FolderNode) -> Void
    let onMoveFolder: (FolderNode) -> Void
    let onRenameFolder: (FolderNode) -> Void
    let onDeleteResult: (ResultNode) -> Void
    let onMoveResult: (ResultNode) -> Void
    let onRenameResult: (ResultNode) -> Void
    let onNewFolder: (FolderNode?) -> Void
    var nativeBinding: MaktabahNativeSavedResultsBinding? = nil
    var nativeOwner: UUID? = nil

    let viewModel: ResultsViewModel = .shared

    private var currentFolder: FolderNode? {
        guard let folder else { return nil }
        return viewModel.folderById[folder.id] ?? folder
    }

    private var children: [FolderNode] {
        if let currentFolder {
            currentFolder.children
        } else {
            viewModel.folderRoots
        }
    }

    private var results: [ResultNode] {
        viewModel.folderResults[folder?.id] ?? []
    }

    var body: some View {
        ScrollViewReader { proxy in
        ThemeList {
            ForEach(children) { child in
                NavigationLink(value: child) {
                    HStack {
                        Image(systemName: "folder")
                            .accessibilityHidden(true)
                        Text(child.name)
                    }
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) { onDeleteFolder(child) } label: { Label("Delete", systemImage: "trash") }
                }
                .swipeActions(edge: .leading) {
                    Button { onMoveFolder(child) } label: { Label("Move", systemImage: "folder") }.tint(.blue)
                    Button { onRenameFolder(child) } label: { Label("Rename", systemImage: "pencil") }.tint(.orange)
                }
            }

            ForEach(results) { result in
                ResultRow(result: result, action: { onSelectResult(result) })
                    .id(MaktabahNativeSavedResultsBinding.ScrollKey.result(result))
                    .background {
                        if let binding = nativeBinding, let owner = nativeOwner {
                            MaktabahNativeSavedResultsRowWitness(binding: binding, owner: owner,
                                folder: folder, node: .result(result))
                                .allowsHitTesting(false).accessibilityHidden(true)
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) { onDeleteResult(result) } label: { Label("Delete", systemImage: "trash") }
                    }
                    .swipeActions(edge: .leading) {
                        Button { onMoveResult(result) } label: { Label("Move", systemImage: "folder") }.tint(.blue)
                        Button { onRenameResult(result) } label: { Label("Rename", systemImage: "pencil") }.tint(.orange)
                    }
            }
        }
        .background {
            if let binding = nativeBinding, let owner = nativeOwner {
                MaktabahNativeSavedResultsPageWitness(binding: binding, owner: owner, folder: folder,
                    reveal: { proxy.scrollTo($0, anchor: .center) })
                    .allowsHitTesting(false).accessibilityHidden(true)
            }
        }
        .refreshable {
            CloudKitSyncManager.shared.fetchChanges()
            try? await Task.sleep(nanoseconds: 1_000_000_000)
        }
        .listStyle(.plain)
        .navigationTitle(folder?.name ?? "Saved Results".localized)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    onNewFolder(currentFolder)
                } label: {
                    Label("New Folder", systemImage: "folder.badge.plus")
                }
            }
        }
        }
    }
}

// MARK: - RenameTarget

struct RenameTarget: Identifiable {
    enum Kind {
        case folder(FolderNode)
        case result(ResultNode)
        case newFolder(parent: FolderNode?)
    }

    let id = UUID()
    let kind: Kind
    var draftName: String

    static func folder(_ node: FolderNode) -> RenameTarget {
        RenameTarget(kind: .folder(node), draftName: node.name)
    }

    static func result(_ node: ResultNode) -> RenameTarget {
        RenameTarget(kind: .result(node), draftName: node.name)
    }

    static func newFolder(parent: FolderNode? = nil) -> RenameTarget {
        RenameTarget(kind: .newFolder(parent: parent), draftName: "")
    }

    var alertTitle: String {
        switch kind {
        case .folder: String(localized: "Rename Folder")
        case .result: String(localized: "Rename Result")
        case .newFolder: String(localized: "New Folder")
        }
    }
}

// MARK: - ResultRow

struct ResultRow: View {
    let result: ResultNode
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                let mode = SearchMode(rawValue: result.searchMode) ?? .phrase
                Image(systemName: SearchMode.imageNameForMode(mode))
                    .accessibilityHidden(true)
                VStack(alignment: .leading) {
                    Text(result.name)
                        .foregroundStyle(.primary)
                    if let query = result.items.first?.query, !query.isEmpty {
                        Text(query)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}
