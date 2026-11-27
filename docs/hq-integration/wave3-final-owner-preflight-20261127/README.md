# Final owner and provenance admission preflight

## Result and scope

This is a read-only source and policy review of application commit **ec5385e863a478e368c7de47264474a440fd0734**. It is not a signing operation, a final approval gate result, an SDK build, native acceptance or release qualification. The coordinator subsequently confirmed that e27ab8e4 was documentation-only; later product 7fbe and pending test additions are outside this inventory and require a fresh final inventory.

The existing 55 approved records and five informational records remain unchanged. Against the unchanged release gate's full baseline, this candidate has **60 protected modified paths**: 34 records still match the exact current blob and canonical patch digest; 21 need authentic renewal; five need new protected-path records. The comparison does not reverify cryptographic signatures. The prior actual eb532 gate failure remains preserved at its original scope of 60 paths, 38 valid, 17 stale and five unapproved. These are different source observations, not contradictory test results.

`FINAL_SOURCE_INVENTORY.json` contains all 60 paths, stable existing IDs, current and signed blobs/digests, expiry, upstream membership and the 231 source/test/tool paths changed since retained integration 29a731e2. `SOURCE_INPUTS.json` pins the actual policy, original generators/verifiers, workflows and evidence read. No foreign dirty checkout was verified or changed; immutable Git objects were read through the agent's own clean Oracle worktree.

## Authorization and unchanged trust boundaries

AGENTS.md and PROJECT_AGENT_GUIDANCE.md, both with standing owner authorization dated 2026-11-19, already authorize necessary development, builds, integration, signing and release work. The updated upstream policy also states that the task covers necessary upstream hooks without another per-file permission request. Historical role/permission pauses do not create a new user confirmation requirement. They do not replace source-bound authentic signature verification or runtime acceptance.

The unchanged release wrapper is `Scripts/CI/verify-owner-release-approval.py`, SHA-256 `ab0da734ad6328da65da410e4d09d4e2911e423c82d7808df452fe8dae90aaaa`. It requires:

- Repository `davidpovarsky/Maktabah`, exact full candidate SHA, and matching event SHA when supplied.
- Baseline **157729471b649a023a81f923be33fb7bfa6e41c9**, with the exact original policy transition from 031df357. The two protected policy blobs are checked, not regenerated.
- Gate upstream **a0ed0df908a6cb38bc459d4baaeb400f447b2fc4** and the verifier loaded from immutable commit **978db8b37256d4dd2d58e91a0ea8d531798221c0**, SHA-256 **9733798a242382f59da99cb999a169e2c69c59010b336742e9a8fa151e837676**.
- The independently configured `MAKTABAH_OWNER_VERIFICATION_KEY`; the candidate registry cannot choose its trust anchor.
- Exact coverage of the entire protected baseline-to-candidate delta, authentic Ed25519 signatures, matching repository and future expiration, zero violations and a real PASS/exit0.
- Unchanged actual Source, Vendor, Xcode project and UI-test worktree/tree identities before and after verification. Failure evidence is retained.

The current maintained upstream source inspected earlier by the coordinator is **4203de5fd77beb119e5826e039be1a61325f7be0**. It was used here as an immutable lineage reference. It is distinct from the release gate's fixed upstream and is not silently substituted into that gate. This preflight did not repeat the remote query.

## Exact signature renewal scope at ec5385

Existing path-to-ID mappings must remain stable. The 21 renewals are:

