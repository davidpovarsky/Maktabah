//
//  StudyProfileCapsule.swift
//  Maktabah
//
//  Downstream-owned toolbar capsule and menu for switching Study Profiles and Tab Groups (Plan C3).
//

#if os(iOS)
import SwiftUI

/// Compact toolbar capsule displaying the active `StudyProfile` and `StudyTabGroup`,
/// presenting a native menu for instant profile/group switching, group creation, and profile management.
struct StudyProfileCapsule: View {
    @Environment(iOSNavigationManager.self) private var navigationManager
    @Bindable var sceneCoordinator: StudyWorkspaceSceneCoordinator
    var workspaceStore: StudyWorkspaceStore = .shared

    @State private var showingNewGroupAlert = false
    @State private var newGroupName = ""
    @State private var copyCurrentTabsIntoNewGroup = false

    var body: some View {
        let activeProfile = sceneCoordinator.activeProfile
        let activeGroup = sceneCoordinator.activeGroup

        Menu {
            // Section 1: Tab Groups in Active Profile
            Section("קבוצות לימוד (\(activeProfile.name))") {
                ForEach(sceneCoordinator.groupsInActiveProfile) { group in
                    let count = workspaceStore.tabs(in: group.id).count
                    Button {
                        switchToGroup(group.id)
                    } label: {
                        HStack {
                            Text("\(group.name) (\(count))")
                            if group.id == activeGroup.id {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }

                Button {
                    newGroupName = ""
                    copyCurrentTabsIntoNewGroup = false
                    showingNewGroupAlert = true
                } label: {
                    Label("קבוצת לימוד חדשה...", systemImage: "plus.rectangle.on.folder")
                }

                if !navigationManager.openTabs.isEmpty {
                    Button {
                        newGroupName = ""
                        copyCurrentTabsIntoNewGroup = true
                        showingNewGroupAlert = true
                    } label: {
                        Label("קבוצה חדשה מהכרטיסיות הפתוחות...", systemImage: "doc.on.doc")
                    }
                }
            }

            // Section 2: Study Profiles
            Section("פרופילי לימוד") {
                ForEach(workspaceStore.profiles) { profile in
                    Button {
                        switchToProfile(profile.id)
                    } label: {
                        HStack {
                            Label(profile.name, systemImage: profile.icon)
                            if profile.id == activeProfile.id {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }

                Button {
                    sceneCoordinator.isProfileManagementPresented = true
                } label: {
                    Label("ניהול פרופילי לימוד...", systemImage: "slider.horizontal.3")
                }
            }

            // Section 3: Overview
            Section {
                Button {
                    sceneCoordinator.navigationAdapter.captureLiveState(
                        from: navigationManager,
                        intoGroup: sceneCoordinator.activeGroup.id
                    )
                    sceneCoordinator.isOverviewPresented = true
                } label: {
                    Label("תצוגת על של כל הקבוצות", systemImage: "square.grid.2x2")
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: activeProfile.icon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                Text(activeProfile.name)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                Text("·")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(activeGroup.name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 10)
            .frame(minHeight: 34)
            .background(Color.secondary.opacity(0.1), in: Capsule(style: .continuous))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("פרופיל לימוד \(activeProfile.name), קבוצה \(activeGroup.name)")
        .alert(
            copyCurrentTabsIntoNewGroup ? "קבוצה חדשה מהכרטיסיות הפתוחות" : "קבוצת לימוד חדשה",
            isPresented: $showingNewGroupAlert
        ) {
            TextField("שם הקבוצה (למשל: סוגיית שבת, הלכה, עיון)", text: $newGroupName)
            Button("ביטול", role: .cancel) {}
            Button("צור") {
                createGroupFromAlert()
            }
        } message: {
            Text(
                copyCurrentTabsIntoNewGroup
                    ? "כל הכרטיסיות הפתוחות כעת יועתקו כעותקים עצמאיים לקבוצה החדשה."
                    : "הזן שם עבור קבוצת הלימוד החדשה בפרופיל \(activeProfile.name)."
            )
        }
        .sheet(isPresented: $sceneCoordinator.isProfileManagementPresented) {
            StudyProfileManagementView(sceneCoordinator: sceneCoordinator)
        }
    }

    private func switchToGroup(_ targetGroupID: UUID) {
        _ = sceneCoordinator.transitionToGroup(targetGroupID, in: navigationManager)
    }

    private func switchToProfile(_ targetProfileID: UUID) {
        guard sceneCoordinator.activeProfile.id != targetProfileID else { return }
        guard let targetProfile = workspaceStore.profile(for: targetProfileID) else { return }
        let targetGroup = workspaceStore.groups(for: targetProfile.id).first ?? workspaceStore.defaultGroup(for: targetProfile.id)
        _ = sceneCoordinator.transitionToGroup(targetGroup.id, in: navigationManager)
    }

    private func createGroupFromAlert() {
        let previousGroupID = sceneCoordinator.activeGroup.id
        sceneCoordinator.navigationAdapter.captureLiveState(
            from: navigationManager,
            intoGroup: previousGroupID
        )
        let created = workspaceStore.createGroup(
            name: newGroupName,
            inProfile: sceneCoordinator.activeProfile.id,
            fromCurrentTabsIn: copyCurrentTabsIntoNewGroup ? previousGroupID : nil,
            activateImmediately: false
        )
        _ = sceneCoordinator.transitionToGroup(created.id, in: navigationManager)
    }
}
#endif
