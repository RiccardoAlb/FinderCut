// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "FinderCut",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "FinderCutCore", path: "Sources/FinderCutCore"),
        .executableTarget(name: "FinderCut", dependencies: ["FinderCutCore"], path: "Sources/FinderCut"),
        .testTarget(name: "FinderCutCoreTests", dependencies: ["FinderCutCore"], path: "Tests/FinderCutCoreTests"),
    ]
)
