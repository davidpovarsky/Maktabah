# Canonical Hanlin SDK upgrade to 32da9e31

The real Maktabah consumer now locks **32da9e314e22bbf22391fcf8902302acfbb281e2** in both HanlinSDK.lock.json and its original Vendor/HanlinSDK Gitlink. Code commit **a76983af7d46f9496f79adcf6ec90857c6a36e7e** changes only those two inputs. The eight selected products, original application/test source, Xcode project and external native engines remain unchanged.

## Actual installation and source verification

The existing host bootstrap loaded the canonical installer from the new immutable SDK revision. Installation passed in7.905s and strict verify-only passed in5.399s. The original host verifier checked **580 materialized original blobs** plus generated profile identity. An independent complete selected-file comparison matched all **545** selected file contents, modes and membership to32da. Package.swift is byte-identical to the previous profile; no binary/native target was prepared or downloaded.

The selected SDK changes from d49 are the original provider-query duplicate-key crash fix, the keyed ScriptUI reorder/diagnostic fix and the original shared HanlinComposerDraft addition. The draft is not referenced by this unchanged host adapter. Resource contents and public product/dependency selection remain unchanged. Exact Git objects and content hashes are in [receipt.json](receipt.json); the complete original verifier output is [original-source-proof.json](original-source-proof.json).

## Exact existing source policy retained

The focused input manifest now names code commit a76983af, its actual Vendor tree and the new Gitlink. Only those three fields changed. The two original focused/live drivers now name that same reviewed code commit; replacing those one-line constants with their old values recovers every other byte of each script. All four tree comparisons, expected checkout identity, selectors, credential admission, cleanup, binary/resource/fixture and integrity guards remain intact.

The original read-only stage2 preflight passed against the updated binding: [source-policy-preflight.json](source-policy-preflight.json). It retained UNCHANGED_PRODUCTION_PREBUILT for Zayit and the original engine/resource/dependency pins. No native preparation, test, live request or CI dispatch was performed for this upgrade.

## Acceptance remains attributed to its actual source

The existing [native run45125110974](https://github.com/davidpovarsky/Maktabah/actions/runs/45125110974) remains **48 component cases and one original no-send iPad UI case passed** at a65cdf9a / application source aa944bd2 / SDKd49. Its six reviewed frames and original receipts are preserved. This source-only update does not claim that those tests or a new device binary were executed at32da.

The shared [final source qualification](https://github.com/davidpovarsky/hanlin-ai/blob/b6a278531b5bfbc7246b4f5fec7d676750c645a5/Docs/SDK/HanlinConsumerUpgradeQualification20261123.md) binds the selected deltas and retained focused provider/reconciler evidence. Common Apple compilation, live-provider, full116/114, physical-device and signed-distribution outcomes remain separately attributed. The commit uses skip-ci to avoid replaying the already accepted host scope for this verified source/profile update.
