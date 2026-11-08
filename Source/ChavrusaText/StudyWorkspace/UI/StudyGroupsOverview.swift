import SwiftUI
import UIKit

struct StudyGroupsOverview: View {
    @Bindable var workspace: StudyWorkspaceNavigationAdapter
    let manager: iOSNavigationManager
    let onOpenLibrary: () -> Void
    let onClose: () -> Void
    @State private var showsNamePrompt = false
    @State private var name = ""
    @State private var copiesCurrent = false
    @State private var renamesCurrent = false
    @State private var confirmsDelete = false
    @State private var showsProfiles = false
    @AppStorage("chavrusa.study-tabs.layout") private var tabSwitcherLayoutRaw = ReaderTabSwitcherLayout.grid.rawValue

    private var tabSwitcherLayout: ReaderTabSwitcherLayout {
        ReaderTabSwitcherLayout(rawValue: tabSwitcherLayoutRaw) ?? .grid
    }

    var body: some View {
        NavigationStack {
            TabSwitcherPageHost(
                documents: (workspace.group?.tabs ?? []).map {
                    ReaderTabSwitcherDocument(id: $0.id, title: $0.session.bookTitle ?? "ספר", subtitle: $0.backend.displayName)
                },
                selectedID: workspace.group?.activeTabID,
                layoutMode: tabSwitcherLayout,
                onSelect: openDocument,
                onClose: closeDocument,
                onReorder: { document, index in
                    workspace.reorderDocument(document.id, to: index, manager: manager)
                },
                contextMenu: contextMenu
            )
            .overlay {
                if workspace.group?.tabs.isEmpty != false {
                    ContentUnavailableView {
                        Label("אין כרטיסיות בקבוצה", systemImage: "book.closed")
                    } actions: {
                        Button("פתח ספר מהספרייה") { onClose(); onOpenLibrary() }
                    }
                }
            }
            .navigationTitle("כל הכרטיסיות")
            .safeAreaInset(edge: .top) {
                ScrollableGroupsHost(groups: workspace.groups, selectedID: workspace.selection?.groupID, isEnabled: !workspace.isSwitching) { id in
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
                if !MaktabahApp.isIpad {
                    ToolbarItem(placement: .secondaryAction) {
                        StudyProfileMenu(workspace: workspace, manager: manager, compact: true) { showsProfiles = true }
                    }
                    .readerSourceGlassBackground()
                }
                ToolbarItem(placement: .confirmationAction) { Button("סיום") { onClose() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        tabSwitcherLayoutRaw = tabSwitcherLayout == .grid
                            ? ReaderTabSwitcherLayout.list.rawValue
                            : ReaderTabSwitcherLayout.grid.rawValue
                    } label: {
                        Label(
                            tabSwitcherLayout == .grid ? "תצוגת רשימה" : "תצוגת רשת",
                            systemImage: tabSwitcherLayout == .grid ? "list.bullet" : "square.grid.2x2"
                        )
                    }
                    .accessibilityIdentifier("study-tabs-layout-toggle")
                }
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button("קבוצה ריקה", systemImage: "plus") { prompt(copy: false) }
                        Button("קבוצה מהכרטיסיות הנוכחיות", systemImage: "square.on.square") { prompt(copy: true) }
                        Button("שינוי שם הקבוצה", systemImage: "pencil") {
                            renamesCurrent = true; name = workspace.group?.name ?? ""; showsNamePrompt = true
                        }
                        Button("מחיקת קבוצה", systemImage: "trash", role: .destructive) { confirmsDelete = true }
                    } label: { Label("קבוצות כרטיסיות", systemImage: "ellipsis.circle") }
                    .accessibilityLabel("פעולות בקבוצת הכרטיסיות")
                    .accessibilityIdentifier("study-group-actions-menu")
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
        .sheet(isPresented: $showsProfiles) {
            StudyProfileManagementView(workspace: workspace, manager: manager)
        }
        .alert("לא ניתן לשנות את סביבת הלימוד", isPresented: Binding(
            get: { workspace.errorMessage != nil }, set: { if !$0 { workspace.errorMessage = nil } })) {
            Button("אישור") { workspace.errorMessage = nil }
        } message: { Text(workspace.errorMessage ?? "") }
        .accessibilityIdentifier("study-groups-overview")
    }

    private func prompt(copy: Bool) { renamesCurrent = false; copiesCurrent = copy; name = ""; showsNamePrompt = true }

    private func openDocument(_ document: ReaderTabSwitcherDocument) {
        // Like returning to the browser's already-selected tab: no navigation
        // or restoration should run just to uncover its existing view.
        if workspace.group?.activeTabID == document.id {
            onClose()
            return
        }
        Task {
            do {
                guard let group = workspace.group else { return }
                try await workspace.switchGroup(to: group.id, documentID: document.id, manager: manager)
                onClose()
            } catch {
                workspace.errorMessage = error.localizedDescription
            }
        }
    }

    private func closeDocument(_ document: ReaderTabSwitcherDocument) {
        if manager.openTabs.contains(where: { $0.id == document.id }) {
            manager.closeTab(id: document.id)
            workspace.synchronize(manager)
        } else if let group = workspace.group {
            do {
                let remaining = group.tabs.filter { $0.id != document.id }
                try workspace.store.saveTabs(
                    remaining,
                    activeID: group.activeTabID == document.id ? remaining.first?.id : group.activeTabID,
                    groupID: group.id
                )
            } catch {
                workspace.errorMessage = error.localizedDescription
            }
        }
    }

    private func contextMenu(_ document: ReaderTabSwitcherDocument) -> UIMenu? {
        let targets = (workspace.store.snapshot?.groups ?? []).filter { $0.id != workspace.group?.id }
        let move = UIMenu(
            title: "העברה לקבוצה",
            image: UIImage(systemName: "arrow.right.square"),
            children: targets.map { target in
                UIAction(title: target.name) { _ in
                    workspace.moveTab(document.id, to: target.id, copy: false, manager: manager)
                }
            }
        )
        let copy = UIMenu(
            title: "העתקה לקבוצה",
            image: UIImage(systemName: "square.on.square"),
            children: targets.map { target in
                UIAction(title: target.name) { _ in
                    workspace.moveTab(document.id, to: target.id, copy: true, manager: manager)
                }
            }
        )
        let close = UIAction(title: "סגירת כרטיסייה", image: UIImage(systemName: "xmark"), attributes: .destructive) { _ in
            closeDocument(document)
        }
        return UIMenu(children: targets.isEmpty ? [close] : [move, copy, close])
    }
}
