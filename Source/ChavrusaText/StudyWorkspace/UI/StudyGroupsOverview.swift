import SwiftUI

struct StudyGroupsOverview: View {
    @Bindable var workspace: StudyWorkspaceNavigationAdapter
    let manager: iOSNavigationManager
    let onOpenLibrary: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var showsNamePrompt = false
    @State private var name = ""
    @State private var copiesCurrent = false
    @State private var renamesCurrent = false
    @State private var confirmsDelete = false

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 190), spacing: 16)], spacing: 16) {
                    ForEach(workspace.group?.tabs ?? []) { document in
                        documentCard(document)
                    }
                }
                .padding()
            }
            .overlay {
                if workspace.group?.tabs.isEmpty != false {
                    ContentUnavailableView {
                        Label("אין כרטיסיות בקבוצה", systemImage: "book.closed")
                    } actions: {
                        Button("פתח ספר מהספרייה") { dismiss(); onOpenLibrary() }
                    }
                }
            }
            .navigationTitle("כל הכרטיסיות")
            .safeAreaInset(edge: .top) {
                ScrollableGroupsHost(groups: workspace.groups, selectedID: workspace.selection?.groupID) { id in
                    Task {
                        do { try await workspace.switchGroup(to: id, manager: manager) }
                        catch { workspace.errorMessage = error.localizedDescription }
                    }
                }
                .frame(maxWidth: 640)
                .frame(height: 49)
                .frame(maxWidth: .infinity)
                .padding(.horizontal)
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("סיום") { dismiss() } }
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button("קבוצה ריקה", systemImage: "plus") { prompt(copy: false) }
                        Button("קבוצה מהכרטיסיות הנוכחיות", systemImage: "square.on.square") { prompt(copy: true) }
                        Button("שינוי שם הקבוצה", systemImage: "pencil") {
                            renamesCurrent = true; name = workspace.group?.name ?? ""; showsNamePrompt = true
                        }
                        Button("מחיקת קבוצה", systemImage: "trash", role: .destructive) { confirmsDelete = true }
                    } label: { Label("קבוצות כרטיסיות", systemImage: "ellipsis.circle") }
                }
            }
            .alert("שם קבוצת הכרטיסיות", isPresented: $showsNamePrompt) {
                TextField("שם", text: $name)
                Button("שמירה") {
                    let value = name.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !value.isEmpty else { return }
                    if renamesCurrent, let id = workspace.group?.id {
                        do { try workspace.store.renameGroup(id, name: value) }
                        catch { workspace.errorMessage = error.localizedDescription }
                    } else { Task { await workspace.createGroup(name: value, fromCurrent: copiesCurrent, manager: manager) } }
                }
                Button("ביטול", role: .cancel) {}
            }
            .confirmationDialog("למחוק את הקבוצה והכרטיסיות שלה?", isPresented: $confirmsDelete, titleVisibility: .visible) {
                Button("מחיקת קבוצה", role: .destructive) {
                    guard let old = workspace.group?.id, let replacement = workspace.groups.first(where: { $0.id != old }) else {
                        workspace.errorMessage = StudyWorkspaceError.lastGroup.localizedDescription; return
                    }
                    Task {
                        do {
                            try await workspace.switchGroup(to: replacement.id, manager: manager)
                            try workspace.store.deleteGroup(old)
                        } catch { workspace.errorMessage = error.localizedDescription }
                    }
                }
            }
        }
        .onAppear { workspace.synchronize(manager) }
        .accessibilityIdentifier("study-groups-overview")
    }

    private func prompt(copy: Bool) { renamesCurrent = false; copiesCurrent = copy; name = ""; showsNamePrompt = true }

    private func documentCard(_ document: ReaderDocumentTab) -> some View {
        VStack(spacing: 8) {
            Button {
                Task {
                    do {
                        guard let group = workspace.group else { return }
                        try await workspace.switchGroup(to: group.id, documentID: document.id, manager: manager)
                        dismiss()
                    } catch { workspace.errorMessage = error.localizedDescription }
                }
            } label: {
                VStack(spacing: 12) {
                    Image(systemName: "book.closed").font(.largeTitle).foregroundStyle(.secondary)
                    Text(document.session.bookTitle ?? "ספר").font(.headline).lineLimit(2)
                    Text(document.backend.displayName).font(.caption).foregroundStyle(.secondary)
                    Text("תצוגה מקדימה אינה זמינה").font(.caption2).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 150)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            HStack {
                Menu {
                    ForEach((workspace.store.snapshot?.groups ?? []).filter { $0.id != workspace.group?.id }) { target in
                        Button("העבר אל \(target.name)") { workspace.moveTab(document.id, to: target.id, copy: false, manager: manager) }
                        Button("העתק אל \(target.name)") { workspace.moveTab(document.id, to: target.id, copy: true, manager: manager) }
                    }
                } label: { Image(systemName: "ellipsis").frame(width: 44, height: 44) }
                Spacer()
                Button(role: .destructive) {
                    if manager.openTabs.contains(where: { $0.id == document.id }) {
                        manager.closeTab(id: document.id); workspace.synchronize(manager)
                    } else if let group = workspace.group {
                        do {
                            try workspace.store.saveTabs(group.tabs.filter { $0.id != document.id }, activeID: group.activeTabID, groupID: group.id)
                        } catch { workspace.errorMessage = error.localizedDescription }
                    }
                } label: { Image(systemName: "xmark").frame(width: 44, height: 44) }
                .accessibilityLabel("סגור \(document.session.bookTitle ?? "ספר")")
            }
        }
        .padding(8)
        .background(.background, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(uiColor: .separator), lineWidth: 1))
    }
}
