import ConciergeCore
import GGSBrand
import SwiftUI

/// Settings, opened from the gear in the top bar. Offline AI first (the same "start here" card
/// and setup guide as PrepPilot and FocusFound), then the concierge, snooze and mornings,
/// appearance and language, backups, and About.
struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.l10n) private var l10n
    @Environment(\.dismiss) private var dismiss
    @State private var showingCompany = false

    var body: some View {
        @Bindable var store = model.settings
        let settings = store.settings
        NavigationStack {
            Form {
                OfflineAIStartHere()

                Section {
                    NavigationLink {
                        ButlerSettingsView()
                    } label: {
                        LabeledContent {
                            Text(verbatim: settings.persona().displayName)
                        } label: {
                            Label(l10n["butler.title"], systemImage: "person.crop.circle")
                        }
                    }
                    .accessibilityIdentifier("settings.butler")
                    NavigationLink {
                        SnoozeSettingsView()
                    } label: {
                        LabeledContent {
                            Text(l10n.minutesText(settings.defaultSnoozeMinutes))
                        } label: {
                            Label(l10n["snooze.title"], systemImage: "zzz")
                        }
                    }
                    NavigationLink {
                        MorningSettingsView()
                    } label: {
                        Label(l10n["morning.title"], systemImage: "sunrise")
                    }
                    NavigationLink {
                        CalendarAccountsView()
                    } label: {
                        LabeledContent {
                            Text(model.calendars.eventAccess == .granted
                                 ? l10n("calendars.accountCount", model.calendars.calendarAccounts.count)
                                 : l10n["calendars.notConnected"])
                        } label: {
                            Label(l10n["calendars.title"], systemImage: "calendar")
                        }
                    }
                    .accessibilityIdentifier("settings.calendars")
                } header: {
                    Text(l10n["settings.concierge"])
                }

                Section {
                    NavigationLink {
                        OfflineAIView()
                    } label: {
                        LabeledContent(l10n["ai.title"]) {
                            Text(model.models.isReady ? l10n["ai.ready"] : l10n["ai.notReady"])
                                .foregroundStyle(model.models.isReady ? ConciergeStyle.tint : Theme.textSecondary)
                        }
                    }
                } footer: {
                    Text(l10n["settings.aiFooter"])
                }

                Section(l10n["settings.appearance"]) {
                    Picker(l10n["settings.theme"], selection: $store.settings.theme) {
                        Text(l10n["theme.system"]).tag(ThemePreference.system)
                        Text(l10n["theme.light"]).tag(ThemePreference.light)
                        Text(l10n["theme.dark"]).tag(ThemePreference.dark)
                    }
                    Picker(l10n["settings.appIcon"], selection: $store.settings.appIcon) {
                        Text(l10n["icon.dark"]).tag(AppIconChoice.dark)
                        Text(l10n["icon.light"]).tag(AppIconChoice.light)
                    }
                    Toggle(l10n["settings.haptics"], isOn: $store.settings.hapticsEnabled)
                }

                Section {
                    Picker(l10n["settings.language"], selection: languageBinding) {
                        Text(l10n("language.system", AppLanguage.systemDefault.nativeName)).tag(String?.none)
                        ForEach(AppLanguage.allCases) { language in
                            Text(verbatim: language.nativeName).tag(String?.some(language.rawValue))
                        }
                    }
                } footer: {
                    Text(l10n["settings.languageFooter"])
                }

                Section {
                    NavigationLink {
                        BackupExportView()
                    } label: {
                        Label(l10n["backup.title"], systemImage: "externaldrive")
                    }
                }

                Section {
                    NavigationLink {
                        AboutConciergeClockView()
                    } label: {
                        Label(l10n["settings.aboutApp"], systemImage: "info.circle")
                    }
                    Button {
                        showingCompany = true
                    } label: {
                        Label(l10n["company.title"], systemImage: "building.2")
                    }
                }
            }
            .navigationTitle(l10n["common.settings"])
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(l10n["common.done"]) { dismiss() }
                }
            }
            .sheet(isPresented: $showingCompany) {
                AboutCompanyView()
            }
        }
        .tint(ConciergeStyle.tint)
    }

    private var languageBinding: Binding<String?> {
        Binding(
            get: { model.settings.settings.languageCode },
            set: { model.settings.settings.languageCode = $0 }
        )
    }
}
