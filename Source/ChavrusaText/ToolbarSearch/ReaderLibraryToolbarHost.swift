//
//  ReaderLibraryToolbarHost.swift
//  Maktabah
//
//  Downstream-owned 3-group Safari-style viewer toolbar for iPad (Plan B & Plan C).
//  Groups:
//  1. Leading: Sidebar toggle, TOC quick-open, StudyProfile/Group capsule, Tab Groups Overview button.
//  2. Center: Expanding library search capsule (ReaderLibraryCommandPaletteHost + GelatinMotionOnly).
//  3. Trailing: Book-local search, Annotations, Display options, Book Info, Backend selector.
//

#if os(iOS)
import SwiftUI

/// Renders the unified single top Safari-style 3-group viewer toolbar for ChavrusaText on iPad.
struct ReaderLibraryToolbarHost: View {
    @Environment(iOSNavigationManager.self) private var navigationManager
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @Bindable var sidebarCoordinator: ReaderSidebarStateCoordinator
    @Bindable var searchCoordinator: ExpandableLibrarySearchCoordinator
    var sceneCoordinator: StudyWorkspaceSceneCoordinator?
    var libraryViewModel: LibraryViewModel

    @Binding var showingBookSearchSheet: Bool
    @Binding var showingAnnotationSheet: Bool
    @Binding var showingDisplaySettingsPopover: Bool
    @Binding var showingBookInfoPopover: Bool
    @State private var showingNavigationPopover: Bool = false
    @State private var currentAvailableWidth: CGFloat = 0

    var isCompact: Bool {
        if currentAvailableWidth > 0 {
            return currentAvailableWidth < 680
        }
        return horizontalSizeClass == .compact
    }

