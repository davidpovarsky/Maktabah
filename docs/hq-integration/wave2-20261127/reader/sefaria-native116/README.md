# Sefaria Native116 diagnosis and reader-lane repair

## Scope and current acceptance boundary

Production parser repair: c1ea03786921d683a620e3800c2a9e22cd5bbfcd.
Original UI observation/loading identity repair: 49cfd5e8d5ecebf37acf812e047fee36cf60893a.
TOC generation/cancellation repair is independently documented under ../toc-load-lifecycle
(bbc68b0d8125a47f8c195653db77a7f771854837, 34/34 Apple source controls).

The parser was compiled and executed on the authorized Scaleway Mac using whole
original production Swift files and five retained original textToc payloads. The
application UI changes have a syntax-only Apple iOS Simulator parse. Native UI
execution of this candidate remains NOT_RUN and belongs to the combined-build owner.
No original Native116 failure has been relabeled PASS here.

## What the original Native116 actually showed

The retained native116-actual-baseline-diagnostic.json names application source
f2e3fecbd3e6f36d8a8b7edd7c95e6015acb48fb and control checkout
ec14460748dc79818b1a7a3f269a54e3a1ddfaa9. It records 82 passed and 34 failed
selectors across the original 116-case diagnostic; this is not release acceptance.
native116-original-observations.json retains the two original Apple summary
documents plus SHA-256, size, source path and exact selected AX lines from eight
original hierarchies. The complete original files remain at those paths.

| Failure | Original observation | Repair and remaining native check |
| --- | --- | --- |
| Pad English Talmud structure | Picker has Folios and Berakhot, but test requires Chapters. Original mobile alts/Chapters root inherits work title/titles. | Mobile parser now labels structures from the original dictionary keys and existing localized resolver. Native API title handling is unchanged. Rerun both languages. |
| Pad English complex parent | toc-row--16525 is leaf verse 2 inside autoexpanded chapter 1; it has no same-node disclosure. | The bounded original-row search now requires an actual matching disclosure before accepting a parent. Canonical destination assertion remains exact. |
| Pad Hebrew complex action | Actual localized text wraps פרק ב׳ in Apple's FSI/PDI. | Accept only exact localized action/title, optionally surrounded by that exact FSI/PDI pair. Product direction controls remain unchanged; RTL disclosure geometry assertion remains. |
| Pad Hebrew Talmud query | Immediate field snapshot was ב; final original palette AX has complete ברכות and the exact Berakhot result. | Wait up to 15 seconds for exact typed value, then retain exact equality. No additional typing, alternate match or query substitution. |
| Pad Remote loading, both languages | Original localized loading Text exists at visible coordinates, but the containing VStack's toc-loading identifier is absent. | Put the identifier on the actual loading Text and compare its exact localized label. Transport armed/tagged/held/failure ownership assertions remain. |
| Phone TOC lists | Actual collection and rows are in the original window. Calling the collection's activation point fails before any row action. | Validate finite on-screen list geometry and require an on-screen hittable original TOC row. Do not ask a non-action collection for a button activation point. |
| Phone Talmud open | Compact Reader has an original Library BackButton and no iPad command-palette toolbar item. | Use original BackButton, unique original Library search, exact settled query and unique visible exact-title catalog row. Backend/work/canonical Reader assertions remain. |

The TOC loading lifecycle race discovered separately is not claimed to be the
cause of Native116's absent accessibility container: its original loading text
was already rendered. Those are separately reproduced and verified changes.

## Identical before/after Apple source comparison

Tool: tools/hq-sefaria-mobile-labels.py. Inputs and actual commands are retained
per attempt. Both attempts use the same full test, boundary and fixture bytes,
MOBILE_LANGUAGE_CASES, strict Swift 6 concurrency, and the same 84-case inventory.
The production source is read from the named immutable Git commit.

| Attempt | Source | Compile | Run | Cases |
| --- | --- | --- | --- | --- |
| Before | 59d3bf9e18ca14f4fdb63f552e81c53f86f6919a | 0 | 1 | 78 passed, 6 failed |
| After | c1ea03786921d683a620e3800c2a9e22cd5bbfcd | 0 | 0 | 84 passed, 0 failed |

The six reproduced failures are the Hebrew/English alternate structure labels
for Berakhot, Genesis and Rashi on Genesis. The 76 existing cases and two added
native-API title preservation controls pass on both sources. The original
canonical refs, sparse node positions, errors, cancellation and source work
identities continue to be checked. No fake corpus or substituted mobile payload
was introduced.

Before parser SHA-256: 3a33b37270a8cc19826a403db93f7d800a99a453626b2c0c31ec8e0c9f7a0a5e.
After parser SHA-256: c867b7384455f87e5bddec526f0f1c5bc9af4f7ec73707260df6de6c311e8a5f.
Before binary SHA-256: ac3be6163199004eedb0a5986e0261dc6715c5788aebc5302861b01b704034dc.
After binary SHA-256: a665a5ac1432672ef736c7acb0f859fe11503c1f66ba6aa380b45c2dd085ac7e.
All source/fixture input hashes stayed unchanged during execution.

Apple Swift 6.4 (swiftlang-6.4.0.34.1), Xcode 27.0 build 27A266a.
Actual execution UTC: baseline 2026-11-26 22:51:49–22:52:07;
candidate 22:52:07–22:52:25.
Mac artifacts: /Users/m1/builds/otzaria-wave2-reader-controls-20261127/sefaria-labels.

Only Hermes/UIKit startup and JavaScript transport use the existing explicit
fixture boundary. The original complete adapter/RPC/parser/model code executes.
These are source component controls, not Embedded Hermes or app UI acceptance.

## Syntax check and next native execution

syntax-only/RESULT.json records exit 0 for the exact two source files from
49cfd5e8d5ecebf37acf812e047fee36cf60893a. The command uses Apple's Swift frontend,
DEBUG, arm64-apple-ios17.0-simulator and iPhoneSimulator27.0.sdk. This checks
syntax only; it does not typecheck, build, launch or exercise XCTest.

The combined build owner must run both original classes:

- Maktabah-iOSUITests/SefariaTOCLocalizationPadAcceptanceTests
- Maktabah-iOSUITests/SefariaTOCLocalizationPhoneAcceptanceTests

Each class contains Hebrew/English Talmud, chapter/complex, and remote held
loading/failure/original Retry cases. Preserve all 12 exact selectors and inspect
actual screenshots/AX, exact canonical refs and native transport receipts.
The full-v32 cases and full-v40 performance/corpus scope remain separate.
