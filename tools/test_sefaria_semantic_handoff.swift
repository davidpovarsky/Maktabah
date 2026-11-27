// Appended to exact original production types by the source-only runner.
// Observation/Foundation/locks/runtime/ticket code are real; UIKit/Core grant
// issuance/React execution are outside this executable and never claimed.
import Dispatch

@Observable @MainActor private final class SemanticOriginalState {
    var selection = 0
    var backendGeneration = 1
}
@MainActor private final class SemanticFixture {
    let original = SemanticOriginalState()
    let rootPublications = MaktabahNativeRootPublicationSource()
    let originalTab = SemanticOriginalTab()
    let originalMode = SemanticOriginalMode()
    let windowSource = MaktabahNativeWindowSource()
    let originalView = UIView()
    let originalWindow = UIWindow()
    let authority = SefariaRPCSessionEpoch()
    let root: NativeComponentSourceObservation
    let feature: NativeComponentSourceObservation
    let runtime: SefariaEmbeddedSurfaceRuntimeToken
    let ticket: SefariaEmbeddedSemanticTicket
    let registry = SefariaEmbeddedSemanticHandoffs()
    let identity: SefariaEmbeddedSurfaceIdentity
    let host = UUID()
    var selection: Binding<iOSTab> {
        rootPublications.selectionBinding(.init(get: { self.originalTab.value }, set: { value, _ in self.originalTab.value = value }))
    }
    var json: String { get throws { String(decoding: try JSONEncoder().encode(ticket.claim), as: UTF8.self) } }
    init(arm: Bool = true, target: SefariaEmbeddedSemanticTarget = .library, maximumRootRevision: Bool = false) throws {
        let original = self.original
        let rootPublications = self.rootPublications
        let originalMode = self.originalMode, windowSource = self.windowSource
        originalView.window = originalWindow
        _ = windowSource.observe(originalWindow, from: originalView)
        if maximumRootRevision { rootPublications.seedMaximumRevisionForControl() }
        root = NativeComponentSourceObservation(publications: [rootPublications.nativePublication,
            originalMode.nativeModePresentationPublication, windowSource.nativePublication]) {
            _ = original.selection
            _ = rootPublications.selectionRevision
            _ = rootPublications.settingsRevision
            _ = originalMode.currentMode; _ = originalMode.nativeModePresentationRevision
        }
        feature = NativeComponentSourceObservation { _ = original.backendGeneration }
        authority.update { $0.ready = true; $0.listeners = true; $0.transport = true }
        runtime = try authority.retainSurface()
        identity = .init(id: UUID(), mountID: UUID(), sceneID: "original-native-scene", epoch: runtime.observation.epoch)
        ticket = try .init(requestID: UUID(), identity: identity, target: target,
            deadlineUptimeNanoseconds: DispatchTime.now().uptimeNanoseconds + 20_000_000_000,
            runtime: runtime, rootSource: root, originalSource: feature)
        try registry.register(ticket)
        if arm { precondition(ticket.arm(originalHostToken: host)) }
    }
}
private final class SemanticCount: Sendable { let value = Mutex(0) }
private final class SemanticBoolean: Sendable { let value = Mutex<Bool?>(nil) }
private struct SemanticControlError: Error { let message: String }
private struct SemanticControlResult: Codable { let name: String; let passed: Bool; let error: String? }
private struct SemanticControlReport: Codable {
    let scope: String; let passed: Int; let failed: Int; let results: [SemanticControlResult]
}
@main private struct SemanticHandoffControls {
    @MainActor private static var results: [SemanticControlResult] = []
    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        guard condition() else { throw SemanticControlError(message: message) }
    }
    @MainActor private static func test(_ name: String, _ body: @MainActor () throws -> Void) {
        do { try body(); results.append(.init(name: name, passed: true, error: nil)) }
        catch { results.append(.init(name: name, passed: false, error: String(describing: error))) }
    }
    @MainActor private static func altered(_ fixture: SemanticFixture, _ key: String, _ value: Any) throws -> String {
        let data = try JSONEncoder().encode(fixture.ticket.claim)
        var object = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        object[key] = value
        return String(decoding: try JSONSerialization.data(withJSONObject: object), as: UTF8.self)
    }
    @MainActor static func main() {
        test("one exact armed ticket consumes once") {
            let f = try SemanticFixture(), json = try f.json
            try expect(f.registry.claim(json), "actual admitted claim rejected")
            try expect(!f.registry.claim(json), "same ticket executed twice")
            try expect(f.ticket.wasClaimed && f.ticket.canSupportEvidence, "claim state lost")
        }
        test("unarmed cold host cannot claim") {
            let f = try SemanticFixture(arm: false), json = try f.json
            try expect(!f.registry.claim(json), "claim preceded actual original host")
            try expect(f.ticket.arm(originalHostToken: f.host), "first host failed")
            try expect(f.registry.claim(json), "same original first host could not consume")
        }
        test("armed host cannot be replaced or rearmed") {
            let f = try SemanticFixture()
            try expect(!f.ticket.arm(originalHostToken: UUID()), "foreign host rearmed ticket")
            try expect(f.ticket.matchesOriginalHost(f.host), "original host changed")
        }
        test("cancellation before queued claim has zero consumption") {
            let f = try SemanticFixture(), json = try f.json; f.ticket.revoke()
            try expect(!f.registry.claim(json) && !f.ticket.wasClaimed, "cancelled queued effect consumed")
        }
        test("cancellation before cold host cannot later arm") {
            let f = try SemanticFixture(arm: false); f.ticket.revoke()
            try expect(!f.ticket.arm(originalHostToken: f.host), "cancelled ticket rearmed")
        }
        test("after-claim cancellation retains possible effect and rejects evidence") {
            let f = try SemanticFixture(), json = try f.json
            try expect(f.registry.claim(json), "initial claim failed"); f.ticket.revoke()
            try expect(f.ticket.wasClaimed, "committed-effect history erased")
            try expect(!f.ticket.canSupportEvidence && !f.registry.claim(json), "cancelled effect became receipt/replay")
        }
        test("actual original root wrapper publishes equal State write synchronously") {
            let f = try SemanticFixture(), json = try f.json
            f.selection.wrappedValue = .library
            try expect(f.originalTab.value == .library && f.rootPublications.selectionRevision == 1,
                       "the actual original equal-write wrapper did not advance")
            try expect(!f.registry.claim(json), "original equal publication was accepted")
        }
        test("actual original root wrapper catches State A B A before JS claim") {
            let f = try SemanticFixture(), json = try f.json
            f.selection.wrappedValue = .search; f.selection.wrappedValue = .library
            try expect(f.rootPublications.selectionRevision == 2 && f.originalTab.value == .library,
                       "the actual original A B A setter sequence changed")
            try expect(!f.registry.claim(json), "original State ABA revived a ticket")
        }
        test("actual original root overflow permanently closes claim") {
            let f = try SemanticFixture(maximumRootRevision: true), json = try f.json
            try expect(f.rootPublications.selectionRevision == .max, "overflow fixture was not prepared before capture")
            f.selection.wrappedValue = .library
            try expect(f.rootPublications.selectionRevision == nil, "original counter recycled an exhausted revision")
            try expect(!f.registry.claim(json), "overflow revived a ticket")
            f.selection.wrappedValue = .search
            try expect(f.rootPublications.selectionRevision == nil && !f.registry.claim(json), "exhaustion was reset")
        }
        test("actual original root write and JS-thread claim preserve one linearization") {
            for _ in 0..<32 {
                let f = try SemanticFixture(), json = try f.json, group = DispatchGroup(), registry = f.registry
                let outcome = SemanticBoolean()
                group.enter()
                DispatchQueue.global().async { outcome.value.withLock { $0 = registry.claim(json) }; group.leave() }
                f.selection.wrappedValue = .library
                try expect(group.wait(timeout: .now() + 2) == .success, "original State publisher and JS claim deadlocked")
                guard let won = outcome.value.withLock({ $0 }) else { throw SemanticControlError(message: "JS claim did not finish") }
                try expect(f.rootPublications.selectionRevision == 1 && !f.registry.claim(json), "late JS claim survived source publication")
                try expect(f.ticket.wasClaimed == won, "claim history disagrees with actual race outcome")
            }
        }
        test("original parent observation catches real A B A") {
            let f = try SemanticFixture(), json = try f.json; f.original.selection = 1; f.original.selection = 0
            try expect(!f.registry.claim(json), "original parent ABA borrowed old source")
        }
        test("actual original mode setter equal write retires the claim") {
            let f = try SemanticFixture(), json = try f.json
            f.originalMode.currentMode = .viewer
            try expect(f.originalMode.nativeModePresentationRevision == 1, "original mode counter did not publish")
            try expect(!f.registry.claim(json), "equal original mode write escaped its retained claim observation")
        }
        test("actual original mode setter A B A retires the claim") {
            let f = try SemanticFixture(), json = try f.json
            f.originalMode.currentMode = .search; f.originalMode.currentMode = .viewer
            try expect(f.originalMode.nativeModePresentationRevision == 2 && !f.registry.claim(json), "original mode ABA revived source")
        }
        test("ignored original mode counter does not lose nested setter publications") {
            let f = try SemanticFixture(), writes = SemanticWrites()
            withObservationTracking { _ = f.originalMode.nativeModePresentationRevision } onChange: {
                MainActor.assumeIsolated {
                    if !writes.reentered {
                        writes.reentered = true; writes.count += 1; f.originalMode.currentMode = .viewer
                    }
                }
            }
            writes.count += 1; f.originalMode.currentMode = .search
            try expect(!writes.reentered && f.originalMode.nativeModePresentationRevision == UInt64(writes.count),
                       "counter callback reentered/lost publication: writes=\(writes.count) revision=\(String(describing: f.originalMode.nativeModePresentationRevision))")
        }
        test("original mode value observer reentry remains independently counted") {
            let f = try SemanticFixture(), writes = SemanticWrites(), json = try f.json
            withObservationTracking { _ = f.originalMode.currentMode } onChange: {
                MainActor.assumeIsolated {
                    if !writes.reentered {
                        writes.reentered = true; writes.count += 1; f.originalMode.currentMode = .viewer
                    }
                }
            }
            writes.count += 1; f.originalMode.currentMode = .search
            try expect(writes.count == 2 && f.originalMode.nativeModePresentationRevision == 2,
                       "original value callback lost a setter publication")
            try expect(!f.registry.claim(json), "nested original mode publication escaped source latch")
        }
        test("nonobservable original root counter cannot reenter its unfinished increment") {
            let f = try SemanticFixture(), writes = SemanticWrites()
            withObservationTracking { _ = f.rootPublications.selectionRevision } onChange: {
                MainActor.assumeIsolated {
                    if !writes.reentered {
                        writes.reentered = true; writes.count += 1; f.selection.wrappedValue = .library
                    }
                }
            }
            writes.count += 1; f.selection.wrappedValue = .search
            try expect(!writes.reentered && f.rootPublications.selectionRevision == UInt64(writes.count),
                       "root counter callback reentered/lost publication: writes=\(writes.count) revision=\(String(describing: f.rootPublications.selectionRevision))")
        }
        test("actual original Binding setter reentry still advances two complete publications") {
            let f = try SemanticFixture(), writes = SemanticWrites(), json = try f.json
            let original = Binding<iOSTab>(get: { f.originalTab.value }, set: { value, _ in
                f.originalTab.value = value
                if !writes.reentered {
                    writes.reentered = true; writes.count += 1; f.selection.wrappedValue = .library
                }
            })
            let wrapped = f.rootPublications.selectionBinding(original)
            writes.count += 1; wrapped.wrappedValue = .search
            try expect(writes.count == 2 && f.rootPublications.selectionRevision == 2 && f.originalTab.value == .library,
                       "original root setter/counter ordering changed")
            try expect(!f.registry.claim(json), "reentrant original root setter escaped source latch")
        }
        test("nonobservable original window counter cannot lose nested observe publications") {
            let f = try SemanticFixture(), writes = SemanticWrites(), foreign = UIView(), window = UIWindow()
            foreign.window = window
            let before = f.windowSource.controlOriginalRevision!
            withObservationTracking { _ = f.windowSource.controlOriginalRevision } onChange: {
                MainActor.assumeIsolated {
                    if !writes.reentered {
                        writes.reentered = true; writes.count += 1
                        _ = f.windowSource.observe(f.originalWindow, from: f.originalView)
                    }
                }
            }
            writes.count += 1; _ = f.windowSource.observe(window, from: foreign)
            try expect(!writes.reentered && f.windowSource.controlOriginalRevision == before + UInt64(writes.count),
                       "window counter callback reentered/lost publication: writes=\(writes.count) revision=\(String(describing: f.windowSource.controlOriginalRevision))")
        }
        test("closed registration precedes actual original read reentry") {
            let f = try SemanticFixture()
            let observation = NativeComponentSourceObservation(publications: [f.rootPublications.nativePublication]) {
                f.selection.wrappedValue = .library
            }
            var refused = false
            do { try observation.validate() } catch { refused = true }
            try expect(refused && !observation.claimIfCurrent({ true }), "getter reentry preceded source registration")
        }
        test("closed publisher retains only weak latches and prunes expired entries") {
            let publication = NativeComponentSourcePublication()
            weak var weakObservation: NativeComponentSourceObservation?
            do {
                let observation = NativeComponentSourceObservation(publications: [publication]) {}
                weakObservation = observation
                try expect(publication.controlRetainedCount == 1, "initial source registration missing")
            }
            try expect(weakObservation == nil, "publisher retained an ended request")
            let next = NativeComponentSourceObservation(publications: [publication]) {}
            try expect(publication.controlRetainedCount == 1, "expired weak entries were not pruned")
            publication.invalidateRetainedSources()
            try expect(publication.controlRetainedCount == 0 && !next.claimIfCurrent({ true }), "publication did not consume all retained latches")
        }
        test("actual Session attachment replacement and ABA retire original root before reuse") {
            let f = try SemanticFixture(), json = try f.json, session = SemanticWindowSession()
            session.attachWindowSource(f.windowSource)
            session.sefariaRootSources[UUID()] = f.root
            session.attachWindowSource(MaktabahNativeWindowSource())
            session.attachWindowSource(f.windowSource)
            try expect(session.windowSource === f.windowSource && session.windowSourceRevision == 3,
                       "actual original attachment revision did not retain both replacements")
            try expect(!f.registry.claim(json), "restored Session source borrowed an older claim")
        }
        test("actual weak original window source observer compiles and catches window ABA") {
            let f = try SemanticFixture(), json = try f.json, foreign = UIWindow()
            f.originalView.window = foreign
            try expect(f.windowSource.observe(foreign, from: f.originalView), "actual source did not publish window replacement")
            f.originalView.window = f.originalWindow
            try expect(f.windowSource.observe(f.originalWindow, from: f.originalView), "actual source did not publish window restoration")
            try expect(!f.registry.claim(json), "original window ABA revived a ticket")
        }
        test("actual weak original source view observer catches view ABA") {
            let f = try SemanticFixture(), json = try f.json, foreign = UIView()
            foreign.window = f.originalWindow
            try expect(f.windowSource.observe(f.originalWindow, from: foreign), "source view replacement did not publish")
            try expect(f.windowSource.observe(f.originalWindow, from: f.originalView), "source view restoration did not publish")
            try expect(!f.registry.claim(json), "source view ABA revived ticket")
        }
        test("actual original window detach refuses but stale foreign detach preserves current owner") {
            let f = try SemanticFixture(), json = try f.json, foreign = UIView()
            try expect(!f.windowSource.observe(nil, from: foreign), "foreign old view detached current owner")
            try expect(f.registry.claim(json), "stale foreign detach retired actual current source")
            let detached = try SemanticFixture(), later = try detached.json
            try expect(detached.windowSource.observe(nil, from: detached.originalView), "actual original detach was not published")
            try expect(!detached.registry.claim(later), "detached original view could claim")
        }
        test("unchanged actual original window publication does not fabricate a new lifetime") {
            let f = try SemanticFixture(), json = try f.json
            try expect(!f.windowSource.observe(f.originalWindow, from: f.originalView), "equal original identity published a replacement")
            try expect(f.registry.claim(json), "unchanged root was unnecessarily retired")
        }
        test("original backend/feature observation catches real A B A") {
            let f = try SemanticFixture(), json = try f.json; f.original.backendGeneration = 2; f.original.backendGeneration = 1
            try expect(!f.registry.claim(json), "backend ABA borrowed old source")
        }
        test("manual original publisher invalidation is synchronous") {
            let f = try SemanticFixture(), json = try f.json; f.feature.invalidate()
            try expect(!f.registry.claim(json), "manual publisher invalidation was delayed")
        }
        test("runtime publication with unchanged values retires retained token") {
            let f = try SemanticFixture(), json = try f.json; f.authority.update { $0.ready = true }
            try expect(!f.registry.claim(json), "runtime revision was ignored")
        }
        test("runtime ready A B A cannot restore ticket") {
            let f = try SemanticFixture(), json = try f.json
            f.authority.update { $0.ready = false }; f.authority.update { $0.ready = true }
            try expect(!f.registry.claim(json), "runtime ABA accepted")
        }
        test("native transition begins before actor update and blocks claim") {
            let f = try SemanticFixture(), json = try f.json; f.authority.beginTransition()
            try expect(!f.registry.claim(json), "queued runtime transition left claim open")
            f.authority.endTransition(); try expect(!f.registry.claim(json), "ended transition rearmed old ticket")
        }
        test("releasing exact source membership before claim refuses") {
            let f = try SemanticFixture(), json = try f.json; f.registry.remove(f.ticket, revoke: true)
            try expect(!f.registry.claim(json) && !f.ticket.wasClaimed, "released request consumed")
        }
        test("completed ticket membership removal preserves historical claim only") {
            let f = try SemanticFixture(), json = try f.json
            try expect(f.registry.claim(json), "claim failed"); f.registry.remove(f.ticket, revoke: false)
            try expect(!f.registry.claim(json) && f.ticket.wasClaimed, "completed record recreated authority")
        }
        test("duplicate native registry registration is rejected") {
            let f = try SemanticFixture(); var refused = false
            do { try f.registry.register(f.ticket) } catch { refused = true }
            try expect(refused, "duplicate ticket replaced owner")
        }
        for (key, value) in [("ticketID", UUID().uuidString), ("requestID", UUID().uuidString),
                             ("surfaceID", UUID().uuidString), ("mountID", UUID().uuidString),
                             ("nonce", UUID().uuidString), ("sceneID", "foreign-scene"),
                             ("target", "topics")] {
            test("exact private " + key + " rejects replacement") {
                let f = try SemanticFixture(), json = try altered(f, key, value)
                try expect(!f.registry.claim(json) && !f.ticket.wasClaimed, "changed " + key + " consumed")
            }
        }
        test("wrong runtime epoch refuses") {
            let f = try SemanticFixture(), json = try altered(f, "epoch", 999)
            try expect(!f.registry.claim(json), "wrong epoch consumed")
        }
        test("extra command field is rejected before lookup") {
            let f = try SemanticFixture(), json = try altered(f, "script", "arbitrary()")
            try expect(!f.registry.claim(json), "extra executable field accepted")
        }
        test("missing or mistyped ticket is rejected") {
            let f = try SemanticFixture()
            try expect(!f.registry.claim("{}"), "empty request accepted")
            let json = try altered(f, "ticketID", 17)
            try expect(!f.registry.claim(json), "mistyped ticket accepted")
        }
        test("one source latch cannot be nested into itself") {
            let f = try SemanticFixture(); var refused = false
            do {
                _ = try SefariaEmbeddedSemanticTicket(requestID: UUID(), identity: f.identity, target: .topics,
                    deadlineUptimeNanoseconds: .max, runtime: f.runtime, rootSource: f.root, originalSource: f.root)
            } catch { refused = true }
            try expect(refused, "same nonrecursive latch could be reacquired")
        }
        test("expired original admission cannot create a ticket") {
            let f = try SemanticFixture(); var refused = false
            do {
                _ = try SefariaEmbeddedSemanticTicket(requestID: UUID(), identity: f.identity, target: .topics,
                    deadlineUptimeNanoseconds: 1, runtime: f.runtime, rootSource: f.root, originalSource: f.feature)
            } catch { refused = true }
            try expect(refused, "expired admission minted an effect")
        }
        test("foreign retained runtime cannot be paired with identity") {
            let f = try SemanticFixture(); var refused = false
            let identity = SefariaEmbeddedSurfaceIdentity(id: UUID(), mountID: UUID(), sceneID: "scene", epoch: 999)
            do {
                _ = try SefariaEmbeddedSemanticTicket(requestID: UUID(), identity: identity, target: .topics,
                    deadlineUptimeNanoseconds: .max, runtime: f.runtime, rootSource: f.root, originalSource: f.feature)
            } catch { refused = true }
            try expect(refused, "wrong runtime identity was admitted")
        }
        test("JS-thread claim completes while MainActor is blocked") {
            let f = try SemanticFixture(), json = try f.json, registry = f.registry
            let result = SemanticBoolean(), done = DispatchSemaphore(value: 0)
            DispatchQueue.global().async { result.value.withLock { $0 = registry.claim(json) }; done.signal() }
            try expect(done.wait(timeout: .now() + 2) == .success, "claim required MainActor callback")
            try expect(result.value.withLock { $0 } == true, "closed off-main claim failed")
        }
        test("concurrent reentry consumes one original effect") {
            let f = try SemanticFixture(), json = try f.json, registry = f.registry
            let successes = SemanticCount()
            DispatchQueue.concurrentPerform(iterations: 32) { _ in
                if registry.claim(json) { successes.value.withLock { $0 += 1 } }
            }
            try expect(successes.value.withLock { $0 } == 1, "parallel callbacks consumed more than once")
        }
        test("simultaneous cancel and claim has one truthful linearization") {
            for _ in 0..<32 {
                let f = try SemanticFixture(), json = try f.json, registry = f.registry, ticket = f.ticket
                let successes = SemanticCount()
                DispatchQueue.concurrentPerform(iterations: 2) { index in
                    if index == 0 { ticket.revoke() }
                    else if registry.claim(json) { successes.value.withLock { $0 += 1 } }
                }
                let calls = successes.value.withLock { $0 }
                try expect((calls == 0 || calls == 1) && ticket.wasClaimed == (calls == 1), "effect history disagrees with claim")
                try expect(!ticket.canSupportEvidence, "post-cancel effect became successful evidence")
                try expect(!registry.claim(json), "cancel/claim race created another effect")
            }
        }
        test("finite target labels preserve original schedules disambiguation") {
            try expect(SefariaEmbeddedSemanticTarget.allCases.count == 4, "unexpected new target")
            try expect(!SefariaEmbeddedSemanticTarget.dedication.isPublicNavigation, "dedication became public")
            for language in ["english", "hebrew"] {
                try expect(SefariaEmbeddedSemanticTarget.learningSchedules.originalVisibleTexts(language: language)?.count == 2,
                           "Library preview title could masquerade as schedules")
            }
            try expect(SefariaEmbeddedSemanticTarget.topics.originalVisibleTexts(language: "unknown") == nil,
                       "unverified language witness accepted")
        }
        let report = SemanticControlReport(scope: "actual original Observation/runtime/Swift ticket source; UIKit/Core/JS boundaries, no app/native claim",
            passed: results.filter(\.passed).count, failed: results.filter { !$0.passed }.count, results: results)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        print(String(decoding: try! encoder.encode(report), as: UTF8.self))
        if report.failed > 0 { exit(1) }
    }
}
