import ConciergeCore
import GGSBrand
import SwiftUI

/// Add or edit an alarm: time, label, repeat days, snooze, days off and the butler's voice for
/// this alarm.
struct AlarmEditorView: View {
    @State private var alarm: Alarm
    let isNew: Bool

    @Environment(AppModel.self) private var model
    @Environment(\.l10n) private var l10n
    @Environment(\.dismiss) private var dismiss
    @State private var confirmingDelete = false

    init(alarm: Alarm, isNew: Bool) {
        _alarm = State(initialValue: alarm)
        self.isNew = isNew
    }

    var body: some View {
        let settings = model.settings.settings
        NavigationStack {
            Form {
                Section {
                    // Repeating alarms: just the time. Dated alarms set date and time together below.
                    if scheduleKind == .repeating {
                        DatePicker(l10n["editor.time"], selection: timeBinding, displayedComponents: .hourAndMinute)
                            .datePickerStyle(.wheel)
                            .labelsHidden()
                            .frame(maxWidth: .infinity)
                    }
                    TextField(l10n["editor.label"], text: $alarm.label)
                        .accessibilityIdentifier("editor.label")
                }

                Section {
                    Picker(l10n["editor.when"], selection: scheduleBinding) {
                        Text(l10n["editor.when.repeat"]).tag(ScheduleKind.repeating)
                        Text(l10n["editor.when.date"]).tag(ScheduleKind.date)
                    }
                    .pickerStyle(.segmented)
                    switch scheduleKind {
                    case .repeating:
                        WeekdayPicker(days: repeatBinding)
                    case .date:
                        // Today and the current minute are allowed: an alarm set for "now" rings at once.
                        DatePicker(
                            l10n["editor.date"], selection: dateTimeBinding,
                            in: Self.startOfCurrentMinute()..., displayedComponents: [.date, .hourAndMinute]
                        )
                        .datePickerStyle(.graphical)
                    }
                } header: {
                    Text(l10n["editor.repeat"])
                } footer: {
                    Text(footerText)
                }

                Section {
                    Picker(l10n["snooze.title"], selection: snoozeBinding) {
                        Text(l10n("editor.default", l10n.minutesText(settings.defaultSnoozeMinutes))).tag(Int?.none)
                        ForEach(Snooze.presets, id: \.self) { minutes in
                            Text(l10n.minutesText(minutes)).tag(Int?.some(minutes))
                        }
                    }
                    Toggle(l10n["editor.skipDaysOff"], isOn: $alarm.skipOnDaysOff)
                } footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        if alarm.skipOnDaysOff, model.calendars.eventAccess != .granted {
                            Text(l10n["editor.skipDaysOffNeedsCalendar"]).foregroundStyle(.orange)
                        }
                        Text(l10n["editor.snoozeFooter"])
                    }
                }

                Section {
                    Picker(l10n["butler.tone"], selection: $alarm.toneOverride) {
                        Text(l10n("editor.default", l10n.toneName(settings.tone))).tag(PersonaTone?.none)
                        ForEach(PersonaTone.allCases) { tone in
                            Text(l10n.toneName(tone)).tag(PersonaTone?.some(tone))
                        }
                    }
                    Picker(l10n["butler.voice"], selection: $alarm.accentOverride) {
                        Text(l10n("editor.default", l10n.accentName(settings.voiceAccent))).tag(VoiceAccent?.none)
                        ForEach(VoiceAccent.allCases) { accent in
                            Text(l10n.accentName(accent)).tag(VoiceAccent?.some(accent))
                        }
                    }
                    Picker(l10n["butler.length"], selection: $alarm.lengthOverride) {
                        Text(l10n("editor.default", l10n.lengthName(settings.briefingLength))).tag(BriefingLength?.none)
                        ForEach(BriefingLength.allCases) { length in
                            Text(l10n.lengthName(length)).tag(BriefingLength?.some(length))
                        }
                    }
                } header: {
                    Text(l10n["editor.butler"])
                } footer: {
                    Text(l10n["editor.butlerFooter"])
                }

                if !isNew {
                    Section {
                        Button(l10n["editor.delete"], role: .destructive) { confirmingDelete = true }
                    }
                }
            }
            .navigationTitle(isNew ? l10n["editor.newTitle"] : l10n["editor.editTitle"])
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(l10n["common.cancel"]) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(l10n["common.save"]) {
                        var saved = alarm
                        saved.label = String(saved.label.trimmingCharacters(in: .whitespacesAndNewlines).prefix(60))
                        saved.isEnabled = true
                        model.save(saved)
                        dismiss()
                    }
                    .accessibilityIdentifier("editor.save")
                }
            }
            .confirmationDialog(l10n["editor.deleteConfirm"], isPresented: $confirmingDelete, titleVisibility: .visible) {
                Button(l10n["editor.delete"], role: .destructive) {
                    model.delete(alarm)
                    dismiss()
                }
            }
        }
        .tint(ConciergeStyle.tint)
    }

    private var timeBinding: Binding<Date> {
        Binding(
            get: { Calendar.current.date(bySettingHour: alarm.hour, minute: alarm.minute, second: 0, of: Date()) ?? Date() },
            set: { date in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
                alarm.hour = parts.hour ?? alarm.hour
                alarm.minute = parts.minute ?? alarm.minute
                alarm.skipDay = nil
            }
        )
    }

    private enum ScheduleKind: Hashable {
        case repeating, date
    }

    private var scheduleKind: ScheduleKind {
        alarm.repeatDays.isEmpty && alarm.date != nil ? .date : .repeating
    }

    /// Switching to "On a date" picks the next day this time comes round; switching back
    /// clears the date (no repeat days = the next occurrence of the time).
    private var scheduleBinding: Binding<ScheduleKind> {
        Binding(
            get: { scheduleKind },
            set: { kind in
                switch kind {
                case .date:
                    alarm.repeatDays = []
                    // The next time the chosen time comes round (today if it is still ahead,
                    // including the current minute).
                    let now = Date()
                    let today = Calendar.current.date(bySettingHour: alarm.hour, minute: alarm.minute, second: 0, of: now) ?? now
                    let next = today >= Self.startOfCurrentMinute(now) ? today : (Calendar.current.date(byAdding: .day, value: 1, to: today) ?? today)
                    alarm.date = DayKey(next)
                case .repeating:
                    alarm.date = nil
                }
                alarm.skipDay = nil
            }
        )
    }

    private var repeatBinding: Binding<Set<Weekday>> {
        Binding(
            get: { alarm.repeatDays },
            set: { days in
                alarm.repeatDays = days
                if !days.isEmpty { alarm.date = nil }
            }
        )
    }

    /// The dated alarm's day and time as one value.
    private var dateTimeBinding: Binding<Date> {
        Binding(
            get: {
                let day = alarm.date?.date() ?? Date()
                return Calendar.current.date(bySettingHour: alarm.hour, minute: alarm.minute, second: 0, of: day) ?? day
            },
            set: { value in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: value)
                alarm.date = DayKey(value)
                alarm.hour = parts.hour ?? alarm.hour
                alarm.minute = parts.minute ?? alarm.minute
                alarm.skipDay = nil
            }
        )
    }

    static func startOfCurrentMinute(_ now: Date = Date()) -> Date {
        Calendar.current.dateInterval(of: .minute, for: now)?.start ?? now
    }

    /// "Mon Wed Fri", "Rings once…", or "Friday 12 December 2026 at 7:00 — in 14 days".
    private var footerText: String {
        if scheduleKind == .date, let fire = alarm.nextFireDate(after: Date()) {
            return l10n("editor.dateFooter", fire.formatted(Date.FormatStyle(date: .complete, time: .shortened).locale(l10n.locale)))
        }
        if scheduleKind == .date {
            return l10n["editor.datePast"]
        }
        return alarm.repeatDays.isEmpty ? l10n["editor.repeatOnce"] : l10n.repeatText(alarm.repeatDays)
    }

    private var snoozeBinding: Binding<Int?> {
        Binding(get: { alarm.snoozeMinutes }, set: { alarm.snoozeMinutes = $0 })
    }
}

/// Seven round day buttons (in the week order of the user's locale).
private struct WeekdayPicker: View {
    @Binding var days: Set<Weekday>
    @Environment(\.l10n) private var l10n

    var body: some View {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = l10n.locale
        let symbols = calendar.veryShortWeekdaySymbols
        let names = calendar.weekdaySymbols
        let first = Locale.current.calendar.firstWeekday
        let order = (0..<7).map { (first - 1 + $0) % 7 + 1 }
        return HStack(spacing: 6) {
            ForEach(order, id: \.self) { day in
                let on = days.contains(day)
                Button {
                    if on { days.remove(day) } else { days.insert(day) }
                } label: {
                    Text(symbols[day - 1])
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 38)
                        .background(on ? ConciergeStyle.tint : Theme.surfaceMuted, in: Circle())
                        .foregroundStyle(on ? Color.white : Theme.textPrimary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(names[day - 1])
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .padding(.vertical, 4)
    }
}