| Existing ID | Protected path |
| --- | --- |
| OWNER_PATCH_003 | Maktabah.xcodeproj/project.pbxproj |
| OWNER_PATCH_006 | Source/Core/Database/SQLiteDatabase.swift |
| OWNER_PATCH_008 | Source/Features/Annotations/iOS/AnnotationListView.swift |
| OWNER_PATCH_015 | Source/Features/Library/iOS/iOSLibraryView.swift |
| OWNER_PATCH_017 | Source/Features/Reader/ViewModel/BookTOCViewModel.swift |
| OWNER_PATCH_023 | Source/Features/Reader/iOS/Toolbar/TOCNodeRow.swift |
| OWNER_PATCH_026 | Source/Features/Reader/iOS/Toolbar/iOSReaderBottomToolbarView.swift |
| OWNER_PATCH_028 | Source/Features/Reader/iOS/Toolbar/iOSTOCView.swift |
| OWNER_PATCH_055 | Source/Features/Reader/iOS/iOSReaderTabView.swift |
| OWNER_PATCH_031 | Source/Features/Reader/iOS/iOSReaderWorkspaceView.swift |
| OWNER_PATCH_033 | Source/Features/Search/ViewModel/Extensions/Search+Execution.swift |
| OWNER_PATCH_034 | Source/Features/Search/ViewModel/SearchViewModel.swift |
| OWNER_PATCH_036 | Source/Features/Search/iOS/SearchModeView.swift |
| OWNER_PATCH_037 | Source/Features/Search/iOS/SearchResultsListView.swift |
| OWNER_PATCH_038 | Source/Features/Search/iOS/iOSSearchFilterViewController.swift |
| OWNER_PATCH_039 | Source/Features/Setting/SettingsView.swift |
| OWNER_PATCH_040 | Source/Localizable.xcstrings |
| OWNER_PATCH_043 | Source/UI/iOS/Managers/iOSNavigationManager.swift |
| OWNER_PATCH_047 | Source/UI/iOS/Views/iOSMainView.swift |
| OWNER_PATCH_048 | Source/UI/iOS/Views/iPadLayout.swift |
| OWNER_PATCH_049 | Source/UI/iOS/Views/iPhoneLayout.swift |

The five newly unapproved paths are:

1. `Source/Features/History/ViewModel/Extensions/History+Database.swift`
2. `Source/Features/History/ViewModel/HistoryViewModel.swift`
3. `Source/Features/History/iOS/HistoryComponents.swift`
4. `Source/Features/History/iOS/iOSHistoryView.swift`
5. `Source/Features/Reader/iOS/ViewOptionsView.swift`

All 60 paths exist in the configured baseline and have modification status. No protected addition/deletion is being hidden. The original generator can render their full-index patches. Its sequential sorted output IDs are not automatically the established 55 IDs: the final unsigned review manifest must deliberately preserve the existing path-to-ID mappings and allocate unique new IDs for new paths. Preserve the 34 unchanged records exactly, retain superseded records in immutable history/evidence, and retain all five informational records. Do not keep two conflicting active records for one path.

## Existing Windows identity and missing runner locator

The live metadata read on DAVID's enrolled Windows host confirmed:

| Item | Observed location or identity |
| --- | --- |
| Account | DAVID |
| Python | `C:\Users\DAVID\AppData\Local\Programs\Python\Python312\python.exe` |
| Existing DPAPI envelope | `C:\Users\DAVID\AppData\Local\Maktabah\OwnerVerification\owner-signing.dpapi`, 314 bytes, existence/size only |
| Existing public-key file | Same directory, `owner-signing.public.hex`, 66 bytes |
| Decoded public-key fingerprint | `b0f0fa39ad1b59595699cd7eaef340a17567c9ff8dbe1408c2372c2a5866818b` |

No private-key bytes were read, decrypted, copied, logged or exported. No new identity was created. The public fingerprint matches the established external identity. The canonical repository signer is `tools/sign_owner_approvals.py`, SHA-256 `07e94cbb190d28d1a0f086f77d47bd8d921cea69bc87a130bd36829cfc0d0006`; its CLI accepts a secure plaintext key file, not a DPAPI envelope. Passing the envelope as a private-key file or exporting the plaintext to satisfy that CLI is not the established DPAPI workflow.

**The exact historical six-path `sign-reviewed-delta.py` runner/repository path is not yet located.** Bounded filename lookups found no match in the retained artifact area or the three specified historical Maktabah repositories. Sentinel context searches for the exact original Codex conversation returned no match; two older Maktabah context exports predate the six-path signing and do not provide the runner. The next filename-only lookup of known Code/worktree/session roots did not execute because Windows returned `agent_offline`, hub request `hreq_faa2662abf614e86`. Module availability checks in that same request also did not execute. The subsequently authorized original Oracle-to-Windows `david-win` alias was confirmed to use DAVID, BatchMode, IdentitiesOnly and strict host-key verification; one identity-only SSH attempt then timed out connecting to port 22 (exit255), before executing a remote command. Neither transport was reconfigured. Do not infer the runner is absent everywhere or claim its invocation has been verified.

