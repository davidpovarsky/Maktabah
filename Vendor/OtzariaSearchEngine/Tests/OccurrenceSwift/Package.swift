// swift-tools-version: 6.1
import Foundation
import PackageDescription

let environment = ProcessInfo.processInfo.environment
guard let library = environment["OTZARIA_OCCURRENCE_STATIC_LIBRARY"],
      let nativeDirectory = environment["OTZARIA_OCCURRENCE_NATIVE_LIB_DIR"],
      let encodedLibraries = environment["OTZARIA_OCCURRENCE_NATIVE_LIBS"],
      let data = encodedLibraries.data(using: .utf8),
      let libraries = try? JSONDecoder().decode([String].self, from: data) else {
    fatalError("Use the owned occurrence acceptance driver with an actual staticlib build record")
}
let linkFlags = [
    "-Xlinker", library, "-Xlinker", "/LIBPATH:" + nativeDirectory,
    "-Xlinker", "/NODEFAULTLIB:libcmt",
] + libraries.flatMap { ["-Xlinker", $0] }

let package = Package(
    name: "OtzariaOccurrenceSwiftAcceptance",
    dependencies: [
        .package(url: "https://github.com/apple/swift-crypto.git", revision: "1b6b2e274e85105bfa155183145a1dcfd63331f1")
    ],
    targets: [
        .executableTarget(
            name: "OtzariaOccurrenceSwiftAcceptance",
            dependencies: [.product(name: "Crypto", package: "swift-crypto")],
            path: "Sources",
            swiftSettings: [.define("OTZARIA_OCCURRENCE_TESTING"), .swiftLanguageMode(.v6)],
            linkerSettings: [.unsafeFlags(linkFlags, .when(platforms: [.windows]))]
        )
    ]
)
