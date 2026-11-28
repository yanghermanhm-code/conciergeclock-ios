import ConciergeCore
import GGSBrand
import SwiftUI

/// Alarms tab: every alarm with its next ring, on/off switches, skip next, add and edit.
/// The alarms themselves are rung by iOS (AlarmKit), so they work with the app closed, in
/// silent mode and during Focus.
struct AlarmsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.l10n) private var l10n
    @State private var editing: Alarm?

    var body: some View {
        List {
            permissionSection
            if model.alarmList.isEmpty {
                Section {
                    ContentUnavailableView {
                        Label(l10n["alarms.empty.title"], systemImage: "alarm")
                    } description: {
                        Text(l10n["alarms.empty.message"])
                    } actions: {
                        Button(l10n["alarms.add"]) { editing = newAlarm() }
                            .buttonStyle(.borderedProminent)
                    }
                }
                .listRowBackground(Color.clear)
            } else {
                Section {
                    ForEach(model.alarmList) { alarm in
                        AlarmRow(alarm: alarm) { editing = alarm }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    model.delete(alarm)
                                } label: {
                                    Label(l10n["common.delete"], systemImage: "trash")
                                }
                                Button {
                                    model.toggleSkipNext(alarm)
                                } label: {
                                    Label(alarm.skipDay == nil ? l10n["alarms.skipNext"] : l10n["alarms.unskip"], systemImage: "forward.end")
                                }
                                .tint(.orange)
                            }
                            .contextMenu {
                                Button {
                                    model.toggleSkipNext(alarm)
                                } label: {
                                    Label(alarm.skipDay == nil ? l10n["alarms.skipNext"] : l10n["alarms.unskip"], systemImage: "forward.end")
                                }
                                Button(role: .destructive) {
                                    model.delete(alarm)
                                } label: {
                                    Label(l10n["common.delete"], systemImage: "trash")
                                }
                            }
                    }
                } footer: {
                    Text(l10n["alarms.footer"])
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .safeAreaInset(edge: .bottom) {
            if !model.alarmList.isEmpty {
                Button {
                    editing = newAlarm()
                } label: {
                    Label(l10n["alarms.add"], systemImage: "plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
                .accessibilityIdentifier("alarms.add")
            }
        }
        .sheet(item: $editing) { alarm in
            AlarmEditorView(alarm: alarm, isNew: !model.alarmList.contains { $0.id == alarm.id })
        }
    }

    @ViewBuilder
    private var permissionSection: some View {
        switch model.scheduler.authorization {
        case .denied:
            Section {
                Label(l10n["alarms.permission.denied"], systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Button(l10n["alarms.permission.openSettings"]) {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
            }
        case .notDetermined where !model.alarmList.isEmpty:
            Section {
                Button(l10n["alarms.permission.allow"]) {
                    Task { await model.scheduler.requestAuthorization() }
                }
            } footer: {
                Text(l10n["alarms.permission.footer"])
            }
        default:
            if let error = model.scheduler.lastError {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                        .font(.footnote)
                }
            }
        }
    }

    /// A new alarm at the next round half hour, on weekdays.
    private func newAlarm() -> Alarm {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: Date().addingTimeInterval(30 * 60))
        let minute = (parts.minute ?? 0) < 30 ? 30 : 0
        let hour = minute == 0 ? ((parts.hour ?? 7) + 1) % 24 : (parts.hour ?? 7)
        return Alarm(hour: hour, minute: minute, repeatDays: Weekdays.workWeek)
    }
}

/// One alarm: time, label, repeat days, next ring, and its switch.
private struct AlarmRow: View {
    let alarm: Alarm
    let onEdit: () -> Void
    @Environment(AppModel.self) private var model
    @Environment(\.l10n) private var l10n

    var body: some View {
        let time = Calendar.current.date(bySettingHour: alarm.hour, minute: alarm.minute, second: 0, of: Date()) ?? Date()
        HStack(alignment: .center, spacing: 12) {
            Button(action: onEdit) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(l10n.time(time))
                        .font(.system(.largeTitle, design: .rounded, weight: .semibold).monospacedDigit())
                        .foregroundStyle(alarm.isEnabled ? Theme.textPrimary : Theme.textSecondary)
                    Text([alarm.label.nonBlank, scheduleText].compactMap { $0 }.joined(separator: " · "))
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                    if alarm.isEnabled {
                        nextRingLine
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Toggle(isOn: Binding(get: { alarm.isEnabled }, set: { model.setEnabled($0, for: alarm) })) {
                Text(l10n.time(time))
            }
            .labelsHidden()
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityAction(named: l10n["common.edit"], onEdit)
    }

    /// Repeat days, or the exact date of a one-off alarm.
    private var scheduleText: String {
        if alarm.isDated, let day = alarm.date?.date() {
            return day.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted).locale(l10n.locale))
        }
        return l10n.repeatText(alarm.repeatDays)
    }

    @ViewBuilder
    private var nextRingLine: some View {
        if alarm.skipDay != nil {
            Label(l10n["alarms.skipped"], systemImage: "forward.end")
                .font(.caption)
                .foregroundStyle(.orange)
        } else if let next = model.nextRing(of: alarm) {
            Label(l10n("alarms.nextRing", l10n.dateTime(next)), systemImage: "bell")
                .font(.caption)
                .foregroundStyle(ConciergeStyle.tint)
        } else if alarm.isDated {
            Label(l10n["alarms.past"], systemImage: "checkmark.circle")
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
        }
    }
}
