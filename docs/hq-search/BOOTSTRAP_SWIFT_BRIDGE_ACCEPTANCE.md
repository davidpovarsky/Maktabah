# Existing bootstrap Swift bridge acceptance extension

15 November2026, S thread01a1df8a-df83-7f53-a190-7e582a40aaba.
Assigned worktree C:/Users/DAVID/Code/Maktabah-hq-search-20261115;
base eb2f321a343a2c66381f50dadd37c94c49bb5cd0, verified clean before edits.

Manager's narrow follow-up lease authorizes ONLY the existing
populateSearchState method in downstream-owned
Source/Otzaria/Bootstrap/OtzariaNativeBootstrapAcceptanceRunner.swift, plus S
tests/evidence. File is absent from original upstream
d46af139b3a265399c16d87f5923acd8e3444024; existing file origin revision
8e72dd22cf058d29e39410adf3d749ad05c0ad74. No other bootstrap method, flag,
report/interface, Otzaria check, CI input or simulator selection script changes.

The existing installed-artifact readiness, actual paths and actual
ZayitSearchEngineBridge remain the production path. Its original בראשית request
is retained with near5/offset0/limit25. The method now requires:

1. A genuine nonempty baseline with a positive raw document total.
2. Two identical warm requests preserving ordered IDs, source book/work/line/ref,
   total and last-page state.
3. The SAME query/near/offset/limit scoped only to the actual first-hit source
   book; it must remain nonempty and every returned hit must belong to that
   book/work. The original unfiltered request must still match after filtering.
4. Explicit close/reopen of the SAME bridge and installed paths, then the SAME
   frozen request preserving the same IDs/locations/total/last-page state.

Any inconsistency throws the existing validationFailed error. The unchanged
outer report catches errors and remains responsible for failure publication;
zayitSearchResults is assigned only after every proof succeeds. The original
Otzaria document count/query and both engine cleanup paths remain intact.

## Executed checks

`python tools/hq-search-tests.py --bootstrap-search-only` extends the EXISTING
portable harness, extracting the exact leased method unchanged and compiling it
with the REAL Zayit Swift request/page/hit models. All engine/install/DB boundaries
are explicit doubles; no new app or simulator harness is created.

Swift6.3.3 Windows, complete concurrency checking:49 assertions across12 scenarios
PASS. They cover healthy frozen parameters/report/cleanup, empty initial response,
warm total/ID/location drift, empty or foreign-book filtered results, post-filter
drift, reopened total/ID/last-page drift and unavailable artifact. Existing Otzaria
checks and cleanup execute once in every scenario. Method normalized UTF8 SHA256:
a495ef12af7782fa858e86c6f596c9a3c38323250ee1b67e1fde923ff334cd8c.
Log: wave-bootstrap-search-tests.log. Full source frontend syntax parse is also
recorded; that is not Apple typechecking.

## Native gate still OPEN

This packet adds the requested genuine app-side acceptance assertions; it does
NOT claim those assertions have executed on Mac, with the rebuilt XCFramework,
or against an actual installed miniTest10 payload yet. The manager's existing
disposable INSTALL_SEARCH=1 bootstrap path must run it with the exact matching
fresh Zayit binary before Reader UI cases. A behavioral PASS is not a substitute
for the binary/source identity gate. Physical iPad acceptance remains separate.

No new dataset download/rebuild, schema/user-data change, project/CI edit or call
to run-mini-test10-bootstrap-acceptance.sh was performed. The existing fixture
and original report interface are reused. Rollback is this single method hunk
and its focused tests/evidence; no data recovery is needed.
