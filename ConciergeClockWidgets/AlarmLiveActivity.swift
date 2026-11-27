import AlarmKit
import ActivityKit
import GGSBrand
import SwiftUI
import WidgetKit

/// The Lock Screen and Dynamic Island view of a Concierge Clock alarm while it rings or snoozes.
/// iOS (AlarmKit) runs the alarm and its Stop / Snooze buttons; this only draws it.
struct AlarmLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AlarmAttributes<ConciergeAlarmMetadata>.self) { context in
            AlarmLockScreenView(attributes: context.attributes, state: context.state)
                .padding(16)
                .activityBackgroundTint(Color(hex: 0x0D3B5C))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    ButlerNetworkMark(style: .onDark)
                        .frame(width: 40, height: 37)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    AlarmCountdownText(state: context.state)
                        .font(.system(.title2, design: .rounded, weight: .semibold).monospacedDigit())
                        .foregroundStyle(Brand.tealOnDark)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.attributes.metadata?.label.isEmpty == false ? context.attributes.metadata?.label ?? "" : "Concierge Clock")
                        .font(.headline)
                        .lineLimit(1)
                }
            } compactLeading: {
                Image(systemName: "alarm.fill")
                    .foregroundStyle(Brand.brassOnDark)
            } compactTrailing: {
                AlarmCountdownText(state: context.state)
                    .monospacedDigit()
                    .frame(maxWidth: 52)
                    .foregroundStyle(Brand.tealOnDark)
            } minimal: {
                Image(systemName: "alarm.fill")
                    .foregroundStyle(Brand.brassOnDark)
            }
            .keylineTint(Brand.teal)
        }
    }
}

private struct AlarmLockScreenView: View {
    let attributes: AlarmAttributes<ConciergeAlarmMetadata>
    let state: AlarmPresentationState

    var body: some View {
        HStack(spacing: 14) {
            ButlerNetworkMark(style: .onDark)
                .frame(width: 46, height: 42)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: "Concierge Clock")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.white.opacity(0.7))
                Text(attributes.metadata?.label.isEmpty == false ? attributes.metadata?.label ?? "" : "⏰")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }
            Spacer()
            AlarmCountdownText(state: state)
                .font(.system(.title, design: .rounded, weight: .semibold).monospacedDigit())
                .foregroundStyle(Brand.tealOnDark)
        }
    }
}

/// While snoozing: the time left until it rings again. While ringing: a bell.
private struct AlarmCountdownText: View {
    let state: AlarmPresentationState

    var body: some View {
        switch state.mode {
        case let .countdown(countdown):
            Text(timerInterval: Date.now...max(Date.now, countdown.fireDate), countsDown: true)
        case .paused:
            Image(systemName: "pause.fill")
        default:
            Image(systemName: "bell.and.waves.left.and.right.fill")
        }
    }
}
