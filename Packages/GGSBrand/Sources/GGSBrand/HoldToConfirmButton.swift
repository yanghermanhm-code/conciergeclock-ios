// Shared with FocusFound & FotoPhilter — change all (FotoPhilter: Packages/GGSBrand/Sources/GGSBrand/HoldToConfirmButton.swift).

import SwiftUI

/// A button that only fires after being pressed and held for `duration` seconds,
/// filling up as you hold. Used for the Strict Mode emergency override.
/// VoiceOver users get an equivalent custom action, since long presses are hard there.
public struct HoldToConfirmButton: View {
    private let title: String
    private let systemImage: String
    private let duration: TimeInterval
    private let tint: Color
    private let onSecondElapsed: (Int) -> Void
    private let onComplete: () -> Void

    @State private var progress: Double = 0
    @State private var holdTask: Task<Void, Never>?

    /// - Parameters:
    ///   - onSecondElapsed: called once per full second held (for haptic ticks).
    ///   - onComplete: called when the hold finishes.
    public init(
        title: String,
        systemImage: String = "hand.raised.fill",
        duration: TimeInterval = 3,
        tint: Color = .red,
        onSecondElapsed: @escaping (Int) -> Void = { _ in },
        onComplete: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.duration = max(0.5, duration)
        self.tint = tint
        self.onSecondElapsed = onSecondElapsed
        self.onComplete = onComplete
    }

    public var body: some View {
        Label(title, systemImage: systemImage)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule().fill(tint.opacity(0.12))
                        Capsule()
                            .fill(tint.opacity(0.30))
                            .frame(width: geometry.size.width * progress)
                    }
                }
            }
            .clipShape(Capsule())
            .contentShape(Capsule())
            .onLongPressGesture(minimumDuration: duration, maximumDistance: 40) {
                finish()
            } onPressingChanged: { pressing in
                pressing ? begin() : cancel()
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(title)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { finish() }
    }

    private func begin() {
        holdTask?.cancel()
        let start = Date()
        holdTask = Task { @MainActor in
            var lastSecond = 0
            while !Task.isCancelled {
                let elapsed = Date().timeIntervalSince(start)
                progress = min(1, elapsed / duration)
                let second = Int(elapsed)
                if second > lastSecond, second < Int(duration.rounded(.up)) {
                    lastSecond = second
                    onSecondElapsed(second)
                }
                if elapsed >= duration { return }
                try? await Task.sleep(for: .milliseconds(30))
            }
        }
    }

    private func cancel() {
        holdTask?.cancel()
        holdTask = nil
        withAnimation(.easeOut(duration: 0.2)) { progress = 0 }
    }

    private func finish() {
        holdTask?.cancel()
        holdTask = nil
        progress = 0
        onComplete()
    }
}

#Preview {
    HoldToConfirmButton(title: "Hold 3 s to end sprint") {}
        .padding()
}
