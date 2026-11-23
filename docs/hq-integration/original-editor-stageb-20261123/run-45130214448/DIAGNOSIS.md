# Stage B 45130214448: authenticated universal-framework false rejection

Source a0b0e12cee7260829f4cafe41fc9c4c0dfad6c44, attempt 1, job 137543753781. The job actually ran 2026-11-23 07:39:10–07:48:15 UTC and failed during app-build preparation. Its sole observer closed at 07:48:18 UTC with exit 1, no timeout, reaped child and drained owned process group.

## Exact failure

`Scripts/CI/hq-original-editor-distribution.py:367` compares the complete `lipo -archs` output to the literal `arm64`. The first actual original product, AmplitudeCore, returns `x86_64 arm64`. Its real lipo, otool and strict codesign commands all return 0 with empty stderr. Both CPU headers are DYLIB. The authenticated original de631 producer header0 already records precisely these two CPU slices; this is not newly introduced or unqualified framework content.

The full original distribution was restored and verified: 2528 files; no framework or consumer rebuild, no repaired/overwritten files. The actual original EN/HE signed consumer qualification remains separately accepted at run45123300449/e9504bc.

## Phase boundaries

The unchanged toolchain selector now passed, and the separate UI source compilation passed. The build preparation had also completed dependency setup and resolution. It stopped in `admit` before later framework checks, exported API typechecking, generated app-target integration, or xcodebuild build-for-testing. The mounted editor journey was skipped. The always-run collector subsequently reported `No matching original SDK/app/runner build`; this is secondary to the exact architecture predicate failure. No edit/save/reopen/new-PID/UI or device success is credited.

## Authentication

Artifact14799460254 is615683 bytes, SHA2563662b88875a2062005edcad376463761c1f4a6b300a096ab0329dc4d211affcd. The authenticated API, successful upload step and exact upload log agree on ID, size and digest. All55 unique safe ZIP files passed CRC. This artifact has no upstream per-member hash index; ZIP_ADMISSION records locally verified file digests without inventing one. The unaltered ZIP retains every member. Full raw job log is3015790 bytes, SHAd3dbbf0eae9889a0285ff3d7a07a1cdfb4e2e39e2b834a2e09a0265ed3eb01d3.

## Remaining source review

The complete current admission, prepare, unchanged-distribution, embed and built-app verification functions were read. Only this literal single-slice assumption was identified. Full distribution identity, strict signature, Simulator platform, original exported API compilation, package/Hanlin source equality, isolated target integration, and exact before/after app inventories remain required. A future source repair does not grant any not-yet-executed boundary. No retry or source test replay occurred during this intake.
