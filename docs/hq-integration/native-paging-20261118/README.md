# Native search page acceptance

Status: SOURCE_IMPLEMENTED / NOT_RUN. The 54-case run 44320497938 remains pinned to c0599822 and is not cancelled or credited to these later changes.

## Real acceptance gap

The existing zero-match projection tests establish that one explicit Load More request changes the visible loaded count. They do not prove every retained provider field across 50/100+ rows, exact raw cursor progression, identity stability after later pages, or opening a later-page result.

Two additional real-app tests now require:
- Zayit: at least three original provider pages, at least 150 unique published UI rows, and true offsets consuming raw rows.
- Otzaria: at least two original engine pages, at least 200 unique published UI rows, and preservation of the complete original metadata associated with each identity.
- Source book, line, title and locator checked against the independently sealed original miniTest10 SQL metadata.
- No local-title matches while explicit paging; then restored original UI list, the same query, no page error/dirty state, and a real later-page result opened by its existing preview/Open controls.
- Original TextKit content, exact canonical Reader locator/title and a nonzero rendered search highlight.

## Observation boundary

The original models expose optional DEBUG-only observation closures immediately after their normal generation/cancellation-checked page commits. These closures cannot return replacement data and do not intercept the engine, cursor, result store or UI.
The original unified session writes observations of both real provider pages and the actual published UI result array. Observation is enabled only with the explicit GlobalSearchNativeTraceEnabled launch flag, the original miniTest10 profile, and a valid per-test studyWorkspaceTestingNamespace UUID.
The file is confined to the installed app Documents/OtzariaLogs/search-native-UUID.jsonl, capped at 8 MiB. Query fields are removed and SHA256 recorded. Fixture source metadata contains actual snippets/terms. All hooks and exports are absent from Release builds.
The native test independently compares raw engine rows, the complete retained original records, the actual published UI model and the sealed SQL map. An observation alone is not a UI PASS; native controls and Reader assertions remain mandatory.

## Verification so far

Windows Swift frontend syntax parse of all four changed source/test files passed with DEBUG enabled. This is not Apple SDK typecheck, application build, Native execution or performance proof. The observer is intentionally disabled in unrelated performance tests.
All original 54 Native methods remain selected; the matrix adds these two tests to the search group. No retries, skip conditions, fake provider, source result count assumption or changed Reader oracle were introduced.
