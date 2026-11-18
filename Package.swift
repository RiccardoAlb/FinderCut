// swift-tools-version:5.9
import Foundation
import PackageDescription

// Local-only debugging: if the git-ignored LocalDiagnostics.swift exists, enable it.
let localDiagnostics = FileManager.default.fileExists(
    atPath: URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        .appendingPathComponent("Sources/FinderCut/LocalDiagnostics.swift").path)

let package = Package(
    name: "FinderCut",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "FinderCutCore", path: "Sources/FinderCutCore"),
        .executableTarget(
            name: "FinderCut",
            dependencies: ["FinderCutCore"],
            path: "Sources/FinderCut",
            swiftSettings: localDiagnostics ? [.define("LOCAL_DIAGNOSTICS")] : []),
        .testTarget(name: "FinderCutCoreTests", dependencies: ["FinderCutCore"], path: "Tests/FinderCutCoreTests"),
    ]
)
