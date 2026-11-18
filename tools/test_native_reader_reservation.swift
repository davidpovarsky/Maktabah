import Foundation

@MainActor private final class ReservationOwner {}
@MainActor private struct ReservationFixture {
    let manager = ReservationOwner(), oldReader = ReservationOwner(), newReader = ReservationOwner()
    let source = StudyWorkspaceMappingSource(available: true)
    let profile = UUID(), group = UUID(), oldID = UUID(), newID = UUID()
    var original: StudyWorkspaceMappingProjection {
        .init(profileID: profile, groupID: group, profileIDs: [profile], groupIDs: [group],
              activeTabID: oldID, targets: [oldID: .init(backend: .otzaria, bookID: 101,
                  workKey: "book:101", readerOwner: ObjectIdentifier(oldReader))])
    }
    var saved: StudyWorkspaceMappingProjection {
        .init(profileID: profile, groupID: group, profileIDs: [profile], groupIDs: [group],
              activeTabID: oldID, targets: [oldID: .init(backend: .otzaria, bookID: 101,
                  workKey: "book:101", readerOwner: nil)])
    }
    func observation(_ projection: StudyWorkspaceMappingProjection) -> StudyWorkspaceMappingObservation {
        .init(source: source, owner: ObjectIdentifier(manager), scene: "scene.reservation",
              epoch: source.event.epoch!, coverage: .liveNativeSetters, projection: projection)
    }
    func reserve() throws -> StudyWorkspaceReaderReservation {
        try .init(requestID: UUID(), observation: observation(original), workspace: saved,
                  target: .init(id: newID, target: .init(backend: .otzaria, bookID: 202,
                      workKey: "book:202", readerOwner: ObjectIdentifier(newReader))))
    }
    func commit(_ ticket: StudyWorkspaceReaderReservation) throws {
        try ticket.beginApply(observation(original))
        require(ticket.permitsTabsPublication(from: original, to: ticket.tabsPublished), "exact append")
        require(!ticket.matches(observation(original)), "no stable observation during setter publication")
        require(ticket.didPublish(actual: ticket.tabsPublished), "read actual appended tab")
        require(ticket.permitsSelectionPublication(from: ticket.tabsPublished, to: ticket.committed), "exact activation")
        require(ticket.didPublish(actual: ticket.committed), "read actual active tab")
        try ticket.finishApply(observation(ticket.committed))
    }
}
@MainActor private var checks = 0
@MainActor private func require(_ value: @autoclosure () -> Bool, _ why: String) {
    guard value() else { fatalError("FAIL: " + why) }; checks += 1
}
@MainActor private func mustReject(_ why: String, _ body: () throws -> Void) {
    do { try body(); fatalError("FAIL: " + why) } catch { checks += 1 }
}
@main struct ReservationTests {
    @MainActor static func main() throws {
        var scenarios = 0
        do {
            let f = ReservationFixture(), ticket = try f.reserve(), epoch = f.source.event.epoch
            require(ticket.matches(f.observation(f.original)), "real original binding")
            try f.commit(ticket)
            require(f.source.event.epoch == epoch, "one intended reservation preserves original source epoch")
            require(ticket.matches(f.observation(ticket.committed)), "committed actual owner")
            require(ticket.permitsCheckpoint(from: f.saved, to: ticket.persisted,
                    actual: f.observation(ticket.committed)), "exact original checkpoint")
            require(ticket.permitsCheckpoint(from: ticket.persisted, to: ticket.persisted,
                    actual: f.observation(ticket.committed)), "metadata-only subsequent checkpoint")
            scenarios += 1
        }
        do {
            let f = ReservationFixture(), ticket = try f.reserve()
            require(!ticket.permitsTabsPublication(from: f.original, to: ticket.tabsPublished),
                    "reservation data alone cannot authorize mutation before beginApply")
            mustReject("invalid ticket stays invalid") { try ticket.beginApply(f.observation(f.original)) }
            scenarios += 1
        }
        do {
            let f = ReservationFixture(), ticket = try f.reserve()
            try ticket.beginApply(f.observation(f.original))
            require(!ticket.permitsSelectionPublication(from: f.original, to: ticket.committed), "selection cannot precede append")
            scenarios += 1
        }
        do {
            let f = ReservationFixture(), ticket = try f.reserve()
            try ticket.beginApply(f.observation(f.original))
            require(!ticket.permitsTabsPublication(from: f.original, to: ticket.committed), "cannot collapse or substitute observed setter sequence")
            scenarios += 1
        }
        do {
            let f = ReservationFixture(), ticket = try f.reserve()
            try ticket.beginApply(f.observation(f.original))
            require(ticket.permitsTabsPublication(from: f.original, to: ticket.tabsPublished), "expected willSet")
            require(!ticket.didPublish(actual: f.original), "desired append without actual model effect rejected")
            scenarios += 1
        }
        do {
            let f = ReservationFixture(), ticket = try f.reserve()
            try ticket.beginApply(f.observation(f.original))
            require(ticket.permitsTabsPublication(from: f.original, to: ticket.tabsPublished), "first append allowed")
            require(!ticket.permitsTabsPublication(from: f.original, to: ticket.tabsPublished), "reentrant setter rejected")
            scenarios += 1
        }
        do {
            let f = ReservationFixture(), ticket = try f.reserve()
            f.source.beginChange([.selection]); f.source.finishChange(available: true)
            require(!ticket.matches(f.observation(f.original)), "same visible projection after ABA has changed real epoch")
            mustReject("ABA cannot begin apply") { try ticket.beginApply(f.observation(f.original)) }
            scenarios += 1
        }
        do {
            let f = ReservationFixture(), ticket = try f.reserve()
            f.source.retire()
            require(!ticket.permitsTabsPublication(from: f.original, to: ticket.tabsPublished), "retired source cannot mutate")
            scenarios += 1
        }
        do {
            let f = ReservationFixture(), ticket = try f.reserve()
            var other = f.observation(f.original)
            other = .init(source: f.source, owner: ObjectIdentifier(f.newReader), scene: other.scene,
                          epoch: other.epoch, coverage: .liveNativeSetters, projection: other.projection)
            require(!ticket.matches(other), "substituted manager refused")
            scenarios += 1
        }
        do {
            let f = ReservationFixture(), ticket = try f.reserve()
            let other = StudyWorkspaceMappingObservation(source: f.source, owner: ObjectIdentifier(f.manager),
                scene: "scene.other", epoch: f.source.event.epoch!, coverage: .liveNativeSetters, projection: f.original)
            require(!ticket.matches(other), "other scene refused")
            scenarios += 1
        }
        do {
            let f = ReservationFixture(), ticket = try f.reserve()
            ticket.release()
            mustReject("released reservation cannot be reused") { try ticket.beginApply(f.observation(f.original)) }
            require(f.original.targets[f.newID] == nil, "unused reservation creates no actual tab")
            scenarios += 1
        }
        do {
            let f = ReservationFixture(), ticket = try f.reserve()
            try f.commit(ticket)
            mustReject("committed reservation is one-use") { try ticket.beginApply(f.observation(ticket.committed)) }
            scenarios += 1
        }
        do {
            let f = ReservationFixture(), ticket = try f.reserve()
            try f.commit(ticket)
            let otherGroup = UUID()
            let changed = StudyWorkspaceMappingProjection(profileID: f.profile, groupID: otherGroup,
                profileIDs: [f.profile], groupIDs: [otherGroup], activeTabID: f.newID, targets: ticket.persisted.targets)
            require(!ticket.permitsCheckpoint(from: f.saved, to: changed, actual: f.observation(ticket.committed)),
                    "checkpoint cannot hide group change")
            require(!ticket.permitsCheckpoint(from: f.saved, to: ticket.persisted, actual: f.observation(f.original)),
                    "checkpoint cannot echo a desired current tab")
            scenarios += 1
        }
        do {
            let f = ReservationFixture()
            mustReject("reservation cannot reuse an existing ID") {
                _ = try StudyWorkspaceReaderReservation(requestID: UUID(), observation: f.observation(f.original), workspace: f.saved,
                    target: .init(id: f.oldID, target: .init(backend: .otzaria, bookID: 202,
                        workKey: "book:202", readerOwner: ObjectIdentifier(f.newReader))))
            }
            scenarios += 1
        }
        do {
            let f = ReservationFixture()
            mustReject("target must have an actual retained reader object") {
                _ = try StudyWorkspaceReaderReservation(requestID: UUID(), observation: f.observation(f.original), workspace: f.saved,
                    target: .init(id: f.newID, target: .init(backend: .otzaria, bookID: 202, workKey: "book:202", readerOwner: nil)))
            }
            scenarios += 1
        }
        do {
            let f = ReservationFixture(), ticket = try f.reserve()
            try f.commit(ticket)
            f.source.beginChange([.targetIdentity]); f.source.finishChange(available: true)
            require(!ticket.matches(f.observation(ticket.committed)), "revocation after apply prevents late completion")
            require(!ticket.permitsCheckpoint(from: f.saved, to: ticket.persisted, actual: f.observation(ticket.committed)),
                    "revoked ticket cannot suppress checkpoint invalidation")
            scenarios += 1
        }
        print("PASS: \(scenarios) real reservation-policy scenarios / \(checks) assertions; native UI not executed")
    }
}
