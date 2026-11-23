@main
private struct ManifestStreamCancellationControls {
    @MainActor static func main() async throws {
        let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        let suite = ControlSuite(root: output)
        var observations: [[String: Any]] = []
        for (name, overflow) in [
            ("manifest_stream_declared_length_mismatch_cancels", false),
            ("manifest_stream_actual_byte_overflow_cancels", true)
        ] {
            await suite.run(name) {
                let fixture = try ControlledArchive.make("controlled-mime-" + name)
                let started = ProcessInfo.processInfo.systemUptime
                var ownedStopBeforeCleanup = false
                defer {
                    observations.append([
                        "case": name,
                        "elapsed_seconds": ProcessInfo.processInfo.systemUptime - started,
                        "fixture_manifest_bytes": fixture.manifest.count,
                        "fixture_mime": "application/octet-stream",
                        "stop_events_after_cleanup": ControlledTransport.shared.stopCount(),
                        "owned_stop_observed_before_cleanup": ownedStopBeforeCleanup,
                        "requests": ControlledTransport.shared.requests().map {
                            ["url": $0.url, "range": $0.range ?? "", "validator": $0.validator ?? ""]
                        }
                    ])
                }
                var routes: [String: ControlledTransport.Route] = [:]
                routes[OtzariaLibraryReleaseClient.latestReleaseURL.absoluteString] = { _, _ in
                    .init(data: fixture.payload,
                          headers: ["Content-Length": String(fixture.payload.count)])
                }
                let manifestURL = fixture.release.asset.downloadURL.absoluteString
                routes[manifestURL] = { _, _ in
                    var bytes = fixture.manifest
                    if overflow { bytes.append(0) }
                    // Model an explicit binary release asset. Keep the response open:
                    // neither EOF nor the 30s product timeout may satisfy cancellation.
                    var headers = ["Content-Type": "application/octet-stream"]
                    if !overflow { headers["Content-Length"] = String(fixture.manifest.count + 1) }
                    return .init(data: bytes, headers: headers, hold: true)
                }
                let stopped = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
                ControlledTransport.shared.configure(routes, onStop: { url in
                    if url == manifestURL { stopped.continuation.yield(()) }
                })
                let session = URLSession(configuration: configuration())
                defer { session.invalidateAndCancel(); stopped.continuation.finish() }
                do {
                    _ = try await OtzariaLibraryReleaseClient(session: session).fetchLatestRelease()
                    throw ControlFailure.failed("out-of-bounds manifest was accepted")
                } catch OtzariaDatabaseBootstrapError.invalidAssetMetadata { }
                try require(ProcessInfo.processInfo.systemUptime - started < 5,
                            "metadata refusal did not occur within 5 seconds")
                try await requireOwnedStop(stopped.stream)
                ownedStopBeforeCleanup = true
                try require(ControlledTransport.shared.requests().count == 2,
                            "unexpected request outside original metadata and owned manifest")
            }
        }
        let failed = suite.rows.filter { $0["status"] == "FAIL" }.count
        let report: [String: Any] = [
            "status": failed == 0 ? "APPLE_STREAM_CONTROLS_PASS" : "APPLE_STREAM_CONTROLS_FAIL",
            "counts": ["PASS": suite.rows.count - failed, "FAIL": failed, "SKIP": 0],
            "cases": suite.rows, "observations": observations,
            "public_network_requests": 0,
            "native_app_or_sqlite_installation_acceptance": false
        ]
        try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
            .write(to: output.appendingPathComponent("RESULT.json"))
        if failed != 0 { exit(1) }
    }
}
