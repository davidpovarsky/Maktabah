# Inspector lane discoveries

- [x] 2026-11-15: shared Inspector metadata-first loading did not eliminate the legacy reader-tap eager fetch. Removing its unused prefetch avoids an independent full-commentary decode. Keep future reader entry paths routed through the shared repository.
- [x] 2026-11-15: book-scoped annotation caching does not make a cold cache free of SQLite work. Inspector now loads cold notes asynchronously and checks generation/backend/book before returning them.
- [ ] Production acceptance must measure the interval before SQLite yields a row and time spent waiting for the shared database lock: row/chunk task checks cannot interrupt those waits. Record this separately from UI response and stale-result rejection.
