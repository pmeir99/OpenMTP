// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "OpenMTPNative",
    platforms: [.macOS(.v27)],
    products: [.executable(name: "OpenMTPNative", targets: ["OpenMTPNative"])],
    targets: [
        .executableTarget(
            name: "OpenMTPNative",
            path: "Sources/OpenMTPNative"
        )
    ]
)