The original six-path action is evidenced by signed commit **322d582b9f2e005b1efa493a190d9c82c2cb1209**, which changes only the registry, and Asana story **1220938102945251** recording six new signatures plus 49 retained records and the actual Oracle 55/55 receipt `309e25bf9a4adb350abdad9970fd101946cd7d02eb4c38c339c2f838cd894986`. Recover the runner and its immutable review inputs from that original execution before choosing the final invocation. The old unsigned two-path e769 packet is intentionally not a substitute. No new signing bridge was created by this preflight.

Before any eventual signing, verify the actual runner bytes and fixed scope, DAVID's original DPAPI user context, installed Python/cryptography/DPAPI modules, independent external public pin, clean isolated exact-source checkout, exact reviewed manifest digest and stable IDs, preservation of retained records, exclusive output creation and atomic post-sign WORKTREE verification. A six-path runner cannot be assumed to accept the final 26-or-more-path delta. That executable boundary remains unresolved, not silently widened.

## Legitimate PR admission and final freeze order

The original PR guard reads its register from the **trusted actual base**, while release verification reads the candidate's authentic full-baseline records. These are separate scopes. The existing PR guard accepts an attestation baseline which is the register's approved ancestor, but still compares the canonical patch to the actual merge-base-to-head diff. A full-157729 signature does not automatically match a narrower target-base patch.

Use this order only after the final product is ready and the actual target branch and its trusted guard have been read:

1. Pin actual target **T0**. Integrate T0 into the isolated candidate through normal conflict/source review, preserving independent work, and require T0 is the actual merge-base. Freeze resulting product **S**. If target moves, repeat the source/diff review; do not pick an older base merely to obtain a pass.
2. Prepare and genuinely sign the **T0-to-S PR-range** review using the established identity. This may differ from the full release review in count and digest. Preserve historical approvals and exact archive bytes. The trusted register's baseline must identify the genuine reviewed ancestor accepted by the unchanged guard.
3. Admit only those authentic PR-range records and their evidence in an **approval-only target commit T1**. Verify every protected product/test tree remains equal to T0. Its own boundary run is a real nonempty metadata change, not base=head and not protected source combined with self-asserted approval.
4. Bring T1 ancestry into the isolated candidate without changing the frozen product/test bytes. Require the actual merge-base is T1 and each full-index **T1-to-candidate** patch equals the authenticated T0-to-S patch. The guard must load T1's trusted records. Retain any referenced authenticated archive files in the candidate. Candidate-only registry changes cannot supply PR authority.
5. Separately prepare the candidate's **full 157729-to-S release registry** with all required authentic records. Preserve stable IDs and unrelated/informational entries. The candidate can retain the release scope while the PR guard reads the separately admitted target scope. Resolve registry/archive metadata explicitly; do not alter either verifier, bypass branch protections or use an unsafe override.
6. Commit final source admission, SDK route inputs, signed release registry, PBX/catalog, all native selectors and fixes **before the qualifying complete UI run**. Verify the final exact candidate through both applicable original routes. Record the actual target/merge/CI SHAs and retained rollback refs.

This is an ordering proposal grounded in the current original guard, not a claim that the actual target is already ready or that such commits were executed. A different trusted target guard, unresolved target changes or missing authentic signatures must be resolved as real prerequisites.

The unchanged `verify-runtime27-release-gate.py` allows an earlier tested SHA only for a descendant changing exclusively `docs/hq-integration/`, with its input-equivalence proof. A later signed registry under `docs/architecture/`, source admission, test, SDK or catalog change is outside that exception. Signing after native acceptance and relabeling the earlier run would fail the existing route.

## Source admission and new UI/Core obligations

