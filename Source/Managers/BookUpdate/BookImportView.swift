//
//  OfflineImportFormView.swift
//  Maktabah
//

import SwiftUI
import UniformTypeIdentifiers

struct OfflineImportFormView: View {
    @State private var sqliteURL: URL?
    let onImport: (URL, BookMetadata, [String: Any]?) async -> Void
    @Environment(\.dismiss) var dismiss
    @Environment(\.openURL) var openURL

    @State private var isImporting: Bool = false
    @State private var isNewBook: Bool = true
    @State private var selectedBookId: Int? = nil
    @State private var bookName: String = ""
    @State private var categoryId: Int = 0
    @State private var archiveId: Int = 20
    @State private var betaka: String = ""
    @State private var inf: String = ""
    @State private var tafseerNam: String = ""
    @State private var bVerText: String = "1"

    @State private var isNewAuthor: Bool = false
    @State private var selectedAuthorId: Int? = nil
    @State private var authorName: String = ""
    @State private var authorInf: String = ""
    @State private var authorLng: String = ""
    @State private var authorHigriD: String = ""
    @State private var oVerText: String = "1"

    @State private var maxBkid: Int = 0
    @State private var maxAuthid: Int = 0

    @State private var categories: [CategoryData] = []
    @State private var authors: [(id: Int, muallif: Muallif)] = []
    @State private var books: [BooksData] = []

    @State private var showBookPicker = false
    @State private var showAuthorPicker = false
    @State private var showFilePicker = false
    @State private var showHelpPopover = false

    private let converterURL = URL(
        string: "https://maktabah-web-converter-dfbmqvd2wyzupyxlb38p5y.streamlit.app"
    )