    var body: some View {
        HStack(spacing: isCompact ? 6 : 12) {
            leadingToolbarGroup
            Spacer(minLength: isCompact ? 4 : 12)
            centerToolbarGroup
            Spacer(minLength: isCompact ? 4 : 12)
            trailingToolbarGroup
        }
        .padding(.horizontal, isCompact ? 8 : 14)
        .padding(.vertical, 8)
        .frame(minHeight: 52)
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear {
                        currentAvailableWidth = geo.size.width
                        sidebarCoordinator.availableReaderWidth = geo.size.width
                    }
                    .onChange(of: geo.size.width) { _, newWidth in
                        currentAvailableWidth = newWidth
                        sidebarCoordinator.availableReaderWidth = newWidth
                    }
            }
        )
        .background(.bar)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    // MARK: - Group 1: Leading (Sidebar + TOC + Profile/Group Capsule + Overview)

    private var leadingToolbarGroup: some View {
        HStack(spacing: 6) {
            Button {
                withAnimation(.snappy(duration: 0.25)) {
                    sidebarCoordinator.toggleSidebar()
                }
            } label: {
                Image(systemName: "sidebar.leading")
                    .font(.body.weight(.medium))
                    .frame(minWidth: 36, minHeight: 36)
            }
            .buttonStyle(.plain)
            .help("הצג/הסתר סרגל צד")
            .accessibilityLabel("הצג או הסתר סרגל צד")

            Button {
                withAnimation(.snappy(duration: 0.25)) {
                    sidebarCoordinator.showTOC()
                }
            } label: {
                Image(systemName: "list.bullet.indent")
                    .font(.body.weight(.medium))
                    .foregroundStyle(
                        sidebarCoordinator.sidebarVisible && sidebarCoordinator.selectedPage == .toc
                            ? Color.accentColor
                            : Color.primary
                    )
                    .frame(minWidth: 36, minHeight: 36)
            }
            .buttonStyle(.plain)
            .disabled(navigationManager.activeTab == nil)
            .help("תוכן עניינים")
            .accessibilityLabel("פתח תוכן עניינים בסרגל הצד")

            if ChavrusaTextFeatureFlags.shared.effectiveStudyWorkspaceEnabled, let sceneCoordinator {
                Divider()
                    .frame(height: 18)
                    .padding(.horizontal, 2)

                StudyProfileCapsule(sceneCoordinator: sceneCoordinator)

                Button {
                    withAnimation(.snappy(duration: 0.28)) {
                        sceneCoordinator.navigationAdapter.captureLiveState(
                            from: navigationManager,
                            intoGroup: sceneCoordinator.activeGroup.id
                        )
                        sceneCoordinator.toggleOverview()
                    }
                } label: {
                    Image(systemName: sceneCoordinator.isOverviewPresented ? "square.grid.2x2.fill" : "square.grid.2x2")
                        .font(.body.weight(.medium))
                        .foregroundStyle(sceneCoordinator.isOverviewPresented ? Color.accentColor : Color.primary)
                        .frame(minWidth: 36, minHeight: 36)
                }
                .buttonStyle(.plain)
                .help("תצוגת על של קבוצות לימוד")
                .accessibilityLabel("תצוגת על של קבוצות לימוד")
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
        .background(.regularMaterial, in: Capsule(style: .continuous))
    }

    // MARK: - Group 2: Center (Expanding Library Search)

    private var centerToolbarGroup: some View {
        ReaderLibraryCommandPaletteHost(
            coordinator: searchCoordinator,
            libraryViewModel: libraryViewModel,
            sidebarCoordinator: sidebarCoordinator
        )
    }

    // MARK: - Group 3: Trailing (Reader Actions + Backend Switcher)

    private var trailingToolbarGroup: some View {
        let hasActiveBook = (navigationManager.activeTab != nil)
        let activeVM = navigationManager.activeReaderViewModel

        return HStack(spacing: isCompact ? 4 : 6) {
            if let activeVM {
                let activeNavTitle: String? = {
                    if let idx = activeVM.currentNavigationIndex,
                       activeVM.navigationItems.indices.contains(idx) {
                        return activeVM.navigationItems[idx].title
                    }
                    return nil
                }()
                let displayRef = ReaderNavigationDisplayPolicy.resolveUnifiedSemanticDisplayLabel(
                    sectionDisplayRef: activeVM.backendSection?.displayRef,
                    sectionHeRef: activeVM.backendSection?.heRef,
                    activeNavigationItemTitle: activeNavTitle,
                    explicitSelectedSegmentLocator: activeVM.selectedSegmentLocator,
                    fallbackSubtitle: activeVM.statusSubtitle
                )
                Button {
                    showingNavigationPopover.toggle()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "slider.horizontal.below.rectangle")
                            .font(.caption.weight(.semibold))
                        Text(displayRef)
                            .font(.caption.weight(.medium))
                            .lineLimit(1)
                            .frame(maxWidth: isCompact ? 100 : 140)
                    }
                    .padding(.horizontal, isCompact ? 6 : 8)
                    .frame(minHeight: 32)
                    .background(Color.secondary.opacity(0.1), in: Capsule())
                }
                .buttonStyle(.plain)
                .help("ניווט בספר")
                .accessibilityLabel("ניווט בספר: \(displayRef)")
                .popover(isPresented: $showingNavigationPopover, arrowEdge: .top) {
                    iOSReaderNavigationPopoverView(viewModel: activeVM)
                        .presentationCompactAdaptation(.popover)
                }
            }

            if !isCompact {
                if let activeVM, activeVM.hasActiveSearchHighlight {
                    Button {
                        activeVM.clearSearchHighlight()
                    } label: {
                        Label("נקה הדגשה", systemImage: "xmark.circle.fill")
                            .labelStyle(.titleAndIcon)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(Color.accentColor.opacity(0.14), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("נקה הדגשת חיפוש")
                }

                if let activeVM, !activeVM.otzariaAvailableUnitModes.isEmpty {
                    Menu {
                        ForEach(activeVM.otzariaAvailableUnitModes) { option in
                            Button {
                                activeVM.setOtzariaUnitMode(option.mode)
                            } label: {
                                if option.mode == activeVM.otzariaUnitMode {
                                    Label(option.title, systemImage: "checkmark")
                                } else {
                                    Text(option.title)
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "text.badge.checkmark")
                            .font(.body.weight(.medium))
                            .frame(minWidth: 36, minHeight: 36)
                    }
                    .buttonStyle(.plain)
                    .help("יחידת תצוגה")
                    .accessibilityLabel("יחידת תצוגה")
                }
            }

            Button {
                showingBookSearchSheet = true
            } label: {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.body.weight(.medium))
                    .frame(minWidth: 36, minHeight: 36)
            }
            .buttonStyle(.plain)
            .disabled(!hasActiveBook)
            .help("חיפוש בתוך הספר")
            .accessibilityLabel("חיפוש בתוך הספר הפעיל")

            if !isCompact {
                Button {
                    showingAnnotationSheet = true
                } label: {
                    Image(systemName: "highlighter")
                        .font(.body.weight(.medium))
                        .frame(minWidth: 36, minHeight: 36)
                }
                .buttonStyle(.plain)
                .disabled(!hasActiveBook)
                .help("הערות והדגשות")
                .accessibilityLabel("הערות והדגשות")
            }

            Button {
                showingDisplaySettingsPopover = true
            } label: {
                Image(systemName: "textformat.size")
                    .font(.body.weight(.medium))
                    .frame(minWidth: 36, minHeight: 36)
            }
            .buttonStyle(.plain)
            .disabled(!hasActiveBook)
            .help("הגדרות תצוגה וגופן")
            .accessibilityLabel("הגדרות תצוגה וגופן")
            .popover(isPresented: $showingDisplaySettingsPopover, arrowEdge: .top) {
                if let activeVM {
                    ViewOptionsView(readerViewModel: activeVM)
                        .frame(width: 300, height: 500)
                        .presentationCompactAdaptation(.popover)
                }
            }

            if !isCompact {
                Button {
                    if let book = navigationManager.activeTab?.book {
                        navigationManager.selectedBookForInfo = book
                    }
                    showingBookInfoPopover = true
                } label: {
                    Image(systemName: "info.circle")
                        .font(.body.weight(.medium))
                        .frame(minWidth: 36, minHeight: 36)
                }
                .buttonStyle(.plain)
                .disabled(!hasActiveBook)
                .help("פרטי הספר")
                .accessibilityLabel("פרטי הספר")
                .popover(isPresented: $showingBookInfoPopover, arrowEdge: .top) {
                    if let book = navigationManager.activeTab?.book {
                        iOSBookInfoCardView(book: book)
                            .presentationCompactAdaptation(.popover)
                            .preferredColorScheme(TextViewState.shared.isDarkMode ? .dark : .light)
                    }
                }
            }

            if isCompact && hasActiveBook {
                Menu {
                    Button {
                        showingAnnotationSheet = true
                    } label: {
                        Label("הערות והדגשות", systemImage: "highlighter")
                    }

                    Button {
                        if let book = navigationManager.activeTab?.book {
                            navigationManager.selectedBookForInfo = book
                        }
                        showingBookInfoPopover = true
                    } label: {
                        Label("פרטי הספר", systemImage: "info.circle")
                    }

                    if let activeVM, !activeVM.otzariaAvailableUnitModes.isEmpty {
                        Menu("יחידת תצוגה") {
                            ForEach(activeVM.otzariaAvailableUnitModes) { option in
                                Button {
                                    activeVM.setOtzariaUnitMode(option.mode)
                                } label: {
                                    if option.mode == activeVM.otzariaUnitMode {
                                        Label(option.title, systemImage: "checkmark")
                                    } else {
                                        Text(option.title)
                                    }
                                }
                            }
                        }
                    }

                    if let activeVM, activeVM.hasActiveSearchHighlight {
                        Button {
                            activeVM.clearSearchHighlight()
                        } label: {
                            Label("נקה הדגשת חיפוש", systemImage: "xmark.circle")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.body.weight(.medium))
                        .frame(minWidth: 32, minHeight: 36)
                }
                .buttonStyle(.plain)
                .help("פעולות נוספות")
                .accessibilityLabel("פעולות נוספות")
            }

            if let activeVM {
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        if activeVM.readerInspectorVisible {
                            activeVM.closeReaderInspector()
                        } else {
                            activeVM.readerInspectorVisible = true
                        }
                    }
                } label: {
                    PanelToggleIcon(isOpen: activeVM.readerInspectorVisible)
                        .frame(minWidth: 36, minHeight: 36)
                }
                .buttonStyle(.plain)
                .help("כלי לימוד ומפרשים")
                .accessibilityLabel(activeVM.readerInspectorVisible ? "הסתר כלי לימוד" : "הצג כלי לימוד")
            }

            Divider()
                .frame(height: 18)
                .padding(.horizontal, 2)

            backendSwitchMenu
                .frame(minHeight: 36)
        }
        .padding(.horizontal, isCompact ? 6 : 8)
        .padding(.vertical, 2)
        .background(.regularMaterial, in: Capsule(style: .continuous))
    }

    private var backendSwitchMenu: some View {
        let activeBackend = BackendCoordinator.shared.activeBackendID
        return Menu {
            Section("מקור ספרייה") {
                ForEach(BackendID.allCases) { backend in
                    Button {
                        guard backend != activeBackend else { return }
                        Task { @MainActor in
                            _ = await BackendCoordinator.shared.commitAsync(backend)
                        }
                    } label: {
                        HStack {
                            Text(backend.displayName)
                            if backend == activeBackend {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "building.columns")
                    .font(.caption.weight(.semibold))
                Text(activeBackend.displayName)
                    .font(.caption.weight(.semibold))
            }
            .padding(.horizontal, 8)
            .frame(minHeight: 32)
            .background(Color.secondary.opacity(0.1), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("מקור ספרייה פעיל: \(activeBackend.displayName)")
    }
}
#endif
