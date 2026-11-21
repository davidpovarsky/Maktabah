# Full-v32 Native artifact audit — run 44941360413

## Result and scope

**ARTIFACT_AND_SCOPED_INPUT_CLOSURE_VERIFIED.** The retained evidence supports the existing full-v32 native download/install, resumed download, original app query execution, and separate-process reopen at application source `cf44ada2a47aa0abb152af1fdce4f14d5417456d`. The relevant v32 component trees remain identical at `2818019c7dcecda953c74caa4f38823fb97cf70f`, so this narrowly scoped evidence can be reused for those unchanged components. It does not establish whole-app binary or runtime equivalence.

The audit did not rerun the native application, download the corpus/framework, rebuild an index, rerun corpus benchmarks, or mutate product sources. It inspected the intact artifact, fresh GitHub metadata, immutable Git inputs and the existing evidence validator. The original downloaded ZIP is retained without modification.

## Provenance

| Item | Verified identity |
| --- | --- |
| Successful run | [44941360413, attempt 1](https://github.com/davidpovarsky/Maktabah/actions/runs/44941360413), workflow_dispatch |
| Workflow checkout | `1da5532834315d6aebe3402751a3bf0682753c9f` |
| Application source | `cf44ada2a47aa0abb152af1fdce4f14d5417456d` |
| Reuse comparison source | `2818019c7dcecda953c74caa4f38823fb97cf70f` |
| Evidence artifact | `14722834927`, `full-v32-native-prebuilt-evidence` |
| Exact ZIP size | 1,358,070 bytes |
| Exact ZIP SHA-256 | `d9d26b6035f7a282f3217045308d82bf3c00df3b3c9acf61e5b2005471754316` |
| Corpus release | `otzaria-search-data-v32-20261010190601-102293b3a63c` |
| Corpus identity | `102293b3a63c7f73fa05298457073804e57e020486753f8f6b8f7964ce29f17e` |
| Manifest SHA-256 | `34319ced48e76f22a5ae2df23745a03332160ddab2dd64244a5c917e0ce00a57` |

The ZIP digest, size, run/source identities and completed-success status match the separately retained GitHub API metadata. All ZIP members pass CRC checks; duplicate or escaping member paths are rejected. The native log, reports, manifest and executed driver/launcher/runner/workflow hashes bind to the pinned Git source.

## Actual database and native execution

The canonical database came from `Otzaria/SeforimLibrary`, release `v32-20261010190601`, asset `seforim-schema6.db.zst` (asset ID 629048655). Its verified decompressed size was **3,821,240,320 bytes** and SHA-256 was:

```text
2f4dcd72e8bdb1fc5c0516ae9705e57759c017ec2981b49c35115625c3d3f765
```

The executed preparation gate opened SQLite read-only and counted the actual `book` and `line` tables: **7,876 books and 7,080,797 lines**. The executed native gate hashed the full source database before and after the app run and hashed its actual simulator-container copy, all against that same expected byte count and digest. The pinned schema6 asset and exact bytes are established; there is no separately recorded numeric `PRAGMA user_version == 6` assertion. The native index schema is **4**.

The 3.8 GB database is not included in this small evidence ZIP. This audit verifies the hash-bound reports and the exact executed gates; it does not claim an independent local rehash of unavailable database bytes.

| Native observation | Evidence |
| --- | --- |
| Device | Owned iPad Pro 11-inch (M5) (16GB) simulator, iOS 27.2 |
| Simulator UDID | `B69CF6C0-E38F-4E1E-9F2C-AB6F7AAAB215` |
| Bundle | `com.davidpovarsky.chavrusatext` |
| Install process | PID **20796** |
| Reopen process | PID **27466** |
| Native download resumed | **1,048,576 bytes** |
| Reopen download/resume | false / 0 bytes |
| Native local indexing | false |
| Post-install staging directory | Absent in both phases |
| Production discovery and validator | Executed and selected the exact pinned release |
| Simulator cleanup | Exit code 0, owned simulator only |

The container witness is tied to the simulator, bundle, actual data-container path and invocation nonce. The native log proves separate process identifiers. The evidence validator confirms both reports, exactly matching query checks and golden result identities after restart.

## Query and count credit

Exact, fuzzy and advanced native queries for **בראשית** each returned **104,120 matching documents**, with the first file `otzaria-book:1`.

The golden query **לחתוך צנון בסכין בשרי** produced 25 highlighted top results. The ordered result IDs were identical after process restart and are retained in `AUDIT.json`.

| Query | Matching live documents | Distinct token occurrences |
| --- | ---: | ---: |
| בראשית | 104,120 | 143,982 |
| אברהם | 109,419 | 170,515 |

Both phases expose the exact-occurrence engine proof at consumer revision `d5d59d1269bdf87fb0a6901cf31941726a0c699b`, live index documents 7,080,797, schema 4 and the original producer revision `265a14ea54f959a3e266d6e8acfa3a3b98101d68`.

The existing evidence validator was invoked directly over the retained reports. It reused the previously qualified independent SQL oracle, whose raw SHA-256 is `015b4ac382b8c6005d672234cfa7fc1ddaf291f7e5e0d07982f2c89db242f781`. That oracle covers 7,080,797 original rows, 7,876 books and 71 partitions, each original row ID exactly once, with no engine loaded or index read. No SQL scan or engine query was repeated during this audit.

## Build, generated configuration and binary attribution

The recorded build contains **1,007 actual source inputs**. Of these, **1,006 match the pinned application Git blobs directly**. The remaining input is the declared original CocoaPods aggregation of `Source/PrivacyInfo.xcprivacy`.

The audit checked the archived original and generated privacy bytes, their Git/blob and SHA-256 identities, unchanged non-API declarations, retention of all original API reasons, the exact six added reasons, and each corresponding dependency privacy-manifest hash and reason. This generated configuration is explicitly credited as generated input, not falsely treated as an unchanged source blob.

The Otzaria XCFramework input is artifact **14596463166**, 201,330,360 bytes, SHA-256 `efc73de90d74fdd380ffecfa334fe9dcece38519832b89cf3fb2a5741dcc25ad`, produced from `99f7927e4da72f2463417f5c2de2c4d20c6aa168`. Fresh GitHub metadata matches the retained build report.

Only [producer job 136041463727](https://github.com/davidpovarsky/Maktabah/actions/runs/44661774024/job/136041463727) succeeded. Its encompassing workflow 44661774024 failed; no whole-workflow success is claimed. All 43 producer SDK entries preserve the same mode, object type and blob in the tested source; the only 78 additions are regular files under SDK `Tests/`. Attribution remains to the verified producer binary inputs, not to the expanded whole current SDK tree.

The retained artifact does **not** record a final app Mach-O SHA-256. It establishes the verified build inputs and actual original-app invocation through the route, but cannot independently authenticate final app bytes that are not retained here.

## Current source input closure

| Component | Unchanged Git tree at cf44 → 2818019 |
| --- | --- |
| Source/Otzaria/Search | `5f25e1fb7843f1172e5eeae73a4d87778953a223` |
| Source/Otzaria/Storage | `ba09ea3a864b8f1f678d5d4765401e3d5469f1a8` |
| Source/Otzaria/App | `e0c5763d67d741f97abf765463eae8b1e98410ad` |
| Source/LibraryBackend | `2b4db497b77f3a337b7e3d65a0a86eb62fd134ab` |
| Vendor/OtzariaSearchEngine | `424e157913f36db2b5cc4c6204056f56c3194dd9` |

The entire `Vendor` tree is unchanged. Of the 1,007 recorded source baselines, 1,005 remain at the same path with the same Git blob. The two differences are the downstream Hanlin chat view and the byte-identical relocation of `NativeStudySheetPresenter.swift` into `Source/ChavrusaText/Reader/`. The project change updates only that file's group/path, retaining its file-reference identity. These differences do not change the scoped v32 component trees, but prevent a claim of whole-app binary equivalence.

## Explicit exclusions

This evidence does not close:

- Core request/admission or cold-search ownership gates, or actual UI query presentation.
- XCTest UI or physical-device acceptance.
- Crash/interrupted-install recovery beyond the observed partial-download resume.
- Release signing, distribution archive or publication.
- Additional corpus queries, a broad benchmark, or a new index build.
- Runtime acceptance of the newer Hanlin view/test or the complete current app binary.

## Reproduction

The Python audit reads this directory's intact ZIP and API metadata and the named immutable commits from the repository. Its default operation prints the audit summary without changing tracked files:

```sh
python docs/hq-integration/full-v32-44941360413-20261121/audit_v32.py
```

An explicit `--repo` and `--evidence` may be supplied for another checkout. `--output <path>` optionally writes a fresh JSON report. The audit invokes only the existing pure report validator and local Git reads. It does not start the native runner or any download/build/index/query process.

Retained files: original artifact ZIP, `AUDIT.json`, `audit_v32.py`, run/artifact API metadata, and framework artifact/successful producer-job API metadata.
