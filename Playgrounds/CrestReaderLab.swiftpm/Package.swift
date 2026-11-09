// swift-tools-version: 6.0
import PackageDescription
#if canImport(AppleProductTypes)
import AppleProductTypes

let package = Package(
    name: "CrestReaderLab",
    defaultLocalization: "he",
    platforms: [.iOS("26.0")],
    products: [
        .iOSApplication(
            name: "Crest Reader Lab",
            targets: ["AppModule"],
            bundleIdentifier: "com.davidpovarsky.crestreaderlab",
            displayVersion: "0.1",
            bundleVersion: "1",
            supportedDeviceFamilies: [.pad],
            supportedInterfaceOrientations: [
                .landscapeLeft, .landscapeRight, .portrait,
                .portraitUpsideDown(.when(deviceFamilies: [.pad]))
            ]
        )
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "AppModule",
            path: "Sources",
            resources: [.process("Resources")]
        )
    ],
    swiftLanguageModes: [.v5]
)
#else
let package = Package(
    name: "CrestReaderLab",
    platforms: [.iOS("26.0")],
    products: [.executable(name: "CrestReaderLab", targets: ["AppModule"])],
    targets: [.executableTarget(name: "AppModule", path: "Sources", resources: [.process("Resources")])],
    swiftLanguageModes: [.v5]
)
#endif
