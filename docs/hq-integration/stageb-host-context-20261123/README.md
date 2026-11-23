# Stage B host Clang composition

Run 45174533607 at Maktabah 00b30baa97fe14c0ba5be550e7a72cf64e768951 failed in the real SwiftDriver command because nine original SDK Clang module maps collide with host SwiftPM/CocoaPods maps. See FAILURE_ANALYSIS.json for exact original diagnostics, artifact hash and package versions.

The consumer now projects the four shared SwiftPM map/include roots onto the host paths after checking the entire admitted declaration subtree byte for byte and the already-verified shared package revision. The SDK export is unchanged. A concrete Clang regression reproduces the duplicate-map failure and passes when the identical canonical host map is used. Six additional focused checks cover header/map drift, source-revision mismatch, checkout escapes and CocoaPods collision reporting.

The five remaining CocoaPods module collisions are not silently suppressed. The actual original AnytypeOriginalEditor binary defines FBLPromise, FIRApp and FIRInstallations, while the host compiles separate versions. The new early report identifies this composition error before another full app build. A compatible single runtime dependency closure must be produced and admitted before the full Stage B journey can run.

Focused controls: 7 passed on Oracle/Linux. This is compiler-context behavior evidence, not Apple SDK or native UI acceptance. The app, bundle identity, original editor features, test assertions, SDK binary admission and release requirements remain unchanged.

Retained original artifact: https://github.com/davidpovarsky/Maktabah/actions/runs/45174533607
Producer source: https://github.com/davidpovarsky/anytype-swift/commit/de63125b97cd5b91a1fa4f4b71d03738076e735f

Next required implementation: externalize the original producer's overlapping runtime dependencies and make the real host consume those same products; rebuild/qualify the genuine original API consumer, then execute edit/save/process-exit/new-PID/reopen in Stage B. Merely updating version labels or dropping module-map arguments is insufficient.
