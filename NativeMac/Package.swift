// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "OpenMTPNative",
    platforms: [.macOS(.v26)],
    products: [.executable(name: "OpenMTPNative", targets: ["OpenMTPNative"])],
    targets: [
        .executableTarget(
            name: "OpenMTPNative",
            path: "Sources/OpenMTPNative"
        )
    ]
)
