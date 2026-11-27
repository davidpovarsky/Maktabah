#!/usr/bin/env python3
"""Compile-time source extraction for the actual search preview task.

This is an actor-isolated component control, never a SwiftUI/UI acceptance run.
Only the provider transport, unrelated model fields and state storage are small
fixtures. Both task bodies and SearchPreviewSegment come verbatim from source.
"""
import hashlib
import json
from pathlib import Path
import sys

PRELUDE = r'''
import Foundation
import Darwin

enum FixtureBackend: Sendable { case otzaria, sefaria }
struct FixtureLocator: Sendable { let backend: FixtureBackend; let persistenceKey: String }
struct LibraryTextVersionSelection: Sendable { let title: String; let language: String }
struct FixtureSegment: Sendable { let locator: FixtureLocator; let primaryText: String; let translation: String? }
struct LibraryTextSection: Sendable { let segments: [FixtureSegment] }
struct FixtureItem {
    let backendLocator: FixtureLocator?
    let resultLanguage: String?
    let versionTitle: String?
    let attributedText: NSAttributedString
}
extension String { var readerPlainText: String { self } }
enum FixtureError: LocalizedError {
    case stale, current
    var errorDescription: String? { self == .stale ? "stale-provider-failure" : "current-provider-failure" }
}

@MainActor final class BackendCoordinator {
    static let shared = BackendCoordinator()
    var requests: [LibraryTextVersionSelection?] = []
    var pending: [Int: CheckedContinuation<LibraryTextSection, any Error>] = [:]
    func section(at locator: FixtureLocator) async throws -> LibraryTextSection {
        try await request(nil)
    }
    func section(at locator: FixtureLocator, version: LibraryTextVersionSelection) async throws -> LibraryTextSection {
        try await request(version)
    }
    private func request(_ version: LibraryTextVersionSelection?) async throws -> LibraryTextSection {
        requests.append(version)
        let id = requests.count
        // Deliberately retain the real continuation after Task.cancel(). This
        // models a provider which ignores cancellation or throws another error.
        return try await withCheckedThrowingContinuation { pending[id] = $0 }
    }
    func waitForRequests(_ count: Int) async {
        for _ in 0..<2_000 {
            if requests.count >= count { return }
            try? await Task.sleep(for: .milliseconds(1))
        }
        fatalError("Controlled provider request did not arrive")
    }
    func reset() {
        precondition(pending.isEmpty, "Every held provider completion must be resolved")
        requests.removeAll()
    }
    func complete(_ id: Int, _ result: Result<LibraryTextSection, any Error>) {
        guard let continuation = pending.removeValue(forKey: id) else { fatalError("Unknown held request") }
        continuation.resume(with: result)
    }
}

@MainActor private final class PreviewProbe {
    var item = FixtureItem(backendLocator: .init(backend: .otzaria, persistenceKey: "fixture|same-source"),
                           resultLanguage: nil, versionTitle: nil, attributedText: NSAttributedString(string: "snippet"))
    var fullSegments: [SearchPreviewSegment] = []
    var previewError: String?
    var isLoading = false
    var activePreviewRequestID: UUID?

    func load() async {
__ACTUAL_TASK_BODY__
    }
}

__ACTUAL_SEGMENT_DECLARATION__

@main private struct RaceControl {
    @MainActor static var observations: [[String: Any]] = []
    @MainActor static let provider = BackendCoordinator.shared

    static func section(_ text: String) -> LibraryTextSection {
        .init(segments: [.init(locator: .init(backend: .otzaria, persistenceKey: "fixture|same-source"),
                              primaryText: text, translation: nil)])
    }
    @MainActor static func observe(_ name: String, _ passed: Bool, _ probe: PreviewProbe) {
        observations.append(["name": name, "passed": passed, "loading": probe.isLoading,
                             "error": probe.previewError as Any? ?? NSNull(),
                             "segments": probe.fullSegments.map(\.primary)])
    }

    @MainActor static func staleCompletion(_ name: String, cancel: Bool,
        success: Bool, cancellationError: Bool = false, newCompletesFirst: Bool) async {
        provider.reset()
        let probe = PreviewProbe()
        let stale = Task { await probe.load() }
        await provider.waitForRequests(1)
        if cancel { stale.cancel() }
        let current = Task { await probe.load() }
        await provider.waitForRequests(2)
        if newCompletesFirst {
            provider.complete(2, .success(section("current body")))
            await current.value
        }
        let staleResult: Result<LibraryTextSection, any Error> = success
            ? .success(section("stale body"))
            : .failure(cancellationError ? CancellationError() : FixtureError.stale)
        provider.complete(1, staleResult)
        await stale.value
        observe(name + ": stale completion cannot publish an error", probe.previewError == nil, probe)
        observe(name + ": stale completion cannot change current loading", probe.isLoading == !newCompletesFirst, probe)
        observe(name + ": stale completion cannot replace current segments",
                probe.fullSegments.map(\.primary) == (newCompletesFirst ? ["current body"] : []), probe)
        if !newCompletesFirst {
            provider.complete(2, .success(section("current body")))
            await current.value
        }
        observe(name + ": current completion still publishes its complete state",
                probe.fullSegments.map(\.primary) == ["current body"] && !probe.isLoading && probe.previewError == nil, probe)
    }

    @MainActor static func activeFailure(_ cancellation: Bool) async {
        provider.reset()
        let probe = PreviewProbe()
        let task = Task { await probe.load() }
        await provider.waitForRequests(1)
        provider.complete(1, .failure(cancellation ? CancellationError() : FixtureError.current))
        await task.value
        observe(cancellation ? "Current provider cancellation completes its spinner" : "Current ordinary error completes its spinner",
                !probe.isLoading, probe)
        observe(cancellation ? "Current provider cancellation publishes no invented error" : "Current ordinary error remains visible",
                cancellation ? probe.previewError == nil : probe.previewError == "current-provider-failure", probe)
    }

    @MainActor static func cancelledBeforeStart() async {
        provider.reset()
        let probe = PreviewProbe()
        probe.fullSegments = [.init(id: "fixture|existing", primary: "existing body", translation: nil)]
        var completed = false
        let task = Task { await probe.load(); completed = true }
        task.cancel() // No suspension has occurred, so the actor-isolated body has not begun.
        for _ in 0..<2_000 {
            if completed || !provider.pending.isEmpty { break }
            try? await Task.sleep(for: .milliseconds(1))
        }
        if provider.pending[1] != nil { provider.complete(1, .success(section("unwanted body"))) }
        await task.value
        observe("Already-cancelled task does not contact the provider", provider.requests.isEmpty, probe)
        observe("Already-cancelled task preserves the existing complete state",
                probe.fullSegments.map(\.primary) == ["existing body"] && !probe.isLoading && probe.previewError == nil, probe)
    }

    @MainActor static func activeVersionAndEmpty() async {
        provider.reset()
        let probe = PreviewProbe()
        probe.item = .init(backendLocator: .init(backend: .sefaria, persistenceKey: "sefaria|Psalms 35:17"),
                           resultLanguage: "en", versionTitle: "Selected actual edition", attributedText: NSAttributedString(string: "snippet"))
        let task = Task { await probe.load() }
        await provider.waitForRequests(1)
        let selectedVersion = provider.requests[0]
        observe("Original selected-version title and language are forwarded unchanged",
                selectedVersion?.title == "Selected actual edition" && selectedVersion?.language == "en", probe)
        provider.complete(1, .success(section("current selected edition")))
        await task.value
        observe("Current selected edition still renders", probe.fullSegments.map(\.primary) == ["current selected edition"] && !probe.isLoading, probe)
        provider.reset()
        let empty = Task { await probe.load() }
        await provider.waitForRequests(1)
        provider.complete(1, .success(.init(segments: [])))
        await empty.value
        observe("Current empty result retains its original error and finishes loading",
                probe.fullSegments.isEmpty && probe.previewError?.isEmpty == false && !probe.isLoading, probe)
    }

    @MainActor static func main() async throws {
        await staleCompletion("Cancelled ordinary error while current waits", cancel: true, success: false, newCompletesFirst: false)
        await staleCompletion("Cancelled ordinary error after current success", cancel: true, success: false, newCompletesFirst: true)
        await staleCompletion("Superseded ordinary error without cancellation", cancel: false, success: false, newCompletesFirst: false)
        await staleCompletion("Superseded success while current waits", cancel: false, success: true, newCompletesFirst: false)
        await staleCompletion("Superseded success after current success", cancel: false, success: true, newCompletesFirst: true)
        await staleCompletion("Cancelled CancellationError while current waits", cancel: true, success: false, cancellationError: true, newCompletesFirst: false)
        await staleCompletion("Cancelled successful provider while current waits", cancel: true, success: true, newCompletesFirst: false)
        await activeFailure(false)
        await activeFailure(true)
        await cancelledBeforeStart()
        await activeVersionAndEmpty()
        let failures = observations.filter { $0["passed"] as? Bool != true }.count
        let report: [String: Any] = ["schema": 1, "variant": "__VARIANT__", "sourceSHA256": "__SOURCE_SHA__",
            "taskBodySHA256": "__TASK_SHA__", "passed": observations.count - failures, "failed": failures,
            "scope": "Verbatim original preview task component; held fixture provider; not full SwiftUI build or native UI acceptance",
            "observations": observations]
        print(String(decoding: try JSONSerialization.data(withJSONObject: report, options: [.sortedKeys, .prettyPrinted]), as: UTF8.self))
        if "__VARIANT__" == "candidate" && failures != 0 { exit(1) }
    }
}
'''


