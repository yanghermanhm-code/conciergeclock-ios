import ConciergeCore
import GGSBrand
import SwiftUI
import UniformTypeIdentifiers

/// Settings › Backup & Export: full JSON backup and restore, automatic daily backup to a
/// folder the user chooses (iCloud Drive, On My iPhone, any Files location), and spreadsheets.
struct BackupExportView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.l10n) private var l10n
    @State private var share: BackupService.ShareItem?
    @State private var choosingBackup = false
    @State private var choosingFolder = false
    @State private var pendingRestore: BackupPayload?
    @State private var errorMessage: String?

    var body: some View {
        let settings = model.settings.settings
        let backups = model.backups
        Form {
            Section {
                Button {
                    run { try await backups.makeBackup(settings: model.settings) }
                } label: {
                    Label(l10n["backup.now"], systemImage: "externaldrive.badge.plus")
                }
                .accessibilityIdentifier("backup.now")
                Button {
                    choosingBackup = true
                } label: {
                    Label(l10n["backup.restore"], systemImage: "arrow.counterclockwise")
                }
            } header: {
                Text(l10n["backup.header"])
            } footer: {
                VStack(alignment: .leading, spacing: 6) {
                    if let last = settings.lastBackupAt {
                        Text(l10n("backup.last", l10n.dateTime(last)))
                    } else {
                        Text(l10n["backup.never"])
                    }
                    Text(l10n["backup.footer"])
                }
            }

            Section {
                if let folder = backups.autoBackupFolderName, settings.autoBackupEnabled {
                    LabeledContent(l10n["backup.auto.folder"], value: folder)
                    if let last = settings.lastAutoBackupAt {
                        LabeledContent(l10n["backup.auto.last"], value: l10n.dateTime(last))
                    }
                    Button(l10n["backup.auto.change"]) { choosingFolder = true }
                    Button(l10n["backup.auto.stop"], role: .destructive) {
                        backups.stopAutoBackup(settings: model.settings)
                    }
                } else {
                    Button {
                        choosingFolder = true
                    } label: {
                        Label(l10n["backup.auto.choose"], systemImage: "folder.badge.plus")
                    }
                }
                if let problem = backups.autoBackupProblem {
                    Label(problem == .folderUnavailable ? l10n["backup.auto.folderGone"] : l10n["backup.auto.failed"], systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                        .font(.footnote)
                }
            } header: {
                Text(l10n["backup.auto.header"])
            } footer: {
                Text(l10n["backup.auto.footer"])
            }

            Section {
                Button {
                    run { try await backups.makeCSV(l10n: l10n) }
                } label: {
                    Label(l10n["export.csv"], systemImage: "tablecells")
                }
            } footer: {
                Text(l10n["export.footer"])
            }

            if backups.isWorking {
                Section {
                    HStack(spacing: 12) {
                        ProgressView()
                        Text(l10n["export.working"])
                    }
                }
            }
        }
        .navigationTitle(l10n["backup.title"])
        .navigationBarTitleDisplayMode(.inline)
        .disabled(backups.isWorking)
        .sheet(item: $share) { item in
            ShareSheet(urls: item.urls)
        }
        .fileImporter(isPresented: $choosingBackup, allowedContentTypes: [.conciergeClockBackup, .json, .data]) { result in
            guard case let .success(url) = result else { return }
            Task {
                do {
                    pendingRestore = try await backups.readBackup(at: url)
                } catch {
                    errorMessage = l10n.backupErrorMessage(error)
                }
            }
        }
        // A second importer on the same view is ignored by SwiftUI, so the folder picker hangs
        // off the section's background.
        .background(
            Color.clear.fileImporter(isPresented: $choosingFolder, allowedContentTypes: [.folder]) { result in
                guard case let .success(url) = result else { return }
                backups.chooseAutoBackupFolder(url, settings: model.settings)
            }
        )
        .restoreConfirmation($pendingRestore, errorMessage: $errorMessage)
        .alert(l10n["error.title"], isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button(l10n["common.ok"], role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    /// Runs an export and opens the share sheet with its files.
    private func run(_ work: @escaping @MainActor () async throws -> BackupService.ShareItem) {
        Task {
            do {
                share = try await work()
            } catch {
                errorMessage = l10n.backupErrorMessage(error)
            }
        }
    }
}

/// Asks before replacing everything with a backup, showing what the backup contains.
private struct RestoreConfirmation: ViewModifier {
    @Binding var pending: BackupPayload?
    @Binding var errorMessage: String?
    @Environment(AppModel.self) private var model
    @Environment(\.l10n) private var l10n

    func body(content: Content) -> some View {
        content.confirmationDialog(
            l10n["backup.confirmTitle"],
            isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } }),
            titleVisibility: .visible,
            presenting: pending
        ) { payload in
            Button(l10n["common.cancel"], role: .cancel) {
                pending = nil
            }
            Button(l10n["backup.confirmRestore"], role: .destructive) {
                pending = nil
                Task {
                    do {
                        try await model.backups.restore(payload, model: model)
                    } catch {
                        errorMessage = l10n.backupErrorMessage(error)
                    }
                }
            }
        } message: { payload in
            Text(l10n(
                "backup.confirmMessage",
                l10n.dateTime(payload.createdAt),
                payload.alarms.count,
                payload.wakeEvents.count
            ))
        }
    }
}

extension View {
    /// Confirmation before restoring a backup that has been read.
    func restoreConfirmation(_ pending: Binding<BackupPayload?>, errorMessage: Binding<String?>) -> some View {
        modifier(RestoreConfirmation(pending: pending, errorMessage: errorMessage))
    }
}
