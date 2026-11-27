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
