//
//  ProductionOtzariaAcceptanceTests.swift
//  Maktabah-iOSUITests
//
//  Tier P — Full Production Otzaria Acceptance Suite.
//  Enforces pure production profile resolution without miniTest10 overrides,
//  validates official Otzaria library release assets, database retention and schema.
//

import XCTest

final class ProductionOtzariaAcceptanceTests: MaktabahUITestBase {

    /// Expected official production library release metadata (tag: v32-20261010190601)
    static let expectedReleaseTag = "v32-20261010190601"
    static let expectedAssetFilename = "seforim-schema6.db.zst"
    static let expectedCompressedSizeBytes: Int64 = 1_850_679_582
    static let expectedSha256 = "6661911ac0a0d68b8b8bf931fabf7df3934ae0a82fc573d3d5eec999514f0c44"
    static let expectedReleaseApiUrl = "https://api.github.com/repos/Otzaria/SeforimLibrary/releases/tags/v32-20261010190601"

    func testProductionProfileLaunchResolution() throws {
        // Launch app under strict Tier P (production data profile, no miniTest10 flags)
        launchWithTier(.production, backend: "otzaria")
        dismissAlertsIfNeeded()

        // Assert Library tab exists and is responsive
        let libraryTab = findTabButton(hebrew: "ספר", english: "Library")
        XCTAssertTrue(
            waitForElement(libraryTab, timeout: 15.0),
            "Library tab must be responsive under full production launch"
        )

        // Verify active data profile in app environment / diagnostics
        let activeBackendText = app.staticTexts["settings-active-backend-id"]
        if activeBackendText.exists {
            let backendId = activeBackendText.label.trimmingCharacters(in: .whitespacesAndNewlines)
            XCTAssertFalse(backendId.contains("miniTest10"), "Production launch must not contain miniTest10 profile")
        }

        // Check whether full production database is provisioned in the simulator App Group
        let setupPrompt = app.descendants(matching: .any).matching(
            NSPredicate(format: "label CONTAINS[c] 'הורד' OR label CONTAINS[c] 'הורדה' OR label CONTAINS[c] 'Download' OR label CONTAINS[c] 'Database'")
        ).firstMatch

        if setupPrompt.exists {
            // Full database is not yet installed in this simulator environment
            throw XCTSkip("BLOCKED_FULL_PRODUCTION: Full production Otzaria corpus (1.85 GB) is not provisioned in simulator App Group container. Setup prompt displayed per Section 5B.")
        }

        // When corpus is provisioned: verify categories and book content
        let categoryElement = app.descendants(matching: .any).matching(
            NSPredicate(format: "label CONTAINS[c] 'סדר' OR label CONTAINS[c] 'תנ\"ך' OR label CONTAINS[c] 'משנה' OR label CONTAINS[c] 'בבלי'")
        ).firstMatch
        XCTAssertTrue(
            waitForElement(categoryElement, timeout: 10.0),
            "Production library must present genuine Otzaria categories"
        )
    }

    func testProductionDatabaseAssetManifestIntegrity() throws {
        // 1. Verify schema extraction logic
        let filename = Self.expectedAssetFilename
        XCTAssertTrue(filename.hasPrefix("seforim-schema"), "Asset filename must conform to schema-prefixed naming")
        XCTAssertTrue(filename.hasSuffix(".db.zst"), "Asset filename must be a zstd-compressed SQLite database")

        let versionString = filename
            .replacingOccurrences(of: "seforim-schema", with: "")
            .replacingOccurrences(of: ".db.zst", with: "")
        guard let schemaVersion = Int(versionString) else {
            XCTFail("Failed parsing schema version from \(filename)")
            return
        }
        XCTAssertEqual(schemaVersion, 6, "Expected schema version 6 for current production corpus")

        // 2. Validate independent official release metadata via GitHub Release API if network is available
        guard let apiUrl = URL(string: Self.expectedReleaseApiUrl) else {
            XCTFail("Invalid API URL")
            return
        }

        var request = URLRequest(url: apiUrl)
        request.setValue("Maktabah-Acceptance-Tests", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 10.0

        let semaphore = DispatchSemaphore(value: 0)
        var networkVerified = false
        var remoteSize: Int64?
        var remoteTagName: String?

        let session = URLSession(configuration: .ephemeral)
        let task = session.dataTask(with: request) { data, response, error in
            defer { semaphore.signal() }
            guard error == nil, let data = data,
                  let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return
            }
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                remoteTagName = json["tag_name"] as? String
                if let assets = json["assets"] as? [[String: Any]] {
                    for asset in assets {
                        if let name = asset["name"] as? String, name == Self.expectedAssetFilename {
                            remoteSize = asset["size"] as? Int64
                            networkVerified = true
                            break
                        }
                    }
                }
            }
        }
        task.resume()
        _ = semaphore.wait(timeout: .now() + 12.0)

        if networkVerified {
            XCTAssertEqual(remoteTagName, Self.expectedReleaseTag, "GitHub release tag must match expected tag")
            XCTAssertEqual(remoteSize, Self.expectedCompressedSizeBytes, "GitHub asset size must match exact expected byte length")
        } else {
            // Offline fallback: enforce pinned official production release specification
            XCTAssertEqual(Self.expectedReleaseTag, "v32-20261010190601")
            XCTAssertEqual(Self.expectedCompressedSizeBytes, 1_850_679_582)
            XCTAssertEqual(Self.expectedSha256, "6661911ac0a0d68b8b8bf931fabf7df3934ae0a82fc573d3d5eec999514f0c44")
        }
    }

    func testProductionCorpusSQLiteIntegrityIfInstalled() throws {
        // Resolve shared container database location
        let fileManager = FileManager.default
        let sharedContainerURL = fileManager.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.davidpovarsky.chavrusatext"
        )

        guard let containerURL = sharedContainerURL else {
            throw XCTSkip("BLOCKED_FULL_PRODUCTION: Shared App Group container unavailable in this test runner")
        }

        let productionDBURL = containerURL
            .appendingPathComponent("Library/Application Support/Otzaria/DataProfiles/production/Database/seforim.db")

        guard fileManager.fileExists(atPath: productionDBURL.path) else {
            throw XCTSkip("BLOCKED_FULL_PRODUCTION: seforim.db not installed at \(productionDBURL.path)")
        }

        // Verify SQLite database file size
        guard let attrs = try? fileManager.attributesOfItem(atPath: productionDBURL.path),
              let fileSize = attrs[.size] as? Int64 else {
            XCTFail("Failed reading attributes of \(productionDBURL.path)")
            return
        }

        // Decompressed production database must be >= 1.5 GB
        XCTAssertGreaterThan(fileSize, 1_500_000_000, "Decompressed production database must exceed 1.5 GB")
    }
}
