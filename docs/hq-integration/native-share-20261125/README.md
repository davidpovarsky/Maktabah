# Ordinary saved-note sharing — 2026-11-25

Parent source: `6b330a2964adf30932cfb7e86fc984068c7c5d10` (empty quick-editor fix). SDK API dependency: `73291acd232ead88a3d25dd75848e7fe5bac05f3` on `codex/otzaria-original-annotation-exchange-20261125`, plus any subsequently qualified source fix on that branch.

## Implemented path

The ordinary note sheet offers **Share saved note with Anytype** only for a saved native rich body. The quick-editor text, style and tags must still match the saved note. Sharing captures the actual profile/scene/source/SQLite session before authentication and rejects any changed source across the original account presentation.

The SDK suspends the closed private localOnly editor through the actual original AccountStop/drain. Its actual account/Space UI supplies a nonconstructible account session. The user separately confirms **Send saved note**. The existing SQLite preparation and `dispatch_may_have_occurred` transaction must commit before the same one-use original native import is invoked.

The returned native await is never treated as completion. Only the SDK's independently drained, original readback-verified receipt starts the historical write. Exact native response bytes, mappings, source/destination tuple and hashes are persisted atomically under the originally captured profile database's `.native-import-history` directory with iOS file protection. Replays must match the existing bytes exactly. A closed UI cannot cancel or recreate that late callback. This record cannot be decoded into an SDK account, import attempt or source lifetime.

Success explicitly means **local native copy verified** and states that another-device delivery remains unverified. The pre-existing one-active-attempt SQL constraint stays in force to prevent duplicate native reimports. This change adds no unverified automatic retry, remote ACK, or replacement engine. Genuine continuous update/reverse/conflict transport remains a separate acceptance requirement.

Account closure is retained across dismissal/cancellation, and a failed original Stop exposes an explicit retry. Local suspension likewise exposes a retry for its retained original Stop. The unchanged private localOnly journal is reopened only after the account runtime has actually drained and relinquished ownership.

## Verification

- PASS: actual Xcode/iOS Simulator Swift syntax parsing of the changed production import/UI and normal UI acceptance test, with exact hashes and SDK paths in `SWIFT_PARSE.json` (job `job_f77598cac348446a8a0c6f262f45e339`). This is not typecheck, build, runtime or sync evidence.
- PASS: every literal `OriginalAnnotationEditor` UI key in the file has both English and Hebrew localization; receipt in `LOCALIZATION.json`.
- The existing ordinary production journey now exercises local native editor → original account presentation → actual close → same saved local editor. It sends no note automatically and makes no remote-delivery claim. This added runtime journey is **NOT RUN** pending the candidate SDK and final integrated application.
- Existing 43 + 2 native-attempt/store controls remain reusable for their unchanged SQLite/save implementation. No persistence transaction, original attempt schema or original atomic save file was changed.
- Full candidate app build, actual shared-copy receipt persistence, cancelled late callback write, authenticated live network sync, reverse/conflicts, and 5,000-note acceptance are **NOT RUN**.

## Remaining true acceptance

Qualify the candidate SDK, run the normal UI journey in the integrated app, perform an explicit real import and inspect the actual native receipt bytes/mapping, then verify remote readback using independent original engine processes/accounts. Do not mark stages C–F or TestFlight completion from these source/parsing results.
