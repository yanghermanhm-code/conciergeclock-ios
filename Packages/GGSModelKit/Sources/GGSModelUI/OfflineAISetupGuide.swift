#if os(iOS)
import GGSModelCore
import SwiftUI

/// "Set up offline AI": a screen-by-screen guide, shared by every Greater Good Software app,
/// to download and turn on the Gemma model recommended for this iPhone. Each page shows a
/// drawing of the screen with the control to tap highlighted. The pages adapt to the iPhone:
/// recommended model, download size, free space, and the download's live progress.
///
/// Each app supplies its own name, where its Settings are, and how to check the model works.
public struct OfflineAISetupGuide: View {
    public struct AppDetails: Sendable {
        /// "PrepPilot"
        public var appName: String
        /// How to open the app's settings, in the app's language ("Tap the gear at the top right.").
        public var openSettings: String
        /// How to see the model at work, in the app's language (nil to skip that page).
        public var checkItWorks: String?

        public init(appName: String, openSettings: String, checkItWorks: String?) {
            self.appName = appName
            self.openSettings = openSettings
            self.checkItWorks = checkItWorks
        }
    }

    let app: AppDetails
    let downloader: ModelDownloader
    let capability: DeviceCapability
    let strings: GuideStrings
    @Environment(\.dismiss) private var dismiss
    @State private var page = 0

    /// - Parameter languageCode: the app's language setting (nil = the iPhone's language).
    public init(app: AppDetails, downloader: ModelDownloader, capability: DeviceCapability = .current, languageCode: String? = nil) {
        self.app = app
        self.downloader = downloader
        self.capability = capability
        self.strings = GuideStrings(languageCode: languageCode)
    }

    var spec: ModelSpec? { capability.recommendedModel }

    enum Step: Hashable {
        case intro, openSettings, offlineAI, model, wifiAndSpace, download, ready, turnOn, check
    }

    var steps: [Step] {
        guard spec != nil else { return [.intro] }
        return [.intro, .openSettings, .offlineAI, .model, .wifiAndSpace, .download, .ready, .turnOn] + (app.checkItWorks == nil ? [] : [.check])
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TabView(selection: $page) {
                    ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                        ScrollView {
                            StepPage(step: step, number: index, total: steps.count - 1, guide: self)
                                .padding(20)
                        }
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))

                HStack {
                    if page > 0 {
                        Button(strings["guide.back"]) { withAnimation { page -= 1 } }
                            .buttonStyle(.bordered)
                    }
                    Spacer()
                    if page < steps.count - 1 {
                        Button(strings["guide.next"]) { withAnimation { page += 1 } }
                            .buttonStyle(.borderedProminent)
                    } else {
                        Button(strings["guide.done"]) { dismiss() }
                            .buttonStyle(.borderedProminent)
                    }
                }
                .padding(16)
            }
            .navigationTitle(strings["guide.title"])
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(strings["guide.close"]) { dismiss() }
                }
            }
        }
    }
}

// MARK: - Pages

private struct StepPage: View {
    let step: OfflineAISetupGuide.Step
    let number: Int
    let total: Int
    let guide: OfflineAISetupGuide

    private var strings: GuideStrings { guide.strings }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if number > 0 {
                Text(strings("guide.step", number, total))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
            }
            Text(title).font(.title2.weight(.bold))
                .accessibilityAddTraits(.isHeader)
            illustration
                .frame(maxWidth: .infinity)
                .accessibilityHidden(true)
            Text(detail)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
            status
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var spec: ModelSpec? { guide.spec }
    private var modelName: String { spec?.displayName ?? "Gemma" }
    private var size: String { ByteCountFormatter.string(fromByteCount: spec?.sizeBytes ?? 0, countStyle: .file) }
    private var memory: String { String(format: "%.0f GB", guide.capability.memoryGB.rounded()) }

    private var title: String {
        switch step {
        case .intro: strings["guide.intro.title"]
        case .openSettings: strings("guide.open.title", guide.app.appName)
        case .offlineAI: strings["guide.find.title"]
        case .model: strings["guide.model.title"]
        case .wifiAndSpace: strings["guide.space.title"]
        case .download: strings["guide.download.title"]
        case .ready: strings["guide.ready.title"]
        case .turnOn: strings["guide.turnOn.title"]
        case .check: strings["guide.verify.title"]
        }
    }

