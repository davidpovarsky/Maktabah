//
//  StudyGroupsOverview.swift
//  Maktabah
//
//  Downstream-owned iPad Tab Groups Overview surface with centered StudyGroupSelectorHost
//  and responsive document tab card grid (Plan C3).
//

#if os(iOS)
import SwiftUI

/// Full-workspace Overview for browsing, organizing, and switching between `StudyTabGroup`s
/// and `ReaderDocumentTab` cards within the active `StudyProfile`.
struct StudyGroupsOverview: View {
    @Environment(iOSNavigationManager.self) private var navigationManager
    @Bindable var sceneCoordinator: StudyWorkspaceSceneCoordinator
    var sidebarCoordinator: ReaderSidebarStateCoordinator?
    var workspaceStore: StudyWorkspaceStore = .shared

    @State private var showingNewGroupAlert = false
    @State private var newGroupName = ""
    @State private var copyCurrentTabs = false
    @State private var groupPendingRename: StudyTabGroup?
    @State private var renameGroupText = ""

    private let gridColumns = [
        GridItem(.adaptive(minimum: 220, maximum: 300), spacing: 16)
    ]

    var body: some View {
        let activeProfile = sceneCoordinator.activeProfile
        let activeGroup = sceneCoordinator.activeGroup
        let profileGroups = sceneCoordinator.groupsInActiveProfile
        let tabsInGroup = workspaceStore.tabs(in: activeGroup.id)

        VStack(spacing: 0) {
            overviewTopHeader(activeProfile: activeProfile, activeGroup: activeGroup, profileGroups: profileGroups)
            Divider()
            overviewGridContent(activeGroup: activeGroup, tabsInGroup: tabsInGroup, profileGroups: profileGroups)
        }
        .background(Color.appBackground)
        .alert("קבוצת לימוד חדשה", isPresented: $showingNewGroupAlert) {
            TextField("שם הקבוצה", text: $newGroupName)
            Button("ביטול", role: .cancel) {}
            Button("צור") {
                let previousGroupID = sceneCoordinator.activeGroup.id
                sceneCoordinator.navigationAdapter.captureLiveState(
                    from: navigationManager,
                    intoGroup: previousGroupID
                )
                let created = workspaceStore.createGroup(
                    name: newGroupName,
                    inProfile: activeProfile.id,
                    fromCurrentTabsIn: copyCurrentTabs ? previousGroupID : nil,
                    activateImmediately: false
                )
                _ = sceneCoordinator.transitionToGroup(created.id, in: navigationManager)
            }
        }
        .alert(
            "שינוי שם קבוצה",
            isPresented: Binding(
                get: { groupPendingRename != nil },
                set: { if !$0 { groupPendingRename = nil } }
            )
        ) {
            TextField("שם הקבוצה", text: $renameGroupText)
            Button("ביטול", role: .cancel) { groupPendingRename = nil }
            Button("שמור") {
                if let group = groupPendingRename {
                    workspaceStore.renameGroup(group.id, newName: renameGroupText)
                }
                groupPendingRename = nil
            }
        }
    }

    // MARK: - Top Header with Centered Group Selector

