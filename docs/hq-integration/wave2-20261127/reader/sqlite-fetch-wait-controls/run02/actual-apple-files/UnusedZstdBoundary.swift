import Foundation

// Compile-only boundary for the unrelated compressed-column helper in the
// COMPLETE original SQLiteDatabase.swift. No SQLite API is mocked or replaced.
// These checks never call a decompression API; an accidental call must fail.
enum ZstdDecompressor {
    static func decompressData(from: UnsafeRawBufferPointer?) -> String {
        fatalError("ZSTD is outside this actual SQLite connection acceptance scope")
    }
}
