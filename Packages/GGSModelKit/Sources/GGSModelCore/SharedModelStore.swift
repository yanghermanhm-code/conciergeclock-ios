import CryptoKit
import Foundation

/// Where downloaded models live: the "Models" folder of the shared App Group, so PrepPilot,
/// FocusFound and FotoPhilter use one copy. A model counts as installed only after its
/// SHA-256 matched the catalog (a ".verified" file next to it records that).
public struct SharedModelStore: Sendable {
    /// The App Group every Greater Good Software app joins to share models.
    public static let appGroup = "group.com.greatergoodsoftware.models"

    /// The Models folder, or nil when the App Group is not set up for this app.
    public let folder: URL?

    public init(folder: URL?, isShared: Bool = true) {
        self.folder = folder
        self.isShared = isShared
    }

    /// The shared store. Without the App Groups capability (for example a free Personal Team
    /// in Xcode) models go to this app's own Application Support folder instead: offline AI
    /// still works, but other apps cannot reuse the download.
    public static var shared: SharedModelStore {
        if let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup) {
            return SharedModelStore(folder: container.appendingPathComponent("Models", isDirectory: true), isShared: true)
        }
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        return SharedModelStore(folder: support?.appendingPathComponent("Models", isDirectory: true), isShared: false)
    }

    /// Whether the folder is the App Group one (shared with the other apps).
    public let isShared: Bool

    public var isAvailable: Bool { folder != nil }

    public func fileURL(for spec: ModelSpec) -> URL? {
        folder?.appendingPathComponent(spec.fileName)
    }

    func markerURL(for spec: ModelSpec) -> URL? {
        folder?.appendingPathComponent(spec.fileName + ".verified")
    }

    /// A partly downloaded file waiting to be checked.
    public func partialURL(for spec: ModelSpec) -> URL? {
        folder?.appendingPathComponent(spec.fileName + ".part")
    }

    /// Whether the model is downloaded and verified.
    public func isInstalled(_ spec: ModelSpec) -> Bool {
        guard let file = fileURL(for: spec), let marker = markerURL(for: spec),
              let recorded = try? String(contentsOf: marker, encoding: .utf8),
              recorded.trimmingCharacters(in: .whitespacesAndNewlines) == spec.sha256,
              let size = (try? FileManager.default.attributesOfItem(atPath: file.path))?[.size] as? NSNumber
        else { return false }
        return size.int64Value == spec.sizeBytes
    }

    public func installedModels() -> [ModelSpec] {
        ModelCatalog.all.filter(isInstalled)
    }

    /// Creates the folder (excluded from iCloud/iTunes backup: the model can be downloaded again).
    public func prepareFolder() throws -> URL {
        guard var folder else { throw ModelStoreError.appGroupMissing }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? folder.setResourceValues(values)
        return folder
    }

    /// Checks a downloaded file against the catalog and moves it into place.
    public func install(downloadedFile: URL, as spec: ModelSpec) throws {
        _ = try prepareFolder()
        guard let destination = fileURL(for: spec), let marker = markerURL(for: spec) else { throw ModelStoreError.appGroupMissing }
        let size = ((try FileManager.default.attributesOfItem(atPath: downloadedFile.path))[.size] as? NSNumber)?.int64Value ?? -1
        guard size == spec.sizeBytes else {
            try? FileManager.default.removeItem(at: downloadedFile)
            throw ModelStoreError.wrongSize(expected: spec.sizeBytes, actual: size)
        }
        let digest = try Self.sha256(of: downloadedFile)
        guard digest == spec.sha256 else {
            try? FileManager.default.removeItem(at: downloadedFile)
            throw ModelStoreError.checksumMismatch
        }
        try? FileManager.default.removeItem(at: marker)
        if FileManager.default.fileExists(atPath: destination.path) {
            _ = try FileManager.default.replaceItemAt(destination, withItemAt: downloadedFile)
        } else {
            try FileManager.default.moveItem(at: downloadedFile, to: destination)
        }
        try spec.sha256.write(to: marker, atomically: true, encoding: .utf8)
    }

    /// Deletes a model (every app sharing it loses it, so apps confirm first).
    public func delete(_ spec: ModelSpec) throws {
        for url in [fileURL(for: spec), markerURL(for: spec), partialURL(for: spec)].compactMap({ $0 })
        where FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }

    /// Bytes used by the Models folder.
    public func usedBytes() -> Int64 {
        guard let folder, let files = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.fileSizeKey]) else { return 0 }
        return files.reduce(0) { $0 + Int64((try? $1.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0) }
    }

    /// Free space for a large, user-requested download.
    public static func freeBytes() -> Int64 {
        let home = URL(fileURLWithPath: NSHomeDirectory())
        return (try? home.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]).volumeAvailableCapacityForImportantUsage) ?? 0
    }

    /// SHA-256 of a file, read in 8 MB pieces (the models are several GB).
    public static func sha256(of url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while true {
            let chunk = try autoreleasepool { try handle.read(upToCount: 8 * 1024 * 1024) }
            guard let chunk, !chunk.isEmpty else { break }
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}

public enum ModelStoreError: Error, Equatable, Sendable {
    case appGroupMissing
    case wrongSize(expected: Int64, actual: Int64)
    case checksumMismatch
    case notEnoughSpace(needed: Int64)
}
