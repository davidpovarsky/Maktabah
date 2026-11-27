import Foundation
import Observation
import OtzariaUIRouting

public struct NativeComponentEvidence: Sendable, Equatable {
    public let anchor: UIDestinationID
    public let sceneID: UIStableID
    public let isVisible: Bool
    public init(anchor: UIDestinationID, sceneID: UIStableID, isVisible: Bool) {
        self.anchor = anchor; self.sceneID = sceneID; self.isVisible = isVisible
    }
}

/// Finite original UI anchors, not selectors, setting values, or executable actions.
public struct NativeComponentDescriptor: Sendable {
    public let anchor: UIDestinationID
    public let title: String
    public init(anchor: UIDestinationID, title: String) { self.anchor = anchor; self.title = title }
}

/// Scene-owned PRESENTATION state for an original feature. The one canonical
/// commit publishes the parent and target together. A newly mounted view renders
/// that state through its original scroll owner; it never obtains another grant.
@MainActor @Observable
public final class NativeComponentRevealOwner {
    public let destination: UIDestinationID
    public let presentation: PresentationSpec.Kind
    public let descriptors: [NativeComponentDescriptor]
    public private(set) var renderRevision: UInt64 = 0
    @ObservationIgnored private let available: @MainActor (UIDestinationID) -> Bool
    @ObservationIgnored private let captureSource: @MainActor (UIDestinationID) throws -> (@MainActor () throws -> Void)
    @ObservationIgnored private var sources: [UUID: (UIDestinationID, @MainActor () throws -> Void)] = [:]
    @ObservationIgnored private var renderedSource: (@MainActor () throws -> Void)?
    @ObservationIgnored private var changed: @MainActor () -> Void = {}
    @ObservationIgnored private var invalidated: @MainActor () -> Void = {}
    @ObservationIgnored private var viewID: UUID?
    @ObservationIgnored private var blocked: @MainActor () -> Bool = { false }
    @ObservationIgnored private var checks: [UIDestinationID: (UUID, @MainActor () -> NativeComponentEvidence?)] = [:]
    @ObservationIgnored private var pending: Pending?
    @ObservationIgnored private var renderedAnchor: UIDestinationID?
    @ObservationIgnored private var presentationRevision: UInt64 = 0

    private struct Pending {
        let requestID: UUID
        let anchor: UIDestinationID
        let validate: @MainActor () throws -> Void
        var viewID: UUID?
        var applied = false
        var rendered = false
    }

    public init(destination: UIDestinationID, presentation: PresentationSpec.Kind,
         descriptors: [NativeComponentDescriptor],
         available: @escaping @MainActor (UIDestinationID) -> Bool,
         captureSource: @escaping @MainActor (UIDestinationID) throws -> (@MainActor () throws -> Void) = { _ in {} }) {
        self.destination = destination; self.presentation = presentation
        self.descriptors = descriptors; self.available = available; self.captureSource = captureSource
    }

    public func install(changed: @escaping @MainActor () -> Void, invalidated: @escaping @MainActor () -> Void) {
        self.changed = changed; self.invalidated = invalidated
    }
    public func isAvailable(_ anchor: UIDestinationID) -> Bool {
        descriptors.contains { $0.anchor == anchor } && available(anchor) && !blocked()
    }

    public var isMounted: Bool { viewID != nil }

    /// Capture once at initial local binding, BEFORE any Core/directory await.
    /// A feature retains its actual tab/model/node/structure here, not just a
    /// boolean indicating that some current component happens to be available.
    public func retainSource(requestID: UUID, anchor: UIDestinationID) throws {
        guard sources.isEmpty, pending == nil, isAvailable(anchor) else {
            throw UIRouteError(.unavailable, "native_component_source_busy")
        }
        let source = try captureSource(anchor)
        let revision = presentationRevision
        let validate: @MainActor () throws -> Void = { [weak self] in
            guard let self, self.presentationRevision == revision else {
                throw UIRouteError(.staleState, "native_component_presentation_changed")
            }
            try source()
        }
        try validate()
        guard isAvailable(anchor) else { throw UIRouteError(.staleState, "native_component_source_changed") }
        sources[requestID] = (anchor, validate)
    }
    public func validateSource(requestID: UUID, anchor: UIDestinationID) throws {
        guard let source = sources[requestID], source.0 == anchor, isAvailable(anchor) else {
            throw UIRouteError(.staleState, "native_component_source_changed")
        }
        try source.1()
    }
    public func releaseSource(requestID: UUID) { sources.removeValue(forKey: requestID) }

