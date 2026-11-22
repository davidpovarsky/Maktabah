# Raw preflight evidence

The original source-only command exited0 in7.5seconds. Its stdout uses native Windows CRLF line endings. The first retention script stopped at Git whitespace checking after the successful command; it did not commit or rerun any validation. These raw bytes remain identical to build output and RUN.json hashes. The local attributes preserve bytes and recognize CRLF without disabling source whitespace checks. No source, test assertion, gate or global Git setting was changed.
