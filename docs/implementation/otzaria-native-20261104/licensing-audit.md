# Source and licensing audit

The Rust engine is pristine at 225a6d5d7265c478a64d3a609a536d0deed433e7 (7.0.1, MIT); downstream bridge changes do not modify its implementation. Cargo.lock pins the original dependencies. sqlite-bundled is the selected upstream feature; semantic is disabled by default and no model/ONNX runtime is shipped by this change.

Schema and reference-wire-format facts were independently implemented in Swift against SeforimLibrary 344232b6c3e889be2bbf8a8f24f904d16dbef642. No Kotlin DAO or Flutter UI/provider implementation was imported. The 43 functional test vectors in tools/fixtures/otzaria-ref-key-fixtures.json come from that commit's generator/common/src/jvmTest/resources/ref_key_fixtures.json. They are validation data, not runtime Kotlin code.

Existing dictionary.json/Acronyms.json bytes retain their committed resource-manifest provenance and hashes. No new Flutter asset is fetched or licensed by this change. Engine sync now validates those existing bytes locally and never imports new application assets automatically. The historical manifest's license reference is not evidence of a new grant; distribution rights remain the existing owner's responsibility and no broader rights are asserted.

Original Sefaria Mobile remains pinned and headless; only downstream Integration JS and native adapters are changed. Original notices/licenses remain intact. The updater is not imported; delta updating remains deferred.

The CI-only Sharp 0.32.6 download uses the unchanged Sefaria Mobile lockfile. The official darwin-arm64 N-API 7 asset is SHA256 8004e60c1161f65977dd45455a8fa22687c0c387e1b57ef64b44bce2baf0085a (92,687 bytes). libvips 8.14.5 is checked against the original SHA512 in Sharp package.json. Both are existing host build dependencies; this does not import Flutter application assets or update runtime package versions.
