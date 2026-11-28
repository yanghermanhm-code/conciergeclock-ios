// swift-tools-version: 6.2
import PackageDescription

// Greater Good Software brand UI shared by FocusFound, FotoPhilter, PrepPilot, ConciergeClock and NoteNook.
// When you change a shared file here, change it in the other apps too. GradCapMark.swift is
// PrepPilot's own mark and ButlerMark.swift is ConciergeClock's (both additive: copying this
// package into another app changes nothing there); BrandProgressRing gained a `mark:` option
// (default `.shield`, so the other apps are unaffected when they copy it back).
let package = Package(
    name: "GGSBrand",
    platforms: [
        .iOS(.v26),
        .macOS(.v26),
    ],
    products: [
        .library(name: "GGSBrand", targets: ["GGSBrand"]),
    ],
    targets: [
        .target(name: "GGSBrand"),
    ]
)
