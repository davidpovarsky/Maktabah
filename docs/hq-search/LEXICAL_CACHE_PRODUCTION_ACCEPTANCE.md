# Actual v32 C ABI corpus acceptance and selected-expansion cache correction

S, thread01a1df8a-df83-7f53-a190-7e582a40aaba, 15 November2026.
Worktree C:/Users/DAVID/Code/Maktabah-hq-search-20261115.
Original upstream d46af139b3a265399c16d87f5923acd8e3444024 remains unchanged.

## Source ownership and runtime correction

`Vendor/ZayitSearchPort/Rust/src/magic_dictionary_index.rs` is the downstream
read-only Rust port/bridge, added in fork commit
0985b29c6b1ad6d9945b0e3042387ce8853b37c9. No imported upstream reference or
Otzaria engine source changes. Manager explicitly confirmed this scoped fix and
owns the matching binary/CI integration.

On a cache miss, expansion_for selected the preferred `best` lexical meaning,
but stored ALL candidates in hash-map order. On a cache hit it returned the first
stored candidate, which could be another lemma. The same query's warm, filtered
or paged follow-up could therefore change meaning and return zero in a book that
had just matched. The correction caches only the selected expansion (or the empty
negative result). The selection rule, C ABI, engine version, schema and index
files remain unchanged. No index rebuild/download/reset is needed for this bug.

The public regression creates a real disposable lexical SQLite database with64
ambiguous tokens. Its first call must choose the normalized-base meaning; three
warm calls must retain exactly that meaning. Restoring only the old cache write
produced RED on tokenמילה0: actual baseאחר0 versus selectedמילה0. Restored
correction passed. Evidence: wave-lexical-cache-red.log and
wave-lexical-cache-tests.log. This is one Rust test, not256 independent tests.
The scoped Rust library/binary/SQLite fixture suite also passed14 tests,0 failures
(its production case remains explicitly ignored in the default suite). The
production case was separately actually executed and passed as documented below;
an ignored status is never counted as runtime PASS.

## Genuine production data, independent of mini fixtures

The existing audit tool gained an explicit isolated reconstruction mode, reusing
the existing release workflow's part/offset/zstd verification. All writes are
under the NEW ignored build/hq-search-v32-fixture-20261115 directory. No installed
user package, settings, reader session or database was opened/changed/deleted.

- Actual Zayit v32 parts:74 compressed SHA256/size-verified files reconstruct
  3,746,522,849 bytes using exact destination offsets/uncompressed sizes.
- Canonical schema6 database:3,821,240,320 bytes, SHA256
  2f4dcd72e8bdb1fc5c0516ae9705e57759c017ec2981b49c35115625c3d3f765,
  reconstructed from the separately SHA256-verified official compressed asset.
- Actual lexical.db v0.3.0:57,122,816 bytes, SHA256
  b42e36626802629fed178068e8cf11f0f034d6f24ae3b72ac9999b9311bf299f.
- Index artifact identity:
  81cc25fa8fc3cf4612a5a4d23377daaac28b4b1293eb78be44c2d192f8cdb2e3.

The lexical file is a runtime download, not a bundled repository file. The first
reconstruction attempt stopped after successfully verifying the index and
canonical database because the helper assumed a bundled path. Corrected finish
mode reverified every retained compressed part/final size and canonical database,
downloaded the pinned lexical asset, verified it, and only then wrote the ready
marker. Earlier logs are retained; the final gate is in
wave-v32-reconstruction-audit.json and wave-v32-reconstruction-finish.log.

The canonical v32 book table has no filePath column. The test oracle first assumed
that optional column and failed; it now reads PRAGMA table_info and verifies the
documented book:<id> fallback. That setup failure is not a product root cause.
The close/reopen oracle also initially compared different limits20/50; it now
uses the SAME frozen query/near/offset/limit50. Page-size ranking differences are
outside this correction, not silently treated as an identity regression.

## Real engine / C ABI execution

An explicitly ignored production case extends the EXISTING
fixture_index_search.rs C ABI test, using only the verified owned fixture marker.
Rust1.92.0, x86_64-pc-windows-msvc. No FFI, SQLite, index or lexical doubles.

- Four genuine Hebrew queries (`משה`, `שלום`, `בראשית`, and the existing release
  golden query) return hits both globally and filtered to their actual first-hit
  source book, using near5/limit50. Repeating each global query after warming the
  cache preserves its actual total and first-page line IDs.
- Actual paging forמשה with near0/limit50 at offsets0/50/100 returns50+50+50
  hits,150 distinct source line IDs. Every ID/book/line-index/stable-work-key is
  cross-checked against the REAL canonical SQLite tables. Snippets and matched
  terms are nonempty; totals/last-page state stay stable.
- Engine destroy/reopen with the SAME query parameters preserves the total and
  exact first50 IDs, without rebuilding the index.

Final executed case:1 PASS,0 failures,13.56s test execution. Earlier intermittent
scoped-zero failure on old code is retained in wave-v32-filter-regression-red.log;
the earlier healthy pre-reproduction report is explicitly separate. The final
report sets IN_PROGRESS before execution and marks PASS only after all checks.
Artifacts: wave-v32-real-ffi.json and wave-v32-real-ffi.log. Totals are raw matching
index documents with explicit request parameters, NOT exact occurrence counts.

## Native and device gates

This proves a real runtime cache defect on actual production data, not the
physical user's exact root cause. Windows C ABI acceptance does not validate
Swift/Combine/UI scrolling, app installer/reuse, installed user manifests,
background/tab restoration or physical iPad behavior. These Asana tasks stay OPEN.

NEXT coherent native chain must rebuild Zayit's XCFramework from the accepted
exact Rust source using the existing
Vendor/ZayitSearchPort/Scripts/build-ios-xcframework.sh, and verify its source
digest. The old framework is a baseline only. Manager owns CI/helper wiring and
one watcher. Otzaria engine source/pins remain frozen and reused. No TestFlight,
release, production publication or index-schema change was performed.

Rollback is a targeted source/test/tool revert and corresponding binary rebuild;
no user data rollback or destructive package recovery is required.
