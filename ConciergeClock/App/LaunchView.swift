import GGSBrand
import SwiftUI

/// The launch animation: the butler's nodes pop in, the mesh edges connect him, his tray and
/// alarm clock, then the name fades in (about 1.6 s). Tap anywhere to skip. With Reduce Motion on,
/// the finished mark is shown briefly instead. Same timing as PrepPilot's.
struct LaunchView: View {
    let onFinished: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.l10n) private var l10n
    @State private var start = Date()
    @State private var finished = false

    private let duration: TimeInterval = 1.6

    var body: some View {
        TimelineView(.animation(paused: finished)) { timeline in
            let elapsed = timeline.date.timeIntervalSince(start)
            let progress = reduceMotion ? 1 : min(1, elapsed / (duration * 0.75))
            let nameOpacity = reduceMotion ? 1 : min(1, max(0, (elapsed - duration * 0.6) / (duration * 0.3)))
            VStack(spacing: 20) {
                AnimatedButlerMark(progress: progress, style: colorScheme == .dark ? .onDark : .standard)
                    .frame(width: 200, height: 184)
                Text(verbatim: "ConciergeClock")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .foregroundStyle(Theme.focus)
                    .opacity(nameOpacity)
                BrandLockup(height: 34)
                    .environment(\.layoutDirection, .leftToRight)
                    .opacity(nameOpacity * 0.9)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.background)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: finish)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "ConciergeClock"))
        .accessibilityHint(l10n["launch.skipHint"])
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { finish() }
        .task {
            start = Date()
            let total = reduceMotion ? 0.6 : duration + 0.25
            try? await Task.sleep(for: .seconds(total))
            finish()
        }
    }

    private func finish() {
        guard !finished else { return }
        finished = true
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.3)) {
            onFinished()
        }
    }
}