    private func overviewTopHeader(
        activeProfile: StudyProfile,
        activeGroup: StudyTabGroup,
        profileGroups: [StudyTabGroup]
    ) -> some View {
        HStack(spacing: 12) {
            // Leading: Profile badge & management trigger
            Menu {
                ForEach(workspaceStore.profiles) { profile in
                    Button {
                        let prevGroupID = sceneCoordinator.activeGroup.id
                        sceneCoordinator.navigationAdapter.captureLiveState(
                            from: navigationManager,
                            intoGroup: prevGroupID
                        )
                        sceneCoordinator.selectProfile(profile.id)
                        sceneCoordinator.navigationAdapter.projectGroup(
                            sceneCoordinator.activeGroup.id,
                            onto: navigationManager
                        )
                    } label: {
                        HStack {
                            Label(profile.name, systemImage: profile.icon)
                            if profile.id == activeProfile.id {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
                Divider()
                Button {
                    sceneCoordinator.isProfileManagementPresented = true
                } label: {
                    Label("ניהול פרופילי לימוד...", systemImage: "slider.horizontal.3")
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: activeProfile.icon)
                        .foregroundStyle(Color.accentColor)
                    Text(activeProfile.name)
                        .font(.subheadline.weight(.semibold))
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .frame(minHeight: 38)
                .background(.regularMaterial, in: Capsule())
            }
            .buttonStyle(.plain)

            Spacer(minLength: 8)

            // Center: Horizontal Scrollable Group Selector
            StudyGroupSelectorHost(
                groups: profileGroups,
                selectedGroupID: activeGroup.id,
                tabCountProvider: { grp in workspaceStore.tabs(in: grp.id).count },
                onSelectGroup: { selected in
                    _ = sceneCoordinator.transitionToGroup(selected.id, in: navigationManager)
                },
                onAddGroupTapped: {
                    newGroupName = ""
                    copyCurrentTabs = false
                    showingNewGroupAlert = true
                }
            )

            Spacer(minLength: 8)

            // Trailing: Group actions menu + Done button
            HStack(spacing: 8) {
                Menu {
                    Button {
                        renameGroupText = activeGroup.name
                        groupPendingRename = activeGroup
                    } label: {
                        Label("שנה שם קבוצה...", systemImage: "pencil")
                    }

                    Button {
                        workspaceStore.togglePinGroup(activeGroup.id)
                    } label: {
                        Label(
                            activeGroup.isPinned ? "בטל הצמדת קבוצה" : "הצמד קבוצה לראש הרשימה",
                            systemImage: activeGroup.isPinned ? "pin.slash" : "pin"
                        )
                    }

                    let otherProfiles = workspaceStore.profiles.filter { $0.id != activeProfile.id }
                    if !otherProfiles.isEmpty {
                        Menu("העבר קבוצה לפרופיל") {
                            ForEach(otherProfiles) { targetProfile in
                                Button(targetProfile.name) {
                                    workspaceStore.moveGroup(activeGroup.id, toProfile: targetProfile.id)
                                    sceneCoordinator.refreshFromStore()
                                    sceneCoordinator.navigationAdapter.projectGroup(
                                        sceneCoordinator.activeGroup.id,
                                        onto: navigationManager
                                    )
                                }
                            }
                        }
                    }

                    Divider()

                    Button(role: .destructive) {
                        let fallback = workspaceStore.deleteGroup(activeGroup.id)
                        _ = sceneCoordinator.transitionToGroup(fallback.id, in: navigationManager)
                    } label: {
                        Label("מחק קבוצת לימוד", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                        .frame(minWidth: 38, minHeight: 38)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("פעולות עבור קבוצת הלימוד")

                Button {
                    withAnimation(.snappy(duration: 0.25)) {
                        sceneCoordinator.isOverviewPresented = false
                    }
                } label: {
                    Text("סיום")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 14)
                        .frame(minHeight: 36)
                        .background(Color.accentColor, in: Capsule())
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("סגור תצוגת על וחזור לקריאה")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
    }

    // MARK: - Responsive Tab Cards Grid

    @ViewBuilder
    private func overviewGridContent(
        activeGroup: StudyTabGroup,
        tabsInGroup: [ReaderDocumentTab],
        profileGroups: [StudyTabGroup]
    ) -> some View {
        if tabsInGroup.isEmpty {
            ContentUnavailableView {
                Label("אין כרטיסיות בקבוצה \"\(activeGroup.name)\"", systemImage: "books.vertical")
            } description: {
                Text("בחר ספר מתוך הספרייה כדי לפתוח אותו בקבוצת לימוד זו.")
            } actions: {
                Button("פתח ספרייה") {
                    sceneCoordinator.isOverviewPresented = false
                    sidebarCoordinator?.showLibrary()
                }
                .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVGrid(columns: gridColumns, spacing: 16) {
                    ForEach(tabsInGroup) { tab in
                        overviewTabCard(
                            tab: tab,
                            isSelected: activeGroup.activeTabID == tab.id,
                            activeGroup: activeGroup,
                            otherGroups: profileGroups.filter { $0.id != activeGroup.id }
                        )
                    }
                }
                .padding(20)
            }
        }
    }

    private func overviewTabCard(
        tab: ReaderDocumentTab,
        isSelected: Bool,
        activeGroup: StudyTabGroup,
        otherGroups: [StudyTabGroup]
    ) -> some View {
        let title = tab.bookTitle ?? "ספר \(tab.bookId)"
        let refText = tab.sectionLocator?.description ?? (tab.page.map { "עמ׳ \($0)" } ?? "פתוח לקריאה")

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                HStack(spacing: 6) {
                    Image(systemName: tab.isDormantUnavailable ? "exclamationmark.triangle.fill" : "book.closed.fill")
                        .font(.subheadline)
                        .foregroundStyle(tab.isDormantUnavailable ? Color.orange : Color.accentColor)
                    Text(tab.backend.displayName)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 4)

                Button {
                    navigationManager.closeTab(id: tab.id)
                    workspaceStore.closeTab(tab.id, inGroup: activeGroup.id)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 28, minHeight: 28)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("סגור \(title)")
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                Text(refText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            HStack {
                if tab.isDormantUnavailable {
                    Text("לא זמין במקור הנוכחי")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.orange)
                } else if isSelected {
                    Text("פעיל כעת")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                } else {
                    Text("הקש לפתיחה")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                Spacer()
            }
        }
        .padding(16)
        .frame(minHeight: 148)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(
                            isSelected ? Color.accentColor : Color.primary.opacity(0.08),
                            lineWidth: isSelected ? 2 : 0.8
                        )
                )
        )
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onTapGesture {
            sceneCoordinator.selectTab(tab.id, closeOverviewIfNeeded: true)
            sceneCoordinator.navigationAdapter.projectGroup(
                activeGroup.id,
                onto: navigationManager
            )
        }
        .contextMenu {
            Button {
                _ = workspaceStore.copyTab(tab.id, toGroup: activeGroup.id, activateInDestination: true)
                sceneCoordinator.navigationAdapter.projectGroup(
                    activeGroup.id,
                    onto: navigationManager
                )
            } label: {
                Label("שכפל כרטיסייה", systemImage: "plus.square.on.square")
            }

            if !otherGroups.isEmpty {
                Menu("העבר לקבוצת לימוד") {
                    ForEach(otherGroups) { targetGroup in
                        Button(targetGroup.name) {
                            workspaceStore.moveTab(
                                tab.id,
                                fromGroup: activeGroup.id,
                                toGroup: targetGroup.id,
                                activateInDestination: true
                            )
                            navigationManager.closeTab(id: tab.id)
                        }
                    }
                }

                Menu("העתק לקבוצת לימוד") {
                    ForEach(otherGroups) { targetGroup in
                        Button(targetGroup.name) {
                            _ = workspaceStore.copyTab(
                                tab.id,
                                toGroup: targetGroup.id,
                                activateInDestination: true
                            )
                        }
                    }
                }
            }

            Divider()

            Button(role: .destructive) {
                navigationManager.closeTab(id: tab.id)
                workspaceStore.closeTab(tab.id, inGroup: activeGroup.id)
            } label: {
                Label("סגור כרטיסייה", systemImage: "xmark")
            }
        }
    }
}
#endif
