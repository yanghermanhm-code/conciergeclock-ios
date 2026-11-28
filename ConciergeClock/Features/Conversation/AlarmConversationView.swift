import ConciergeCore
import GGSBrand
import SwiftUI

/// Full screen while an alarm is being talked about: the butler, what he is doing (speaking,
/// listening, thinking), what he said and heard, and big buttons for Dismiss, Remind again and
/// Repeat.
struct AlarmConversationView: View {
    let conversation: AlarmConversation
    @Environment(AppModel.self) private var model
    @Environment(\.l10n) private var l10n

    var body: some View {
        let snooze = model.settings.settings.snoozeMinutes(for: conversation.alarm)
        VStack(spacing: 18) {
            HStack {
                Spacer()
                Button {
                    conversation.close()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title)
                        .foregroundStyle(Color.white.opacity(0.6))
                }
                .accessibilityLabel(l10n["common.done"])
            }
            ButlerNetworkMark(style: .onDark)
                .frame(height: 120)
            Text(conversation.alarm?.label.nonBlank ?? l10n["alarm.defaultTitle"])
                .font(.system(.title, design: .rounded, weight: .bold))
                .foregroundStyle(.white)
            Text(Date.now, style: .time)
                .font(.system(size: 56, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundStyle(.white)
            PhaseLabel(phase: conversation.phase)
            if let announcement = conversation.announcement {
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(announcement.lines) { line in
                            Text(line.text)
                                .font(.callout)
                                .foregroundStyle(Color.white.opacity(0.85))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        if !conversation.heard.isEmpty {
                            Label(conversation.heard, systemImage: "person.wave.2")
                                .font(.callout.italic())
                                .foregroundStyle(Brand.tealOnDark)
                        }
                    }
                }
                .frame(maxHeight: 180)
            }
            Spacer(minLength: 0)
            VStack(spacing: 12) {
                Button {
                    conversation.tap(.dismiss)
                } label: {
                    Label(l10n["conversation.dismiss"], systemImage: "checkmark.circle.fill")
                        .font(.title3.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 56)
                }
                .buttonStyle(.borderedProminent)
                .tint(Brand.tealOnDark)
                .accessibilityIdentifier("conversation.dismiss")
                HStack(spacing: 12) {
                    Button {
                        conversation.tap(.remindIn(minutes: snooze))
                    } label: {
                        Label(l10n("conversation.remind", snooze), systemImage: "zzz")
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: 52)
                    }
                    .buttonStyle(.bordered)
                    .tint(Brand.brassOnDark)
                    .accessibilityIdentifier("conversation.remind")
                    Button {
                        conversation.tapRepeat()
                    } label: {
                        Label(l10n["conversation.repeat"], systemImage: "arrow.counterclockwise")
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: 52)
                    }
                    .buttonStyle(.bordered)
                    .tint(.white)
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(colors: [Color(hex: 0x0D3B5C), Color(hex: 0x051A2B)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        )
        .preferredColorScheme(.dark)
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
    }
}

/// "Speaking…", "Listening…" (with a pulsing microphone), "Thinking…", or the outcome.
private struct PhaseLabel: View {
    let phase: AlarmConversation.Phase
    @Environment(\.l10n) private var l10n
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .scaleEffect(phase == .listening && pulse && !reduceMotion ? 1.25 : 1)
                .animation(phase == .listening && !reduceMotion ? .easeInOut(duration: 0.7).repeatForever() : .default, value: pulse)
            Text(text)
        }
        .font(.headline)
        .foregroundStyle(phase == .listening ? Brand.tealOnDark : Color.white.opacity(0.8))
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.08), in: Capsule())
        .onAppear { pulse = true }
        .accessibilityElement(children: .combine)
    }

    private var icon: String {
        switch phase {
        case .starting, .speaking: "speaker.wave.2.fill"
        case .listening: "mic.fill"
        case .thinking: "ellipsis.bubble"
        case .done: "checkmark.circle"
        case .buttonsOnly: "hand.tap"
        }
    }

    private var text: String {
        switch phase {
        case .starting, .speaking: l10n["conversation.speaking"]
        case .listening: l10n["conversation.listening"]
        case .thinking: l10n["conversation.thinking"]
        case let .done(message): message
        case let .buttonsOnly(message): message
        }
    }
}
