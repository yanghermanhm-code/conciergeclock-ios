import ConciergeCore
import GGSBrand
import SwiftUI

/// Settings › Your concierge: the butler's names, voice, tone, briefing length and language.
/// Voice preview and the voice download guide arrive with the spoken briefing (Phase 2); the
/// bundled offline voices with Phase 7.
struct ButlerSettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.l10n) private var l10n
    @State private var pendingUnhinged = false

    var body: some View {
        @Bindable var store = model.settings
        let settings = store.settings
        Form {
            Section {
                TextField(l10n["butler.formalName"], text: nameBinding(\.formal))
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("butler.formalName")
                TextField(l10n["butler.familiarName"], text: nameBinding(\.familiar))
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("butler.familiarName")
            } header: {
                Text(l10n["butler.names"])
            } footer: {
                Text(l10n["butler.namesFooter"])
            }

            Section {
                Picker(l10n["butler.voice"], selection: $store.settings.voiceAccent) {
                    ForEach(VoiceAccent.allCases) { accent in
                        Text(l10n.accentName(accent)).tag(accent)
                    }
                }
                VoiceStatusRow(persona: settings.persona())
                Button {
                    model.previewVoice(settings.persona())
                } label: {
                    Label(l10n["butler.previewVoice"], systemImage: "play.circle")
                }
                .accessibilityIdentifier("butler.previewVoice")
                NavigationLink {
                    AllVoicesView()
                } label: {
                    Label(l10n["voices.title"], systemImage: "person.wave.2")
                }
                NavigationLink {
                    VoiceDownloadGuide()
                } label: {
                    Label(l10n["voices.guide.title"], systemImage: "arrow.down.circle")
                }
            } header: {
                Text(l10n["butler.voiceHeader"])
            } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    if settings.voiceAccent.isApproximated {
                        Text(l10n["butler.voiceApproximated"])
                    }
                    if settings.briefingLanguageCode != "en" {
                        Text(l10n["butler.voiceEnglishOnly"])
                    }
                    Text(l10n["butler.voiceFooter"])
                }
            }

            Section {
                Picker(l10n["butler.tone"], selection: toneBinding) {
                    ForEach(PersonaTone.allCases) { tone in
                        Text(l10n.toneName(tone)).tag(tone)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
                if settings.tone == .unhinged {
                    Toggle(l10n["butler.mildSwearing"], isOn: $store.settings.allowMildSwearing)
                }
            } header: {
                Text(l10n["butler.tone"])
            } footer: {
                VStack(alignment: .leading, spacing: 6) {
                    Text(l10n.toneHint(settings.tone))
                    Text(l10n.toneSample(settings.tone, name: settings.persona().displayName))
                        .italic()
                }
            }

            Section {
                Picker(l10n["butler.length"], selection: $store.settings.briefingLength) {
                    ForEach(BriefingLength.allCases) { length in
                        Text(l10n.lengthName(length)).tag(length)
                    }
                }
                .pickerStyle(.segmented)
                Picker(l10n["butler.language"], selection: $store.settings.briefingLanguageCode) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(verbatim: language.nativeName).tag(language.rawValue)
                    }
                }
                Toggle(l10n["butler.speakTitles"], isOn: $store.settings.speakEventTitles)
                Button {
                    model.briefMeNow()
                } label: {
                    Label(model.speech.state == .speaking ? l10n["concierge.stop"] : l10n["butler.previewBriefing"],
                          systemImage: model.speech.state == .speaking ? "stop.fill" : "text.bubble")
                }
                .accessibilityIdentifier("butler.previewBriefing")
            } header: {
                Text(l10n["butler.briefing"])
            } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(l10n.lengthHint(settings.briefingLength))
                    Text(settings.speakEventTitles ? l10n["butler.speakTitlesOn"] : l10n["butler.speakTitlesOff"])
                }
            }
        }
        .navigationTitle(l10n["butler.title"])
        .onDisappear { model.speech.stop() }
        .navigationBarTitleDisplayMode(.inline)
        .alert(l10n["unhinged.title"], isPresented: $pendingUnhinged) {
            Button(l10n["common.cancel"], role: .cancel) {}
            Button(l10n["unhinged.confirm"]) {
                model.settings.settings.unhingedAcknowledged = true
                model.settings.settings.tone = .unhinged
            }
        } message: {
            Text(l10n["unhinged.message"])
        }
    }

    /// Choosing Unhinged for the first time shows the notice before it takes effect.
    private var toneBinding: Binding<PersonaTone> {
        Binding(
            get: { model.settings.settings.tone },
            set: { tone in
                if tone == .unhinged, !model.settings.settings.unhingedAcknowledged {
                    pendingUnhinged = true
                } else {
                    model.settings.settings.tone = tone
                }
            }
        )
    }

    /// Edits one of the butler's names, limited to `ButlerName.maxLength` characters.
    private func nameBinding(_ keyPath: WritableKeyPath<ButlerName, String>) -> Binding<String> {
        Binding(
            get: { model.settings.settings.butlerName[keyPath: keyPath] },
            set: { value in
                model.settings.settings.butlerName[keyPath: keyPath] = String(value.prefix(ButlerName.maxLength))
            }
        )
    }
}

