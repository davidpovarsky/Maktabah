//
//  ChavrusaTextFeatureFlags.swift
//  Maktabah
//
//  Downstream-owned reversible feature flags for ChavrusaText iPad UI plans (A-E).
//

import Foundation
import Observation

/// Centralized, reversible feature flags governing the ChavrusaText iPad UI architecture.
/// Every major plan (A-E) can be toggled independently via `UserDefaults` or launch environment
/// without removing user persistence or corrupting legacy `ios_reader_session.json`.
@MainActor
@Observable
final class ChavrusaTextFeatureFlags {
    static let shared = ChavrusaTextFeatureFlags()

    enum Key: String, CaseIterable, Sendable {
        case sidebarPagerEnabled = "chavrusa.feature.sidebarPagerEnabled"
        case safariToolbarSearchEnabled = "chavrusa.feature.safariToolbarSearchEnabled"
        case studyWorkspaceEnabled = "chavrusa.feature.studyWorkspaceEnabled"
        case duckTabStripEnabled = "chavrusa.feature.duckTabStripEnabled"
        case inspectorHostRefinementEnabled = "chavrusa.feature.inspectorHostRefinementEnabled"
        case semanticSliderPolicyEnabled = "chavrusa.feature.semanticSliderPolicyEnabled"
    }

    private let defaults: UserDefaults

    /// Plan A: Craft-style 2-screen sidebar pager (Library + TOC) in a 2-column NavigationSplitView.
    var sidebarPagerEnabled: Bool {
        didSet { defaults.set(sidebarPagerEnabled, forKey: Key.sidebarPagerEnabled.rawValue) }
    }

    /// Plan B: 3-group Safari-style viewer toolbar + expanding center library search with Gelatin motion.
    var safariToolbarSearchEnabled: Bool {
        didSet { defaults.set(safariToolbarSearchEnabled, forKey: Key.safariToolbarSearchEnabled.rawValue) }
    }

    /// Plan C1/C3: Study Profiles, Tab Groups, Overview, and sidecar workspace persistence.
    var studyWorkspaceEnabled: Bool {
        didSet { defaults.set(studyWorkspaceEnabled, forKey: Key.studyWorkspaceEnabled.rawValue) }
    }

    /// Plan C2: DuckDuckGo-inspired UIKit collection-view document tab strip beneath the toolbar.
    var duckTabStripEnabled: Bool {
        didSet { defaults.set(duckTabStripEnabled, forKey: Key.duckTabStripEnabled.rawValue) }
    }

    /// Plan D: Width-driven Inspector host & clean paper-matched background (preserving FloatingPanel + TorahInspectorKit).
    var inspectorHostRefinementEnabled: Bool {
        didSet { defaults.set(inspectorHostRefinementEnabled, forKey: Key.inspectorHostRefinementEnabled.rawValue) }
    }

    /// Plan E2: Semantic navigation slider policy (chapter/daf/section granularity rather than paragraph line index).
    var semanticSliderPolicyEnabled: Bool {
        didSet { defaults.set(semanticSliderPolicyEnabled, forKey: Key.semanticSliderPolicyEnabled.rawValue) }
    }

    // MARK: - Deterministic Flag Dependency Matrix

    /// Plan A is self-contained when enabled.
    var effectiveSidebarPagerEnabled: Bool {
        sidebarPagerEnabled
    }

    /// Plan B is self-contained when enabled; when false, the legacy sidebar `.searchable` and reader navigation bar remain active.
    var effectiveSafariToolbarSearchEnabled: Bool {
        safariToolbarSearchEnabled
    }

    /// Plan C1/C3 (Study Profiles, Tab Groups, Overview, sidecar persistence).
    /// When false, zero workspace sidecar mutations or `StudyWorkspaceNavigationAdapter` projections occur.
    var effectiveStudyWorkspaceEnabled: Bool {
        studyWorkspaceEnabled
    }

    /// Plan C2 (40pt DuckDuckGo-style UIKit document tab strip).
    /// Can run standalone against `iOSNavigationManager.openTabs` or with `studyWorkspaceEnabled` for group operations.
    var effectiveDuckTabStripEnabled: Bool {
        duckTabStripEnabled
    }