    private var detail: String {
        switch step {
        case .intro:
            guard spec != nil else { return strings("guide.intro.unsupported", memory) }
            return strings("guide.intro.body", memory, modelName, size) + "\n\n" + strings["guide.intro.shared"]
        case .openSettings: return guide.app.openSettings
        case .offlineAI: return strings["guide.find.body"]
        case .model:
            var text = strings("guide.model.body", modelName)
            if let spec, spec == ModelCatalog.gemma4E2B, guide.capability.memoryGB < ModelCatalog.gemma4E4B.minimumMemoryGB {
                text += "\n\n" + strings["guide.model.e4bNote"]
            }
            return text
        case .wifiAndSpace: return strings("guide.space.body", ByteCountFormatter.string(fromByteCount: (spec?.sizeBytes ?? 0) * 2, countStyle: .file))
        case .download: return strings["guide.download.body"]
        case .ready: return strings["guide.ready.body"]
        case .turnOn: return strings["guide.turnOn.body"]
        case .check: return guide.app.checkItWorks ?? ""
        }
    }

    /// Live facts about this iPhone on the pages where they matter.
    @ViewBuilder
    private var status: some View {
        if let spec {
            switch step {
            case .intro, .download, .ready:
                switch guide.downloader.state(spec) {
                case .installed: StatusLine(text: strings["guide.status.ready"], symbol: "checkmark.circle.fill", color: .green)
                case let .downloading(progress, _): StatusLine(text: strings("guide.status.downloading", Int(progress * 100)), symbol: "arrow.down.circle", color: .blue)
                default: EmptyView()
                }
            case .wifiAndSpace:
                let free = SharedModelStore.freeBytes()
                let enough = free >= spec.sizeBytes * 2
                StatusLine(
                    text: strings(enough ? "guide.space.ok" : "guide.space.low", ByteCountFormatter.string(fromByteCount: free, countStyle: .file)),
                    symbol: enough ? "checkmark.circle.fill" : "exclamationmark.triangle.fill", color: enough ? .green : .orange
                )
            default:
                EmptyView()
            }
        }
    }

    // MARK: Drawings of each screen

    @ViewBuilder
    private var illustration: some View {
        switch step {
        case .intro:
            Image(systemName: spec == nil ? "iphone.slash" : "cpu")
                .font(.system(size: 64))
                .foregroundStyle(.tint)
                .padding(.vertical, 12)
        case .openSettings:
            MockScreen(title: guide.app.appName, trailingIcon: "gearshape", highlightTrailing: true) {
                MockRow(text: "· · ·", detail: nil)
                MockRow(text: "· · ·", detail: nil)
            }
        case .offlineAI:
            MockScreen(title: strings["guide.mock.settings"]) {
                MockRow(text: "· · ·", detail: nil)
                MockRow(text: strings["guide.mock.offlineAI"], detail: "›", highlighted: true)
                MockRow(text: "· · ·", detail: nil)
            }
        case .model:
            MockScreen(title: strings["guide.mock.offlineAI"]) {
                MockModelRow(name: modelName, size: size, badge: strings["guide.mock.recommended"], button: strings["guide.mock.download"], highlighted: true)
                if let other = ModelCatalog.all.first(where: { $0 != spec }) {
                    MockModelRow(name: other.displayName, size: ByteCountFormatter.string(fromByteCount: other.sizeBytes, countStyle: .file), badge: nil, button: strings["guide.mock.download"], highlighted: false)
                }
            }
        case .wifiAndSpace:
            MockScreen(title: strings["guide.mock.offlineAI"]) {
                MockToggleRow(text: strings["guide.mock.wifi"], isOn: true, highlighted: true)
                MockRow(text: "· · ·", detail: nil)
            }
        case .download:
            MockScreen(title: strings["guide.mock.offlineAI"]) {
                MockModelRow(name: modelName, size: size, badge: strings["guide.mock.recommended"], button: strings["guide.mock.download"], highlighted: true)
                MockProgress(progress: 0.4)
            }
        case .ready:
            MockScreen(title: strings["guide.mock.offlineAI"]) {
                HStack {
                    Text(modelName).font(.caption.weight(.semibold))
                    Spacer()
                    Label(strings["guide.mock.ready"], systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                        .padding(4)
                        .overlay(Highlight())
                }
            }
        case .turnOn:
            MockScreen(title: strings["guide.mock.offlineAI"]) {
                MockToggleRow(text: strings["guide.mock.useAI"], isOn: true, highlighted: true)
                MockRow(text: "· · ·", detail: nil)
            }
        case .check:
            Image(systemName: "sparkles")
                .font(.system(size: 56))
                .foregroundStyle(.tint)
                .padding(.vertical, 12)
        }
    }
}

// MARK: - Mock-up pieces

/// A small drawing of an app screen: a title bar and rows.
private struct MockScreen<Content: View>: View {
    let title: String
    var trailingIcon: String?
    var highlightTrailing = false
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(title).font(.caption.weight(.bold))
                Spacer()
                if let trailingIcon {
                    Image(systemName: trailingIcon)
                        .font(.body)
                        .padding(6)
                        .overlay { if highlightTrailing { Highlight() } }
                }
            }
            content
        }
        .padding(12)
        .frame(maxWidth: 300)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(.quaternary, lineWidth: 1))
    }
}

