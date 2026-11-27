import Foundation
import HanlinChatCore
import HanlinHostContracts
import HanlinPlatformContracts
import HanlinPresentationKit

struct OtzariaHanlinToolActivity: Codable, Hashable, Identifiable, Sendable {
    let id: String
    let messageID: UUID
    var name: String
    var status: String
    var arguments: String
    var result: String?
    var isActive: Bool
}

struct OtzariaHanlinSourceLink: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    let messageID: UUID
    let destination: URL
}

/// User input/history belongs to this app. SDK metadata is a separate field;
/// a restored transcript never recreates a native lease or execution grant.
struct OtzariaHanlinHistory: Codable, Hashable, Sendable {
    var draft: String
    var selectedProfile: PresentationReference
    var messages: [HanlinChatMessage]
    var presentations: [UUID: MessagePresentationSnapshot]
    var activities: [OtzariaHanlinToolActivity]
    var reasoning: [UUID: String]
    var sources: [OtzariaHanlinSourceLink] = []
    // Optional fields preserve existing saved histories. These are value snapshots,
    // never restored grants or permission to execute a capability.
    var draftCapabilities: [HanlinCapabilityAttachment]? = nil
    var messageCapabilities: [UUID: [HanlinCapabilityAttachment]]? = nil

    func validate(namespace: HanlinConversationNamespace, conversationID: UUID) throws {
        guard draft.utf8.count <= 32_768, messages.count <= 256,
              Set(messages.map(\.id)).count == messages.count,
              messages.allSatisfy({ ["user", "assistant"].contains($0.role) && $0.content.utf8.count <= 262_144 }),
              activities.count <= 256, sources.count <= 256 else { throw HanlinHostError.invalidRecord }
        let users = Set(messages.filter { $0.role == "user" }.map(\.id))
        let sentCapabilities = messageCapabilities ?? [:]
        guard Set(sentCapabilities.keys).isSubset(of: users) else { throw HanlinHostError.invalidRecord }
        for selection in [draftCapabilities ?? []] + Array(sentCapabilities.values) {
            guard selection.count <= 32, Set(selection.map(\.id)).count == selection.count,
                  Set(selection.map(\.selectionKey)).count == selection.count else {
                throw HanlinHostError.invalidRecord
            }
        }
        let assistants = Set(messages.filter { $0.role == "assistant" }.map(\.id))
        guard Set(presentations.keys) == assistants, Set(reasoning.keys).isSubset(of: assistants),
              reasoning.values.allSatisfy({ $0.utf8.count <= 262_144 }),
              activities.allSatisfy({ assistants.contains($0.messageID)
                  && !$0.id.isEmpty && $0.id.utf8.count <= 256 && $0.name.utf8.count <= 256
                  && $0.status.utf8.count <= 128 && $0.arguments.utf8.count <= 65_536
                  && ($0.result?.utf8.count ?? 0) <= 262_144 }) else { throw HanlinHostError.invalidRecord }
        guard Set(sources.map(\.id)).count == sources.count,
              sources.allSatisfy({ assistants.contains($0.messageID)
                  && $0.destination.scheme == "maktabah" && $0.destination.host == "action"
                  && $0.destination.user == nil && $0.destination.password == nil
                  && $0.destination.fragment == nil && $0.destination.absoluteString.utf8.count <= 16_384 }) else {
            throw HanlinHostError.invalidRecord
        }
        let activityKeys = activities.map { $0.messageID.uuidString + ":" + $0.id }
        guard Set(activityKeys).count == activityKeys.count else { throw HanlinHostError.invalidRecord }
        for (id, presentation) in presentations {
            guard presentation.identity == .init(appID: namespace.app, conversationID: conversationID, messageID: id) else {
                throw HanlinHostError.invalidRecord
            }
        }
    }
}

struct OtzariaHanlinConversationSummary: Identifiable, Sendable {
    let id: UUID
    let title: String
    let updatedAt: Date
    let historyRevision: UInt64?
    let metadataRevision: UInt64?
}