At ec5385, both committed build admission files still name **64c1e74a5888f807e127e43611c3aab8fa702755**, 80 accepted components and 141 product delta objects. Their manifest SHA is `4dc9fbeb212b248cfc3b464d688b1b5e08ee6d647012571bd5c696c406ddfa15`; `native_qualified` is correctly false. The current candidate's four trees differ. Reuse of this source receipt cannot admit ec5385 or later product code.

The original source verifier also requires the historical Vendor delta to equal only `Vendor/HanlinSDK`. The actual ec5385 delta is seven paths:

- `Vendor/HanlinSDK`
- `Vendor/SefariaMobile/Integration/JS/ChavrusaRoot.js`
- `Vendor/SefariaMobile/Integration/JS/ChavrusaVisibleSurface.js`
- `Vendor/SefariaMobile/Integration/JS/ChavrusaVisibleSurfaceRegistry.js`
- `Vendor/SefariaMobile/Integration/JS/chavrusaRPCFacade.js`
- `Vendor/SefariaMobile/Integration/iOS/ChavrusaSefariaBridgeModule.swift`
- `Vendor/ZayitSearchPort/Swift/ZayitSearchViewModel.swift`

Therefore regenerating only the existing manifest is insufficient. The six accepted downstream Vendor integration hooks need an explicit exact reviewed source-admission contract preserving the imported engine boundaries. This preflight does not change the predicate or authorize a permissive allow-all. Preserve the original historical evidence, engine/build inputs and source verification invariants; source identity still does not confer SDK or runtime acceptance.

New downstream Actions Core, UI routing, Host services and original-UI adapters require lineage and behavior review even when the protected-path predicate excludes their namespaces. The final packet must bind the actual source and tests for:

- One-use Core preparation/continuation, old-versus-staged mutual exclusion, terminal source and parent revalidation, immutable request/deadline and no authority renewal.
- Original scene/window/tab/book/Reader identity, pre-await capture, synchronous ABA invalidation, correct detach/replacement handling, and actual geometry/focus acknowledgement.
- Finite Settings/TOC/Library, typed History/Favorite/Reader/Profile/Group and Search continuation routes; original owner/state preservation and exact private-record identity. Generic root visibility alone is not completion of a typed request.
- Exact new file target membership, original native test preservation, unchanged real production query/data oracles, original failure/refusal controls and late-effect checks. Parsing and domain-boundary component controls remain separate from original app SDK/native results.
- Original UI-03–07 and 294-component acceptance mapping, iOS/iPadOS 27, platform/backend, accessibility and real VoiceOver, languages/RTL, keyboard/window/resize, system delivery and physical-device obligations.

These are the already assigned product and source contracts, not extra cryptographic approval categories. The 231-path inventory distinguishes protected paths, candidate downstream/test/tool paths, and Vendor paths needing their own provenance; it is not a blanket provenance PASS for each path.

## Provenance, licenses and release evidence

The original upstream audit task **1220769157395027** and Batch B task **1219848733895424** remain open. They require exact source provenance, dependency/engine boundaries, real candidate acceptance and truthful physical QA. The original policy calls for an ownership matrix with origin SHA, exact downstream hook, alternative, task and regression evidence, and requires unresolved UNKNOWN lineage to be traced. A new directory alone does not establish downstream ownership. A true upstream sync additionally requires its own two-parent merge and semantic conflict ledger; none was performed here.

No production Package/SwiftPM/Cargo/npm manifest, lock or license/NOTICE changed between 29a and ec5385 in the checked inventory; the one matching LICENSE path is preserved producer evidence under docs. This observation does not qualify newly built SDKs. The current NOTICE still identifies Anytype **75a98ba98d6455eefc2c98113fa744b0f3c2e7bf**, Hanlin **9565a9e4775901a4cee6f0402d7fd2978fab6612** and Sefaria **2fd173a5a3bd32d94a9ba1222e4e32a37f6bd23c**. Root's planned original Anytype SDK source is d6090c03; that new artifact has not been qualified by this preflight.

The historical bundled license check covered eight files in product 6e80dafb and receipt `feb0b9dbc6dfba9db6469d9a08b2ccad6bcb8b1131ea679efabc1a86bfe3a47e`. Keep that pass at its original scope. Before final Archive/IPA acceptance, bind the real SDK source and dependencies, appropriate NOTICE/source references, all eight resource bytes and their presence in the actual final bundle. The included Any Source Available License 1.0 preserves its noncommercial/allowed-network conditions and redistribution notice requirement; its text is not converted into an unrestricted license. This is an evidence requirement from the existing audit, not a new legal conclusion or inferred incompatibility.

