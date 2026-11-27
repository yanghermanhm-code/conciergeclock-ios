// Shared with FocusFound & FotoPhilter — change all (FotoPhilter: Packages/GGSBrand/Sources/GGSBrand/BrandProgressRing.swift).
// if FocusFound adopts it, keep both copies identical.

import SwiftUI

/// A brand mark (shield or graduation cap) inside a blue→green ring, used for imports,
/// exports, long tasks and mastery/readiness gauges.
///
/// Determinate progress fills the ring clockwise from 12 o'clock. Indeterminate progress
/// spins a short arc; with Reduce Motion on, the arc stays still and gently pulses instead.
public struct BrandProgressRing: View {
    public enum Progress: Equatable, Sendable {
        /// 0…1.
        case determinate(Double)
        case indeterminate
    }

    /// The mark drawn inside the ring. `.shield` keeps FocusFound/FotoPhilter unchanged.
    public enum Mark: Sendable {
        case shield
        case gradCap
        /// No mark: the caller overlays its own content (e.g. a percentage).
        case none
    }

    private let progress: Progress
    private let mark: Mark
    private let lineWidth: CGFloat
    private let accessibilityText: String

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// - Parameters:
    ///   - accessibilityText: spoken label, already translated by the app (e.g. "Importing").
    public init(_ progress: Progress, mark: Mark = .shield, lineWidth: CGFloat = 8, accessibilityText: String) {
        self.progress = progress
        self.mark = mark
        self.lineWidth = lineWidth
        self.accessibilityText = accessibilityText
    }

    private var gradient: AngularGradient {
        AngularGradient(
            colors: [Brand.blue, Brand.green, Brand.blue],
            center: .center,
            startAngle: .degrees(-90),
            endAngle: .degrees(270)
        )
    }

    public var body: some View {
        ZStack {
            Circle()
                .stroke(Theme.ringTrack, lineWidth: lineWidth)
            arc
            switch mark {
            case .shield:
                ShieldNetworkMark(style: colorScheme == .dark ? .onDark : .standard)
                    .padding(lineWidth * 2.2)
            case .gradCap:
                GradCapNetworkMark(style: colorScheme == .dark ? .onDark : .standard)
                    .padding(lineWidth * 2.2)
            case .none:
                EmptyView()
            }
        }
        .padding(lineWidth / 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityValue(accessibilityValue)
    }

    @ViewBuilder
    private var arc: some View {
        switch progress {
        case let .determinate(value):
            Circle()
                .trim(from: 0, to: max(0.0001, min(1, value)))
                .stroke(gradient, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: value)
        case .indeterminate:
            TimelineView(.animation) { timeline in
                let seconds = timeline.date.timeIntervalSinceReferenceDate
                if reduceMotion {
                    Circle()
                        .trim(from: 0, to: 0.3)
                        .stroke(gradient, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .opacity(0.55 + 0.45 * abs(sin(seconds * 1.5)))
                } else {
                    Circle()
                        .trim(from: 0, to: 0.3)
                        .stroke(gradient, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                        .rotationEffect(.degrees(seconds.truncatingRemainder(dividingBy: 1.2) / 1.2 * 360 - 90))
                }
            }
        }
    }

    private var accessibilityValue: String {
        switch progress {
        case let .determinate(value):
            (min(1, max(0, value))).formatted(.percent.precision(.fractionLength(0)))
        case .indeterminate:
            ""
        }
    }
}

#Preview("Progress ring") {
    HStack(spacing: 24) {
        BrandProgressRing(.determinate(0.62), accessibilityText: "Exporting")
            .frame(width: 96, height: 96)
        BrandProgressRing(.indeterminate, mark: .gradCap, accessibilityText: "Importing")
            .frame(width: 96, height: 96)
    }
    .padding()
}
