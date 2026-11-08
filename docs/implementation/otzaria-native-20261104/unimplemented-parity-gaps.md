# Remaining acceptance work (checkpoint)

These are explicit pending items, not claims of parity:

- Real iPad Hebrew/English TOC, selection/inspector source navigation, preview source/translation/both, background/reopen and three-backend regression acceptance.
- Physical-device acceptance of edition selection, restored original footnotes, and restricted export actions. Their native implementations and real SQLite fixtures exist; device interaction is not yet verified.
- Sacred-name substitutions are NOT_SUPPORTED_YET. Packed original spans are decoded and source text preserved; no unverified religious transformation is applied. Word highlights remain absent when a reliable Unicode/HTML/source map cannot be established.
- Reference codec passes pinned fixtures; work-scoped repository exists, but a global ambiguous reference is never resolved by choosing the first book.
- Cancellation now uses the upstream Arc-backed handle through a separately owned C registry. A native Rust test verifies cancellation while the engine mutex is held, all three lexical modes/counts, isolation of unrelated request IDs, and registry lifetime after engine close. Apple SDK/runtime acceptance is still pending.
- Production and miniTest10 schema10 index artifacts and final synchronized build are pending.
- Delta updater is deliberately outside the approved initial scope. Production semantic search remains unavailable without a verified model and supported runtime.
