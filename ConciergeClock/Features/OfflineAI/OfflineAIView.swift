import GGSBrand
import GGSModelCore
import GGSModelUI
import ConciergeCore
import SwiftUI

/// Settings › Offline AI: download Gemma, choose the model, test it. The same screen, guide and
/// wording as PrepPilot and FocusFound; the model is shared with Greater Good Software's other
/// apps, so it is downloaded once for all of them.
struct OfflineAIView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.l10n) private var l10n
    @State private var pendingDelete: ModelSpec?
    @State private var deleteError: String?
    @State private var showingGuide = false
    @State private var testSteps: [ModelService.TestStep] = []
    @State private var testing = false

    private var models: ModelService { model.models }

    var body: some View {
        @Bindable var store = model.settings
        Form {
            if models.isSupported {
                Section {
                    Button {
                        showingGuide = true
                    } label: {
                        Label(l10n["guide.app.open"], systemImage: "list.number")
                    }
                }
            }

            Section {
                Toggle(l10n["ai.use"], isOn: $store.settings.useOfflineAI)
            } footer: {
                Text(l10n["ai.useFooter"])
            }

            if !models.isSupported {
                Section {
                    Label(l10n["ai.unsupported"], systemImage: "exclamationmark.triangle")
                        .foregroundStyle(Theme.textSecondary)
                }
            }

            Section {
                ForEach(ModelCatalog.all) { spec in
                    ModelRow(spec: spec, onDelete: { pendingDelete = spec })
                }
            } header: {
                Text(l10n["ai.models"])
            } footer: {
                Text(l10n["ai.modelsFooter"])
            }

            Section {
                Picker(l10n["ai.choice"], selection: $store.settings.localModel) {
                    Text(l10n("ai.choice.automatic", models.capability.recommendedModel?.displayName ?? "—")).tag(LocalModelChoice.automatic)
                    Text(verbatim: ModelCatalog.gemma4E2B.displayName).tag(LocalModelChoice.gemma4E2B)
                    Text(verbatim: ModelCatalog.gemma4E4B.displayName).tag(LocalModelChoice.gemma4E4B)
                }
                Toggle(l10n["ai.wifiOnly"], isOn: $store.settings.modelDownloadWiFiOnly)
            } header: {
                Text(l10n["ai.options"])
            }

            if let spec = models.chosenSpec, models.downloader.state(spec) == .installed {
                Section {
                    Button {
                        testSteps = []
                        testing = true
                        Task {
                            await models.selfTest { testSteps.append($0) }
                            testing = false
                        }
                    } label: {
                        HStack {
                            Label(l10n["ai.test"], systemImage: "stethoscope")
                            if testing { Spacer(); ProgressView() }
                        }
                    }
                    .disabled(testing)
                    ForEach(testSteps) { step in
                        HStack(alignment: .firstTextBaseline) {
                            Image(systemName: step.ok ? "checkmark.circle.fill" : "xmark.octagon.fill")
                                .foregroundStyle(step.ok ? ConciergeStyle.tint : .red)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(testName(step.kind)).font(.subheadline)
                                Text(testDetail(step)).font(.caption.monospacedDigit()).foregroundStyle(Theme.textSecondary)
                            }
                        }
                        .accessibilityElement(children: .combine)
                    }
                } footer: {
                    Text(l10n["ai.test.footer"])
                }
            }

            Section {
                LabeledContent(l10n["ai.storageUsed"], value: l10n.byteText(models.downloader.store.usedBytes()))
                LabeledContent(l10n["ai.storageFree"], value: l10n.byteText(SharedModelStore.freeBytes()))
            }
        }
        .navigationTitle(l10n["ai.title"])
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { models.refresh() }
        .sheet(isPresented: $showingGuide) { ConciergeClockSetupGuide() }
        .confirmationDialog(
            l10n("ai.deleteTitle", pendingDelete?.displayName ?? ""),
            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
            titleVisibility: .visible,
            presenting: pendingDelete
        ) { spec in
            Button(l10n["common.delete"], role: .destructive) {
                do { try models.delete(spec) } catch { deleteError = error.localizedDescription }
            }
        } message: { _ in
            Text(l10n["ai.deleteMessage"])
        }
        .alert(l10n["ai.deleteFailed"], isPresented: Binding(get: { deleteError != nil }, set: { if !$0 { deleteError = nil } })) {
            Button(l10n["common.ok"]) { deleteError = nil }
        } message: {
            Text(deleteError ?? "")
        }
    }
}

/// One model: size, whether it suits this iPhone, and its download.
private struct ModelRow: View {
    let spec: ModelSpec
    let onDelete: () -> Void
    @Environment(AppModel.self) private var model
    @Environment(\.l10n) private var l10n

    private var models: ModelService { model.models }

