//
//  ReaderInspectorHostPolicy.swift
//  Maktabah
//
//  Downstream-owned host layout and background policy for the TorahInspectorKit + FloatingPanel Inspector (Plan D).
//  NOTE: Per project owner override, Native System Sheet (.sheet / .presentationPlacement(.trailing) / 3 detents)
//  is STRICTLY FORBIDDEN for the Inspector. FloatingPanel + TorahInspectorKit remain the sole presenter.
//

#if canImport(CoreGraphics)
import CoreGraphics
#endif
import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif
#if os(iOS)
import TorahInspectorUI
#endif

/// Encapsulates Plan D Inspector hosting rules while preserving `FloatingPanel` (`3db567a`)
/// and `TorahInspectorKit` (`157676f`).
enum ReaderInspectorHostPolicy {
    /// Minimum available detail workspace width to display the side-by-side trailing Inspector column
    /// (`wideWorkspace` with `panelResizeHandle`) instead of the compact bottom `FloatingPanel`.
    /// Guarantees `>= minimumReaderContentColumnWidth (340) + minInspectorWidth (280) + dividerHandleWidth (18) = 638pt`.
    static let minimumWideWorkspaceWidth: CGFloat = 700

    /// Minimum reader text column width when the trailing Inspector column is open.
    static let minimumReaderContentColumnWidth: CGFloat = 340

    /// Default horizontal text margin inset next to the Inspector resize handle so Hebrew lines never collide with the divider.
    static let inspectorAdjacentSafeMargin: CGFloat = 14

    /// Determines whether the workspace should use the side-by-side trailing Inspector panel
    /// based on actual available width rather than legacy 3-column `columnVisibility == .all`.
    static func shouldUseWideInspectorWorkspace(
        availableWidth: CGFloat,
        isCompactHorizontalSizeClass: Bool
    ) -> Bool {
        guard !isCompactHorizontalSizeClass else { return false }
        return availableWidth >= minimumWideWorkspaceWidth
    }

    /// Unified single source of truth for `iOSReaderWorkspaceView.shouldPresentPanelInContent`.
    /// Returns `true` when on regular/wide layout (`!isCompactHorizontalSizeClass`) and the Inspector
    /// should be hosted in the bottom `FloatingPanel` (`floatingWorkspace`) rather than the side-by-side
    /// trailing column (`wideWorkspace`). Returns `false` on compact layout so `updatePanelPresentation`
    /// falls through to `compactStudyPanel` (`showPanelSheet = true`).
    /// Used identically by `workspaceDetail`, `updatePanelPresentation(animated:)`, and `.onChange(of: floatingPanelState)`.
    static func shouldPresentPanelInContent(
        availableWidth: CGFloat,
        isCompactHorizontalSizeClass: Bool,
        isAllColumnsVisibleInLegacySplit: Bool,
        inspectorHostRefinementEnabled: Bool
    ) -> Bool {
        guard !isCompactHorizontalSizeClass else { return false }
        if inspectorHostRefinementEnabled && availableWidth > 0 {
            return !shouldUseWideInspectorWorkspace(
                availableWidth: availableWidth,
                isCompactHorizontalSizeClass: isCompactHorizontalSizeClass
            )
        }
        return isAllColumnsVisibleInLegacySplit
    }

    /// Indicates whether the side-by-side `wideWorkspace` Inspector column should use seamless full-column
    /// chrome (`.embeddedSheet`, zero outer `.padding(8)` inset) rather than `.floatingPanel` (which adds an 8pt outer gap).
    static func prefersSeamlessWideColumnChrome(
        inspectorHostRefinementEnabled: Bool
    ) -> Bool {
        inspectorHostRefinementEnabled
    }

    /// Clamps the trailing Inspector panel width so the main reader column always retains at least `minimumReaderContentColumnWidth`.
    static func clampedInspectorWidth(
        preferredWidth: Double,
        availableWorkspaceWidth: CGFloat,
        minInspectorWidth: CGFloat = 280,
        maxInspectorWidth: CGFloat = 520,
        dividerHandleWidth: CGFloat = 18
    ) -> CGFloat {
        let maxAllowedByReader = max(
            minInspectorWidth,
            availableWorkspaceWidth - minimumReaderContentColumnWidth - dividerHandleWidth
        )
        let upperBound = min(maxInspectorWidth, maxAllowedByReader)
        return min(max(CGFloat(preferredWidth), minInspectorWidth), upperBound)
    }

    #if os(iOS)
    /// Resolves `TorahInspectorChrome` for the side-by-side `wideWorkspace` Inspector column.
    /// Using `.embeddedSheet` in `wideWorkspace` structurally removes `TorahSegmentDetailView`'s outer `.padding(8)`
    /// and rounded-card inset so no outer brown `Color.appBackground` frame is ever exposed around the column,
    /// while `floatingWorkspace` (the bottom `FloatingPanel`) continues using `.floatingPanel`.
    @MainActor static func resolvedWideWorkspaceInspectorChrome(
        featureFlags: ChavrusaTextFeatureFlags = .shared
    ) -> TorahInspectorChrome {
        prefersSeamlessWideColumnChrome(
            inspectorHostRefinementEnabled: featureFlags.effectiveInspectorHostRefinementEnabled
        ) ? .embeddedSheet : .floatingPanel
    }

    /// Resolves the background color behind the reader detail workspace and `panelResizeHandle`.
    @MainActor static func resolvedWorkspaceBackgroundColor(
        featureFlags: ChavrusaTextFeatureFlags = .shared
    ) -> Color {
        if featureFlags.effectiveInspectorHostRefinementEnabled {
            return TextViewState.shared.backgroundColor.color
        }
        return Color.appBackground
    }
    #endif
}
