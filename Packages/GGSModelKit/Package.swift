// swift-tools-version: 6.2
import PackageDescription

// Greater Good Software's offline AI model support, shared by PrepPilot, FocusFound and
// FotoPhilter. One copy of the model lives in the App Group
// "group.com.greatergoodsoftware.models", so every app that joins the group reuses it.
//
//   GGSModelCore – which models exist (ModelCatalog), where they are stored (SharedModelStore),
//                  downloading and checking them (ModelDownloader), and which model this
//                  iPhone can run (DeviceCapability). Foundation + CryptoKit only.
//   GGSModelKit  – runs a model on the iPhone with Google's LiteRT-LM (GemmaEngine).
//   GGSModelUI   – the step-by-step "Set up offline AI" guide every app shows (11 languages;
//                  strings from PrepPilot's tools/translations, keys "guide.*").
//
// When you change a file here, change it in the other apps too (same rule as GGSBrand).
let package = Package(
    name: "GGSModelKit",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v26),
        .macOS(.v26),
    ],
    products: [
        .library(name: "GGSModelCore", targets: ["GGSModelCore"]),
        .library(name: "GGSModelKit", targets: ["GGSModelKit"]),
        .library(name: "GGSModelUI", targets: ["GGSModelUI"]),
    ],
    dependencies: [
        // Google's on-device LLM runtime (Apache 2.0), v0.20.0, vendored in Packages/LiteRTLM
        // (the upstream repository uses Git LFS and often fails to resolve in Xcode).
        .package(path: "../LiteRTLM"),
    ],
    targets: [
        .target(name: "GGSModelCore"),
        .target(
            name: "GGSModelKit",
            dependencies: [
                "GGSModelCore",
                .product(name: "LiteRTLM", package: "LiteRTLM"),
            ]
        ),
        .target(
            name: "GGSModelUI",
            dependencies: ["GGSModelCore"],
            resources: [.process("Resources")]
        ),
        .testTarget(name: "GGSModelCoreTests", dependencies: ["GGSModelCore"]),
    ]
)
