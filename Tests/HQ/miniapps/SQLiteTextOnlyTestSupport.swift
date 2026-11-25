#if os(Linux)
// The original SQLiteDatabase is compiled unchanged. MiniApps notes and receipts
// use TEXT columns; compression is outside this check and must never be called.
enum ZstdDecompressor {
    static func decompressData(from: UnsafeRawBufferPointer?) -> String {
        preconditionFailure("Compressed-book decoding is outside MiniApps receipt checks")
    }
}
#endif
