# Verified Apple SDK and component acceptance

Run [44660550095](https://github.com/davidpovarsky/Maktabah/actions/runs/44660550095) completed successfully at exact checkout 3a777e77bbe297b652f96e9f63803f25db2973e2. Application, Vendor, Xcode project and XCTest trees are identical to original application source 7e777509 and frozen Native/Release checkout fe4df7c.

The unmodified GitHub ZIP is retained here. Its exact size and GitHub-provided SHA256 were independently verified; VERIFIED.json lists every extracted file digest. Xcode27.2/Apple Swift6.4.2 compiled and generated code for the88 declared black-box XCTest cases with2668 warnings. Zero Native UI cases executed in this SDK run; app-composed sidebar/global-search checks still require the full app build.

Actual executed outcomes: original SQLite25/25; BookPageCache26/26; annotation ledger28/28 plus two separate real process-termination/recovery checks (child73, verifier0, WAL synchronous2); Hebrew source ranges15/15; inspector owner17/17; original Hanlin API1.2 host28/28, legacy dispatcher8/8 and scoped filesystem store11/11; workspace89 checks. These distinct test boundaries are not combined into a Native total. The Windows-only optional original-source database read oracle was absent in Apple CI, explaining SQLite25 versus Windows26.

The annotation tests used the original Apple SDK SQLite3 module, actual SQLite3.54.0, production CryptoKit SHA256, original SQLiteDatabase and SyncPendingStore. AnnotationRepository/CloudKit runtime, Anytype, transport and live exchange remain unexecuted/disabled. The previous failed run44657109179 is retained separately: its duplicate SQLite module prevented annotation execution and skipped workspace execution. The correction changed only the acceptance package setup, preserving production source and all28+2 original assertions.

Native88 run44657116407 and full Release run44657123753 remain independent pending gates. This component/SDK success does not approve merging a release or closing their Asana tasks.
