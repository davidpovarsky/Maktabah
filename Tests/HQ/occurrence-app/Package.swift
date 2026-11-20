// swift-tools-version: 6.1
import Foundation
import PackageDescription

let env = ProcessInfo.processInfo.environment
guard let library = env["OTZARIA_OCCURRENCE_STATIC_LIBRARY"],
      let nativeDirectory = env["OTZARIA_OCCURRENCE_NATIVE_LIB_DIR"],
      let sqliteLibraryDirectory = env["OTZARIA_OCCURRENCE_SQLITE_LIB_DIR"],
      let core = env["OTZARIA_OCCURRENCE_ACTION_CORE_ROOT"],
      let encoded = env["OTZARIA_OCCURRENCE_NATIVE_LIBS"],
      let bytes = encoded.data(using: .utf8),
      let libraries = try? JSONDecoder().decode([String].self, from: bytes) else {
    fatalError("Use the owned whole app occurrence fixture driver")
}
let linkFlags = ["-Xlinker", library, "-Xlinker", "/LIBPATH:" + nativeDirectory,
                 "-Xlinker", "/LIBPATH:" + sqliteLibraryDirectory, "-Xlinker", "/NODEFAULTLIB:libcmt"]
    + libraries.flatMap { ["-Xlinker", $0] }

let package = Package(
    name: "OtzariaOccurrenceAppAcceptance",
    dependencies: [
        .package(url: "https://github.com/apple/swift-crypto.git",
                 revision: "1b6b2e274e85105bfa155183145a1dcfd63331f1"),
        .package(path: core)
    ],
    targets: [
        .systemLibrary(name: "SQLite3", path: "SQLite3"),
        .executableTarget(name: "OtzariaOccurrenceAppAcceptance",
            dependencies: ["SQLite3", .product(name: "Crypto", package: "swift-crypto"),
                           .product(name: "OtzariaActionCore", package: "actions")],
            path: "Sources",
            swiftSettings: [.define("OTZARIA_OCCURRENCE_TESTING"), .swiftLanguageMode(.v6)],
            linkerSettings: [.unsafeFlags(linkFlags, .when(platforms: [.windows]))])
    ]
)
