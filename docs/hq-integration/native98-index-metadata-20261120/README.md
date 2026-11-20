# Native98 original index metadata across explicit reinstallation

## Actual failure and source evidence

The original Native run44723902453, F60a57972acb28739ec738565083bf17fb7503028 / M87b783ac3f0257e8461762e0ea9dfa5248dd06e8, failed SearchDataNativeAcceptanceTests/testCorruptIndexShowsRepairRequiredAndOriginalRepairSurvivesColdLaunch at GlobalSearchNativeAcceptanceTests.swift1344 after203.536seconds. The genuine ready row again displayed18879documents, but the complete nine-file inventory differed only at otzaria_index_meta.json. The existing real-query and cold-reopen assertions had not finished. This original Native result remains FAIL.

The actual captured test stdout was read from the authenticated HTTP206-selected capture entry, independently byte/hash checked against the CRC-validated range receipt:30378bytes, SHA256 d8ffde08bf5c32ccfe501b4227eb2b6ffdcab9cb5b120b485ae297b17fca664f. The full775094118byte capture archive was not downloaded; its advertised whole-archive digest is not claimed verified.

The exact source-pinned engine is davidpovarsky/otzaria_search_engine d5d59d1269bdf87fb0a6901cf31941726a0c699b. Its complete rust/src/api/search_engine.rs blob3727022001e1105d99880a47e22f973afe7d879a was read and Git-blob verified. IndexMetadata has five fields. On an otherwise compatible legacy index lacking this sidecar, ensure_current_index_metadata writes the original pretty-serialized structure and SystemTime creation second.

The untouched miniTest10v6 artifact manifest contains exactly seven Tantivy files, including meta.json, and does not contain otzaria_index_meta.json. The unchanged original app installer extracts these files and opens the original engine. The seven-file manifest, original installer/manager and upstream pins are byte-identical between the failed F60 and this source base.

Both observed Native SHA256 values match exactly163bytes generated from that unchanged original serializer:

- Before: f0319223893cce1e7f3e62837ec16be660f23ac652c2ae5fda65996151d79b6e; creation second1795181380,2026-11-20T13:29:40Z.
- After:768dfd7417528f6f561f484e64b43d8f9438f3123b483547671641d68e0fcc0a; creation second1795181732,2026-11-20T13:35:32Z.

The other four metadata fields and every other byte are identical. These named SOURCE_DERIVED files are computed candidate bytes exactly matching the observed hashes, not raw downloaded metadata attachments. That distinction is retained in every proof. The observed timestamp change is consistent with the original fresh-install sidecar behavior; no engine/product rewrite is required to preserve the original behavior.

## Narrow test correction

Application base:0f25cb37711cbc1057d34a20ee8552bbcae75903; test source commit:d2f10ab0953de4b2bbc7d169740eb10172fe3c2e. Only Maktabah-iOSUITests/GlobalSearchNativeAcceptanceTests.swift changes.

The fixture now proves the seven original artifact paths plus both metadata paths constitute the complete nine-file inventory, and captures the original metadata bytes. Only the three existing explicit successful reinstall actions record their actual pre-tap Date. The new Foundation helper requires the exact original five fields, unique field names, current pinned format/schema/engine/Tantivy values, a creation second inside floor(actual tap time)...floor(actual observation time), and no backward creation time. It compares every other UTF8 byte exactly. No metadata field/file is ignored.

After that proof, only the expected SHA of that generated sidecar changes in the nine-file dictionary. All other eight file hashes and the complete path set still match the original. The unchanged real search query then runs. Following cold relaunch, the complete nine-file inventory must match the repaired baseline byte for byte, including the newly generated metadata. New raw metadata/interval attachments will make the actual Native result inspectable.

The healthy case, missing-secondary-identity recovery, before-failure inventory, complete verified backup/restore logic and database/owner preservation retain their original assertions. All five SearchData method identifiers and every method identifier in this file remain unchanged. The file prefix outside the SearchData section is unchanged. No timeout, retry, engine, permission, SDK, app source, database or product feature changes.

## Executed validation and remaining gate

The final exact helper source span compiled with Windows Swift6.3.3 and passed all33 unique real boundary controls at2026-11-20T14:09:15.813396+00:00. Controls exercise the observed hash-matched pair, inclusive second bounds, same-second installation, all format/schema/version changes, extra/missing/duplicate fields, every other byte, invalid timestamps, JSON, UTF8 and observation windows. The complete Native source file separately passed a frontend syntax parse. Compiler diagnostics are retained verbatim.

The first33-control run also passed and remains separately recorded. Independent reviewer C read the complete patch and requested explicit UTF8 byte equality instead of Swift String equivalence; that one expression was tightened, and the same33controls were rerun on the final source. These are33 final controls, not66 unique tests.

AppleSDK typecheck and the five original Native cases on the corrected source remain NOT_RUN. No cold-launch or actual repair PASS is inferred from the helper controls. The original native failure is preserved. Final acceptance still requires the original immutable Apple/Native gate, real query, owned fixture safety, failure/retry and cold reopening.

## Reproduction and integrity

RAW_FILES.json seals every raw source/proof/driver/log/receipt as deterministic gzip with compressed and exact original byte/hash identities. MANIFEST.json seals the delivered document set except itself. BoundaryControls.swift contains the exact Foundation helper span plus the actual33-control harness; decompress it and both SOURCE_DERIVED_MATCH files, compile using swiftc -parse-as-library, and invoke the executable with the before and after metadata file paths. This exercises the helper only; it does not invoke XCTest.

The original edit/inverse proof, review adjustment and both control attempts are retained. Source before/after, complete original Rust source and the source-pinned seven-file artifact manifest are provided to distinguish runtime-created metadata from immutable artifact payload.
