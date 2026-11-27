import ConciergeCore
import Foundation

/// Where the database file lives: Application Support/ConciergeClock/conciergeclock.sqlite.
enum DatabaseLocation {
    static let fileName = "conciergeclock.sqlite"

    static func resolveURL(fileManager: FileManager = .default) throws -> URL {
        try AppDirectories.applicationSupport(fileManager: fileManager).appendingPathComponent(fileName)
    }
}

/// The app's top-level folders.
///
/// - Application Support/ConciergeClock: the database and (Phase 3) pre-recorded briefings.
///   Never purged by iOS, and excluded from nothing: it is part of the iPhone's own backup.
/// - Caches/ConciergeClock: rebuildable scratch files (rendered sounds). iOS may purge it.
public enum AppDirectories {
    public static let folderName = "ConciergeClock"

    public static func applicationSupport(fileManager: FileManager = .default) throws -> URL {
        let url = try fileManager
            .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent(folderName, isDirectory: true)
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    public static func caches(fileManager: FileManager = .default) throws -> URL {
        let url = try fileManager
            .url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent(folderName, isDirectory: true)
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
