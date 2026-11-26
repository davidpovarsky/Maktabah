import Foundation

/// Exact selection of a source-classified commentary linked to one base passage.
/// Neither a title match alone nor an inferred reference establishes this link.
public struct ActionResolveCommentaryQuery: Sendable, Equatable {
    public let baseLocator: ActionTextRef
    public let workRef: ActionWorkRef?
    public let commentaryQuery: String?
    public init(baseLocator: ActionTextRef, workRef: ActionWorkRef? = nil, commentaryQuery: String? = nil) {
        self.baseLocator = baseLocator; self.workRef = workRef; self.commentaryQuery = commentaryQuery
    }
}

/// Metadata projected from the original relationship provider. Text/translation
/// payloads are deliberately excluded; the original reader loads its own content.
public struct ActionCommentaryLink: Sendable, Equatable {
    public let baseLocator: ActionTextRef
    public let destination: ActionReaderDestination
    public let title: String
    public let aliases: [String]
    public init(baseLocator: ActionTextRef, destination: ActionReaderDestination, title: String, aliases: [String] = []) {
        self.baseLocator = baseLocator; self.destination = destination; self.title = title; self.aliases = aliases
    }
}

/// One link from the active library's original relationship provider.
public struct ActionRelatedSource: Codable, Sendable, Hashable {
    public let locator: ActionTextRef
    public let displayRef: String
    public let category: String
    public let relationshipType: String

    public init(locator: ActionTextRef, displayRef: String, category: String, relationshipType: String) {
        self.locator = locator
        self.displayRef = displayRef
        self.category = category
        self.relationshipType = relationshipType
    }
}

public protocol ActionRelatedSourcesPort: Sendable {
    func relatedSources(for locator: ActionTextRef, invocation: ActionPortInvocation) async throws -> [ActionRelatedSource]
}

/// A topic returned by the source relationship provider for a passage.
public struct ActionRelatedTopic: Codable, Sendable, Hashable {
    public let slug: String
    public let titleHe: String?
    public let titleEn: String?

    public init(slug: String, titleHe: String? = nil, titleEn: String? = nil) {
        self.slug = slug
        self.titleHe = titleHe
        self.titleEn = titleEn
    }
}

public protocol ActionRelatedRefsPort: Sendable {
    func relatedRefs(for locator: ActionTextRef, invocation: ActionPortInvocation) async throws -> [ActionTextRef]
}

public protocol ActionRelatedTopicsPort: Sendable {
    func relatedTopics(for locator: ActionTextRef, invocation: ActionPortInvocation) async throws -> [ActionRelatedTopic]
}

/// Optional additive ports preserve existing resolvers and source adapters.
public protocol ActionCommentaryDataPort: Sendable {
    func commentaryLinks(for baseLocator: ActionTextRef, invocation: ActionPortInvocation) async throws -> [ActionCommentaryLink]
}
public protocol ActionCommentaryResolverPort: Sendable {
    func canResolveCommentary() async -> Bool
    func resolveCommentary(_ query: ActionResolveCommentaryQuery, invocation: ActionPortInvocation) async throws -> ActionResolution<ActionReaderDestination>
}

/// Opt-in host seam: retain and bind the exact original reader destination
/// BEFORE Core mints its one-use content grant. The original scene owner owns
/// cleanup after execute returns; no UI receipt can be synthesized here.
public protocol ActionCommentaryUICommandSink: ActionUICommandSink {
    @MainActor func prepareCommentaryReader(_ destination: ActionReaderDestination, context: ActionExecutionContext,
                                            invocation: ActionPortInvocation) async throws
}