    var body: some View {
        Form {
            // MARK: - Book Section

            Section("Book Information") {
                Picker("Book Type", selection: $isNewBook) {
                    Text("New Book").tag(true)
                    Text("Replace Existing Book").tag(false)
                }
                .pickerStyle(.segmented)

                if isNewBook {
                    LabeledContent("New Book ID") {
                        Text("\(maxBkid + 1)")
                            .foregroundColor(.secondary)
                    }
                } else {
                    LabeledContent("Select Book") {
                        Button(action: { showBookPicker = true }) {
                            HStack {
                                if let bookId = selectedBookId,
                                   let book = LibraryDataManager.shared.booksById[bookId]
                                {
                                    Text("\(book.book) (ID: \(bookId))")
                                        .foregroundColor(.primary)
                                } else {
                                    Text("Click to select...")
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 8)
                            .frame(minHeight: 24)
                            .background(Color.gray.opacity(0.1))
                        }
                        .environment(\.layoutDirection, .rightToLeft)
                        .buttonStyle(.plain)
                    }
                }

                LabeledContent("Book Name (bk)") {
                    TextField("", text: $bookName, prompt: Text("e.g., Sahih Bukhari"))
                }

                LabeledContent("Category (cat)") {
                    Picker("", selection: $categoryId) {
                        Text("Select Category...").tag(0)
                        ForEach(categories, id: \.id) { cat in
                            Text(cat.name).tag(cat.id)
                        }
                    }
                    .environment(\.layoutDirection, .rightToLeft)
                    .labelsHidden()
                }

                LabeledContent("Archive ID") {
                    Stepper("\(archiveId)", value: $archiveId, in: 1 ... 20)
                        .disabled(!isNewBook)
                }

                LabeledContent("Edition") {
                    TextField("", text: $betaka, prompt: Text("Optional"))
                }

                LabeledContent("Information (inf)") {
                    TextField("", text: $inf, prompt: Text("Optional"))
                }

                LabeledContent("Tafseer Name") {
                    TextField("", text: $tafseerNam, prompt: Text("Optional"))
                }

                LabeledContent("Version") {
                    TextField("", text: $bVerText, prompt: Text("1"))
                }
            }

            // MARK: - Author Section

            Section("Author Information") {
                Picker("Author Type", selection: $isNewAuthor) {
                    Text("Existing Author").tag(false)
                    Text("New Author").tag(true)
                }
                .pickerStyle(.segmented)

                if !isNewAuthor {
                    LabeledContent("Select Author") {
                        Button(action: { showAuthorPicker = true }) {
                            HStack {
                                if let authId = selectedAuthorId,
                                   let auth = authors.first(where: { $0.id == authId })
                                {
                                    Text("\(auth.muallif.nama) (ID: \(authId))")
                                        .foregroundColor(.primary)
                                } else {
                                    Text("Click to select...")
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 8)
                            .frame(minHeight: 24)
                            .background(Color.gray.opacity(0.1))
                        }
                        .environment(\.layoutDirection, .rightToLeft)
                        .buttonStyle(.plain)
                    }
                } else {
                    LabeledContent("New Author ID") {
                        Text("\(maxAuthid + 1)")
                            .foregroundColor(.secondary)
                    }

                    LabeledContent("Author Name") {
                        TextField("", text: $authorName, prompt: Text("e.g., Al-Bukhari"))
                    }

                    LabeledContent("Author Info") {
                        TextField("", text: $authorInf, prompt: Text("Optional"))
                    }

                    LabeledContent("Full Name (Lng)") {
                        TextField("", text: $authorLng, prompt: Text("Optional"))
                    }

                    LabeledContent("Death Year") {
                        TextField("", text: $authorHigriD, prompt: Text("e.g., 256 AH"))
                    }

                    LabeledContent("Version") {
                        TextField("", text: $oVerText, prompt: Text("1"))
                    }
                }
            }
        }
        .formStyle(.grouped)
        .safeAreaInset(edge: .top, spacing: 0) {
            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Offline Book Import")
                            .font(.title2)
                            .bold()
                        HStack {
                            Text("File: \(sqliteURL?.lastPathComponent ?? "None selected")")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Button("Select File") {
                                showFilePicker = true
                            }
                            .font(.caption)
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                    Spacer()
                    helpButton
                }
                .padding()
                Divider()
            }
            .background(.ultraThinMaterial)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 0) {
                Divider()
                actionButtons
                    .padding()
            }
            .background(.ultraThinMaterial)
        }
        .sheet(isPresented: $showBookPicker) {
            SearchSelectionView(
                title: "Select Book to Replace",
                items: books.map {
                    SearchSelectionItem(id: $0.id, title: $0.book, subtitle: "ID: \($0.id)")
                },
                onSelect: { item in
                    selectedBookId = item.id
                    if let book = books.first(where: { $0.id == item.id }) {
                        bookName = book.book
                        archiveId = book.archive
                        categoryId = book.catId ?? 0
                    }
                    showBookPicker = false
                }
            )
        }
        .sheet(isPresented: $showAuthorPicker) {
            SearchSelectionView(
                title: "Select Registered Author",
                items: authors.map {
                    SearchSelectionItem(id: $0.id, title: $0.muallif.nama, subtitle: "ID: \($0.id)")
                },
                onSelect: { item in
                    selectedAuthorId = item.id
                    showAuthorPicker = false
                }
            )
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.database, .data, .item],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let selectedURL = urls.first else { return }

                let shouldStopAccessing = selectedURL.startAccessingSecurityScopedResource()
                defer {
                    if shouldStopAccessing {
                        selectedURL.stopAccessingSecurityScopedResource()
                    }
                }

                do {
                    let tempURL = FileManager.default.temporaryDirectory
                        .appendingPathComponent(UUID().uuidString)
                        .appendingPathExtension(selectedURL.pathExtension)

                    if FileManager.default.fileExists(atPath: tempURL.path) {
                        try FileManager.default.removeItem(at: tempURL)
                    }

                    try FileManager.default.copyItem(at: selectedURL, to: tempURL)
                    sqliteURL = tempURL
                } catch {
                    print("Error copying file: \(error.localizedDescription)")
                }

            case .failure(let error):
                print("Error picking file: \(error.localizedDescription)")
            }
        }
        .textFieldStyle(.roundedBorder)
        .task(priority: .userInitiated) {
            await setupData()
        }
    }

    private var isValid: Bool {
        if sqliteURL == nil { return false }
        if !isNewBook && selectedBookId == nil { return false }
        if bookName.isEmpty { return false }
        if isNewAuthor {
            if authorName.isEmpty { return false }
        } else {
            if selectedAuthorId == nil { return false }
        }
        return true
    }

    private func setupData() async {
        maxBkid = DatabaseManager.shared.getMaxBookId()
        maxAuthid = DatabaseManager.shared.getMaxAuthId()

        categories = Array(LibraryDataManager.shared.categoryMap.values).sorted(by: {
            $0.id < $1.id
        })

        authors = DatabaseManager.shared.fetchAllAuthors().sorted(by: { $0.id < $1.id })

        books = Array(LibraryDataManager.shared.booksById.values).sorted(by: { $0.book < $1.book })
    }

    private var helpButton: some View {
        Button {
            showHelpPopover = true
        } label: {
            Image(systemName: "questionmark.circle.fill")
                .foregroundColor(.secondary)
                .font(.title3)
        }
        .buttonStyle(.plain)
        .help("Converter Tool & Help")
        .popover(isPresented: $showHelpPopover, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 12) {
                Text(.convertImportHelpTitle)
                    .font(.headline)

                Text(.convertImportHelpDesc)
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    if let converterURL {
                        openURL(converterURL)
                    }
                    showHelpPopover = false
                } label: {
                    Label("Open Web Converter", systemImage: "arrow.up.right.app")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .presentationCompactAdaptation(.popover)
            .padding()
            .frame(minWidth: 280, minHeight: 220)
        }
    }

    @ViewBuilder
    private var actionButtons: some View {
        #if os(macOS)
        HStack {
            closeButton
            Spacer()
            importButtonGroup
        }
        #else
        VStack(spacing: 12) {
            importButtonGroup
            closeButton
        }
        #endif
    }

    private var closeButton: some View {
        Button(role: .destructive) {
            dismiss()
        } label: {
            Text("Close")
            #if !os(macOS)
                .frame(maxWidth: .infinity)
            #endif
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .tint(.red)
        .disabled(isImporting)
        #if !os(macOS)
        .frame(maxWidth: .infinity)
        #endif
    }

    private var importButtonGroup: some View {
        HStack {
            if isImporting {
                ProgressView()
                    .controlSize(.small)
                    .padding(.trailing, 8)
            }

            Button {
                Task { await performImport() }
            } label: {
                Text("Import Now")
                    #if !os(macOS)
                    .frame(maxWidth: .infinity)
                    #endif
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!isValid || isImporting)
            #if !os(macOS)
            .frame(maxWidth: .infinity)
            #endif
        }
        #if !os(macOS)
        .frame(maxWidth: .infinity)
        #endif
    }

    private func performImport() async {
        guard let url = sqliteURL else { return }
        isImporting = true
        defer { isImporting = false }

        let finalBookId = isNewBook ? (maxBkid + 1) : (selectedBookId ?? 0)
        var finalAuthId: Int? = nil
        var authorRow: [String: Any]? = nil

        if isNewAuthor {
            finalAuthId = maxAuthid + 1
            authorRow = [
                "authid": finalAuthId!,
                "auth": authorName,
                "inf": authorInf,
                "Lng": authorLng,
                "HigriD": authorHigriD,
                "oVer": Int(oVerText) ?? 1,
            ]
        } else {
            finalAuthId = selectedAuthorId
        }

        let metadata = BookMetadata(
            bkid: finalBookId,
            cat: categoryId == 0 ? nil : categoryId,
            bk: bookName,
            archive: archiveId,
            betaka: betaka.isEmpty ? nil : betaka,
            authno: finalAuthId,
            inf: inf.isEmpty ? nil : inf,
            tafseerNam: tafseerNam.isEmpty ? nil : tafseerNam,
            bVer: Int(bVerText) ?? 1,
            link: nil
        )

        await onImport(url, metadata, authorRow)
    }
}

// MARK: - Search Selection Helper

struct SearchSelectionItem: Identifiable {
    let id: Int
    let title: String
    let subtitle: String
}

struct SearchSelectionView: View {
    let title: String
    let items: [SearchSelectionItem]
    let onSelect: (SearchSelectionItem) -> Void
    @Environment(\.dismiss) var dismiss

    @State private var searchText = ""

    var filteredItems: [SearchSelectionItem] {
        if searchText.isEmpty {
            return items
        }
        return items.filter {
            $0.title.localizedCaseInsensitiveContains(searchText)
                || $0.subtitle.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.plain)
                .foregroundColor(.accentColor)
            }
            .padding()

            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search...", text: $searchText)
                    .textFieldStyle(.plain)

                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(10)
            .background(Color.gray.opacity(0.1))
            .padding(.horizontal)
            .padding(.bottom, 12)

            Divider()

            List(filteredItems) { item in
                Button(action: { onSelect(item) }) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title)
                            .font(.body)
                            .fontWeight(.medium)
                        Text(item.subtitle)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .listStyle(.inset)
        }
        #if os(macOS)
        .frame(width: 400, height: 500)
        #endif
    }
}
