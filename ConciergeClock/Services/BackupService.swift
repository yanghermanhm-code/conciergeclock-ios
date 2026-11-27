import ConciergeCore
import ConciergeData
import Foundation
import Observation
import SwiftUI
import UIKit
import UniformTypeIdentifiers

extension UTType {
    /// `.conciergeclock` full backups (JSON). Declared in Config/Info.plist.
    static let conciergeClockBackup = UTType(exportedAs: "com.greatergoodsoftware.conciergeclock.backup", conformingTo: .json)
}

/// Backups, restores, spreadsheets and the automatic backup to a folder the user chooses.
/// Every file is created on the iPhone and handed to the share sheet or written to the chosen
/// folder (Files, iCloud Drive…); Concierge Clock itself never uploads anything.
@MainActor
@Observable
final class BackupService {
    /// What a share sheet should offer.
    struct ShareItem: Identifiable {
        let id = UUID()
        let urls: [URL]
    }

    private(set) var isWorking = false
    /// The folder automatic backups go to (its display name), or nil.
    private(set) var autoBackupFolderName: String?
    /// Why the last automatic backup failed, if it did.
    private(set) var autoBackupProblem: AutoBackupProblem?

    enum AutoBackupProblem: Equatable {
        /// The folder was moved, deleted or is no longer reachable.
        case folderUnavailable
        case writeFailed
    }

    private let database: AppDatabase

    init(database: AppDatabase) {
        self.database = database
        autoBackupFolderName = Self.resolveFolder(database.loadAutoBackupBookmark())?.lastPathComponent
    }

