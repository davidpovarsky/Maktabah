# Focused Apple verification plan — concrete, not executed

[תומר | INT] [MAIN_SESSION] — 2026-11-15

Integrated application source: 07d1cafa6c6bc27aaf299aa826d28a4c02090cb5. The later doc-correction merge 24dab7d960ddc146ee4a5e37fe7efd6163d82c2e has byte-identical Source/Vendor/project trees. Rollback remains codex/otzaria-integration-pre-stage2-20261115 at 242571c9a1502d068410c82af753ba2a8a2b0bbf. No Apple execution, signing or project publication performed.

## Preferred honest integration check: one unsigned iOS app target

Adapt only the existing ios-build.yml simulator build command, not the dependency-heavy multi-job workflow. Run on the real macOS/Xcode authority selected by Lead, with the immutable source package staged in an isolated checkout and compatible prebuilt dependency inputs already restored. Do not dispatch generic apple-authority build: its current command does not force signing off.

```bash
set -euo pipefail
mkdir -p build/hq-apple/logs
python3 Scripts/CI/verify-otzaria-xcode-project.py
bash Scripts/CI/verify-xcframework.sh Vendor/OtzariaSearchEngine/OtzariaSearchEngine.xcframework otzaria_search_engine.h
bash Scripts/CI/verify-xcframework.sh Vendor/ZayitSearchPort/build/MaktabahZayitSearch.xcframework maktabah_zayit_search.h
xcodebuild build \
  -project Maktabah.xcodeproj \
  -scheme Maktabah-iOS \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath build/hq-apple/DerivedData \
  -clonedSourcePackagesDirPath build/SourcePackages \
  -disableAutomaticPackageResolution \
  -jobs 2 -showBuildTimingSummary \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY='' \
  2>&1 | tee build/hq-apple/logs/unsigned-ios-target.log
```

Use DEVELOPER_DIR only per invocation if Lead selects a specific stable Xcode. Do not change xcode-select or project settings. The command builds only the existing app scheme/dependencies, without tests, archive, IPA, upload, distribution, Rust rebuild, index download or real DB. It compiles and links the actual app sources, including SwiftUI/UIKit hooks and production safety adapter, against actual packages/FFI binaries. It does not prove touch behavior, engine correctness against production DB, data-update recovery, UI-test execution, physical acceptance or fully configured embedded React runtime. Native Maktabah updates remain intentionally unavailable for current BackendID.

Required inputs (do not silently fabricate/disable them):

- Exact source checkout/archive, tracked local CommandPalette package, resources and unchanged Package.resolved. Archive alone does not include gitlink contents.
- Prebuilt OtzariaSearchEngine.xcframework and MaktabahZayitSearch.xcframework matching the preserved baseline Rust/ABI pins, with real simulator slices. Verify original artifact provenance/digests before reuse; archive names/mtime alone are not proof.
- Pinned SwiftPM source/build inputs for AnchoredPopup, FloatingPanel, TorahInspectorKit (19d1b35397af4f10ae70cfb3f444c9de87383b53), ZIPFoundation and zstd; shared lock also includes Sparkle for other targets. Let target build use their real APIs, no app-model/package mocks.
- Existing Sefaria build-phase inputs: pinned submodule 2fd173a5a3bd32d94a9ba1222e4e32a37f6bd23c ios/sources JSON files, real build/jsbundle/main.jsbundle and assets required by Scripts/copy-sefaria-bundle-resources.sh. Do not add FAIL_ON_MISSING_BUNDLE=0 or empty placeholders just to pass.

Already present cached archives in untouched original source tree (not copied, provenance not yet authenticated): OtzariaSearchEngine.xcframework.tar 200,977,408 bytes; MaktabahZayitSearch.xcframework.tar 122,824,704 bytes; SourcePackages.tar 228,718,080 bytes. Total 552,520,192 bytes (~527 MiB), before extraction. These are much smaller than rebuilding Rust/installing all JS dependencies, but cannot be called compatible until verified. Main checkout's user data/artifacts remain untouched.

## Smallest actual-SDK subset, when a full target's inputs are unavailable

One real production source file already has a deliberate fixture compile boundary. Compile its Foundation/SQLite safety core without mocks; explicitly exclude only its production app adapter via the existing HQ_UPDATES_FIXTURE flag:

```bash
set -euo pipefail
mkdir -p build/hq-apple/logs build/hq-apple/ModuleCache
sdk_path="$(xcrun --sdk iphonesimulator --show-sdk-path)"
xcrun --sdk iphonesimulator swiftc -typecheck -swift-version 6 \
  -target arm64-apple-ios18.6-simulator -sdk "$sdk_path" \
  -module-cache-path build/hq-apple/ModuleCache \
  -D HQ_UPDATES_FIXTURE \
  Source/ChavrusaText/BookUpdates/MaktabahBookUpdateSafety.swift \
  2>&1 | tee build/hq-apple/logs/safety-core-sdk-typecheck.log
```

Dependency closure: this exact file plus installed Apple Foundation and SQLite3 modules; zero app-model stubs, package downloads, Rust, JS, signing, linker or user data. It can establish real Apple SDK compiler acceptance for active safety-core declarations, TaskLocal context and SQLite C API calls. It explicitly does NOT check the excluded BackendCoordinator/AppConfig production bridge, original caller integration, target membership, SwiftUI/UIKit hooks or full application. A subset PASS cannot close the integration gate. Do not run the shared generic typecheck wrapper unmodified for this command: it lacks the explicit target and flag inputs above.

## Transport boundary and rejected shortcuts

Lead's bounded checks found no connected Mac: local portable Windows only; XcodeBuildMCP xcrun ENOENT; SentinelX Windows only; online Remote Desktop host Linux arm64; no repo self-hosted runner. Existing Apple Authority checks out repository/ref and exposes neither archive upload nor custom command/flag inputs. Its build mode does not force unsigned; current typecheck mode cannot express the explicit target/fixture flag above. Toolkit/workflow edits and project push are not authorized. Do not inject commands into path/ref inputs or mislabel baseline/public-ref checks as integrated-source checks.

The integrated application-only binary diff against remote baseline df2a2194 is 171,017 bytes (34,253 bytes gzip, ~45.7KB base64); this quantifies a potential future reviewed overlay transport. No existing supported input accepts that overlay. No workflow/toolkit/transport was changed or dispatched. A source-access route plus explicit unsigned command execution is needed; owner already authorized isolated integration and focused Apple verification, so the issue is transport/executor authorization, not a renewed request for those operations.

Stage outcome until that route exists: exact isolated composition and membership PASS; actual Apple SDK compile NOT_RUN/BLOCKED_TRANSPORT; physical acceptance OPEN. Preserve all immutable refs/artifacts for the authorized next step.

## Superseding execution route

Owner subsequently authorized necessary isolated publication and a narrow manual-only focused validation entry. See STAGE2_VALIDATOR_NECESSITY.md and Scripts/CI/hq-stage2-focused-apple.py. The selected check is now the actual unsigned iOS app target with verified prebuilt native and real resource inputs; the model-only smoke was not dispatched. Existing immutable native artifacts from run40566258679 match all preserved native engine/Rust/upstream trees. Small real Sefaria resource artifact13658066283 was downloaded and digest-verified for metadata audit. No product stub or fake resource will be introduced.

The new mode is false by default; normal workflow inputs/job bodies/default behavior and automatic triggers are preserved. Requested 40-character checkout SHA is mandatory for focused mode. One scoped job, no simulator tests/corpus/release. Local validator checks passed: source closure, wrong-SHA/source-tree refusal and archive traversal refusal. No Apple PASS is claimed before the actual run completes.
