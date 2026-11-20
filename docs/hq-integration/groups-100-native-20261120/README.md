# Additional Native coverage: 100 original group switches

Status: PREPARED / NOT_RUN. Apple typecheck and Native execution have not run for this new case. No task is marked complete.

## Requirement and exact scope

Asana task [1220107239748221](https://app.asana.com/1/1219597879016953/task/1220107239748221) explicitly requires “100 rapidly switching groups.” Its original acceptance also requires production data and physical hardware. ASANA_PROVENANCE.json preserves the fresh task read, including those qualifications. The existing 20 round trips exercise 40 group switches; they do not establish 100.

This change adds one iPad test:
StudyGroupStressNativeAcceptanceTests/testOneHundredConsecutiveOriginalGroupSwitchesPreserveDocumentsAndColdRestore.

It uses the original normal bootstrap (.realUI), original miniTest10 fixture, original StudyGroupsOverview and ScrollableTabBar controls, and a fresh UUID namespace. It prepares three one-book groups through the original group-copy action. It performs exactly 100 consecutive, acknowledged, different-group transitions without sleeps or artificial pacing. Preparation transitions are excluded from the count. It does not simulate overlapping commands while the original selector is disabled, measure product p95/memory, establish production-data acceptance, or supply physical-device acceptance.

## What constitutes a counted transition

Before fixture cleanup, the test verifies the miniTest10 launch arguments and environment, absence of the bootstrap bypass, the matrix-derived canonical fixture book, one exact namespace sidecar, and the actual Simulator container metadata identifying com.davidpovarsky.chavrusatext. The original one-book preparation runs through native close actions only. It is reused through a same-file wrapper; its body and actor annotation remain unchanged.

Every counted transition must change both the original group UUID and document UUID. The following must agree before the count advances:

- The original persisted scene, profile, group, active document and increasing revision.
- The original native group selector's enabled state and selected value.
- The exact original selected overview card UUID, selected state and hittability.
- All three groups' original membership/order, active documents, canonical locators and retained search state, plus each group's independent scene document selection.

Revision is a persisted observation, not a claim about a Core lease or native acknowledgement. The selector becomes enabled only after the original switch operation finishes; the passive observer checks it together with the persisted and card identities. The observer is an explicit MainActor object, so the predicate does not transfer a local function that implicitly captures XCTestCase/self.

All three readers are hydrated and their genuine visible locators checked before the baseline is pinned. After the 100th committed transition, the original reader must return to its retained locator. A genuine process termination and catalog-scenario relaunch must restore the exact final group/profile/document and original semantic membership/locators. A new system scene identifier on relaunch is allowed, as supported by the original scene restoration owner.

## Evidence volume and failures

Each attempt and accepted transition emits a compact GROUP_STRESS_OBSERVATION JSON record. The report records the actual completed count and a separate coldRestoreVerified value. A teardown attachment retains partial progress if the test fails. Full sidecars and native AX/screenshot pairs are retained at three stress checkpoints; the reused one-book preparation and original R27 teardown retain their own existing bounded evidence.

The recorded elapsed seconds include XCTest delivery, original commit and AX observation. They are not app latency or p95 measurements. The existing 600-second per-case gate is unchanged. A timeout or failed transition cannot count as 100.

## Integration and preservation

Base app/test source: 0f5111e8f8e379e17da558ddbe2aab5214ac0315.
Owned branch: codex/otzaria-groups-100-native-20261120.
Only the existing FaithfulReaderUIAcceptanceTests.swift file is appended. Its complete original Git-LF bytes remain an exact prefix. The file is already registered through the Maktabah-iOSUITests synchronized source group; no project registration change is needed.

EXTRA_SELECTION.json is a proposal for Root's next freeze, not an edited active manifest. Append this case to the iPad11 execution group (label 11, HID false). Retain all 92 original IDs as a required subset. The proposed next full Native count is 93: 73 iPad / 20 iPhone. No original case is replaced or reclassified. The full Release manifest remains byte-identical at 96 UI executions plus two original oracles across five configurations.

The existing matrix supplies FAITHFUL_VIEWPORT_DIRECTORY and validates the installed miniTest10 fixture before deriving R27_EXPECTED_OTZARIA_WORK_KEY and R27_EXPECTED_OTZARIA_BOOK_TITLE. No URL-transport or HID service is required by this new case. R27 source, per-case timeouts, all Source/Vendor/project files, both canonical manifests and workflow/runtime drivers are unchanged.

The next freeze must bind the new Faithful canonical Git-LF hash, exact app/test source and original source closure. Only Root may derive/freeze/dispatch the next immutable branch.

## Actual validation and limits

SWIFT_PARSE.json and swift-parse.log record Swift 6 frontend syntax parsing of the complete modified file, exit 0, no diagnostics. This is not Apple typechecking or an XCTest execution. SOURCE_PRESERVATION.json records the exact prefix, source hashes, unchanged original manifests and declarations, original target registration and unchanged product trees.

No UI PASS, 100-switch result, cold-restore result, p95, memory result, production-data result or physical-device result is claimed here. The Profiles QA task remains open pending its full actual acceptance.
