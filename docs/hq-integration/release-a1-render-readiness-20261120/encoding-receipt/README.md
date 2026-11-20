# A1 evidence byte encodings

This adds a documentation-only receipt to commit 9086a9e0b94ab79480e269fa264f41f548f1f4c2. The original evidence files and their claims are unchanged.

The original FILES.json describes raw local packaging bytes. Git normalizes CRLF in text files to LF. EVIDENCE_ENCODINGS.json records both independently hashed byte streams and retains every differing raw stream in a deterministic gzip. Decompression restores the original hash exactly. PNGs and the two authentic 199-byte attachments have identical raw and canonical Git bytes.

This receipt neither reruns nor changes the A1 XCTest. Its source still waits for actual nonempty text and a rendered-generation diagnostic from the same Reader before the unchanged highlight assertion. The historical test failed; candidate Apple typecheck and Native execution remain NOT_RUN in this evidence tranche.