/// One original application-owned commit owner, shared by its native scenes.
/// All public calls are synchronous on MainActor: authority cannot change
/// between the scoped lease check and the atomic file commit.
@MainActor
final class OtzariaHanlinConversationStore {
    static let shared = OtzariaHanlinConversationStore(rootURL:
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ChavrusaText/HanlinConversations/v1", isDirectory: true))
    static let maximumBytes = 8 * 1_024 * 1_024
    let rootURL: URL

    private struct Envelope: Codable {
        var formatVersion = 1
        let namespace: HanlinConversationNamespace
        let conversationID: UUID
        let createdAt: Date
        var updatedAt: Date
        var historyRevision: UInt64?
        var history: OtzariaHanlinHistory?
        var metadata: HanlinConversationRecord?
        var deleted = false

        func validate() throws {
            guard formatVersion == 1 else { throw HanlinHostError.unsupportedVersion }
            guard (historyRevision == nil) == (history == nil), createdAt <= updatedAt else {
                throw HanlinHostError.invalidRecord
            }
            if deleted {
                guard history == nil, historyRevision == nil, metadata == nil else { throw HanlinHostError.invalidRecord }
            }
            if let history { try history.validate(namespace: namespace, conversationID: conversationID) }
            if let metadata {
                try metadata.validate()
                guard metadata.namespace == namespace, metadata.conversationID == conversationID else {
                    throw HanlinHostError.invalidRecord
                }
            }
        }
    }

    init(rootURL: URL) { self.rootURL = rootURL }

    private func directory(_ namespace: HanlinConversationNamespace) throws -> URL {
        guard namespace.app == "otzaria",
              let account = UUID(uuidString: namespace.account), account.uuidString == namespace.account,
              let workspace = UUID(uuidString: namespace.workspace), workspace.uuidString == namespace.workspace,
              !namespace.space.isEmpty, namespace.space.utf8.count <= 64,
              namespace.space.utf8.allSatisfy({ (48...57).contains($0) || (65...90).contains($0)
                  || (97...122).contains($0) || $0 == 45 || $0 == 95 }) else { throw HanlinHostError.invalidContext }
        return rootURL.appendingPathComponent(namespace.account, isDirectory: true)
            .appendingPathComponent(namespace.workspace, isDirectory: true)
            .appendingPathComponent(namespace.space, isDirectory: true)
    }

    private func url(_ id: UUID, namespace: HanlinConversationNamespace) throws -> URL {
        try directory(namespace).appendingPathComponent(id.uuidString).appendingPathExtension("json")
    }

    private func read(_ id: UUID, namespace: HanlinConversationNamespace) throws -> Envelope? {
        let source = try url(id, namespace: namespace)
        let data: Data
        do {
            // Only a proven no-such-file from the actual open means missing.
            // A permission/metadata/decode error never becomes a new record.
            let handle = try FileHandle(forReadingFrom: source)
            defer { try? handle.close() }
            let attributes = try source.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
            guard attributes.isRegularFile == true, attributes.isSymbolicLink != true else { throw HanlinHostError.invalidRecord }
            var bytes = Data()
            while bytes.count <= Self.maximumBytes {
                let count = min(65_536, Self.maximumBytes + 1 - bytes.count)
                guard let chunk = try handle.read(upToCount: count), !chunk.isEmpty else { break }
                bytes.append(chunk)
            }
            data = bytes
        } catch let error as NSError where error.domain == NSCocoaErrorDomain
            && [NSFileReadNoSuchFileError, NSFileNoSuchFileError].contains(error.code) {
            return nil
        }
        guard data.count <= Self.maximumBytes else { throw HanlinHostError.storageLimitExceeded }
        let value = try JSONDecoder().decode(Envelope.self, from: data)
        try value.validate()
        guard value.namespace == namespace, value.conversationID == id else { throw HanlinHostError.invalidRecord }
        return value
    }

    private func write(_ value: Envelope) throws {
        try value.validate()
        let destination = try url(value.conversationID, namespace: value.namespace)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let bytes = try encoder.encode(value)
        guard bytes.count <= Self.maximumBytes else { throw HanlinHostError.storageLimitExceeded }
        var attributes: [FileAttributeKey: Any] = [:]
        var options: Data.WritingOptions = [.atomic]
        #if os(iOS)
        attributes[.protectionKey] = FileProtectionType.complete
        options.insert(.completeFileProtection)
        #endif
        try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(),
            withIntermediateDirectories: true, attributes: attributes)
        try bytes.write(to: destination, options: options)
    }

    private func existingOrNew(_ id: UUID, namespace: HanlinConversationNamespace) throws -> Envelope {
        if let value = try read(id, namespace: namespace) {
            guard !value.deleted else { throw HanlinHostError.storeConflict }
            return value
        }
        return .init(namespace: namespace, conversationID: id, createdAt: .now, updatedAt: .now)
    }

