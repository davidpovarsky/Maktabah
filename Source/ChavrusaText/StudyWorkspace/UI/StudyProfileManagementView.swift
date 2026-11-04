import SwiftUI

struct StudyProfileManagementView: View {
    @Bindable var workspace: StudyWorkspaceNavigationAdapter
    let manager: iOSNavigationManager
    @Environment(\.dismiss) private var dismiss
    @State private var editing: StudyProfile?
    @State private var createsProfile = false
    @State private var deleting: StudyProfile?

    var body: some View {
        NavigationStack {
            List {
                ForEach((workspace.store.snapshot?.profiles ?? []).sorted { $0.order < $1.order }) { profile in
                    HStack {
                        Label(profile.name, systemImage: profile.symbol)
                        Spacer()
                        if workspace.profile?.id == profile.id { Image(systemName: "checkmark") }
                        Menu {
                            Button("עריכה", systemImage: "pencil") { editing = profile }
                            Button("מחיקה", systemImage: "trash", role: .destructive) { deleting = profile }
                        } label: { Image(systemName: "ellipsis.circle").frame(width: 44, height: 44) }
                    }
                }
                .onMove { source, destination in
                    do {
                        try workspace.store.transaction { value in
                            var profiles = value.profiles.sorted { $0.order < $1.order }
                            profiles.move(fromOffsets: source, toOffset: destination)
                            for index in profiles.indices { profiles[index].order = index }
                            value.profiles = profiles
                        }
                    } catch { workspace.errorMessage = error.localizedDescription }
                }
                Button("פרופיל לימוד חדש", systemImage: "plus") { createsProfile = true }
                NavigationLink("ניהול קבוצות כרטיסיות") {
                    StudyGroupManagementView(workspace: workspace, manager: manager)
                }
            }
            .navigationTitle("פרופילי לימוד")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("סיום") { dismiss() } }
                ToolbarItem(placement: .topBarLeading) { EditButton() }
            }
            .sheet(item: $editing) { profile in profileEditor(profile) }
            .sheet(isPresented: $createsProfile) { profileEditor(nil) }
            .confirmationDialog("למחוק את הפרופיל וקבוצות הכרטיסיות שלו?", isPresented: Binding(
                get: { deleting != nil }, set: { if !$0 { deleting = nil } }), titleVisibility: .visible) {
                Button("מחיקת פרופיל", role: .destructive) {
                    guard let old = deleting else { return }
                    deleting = nil
                    Task {
                        do {
                            if workspace.profile?.id == old.id {
                                guard let target = workspace.store.snapshot?.groups.first(where: { $0.profileID != old.id }) else { throw StudyWorkspaceError.lastProfile }
                                try await workspace.switchGroup(to: target.id, manager: manager)
                            }
                            try workspace.store.deleteProfile(old.id)
                        } catch { workspace.errorMessage = error.localizedDescription }
                    }
                }
            }
        }
        .accessibilityIdentifier("study-profile-management")
        .alert("לא ניתן לשנות את סביבת הלימוד", isPresented: Binding(
            get: { workspace.errorMessage != nil }, set: { if !$0 { workspace.errorMessage = nil } })) {
            Button("אישור") { workspace.errorMessage = nil }
        } message: { Text(workspace.errorMessage ?? "") }
    }

    private func profileEditor(_ profile: StudyProfile?) -> some View {
        StudyProfileEditor(profile: profile) { name, symbol in
            do {
                if let profile { try workspace.store.renameProfile(profile.id, name: name, symbol: symbol) }
                else { try workspace.store.addProfile(name: name, symbol: symbol) }
                return true
            } catch { workspace.errorMessage = error.localizedDescription; return false }
        }
    }
}

private struct StudyGroupManagementView: View {
    @Bindable var workspace: StudyWorkspaceNavigationAdapter
    let manager: iOSNavigationManager
    @State private var renaming: StudyTabGroup?
    @State private var name = ""
    var body: some View {
        List {
            ForEach((workspace.store.snapshot?.profiles ?? []).sorted { $0.order < $1.order }) { profile in
                Section(profile.name) {
                    let groups = (workspace.store.snapshot?.groups.filter { $0.profileID == profile.id } ?? []).sorted { $0.order < $1.order }
                    ForEach(groups) { group in
                        HStack {
                            Text(group.name)
                            Spacer()
                            Menu {
                                Button("שינוי שם", systemImage: "pencil") { name = group.name; renaming = group }
                                Menu("העברה לפרופיל") {
                                    ForEach((workspace.store.snapshot?.profiles ?? []).filter { $0.id != profile.id }) { target in
                                        Button(target.name) {
                                            do { try workspace.store.moveGroup(group.id, to: target.id) }
                                            catch { workspace.errorMessage = error.localizedDescription }
                                        }
                                    }
                                }
                            } label: { Image(systemName: "ellipsis.circle").frame(width: 44, height: 44) }
                        }
                    }
                    .onMove { source, destination in
                        var reordered = groups
                        reordered.move(fromOffsets: source, toOffset: destination)
                        do { try workspace.store.orderGroups(reordered.map(\.id), profileID: profile.id) }
                        catch { workspace.errorMessage = error.localizedDescription }
                    }
                }
            }
        }
        .navigationTitle("קבוצות כרטיסיות")
        .toolbar { EditButton() }
        .alert("שם קבוצת הכרטיסיות", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
            TextField("שם", text: $name)
            Button("שמירה") {
                guard let group = renaming else { return }
                do { try workspace.store.renameGroup(group.id, name: name.trimmingCharacters(in: .whitespacesAndNewlines)) }
                catch { workspace.errorMessage = error.localizedDescription }
                renaming = nil
            }
            Button("ביטול", role: .cancel) { renaming = nil }
        }
    }
}

private struct StudyProfileEditor: View {
    let profile: StudyProfile?
    let onSave: (String, String) -> Bool
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var symbol: String
    private let symbols = ["person.crop.circle", "book.closed", "books.vertical", "graduationcap", "star"]
    init(profile: StudyProfile?, onSave: @escaping (String, String) -> Bool) {
        self.profile = profile; self.onSave = onSave
        _name = State(initialValue: profile?.name ?? "")
        _symbol = State(initialValue: profile?.symbol ?? "person.crop.circle")
    }
    var body: some View {
        NavigationStack {
            Form {
                TextField("שם הפרופיל", text: $name)
                Picker("סמל", selection: $symbol) {
                    ForEach(symbols, id: \.self) { Image(systemName: $0).tag($0) }
                }
            }
            .navigationTitle(profile == nil ? "פרופיל חדש" : "עריכת פרופיל")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("ביטול") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("שמירה") { if onSave(name.trimmingCharacters(in: .whitespacesAndNewlines), symbol) { dismiss() } }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
