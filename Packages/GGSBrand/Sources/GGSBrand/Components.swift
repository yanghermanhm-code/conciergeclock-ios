// Shared with FocusFound & FotoPhilter — change all (FotoPhilter: Packages/GGSBrand/Sources/GGSBrand/Components.swift).

import SwiftUI

// MARK: - Progress ring

/// The circular countdown ring. `progress` goes 0 → 1 as time elapses.
public struct ProgressRing<Fill: ShapeStyle>: View {
    private let progress: Double
    private let lineWidth: CGFloat
    private let fill: Fill

    public init(progress: Double, lineWidth: CGFloat = 14, fill: Fill) {
        self.progress = progress
        self.lineWidth = lineWidth
        self.fill = fill
    }

    public var body: some View {
        ZStack {
            Circle()
                .stroke(Theme.ringTrack, lineWidth: lineWidth)
            Circle()
                // Show remaining time: the ring shrinks as the phase progresses.
                .trim(from: 0, to: max(0.0001, 1 - progress))
                .stroke(fill, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90)) // start at 12 o'clock, like the app icon
        }
        .padding(lineWidth / 2)
    }
}

// MARK: - Buttons

/// Large filled capsule — the single most important action on a screen.
public struct PrimaryButtonStyle: ButtonStyle {
    private let tint: Color

    public init(tint: Color = Theme.accent) {
        self.tint = tint
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(tint.opacity(configuration.isPressed ? 0.8 : 1), in: Capsule())
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// Round icon button for secondary controls (reset, skip, +5).
public struct CircleIconButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.title3.weight(.semibold))
            .foregroundStyle(Theme.textPrimary)
            .frame(width: 56, height: 56)
            .background(Theme.surfaceMuted.opacity(configuration.isPressed ? 0.6 : 1), in: Circle())
            .opacity(isEnabled ? 1 : 0.35)
    }
}

// MARK: - Chips

/// Small rounded label, e.g. the current phase ("Focus", "Short Break").
public struct PhaseChip: View {
    private let title: String
    private let color: Color

    public init(_ title: String, color: Color) {
        self.title = title
        self.color = color
    }

    public var body: some View {
        Text(title.uppercased())
            .font(.caption.weight(.bold))
            .tracking(1.2)
            .foregroundStyle(color)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(color.opacity(0.12), in: Capsule())
    }
}

/// Dots showing progress through the long-break cycle ("●●○○").
public struct CycleDots: View {
    private let completed: Int
    private let total: Int
    private let color: Color
    private let accessibilityText: String

    /// - Parameter accessibilityText: spoken description, already translated by the app.
    public init(completed: Int, total: Int, color: Color = Theme.accent, accessibilityText: String) {
        self.completed = completed
        self.total = max(1, total)
        self.color = color
        self.accessibilityText = accessibilityText
    }

    public var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<total, id: \.self) { index in
                Circle()
                    .fill(index < completed ? color : Theme.ringTrack)
                    .frame(width: 8, height: 8)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }
}

// MARK: - Card

public extension View {
    /// Standard rounded surface used for grouped content.
    func cardStyle(padding: CGFloat = 16) -> some View {
        self
            .padding(padding)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Theme.hairline, lineWidth: 0.5)
            )
    }
}

#Preview("Components") {
    VStack(spacing: 24) {
        ProgressRing(progress: 0.35, fill: Theme.focusGradient)
            .frame(width: 220, height: 220)
        PhaseChip("Focus", color: Theme.focus)
        CycleDots(completed: 2, total: 4, accessibilityText: "2 of 4")
        Button("Start Focus") {}.buttonStyle(PrimaryButtonStyle())
        HStack {
            Button {} label: { Image(systemName: "arrow.counterclockwise") }
            Button {} label: { Image(systemName: "forward.end.fill") }
        }
        .buttonStyle(CircleIconButtonStyle())
    }
    .padding()
    .background(Theme.background)
}
