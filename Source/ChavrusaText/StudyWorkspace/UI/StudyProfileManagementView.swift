import SwiftUI
import OtzariaUIRouting
import ChavrusaUIRoutingHost

struct StudyProfileManagementView: View {
    @Bindable var workspace: StudyWorkspaceNavigationAdapter
    let manager: iOSNavigationManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(\.maktabahNativeRoutingSession) private var routingSession
    private var localized: StudyWorkspaceText { StudyWorkspaceText(locale: locale) }
    @State private var editing: StudyProfile?
    @State private var createsProfile = false
    @State private var deleting: StudyProfile?
    @State private var managementPath: [ManagementPage] = []
    @State private var renamingGroup: StudyTabGroup?
    @State private var groupName = ""
    @State private var componentViewID = UUID()
    @State private var originalLayoutRevision: UInt64 = 0
    @State private var originalVisiblePage: String?

    private enum ManagementPage: Hashable { case groups }
    private var componentOwner: MaktabahNativeComponentOwner? {
        routingSession?.componentOwner(for: MaktabahNativeWorkspacePresentationBinding.Parent.profiles.destination)
    }
    private var blocksComponentNavigation: Bool {
        editing != nil || createsProfile || deleting != nil || renamingGroup != nil
            || workspace.errorMessage != nil || workspace.isSwitching
    }

    private func originalBinding<Value: Equatable>(_ value: Binding<Value>,
        change: MaktabahNativeWorkspacePresentationBinding.OriginalChange = .draft) -> Binding<Value> {
        maktabahWorkspaceOriginalBinding(value, binding: routingSession?.workspacePresentation,
            host: .profiles, stateOwnerID: componentViewID, change: change)
    }

