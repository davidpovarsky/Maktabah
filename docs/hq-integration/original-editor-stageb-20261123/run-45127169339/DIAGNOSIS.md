# Stage B run 45127169339: exact source admission failure

The authentic first Stage B run stopped before SDK restoration, installed Xcode inspection, compilation, or simulator execution. The primary error was `Original SDK toolchain differs from the exact retained framework producer`, raised by the unchanged selector at line56.

The committed schema2 input contains the authenticated original producer tuple under `framework_producer.toolchain`, but omits the required top-level `toolchain` alias. The selector intentionally compares these values exactly. Its call occurs at main line131, before xcode-select and candidate enumeration; this is not evidence that the runner lacks the required Xcode.

The source freeze/Python prepare step passed. The restore, UI compile, app build and saved-annotation journey were all skipped. The always-run collector then failed because the downstream build result file did not exist; that is secondary and grants no UI result.

## Authentic evidence

- Repository davidpovarsky/Maktabah, run45127169339 attempt1, job137534067388, source6dd57e5b7d7ffa570472d31e38881af32ff38177, treecd105995c0102d82b48dddef82c25cc56cfac08c.
- Artifact14796393879: 88,573 bytes, SHA2564f58493c4b1818ca04e457f1b221094ce7418d778c29d763916fd9f0655fa8bc; six unique safe CRC-verified members, no upstream member index. Original ZIP, raw log and authenticated API metadata retained unchanged.
- Original application/UI trees remain source1969b2065469b55e38e42cbb838a469ffa6a80f7. Original SDK EN/HE external-consumer qualification remains separately accepted at run45123300449; it does not qualify this mounted journey.

## Bounded proposed correction

Add the exact existing original producer tuple as the missing top-level input alias: Xcode27.0/build27A266a, the complete recorded Swift6.4 version/target string, SDK27.0. Keep the selector, workflow, source/failure evidence, original producer and signed-runtime identities unchanged. Before publication, execute the unchanged selector configuration function against the final committed input on Oracle, and inspect the remaining configuration-only consumers. Actual installed-toolchain inspection remains Apple-only. No replay of the accepted six runtime-admission/eight source controls is implied by source correspondence. Root review is required before any new CI publication.
