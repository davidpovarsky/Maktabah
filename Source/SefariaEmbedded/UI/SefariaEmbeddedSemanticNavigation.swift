import Foundation
import ChavrusaUIRoutingHost

/// Fixed navigation destinations over the pinned ORIGINAL ReaderApp. These are
/// not selectors, text locators, queries, scripts or an independent executor.
enum SefariaEmbeddedSemanticTarget: String, Codable, CaseIterable, Sendable {
    case library, topics, learningSchedules, dedication

    var destinationID: String { "native.sefariaEmbedded." + rawValue }
    var isPublicNavigation: Bool { self != .dedication }
    var originalMenu: String {
        switch self {
        case .library: "navigation"
        case .topics: "topic toc"
        case .learningSchedules: "learning schedules"
        case .dedication: "dedication"
        }
    }
    var originalHeaderKey: String {
        switch self {
        case .library: "nav.browse_the_library"
        case .topics: "topics.explore_by_topic"
        case .learningSchedules: "learning_schedules.learning_schedules"
        case .dedication: "about.app_for_ios_and_android"
        }
    }
    /// Read-only witness text from the exact 2fd173a5 original en/he JSON. It is
    /// never rendered by this adapter. The schedules title is also in Library,
    /// so its original page-only description is mandatory as a second witness.
    func originalVisibleTexts(language: String) -> [String]? {
        guard language == "english" || language == "hebrew" else { return nil }
        let hebrew = language == "hebrew"
        switch self {
        case .library: return [hebrew ? "עיון בספריה" : "Browse the Library"]
        case .topics: return [hebrew ? "חיפוש לפי נושאים" : "Explore by Topic"]
        case .learningSchedules:
            return hebrew ? ["לוח לימוד יומי", "מימי קדם חולקה התורה לקטעי קריאה שבועיים שנועדו לסיום הספר כולו במשך תקופת זמן של שנה. בעקבות המנהג הזה התפתחו לאורך השנים סדרי לימוד תקופתיים רבים נוספים, ובעזרתם יכולות קהילות וקבוצות של לומדים ללמוד יחד טקסטים שלמים."]
                : ["Learning Schedules", "Since biblical times, the Torah has been divided into sections which are read each week on a set yearly calendar. Following this practice, many other calendars have been created to help communities of learners work through specific texts together."]
        case .dedication: return [hebrew ? "האפליקציה של ספריא עבור אנדרואיד ו-iOS" : "Sefaria App for iOS and Android"]
        }
    }
}

/// Private native-to-JS handoff identity. Public routing never decodes this type.
struct SefariaEmbeddedSemanticClaim: Codable, Equatable, Sendable {
    let ticketID: UUID
    let requestID: UUID
    let surfaceID: UUID
    let mountID: UUID
    let sceneID: String
    let epoch: UInt64
    let target: SefariaEmbeddedSemanticTarget
    let nonce: UUID

    static let fieldNames: Set<String> = ["ticketID", "requestID", "surfaceID", "mountID", "sceneID", "epoch", "target", "nonce"]
}

/// This record can only be created during the original Core apply. The claim
/// is the linearization point of its one original JS method invocation. No
/// callback, actor hop, I/O or JS execution is performed inside these locks.
final class SefariaEmbeddedSemanticTicket: @unchecked Sendable {
    let claim: SefariaEmbeddedSemanticClaim
    let deadlineUptimeNanoseconds: UInt64
    private let runtime: SefariaEmbeddedSurfaceRuntimeToken
    private let rootSource: NativeComponentSourceObservation
    private let originalSource: NativeComponentSourceObservation
    private let lock = NSLock()
    private var hostToken: UUID?
    private var claimed = false
    private var revoked = false

    init(requestID: UUID, identity: SefariaEmbeddedSurfaceIdentity,
         target: SefariaEmbeddedSemanticTarget, deadlineUptimeNanoseconds: UInt64,
         runtime: SefariaEmbeddedSurfaceRuntimeToken,
         rootSource: NativeComponentSourceObservation,
         originalSource: NativeComponentSourceObservation) throws {
        guard identity.valid, identity.epoch == runtime.observation.epoch,
              rootSource !== originalSource,
              deadlineUptimeNanoseconds > DispatchTime.now().uptimeNanoseconds else {
            throw SefariaRPCError(code: "SEMANTIC_HANDOFF_INVALID", message: "The original navigation admission is unavailable.")
        }
        claim = .init(ticketID: UUID(), requestID: requestID, surfaceID: identity.id,
            mountID: identity.mountID, sceneID: identity.sceneID, epoch: identity.epoch,
            target: target, nonce: UUID())
        self.deadlineUptimeNanoseconds = deadlineUptimeNanoseconds
        self.runtime = runtime; self.rootSource = rootSource; self.originalSource = originalSource
    }

