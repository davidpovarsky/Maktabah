# Explicit Save before native MiniApps

Both the original native-editor action and Maktabah toolbar now request an explicit Save confirmation before persisting the current native draft and opening MiniApps. Cancel continues editing without invoking the existing save, native engine, SQLite or bridge dispatch paths. The original canonical Save/CAS/receipt/ACK operations remain unchanged.

The rich-editor acceptance journey now reads the actual saved row and all canonical versions in read-only SQLite, opens and cancels the confirmation, checks no outgoing request was created, and verifies both private native blocks still render. It then explicitly confirms Save for the existing warm and cold MiniApps journeys. These UI assertions are compiled, not yet executed.

The catalog has three new English/Hebrew strings; all 110 existing entries are unchanged. The Save confirmation is anchored to the original toolbar button, separately from the existing Discard confirmation.

## Actual Apple compilation

Job `job_2ec641348939` passed the complete 22-source original UI compile on the Scaleway Mac in19.28s, including the four ordinary-account journey sources. The changed production view passed the Apple parser; the entire production target still requires the final native SDK build.

The `apple-ui-compile` folder preserves the original command, exact source hashes, real compiler output, artifact digest and independently verified archive. This grants no actual XCTest, live account, native lifecycle, full app build or signing acceptance.

## Review

The editor lane independently reviewed source SHA256 `bec4030c163db7373dafebc804d4754d1f4818059f028775a7496d200f09b67d` and test SHA256 `b153094431f1c601b00c576b20c9ffb670eedb45187b8d31427a89e1f24257ae`. Both launch triggers lead only to requestMiniApps; the only caller of private launchMiniApps is explicit confirmation. Cancel and retire clear pending context. Native source/row validation remains before actual capture and canonical Save.

The separate private ordinary-network controller directory fix only creates its runtime27 evidence directory before the original logging function runs. Run and matrix claims continue to reject duplicate execution; no previous proof is overwritten.