def extract(source: str):
    task_start = source.rindex('        .task(id: ')
    body_start = source.index('\n', task_start) + 1
    closing = '\n        }\n    }\n}\n\nprivate struct SearchPreviewSegment:'
    body_end = source.index(closing, body_start)
    body = source[body_start:body_end]
    segment = source[source.index('private struct SearchPreviewSegment:'):].strip()
    assert 'BackendCoordinator.shared.section' in body
    assert 'catch is CancellationError' in body and 'previewError = error.localizedDescription' in body
    assert segment.endswith('}')
    return body, segment


def generate(variant, source_path, output):
    data = source_path.read_bytes()
    source = data.decode()
    body, segment = extract(source)
    values = {
        '__ACTUAL_TASK_BODY__': body,
        '__ACTUAL_SEGMENT_DECLARATION__': segment,
        '__VARIANT__': variant,
        '__SOURCE_SHA__': hashlib.sha256(data).hexdigest(),
        '__TASK_SHA__': hashlib.sha256(body.encode()).hexdigest(),
    }
    result = PRELUDE
    for marker, value in values.items():
        result = result.replace(marker, value)
    path = output / (variant + '.swift')
    path.write_text(result)
    return {'variant': variant, 'sourceSHA256': values['__SOURCE_SHA__'],
            'taskBodySHA256': values['__TASK_SHA__'], 'compiledFileSHA256': hashlib.sha256(path.read_bytes()).hexdigest(),
            'sourcePath': str(source_path), 'compiledFile': path.name}


def main():
    baseline, candidate, output = map(Path, sys.argv[1:])
    output.mkdir(parents=True, exist_ok=True)
    receipts = [generate('baseline', baseline, output), generate('candidate', candidate, output)]
    (output / 'extraction.json').write_text(json.dumps(receipts, indent=2) + '\n')
    print(json.dumps(receipts))


if __name__ == '__main__':
    main()
