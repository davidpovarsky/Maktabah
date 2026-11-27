import Foundation
import Observation

// Synthetic lifetime boundary only. All layout state implementation below is
// verbatim from the actual app adapter. No UIKit/native acceptance is inferred.
@MainActor private final class MaktabahNativeComponentOwner {
    var activeView: UUID?
    func owns(viewID: UUID) -> Bool { activeView == viewID }
}

private struct MaktabahNativeTOCLayoutKey: Equatable {
    let model: ObjectIdentifier
    let selectedID: Int?
    let selectedNode: ObjectIdentifier?
    let structure: String
    let expanded: Set<ObjectIdentifier>
    let search: String
}
private struct MaktabahNativeTOCScrollGeometry: Equatable {
    let contentSize: CGSize
    let containerSize: CGSize
    let visibleRect: CGRect
}

@MainActor @Observable
private final class MaktabahNativeTOCLayoutPresentation {
    let viewID = UUID()
    private(set) var layoutRevision: UInt64 = 0
    private(set) var publisherToken: UUID?
    @ObservationIgnored private var activeToken: UUID?
    @ObservationIgnored private weak var owner: MaktabahNativeComponentOwner?
    @ObservationIgnored private var currentKey: MaktabahNativeTOCLayoutKey?
    @ObservationIgnored private var publishedKey: MaktabahNativeTOCLayoutKey?
    @ObservationIgnored private var previousFrame: CGRect?
    @ObservationIgnored private var previousGeometry: MaktabahNativeTOCScrollGeometry?

    func activate(token: UUID, owner: MaktabahNativeComponentOwner, key: MaktabahNativeTOCLayoutKey) {
        guard owner.owns(viewID: viewID) else { return }
        if activeToken != token || self.owner !== owner {
            publishedKey = nil; previousFrame = nil; previousGeometry = nil
        }
        self.owner = owner; activeToken = token; currentKey = key
        publisherToken = token
    }

    func update(token: UUID, key: MaktabahNativeTOCLayoutKey) {
        guard activeToken == token else { return }
        currentKey = key
    }

    func invalidate(token: UUID) {
        guard activeToken == token else { return }
        activeToken = nil; currentKey = nil; publishedKey = nil
        previousFrame = nil; previousGeometry = nil
        // Immediate token retirement blocks old callbacks. This UI notification
        // is posted outside dismantle/update; it creates no render authority.
        DispatchQueue.main.async { [weak self] in
            guard let self, self.activeToken == nil, self.publisherToken == token else { return }
            self.publisherToken = nil
        }
    }

    private func accepts(token: UUID, owner: MaktabahNativeComponentOwner, key: MaktabahNativeTOCLayoutKey) -> Bool {
        self.owner === owner && currentKey == key && owner.owns(viewID: viewID)
    }

    func publishLayout(token: UUID, owner: MaktabahNativeComponentOwner,
                       key: MaktabahNativeTOCLayoutKey, frame: CGRect) {
        guard accepts(token: token, owner: owner, key: key),
              frame.width.isFinite, frame.height.isFinite, frame.width > 0, frame.height > 0,
              publishedKey != key || previousFrame != frame else { return }
        publishedKey = key; previousFrame = frame
        layoutRevision &+= 1
    }

    func publishScroll(token: UUID, owner: MaktabahNativeComponentOwner,
                       key: MaktabahNativeTOCLayoutKey, geometry: MaktabahNativeTOCScrollGeometry) {
        guard accepts(token: token, owner: owner, key: key),
              geometry.contentSize.width.isFinite, geometry.contentSize.height.isFinite,
              geometry.containerSize.width.isFinite, geometry.containerSize.height.isFinite,
              geometry.visibleRect.width.isFinite, geometry.visibleRect.height.isFinite,
              geometry.contentSize.width > 0, geometry.contentSize.height > 0,
              geometry.containerSize.width > 0, geometry.containerSize.height > 0,
              geometry.visibleRect.width > 0, geometry.visibleRect.height > 0,
              publishedKey != key || previousGeometry != geometry else { return }
        publishedKey = key; previousGeometry = geometry
        layoutRevision &+= 1
    }

    func hasPublication(for key: MaktabahNativeTOCLayoutKey) -> Bool {
        guard let activeToken, let owner else { return false }
        return accepts(token: activeToken, owner: owner, key: key) && publishedKey == key
    }
}