private struct MockRow: View {
    let text: String
    let detail: String?
    var highlighted = false

    var body: some View {
        HStack {
            Text(text).font(.caption)
            Spacer()
            if let detail { Text(detail).font(.caption).foregroundStyle(.secondary) }
        }
        .padding(8)
        .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay { if highlighted { Highlight() } }
    }
}

private struct MockToggleRow: View {
    let text: String
    let isOn: Bool
    let highlighted: Bool

    var body: some View {
        HStack {
            Text(text).font(.caption)
            Spacer()
            Capsule().fill(isOn ? Color.green : Color.gray.opacity(0.4))
                .frame(width: 34, height: 20)
                .overlay(alignment: isOn ? .trailing : .leading) { Circle().fill(.white).padding(2) }
                .padding(3)
                .overlay { if highlighted { Highlight() } }
        }
        .padding(8)
        .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct MockModelRow: View {
    let name: String
    let size: String
    let badge: String?
    let button: String
    let highlighted: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(name).font(.caption.weight(.semibold))
                if let badge {
                    Text(badge).font(.caption2.weight(.semibold))
                        .padding(.horizontal, 5).padding(.vertical, 1)
                        .background(Color.green.opacity(0.18), in: Capsule())
                        .foregroundStyle(.green)
                }
                Spacer()
                Text(size).font(.caption2).foregroundStyle(.secondary)
            }
            Text(button).font(.caption.weight(.semibold))
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(highlighted ? Color.accentColor : Color.gray.opacity(0.3), in: Capsule())
                .foregroundStyle(.white)
                .padding(3)
                .overlay { if highlighted { Highlight() } }
        }
        .padding(8)
        .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct MockProgress: View {
    let progress: Double

    var body: some View {
        ProgressView(value: progress).padding(.horizontal, 8)
    }
}

/// The ring that marks what to tap.
private struct Highlight: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .strokeBorder(Color.orange, lineWidth: 2.5)
            .overlay(alignment: .bottomTrailing) {
                Image(systemName: "hand.point.up.left.fill")
                    .font(.title3)
                    .foregroundStyle(.orange)
                    .offset(x: 14, y: 16)
            }
    }
}

private struct StatusLine: View {
    let text: String
    let symbol: String
    let color: Color

    var body: some View {
        Label(text, systemImage: symbol)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(color)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

// MARK: - Strings

/// The guide's translations (in this package, so every app shows the same guide), following
/// the app's language setting.
struct GuideStrings {
    let bundle: Bundle
    let locale: Locale

    init(languageCode: String?) {
        if let code = languageCode, let path = Bundle.module.path(forResource: code, ofType: "lproj"), let bundle = Bundle(path: path) {
            self.bundle = bundle
            self.locale = Locale(identifier: code)
        } else {
            self.bundle = .module
            self.locale = .current
        }
    }

    subscript(_ key: String) -> String {
        bundle.localizedString(forKey: key, value: nil, table: nil)
    }

    func callAsFunction(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: self[key], locale: locale, arguments: arguments)
    }
}
#endif