/// The iPhone voice that will speak, its quality, and whether a better one can be downloaded.
private struct VoiceStatusRow: View {
    let persona: Persona
    @Environment(\.l10n) private var l10n

    var body: some View {
        let summary = VoiceCatalog.summary(for: persona)
        VStack(alignment: .leading, spacing: 4) {
            if let name = summary.name {
                LabeledContent(l10n["voices.current"], value: "\(name) · \(qualityName(summary.quality))")
            } else {
                Label(l10n["voices.none"], systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
            }
            if summary.name != nil, summary.canImprove {
                Text(l10n["voices.canImprove"])
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
    }

    private func qualityName(_ quality: VoiceCatalog.Quality?) -> String {
        switch quality {
        case .premium: l10n["voices.quality.premium"]
        case .enhanced: l10n["voices.quality.enhanced"]
        default: l10n["voices.quality.standard"]
        }
    }
}

/// Every accent and tone, each with a Preview button, in the briefing language.
struct AllVoicesView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.l10n) private var l10n

    var body: some View {
        let base = model.settings.settings.persona()
        List {
            if base.usesAccent {
                Section(l10n["butler.voice"]) {
                    ForEach(VoiceAccent.allCases) { accent in
                        previewRow(
                            title: l10n.accentName(accent),
                            detail: VoiceCatalog.summary(for: base.with(accent: accent)).name ?? l10n["voices.none"],
                            persona: base.with(accent: accent)
                        )
                    }
                }
            } else {
                Section {
                    Text(l10n["butler.voiceEnglishOnly"])
                        .font(.footnote)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            Section(l10n["butler.tone"]) {
                ForEach(PersonaTone.allCases) { tone in
                    previewRow(title: l10n.toneName(tone), detail: l10n.toneHint(tone), persona: base.with(tone: tone))
                }
            }
        }
        .navigationTitle(l10n["voices.title"])
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { model.speech.stop() }
    }

    private func previewRow(title: String, detail: String, persona: Persona) -> some View {
        Button {
            model.previewVoice(persona)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).foregroundStyle(Theme.textPrimary)
                    Text(detail).font(.caption).foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                Image(systemName: "play.circle.fill")
                    .font(.title2)
                    .foregroundStyle(ConciergeStyle.tint)
            }
        }
        .accessibilityHint(l10n["butler.previewVoice"])
    }
}

/// How to download better (Enhanced / Premium) voices in iOS Settings. They are free, made by
/// Apple, and once downloaded work offline in every app.
struct VoiceDownloadGuide: View {
    @Environment(\.l10n) private var l10n

    var body: some View {
        List {
            Section {
                Text(l10n["voices.guide.intro"])
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
            }
            Section(l10n["calendars.guide.stepsTitle"]) {
                ForEach(1...5, id: \.self) { number in
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text(l10n.number(number))
                            .font(.headline.monospacedDigit())
                            .frame(width: 26, height: 26)
                            .background(ConciergeStyle.tint.opacity(0.15), in: Circle())
                            .foregroundStyle(ConciergeStyle.tint)
                        Text(l10n["voices.guide.step\(number)"])
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            Section(l10n["voices.guide.suggestions"]) {
                Text(l10n["voices.guide.british"])
                Text(l10n["voices.guide.indian"])
                Text(l10n["voices.guide.american"])
            }
            Section {
                Button(l10n["alarms.permission.openSettings"]) {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
            } footer: {
                Text(l10n["voices.guide.footer"])
            }
        }
        .navigationTitle(l10n["voices.guide.title"])
        .navigationBarTitleDisplayMode(.inline)
    }
}

private extension Persona {
    func with(accent: VoiceAccent) -> Persona {
        var copy = self
        copy.accent = accent
        return copy
    }

    func with(tone: PersonaTone) -> Persona {
        var copy = self
        copy.tone = tone
        return copy
    }
}
