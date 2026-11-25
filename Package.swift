// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MemoryAids",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "MemoryAids",
            path: "Sources/MemoryAids"
        )
    ]
)
