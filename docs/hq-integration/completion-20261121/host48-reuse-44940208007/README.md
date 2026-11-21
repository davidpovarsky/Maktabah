# Reuse of the actual Host48 component result

The original component execution passed 48/48, with zero warnings or failures,
in run44940208007. The full workflow failed in unrelated native UI cases; no
whole-run pass or native/live-provider result is inferred.

https://github.com/davidpovarsky/Maktabah/actions/runs/44940208007

The evidence ZIP preserves the original result, 64-input manifest, full compiler
and XCTest log, and generated Package.swift bytes. PROVENANCE.json binds this
subset to the already downloaded, SHA-256 and CRC verified original artifact.

Scripts/CI/reuse-host48.py requires the exact evidence ZIP digest and all48
original pass records. It verifies the unchanged original builder, the same
immutable Hanlin SDK gitlink (29 inputs), and the exact35 local component inputs
in both the committed tree and the working files. Added, missing, or changed
inputs reject reuse. The original full app build independently audits the actual
SDK checkout. Apple CI working bytes must match exactly; Windows preflight
explicitly records only reversible checkout CRLF normalization.

This guard performs no Swift tests and reports new_tests_executed=0. It does not
credit Native116, Release114, an original AgentSession, a model provider, or
physical devices. A changed component input stops the workflow for review; it
does not silently replace or broaden the original component execution.

The UI fixes under review affect Reader layout, native tab policy, and the
Settings orientation harness. These files are outside this frozen component
closure, so repeating its already passing48 tests is unnecessary.
