# Books Updates provider revalidation

The configured catalog was read once at 2026-11-22 13:44:42 UTC from the exact BookUpdateVM source at a1940076187c0c2e6047115162771f0e48e5cab8. HTTP 200 returned 792 bytes, SHA-256 `99c2cf2fb5e4d5c9f30d2d0016cd769eef2b0953642e3464619310da4710c293`, unchanged from the retained 20–22 November reads.

The actual semicolon-delimited catalog contains a header and seven data rows, each with six columns: `bkid;cat;verName;link;size;bk`. It still supplies no authoritative backend, target schema, source database digest, or migration manifest. The existing refusal remains necessary. No updater, user database, package payload, or test was executed.

The original exploratory HTTP receipt retains its initial default-comma parse. CATALOG_CONTRACT.json corrects only that local parse using the already downloaded bytes and the actual semicolon delimiter. The network request was not repeated; both receipts and the original catalog are retained. This is provider-source evidence, not a compatible-update or recovery acceptance result.
