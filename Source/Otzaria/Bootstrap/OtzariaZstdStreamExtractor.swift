import Foundation

struct OtzariaZstdStreamExtractor: Sendable {
    typealias ProgressHandler = @Sendable (_ consumedInput: Int64, _ totalInput: Int64) -> Void

    func frameContentSize(at archiveURL: URL) throws -> Int64? {
        let handle = try FileHandle(forReadingFrom: archiveURL)
        defer { try? handle.close() }
        let header = try handle.read(upToCount: max(ZSTD_DStreamInSize(), 256)) ?? Data()
        guard !header.isEmpty else {
            throw OtzariaDatabaseBootstrapError.zstdCorruptData("the archive is empty")
        }
        let size = header.withUnsafeBytes {
            ZSTD_getFrameContentSize($0.baseAddress, header.count)
        }
        if size == ZSTD_CONTENTSIZE_ERROR {
            throw OtzariaDatabaseBootstrapError.zstdCorruptData("invalid zstd frame header")
        }
        if size == ZSTD_CONTENTSIZE_UNKNOWN { return nil }
        guard size <= UInt64(Int64.max) else {
            throw OtzariaDatabaseBootstrapError.zstdCorruptData("declared output is too large")
        }
        return Int64(size)
    }

    @discardableResult
    func extract(
        archiveURL: URL,
        outputURL: URL,
        progress: @escaping ProgressHandler
    ) throws -> Int64 {
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: outputURL.path) {
            try fileManager.removeItem(at: outputURL)
        }
        fileManager.createFile(atPath: outputURL.path, contents: nil)

        do {
            return try extractCore(
                archiveURL: archiveURL,
                outputURL: outputURL,
                append: false,
                progress: progress
            )
        } catch {
            try? fileManager.removeItem(at: outputURL)
            if error is CancellationError {
                throw OtzariaDatabaseBootstrapError.cancelled
            }
            throw error
        }
    }

    @discardableResult
    func extractPart(
        archiveURL: URL,
        outputURL: URL,
        expectedOffset: Int64,
        expectedOutputBytes: Int64,
        progress: @escaping ProgressHandler
    ) throws -> Int64 {
        let fileManager = FileManager.default
        let currentSize = ((try? fileManager.attributesOfItem(atPath: outputURL.path)[.size]) as? NSNumber)?.int64Value ?? 0
        guard currentSize == expectedOffset else {
            throw OtzariaDatabaseBootstrapError.extractionWriteFailed(
                "\(outputURL.lastPathComponent) has offset \(currentSize), expected \(expectedOffset)"
            )
        }
        if !fileManager.fileExists(atPath: outputURL.path) {
            fileManager.createFile(atPath: outputURL.path, contents: nil)
        }
        do {
            let written = try extractCore(
                archiveURL: archiveURL,
                outputURL: outputURL,
                append: true,
                progress: progress
            )
            guard written == expectedOutputBytes else {
                throw OtzariaDatabaseBootstrapError.zstdCorruptData(
                    "\(archiveURL.lastPathComponent) expanded to \(written), expected \(expectedOutputBytes) bytes"
                )
            }
            return written
        }
    }
}

private extension OtzariaZstdStreamExtractor {
    func extractCore(
        archiveURL: URL,
        outputURL: URL,
        append: Bool,
        progress: @escaping ProgressHandler
    ) throws -> Int64 {
        guard let stream = ZSTD_createDStream() else {
            throw OtzariaDatabaseBootstrapError.zstdInitializationFailed("ZSTD_createDStream returned null")
        }
        defer { _ = ZSTD_freeDStream(stream) }

        var result = ZSTD_initDStream(stream)
        try checkZstd(result, operation: "ZSTD_initDStream")

        // Otzaria's production seforim.db.zst is created with zstd --long.
        // The normal 128 MiB decoder window is therefore too small.
        result = ZSTD_DCtx_setParameter(stream, ZSTD_d_windowLogMax, 31)
        try checkZstd(result, operation: "ZSTD_DCtx_setParameter(windowLogMax)")

        let inputChunkSize = max(ZSTD_DStreamInSize(), 128 * 1_024)
        let outputChunkSize = max(ZSTD_DStreamOutSize(), 128 * 1_024)
        let totalInput = OtzariaDatabaseDownloader.fileSize(at: archiveURL)
        let expectedOutput = try frameContentSize(at: archiveURL)

        let inputHandle = try FileHandle(forReadingFrom: archiveURL)
        defer { try? inputHandle.close() }
        let outputHandle = try FileHandle(forWritingTo: outputURL)
        defer { try? outputHandle.close() }
        if append { try outputHandle.seekToEnd() }

        var totalConsumed: Int64 = 0
        var totalWritten: Int64 = 0
        var lastResult: Int?
        var sawInput = false
        var outputData = Data(count: outputChunkSize)

        do {
            while true {
                try Task.checkCancellation()
                let inputData = try inputHandle.read(upToCount: inputChunkSize) ?? Data()
                if inputData.isEmpty { break }
                sawInput = true

                try inputData.withUnsafeBytes { inputBytes in
                    var input = ZSTD_inBuffer(
                        src: inputBytes.baseAddress,
                        size: inputData.count,
                        pos: 0
                    )

                    while input.pos < input.size {
                        try Task.checkCancellation()
                        let produced: Int = try outputData.withUnsafeMutableBytes { outputBytes in
                            var output = ZSTD_outBuffer(
                                dst: outputBytes.baseAddress,
                                size: outputChunkSize,
                                pos: 0
                            )
                            let code = ZSTD_decompressStream(stream, &output, &input)
                            try checkZstd(code, operation: "ZSTD_decompressStream")
                            lastResult = code
                            return output.pos
                        }

                        if produced > 0 {
                            do {
                                try outputHandle.write(contentsOf: outputData.prefix(produced))
                            } catch {
                                throw OtzariaDatabaseBootstrapError.extractionWriteFailed(
                                    error.localizedDescription
                                )
                            }
                            totalWritten += Int64(produced)
                        }
                    }
                }

                totalConsumed += Int64(inputData.count)
                progress(totalConsumed, totalInput)
            }

            guard sawInput, lastResult == 0 else {
                throw OtzariaDatabaseBootstrapError.zstdCorruptData(
                    "the zstd frame ended before decompression completed"
                )
            }
            try outputHandle.synchronize()
        } catch let error as OtzariaDatabaseBootstrapError {
            throw error
        } catch is CancellationError {
            throw OtzariaDatabaseBootstrapError.cancelled
        } catch {
            throw OtzariaDatabaseBootstrapError.extractionWriteFailed(error.localizedDescription)
        }

        if let expectedOutput, expectedOutput != totalWritten {
            throw OtzariaDatabaseBootstrapError.zstdCorruptData(
                "expected \(expectedOutput) output bytes but wrote \(totalWritten)"
            )
        }
        progress(totalInput, totalInput)
        return totalWritten
    }

    func checkZstd(_ code: Int, operation: String) throws {
        guard ZSTD_isError(code) != 0 else { return }
        let message = String(cString: ZSTD_getErrorName(code))
        if operation == "ZSTD_initDStream" || operation.hasPrefix("ZSTD_DCtx_setParameter") {
            throw OtzariaDatabaseBootstrapError.zstdInitializationFailed(message)
        }
        throw OtzariaDatabaseBootstrapError.zstdCorruptData(message)
    }
}
