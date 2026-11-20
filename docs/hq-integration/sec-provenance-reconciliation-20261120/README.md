# SEC/INT provenance reconciliation — 20 November 2026

Task: [1220103384074338](https://app.asana.com/0/0/1220103384074338). This is a dated supplement to the existing provenance records. **Both requested evidence gaps are resolved: the real upstream common ancestor is established, and the unmatched LibraryCommandPaletteAdapter historical digest is accounted for exactly by its Windows line endings.** No application source, historical ledger, approval policy, test oracle, source pin, or frozen Native branch was changed.

## Exact scope and identities

| Item | Exact identity |
| --- | --- |
| Audited app/test source | `0f5111e8f8e379e17da558ddbe2aab5214ac0315` |
| Real upstream | `https://github.com/bismillah-100/Maktabah.git`, `refs/heads/main` |
| Upstream HEAD observed during this audit | `d46af139b3a265399c16d87f5923acd8e3444024` |
| Common ancestor | `a0ed0df908a6cb38bc459d4baaeb400f447b2fc4` |
| Collector worktree base | `859fd664b0ce225d8e62ea806bc2907aaac9ba5b`, clean before collection |
| Earlier reconciliation source, preserved | `bfc7f5a6aa849ab7e9a892cf63c693a8f49ac8a1` |
| Audited Source tree | `8c0c17c9df352161a025eb66a7a16114a32d41a3` |
| Audited Vendor tree | `91a62524a787c3c0317db65ffda8c3d21dcb9497` |

The collector branch is an ancestor of the audited app source. All source reads in this audit use immutable Git objects at the stated revision; the collector worktree is not mislabeled as the later app checkout. `ANCESTRY_PROOF.json` also records the actual `Maktabah.xcodeproj/project.pbxproj` blob. An initial lookup of a nonexistent root-level `project.pbxproj` is retained as exit 128, followed by the corrected path; it is not a successful check or a product compiler failure.

## 1. Actual upstream ancestry

Before this work, the shared local repository had a single shallow boundary at upstream `d46af139`; `git show` therefore omitted its parents and `git merge-base` exited 1. Its raw commit object already named parent `44fa15860d864634c8cffc5be61e302b9ce2f497`. A fresh read-only `git ls-remote --symref upstream HEAD` verified that the original maintained repository still published the exact pinned revision on `main`.

An independent GitHub compare of the exact upstream and audited app revisions returned common ancestor `a0ed0df9`, with status `diverged`. The complete response is retained compressed, with its original byte count and SHA256 in `GITHUB_COMPARE.json`.

One ordinary Git fetch then expanded only the requested upstream history by a bounded 32 generations, with blob filtering, no tags, no FETCH_HEAD write, and no automatic maintenance. It completed successfully in approximately 2.73 seconds. `BOUNDED_FETCH.json` preserves the exact command and times; `FETCH_BEFORE.json`, `FETCH_AFTER.json`, and the compressed shallow files preserve the metadata change. The filtered fetch added normal upstream promisor/blob-filter configuration, recorded explicitly in those receipts. No application or user-data operation occurred.

After the fetch, local `git merge-base --all` returns exactly the same `a0ed0df9` as GitHub. Positive ancestry checks establish that this commit is an ancestor of both inputs. The upstream tip is **not** an ancestor of the app source. This is lineage evidence, not an upstream merge or a claim that the fork contains all upstream changes.

### Remaining graph limit

The repository deliberately remains shallow at `dc72ca81738620e0a671b5f2fd0b3a3f51614785` (19 October 2026), which is older than the proven common ancestor and is an ancestor of both compared tips. No full-history download was needed to answer the requested common-ancestor question. There are no Git replace refs.

GitHub's full-graph compare reports 22 upstream-only and 1,387 downstream-only commits. The still-shallow local symmetric difference reports 22 and 1,684; it also lists pre-boundary commits, including the February initial commit, through other fork ancestry. Those counts are retained without equating them. **Do not use the shallow local count as a complete divergence inventory.** The resolved common ancestor agrees independently; a complete upstream-sync impact assessment remains a separate task and was not performed.

## 2. Historical LibraryCommandPaletteAdapter digest

The existing manifest records historical destination SHA256 `d4f5c45680c8cf72001a0a0d83b5e62a97368dbc68b6ea229985028cf86ae66a`. The earlier audit could not match this against canonical Git blobs. The current collector's `core.autocrlf` is `true`.

A rename-aware history search, bounded at 160 path revisions, returned 12 revisions and an original add entry, with no rename/copy entries. The exact historical digest occurs in the manifest at the same commit that supplies the matching source:

| Representation at `dd7b1eb5119544ed28c12d1ea4a3653dddce9842` | Bytes | SHA256 |
| --- | ---: | --- |
| Canonical Git blob `c9aee7e586b096b81ccea6ac3c8e12471556063c`, LF | 6,178 | `2f7b6765c4eb500f53b74a7261c372ad3c9d738d40f104705f4f02c938fdb0e2` |
| Exact LF-to-CRLF projection, 165 line endings | 6,343 | `d4f5c45680c8cf72001a0a0d83b5e62a97368dbc68b6ea229985028cf86ae66a` |
| Current audited source, Git LF | 3,151 | `322159512454716200aed3329c435d000018b698ed25ee230da61b710443c239` |

The line-ending projection is reversible byte for byte and introduces no other text change. This proves that the historical manifest digest represents that source in CRLF form. The CRLF payload in this package is explicitly **reconstructed from the immutable Git object**, not claimed to be a retained copy of the November 8 worktree. Both representations are compressed to preserve exact bytes across Git checkouts with different line-ending settings.

`LIBRARY_TIMELINE.json` proves that the manifest first acquired this digest in `dd7b1eb5`, and that the commit is an ancestor of the audited source. Later source evolution remains real and is preserved as a complete patch and path-history references. The current file is not represented as byte-identical to its historical version.

## 3. Current 32-row source-port ledger

The original manifest and the prior reconciliation are retained unchanged in their original Git paths, with exact source hashes and compressed copies here. The earlier result of 29 matching rows and 3 evolved rows was a statement about its own `bfc7f5a6` source. The 32 rows represent 32 distinct origin-to-destination mappings over 28 unique destination files: five original DuckDuckGo files contribute to TabSwitcherPagePort.swift. At the later audited app source, **26 rows (22 unique destination files) still match the historical Git-byte digest and 6 rows/files have evolved**.

All six historical destination hashes now resolve to exact, ancestry-verified Git objects, with the one documented CRLF projection. `CURRENT_32_ROW_RECONCILIATION.json` records every current blob, byte count, canonical SHA256, historical record, and prior audit row. `SIX_SOURCE_EVOLUTIONS.json` and the six compressed patches preserve the exact changes.

| Evolved path | Historical source bound to the recorded digest | Representation |
| --- | --- | --- |
| CommandPalette/Views/CommandPaletteView.swift | `e815a6da7df54dccafbd4efcec96a7a34e759175` | Git bytes |
| DuckDuckGoTabsPort/TabsBarView.swift | `bfc7f5a6aa849ab7e9a892cf63c693a8f49ac8a1` | Git bytes |
| DuckDuckGoTabsPort/TabsBarCell.swift | `bfc7f5a6aa849ab7e9a892cf63c693a8f49ac8a1` | Git bytes |
| ToolbarSearch/LibraryCommandPaletteAdapter.swift | `dd7b1eb5119544ed28c12d1ea4a3653dddce9842` | CRLF projection |
| ReaderHost/ChavrusaReaderHost.swift | `20bff505d3ee735d43201a35f4f9cd2e1fd56894` | Git bytes |
| ReaderHost/ReaderOverviewPresentation.swift | `bfc7f5a6aa849ab7e9a892cf63c693a8f49ac8a1` | Git bytes |

The three newly evolved rows relative to the older inventory are TabsBarView, TabsBarCell, and ReaderOverviewPresentation. Their recorded changes point to existing source commits `4fee5615` and `4ce1a929`. ChavrusaReaderHost also has later changes, but was already an evolved row. Tracing a change does not grant a new license, approve a protected hunk, or certify its runtime behavior.

## 4. Verification and task boundary

Run the included read-only verifier from this package:

```sh
python verify-reconciliation.py --repo /path/to/Maktabah
```

It reads the exact original Git objects and retained remote receipt. It performs no fetch, checkout, rewrite, or application execution. It verifies all 32 unique origin mappings and their 28 destination paths; immutable historical records; all six historical hash matches and complete evolution patches; CRLF-only round trip; exact manifest chronology; local ancestry; and independent remote merge-base agreement. The corrected verifier executed at 09:21:42–09:21:48 UTC with exit0 and241 distinct source-verification assertions passing. Its raw output, initial failure, execution receipts and source-preservation result are retained separately. These are provenance assertions, not application/unit/Native test cases.

This tranche resolves the two requested provenance evidence gaps. It does **not** close SEC/INT by itself: existing license/NOTICE and public-API assessments retain their stated scope; source ownership and protected-hunk approvals are not broadened; actual feature-off/rollback and Native/physical acceptance remain owned by their original tasks and runs. No source rewrite, SDK/pin upgrade, upstream merge, signing change, user-index operation, or new CI run was performed. Native tests executed by this tranche: **0**.

### Retained verification correction

The initial read-only verifier stopped with `exact_unique_32_paths`: it incorrectly assumed that every source-port row had a different destination. The actual historical manifest deliberately maps five original DuckDuckGo files to TabSwitcherPagePort.swift. The corrected verifier keys records by repository, original path and destination, keeps all 32 mappings, checks 28 distinct destinations, and binds each prior-audit row to the same full identity. The initial verifier, input snapshot, execution receipt and failure output are retained. No historical record or product source was changed to make this check pass.
