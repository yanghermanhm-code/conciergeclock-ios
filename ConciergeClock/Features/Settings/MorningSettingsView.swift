import ConciergeCore
import GGSBrand
import SwiftUI

/// Settings › Snooze: default length (5 minutes), presets and custom lengths, escalation and
/// an optional limit.
struct SnoozeSettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.l10n) private var l10n

    var body: some View {
        @Bindable var store = model.settings
        let settings = store.settings
        Form {
            Section {
                Picker(l10n["snooze.default"], selection: $store.settings.defaultSnoozeMinutes) {
                    ForEach(presetChoices(including: settings.defaultSnoozeMinutes), id: \.self) { minutes in
                        Text(l10n.minutesText(minutes)).tag(minutes)
                    }
                }
                Stepper(value: $store.settings.defaultSnoozeMinutes, in: Snooze.minuteRange) {
                    LabeledContent(l10n["snooze.custom"], value: l10n.minutesText(settings.defaultSnoozeMinutes))
                }
            } footer: {
                Text(l10n["snooze.footer"])
            }

            Section {
                Toggle(l10n["snooze.escalation"], isOn: $store.settings.snoozeEscalation)
                Toggle(l10n["snooze.limitOn"], isOn: limitEnabled)
                if let limit = settings.snoozeLimit {
                    Stepper(value: limitValue, in: 1...20) {
                        LabeledContent(l10n["snooze.limit"], value: l10n.number(limit))
                    }
                }
            } footer: {
                Text(l10n["snooze.escalationFooter"])
            }
        }
        .navigationTitle(l10n["snooze.title"])
        .navigationBarTitleDisplayMode(.inline)
    }

    /// The presets, plus the current value when it is a custom length.
    private func presetChoices(including current: Int) -> [Int] {
        Snooze.presets.contains(current) ? Snooze.presets : (Snooze.presets + [current]).sorted()
    }

    private var limitEnabled: Binding<Bool> {
        Binding(
            get: { model.settings.settings.snoozeLimit != nil },
            set: { model.settings.settings.snoozeLimit = $0 ? 3 : nil }
        )
    }

    private var limitValue: Binding<Int> {
        Binding(
            get: { model.settings.settings.snoozeLimit ?? 3 },
            set: { model.settings.settings.snoozeLimit = $0 }
        )
    }
}

/// Settings › Mornings: the "Are you really up?" check, bedtime preview, sunrise screen,
/// calendar-aware alarm suggestions, days off, Apple Health and the wake score.
struct MorningSettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.l10n) private var l10n
    @State private var newKeyword = ""

    var body: some View {
        @Bindable var store = model.settings
        let settings = store.settings
        Form {
            Section {
                Toggle(l10n["morning.awakeCheck"], isOn: $store.settings.awakeCheckEnabled)
                if settings.awakeCheckEnabled {
                    Stepper(value: $store.settings.awakeCheckDelayMinutes, in: 1...15) {
                        LabeledContent(l10n["morning.awakeCheckDelay"], value: l10n.minutesText(settings.awakeCheckDelayMinutes))
                    }
                }
            } footer: {
                Text(l10n["morning.awakeCheckFooter"])
            }

            Section {
                Toggle(l10n["morning.bedtimePreview"], isOn: $store.settings.bedtimePreviewEnabled)
                Toggle(l10n["morning.sunrise"], isOn: $store.settings.sunriseEnabled)
                if settings.sunriseEnabled {
                    Stepper(value: $store.settings.sunriseMinutes, in: 5...60, step: 5) {
                        LabeledContent(l10n["morning.sunriseMinutes"], value: l10n.minutesText(settings.sunriseMinutes))
                    }
                }
            } header: {
                Text(l10n["morning.nightstand"])
            } footer: {
                Text(l10n["morning.nightstandFooter"])
            }

            Section {
                Toggle(l10n["morning.suggestAlarm"], isOn: $store.settings.suggestAlarmFromCalendar)
                if settings.suggestAlarmFromCalendar {
                    Stepper(value: $store.settings.getReadyMinutes, in: 10...240, step: 5) {
                        LabeledContent(l10n["morning.getReady"], value: l10n.minutesText(settings.getReadyMinutes))
                    }
                }
            } header: {
                Text(l10n["morning.calendar"])
            } footer: {
                Text(l10n["morning.suggestAlarmFooter"])
            }

            Section {
                ForEach(settings.dayOffKeywords, id: \.self) { keyword in
                    Text(keyword)
                }
                .onDelete { offsets in
                    model.settings.settings.dayOffKeywords.remove(atOffsets: offsets)
                }
                HStack {
                    TextField(l10n["morning.addKeyword"], text: $newKeyword)
                        .onSubmit(addKeyword)
                    Button(l10n["common.add"], action: addKeyword)
                        .disabled(newKeyword.nonBlank == nil)
                }
            } header: {
                Text(l10n["morning.daysOff"])
            } footer: {
                Text(l10n["morning.daysOffFooter"])
            }

            Section {
                Toggle(l10n["morning.health"], isOn: $store.settings.healthSleepEnabled)
            } footer: {
                Text(l10n["morning.healthFooter"])
            }

            Section {
                ruleStepper(l10n["score.grace"], value: $store.settings.wakeScoreRules.graceMinutes, range: WakeScoreRules.graceRange) {
                    l10n.minutesText($0)
                }
                ruleStepper(l10n["score.lateMinute"], value: $store.settings.wakeScoreRules.pointsPerLateMinute, range: WakeScoreRules.lateMinuteRange) {
                    l10n("score.points", $0)
                }
                ruleStepper(l10n["score.maxLate"], value: $store.settings.wakeScoreRules.maxLatePenalty, range: WakeScoreRules.maxLateRange, step: 5) {
                    l10n("score.points", $0)
                }
                ruleStepper(l10n["score.snooze"], value: $store.settings.wakeScoreRules.pointsPerSnooze, range: WakeScoreRules.snoozeRange) {
                    l10n("score.points", $0)
                }
                ruleStepper(l10n["score.missedCheck"], value: $store.settings.wakeScoreRules.missedCheckPenalty, range: WakeScoreRules.missedCheckRange) {
                    l10n("score.points", $0)
                }
                ruleStepper(l10n["score.threshold"], value: $store.settings.wakeScoreRules.successThreshold, range: WakeScoreRules.thresholdRange, step: 5) {
                    l10n.number($0)
                }
                Button(l10n["score.reset"]) {
                    model.settings.settings.wakeScoreRules = .default
                }
                .disabled(settings.wakeScoreRules == .default)
            } header: {
                Text(l10n["score.title"])
            } footer: {
                Text(l10n["score.footer"])
            }
        }
        .navigationTitle(l10n["morning.title"])
        .navigationBarTitleDisplayMode(.inline)
    }

    private func ruleStepper(_ title: String, value: Binding<Int>, range: ClosedRange<Int>, step: Int = 1, text: @escaping (Int) -> String) -> some View {
        Stepper(value: value, in: range, step: step) {
            LabeledContent(title, value: text(value.wrappedValue))
        }
    }

    private func addKeyword() {
        guard let keyword = newKeyword.nonBlank else { return }
        if !model.settings.settings.dayOffKeywords.contains(where: { $0.caseInsensitiveCompare(keyword) == .orderedSame }) {
            model.settings.settings.dayOffKeywords.append(keyword)
        }
        newKeyword = ""
    }
}
