//
//  StudyGroupSelectorHost.swift
//  Maktabah
//
//  Downstream-owned centered horizontal scrollable tab-group selector for StudyGroupsOverview (Plan C3).
//  Implemented with 100% public SwiftUI APIs (ScrollViewReader + matchedGeometryEffect + GelatinMotionOnly).
//  Zero private UIKit/_UIHostingView/ABIBridge APIs.
//

#if os(iOS)
import SwiftUI

/// Horizontal scrollable group-pill bar displayed in the center header of `StudyGroupsOverview`.
struct StudyGroupSelectorHost: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var pillSelectionNamespace

    let groups: [StudyTabGroup]
    let selectedGroupID: UUID
    var tabCountProvider: (StudyTabGroup) -> Int
    var onSelectGroup: (StudyTabGroup) -> Void
    var onAddGroupTapped: () -> Void

    var body: some View {
        ScrollViewReader { scrollProxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(groups) { group in
                        let isSelected = (group.id == selectedGroupID)
                        let tabCount = tabCountProvider(group)

                        Button {
                            withAnimation(springAnimation) {
                                onSelectGroup(group)
                                scrollProxy.scrollTo(group.id, anchor: .center)
                            }
                        } label: {
                            HStack(spacing: 6) {
                                if group.isPinned {
                                    Image(systemName: "pin.fill")
                                        .font(.caption2)
                                        .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                                }
                                Text(group.name)
                                    .font(.subheadline.weight(isSelected ? .semibold : .medium))
                                    .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                                    .lineLimit(1)

                                Text("\(tabCount)")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(
                                        Capsule()
                                            .fill(isSelected ? Color.accentColor.opacity(0.16) : Color.secondary.opacity(0.12))
                                    )
                            }
                            .padding(.horizontal, 14)
                            .frame(minHeight: 38)
                            .background {
                                if isSelected {
                                    Capsule(style: .continuous)
                                        .fill(.regularMaterial)
                                        .overlay(
                                            Capsule(style: .continuous)
                                                .strokeBorder(Color.accentColor.opacity(0.45), lineWidth: 1)
                                        )
                                        .matchedGeometryEffect(id: "ActiveGroupPill", in: pillSelectionNamespace)
                                } else {
                                    Capsule(style: .continuous)
                                        .fill(Color.secondary.opacity(0.08))
                                }
                            }
                            .contentShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .gelatinMotionOnly(isPressed: false)
                        .id(group.id)
                        .accessibilityLabel("\(group.name), \(tabCount) כרטיסיות")
                        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : [.isButton])
                    }

                    Button {
                        onAddGroupTapped()
                    } label: {
                        Label("קבוצה חדשה", systemImage: "plus")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 12)
                            .frame(minHeight: 38)
                            .background(
                                Capsule(style: .continuous)
                                    .strokeBorder(Color.secondary.opacity(0.3), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("צור קבוצת לימוד חדשה")
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
            }
            .onChange(of: selectedGroupID) { _, newID in
                withAnimation(springAnimation) {
                    scrollProxy.scrollTo(newID, anchor: .center)
                }
            }
        }
    }

    private var springAnimation: Animation {
        reduceMotion
            ? .linear(duration: 0.01)
            : .interpolatingSpring(stiffness: 320, damping: 26)
    }
}
#endif
