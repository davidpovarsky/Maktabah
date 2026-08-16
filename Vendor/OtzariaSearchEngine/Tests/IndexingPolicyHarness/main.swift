import Foundation

private func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        FileHandle.standardError.write(Data("FAIL: \(message)\n".utf8))
        exit(1)
    }
}

// Simulate an engine transaction with good A/B, recoverable bad C and good D.
// The first attempt rolls A/B back when C fails. The source-bound ledger then
// causes the replay to index A/B, skip C and continue through D in one commit.
let books = ["A", "B", "C", "D"]
var ledger: [String: String] = [:]
var committed: [String] = []

func attempt() -> Bool {
    var transaction: [String] = []
    for book in books {
        let identity = "identity-\(book)"
        if let recorded = ledger[book], OtzariaSearchIndexingPolicy.quarantineMatches(
            recordSourceKey: book,
            recordSourceIdentity: recorded,
            sourceKey: book,
            sourceIdentity: identity
        ) {
            continue
        }
        if book == "C" && ledger[book] == nil {
            ledger[book] = identity
            return false // rollback transaction
        }
        transaction.append(book)
    }
    committed = transaction
    return true
}

require(!attempt(), "first transaction must roll back at bad C")
require(committed.isEmpty, "A/B must not leak from a rolled-back transaction")
require(attempt(), "replay must finish after quarantining C")
require(committed == ["A", "B", "D"], "good D must remain reachable after bad C")
require(!OtzariaSearchIndexingPolicy.quarantineMatches(
    recordSourceKey: "C", recordSourceIdentity: "identity-C",
    sourceKey: "C", sourceIdentity: "changed-C"
), "a changed source must leave quarantine and be retried")

require(!OtzariaSearchIndexingPolicy.pdfIsFresh(
    storedLocalIdentity: nil, currentLocalIdentity: "pdf-v1", indexedPathExists: true
), "upstream PDF presence/fingerprint zero cannot prove freshness")
require(OtzariaSearchIndexingPolicy.pdfIsFresh(
    storedLocalIdentity: "pdf-v1", currentLocalIdentity: "pdf-v1", indexedPathExists: true
), "matching local PDF source identity should be reusable")
require(!OtzariaSearchIndexingPolicy.pdfIsFresh(
    storedLocalIdentity: "pdf-v1", currentLocalIdentity: "pdf-v2", indexedPathExists: true
), "changed PDF source identity must reindex")

require(OtzariaSearchIndexingPolicy.canIncludeNextBook(
    booksWritten: 0, documentsWritten: 0, bytesWritten: 0,
    nextDocuments: 25_000, nextBytes: 20_000_000, elapsed: 0,
    maxBooks: 16, maxDocuments: 20_000, maxBytes: 16_777_216, elapsedBudget: 20
), "an oversized first book must be admitted into its isolated batch")
require(OtzariaSearchIndexingPolicy.isOversized(
    documents: 25_000, bytes: 20_000_000, maxDocuments: 20_000, maxBytes: 16_777_216
), "oversized detection must be explicit")

// Commit failure cannot advance a checkpoint. Commit-before-checkpoint crash
// replays the same delete+add transaction and then advances exactly once.
var checkpoint = 2
func commitBatch(nativeCommitSucceeds: Bool, checkpointWriteSucceeds: Bool) -> Bool {
    guard nativeCommitSucceeds else { return false }
    guard checkpointWriteSucceeds else { return false }
    checkpoint = 3
    return true
}
require(!commitBatch(nativeCommitSucceeds: false, checkpointWriteSucceeds: true),
        "native commit failure must fail the batch")
require(checkpoint == 2, "native commit failure must not advance checkpoint")
require(!commitBatch(nativeCommitSucceeds: true, checkpointWriteSucceeds: false),
        "commit-before-checkpoint crash must be reported as incomplete")
require(checkpoint == 2, "missing checkpoint must force replay")
require(commitBatch(nativeCommitSucceeds: true, checkpointWriteSucceeds: true),
        "idempotent replay must converge")
require(checkpoint == 3, "successful replay must advance once")

print("Otzaria indexing policy harness passed: rollback/replay/quarantine/PDF/oversized")
