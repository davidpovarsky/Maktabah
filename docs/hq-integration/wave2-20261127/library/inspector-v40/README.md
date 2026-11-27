# Exact full-v40 Inspector source oracle

Status: **source oracle prepared; native Inspector UI execution is not yet accepted**.

## Source admission

The database is the existing production source at
`/mnt/development/projects/worktrees/Maktabah-core-final-20261126/build/v40-index-fixture/seforim.db`.
It was opened only for reading; SQL connections use `mode=ro&immutable=1` and
`PRAGMA query_only=ON`. No copy, migration, corpus download, or source write was performed.

`SOURCE_IDENTITY.json` records one fresh complete SHA-256 read of all
4,355,063,808 bytes, from 2026-11-27 00:28:01.781862 through 00:29:54.015493 UTC
(Sentinel job `job_3e076c7c2b82`). The digest is
`8389709c1702753af6f0719ef1c98c09854450e48ebb05fe1f95486b26348b01`.
Device, inode, size, mtime, ctime, and mode are identical before and after that
read. The generator checks this witness again before and after its bounded SQL
queries. A current stat by itself is not presented as proof of continuity with
the older hash run.

The 8,259 books, 7,925,185 lines, and 7,001,824 links are explicitly reused from
the prior full-source receipt in commit
`b33c7eb11d7c2a6f9aa8891fc2a3843d2acdc830`, whose complete database SHA-256 is the
same. These counts were not recounted in this admission run.

| Artifact | Bytes | SHA-256 |
| --- | ---: | --- |
| `SOURCE_IDENTITY.json` | 1,112 | `9b9077fb62991b0c0a1859343989ee8607de286ae9f470ca96a2f3c311e23c88` |
| `ORACLE.json` | 73,525 | `53694dd13202791d02b223a03c88d9c550bd840749884fc576d15928aef4dff6` |
| `Scripts/CI/prepare-production-inspector-oracle.py` | See Git blob | `74c4f8d773bb2716866b803d6436799de70d99493d9fc04f72da57c8e41b50c6` |

## Independent expectations

The generator reads original book, author, TOC, line, link, link-coverage and
suppressed-side tables. It does not read an application relationship cache or
turn a native row count into an expected count. Original `line_content` frames
are decoded with their actual `zstd_dict` dictionaries; selected full text is
normalized only for Unicode composition and whitespace comparison.

The oracle identifies original Psalms book 28, chapters 1, 75, and 150. The real
TOC starts are line indexes 1, 1258, and 2671; their inclusive ends are 7, 1269,
and 2677. It retains the complete source-ID membership of the selected author
groups, both for each chapter and for every individual line in those chapters.

| Real chapter | רבי דוד אלטשולר commentary entries / works | רבי אברהם סבע quoting entries / works |
| --- | ---: | ---: |
| 1 | 38 / 11 | 4 / 1 |
| 75 | 32 / 4 | 4 / 1 |
| 150 | 16 / 7 | 1 / 1 |

All three David Altschuler groups contain both actual Psalms works:
3323, `מצודת דוד על תהילים`, and 3436, `מצודת ציון על תהילים`.
The quoting samples come from actual work 3554, `צרור המור על התורה`.
Chapter 150 additionally contains separate real commentary groups for
`רבנו משה בן מימון [הרמב"ם]` and `רבנו משה ב"ר נחמן [הרמב"ן]`, with one entry
each. The oracle preserves their distinct IDs; it does not merge similar names.

This is a curated semantic oracle, not a total count of every Inspector author
or every link in the corpus. Its commentary counts include all observed members
for the declared authors in these windows. A bounded audit of excluded metadata
candidates found only base-book `OTHER` links to Mishneh Torah (books 297, 298,
308 in chapter 1; 305, 336 in chapter 150). Those belong to the Links category,
not these commentary groups. Chapter 75 had no excluded metadata candidates.

## Original producer and upstream provenance

The expected source-ID and author/work grouping contract was checked against
the app source at `947e4ccf9f9b7e1487bd6722ee5dd39822f7c5fb` and the pinned
TorahInspectorKit revision `23db0f84e88d9ee9c7053c49de86903fc7bb5785`.
Relevant original producers are `MaktabahTorahInspectorAdapter.swift`,
`OtzariaLineSourcesService.swift`, `OtzariaRelationshipClassifier.swift`, and
Kit `Models.swift` / `TorahSegmentDetailView.swift`.

The oracle generator and these evidence files are additive downstream files.
The planned existing registered UI test path
`Maktabah-iOSUITests/DeepLinkedCommentaryAcceptanceTests.swift` is absent from
upstream `bismillah-100/Maktabah` at the verified exact revision
`4203de5fd77beb119e5826e039be1a61325f7be0` (`git ls-tree` returned no entry).
Its original downstream file SHA-256 before the additive UI work is
`60f784dde093bb9e21de40a58281e972fe6915fa7af26e8a42dc59012605d16d`.

## Acceptance boundaries and next run

The accompanying original-UI semantic case is being prepared separately. It
must run on the retained managed-v40 simulator and compare genuine UI counts,
source cards, copied source text, linked-reader content, and selected-line
membership with this oracle. Original Add Note/Save can persist the selected
backend locator for a read-only witness; raw annotation rows are never injected.

Source preparation does not prove UI execution, loading/error/cancel behavior,
performance, or a physical-device result. Natural 100/500/2000 relationship
windows and resource observations remain owned by the separately qualified
full-v40 Reader/Inspector tests; they are not inferred from these group counts.
When combined accessibility hides a rendered body, screenshots still need
review to rule out visual snippet duplication.
