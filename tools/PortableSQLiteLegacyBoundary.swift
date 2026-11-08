// Test compilation boundary for a legacy upstream helper that imports Apple OSLog.
// SQL fixtures exercise the real downstream OtzariaLineContentDecoder and native SQLite/zstd.
// Calling this excluded legacy path is a test failure, never a fabricated decompression result.
#if os(Windows)
import Foundation
enum ZstdDecompressor {
    static func decompressData(from data: UnsafeRawBufferPointer) -> String {
        fatalError("The legacy OSLog decompression helper requires Apple SDK verification")
    }
}
#endif
