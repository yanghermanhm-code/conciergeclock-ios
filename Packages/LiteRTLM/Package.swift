// swift-tools-version: 5.9
// Vendored copy of Google's LiteRT-LM Swift package, release v0.20.0
// (https://github.com/google-ai-edge/LiteRT-LM, tag v0.20.0, commit
// 95df4c2a932b4917ace66fcfef6c154e8d2a6699). Apache License 2.0 — see LICENSE.
//
// Why vendored: resolving the upstream repository makes Xcode clone a very large repo
// with Git LFS files, which often fails and then leaves every package "missing". This
// package contains only the Swift wrapper (unchanged sources from swift/) and downloads the
// prebuilt runtime from the official GitHub release, verified by checksum.
//
// To update: copy swift/*.swift (not the tests) from the new tag and change the URLs and
// checksums below to the ones in that tag's Package.swift.
import PackageDescription

let package = Package(
    name: "LiteRTLM",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
    ],
    products: [
        .library(name: "LiteRTLM", targets: ["LiteRTLM"]),
    ],
    targets: [
        .binaryTarget(
            name: "CLiteRTLM",
            url: "https://github.com/google-ai-edge/LiteRT-LM/releases/download/v0.20.0/CLiteRTLM.xcframework.zip",
            checksum: "ae6b2b2ea3e46964152110ad5bd64b754f39273add2eb4cc417bbbbd72c5e6e7"
        ),
        .binaryTarget(
            name: "CLiteRTLM_mac",
            url: "https://github.com/google-ai-edge/LiteRT-LM/releases/download/v0.20.0/CLiteRTLM_mac.xcframework.zip",
            checksum: "ed5943902177e8df2ec18c5a1e85b5dcb74b55e6cab84da95d0a00776fb4a270"
        ),
        .target(
            name: "LiteRTLM",
            dependencies: [
                .target(name: "CLiteRTLM", condition: .when(platforms: [.iOS])),
                .target(name: "CLiteRTLM_mac", condition: .when(platforms: [.macOS])),
            ],
            // Google's sources are kept unchanged; their concurrency warnings are theirs.
            swiftSettings: [.unsafeFlags(["-suppress-warnings"])]
        ),
    ]
)