    static var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(version) (\(build))"
    }

    /// A fresh folder under tmp/Exports for one export.
    private func exportFolder() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("Exports", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    // MARK: Backup & restore

    /// Writes a full `.conciergeclock` backup and returns it for the share sheet.
    func makeBackup(settings: SettingsStore) async throws -> ShareItem {
        isWorking = true
        defer { isWorking = false }
        let folder = try exportFolder()
        let database = self.database
        let version = Self.appVersion
        let url = try await Task.detached(priority: .userInitiated) { () throws -> URL in
            let now = Date()
            let payload = try BackupStore(database: database).exportPayload(appVersion: version, at: now)
            let url = folder.appendingPathComponent(BackupPayload.fileName(at: now))
            try payload.encoded().write(to: url, options: .atomic)
            return url
        }.value
        settings.settings.lastBackupAt = Date()
        return ShareItem(urls: [url])
    }

    /// Reads and checks a backup (from Files or opened from another app). Nothing changes
    /// until `restore(_:model:)`.
    func readBackup(at url: URL) async throws -> BackupPayload {
        isWorking = true
        defer { isWorking = false }
        return try await Task.detached(priority: .userInitiated) {
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            let data: Data
            do {
                data = try Data(contentsOf: url)
            } catch {
                throw BackupError.notABackup
            }
            let payload = try BackupPayload.decode(data)
            guard payload.integrityIssues.isEmpty else { throw BackupError.inconsistent }
            return payload
        }.value
    }

    /// Replaces everything with the backup, then reloads settings.
    func restore(_ payload: BackupPayload, model: AppModel) async throws {
        isWorking = true
        defer { isWorking = false }
        let database = self.database
        try await Task.detached(priority: .userInitiated) {
            try BackupStore(database: database).replaceAll(with: payload)
        }.value
        model.didRestoreBackup()
    }

    // MARK: Spreadsheets

    /// Two CSV files: the wake log and the alarms.
    func makeCSV(l10n: Localizer) async throws -> ShareItem {
        isWorking = true
        defer { isWorking = false }
        let folder = try exportFolder()
        let database = self.database
        let names = (wakeLog: l10n["export.file.wakeLog"], alarms: l10n["export.file.alarms"])
        let urls = try await Task.detached(priority: .userInitiated) { () throws -> [URL] in
            let payload = try BackupStore(database: database).exportPayload(appVersion: "")
            let files = [
                (names.wakeLog, CSVExport.wakeLog(payload.wakeEvents)),
                (names.alarms, CSVExport.alarms(payload.alarms)),
            ]
            return try files.map { name, text in
                let url = folder.appendingPathComponent(Self.safeFileName(name) + ".csv")
                try Data(text.utf8).write(to: url, options: .atomic)
                return url
            }
        }.value
        return ShareItem(urls: urls)
    }

    nonisolated static func safeFileName(_ name: String) -> String {
        let forbidden = CharacterSet(charactersIn: "/\\?%*|\"<>:")
        return name.components(separatedBy: forbidden).joined(separator: "-")
    }

    // MARK: Automatic backup

    /// Remembers `folder` (picked with the folder picker) for automatic backups and saves one
    /// there right away.
    func chooseAutoBackupFolder(_ folder: URL, settings: SettingsStore) {
        let accessing = folder.startAccessingSecurityScopedResource()
        defer { if accessing { folder.stopAccessingSecurityScopedResource() } }
        do {
            let bookmark = try folder.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
            try database.saveAutoBackupBookmark(bookmark)
            autoBackupFolderName = folder.lastPathComponent
            autoBackupProblem = nil
            settings.settings.autoBackupEnabled = true
            settings.settings.lastAutoBackupAt = nil
            autoBackupIfDue(settings: settings)
        } catch {
            autoBackupProblem = .folderUnavailable
        }
    }

    /// Stops automatic backups and forgets the folder. Backups already saved stay there.
    func stopAutoBackup(settings: SettingsStore) {
        try? database.saveAutoBackupBookmark(nil)
        autoBackupFolderName = nil
        autoBackupProblem = nil
        settings.settings.autoBackupEnabled = false
    }

    /// Saves a backup to the chosen folder when automatic backup is on and the last one is
    /// more than a day old. Keeps the 7 newest automatic backups in that folder.
    func autoBackupIfDue(settings: SettingsStore, now: Date = Date()) {
        guard settings.settings.autoBackupEnabled else { return }
        if let last = settings.settings.lastAutoBackupAt, now.timeIntervalSince(last) < 20 * 3600 { return }
        guard let bookmark = database.loadAutoBackupBookmark(), let folder = Self.resolveFolder(bookmark) else {
            autoBackupProblem = .folderUnavailable
            return
        }
        let database = self.database
        let version = Self.appVersion
        Task {
            let result = await Task.detached(priority: .utility) { () -> Bool in
                let accessing = folder.startAccessingSecurityScopedResource()
                defer { if accessing { folder.stopAccessingSecurityScopedResource() } }
                do {
                    let payload = try BackupStore(database: database).exportPayload(appVersion: version, at: now)
                    let url = folder.appendingPathComponent(BackupPayload.fileName(at: now))
                    try payload.encoded().write(to: url, options: .atomic)
                    Self.pruneAutoBackups(in: folder, keep: 7)
                    return true
                } catch {
                    return false
                }
            }.value
            if result {
                settings.settings.lastAutoBackupAt = now
                autoBackupProblem = nil
            } else {
                autoBackupProblem = .writeFailed
            }
        }
    }

    /// The folder a bookmark points to, or nil when it is gone.
    private static func resolveFolder(_ bookmark: Data?) -> URL? {
        guard let bookmark else { return nil }
        var stale = false
        return try? URL(resolvingBookmarkData: bookmark, options: [], relativeTo: nil, bookmarkDataIsStale: &stale)
    }

    /// Deletes all but the newest `keep` Concierge Clock backups in `folder` (only files this
    /// app named; nothing else in the folder is touched).
    nonisolated private static func pruneAutoBackups(in folder: URL, keep: Int) {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
        let backups = names
            .filter { $0.hasPrefix("Concierge Clock Backup ") && $0.hasSuffix("." + BackupPayload.fileExtension) }
            .sorted(by: >) // The date stamp sorts chronologically.
        for name in backups.dropFirst(keep) {
            try? FileManager.default.removeItem(at: folder.appendingPathComponent(name))
        }
    }
}

/// The system share sheet for exported files.
struct ShareSheet: UIViewControllerRepresentable {
    let urls: [URL]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: urls, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

extension Localizer {
    func backupErrorMessage(_ error: Error) -> String {
        switch error as? BackupError {
        case .notABackup: self["backup.error.notABackup"]
        case .newerVersion: self["backup.error.newer"]
        case .inconsistent: self["backup.error.damaged"]
        case .writeFailed: self["backup.error.write"]
        case nil: error.localizedDescription
        }
    }
}
