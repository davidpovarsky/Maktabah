import SwiftUI

struct StudyProfileMenu: View {
    @Bindable var workspace: StudyWorkspaceNavigationAdapter
    let manager: iOSNavigationManager
    var compact = false
    let onManage: () -> Void

    var body: some View {
        GlassButtonGroup {
            Menu {
                ForEach((workspace.store.snapshot?.profiles ?? []).sorted { $0.order < $1.order }) { profile in
                    Button {
                        guard let group = workspace.store.snapshot?.groups.filter({ $0.profileID == profile.id }).sorted(by: { $0.order < $1.order }).first else { return }
                        Task {
                            do { try await workspace.switchGroup(to: group.id, manager: manager) }
                            catch { workspace.errorMessage = error.localizedDescription }
                        }
                    } label: {
                        Label(profile.name, systemImage: workspace.profile?.id == profile.id ? "checkmark" : profile.symbol)
                    }
                    .accessibilityAddTraits(workspace.profile?.id == profile.id ? .isSelected : [])
                }
                Divider()
                Button("ניהול פרופילי לימוד", systemImage: "person.crop.circle.badge.plus", action: onManage)
            } label: {
                HStack(spacing: 5) {
                    if !compact { Text(workspace.profile?.name ?? "אישי").font(.system(size: 15, weight: .medium)).lineLimit(1) }
                    Image(systemName: workspace.profile?.symbol ?? "person.crop.circle.fill").font(.system(size: 20))
                }
                .frame(height: 44)
                .padding(.horizontal, compact ? 5 : 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(workspace.isSwitching)
            .accessibilityLabel("פרופיל לימוד")
            .accessibilityIdentifier("study-profile-menu")
        }
    }
}
