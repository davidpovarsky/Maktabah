# Focused native run 44940208007: observed failure and CI wiring repair

Run 44940208007 completed with failure at checkout 3b475a8f on application
source cf44ada2. The original full app/UI-runner build and Host48 passed.
The seven-case result is 1 passed, 3 failed, 0 skipped and 3 not run.

The original global Search portrait case passed. Landscape failed its unchanged
native-navigation comparison (86 versus 106, tolerance 1). Reduce Motion completed
the app checks but failed while restoring the real Settings switch. The Study
Sheet case failed its scrollable-overflow prerequisite (-180 versus required >80),
before the real Reader gesture. The three keyboard cases never ran: native
miniTest10 provisioning reported lexical.db HTTP403. All owned Simulator cleanup
receipts passed. None of these observations grants full Native or Release credit.

The intact evidence ZIP was verified against GitHub size, SHA256 and CRC. The
small archive here retains original unedited log/xcresult summaries/test trees,
fixture and matrix reports, with per-file hashes. Full captures are separately
identified; visual interpretation follows their completed independent download.

The focused wrapper supplied GH_TOKEN only to its build step, while the existing
manual Native/Release workflow supplies the built-in read-only token to native
execution. The original fixture script forwards GH_TOKEN to the app's genuine
installer; the lexical manager restricts its Authorization header to api.github.com.
This patch restores that same execution-step environment in the focused and live
wrappers. It changes no app source, data identity, validation, retry eligibility,
assertion, selection, threshold or native outcome. HTTP403 is not made retryable.

The saved error does not identify which lexical HTTP request returned403, so API
rate limiting is a plausible explanation, not a proven diagnosis or claimed fix.
The next actual native attempt must establish provisioning success. The live
run44947117347 was already frozen and continues without cancellation or mutation.
Its provider secret remains confined to the separately reviewed live route.
