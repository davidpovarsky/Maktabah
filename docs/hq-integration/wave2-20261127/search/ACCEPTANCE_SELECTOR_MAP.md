# Search-owned F/R acceptance selector map

This is a source/selector handoff, not an acceptance closure. Candidate native runs are still required on the exact integrated app and source-qualified inputs. Component controls, an API capture, a miniTest10 run, full-v32, full-v40, and a published-package UI installation have separate scopes.

## Source requirements

- Canonical F01–F10 and original R01–R04 summary: Asana task 1219602719070497.
- Search context/language/version/Open acceptance: task 1219603012547016, A01–A07 and A12–A15.
- Zayit pagination: task 1219603004720303.
- Exact Zayit hit identity: task 1219602829324347.
- Actual SQL line identity: task 1219602829298459.
- Cumulative Otzaria page metadata: task 1219602829324283.
- R05–R08 definitions recovered by integration root from task 1219602987688812: request generations/cancellation across backends and selected scope; localized Hebrew/English UI, RTL, Dynamic Type, VoiceOver; safe HTML/mark/Nikud and offsets; production+miniTest10 database/index compatibility, cold offline reopening without repeated downloads, and absence of giant databases in the IPA.
- The historical completion comment on task 1219603012547016 does not prove the new source's full text or real three-edition later-page body cases.

## Search and shared selectors

All names below are in the registered Maktabah-iOSUITests target. New original full-context cases are described in native-context/TEST_CONTRACT.md.

| Requirement | Exact source-qualified selector/evidence | Candidate boundary |
| --- | --- | --- |
| F01 full paragraph/chapter for נפשי | PublishedProductionSearchDataTests/testPublishedV40NafshiFirstPageForIndependentFullContextOracle, then /testPublishedV40NafshiFullParagraphAndChapterMatchEveryOriginalSourceSegment | First case only selects real provider hits and checks SQL. The second requires the independently compiled original service/presentation oracle and every actual native text node. No acceptance before both phases execute. |
| F02 Hebrew/source/translation/both | SefariaFullSearchContextAcceptanceTests/testHebrewUIEnglishResultHonorsOriginalSourceTranslationAndBothControls | Actual public Sefaria bilingual response, Hebrew UI, genuine source and selected English edition. Never infer translations for production Otzaria. |
| F03 original Zayit paging | PublishedProductionSearchDataTests/testPublishedV40ZayitPages50_100_150RetainSQLIdentity | Actual published artifact and installed v40 SQL, counters50/100/150, source IDs/order/metadata. Existing mini selector GlobalSearchNativeAcceptanceTests/testZayitThreeNativePagesRetainCanonicalIdentityAndOriginalMetadata remains a distinct mini regression. |
| F04 three editions, third on later page | SefariaFullSearchContextAcceptanceTests/testThreeActualSefariaEditionsAcrossTwoPagesKeepDistinctCompleteBodies | Real soul/Psalms canonical pages100+100, Psalms35:17 editions at offsets98/99/100, one canonical card and all28 complete translated segments. API captures and24 component controls are not this UI pass. Selected-edition Reader persistence is not claimed. |
| F08 exact Reader Open/focus | Reader agent's FullV40ReaderModeAcceptanceTests/testOriginalSearchOpensLineParagraphAndChapterAtExactSourceFocus; existing GlobalSearchNativeAcceptanceTests/testZayitCanonicalRowOpensOriginalReaderAtExactSourceLine and /testZayitNonzeroSourceLineRetainsExactOriginalTextAndHighlight | The original Reader Open path has its own rendering oracle. Search preview text is not interchangeable with Reader raw/rendered text. Existing mini line cases do not accept full-v40 chapter/paragraph Open. |
| R01 exact hit identity | Original stable-ID dispatch plus the actual source ID checks in production and mini Zayit paging/Open selectors above | Do not accept a title/book+line proxy as an exact hit. Source identity must remain bound to the actual provider record through Open; cross-query/stale scope remains subject to original cancellation/routing tests. |
| R02 real SQL line IDs | Every production page row reads immutable SQL id/bookId/lineIndex; F01 validates every real anchor/segment ID; Reader F08 uses its separate exact destination/focus oracle | No content.id+offset arithmetic, no inferred line IDs from newlines, no fixture arithmetic promoted to full production. |
| R03 cumulative metadata beyond100 | PublishedProductionSearchDataTests/testPublishedV40OtzariaPagesRetainCumulativeSQLMetadata; existing GlobalSearchNativeAcceptanceTests/testOtzariaNativePagesRetainCanonicalMetadataBeyondOneHundred and /testActualPageFailurePreservesRowsAndRetryAppends | Full-v40100/200 source/page/item agreement is separate from mini error/retry controls. Verify tab return, new query and missing-metadata behavior against their actual receipts. |
| R05 generations/cancellation and selected scope | GlobalSearchNativeAcceptanceTests/testHeldSearchCanBeCancelledWithQueryVisible; /testModeEditRequiresExplicitRerun; /testOptionsDismissalReturnsToSameQueryWithoutSubmission; /testLocalTitleFilterPreservesInputsAndRestoresOriginalIdentity | Controlled provider hold/cancellation has its own evidence scope. Cross-backend stale Reader transitions are owned by reader/integration; do not infer them from a pure UI visibility check. |
| R06 Hebrew/English, RTL, Dynamic Type, VoiceOver, resizing | /testHebrewHeaderUsesActualRTLGeometry; /testEnglishHeaderUsesActualLTRGeometry; /testHeaderAndHistoryNativeAccessibilityAudit; new source-qualified F01/F02/F04 viewport assertions | The audit remains unfiltered. Native116 had a real audit failure and one Apple AX process crash; source fixes are hypotheses until exact native rerun. Sefaria TOC localization is reader-owned. Orientation changes prove actual viewport resizing, not Stage Manager. |
| R07 safe presentation, Nikud and offsets | Actual production presentation helper in source oracle; /testZayitNonzeroSourceLineRetainsExactOriginalTextAndHighlight; Reader F08 and Reader annotation/highlight cases | Complete preview text and canonical IDs are checked independently from Reader UTF16 range/focus/highlight and unsafe-HTML sanitization controls. Do not conflate these gates. |
| R08 data/index profiles, cold offline reopening and distribution | PublishedProductionSearchDataTests/testPublishedV40PackagesInstallThroughOriginalSearchDataAndColdReopen plus both production page cases; existing SearchDataNativeAcceptanceTests mini recovery cases | Published UI installation/cold readiness/local queries are distinct. Per-process real network denial and physical offline still require their own negative public-request proof; no icon or fixture-error control supplies it. Library/IPA packaging checks are owned by root/library. |

