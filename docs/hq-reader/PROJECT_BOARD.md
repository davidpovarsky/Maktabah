# Private reader-lane follow-ups

- The original `Reader+Content.swift` still constructs the neutral render model
  synchronously after async section retrieval. R's normalization optimization
  preserves full genuine book output by SHA256 and reduces portable work, but
  does not move that callsite off MainActor. Profile the coherent Apple app;
  only introduce a scoped upstream hook if actual native evidence requires it.

- Line-mode metadata now uses bounded indexed row/neighbor queries (wave R,
  15 November). Paragraph/chapter still index the whole book; measure those
  modes on the full corpus before choosing an incremental index/window design.
  Preserve the existing sparse membership and per-root title semantics.
- Async reader/selection requests must retain the generation captured before
  worker admission, not only the generation obtained by the worker. Both can
  be current independently while the request spans a database replacement.
- Generic reader providers must propagate source and navigation SQL failures;
  optional legacy bridge wrappers erase them and can make a partial fallback
  look like a complete chapter or an absent neighbor. New adapter regressions
  preserve this boundary without changing the shared bridge API.

- Metadata min/max spans are not semantic membership when TOC units interleave. Any future index/window optimization must retain actual line sets and summary adjacency; the new sparse fixtures should stay in its acceptance gate.
- The changed LEFT JOIN query preserves partially mapped source rows. Validate production indexes/query plan and first-content timing on the actual schema before claiming faster startup; the in-memory fixture only proves SQL coverage.
- Full corpus and physical iPad acceptance remain open for all three PERF tasks. Retention budgets and Windows synthetic timings do not establish UI hitch/RSS/SQLite-lock behavior.
