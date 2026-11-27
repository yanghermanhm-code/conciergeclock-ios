import CryptoKit
import Foundation
@testable import GGSModelCore
import XCTest

final class ModelCoreTests: XCTestCase {
    func testCatalogLinksArePinned() {
        XCTAssertEqual(
            ModelCatalog.gemma4E2B.downloadURL.absoluteString,
            "https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/2e12bfd869b2962984f97a1f2a26807316d534cc/gemma-4-E2B-it.litertlm"
        )
        for spec in ModelCatalog.all {
            XCTAssertEqual(spec.sha256.count, 64)
            XCTAssertEqual(spec.revision.count, 40)
            XCTAssertEqual(spec.license, "Apache-2.0")
        }
    }

    func testRecommendedModelByMemory() {
        XCTAssertEqual(DeviceCapability(memoryGB: 7.6).recommendedModel, ModelCatalog.gemma4E4B)
        XCTAssertEqual(DeviceCapability(memoryGB: 5.6).recommendedModel, ModelCatalog.gemma4E2B)
        XCTAssertNil(DeviceCapability(memoryGB: 3.6).recommendedModel)
        XCTAssertEqual(DeviceCapability(memoryGB: 5.6).backend(for: ModelCatalog.gemma4E4B), .cpu)
        XCTAssertEqual(DeviceCapability(memoryGB: 7.6).backend(for: ModelCatalog.gemma4E4B), .gpu)
    }

    func testInstallVerifiesSizeAndChecksum() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = SharedModelStore(folder: folder)
        let bytes = Data("tiny model".utf8)
        var spec = ModelCatalog.gemma4E2B
        spec.sizeBytes = Int64(bytes.count)
        spec.sha256 = SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()

        let download = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try bytes.write(to: download)
        XCTAssertFalse(store.isInstalled(spec))
        try store.install(downloadedFile: download, as: spec)
        XCTAssertTrue(store.isInstalled(spec))

        var wrong = spec
        wrong.sha256 = String(repeating: "0", count: 64)
        XCTAssertFalse(store.isInstalled(wrong), "a different checksum is not the installed model")
        let bad = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try bytes.write(to: bad)
        XCTAssertThrowsError(try store.install(downloadedFile: bad, as: wrong)) { XCTAssertEqual($0 as? ModelStoreError, .checksumMismatch) }
        XCTAssertFalse(FileManager.default.fileExists(atPath: bad.path), "a bad download is deleted")

        try store.delete(spec)
        XCTAssertFalse(store.isInstalled(spec))
    }

    func testStoreWithoutAppGroup() {
        let store = SharedModelStore(folder: nil)
        XCTAssertFalse(store.isAvailable)
        XCTAssertFalse(store.isInstalled(ModelCatalog.gemma4E2B))
        XCTAssertThrowsError(try store.prepareFolder())
    }
}
