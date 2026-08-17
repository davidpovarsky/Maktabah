//
//  ZstdShim.swift
//  Maktabah
//
//  Declares the subset of zstd C symbols used by the app without importing
//  the SwiftPM Clang module that triggers config macro warnings on newer Xcode.
//

import Foundation

let ZSTD_CONTENTSIZE_ERROR: UInt64 = .max
let ZSTD_CONTENTSIZE_UNKNOWN: UInt64 = .max - 1
let ZSTD_d_windowLogMax: Int32 = 100

struct ZSTD_inBuffer {
    var src: UnsafeRawPointer?
    var size: Int
    var pos: Int
}

struct ZSTD_outBuffer {
    var dst: UnsafeMutableRawPointer?
    var size: Int
    var pos: Int
}

@_silgen_name("ZSTD_getFrameContentSize")
func ZSTD_getFrameContentSize(_ src: UnsafeRawPointer?, _ srcSize: Int) -> UInt64

@_silgen_name("ZSTD_decompress")
func ZSTD_decompress(
    _ dst: UnsafeMutableRawPointer?,
    _ dstCapacity: Int,
    _ src: UnsafeRawPointer?,
    _ compressedSize: Int
) -> Int

@_silgen_name("ZSTD_isError")
func ZSTD_isError(_ code: Int) -> UInt32

@_silgen_name("ZSTD_getErrorName")
func ZSTD_getErrorName(_ code: Int) -> UnsafePointer<CChar>

@_silgen_name("ZSTD_createDStream")
func ZSTD_createDStream() -> OpaquePointer?

@_silgen_name("ZSTD_freeDStream")
func ZSTD_freeDStream(_ stream: OpaquePointer?) -> Int

@_silgen_name("ZSTD_initDStream")
func ZSTD_initDStream(_ stream: OpaquePointer?) -> Int

@_silgen_name("ZSTD_DCtx_setParameter")
func ZSTD_DCtx_setParameter(
    _ context: OpaquePointer?,
    _ parameter: Int32,
    _ value: Int32
) -> Int

@_silgen_name("ZSTD_decompressStream")
func ZSTD_decompressStream(
    _ stream: OpaquePointer?,
    _ output: UnsafeMutablePointer<ZSTD_outBuffer>?,
    _ input: UnsafeMutablePointer<ZSTD_inBuffer>?
) -> Int

@_silgen_name("ZSTD_DStreamInSize")
func ZSTD_DStreamInSize() -> Int

@_silgen_name("ZSTD_DStreamOutSize")
func ZSTD_DStreamOutSize() -> Int

@_silgen_name("ZSTD_compressBound")
func ZSTD_compressBound(_ srcSize: Int) -> Int

@_silgen_name("ZSTD_compress")
func ZSTD_compress(
    _ dst: UnsafeMutableRawPointer?,
    _ dstCapacity: Int,
    _ src: UnsafeRawPointer?,
    _ srcSize: Int,
    _ compressionLevel: Int32
) -> Int