    var body: some View {
        ScrollViewReader { proxy in
            NavigationStack(path: originalBinding($managementPath, change: .navigation)) {
                List {
                    ForEach((workspace.store.snapshot?.profiles ?? []).sorted { $0.order < $1.order }) { profile in
                        HStack {
                            Label { Text(profile.name) } icon: {
                                StudyProfileIcon(symbol: profile.symbol, color: profile.color)
                            }
                                .accessibilityValue(profile.color?.displayName(using: localized) ?? "")
                                .accessibilityIdentifier("study-profile-\(profile.id.uuidString)")
                                .accessibilityAddTraits(workspace.profile?.id == profile.id ? .isSelected : [])
                            Spacer()
                            if workspace.profile?.id == profile.id { Image(systemName: "checkmark").accessibilityHidden(true) }
                            Menu {
                                Button(localized("Edit", "עריכה"), systemImage: "pencil") { originalBinding($editing).wrappedValue = profile }
                                Button(localized("Delete", "מחיקה"), systemImage: "trash", role: .destructive) { originalBinding($deleting).wrappedValue = profile }
                            } label: { Image(systemName: "ellipsis.circle").frame(width: 44, height: 44) }
                            .accessibilityLabel(localized("Actions for profile \(profile.name)", "פעולות בפרופיל \(profile.name)"))
                            .accessibilityIdentifier("study-profile-actions-\(profile.id.uuidString)")
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
                    Button(localized("New Study Profile", "פרופיל לימוד חדש"), systemImage: "plus") { originalBinding($createsProfile).wrappedValue = true }
                        .accessibilityIdentifier("study-profile-create")
                        .maktabahWorkspaceProfilesComponent(.newProfile, workspace: workspace, manager: manager)
                    NavigationLink(value: ManagementPage.groups) {
                        Text(localized("Manage Tab Groups", "ניהול קבוצות כרטיסיות"))
                    }
                    .accessibilityIdentifier("study-profile-manage-groups")
                }
                .maktabahWorkspaceProfilesComponent(.list, workspace: workspace, manager: manager)
                .background {
                    MaktabahNativeWorkspacePageLayoutWitness(page: "profiles", ownerToken: componentViewID,
                        sceneID: workspace.sceneID, publish: originalPageDidLayout)
                        .allowsHitTesting(false).accessibilityHidden(true)
                }
                .navigationTitle(localized("Study Profiles", "פרופילי לימוד"))
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(localized("Done", "סיום")) {
                            routingSession?.workspacePresentation?.originalStateWillChange(
                                host: .profiles, stateOwnerID: componentViewID, change: .profiles)
                            dismiss()
                        }
                    }
                    ToolbarItem(placement: .topBarLeading) { EditButton() }
                }
                .sheet(item: originalBinding($editing)) { profile in profileEditor(profile) }
                .sheet(isPresented: originalBinding($createsProfile)) { profileEditor(nil) }
                .confirmationDialog(localized("Delete this profile and its tab groups?", "למחוק את הפרופיל וקבוצות הכרטיסיות שלו?"), isPresented: Binding(
                    get: { deleting != nil }, set: { if !$0 { originalBinding($deleting).wrappedValue = nil } }), titleVisibility: .visible) {
                    Button(localized("Delete Profile", "מחיקת פרופיל"), role: .destructive) {
                        guard let old = deleting else { return }
                        originalBinding($deleting).wrappedValue = nil
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
                .navigationDestination(for: ManagementPage.self) { page in
                    switch page {
                    case .groups:
                        StudyGroupManagementView(workspace: workspace, manager: manager,
                            renaming: originalBinding($renamingGroup), name: originalBinding($groupName),
                            componentViewID: componentViewID, onOriginalLayout: originalPageDidLayout)
                    }
                }
            }
            .modifier(MaktabahNativeComponentContainer(
                owner: componentOwner,
                blocked: { blocksComponentNavigation },
                viewID: componentViewID, layoutRevision: originalLayoutRevision,
                revealPhase: { anchor, _ in revealOriginalComponent(anchor, proxy: proxy) }))
        }
        .modifier(MaktabahNativeWorkspaceOriginalHost(
            binding: routingSession?.workspacePresentation, kind: .profiles, stateOwnerID: componentViewID,
            workspace: workspace, manager: manager, blocked: { blocksComponentNavigation }))
        .background { MaktabahNativeRoutingWitness(kind: .workspaceProfiles) }
        .accessibilityIdentifier("study-profile-management")
        .alert(localized("Unable to change the study workspace", "לא ניתן לשנות את סביבת הלימוד"), isPresented: Binding(
            get: { workspace.errorMessage != nil }, set: { if !$0 { workspace.errorMessage = nil } })) {
            Button(localized("OK", "אישור")) { workspace.errorMessage = nil }
        } message: { Text(workspace.errorMessage ?? "") }
    }

    private func originalPageDidLayout(_ page: String, token: UUID) {
        guard token == componentViewID else { return }
        originalVisiblePage = page
        originalLayoutRevision &+= 1
    }

    /// The original NavigationStack and List remain the navigation/scroll owners.
    /// Drafts and confirmations are never dismissed to reveal another component.
    private func revealOriginalComponent(_ id: UIDestinationID, proxy: ScrollViewProxy) -> NativeComponentRenderResult {
        guard !blocksComponentNavigation,
              let anchor = MaktabahNativeWorkspaceComponents.Profiles(rawValue: id.rawValue) else {
            return .awaitingOriginalLayout
        }
        switch anchor {
        case .groups:
            if managementPath != [.groups] {
                do {
                    try routingSession?.workspacePresentation?.revealProfileNavigation(
                        anchor: id, stateOwnerID: componentViewID) {
                            originalBinding($managementPath, change: .navigation).wrappedValue = [.groups]
                        }
                } catch { return .awaitingOriginalLayout }
                return .awaitingOriginalLayout
            }
            return originalVisiblePage == "groups" ? .rendered : .awaitingOriginalLayout
        case .list, .newProfile:
            if !managementPath.isEmpty {
                do {
                    try routingSession?.workspacePresentation?.revealProfileNavigation(
                        anchor: id, stateOwnerID: componentViewID) {
                            originalBinding($managementPath, change: .navigation).wrappedValue = []
                        }
                } catch { return .awaitingOriginalLayout }
                return .awaitingOriginalLayout
            }
            guard originalVisiblePage == "profiles" else { return .awaitingOriginalLayout }
            if anchor == .newProfile { proxy.scrollTo(anchor.id.rawValue, anchor: .center) }
            return .rendered
        }
    }

    private func profileEditor(_ profile: StudyProfile?) -> some View {
        StudyProfileEditor(profile: profile) { name, symbol, color in
            do {
                if let profile { try workspace.store.updateProfile(profile.id, name: name, symbol: symbol, color: color) }
                else { try workspace.store.addProfile(name: name, symbol: symbol, color: color) }
                return true
            } catch { workspace.errorMessage = error.localizedDescription; return false }
        }
    }
}

private struct StudyGroupManagementView: View {
    @Bindable var workspace: StudyWorkspaceNavigationAdapter
    let manager: iOSNavigationManager
    @Environment(\.locale) private var locale
    private var localized: StudyWorkspaceText { StudyWorkspaceText(locale: locale) }

    @Binding var renaming: StudyTabGroup?
    @Binding var name: String
    let componentViewID: UUID
    let onOriginalLayout: @MainActor (String, UUID) -> Void
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
                                Button(localized("Rename", "שינוי שם"), systemImage: "pencil") { name = group.name; renaming = group }
                                Menu(localized("Move to Profile", "העברה לפרופיל")) {
                                    ForEach((workspace.store.snapshot?.profiles ?? []).filter { $0.id != profile.id }) { target in
                                        Button(target.name) {
                                            do { try workspace.store.moveGroup(group.id, to: target.id) }
                                            catch { workspace.errorMessage = error.localizedDescription }
                                        }
                                    }
                                }
                            } label: { Image(systemName: "ellipsis.circle").frame(width: 44, height: 44) }
                            .accessibilityLabel(localized("Actions for group \(group.name)", "פעולות בקבוצה \(group.name)"))
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
        .accessibilityIdentifier("study-group-management")
        .maktabahWorkspaceProfilesComponent(.groups, workspace: workspace, manager: manager)
        .background {
            MaktabahNativeWorkspacePageLayoutWitness(page: "groups", ownerToken: componentViewID,
                sceneID: workspace.sceneID, publish: onOriginalLayout)
                .allowsHitTesting(false).accessibilityHidden(true)
        }
        .navigationTitle(localized("Tab Groups", "קבוצות כרטיסיות"))
        .toolbar { EditButton() }
        .alert(localized("Tab group name", "שם קבוצת הכרטיסיות"), isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
            TextField(localized("Name", "שם"), text: $name)
            Button(localized("Save", "שמירה")) {
                guard let group = renaming else { return }
                do { try workspace.store.renameGroup(group.id, name: name.trimmingCharacters(in: .whitespacesAndNewlines)) }
                catch { workspace.errorMessage = error.localizedDescription }
                renaming = nil
            }
            Button(localized("Cancel", "ביטול"), role: .cancel) { renaming = nil }
        }
    }
}

