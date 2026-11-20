# Original Release workflow build-stage evidence

Run44723918854, attempt1, checkout60a57972acb28739ec738565083bf17fb7503028, application87b783ac3f0257e8461762e0ea9dfa5248dd06e8:
https://github.com/davidpovarsky/Maktabah/actions/runs/44723918854

The original build job136246453842 completed successfully. Its recorded results are RELEASE_BUILD_ONLY_PASS and SIMULATOR_BUILD_FOR_REAL_UI_PASS. The actual app build-for-testing and SafariPrototypeReference build used Debug simulator products, Xcode27.2 build27B52, Swift6.4.2 and iOS Simulator SDK27.2. This does not establish Production Release or UI acceptance.

Root independently verified the complete downloaded artifact14626257677:1,618,660bytes, SHA25642978dc266c442eae2023c01b6ff944d752f052a5cf60b76588b441d9c16447a, all82 archive entries and CRCs, and exact extracted bytes. The archive is preserved losslessly in raw/artifact.zip.gz.

Source review checked995 exact Git blob inputs. The remaining input is the original CocoaPods-generated privacy aggregation, independently audited using the original and generated complete plists plus five complete actual dependency privacy manifests. All existing non-API declarations and API reasons remain; exactly six dependency-supported reasons were added. The generated Git blob matches the recorded actual input. The initial all-Git comparison stopped at this explicit difference; that stopped attempt is retained instead of silently treating996 as unchanged Git files.

All18 test source SHA256s and21 helper SHA256s match the frozen checkout. Original Hanlin e00498e33f106cc43be0476ffa2e09329c8ca300 source receipts are byte-identical before/after the build. Package lock SHA256 is unchanged; the original report records17 package pins and actual checkouts. Root did not download the larger341,780,081byte binary handoff; the original downstream stage owns its same-run verification.

This stage executed zero UI tests. The96 UI cases, two prototype interaction oracles, and Production Release remain NOT_RUN in this build-stage artifact. The downstream workflow was still in_progress when the second finite observer ended13:18:08UTC; a third single finite observer started13:19:18UTC without canceling the workflow. No result from this old source is transferred to the current integration.
