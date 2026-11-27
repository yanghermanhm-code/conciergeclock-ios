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
                    DatePicker(l10n["editor.time"], selection: timeBinding, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                        .frame(maxWidth: .infinity)
                    TextField(l10n["editor.label"], text: $alarm.label)
                        .accessibilityIdentifier("editor.label")
                }

                Section {
                    WeekdayPicker(days: $alarm.repeatDays)
                } header: {
                    Text(l10n["editor.repeat"])
                } footer: {
                    Text(alarm.repeatDays.isEmpty ? l10n["editor.repeatOnce"] : l10n.repeatText(alarm.repeatDays))
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