    func summaries(namespace: HanlinConversationNamespace) throws -> [OtzariaHanlinConversationSummary] {
        let directory = try directory(namespace)
        let files: [URL]
        do {
            files = try FileManager.default.contentsOfDirectory(at: directory,
                includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles])
        } catch let error as NSError where error.domain == NSCocoaErrorDomain
            && [NSFileReadNoSuchFileError, NSFileNoSuchFileError].contains(error.code) { return [] }
        let records = files.filter { $0.pathExtension == "json" }
        guard records.count <= 1_024 else { throw HanlinHostError.storageLimitExceeded }
        return try records.compactMap { path in
            guard let id = UUID(uuidString: path.deletingPathExtension().lastPathComponent),
                  id.uuidString == path.deletingPathExtension().lastPathComponent else { throw HanlinHostError.invalidRecord }
            guard let value = try read(id, namespace: namespace), !value.deleted,
                  let history = value.history else { return nil }
            let title = history.messages.first(where: { $0.role == "user" })?.content ?? history.draft
            return .init(id: id, title: String(title.prefix(100)), updatedAt: value.updatedAt,
                historyRevision: value.historyRevision, metadataRevision: value.metadata?.revision)
        }.sorted { $0.updatedAt > $1.updatedAt }
    }

    func history(_ id: UUID, namespace: HanlinConversationNamespace) throws -> (OtzariaHanlinHistory, UInt64)? {
        guard let value = try read(id, namespace: namespace), !value.deleted,
              let history = value.history, let revision = value.historyRevision else { return nil }
        return (history, revision)
    }

    func saveHistory(_ history: OtzariaHanlinHistory, id: UUID, namespace: HanlinConversationNamespace,
                     replacing revision: UInt64?) throws -> UInt64 {
        try history.validate(namespace: namespace, conversationID: id)
        var value = try existingOrNew(id, namespace: namespace)
        guard value.historyRevision == revision, revision != UInt64.max else { throw HanlinHostError.storeConflict }
        let next = revision.map { $0 + 1 } ?? 0
        value.history = history; value.historyRevision = next; value.updatedAt = max(value.createdAt, .now)
        try write(value)
        return next
    }

    func loadMetadata(_ id: UUID, namespace: HanlinConversationNamespace) throws -> HanlinConversationRecord? {
        let value = try read(id, namespace: namespace)
        return value?.deleted == true ? nil : value?.metadata
    }

    func saveMetadata(_ record: HanlinConversationRecord, replacing revision: UInt64?) throws {
        try record.validate()
        var value = try existingOrNew(record.conversationID, namespace: record.namespace)
        guard value.metadata?.revision == revision,
              revision.map({ $0 < UInt64.max && record.revision == $0 + 1 }) ?? (record.revision == 0) else {
            throw HanlinHostError.storeConflict
        }
        value.metadata = record; value.updatedAt = max(value.createdAt, .now)
        try write(value)
    }

    /// The SDK owns only its metadata field; host user history is not its draft.
    func deleteMetadata(_ id: UUID, namespace: HanlinConversationNamespace, replacing revision: UInt64) throws {
        guard var value = try read(id, namespace: namespace), !value.deleted,
              value.metadata?.revision == revision else { throw HanlinHostError.storeConflict }
        value.metadata = nil; value.updatedAt = max(value.createdAt, .now)
        try write(value)
    }

    /// Explicit user history deletion leaves a content-free tombstone so a
    /// delayed first SDK save cannot recreate a deleted conversation.
    func deleteConversation(_ summary: OtzariaHanlinConversationSummary, namespace: HanlinConversationNamespace) throws {
        guard var value = try read(summary.id, namespace: namespace), !value.deleted,
              value.metadata?.revision == summary.metadataRevision,
              value.historyRevision == summary.historyRevision else { throw HanlinHostError.storeConflict }
        value.deleted = true; value.history = nil; value.historyRevision = nil; value.metadata = nil
        value.updatedAt = max(value.createdAt, .now)
        try write(value)
    }
}

/// The real SDK and this presentation share this exact native-session lease.
/// No stale SDK callback may write after dismissal, source change or replacement.
@MainActor
final class OtzariaHanlinScopedConversationStore: HanlinConversationStore {
    private let identity: HanlinHostSession
    private let store: OtzariaHanlinConversationStore
    private let validateOwner: @MainActor () throws -> Void
    private var revoked = false

    init(identity: HanlinHostSession, store: OtzariaHanlinConversationStore,
         validateOwner: @escaping @MainActor () throws -> Void) {
        self.identity = identity; self.store = store; self.validateOwner = validateOwner
    }
    func revoke() { revoked = true }
    private func validate(_ id: UUID, namespace: HanlinConversationNamespace) throws {
        guard !revoked, id == identity.conversationID, namespace == identity.context.namespace else {
            throw HanlinHostError.staleContext
        }
        try validateOwner()
    }
    func load(_ id: UUID, namespace: HanlinConversationNamespace) throws -> HanlinConversationRecord? {
        try validate(id, namespace: namespace)
        return try store.loadMetadata(id, namespace: namespace)
    }
    func save(_ record: HanlinConversationRecord, replacing revision: UInt64?) throws {
        try validate(record.conversationID, namespace: record.namespace)
        try store.saveMetadata(record, replacing: revision)
    }
    func delete(_ id: UUID, namespace: HanlinConversationNamespace, replacing revision: UInt64) throws {
        try validate(id, namespace: namespace)
        try store.deleteMetadata(id, namespace: namespace, replacing: revision)
    }
    func history() throws -> (OtzariaHanlinHistory, UInt64)? {
        try validate(identity.conversationID, namespace: identity.context.namespace)
        return try store.history(identity.conversationID, namespace: identity.context.namespace)
    }
    func saveHistory(_ history: OtzariaHanlinHistory, replacing revision: UInt64?) throws -> UInt64 {
        try validate(identity.conversationID, namespace: identity.context.namespace)
        return try store.saveHistory(history, id: identity.conversationID, namespace: identity.context.namespace, replacing: revision)
    }
}