## Other F/R ownership

| Requirement | Owner and precise boundary |
| --- | --- |
| F05 links for selection/whole unit, natural link scales, cancellation/errors | Reader/Inspector agent. Full-v40 relationship-scale/return test and actual link payload receipts; selected-range and whole-unit semantics must each be verified. |
| F06 one expanded card without duplicated content | Reader/Inspector agent. Requires actual complete content/expansion evidence, not merely a nonempty title. |
| F07 notes/SQLite repeated cycles | Wave3 UI/groups agent. Original note UI and30-cycle statement/reset coverage remain separate. |
| F09 same author, two works, multiple chapters | Reader/Inspector agent. Require actual distinct canonical works/chapters and payload-derived grouping. |
| F10 commentary versus commentary quotations | Reader/Inspector agent. Require real classifications, counts and complete linked content. |
| R04 getLinksForLine errors | Reader/library agent. Empty genuine links and surfaced source failure must be distinguished. |

## Preserved evidence

No published search artifact was rebuilt or replaced. The full7,925,185-document source validation, public release manifests, original Zayit pagination, full-v32 receipts, v32-to-v40 installer upgrades and Reader performance receipts remain separately qualified.

Source controls retained here: bounded history baseline11/2 versus13/0; offline refresh state fixture6/2 versus8/0; exact selected-edition/source-mode Apple controls12/12 versus24/0. These are component controls. None establishes actual UI, network loss, full production index installation or source compatibility beyond its recorded inputs.