    public func begin(requestID: UUID, anchor: UIDestinationID, validate: @escaping @MainActor () throws -> Void) throws {
        guard pending == nil, let source = sources[requestID], source.0 == anchor, isAvailable(anchor) else {
            throw UIRouteError(.unavailable, "native_component_unavailable")
        }
        let retained: @MainActor () throws -> Void = { try validate(); try source.1() }
        try retained()
        pending = .init(requestID: requestID, anchor: anchor, validate: retained, viewID: viewID)
        renderedAnchor = nil; renderedSource = nil
    }

    /// Called synchronously ONLY by the existing driver's canonical apply.
    public func apply(requestID: UUID) throws {
        guard var value = pending, value.requestID == requestID, !value.applied,
              isAvailable(value.anchor), value.viewID == viewID else {
            throw UIRouteError(.staleState, "native_component_owner_changed")
        }
        try value.validate()
        value.applied = true; pending = value
        renderRevision &+= 1
    }

    public func attach(viewID: UUID, blocked: @escaping @MainActor () -> Bool) {
        guard self.viewID != viewID else { self.blocked = blocked; return }
        if self.viewID != nil {
            retirePresentation()
        }
        self.viewID = viewID; self.blocked = blocked
        if var value = pending {
            // A cold presentation may bind its FIRST original view. A replaced
            // view can never inherit an already retained request.
            guard value.viewID == nil else { retirePresentation(); return }
            value.viewID = viewID; pending = value
        }
        changed()
    }
    public func detach(viewID: UUID) {
        guard self.viewID == viewID else { return }
        self.viewID = nil; blocked = { false }; checks.removeAll()
        retirePresentation()
        changed()
    }

    /// Normal original-view rendering, bounded by the original command. This
    /// closure can reveal UI only; it must not alter feature data or execute a
    /// button. Calling scrollTo is not evidence that scrolling succeeded.
    public func render(viewID: UUID, reveal: (UIDestinationID) -> Void) {
        guard var value = pending, value.applied, !value.rendered,
              self.viewID == viewID, value.viewID == viewID,
              isAvailable(value.anchor) else { return }
        do { try value.validate() }
        catch { retirePresentation(); return }
        reveal(value.anchor)
        // No await between the exact ownership check and native UI rendering.
        guard self.viewID == viewID, pending?.requestID == value.requestID else {
            retirePresentation(); return
        }
        value.rendered = true; pending = value
        renderedAnchor = value.anchor
        renderedSource = sources[value.requestID]?.1
        changed()
    }

    public func observe(anchor: UIDestinationID, token: UUID,
                 check: @escaping @MainActor () -> NativeComponentEvidence?) {
        guard descriptors.contains(where: { $0.anchor == anchor }) else { return }
        checks[anchor] = (token, check)
    }
    public func remove(anchor: UIDestinationID, token: UUID) {
        guard checks[anchor]?.0 == token else { return }
        checks.removeValue(forKey: anchor); changed()
    }
    public func geometryChanged() { changed() }

    /// This facet comes from the fixed anchor attached to the ACTUAL original
    /// row/control and its clipped viewport, never from the submitted route.
    public func actualFocus(in sceneID: UIStableID) -> FocusSpec? {
        guard let renderedAnchor, viewID != nil, isAvailable(renderedAnchor),
              let actual = checks[renderedAnchor]?.1(),
              actual.anchor == renderedAnchor, actual.sceneID == sceneID,
              actual.isVisible, let renderedSource else { return nil }
        do { try renderedSource() } catch { return nil }
        if let pending {
            guard pending.rendered, pending.anchor == actual.anchor else { return nil }
            do { try pending.validate() } catch { return nil }
        }
        return .init(kind: .component, anchor: actual.anchor)
    }

    public func finish(requestID: UUID, completed: Bool) {
        guard pending?.requestID == requestID else { return }
        pending = nil
        if !completed { renderedAnchor = nil; renderedSource = nil }
    }
    public func retirePresentation() {
        // This also revokes a source retained before begin(), including a local
        // overlay that opens and closes while Core is suspended.
        presentationRevision &+= 1
        let wasPending = pending != nil
        pending = nil; renderedAnchor = nil; renderedSource = nil
        if wasPending { invalidated() }
    }
}
