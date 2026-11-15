# Resource-bundle layout repair — Apple CI 43727696309

P worktree: `C:/Users/DAVID/Code/Maktabah-hq-actions-core-20261115`, branch `codex/otzaria-ui-registry-20261115`. Resource-only repair base: `bedd754dd0af058eddbb0c386a3a189a38e6269e` (the separate post-observation authorization addition).

## Actual failure and source evidence

Manager supplied the terminal build-for-testing log for coherent source `fe6f5fe5126a964bd76d3f308489e131a491fe36` (app source pin daeeae69), run43727696309. It fails when Xcode ad-hoc signs `OtzariaUIRouting_OtzariaUIRouting.bundle`: `bundle format unrecognized, invalid, or unsuitable`. The six selected native reader cases never ran: **0 fresh UI PASS / 0 UI FAIL / 6 NOT_RUN**. This is a resource CodeSign BUILD_FAILED, not evidence of an API compiler failure or reader regression. Metro's source bundle build is separately manager-attributed; installed app/hash/Hermes were not reached.

Raw evidence: `C:/Users/DAVID/Code/Codex-Agent-HQ/docs/otzaria/single-manager-wave-20261115/run-43727696309/artifacts/hq-stage2/simulator-build-for-testing.log`.

The actual Xcode commands show:

- UI resource Info.plist at the bundle root, then CpResource of the entire source `Resources` directory to `OtzariaUIRouting_OtzariaUIRouting.bundle/Resources` (approximately lines4473-4479).
- Core likewise materializes `OtzariaActionCore_OtzariaActionCore.bundle/Resources` alongside its root Info.plist (approximately lines4481-4487).
- The immediately following CodeSign of the UI resource bundle fails. Both Package.swift files declare `.copy("Resources")`.

The copied root directory is the package-owned layout defect addressed here. Its relationship to the exact Apple signing rejection is the focused diagnosis; final cause closure requires the new real Xcode build/sign result. The artifact set does not contain the complete generated Mac bundles, so no independent full native bundle-tree inspection or codesign PASS is claimed.

## Narrow repair

Change both production package resource rules to `.process("Resources")`. Update the existing Core `ActionRegistry.resource(_:)` lookup to `Bundle.module.url(forResource:withExtension:)`, without a literal Resources subdirectory or fallback. UI has no hand-written production Bundle.module lookup; only its generated resource accessor is used. Its test fixture rule `.copy("Contracts/Fixtures")` stays intact, with the existing Fixtures lookups unchanged.

Apple documents that process applies recursively to a source directory and puts files without platform-specific processing at the resource bundle's normal resource root; copy retains a directory's structure. Continue using Bundle.module instead of assuming the physical bundle path. Source: [Bundling resources with a Swift package](https://developer.apple.com/documentation/xcode/bundling-resources-with-a-swift-package). This supports the packaging/lookup choice; Windows does not prove Apple's codesign result.

The source directories are retained. All six frozen Core JSON payloads and the one UI catalog-status JSON remain byte-for-byte unchanged. There is no resource rename/deletion, new JSON/schema meaning, fixture mutation, descriptor-count change, SDK/deployment/toolchain change, signing bypass, entitlement/certificate change, project edit, workflow/trigger/release-gate edit or S/I/R source edit.

Extend the existing `WireSecurityTests.testFrozenCatalogAndElevenExamplesProject` assertions without changing its test-method count: the generated resource bundle must have no copied top-level Resources directory; all six original contracts must load through the normal Bundle.module resource root and public Core loader; existing29 catalog descriptors/5 implemented IDs/11 example projections remain asserted.

## Verification boundaries

Use a fresh ignored SwiftPM scratch directory under P's existing `.build`, preserving old caches and evidence. This matters because obsolete copied output can survive an incremental resource-rule change and mask the new materialized layout. The fresh portable resource inventory compares each generated JSON file against its source SHA256, the six frozen Core hashes, and the pre-repair Git bytes. UI's existing7 codec +2 golden tests retain their methods/fixtures and verify codec behavior after the dependency resource relocation.

Exact executed commands/results, generated portable bundle inventory and hashes are recorded in `results/resource-layout-summary.json`. Those are portable packaging/lookup/fixture results only. Actual Apple codesign, app build, six native reader cases, installed-bundle match, Hermes, UI03 and physical/fullDB acceptance remain separate manager verification. Do not bypass signing or rerun the unchanged source and call it a fix. The manager owns the focused corrected-source native validation.

Ownership: two downstream package manifests, Core's existing downstream registry loader, and its existing downstream WireSecurityTests only, plus evidence/docs. Revert this isolated repair commit if needed; never reset/clean preserved worktrees or caches. The resource patch is separate from parent bedd754d's post-observation authorization contract and can be applied independently to065148d3/coherent sources if the manager chooses that source composition.

## Executed source verification

Final strict Swift6.3.3 Windows focused runs in the fresh ignored scratch path: **1 existing Core WireSecurityTests method / 0 failures / 0 warnings**, then **9 existing UI codec/golden methods / 0 failures / 0 warnings**. The added Core assertions keep its method count unchanged. Defined method counts remain identical to pre-resource-fix bedd754d (see the exact counts in resource-layout-summary.json); not all were executed for this layout-only patch. The initial new assertion omitted a `try`, causing a preserved test-compile failure with zero tests; final corrected runs passed.

Fresh materialized production bundles contain all **7 JSON files at their normal resource root with no copied root Resources directory**. Every generated JSON byte matches its untouched working source; all6 Core working/built payload hashes match the original frozen working manifest. All7 resource Git blob IDs are unchanged from bedd754d. Working CRLF versus committed LF differences are explicitly recorded per file: raw Git bytes are not relabelled as identical to working/built bytes. All3 copied UI fixture JSON files are also byte-identical to their working sources. Exact inventory, source/Git/log hashes and the before-fix native build-log hash: `results/resource-layout-summary.json`. Raw focused logs: `resource-layout-core.log`, `resource-layout-ui.log`, and preserved `resource-layout-test-compile-failed.log`.

The fixed source still needs real Apple codesign/app/test validation. Use fresh native build output or inspect that old copied Resources output has not survived a cache restore; preserve earlier caches/evidence rather than weakening signing. There is no new Apple/native PASS from P. The6 native cases from43727696309 remain NOT_RUN in that historical failure.
