# Full v32 partial-download seed repair — 2026-11-20

## Result and scope

Run [44628513017](https://github.com/davidpovarsky/Maktabah/actions/runs/44628513017) remains **FAILED**. Its application completed the original native installation, three search modes, golden query and real process restart, but the strict wrapper rejected `install.resumedDownloadBytes == 0`. The required value remains **1,048,576 bytes**.

These observations belong only to workflow checkout `38e8114ba6d9ded8193be4aab1128a05b2415683` and application source `440f7e43af9fa49b67613685566fbb9b6bbc9248`. They do not validate the subsequent notes/search integration or the repair commit. The corrected native resume acceptance is **NOT_RUN** here and must pass on the final combined source before the acceptance task can close.

## Original evidence

[Artifact 14585860346](https://github.com/davidpovarsky/Maktabah/actions/runs/44628513017/artifacts/14585860346), `full-v32-native-prebuilt-evidence`, was downloaded as the original ZIP and authenticated against GitHub metadata and the upload log:

- ZIP bytes: **39,644,197**.
- ZIP SHA-256: `899a5026a61b244c5a3eaeb892260ec870fdb4500b1b1f0becd78d44405c2715`.
- Original raw native log SHA-256: `e5db5893f3be0eee213828152581d1a40a4d2df95b7c2401e27c24b0524dbaaa`.
- Install report SHA-256: `4fd900df14437b35c02df31078deab45977ea05b1c779e90b63933ea0d1fe14e`.
- Reopen report SHA-256: `c4e0233af9387529510c8179516596591bc21f0aa6e1a28ec4a1e748e92794e0`.
- The reviewed driver bytes match the run's reported SHA-256: `4b5d00ee0765a8f98b6ff4d16a3ca5fa3b4f30809c9ae136aef6d8e02570f3d3`.

The four `original-*` files in this directory retain the exact bytes from that artifact. `verified-compact.json` is a derived summary, not a replacement run report. The large original ZIP remains in the artifact service; it was not copied to the Windows worktree.

| Original check | Actual result |
| --- | --- |
| Source preflight and URLSession release-candidate regression | PASS |
| Xcode 27.2 simulator application build | PASS |
| Manifest, official database and source preparation | PASS |
| Native application launcher | Exit 0 |
| Install / reopen reports | Both `passed: true` |
| Production discovery / manifest validator | Both phases ran and selected the exact v32 release |
| Corpus | 7,080,797 documents; 7,876 sources |
| Exact / fuzzy / advanced query `בראשית` | 104,120 results each, `otzaria-book:1` first; equal across restart |
| Golden query `לחתוך צנון בסכין בשרי` | 25 unique ordered results, 25 highlighted top results; complete golden report equal across restart |
| Actual app processes | Install PID 11356; reopen PID 15115 |
| Install native downloader | Ran; reported 0 pre-existing partial bytes |
| Reopen native downloader | Did not run; 0 resumed bytes |
| Staging / local indexing | Staging absent; local indexing did not run in either phase |
| Strict 1MiB resume gate | FAIL |
| Post-validation original/installed DB hash checks | NOT_RUN: the strict resume gate threw before these statements |
| XCTest UI cases / physical device | 0 / NOT_RUN |

Discovery uses the production release client on an authentic captured releases response and its real per-candidate URLSession manifest loading. The native app did not itself fetch the release-list API in this acceptance path. The index part downloader and engine ran in the original application.

## Confirmed cause

The original launcher wrote the partial file under:

```text
Library/Caches/Maktabah/Otzaria/SearchDownloads/<artifactIdentity>/<partSHA256>.part
```

The production `OtzariaSearchArtifactStorage.init()` passes the app cache directory to the actual `OtzariaProfileStorage.downloadsRoot(..., component: .otzariaSearch)`. For the production profile that resolver returns:

```text
Library/Caches/Maktabah/Otzaria/Downloads/<artifactIdentity>/<partSHA256>.part
```

Consequently the original downloader's `existingBytes` saw no partial file in its own workspace and downloaded the package completely. This is a confirmed acceptance-fixture path mismatch. This run supplies no evidence of a broken native range-resume implementation, and it supplies no successful range-resume acceptance.

## Repair

The launcher now seeds the production `Downloads` directory. Its `dd` still writes exactly one 1MiB prefix, the real downloader is unchanged, and `validate_reports` retains the exact 1,048,576-byte requirement.

A focused parity regression compiles the original Swift storage, profile and registry sources. It executes the original shell seed block with controlled bytes in a temporary container, then asks that compiled resolver which production workspace contains the partial file. The unused shared-container default is a fail-fast test shim; the real resolver receives the same explicit cache base as the production storage initializer. No Swift storage implementation is copied into the test.

The native-v32 workflow runs the parity and evidence-gate regressions before the expensive simulator build and retains their logs with its existing artifact. No application source, vendor source, producer pin, package data, manifest, index, workflow trigger or acceptance threshold changes.

## Validation performed

| Validation | Result |
| --- | --- |
| New path regression before correction | Expected RED: 3 executed, 2 PASS / 1 FAIL; actual Swift resolver disagreed with the original `SearchDownloads` seed |
| New path regression after correction | 3 executed / 3 PASS / 0 skipped |
| Legacy-path negative control | Reproduced 0 bytes at the actual production workspace |
| Production / mini-profile separation | Production seed did not appear in the mini-profile workspace |
| Existing evidence-gate suite plus native-full-redownload negative control | 15 executed / 15 PASS / 0 skipped |
| Bash syntax | PASS |
| Git whitespace check | PASS |
| Actual native acceptance with corrected seed | NOT_RUN; root will run the final combined source |

Portable path tests used Windows Swift 6.3.3 and Git Bash. They prove source/path/seed agreement, not UIKit, simulator behavior, HTTP 206 receipt or native acceptance. Raw before/after and evidence-gate logs are retained alongside this review.

## Ownership and integration

Repair base: `03ac69e5dfcfb19f161d40f569f1e53796c07330`. Isolated branch: `codex/otzaria-v32-resume-repair-20261120`.

| File group | Ownership / change |
| --- | --- |
| `Scripts/run-otzaria-prebuilt-acceptance.sh` | Downstream acceptance launcher; production seed directory only |
| `Scripts/CI/test-v32-seed-workspace.py` | New downstream source-parity regression |
| `Scripts/CI/test-v32-prebuilt-native.py` | Downstream evidence controls; explicit full-redownload negative case |
| `.github/workflows/otzaria-search-artifacts.yml` | Existing downstream native-v32 validation job; pre-build focused checks |
| This evidence directory and project board | Source-bound failure, repair and remaining acceptance recorded |

The launcher and new test are absent from the reviewed upstream tree `d46af139b3a265399c16d87f5923acd8e3444024`. No upstream-owned application file was changed. No CI dispatch was performed by this repair branch. Merge the small harness change, keep these historical observations scoped to their original SHAs, and rerun the unchanged native gate on the final combined source.
