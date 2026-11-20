# Candidate verification and remaining Apple gate

Production candidate: **`39ba01a0e014e41272ea53aa28ca8a24656f21e1`**.
The preceding RED evidence is committed as
`95b8bd88db0ce24e00c9561b8469f19b29046f4b`; the earlier 0-executed setup
failure is retained. This report does not replace or reclassify those results.

## Implemented change

The original mounted-root identity enumeration now lives in synchronous
`intentRootEntities()`, with cancellation and complete backend-snapshot checks.
`NativeIntentService.readerWindows` has its own host-injected metadata resolver,
the original query/ID/catalog limits, duplicate refusal, cancellation before and
after resolution, and a Library-root-only result filter. The optional initializer
argument preserves existing callers. Neither metadata resolver grants navigation.

All three original `NativeReaderWindowEntityQuery` methods and the initial
identity lookup in `openReaderIntent` use that metadata path. General system
entity discovery still observes original live Search controls and the Inspector.
The original foreground wait, fresh post-wait discovery, exact selected window,
source generation, original Reader resolver, Core and native receipt path remain.

DEBUG diagnostics at the existing dependency closures use fixed literal stages,
an allowlist of internal `UIRouteError.code` values and the typed status enum.
Unknown codes are `unclassified`; cancellation is a fixed value. The function
does not log requests, queries, source content, identifiers, tokens or raw error
descriptions. Every catch rethrows the same error. Release builds omit the
diagnostic body.

## Actual results

| Verification | Actual result | Evidence |
|---|---|---|
| Exact original-method metadata fixture | **15/15 PASS**, 0 missing/failed, 0 compiler warnings; 17.844-second compilation | `job_c5493c46077c`, `green-attempt01` |
| Entire original Host XCTest target | **135/135 PASS**, 0 failed/skipped/missing/unexpected, 0 warnings; 116.828 seconds including compilation | `job_6d2d688d983e`, `host-regression-attempt01` |
| Complete three production files parsed for `arm64-apple-ios27.0` | 3/3 syntax parses exited 0; **six environment warnings** about Windows SDK settings/sysroot | `apple-target-syntax` |

The 135 executed Host tests include all **127 pre-existing tests** plus eight
new `NativeIntentService` tests. The original 16 Intent-service test method bodies
are unchanged; all 24 execute. The new cases cover independent reader metadata,
exact selected identity, exclusion of components/Inspector, legacy initializer
behavior, request/catalog bounds, duplicate identities, source failure without
fallback, cancellation before resolution and cancellation winning over an
already-started non-cooperating host result.

Every Core/UIRouting/Host package input is hashed before and after each executed
suite. The reports confirm unchanged inputs. This uses Swift 6.3.3 on Windows,
one compiler job, complete strict concurrency, and the existing XCTest runner
with `--disable-swift-testing` for this XCTest-only target. No additional SDK,
index or corpus was copied. One shared 450,340,024-byte compilation cache served
the original-method fixture and Host regression.

The transition fixture retains the exact baseline failing assertions. With the
correction, synchronous metadata never invokes the injected async live-discovery
boundary. It then explicitly invokes the original foreground transition and
resolves the same identity again in the background. This is not a claim that a
synchronous MainActor enumeration yields to that injected callback.

## Reproduction

```powershell
python tools/hq-native-intent-metadata.py `
  --artifacts-dir build/intent-background-20261120/new-green-attempt `
  --source-ref 39ba01a0e014e41272ea53aa28ca8a24656f21e1 `
  --timeout 600

swift test --package-path Source/ChavrusaText/UIRoutingHost `
  --scratch-path build/intent-metadata-swift --disable-swift-testing `
  -j 1 -Xswiftc -strict-concurrency=complete
```

Run from this candidate checkout: the fixture extracts its app methods from the
specified immutable Git source and compiles the current local package inputs,
whose full hashes are recorded. The recorded successful runs used candidate39ba
for both. Raw generated Swift inputs, reports and logs are retained losslessly in
gzip form; digest manifests identify both original and compressed bytes.

## Review and unresolved gates

Root independently reviewed the three production files at 39ba and found no
source blocker. That review specifically checked pre-filter bounds, compatible
initializer defaults, metadata-only resolution, unchanged foreground/Core/receipt
guards and redacted diagnostics. It was a **source-only review**, not a separate
execution or Apple validation.

The Windows Apple-target parse reports syntax only; the warnings explicitly
confirm it used the Windows sysroot. **Apple SDK typechecking, app linking and
the original iPad/phone system-intent Native cases have not run on this candidate.**
No Native test was changed, relaxed, skipped or declared successful by this work.
Root will pin the integrated source and run those gates.

The historical Native78 iPad `Code=1` remains unattributed to a particular internal
code. The deterministic `native_scene_busy` and revocation failures are source
defects demonstrated by the RED fixture. The added fixed-code diagnostics will
identify the boundary if a future actual system-intent invocation fails.
