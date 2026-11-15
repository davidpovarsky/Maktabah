# Reader lane comparison with schema10 reference

Reference `850b9e47` versus leased base `df2a21941afa46da716387fce9de620865d2a151`. Read-only Git diff; no merge, checkout of reference blobs, or restoration of whole files.

- The reading service, unit/descriptor models, reading bridge and line-anchor cache are identical between these two commits. Their newly demonstrated sparse coverage/navigation/cache defects therefore need focused fixes; switching to schema10 blobs would not fix them.
- `OtzariaAppContainer.swift` at schema10 has `generationSnapshot()`, detected capabilities and isolated metadata enrichment. Base lacks these. This lane adds the small synchronized snapshot accessor for its request guards, without importing schema10 capability/metadata machinery or changing shared DB/service lease signatures.
- The generic adapter at schema10 retains a real locator for multiline fallback content. Base fabricates `content.id + newline offset`. This lane independently repairs that localized fallback and tests actual multiline preservation. Schema10 also has versioned text/decorations, alternative TOC, reference resolution and different search calls/pagination. Those systems are not restored by this patch; Search/Inspector/API owners retain their leases.
- Neutral models at schema10 add locator descriptions, TOC line coverage, version/source metadata, language normalization and search titles. The existing running UTF16 renderer is already present in base. This lane leaves the neutral models untouched after actual-source Unicode/range fixtures pass.

Remaining schema10 feature differences are not evidence of a reader-performance fix and not authority to copy implementations across branches. In particular, full-corpus/iPad performance and application integration remain NOT_RUN/BLOCKED_DEVICE.
