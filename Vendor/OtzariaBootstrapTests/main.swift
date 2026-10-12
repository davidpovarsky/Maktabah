import Foundation

enum OtzariaBootstrapPolicyHarness {
    static func run() throws {
        try testReleaseParsing()
        try testReleaseParsingFailures()
        try testResumeIdentityAndValidators()
        testHTTPResumeResponses()
        testStorageCapacityNormalization()
        print("Otzaria bootstrap release and resume policy tests passed")
    }

    private static func testReleaseParsing() throws {
        let json = #"""
        {
          "id": 42,
          "tag_name": "v-test",
          "assets": [
            {"id": 1, "name": "lines_snapshot.db.zst", "browser_download_url": "https://example.test/lines", "size": 10, "digest": null},
            {"id": 2, "name": "patch-1.db.zst", "browser_download_url": "https://example.test/patch", "size": 20, "digest": null},
            {"id": 3, "name": "seforim.db.buildstate", "browser_download_url": "https://example.test/state", "size": 30, "digest": null},
            {"id": 98, "name": "seforim-schema4.db.zst", "browser_download_url": "https://example.test/schema4", "size": 120000, "digest": "sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"},
            {"id": 99, "name": "seforim.db.zst", "browser_download_url": "https://example.test/seforim", "size": 123456, "digest": "sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"},
            {"id": 100, "name": "seforim-schema6.db.zst", "browser_download_url": "https://example.test/schema6", "size": 234567, "digest": "sha256:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc", "updated_at": "2026-10-10T00:00:00Z"}
          ]
        }
        """#
        let release = try OtzariaLibraryReleaseClient.parseLatestRelease(data: Data(json.utf8))
        expect(release.id == 42, "release ID")
        expect(release.tag == "v-test", "release tag")
        expect(release.asset.id == 100, "highest schema asset ID")
        expect(release.asset.name == "seforim-schema6.db.zst", "highest schema asset name")
        expect(release.asset.compressedSize == 234567, "asset size")
        expect(release.expectedSHA256 == String(repeating: "c", count: 64), "digest")

        let legacyJSON = #"{"id":43,"tag_name":"legacy","assets":[{"id":101,"name":"seforim.db.zst","browser_download_url":"https://example.test/legacy","size":99,"digest":"sha256:dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd"}]}"#
        let legacy = try OtzariaLibraryReleaseClient.parseLatestRelease(data: Data(legacyJSON.utf8))
        expect(legacy.asset.name == "seforim.db.zst", "legacy asset fallback")
    }

    private static func testReleaseParsingFailures() throws {
        try expectThrows("missing exact asset") {
            _ = try OtzariaLibraryReleaseClient.parseLatestRelease(
                data: Data(#"{"id":1,"tag_name":"v1","assets":[]}"#.utf8)
            )
        }
        try expectThrows("malformed JSON") {
            _ = try OtzariaLibraryReleaseClient.parseLatestRelease(data: Data("{".utf8))
        }
        try expectThrows("malformed SHA") {
            let json = #"{"id":1,"tag_name":"v1","assets":[{"id":2,"name":"seforim.db.zst","browser_download_url":"https://example.test/db","size":10,"digest":"sha256:nope"}]}"#
            _ = try OtzariaLibraryReleaseClient.parseLatestRelease(data: Data(json.utf8))
        }
        try expectThrows("missing SHA") {
            let json = #"{"id":1,"tag_name":"v1","assets":[{"id":2,"name":"seforim-schema6.db.zst","browser_download_url":"https://example.test/db","size":10,"digest":null}]}"#
            _ = try OtzariaLibraryReleaseClient.parseLatestRelease(data: Data(json.utf8))
        }
    }

    private static func testResumeIdentityAndValidators() throws {
        let release = sampleRelease(id: 10, assetID: 20, size: 1_000)
        var metadata = OtzariaDownloadResumeMetadata(release: release, downloadedBytes: 400)
        metadata.etag = "\"representation-a\""
        expect(
            OtzariaDownloadPolicy.reusableOffset(
                metadata: metadata,
                release: release,
                localSize: 400
            ) == 400,
            "strong ETag resume"
        )

        var weak = metadata
        weak.etag = "W/\"representation-a\""
        expect(
            OtzariaDownloadPolicy.reusableOffset(metadata: weak, release: release, localSize: 400) == 0,
            "weak ETag must not resume"
        )

        var dated = weak
        dated.lastModified = "Mon, 17 Aug 2026 00:00:00 GMT"
        expect(
            OtzariaDownloadPolicy.reusableOffset(metadata: dated, release: release, localSize: 400) == 400,
            "Last-Modified resume"
        )

        let productionRelease = OtzariaLibraryRelease(
            id: 30,
            tag: "v30",
            asset: .init(
                id: 40,
                name: "seforim-schema6.db.zst",
                downloadURL: URL(string: "https://github.com/Otzaria/SeforimLibrary/releases/download/v30/seforim-schema6.db.zst")!,
                compressedSize: 2_000,
                digest: "sha256:" + String(repeating: "a", count: 64),
                updatedAt: nil
            )
        )
        var cached = OtzariaDownloadResumeMetadata(release: productionRelease, downloadedBytes: 400)
        cached.etag = "\"production-representation\""
        expect(
            cached.resumableProductionRelease(localSize: 400) == productionRelease,
            "validated production sidecar reconstructs a release when lookup is unavailable"
        )
        cached.etag = nil
        expect(
            cached.resumableProductionRelease(localSize: 400) == nil,
            "cached production release requires a resume validator"
        )

        let changedRelease = sampleRelease(id: 11, assetID: 21, size: 1_000)
        expect(
            OtzariaDownloadPolicy.reusableOffset(
                metadata: metadata,
                release: changedRelease,
                localSize: 400
            ) == 0,
            "release and asset identity mismatch"
        )
        expect(
            OtzariaDownloadPolicy.reusableOffset(
                metadata: metadata,
                release: release,
                localSize: 1_001
            ) == 0,
            "oversized partial"
        )
    }

    private static func testHTTPResumeResponses() {
        expect(
            OtzariaDownloadPolicy.responseAction(
                statusCode: 200,
                requestedOffset: 400,
                localSize: 400,
                expectedSize: 1_000,
                contentRange: nil
            ) == .acceptFresh,
            "server ignoring Range must restart from the 200 body"
        )
        expect(
            OtzariaDownloadPolicy.responseAction(
                statusCode: 206,
                requestedOffset: 400,
                localSize: 400,
                expectedSize: 1_000,
                contentRange: "bytes 400-999/1000"
            ) == .append,
            "valid 206 append"
        )
        if case .restartFresh = OtzariaDownloadPolicy.responseAction(
            statusCode: 206,
            requestedOffset: 400,
            localSize: 400,
            expectedSize: 1_000,
            contentRange: "bytes 399-999/1000"
        ) {} else {
            fatalError("wrong Content-Range must restart fresh")
        }
        expect(
            OtzariaDownloadPolicy.responseAction(
                statusCode: 416,
                requestedOffset: 1_000,
                localSize: 1_000,
                expectedSize: 1_000,
                contentRange: "bytes */1000"
            ) == .complete,
            "416 full local file"
        )
        if case .restartFresh = OtzariaDownloadPolicy.responseAction(
            statusCode: 416,
            requestedOffset: 400,
            localSize: 400,
            expectedSize: 1_000,
            contentRange: "bytes */1000"
        ) {} else {
            fatalError("416 partial local file must restart")
        }
        expect(
            OtzariaDownloadPolicy.responseAction(
                statusCode: 503,
                requestedOffset: 0,
                localSize: 0,
                expectedSize: 1_000,
                contentRange: nil
            ) == .failHTTP(503),
            "HTTP error"
        )
        expect(OtzariaDownloadPolicy.parseContentRange("bytes 0-9/10")?.total == 10, "range parse")
        expect(OtzariaDownloadPolicy.parseContentRange("junk bytes 0-9/10") == nil, "anchored range parse")
    }

    private static func testStorageCapacityNormalization() {
        let exact = OtzariaStorageErrorNormalizer.failure(
            for: OtzariaDatabaseBootstrapError.insufficientDiskSpace(
                required: 8_500_000_000,
                available: 1_200_000_000
            )
        )
        expect(exact?.requiredBytes == 8_500_000_000, "storage required bytes")
        expect(exact?.availableBytes == 1_200_000_000, "storage available bytes")
        expect(exact?.missingBytes == 7_300_000_000, "storage missing bytes")

        let posix = NSError(domain: "NSPOSIXErrorDomain", code: 28)
        let wrapped = NSError(
            domain: "example.wrapper",
            code: 1,
            userInfo: [NSUnderlyingErrorKey: posix]
        )
        let lateFailure = OtzariaStorageErrorNormalizer.failure(
            for: wrapped,
            fallbackAvailableBytes: 750_000_000
        )
        expect(lateFailure?.requiredBytes == nil, "late storage required bytes unavailable")
        expect(lateFailure?.availableBytes == 750_000_000, "late storage available bytes")
        expect(lateFailure?.missingBytes == nil, "late storage missing bytes unavailable")
    }

    private static func sampleRelease(id: Int64, assetID: Int64, size: Int64) -> OtzariaLibraryRelease {
        OtzariaLibraryRelease(
            id: id,
            tag: "v\(id)",
            asset: .init(
                id: assetID,
                name: "seforim.db.zst",
                downloadURL: URL(string: "https://example.test/seforim.db.zst")!,
                compressedSize: size,
                digest: "sha256:" + String(repeating: "b", count: 64),
                updatedAt: nil
            )
        )
    }

    private static func expect(_ condition: @autoclosure () -> Bool, _ name: String) {
        if !condition() { fatalError("failed: \(name)") }
    }

    private static func expectThrows(_ name: String, _ body: () throws -> Void) throws {
        do {
            try body()
            fatalError("failed: \(name) did not throw")
        } catch is OtzariaDatabaseBootstrapError {
            return
        }
    }
}

try OtzariaBootstrapPolicyHarness.run()
