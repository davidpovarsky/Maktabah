//
//  StudyProfileManagementView.swift
//  Maktabah
//
//  Downstream-owned management sheet for creating, editing, and deleting Study Profiles (Plan C3).
//

#if os(iOS)
import SwiftUI

/// Sheet interface for managing `StudyProfile`s ("אישי", "עיון", "דף היומי", "הלכה", etc.).
/// Guarantees that the default `"אישי"` profile cannot be deleted and serves as the fallback profile.
struct StudyProfileManagementView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(iOSNavigationManager.self) private var navigationManager

    @Bindable var sceneCoordinator: StudyWorkspaceSceneCoordinator
    var workspaceStore: StudyWorkspaceStore = .shared

    @State private var newProfileName: String = ""
    @State private var selectedIcon: String = "books.vertical"
    @State private var editingProfile: StudyProfile?
    @State private var editedProfileName: String = ""

    private let availableIcons: [String] = [
        "person.crop.circle",
        "books.vertical",
        "book.pages",
        "text.book.closed",
        "scroll",
        "sparkles",
        "graduationcap",
        "bookmark.circle"
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("פרופילי לימוד קיימים") {
                    ForEach(workspaceStore.profiles) { profile in
                        let groupCount = workspaceStore.groups(for: profile.id).count
                        HStack(spacing: 12) {
                            Image(systemName: profile.icon)
                                .font(.title3)
                                .foregroundStyle(Color.accentColor)
                                .frame(width: 28)

                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(profile.name)
                                        .font(.body.weight(.semibold))
                                    if profile.isDefault {
                                        Text("ברירת מחדל")
                                            .font(.caption2.weight(.semibold))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.secondary.opacity(0.15), in: Capsule())
                                    }
                                }
                                Text("\(groupCount) קבוצות לימוד")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if sceneCoordinator.activeProfile.id == profile.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Color.accentColor)
                            }

                            Button {
                                editedProfileName = profile.name
                                editingProfile = profile
                            } label: {
                                Image(systemName: "pencil")
                                    .font(.subheadline)
                                    .frame(minWidth: 32, minHeight: 32)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("שנה שם פרופיל \(profile.name)")

                            if !profile.isDefault && profile.id != StudyProfile.defaultProfileID {
                                Button(role: .destructive) {
                                    deleteProfile(profile)
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.subheadline)
                                        .foregroundStyle(.red)
                                        .frame(minWidth: 32, minHeight: 32)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("מחק פרופיל \(profile.name)")
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectProfile(profile)
                        }
                    }
                }

                Section("יצירת פרופיל לימוד חדש") {
                    TextField("שם הפרופיל (למשל: עיון, דף היומי, הלכה)", text: $newProfileName)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(availableIcons, id: \.self) { icon in
                                let isChosen = (selectedIcon == icon)
                                Button {
                                    selectedIcon = icon
                                } label: {
                                    Image(systemName: icon)
                                        .font(.body)
                                        .frame(width: 38, height: 38)
                                        .background(
                                            Circle()
                                                .fill(isChosen ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.1))
                                        )
                                        .overlay(
                                            Circle()
                                                .strokeBorder(isChosen ? Color.accentColor : Color.clear, lineWidth: 1.5)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    Button {
                        createNewProfile()
                    } label: {
                        Label("צור פרופיל חדש", systemImage: "plus.circle.fill")
                            .font(.body.weight(.semibold))
                    }
                    .disabled(newProfileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .navigationTitle("פרופילי לימוד")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("סיום") {
                        dismiss()
                    }
                }
            }
            .alert(
                "עריכת שם פרופיל",
                isPresented: Binding(
                    get: { editingProfile != nil },
                    set: { if !$0 { editingProfile = nil } }
                )
            ) {
                TextField("שם הפרופיל", text: $editedProfileName)
                Button("ביטול", role: .cancel) { editingProfile = nil }
                Button("שמור") {
                    if let profile = editingProfile {
                        workspaceStore.updateProfile(profile.id, name: editedProfileName)
                    }
                    editingProfile = nil
                }
            }
        }
    }

    private func selectProfile(_ profile: StudyProfile) {
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
    }

    private func createNewProfile() {
        let prevGroupID = sceneCoordinator.activeGroup.id
        sceneCoordinator.navigationAdapter.captureLiveState(
            from: navigationManager,
            intoGroup: prevGroupID
        )
        let created = workspaceStore.createProfile(
            name: newProfileName,
            icon: selectedIcon,
            activateImmediately: true
        )
        sceneCoordinator.selectProfile(created.id)
        sceneCoordinator.navigationAdapter.projectGroup(
            sceneCoordinator.activeGroup.id,
            onto: navigationManager
        )
        newProfileName = ""
    }

    private func deleteProfile(_ profile: StudyProfile) {
        let wasActive = (sceneCoordinator.activeProfile.id == profile.id)
        _ = workspaceStore.deleteProfile(profile.id)
        sceneCoordinator.refreshFromStore()
        if wasActive {
            sceneCoordinator.navigationAdapter.projectGroup(
                sceneCoordinator.activeGroup.id,
                onto: navigationManager
            )
        }
    }
}
#endif
