import Foundation

enum OtzariaDownloadResponseAction: Equatable {
    case acceptFresh
    case append
    case complete
    case restartFresh(String)
    case failHTTP(Int)
}

enum OtzariaDownloadPolicy {
    static func responseAction(
        statusCode: Int,
        requestedOffset: Int64,
        localSize: Int64,
        expectedSize: Int64,
        contentRange: String?
    ) -> OtzariaDownloadResponseAction {
        if statusCode == 416 {
            return localSize == expectedSize
                ? .complete
                : .restartFresh("HTTP 416 did not prove that the local file is complete")
        }
        if statusCode == 200 { return .acceptFresh }
        guard statusCode == 206 else { return .failHTTP(statusCode) }
        guard requestedOffset > 0,
              let range = parseContentRange(contentRange),
              range.start == requestedOffset,
              range.total == expectedSize else {
            return .restartFresh("Content-Range did not match the requested offset or asset size")
        }
        return .append
    }

    static func reusableOffset(
        metadata: OtzariaDownloadResumeMetadata?,
        release: OtzariaLibraryRelease,
        localSize: Int64
    ) -> Int64 {
        guard let metadata,
              metadata.matches(release),
              localSize > 0,
              localSize <= release.asset.compressedSize else { return 0 }
        if localSize == release.asset.compressedSize { return localSize }
        return metadata.resumeValidator == nil ? 0 : localSize
    }

    static func parseContentRange(_ value: String?) -> (start: Int64, end: Int64, total: Int64)? {
        guard let value else { return nil }
        let expression = try? NSRegularExpression(pattern: #"^bytes ([0-9]+)-([0-9]+)/([0-9]+)$"#)
        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        guard let match = expression?.firstMatch(in: value, range: range), match.numberOfRanges == 4,
              let startRange = Range(match.range(at: 1), in: value),
              let endRange = Range(match.range(at: 2), in: value),
              let totalRange = Range(match.range(at: 3), in: value),
              let start = Int64(value[startRange]),
              let end = Int64(value[endRange]),
              let total = Int64(value[totalRange]),
              start <= end, end < total else { return nil }
        return (start, end, total)
    }
}
