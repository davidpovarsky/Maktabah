# Sefaria navigation title preference repair — 20 November 2026

## Scope and original acceptance

This tranche addresses a concrete remaining parser defect in Asana [1219850068707719](https://app.asana.com/1/1219597879016953/task/1219850068707719), the Sefaria TOC localization task. The original task requires Hebrew titles and addresses, canonical reference preservation, English without regression, real loading/empty/failure/retry states, varied book shapes, offline/online behavior, RTL and VoiceOver. Its unchanged acceptance snapshot is retained here.

Three original title branches selected Hebrew even when prefersHebrew was false: complex primary shape titles, complex schema nodes and object children of shapes. They also treated empty or whitespace Hebrew titles as usable in some paths. The repair calls the existing LibraryPresentationPolicy.workTitle at those three sites with an explicit he/en locale. Schema nodes retain their original key fallback when both display titles are empty. No new language selector, model, DTO, route, engine, UI or storage path was added.

The original canonical ref, wholeRef/default-node identity, chapter traversal, dictionary headwords, alternate structures and Hebrew folio formatting remain unchanged. The normal Hebrew preference still selects Hebrew; a missing/empty preferred title now follows the existing original display policy.

Production scope: **Source/Sefaria/Domain/SefariaNavigationParser.swift only**, three localized hunks. SOURCE_PRESERVATION.json records exact inverse recovery of all production bytes and all pre-existing test bytes. Two original Hebrew title assertions now pass prefersHebrew:true explicitly; their expected values are unchanged. The added 31 cases are also called from the original NavigationAndPackageTests stage.

## Executed evidence

The candidate was tested as working source on base c6542e412fb5b052d182aacbea685c62bdf8440c. Its hashes identify the repaired source; the base HEAD by itself does not contain the repair.

| Run | Actual result | UTC interval |
| --- | --- | --- |
| Complete original baseline parser, same 31 cases | 31 executed; 20 PASS; 11 FAIL | 10:31:45.920833–10:32:18.900134 |
| Complete repaired parser, same 31 cases | 31 executed; 31 PASS; 0 FAIL | 10:32:54.621829–10:33:13.228418 |
| Original Inspector backend regression driver | All 6 original stages PASS; exit 0 | 10:33:13.341124–10:34:30.320850 |

The baseline failures remain in focused-baseline/CASES.json and raw logs. They cover English schema/shape preference, title fallback/whitespace, primary-title precedence and the original default language policy. The candidate runs exactly the same 31 unique case names and expectations.

The focused runner compiles seven complete production Swift files plus complete original TestSupport. Only the complete named test-case block is extracted into its standalone entry point. No production function is extracted, rewritten, mocked, or replaced. It exercises the real parser, DTO decoder, presentation policy, localization resolver, models and Hebrew address formatter, using original JSON fixtures and clearly marked test-only shape/schema inputs.

For regression, tools/hq-sefaria-navigation-language.py extracts the exact original 38-source invocation and OTZARIA_INSPECTOR_MAPPING_TESTS define from the workflow step Test Inspector backend mappings. It retains the original entry point, all six stage fixtures and seven original JSON resources. Only the installed Windows compiler/output paths and single-job/module-cache settings differ from the Apple driver. All 45 input records are retained. The passing stages are LocatorAndRefTests, DecodingTests, NavigationAndPackageTests, LegacyIdentityRegistryTests, BackendCoordinatorTests and UnifiedSearchArchitectureTests. No uninstrumented assertion total is claimed.

Installed Swift was 6.3.3 on Windows. Focused compilation used Swift 6 and complete strict concurrency. All three compiles returned zero and emitted no compiler warnings; their stderr contains only the Windows linker library message. The intentionally failing baseline executable returned 1; the candidate and full regression returned 0. The existing Inspector module cache was reused; no SDK, corpus or SwiftPM copy was created. Source and copied-input hashes were checked before and after execution.

## Source identity and preservation

Canonical Git LF parser SHA256:

- Baseline: 651c555044682f5389bfbfc085f7a509bdd97906a388a64b199241c90303c7a3
- Candidate: 9aa0913e30f11146dcc2268bdcb1b609ed9ef0996fce6967467e9edb583a8c99

The canonical input difference between baseline and candidate is only the parser; the same tests, dependencies and resources are used. Current source hashes still match the successful candidate and regression inputs at sealing. SOURCE_INPUT_BINDING.json records the checks; raw input manifests retain both physical bytes and canonical LF hashes.

Upstream was read at d46af139b3a265399c16d87f5923acd8e3444024, with merge-base a0ed0df908a6cb38bc459d4baaeb400f447b2fc4. This parser and its test path are fork-owned and absent from that upstream tree. No protected upstream file was rewritten. A read-only peer review of all three hunks and the original title helpers found no concrete source/type blocker; that review did not run tests or Apple tools. The pre-existing schema rule where an empty primary title suppresses another same-language alias remains unchanged.

## Retained evidence and limits

Each run directory retains RESULT, INPUTS, COMMANDS, case outcomes where applicable and exact raw compiler/runtime streams. Raw logs and preparation records are losslessly gzip-compressed with original byte hashes in RAW_SOURCE_MAP.json. Executables remain in the owned ignored build directory, with sizes and hashes in RESULT.json; executable binaries and duplicate corpus/resources are not committed. ARTIFACTS.json seals the exact committed Git representations of this evidence.

**Apple SDK/Native UI, live Sefaria network or offline-store execution, RTL/VoiceOver and physical-device acceptance remain NOT_RUN for this tranche.** The original task remains OPEN. This repair and the portable regression evidence do not establish the separate loading/retry, actual rendered TOC or accessibility acceptance conditions.