Native116, complete Release114+2, production v40/indexes and exact Anytype/Hanlin/MiniApps acceptance remain their real gates. No component run, source proof, previous 55/55, SDK partial output, Apple VALID result or old build 11201 substitutes for them. Physical iPad/iPhone checks remain NOT_RUN until actually performed by the owner on the delivered beta.

## Final-freeze checklist and exact existing commands

Only run these after final source selection, reviewed target admission and a clean owned checkout. Placeholders intentionally denote unresolved final values; they are not claimed executable invocations of the missing DPAPI wrapper.

1. Pin actual final source/target/SDK SHAs, clean checkout, four product trees, dependency locks and complete provenance matrix. Recalculate the protected scope; ec5385's 34/21/5 counts are not frozen for later code.
2. Generate an unsigned complete review into a new directory using the original tool, then retain stable IDs and all exact canonical patch bytes for independent review:

   ```sh
   python3 tools/generate_owner_patch_manifest.py \
     --repo <clean-owned-checkout> \
     --base 157729471b649a023a81f923be33fb7bfa6e41c9 \
     --head <final-product-sha> \
     --upstream-ref a0ed0df908a6cb38bc459d4baaeb400f447b2fc4 \
     --out-dir <new-owner-review-directory>
   ```

3. Validate manifest count/unique IDs and paths, full immutable base/head blobs and exact LF full-index patch digests. Preserve matching records. Review new/renewed records and source/provenance/test evidence; recover and inspect the authentic existing DPAPI runner. If an archive is referenced, keep it under the original `docs/architecture` allowed root with a matching relative path; do not leave contradictory aliases.
4. Complete authentic PR and release attestations through the established owner identity under the separately reviewed exact scope. No private-key export, regenerated identity, self-authored signature, unsafe override or narrow historical bridge. Preserve all superseded signed records/evidence. Expiry is calculated per signing invocation, so an earlier preview payload's digest is not automatically the actual signed payload's digest.
5. Commit all final admission/SDK/approval/test inputs and verify the unchanged original release wrapper with the independent existing key configured outside the candidate:

   ```sh
   python3 -I Scripts/CI/verify-owner-release-approval.py \
     --repo <clean-owned-checkout> \
     --expected-sha <final-candidate-sha> \
     --repository davidpovarsky/Maktabah \
     --out-dir <new-owner-gate-evidence>
   ```

6. Obtain the genuine final complete Debug/native and Release/production results with actual SDK/source/dependency/binary/device/data oracles, no skipped required cases, and all original failures retained. Use the existing release UI verifier against that actual completed run and exact candidate. Later changes outside its narrow documentation exception require the existing affected/final acceptance process.
7. Recheck original signing map/profile and three App Groups on the final bundle, real device Archive, exported IPA, original SDK/resource/entitlement verification, validation/upload, Apple processing VALID and authorized installation availability. Record version/build/final SHA/link and prepare the owner's physical QA separately.

### Remaining concrete prerequisites

- Original Windows six-path runner locator/source/invocation and module prerequisites are unverified because the last Windows request was offline. No signing may be represented as ready from this preflight alone.
- Final source is still moving; current records leave 21 renewals plus five additions at ec5385, with later source outside this count.
- Actual target trusted-base admission is not executed. PR-range and release-range signatures are not interchangeable without exact patch equality.
- Build source admission is stale and the exact six additional Vendor integration paths are outside its current admitted predicate.
- New SDK qualification and final NOTICE/bundled-license binding, complete original native/Release/production gates and owner physical QA remain outstanding at their actual scopes.

No policy file, signer, verifier, approval registry, application source, tests or private identity was modified. There was no signing, final gate execution, native run or release action in this preflight. `READ_ONLY_INVENTORY_SCRIPT.py` is retained evidence of the immutable source comparison and is not a replacement gate or signing tool.
