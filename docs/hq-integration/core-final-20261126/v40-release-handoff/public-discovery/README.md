# Public v40 release discovery by the original clients

On Scaleway Mac with Xcode 27.0, both original Swift clients used anonymous HTTPS against the real app release catalog and selected their public v40 release. The test used production profile storage and the verified real managed v40 database and installation manifest. Git commit `44100265611efb96a33d7f650f1b845a6a7a4e1e` supplies the original sources. Final app and simulator acceptance remain separate.

- Otzaria selected release 458964363. The result matched the manifest from the existing native install receipt, used that receipt's real d5 consumer build information and returned 15 exact release part URLs.
- Zayit selected `zayit-search-data-v40-20261123094345-17cabb80e86a`. The result matched the manifest from the verified v40 package, required the original index schema 2 and upstream pin, and returned 74 exact release part URLs. The existing signed iOS Debug binary exposes the five original Zayit ABI symbols in the retained inventory.

The harness reuses the existing headless Swift build inputs. It compiles the original Otzaria client and policy unchanged. It compiles the original Zayit distribution source through the end of the service and appends a same-file observation method for the actual private resolver. The app UI controller is outside the headless source projection. The existing compile-time app boundary is unused in discovery. Release URLs, transport, decoders and compatibility functions came from the original clients. The observed library and search manifest identities are in the JSON result. This was a small discovery check that read the catalog and manifests. It did not download index parts, execute the C search ABI or run a simulator.

[Result](RESULT.json) · [Compiled input hashes](INPUTS.sha256) · [Run log](run.log) · [Previously accepted native d5 build and install](../../native-v40-otzaria)
