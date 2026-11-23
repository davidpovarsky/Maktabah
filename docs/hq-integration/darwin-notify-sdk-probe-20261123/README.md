# Actual Darwin notification SDK diagnosis

The original UI compile first rejected the notification symbols and then rejected the proposed `DarwinNotify` import. The Apple documentation collection name did not establish an importable module in the installed SDK. Both failed runs and all ten unexecuted native leaves remain recorded.

This isolated branch retains the unchanged toolchain selector, requires the exact observed Xcode 27.2/Swift 6.4.2/iPhoneSimulator27.2 tuple, captures the actual `notify.h` and relevant module maps, and compiles declaration-only Swift and C sources. Candidate import paths are derived from the installed maps. A direct-header bridge is a diagnostic control. No application, notification, Simulator action, native test or product source mutation occurs.

The real compiler stdout, stderr, source hashes, process ownership and bounded cleanup are uploaded even on diagnostic failure. A passing diagnostic is not application or native acceptance. The parent product/UI trees are retained exactly. Source and peer-review details are in SOURCE_REVIEW.json.
