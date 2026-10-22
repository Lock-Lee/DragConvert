// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "DragConvert",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "DragConvert", path: "Sources/DragConvert")
    ]
)