private struct StudyProfileEditor: View {
    let profile: StudyProfile?
    let onSave: (String, String, StudyProfileColor?) -> Bool
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    private var localized: StudyWorkspaceText { StudyWorkspaceText(locale: locale) }
    @State private var name: String
    @State private var symbol: String
    @State private var color: StudyProfileColor?
    private let symbols = ["person.crop.circle", "book.closed", "books.vertical", "graduationcap", "star"]
    private var symbolLabels: [String: String] {
        ["person.crop.circle": localized("Personal", "אישי"),
         "book.closed": localized("Book", "ספר"),
         "books.vertical": localized("Books", "ספרים"),
         "graduationcap": localized("Study", "לימוד"),
         "star": localized("Favorite", "מועדף")]
    }
    init(profile: StudyProfile?, onSave: @escaping (String, String, StudyProfileColor?) -> Bool) {
        self.profile = profile; self.onSave = onSave
        _name = State(initialValue: profile?.name ?? "")
        _symbol = State(initialValue: profile?.symbol ?? "person.crop.circle")
        _color = State(initialValue: profile?.color)
    }
    var body: some View {
        NavigationStack {
            Form {
                TextField(localized("Profile name", "שם הפרופיל"), text: $name)
                Picker(localized("Symbol", "סמל"), selection: $symbol) {
                    ForEach(symbols, id: \.self) { choice in
                        Image(systemName: choice).accessibilityLabel(symbolLabels[choice] ?? choice).tag(choice)
                    }
                }
                Picker(localized("Color", "צבע"), selection: $color) {
                    Text(localized("Default", "ברירת מחדל")).tag(StudyProfileColor?.none)
                    ForEach(StudyProfileColor.allCases, id: \.self) { choice in
                        Label { Text(choice.displayName(using: localized)) } icon: {
                            StudyProfileIcon(symbol: "circle.fill", color: choice)
                        }.tag(Optional(choice))
                    }
                }
                .pickerStyle(.menu)
                .accessibilityIdentifier("study-profile-color")
                .accessibilityValue(color?.displayName(using: localized) ?? localized("Default", "ברירת מחדל"))
            }
            .navigationTitle(profile == nil ? localized("New Profile", "פרופיל חדש") : localized("Edit Profile", "עריכת פרופיל"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(localized("Cancel", "ביטול")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(localized("Save", "שמירה")) { if onSave(name.trimmingCharacters(in: .whitespacesAndNewlines), symbol, color) { dismiss() } }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

/// Only an explicit user color overrides the inherited native symbol style.
struct StudyProfileIcon: View {
    let symbol: String
    let color: StudyProfileColor?
    var body: some View {
        if let color {
            Image(systemName: symbol).foregroundStyle(color.swiftUIColor)
        } else {
            Image(systemName: symbol)
        }
    }
}

extension StudyProfileColor {
    func displayName(using localized: StudyWorkspaceText) -> String {
        switch self {
        case .blue: localized("Blue", "כחול")
        case .teal: localized("Teal", "טורקיז")
        case .green: localized("Green", "ירוק")
        case .orange: localized("Orange", "כתום")
        case .red: localized("Red", "אדום")
        case .purple: localized("Purple", "סגול")
        }
    }

    var swiftUIColor: Color {
        switch self {
        case .blue: .blue
        case .teal: .teal
        case .green: .green
        case .orange: .orange
        case .red: .red
        case .purple: .purple
        }
    }
}