    /// Plan D (Width-driven Inspector host & structural `.embeddedSheet` wide-column chrome).
    var effectiveInspectorHostRefinementEnabled: Bool {
        inspectorHostRefinementEnabled
    }

    /// Plan E2 (Semantic TOC slider granularity).
    var effectiveSemanticSliderPolicyEnabled: Bool {
        semanticSliderPolicyEnabled
    }

    /// Top-level reader chrome replacement (Plan B Safari Toolbar, Plan C2 Duck Tab Strip, or Plan C1/C3 Study Workspace).
    /// When any of these are enabled, `ReaderWorkspaceChromeHost` wraps the reader detail area.
    var hasAnyReaderChromeUpgradeEnabled: Bool {
        effectiveSafariToolbarSearchEnabled || effectiveDuckTabStripEnabled || effectiveStudyWorkspaceEnabled
    }

    /// Safe default: In automated unit tests (`environment.isEmpty` or running under `XCTest`),
    /// flags default to `false` ensuring complete isolation and verifying default behavior.
    /// In live app sessions (such as the TestFlight experimental build), flags default to `true`
    /// so the user can test the UI upgrades immediately upon launch.
    init(
        defaults: UserDefaults = .standard,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        defaultState: Bool? = nil
    ) {
        self.defaults = defaults
        let isTesting = NSClassFromString("XCTestCase") != nil
            || ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
            || environment.isEmpty
        let resolvedDefault = defaultState ?? (isTesting ? false : true)

        self.sidebarPagerEnabled = Self.resolve(
            key: .sidebarPagerEnabled,
            defaultValue: resolvedDefault,
            defaults: defaults,
            environment: environment
        )
        self.safariToolbarSearchEnabled = Self.resolve(
            key: .safariToolbarSearchEnabled,
            defaultValue: resolvedDefault,
            defaults: defaults,
            environment: environment
        )
        self.studyWorkspaceEnabled = Self.resolve(
            key: .studyWorkspaceEnabled,
            defaultValue: resolvedDefault,
            defaults: defaults,
            environment: environment
        )
        self.duckTabStripEnabled = Self.resolve(
            key: .duckTabStripEnabled,
            defaultValue: resolvedDefault,
            defaults: defaults,
            environment: environment
        )
        self.inspectorHostRefinementEnabled = Self.resolve(
            key: .inspectorHostRefinementEnabled,
            defaultValue: resolvedDefault,
            defaults: defaults,
            environment: environment
        )
        self.semanticSliderPolicyEnabled = Self.resolve(
            key: .semanticSliderPolicyEnabled,
            defaultValue: resolvedDefault,
            defaults: defaults,
            environment: environment
        )
    }

    /// Resets all feature flags to their safe production default (`false`).
    func resetToDefaults() {
        for key in Key.allCases {
            defaults.removeObject(forKey: key.rawValue)
        }
        sidebarPagerEnabled = false
        safariToolbarSearchEnabled = false
        studyWorkspaceEnabled = false
        duckTabStripEnabled = false
        inspectorHostRefinementEnabled = false
        semanticSliderPolicyEnabled = false
    }

    /// Convenience helper for opt-in QA / preview sessions to enable all Plans A-E simultaneously.
    func enableAll() {
        sidebarPagerEnabled = true
        safariToolbarSearchEnabled = true
        studyWorkspaceEnabled = true
        duckTabStripEnabled = true
        inspectorHostRefinementEnabled = true
        semanticSliderPolicyEnabled = true
    }

    private static func resolve(
        key: Key,
        defaultValue: Bool,
        defaults: UserDefaults,
        environment: [String: String]
    ) -> Bool {
        let envKey = key.rawValue.replacingOccurrences(of: ".", with: "_").uppercased()
        if let rawEnv = environment[envKey]?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            if ["1", "true", "yes", "on"].contains(rawEnv) { return true }
            if ["0", "false", "no", "off"].contains(rawEnv) { return false }
        }
        if defaults.object(forKey: key.rawValue) != nil {
            return defaults.bool(forKey: key.rawValue)
        }
        return defaultValue
    }
}