    /// Caller already holds/revalidates the original MainActor source and Core
    /// admission. Only its exact first native host may arm this existing ticket.
    /// This method cannot create/renew a ticket, source or deadline.
    func arm(originalHostToken: UUID) -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard !revoked, !claimed, hostToken == nil,
              DispatchTime.now().uptimeNanoseconds < deadlineUptimeNanoseconds else { return false }
        hostToken = originalHostToken
        return true
    }

    /// Lock order is fixed: runtime -> parent latch -> original/backend latch
    /// -> ticket. Publication/revocation acquires one latch only and never calls
    /// back into this path. There is no external/JS/user callback in this chain.
    fileprivate func consume(_ actual: SefariaEmbeddedSemanticClaim) -> Bool {
        guard actual == claim else { return false }
        return runtime.claimIfCurrent {
            rootSource.claimIfCurrent {
                originalSource.claimIfCurrent {
                    lock.lock(); defer { lock.unlock() }
                    guard !revoked, !claimed, hostToken != nil,
                          DispatchTime.now().uptimeNanoseconds < deadlineUptimeNanoseconds else { return false }
                    claimed = true
                    return true
                }
            }
        }
    }

    /// Cancellation invokes this synchronously, before queued MainActor cleanup.
    /// If the claim already won, keep that fact: original React work may commit.
    func revoke() {
        lock.lock(); defer { lock.unlock() }; revoked = true
    }
    var wasClaimed: Bool {
        lock.lock(); defer { lock.unlock() }; return claimed
    }
    var isArmed: Bool {
        lock.lock(); defer { lock.unlock() }; return hostToken != nil
    }
    var canSupportEvidence: Bool {
        lock.lock(); defer { lock.unlock() }; return claimed && !revoked && hostToken != nil
    }
    func matchesOriginalHost(_ token: UUID) -> Bool {
        lock.lock(); defer { lock.unlock() }; return hostToken == token
    }
}

/// Only the existing native module's closed synchronous export consumes records.
/// The registry lock is released before the source locks; retirement cannot form
/// a reverse lock edge. No public method creates a ticket from a JSON payload.
final class SefariaEmbeddedSemanticHandoffs: @unchecked Sendable {
    static let shared = SefariaEmbeddedSemanticHandoffs()
    private let lock = NSLock()
    private var tickets: [UUID: SefariaEmbeddedSemanticTicket] = [:]

    func register(_ ticket: SefariaEmbeddedSemanticTicket) throws {
        lock.lock(); defer { lock.unlock() }
        guard tickets[ticket.claim.ticketID] == nil else {
            throw SefariaRPCError(code: "SEMANTIC_HANDOFF_DUPLICATE", message: "The original navigation admission is already registered.")
        }
        tickets[ticket.claim.ticketID] = ticket
    }
    func remove(_ ticket: SefariaEmbeddedSemanticTicket, revoke: Bool) {
        if revoke { ticket.revoke() }
        lock.lock(); defer { lock.unlock() }
        if tickets[ticket.claim.ticketID] === ticket { tickets.removeValue(forKey: ticket.claim.ticketID) }
    }
    func claim(_ json: String) -> Bool {
        guard let data = json.data(using: .utf8), data.count <= 4096,
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              Set(object.keys) == SefariaEmbeddedSemanticClaim.fieldNames,
              let actual = try? JSONDecoder().decode(SefariaEmbeddedSemanticClaim.self, from: data) else { return false }
        lock.lock()
        let ticket = tickets[actual.ticketID]
        lock.unlock()
        return ticket?.consume(actual) == true
    }
}

/// Selected ORIGINAL state is observed on an actual JS frame after the original
/// method. It is only one part of acceptance: the real original native text and
/// geometry witness, retained source and canonical receipt remain mandatory.
struct SefariaEmbeddedSemanticProof: Codable, Equatable, Sendable {
    let contract: String
    let claim: SefariaEmbeddedSemanticClaim
    let originalSurface: SefariaEmbeddedSurfaceProof
    let originalMenu: String
    let originalHeaderKey: String
    let interfaceLanguage: String
    let originalRootSelection: Bool
    let originalInstanceRetained: Bool
    let observedAfterOriginalCall: Bool

    func matches(_ ticket: SefariaEmbeddedSemanticTicket, identity: SefariaEmbeddedSurfaceIdentity) -> Bool {
        contract == "chavrusa.original-rn-target.v1" && claim == ticket.claim
            && ticket.canSupportEvidence
            && originalSurface.matches(identity, nonce: claim.nonce)
            && originalMenu == claim.target.originalMenu
            && originalHeaderKey == claim.target.originalHeaderKey
            && claim.target.originalVisibleTexts(language: interfaceLanguage) != nil
            && originalRootSelection && originalInstanceRetained && observedAfterOriginalCall
    }
}

struct SefariaEmbeddedSemanticAcceptanceEvidence: Codable, Sendable {
    let nativeReceiptID: UUID
    let nativeSceneID: String
    let nativeHostToken: UUID
    let runtimeRevision: UInt64
    let actualOriginalViewCount: Int
    let originalTarget: SefariaEmbeddedSemanticProof
}
