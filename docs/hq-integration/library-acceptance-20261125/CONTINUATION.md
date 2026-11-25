# Library continuation — 25 November 2026

## Source and delivery status

Base application: `08f50a5646b7669d15f8c53cb13c84ac504a02bd`.
Working branch: `codex/otzaria-library-acceptance-20261125`.

The normal iOS Settings → Library Source → Library Updates route now checks the actual official release, offers a complete snapshot and calls the original managed bootstrap downloader/installer. It keeps the checked release identity fixed; verifies the installed production manifest, provider, profile, file size and selected database; serializes installation across scenes; blocks backend changes while an update owns the resource; preserves resumable downloads; and removes only its own cancelled staging database.

The original checksum verification, multipart assembly, SQLite validation, disk preflight, atomic replacement, rollback and installation manifests remain in use. The generic `libraryFolderChanged` notification clears tabs, so this change uses a scoped Otzaria reload. It resolves the existing tab locators through the normal reader, keeps UUIDs/selection, preserves unavailable tabs with an error, and invalidates obsolete inactive reader caches without deleting saved groups. Success, cancellation and failure release the resource owner and resume the relevant readers.

English and Hebrew strings and exactly one iOS source membership per new Swift file were added. External Files-selected databases are not replaced. The legacy foreign SQL updater remains disabled for all currently supported backends.

**Native application update acceptance is still pending.** Source checks and policy fixtures are not a claim that the application was built or the full update succeeded. Required before final release: Apple compilation; the focused policy controls; normal UI full update from an authentic managed older installation; preserved notes/bookmarks/group/tab state and locators; cancellation/retry/failure/reopen; correct latest search/index behavior; and the original v40 full installer acceptance.

## Actual provider verification

Read-only HTTPS checks on 2026-11-25 are saved in `PROVIDER_AND_RELEASE_CHECK.json`, `OFFICIAL_METADATA_REVIEW.json` and the raw response files alongside this note. Full archive/patch payloads were not downloaded by this audit.

The old Maktabah Google CSVs are still seven rows/six columns and four rows/three columns respectively. Their raw SHA-256 values are:

- main: `99c2cf2fb5e4d5c9f30d2d0016cd769eef2b0953642e3464619310da4710c293`
- authors: `b817659e9fd948f13160071cf6c1c88bf7f52732bec74407fc53bcdf17d86dc7`

They do not establish a safe Otzaria SQLite migration contract.

Separately, the original Otzaria provider has a genuine delta contract. The latest release observed was [v40-20261123094345](https://github.com/Otzaria/SeforimLibrary/releases/tag/v40-20261123094345), release ID 455390662, published 2026-11-23. Its original Dart application uses `seforim_library_updater` at `e19880621773a289424ac33d400d48cb879f436a` from [Otzaria/otzaria_library_updater](https://github.com/Otzaria/otzaria_library_updater). The native Swift application does not copy or invent that SQL patch engine.

The verified v32→v40 patch manifest specifies format 4, database version 32→40, schema 6→7 and full logical content hashes:

- from: `56bf95ee5035469cf62dd8d99329727384d00220d3d2709dd836dff6f6476f68`
- to: `006b59566d12e64d438dd8d9f27e1697fdf227f03dda2e39b805cc3011ebbca0`
- compressed patch: 504,579,613 bytes, SHA-256 `1da99d7ea3058abef7970df23521c5bcd49e4a822ac5875636cc08ce5b7cd25d`

This change uses the existing full snapshot installer. It does not claim native delta patch execution or turn on the unrelated legacy SQL updater.

## v40 archive and disk admission

The real full database archive is 2,129,902,636 bytes, SHA-256 `39a2b52129323ea53ac3629835c4721e25acff010a8fc971bf076a666a3b9587`, described by the 589-byte official multipart manifest. Its two parts are 1,992,294,400 and 137,608,236 bytes. Provider statistics are 8,259 books and 7,925,185 lines; build provenance reports database schema 7. Exact manifests, statistics, provenance and GitHub asset digests are retained here.

The original conservative fresh-download projection is 18,112,962,912 bytes. The native shell separately requires 22 GiB available in the simulator container. Reserve approximately 24 GB for this lane, plus the global emergency buffer and other active owners. Existing databases must be counted for an update. Root schedules all Mac work and cleanup; no heavy download or native acceptance run has been dispatched from this lane yet.

## Evidence retained and new validation

The original multipart six compiled product inputs and capacity implementation are unchanged; the original 35 passes plus the two authentic streamed-response continuation passes retain their component scope. The adapter and service orchestration changed and require focused new native acceptance. The original receipt is not rewritten to claim new app acceptance.

- Original component run: 45261599920, source `4310c29728de5bbba2dc6584642c6934d554e213`, 35 passes and two held-response failures.
- Continuation run: 45267387191, source `573e4dc004dd61ba3d8f1ed8a42901ba1f3e956f`, two passes with authentic binary MIME, no product substitution.
- Prior component artifact: 14861468851, SHA-256 `0d4e9b045f3f526912108e2d0572c8abacb1f5592414d705c13d26b96f834057`.
- Continuation artifact: 14863027597, SHA-256 `3b9324f56c74821945f4ecf36b5a93066b6c05019d8a7a0a15204c6e6e4a1584`.
- Existing Library 7/7 and full-v32 install evidence remain scoped to their original source/runs; neither is silently promoted to final integrated application acceptance.

New focused Swift policy runner:
`python3 Tests/HQ/updates/run_library_update_apple.py --expected-sha <actual checkout SHA>`
on the real Mac. It compiles the original release parser/models plus the new policy against real Apple Foundation/CryptoKit and executes 15 checks using the retained official v32/v40 metadata. `--prepare-only` checks source binding without compiling or claiming a pass.

Source registration was actually checked with `Scripts/CI/verify-otzaria-xcode-project.py`: PASS, 165 Otzaria Swift files, both original search frameworks and required dictionaries. The project parser separately confirmed exactly one new policy/view membership in Maktabah-iOS.

## Remaining original acceptance

- Groups100 original native leaf and all original group acceptance, including cold restore, profiles, two-window behavior and both directions.
- Full-v32 `testTwentyOriginalFullV32ReaderOpensAndForcedRelaunch` and `testOriginalFullV32InspectorRelationshipScalesAndReturn`.
- Full native v40 cancel → resumed install → separate-process restore, all part/archive/SQLite integrity and temporary-file cleanup checks.
- Normal update action and state preservation on the final integrated app, search/performance/stability and Hebrew/English UI.
- Physical iPad checks after the signed final build becomes installable.

Relevant Asana: Bootstrap 1219682272017128; search-v32 1219674938327411; books updates 1220539610434045 (parent 1220539630830553); groups 1220103384037482 and QA 1220107239748221; physical 1219613602997169. None is marked complete by this source milestone.