@main struct LayoutPublicationControls {
    @MainActor static func main() async throws {
        final class Identity {}
        let model = Identity(), node = Identity()
        func key(expanded: Bool = false, search: String = "") -> MaktabahNativeTOCLayoutKey {
            .init(model: ObjectIdentifier(model), selectedID: 17, selectedNode: ObjectIdentifier(node),
                  structure: "original", expanded: expanded ? [ObjectIdentifier(node)] : [], search: search)
        }
        let state = MaktabahNativeTOCLayoutPresentation()
        let owner = MaktabahNativeComponentOwner()
        owner.activeView = state.viewID
        let token = UUID(), a = key(), b = key(expanded: true)
        let frame = CGRect(x: 10, y: 20, width: 200, height: 500)
        var results: [[String: Any]] = []
        func check(_ name: String, _ passed: Bool) {
            results.append(["name": name, "passed": passed])
            print((passed ? "PASS " : "FAIL ") + name)
        }
        state.activate(token: token, owner: owner, key: a)
        check("mount activation alone is not layout evidence", state.layoutRevision == 0 && !state.hasPublication(for: a))
        state.publishLayout(token: token, owner: owner, key: a, frame: .zero)
        check("empty native frame cannot advance revision", state.layoutRevision == 0)
        state.publishLayout(token: token, owner: owner, key: a, frame: frame)
        check("same live owner and source actual layout is accepted", state.layoutRevision == 1 && state.hasPublication(for: a))
        state.publishLayout(token: token, owner: owner, key: a, frame: frame)
        check("duplicate layout cannot advance a second phase", state.layoutRevision == 1)
        state.update(token: token, key: b)
        check("expansion state mutation alone produces no publication",
              state.layoutRevision == 1 && !state.hasPublication(for: a) && !state.hasPublication(for: b))
        state.publishLayout(token: token, owner: owner, key: a, frame: frame)
        check("queued previous expansion callback is rejected", state.layoutRevision == 1)
        state.publishLayout(token: UUID(), owner: owner, key: b, frame: frame)
        check("wrong marker token is rejected", state.layoutRevision == 1)
        state.publishLayout(token: token, owner: owner, key: b, frame: frame)
        check("new original expansion layout is separately observed", state.layoutRevision == 2 && state.hasPublication(for: b))
        owner.activeView = nil
        state.publishLayout(token: token, owner: owner, key: b, frame: frame.insetBy(dx: 1, dy: 1))
        check("detached original container cannot publish", state.layoutRevision == 2 && !state.hasPublication(for: b))
        owner.activeView = state.viewID
        state.invalidate(token: token)
        let replacementToken = UUID()
        state.activate(token: replacementToken, owner: owner, key: b)
        state.publishLayout(token: token, owner: owner, key: b, frame: frame)
        check("old mount callback cannot inherit identical new source", state.layoutRevision == 2 && !state.hasPublication(for: b))
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            DispatchQueue.main.async { continuation.resume() }
        }
        check("queued old retirement cannot erase replacement publisher", state.publisherToken == replacementToken)
        state.publishLayout(token: replacementToken, owner: owner, key: b, frame: frame)
        check("replacement marker requires its own actual layout", state.layoutRevision == 3 && state.hasPublication(for: b))
        let anotherOwner = MaktabahNativeComponentOwner()
        anotherOwner.activeView = state.viewID
        state.publishLayout(token: replacementToken, owner: anotherOwner, key: b, frame: frame.insetBy(dx: 2, dy: 2))
        check("another owner with equal view ID cannot inherit", state.layoutRevision == 3)
        let geometry = MaktabahNativeTOCScrollGeometry(contentSize: CGSize(width: 200, height: 900),
            containerSize: CGSize(width: 200, height: 500), visibleRect: frame)
        state.publishScroll(token: replacementToken, owner: owner, key: b,
            geometry: .init(contentSize: .zero, containerSize: geometry.containerSize, visibleRect: frame))
        check("empty original list geometry is not publication", state.layoutRevision == 3)
        state.publishScroll(token: replacementToken, owner: owner, key: b, geometry: geometry)
        check("actual list content geometry can publish offscreen expansion", state.layoutRevision == 4)
        state.publishScroll(token: replacementToken, owner: owner, key: b, geometry: geometry)
        check("duplicate list geometry cannot advance revision", state.layoutRevision == 4)
        let c = key(expanded: true, search: "filter")
        state.update(token: replacementToken, key: c)
        state.publishScroll(token: replacementToken, owner: owner, key: b, geometry: geometry)
        check("prior original search-state geometry is rejected", state.layoutRevision == 4 && !state.hasPublication(for: c))
        state.invalidate(token: replacementToken)
        state.publishScroll(token: replacementToken, owner: owner, key: c, geometry: geometry)
        check("retired marker rejects final queued geometry", state.layoutRevision == 4)
        let result: [String: Any] = [
            "status": "SOURCE_LAYOUT_LIFETIME_CONTROLS_ONLY", "controls": results,
            "passed": results.filter { $0["passed"] as? Bool == true }.count,
            "failed": results.filter { $0["passed"] as? Bool == false }.count,
            "native_ui_executed": 0, "physical_device_executed": 0,
            "owner_boundary": "Synthetic ownership predicate; actual app layout-state implementation verbatim"]
        let data = try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: URL(fileURLWithPath: CommandLine.arguments[1]), options: .atomic)
        if results.contains(where: { $0["passed"] as? Bool == false }) { exit(1) }
    }
}
