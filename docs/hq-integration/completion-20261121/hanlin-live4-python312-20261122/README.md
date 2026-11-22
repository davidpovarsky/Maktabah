# Original Hanlin live Python compatibility repair

Original Live4 run [44968087855](https://github.com/davidpovarsky/Maktabah/actions/runs/44968087855), checkout f955a3677f70ae61a8f3f40b7c3caa73fb9a541e, stopped in the dependency preflight before the full app build or Native/provider execution. Actual pip reported no matching binary distribution for zstandard0.25.0. The prior interpreter version was not printed, so no exact prior Python-version cause is asserted.

The actual runner image was xcode-27-arm64 on macOS27.0.1. The official PyPI0.25.0 release provides a CPython3.12 Darwin-arm64 wheel, and the official actions/python-versions manifest provides stable Darwin-arm64 CPython3.12 installations. Exact reviewed wheel metadata and source links are retained.

This workflow-only correction explicitly selects CPython3.12/arm64 immediately before the already-owned venv, prints its nonsecret interpreter/pip identity, and asserts the selected platform. The original pinned zstandard version, binary-only install, original SQL decoder smoke, app/test source, Hanlin source, cache keys and build/native/cleanup routes are unchanged. The source checks did not rerun an already-passed decoder smoke and do not claim the Apple install or any Native/provider execution. Actual macOS dependency installation and the original decoder smoke must pass before the costly app build.

The sole Live4 observer recorded terminal failure and removed only the exact temporary secret it owned: metadata matched00:42:58Z, DELETE204 then GET404, at00:47:56Z. The canonical437-byte cleanup receipt is retained byte-for-byte. No secret value is included. The original workflow's private-input/evidence cleanup also passed.

No task is closed and no new Native acceptance is claimed by this repair.
