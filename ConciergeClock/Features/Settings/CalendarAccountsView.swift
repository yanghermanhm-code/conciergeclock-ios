import ConciergeCore
import GGSBrand
import SwiftUI

/// Settings › Calendars & Reminders: permission, every account on the iPhone (iCloud, Google,
/// Outlook / Exchange / Microsoft 365, Yahoo, on this iPhone, subscribed) with its calendars and
/// reminder lists, which of them Concierge Clock reads, and how to add Google or Outlook.
struct CalendarAccountsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.l10n) private var l10n

    var body: some View {
        let calendars = model.calendars
        let settings = model.settings.settings
        Form {
            Section {
                accessRow(
                    title: l10n["calendars.calendars"], systemImage: "calendar", access: calendars.eventAccess,
                    allow: { Task { await calendars.requestCalendarAccess() } }
                )
                accessRow(
                    title: l10n["calendars.reminders"], systemImage: "checklist", access: calendars.reminderAccess,
                    allow: { Task { await calendars.requestReminderAccess() } }
                )
                if calendars.eventAccess == .granted, let count = calendars.eventCountToday(excluding: Set(settings.excludedCalendarIDs)) {
                    LabeledContent(l10n["calendars.todayCount"], value: l10n.number(count))
                }
            } footer: {
                Text(l10n["calendars.privacy"])
            }

            Section {
                NavigationLink {
                    AddCalendarAccountGuide()
                } label: {
                    Label(l10n["calendars.addAccount"], systemImage: "person.crop.circle.badge.plus")
                }
            } footer: {
                Text(l10n["calendars.addAccountFooter"])
            }

            ForEach(calendars.calendarAccounts) { account in
                Section {
                    ForEach(account.calendars) { calendar in
                        Toggle(isOn: includeBinding(calendar.id, keyPath: \.excludedCalendarIDs)) {
                            Label {
                                Text(calendar.title)
                            } icon: {
                                Circle().fill(calendar.color).frame(width: 12, height: 12)
                            }
                        }
                    }
                } header: {
                    accountHeader(account)
                }
            }

            if !calendars.reminderAccounts.isEmpty {
                ForEach(calendars.reminderAccounts) { account in
                    Section {
                        ForEach(account.calendars) { list in
                            Toggle(isOn: includeBinding(list.id, keyPath: \.excludedReminderListIDs)) {
                                Label {
                                    Text(list.title)
                                } icon: {
                                    Image(systemName: "list.bullet.circle.fill").foregroundStyle(list.color)
                                }
                            }
                        }
                    } header: {
                        HStack(spacing: 6) {
                            Image(systemName: "checklist")
                            accountHeader(account)
                        }
                    }
                }
            }
        }
        .navigationTitle(l10n["calendars.title"])
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { calendars.refresh() }
    }

    @ViewBuilder
    private func accessRow(title: String, systemImage: String, access: CalendarService.Access, allow: @escaping () -> Void) -> some View {
        HStack {
            Label(title, systemImage: systemImage)
            Spacer()
            switch access {
            case .granted:
                Text(l10n["calendars.allowed"]).foregroundStyle(ConciergeStyle.tint)
            case .notDetermined:
                Button(l10n["calendars.allow"], action: allow)
                    .buttonStyle(.borderedProminent)
            case .denied:
                Button(l10n["calendars.openSettings"]) {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private func accountHeader(_ account: CalendarAccount) -> some View {
        Label {
            Text(verbatim: [kindName(account.kind), account.title.nonBlank].compactMap { $0 }.uniqued().joined(separator: " · "))
        } icon: {
            Image(systemName: account.kind.systemImage)
        }
    }

    private func kindName(_ kind: AccountKind) -> String {
        switch kind {
        case .iCloud: "iCloud"
        case .google: "Google"
        case .outlook: "Outlook / Exchange"
        case .yahoo: "Yahoo"
        case .otherOnline: l10n["calendars.kind.other"]
        case .onMyPhone: l10n["calendars.kind.iphone"]
        case .subscribed: l10n["calendars.kind.subscribed"]
        case .birthdays: l10n["calendars.kind.birthdays"]
        }
    }

    /// On = read by Concierge Clock (stored as the list of calendars left out).
    private func includeBinding(_ id: String, keyPath: WritableKeyPath<AppSettings, [String]>) -> Binding<Bool> {
        Binding(
            get: { !model.settings.settings[keyPath: keyPath].contains(id) },
            set: { included in
                var excluded = model.settings.settings[keyPath: keyPath]
                excluded.removeAll { $0 == id }
                if !included { excluded.append(id) }
                model.settings.settings[keyPath: keyPath] = excluded
            }
        )
    }
}

private extension Array where Element == String {
    /// The strings without case-insensitive repeats ("Outlook / Exchange · Outlook" stays, "iCloud · iCloud" does not).
    func uniqued() -> [String] {
        var seen: Set<String> = []
        return filter { seen.insert($0.lowercased()).inserted }
    }
}

/// How to add a Google, Outlook.com, Exchange / Microsoft 365 or Yahoo account to the iPhone,
/// so its calendars and reminders appear in Concierge Clock. Nothing is signed into inside the
/// app: the iPhone keeps the account and syncs it; Concierge Clock reads it offline.
struct AddCalendarAccountGuide: View {
    @Environment(\.l10n) private var l10n

    var body: some View {
        List {
            Section {
                Text(l10n["calendars.guide.intro"])
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
            }
            Section(l10n["calendars.guide.stepsTitle"]) {
                step(1, l10n["calendars.guide.step1"])
                step(2, l10n["calendars.guide.step2"])
                step(3, l10n["calendars.guide.step3"])
                step(4, l10n["calendars.guide.step4"])
                step(5, l10n["calendars.guide.step5"])
            }
            Section(l10n["calendars.guide.which"]) {
                provider("g.circle", "Google", l10n["calendars.guide.google"])
                provider("envelope.circle", "Outlook.com / Hotmail", l10n["calendars.guide.outlook"])
                provider("building.2", "Microsoft 365 / Exchange", l10n["calendars.guide.exchange"])
                provider("icloud", "iCloud", l10n["calendars.guide.icloud"])
            }
            Section {
                Label(l10n["calendars.guide.outlookApp"], systemImage: "info.circle")
                    .font(.footnote)
                Label(l10n["calendars.guide.googleTasks"], systemImage: "info.circle")
                    .font(.footnote)
            }
        }
        .navigationTitle(l10n["calendars.addAccount"])
        .navigationBarTitleDisplayMode(.inline)
    }

    private func step(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(l10n.number(number))
                .font(.headline.monospacedDigit())
                .frame(width: 26, height: 26)
                .background(ConciergeStyle.tint.opacity(0.15), in: Circle())
                .foregroundStyle(ConciergeStyle.tint)
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    private func provider(_ icon: String, _ name: String, _ detail: String) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: name).font(.subheadline.weight(.semibold))
                Text(detail).font(.caption).foregroundStyle(Theme.textSecondary)
            }
        } icon: {
            Image(systemName: icon).foregroundStyle(ConciergeStyle.brass)
        }
    }
}
