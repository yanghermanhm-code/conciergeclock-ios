import ConciergeCore
import GGSBrand
import SwiftUI

/// Alarms tab. Phase 1a shows what is coming; Phase 1b adds the alarm list, the editor and
/// real AlarmKit alarms that ring through silent mode and Focus.
struct AlarmsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.l10n) private var l10n

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if model.alarmList.isEmpty {
                    ContentUnavailableView {
                        Label(l10n["alarms.empty.title"], systemImage: "alarm")
                    } description: {
                        Text(l10n["alarms.empty.message"])
                    }
                    .padding(.top, 12)
                } else {
                    Text(l10n("alarms.count", model.alarmList.count))
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    ForEach(model.alarmList) { alarm in
                        AlarmSummaryRow(alarm: alarm)
                    }
                }
                ComingSoonCard(
                    systemImage: "alarm.waves.left.and.right",
                    title: l10n["alarms.soon.title"],
                    message: l10n["alarms.soon.message"],
                    items: [
                        l10n["alarms.soon.ring"],
                        l10n["alarms.soon.repeat"],
                        l10n["alarms.soon.snooze"],
                        l10n["alarms.soon.skip"],
                        l10n["alarms.soon.widget"],
                    ]
                )
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .background(Theme.background)
    }
}

/// One alarm: time, label and repeat days (read-only until the editor arrives in Phase 1b).
private struct AlarmSummaryRow: View {
    let alarm: Alarm
    @Environment(\.l10n) private var l10n

    var body: some View {
        let time = Calendar.current.date(bySettingHour: alarm.hour, minute: alarm.minute, second: 0, of: Date()) ?? Date()
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(l10n.time(time))
                    .font(.system(.largeTitle, design: .rounded, weight: .semibold).monospacedDigit())
                    .foregroundStyle(alarm.isEnabled ? Theme.textPrimary : Theme.textSecondary)
                Text([alarm.label.nonBlank, l10n.repeatText(alarm.repeatDays)].compactMap { $0 }.joined(separator: " · "))
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
        }
        .cardStyle()
        .accessibilityElement(children: .combine)
    }
}