    var body: some View {
        let state = models.downloader.state(spec)
        let capability = models.capability
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(verbatim: spec.displayName).font(.headline)
                if capability.recommendedModel == spec {
                    Text(l10n["ai.recommended"])
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(ConciergeStyle.tint.opacity(0.15), in: Capsule())
                        .foregroundStyle(ConciergeStyle.tint)
                }
                Spacer()
                Text(l10n.byteText(spec.sizeBytes)).font(.caption.monospacedDigit()).foregroundStyle(Theme.textSecondary)
            }
            Text(spec == ModelCatalog.gemma4E4B ? l10n["ai.e4bHint"] : l10n["ai.e2bHint"])
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
            if capability.canRun(spec), capability.backend(for: spec) == .cpu {
                Label(l10n["ai.cpuNote"], systemImage: "tortoise")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            controls(state)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func controls(_ state: ModelDownloader.State) -> some View {
        if !models.capability.canRun(spec) {
            Text(l10n["ai.unsupported"]).font(.caption).foregroundStyle(Theme.textSecondary)
        } else {
            switch state {
            case .idle:
                Button(l10n["ai.download"]) { models.download(spec) }
                    .buttonStyle(.borderedProminent)
            case let .downloading(progress, received):
                VStack(alignment: .leading, spacing: 4) {
                    ProgressView(value: progress)
                    HStack {
                        Text(l10n("ai.progress", l10n.byteText(received), l10n.byteText(spec.sizeBytes)))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(Theme.textSecondary)
                        Spacer()
                        Button(l10n["ai.pause"]) { models.downloader.pause(spec) }
                            .font(.caption)
                    }
                }
            case .paused:
                HStack {
                    Button(l10n["ai.resume"]) { models.download(spec) }
                        .buttonStyle(.borderedProminent)
                    Button(l10n["common.cancel"], role: .destructive) { models.downloader.cancel(spec) }
                        .buttonStyle(.bordered)
                }
            case .verifying:
                HStack(spacing: 8) {
                    ProgressView()
                    Text(l10n["ai.verifying"]).font(.caption).foregroundStyle(Theme.textSecondary)
                }
            case .installed:
                HStack {
                    Label(l10n["ai.installed"], systemImage: "checkmark.circle.fill")
                        .foregroundStyle(ConciergeStyle.tint)
                        .font(.subheadline)
                    Spacer()
                    Button(l10n["common.delete"], role: .destructive, action: onDelete)
                        .font(.caption)
                }
            case let .failed(failure):
                VStack(alignment: .leading, spacing: 6) {
                    Text(failureText(failure)).font(.caption).foregroundStyle(.red)
                    Button(l10n["ai.retry"]) { models.download(spec) }
                        .buttonStyle(.bordered)
                }
            }
        }
    }

    private func failureText(_ failure: ModelDownloadFailure) -> String {
        switch failure {
        case .network: l10n["ai.failed.network"]
        case .checksum: l10n["ai.failed.checksum"]
        case .appGroupMissing: l10n["ai.failed.appGroup"]
        case let .notEnoughSpace(needed): l10n("ai.failed.space", l10n.byteText(needed))
        }
    }
}

extension OfflineAIView {
    func testName(_ kind: ModelService.TestStep.Kind) -> String {
        switch kind {
        case .load: l10n["ai.test.load"]
        case .plainReply: l10n["ai.test.plain"]
        case .speed: l10n["ai.test.speed"]
        case .jsonReply: l10n["ai.test.json"]
        }
    }

    func testDetail(_ step: ModelService.TestStep) -> String {
        let time = String(format: "%.1f s", step.seconds)
        guard step.ok else { return time + " · " + step.detail }
        switch step.kind {
        case .load: return time + " · " + step.detail
        case .speed: return time + " · " + l10n("ai.test.wordsPerSecond", step.detail)
        default: return time
        }
    }
}

/// The shared step-by-step setup guide, with ConciergeClock's details.
struct ConciergeClockSetupGuide: View {
    @Environment(AppModel.self) private var model
    @Environment(\.l10n) private var l10n

    var body: some View {
        OfflineAISetupGuide(
            app: .init(
                appName: "ConciergeClock",
                openSettings: l10n["guide.app.openSettings"],
                checkItWorks: l10n("guide.app.check", model.models.capability.recommendedModel?.displayName ?? "Gemma")
            ),
            downloader: model.models.downloader,
            capability: model.models.capability,
            languageCode: model.settings.settings.languageCode
        )
    }
}

/// The first thing in Settings: until offline AI is set up, a highlighted "Important: start
/// here" card; while downloading, its progress; once ready, one quiet line.
struct OfflineAIStartHere: View {
    @Environment(AppModel.self) private var model
    @Environment(\.l10n) private var l10n
    @State private var showingGuide = false

    var body: some View {
        let models = model.models
        if let spec = models.capability.recommendedModel {
            let state = models.downloader.state(models.chosenSpec ?? spec)
            Section {
                switch state {
                case .installed:
                    NavigationLink {
                        OfflineAIView()
                    } label: {
                        Label(l10n("settings.startHere.ready", (models.chosenSpec ?? spec).displayName), systemImage: "checkmark.seal.fill")
                            .foregroundStyle(ConciergeStyle.tint)
                    }
                case let .downloading(progress, _):
                    NavigationLink {
                        OfflineAIView()
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(l10n("settings.startHere.downloading", spec.displayName, Int(progress * 100)))
                                .font(.subheadline.weight(.semibold))
                            ProgressView(value: progress)
                        }
                    }
                default:
                    VStack(alignment: .leading, spacing: 10) {
                        Label(l10n["settings.startHere"], systemImage: "exclamationmark.circle.fill")
                            .font(.caption.weight(.bold))
                            .textCase(.uppercase)
                            .foregroundStyle(.orange)
                        Text(l10n["guide.title"])
                            .font(.title3.weight(.bold))
                            .foregroundStyle(Theme.textPrimary)
                        Text(l10n("settings.startHere.body", spec.displayName, l10n.byteText(spec.sizeBytes)))
                            .font(.subheadline)
                            .foregroundStyle(Theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Button {
                            showingGuide = true
                        } label: {
                            Label(l10n["guide.app.open"], systemImage: "list.number")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                        NavigationLink {
                            OfflineAIView()
                        } label: {
                            Text(l10n["settings.startHere.open"]).font(.subheadline.weight(.semibold))
                        }
                    }
                    .padding(.vertical, 6)
                    .listRowBackground(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.orange.opacity(0.10))
                            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.orange.opacity(0.6), lineWidth: 1.5))
                    )
                }
            }
            .sheet(isPresented: $showingGuide) { ConciergeClockSetupGuide() }
        }
    }
}
