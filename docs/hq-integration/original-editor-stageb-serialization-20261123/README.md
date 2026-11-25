# Original Stage B exact Xcodeproj serialization repair

The authenticated run 45167025321 failed before application compilation. Its generated original CocoaPods project and rejected saved project show only two representation mismatches: OTHER_SWIFT_FLAGS and SWIFT_INCLUDE_PATHS are serialized by the actual Xcodeproj 1.28.1 as exact ordered space-joined strings. The original helper restored the complete project byte-for-byte. All other settings and 2,358 unrelated objects were unchanged.

## Minimal source change

Only Scripts/CI/hq-original-editor-app-target.rb changes. Its expected-settings snapshot normalizes only the two observed array-valued keys, refuses non-string tokens, and retains the complete token arrays in the receipt. Full saved-settings equality, project/target/configuration isolation, original embed phase, exact nineteen module-map pairs, original linker pairs and rollback remain intact. The full two-hunk inverse is retained.

## Actual new control

The authentic generated PBX project and unchanged app-target plan were used with the genuine pinned Xcodeproj 1.28.1 and its eight exact dependencies, downloaded from official RubyGems metadata and package digests. The actual original full helper reproduced its precise rejection and rollback. The actual candidate full helper saved successfully. A test-only fault changed CODE_SIGN_STYLE after the real save; the candidate rejected it and restored original bytes. Three leaves, 49 assertions and three bounded/reaped/drained Ruby commands passed. The two deliberately adverse helper commands exited nonzero as required. This is one serialization/rollback experiment, with no replay of the old flag or Ruby-context controls.

All 263 observed package-source files match the failed CI runtime. Five observed NKF Apple build outputs are explicitly distinct from package source and from the newly built Linux extension. The initial complete 268-file comparison honestly retains its false all-files result; the classified source binding records the actual scope. No Apple-runtime or binary-framework equivalence is claimed.

## Environment and evidence

A new copy of the already retained portable Ruby 3.2.3 tree was used with its exact Ubuntu development headers and an isolated GEM_HOME. The original runtime tree and system installation were untouched. An initial owned-directory permission refusal is retained; the directory was assigned to the actual ubuntu identity and the unchanged exact-version installation then succeeded. The official packages, metadata, command streams, source correspondence and actual extension binary are retained. Reproducible extracted runtime trees are represented by source-package/install receipts rather than duplicate trees.

The original failed artifact, all 224 CRC member hashes, restored/rejected PBX files, transport flag refusal, successful supported artifact download and closed observer receipts remain under failure-run-45167025321. Asana failure comment: 1220788303892173.

No app compiler, SDK framework embedding, simulator or UI journey executes in these controls. Stage B remains NOT_RUN for app/edit/reopen acceptance until a real Apple run succeeds. The SDK pins, application/UI/vendor trees, workflow and original admission functions are unchanged. The unchanged original source prepare passed once at 2abbea9f706bd77a1b7e80553141b5d1aac6b864, with all 285 execution inputs independently matched to both committed Git blobs and materialized working bytes. Seven code/product/workflow trees are bound for the evidence-only child. Publication/activation requires root review.
