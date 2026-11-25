# Frozen official production release for native observation

The full-v32 observation already requires release 409213893 and asset 629048655 with an independent compressed and installed database digest. Its original installer nevertheless requested GitHub's moving latest release. The authenticated failed run reached v40, whose database is published as a manifest and two parts; no native observation began.

This source change lets the existing opt-in DEBUG native install path request its frozen official numeric release ID. The real release client still fetches official metadata, checks the returned ID, and applies all existing asset checks. The existing downloader, extraction, checksum, SQLite, atomic promotion, and the full-v32 driver's final source/count checks remain operative. A pinned lookup failure propagates and cannot be replaced by a resumable cache of another release. Ordinary app launches and Release builds retain their existing latest-release lookup and unpinned offline resume behavior.

The four changed paths are recorded in SOURCE_REVIEW.json and SOURCE_DELTA.patch. The actual Swift 6 component controls compile the original release client, models, and profile registry in DEBUG and Release configurations; they made 17 and 8 assertions respectively against authentic official v32 metadata. Three invalid CLI scope cases fail before any Simulator operation. The service addition has source/inverse review and Swift syntax validation; it has not executed in the Apple app yet.

Independent source review by /root/stageb_repair found the original cache fallback issue and verified its repair. This is a published source candidate only. Native install and both original UI cases still require a new source-bound run. The six successful Library cases are preserved and are not selected for replay by this change.

Latest-release multipart database support is separate product work. This change does not claim v40 download, schema compatibility, or Books update migration acceptance.
