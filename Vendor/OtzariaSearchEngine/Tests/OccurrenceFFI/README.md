# Occurrence C bridge verification — 2026-11-20

## Result and boundary

The isolated bridge executes the original exact-single-analyzed-token primitive
at owned-fork commit **d5d59d1269bdf87fb0a6901cf31941726a0c699b**, with original
upstream ancestor **265a14ea54f959a3e266d6e8acfa3a3b98101d68**.

| Actual execution | Result |
| --- | --- |
| New C-export Rust cases, original engine in owned TempDir indexes | 22 passed, 0 failed |
| Existing bridge regression, original assertions and temporary indexes | 12 passed, 0 failed |
| Non-test static library build, no-default-features | Built successfully |
| External C consumer, real public header, static library, original Rust engine | Compiled, linked and ran; six assertion groups passed |
| Apple SDK, Apple binary artifact, Native, full corpus, application capability | NOT_RUN / NOT_CONNECTED |

The 22 and 12 rows are disjoint: the former filtered 12 legacy cases; the latter
filtered 22 new cases. Do not count filtered cases as additional executions.
The existing 1024-book lifecycle test ran in its original owned temporary index.
None of the original engine's optional real-user-path diagnostics were selected.

The application is not connected by this component commit. Exact index/artifact
compatibility, source/database coverage and host capability publication remain
separate gates. A d5 binary is never labelled as source265.

## What changed

- A separate C module adds bounded opaque request IDs and exact occurrence
  execution. Existing C functions and their search behavior are untouched.
- IDs never wrap or repeat and execute once. A cancellation flag and absolute
  deadline exist before the original engine mutex can be awaited.
- The live capacity reservation follows the final Arc lifetime, including
  released requests still returning from engine work.
- The original engine's analyzer, facets, live postings, distinct positions,
  budgets and snapshot proof are authoritative. No text scanner or hit-count
  approximation was added.
- Four declarations were added to the existing header. The only new production
  lib.rs line is the module registration.
- tempfile is a test-only dependency already present in the locked graph.
  Cargo.lock changes only the bridge package's dependency membership, not any
  version or checksum.
- The separate upstream provenance commits 35f46e9dc8df29a4e529e5f63d8a1c474f1f32bb
  and 02c98238619f88a56f0180326c336cc1f4e96dea supply truthful fork source/build
  metadata and retain strict pristine checkout guards.

See CONTRACT.md for inputs, safe caller ownership, one-use/release semantics,
failure codes, finite budgets and source proof boundaries.

## Meaningful runtime coverage

The 22 focused cases cover same-document repeated positions versus legacy
document count; original book/facet dimensions; real deleted postings and delete
snapshot; Hebrew normalization, prefix exclusion and exact zero; unsupported
modes/unknown options/multiple tokens; malformed/UTF-8/null/oversized inputs;
all budgets and excessive limits; nonreuse and one-use; strict capacity; actual
engine-mutex contention with cancellation, deadline and release; concurrent
duplicate execution; cancellation/expiry/release after actual count and
serialization; elapsed time before execution; null/poisoned engine; and panic
containment. The final lifetime case proves release during active work does not
reopen a capacity slot before the final Arc is dropped.

A private cfg(test) scheduling hook only pauses after original engine count and
success serialization. It cannot provide a fake engine, result or proof.
Held-mutex workers own a borrow of the fixture and always join before fixture
free, including assertion failure cleanup. The response is required while the
test still holds the engine mutex.

The external C program includes the real public header, links the non-test
staticlib, adds and commits an owned original-engine index, and calls both the
existing search API and the new request API. Its JSON is independently decoded
by the Python driver. Fifteen labelled responses establish six assertion groups,
including occurrences=2, matchingLiveDocuments=1, legacy totalCount=1, original
Hebrew token, genuine request/snapshot/scope/source identity, one-use,
cancellation, expired deadline, malformed request and duplicate release.
TemporaryDirectory was removed after the run. No arbitrary caller index path is
accepted by the driver.

## Retained unsuccessful attempts

1. focused-attempt1: cargo --offline stopped with exit101 before compilation/tests,
   because already-locked aho-corasick 1.1.5 was not cached. Zero tests ran.
   The next attempt fetched unchanged locked dependencies and passed.
2. c-smoke-attempt1: C compiled but link failed (1120), due to the Clang driver's
   static CRT default conflicting with the actual Rust/native dynamic CRT.
3. c-smoke-attempt2: explicit -fms-runtime-lib=dll fixed the C object selection,
   but inspection with clang -### proved the driver still injected
   -defaultlib:libcmt. llvm-readobj confirmed the Rust native objects require
   MSVCRT, not libcmt. This second link failure is retained.
4. c-smoke-attempt3: the test link command explicitly excludes only that injected
   libcmt and uses the actual rustc-emitted native libraries/MSVCRT. It compiled
   and ran successfully. No bridge/engine source or assertion was changed to
   obtain this result, and no unresolved-symbol bypass was used.

The byte-exact output logs are stored as deterministic gzip files. JSON result
records are copied unchanged. verification.json records source hashes and each
uncompressed log hash. Some source hashes in the runtime record are raw Windows
CRLF bytes; source_sha256_lf hashes separately normalize CRLF for Git comparison.

## Reproduction

From this Maktabah checkout, after the strict checkout script establishes the
pinned original-engine fork:

    cargo test --locked --manifest-path Vendor/OtzariaSearchEngine/ios_bridge/Cargo.toml --no-default-features --lib exact_occurrences::tests -- --test-threads=1
    cargo test --locked --manifest-path Vendor/OtzariaSearchEngine/ios_bridge/Cargo.toml --no-default-features --lib -- --skip exact_occurrences::tests --test-threads=1
    cargo rustc --locked --manifest-path Vendor/OtzariaSearchEngine/ios_bridge/Cargo.toml --no-default-features --lib -- --print native-static-libs

The external Windows C driver takes a build record containing the actual
artifact/hash and rustc native-library line, an explicit directory for that
locked windows_x86_64_msvc native dependency, and a build output directory:

    python Vendor/OtzariaSearchEngine/Tests/OccurrenceFFI/run-c-smoke.py --build-record <actual-staticlib-build.json> --native-library-dir <locked-native-lib-dir> --output <owned-build-output>

Actual commands, paths, tools, timestamps and source hashes are in the evidence.
The compiled 560900320-byte staticlib and executables remain ignored build
outputs and are not repository deliverables.

## Handoff to host integration

The current EngineHandle is still owned by its original caller. New request
tokens safely race with cancel/release, but they do not make a freed or arbitrary
engine pointer valid. The caller must keep the engine alive and cancel/join
active work before free. The future Swift owner must use the existing engine
queue/lifetime, allocate the deadline/request before queue waiting, retain the
request's capacity through queued/in-flight cleanup, and validate the typed
token/source/snapshot proof before returning a numeric result.

This report does not close SEARCH-API or any Apple/native/corpus acceptance gate.
