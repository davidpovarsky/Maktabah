# Original Hanlin live Native continuation: Python dependency repair

## Verified terminal result

GitHub run **44959295674**, attempt 1, checked out **34d06949e7fedbda6e0d256a769b3d0b8659c211**. The application source remains **a0781bd2628c1311394f7da6aa1e84c17f252fa4**, and the original Hanlin SDK remains **e00498e33f106cc43be0476ffa2e09329c8ca300**.

- The original application and original UI test runner built successfully: `SIMULATOR_BUILD_FOR_REAL_UI_PASS`.
- The actual Simulator App Group resolver interface passed, the actual application was installed, and the original miniTest10 installation passed its integrity checks.
- The live Native case did **not** start. Its original staging path calls `Scripts/verify-otzaria-mini-parity.py::decoder`; that function failed because the runner's Python environment lacked `zstandard`.
- The Actions run has conclusion `cancelled`; its Native execution step has outcome `failure`. The actual evidence reports `PROVISIONING_NATIVE_FIXTURES` and `RuntimeError: install the Python zstandard package`. This continuation did not cancel the run and does not infer a separate external cancellation cause from the status label.
- Completed provider conversations: **0**. Private provider input was **not staged**. The original cleanup passed, removed the disposable Simulator, and restored prior evidence.

Artifact **14731246409** contains 14 admitted files. Its ZIP is 74,486 bytes with SHA256 `74c788910aa89e015601a1d2aaadce9fd6e8e80b7e6b7f148e077d07990d3d6d`. ZIP CRC and all 13 member entries in `admission.json` were independently verified. The source-before and source-after receipts are byte-identical, SHA256 `55d8cdc5626391ff266bd7c4ddf882c3489eb9e571c522786dbc331d4c36684f`.

## Focused correction

The workflow now creates its own disposable Python virtual environment, installs the pinned `zstandard==0.25.0` wheel, and executes the **original** decoder on a small compressed UTF-8 smoke sample before the expensive application build. This smoke check is an environment/dependency check, not a miniature substitute for the actual installed Native fixture.

Only the existing live case runs through that environment; other build tools keep their existing Python selection. The live step requires both successful dependency preparation and the existing matching build receipt. Original cleanup remains unconditional and uses the existing standard-library-only path. The dependency receipt joins the existing bounded, credential-scanned artifact admission list.

The app, original Host/SDK, original SQL decoder, canonical Core data path, test selector, consent checks, and Native assertions are unchanged. The runtime driver's AST is unchanged except for admitting the one new nonprivate dependency receipt.

## Verification and reuse boundary

The actual original decoder smoke passed locally on Python 3.12.14 with zstandard 0.25.0. YAML parsing, Python syntax, dependency-before-build ordering, and the narrowly compared runtime AST passed. The Apple virtual-environment installation and the live Native case still require execution on the corrected checkout. No provider, UIKit, simulator, 116-case Native matrix, 114-case Release gate, signing, or physical-device pass is claimed by these portable checks.

The exact existing compiler-cache key was restored in run 44959295674. The build still ran and passed; cache restoration is not an acceptance result. Existing unchanged Host48 evidence remains reusable only under its actual input identity guard. No previously passed Host tests were repeated for this workflow-only correction.

After the completed run, its temporary repository secret was deleted with HTTP 204 and absence verified with HTTP 404. The cleanup receipt is `Maktabah-completion-20261121/build/hanlin-live-secret-cleanup-44959295674.json`; no credential value is part of this report or these files. Any subsequent attempt must establish and clean up its own secret ownership separately.

## Sources

- Run: https://github.com/davidpovarsky/Maktabah/actions/runs/44959295674
- Immutable artifact: https://github.com/davidpovarsky/Maktabah/actions/runs/44959295674/artifacts/14731246409
- Original decoder: https://github.com/davidpovarsky/Maktabah/blob/34d06949e7fedbda6e0d256a769b3d0b8659c211/Scripts/verify-otzaria-mini-parity.py
- Dependency release: https://pypi.org/project/zstandard/0.25.0/
- Asana update: https://app.asana.com/0/0/1220542467495722/f (comment 1220765212357208)
