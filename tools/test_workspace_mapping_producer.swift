import Foundation
import Observation

private struct CheckFailure: Error { let message: String }

@main struct WorkspaceMappingProducerTests {
    @MainActor static func main() async throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("workspace-mapping-producer-\(UUID())")
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }
        var checks = 0
        func expect(_ condition: Bool, _ name: String) throws {
            guard condition else { throw CheckFailure(message: name) }
            checks += 1
            print("PASS STORE[\(checks)] \(name)")
        }
        func document(id: UUID = UUID(), book: Int = 17, key: String = "book:17", backend: BackendID = .otzaria, line: Int = 0) -> ReaderDocumentTab {
            .init(backend: backend, session: .init(id: id, bookId: book, bookTitle: "fixture",
                backendLocator: .init(backend: backend, workKey: key, position: .legacyLine(line)),
                contentId: line, locator: .init(backend: backend, workKey: key, position: .legacyLine(line)),
                scrollPosition: .init(x: 0, y: CGFloat(line))))
        }
        let persistence = StudyWorkspacePersistence(url: root.appendingPathComponent("store/workspace.json"))
        let store = StudyWorkspaceStore(persistence: persistence, canonicalSessionURL: root.appendingPathComponent("absent-session.json"))
        let a = document(), b = document(book: 18, key: "book:18")
        let source = store.mappingSource(scene: "a")
        try expect(source.mappingRevision == nil, "missing scene has no default stable epoch")
        try store.attach(scene: "a", legacyTabs: [a, b], activeID: a.id)
        guard let group = store.selectedGroup(scene: "a"), let initial = source.event.epoch else { throw CheckFailure(message: "real attach must publish available ownership") }
        try expect(source === store.mappingSource(scene: "a"), "fixed source identity")
        var admitted = true
        var invalidations = 0
        var observedFence = false
        let observer = NativeBindingSourceObservation(readRevision: { source.mappingRevision }, onInvalidation: {
            admitted = false
            invalidations += 1
        })
        withObservationTracking { _ = store.snapshot } onChange: {
            MainActor.assumeIsolated { observedFence = source.mappingRevision == nil }
        }
        try store.saveTabs([a, b], activeID: b.id, groupID: group.id)
        try expect(!admitted && observedFence, "selection revokes synchronously before snapshot publication")
        try expect(source.event.epoch != initial && source.event.reasons.contains(.selection), "selection epoch classified")
        admitted = true // Re-admission between writes; deliberately no await.
        let between = source.event.epoch
        try store.saveTabs([a, b], activeID: a.id, groupID: group.id)
        try expect(!admitted && source.event.epoch != between && source.event.epoch != initial, "same-turn ABA revokes intervening admission")
        for _ in 0..<20 {
            admitted = true
            try store.saveTabs([a, b], activeID: b.id, groupID: group.id)
            try expect(!admitted, "rearmed synchronous B setter")
            admitted = true
            try store.saveTabs([a, b], activeID: a.id, groupID: group.id)
            try expect(!admitted, "rearmed synchronous A setter")
        }
        admitted = true
        let stable = source.event.epoch
        let broadRevision = store.snapshot!.revision
        let callbacks = invalidations
        try store.transaction { _ in }
        try store.saveTabs([document(id: a.id, line: 90), b], activeID: a.id, groupID: group.id)
        try store.renameGroup(group.id, name: "renamed")
        try store.renameProfile(group.profileID, name: "renamed profile", symbol: "book")
        try store.reorderDocument(b.id, to: 0, groupID: group.id)
        try expect(admitted && source.event.epoch == stable && invalidations == callbacks, "checkpoint/no-op/position/rename/order preserve mapping")
        try expect(store.snapshot!.revision > broadRevision, "narrow epoch independent of persisted checkpoint revision")
        var unchangedObservationAvailable = false
        withObservationTracking { _ = store.snapshot } onChange: {
            MainActor.assumeIsolated { unchangedObservationAvailable = store.mappingObservation(scene: "a")?.epoch == stable }
        }
        try store.transaction { _ in }
        _ = try store.addGroup(profileID: group.profileID, name: "unrelated sibling group")
        try expect(unchangedObservationAvailable && admitted && source.event.epoch == stable && invalidations == callbacks,
            "unchanged checkpoint publication and unrelated group membership preserve exact-scene availability")
        let beforeFailure = store.snapshot!
        let diskBeforeFailure = try Data(contentsOf: persistence.url)
        do {
            try store.transaction { $0.groups.removeAll() }
            throw CheckFailure(message: "invalid membership accepted")
        } catch StudyWorkspaceError.invalidMembership {}
        try expect(store.snapshot == beforeFailure && source.event.epoch == stable, "invalid transaction rolls back epoch and snapshot")
        try expect(admitted && invalidations == callbacks, "invalid membership does not revoke an existing admission")
        if fm.fileExists(atPath: persistence.backupURL.path) { try fm.removeItem(at: persistence.backupURL) }
        try fm.createDirectory(at: persistence.backupURL, withIntermediateDirectories: false)
        do {
            try store.renameGroup(group.id, name: "save must fail")
            throw CheckFailure(message: "disk save failure expected")
        } catch is CheckFailure { throw CheckFailure(message: "disk failure fixture did not fail") }
        catch {}
        try expect(store.snapshot == beforeFailure && source.event.epoch == stable, "failed disk save never emits ownership invalidation")
        try expect(try Data(contentsOf: persistence.url) == diskBeforeFailure, "failed save preserves actual primary bytes")
        try fm.removeItem(at: persistence.backupURL)
        try store.saveTabs([document(id: a.id, book: 19, key: "book:19"), b], activeID: a.id, groupID: group.id)
        try expect(source.event.reasons.contains(.targetIdentity) && !admitted, "replacement book behind same tab UUID invalidates")
        let replaced = source.event.epoch
        try store.saveTabs([document(id: a.id, book: 19, key: "other", backend: .sefaria), b], activeID: a.id, groupID: group.id)
        try expect(source.event.reasons.contains(.backend) && source.event.epoch != replaced, "backend ownership distinguished")
        let beforeKey = source.event.epoch
        try store.saveTabs([document(id: a.id, book: 19, key: "another", backend: .sefaria), b], activeID: a.id, groupID: group.id)
        try expect(source.event.reasons == [.targetIdentity] && source.event.epoch != beforeKey, "same book/id/backend changed work identity is not progress")
        let removeEpoch = source.event.epoch
        try store.saveTabs([document(id: a.id, book: 19, key: "another", backend: .sefaria)], activeID: a.id, groupID: group.id)
        try expect(source.event.reasons.contains(.tabMembership) && source.event.epoch != removeEpoch, "target tab removal classified")
        let unrelated = source.event.epoch
        let profileB = try store.addProfile(name: "other", symbol: "book")
        let groupB = store.snapshot!.groups.first { $0.profileID == profileB }!
        try store.transaction {
            $0.scenes["b"] = .init(profileID: profileB, groupID: groupB.id)
        }
        try store.saveTabs([document(book: 77, key: "book:77")], activeID: nil, groupID: groupB.id)
        try expect(source.event.epoch == unrelated, "unrelated profile/scene changes do not revoke scene A")
        try store.transaction {
            $0.scenes.removeValue(forKey: "a")
            $0.lastActiveSceneID = "b"
        }
        try expect(source.mappingRevision == nil && source.event.reasons.contains(.availability), "scene removal is unavailable")
        try store.attach(scene: "a", legacyTabs: [], activeID: nil)
        try expect(source.mappingRevision != nil && source.event.epoch != unrelated, "reattach cannot revive old epoch")
        try expect(store.mappingObservation(scene: "a")?.coverage == .workspaceStoreOnly, "Store observation explicitly excludes native setters")
        for index in 0..<500 {
            let unused = store.mappingSource(scene: "unused-\(index)")
            if unused.mappingRevision != nil { throw CheckFailure(message: "unknown source received default epoch") }
        }
        _ = store.mappingSource(scene: "a")
        let registry = Mirror(reflecting: store).children.first { $0.label == "mappingSources" }!.value
        try expect(Mirror(reflecting: registry).children.count <= 2, "weak source registry does not retain historical/unavailable scene probes")
        observer.cancel()
        let afterCancel = invalidations
        try store.saveTabs([], activeID: nil, groupID: groupB.id)
        try expect(invalidations == afterCancel, "canonical observer cancellation stops callbacks")
        let replacement = StudyWorkspaceStore(persistence: persistence, canonicalSessionURL: root.appendingPathComponent("none.json"))
        let replacementObservation = replacement.mappingObservation(scene: "a")!
        try expect(replacementObservation.owner != ObjectIdentifier(store)
            && replacementObservation.epoch.sourceID != source.event.epoch?.sourceID,
            "same persisted scene/group identity in a replacement Store has a distinct actual owner and source lifetime")

        var temporary: StudyWorkspaceStore? = StudyWorkspaceStore(persistence: .init(url: root.appendingPathComponent("lifetime/workspace.json")), canonicalSessionURL: root.appendingPathComponent("absent.json"))
        try temporary!.attach(scene: "life", legacyTabs: [a], activeID: a.id)
        let lifetimeSource = temporary!.mappingSource(scene: "life")
        var lifetimeAdmission = true
        let lifetimeObserver = NativeBindingSourceObservation(readRevision: { lifetimeSource.mappingRevision }, onInvalidation: { lifetimeAdmission = false })
        weak var weakStore = temporary
        temporary = nil
        try expect(weakStore == nil && !lifetimeAdmission && lifetimeSource.mappingRevision == nil && lifetimeSource.event.reasons == [.ownerLifetime], "retained source revokes synchronously when actual Store owner deinitializes")
        lifetimeObserver.cancel()
        weakStore = nil
        let overflow = StudyWorkspaceMappingSource(available: true, maximumRevision: 1)
        overflow.beginChange([.selection]); overflow.finishChange(available: true)
        try expect(overflow.mappingRevision == 1, "finite real producer sequence boundary")
        overflow.beginChange([.selection]); overflow.finishChange(available: true)
        try expect(overflow.mappingRevision == nil && overflow.event.reasons == [.epochExhausted], "real producer overflow retires rather than wraps or readmits")
        let overflowPersistence = StudyWorkspacePersistence(url: root.appendingPathComponent("max-revision/workspace.json"))
        var maxSnapshot = store.snapshot!
        maxSnapshot.revision = .max
        try overflowPersistence.save(maxSnapshot)
        let maxStore = StudyWorkspaceStore(persistence: overflowPersistence, canonicalSessionURL: root.appendingPathComponent("none.json"))
        let maxSource = maxStore.mappingSource(scene: "a")
        let maxEpoch = maxSource.event.epoch
        do {
            try maxStore.transaction { _ in }
            throw CheckFailure(message: "persisted revision must not wrap")
        } catch StudyWorkspaceError.invalidMembership {}
        try expect(maxStore.snapshot?.revision == .max && maxSource.event.epoch == maxEpoch,
            "broad revision overflow rejects failed transaction without mapping invalidation")
        for backend in [BackendID.sefaria, .sefariaEmbedded] {
            let signedStore = StudyWorkspaceStore(persistence: .init(url: root.appendingPathComponent("signed-\(backend.rawValue)/workspace.json")), canonicalSessionURL: root.appendingPathComponent("none.json"))
            let signed = document(book: -17, key: "Genesis", backend: backend)
            try signedStore.attach(scene: "signed", legacyTabs: [signed], activeID: signed.id)
            try expect(signedStore.mappingObservation(scene: "signed")?.projection.targets[signed.id]?.bookID == -17,
                "qualified \(backend.rawValue) legacy negative identity is preserved, not revalidated as an Otzaria ID")
        }
        let storeChecks = checks
        let nativeChecks = try MappingNativeBoundaryChecks.run(root: root)
        print("PASS: \(storeChecks) actual Store/source assertions + \(nativeChecks) exact adapter-body/boundary-double assertions; actual Apple/native setter installation NOT_RUN")
        try await WorkspaceStartupReconciliationChecks.run(root: root)
    }
}
