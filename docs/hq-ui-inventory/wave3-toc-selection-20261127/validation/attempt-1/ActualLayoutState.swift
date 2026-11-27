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
        activeToken == token && self.owner === owner && currentKey == key && owner.owns(viewID: viewID)
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

