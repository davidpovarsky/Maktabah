# Original occurrence app: early Apple compile gates

Application and XCTest source: `34c7ab5ae026a0d3d08f02a2c97ddf4b38e1a56c`. The strict source/input preflight actually passed at checkout `0c207d37eb92b12f63e0b156df7acdab70575ec2` (SentinelX `job_cea38c2b4c32`). This includes the exact d5 producer, all original producer inputs and the reviewed 78 additional regular test files.

All 90 preceding Native cases and their oracles are retained; two original-Core count cases make 92 required (72 iPad, 20 iPhone). Neither new Native case has run. The compatibility registry remains disabled pending the complete independent SQL qualification.

Two distinct Apple gates are being prepared on one immutable checkout: XCTest SDK/portable workspace checks and the actual unsigned original iOS application build. The latter uses the original React workspace/bundle preparation and exact verified frameworks. These gates do not run Native UI, count as device evidence, or satisfy the pending corpus qualification.

Producer archive and static Mach-O proofs: `docs/hq-integration/occurrence-apple-framework-44661774024-20261120`. Exact binding tests and actual GitHub metadata validation: `docs/hq-integration/d5-prebuilt-20261120`. All failed original attempts and their acceptance boundaries are preserved.
